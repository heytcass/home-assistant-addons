#!/bin/bash

# tmux-status.sh — lightweight status bar data for Claude Terminal
# Called by tmux every status-interval seconds. Must be fast (<1s).

# --- Auth status ---
auth_status() {
    local config_dir="${ANTHROPIC_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/claude}"

    # Current Claude Code stores OAuth credentials in ~/.claude; older
    # versions used the config dir. A file with an expired token shows
    # orange, not green — existence alone doesn't mean logged in.
    local cred
    for cred in "$HOME/.claude/.credentials.json" \
                "$config_dir/.credentials.json" "$config_dir/credentials.json"; do
        [ -f "$cred" ] || continue
        local expires_at
        expires_at=$(jq -r '.claudeAiOauth.expiresAt // empty' "$cred" 2>/dev/null)
        if [ -n "$expires_at" ] && [ "$expires_at" -lt "$(( $(date +%s) * 1000 ))" ] 2>/dev/null; then
            echo "#[fg=colour208]Auth"
        else
            echo "#[fg=colour114]Auth"
        fi
        return
    done

    if [ -f "$config_dir/settings.json" ] && \
       grep -q '"apiKey"\|"oauthToken"\|"sessionKey"' "$config_dir/settings.json" 2>/dev/null; then
        echo "#[fg=colour114]Auth"
    else
        echo "#[fg=colour203]Auth"
    fi
}

# --- HA connection status ---
ha_status() {
    if [ -z "$SUPERVISOR_TOKEN" ]; then
        echo "#[fg=colour245]HA"
        return
    fi

    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" -m 2 \
        -H "Authorization: Bearer $SUPERVISOR_TOKEN" \
        "http://supervisor/core/api/" 2>/dev/null)

    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
        echo "#[fg=colour114]HA"
    else
        echo "#[fg=colour208]HA"
    fi
}

# --- Build output ---
auth=$(auth_status)
ha=$(ha_status)
datetime=$(date '+%a %m-%d %H:%M')

echo "${auth} #[fg=colour245]| ${ha} #[fg=colour245]| #[fg=colour252]${datetime}"
