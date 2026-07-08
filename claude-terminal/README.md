# Claude Terminal for Home Assistant

Claude Code in a web terminal, as a Home Assistant add-on.

![Claude Terminal Screenshot](https://github.com/heytcass/home-assistant-addons/raw/main/claude-terminal/screenshot.png)

*Claude Terminal running in Home Assistant*

## What is Claude Terminal?

This add-on runs Anthropic's [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI in a browser-based terminal, directly from your Home Assistant dashboard. It starts in your `/config` directory, so Claude can immediately help with:

- Writing and debugging automations, scripts, and dashboards
- Fixing YAML configuration problems
- Controlling and inspecting Home Assistant via the bundled MCP server
- General coding and troubleshooting

## Features

- **Just Claude Code**: opens straight into Claude — no menus in the way
- **Stays current**: the official native Claude Code build is installed into persistent storage and auto-updated in the background
- **Session persistence**: tmux keeps your conversation alive across browser reloads and HA navigation; scrollback and mouse copy work
- **Persistent auth**: log in once via OAuth; credentials survive restarts and updates
- **Home Assistant MCP**: bundled [ha-mcp](https://github.com/homeassistant-ai/ha-mcp) server for natural-language control of your instance
- **HA Smart Context**: Claude automatically knows your HA version, entities, and add-ons
- **Broad file access**: `/config`, `/addon_configs`, and `/share` are mounted
- **Persistent packages**: `persist-install` keeps your extra apk/pip tools across restarts
- **Multi-architecture**: amd64 and aarch64 (prebuilt images pulled from GHCR)

## Installation

1. Add this repository to your Home Assistant add-on store
2. Install the Claude Terminal add-on
3. Start the add-on
4. Click "OPEN WEB UI" or the sidebar icon
5. On first use, follow the OAuth prompts to log in to your Anthropic account

## Configuration

Works out of the box. All options:

| Option | Default | Description |
|--------|---------|-------------|
| `auto_launch_claude` | `true` | Start Claude on terminal open; `false` gives you a shell |
| `claude_auto_update` | `true` | Keep Claude Code updated automatically |
| `dangerously_skip_permissions` | `false` | Skip Claude's confirmation prompts (see security note in [DOCS](DOCS.md)) |
| `claude_extra_args` | `""` | Extra flags for every Claude launch |
| `ha_smart_context` | `true` | Generate HA context file for Claude |
| `enable_ha_mcp` | `true` | Home Assistant MCP server integration |
| `ha_mcp_version` | `"7.11.0"` | ha-mcp release to run |
| `persistent_apk_packages` | `[]` | APK packages to install on startup |
| `persistent_pip_packages` | `[]` | pip packages to install on startup |

See [DOCS.md](DOCS.md) for full documentation, terminal tips (scrolling, copy/paste), and troubleshooting.

## Useful Links

- [Claude Code Documentation](https://docs.anthropic.com/en/docs/claude-code)
- [Claude Code GitHub Repository](https://github.com/anthropics/claude-code)
- [Home Assistant Add-ons](https://www.home-assistant.io/addons/)

## Credits

This add-on was created with the assistance of Claude Code itself! The development process, debugging, and documentation were all completed using Claude's AI capabilities - a perfect demonstration of what this add-on can help you accomplish.

## License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details.
