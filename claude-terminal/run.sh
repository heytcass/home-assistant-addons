#!/usr/bin/with-contenv bashio

# Claude Terminal — Claude Code in a browser terminal (ttyd + tmux).
#
# Startup philosophy: everything the terminal needs is baked into the image,
# and nothing on the boot path may depend on the network or block on input.
# Network work (Claude updates, HA context generation) happens in the
# background after the terminal is already available.

set -e
set -o pipefail

# Initialize environment for Claude Code CLI using /data (HA best practice)
init_environment() {
    # Use /data exclusively - guaranteed writable by HA Supervisor
    local data_home="/data/home"
    local config_dir="/data/.config"
    local cache_dir="/data/.cache"
    local state_dir="/data/.local/state"
    local claude_config_dir="/data/.config/claude"

    bashio::log.info "Initializing Claude Code environment in /data..."

    # Create all required directories
    if ! mkdir -p "$data_home" "$config_dir/claude" "$cache_dir" "$state_dir" "/data/.local"; then
        bashio::log.error "Failed to create directories in /data"
        exit 1
    fi

    # Set permissions
    chmod 755 "$data_home" "$config_dir" "$cache_dir" "$state_dir" "$claude_config_dir"

    # Set XDG and application environment variables
    export HOME="$data_home"
    export XDG_CONFIG_HOME="$config_dir"
    export XDG_CACHE_HOME="$cache_dir"
    export XDG_STATE_HOME="$state_dir"
    export XDG_DATA_HOME="/data/.local/share"

    # Claude-specific environment variables
    export ANTHROPIC_CONFIG_DIR="$claude_config_dir"
    export ANTHROPIC_HOME="/data"

    # The persistent native Claude install (see update_claude) must win over
    # the npm copy bundled in the image
    export PATH="$data_home/.local/bin:$PATH"

    # Older versions let the npm cache pile up here, inflating HA backups by
    # gigabytes (#103). The cache now lives in /tmp (npm_config_cache env).
    rm -rf "$data_home/.npm"

    # Migrate any existing authentication files from legacy locations
    migrate_legacy_auth_files "$claude_config_dir"

    # Install tmux configuration to user home directory
    if [ -f "/opt/scripts/tmux.conf" ]; then
        cp /opt/scripts/tmux.conf "$data_home/.tmux.conf"
        chmod 644 "$data_home/.tmux.conf"
    fi

    bashio::log.info "Environment initialized (HOME=${HOME})"
}

