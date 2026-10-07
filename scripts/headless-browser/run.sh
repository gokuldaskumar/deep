#!/usr/bin/env bash
# Wrapper: points LD_LIBRARY_PATH at the vendored libs, then runs browse.mjs.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BROWSER_LIBS="${BROWSER_LIBS:-$HOME/chromedeps}"
export LD_LIBRARY_PATH="$BROWSER_LIBS/usr/lib/x86_64-linux-gnu:$BROWSER_LIBS/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"
exec node "$HERE/browse.mjs" "$@"
