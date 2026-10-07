# Headless browser in the sandbox

The sandbox ships **no browser** and runs as an unprivileged user (**no `sudo`**,
no apt package lists). Chromium needs a set of shared libraries that aren't
installed, so `apt-get` can't provide them.

This folder makes a real, scriptable **headless Chromium** work anyway:

1. Install the Playwright npm package + Chromium binaries (user-space, no root).
2. Download the missing `.so` files as Debian `.deb` packages **directly from the
   mirror** and extract them into a private prefix (`~/chromedeps`).
3. Run Chromium with `LD_LIBRARY_PATH` pointing at that prefix.

## Setup

```bash
scripts/headless-browser/setup.sh
```

## Use

```bash
# title/status of a page
scripts/headless-browser/run.sh https://example.com

# screenshot (full page) + rendered text
scripts/headless-browser/run.sh https://example.com --screenshot out.png --full --text

# dump links, or save a PDF
scripts/headless-browser/run.sh https://example.com --links
scripts/headless-browser/run.sh https://example.com --pdf page.pdf
```

`run.sh` sets `LD_LIBRARY_PATH` for you. If you call Playwright from your own
script, replicate that env:

```bash
export LD_LIBRARY_PATH="$HOME/chromedeps/usr/lib/x86_64-linux-gnu:$HOME/chromedeps/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH"
```

## Notes / limits

- Strictly **headless** — no display server, so no visible window or interactive
  session. For pages needing a display, add `xvfb` (also not installed).
- **TLS:** the sandbox egress proxy MITMs TLS (e.g. to inject GitHub
  credentials), so its CA is not trusted by Chromium. The CLI launches with
  `--ignore-certificate-errors` by default; pass `--strict-tls` to enforce
  normal certificate validation.
- Everything is user-space: nothing is written outside `$HOME` and `/tmp`.
- `node_modules/` and the vendored libs are git-ignored.
