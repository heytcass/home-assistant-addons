ARG BUILD_FROM
FROM ${BUILD_FROM}

# All runtime packages are baked into the image so startup never depends on
# the network (ttyd/tmux/jq were previously apk-installed on every boot)
RUN apk add --no-cache \
    bash \
    curl \
    git \
    jq \
    nano \
    nodejs \
    npm \
    py3-aiohttp \
    py3-beautifulsoup4 \
    py3-pip \
    py3-requests \
    py3-yaml \
    python3 \
    tmux \
    tree \
    ttyd \
    uv \
    vim \
    wget \
    yq

# Keep the npm cache out of persistent storage so it never lands in HA backups
ENV npm_config_cache=/tmp/npm-cache

# Claude Code refuses --dangerously-skip-permissions as root unless the
# environment declares itself a disposable container — which HA add-ons are
ENV IS_SANDBOX=1

# Bundled Claude Code CLI. This copy is frozen at image build time; when
# claude_auto_update is enabled, run.sh maintains a persistent native install
# in /data that takes precedence and keeps itself current.
RUN npm install -g @anthropic-ai/claude-code@latest \
    && npm cache clean --force

WORKDIR /config

COPY run.sh /run.sh
COPY scripts/ /opt/scripts/
RUN chmod +x /run.sh /opt/scripts/*.sh

# Use exec form for better signal handling
CMD ["/run.sh"]
