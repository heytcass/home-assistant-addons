# Claude Terminal for Home Assistant

A secure, web-based terminal with Claude Code CLI pre-installed for Home Assistant.

![Claude Terminal Screenshot](https://github.com/heytcass/home-assistant-addons/raw/main/claude-terminal/screenshot.png)

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
- **Native Claude Code CLI**: Pre-installed using Anthropic's official native installer with automatic updates
- **No Configuration Needed**: Uses OAuth authentication for easy setup
- **Direct Config Access**: Terminal starts in your `/config` directory for immediate access to all Home Assistant files
- **Home Assistant Integration**: Access directly from your dashboard
- **Panel Icon**: Quick access from the sidebar with the code-braces icon
- **Multi-Architecture Support**: Works on amd64, aarch64, and armv7 platforms
- **Secure Credential Management**: Persistent authentication with safe credential storage
- **Automatic Recovery**: Built-in fallbacks and error handling for reliable operation
- **Persistent Package Management**: Install APK and pip packages that survive container restarts

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

# Install packages that persist across restarts
persist-install apk vim htop
persist-install pip requests pandas

# List persistent packages
persist-install list
```

## Installation

1. Add this repository to your Home Assistant add-on store
2. Install the Claude Terminal add-on
3. Start the add-on
4. Click "OPEN WEB UI" or the sidebar icon to access
5. On first use, follow the OAuth prompts to log in to your Anthropic account

## Configuration

The add-on works out of the box with sensible defaults. Optional configuration:

| Option | Default | Description |
|--------|---------|-------------|
| `auto_launch_claude` | `true` | Auto-start Claude on terminal open (set to `false` for session picker) |
| `persistent_apk_packages` | `[]` | List of APK packages to install on startup |
| `persistent_pip_packages` | `[]` | List of pip packages to install on startup |

### Example Configuration
```yaml
auto_launch_claude: true
persistent_apk_packages:
  - vim
  - htop
  - rsync
persistent_pip_packages:
  - requests
  - pandas
  - numpy
```

### Default Settings
- **Port**: Web interface runs on port 7681
- **Authentication**: OAuth with Anthropic (credentials stored securely in `/data/.config/claude/`)
- **Terminal**: Full bash environment with Claude Code CLI pre-installed
- **Volumes**: Access to `/config` (Home Assistant configuration)

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

### Unreleased - Native Installation
- **Native Claude Code Installation**: Switched to official native installer
- Automatic background updates from Anthropic
- Faster startup without Node.js interpreter overhead

### v1.5.0 (Current) - Persistent Packages
- **Persistent Package Management**: Install APK and pip packages that survive restarts
- New `persist-install` command for easy package management
- Configuration options for auto-installing packages on startup
- Inspired by community contributions from [@ESJavadex](https://github.com/ESJavadex)

### v1.4.x
- Added Python 3.11 and development tools (git, vim, jq, wget, tree)
- ttyd keepalive options to prevent WebSocket disconnects
- Home Assistant API access with examples

### v1.3.x
- Interactive session picker menu
- Authentication helper for clipboard issues
- Health check diagnostics

See [CHANGELOG.md](CHANGELOG.md) for complete version history.

## Useful Links

- [Claude Code Documentation](https://docs.anthropic.com/claude/docs/claude-code)
- [Get an Anthropic API Key](https://console.anthropic.com/)
- [Claude Code GitHub Repository](https://github.com/anthropics/claude-code)
- [Home Assistant Add-ons](https://www.home-assistant.io/addons/)

## Credits

This add-on was created with the assistance of Claude Code itself! The development process, debugging, and documentation were all completed using Claude's AI capabilities - a perfect demonstration of what this add-on can help you accomplish.

## License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details.