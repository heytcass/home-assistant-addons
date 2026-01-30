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
}

# Legacy monitoring functions removed - using simplified /data approach

# Start Claude API server in background
start_api_server() {
    local api_enabled
    api_enabled=$(bashio::config 'api_enabled' 'true')

    if [ "$api_enabled" = "false" ]; then
        bashio::log.info "API server disabled by configuration"
        return 0
    fi

    bashio::log.info "Starting Claude API server on port 7682..."

    # Start in background with logs to persistent location
    python3 /opt/scripts/claude-api-server.py > /data/api-server.log 2>&1 &
    API_PID=$!

    # Wait for startup
    sleep 2

    # Verify running
    if kill -0 $API_PID 2>/dev/null; then
        bashio::log.info "API server started successfully (PID: $API_PID)"
        bashio::log.info "API available at http://localhost:7682/api/health"
    else
        bashio::log.warning "API server failed to start"
        bashio::log.warning "Check logs at /data/api-server.log"
    fi
}

# Determine Claude launch command based on configuration
get_claude_launch_command() {
    local auto_launch_claude
    
    # Get configuration value, default to true for backward compatibility
    auto_launch_claude=$(bashio::config 'auto_launch_claude' 'true')
    
    if [ "$auto_launch_claude" = "true" ]; then                                                                 
        # Use tmux for session persistence - attach to existing or create new                                   
        echo "tmux new-session -A -s claude 'claude'"                                                           
    else                                                                                                        
        # New behavior: show interactive session picker (also with tmux persistence)                            
        if [ -f /usr/local/bin/claude-session-picker ]; then                                                    
            echo "tmux new-session -A -s claude-picker '/usr/local/bin/claude-session-picker'"                  
        else                                                                                                    
            # Fallback if session picker is missing                                                             
            bashio::log.warning "Session picker not found, falling back to auto-launch"                         
            echo "tmux new-session -A -s claude 'claude'"                                                       
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
    start_api_server
    start_web_terminal
}

# Execute main function
main "$@"
