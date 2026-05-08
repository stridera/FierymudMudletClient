#!/usr/bin/env bash
# Build the FierymudRs Mudlet package, copy it into Muditor's public
# directory, and sync `GameConfig.gmcp.client_gui_version` so the
# Rust server's `Client.GUI` GMCP advertisement matches what
# Mudlet just downloaded.
#
# Single source of truth: the `version` field in `mfile`. Bump it
# there, run this script, and:
#   1. muddler builds build/<package>.mpackage
#   2. it's copied to muditor-web's public/mudlet/ so the URL
#      https://muditor.utaboshi.com/mudlet/<package>.mpackage
#      serves the new bytes
#   3. the GameConfig row that the Rust server reads at boot is
#      updated to match — without this step Mudlet's `Client.GUI`
#      version-diff sees an unchanged advertisement and silently
#      keeps the old install. The runtime `RuntimeConfig` resource
#      is loaded once per server boot, so a server restart is
#      required for the new advertise to take effect (we leave
#      that as a manual step — restarting on every package edit
#      would interrupt connected players).
#
# Falls back to a portable JDK + muddler.jar download under
# ~/.local/share/ when Docker isn't available.
#
# Run from this repository's root:
#   ./build-and-publish.sh
#
# Override env vars:
#   PACKAGE_NAME    — defaults to "FierymudRs"
#   MUDITOR_PUBLIC  — defaults to /home/strider/Code/mud/muditor/apps/web/public/mudlet
#   PSQL_DB         — defaults to "fierydev"
#   PSQL_USER       — defaults to "strider"
#   SKIP_DB_SYNC=1  — bypass the GameConfig update (e.g. dry runs)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
MUDITOR_PUBLIC="${MUDITOR_PUBLIC:-/home/strider/Code/mud/muditor/apps/web/public/mudlet}"
PACKAGE_NAME="${PACKAGE_NAME:-FierymudRs}"
PSQL_DB="${PSQL_DB:-fierydev}"
PSQL_USER="${PSQL_USER:-strider}"

# Pull the package version straight out of mfile so the script
# never lies about what got built. `python3 -c` over the JSON is
# more robust than a regex grep against arbitrary spacing.
VERSION="$(python3 -c "import json; print(json.load(open('$REPO_ROOT/mfile'))['version'])")"
echo "[1/4] Building $PACKAGE_NAME version $VERSION from $REPO_ROOT/src/"

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

echo "[2/4] Copying to $MUDITOR_PUBLIC/"
mkdir -p "$MUDITOR_PUBLIC"
cp "$OUT" "$MUDITOR_PUBLIC/"

if [ "${SKIP_DB_SYNC:-}" != "1" ]; then
  echo "[3/4] Updating GameConfig.gmcp.client_gui_version → $VERSION"
  if command -v psql >/dev/null 2>&1; then
    psql -U "$PSQL_USER" -d "$PSQL_DB" -v ON_ERROR_STOP=1 \
         -c "UPDATE \"GameConfig\"
             SET value = '$VERSION'
             WHERE category = 'gmcp' AND key = 'client_gui_version';" \
         >/dev/null
    # The Rust server caches GameConfig at boot — print a reminder.
    echo "    DB row updated. Restart fierymud-rs to pick up the new advertise."
  else
    echo "    WARNING: psql not on PATH. Run manually:"
    echo "      psql -U $PSQL_USER -d $PSQL_DB -c \\"
    echo "        \"UPDATE \\\"GameConfig\\\" SET value='$VERSION'\\"
    echo "         WHERE category='gmcp' AND key='client_gui_version';\""
  fi
else
  echo "[3/4] SKIP_DB_SYNC=1 set — leaving GameConfig untouched."
fi

echo "[4/4] Verifying public URL"
URL="https://muditor.utaboshi.com/mudlet/$PACKAGE_NAME.mpackage"
if curl -sIf "$URL" >/dev/null; then
  echo "    $URL  ✓"
else
  echo "    $URL  (not yet reachable — check Caddy / muditor-web)"
fi

echo
echo "Done. Restart fierymud-rs (so the new GameConfig row is loaded),"
echo "then connect with Mudlet — the Client.GUI version diff triggers"
echo "an in-place update of the installed package."
