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

The add-on works out of the box with sensible defaults. Optional configuration options:

### Configuration Options

- **auto_launch_claude** (default: `true`): Automatically launch Claude when opening the terminal
  - Set to `false` to show an interactive session picker menu instead
- **auto_resume_session** (default: `true`): Automatically resume your most recent conversation
  - Set to `false` to always start new sessions
  - Only applies when `auto_launch_claude` is enabled

### Authentication

The add-on uses OAuth authentication. On first use, you'll be prompted to log in to your Anthropic account.

Your OAuth credentials are stored in the `/data/.config/claude/` directory and will persist across add-on updates and restarts, so you won't need to log in again.

## Usage

Claude launches automatically when you open the terminal. You can also start Claude manually with:

```bash
node /usr/local/bin/claude
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
- **Auto-Resume Sessions**: Automatically continues your most recent conversation when reopening the terminal
- **Auto-Launching**: Claude starts automatically when you open the terminal
- **Git Integration**: Version control tools included for repository management
- **Claude AI**: Access Claude's AI capabilities for programming, troubleshooting and more
- **Direct Config Access**: Terminal starts in `/config` for immediate access to all Home Assistant files
- **Simple Setup**: Uses OAuth for easy authentication
- **Interactive Session Picker**: Choose between new session, continue, resume, or custom commands
- **Home Assistant Integration**: Access directly from your dashboard

## Troubleshooting

- If Claude doesn't start automatically, try running `node /usr/local/bin/claude -i` manually
- If you see permission errors, try restarting the add-on
- If you have authentication issues, try logging out and back in
- Check the add-on logs for any error messages

## Credits

This add-on was created with the assistance of Claude Code itself! The development process, debugging, and documentation were all completed using Claude's AI capabilities - a perfect demonstration of what this add-on can help you accomplish.