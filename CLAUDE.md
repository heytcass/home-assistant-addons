# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains Home Assistant add-ons, specifically the **Claude Terminal** add-on which provides a web-based terminal interface with Claude Code CLI pre-installed. The add-on allows Home Assistant users to access Claude AI capabilities directly from their dashboard.

## Development Environment

### Setup
```bash
# Enter the development shell (NixOS/Nix)
nix develop

# Or with direnv (if installed)
direnv allow
```

### Core Development Commands
- `build-addon` - Build the Claude Terminal add-on with Podman
- `run-addon` - Run add-on locally on port 7681 with volume mapping
- `lint-dockerfile` - Lint Dockerfile using hadolint
- `test-endpoint` - Test web endpoint availability (curl localhost:7681)

### Manual Commands (without aliases)
```bash
# Build
podman build --build-arg BUILD_FROM=ghcr.io/home-assistant/amd64-base:3.19 -t local/claude-terminal ./claude-terminal

# Run locally
podman run -p 7681:7681 -v $(pwd)/config:/config local/claude-terminal

# Lint
hadolint ./claude-terminal/Dockerfile

# Test endpoint
curl -X GET http://localhost:7681/
```

## Architecture

### Add-on Structure (claude-terminal/)
- **config.yaml** - Home Assistant add-on configuration (multi-arch, ingress, ports)
- **Dockerfile** - Alpine-based container with Node.js and Claude Code CLI
- **build.yaml** - Multi-architecture build configuration (amd64, aarch64, armv7)
- **run.sh** - Main startup script with credential management and ttyd terminal
- **scripts/** - Modular credential management scripts

### Key Components
1. **Web Terminal**: Uses ttyd to provide browser-based terminal access
2. **Credential Management**: Persistent authentication storage in `/config/claude-config/`
3. **Service Integration**: Home Assistant ingress support with panel icon
4. **Multi-Architecture**: Supports amd64, aarch64, armv7 platforms

### Credential System
The add-on implements a sophisticated credential management system:
- **Persistent Storage**: Credentials saved to `/config/claude-config/` (survives restarts)
- **Multiple Locations**: Handles various Claude credential file locations
- **Background Service**: Continuous credential monitoring and saving
- **Security**: Proper file permissions (600) and safe directory operations

### Container Execution Flow
1. Initialize environment and create credential directories
2. Install ttyd and tools via apk
3. Setup modular credential management scripts
4. Start background credential monitoring service
5. Launch ttyd web terminal with Claude auto-start

## Development Notes

### Testing
- **Local Testing**: Use `run-addon` to test on localhost:7681
- **Container Health**: Check logs with `podman logs <container-id>`
- **Authentication**: Use `claude-auth debug` within terminal for credential troubleshooting

### File Conventions
- **Shell Scripts**: Use `#!/usr/bin/with-contenv bashio` for add-on scripts
- **Indentation**: 2 spaces for YAML, 4 spaces for shell scripts
- **Error Handling**: Use `bashio::log.error` for error reporting
- **Permissions**: Credential files must have 600 permissions

### Key Environment Variables
- `CLAUDE_CREDENTIALS_DIRECTORY=/config/claude-config`
- `ANTHROPIC_CONFIG_DIR=/config/claude-config`
- `HOME=/root`

### Important Constraints
- No sudo privileges available in development environment
- Add-on targets Home Assistant OS (Alpine Linux base)
- Must handle credential persistence across container restarts
- Requires multi-architecture compatibility