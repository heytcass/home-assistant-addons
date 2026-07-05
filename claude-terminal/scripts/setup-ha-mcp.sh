#!/usr/bin/with-contenv bashio
# Setup ha-mcp (Home Assistant MCP Server) for Claude Code
# This script configures Claude Code to use ha-mcp for Home Assistant integration
# Repository: https://github.com/homeassistant-ai/ha-mcp

set -e

# Check if ha-mcp setup should be enabled
configure_ha_mcp_server() {
    local enable_ha_mcp
    enable_ha_mcp=$(bashio::config 'enable_ha_mcp' 'true')

    if [ "$enable_ha_mcp" != "true" ]; then
        bashio::log.info "ha-mcp integration is disabled in configuration"
        return 0
    fi

    bashio::log.info "Setting up ha-mcp (Home Assistant MCP Server)..."

    # Check for supervisor token (required for HA API access)
    if [ -z "${SUPERVISOR_TOKEN:-}" ]; then
        bashio::log.warning "SUPERVISOR_TOKEN not available - ha-mcp setup skipped"
        bashio::log.warning "MCP server requires Supervisor API access"
        return 0
    fi

    # Check if uv/uvx is available
    if ! command -v uvx &> /dev/null; then
        bashio::log.warning "uvx not found - ha-mcp setup skipped"
        return 0
    fi

    # Resolve the ha-mcp version to install (configurable via add-on options
    # so it can be bumped without waiting for an add-on release)
    local ha_mcp_version
    ha_mcp_version=$(bashio::config 'ha_mcp_version' '7.9.0')
    if [ -z "$ha_mcp_version" ] || [ "$ha_mcp_version" = "null" ]; then
        ha_mcp_version="7.9.0"
    fi

    # ha-mcp >=3.6 requires CPython 3.13 exactly (requires-python >=3.13,<3.14)
    # while Alpine ships 3.12, so let uv provision a managed musl Python 3.13.
    # It lands under XDG_DATA_HOME (/data), so it persists across restarts.
    # No managed musl builds exist for armv7 - stay on ha-mcp 3.5.1 there,
    # the last release that runs on the system Python.
    local machine
    local uvx_python_args=()
    machine=$(uname -m)
    case "$machine" in
        x86_64|aarch64)
            uvx_python_args=(--python 3.13)
            ;;
        *)
            if [ "$ha_mcp_version" != "3.5.1" ]; then
                bashio::log.warning "No managed Python 3.13 builds for ${machine}; using ha-mcp@3.5.1"
                ha_mcp_version="3.5.1"
            fi
            ;;
    esac

    # Configure Claude Code to use ha-mcp
    # The MCP server will connect to Home Assistant via the Supervisor API
    bashio::log.info "Configuring Claude Code MCP server for Home Assistant (ha-mcp@${ha_mcp_version})..."

    # Remove existing ha-mcp configuration if present (to ensure clean state)
    claude mcp remove home-assistant 2>/dev/null || true

    # Add ha-mcp as MCP server
    # Using stdio transport with uvx to run ha-mcp
    # Environment variables:
    #   HOMEASSISTANT_URL: Internal Supervisor API endpoint
    #   HOMEASSISTANT_TOKEN: Supervisor token for authentication
    if claude mcp add home-assistant \
        --env "HOMEASSISTANT_URL=http://supervisor/core" \
        --env "HOMEASSISTANT_TOKEN=${SUPERVISOR_TOKEN}" \
        -- uvx "${uvx_python_args[@]}" --index-strategy unsafe-best-match "ha-mcp@${ha_mcp_version}"; then
        bashio::log.info "ha-mcp configured successfully!"
        bashio::log.info "Claude Code now has access to Home Assistant via MCP"
        bashio::log.info "Available tools: entity control, automations, scripts, history, and more"

        # Pre-warm the uv caches in the background: the first launch downloads
        # Python 3.13 and the ha-mcp package into /data, which could otherwise
        # exceed the MCP client startup timeout on first connection
        (timeout 600 uvx "${uvx_python_args[@]}" --index-strategy unsafe-best-match \
            "ha-mcp@${ha_mcp_version}" --help </dev/null >/dev/null 2>&1 || true) &
    else
        bashio::log.warning "Failed to configure ha-mcp - continuing without MCP integration"
        bashio::log.warning "You can manually run: claude mcp add home-assistant --env HOMEASSISTANT_URL=http://supervisor/core --env HOMEASSISTANT_TOKEN=\$SUPERVISOR_TOKEN -- uvx ${uvx_python_args[*]} --index-strategy unsafe-best-match ha-mcp@${ha_mcp_version}"
    fi
}

# Run setup if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    configure_ha_mcp_server
fi
