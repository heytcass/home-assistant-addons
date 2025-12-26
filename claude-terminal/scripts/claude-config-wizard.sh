#!/bin/bash

# Claude Configuration Wizard
# Interactive setup for choosing between default Anthropic or custom providers (Z.ai, etc.)

# Claude CLI looks in ~/.claude/settings.json by default
SETTINGS_FILE="$HOME/.claude/settings.json"
SETTINGS_DIR="$HOME/.claude"
WIZARD_COMPLETED_MARKER="/data/.config/claude/.wizard-completed"

# Ensure settings directory exists
mkdir -p "$SETTINGS_DIR"
mkdir -p "$(dirname "$WIZARD_COMPLETED_MARKER")"

show_banner() {
    clear
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║              🤖 Claude Configuration Wizard                  ║"
    echo "║           First-time Setup & Model Provider Selection        ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
}

show_provider_menu() {
    echo "Choose your Claude provider:"
    echo ""
    echo "  1) 🌐 Anthropic (Default - Official Claude API)"
    echo "     • Uses your Anthropic account"
    echo "     • OAuth authentication"
    echo "     • Standard Claude models"
    echo ""
    echo "  2) ⚡ Z.ai (Custom Provider - GLM Models)"
    echo "     • Uses Z.ai API endpoint"
    echo "     • Requires Z.ai API key"
    echo "     • GLM-4.5-Air, GLM-4.6 models"
    echo ""
    echo "  3) 🔧 Custom Provider (Advanced)"
    echo "     • Manual configuration"
    echo "     • Custom API endpoint and models"
    echo ""
    echo "  4) ℹ️  Show current configuration"
    echo "  5) 🗑️  Remove custom settings (keep wizard status)"
    echo "  6) 🔄 Reset wizard (show on next restart)"
    echo "  7) ❌ Exit without changes"
    echo ""
}

get_user_choice() {
    local choice
    printf "Enter your choice [1-7]: " >&2
    read -r choice
    echo "$choice" | tr -d '[:space:]'
}

setup_anthropic_default() {
    echo ""
    echo "✅ Using Anthropic (Default Configuration)"
    echo ""
    echo "This will:"
    echo "  • Remove any custom settings.json"
    echo "  • Use standard Anthropic OAuth authentication"
    echo "  • Use official Claude models"
    echo ""
    printf "Continue? [Y/n]: " >&2
    read -r confirm

    if [[ "$confirm" =~ ^[Nn] ]]; then
        echo "Cancelled."
        return 1
    fi

    # Remove custom settings if they exist
    if [ -f "$SETTINGS_FILE" ]; then
        rm -f "$SETTINGS_FILE"
        echo "✅ Custom settings removed"
    fi

    # Mark wizard as completed
    touch "$WIZARD_COMPLETED_MARKER"

    echo "✅ Configuration complete!"
    echo ""
    echo "Next steps:"
    echo "  1. You'll be prompted to authenticate with Anthropic"
    echo "  2. Follow the OAuth flow in your browser"
    echo "  3. Start using Claude!"
    echo ""
    return 0
}

setup_zai_provider() {
    echo ""
    echo "⚡ Z.ai Provider Setup"
    echo ""
    echo "You'll need:"
    echo "  • Z.ai API key (from https://z.ai)"
    echo ""
    
    printf "Enter your Z.ai API key: " >&2
    read -r api_key
    
    if [ -z "$api_key" ]; then
        echo "❌ API key is required"
        return 1
    fi
    
    echo ""
    echo "Select default models:"
    echo "  1) GLM-4.6 (Recommended - Best performance)"
    echo "  2) GLM-4.5-Air (Faster, lighter)"
    echo "  3) Custom model names"
    echo ""
    printf "Choice [1-3] (default: 1): " >&2
    read -r model_choice
    
    local haiku_model="GLM-4.5-Air"
    local sonnet_model="GLM-4.6"
    local opus_model="GLM-4.6"
    
    case "$model_choice" in
        2)
            haiku_model="GLM-4.5-Air"
            sonnet_model="GLM-4.5-Air"
            opus_model="GLM-4.5-Air"
            ;;
        3)
            printf "Haiku model name: " >&2
            read -r haiku_model
            printf "Sonnet model name: " >&2
            read -r sonnet_model
            printf "Opus model name: " >&2
            read -r opus_model
            ;;
        *)
            # Use defaults (already set)
            ;;
    esac
    
    # Create settings.json with apiKeyHelper
    cat > "$SETTINGS_FILE" <<EOF
{
  "apiKeyHelper": "echo '$api_key'",
  "env": {
    "ANTHROPIC_BASE_URL": "https://api.z.ai/api/anthropic",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "$haiku_model",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "$sonnet_model",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "$opus_model"
  }
}
EOF
    
    chmod 644 "$SETTINGS_FILE"

    # Mark wizard as completed
    touch "$WIZARD_COMPLETED_MARKER"

    echo ""
    echo "✅ Z.ai configuration saved!"
    echo ""
    echo "Configuration:"
    echo "  • API Endpoint: https://api.z.ai/api/anthropic"
    echo "  • Haiku Model: $haiku_model"
    echo "  • Sonnet Model: $sonnet_model"
    echo "  • Opus Model: $opus_model"
    echo ""
    return 0
}

