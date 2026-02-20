#!/bin/bash

# Claude Session Picker - Interactive menu for choosing Claude session type
# Provides options for new session, continue, resume, manual command, or regular shell
# Now with tmux session persistence for reconnection on navigation

TMUX_SESSION_NAME="claude"

show_banner() {
    clear
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    🤖 Claude Terminal                        ║"
    echo "║                   Interactive Session Picker                ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
}

# Check if a tmux session exists and is running
check_existing_session() {
    tmux has-session -t "$TMUX_SESSION_NAME" 2>/dev/null
}

show_menu() {
    echo "Choose your Claude session type:"
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
    echo "  ─────────────────────────────────────"
    if is_yolo_enabled; then
        echo "  8) ☢️  Dangerous Mode (YOLO - skip all permissions)"
    fi
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
    exec tmux new-session -s "$TMUX_SESSION_NAME" 'claude'
}

launch_claude_continue() {
    echo "⏩ Continuing most recent conversation..."

    if check_existing_session; then
        tmux kill-session -t "$TMUX_SESSION_NAME" 2>/dev/null
    fi

    sleep 1
    exec tmux new-session -s "$TMUX_SESSION_NAME" 'claude -c'
}

launch_claude_resume() {
    echo "📋 Opening conversation list for selection..."

    if check_existing_session; then
        tmux kill-session -t "$TMUX_SESSION_NAME" 2>/dev/null
    fi

    sleep 1
    exec tmux new-session -s "$TMUX_SESSION_NAME" 'claude -r'
}

launch_claude_custom() {
    echo ""
    echo "Enter your Claude command (e.g., 'claude --help' or 'claude -p \"hello\"'):"
    echo "Available flags: -c (continue), -r (resume), -p (print), --model, etc."
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

launch_claude_yolo() {
    # Pre-flight check: verify Claude binary is available before showing prompts
    if ! command -v claude >/dev/null 2>&1; then
        echo "YOLO Mode: Claude binary not found" >&2
        clear
        echo "❌ Error: Claude binary not found"
        echo ""
        echo "The Claude CLI is not installed or not in your PATH."
        echo ""
        echo "Try running option 5 (Authentication helper) to set up Claude."
        echo ""
        printf "Press Enter to return to menu..." >&2
        read -r
        return
    fi

    clear
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║               ☢️  DANGEROUS MODE WARNING (YOLO) ☢️            ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    if ! is_yolo_enabled; then
        echo "❌ YOLO mode is disabled by default for safety"
        echo ""
        echo "To enable it explicitly, set: ALLOW_YOLO_MODE=1"
        echo "(e.g. in add-on configuration/environment)"
        echo ""
        printf "Press Enter to return to menu..." >&2
        read -r
        return
    fi

    echo "You are about to launch Claude with --dangerously-skip-permissions"
    echo ""
    echo "⚠️  THIS IS EXTREMELY DANGEROUS! ⚠️"
    echo ""
    echo "Dangerous (YOLO) mode allows Claude to:"
    echo "  • DELETE your Home Assistant configuration"
    echo "  • EXPOSE credentials, API keys, and tokens"
    echo "  • MODIFY or DELETE automations without asking"
    echo "  • EXECUTE destructive system commands"
    echo "  • ACCESS and TRANSMIT sensitive data"
    echo ""
    echo "🚨 ONLY use this in isolated test environments!"
    echo "🚨 NEVER use this on production Home Assistant!"
    echo ""
    printf "Type 'YOLO' to confirm (or anything else to cancel): "
    read -r confirmation

    if [ "$confirmation" != "YOLO" ]; then
        echo ""
        echo "❌ YOLO Mode cancelled. Returning to main menu..."
        sleep 2
        return
    fi

    echo ""
    echo "✅ YOLO Mode confirmed!"
    echo ""
    echo "Select session type for YOLO Mode:"
    echo "  1) 🆕 New session"
    echo "  2) ⏩ Continue most recent conversation"
    echo "  3) 📋 Resume from conversation list"
    echo ""
    printf "Enter your choice [1-3] (default: 1): "
    read -r yolo_choice

    # Default to 1 if empty
    if [ -z "$yolo_choice" ]; then
        yolo_choice=1
    fi

    # Validate choice - return to main menu on invalid input to ensure users
    # get exactly the session type they requested rather than silently defaulting.
    if [ "$yolo_choice" != "1" ] && [ "$yolo_choice" != "2" ] && [ "$yolo_choice" != "3" ]; then
        echo "YOLO Mode: Invalid session type choice: '$yolo_choice' (expected 1-3)" >&2
        echo ""
        echo "❌ Invalid choice: '$yolo_choice'"
        echo "   Valid options are 1 (New), 2 (Continue), or 3 (Resume)"
        echo ""
        printf "Press Enter to return to menu..." >&2
        read -r
        return
    fi

    # Launch Claude with IS_SANDBOX scoped to the command (not exported globally).
    # exec replaces this process; if exec fails, the lines after it run as a fallback.
    case "$yolo_choice" in
        1)
            echo "🚀 Starting new YOLO session..."
            sleep 1
            IS_SANDBOX=1 exec claude --dangerously-skip-permissions
            ;;
        2)
            echo "⏩ Continuing most recent conversation in YOLO mode..."
            sleep 1
            IS_SANDBOX=1 exec claude -c --dangerously-skip-permissions
            ;;
        3)
            echo "📋 Opening conversation list for YOLO mode..."
            sleep 1
            IS_SANDBOX=1 exec claude -r --dangerously-skip-permissions
            ;;
    esac

    # If we reach here, exec failed
    echo "YOLO Mode: Failed to launch Claude" >&2
    echo ""
    echo "❌ Failed to launch Claude. Check that the CLI is installed correctly."
    echo ""
    printf "Press Enter to return to menu..." >&2
    read -r
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
            8)
                if is_yolo_enabled; then
                    launch_claude_yolo
                else
                    echo ""
                    echo "❌ Dangerous mode is disabled (set ALLOW_YOLO_MODE=1 to enable)."
                    echo ""
                    printf "Press Enter to continue..." >&2
                    read -r
                fi
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