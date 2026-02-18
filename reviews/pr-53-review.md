## Code Review: PR #53 — fix: resolve native install path mismatch when HOME=/data/home (v1.6.1)

**Verdict: Approve** ✅ (with minor suggestions)

---

### Summary

Clean, well-targeted bug fix. The native installer places Claude at `/root/.local/bin/claude` during Docker build, but at runtime `HOME=/data/home`, so Claude's internal self-check fails with *"installMethod is native, but directory does not exist"*. The symlink approach is the correct fix.

### What's Good

- **Guard conditions are solid** — checks that `/root/.local/bin/claude` exists AND that the target doesn't already exist before creating the symlink
- **Handles broken symlinks** — `ln -sf` will overwrite stale symlinks
- **Correct placement** — the symlink is created *before* `export HOME="$data_home"`, which is exactly right
- **Version bump** 1.6.0 → 1.6.1 is correct semver for a patch fix

### Suggestions

1. **Add a fallback log if the source binary is missing:**
   ```bash
   if [ -f /root/.local/bin/claude ] && [ ! -f "$native_bin_dir/claude" ]; then
       ln -sf /root/.local/bin/claude "$native_bin_dir/claude"
       bashio::log.info "  - Claude native binary linked: $native_bin_dir/claude"
   elif [ ! -f /root/.local/bin/claude ]; then
       bashio::log.warning "  - Claude native binary not found at /root/.local/bin/claude"
   fi
   ```
   This would help diagnose cases where the Docker build itself failed to install Claude.

2. **Consider also adding the directory to PATH** as belt-and-suspenders:
   ```bash
   export PATH="$native_bin_dir:$PATH"
   ```
   This ensures `which claude` works from the runtime HOME context even if something else resolves the binary differently.

3. **Minor: CHANGELOG entry is missing a date** — prior entries use the `## X.Y.Z - YYYY-MM-DD` format. Adding a date keeps it consistent.

### Verdict

This is a clean, focused fix for a concrete regression. The approach is sound and the risk is minimal. Approve with the nits above optionally addressed.
