# Security Policy

## Overview

This document outlines the security measures implemented in the Claude Terminal add-on and provides guidance for secure deployment.

## Security Fixes Implemented

### Critical Vulnerabilities Fixed (v1.4.2+)

#### 1. Command Injection Prevention
**Location**: `claude-terminal/scripts/claude-session-picker.sh`, `config/scripts/claude-session-picker.sh`

**Issue**: User input was passed directly to `eval`, allowing arbitrary command execution.

**Fix**:
- Removed `eval` usage
- Added input validation with allowlist of safe characters
- Implemented pattern matching to block shell operators (`;`, `&&`, `||`, `$()`, etc.)
- Safe argument passing without shell expansion

**Impact**: Prevents remote code execution via terminal session picker.

---

#### 2. Secure Credential Storage
**Location**: `claude-terminal/scripts/claude-auth-helper.sh`

**Issue**: Authentication codes written to world-readable `/tmp/claude-auth-code`.

**Fix**:
- Use `mktemp` to create secure temporary files with unique names
- Set restrictive permissions (600) on all credential files
- Implement trap handler for guaranteed cleanup on exit
- Secure file deletion (overwrite before removal)
- Validate file permissions before reading credentials

**Impact**: Prevents credential theft by other processes.

---

#### 3. Restrictive File Permissions
**Location**: `claude-terminal/run.sh`

**Issue**: Directories created with world-readable permissions (755), credential files accessible to all users.

**Fix**:
- Changed directory permissions from 755 to 700 (owner-only access)
- Ensure all credential files have 600 permissions
- Apply security permissions immediately after directory creation
- Recursive permission fixing for existing credentials

**Impact**: Prevents unauthorized access to Claude credentials and configuration.

---

#### 4. TOCTOU Race Condition Prevention
**Location**: `claude-terminal/run.sh`

**Issue**: Directory deletion followed by symlink creation allowed race condition attacks.

**Fix**:
- Skip migration from `/tmp` sources (symlink attack prevention)
- Verify paths are real directories, not symlinks
- Use atomic operations (create temp symlink, then atomic move)
- Set secure permissions BEFORE any cleanup operations
- Added symlink validation checks

**Impact**: Prevents privilege escalation via symlink attacks.

---

### High-Severity Improvements

#### 5. Reduced Home Assistant Permissions
**Location**: `claude-terminal/config.yaml`

**Changes**:
- Reduced `hassio_role` from `manager` to `default`
- Disabled `homeassistant_api` (was: true)
- Disabled `auth_api` (was: true)
- Added documentation for when elevated permissions are needed

**Impact**: Follows principle of least privilege, reduces attack surface.

**Note**: If you need elevated API access for advanced use cases, you can re-enable:
```yaml
hassio_role: manager           # For add-on management
homeassistant_api: true        # For entity/service access
auth_api: true                 # For authentication tokens
```

---

#### 6. Container Security Hardening
**Location**: `claude-terminal/Dockerfile`

**Changes**:
- Added `CLAUDE_VERSION` ARG for package version pinning
- Includes essential development tools (git, Python, jq) for Claude workflows
- Added HEALTHCHECK for service monitoring
- Documented root execution requirement (Home Assistant limitation)
- Added instructions for version pinning

**Recommended**: Pin to specific version in production:
```dockerfile
ARG CLAUDE_VERSION=1.2.3
```

**Impact**: Reproducible builds, reduced attack surface, better monitoring.

---

## Security Best Practices

### For Deployment

1. **Pin Package Versions**
   - Update `CLAUDE_VERSION` in Dockerfile to specific version
   - Regularly update to latest stable release
   - Test updates in development before production

2. **Minimize Permissions**
   - Use default permissions unless elevated access is required
   - Consider making `/config` read-only if Claude doesn't need write access
   - Only enable API access for specific use cases

3. **Monitor Access**
   - Enable Home Assistant audit logs
   - Monitor terminal access via `panel_admin: true` restriction
   - Review credential file permissions periodically

