#!/bin/bash

# claude-login-url — extract the most recent OAuth login URL from the Claude
# tmux session and save it to /config, where it can be opened via the Home
# Assistant File Editor or Samba and copied without going through the
# terminal clipboard at all.
#
# Why: the browser terminal's OSC 52 clipboard path truncates long payloads
# (~400 chars), and Claude Code's login URL is ~450+ chars — the tail (the
# `state` parameter) gets cut off, which makes authorization fail with
# "Invalid request format". capture-pane with -J joins soft-wrapped lines,
# so the URL comes out intact regardless of terminal width.

OUT="${1:-/config/claude-login-url.txt}"

url=$(tmux capture-pane -p -J -t claude -S -500 2>/dev/null \
    | grep -oE "https://(claude\.(com|ai)|console\.anthropic\.com|platform\.claude\.com)[^[:space:]\"'\`)<>]*" \
    | tail -1)

if [ -z "$url" ]; then
    echo "No login URL found in the Claude session." >&2
    echo "Start the login in Claude first (run /login), then run this command again." >&2
    exit 1
fi

printf '%s\n' "$url" > "$OUT"
chmod 600 "$OUT"

echo "Login URL saved to: $OUT"
echo "Open it with the Home Assistant File Editor (or over Samba), copy the"
echo "whole line into your browser, and authorize. Delete the file afterwards."
