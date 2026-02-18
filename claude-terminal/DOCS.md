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

No configuration is needed! The add-on uses OAuth authentication, so you'll be prompted to log in to your Anthropic account the first time you use it.

Your OAuth credentials are stored in the `/config/claude-config` directory and will persist across add-on updates and restarts, so you won't need to log in again.

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `auto_launch_claude` | `true` | Automatically start Claude when opening the terminal |
| `enable_ha_mcp` | `true` | Enable Home Assistant MCP server integration |
| `persistent_apk_packages` | `[]` | APK packages to install on every startup |
| `persistent_pip_packages` | `[]` | Python packages to install on every startup |

## Usage

Claude launches automatically when you open the terminal. You can also start Claude manually with:

```bash
claude
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
- **Home Assistant MCP Server**: Built-in integration with [ha-mcp](https://github.com/homeassistant-ai/ha-mcp) for natural language control

## Home Assistant MCP Integration

This add-on includes the [homeassistant-ai/ha-mcp](https://github.com/homeassistant-ai/ha-mcp) MCP server, enabling Claude to directly interact with your Home Assistant instance using natural language.

### What You Can Do

- **Control Devices**: "Turn off the living room lights", "Set the thermostat to 72°F"
- **Query States**: "What's the temperature in the bedroom?", "Is the front door locked?"
- **Manage Automations**: "Create an automation that turns on the porch light at sunset"
- **Work with Scripts**: "Run my movie mode script", "Create a script for my morning routine"
- **View History**: "Show me the energy usage for the last week"
- **Debug Issues**: "Why isn't my motion sensor automation triggering?"
- **Manage Dashboards**: "Add a weather card to my dashboard"

### How It Works

The MCP (Model Context Protocol) server automatically connects to your Home Assistant using the Supervisor API. No manual configuration or token setup is required - it just works!

The integration provides 97+ tools for:
- Entity search and control
- Automation and script management
- Dashboard configuration
- History and statistics
- Device registry access
- And much more

### Security Note

The ha-mcp integration gives Claude extensive control over your Home Assistant instance, including the ability to control devices, modify automations, and access history data. Only enable this if you understand and accept these capabilities. You can disable it at any time by setting `enable_ha_mcp: false` in the add-on configuration.

### Disabling the Integration

If you don't want the Home Assistant MCP integration, you can disable it in the add-on configuration:

```yaml
enable_ha_mcp: false
```

## Troubleshooting

- If Claude doesn't start automatically, try running `claude -i` manually
- If you see permission errors, try restarting the add-on
- If you have authentication issues, try logging out and back in
- Check the add-on logs for any error messages

## Credits

This add-on was created with the assistance of Claude Code itself! The development process, debugging, and documentation were all completed using Claude's AI capabilities - a perfect demonstration of what this add-on can help you accomplish.