# One-time migration of existing authentication files
migrate_legacy_auth_files() {
    local target_dir="$1"
    local migrated=false

    # Check common legacy locations
    local legacy_locations=(
        "/root/.config/anthropic"
        "/root/.anthropic"
        "/config/claude-config"
        "/tmp/claude-config"
    )

    for legacy_path in "${legacy_locations[@]}"; do
        if [ -d "$legacy_path" ] && [ "$(ls -A "$legacy_path" 2>/dev/null)" ]; then
            bashio::log.info "Migrating auth files from: $legacy_path"

            # Copy files to new location
            if cp -r "$legacy_path"/* "$target_dir/" 2>/dev/null; then
                # Set proper permissions
                find "$target_dir" -type f -exec chmod 600 {} \;

                # Create compatibility symlink if this is a standard location
                if [[ "$legacy_path" == "/root/.config/anthropic" ]] || [[ "$legacy_path" == "/root/.anthropic" ]]; then
                    rm -rf "$legacy_path"
                    ln -sf "$target_dir" "$legacy_path"
                fi

                migrated=true
                bashio::log.info "Migration completed from: $legacy_path"
            else
                bashio::log.warning "Failed to migrate from: $legacy_path"
            fi
        fi
    done

    if [ "$migrated" = false ]; then
        bashio::log.info "No legacy authentication files to migrate"
    fi
}

# Install user-facing commands into /usr/local/bin
setup_commands() {
    local entry name script
    for entry in \
        "welcome:/opt/scripts/welcome.sh" \
        "persist-install:/opt/scripts/persist-install.sh" \
        "ha-context:/opt/scripts/ha-context.sh" \
        "claude-doctor:/opt/scripts/health-check.sh" \
        "claude-login-url:/opt/scripts/claude-login-url.sh"; do
        name="${entry%%:*}"
        script="${entry#*:}"
        if [ -f "$script" ]; then
            cp "$script" "/usr/local/bin/$name"
            chmod +x "/usr/local/bin/$name"
        else
            bashio::log.warning "Script not found: $script"
        fi
    done

    # Write add-on version for the welcome banner (no bashio inside ttyd)
    bashio::addon.version > /opt/scripts/addon-version 2>/dev/null \
        || echo "unknown" > /opt/scripts/addon-version
}

# Keep Claude Code current. The npm copy in the image is frozen at build
# time, so install the official native build into /data (persists across
# restarts and add-on updates) and refresh it in the background on each
# boot. Approach adapted from #104 by @WKassebaum.
# A native install being executable (-x) is not the same as it being
# runnable. The native build is dynamically linked, so a libc symbol
# mismatch — e.g. the Alpine base image's musl lacking `posix_getdents`,
# which recent Claude Code builds relocate against — makes the binary abort
# on launch with a relocation error even though the file is present and +x.
# Such a binary still wins on PATH over the bundled copy and takes the whole
# terminal down with it (ttyd runs `tmux new-session ... 'claude'`, so the
# tmux session dies the instant claude does). Treat "installed" and
# "actually runs" as separate facts.
native_claude_runs() {
    "$HOME/.local/bin/claude" --version >/dev/null 2>&1
}

# Remove a persistent native install that exists but cannot execute in this
# image (typically a libc mismatch), so it stops shadowing the working
# bundled copy at /usr/local/bin/claude on PATH. This must run regardless of
# the auto-update setting — a broken +x binary is what takes the terminal
# down, and disabling auto-update does not remove it. Returns 0 if a usable
# native install remains, 1 otherwise.
ensure_native_claude_usable() {
    [ -x "$HOME/.local/bin/claude" ] || return 1
    if native_claude_runs; then
        return 0
    fi
    bashio::log.warning "Persistent Claude Code is present but fails to run (likely a libc mismatch); removing it and falling back to the bundled copy"
    rm -f "$HOME/.local/bin/claude"
    return 1
}

update_claude() {
    # Always neutralise a broken persistent install first, even when
    # auto-update is off, so it can't keep shadowing the bundled copy.
    # Capture via `|| native_usable=$?` so the intentional non-zero return
    # (no/removed native install) doesn't trip `set -e` and abort startup.
    local native_usable=0
    ensure_native_claude_usable || native_usable=$?

    if [ "$(bashio::config 'claude_auto_update' 'true')" != "true" ]; then
        if [ "$native_usable" -eq 0 ]; then
            bashio::log.info "Claude auto-update disabled; using persistent Claude Code"
        else
            bashio::log.info "Claude auto-update disabled; using bundled Claude Code"
        fi
        return 0
    fi

    if [ "$native_usable" -eq 0 ]; then
        bashio::log.info "Persistent Claude Code found; checking for updates in background"
        (
            "$HOME/.local/bin/claude" update >/dev/null 2>&1 || true
            # An update can pull a build this image's libc can't run; don't
            # let it linger on PATH for the next launch or reconnect.
            if [ -x "$HOME/.local/bin/claude" ] && ! native_claude_runs; then
                bashio::log.warning "Updated Claude Code no longer runs in this image; removing it and falling back to the bundled copy"
                rm -f "$HOME/.local/bin/claude"
            fi
        ) &
        return 0
    fi

    bashio::log.info "Installing persistent Claude Code into /data (background)..."
    (
        if curl -fsSL --connect-timeout 10 https://claude.ai/install.sh | bash >/dev/null 2>&1 \
            && [ -x "$HOME/.local/bin/claude" ] && native_claude_runs; then
            bashio::log.info "Persistent Claude Code installed: $("$HOME/.local/bin/claude" --version 2>/dev/null || echo 'version unknown')"
        else
            # Don't let a freshly installed but unrunnable binary shadow the
            # bundled copy either.
            rm -f "$HOME/.local/bin/claude"
            bashio::log.warning "Native Claude Code install unavailable or unrunnable; using bundled copy"
        fi
    ) &
}

# Install persistent packages from config and saved state
install_persistent_packages() {
    local persist_config="/data/persistent-packages.json"
    local apk_packages=""
    local pip_packages=""

    # Collect APK packages from Home Assistant config
    if bashio::config.has_value 'persistent_apk_packages'; then
        local config_apk
        config_apk=$(bashio::config 'persistent_apk_packages')
        if [ -n "$config_apk" ] && [ "$config_apk" != "null" ]; then
            apk_packages="$config_apk"
        fi
    fi

    # Collect pip packages from Home Assistant config
    if bashio::config.has_value 'persistent_pip_packages'; then
        local config_pip
        config_pip=$(bashio::config 'persistent_pip_packages')
        if [ -n "$config_pip" ] && [ "$config_pip" != "null" ]; then
            pip_packages="$config_pip"
        fi
    fi

    # Also check local persist-install config file
    if [ -f "$persist_config" ]; then
        local local_apk local_pip
        local_apk=$(jq -r '.apk_packages | join(" ")' "$persist_config" 2>/dev/null || echo "")
        if [ -n "$local_apk" ]; then
            apk_packages="$apk_packages $local_apk"
        fi

        local_pip=$(jq -r '.pip_packages | join(" ")' "$persist_config" 2>/dev/null || echo "")
        if [ -n "$local_pip" ]; then
            pip_packages="$pip_packages $local_pip"
        fi
    fi

    # Trim whitespace and remove duplicates
    apk_packages=$(echo "$apk_packages" | tr ' ' '\n' | sort -u | tr '\n' ' ' | xargs)
    pip_packages=$(echo "$pip_packages" | tr ' ' '\n' | sort -u | tr '\n' ' ' | xargs)

    # Install APK packages
    if [ -n "$apk_packages" ]; then
        bashio::log.info "Installing persistent APK packages: $apk_packages"
        # shellcheck disable=SC2086
        if apk add --no-cache $apk_packages; then
            bashio::log.info "APK packages installed successfully"
        else
            bashio::log.warning "Some APK packages failed to install"
        fi
    fi

    # Install pip packages
    if [ -n "$pip_packages" ]; then
        bashio::log.info "Installing persistent pip packages: $pip_packages"
        # shellcheck disable=SC2086
        if pip3 install --break-system-packages --no-cache-dir $pip_packages; then
            bashio::log.info "pip packages installed successfully"
        else
            bashio::log.warning "Some pip packages failed to install"
        fi
    fi
}

# Generate Home Assistant context file for Claude sessions (background —
# a slow Supervisor API must never delay the terminal)
generate_ha_context() {
    if [ "$(bashio::config 'ha_smart_context' 'true')" != "true" ]; then
        bashio::log.info "HA Smart Context disabled in configuration"
        return 0
    fi

    if [ -f /usr/local/bin/ha-context ]; then
        bashio::log.info "Generating Home Assistant context in background"
        (/usr/local/bin/ha-context >/dev/null 2>&1 || true) &
    fi
}

# Build extra flags for every claude launch.
# Note: the value is word-split; quoted multi-word arguments are not
# re-parsed (documented limitation).
build_claude_flags() {
    local flags=""

    if [ "$(bashio::config 'dangerously_skip_permissions' 'false')" = "true" ]; then
        flags="--dangerously-skip-permissions"
    fi

    local extra
    extra=$(bashio::config 'claude_extra_args' '')
    if [ -n "$extra" ] && [ "$extra" != "null" ]; then
        flags="${flags:+$flags }$extra"
    fi

    echo "$flags"
}

# Determine the command ttyd runs for each client connection
get_claude_launch_command() {
    local flags="$1"

    if [ "$(bashio::config 'auto_launch_claude' 'true')" = "true" ]; then
        # tmux -A attaches to the live session on browser reconnects and HA
        # navigation instead of stacking new ones
        echo "tmux new-session -A -s claude 'claude${flags:+ $flags}'"
    else
        # Shell mode: banner + interactive bash, still inside tmux for
        # reconnect persistence. Run 'claude' manually when ready.
        echo "tmux new-session -A -s claude '/usr/local/bin/welcome --shell'"
    fi
}

# Start main web terminal
start_web_terminal() {
    local port=7681
    local flags
    flags=$(build_claude_flags)

    if [[ "$flags" == *"--dangerously-skip-permissions"* ]]; then
        bashio::log.warning "=========================================================="
        bashio::log.warning "dangerously_skip_permissions is ENABLED."
        bashio::log.warning "Claude will run tools without asking for confirmation."
        bashio::log.warning "It has write access to /config and can control Home"
        bashio::log.warning "Assistant through the Supervisor API and MCP."
        bashio::log.warning "=========================================================="
    fi

    local launch_command
    launch_command=$(get_claude_launch_command "$flags")

    bashio::log.info "Starting web terminal on port ${port} (auto_launch_claude=$(bashio::config 'auto_launch_claude' 'true'))"

    # Terminal theme - dark palette with terracotta accents (#d97757)
    local ttyd_theme='{"background":"#1a1b26","foreground":"#c0caf5","cursor":"#d97757","cursorAccent":"#1a1b26","selectionBackground":"#33467c","selectionForeground":"#c0caf5","black":"#15161e","red":"#f7768e","green":"#9ece6a","yellow":"#e0af68","blue":"#7aa2f7","magenta":"#bb9af7","cyan":"#7dcfff","white":"#a9b1d6","brightBlack":"#414868","brightRed":"#f7768e","brightGreen":"#9ece6a","brightYellow":"#e0af68","brightBlue":"#7aa2f7","brightMagenta":"#bb9af7","brightCyan":"#7dcfff","brightWhite":"#c0caf5"}'

    # Run ttyd with keepalive configuration to prevent WebSocket disconnects
    # See: https://github.com/heytcass/home-assistant-addons/issues/24
    exec ttyd \
        --port "${port}" \
        --interface 0.0.0.0 \
        --writable \
        --ping-interval 30 \
        --client-option enableReconnect=true \
        --client-option reconnect=10 \
        --client-option reconnectInterval=5 \
        --client-option "theme=${ttyd_theme}" \
        --client-option fontSize=14 \
        bash -c "$launch_command"
}

# Setup ha-mcp (Home Assistant MCP Server) for Claude Code integration
setup_ha_mcp() {
    if [ -f "/opt/scripts/setup-ha-mcp.sh" ]; then
        bashio::log.info "Setting up Home Assistant MCP integration..."
        chmod +x /opt/scripts/setup-ha-mcp.sh
        # Source the script to get the configure function
        source /opt/scripts/setup-ha-mcp.sh
        configure_ha_mcp_server || bashio::log.warning "ha-mcp setup encountered issues but continuing..."
    fi
}

# Main execution
main() {
    bashio::log.info "Starting Claude Terminal add-on..."

    init_environment
    setup_commands
    update_claude
    install_persistent_packages
    generate_ha_context
    setup_ha_mcp
    start_web_terminal
}

# Execute main function
main "$@"
