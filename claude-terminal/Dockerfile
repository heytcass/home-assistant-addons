ARG BUILD_FROM
FROM ${BUILD_FROM}

# Install system packages and development tools
RUN apk add --no-cache \
    bash \
    curl \
    nano \
    nodejs \
    npm \
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
    tmux \
    yq

# Install Claude Code CLI via npm (avoids musl binary compatibility issues)
RUN npm install -g @anthropic-ai/claude-code@latest \
    && npm cache clean --force

# Install uv for running ha-mcp (Python package manager/runner)
# ha-mcp >=3.6 requires CPython 3.13 exactly, which no Alpine release ships,
# and Alpine's apk-packaged uv is too old to download managed musl Python
# builds - so install a recent uv from the official installer instead
RUN curl -LsSf -o /tmp/uv-install.sh https://astral.sh/uv/0.11.26/install.sh \
    && env UV_INSTALL_DIR=/usr/local/bin INSTALLER_NO_MODIFY_PATH=1 sh /tmp/uv-install.sh \
    && rm /tmp/uv-install.sh

# Create directory for Claude configuration and set working directory
RUN mkdir -p /config/claude-config
WORKDIR /config

# Copy startup script and modular scripts
COPY run.sh /run.sh
COPY scripts/ /opt/scripts/
RUN chmod +x /run.sh \
    && chmod +x /opt/scripts/*.sh

# Use exec form for better signal handling
CMD ["/run.sh"]