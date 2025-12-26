# Release Notes

## Version 1.5.1 (2024-12-12)

### 🐛 Critical Bug Fixes

**Wizard Settings Persistence**
- Fixed: Settings created by wizard are no longer deleted on restart
- The add-on now properly detects and preserves wizard-created `settings.json`
- Only manual YAML configuration (`custom_settings_json`) overrides wizard settings

**Z.ai and Custom Provider Support**
- Fixed: Corrected `settings.json` structure to use `apiKeyHelper`
- API keys now properly passed to Claude Code CLI
- Custom API endpoints (Z.ai, etc.) now work correctly
- No more "Choose API key or Max plan" prompts when using custom providers

**Wizard Completion Tracking**
- Fixed: Wizard no longer appears on every restart
- Added `.wizard-completed` marker file for persistence
- New "Reset wizard" option (menu option 6) to re-run wizard if needed

### 🎯 Improvements

- **Version Display**: Add-on version now shown in startup logs
- **Better Logging**: Settings preview displayed when wizard configuration is detected
- **Documentation**: Updated all examples with correct `apiKeyHelper` structure

### 📝 Migration Notes

If you configured Z.ai or custom providers in v1.5.0:
1. Rebuild the add-on to get v1.5.1
2. Re-run the configuration wizard (option 5 in session picker)
3. Your settings will now persist correctly across restarts

---

## Version 1.5.0 (2024-12-11)

### ✨ New Features

**Interactive Configuration Wizard**
- Automatic first-run detection and wizard launch
- Choose between Anthropic (default), Z.ai, or custom providers
- Guided prompts for API keys and model selection
- No manual YAML editing required
- Accessible from session picker menu (option 5)
- View current configuration and remove custom settings

**Enhanced Session Picker**
- Added configuration wizard option to menu
- Better organization of session options

**Environment Variable Loader**
- New `load-claude-env.sh` script loads settings.json environment variables
- All Claude launch methods now properly load custom configurations
- Visual feedback showing loaded configuration

### 🎯 Improvements

- Simplified onboarding experience for new users
- Reduced configuration errors with interactive prompts
- Better discoverability of Z.ai and custom provider options

### 📝 Documentation

- Comprehensive Z.ai integration guide
- Interactive wizard user guide (WIZARD_GUIDE.md)
- Updated README with new features
- Added translations for UI labels

---

## Version 1.4.0 (2024-12-10)

### ✨ New Features

**Custom settings.json Support**
- Enable Z.ai and alternative model provider integration
- New `custom_settings_json` configuration option in add-on settings
- Settings file automatically created at `/data/.config/claude/settings.json`
- Supports environment variables, model configuration, and permissions
- JSON validation with helpful error messages
- Automatic cleanup when custom settings are removed

### 📝 Documentation

- Comprehensive Z.ai integration guide with examples
- Custom permissions configuration examples
- Step-by-step setup instructions
- Links to official Claude Code settings documentation

---

## Version 1.3.0 (2024-12-09)

### ✨ New Features

**Session Picker**
- Interactive menu for choosing session type
- Options: New session, Continue, Resume, Custom command
- Authentication helper for paste issues
- Bash shell access option

**Configuration Options**
- `auto_launch_claude` setting to enable/disable session picker
- Backward compatible (defaults to auto-launch)

### 🎯 Improvements

- Better user experience with session management
- Easier troubleshooting with authentication helper

---

## Version 1.2.0 (2024-12-08)

### 🐛 Bug Fixes

**Credential Persistence**
- Fixed: OAuth credentials now properly persist across restarts
- Improved credential migration from `/root/.claude/` to `/data/.config/claude/`
- Better error handling for credential operations

### 🎯 Improvements

- Enhanced logging for credential operations
- More robust credential directory setup

---

## Version 1.1.0 (2024-12-07)

### ✨ New Features

**Health Check System**
- Comprehensive system diagnostics on startup
- Memory, disk space, and network connectivity checks
- Node.js and Claude CLI verification
- Helpful for troubleshooting installation issues

### 🎯 Improvements

- Better startup logging
- Improved error messages

---

## Version 1.0.0 (2024-12-06)

### 🎉 Initial Release

**Core Features**
- Web-based terminal interface via ttyd
- Pre-installed Claude Code CLI
- OAuth authentication with Anthropic
- Persistent credential storage
- Multi-architecture support (amd64, aarch64, armv7)
- Home Assistant ingress support
- Direct access to `/config` directory

**Security**
- Secure credential storage in `/data/.config/claude/`
- Proper file permissions (600 for credentials)
- OAuth-based authentication

**User Experience**
- Auto-launch Claude on terminal open
- Clean, simple interface
- No configuration required for basic usage

