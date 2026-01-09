#!/usr/bin/with-contenv bashio

# Enable strict error handling
set -e
set -o pipefail

# Secure credential directory permissions
secure_credential_permissions() {
    local claude_config_dir="$1"

    bashio::log.info "Securing credential directory permissions..."

    # Ensure directory has restrictive permissions (700 = rwx------)
    chmod 700 "$claude_config_dir" 2>/dev/null || {
        bashio::log.warning "Could not set directory permissions for $claude_config_dir"
    }

    # Secure all credential files (600 = rw-------)
    if [ -d "$claude_config_dir" ]; then
        find "$claude_config_dir" -type f -exec chmod 600 {} \; 2>/dev/null
        bashio::log.info "Credential files secured with 600 permissions"
    fi

    # Remove any world-readable files in parent directories that might leak info
    find "/data/.config" -maxdepth 1 -type f -perm -004 -exec chmod 600 {} \; 2>/dev/null || true
}

# Initialize environment for Claude Code CLI using /data (HA best practice)
init_environment() {
    # Use /data exclusively - guaranteed writable by HA Supervisor
    local data_home="/data/home"
    local config_dir="/data/.config"
    local cache_dir="/data/.cache"
    local state_dir="/data/.local/state"
    local claude_config_dir="/data/.config/claude"

    bashio::log.info "Initializing Claude Code environment in /data..."

    # Create all required directories with secure permissions from the start
    if ! (umask 077 && mkdir -p "$data_home" "$config_dir/claude" "$cache_dir" "$state_dir" "/data/.local"); then
        bashio::log.error "Failed to create directories in /data"
        exit 1
    fi

    # Set restrictive permissions on sensitive directories
    chmod 700 "$claude_config_dir"
    chmod 755 "$data_home" "$config_dir" "$cache_dir" "$state_dir"

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

    # Apply additional security measures to credential storage
    secure_credential_permissions "$claude_config_dir"

    bashio::log.info "Environment initialized with enhanced security:"
    bashio::log.info "  - Home: $HOME"
    bashio::log.info "  - Config: $XDG_CONFIG_HOME"
    bashio::log.info "  - Claude config: $ANTHROPIC_CONFIG_DIR (secured)"
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
        # Security check: Skip if path is a symlink to prevent symlink attacks
        if [ -L "$legacy_path" ]; then
            bashio::log.warning "Skipping $legacy_path: symlink detected (security measure)"
            continue
        fi

        if [ -d "$legacy_path" ] && [ "$(ls -A "$legacy_path" 2>/dev/null)" ]; then
            bashio::log.info "Migrating auth files from: $legacy_path"

            # Copy files to new location, excluding symlinks
            if find "$legacy_path" -maxdepth 1 -type f -exec cp {} "$target_dir/" \; 2>/dev/null; then
                # Set secure permissions: owner read/write only
                find "$target_dir" -type f -exec chmod 600 {} \;
                find "$target_dir" -type d -exec chmod 700 {} \;

                # Create compatibility symlink if this is a standard location
                # Security: Only create symlink if path doesn't exist or is not critical
                if [[ "$legacy_path" == "/root/.config/anthropic" ]] || [[ "$legacy_path" == "/root/.anthropic" ]]; then
                    # Double-check path is safe before removal
                    if [ -d "$legacy_path" ] && [ ! -L "$legacy_path" ]; then
                        rm -rf "$legacy_path"
                        ln -sf "$target_dir" "$legacy_path"
                        bashio::log.info "Created compatibility symlink: $legacy_path -> $target_dir"
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
}

# Legacy monitoring functions removed - using simplified /data approach

# Determine Claude launch command based on configuration
get_claude_launch_command() {
    local auto_launch_claude
    
    # Get configuration value, default to true for backward compatibility
    auto_launch_claude=$(bashio::config 'auto_launch_claude' 'true')
    
    if [ "$auto_launch_claude" = "true" ]; then
        # Original behavior: auto-launch Claude directly
        echo "clear && echo 'Welcome to Claude Terminal!' && echo '' && echo 'Starting Claude...' && sleep 1 && node \$(which claude)"
    else
        # New behavior: show interactive session picker
        if [ -f /usr/local/bin/claude-session-picker ]; then
            echo "clear && /usr/local/bin/claude-session-picker"
        else
            # Fallback if session picker is missing
            bashio::log.warning "Session picker not found, falling back to auto-launch"
            echo "clear && echo 'Welcome to Claude Terminal!' && echo '' && echo 'Starting Claude...' && sleep 1 && node \$(which claude)"
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
    
    # Run ttyd with improved configuration
    exec ttyd \
        --port "${port}" \
        --interface 0.0.0.0 \
        --writable \
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
    start_web_terminal
}

# Execute main function
main "$@"