#!/bin/bash

# Claude Authentication Helper
# Provides alternative authentication methods when clipboard paste doesn't work

show_auth_menu() {
    clear
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║               🔐 Claude Authentication Helper                 ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Having trouble pasting the authentication code?"
    echo ""
    echo "Options:"
    echo "  1) 📋 Manual input (type or paste the code)"
    echo "  2) 📁 Read code from file (/config/auth-code.txt)"
    echo "  3) 🔄 Retry standard authentication"
    echo "  4) ❌ Exit"
    echo ""
}

manual_auth_input() {
    echo ""
    echo "Please enter your authentication code:"
    echo "(You can try pasting with Ctrl+Shift+V, right-click, or type manually)"
    echo ""
    echo -n "Code: "
    read -r auth_code

    if [ -z "$auth_code" ]; then
        echo "❌ No code provided"
        return 1
    fi

    # Validate auth code format (alphanumeric and common special chars only)
    if ! echo "$auth_code" | grep -qE '^[a-zA-Z0-9_\-]+$'; then
        echo "❌ Invalid authentication code format"
        echo "Code should contain only alphanumeric characters, hyphens, and underscores"
        return 1
    fi

    # Save to temp file with secure permissions
    local temp_file="/tmp/claude-auth-code-$$"
    (umask 077 && echo "$auth_code" > "$temp_file")
    echo ""
    echo "✅ Code saved. Starting Claude authentication..."
    sleep 1

    # Try to pipe the code to Claude
    echo "$auth_code" | node "$(which claude)"

    # Clean up temp file
    rm -f "$temp_file"
}

read_auth_from_file() {
    local auth_file="/config/auth-code.txt"

    echo ""
    echo "Looking for authentication code in: $auth_file"

    # Security check: ensure it's a regular file, not a symlink
    if [ -L "$auth_file" ]; then
        echo "❌ Security error: File is a symlink"
        echo "For security reasons, symlinks are not allowed"
        return 1
    fi

    if [ -f "$auth_file" ]; then
        auth_code=$(cat "$auth_file")
        if [ -z "$auth_code" ]; then
            echo "❌ File exists but is empty"
            return 1
        fi

        # Validate auth code format
        if ! echo "$auth_code" | grep -qE '^[a-zA-Z0-9_\-]+$'; then
            echo "❌ Invalid authentication code format in file"
            echo "Code should contain only alphanumeric characters, hyphens, and underscores"
            rm -f "$auth_file"
            return 1
        fi

        echo "✅ Code found. Starting Claude authentication..."
        sleep 1

        # Try to pipe the code to Claude
        echo "$auth_code" | node "$(which claude)"

        # Securely clean up the file after use
        shred -u "$auth_file" 2>/dev/null || rm -f "$auth_file"
        echo "🧹 Cleaned up auth code file"
    else
        echo "❌ File not found: $auth_file"
        echo ""
        echo "To use this method:"
        echo "1. Create the file in Home Assistant's config directory"
        echo "2. Paste your authentication code in the file"
        echo "3. Save the file and try again"
        return 1
    fi
}

retry_standard_auth() {
    echo ""
    echo "🔄 Starting standard Claude authentication..."
    echo ""
    echo "Tips for pasting in the web terminal:"
    echo "• Try Ctrl+Shift+V"
    echo "• Try right-clicking"
    echo "• Try the browser's Edit menu > Paste"
    echo "• On mobile, long-press may show paste option"
    echo ""
    sleep 2
    exec node "$(which claude)"
}

main() {
    while true; do
        show_auth_menu

        echo -n "Enter your choice [1-4]: "
        read -r choice

        case "$choice" in
            1)
                manual_auth_input
                if [ $? -eq 0 ]; then
                    exit 0
                fi
                echo ""
                echo "Press Enter to continue..."
                read -r
                ;;
            2)
                read_auth_from_file
                if [ $? -eq 0 ]; then
                    exit 0
                fi
                echo ""
                echo "Press Enter to continue..."
                read -r
                ;;
            3)
                retry_standard_auth
                ;;
            4)
                echo "👋 Exiting..."
                exit 0
                ;;
            *)
                echo "❌ Invalid choice"
                sleep 1
                ;;
        esac
    done
}

# Run main function
main "$@"