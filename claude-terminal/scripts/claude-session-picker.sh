#!/bin/bash

# Claude Session Picker - Interactive menu for choosing Claude session type
# Provides options for new session, continue, resume, manual command, or regular shell

show_banner() {
    clear
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    🤖 Claude Terminal                        ║"
    echo "║                   Interactive Session Picker                ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
}

show_menu() {
    echo "Choose your Claude session type:"
    echo ""
    echo "  1) 🆕 New interactive session (default)"
    echo "  2) ⏩ Continue most recent conversation (-c)"
    echo "  3) 📋 Resume from conversation list (-r)"
    echo "  4) ⚙️  Custom Claude command (manual flags)"
    echo "  5) 🔐 Authentication helper (if paste doesn't work)"
    echo "  6) 🐚 Drop to bash shell"
    echo "  7) ❌ Exit"
    echo ""
    echo "  ─────────────────────────────────────"
    echo "  8) ⚠️  YOLO Mode (skip all permissions)"
}

get_user_choice() {
    local choice
    # Send prompt to stderr to avoid capturing it with the return value
    printf "Enter your choice [1-8] (default: 1): " >&2
    read -r choice
    
    # Default to 1 if empty
    if [ -z "$choice" ]; then
        choice=1
    fi
    
    # Trim whitespace and return only the choice
    choice=$(echo "$choice" | tr -d '[:space:]')
    echo "$choice"
}

launch_claude_new() {
    echo "🚀 Starting new Claude session..."
    sleep 1
    exec claude
}

launch_claude_continue() {
    echo "⏩ Continuing most recent conversation..."
    sleep 1
    exec claude -c
}

launch_claude_resume() {
    echo "📋 Opening conversation list for selection..."
    sleep 1
    exec claude -r
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
        sleep 1
        # Use eval to properly handle quoted arguments
        eval "exec claude $custom_args"
    fi
}

launch_auth_helper() {
    echo "🔐 Starting authentication helper..."
    sleep 1
    exec /opt/scripts/claude-auth-helper.sh
}

launch_bash_shell() {
    echo "🐚 Dropping to bash shell..."
    echo "Tip: Run 'claude' manually when ready"
    sleep 1
    exec bash
}

exit_session_picker() {
    echo "👋 Goodbye!"
    exit 0
}

launch_claude_yolo() {
    clear
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    ⚠️  YOLO MODE WARNING ⚠️                    ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "You are about to launch Claude with --dangerously-skip-permissions"
    echo ""
    echo "This mode will:"
    echo "  • Skip ALL permission prompts automatically"
    echo "  • Allow Claude to execute ANY command without confirmation"
    echo "  • Allow Claude to read/write ANY file without asking"
    echo "  • Allow Claude to make network requests freely"
    echo ""
    echo "⚠️  THIS IS DANGEROUS! Only use if you understand the risks."
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

    # Set sandbox environment variable
    export IS_SANDBOX=1

    case "$yolo_choice" in
        1)
            echo "🚀 Starting new YOLO session..."
            sleep 1
            exec claude --dangerously-skip-permissions
            ;;
        2)
            echo "⏩ Continuing most recent conversation in YOLO mode..."
            sleep 1
            exec claude -c --dangerously-skip-permissions
            ;;
        3)
            echo "📋 Opening conversation list for YOLO mode..."
            sleep 1
            exec claude -r --dangerously-skip-permissions
            ;;
        *)
            echo "❌ Invalid choice. Starting new YOLO session..."
            sleep 1
            exec claude --dangerously-skip-permissions
            ;;
    esac
}

# Main execution flow
main() {
    while true; do
        show_banner
        show_menu
        choice=$(get_user_choice)
        
        case "$choice" in
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
                launch_claude_yolo
                ;;
            *)
                echo ""
                echo "❌ Invalid choice: '$choice'"
                echo "Please select a number between 1-8"
                echo ""
                printf "Press Enter to continue..." >&2
                read -r
                ;;
        esac
    done
}

# Handle cleanup on exit
trap 'exit_session_picker' EXIT INT TERM

# Run main function
main "$@"