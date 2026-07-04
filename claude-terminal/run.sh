#!/usr/bin/with-contenv bashio

# Enable strict error handling
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

    # Prefer a persistent native Claude Code install under /data over the npm
    # copy baked into the image (frozen at whatever version was current when
    # the image was built). Propagates through ttyd -> bash -> tmux -> claude.
    export PATH="${data_home}/.local/bin:${PATH}"

    # Migrate any existing authentication files from legacy locations
    migrate_legacy_auth_files "$claude_config_dir"

    # Install tmux configuration to user home directory
    if [ -f "/opt/scripts/tmux.conf" ]; then
        cp /opt/scripts/tmux.conf "$data_home/.tmux.conf"
        chmod 644 "$data_home/.tmux.conf"
        bashio::log.info "tmux configuration installed to $data_home/.tmux.conf"
    fi

    bashio::log.info "Environment initialized:"
    bashio::log.info "  - Home: $HOME"
    bashio::log.info "  - Config: $XDG_CONFIG_HOME"
    bashio::log.info "  - Claude config: $ANTHROPIC_CONFIG_DIR"
    bashio::log.info "  - Cache: $XDG_CACHE_HOME"
}

# One-time migration of existing authentication files
migrate_legacy_auth_files() {
    local target_dir="$1"
    local migrated=false

    bashio::log.info "Checking for existing authentication files to migrate..."

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
                    bashio::log.info "Created compatibility symlink: $legacy_path -> $target_dir"
                fi
                
                migrated=true
                bashio::log.info "Migration completed from: $legacy_path"
            else
                bashio::log.warning "Failed to migrate from: $legacy_path"
            fi
        fi
    done

    if [ "$migrated" = false ]; then
        bashio::log.info "No existing authentication files found to migrate"
    fi
}

# Install required tools
install_tools() {
    bashio::log.info "Installing additional tools..."
    if ! apk add --no-cache ttyd jq curl tmux; then
        bashio::log.error "Failed to install required tools"
        exit 1
    fi
    bashio::log.info "Tools installed successfully"
}

# Install persistent packages from config and saved state
install_persistent_packages() {
    bashio::log.info "Checking for persistent packages..."

    local persist_config="/data/persistent-packages.json"
    local apk_packages=""
    local pip_packages=""

    # Collect APK packages from Home Assistant config
    if bashio::config.has_value 'persistent_apk_packages'; then
        local config_apk
        config_apk=$(bashio::config 'persistent_apk_packages')
        if [ -n "$config_apk" ] && [ "$config_apk" != "null" ]; then
            apk_packages="$config_apk"
            bashio::log.info "Found APK packages in config: $apk_packages"
        fi
    fi

    # Collect pip packages from Home Assistant config
    if bashio::config.has_value 'persistent_pip_packages'; then
        local config_pip
        config_pip=$(bashio::config 'persistent_pip_packages')
        if [ -n "$config_pip" ] && [ "$config_pip" != "null" ]; then
            pip_packages="$config_pip"
            bashio::log.info "Found pip packages in config: $pip_packages"
        fi
    fi

    # Also check local persist-install config file
    if [ -f "$persist_config" ]; then
        bashio::log.info "Found local persistent packages config"

        # Get APK packages from local config
        local local_apk
        local_apk=$(jq -r '.apk_packages | join(" ")' "$persist_config" 2>/dev/null || echo "")
        if [ -n "$local_apk" ]; then
            apk_packages="$apk_packages $local_apk"
        fi

        # Get pip packages from local config
        local local_pip
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

    if [ -z "$apk_packages" ] && [ -z "$pip_packages" ]; then
        bashio::log.info "No persistent packages configured"
    fi
}

# Install or update a persistent native Claude Code build under /data.
# The npm copy baked into the image is frozen at image build time and the
# container filesystem is recreated on every restart, so a native install in
# /data is the only way to keep Claude Code current across restarts.
update_claude_native() {
    local claude_auto_update
    claude_auto_update=$(bashio::config 'claude_auto_update' 'true')

    if [ "$claude_auto_update" != "true" ]; then
        bashio::log.info "Claude Code auto-update disabled in configuration"
        return 0
    fi

    # Native builds are only published for x86_64/aarch64; other architectures
    # (armv7) keep the npm copy bundled in the image
    local machine
    machine=$(uname -m)
    case "$machine" in
        x86_64|aarch64) ;;
        *)
            bashio::log.info "No native Claude Code build for ${machine}, using bundled npm version"
            return 0
            ;;
    esac

    if [ -x "${HOME}/.local/bin/claude" ]; then
        # Native install already present: check for updates in the background
        # so startup is never delayed
        bashio::log.info "Native Claude Code found, checking for updates in background..."
        (timeout 300 "${HOME}/.local/bin/claude" update >/dev/null 2>&1 || true) &
    else
        # First run: install the native build (one-time cost). Probe
        # connectivity first so an offline boot is not delayed.
        if ! curl -fsSL -m 10 -o /dev/null https://claude.ai/install.sh 2>/dev/null; then
            bashio::log.warning "Cannot reach claude.ai, using bundled npm Claude Code for now"
            return 0
        fi
        bashio::log.info "Installing native Claude Code build to ${HOME}/.local/bin (persists in /data)..."
        if timeout 300 bash -c "curl -fsSL https://claude.ai/install.sh | bash" >/dev/null 2>&1; then
            bashio::log.info "Native Claude Code installed successfully"
        else
            bashio::log.warning "Native Claude Code install failed, using bundled npm version"
        fi
    fi

    bashio::log.info "Active Claude Code: $(command -v claude || echo 'not found') $(claude --version 2>/dev/null || echo '(version unavailable)')"
}

