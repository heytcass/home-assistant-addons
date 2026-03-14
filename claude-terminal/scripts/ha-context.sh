#!/bin/bash

# HA Smart Context — generates a CLAUDE.md with Home Assistant context
# Claude Code auto-loads CLAUDE.md from HOME, giving every session HA awareness
#
# Usage:
#   ha-context          Generate medium-detail context (default)
#   ha-context --full   Include entity ID listings per domain
#   ha-context --help   Show usage

SUPERVISOR_URL="http://supervisor"
OUTPUT_FILE="${HOME}/CLAUDE.md"
FULL_MODE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --full)
            FULL_MODE=true
            shift
            ;;
        --output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --help)
            echo "Usage: ha-context [OPTIONS]"
            echo ""
            echo "Generate Home Assistant context for Claude Code sessions."
            echo "Writes a CLAUDE.md file that Claude automatically loads."
            echo ""
            echo "Options:"
            echo "  --full       Include entity ID listings (detailed mode)"
            echo "  --output F   Write to file F instead of \$HOME/CLAUDE.md"
            echo "  --help       Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Run 'ha-context --help' for usage" >&2
            exit 1
            ;;
    esac
done

# --- API helpers ---

api_call() {
    local endpoint="$1"
    curl -s -m 10 \
        -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
        -H "Content-Type: application/json" \
        "${SUPERVISOR_URL}/${endpoint}" 2>/dev/null
}

ha_api_call() {
    local endpoint="$1"
    api_call "core/api/${endpoint}"
}

check_prerequisites() {
    if [ -z "$SUPERVISOR_TOKEN" ]; then
        echo "Error: SUPERVISOR_TOKEN not set. This script must run inside a Home Assistant add-on." >&2
        exit 1
    fi

    for cmd in curl jq; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "Error: '$cmd' is required but not installed." >&2
            exit 1
        fi
    done
}

# --- Section generators ---
# Each function outputs markdown to stdout. Failures produce fallback text.

section_system_info() {
    local core_info ha_config host_info

    core_info=$(api_call "core/info")
    host_info=$(api_call "host/info")
    ha_config=$(ha_api_call "config")

    local ha_version machine ha_os
    ha_version=$(echo "$core_info" | jq -r '.data.version // empty' 2>/dev/null)
    machine=$(echo "$core_info" | jq -r '.data.machine // empty' 2>/dev/null)
    ha_os=$(echo "$host_info" | jq -r '.data.operating_system // empty' 2>/dev/null)

    local hostname timezone location_name
    hostname=$(echo "$host_info" | jq -r '.data.hostname // empty' 2>/dev/null)
    timezone=$(echo "$ha_config" | jq -r '.time_zone // empty' 2>/dev/null)
    location_name=$(echo "$ha_config" | jq -r '.location_name // empty' 2>/dev/null)

    if [ -z "$ha_version" ]; then
        echo "Unable to retrieve system information."
        return
    fi

    echo "- **Home Assistant**: ${ha_version}"
    [ -n "$machine" ] && echo "- **Machine**: ${machine}"
    [ -n "$ha_os" ] && echo "- **OS**: ${ha_os}"
    [ -n "$hostname" ] && echo "- **Hostname**: ${hostname}"
    [ -n "$location_name" ] && echo "- **Location**: ${location_name}"
    [ -n "$timezone" ] && echo "- **Timezone**: ${timezone}"
}

