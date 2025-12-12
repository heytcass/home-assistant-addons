# Configuration Wizard Guide

## Overview

The Claude Terminal add-on now includes an **interactive configuration wizard** that makes it easy to set up custom model providers like Z.ai without manually editing YAML files.

## When Does the Wizard Appear?

The wizard automatically launches on **first run** when:
- No `settings.json` exists
- No authentication has been completed (`.claude.json` doesn't exist)
- No `custom_settings_json` is configured in add-on options

You can also access it anytime from the **session picker menu** (option 5).

## Wizard Options

### 1. 🌐 Anthropic (Default)

**What it does:**
- Removes any custom settings
- Uses standard Anthropic OAuth authentication
- Uses official Claude models (Haiku, Sonnet, Opus)

**Best for:**
- Most users
- Standard Claude experience
- No API key management needed

**Setup:**
1. Select option 1
2. Confirm the choice
3. Follow OAuth prompts in browser

---

### 2. ⚡ Z.ai (Custom Provider)

**What it does:**
- Prompts for Z.ai API key
- Configures Z.ai endpoint
- Sets up GLM models (4.5-Air, 4.6)

**Best for:**
- Users with Z.ai accounts
- Access to GLM models
- Alternative to Anthropic

**Setup:**
1. Select option 2
2. Enter your Z.ai API key
3. Choose model configuration:
   - **Option 1**: GLM-4.6 (recommended)
   - **Option 2**: GLM-4.5-Air (faster)
   - **Option 3**: Custom model names
4. Wizard creates `settings.json` automatically

**Example settings.json created:**
```json
{
  "env": {
    "ANTHROPIC_API_KEY": "your_zai_api_key",
    "ANTHROPIC_BASE_URL": "https://api.z.ai/api/anthropic",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "GLM-4.5-Air",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "GLM-4.6",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "GLM-4.6"
  }
}
```

---

### 3. 🔧 Custom Provider (Advanced)

**What it does:**
- Prompts for custom API key
- Prompts for custom base URL
- Prompts for custom model name

**Best for:**
- Advanced users
- Custom API endpoints
- Self-hosted solutions

**Setup:**
1. Select option 3
2. Enter API key
3. Enter base URL (e.g., `https://api.example.com`)
4. Enter model name (optional)

---

### 4. ℹ️ Show Current Configuration

**What it does:**
- Displays current provider status
- Shows settings.json contents if custom config exists
- Helps verify configuration

---

### 5. 🗑️ Remove Custom Settings

**What it does:**
- Deletes settings.json
- Reverts to Anthropic defaults
- Requires confirmation

**Use when:**
- Switching back to Anthropic
- Troubleshooting configuration issues
- Starting fresh

---

## Accessing the Wizard

### Method 1: First Run (Automatic)
- Install and start the add-on
- Wizard appears automatically

### Method 2: Session Picker
1. Set `auto_launch_claude: false` in add-on configuration
2. Open the terminal
3. Select option 5 from the session picker menu

### Method 3: Manual Launch
From the terminal, run:
```bash
/opt/scripts/claude-config-wizard.sh
```

## File Locations

- **Settings file**: `/data/.config/claude/settings.json`
- **Auth file**: `/data/.config/claude/.claude.json`
- **Wizard script**: `/opt/scripts/claude-config-wizard.sh`

## Troubleshooting

### Wizard doesn't appear on first run
- Check if `custom_settings_json` is set in add-on configuration
- Check if authentication already exists
- Manually launch wizard from session picker

### Invalid JSON error
- Use the wizard instead of manual YAML editing
- Wizard validates all inputs automatically

### Want to change configuration
- Access wizard from session picker (option 5)
- Or use option 5 to remove settings and start fresh

## Comparison: Wizard vs Manual YAML

| Feature | Interactive Wizard | Manual YAML |
|---------|-------------------|-------------|
| Ease of use | ✅ Very easy | ⚠️ Requires YAML knowledge |
| Error prevention | ✅ Validated inputs | ❌ Easy to make mistakes |
| Discoverability | ✅ Guided prompts | ❌ Must read docs |
| Flexibility | ⚠️ Common options | ✅ Full customization |
| First-time users | ✅ Recommended | ❌ Not recommended |

## Best Practices

1. **Use the wizard** for initial setup
2. **Keep API keys secure** - they're stored in `/data/.config/claude/`
3. **Test configuration** after setup by running a simple Claude command
4. **Document custom settings** if using advanced configurations
5. **Use "Show current config"** to verify settings before making changes

