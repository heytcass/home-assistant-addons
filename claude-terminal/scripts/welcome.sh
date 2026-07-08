#!/bin/bash

# Claude Terminal banner — compact, non-blocking header with version and tips.
# With --shell, drops into an interactive bash afterwards (shell mode).
# Runs inside ttyd/tmux (user-visible) — plain bash, no bashio.

TERRACOTTA='\033[38;2;217;119;87m'
WHITE='\033[1;37m'
DIM='\033[2m'
NC='\033[0m'

version=$(cat /opt/scripts/addon-version 2>/dev/null || echo "unknown")

echo ""
echo -e "  ${TERRACOTTA}Claude Terminal${NC}  ${DIM}v${version} · Home Assistant add-on${NC}"
echo ""
echo -e "  ${WHITE}claude${NC}            start Claude Code  ${DIM}(-c continue · -r resume a session)${NC}"
echo -e "  ${WHITE}claude-doctor${NC}     diagnose network, auth, and environment issues"
echo -e "  ${WHITE}persist-install${NC}   install apk/pip packages that survive restarts"
echo -e "  ${WHITE}ha-context${NC}        refresh the Home Assistant context file for Claude"
echo ""

if [ "$1" = "--shell" ]; then
    exec bash
fi
