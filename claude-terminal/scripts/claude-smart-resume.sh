#!/bin/bash

# Smart Resume Script for Claude Code
# Attempts to resume most recent session, but falls back to new session if none exists

# Function to check if Claude has any sessions to resume
has_claude_sessions() {
    local claude_config_dir="${ANTHROPIC_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/claude}"
    local claude_state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/claude"

    # Check for conversation history in common locations
    # Claude Code typically stores session data in state or config directories
    if [ -d "$claude_state_dir" ] && [ -n "$(find "$claude_state_dir" -type f -name "*.json" 2>/dev/null | head -1)" ]; then
        return 0  # Has sessions
    fi

    if [ -d "$claude_config_dir" ] && [ -n "$(find "$claude_config_dir" -type f -name "*conversation*" -o -name "*session*" 2>/dev/null | head -1)" ]; then
        return 0  # Has sessions
    fi

    # Check for recent conversations list
    if [ -f "$claude_state_dir/conversations.json" ] || [ -f "$claude_config_dir/conversations.json" ]; then
        # Check if file has content (not empty or just {})
        if [ -s "$claude_state_dir/conversations.json" ] || [ -s "$claude_config_dir/conversations.json" ]; then
            return 0  # Has sessions
        fi
    fi

    return 1  # No sessions found
}

# Main logic
main() {
    local claude_path
    claude_path="$(which claude)"

    if [ -z "$claude_path" ]; then
        echo "❌ Error: Claude Code CLI not found"
        echo "Please ensure Claude Code is properly installed"
        exit 1
    fi

    # Try to detect if there are existing sessions
    if has_claude_sessions; then
        echo "⏩ Resuming most recent Claude session..."
        exec node "$claude_path" -c
    else
        echo "🆕 No existing sessions found. Starting new Claude session..."
        exec node "$claude_path"
    fi
}

# Run main function
main "$@"
