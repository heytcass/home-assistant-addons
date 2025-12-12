# Claude Terminal

A terminal interface for Anthropic's Claude Code CLI in Home Assistant.

## About

This add-on provides a web-based terminal with Claude Code CLI pre-installed, allowing you to access Claude's powerful AI capabilities directly from your Home Assistant dashboard. The terminal provides full access to Claude's code generation, explanation, and problem-solving capabilities.

## Installation

1. Add this repository to your Home Assistant add-on store
2. Install the Claude Terminal add-on
3. Start the add-on
4. Click "OPEN WEB UI" to access the terminal
5. On first use, follow the OAuth prompts to log in to your Anthropic account

## Configuration

The add-on supports optional configuration for advanced use cases:

### Basic Configuration

No configuration is needed for basic usage! The add-on uses OAuth authentication, so you'll be prompted to log in to your Anthropic account the first time you use it.

Your OAuth credentials are stored in the `/data/.config/claude` directory and will persist across add-on updates and restarts, so you won't need to log in again.

### Advanced Configuration Options

#### Auto-launch Claude
- **Option**: `auto_launch_claude`
- **Type**: boolean (optional)
- **Default**: `true`
- **Description**: When enabled, Claude starts automatically when you open the terminal. Disable this to see a session picker instead.

#### Custom Settings.json (for Z.ai and Custom Models)
- **Option**: `custom_settings_json`
- **Type**: string (optional, JSON format)
- **Description**: Allows you to provide a custom `settings.json` configuration for Claude Code CLI. This is useful for integrating with Z.ai or other custom model providers.

**Example configuration for Z.ai integration:**

```yaml
custom_settings_json: |
  {
    "env": {
      "ANTHROPIC_API_KEY": "your_zai_api_key_here",
      "ANTHROPIC_BASE_URL": "https://api.z.ai/api/anthropic",
      "ANTHROPIC_DEFAULT_HAIKU_MODEL": "GLM-4.5-Air",
      "ANTHROPIC_DEFAULT_SONNET_MODEL": "GLM-4.6",
      "ANTHROPIC_DEFAULT_OPUS_MODEL": "GLM-4.6"
    }
  }
```

**Example configuration with custom permissions:**

```yaml
custom_settings_json: |
  {
    "env": {
      "ANTHROPIC_MODEL": "claude-opus-4-20250514"
    },
    "permissions": {
      "allow": ["Bash(npm run lint)", "Read(~/.bashrc)"],
      "deny": ["Bash(curl:*)", "Read(./secrets/**)"]
    }
  }
```

To configure these options in Home Assistant:
1. Go to **Settings** → **Add-ons** → **Claude Terminal**
2. Click the **Configuration** tab
3. Add your desired configuration in YAML format
4. Click **Save**
5. Restart the add-on for changes to take effect

**Important Notes:**
- The `custom_settings_json` must be valid JSON format
- The settings file will be created at `/data/.config/claude/settings.json`
- If you remove the `custom_settings_json` configuration, any existing settings.json will be deleted on next restart
- For more information on settings.json options, see the [Claude Code settings documentation](https://code.claude.com/docs/en/settings)

## Usage

Claude launches automatically when you open the terminal. You can also start Claude manually with:

```bash
node /usr/local/bin/claude
```

### Common Commands

- `claude -i` - Start an interactive Claude session
- `claude --help` - See all available commands
- `claude "your prompt"` - Ask Claude a single question
- `claude process myfile.py` - Have Claude analyze a file
- `claude --editor` - Start an interactive editor session

The terminal starts directly in your `/config` directory, giving you immediate access to all your Home Assistant configuration files. This makes it easy to get help with your configuration, create automations, and troubleshoot issues.

## Features

- **Web Terminal**: Access a full terminal environment via your browser
- **Auto-Launching**: Claude starts automatically when you open the terminal
- **Claude AI**: Access Claude's AI capabilities for programming, troubleshooting and more
- **Direct Config Access**: Terminal starts in `/config` for immediate access to all Home Assistant files
- **Simple Setup**: Uses OAuth for easy authentication
- **Home Assistant Integration**: Access directly from your dashboard

## Troubleshooting

- If Claude doesn't start automatically, try running `node /usr/local/bin/claude -i` manually
- If you see permission errors, try restarting the add-on
- If you have authentication issues, try logging out and back in
- Check the add-on logs for any error messages

## Credits

This add-on was created with the assistance of Claude Code itself! The development process, debugging, and documentation were all completed using Claude's AI capabilities - a perfect demonstration of what this add-on can help you accomplish.