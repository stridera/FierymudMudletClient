#!/usr/bin/env bash
# Build the FierymudRs Mudlet package and copy it into Muditor's
# public directory so the Rust server's GMCP `Client.GUI` frame
# can serve it directly to connecting clients.
#
# Default behavior: build via the muddler Docker image (the same
# tool the GitHub Action uses). Falls back to a portable JDK +
# muddler.jar download under ~/.local/share/muddler when Docker
# isn't available — mirrors what we did during the initial port.
#
# Run from this repository's root:
#   ./build-and-publish.sh
#
# Bump the package version in `mfile` before running so Mudlet
# picks up the update on existing installs (it diffs by the
# Client.GUI version field).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
MUDITOR_PUBLIC="${MUDITOR_PUBLIC:-/home/strider/Code/mud/muditor/apps/web/public/mudlet}"
PACKAGE_NAME="${PACKAGE_NAME:-FierymudRs}"

echo "[1/3] Building $PACKAGE_NAME.mpackage from $REPO_ROOT/src/"

if command -v docker >/dev/null 2>&1; then
  docker run --rm -i -u "$(id -u):$(id -g)" \
    -v "$REPO_ROOT:/work" -w /work \
    demonnic/muddler
else
  # Portable fallback. Both tools land under ~/.local/share so
  # subsequent runs reuse the cached install.
  JDK_DIR="$HOME/.local/share/jdk-21"
  MUDDLER_DIR="$HOME/.local/share/muddler"

  if [ ! -x "$JDK_DIR/bin/java" ]; then
    echo "  installing portable JDK to $JDK_DIR"
    mkdir -p "$JDK_DIR"
    curl -sL -o /tmp/jdk.tar.gz \
      'https://download.java.net/java/GA/jdk21.0.2/f2283984656d49d69e91c558476027ac/13/GPL/openjdk-21.0.2_linux-x64_bin.tar.gz'
    tar -xzf /tmp/jdk.tar.gz -C "$JDK_DIR" --strip-components=1
    rm /tmp/jdk.tar.gz
  fi

  if [ ! -x "$MUDDLER_DIR/bin/muddle" ]; then
    echo "  installing muddler to $MUDDLER_DIR"
    mkdir -p "$MUDDLER_DIR"
    curl -sL -o /tmp/muddler.zip \
      'https://github.com/demonnic/muddler/releases/download/1.1.0/muddle-shadow-1.1.0.zip'
    unzip -q /tmp/muddler.zip -d /tmp/muddler-extract
    cp -r /tmp/muddler-extract/muddle-shadow-*/* "$MUDDLER_DIR/"
    rm -rf /tmp/muddler.zip /tmp/muddler-extract
  fi

  export JAVA_HOME="$JDK_DIR"
  export PATH="$JAVA_HOME/bin:$PATH"
  cd "$REPO_ROOT"
  rm -rf build
  "$MUDDLER_DIR/bin/muddle"
fi

OUT="$REPO_ROOT/build/$PACKAGE_NAME.mpackage"
if [ ! -f "$OUT" ]; then
  echo "ERROR: muddler did not produce $OUT" >&2
  exit 1
fi

echo "[2/3] Copying to $MUDITOR_PUBLIC/"
mkdir -p "$MUDITOR_PUBLIC"
cp "$OUT" "$MUDITOR_PUBLIC/"

echo "[3/3] Verifying public URL"
URL="https://muditor.utaboshi.com/mudlet/$PACKAGE_NAME.mpackage"
if curl -sIf "$URL" >/dev/null; then
  echo "    $URL  ✓"
else
  echo "    $URL  (not yet reachable — check Caddy / muditor-web)"
fi

echo
echo "Done. Connect with Mudlet to fierymud-rs to install the new build."
echo "Bump mfile version + re-run this script for subsequent updates."
