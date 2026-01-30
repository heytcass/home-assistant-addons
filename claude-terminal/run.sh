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

    # Security: Set restrictive permissions (700 = owner-only access)
    chmod 700 "$data_home" "$config_dir" "$cache_dir" "$state_dir" "$claude_config_dir"

    # Ensure all credential files have secure permissions
    if [ -d "$claude_config_dir" ]; then
        find "$claude_config_dir" -type f -exec chmod 600 {} \; 2>/dev/null || true
    fi

    # Set XDG and application environment variables
    export HOME="$data_home"
    export XDG_CONFIG_HOME="$config_dir"
    export XDG_CACHE_HOME="$cache_dir"
    export XDG_STATE_HOME="$state_dir"
    export XDG_DATA_HOME="/data/.local/share"
    
    # Claude-specific environment variables
    export ANTHROPIC_CONFIG_DIR="$claude_config_dir"
    export ANTHROPIC_HOME="/data"

    # Migrate any existing authentication files from legacy locations
    migrate_legacy_auth_files "$claude_config_dir"

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
        # Security: Skip /tmp sources to prevent symlink attacks
        if [[ "$legacy_path" == /tmp/* ]]; then
            bashio::log.warning "Skipping migration from /tmp for security: $legacy_path"
            continue
        fi

        if [ -d "$legacy_path" ] && [ ! -L "$legacy_path" ] && [ "$(ls -A "$legacy_path" 2>/dev/null)" ]; then
            # Security: Verify it's a real directory, not a symlink
            if [ -L "$legacy_path" ]; then
                bashio::log.warning "Skipping symlink: $legacy_path"
                continue
            fi

            bashio::log.info "Migrating auth files from: $legacy_path"

            # Copy files to new location (already created with secure permissions)
            if cp -r "$legacy_path"/* "$target_dir/" 2>/dev/null; then
                # Security: Set proper permissions on copied files BEFORE any cleanup
                find "$target_dir" -type f -exec chmod 600 {} \;
                find "$target_dir" -type d -exec chmod 700 {} \;

                # Create compatibility symlink if this is a standard location
                # Security: Use atomic operations to prevent TOCTOU race conditions
                if [[ "$legacy_path" == "/root/.config/anthropic" ]] || [[ "$legacy_path" == "/root/.anthropic" ]]; then
                    # Create temporary symlink with unique name
                    local temp_link="${legacy_path}.tmp.$$"

                    # Atomically create symlink
                    if ln -sf "$target_dir" "$temp_link"; then
                        # Atomically replace directory with symlink
                        if mv -f "$temp_link" "$legacy_path" 2>/dev/null; then
                            bashio::log.info "Created compatibility symlink: $legacy_path -> $target_dir"
                        else
                            # Fallback: remove temp link if move failed
                            rm -f "$temp_link"
                            bashio::log.warning "Could not create symlink at: $legacy_path (may require manual cleanup)"
                        fi
                    fi
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
    if ! apk add --no-cache ttyd jq curl; then
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

    # Install pip packages (with --break-system-packages for PEP-0668 compatibility)
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

    # Setup smart resume helper
    if [ -f "/opt/scripts/claude-smart-resume.sh" ]; then
        if ! cp /opt/scripts/claude-smart-resume.sh /usr/local/bin/claude-smart-resume; then
            bashio::log.error "Failed to copy claude-smart-resume script"
            exit 1
        fi
        chmod +x /usr/local/bin/claude-smart-resume
        bashio::log.info "Smart resume script installed successfully"
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
}

# Legacy monitoring functions removed - using simplified /data approach

# Determine Claude launch command based on configuration
get_claude_launch_command() {
    local auto_launch_claude
    local auto_resume_session

    # Get configuration values, default to true for backward compatibility
    auto_launch_claude=$(bashio::config 'auto_launch_claude' 'true')
    auto_resume_session=$(bashio::config 'auto_resume_session' 'true')

    if [ "$auto_launch_claude" = "true" ]; then
        # Check if auto-resume is enabled
        if [ "$auto_resume_session" = "true" ]; then
            # Use smart resume script that handles missing sessions gracefully
            if [ -f /usr/local/bin/claude-smart-resume ]; then
                echo "clear && echo 'Welcome to Claude Terminal!' && echo '' && /usr/local/bin/claude-smart-resume"
            else
                # Fallback: start new session if smart resume not available
                bashio::log.warning "Smart resume script not found, starting new session"
                echo "clear && echo 'Welcome to Claude Terminal!' && echo '' && echo 'Starting Claude...' && sleep 1 && claude"
            fi
        else
            # Original behavior: auto-launch new Claude session
            echo "clear && echo 'Welcome to Claude Terminal!' && echo '' && echo 'Starting Claude...' && sleep 1 && claude"
        fi
    else
        # Show interactive session picker
        if [ -f /usr/local/bin/claude-session-picker ]; then
            echo "clear && /usr/local/bin/claude-session-picker"
        else
            # Fallback if session picker is missing
            bashio::log.warning "Session picker not found, falling back to auto-launch"
            if [ "$auto_resume_session" = "true" ] && [ -f /usr/local/bin/claude-smart-resume ]; then
                echo "clear && echo 'Welcome to Claude Terminal!' && echo '' && /usr/local/bin/claude-smart-resume"
            else
                echo "clear && echo 'Welcome to Claude Terminal!' && echo '' && echo 'Starting Claude...' && sleep 1 && claude"
            fi
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
    local auto_resume_session
    auto_launch_claude=$(bashio::config 'auto_launch_claude' 'true')
    auto_resume_session=$(bashio::config 'auto_resume_session' 'true')
    bashio::log.info "Auto-launch Claude: ${auto_launch_claude}"
    bashio::log.info "Auto-resume session: ${auto_resume_session}"
    
    # Run ttyd with keepalive configuration to prevent WebSocket disconnects
    # See: https://github.com/Arborist-ai/HA-LCASS/issues/24
    # Security Note: Binds to 0.0.0.0 for Home Assistant ingress compatibility.
    # Access is controlled by Home Assistant authentication (panel_admin: true).
    # For production, remove direct port exposure in config.yaml - use ingress only.
    exec ttyd \
        --port "${port}" \
        --interface 0.0.0.0 \
        --writable \
        --ping-interval 30 \
        --client-option enableReconnect=true \
        --client-option reconnect=10 \
        --client-option reconnectInterval=5 \
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

# Main execution
main() {
    bashio::log.info "Initializing Claude Terminal add-on..."

    # Run diagnostics first (especially helpful for VirtualBox issues)
    run_health_check

    init_environment
    install_tools
    setup_session_picker
    install_persistent_packages
    start_web_terminal
}

# Execute main function
main "$@"