ARG BUILD_FROM
FROM ${BUILD_FROM}

# Install packages in a single layer to minimize image size
# Add retry logic for npm installation to handle network issues
RUN apk add --no-cache \
    nodejs \
    npm \
    bash \
    curl \
    nano \
    python3 \
    py3-pip \
    py3-requests \
    py3-aiohttp \
    py3-yaml \
    py3-beautifulsoup4 \
    git \
    vim \
    wget \
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
        # SECURITY NOTE: Using @latest for now, but consider pinning to specific version
        # Example: npm install -g @anthropic-ai/claude-code@1.2.3
        npm install -g @anthropic-ai/claude-code@latest && \
        echo "Successfully installed Claude Code CLI" && \
        break || \
        (echo "Attempt $i failed, retrying in 10 seconds..." && sleep 10); \
    done \
    && npm cache clean --force

# Create directory for Claude configuration and set working directory
RUN mkdir -p /config/claude-config
WORKDIR /config

# Copy startup script and modular scripts
COPY run.sh /run.sh
COPY scripts/ /opt/scripts/
RUN chmod +x /run.sh \
    && chmod +x /opt/scripts/*.sh

# Health check to ensure web terminal is responsive
# Checks every 30 seconds, allows 10s timeout, 3 retries before marking unhealthy
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:7681/ || exit 1

# Use exec form for better signal handling
CMD ["/run.sh"]