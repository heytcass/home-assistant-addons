#!/bin/bash

# build-ttyd-index — run once at image build (Dockerfile), not at boot.
#
# Captures the index.html that this image's own ttyd serves and injects
# ttyd-extras.js into it as a single <script> before </body>. run.sh then
# serves the result with `ttyd --index`. Capturing from the installed ttyd
# keeps the page identical to stock apart from that one tag, and doing it
# at build time keeps it off the boot path. Fails the build if anything
# looks off, rather than shipping an image without the page.
#
# Usage: build-ttyd-index.sh [output] [script]

set -euo pipefail

out="${1:-/opt/ttyd/index.html}"
extras="${2:-/opt/scripts/ttyd-extras.js}"
port=7699

work=$(mktemp -d)
ttyd --port "$port" --interface lo true >/dev/null 2>&1 &
ttyd_pid=$!
trap 'kill "$ttyd_pid" 2>/dev/null || true; rm -rf "$work"' EXIT

for _ in $(seq 1 50); do
    if curl -fsS -o "$work/stock.html" "http://127.0.0.1:${port}/" 2>/dev/null; then
        break
    fi
    sleep 0.2
done

if [ ! -s "$work/stock.html" ]; then
    echo "build-ttyd-index: could not fetch ttyd's built-in page" >&2
    exit 1
fi
if [ "$(grep -o '</body>' "$work/stock.html" | wc -l)" -ne 1 ]; then
    echo "build-ttyd-index: expected exactly one </body> in ttyd's page" >&2
    exit 1
fi
if ! grep -q 'window.term=' "$work/stock.html"; then
    echo "build-ttyd-index: ttyd's page no longer exposes window.term" >&2
    exit 1
fi
if grep -qi '</script' "$extras"; then
    echo "build-ttyd-index: $extras must not contain '</script'" >&2
    exit 1
fi

mkdir -p "$(dirname "$out")"
python3 - "$work/stock.html" "$extras" "$out" <<'PY'
import sys
stock, extras, out = sys.argv[1:4]
html = open(stock, encoding="utf-8").read()
js = open(extras, encoding="utf-8").read()
open(out, "w", encoding="utf-8").write(
    html.replace("</body>", "<script>\n" + js + "</script></body>", 1))
PY

echo "build-ttyd-index: wrote $out ($(wc -c < "$out") bytes)"