4. **Network Isolation**
   - Use ingress-only access (default configuration)
   - Avoid exposing port 7681 directly to network
   - Keep `panel_admin: true` to restrict to administrators

### For Development

1. **Input Validation**
   - Always validate user input before shell execution
   - Use allowlists instead of denylists
   - Never use `eval` with user-controlled input

2. **Credential Handling**
   - Use `mktemp` for temporary credential storage
   - Set restrictive permissions (600 for files, 700 for directories)
   - Implement trap handlers for guaranteed cleanup
   - Overwrite sensitive files before deletion

3. **File Operations**
   - Validate file paths before operations
   - Check for symlinks in security-sensitive operations
   - Use atomic operations where possible
   - Set secure permissions before writing sensitive data

## Known Limitations

### Root Execution
The add-on runs as root (UID 0) due to Home Assistant add-on architecture requirements:
- Needs access to `/config` (Home Assistant configuration)
- Requires `bashio` integration
- Security provided by Home Assistant's container isolation

**Mitigation**: Reduced capabilities through restricted API access and least privilege permissions.

### Network Binding
ttyd binds to `0.0.0.0:7681` for Home Assistant ingress compatibility. Access is controlled by:
- Home Assistant authentication
- `panel_admin: true` (administrators only)
- Container network isolation

**Recommendation**: Use ingress-only access, do not expose port 7681 directly.

## Reporting Security Issues

If you discover a security vulnerability, please report it via:
- GitHub Security Advisories (preferred): https://github.com/Arborist-ai/HA-LCASS/security/advisories

**Do not** open public issues for security vulnerabilities.

## Security Checklist

Before deploying to production:

- [ ] Pin `CLAUDE_VERSION` to specific version in Dockerfile
- [ ] Review and minimize API permissions in config.yaml
- [ ] Ensure direct port exposure is disabled (use ingress only)
- [ ] Verify `panel_admin: true` is set
- [ ] Test credential file permissions (should be 600)
- [ ] Review Home Assistant audit logs
- [ ] Update to latest security patches
- [ ] Document custom security configurations

## Version History

### v1.6.0 - Current Release
- Native Claude Code installation using official installer
- Persistent package management (APK and pip)
- Fixed auto-resume session detection
- PEP-0668 compatibility for Python 3.11+
- All security fixes from v1.4.2 maintained

### v1.5.0
- Auto-resume session functionality
- Git integration for version control
- Enhanced user experience
- All security fixes from v1.4.2 maintained

### v1.4.2 - Security Hardening Release
- Fixed command injection vulnerability (CRITICAL)
- Fixed insecure credential storage (CRITICAL)
- Fixed world-readable credential files (CRITICAL)
- Fixed TOCTOU race condition (HIGH)
- Reduced Home Assistant API permissions (HIGH)
- Added container security hardening (MEDIUM)
- Added input validation throughout
- Improved documentation

### v1.4.1 and earlier
- See git history for changes
- Versions before v1.4.2 contain critical security vulnerabilities
- **Not recommended for production use**

## Compliance Notes

This add-on handles:
- User authentication credentials (Claude API authentication codes)
- Home Assistant configuration files (via `/config` mount)
- Terminal access with shell execution capabilities

**Data Protection**:
- Credentials stored locally on Home Assistant instance
- No external credential transmission except to Claude API
- File permissions prevent cross-container access
- Encryption at rest depends on Home Assistant host configuration

**Access Control**:
- Administrator-only access via `panel_admin: true`
- Home Assistant authentication required
- No independent authentication mechanism

## References

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- [Home Assistant Add-on Security](https://developers.home-assistant.io/docs/add-ons/security)
- [NIST Least Privilege](https://csrc.nist.gov/glossary/term/least_privilege)

---

**Last Updated**: 2026-01-14
**Security Contact**: Via GitHub Security Advisories
