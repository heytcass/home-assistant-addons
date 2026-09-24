# Development Guide

This guide covers local development and testing workflows for the Claude Terminal add-on.

## Local Container Testing

### Prerequisites

- **Podman** (or Docker) installed
- **Git** repository cloned locally
- **NixOS development environment** (optional, for `nix develop`)

### Quick Start Testing

The fastest way to test changes without publishing new versions:

```bash
# 1. Build test container
podman build --build-arg BUILD_FROM=ghcr.io/home-assistant/amd64-base:3.21 \
  -t local/claude-terminal:test ./claude-terminal

# 2. Create test configuration (options.json lives in /data inside a real add-on)
mkdir -p /tmp/test-config /tmp/test-data
echo '{"auto_launch_claude": false}' > /tmp/test-data/options.json

# 3. Run test container
podman run -d --name test-claude-dev \
  -p 7681:7681 \
  -v /tmp/test-config:/config \
  -v /tmp/test-data:/data \
  local/claude-terminal:test

# 4. Check startup logs
podman logs test-claude-dev

# 5. Test in browser: http://localhost:7681

# 6. Clean up when done
podman stop test-claude-dev && podman rm test-claude-dev
```

### Development Workflow

#### 1. Iterative Development

```bash
# Make changes to code
vim claude-terminal/run.sh

# Rebuild image
podman build --build-arg BUILD_FROM=ghcr.io/home-assistant/amd64-base:3.21 \
  -t local/claude-terminal:test ./claude-terminal

# Stop old container
podman stop test-claude-dev && podman rm test-claude-dev

# Start new container with changes
podman run -d --name test-claude-dev -p 7681:7681 \
  -v /tmp/test-config:/config local/claude-terminal:test

# Test changes
open http://localhost:7681
```

#### 2. Hot-reload Script Testing

For script changes without full rebuilds:

```bash
# Copy updated script to running container
podman cp ./claude-terminal/scripts/welcome.sh \
  test-claude-dev:/opt/scripts/welcome.sh

# Make executable
podman exec test-claude-dev chmod +x /opt/scripts/welcome.sh

# Test directly
podman exec -it test-claude-dev /opt/scripts/welcome.sh
```

### Testing Scenarios

#### Launch Mode Testing

```bash
# Shell mode (banner + bash instead of auto-launching Claude)
echo '{"auto_launch_claude": false}' > /tmp/test-data/options.json

# Auto-launch mode (default)
echo '{"auto_launch_claude": true}' > /tmp/test-data/options.json
# OR
rm /tmp/test-data/options.json
```

#### Authentication Testing

```bash
# Start with clean credentials (credentials persist in /data)
rm -rf /tmp/test-data/.config/claude /tmp/test-data/home/.claude
```

#### Multi-session Testing

```bash
# Run multiple containers on different ports
podman run -d --name test-claude-dev-8681 -p 8681:7681 -v /tmp/test-config-2:/config local/claude-terminal:test
podman run -d --name test-claude-dev-9681 -p 9681:7681 -v /tmp/test-config-3:/config local/claude-terminal:test
```

### Debugging Techniques

#### Container Inspection

```bash
# Follow logs in real-time
podman logs -f test-claude-dev

# Execute shell inside container
podman exec -it test-claude-dev /bin/bash

# Check running processes
podman exec test-claude-dev ps aux

# Inspect environment variables
podman exec test-claude-dev env | grep CLAUDE
```

#### Script Debugging

```bash
# Test scripts with debug output
podman exec -it test-claude-dev bash -x /opt/scripts/welcome.sh

# Run on-demand diagnostics
podman exec test-claude-dev /usr/local/bin/claude-doctor

# Check file permissions and locations
podman exec test-claude-dev ls -la /opt/scripts/
podman exec test-claude-dev ls -la /data/
```

#### Network Testing

```bash
# Test web endpoint
curl -I http://localhost:7681

# Test WebSocket connection
curl --include --no-buffer \
  --header "Connection: Upgrade" \
  --header "Upgrade: websocket" \
  --header "Sec-WebSocket-Key: SGVsbG8sIHdvcmxkIQ==" \
  --header "Sec-WebSocket-Version: 13" \
  http://localhost:7681/ws
```

### Performance Testing

#### Resource Usage

```bash
# Monitor container resources
podman stats test-claude-dev

# Check container size
podman images local/claude-terminal:test

# Inspect layers
podman history local/claude-terminal:test
```

#### Load Testing

```bash
# Multiple concurrent connections
for i in {1..5}; do
  curl http://localhost:7681 &
done
wait
```

### Common Issues & Solutions