section_entity_summary() {
    local states
    states=$(ha_api_call "states")

    if [ -z "$states" ] || ! echo "$states" | jq -e '.' >/dev/null 2>&1; then
        echo "Unable to retrieve entity states."
        return
    fi

    local total
    total=$(echo "$states" | jq 'length')

    # Count by domain
    local summary
    summary=$(echo "$states" | jq -r '
        [.[].entity_id | split(".")[0]] | group_by(.) |
        map({domain: .[0], count: length}) |
        sort_by(-.count) |
        .[] | "| \(.domain) | \(.count) |"
    ' 2>/dev/null)

    if [ -z "$summary" ]; then
        echo "0 entities found."
        return
    fi

    echo "| Domain | Count |"
    echo "|--------|-------|"
    echo "$summary"
    echo ""
    echo "**Total: ${total} entities**"

    # Full mode: list entity IDs per domain
    if [ "$FULL_MODE" = true ]; then
        echo ""
        echo "### Entity Details"
        echo ""

        local domains
        domains=$(echo "$states" | jq -r '
            [.[].entity_id | split(".")[0]] | unique | sort | .[]
        ' 2>/dev/null)

        for domain in $domains; do
            local entities count
            entities=$(echo "$states" | jq -r --arg d "$domain" '
                [.[] | select(.entity_id | startswith($d + ".")) | .entity_id] | sort | .[]
            ' 2>/dev/null)
            count=$(echo "$entities" | wc -l)

            echo "**${domain}** (${count}):"

            # Cap at 10 per domain
            local shown=0
            while IFS= read -r entity_id; do
                [ -z "$entity_id" ] && continue
                echo "- \`${entity_id}\`"
                shown=$((shown + 1))
                if [ "$shown" -ge 10 ] && [ "$count" -gt 10 ]; then
                    local remaining=$((count - 10))
                    echo "- *...and ${remaining} more*"
                    break
                fi
            done <<< "$entities"
            echo ""
        done
    fi
}

section_addons() {
    local addons_data
    addons_data=$(api_call "addons")

    if [ -z "$addons_data" ] || ! echo "$addons_data" | jq -e '.data.addons' >/dev/null 2>&1; then
        echo "Unable to retrieve add-on information."
        return
    fi

    echo "$addons_data" | jq -r '
        .data.addons[] |
        select(.installed == true) |
        "- \(.name) v\(.version) (\(.state))"
    ' 2>/dev/null | sort
}

section_recent_errors() {
    local error_log
    error_log=$(ha_api_call "error_log")

    if [ -z "$error_log" ] || [ "$error_log" = "\"\"" ]; then
        echo "No recent errors."
        return
    fi

    # Take last 20 lines, truncate long lines
    echo '```'
    echo "$error_log" | tail -20 | cut -c1-200
    echo '```'
}

# --- Main generation ---

generate_claude_md() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    local tmp_file
    tmp_file=$(mktemp "${OUTPUT_FILE}.XXXXXX")

    cat > "$tmp_file" << HEADER
# Home Assistant Context

> Auto-generated by Claude Terminal add-on. Run \`ha-context\` to refresh.
> Last updated: ${timestamp}

## System

HEADER

    section_system_info >> "$tmp_file"

    cat >> "$tmp_file" << 'DIVIDER'

## Entities

DIVIDER

    section_entity_summary >> "$tmp_file"

    cat >> "$tmp_file" << 'DIVIDER'

## Installed Add-ons

DIVIDER

    section_addons >> "$tmp_file"

    cat >> "$tmp_file" << 'DIVIDER'

## Recent Errors

DIVIDER

    section_recent_errors >> "$tmp_file"

    cat >> "$tmp_file" << 'APIREF'

## API Access

You have full access to the Home Assistant APIs from this terminal:

```bash
# Supervisor API
curl -H "Authorization: Bearer $SUPERVISOR_TOKEN" http://supervisor/core/info

# Entity states
curl -H "Authorization: Bearer $SUPERVISOR_TOKEN" http://supervisor/core/api/states

# Call a service
curl -X POST -H "Authorization: Bearer $SUPERVISOR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"entity_id": "light.living_room"}' \
  http://supervisor/core/api/services/light/turn_on
```

Available endpoints: `states`, `services`, `config`, `events`, `error_log`, `history/period`
APIREF

    # Atomic move
    chmod 644 "$tmp_file"
    mv "$tmp_file" "$OUTPUT_FILE"
}

main() {
    check_prerequisites

    echo "Generating Home Assistant context..." >&2

    generate_claude_md

    local detail="medium"
    [ "$FULL_MODE" = true ] && detail="full"

    echo "HA context (${detail}) written to ${OUTPUT_FILE}" >&2
}

main "$@"
