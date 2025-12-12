#!/bin/bash

# Load environment variables from settings.json before starting Claude
# This ensures custom API endpoints and models are properly configured

SETTINGS_FILE="/data/.config/claude/settings.json"

if [ -f "$SETTINGS_FILE" ]; then
    echo "🔧 Loading custom configuration from settings.json..."

    # Extract and export environment variables from settings.json
    if command -v jq >/dev/null 2>&1; then
        # Use jq to parse the env object
        env_count=0
        while IFS='=' read -r key value; do
            if [ -n "$key" ] && [ -n "$value" ]; then
                export "$key=$value"

                # Show key info without exposing full API key
                if [[ "$key" == *"API_KEY"* ]]; then
                    echo "  ✓ $key: ${value:0:8}..."
                else
                    echo "  ✓ $key: $value"
                fi
                env_count=$((env_count + 1))
            fi
        done < <(jq -r '.env // {} | to_entries[] | "\(.key)=\(.value)"' "$SETTINGS_FILE" 2>/dev/null)

        if [ $env_count -gt 0 ]; then
            echo "✅ Loaded $env_count environment variable(s)"
            echo ""
        fi
    else
        echo "⚠️  jq not available, skipping settings.json environment loading"
    fi
else
    echo "ℹ️  Using default Anthropic configuration"
fi

# Start Claude with all environment variables loaded
exec node "$(which claude)" "$@"