# Assemble extra launch flags for claude, exported as CLAUDE_LAUNCH_ARGS so
# both the auto-launch command and the session picker apply them consistently.
setup_claude_launch_args() {
    local launch_args=""

    # Opt-in bypass of Claude Code's permission prompts. Claude refuses this
    # flag for the root user unless IS_SANDBOX=1 marks the environment as a
    # disposable container, which this add-on is.
    if bashio::config.true 'dangerously_skip_permissions'; then
        bashio::log.warning "dangerously_skip_permissions is enabled: Claude will not ask before running tools"
        export IS_SANDBOX=1
        launch_args="--dangerously-skip-permissions"
    fi

    local extra_args
    extra_args=$(bashio::config 'claude_extra_args' '')
    if [ -n "$extra_args" ] && [ "$extra_args" != "null" ]; then
        launch_args="${launch_args} ${extra_args}"
    fi

    CLAUDE_LAUNCH_ARGS=$(echo "$launch_args" | xargs)
    export CLAUDE_LAUNCH_ARGS
    if [ -n "$CLAUDE_LAUNCH_ARGS" ]; then
        bashio::log.info "Claude launch args: ${CLAUDE_LAUNCH_ARGS}"
    fi
}

# Source user-provided init hooks from /data/init.d (persists across restarts).
# Escape hatch for customizing the ephemeral container at startup, e.g.
# exporting environment variables or adjusting PATH before ttyd launches.
source_user_init_hooks() {
    if [ -d /data/init.d ]; then
        local hook
        for hook in /data/init.d/*.sh; do
            [ -r "$hook" ] || continue
            bashio::log.info "Sourcing user init hook: ${hook}"
            # shellcheck disable=SC1090
            source "$hook" || bashio::log.warning "Init hook failed: ${hook}"
        done
    fi
}

# Setup session picker script
setup_session_picker() {
    # Copy session picker script from built-in location
    if [ -f "/opt/scripts/claude-session-picker.sh" ]; then
        if ! cp /opt/scripts/claude-session-picker.sh /usr/local/bin/claude-session-picker; then
            bashio::log.error "Failed to copy claude-session-picker script"
            exit 1
        fi
        chmod +x /usr/local/bin/claude-session-picker
        bashio::log.info "Session picker script installed successfully"
    else
        bashio::log.warning "Session picker script not found, using auto-launch mode only"
    fi

    # Setup authentication helper if it exists
    if [ -f "/opt/scripts/claude-auth-helper.sh" ]; then
        chmod +x /opt/scripts/claude-auth-helper.sh
        bashio::log.info "Authentication helper script ready"
    fi

    # Setup persist-install script if it exists
    if [ -f "/opt/scripts/persist-install.sh" ]; then
        if ! cp /opt/scripts/persist-install.sh /usr/local/bin/persist-install; then
            bashio::log.warning "Failed to copy persist-install script"
        else
            chmod +x /usr/local/bin/persist-install
            bashio::log.info "Persist-install script installed successfully"
        fi
    fi

    # Setup welcome script
    if [ -f "/opt/scripts/welcome.sh" ]; then
        if cp /opt/scripts/welcome.sh /usr/local/bin/welcome; then
            chmod +x /usr/local/bin/welcome
            bashio::log.info "Welcome script installed successfully"
        else
            bashio::log.warning "Failed to copy welcome script"
        fi
    fi

    # Setup ha-context script
    if [ -f "/opt/scripts/ha-context.sh" ]; then
        if cp /opt/scripts/ha-context.sh /usr/local/bin/ha-context; then
            chmod +x /usr/local/bin/ha-context
            bashio::log.info "HA context script installed successfully"
        else
            bashio::log.warning "Failed to copy ha-context script"
        fi
    fi

    # Write add-on version for welcome script to read (avoids bashio dependency in ttyd)
    bashio::addon.version > /opt/scripts/addon-version 2>/dev/null || echo "unknown" > /opt/scripts/addon-version
}

# Legacy monitoring functions removed - using simplified /data approach

# Generate Home Assistant context file for Claude sessions
generate_ha_context() {
    local ha_smart_context
    ha_smart_context=$(bashio::config 'ha_smart_context' 'true')

    if [ "$ha_smart_context" = "true" ]; then
        bashio::log.info "Generating Home Assistant context for Claude sessions..."
        if [ -f /usr/local/bin/ha-context ]; then
            if /usr/local/bin/ha-context 2>&1 | while IFS= read -r line; do
                bashio::log.info "$line"
            done; then
                bashio::log.info "HA context generated successfully"
            else
                bashio::log.warning "HA context generation had issues, continuing..."
            fi
        else
            bashio::log.warning "ha-context script not found, skipping"
        fi
    else
        bashio::log.info "HA Smart Context disabled in configuration"
    fi
}

# Determine Claude launch command based on configuration
get_claude_launch_command() {
    local auto_launch_claude

    # Get configuration value, default to true for backward compatibility
    auto_launch_claude=$(bashio::config 'auto_launch_claude' 'true')

    # Prepend welcome banner if available (runs inside ttyd, user-visible)
    local welcome_prefix=""
    if [ -f /usr/local/bin/welcome ]; then
        welcome_prefix="welcome; "
    fi

    # Apply configured launch flags (see setup_claude_launch_args)
    local claude_cmd="claude"
    if [ -n "${CLAUDE_LAUNCH_ARGS:-}" ]; then
        claude_cmd="claude ${CLAUDE_LAUNCH_ARGS}"
    fi

    if [ "$auto_launch_claude" = "true" ]; then
        # Use tmux for session persistence - attach to existing or create new
        echo "${welcome_prefix}tmux new-session -A -s claude '${claude_cmd}'"
    else
        # Session picker manages its own tmux sessions internally,
        # so do NOT wrap it in tmux (that would cause nested tmux errors)
        if [ -f /usr/local/bin/claude-session-picker ]; then
            echo "${welcome_prefix}/usr/local/bin/claude-session-picker"
        else
            # Fallback if session picker is missing
            bashio::log.warning "Session picker not found, falling back to auto-launch"
            echo "${welcome_prefix}tmux new-session -A -s claude '${claude_cmd}'"
        fi
    fi
}


# Start main web terminal
start_web_terminal() {
    local port=7681
    bashio::log.info "Starting web terminal on port ${port}..."
    
    # Log environment information for debugging
    bashio::log.info "Environment variables:"
    bashio::log.info "ANTHROPIC_CONFIG_DIR=${ANTHROPIC_CONFIG_DIR}"
    bashio::log.info "HOME=${HOME}"

    # Get the appropriate launch command based on configuration
    local launch_command
    launch_command=$(get_claude_launch_command)
    
    # Log the configuration being used
    local auto_launch_claude
    auto_launch_claude=$(bashio::config 'auto_launch_claude' 'true')
    bashio::log.info "Auto-launch Claude: ${auto_launch_claude}"
    
    # Set TTYD environment variable for tmux configuration
    # This disables tmux mouse mode since ttyd has better mouse handling for web terminals
    export TTYD=1

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

# Run health check
run_health_check() {
    if [ -f "/opt/scripts/health-check.sh" ]; then
        bashio::log.info "Running system health check..."
        chmod +x /opt/scripts/health-check.sh
        /opt/scripts/health-check.sh || bashio::log.warning "Some health checks failed but continuing..."
    fi
}

# Setup ha-mcp (Home Assistant MCP Server) for Claude Code integration
setup_ha_mcp() {
    if [ -f "/opt/scripts/setup-ha-mcp.sh" ]; then
        bashio::log.info "Setting up Home Assistant MCP integration..."
        chmod +x /opt/scripts/setup-ha-mcp.sh
        # Source the script to get the configure function
        source /opt/scripts/setup-ha-mcp.sh
        configure_ha_mcp_server || bashio::log.warning "ha-mcp setup encountered issues but continuing..."
    else
        bashio::log.info "ha-mcp setup script not found, skipping MCP integration"
    fi
}

# Main execution
main() {
    bashio::log.info "Initializing Claude Terminal add-on..."

    # Run diagnostics first (especially helpful for VirtualBox issues)
    run_health_check

    init_environment
    install_tools
    setup_session_picker
    install_persistent_packages
    update_claude_native
    setup_claude_launch_args
    source_user_init_hooks
    generate_ha_context
    setup_ha_mcp
    start_web_terminal
}

# Execute main function
main "$@"
