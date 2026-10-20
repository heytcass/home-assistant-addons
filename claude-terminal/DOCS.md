# Claude Terminal

Claude Code in a web terminal, as a Home Assistant add-on.

## About

This add-on runs Anthropic's [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI in a browser-based terminal (ttyd + tmux) with your Home Assistant configuration mounted. Open it from the sidebar, log in once, and ask Claude to write automations, debug YAML, or manage your setup.

## Installation

1. Add this repository to your Home Assistant add-on store
2. Install the Claude Terminal add-on
3. Start the add-on
4. Click "OPEN WEB UI" to access the terminal
5. On first use, run through the OAuth login: a **"Claude Code login"** notification with a clickable authorize link appears in Home Assistant (bell icon) within a few seconds. Open it, authorize, and paste the code you get back into the terminal

Your credentials are stored under `/data` and persist across restarts and add-on updates, so you won't need to log in again.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `auto_launch_claude` | `true` | Start Claude immediately when the terminal opens. Set to `false` to get a shell instead (run `claude` yourself). |
| `claude_auto_update` | `true` | Keep Claude Code current: installs the official native build into `/data` and updates it in the background on each startup. |
| `working_directory` | `""` | Directory the terminal session starts in (default `/config`), e.g. `/config/ai_repo`. Claude asks its one-time folder-trust question on first use of a new directory. A non-existent path falls back to `/config` with a warning. |
| `claude_code_oauth_token` | `""` | Long-lived token from `claude setup-token`, for non-interactive authentication — useful when the OAuth browser flow is impractical. Note: token auth cannot establish [Remote Control](https://code.claude.com/docs/en/remote-control) sessions; use the normal login for that. Stored in the add-on configuration (masked in the UI, but included in HA backups like all add-on options). |
| `dangerously_skip_permissions` | `false` | Launch Claude with `--dangerously-skip-permissions` (no confirmation prompts). **Read the security note below.** |
| `enable_remote_control` | `false` | Launch Claude with `--remote-control`, so the same session also appears as "Home Assistant" in the Claude mobile app and at [claude.ai/code](https://claude.ai/code), where you can drive it from another device. The terminal keeps working as usual. Requires a normal claude.ai login (Pro/Max/Team/Enterprise) — not `claude_code_oauth_token` or an API key. Claude asks a one-time "Enable Remote Control?" question per directory. No effect in shell mode. |
| `claude_extra_args` | `""` | Extra flags appended to every Claude launch, e.g. `--model claude-sonnet-5`. Parsed like a shell command line, so quoting works: `--append-system-prompt 'be terse'` arrives as one argument. |
| `ha_smart_context` | `true` | Generate a CLAUDE.md with your HA system info so Claude knows your setup. |
| `enable_ha_mcp` | `true` | Register the [ha-mcp](https://github.com/homeassistant-ai/ha-mcp) MCP server so Claude can control Home Assistant directly. |
| `ha_mcp_version` | `"7.11.0"` | ha-mcp release to run. |
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
claude-login-url   # save the OAuth login URL to /config (see Troubleshooting)
persist-install apk htop   # install packages that survive restarts
ha-context      # refresh the Home Assistant context file
```

### Terminal tips

- **Scrolling**: use the mouse wheel — tmux copy-mode opens automatically. Press `q` to jump back to the bottom.
- **Copying**: hold **Shift** while you drag to select. That bypasses tmux and uses the browser terminal's own selection, which is copied to your clipboard as soon as you release (a ✂ flashes). Wrapped lines are copied with line breaks, so rejoin long ones (like URLs) by hand. On macOS, if Shift doesn't select, try Option.
- **Plain drag (no Shift)** selects in tmux and says it copied, but the text only lands in tmux's own buffer: the browser terminal (ttyd 1.7.7) ignores tmux's clipboard escape sequence (OSC 52). Use Shift+drag until that's fixed (#125).
- **Pasting**: use `Ctrl+Shift+V` (or right-click, depending on browser).

### File access

The terminal starts in `/config` (your Home Assistant configuration). Also mounted:

- `/addon_configs` — configuration directories of your other add-ons
- `/share` — the shared folder

## Home Assistant MCP Integration

The bundled [ha-mcp](https://github.com/homeassistant-ai/ha-mcp) server connects Claude to Home Assistant through the Supervisor API — no token setup needed. Claude can query states, control devices, and manage automations, scripts, and dashboards in natural language.

ha-mcp requires Python 3.13, which Alpine doesn't ship — the add-on provisions a managed Python build via [uv](https://github.com/astral-sh/uv) into `/data` on first use (a one-time ~150–250 MB download that persists across restarts and is included in HA backups). The environment is pre-warmed in the background at startup so the first MCP connection is fast.

Disable it with `enable_ha_mcp: false` if you don't want Claude to have this access.

## Security notes

**This add-on gives Claude a lot of power by design**: it runs as root in its container, has read/write access to `/config`, `/addon_configs`, and `/share`, and (with MCP enabled) can control devices and modify automations.

**`dangerously_skip_permissions` removes the last human checkpoint.** With it enabled, a misunderstanding — or a prompt injection in any file or web page Claude reads — can modify your HA configuration or actuate devices without asking you first. Leave it off unless you understand and accept that trade-off. A warning banner is printed in the add-on log whenever it is active.

**Any Home Assistant user can reach the terminal, not just administrators.** `panel_admin: true` hides the sidebar entry from non-admins, but it does not restrict the ingress URL behind it — that is how ingress works in Home Assistant generally, not something this add-on can switch off. Core's ingress view is declared `requires_auth = False` and is gated only by an ingress session cookie, and Core deliberately allows any signed-in user to mint that cookie and to read an add-on's `ingress_url` (see [core#60120](https://github.com/home-assistant/core/pull/60120)). For most add-ons that is harmless; here it means a non-admin account is one URL away from a root shell in this container — which can write anywhere in `/config`, `/addon_configs` and `/share`, and drive the Supervisor API. Treat every account on your instance as trusted while this add-on is installed, and stop or uninstall it if you hand out limited accounts.

**Only Home Assistant's ingress can reach the terminal.** Every add-on shares the internal `hassio` network, so the terminal is not served to it directly: ttyd listens on loopback and a small nginx gate on port 7681 only lets the Supervisor's ingress proxy (`172.30.32.2`) through. Other add-ons get `403 Forbidden`. Scripts that used to talk to `ws://<add-on>:7681/ws` from Home Assistant must go through ingress instead (create an ingress session with `POST http://supervisor/ingress/session`, then connect to `http://supervisor/ingress/<token>/ws` with the `ingress_session` cookie).

**Publishing port 7681 exposes an unauthenticated root shell.** The port is closed by default and ingress does not need it. If you map it to your host anyway, note that the terminal behind it has no login of its own — anyone who can reach that port on your network gets the same shell, with no Home Assistant account involved at all. Leave it unset unless the port is firewalled off and you accept that. When it is published, the gate above lets every address through (the add-on log says so at startup).

## Troubleshooting

- **Logging in**: use the link in the **"Claude Code login"** Home Assistant notification rather than copying the URL out of the terminal. The URL is long enough that the terminal wraps it, and both link detection and copying across the wrap can corrupt it — a damaged `state` or `code_challenge` gets you "Invalid request format" or `OAuth error: Request failed with status code 400`. The notification dismisses itself once you're logged in. If it never appears, open a second tmux window (`Ctrl+B` then `C`), run `claude-login-url`, and copy the URL from `/config/claude-login-url.txt` via the File Editor add-on or Samba (switch back with `Ctrl+B` then `L`; delete the file afterwards).
- **Login still fails with a 400**: the code you paste back is single-use and short-lived, and only works in the same `claude` process that printed the URL — so paste it promptly, and start over with a fresh `/login` if the add-on restarted in between. When you paste, Claude masks the code and shows its last few characters; that's normal, and no particular length is expected. If the browser flow keeps failing, skip it: run `claude setup-token` on any machine with a browser, put the token in the `claude_code_oauth_token` option, and restart the add-on (no Remote Control with token auth).
- **Claude exits immediately or behaves oddly**: restart the add-on so the background auto-updater can fetch the latest Claude Code; check the add-on log for update messages.
- **Diagnostics**: run `claude-doctor` in the terminal for connectivity, memory, and environment checks.
- **Authentication problems**: run `/logout` inside Claude, then `/login` again.
- **Old backups too large?** Versions before 2.3.0 accumulated an npm cache in the add-on's data directory (up to several GB). 2.3.0 removes it automatically on first boot — take a fresh backup after upgrading.

## Credits

This add-on was created with the assistance of Claude Code itself! The development process, debugging, and documentation were all completed using Claude's AI capabilities - a perfect demonstration of what this add-on can help you accomplish.
