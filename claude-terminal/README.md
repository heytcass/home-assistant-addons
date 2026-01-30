# Claude Terminal for Home Assistant

A secure, web-based terminal with Claude Code CLI pre-installed for Home Assistant.

![Claude Terminal Screenshot](https://github.com/Arborist-ai/HA-LCASS/raw/main/claude-terminal/screenshot.png)

*Claude Terminal running in Home Assistant*

## What is Claude Terminal?

This add-on provides a web-based terminal interface with Claude Code CLI pre-installed, allowing you to use Claude's powerful AI capabilities directly from your Home Assistant dashboard. It gives you direct access to Anthropic's Claude AI assistant through a terminal, ideal for:

- Writing and editing code
- Debugging problems
- Learning new programming concepts
- Creating Home Assistant scripts and automations

## Features

- **Web Terminal Interface**: Access Claude through a browser-based terminal using ttyd
- **Auto-Resume Sessions**: Automatically continues your most recent conversation when reopening the terminal
- **Auto-Launch**: Claude starts automatically when you open the terminal
- **Git Integration**: Version control tools included for repository management
- **Native Claude Code CLI**: Pre-installed using Anthropic's official native installer with automatic updates
- **No Configuration Needed**: Uses OAuth authentication for easy setup
- **Persistent Package Management**: Install APK and pip packages that survive container restarts
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

### Configuration Options
- **auto_launch_claude** (default: `true`): Automatically launch Claude on terminal open
  - Set to `false` to show an interactive session picker instead
- **auto_resume_session** (default: `true`): Automatically resume the most recent conversation
  - Set to `false` to always start new sessions
  - Only applies when `auto_launch_claude` is enabled
- **persistent_apk_packages** (default: `[]`): List of APK packages to install on startup
- **persistent_pip_packages** (default: `[]`): List of pip packages to install on startup

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

Security improvements included in recent versions:
- ✅ **Least Privilege**: Reduced API permissions (default role instead of manager)
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

### v1.6.0 (Current) - Native Installer & Persistent Packages
- 🔄 **Native Installation**: Switched to official Claude native installer with automatic updates
- 📦 **Persistent Packages**: Install APK and pip packages that survive container restarts
- 🐛 **Fixed Auto-Resume**: Improved session detection for better resume functionality
- 🛠️ **PEP-0668 Fix**: Added compatibility for Python 3.11+ pip installations

### v1.5.0 - Session Continuity & Git Integration
- ✨ **Auto-Resume**: Automatically continue most recent conversation on terminal reopen
- 🔧 **Git Support**: Version control tools now included in Docker image
- 🎯 **Enhanced UX**: Session picker defaults to "Continue" for better workflow

### v1.4.x - Security & Development Tools
- 🔒 Reduced API permissions to least privilege
- 🛠️ Added Python 3.11 with essential libraries
- 📦 Included git, vim, jq, tree, wget, yq

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