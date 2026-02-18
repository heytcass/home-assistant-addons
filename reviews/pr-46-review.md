## Code Review: PR #46 — Add tmux support for session persistence in Claude Terminal

**Verdict: Request changes** ❌

---

### Summary

Great motivation — navigating away from the terminal in HA kills the session, which is a real pain point. tmux is the right tool for this. The `tmux.conf` is well-crafted. However, the implementation has a **critical bug** in the session picker path and several other issues that need fixing before merge.

### Critical Issue: Nested tmux Sessions

When `auto_launch_claude=false` (session picker mode), the flow is:

1. `run.sh` starts ttyd with: `tmux new-session -A -s claude-picker '/usr/local/bin/claude-session-picker'`
2. The session picker runs **inside** that tmux session
3. User picks an option, which calls e.g. `launch_claude_new()`:
   ```bash
   tmux kill-session -t "$TMUX_SESSION_NAME" 2>/dev/null
   exec tmux new-session -s "$TMUX_SESSION_NAME" "claude"
   ```
4. **This fails** — tmux refuses to create nested sessions by default because `$TMUX` is already set inside the picker's tmux session

The session picker path is **broken** in this PR.

**Fix:** Don't wrap the session picker in tmux. Only wrap the final Claude invocation. In `run.sh`, the `auto_launch_claude=false` branch should run the picker directly, and the picker's launch functions should create the tmux session:

```bash
# In run.sh, for the session picker path:
ttyd_cmd="exec /usr/local/bin/claude-session-picker"
# NOT: tmux new-session -A -s claude-picker '...'
```

Or, detect that we're already in tmux and use `exec claude` directly:
```bash
if [ -n "$TMUX" ]; then
    exec claude
else
    exec tmux new-session -s "$TMUX_SESSION_NAME" "claude"
fi
```

### Issue: Multiple Browser Tabs

When multiple browser tabs connect to the same ttyd instance, they all attach to the same tmux session. tmux constrains the display to the **smallest** connected client, so a small tab will shrink the display for all tabs.

**Fix:** Add to `tmux.conf`:
```
setw -g aggressive-resize on
```

Or use `tmux attach -d` to detach the previous client when a new one connects (single-viewer mode).

### Issue: Duplicate tmux Installation

tmux is installed in the Dockerfile:
```dockerfile
RUN apk add --no-cache ... tmux \
```

And also in `install_tools()` at runtime:
```bash
apk add --no-cache ... tmux ...
```

The runtime install is redundant and wastes startup time. Remove `tmux` from `install_tools()` since it's already in the base image.

### Issue: `default-terminal $TERM` in tmux.conf

```
set-option -g default-terminal $TERM
```

This evaluates `$TERM` at tmux startup. If `$TERM` is unset or something unexpected (e.g., `dumb`), this will produce poor results. Better to hardcode:
```
set-option -g default-terminal "tmux-256color"
```

### Issue: Session Destroyed When Claude Exits

If a user accidentally types `/exit` or Claude crashes, the tmux session is destroyed (because the only command in the session was `claude`). The user loses the persistence benefit.

**Fix:** Fall through to a shell so the session survives:
```bash
exec tmux new-session -s "$TMUX_SESSION_NAME" "claude; exec bash"
```

Or use a wrapper that offers to restart:
```bash
exec tmux new-session -s "$TMUX_SESSION_NAME" "while true; do claude; echo 'Claude exited. Press Enter to restart or Ctrl+C to exit.'; read; done"
```

### Issue: Welcome Message Removed

The PR removes the welcome message that the current terminal shows on first launch. Minor UX regression — users lose the orientation message about what the add-on provides.

### What's Good

- **The `tmux.conf` is well-crafted** — OSC 52 clipboard, conditional mouse support for ttyd, large scrollback, vi keys
- **The reconnect option** (menu choice `0`) in the session picker is a nice UX touch
- **The `TTYD=1` env var** for conditional mouse behavior is a smart detail
- **The core concept is sound** — tmux is the right solution for this problem

### Verdict

The tmux approach is correct and the configuration is thoughtful, but the nested session bug makes the session picker completely non-functional. This needs a rework of how the picker and tmux sessions interact before it's mergeable.

### Suggested Fix Summary

1. **Fix the nesting bug** — don't wrap the session picker in tmux; only wrap the final Claude invocation
2. **Add `aggressive-resize on`** — handle multiple browser tabs gracefully
3. **Remove duplicate tmux install** from `install_tools()`
4. **Hardcode `default-terminal`** to `tmux-256color`
5. **Add shell fallback** so the session survives Claude exits
6. Consider restoring the welcome message
