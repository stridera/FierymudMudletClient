#!/usr/bin/env bash
# Screenshot the running Mudlet window (Windows-side) and save
# to state/screenshots/. Writes both:
#   state/screenshots/latest.png            (fixed name for Read tool)
#   state/screenshots/<UTC-timestamp>.png   (history)
#
# Returns exit 0 on success, non-zero on failure (Mudlet not
# running, window minimized, etc.).

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$REPO_DIR/state/screenshots"
mkdir -p "$OUT_DIR"

TS="$(date -u +%Y%m%dT%H%M%SZ)"
TS_PATH="$OUT_DIR/$TS.png"
LATEST_PATH="$OUT_DIR/latest.png"

PS1_PATH="$REPO_DIR/scripts/capture-mudlet.ps1"

# Translate the WSL path to a Windows path PowerShell will
# accept. wslpath ships with WSL2 by default.
PS1_WIN="$(wslpath -w "$PS1_PATH")"
OUT_WIN="$(wslpath -w "$TS_PATH")"

# Resolve powershell.exe — PATH lookup first, then the canonical
# absolute path. Different shells/sessions inherit different PATH
# layouts on WSL; the absolute path is stable.
PSEXE="$(command -v powershell.exe 2>/dev/null || true)"
if [ -z "$PSEXE" ]; then
  PSEXE="/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
fi
if [ ! -x "$PSEXE" ]; then
  echo "powershell.exe not found" >&2
  exit 1
fi

# `-ExecutionPolicy Bypass`: scripts/ files aren't signed.
# `-NoProfile`: skips loading the user's PS profile (~200ms cold-start savings).
if ! "$PSEXE" -NoProfile -ExecutionPolicy Bypass \
       -File "$PS1_WIN" -OutPath "$OUT_WIN" 2>&1; then
  echo "screenshot failed" >&2
  exit 1
fi

# Mirror the latest into a stable filename. Use cp+mv-atomic so
# a concurrent Read picks up either the old or the new full
# file, never a half-written one.
cp "$TS_PATH" "$LATEST_PATH.tmp"
mv "$LATEST_PATH.tmp" "$LATEST_PATH"

echo "saved $LATEST_PATH (timestamped: $(basename "$TS_PATH"))"
