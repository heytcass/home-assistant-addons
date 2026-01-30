# Claude Terminal API Reference

Complete API documentation for programmatic access to Claude from Home Assistant and external services.

## Quick Start

### 1. Enable the API
Configure in add-on settings:
```yaml
api_enabled: true
api_timeout: 300
```

### 2. Test the Health Endpoint
```bash
curl http://localhost:7682/api/health
```

### 3. Execute Your First Prompt
```bash
curl -X POST http://localhost:7682/api/claude   -H "Content-Type: application/json"   -d '{"prompt":"Say hello"}'
```

## API Endpoints

### POST /api/claude
Execute a Claude prompt and return the response.

**URL:** `http://localhost:7682/api/claude`
**Method:** `POST`
**Content-Type:** `application/json`

**Request Parameters:**
- `prompt` (required): The prompt to send to Claude (max 50KB)
- `options.model` (optional): Claude model to use
- `options.timeout` (optional): Timeout in seconds (1-600, default: 300)

**Success Response (200):**
```json
{
  "success": true,
  "output": "Claude's response",
  "execution_time": 2.34,
  "model": "claude-opus-4-5-20251101"
}
```

**Error Responses:**
- 400: Invalid request (validation error)
- 500: Server error (execution/authentication error)
- 504: Timeout

### GET /api/health
Health check endpoint.

**Response:**
```json
{
  "status": "ok",
  "version": "1.7.0",
  "claude_available": true,
  "uptime": 3600.5
}
```

## Home Assistant Integration

### REST Command
```yaml
rest_command:
  claude_prompt:
    url: "http://localhost:7682/api/claude"
    method: POST
    content_type: "application/json"
    payload: >
      {
        "prompt": "{{ prompt }}",
        "options": {"timeout": {{ timeout | default(60) }}}
      }
```

### Example Automation
```yaml
automation:
  - alias: "Daily Claude Briefing"
    trigger:
      - platform: time
        at: "08:00:00"
    action:
      - service: rest_command.claude_prompt
        data:
          prompt: "Give me a brief morning briefing"
```

## Python Example
```python
import requests

response = requests.post(
    'http://localhost:7682/api/claude',
    json={"prompt": "Hello Claude", "options": {"timeout": 60}}
)

if response.json()['success']:
    print(response.json()['output'])
```

## Security

- Port 7682 NOT exposed externally by default
- No authentication (relies on network isolation)
- Access via Home Assistant internal network
- Input validation and timeout enforcement

## Troubleshooting

**API not responding:**
- Check: `curl http://localhost:7682/api/health`
- View logs: `/config/api-server.log`
- Verify: Add-on configuration has `api_enabled: true`

**Timeout errors:**
- Increase timeout in request or configuration
- Complex prompts may need 120+ seconds

**Authentication errors:**
- Authenticate Claude in terminal first
- Run `claude --help` to test

## Performance

Typical response times:
- Simple questions: 2-5 seconds
- Code generation: 5-15 seconds
- Complex analysis: 15-30 seconds

Resource usage:
- API server: ~50MB RAM
- Per request: ~100-200MB RAM

## Version History

### v1.7.0
- Initial HTTP API implementation
- POST /api/claude and GET /api/health endpoints
- Configurable timeouts and model selection
