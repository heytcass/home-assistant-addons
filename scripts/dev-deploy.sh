#!/bin/bash
# Deploy the working-tree add-on to a Home Assistant box as a *local* add-on,
# side by side with the released one, for testing before a release.
#
#   scripts/dev-deploy.sh root@homeassistant.local   # push over SSH
#   scripts/dev-deploy.sh                            # just build dist/claude-terminal-dev/
#
# The copy is rewritten so it cannot collide with, or be mistaken for, the
# real add-on:
#   - slug/name/panel become claude_terminal_dev / "Claude Terminal (dev)"
#     (own /data, own sidebar entry, installs alongside the release)
#   - the `image:` key is removed, so the Supervisor builds the image locally
#     from this Dockerfile instead of pulling GHCR
#   - the version gets a -dev.<git sha> suffix, so every deploy looks like an
#     update to the Supervisor and it rebuilds instead of reusing a cache
#
# SSH target: the Advanced SSH & Web Terminal add-on (protection mode off) or
# the HA OS host on port 22222 — either exposes /addons. After deploying:
# Settings → Add-ons → Add-on Store → ⋮ → Check for updates, then install or
# update "Claude Terminal (dev)". Remove it from the store UI when done.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
src="$repo_root/claude-terminal"
dist="$repo_root/dist/claude-terminal-dev"
target="${1:-}"

sha=$(git -C "$repo_root" rev-parse --short HEAD 2>/dev/null || echo nogit)
if [ -n "$(git -C "$repo_root" status --porcelain -- claude-terminal 2>/dev/null)" ]; then
    sha="${sha}.dirty"
fi

rm -rf "$dist"
mkdir -p "$dist"
cp -R "$src"/. "$dist"/

config="$dist/config.yaml"
version=$(sed -n 's/^version: *"\{0,1\}\([^"]*\)"\{0,1\}.*/\1/p' "$config" | head -1)
[ -n "$version" ] || { echo "Could not read version from $config" >&2; exit 1; }

# GNU and BSD sed disagree on -i; write to a temp file instead.
sed \
    -e 's/^name: .*/name: "Claude Terminal (dev)"/' \
    -e 's/^slug: .*/slug: "claude_terminal_dev"/' \
    -e 's/^panel_title: .*/panel_title: "Claude Terminal (dev)"/' \
    -e "s/^version: .*/version: \"${version}-dev.${sha}\"/" \
    -e '/^image: /d' \
    "$config" > "$config.tmp" && mv "$config.tmp" "$config"

echo "Built local add-on: $dist"
echo "  slug    claude_terminal_dev"
echo "  version ${version}-dev.${sha}"

if [ -z "$target" ]; then
    echo
    echo "No SSH target given. Copy $dist to /addons/claude-terminal-dev on your"
    echo "Home Assistant box, then reload the add-on store."
    exit 0
fi

remote_dir="/addons/claude-terminal-dev"
echo "Deploying to ${target}:${remote_dir} ..."
# tar over ssh: works on the HA OS host and every SSH add-on, unlike rsync.
# remote_dir is meant to expand client-side
# shellcheck disable=SC2029
ssh "$target" "rm -rf '$remote_dir' && mkdir -p '$remote_dir'"
# shellcheck disable=SC2029
tar -C "$dist" -cf - . | ssh "$target" "tar -xf - -C '$remote_dir'"
echo "Done. In HA: Add-on Store → ⋮ → Check for updates → Claude Terminal (dev)."
