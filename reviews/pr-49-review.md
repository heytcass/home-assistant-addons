## Code Review: PR #49 — feat: Bundle ha-mcp for Home Assistant MCP integration

**Verdict: Approve with changes requested** 🔶

---

### Summary

The most impactful PR in the queue. Bundles [homeassistant-ai/ha-mcp](https://github.com/homeassistant-ai/ha-mcp) as an MCP server so Claude Code can control Home Assistant entities via natural language. Adds `uv` package manager, a setup script, config toggle, comprehensive docs, and a version bump to 1.7.0.

### What's Good

- **Excellent documentation** — DOCS.md and CHANGELOG additions are thorough
- **Clean config handling** — `bool?` schema type means existing installs won't break, double-default pattern (`options` + `bashio::config` fallback) is defensive
- **Proper guard clauses** — checks for `SUPERVISOR_TOKEN`, `uvx` availability, and config flag before proceeding
- **Good error handling** — failures in MCP setup don't block the terminal from starting

### Issues to Address

#### 1. **Split the workflow change into a separate PR** (High)

This PR includes the `pull_request` → `pull_request_target` change from PR #54. Mixing a security-sensitive CI change into a feature PR makes review harder and creates a merge conflict with #54. Remove the `.github/workflows/claude-code-review.yml` changes and let #54 handle that independently.

#### 2. **`ha-mcp@latest` is unpinned** (Medium)

```bash
uvx ha-mcp@latest
```

Every container restart pulls whatever version is newest. A breaking upstream change silently breaks the add-on. Consider:
- `ha-mcp@^6` — allows minor/patch updates, guards against major breaks
- Or pin to a specific version and update deliberately

#### 3. **`set -e` leaks from sourced script** (Medium)

`setup-ha-mcp.sh` has `set -e` at line 7. Since `run.sh` *sources* this script (not executes it), the `set -e` leaks into the parent shell, potentially causing unexpected failures in subsequent `run.sh` commands.

**Fix option A** — Remove `set -e` from `setup-ha-mcp.sh` (the parent shell manages error handling).

**Fix option B** — Execute instead of sourcing:
```bash
setup_ha_mcp() {
    if [ -f "/opt/scripts/setup-ha-mcp.sh" ]; then
        bashio::log.info "Setting up Home Assistant MCP integration..."
        /opt/scripts/setup-ha-mcp.sh || bashio::log.warning "ha-mcp setup encountered issues..."
    fi
}
```

This also makes the `BASH_SOURCE` guard at the bottom of the script actually work.

#### 4. **No check for `claude` CLI availability** (Low)

If Claude CLI hasn't been installed or initialized yet, `claude mcp remove` and `claude mcp add` will fail. Add a guard:
```bash
if ! command -v claude &> /dev/null; then
    bashio::log.warning "Claude CLI not found - ha-mcp setup skipped"
    return 0
fi
```

#### 5. **Network dependency at startup** (Low)

`uvx ha-mcp@latest` downloads the package and Python 3.13 on first run. If the network is slow or unavailable, the first MCP invocation will hang/fail. Consider pre-caching during Docker build:
```dockerfile
RUN uvx --python 3.13 ha-mcp@latest --help || true
```
This warms the cache so startup is instant.

#### 6. **armv7 compatibility unknown** (Low)

The add-on's `build.yaml` lists armv7 as supported. `uv` may not have armv7 binaries — the install script could fail silently. Should verify or document this limitation.

### Minor Nits

- `chmod +x /opt/scripts/setup-ha-mcp.sh` in `run.sh` is redundant — the Dockerfile already does `chmod +x /opt/scripts/*.sh`
- The `SUPERVISOR_TOKEN` is stored in the MCP config file (via `claude mcp add --env`). Not a new attack surface (the token is already in the environment), but worth understanding
- `http://supervisor/core` uses plain HTTP — this is expected for internal Supervisor API communication

### Verdict

Strong feature that fills a real need. The main blockers are (1) splitting out the workflow change and (2) fixing the `set -e` leak. The version pinning and pre-caching are strongly recommended but not blockers.
