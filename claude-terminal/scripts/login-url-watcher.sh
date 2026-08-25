#!/bin/bash

# login-url-watcher — background loop that detects Claude Code's OAuth login
# URL and delivers it as a clickable Home Assistant persistent notification.
#
# Why: the browser terminal's "c to copy" never reliably reaches the OS
# clipboard. Claude Code emits the OSC 52 copy escape sequence twice per
# keypress; tmux's relay of both copies races the browser's async Clipboard
# API, and the write silently never completes. That's true even with tmux
# and the browser fully correctly configured — see claude-login-url.sh for
# the SSH-based fallback this reuses the same extraction logic from. Rather
# than depend on SSH being enabled, this watches for the URL automatically
# and surfaces it in the HA UI directly, with no manual steps.
#
# Runs as a background loop for the life of the container (started once from
# run.sh); cheap when idle since it only polls a local tmux pane.

NOTIFICATION_ID="claude_login_url"
POLL_INTERVAL=3

extract_url() {
    tmux capture-pane -p -J -t claude -S -500 2>/dev/null | awk '
        /^https:\/\/(claude\.(com|ai)|console\.anthropic\.com|platform\.claude\.com)/ {
            url = $0
            collecting = 1
            next
        }
        collecting {
            if (NF == 0) { collecting = 0 }
            else { url = url $0 }
        }
        END { print url }
    '
}

is_logged_in() {
    local cred="$HOME/.claude/.credentials.json"
    [ -f "$cred" ] || return 1
    local expires_at
    expires_at=$(jq -r '.claudeAiOauth.expiresAt // empty' "$cred" 2>/dev/null)
    [ -n "$expires_at" ] && [ "$expires_at" -gt "$(($(date +%s) * 1000))" ] 2>/dev/null
}

notify() {
    local url="$1"
    curl -s -X POST \
        -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "$(jq -n --arg msg "[Click here to authorize Claude Code]($url)

If it doesn't open the right app, copy this link instead:
$url" --arg id "$NOTIFICATION_ID" \
            '{title: "Claude Code login", message: $msg, notification_id: $id}')" \
        http://supervisor/core/api/services/persistent_notification/create >/dev/null 2>&1
}

dismiss() {
    curl -s -X POST \
        -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "$(jq -n --arg id "$NOTIFICATION_ID" '{notification_id: $id}')" \
        http://supervisor/core/api/services/persistent_notification/dismiss >/dev/null 2>&1
}

last_url=""
notified=0

while true; do
    if tmux has-session -t claude 2>/dev/null; then
        if is_logged_in; then
            if [ "$notified" = "1" ]; then
                dismiss
                notified=0
                last_url=""
            fi
        else
            url=$(extract_url)
            if [ -n "$url" ] && [ "$url" != "$last_url" ]; then
                notify "$url"
                last_url="$url"
                notified=1
            fi
        fi
    fi
    sleep "$POLL_INTERVAL"
done
