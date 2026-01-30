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
- **HTTP API**: Programmatic access to Claude from Home Assistant automations
- **Claude AI**: Access Claude's AI capabilities for programming, troubleshooting and more
- **Direct Config Access**: Terminal starts in `/config` for immediate access to all Home Assistant files
- **Simple Setup**: Uses OAuth for easy authentication
- **Home Assistant Integration**: Access directly from your dashboard

## HTTP API

Claude Terminal provides a REST API for programmatic access to Claude from Home Assistant automations, scripts, and external services.

### Configuration

Configure the API in the add-on settings:

```yaml
api_enabled: true       # Enable/disable API (default: true)
api_timeout: 300        # Default timeout in seconds (default: 300, max: 600)
```

**Note:** Port 7682 is NOT exposed externally by default. To access the API from outside your network, you must explicitly expose the port in the add-on configuration.

### API Endpoints

#### POST /api/claude

Execute a Claude prompt and return the response.

**Request:**
```json
{
  "prompt": "What is Home Assistant?",
  "options": {
    "model": "claude-opus-4-5-20251101",
    "timeout": 60
  }
}
```

**Response (Success):**
```json
{
  "success": true,
  "output": "Home Assistant is an open-source home automation platform...",
  "execution_time": 2.34,
  "model": "claude-opus-4-5-20251101"
}
```

**Response (Error):**
```json
{
  "success": false,
  "error": "Request exceeded 60s timeout",
  "error_type": "timeout"
}
```

#### GET /api/health

Check API server health status.

**Response:**
```json
{
  "status": "ok",
  "version": "1.7.0",
  "claude_available": true,
  "uptime": 3600.5
}
```

### Home Assistant Integration

#### Using rest_command

Add to your `configuration.yaml`:

```yaml
rest_command:
  ask_claude:
    url: "http://localhost:7682/api/claude"
    method: POST
    content_type: "application/json"
    payload: >
      {
        "prompt": "{{ prompt }}",
        "options": {
          "timeout": {{ timeout | default(60) }}
        }
      }
```

#### Example Automation

Ask Claude for a weather summary each morning:

```yaml
automation:
  - alias: "Morning Weather Summary from Claude"
    trigger:
      - platform: time
        at: "07:00:00"
    action:
      - service: rest_command.ask_claude
        data:
          prompt: "Based on today's forecast, give me a brief weather summary for New York"
      - service: notify.mobile_app
        data:
          message: "Claude's weather summary: Check the logs"
```

#### RESTful Sensor

Monitor Claude API availability:

```yaml
sensor:
  - platform: rest
    name: Claude API Status
    resource: http://localhost:7682/api/health
    method: GET
    value_template: "{{ value_json.status }}"
    json_attributes:
      - version
      - claude_available
      - uptime
    scan_interval: 60
```

#### Advanced Example with Template Response

Create a script that uses Claude's response:

```yaml
script:
  ask_claude_about_automation:
    alias: "Ask Claude About Automation"
    sequence:
      - service: rest_command.ask_claude
        data:
          prompt: >
            Review this Home Assistant automation and suggest improvements:
            {{ states.automation.my_automation.attributes.configuration | tojson }}
        response_variable: claude_response
      - service: persistent_notification.create
        data:
          title: "Claude's Automation Review"
          message: "{{ claude_response.content.output }}"
```

### API Security

- The API binds to 0.0.0.0:7682 for flexibility
- **Port 7682 is NOT exposed externally by default** - you must explicitly add it
- Access is typically via Home Assistant's internal network only
- Consider network security carefully before exposing the port externally
- No authentication is required (relies on network isolation)

### Troubleshooting API

**API not responding:**
1. Check if API is enabled in add-on configuration
2. View logs in add-on interface or at `/config/api-server.log`
3. Test health endpoint: `curl http://localhost:7682/api/health`
4. Verify Claude is authenticated in the terminal

**Timeout errors:**
1. Increase timeout in request options or configuration
2. Complex prompts may take longer - adjust timeout accordingly
3. Check network connectivity to api.anthropic.com

**Authentication errors:**
1. Ensure Claude is authenticated (open terminal and run `claude`)
2. Check authentication status: `/config/.config/claude/`
3. Re-authenticate if necessary

### Example: Using with Node-RED

If you use Node-RED in Home Assistant:

1. Add an HTTP Request node
2. Configure:
   - Method: POST
   - URL: `http://localhost:7682/api/claude`
   - Payload:
     ```json
     {
       "prompt": "{{payload.question}}",
       "options": {"timeout": 60}
     }
     ```
3. Parse the JSON response and use `msg.payload.output`

## Troubleshooting

- If Claude doesn't start automatically, try running `claude -i` manually
- If you see permission errors, try restarting the add-on
- If you have authentication issues, try logging out and back in
- Check the add-on logs for any error messages

## Credits

This add-on was created with the assistance of Claude Code itself! The development process, debugging, and documentation were all completed using Claude's AI capabilities - a perfect demonstration of what this add-on can help you accomplish.