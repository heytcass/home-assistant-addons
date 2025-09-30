#!/usr/bin/with-contenv bashio

# Home Assistant API Examples for Claude Terminal
# This script demonstrates how to interact with Home Assistant APIs

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          Home Assistant API Examples for Claude             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Get the Supervisor token (automatically available in add-ons)
SUPERVISOR_TOKEN="${SUPERVISOR_TOKEN}"
if [ -z "$SUPERVISOR_TOKEN" ]; then
    echo -e "${RED}Error: Supervisor token not found${NC}"
    echo "This script must be run from within a Home Assistant add-on"
    exit 1
fi

echo -e "${GREEN}✓ Supervisor token available${NC}"
echo ""

# Function to make API calls
api_call() {
    local endpoint=$1
    local method=${2:-GET}
    local data=${3:-}

    if [ "$method" = "GET" ]; then
        curl -s -X GET \
            -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
            -H "Content-Type: application/json" \
            "http://supervisor/${endpoint}"
    else
        curl -s -X "$method" \
            -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
            -H "Content-Type: application/json" \
            -d "$data" \
            "http://supervisor/${endpoint}"
    fi
}

# Example 1: Get add-on info
echo "1. Getting current add-on information:"
echo "   Endpoint: /addons/self/info"
echo ""
api_call "addons/self/info" | jq '.data | {name, version, state}'
echo ""

# Example 2: Get Home Assistant info
echo "2. Getting Home Assistant information:"
echo "   Endpoint: /core/info"
echo ""
api_call "core/info" | jq '.data | {version, machine, operating_system}'
echo ""

# Example 3: List all add-ons
echo "3. Listing installed add-ons:"
echo "   Endpoint: /addons"
echo ""
api_call "addons" | jq '.data.addons[] | {name, slug, version, state}'
echo ""

# Example 4: Get network info
echo "4. Getting network information:"
echo "   Endpoint: /network/info"
echo ""
api_call "network/info" | jq '.data.interfaces[0] | {interface, ip_address: .ipv4.address}'
echo ""

# Example 5: Home Assistant API (entities)
echo "5. Getting Home Assistant entities (via WebSocket):"
echo "   Note: For full entity access, use the WebSocket API"
echo ""

# Function to call Home Assistant API
ha_api_call() {
    local endpoint=$1
    curl -s -X GET \
        -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
        -H "Content-Type: application/json" \
        "http://supervisor/core/api/${endpoint}"
}

echo "   Getting system health:"
ha_api_call "system_health/info" | jq '.'
echo ""

# Example usage in scripts
echo "════════════════════════════════════════════════════════════════"
echo "Usage in your scripts:"
echo ""
echo -e "${YELLOW}# Get add-on configuration:${NC}"
echo 'CONFIG=$(bashio::config)'
echo ""
echo -e "${YELLOW}# Get specific config value:${NC}"
echo 'AUTO_LAUNCH=$(bashio::config "auto_launch_claude")'
echo ""
echo -e "${YELLOW}# Call Supervisor API:${NC}"
echo 'curl -H "Authorization: Bearer $SUPERVISOR_TOKEN" http://supervisor/core/info'
echo ""
echo -e "${YELLOW}# Use bashio for logging:${NC}"
echo 'bashio::log.info "Message"'
echo 'bashio::log.error "Error message"'
echo ""

# WebSocket example (requires additional setup)
echo "════════════════════════════════════════════════════════════════"
echo "For advanced Home Assistant integration (entities, automations):"
echo ""
echo "1. Use the WebSocket API for real-time entity access"
echo "2. Install 'websocat' or use Node.js WebSocket libraries"
echo "3. Connect to: ws://supervisor/core/websocket"
echo ""
echo "Example WebSocket authentication flow:"
echo '{'
echo '  "type": "auth",'
echo '  "access_token": "YOUR_SUPERVISOR_TOKEN"'
echo '}'
echo ""

# Python example for entity control
echo "════════════════════════════════════════════════════════════════"
echo "Python script example for entity control:"
echo ""
cat << 'EOF'
#!/usr/bin/env python3
import os
import requests
import json

# Get token from environment
token = os.environ.get('SUPERVISOR_TOKEN')
base_url = 'http://supervisor/core/api'

headers = {
    'Authorization': f'Bearer {token}',
    'Content-Type': 'application/json'
}

# Get all entities
response = requests.get(f'{base_url}/states', headers=headers)
entities = response.json()

# Turn on a light
data = {'entity_id': 'light.living_room'}
requests.post(f'{base_url}/services/light/turn_on', headers=headers, json=data)

# Set climate temperature
data = {
    'entity_id': 'climate.thermostat',
    'temperature': 22
}
requests.post(f'{base_url}/services/climate/set_temperature', headers=headers, json=data)
EOF

echo ""
echo "════════════════════════════════════════════════════════════════"
echo -e "${GREEN}✓ API access is now enabled for this add-on!${NC}"
echo ""
echo "The SUPERVISOR_TOKEN environment variable provides access to:"
echo "• Supervisor API (/addons, /core, /host, /network, etc.)"
echo "• Home Assistant API (/api/states, /api/services, etc.)"
echo "• WebSocket API (for real-time updates)"
echo ""