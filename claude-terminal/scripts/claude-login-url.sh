#!/bin/bash

# claude-login-url — extract the most recent OAuth login URL from the Claude
# tmux session and save it to /config, where it can be opened via the Home
# Assistant File Editor or Samba and copied without going through the
# terminal clipboard at all.
#
# Why: the browser terminal's OSC 52 clipboard path truncates long payloads
# (~400 chars), and Claude Code's login URL is ~450+ chars — the tail (the
# `state` parameter) gets cut off, which makes authorization fail with
# "Invalid request format".
#
# Claude Code's own UI hard-wraps the URL across multiple physical lines
# (real line breaks from its own rendering, not the terminal's soft-wrap),
# so a single-line grep only ever captures the first fragment. Reassemble it
# by reading every line from the most recent "https://..." start through the
# next blank line and concatenating them — the CLI wraps mid-token with no
# separator, so lines are joined with no space between them.

OUT="${1:-/config/claude-login-url.txt}"

url=$(tmux capture-pane -p -J -t claude -S -500 2>/dev/null | awk '
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
')

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
