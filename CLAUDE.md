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
2. **Auto-Resume Sessions**: Automatically continues most recent conversation (configurable)
3. **Git Integration**: Version control tools included for development workflows
4. **Credential Management**: Persistent authentication storage in `/data/.config/claude/`
5. **Service Integration**: Home Assistant ingress support with panel icon
6. **Multi-Architecture**: Supports amd64, aarch64, armv7 platforms

### Credential System
The add-on implements a sophisticated credential management system:
- **Persistent Storage**: Credentials saved to `/data/.config/claude/` (survives restarts)
- **XDG Compliance**: Uses XDG Base Directory specification for proper config management
- **Migration Support**: Automatically migrates from legacy credential locations
- **Security**: Proper file permissions (600) and safe directory operations

### Container Execution Flow
1. Initialize environment and create credential directories in `/data`
2. Install ttyd and tools via apk
3. Setup session picker and authentication helper scripts
4. Migrate any existing credentials from legacy locations
5. Launch ttyd web terminal with auto-resume or session picker

## Development Notes

### Local Container Testing
For rapid development and debugging without pushing new versions:

#### Quick Build & Test
```bash
# Build test version
podman build --build-arg BUILD_FROM=ghcr.io/home-assistant/amd64-base:3.19 -t local/claude-terminal:test ./claude-terminal

# Create test config directory
mkdir -p /tmp/test-config/claude-config

# Configure options (optional)
# Default: auto-launch with auto-resume enabled
echo '{"auto_launch_claude": true, "auto_resume_session": true}' > /tmp/test-config/options.json

# Or disable auto-resume to always start fresh sessions
# echo '{"auto_launch_claude": true, "auto_resume_session": false}' > /tmp/test-config/options.json

# Or use interactive session picker
# echo '{"auto_launch_claude": false}' > /tmp/test-config/options.json

# Run test container
podman run -d --name test-claude-dev -p 7681:7681 -v /tmp/test-config:/config local/claude-terminal:test

# Check logs
podman logs test-claude-dev

# Test web interface at http://localhost:7681

# Stop and cleanup
podman stop test-claude-dev && podman rm test-claude-dev
```

#### Interactive Testing
```bash
# Test session picker directly
podman run --rm -it local/claude-terminal:test /opt/scripts/claude-session-picker.sh

# Execute commands inside running container
podman exec -it test-claude-dev /bin/bash

# Test script modifications without rebuilding
podman cp ./claude-terminal/scripts/claude-session-picker.sh test-claude-dev:/opt/scripts/
podman exec test-claude-dev chmod +x /opt/scripts/claude-session-picker.sh
```

#### Development Workflow
1. **Make changes** to scripts or Dockerfile
2. **Rebuild** with `podman build -t local/claude-terminal:test ./claude-terminal`
3. **Stop/remove** old container: `podman stop test-claude-dev && podman rm test-claude-dev`
4. **Start new** container with updated image
5. **Test** changes at http://localhost:7681
6. **Repeat** until satisfied, then commit and push

#### Debugging Tips
- **Check container logs**: `podman logs -f test-claude-dev` (follow mode)
- **Inspect running processes**: `podman exec test-claude-dev ps aux`
- **Test individual scripts**: `podman exec test-claude-dev /opt/scripts/script-name.sh`
- **Volume contents**: `ls -la /tmp/test-config/` to verify persistence

### Production Testing
- **Local Testing**: Use `run-addon` to test on localhost:7681
- **Container Health**: Check logs with `podman logs <container-id>`
- **Authentication**: Use `claude-auth debug` within terminal for credential troubleshooting

### File Conventions
- **Shell Scripts**: Use `#!/usr/bin/with-contenv bashio` for add-on scripts
- **Indentation**: 2 spaces for YAML, 4 spaces for shell scripts
- **Error Handling**: Use `bashio::log.error` for error reporting
- **Permissions**: Credential files must have 600 permissions

### Key Environment Variables
- `ANTHROPIC_CONFIG_DIR=/data/.config/claude`
- `XDG_CONFIG_HOME=/data/.config`
- `XDG_CACHE_HOME=/data/.cache`
- `XDG_STATE_HOME=/data/.local/state`
- `HOME=/data/home`

### Important Constraints
- No sudo privileges available in development environment
- Add-on targets Home Assistant OS (Alpine Linux base)
- Must handle credential persistence across container restarts
- Requires multi-architecture compatibility