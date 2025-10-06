#!/usr/bin/with-contenv bashio

# Health check script for Claude Terminal add-on
# Validates environment and provides diagnostic information

check_system_resources() {
    bashio::log.info "=== System Resources Check ==="

    # Check available memory
    local mem_total=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
    local mem_free=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)
    bashio::log.info "Memory: ${mem_free}MB free of ${mem_total}MB total"

    if [ "$mem_free" -lt 256 ]; then
        bashio::log.error "Low memory warning: Less than 256MB available"
        bashio::log.info "This may cause installation or runtime issues"
    fi

    # Check disk space in /data
    local disk_free=$(df -m /data | tail -1 | awk '{print $4}')
    bashio::log.info "Disk space in /data: ${disk_free}MB free"

    if [ "$disk_free" -lt 100 ]; then
        bashio::log.error "Low disk space warning: Less than 100MB in /data"
    fi
}

check_directory_permissions() {
    bashio::log.info "=== Directory Permissions Check ==="

    # Check if /data is writable
    if [ -w "/data" ]; then
        bashio::log.info "/data directory: Writable ✓"
    else
        bashio::log.error "/data directory: Not writable ✗"
        return 1
    fi

    # Try to create test directory
    local test_dir="/data/.test_$$"
    if mkdir -p "$test_dir" 2>/dev/null; then
        bashio::log.info "Can create directories in /data ✓"
        rmdir "$test_dir"
    else
        bashio::log.error "Cannot create directories in /data ✗"
        return 1
    fi
}

check_node_installation() {
    bashio::log.info "=== Node.js Installation Check ==="

    if command -v node >/dev/null 2>&1; then
        local node_version=$(node --version)
        bashio::log.info "Node.js installed: $node_version ✓"
    else
        bashio::log.error "Node.js not found ✗"
        return 1
    fi

    if command -v npm >/dev/null 2>&1; then
        local npm_version=$(npm --version)
        bashio::log.info "npm installed: $npm_version ✓"
    else
        bashio::log.error "npm not found ✗"
        return 1
    fi
}

check_claude_cli() {
    bashio::log.info "=== Claude CLI Check ==="

    if command -v claude >/dev/null 2>&1; then
        bashio::log.info "Claude CLI found at: $(which claude) ✓"

        # Check if Claude CLI is executable
        if [ -x "$(which claude)" ]; then
            bashio::log.info "Claude CLI is executable ✓"
        else
            bashio::log.error "Claude CLI is not executable ✗"
            return 1
        fi
    else
        bashio::log.error "Claude CLI not found ✗"
        bashio::log.info "Attempting to install Claude CLI..."
        return 1
    fi
}

check_network_connectivity() {
    bashio::log.info "=== Network Connectivity Check ==="

    # Check DNS resolution first
    if host registry.npmjs.org >/dev/null 2>&1 || nslookup registry.npmjs.org >/dev/null 2>&1; then
        bashio::log.info "DNS resolution working ✓"
    else
        bashio::log.error "DNS resolution failing - check network configuration"
        bashio::log.info "Try setting custom DNS servers (e.g., 8.8.8.8, 1.1.1.1)"
    fi

    # Try to reach npm registry
    if curl -s --head --connect-timeout 10 --max-time 15 https://registry.npmjs.org > /dev/null; then
        bashio::log.info "Can reach npm registry ✓"
    else
        bashio::log.warning "Cannot reach npm registry - this may affect Claude CLI installation"
        bashio::log.info "This could be due to:"
        bashio::log.info "  - Network proxy/firewall blocking access"
        bashio::log.info "  - DNS resolution issues"
        bashio::log.info "  - Slow network connection (try increasing timeout)"
    fi

    # Try to reach GitHub Container Registry
    if curl -s --head --connect-timeout 10 --max-time 15 https://ghcr.io > /dev/null; then
        bashio::log.info "Can reach GitHub Container Registry ✓"
    else
        bashio::log.error "Cannot reach GitHub Container Registry (ghcr.io)"
        bashio::log.info "This is likely the cause of installation failures"
        bashio::log.info "Possible solutions:"
        bashio::log.info "  1. Check if your network blocks ghcr.io"
        bashio::log.info "  2. Try using a VPN or different network"
        bashio::log.info "  3. Check VM network adapter settings"
    fi

    # Try to reach Anthropic API
    if curl -s --head --connect-timeout 10 --max-time 15 https://api.anthropic.com > /dev/null; then
        bashio::log.info "Can reach Anthropic API ✓"
    else
        bashio::log.warning "Cannot reach Anthropic API - this may affect Claude functionality"
    fi
}

run_diagnostics() {
    bashio::log.info "========================================="
    bashio::log.info "Claude Terminal Add-on Health Check"
    bashio::log.info "========================================="

    local errors=0

    check_system_resources || ((errors++))
    check_directory_permissions || ((errors++))
    check_node_installation || ((errors++))
    check_claude_cli || ((errors++))
    check_network_connectivity || ((errors++))

    bashio::log.info "========================================="

    if [ "$errors" -eq 0 ]; then
        bashio::log.info "✅ All checks passed successfully!"
    else
        bashio::log.error "❌ $errors check(s) failed"
        bashio::log.info "Please review the errors above"

        # Provide VirtualBox-specific advice if relevant
        if [ -f /proc/modules ] && grep -q vboxguest /proc/modules; then
            bashio::log.info ""
            bashio::log.info "=== VirtualBox Environment Detected ==="
            bashio::log.warning "VirtualBox users commonly experience network issues"
            bashio::log.info ""
            bashio::log.info "Required VM settings:"
            bashio::log.info "  • Memory: At least 2GB RAM (4GB recommended)"
            bashio::log.info "  • Storage: At least 8GB disk space"
            bashio::log.info "  • VirtualBox Guest Additions: MUST be installed"
            bashio::log.info ""
            bashio::log.info "Network adapter configuration:"
            bashio::log.info "  • Recommended: Bridged Adapter mode"
            bashio::log.info "  • Alternative: NAT with port forwarding"
            bashio::log.info "  • Ensure 'Cable Connected' is checked"
            bashio::log.info ""
            bashio::log.info "If installation fails with network timeout:"
            bashio::log.info "  1. Try changing VM network adapter to Bridged mode"
            bashio::log.info "  2. Restart the VM after network changes"
            bashio::log.info "  3. Check if your host firewall blocks container registries"
            bashio::log.info "  4. Try installation during off-peak hours (network congestion)"
            bashio::log.info "  5. Consider using Home Assistant on bare metal or Docker instead"
        fi

        # Check for Proxmox environment
        if [ -f /proc/cpuinfo ] && grep -q "QEMU Virtual CPU" /proc/cpuinfo; then
            bashio::log.info ""
            bashio::log.info "=== Virtual Environment Detected (Possibly Proxmox) ==="
            bashio::log.info "If running in Proxmox, ensure:"
            bashio::log.info "  • VM has sufficient resources (2GB+ RAM)"
            bashio::log.info "  • Network device uses VirtIO (recommended)"
            bashio::log.info "  • Firewall rules allow container registry access"
            bashio::log.info "  • DNS is properly configured in the VM"
        fi
    fi

    return $errors
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    run_diagnostics
fi