setup_custom_provider() {
    echo ""
    echo "🔧 Custom Provider Setup"
    echo ""
    
    printf "Enter API key: " >&2
    read -r api_key
    printf "Enter base URL (e.g., https://api.example.com): " >&2
    read -r base_url
    printf "Enter default model name: " >&2
    read -r model_name
    
    if [ -z "$api_key" ] || [ -z "$base_url" ]; then
        echo "❌ API key and base URL are required"
        return 1
    fi
    
    # Create settings.json with apiKeyHelper
    cat > "$SETTINGS_FILE" <<EOF
{
  "apiKeyHelper": "echo '$api_key'",
  "env": {
    "ANTHROPIC_BASE_URL": "$base_url"
EOF

    if [ -n "$model_name" ]; then
        cat >> "$SETTINGS_FILE" <<EOF
,
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "$model_name"
EOF
    fi

    cat >> "$SETTINGS_FILE" <<EOF

  }
}
EOF

    chmod 644 "$SETTINGS_FILE"

    # Mark wizard as completed
    touch "$WIZARD_COMPLETED_MARKER"

    echo "✅ Custom configuration saved!"
    return 0
}

show_current_config() {
    echo ""
    echo "📋 Current Configuration"
    echo ""

    if [ ! -f "$SETTINGS_FILE" ]; then
        echo "  Status: Using Anthropic Default"
        echo "  • No custom settings.json found"
        echo "  • Using standard OAuth authentication"
        echo "  • Using official Claude models"
    else
        echo "  Status: Custom Configuration Active"
        echo "  • Settings file: $SETTINGS_FILE"
        echo ""
        echo "  Contents:"
        cat "$SETTINGS_FILE" | jq '.' 2>/dev/null || cat "$SETTINGS_FILE"
    fi

    echo ""
    printf "Press Enter to continue..." >&2
    read -r
}

remove_custom_settings() {
    echo ""
    echo "🗑️  Remove Custom Settings"
    echo ""

    if [ ! -f "$SETTINGS_FILE" ]; then
        echo "  No custom settings found (already using defaults)"
        printf "Press Enter to continue..." >&2
        read -r
        return 0
    fi

    echo "This will:"
    echo "  • Delete $SETTINGS_FILE"
    echo "  • Revert to Anthropic default configuration"
    echo "  • Keep wizard completion status (won't show wizard on restart)"
    echo ""
    printf "Are you sure? [y/N]: " >&2
    read -r confirm

    if [[ "$confirm" =~ ^[Yy] ]]; then
        rm -f "$SETTINGS_FILE"
        echo "✅ Custom settings removed. Using Anthropic defaults."
    else
        echo "Cancelled."
    fi

    echo ""
    printf "Press Enter to continue..." >&2
    read -r
}

reset_wizard() {
    echo ""
    echo "🔄 Reset Wizard Status"
    echo ""
    echo "This will:"
    echo "  • Remove wizard completion marker"
    echo "  • Show configuration wizard on next add-on restart"
    echo "  • Keep current settings.json (if exists)"
    echo ""
    printf "Are you sure? [y/N]: " >&2
    read -r confirm

    if [[ "$confirm" =~ ^[Yy] ]]; then
        rm -f "$WIZARD_COMPLETED_MARKER"
        echo "✅ Wizard reset. The configuration wizard will appear on next restart."
    else
        echo "Cancelled."
    fi

    echo ""
    printf "Press Enter to continue..." >&2
    read -r
}

# Main execution flow
main() {
    # Check if this is first run (no settings and no auth)
    local is_first_run=false
    if [ ! -f "$SETTINGS_FILE" ] && [ ! -f "/data/.config/claude/.claude.json" ]; then
        is_first_run=true
    fi

    while true; do
        show_banner

        if [ "$is_first_run" = true ]; then
            echo "👋 Welcome! Let's set up your Claude configuration."
            echo ""
            is_first_run=false
        fi

        show_provider_menu
        choice=$(get_user_choice)

        case "$choice" in
            1)
                if setup_anthropic_default; then
                    echo "Press Enter to start Claude..."
                    read -r
                    exec /opt/scripts/load-claude-env.sh
                fi
                ;;
            2)
                if setup_zai_provider; then
                    echo "Press Enter to start Claude..."
                    read -r
                    exec /opt/scripts/load-claude-env.sh
                fi
                ;;
            3)
                if setup_custom_provider; then
                    echo "Press Enter to start Claude..."
                    read -r
                    exec /opt/scripts/load-claude-env.sh
                fi
                ;;
            4)
                show_current_config
                ;;
            5)
                remove_custom_settings
                ;;
            6)
                reset_wizard
                ;;
            7)
                echo "👋 Exiting..."
                exit 0
                ;;
            *)
                echo ""
                echo "❌ Invalid choice: '$choice'"
                echo "Please select a number between 1-7"
                echo ""
                printf "Press Enter to continue..." >&2
                read -r
                ;;
        esac
    done
}

# Handle cleanup on exit
trap 'echo ""; echo "👋 Goodbye!"; exit 0' EXIT INT TERM

# Run main function
main "$@"

