# Security Policy

## Security Improvements (Latest Update)

This document outlines the security improvements made to the Claude Terminal add-on.

### Critical Vulnerabilities Fixed

#### 1. Command Injection Prevention (CRITICAL)
**Location:** `claude-terminal/scripts/claude-session-picker.sh`

**Issue:** User input was directly executed via `eval`, allowing arbitrary command execution.

**Fix:**
- Removed `eval` usage
- Added strict input validation using regex pattern matching
- Only alphanumeric characters, spaces, dashes, underscores, quotes, dots, and equals are allowed
- Invalid input is rejected with clear error message

#### 2. Reduced API Permissions (HIGH)
**Location:** `claude-terminal/config.yaml`

**Issue:** Add-on had excessive "manager" role permissions, allowing full control over Home Assistant.

**Fix:**
- Changed `hassio_role` from "manager" to "default" (read-only)
- Disabled unnecessary `auth_api` access
- Added detailed comments explaining required permissions
- Users can optionally enable "admin" role if write access is needed (with warning)

#### 3. Enhanced Credential Security (HIGH)
**Location:** `claude-terminal/run.sh`

**Improvements:**
- Credentials now stored with 600 permissions (owner read/write only)
- Claude config directory has 700 permissions (owner access only)
- Directories created with restrictive umask (077)
- Added `secure_credential_permissions()` function for continuous enforcement
- Symlink detection prevents symlink attack vectors
- Migration only copies regular files, not symlinks

### Medium Priority Fixes

#### 4. Input Validation
**Locations:**
- `claude-terminal/scripts/claude-auth-helper.sh`
- `claude-terminal/scripts/claude-session-picker.sh`

**Improvements:**
- Authentication codes validated before use
- Temporary files created with secure permissions (umask 077)
- Temp files use process ID suffix to prevent conflicts
- Files securely shredded after use when possible

#### 5. Symlink Attack Prevention
**Location:** `claude-terminal/run.sh` (migration function)

**Improvements:**
- Check if paths are symlinks before operations
- Only copy regular files during migration
- Double-check safety before `rm -rf` operations
- Symlink detection prevents malicious redirects

#### 6. Race Condition Mitigation
**Location:** `claude-terminal/scripts/claude-auth-helper.sh`

**Improvements:**
- Atomic file creation with umask
- Process-specific temp file names
- Secure cleanup after use

### Additional Security Enhancements

#### 7. Docker Build Optimization
**Location:** `claude-terminal/.dockerignore` (new file)

**Benefits:**
- Reduces build context size
- Prevents sensitive files from entering image
- Faster builds

#### 8. Health Check Implementation
**Location:** `claude-terminal/Dockerfile`

**Benefits:**
- Container health monitoring
- Automatic detection of service failures
- Better resilience in production

## Security Best Practices

### For Users

1. **Review API Permissions:** The add-on now uses minimal permissions by default. Only enable "admin" role if you specifically need write access to Home Assistant entities.

2. **Keep Updated:** Regularly update the add-on to receive latest security patches.

3. **Monitor Logs:** Check add-on logs for security warnings or unexpected behavior.

4. **Secure Your Home Assistant:**
   - Use strong passwords
   - Enable two-factor authentication
   - Keep Home Assistant updated
   - Use HTTPS for remote access

### For Developers

1. **Input Validation:** All user input must be validated before use.

2. **Least Privilege:** Request only the minimum required permissions.

3. **Secure Defaults:** Security features should be enabled by default.

4. **Defense in Depth:** Multiple layers of security (validation + permissions + encryption).

## Reporting Security Issues

If you discover a security vulnerability, please:

1. **Do NOT** open a public GitHub issue
2. Email the maintainer directly (see repository.yaml for contact)
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

## Security Roadmap

Future security improvements planned:

- [ ] Implement credential encryption at rest
- [ ] Add rate limiting for authentication attempts
- [ ] Implement audit logging for sensitive operations
- [ ] Add optional 2FA for terminal access
- [ ] Regular security audits
- [ ] Automated vulnerability scanning

## Changelog

### 2026-01-09 - Major Security Update
- Fixed critical command injection vulnerability
- Reduced API permissions from "manager" to "default"
- Enhanced credential storage security
- Added input validation across all scripts
- Implemented symlink attack prevention
- Added Docker health checks
- Created .dockerignore for build security

---

**Last Updated:** 2026-01-09
**Severity Levels:** CRITICAL, HIGH, MEDIUM, LOW
