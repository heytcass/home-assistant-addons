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
| `dangerously_skip_permissions` | `false` | **Read the warning below before enabling.** Launch Claude with `--dangerously-skip-permissions`, which disables all interactive tool-use confirmations. |
| `extra_claude_flags` | `""` | Free-form CLI flags appended to every `claude` invocation (e.g. `--model claude-opus-4-7 --verbose`). Useful for forward-compatibility with new Claude Code flags before this add-on exposes them as dedicated options. |
| `persistent_apk_packages` | `[]` | APK packages to install on every startup |
| `persistent_pip_packages` | `[]` | Python packages to install on every startup |

### About `dangerously_skip_permissions` (read before enabling)

When this option is **enabled**, the add-on launches Claude Code with the
`--dangerously-skip-permissions` flag. This bypasses *every* interactive
permission prompt: file edits, shell commands, network access — all tool calls
execute without confirmation.

**What this means in this add-on specifically:**

- Claude has read/write access to your entire `/config` directory (your Home
  Assistant configuration, secrets, automations, dashboards, blueprints, custom
  components, etc.).
- Claude has access to the Supervisor API (`hassio_api: true`,
  `hassio_role: manager`) and the Home Assistant API. Combined with the bundled
  ha-mcp integration, Claude can change device states, trigger services, edit
  automations, and reconfigure your installation.
- Claude can install arbitrary APK and pip packages via the persistent-package
  mechanism, and can run shell commands as the add-on's root user.

With permissions skipped, **a single hallucination, prompt injection, or
mistaken instruction can silently brick your Home Assistant setup, exfiltrate
secrets from `/config/secrets.yaml`, or take destructive action on connected
devices.** Prompt injection is a real concern here: any document, log, sensor
attribute, or web page Claude reads could contain instructions telling it to
do something harmful, and with this flag set Claude will not ask first.

**Disclaimer of responsibility.** Enabling this option is entirely at your own
risk. The add-on author and the maintainers of this fork accept no liability
for data loss, system damage, leaked credentials, unintended device actions,
or any other consequence resulting from running Claude with permissions
disabled. By turning the toggle on you confirm that you understand the
trade-off and that you are running this on a host where that trade-off is
acceptable.

**Recommendations if you still want to enable it:**

- Take a Home Assistant snapshot/backup *before* every Claude session.
- Keep `/config` under version control (git) so you can diff and revert.
- Do not use this on a production Home Assistant instance that controls
  safety-critical devices (locks, alarms, garage doors, ovens, EV chargers,
  etc.) without an out-of-band kill switch.
- Strongly prefer leaving this **off** and approving prompts manually. The
  flag exists for tightly sandboxed dev environments, not casual use.

If you are not absolutely sure you need this, **leave it disabled.**

### About `extra_claude_flags`

This is a free-form passthrough: whatever you put here is appended verbatim to
every `claude` invocation started by the add-on (auto-launch and session-picker
options 1–3). It exists so that new Claude Code CLI flags introduced upstream
can be used immediately without waiting for a dedicated config option in this
add-on. Examples:

```yaml
extra_claude_flags: "--model claude-opus-4-7"
extra_claude_flags: "--verbose --debug"
```

**Limitation — values containing spaces are not supported.** The string is
word-split on whitespace before being passed to `claude`, and inner quotes
(`'…'` or `"…"`) inside this option are *not* re-parsed by the shell. So a
value like `--append-system-prompt 'hello world'` would arrive at `claude` as
three separate argv entries (`--append-system-prompt`, `'hello`, `world'`),
not the intended quoted string. If you need a multi-word argument, drop into
the session picker (set `auto_launch_claude: false`) and use option 4 (Custom
Claude command) where the line is parsed by a real shell.

If the flag you want is `--dangerously-skip-permissions`, prefer the dedicated
`dangerously_skip_permissions` checkbox above so the warning banner is logged
on startup.

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