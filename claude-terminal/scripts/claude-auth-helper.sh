#!/bin/bash

# Claude Authentication Helper
# Provides alternative authentication methods when clipboard paste doesn't work

# Security: Set up trap to clean up temporary files on exit
TEMP_AUTH_FILE=""
cleanup_temp_files() {
    if [ -n "$TEMP_AUTH_FILE" ] && [ -f "$TEMP_AUTH_FILE" ]; then
        # Secure deletion: overwrite before removing
        dd if=/dev/zero of="$TEMP_AUTH_FILE" bs=1 count=$(stat -c%s "$TEMP_AUTH_FILE" 2>/dev/null || echo 0) 2>/dev/null
        rm -f "$TEMP_AUTH_FILE"
    fi
}
trap cleanup_temp_files EXIT INT TERM

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

    # Security: Create secure temporary file with restricted permissions
    TEMP_AUTH_FILE=$(mktemp -t claude-auth.XXXXXXXXXX)
    chmod 600 "$TEMP_AUTH_FILE"

    # Save to secure temp file
    echo "$auth_code" > "$TEMP_AUTH_FILE"
    echo ""
    echo "✅ Code saved securely. Starting Claude authentication..."
    sleep 1

    # Try to pipe the code to Claude
    echo "$auth_code" | node "$(which claude)"

    # Cleanup will happen via trap handler
}

read_auth_from_file() {
    local auth_file="/config/auth-code.txt"

    echo ""
    echo "Looking for authentication code in: $auth_file"

    if [ -f "$auth_file" ]; then
        # Security: Check file permissions before reading
        local file_perms
        file_perms=$(stat -c '%a' "$auth_file" 2>/dev/null)
        if [ "$file_perms" != "600" ] && [ "$file_perms" != "400" ]; then
            echo "⚠️  Warning: Auth file has insecure permissions ($file_perms)"
            echo "Fixing permissions to 600..."
            chmod 600 "$auth_file"
        fi

        auth_code=$(cat "$auth_file")
        if [ -z "$auth_code" ]; then
            echo "❌ File exists but is empty"
            return 1
        fi

        echo "✅ Code found. Starting Claude authentication..."
        sleep 1

        # Try to pipe the code to Claude
        echo "$auth_code" | node "$(which claude)"

        # Secure cleanup: overwrite before removal
        dd if=/dev/zero of="$auth_file" bs=1 count=$(stat -c%s "$auth_file" 2>/dev/null || echo 0) 2>/dev/null
        rm -f "$auth_file"
        echo "🧹 Securely cleaned up auth code file"
    else
        echo "❌ File not found: $auth_file"
        echo ""
        echo "To use this method:"
        echo "1. Create the file in Home Assistant's config directory"
        echo "2. Paste your authentication code in the file"
        echo "3. Save the file with 600 permissions: chmod 600 /config/auth-code.txt"
        echo "4. Try again"
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