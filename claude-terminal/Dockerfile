ARG BUILD_FROM
FROM ${BUILD_FROM}

# Install system packages and development tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    curl \
    nano \
    nodejs \
    npm \
    python3 \
    python3-pip \
    python3-requests \
    python3-aiohttp \
    python3-yaml \
    python3-bs4 \
    git \
    vim \
    wget \
    jq \
    tree \
    tmux \
    && rm -rf /var/lib/apt/lists/* \
    && pip3 install --break-system-packages yq

# Install Claude Code CLI using native installer
# The installer places the binary in ~/.local/bin
RUN curl -fsSL https://claude.ai/install.sh | bash \
    && ln -sf /root/.local/bin/claude /usr/local/bin/claude

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