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
    vim \
    wget \
    yq

# uv from PyPI, pinned: Alpine 3.21's apk uv (0.5.x) cannot install managed
# musl CPython builds, which ha-mcp >= 4.x needs (it requires Python 3.13;
# Alpine 3.21 ships 3.12). musllinux wheels exist for all three arches.
RUN pip3 install --no-cache-dir --break-system-packages uv==0.11.28

# Keep the npm cache out of persistent storage so it never lands in HA backups
ENV npm_config_cache=/tmp/npm-cache

# Claude Code refuses --dangerously-skip-permissions as root unless the
# environment declares itself a disposable container — which HA add-ons are
ENV IS_SANDBOX=1

# The HA base image already runs ash with pipefail; restate it so hadolint
# (which only sees this file) knows the curl|tar pipe below is guarded
SHELL ["/bin/ash", "-o", "pipefail", "-c"]

# Bundled Claude Code CLI. This copy is frozen at image build time; when
# claude_auto_update is enabled, run.sh maintains a persistent native install
# in /data that takes precedence and keeps itself current.
# Fetched as the native musl binary straight from the npm registry rather
# than via `npm install -g`: the npm package is now only a wrapper that
# installs this same binary, and running npm/Node during aarch64 cross-builds
# (QEMU on CI runners) crashes V8 with SIGILL. curl+tar emulate fine.
RUN case "$(apk --print-arch)" in \
        x86_64)  claude_pkg="linux-x64-musl" ;; \
        aarch64) claude_pkg="linux-arm64-musl" ;; \
        *) echo "Unsupported architecture: $(apk --print-arch)" >&2; exit 1 ;; \
    esac \
    && claude_version="$(curl -fsSL https://registry.npmjs.org/@anthropic-ai/claude-code/latest | jq -r .version)" \
    && curl -fsSL "https://registry.npmjs.org/@anthropic-ai/claude-code-${claude_pkg}/-/claude-code-${claude_pkg}-${claude_version}.tgz" \
        | tar -xz -C /tmp package/claude \
    && install -m 0755 /tmp/package/claude /usr/local/bin/claude \
    && rm -rf /tmp/package

WORKDIR /config

COPY run.sh /run.sh
COPY scripts/ /opt/scripts/
RUN chmod +x /run.sh /opt/scripts/*.sh

# Use exec form for better signal handling
CMD ["/run.sh"]
