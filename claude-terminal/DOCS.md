# Claude Terminal

Claude Code in a web terminal, as a Home Assistant add-on.

## About

This add-on runs Anthropic's [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI in a browser-based terminal (ttyd + tmux) with your Home Assistant configuration mounted. Open it from the sidebar, log in once, and ask Claude to write automations, debug YAML, or manage your setup.

## Installation

1. Add this repository to your Home Assistant add-on store
2. Install the Claude Terminal add-on
3. Start the add-on
4. Click "OPEN WEB UI" to access the terminal
5. On first use, follow the OAuth prompts to log in to your Anthropic account

Your credentials are stored under `/data` and persist across restarts and add-on updates, so you won't need to log in again.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `auto_launch_claude` | `true` | Start Claude immediately when the terminal opens. Set to `false` to get a shell instead (run `claude` yourself). |
| `claude_auto_update` | `true` | Keep Claude Code current: installs the official native build into `/data` and updates it in the background on each startup. |
| `dangerously_skip_permissions` | `false` | Launch Claude with `--dangerously-skip-permissions` (no confirmation prompts). **Read the security note below.** |
| `claude_extra_args` | `""` | Extra flags appended to every Claude launch, e.g. `--model claude-sonnet-5`. Values are split on spaces; quoted multi-word arguments are not supported. |
| `ha_smart_context` | `true` | Generate a CLAUDE.md with your HA system info so Claude knows your setup. |
| `enable_ha_mcp` | `true` | Register the [ha-mcp](https://github.com/homeassistant-ai/ha-mcp) MCP server so Claude can control Home Assistant directly. |
| `persistent_apk_packages` | `[]` | APK packages reinstalled on every startup. |
| `persistent_pip_packages` | `[]` | Python packages reinstalled on every startup. |

## Usage

With default settings, Claude launches automatically inside a tmux session named `claude`. Navigating away in Home Assistant and coming back reattaches to the same session — your conversation survives.

Useful commands (in shell mode, or after exiting Claude):

```bash
claude          # start Claude Code
claude -c       # continue the most recent conversation
claude -r       # pick a past conversation to resume
claude-doctor   # diagnose network, auth, and environment issues
persist-install apk htop   # install packages that survive restarts
ha-context      # refresh the Home Assistant context file
```

### Terminal tips

- **Scrolling**: use the mouse wheel — tmux copy-mode opens automatically. Press `q` to jump back to the bottom.
- **Copying**: select text with the mouse; on release it's copied to your clipboard (OSC 52). Long wrapped lines (like OAuth URLs) are joined back into one line automatically. Note: browsers only allow clipboard writes on secure pages — if you access Home Assistant over plain `http://`, use Shift+drag instead.
- **Shift+drag**: bypasses tmux and gives you the browser's native text selection (copy with `Ctrl+C` / right-click). Works everywhere, but wrapped lines are copied with line breaks — rejoin them by hand.
- **Pasting**: use `Ctrl+Shift+V` (or right-click, depending on browser).

### File access

The terminal starts in `/config` (your Home Assistant configuration). Also mounted:

- `/addon_configs` — configuration directories of your other add-ons
- `/share` — the shared folder

## Home Assistant MCP Integration

The bundled [ha-mcp](https://github.com/homeassistant-ai/ha-mcp) server connects Claude to Home Assistant through the Supervisor API — no token setup needed. Claude can query states, control devices, and manage automations, scripts, and dashboards in natural language.

Disable it with `enable_ha_mcp: false` if you don't want Claude to have this access.

## Security notes

**This add-on gives Claude a lot of power by design**: it runs as root in its container, has read/write access to `/config`, `/addon_configs`, and `/share`, and (with MCP enabled) can control devices and modify automations.

**`dangerously_skip_permissions` removes the last human checkpoint.** With it enabled, a misunderstanding — or a prompt injection in any file or web page Claude reads — can modify your HA configuration or actuate devices without asking you first. Leave it off unless you understand and accept that trade-off. A warning banner is printed in the add-on log whenever it is active.

## Troubleshooting

- **Can't copy the OAuth login URL**: at Claude's login prompt, press `c` to copy the URL to your clipboard (requires accessing HA over HTTPS). Alternatively, drag over the URL with the mouse — tmux copies it as a single joined line on release. On plain `http://`, use Shift+drag and rejoin the wrapped line after pasting. Don't click the link directly: the browser's link detection truncates URLs that wrap across lines.
- **Claude exits immediately or behaves oddly**: restart the add-on so the background auto-updater can fetch the latest Claude Code; check the add-on log for update messages.
- **Diagnostics**: run `claude-doctor` in the terminal for connectivity, memory, and environment checks.
- **Authentication problems**: run `claude /logout` inside Claude, then log in again.
- **Old backups too large?** Versions before 2.3.0 accumulated an npm cache in the add-on's data directory (up to several GB). 2.3.0 removes it automatically on first boot — take a fresh backup after upgrading.

## Credits

This add-on was created with the assistance of Claude Code itself! The development process, debugging, and documentation were all completed using Claude's AI capabilities - a perfect demonstration of what this add-on can help you accomplish.
