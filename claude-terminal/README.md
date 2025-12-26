# Claude Terminal for Home Assistant

![Version](https://img.shields.io/badge/version-1.5.1-blue.svg)
![Architecture](https://img.shields.io/badge/architecture-amd64%20%7C%20aarch64%20%7C%20armv7-green.svg)

A secure, web-based terminal with Claude Code CLI pre-installed for Home Assistant.

![Claude Terminal Screenshot](https://github.com/shipdocs/home-assistant-addons/raw/main/claude-terminal/screenshot.png)

*Claude Terminal running in Home Assistant*

## What is Claude Terminal?

This add-on provides a web-based terminal interface with Claude Code CLI pre-installed, allowing you to use Claude's powerful AI capabilities directly from your Home Assistant dashboard. It gives you direct access to Anthropic's Claude AI assistant through a terminal, ideal for:

- Writing and editing code
- Debugging problems
- Learning new programming concepts
- Creating Home Assistant scripts and automations

## Features

- **Web Terminal Interface**: Access Claude through a browser-based terminal using ttyd
- **Auto-Launch**: Claude starts automatically when you open the terminal
- **Latest Claude Code CLI**: Pre-installed with Anthropic's official CLI (@latest)
- **No Configuration Needed**: Uses OAuth authentication for easy setup
- **Direct Config Access**: Terminal starts in your `/config` directory for immediate access to all Home Assistant files
- **Home Assistant Integration**: Access directly from your dashboard
- **Panel Icon**: Quick access from the sidebar with the code-braces icon
- **Multi-Architecture Support**: Works on amd64, aarch64, and armv7 platforms
- **Secure Credential Management**: Persistent authentication with safe credential storage
- **Automatic Recovery**: Built-in fallbacks and error handling for reliable operation

## Quick Start

The terminal automatically starts Claude when you open it. You can immediately start using commands like:

```bash
# Ask Claude a question directly
claude "How can I write a Python script to control my lights?"

# Start an interactive session
claude -i

# Get help with available commands
claude --help

# Debug authentication if needed
claude-auth debug

# Log out and re-authenticate
claude-logout
```

## Installation

1. Add this repository to your Home Assistant add-on store
2. Install the Claude Terminal add-on
3. Start the add-on
4. Click "OPEN WEB UI" or the sidebar icon to access
5. On first use, follow the OAuth prompts to log in to your Anthropic account

## Configuration

### Interactive Setup Wizard (Recommended)

On first launch, the add-on presents an **interactive configuration wizard** that guides you through setup:

1. **🌐 Anthropic (Default)** - Official Claude API with OAuth authentication
2. **⚡ Z.ai** - Alternative provider with GLM models
3. **🔧 Custom Provider** - Manual configuration for other providers

The wizard automatically:
- Prompts for necessary API keys
- Configures model endpoints
- Creates the settings.json file
- **No manual YAML editing required!**

You can access the wizard anytime from the session picker menu (option 5) or by disabling `auto_launch_claude`.

### Automatic Configuration

The add-on handles all settings automatically:

- **Port**: Web interface runs on port 7681
- **Authentication**: OAuth with Anthropic (credentials stored securely in `/data/.config/claude/`)
- **Terminal**: Full bash environment with Claude Code CLI pre-installed
- **Volumes**: Access to both `/config` (Home Assistant) and `/addons` (for development)

### Advanced: Manual YAML Configuration (Optional)

If you prefer manual configuration or need advanced customization, you can configure a custom `settings.json`:

1. Go to **Settings** → **Add-ons** → **Claude Terminal** → **Configuration** tab
2. Add your custom settings in YAML format:

```yaml
custom_settings_json: |
  {
    "apiKeyHelper": "echo 'your_zai_api_key_here'",
    "env": {
      "ANTHROPIC_BASE_URL": "https://api.z.ai/api/anthropic",
      "ANTHROPIC_DEFAULT_SONNET_MODEL": "GLM-4.6"
    }
  }
```

3. Save and restart the add-on

For more configuration options and examples, see the [full documentation](DOCS.md).

## Troubleshooting

### Authentication Issues
If you have authentication problems:
```bash
claude-auth debug    # Show credential status
claude-logout        # Clear credentials and re-authenticate
```

### Container Issues
- Credentials are automatically saved and restored between restarts
- Check add-on logs if the terminal doesn't load
- Restart the add-on if Claude commands aren't recognized

### Development
For local development and testing:
```bash
# Enter development environment
nix develop

# Build and test locally
build-addon
run-addon

# Lint and validate
lint-dockerfile
test-endpoint
```

## Architecture

- **Base Image**: Home Assistant Alpine Linux base (3.19)
- **Container Runtime**: Compatible with Docker/Podman
- **Web Terminal**: ttyd for browser-based access
- **Process Management**: s6-overlay for reliable service startup
- **Networking**: Ingress support with Home Assistant reverse proxy

## Security

Version 1.0.2 includes important security improvements:
- ✅ **Secure Credential Management**: Limited filesystem access to safe directories only
- ✅ **Safe Cleanup Operations**: No more dangerous system-wide file deletions
- ✅ **Proper Permission Handling**: Consistent file permissions (600) for credentials
- ✅ **Input Validation**: Enhanced error checking and bounds validation

## Development Environment

This add-on includes a comprehensive development setup using Nix:

```bash
# Available development commands
build-addon      # Build the add-on container with Podman
run-addon        # Run add-on locally on port 7681
lint-dockerfile  # Lint Dockerfile with hadolint
test-endpoint    # Test web endpoint availability
```

**Requirements for development:**
- NixOS or Nix package manager
- Podman (automatically provided in dev shell)
- Optional: direnv for automatic environment activation

## Documentation

For detailed usage instructions, see the [documentation](DOCS.md).

## Version History

### v1.4.0 (Current) - Custom Settings & Z.ai Support
- ✨ **NEW**: Custom settings.json configuration support
- 🎯 Enable Z.ai integration and alternative model providers
- 📝 Comprehensive documentation for custom model configuration
- 🔧 Settings file created at `/data/.config/claude/settings.json`

### v1.0.2 - Security & Bug Fix Release
- 🔒 **CRITICAL**: Fixed dangerous filesystem operations
- 🐛 Added missing armv7 architecture support
- 🔧 Pinned NPM packages and improved error handling
- 🛠️ Enhanced development environment with Podman support

### v1.0.1
- Improved credential management
- Enhanced startup reliability

### v1.0.0
- Initial stable release
- Web terminal interface with ttyd
- Pre-installed Claude Code CLI
- OAuth authentication support

## Useful Links

- [Claude Code Documentation](https://docs.anthropic.com/claude/docs/claude-code)
- [Get an Anthropic API Key](https://console.anthropic.com/)
- [Claude Code GitHub Repository](https://github.com/anthropics/claude-code)
- [Home Assistant Add-ons](https://www.home-assistant.io/addons/)

## Credits

This add-on was created with the assistance of Claude Code itself! The development process, debugging, and documentation were all completed using Claude's AI capabilities - a perfect demonstration of what this add-on can help you accomplish.

## License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details.