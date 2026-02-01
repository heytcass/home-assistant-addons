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

    # Configure Claude Code to use ha-mcp
    # The MCP server will connect to Home Assistant via the Supervisor API
    bashio::log.info "Configuring Claude Code MCP server for Home Assistant..."

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
        -- uvx ha-mcp@latest; then
        bashio::log.info "ha-mcp configured successfully!"
        bashio::log.info "Claude Code now has access to Home Assistant via MCP"
        bashio::log.info "Available tools: entity control, automations, scripts, history, and more"
    else
        bashio::log.warning "Failed to configure ha-mcp - continuing without MCP integration"
        bashio::log.warning "You can manually run: claude mcp add home-assistant --env HOMEASSISTANT_URL=http://supervisor/core --env HOMEASSISTANT_TOKEN=\$SUPERVISOR_TOKEN -- uvx ha-mcp@latest"
    fi
}

# Run setup if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    configure_ha_mcp_server
fi