#### Port Already In Use
```bash
# Find and kill process using port 7681
sudo lsof -ti:7681 | xargs kill -9

# Or use different port
podman run -d --name test-claude-dev -p 7682:7681 -v /tmp/test-config:/config local/claude-terminal:test
```

#### Volume Mount Issues
```bash
# Ensure directories exist and have correct permissions
mkdir -p /tmp/test-config /tmp/test-data
chmod 755 /tmp/test-config /tmp/test-data

# Check SELinux labels (if applicable)
ls -laZ /tmp/test-config/
```

#### Build Cache Issues
```bash
# Force rebuild without cache
podman build --no-cache --build-arg BUILD_FROM=ghcr.io/home-assistant/amd64-base:3.21 \
  -t local/claude-terminal:test ./claude-terminal

# Clean up unused images
podman image prune
```

### Cleanup Commands

#### Clean Up Test Environment
```bash
# Stop and remove test containers
podman stop test-claude-dev && podman rm test-claude-dev

# Remove test configurations
rm -rf /tmp/test-config*

# Clean up test images
podman rmi local/claude-terminal:test
```

#### Full System Cleanup
```bash
# Remove all stopped containers
podman container prune

# Remove unused images
podman image prune

# Remove unused volumes
podman volume prune
```

## Testing on a real Home Assistant box

The container tests above prove the image builds and boots, but not how it
behaves under a real Supervisor (ingress, bashio reading real options, the
Supervisor API, OAuth in a real browser, backups). Before any release, run
the change on your own Home Assistant as a **local add-on**, next to the
released one:

```bash
# Push the working tree to HA over SSH (Advanced SSH add-on with protection
# mode off, or the HA OS host on port 22222 — both expose /addons)
scripts/dev-deploy.sh root@homeassistant.local

# Or just build the folder and copy it yourself (Samba: \\homeassistant\addons)
scripts/dev-deploy.sh
```

Then in HA: **Settings → Add-ons → Add-on Store → ⋮ → Check for updates**, and
install (or update) **Claude Terminal (dev)**. It has its own slug, its own
`/data`, and its own sidebar entry, so the released add-on is untouched.
The script strips the `image:` key so the Supervisor builds locally from
your Dockerfile, and suffixes the version with the git sha so every deploy
registers as an update. Uninstall it from the store when you are done.

### Pre-release checklist

- Fresh install: log in, Claude starts, `claude-doctor` is clean, MCP tools work.
- Upgrade path: install the *previous* release as the dev add-on first, log
  in, then deploy the new build over it. Credentials and the session must
  survive without a re-login.
- Restart the add-on twice and reload the browser: the same tmux session
  comes back.
- Toggle every option the change touches, both ways, reading the add-on log
  each time.
- Take a backup and check its size did not grow (see #103, #114).

## Releasing

Merging to `main` ships **nothing** to users. Home Assistant installs pull the
GHCR image tagged with the `version:` in `config.yaml`, and that image is only
built when a matching `v<version>` tag is pushed (`release.yml`). So PRs can
land on `main` freely; a release is a separate, deliberate step:

```bash
# 1. Release commit on main: version bump + CHANGELOG entry, nothing else
vim claude-terminal/config.yaml     # version: "x.y.z"
vim claude-terminal/CHANGELOG.md    # ## x.y.z section at the top
git commit -am "chore(claude-terminal): release x.y.z"
git push origin main

# 2. Tag it — this is what builds and publishes
git tag vx.y.z
git push origin vx.y.z
```

`release.yml` refuses a tag that does not match `config.yaml`, builds and
pushes both architecture images, and only then creates the GitHub release
with the matching `CHANGELOG.md` section as its body. Users see the update
in the add-on store once the Supervisor next refreshes the repository
(within the hour, or immediately via *Check for updates*).

To rebuild the images for the current version without a new release (e.g. a
base-image security fix), run `release.yml` manually from the Actions tab.

## Advanced Testing

### Integration with Home Assistant

```bash
# Test with real Home Assistant config structure
mkdir -p /tmp/ha-config/.storage /tmp/ha-data
echo '{"auto_launch_claude": false}' > /tmp/ha-data/options.json

podman run -d --name test-ha-claude -p 7681:7681 \
  -v /tmp/ha-config:/config -v /tmp/ha-data:/data local/claude-terminal:test
```

### Cross-Platform Testing

```bash
# Test the other supported base image (armv7 was dropped in 2.5.0 — see the
# arch list in config.yaml)
podman build --build-arg BUILD_FROM=ghcr.io/home-assistant/aarch64-base:3.21 \
  -t local/claude-terminal:arm64 ./claude-terminal
```