ARG BUILD_FROM
FROM ${BUILD_FROM}

# Install system packages and development tools
RUN apk add --no-cache \
    bash \
    curl \
    git \
    nano \
    nodejs \
    npm \
    python3 \
    py3-pip \
    py3-requests \
    py3-aiohttp \
    py3-yaml \
    py3-beautifulsoup4 \
    jq \
    tree \
    yq

# Install Claude Code CLI using native installer
# The installer places the binary in ~/.local/bin
# Native binary provides automatic background updates from Anthropic
RUN curl -fsSL https://claude.ai/install.sh | bash \
    && ln -sf /root/.local/bin/claude /usr/local/bin/claude

# Install uv for Python package management (required for uvx MCP servers like ha-mcp)
# Copy pre-built binaries from official uv Docker image (Alpine/musl compatible)
# This is the recommended approach for Alpine Linux per uv documentation
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Security Note: This add-on runs as root (UID 0) due to Home Assistant requirements
# - Needs access to /config (Home Assistant configuration)
# - Requires bashio integration for add-on functionality
# - Security is provided by Home Assistant's container isolation
# Consider restricting capabilities in future versions if HA supports it

# Create directory for Claude configuration and set working directory
RUN mkdir -p /config/claude-config
WORKDIR /config

# Copy startup script and modular scripts
COPY run.sh /run.sh
COPY scripts/ /opt/scripts/
RUN chmod +x /run.sh \
    && chmod +x /opt/scripts/*.sh

# Security: Add health check to monitor service availability
# Checks if ttyd web interface is responding
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:7681/ || exit 1

# Use exec form for better signal handling
CMD ["/run.sh"]
