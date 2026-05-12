#!/usr/bin/env bash
# Run Muddler in watch mode so every edit under src/ rebuilds
# build/FierymudRs.mpackage. Paired with the MuddlerReload
# companion package installed in the FieryDev Mudlet profile,
# this gives a save → ~1-3s → hot-reload loop.
#
# Usage:
#   scripts/dev-watch.sh
#
# Stops on Ctrl-C. Re-running is safe.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

if ! command -v docker >/dev/null 2>&1; then
  echo "error: docker not on PATH" >&2
  exit 1
fi

# Pull lazily — first run grabs the image, subsequent runs hit cache.
if ! docker image inspect demonnic/muddler >/dev/null 2>&1; then
  echo "fetching demonnic/muddler image..."
  docker pull demonnic/muddler
fi

# Mount the repo into the container at the same path so the
# `.output` written by Muddler points at a real WSL path the
# host (and Mudlet via UNC) can resolve.
echo "[dev-watch] starting Muddler -w in $REPO_DIR"
echo "[dev-watch] save any file under src/ to trigger a rebuild"
echo "[dev-watch] Ctrl-C to stop"
echo

exec docker run --rm -it \
  -u "$(id -u):$(id -g)" \
  -v "$REPO_DIR:$REPO_DIR" \
  -w "$REPO_DIR" \
  demonnic/muddler -w
