#!/usr/bin/with-contenv bashio
#
# persist-install - Install packages that persist across container restarts
#
# Usage:
#   persist-install apk <package1> [package2] ...  - Install APK packages
#   persist-install pip <package1> [package2] ...  - Install pip packages
#   persist-install list                           - List persistent packages
#   persist-install help                           - Show this help message
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Config file for tracking installed packages (persisted in /data)
PERSIST_CONFIG="/data/persistent-packages.json"

# Initialize config file if it doesn't exist
init_config() {
    if [ ! -f "$PERSIST_CONFIG" ]; then
        echo '{"apk_packages": [], "pip_packages": []}' > "$PERSIST_CONFIG"
    fi
}

# Show help message
show_help() {
    echo -e "${BLUE}persist-install${NC} - Install packages that persist across container restarts"
    echo ""
    echo "Usage:"
    echo "  persist-install apk <package1> [package2] ...  - Install APK packages"
    echo "  persist-install pip <package1> [package2] ...  - Install pip packages"
    echo "  persist-install list                           - List persistent packages"
    echo "  persist-install remove apk <package>           - Remove APK package from persistence"
    echo "  persist-install remove pip <package>           - Remove pip package from persistence"
    echo "  persist-install help                           - Show this help message"
    echo ""
    echo "Examples:"
    echo "  persist-install apk vim htop"
    echo "  persist-install pip requests pandas numpy"
    echo "  persist-install list"
    echo ""
    echo -e "${YELLOW}Note:${NC} Packages are installed immediately and will be reinstalled"
    echo "      automatically after container restarts."
}

# List installed packages
list_packages() {
    init_config

    echo -e "${BLUE}Persistent Packages${NC}"
    echo "==================="
    echo ""

    echo -e "${GREEN}APK Packages:${NC}"
    local apk_packages
    apk_packages=$(jq -r '.apk_packages[]' "$PERSIST_CONFIG" 2>/dev/null || echo "")
    if [ -z "$apk_packages" ]; then
        echo "  (none)"
    else
        echo "$apk_packages" | while read -r pkg; do
            echo "  - $pkg"
        done
    fi

    echo ""
    echo -e "${GREEN}Pip Packages:${NC}"
    local pip_packages
    pip_packages=$(jq -r '.pip_packages[]' "$PERSIST_CONFIG" 2>/dev/null || echo "")
    if [ -z "$pip_packages" ]; then
        echo "  (none)"
    else
        echo "$pip_packages" | while read -r pkg; do
            echo "  - $pkg"
        done
    fi
}

# Install APK packages
install_apk() {
    init_config

    if [ $# -eq 0 ]; then
        echo -e "${RED}Error:${NC} No packages specified"
        echo "Usage: persist-install apk <package1> [package2] ..."
        exit 1
    fi

    local packages=("$@")

    echo -e "${BLUE}Installing APK packages:${NC} ${packages[*]}"

    # Install packages
    if apk add --no-cache "${packages[@]}"; then
        echo -e "${GREEN}Installation successful!${NC}"

        # Add to persistence config
        for pkg in "${packages[@]}"; do
            # Check if already in list
            if ! jq -e ".apk_packages | index(\"$pkg\")" "$PERSIST_CONFIG" > /dev/null 2>&1; then
                jq ".apk_packages += [\"$pkg\"]" "$PERSIST_CONFIG" > "${PERSIST_CONFIG}.tmp"
                mv "${PERSIST_CONFIG}.tmp" "$PERSIST_CONFIG"
                echo -e "${GREEN}+${NC} Added '$pkg' to persistent packages"
            else
                echo -e "${YELLOW}!${NC} '$pkg' already in persistent packages"
            fi
        done
    else
        echo -e "${RED}Installation failed!${NC}"
        exit 1
    fi
}

# Install pip packages
install_pip() {
    init_config

    if [ $# -eq 0 ]; then
        echo -e "${RED}Error:${NC} No packages specified"
        echo "Usage: persist-install pip <package1> [package2] ..."
        exit 1
    fi

    local packages=("$@")

    echo -e "${BLUE}Installing pip packages:${NC} ${packages[*]}"

    # Install packages
    if pip3 install --break-system-packages --no-cache-dir "${packages[@]}"; then
        echo -e "${GREEN}Installation successful!${NC}"

        # Add to persistence config
        for pkg in "${packages[@]}"; do
            # Check if already in list (normalize package name)
            local pkg_lower
            pkg_lower=$(echo "$pkg" | tr '[:upper:]' '[:lower:]')
            if ! jq -e ".pip_packages | map(ascii_downcase) | index(\"$pkg_lower\")" "$PERSIST_CONFIG" > /dev/null 2>&1; then
                jq ".pip_packages += [\"$pkg\"]" "$PERSIST_CONFIG" > "${PERSIST_CONFIG}.tmp"
                mv "${PERSIST_CONFIG}.tmp" "$PERSIST_CONFIG"
                echo -e "${GREEN}+${NC} Added '$pkg' to persistent packages"
            else
                echo -e "${YELLOW}!${NC} '$pkg' already in persistent packages"
            fi
        done
    else
        echo -e "${RED}Installation failed!${NC}"
        exit 1
    fi
}

# Remove package from persistence
remove_package() {
    init_config

    local pkg_type="$1"
    local pkg_name="$2"

    if [ -z "$pkg_type" ] || [ -z "$pkg_name" ]; then
        echo -e "${RED}Error:${NC} Missing arguments"
        echo "Usage: persist-install remove <apk|pip> <package>"
        exit 1
    fi

    case "$pkg_type" in
        apk)
            jq "del(.apk_packages[] | select(. == \"$pkg_name\"))" "$PERSIST_CONFIG" > "${PERSIST_CONFIG}.tmp"
            mv "${PERSIST_CONFIG}.tmp" "$PERSIST_CONFIG"
            echo -e "${GREEN}-${NC} Removed '$pkg_name' from persistent APK packages"
            echo -e "${YELLOW}Note:${NC} Package is still installed until container restart"
            ;;
        pip)
            jq "del(.pip_packages[] | select(. == \"$pkg_name\"))" "$PERSIST_CONFIG" > "${PERSIST_CONFIG}.tmp"
            mv "${PERSIST_CONFIG}.tmp" "$PERSIST_CONFIG"
            echo -e "${GREEN}-${NC} Removed '$pkg_name' from persistent pip packages"
            echo -e "${YELLOW}Note:${NC} Package is still installed until container restart"
            ;;
        *)
            echo -e "${RED}Error:${NC} Unknown package type '$pkg_type'"
            echo "Usage: persist-install remove <apk|pip> <package>"
            exit 1
            ;;
    esac
}

# Main command handler
main() {
    local command="${1:-help}"
    shift || true

    case "$command" in
        apk)
            install_apk "$@"
            ;;
        pip)
            install_pip "$@"
            ;;
        list)
            list_packages
            ;;
        remove)
            remove_package "$@"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo -e "${RED}Error:${NC} Unknown command '$command'"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

main "$@"
