ARG BUILD_FROM
FROM ${BUILD_FROM}

# Security: Pin package versions for reproducible builds and vulnerability management
# TODO: Update CLAUDE_VERSION to latest stable release periodically
ARG CLAUDE_VERSION=latest
# Security Note: Change @latest to a specific version (e.g., @1.2.3) for production
# Check latest version: npm view @anthropic-ai/claude-code version

# Install packages in a single layer to minimize image size
# Security: Reduced package list - removed git, vim, nano, wget (use 'apk add' in terminal if needed)
RUN apk add --no-cache \
    nodejs \
    npm \
    bash \
    curl \
    python3 \
    py3-pip \
    py3-requests \
    py3-aiohttp \
    py3-yaml \
    py3-beautifulsoup4 \
    jq \
    tree \
    yq \
    && (npm config set registry https://registry.npmjs.org/ || true) \
    && (npm config set fetch-retries 3 || true) \
    && (npm config set fetch-retry-mintimeout 20000 || true) \
    && (npm config set fetch-retry-maxtimeout 120000 || true) \
    && (npm config set fetch-timeout 300000 || true) \
    && for i in 1 2 3; do \
        echo "Attempt $i: Installing Claude Code CLI..." && \
        npm install -g @anthropic-ai/claude-code@${CLAUDE_VERSION} && \
        echo "Successfully installed Claude Code CLI" && \
        break || \
        (echo "Attempt $i failed, retrying in 10 seconds..." && sleep 10); \
    done \
    && npm cache clean --force

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