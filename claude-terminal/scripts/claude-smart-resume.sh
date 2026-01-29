#!/bin/bash

# Smart Resume Script for Claude Code
# Attempts to resume most recent session, but falls back to new session if none exists

# Function to check if Claude has any sessions to resume
has_claude_sessions() {
    local claude_home="${HOME}/.claude"
    local claude_config_dir="${ANTHROPIC_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/claude}"

    # Check for project directory in current working directory
    # This is where Claude Code stores project-specific session data
    if [ -d ".claude" ] && [ -n "$(ls -A .claude 2>/dev/null)" ]; then
        return 0  # Has local project sessions
    fi

    # Check for Claude home directory with projects
    if [ -d "$claude_home/projects" ] && [ -n "$(ls -A "$claude_home/projects" 2>/dev/null)" ]; then
        return 0  # Has project data
    fi

    # Check for any session data in Claude home
    if [ -d "$claude_home" ]; then
        # Look for any JSON files that might contain session data
        if find "$claude_home" -maxdepth 2 -type f \( -name "*.json" -o -name "*.jsonl" \) 2>/dev/null | grep -q .; then
            return 0  # Has session data
        fi
    fi

    # Check for data in config directory
    if [ -d "$claude_config_dir" ] && [ -n "$(ls -A "$claude_config_dir" 2>/dev/null)" ]; then
        # Look for project or session related files
        if find "$claude_config_dir" -maxdepth 2 -type f \( -name "*.json" -o -name "*.jsonl" \) 2>/dev/null | grep -q .; then
            return 0  # Has config data that might include sessions
        fi
    fi

    return 1  # No sessions found
}

# Main logic
main() {
    # Check if claude is available
    if ! command -v claude &> /dev/null; then
        echo "❌ Error: Claude Code CLI not found"
        echo "Please ensure Claude Code is properly installed"
        exit 1
    fi

    # Try to detect if there are existing sessions
    if has_claude_sessions; then
        echo "⏩ Resuming most recent Claude session..."
        exec claude -c
    else
        echo "🆕 No existing sessions found. Starting new Claude session..."
        exec claude
    fi
}

# Run main function
main "$@"
