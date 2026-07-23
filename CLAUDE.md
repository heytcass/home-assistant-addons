# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains Home Assistant add-ons, specifically the **Claude Terminal** add-on: Claude Code CLI in a browser terminal (ttyd + tmux), as a Home Assistant add-on. The design goal is to stay thin — the add-on's job is running Claude Code reliably, not wrapping it in extra UI.

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
podman build --build-arg BUILD_FROM=ghcr.io/home-assistant/amd64-base:3.21 -t local/claude-terminal ./claude-terminal

# Run locally
podman run -p 7681:7681 -v $(pwd)/config:/config local/claude-terminal

# Lint
hadolint ./claude-terminal/Dockerfile
shellcheck -s bash -e SC1008 -e SC1091 claude-terminal/run.sh claude-terminal/scripts/*.sh

# Test endpoint
curl -X GET http://localhost:7681/
```

## Architecture

### Add-on Structure (claude-terminal/)
- **config.yaml** - Home Assistant add-on configuration (options schema, ingress, volume maps)
- **Dockerfile** - Alpine-based image; all runtime packages (ttyd, tmux, nodejs, uv, ...) are baked in so startup never depends on the network
- **build.yaml** - Multi-architecture build configuration (amd64, aarch64); images are prebuilt on GHCR and pulled by the Supervisor
- **run.sh** - Startup script: environment/persistence setup, background Claude auto-update, ttyd launch
- **scripts/** - Support scripts copied to `/opt/scripts/` (welcome banner, health check, HA context, MCP setup, persist-install, tmux config)

### Container Execution Flow
1. `init_environment` — point HOME/XDG at `/data` (persistent), prepend `/data/home/.local/bin` to PATH, clean legacy npm cache, migrate old credentials
2. `setup_commands` — install `welcome`, `persist-install`, `ha-context`, `claude-doctor` into `/usr/local/bin`
3. `update_claude` — background install/update of the native Claude Code build into `/data` (skipped when `claude_auto_update: false`)
4. `install_persistent_packages` — user-configured apk/pip packages
5. `generate_ha_context` — background CLAUDE.md generation via Supervisor API
6. `setup_ha_mcp` — register ha-mcp with `claude mcp add`
7. `start_web_terminal` — `exec ttyd ... tmux new-session -A -s claude 'claude [flags]'` (or a plain shell when `auto_launch_claude: false`)

### Key Design Rules
- **Nothing on the boot path may hit the network or block on input.** Network work (updates, context generation) is backgrounded; packages ship in the image.
- **Everything persistent lives in `/data`** (HOME is `/data/home`). The container filesystem is recreated on every restart.
- **Two Claude copies exist**: the native musl binary baked into the image at `/usr/local/bin/claude` (fallback, frozen at build time, fetched straight from the npm registry — no npm/Node during build, which crashes under QEMU in aarch64 CI builds) and the native install in `/data/home/.local/bin` (persists, self-updates, wins via PATH).
- **No custom session UI.** tmux `new-session -A` handles reconnects; Claude Code's own `-c`/`-r` handle continue/resume.

## Development Notes

### Local Container Testing
```bash
# Build test version
podman build --build-arg BUILD_FROM=ghcr.io/home-assistant/amd64-base:3.21 -t local/claude-terminal:test ./claude-terminal

# Run test container (options.json lives in /data inside a real add-on)
mkdir -p /tmp/test-data
echo '{"auto_launch_claude": false}' > /tmp/test-data/options.json
podman run -d --name test-claude-dev -p 7681:7681 \
  -v /tmp/test-config:/config -v /tmp/test-data:/data local/claude-terminal:test

# Check logs / test at http://localhost:7681
podman logs -f test-claude-dev

# Hot-reload a script without rebuilding
podman cp ./claude-terminal/scripts/welcome.sh test-claude-dev:/opt/scripts/
podman exec test-claude-dev chmod +x /opt/scripts/welcome.sh

# Stop and cleanup
podman stop test-claude-dev && podman rm test-claude-dev
```

Note: `bashio::config` reads `/data/options.json`; outside a real Supervisor environment bashio calls may fall back to defaults.

### Production Testing
- **Local Testing**: Use `run-addon` to test on localhost:7681
- **Container Health**: Check logs with `podman logs <container-id>`
- **Diagnostics**: Run `claude-doctor` inside the terminal for environment/network checks

### File Conventions
- **Shell Scripts**: `#!/usr/bin/with-contenv bashio` for boot-path scripts; plain `#!/bin/bash` for scripts that run inside the user's terminal (no bashio there)
- **Indentation**: 2 spaces for YAML, 4 spaces for shell scripts
- **Error Handling**: Use `bashio::log.error` for error reporting; never let a non-essential step kill startup
- **Permissions**: Credential files must have 600 permissions
- **CI**: shellcheck (warning severity) and hadolint (error threshold) run on PRs; keep both clean

### Key Environment Variables (set by run.sh / Dockerfile)
- `HOME=/data/home`
- `ANTHROPIC_CONFIG_DIR=/data/.config/claude`
- `IS_SANDBOX=1` (image env — allows `--dangerously-skip-permissions` as root)
- `npm_config_cache=/tmp/npm-cache` (image env — keeps caches out of HA backups)

### Important Constraints
- Add-on targets Home Assistant OS (Alpine Linux base); amd64 + aarch64 only (32-bit ARM dropped in 2.5.0)
- Must handle credential/session persistence across container restarts
- `/data` is included in HA backups — never let caches or reproducible artifacts accumulate there
