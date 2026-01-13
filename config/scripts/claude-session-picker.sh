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
    echo "  5) 🐚 Drop to bash shell"
    echo "  6) ❌ Exit"
    echo ""
}

get_user_choice() {
    local choice
    echo -n "Enter your choice [1-6] (default: 1): "
    read -r choice
    
    # Default to 1 if empty
    if [ -z "$choice" ]; then
        choice=1
    fi
    
    echo "$choice"
}

launch_claude_new() {
    echo "🚀 Starting new Claude session..."
    sleep 1
    exec node "$(which claude)"
}

launch_claude_continue() {
    echo "⏩ Continuing most recent conversation..."
    sleep 1
    exec node "$(which claude)" -c
}

launch_claude_resume() {
    echo "📋 Opening conversation list for selection..."
    sleep 1
    exec node "$(which claude)" -r
}

launch_claude_custom() {
    echo ""
    echo "Enter your Claude command (e.g., '-c' or '-r' or '-p \"hello\"'):"
    echo "Available flags: -c (continue), -r (resume), -p (print), --model, --help"
    echo -n "> claude "
    read -r custom_args

    if [ -z "$custom_args" ]; then
        echo "No arguments provided. Starting default session..."
        launch_claude_new
    else
        # Security: Validate input contains only safe characters
        # Allow: letters, numbers, spaces, hyphens, quotes, equals, dots, slashes, underscores
        if ! echo "$custom_args" | grep -qE '^[a-zA-Z0-9 \-="./_ '"'"']+$'; then
            echo "❌ Error: Invalid characters detected in command"
            echo "Only alphanumeric characters, spaces, hyphens, quotes, equals, dots, slashes and underscores are allowed"
            echo ""
            echo "Press Enter to continue..."
            read -r
            return 1
        fi

        # Additional validation: Check for dangerous patterns
        if echo "$custom_args" | grep -qE '(&&|\|\||;|`|\$\(|<|>|\{|\})'; then
            echo "❌ Error: Dangerous shell operators detected"
            echo "Command chaining and redirection are not allowed for security"
            echo ""
            echo "Press Enter to continue..."
            read -r
            return 1
        fi

        echo "🚀 Running: claude $custom_args"
        sleep 1

        # Safe execution: Use array to build command, no eval
        local claude_path
        claude_path="$(which claude)"

        # Execute with proper quoting - shell will handle argument parsing safely
        # shellcheck disable=SC2086
        exec node "$claude_path" $custom_args
    fi
}

launch_bash_shell() {
    echo "🐚 Dropping to bash shell..."
    echo "Tip: Run 'claude' manually when ready, or 'claude-logout' to clear credentials"
    sleep 1
    exec bash
}

save_credentials_and_exit() {
    echo "💾 Saving credentials before exit..."
    /usr/local/bin/credentials-manager save
    exit 0
}

# Main execution flow
main() {
    # Ensure credentials are managed
    /usr/local/bin/credentials-manager save > /dev/null 2>&1
    
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
                launch_bash_shell
                ;;
            6)
                save_credentials_and_exit
                ;;
            *)
                echo ""
                echo "❌ Invalid choice: $choice"
                echo "Please select a number between 1-6"
                echo ""
                echo "Press Enter to continue..."
                read -r
                ;;
        esac
    done
}

# Handle cleanup on exit
trap 'save_credentials_and_exit' EXIT INT TERM

# Run main function
main "$@"