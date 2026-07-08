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
        return 0
    fi

    # Check if uv/uvx is available
    if ! command -v uvx &> /dev/null; then
        bashio::log.warning "uvx not found - ha-mcp setup skipped"
        return 0
    fi

    local version
    version=$(bashio::config 'ha_mcp_version' '7.11.0')

    # Remove existing ha-mcp configuration if present (to ensure clean state)
    claude mcp remove home-assistant 2>/dev/null || true

    # ha-mcp >= 4.x requires CPython 3.13 exactly, which no Alpine release
    # ships — uv provisions a managed musl 3.13 build (persisted under /data
    # via XDG_DATA_HOME, so it downloads once).
    # --index-strategy unsafe-best-match: the HA wheels index doesn't carry
    # every version, so let uv consider all indexes (#77/#79)
    if claude mcp add home-assistant \
        --env "HOMEASSISTANT_URL=http://supervisor/core" \
        --env "HOMEASSISTANT_TOKEN=${SUPERVISOR_TOKEN}" \
        -- uvx --python 3.13 --index-strategy unsafe-best-match "ha-mcp@${version}"; then
        bashio::log.info "ha-mcp ${version} configured for Claude Code"

        # Pre-warm the uv environment in the background (managed Python
        # download + dependency resolution) so the first MCP connection
        # doesn't hit the client startup timeout
        (uvx --python 3.13 --index-strategy unsafe-best-match \
            --from "ha-mcp@${version}" python -c "" >/dev/null 2>&1 || true) &
        bashio::log.info "Pre-warming ha-mcp environment in background"
    else
        bashio::log.warning "Failed to configure ha-mcp - continuing without MCP integration"
        bashio::log.warning "You can manually run: claude mcp add home-assistant --env HOMEASSISTANT_URL=http://supervisor/core --env HOMEASSISTANT_TOKEN=\$SUPERVISOR_TOKEN -- uvx --python 3.13 --index-strategy unsafe-best-match ha-mcp@${version}"
    fi
}

# Run setup if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    configure_ha_mcp_server
fi
