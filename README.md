# Claude Terminal for Home Assistant

This repository contains a custom add-on that integrates Anthropic's Claude Code CLI with Home Assistant.

## Installation

To add this repository to your Home Assistant instance:

1. Go to **Settings** → **Add-ons** → **Add-on Store**
2. Click the three dots menu in the top right corner
3. Select **Repositories**
4. Add the URL: `https://github.com/shipdocs/home-assistant-addons`
5. Click **Add**

## Add-ons

### Claude Terminal

A web-based terminal interface with Claude Code CLI pre-installed. This add-on provides a terminal environment directly in your Home Assistant dashboard, allowing you to use Claude's powerful AI capabilities for coding, automation, and configuration tasks.

**Latest Version: 1.5.0** - Now with interactive configuration wizard!

Features:
- 🎯 **Interactive Configuration Wizard** - Easy setup for Anthropic, Z.ai, or custom providers
- 🌐 **Web Terminal Access** - Browser-based terminal through your Home Assistant UI
- 🚀 **Auto-Launch** - Claude starts automatically when you open the terminal
- 🔧 **Multiple Providers** - Support for Anthropic (default), Z.ai, and custom API endpoints
- 📁 **Direct Config Access** - Terminal starts in your `/config` directory
- 🔐 **Secure Authentication** - OAuth for Anthropic, API key support for alternatives
- 🎨 **Session Picker** - Choose between new session, continue, resume, or custom commands
- 💻 **Multi-Architecture** - Works on amd64, aarch64, and armv7 platforms
- Access to Claude's complete capabilities including:
  - Code generation and explanation
  - Debugging assistance
  - Home Assistant automation help
  - Learning resources

**New in v1.5.0:**
- Interactive wizard for Z.ai and custom model providers
- Automatic environment variable loading from settings.json
- Visual feedback for loaded configurations
- No manual YAML editing required

[Documentation](claude-terminal/DOCS.md) | [Wizard Guide](claude-terminal/WIZARD_GUIDE.md) | [Changelog](claude-terminal/CHANGELOG.md)

## Support

If you have any questions or issues with this add-on, please create an issue in this repository.

## Credits

This add-on was created with the assistance of Claude Code itself! The development process, debugging, and documentation were all completed using Claude's AI capabilities.

## License

This repository is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
