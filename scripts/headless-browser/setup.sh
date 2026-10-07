#!/usr/bin/env bash
# Set up a headless Chromium (Playwright) WITHOUT root.
#
# Why this exists: the sandbox runs as an unprivileged user with no sudo and no
# apt package lists, but Chromium needs a handful of shared libraries that are
# not installed. We download the .deb files straight from the Debian mirror and
# extract them into a private prefix, then point LD_LIBRARY_PATH at it.
#
# Idempotent: safe to re-run.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEB_SUITE="${DEB_SUITE:-bookworm}"                 # Debian 12
DEB_MIRROR="${DEB_MIRROR:-https://deb.debian.org/debian}"
BROWSER_LIBS="${BROWSER_LIBS:-$HOME/chromedeps}"   # extracted .so prefix
CACHE="${CACHE:-/tmp/apt}"

# Shared libraries Chromium needs, by Debian package name.
PKGS=(
  libx11-6 libxcomposite1 libxdamage1 libxext6 libxfixes3 libxrandr2
  libxau6 libxdmcp6 libxi6 libxrender1
  libasound2 libatk1.0-0 libatk-bridge2.0-0 libatspi2.0-0 libdbus-1-3
  libgbm1 libdrm2 libglib2.0-0 libnspr4 libnss3
  libxcb1 libxkbcommon0 libwayland-server0 libpciaccess0
)

echo "==> [1/3] Installing Playwright node package"
cd "$HERE"
[ -f package.json ] || npm init -y >/dev/null
npm install --no-audit --no-fund >/dev/null

echo "==> [2/3] Downloading Chromium browser binaries"
npx playwright install chromium

echo "==> [3/3] Vendoring shared libraries into $BROWSER_LIBS"
mkdir -p "$CACHE/debs" "$BROWSER_LIBS"
IDX="$CACHE/Packages"
if [ ! -s "$IDX" ]; then
  echo "    fetching package index..."
  curl -sSL -m 180 "$DEB_MIRROR/dists/$DEB_SUITE/main/binary-amd64/Packages.gz" -o "$IDX.gz"
  gunzip -f "$IDX.gz"
fi

for p in "${PKGS[@]}"; do
  fn=$(awk -v pkg="$p" '/^Package: /{cur=$2} /^Filename: /{if(cur==pkg){print $2; exit}}' "$IDX")
  if [ -z "$fn" ]; then echo "    !! not in index: $p"; continue; fi
  base=$(basename "$fn")
  [ -f "$CACHE/debs/$base" ] || curl -sSL -m 180 "$DEB_MIRROR/$fn" -o "$CACHE/debs/$base"
  dpkg-deb -x "$CACHE/debs/$base" "$BROWSER_LIBS" 2>/dev/null || true
done

# Verify nothing is still unresolved.
export LD_LIBRARY_PATH="$BROWSER_LIBS/usr/lib/x86_64-linux-gnu:$BROWSER_LIBS/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"
missing=$(find "$HOME/.cache/ms-playwright" -name 'chrome-headless-shell' -type f -print -quit \
  | xargs -r ldd 2>/dev/null | grep -c 'not found' || true)
echo "    unresolved libraries: ${missing:-?}"

echo "==> Done. Use:  $HERE/run.sh <url> [--screenshot out.png]"
