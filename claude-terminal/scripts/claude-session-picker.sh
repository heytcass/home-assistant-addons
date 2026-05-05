#!/bin/bash

# Claude Session Picker - Interactive menu for choosing Claude session type
# Provides options for new session, continue, resume, manual command, or regular shell
# Now with tmux session persistence for reconnection on navigation

TMUX_SESSION_NAME="claude"

# CLAUDE_EXTRA_FLAGS is exported by run.sh from the add-on options
# (--dangerously-skip-permissions and/or extra_claude_flags). When set,
# it is appended to claude invocations from this picker.
CLAUDE_EXTRA_FLAGS="${CLAUDE_EXTRA_FLAGS:-}"

# Colors
TERRACOTTA='\033[38;2;217;119;87m'
WHITE='\033[1;37m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
DIM='\033[2m'
NC='\033[0m'

# True when --dangerously-skip-permissions is part of CLAUDE_EXTRA_FLAGS
dangerous_mode_active() {
    [[ "$CLAUDE_EXTRA_FLAGS" == *"--dangerously-skip-permissions"* ]]
}

show_banner() {
    clear
    echo ""
    echo -e "  ${TERRACOTTA}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "  ${TERRACOTTA}║${NC}                                                              ${TERRACOTTA}║${NC}"
    echo -e "  ${TERRACOTTA}║${NC}   ${WHITE}Claude Terminal${NC}  ${DIM}·  Session Picker${NC}                         ${TERRACOTTA}║${NC}"
    echo -e "  ${TERRACOTTA}║${NC}                                                              ${TERRACOTTA}║${NC}"
    echo -e "  ${TERRACOTTA}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Check if a tmux session exists and is running
check_existing_session() {
    tmux has-session -t "$TMUX_SESSION_NAME" 2>/dev/null
}

show_menu() {
    if dangerous_mode_active; then
        echo -e "${RED}  ┌──────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${RED}  │  ⚠  DANGEROUS MODE: --dangerously-skip-permissions ENABLED   │${NC}"
        echo -e "${RED}  │     Claude will run tools (edits, shell, devices) without    │${NC}"
        echo -e "${RED}  │     asking. Disable in add-on options if this is unintended. │${NC}"
        echo -e "${RED}  └──────────────────────────────────────────────────────────────┘${NC}"
        echo ""
    fi
    echo "Choose your Claude session type:"
    if [ -n "$CLAUDE_EXTRA_FLAGS" ]; then
        echo -e "  ${DIM}configured flags applied to options 1-3:${NC} ${YELLOW}${CLAUDE_EXTRA_FLAGS}${NC}"
    fi
    echo ""

    # Show reconnect option if session exists
    if check_existing_session; then
        echo "  0) 🔄 Reconnect to existing session (recommended)"
        echo ""
    fi

    echo "  1) 🆕 New interactive session (default)"
    echo "  2) ⏩ Continue most recent conversation (-c)"
    echo "  3) 📋 Resume from conversation list (-r)"
    echo "  4) ⚙️  Custom Claude command (manual flags)"
    echo "  5) 🔐 Authentication helper (if paste doesn't work)"
    echo "  6) 🐚 Drop to bash shell"
    echo "  7) ❌ Exit"
    echo ""
}

get_user_choice() {
    local choice
    local default="1"

    # Default to 0 (reconnect) if session exists
    if check_existing_session; then
        default="0"
    fi

    printf "Enter your choice [0-7] (default: %s): " "$default" >&2
    read -r choice
    

    # Use default if empty
    if [ -z "$choice" ]; then
        choice="$default"
    fi

    # Trim whitespace and return only the choice
    choice=$(echo "$choice" | tr -d '[:space:]')
    echo "$choice"
}

# Attach to existing tmux session
attach_existing_session() {
    echo "🔄 Reconnecting to existing Claude session..."
    sleep 1
    exec tmux attach-session -t "$TMUX_SESSION_NAME"
}

# Start claude in a new tmux session (kills existing if any)
launch_claude_new() {
    echo "🚀 Starting new Claude session..."

    # Kill existing session if present
    if check_existing_session; then
        echo "   (closing previous session)"
        tmux kill-session -t "$TMUX_SESSION_NAME" 2>/dev/null
    fi

    sleep 1
    exec tmux new-session -s "$TMUX_SESSION_NAME" "claude $CLAUDE_EXTRA_FLAGS"
}

launch_claude_continue() {
    echo "⏩ Continuing most recent conversation..."

    if check_existing_session; then
        tmux kill-session -t "$TMUX_SESSION_NAME" 2>/dev/null
    fi

    sleep 1
    exec tmux new-session -s "$TMUX_SESSION_NAME" "claude -c $CLAUDE_EXTRA_FLAGS"
}

launch_claude_resume() {
    echo "📋 Opening conversation list for selection..."

    if check_existing_session; then
        tmux kill-session -t "$TMUX_SESSION_NAME" 2>/dev/null
    fi

    sleep 1
    exec tmux new-session -s "$TMUX_SESSION_NAME" "claude -r $CLAUDE_EXTRA_FLAGS"
}

launch_claude_custom() {
    echo ""
    echo "Enter your Claude command (e.g., 'claude --help' or 'claude -p \"hello\"'):"
    echo "Available flags: -c (continue), -r (resume), -p (print), --model, etc."
    if [ -n "$CLAUDE_EXTRA_FLAGS" ]; then
        echo -e "${DIM}Note:${NC} configured ${YELLOW}${CLAUDE_EXTRA_FLAGS}${NC} ${DIM}is NOT auto-applied here — re-add it manually if you need it.${NC}"
    fi
    echo -n "> claude "
    read -r custom_args

    if [ -z "$custom_args" ]; then
        echo "No arguments provided. Starting default session..."
        launch_claude_new
    else
        echo "🚀 Running: claude $custom_args"

        if check_existing_session; then
            tmux kill-session -t "$TMUX_SESSION_NAME" 2>/dev/null
        fi

        sleep 1
        exec tmux new-session -s "$TMUX_SESSION_NAME" "claude $custom_args"
    fi
}

launch_auth_helper() {
    echo "🔐 Starting authentication helper..."
    sleep 1
    exec /opt/scripts/claude-auth-helper.sh
}

launch_bash_shell() {
    echo "🐚 Dropping to bash shell..."
    echo "Tip: Run 'tmux new-session -A -s claude \"claude\"' to start with persistence"
    sleep 1
    exec bash
}

exit_session_picker() {
    echo "👋 Goodbye!"
    exit 0
}

# Main execution flow
main() {
    while true; do
        show_banner
        show_menu
        choice=$(get_user_choice)

        case "$choice" in
            0)
                if check_existing_session; then
                    attach_existing_session
                else
                    echo "❌ No existing session found"
                    sleep 1
                fi
                ;;
            1)
                launch_claude_new
                ;;
            2)
                launch_claude_continue
                ;;
            3)
                launch_claude_resume
                ;;
            4)
                launch_claude_custom
                ;;
            5)
                launch_auth_helper
                ;;
            6)
                launch_bash_shell
                ;;
            7)
                exit_session_picker
                ;;
            *)
                echo ""
                echo "❌ Invalid choice: '$choice'"
                echo "Please select a number between 0-7"
                echo ""
                printf "Press Enter to continue..." >&2
                read -r
                ;;
        esac
    done
}

# Handle cleanup on exit - don't kill tmux session, just exit picker
trap 'echo ""; exit 0' EXIT INT TERM

# Run main function
main "$@"
