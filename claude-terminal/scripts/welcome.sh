#!/bin/bash

# Welcome banner and What's New display for Claude Terminal
# Runs inside ttyd terminal (user-visible), not in run.sh boot logs
# Uses plain bash — no bashio dependency

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
TERRACOTTA='\033[38;2;217;119;87m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

MOTD_VERSION_FILE="/data/.motd-version"
ADDON_VERSION_FILE="/opt/scripts/addon-version"

get_current_version() {
    if [ -f "$ADDON_VERSION_FILE" ]; then
        cat "$ADDON_VERSION_FILE"
    else
        echo "unknown"
    fi
}

get_last_seen_version() {
    cat "$MOTD_VERSION_FILE" 2>/dev/null || echo "none"
}

save_version() {
    echo "$1" > "$MOTD_VERSION_FILE" 2>/dev/null
}

show_welcome_banner() {
    local version="$1"
    local ver_padding
    ver_padding=$(printf '%*s' $((34 - ${#version})) '')
    echo ""
    echo -e "  ${TERRACOTTA}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "  ${TERRACOTTA}║${NC}                                                          ${TERRACOTTA}║${NC}"
    echo -e "  ${TERRACOTTA}║${NC}   ${WHITE}Claude Terminal${NC}  ${DIM}v${version}${NC}${ver_padding}${TERRACOTTA}║${NC}"
    echo -e "  ${TERRACOTTA}║${NC}   ${DIM}Home Assistant Add-on  ·  Powered by Claude Code CLI${NC}   ${TERRACOTTA}║${NC}"
    echo -e "  ${TERRACOTTA}║${NC}                                                          ${TERRACOTTA}║${NC}"
    echo -e "  ${TERRACOTTA}╚══════════════════════════════════════════════════════════╝${NC}"
}

show_whats_new() {
    local version="$1"
    local last_seen="$2"

    # Only show if version changed
    if [ "$version" = "$last_seen" ] || [ "$version" = "unknown" ]; then
        return
    fi

    echo ""
    echo -e "  ${GREEN}${BOLD}What's New in ${version}:${NC}"
    echo ""

    case "$version" in
        2.0.0)
            echo -e "  ${TERRACOTTA}*${NC} ${BOLD}HA Smart Context${NC} — Claude automatically knows your Home"
            echo -e "    Assistant setup (entities, add-ons, errors, system info)"
            echo -e "  ${TERRACOTTA}*${NC} ${BOLD}Welcome screen${NC} — version tracking and release highlights"
            echo -e "  ${TERRACOTTA}*${NC} Run ${DIM}ha-context${NC} anytime to refresh, ${DIM}ha-context --full${NC} for details"
            echo ""
            echo -e "  ${DIM}Thank you for sticking with me through the v1.6-1.9 bumps.${NC}"
            echo -e "  ${DIM}This one's for you.${NC}"
            ;;
        *)
            echo -e "  ${DIM}Upgraded to v${version}. See CHANGELOG for details.${NC}"
            ;;
    esac

    # Mark as seen
    save_version "$version"
}

main() {
    local current_version
    current_version=$(get_current_version)
    local last_seen
    last_seen=$(get_last_seen_version)

    show_welcome_banner "$current_version"
    show_whats_new "$current_version" "$last_seen"

    echo ""
    printf "  Press Enter to continue..."
    read -r
}

main "$@"
