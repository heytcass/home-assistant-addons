# Claude Terminal Home Assistant Add-on Documentation

## Overview

Claude Terminal provides a web-based terminal interface with Claude Code CLI pre-installed, allowing you to access Claude's powerful AI capabilities directly from your Home Assistant dashboard. Claude Code is an AI coding assistant by Anthropic that can help you with Home Assistant configuration, automation creation, debugging, and general coding tasks.

## Installation

Follow these steps to install the add-on:

1. Navigate to your Home Assistant instance
2. Go to Settings -> Add-ons -> Add-on Store
3. Click the three dots in the top right corner and select "Repositories"
4. Add the URL of this repository and click "Add"
5. Find the "Claude Terminal" add-on and click on it
6. Click "Install"

## Configuration

The add-on works out of the box with sensible defaults. Optional configuration:

- **auto_launch_claude** (default: `true`): Automatically launch Claude when opening the terminal
- **auto_resume_session** (default: `true`): Automatically resume your most recent conversation
- **persistent_apk_packages** (default: `[]`): List of APK packages to install on startup that persist across restarts
- **persistent_pip_packages** (default: `[]`): List of pip packages to install on startup that persist across restarts

### Example Configuration
```yaml
auto_launch_claude: true
auto_resume_session: true
persistent_apk_packages:
  - vim
  - htop
  - rsync
persistent_pip_packages:
  - requests
  - pandas
```

The add-on uses OAuth authentication, so you'll be prompted to log in to your Anthropic account the first time you use it.

## Usage

The Claude Code CLI launches automatically when you open the terminal. You can interact with it using the following commands:

### Common Commands

- `claude -i` - Start an interactive Claude session
- `claude --help` - See all available commands
- `claude "your prompt"` - Ask Claude a single question
- `claude process myfile.py` - Have Claude analyze a file
- `claude --editor` - Start an interactive editor session

The terminal starts in the `/config` directory, giving you access to all your Home Assistant configuration files. Claude's authentication and session data persists between restarts in `/data/.config/claude/`.

## Home Assistant-Specific Use Cases

Claude Terminal is particularly useful for Home Assistant tasks. Here are some example uses:

### 1. Automation Creation and Debugging

```
# Create a new automation
claude "create an automation that turns on lights when motion is detected, but only if it's dark"

# Debug an existing automation
claude "why isn't my automation working? Here's the code: [paste automation code]"
```

### 2. YAML Configuration Help

```
# Get help with syntax
claude "what's wrong with this YAML? [paste YAML]"

# Create a new configuration
claude "create a configuration for a zigbee device with these capabilities: [list capabilities]"
```

### 3. Entity Management

```
# Clean up entity names
claude "suggest better names for these entities: [paste entity list]"

# Create a template sensor
claude "create a template sensor that averages these temperature sensors: [paste sensor IDs]"
```

### 4. Custom Component Development

```
# Create a new integration
claude "help me create a custom integration for my smart coffee maker"

# Debug integration issues
claude "why is my custom component failing to load? Here's the error: [paste error]"
```

## Troubleshooting

### Common Issues

1. **Authentication Issues**: 
   - If you're having trouble with OAuth login, try clearing your browser cookies
   - Make sure you have a valid Anthropic account with billing enabled

2. **Connection Problems**: 
   - Check your internet connection
   - Verify the add-on can reach api.anthropic.com

3. **Terminal Connection Issues**:
   - If the terminal disconnects, try refreshing the page
   - Check if the add-on is still running in Home Assistant

### Logs

Check the add-on logs for detailed information about any issues:

1. Go to the add-on page in Home Assistant
2. Click the "Logs" tab

## Security Considerations

Claude Terminal is designed with security in mind:

- The add-on runs in an isolated container
- Your code and queries go directly to Anthropic's API
- OAuth authentication ensures secure access to your account

To further enhance security:
- Log out when not actively using the terminal
- Monitor the add-on logs for unusual activity
- Keep your Anthropic account secure with a strong password

## Support

- For issues with the add-on itself, please open an issue on the GitHub repository
- For Claude Code-specific issues, refer to the [Anthropic documentation](https://docs.anthropic.com/claude-code)
- For billing or API questions, visit [Anthropic's support site](https://support.anthropic.com)

## Credits

This add-on was created with the assistance of Claude Code itself! The entire development process, debugging, and documentation were all completed using Claude's AI capabilities.

## License

This add-on is provided under the MIT License. Claude Code itself is subject to Anthropic's Commercial Terms of Service.
