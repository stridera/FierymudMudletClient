#!/usr/bin/env bash
# Build MuddlerReload.mpackage from companion/ sources.
#
# MuddlerReload is the hot-reload + remote-eval companion package
# installed alongside FierymudRs in the FieryTest profile. Source
# is companion/MuddlerReload.xml + companion/config.lua; output is
# state/companion/MuddlerReload.mpackage (gitignored — build
# artifact). Build also copies the artifact into the FieryTest
# profile dir so an in-Mudlet reinstall picks it up.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$REPO_DIR/state/companion"
PROFILE_DIR="/mnt/c/Users/strid/.config/mudlet/profiles/FieryTest"

mkdir -p "$OUT_DIR"

python3 - <<EOF
import os, zipfile
os.chdir("$REPO_DIR/companion")
with zipfile.ZipFile("$OUT_DIR/MuddlerReload.mpackage", "w",
                     zipfile.ZIP_DEFLATED) as z:
    z.write("MuddlerReload.xml")
    z.write("config.lua")
EOF

if [ -d "$PROFILE_DIR" ]; then
  cp "$OUT_DIR/MuddlerReload.mpackage" "$PROFILE_DIR/MuddlerReload.mpackage"
  echo "built + staged to $PROFILE_DIR/MuddlerReload.mpackage"
else
  echo "built $OUT_DIR/MuddlerReload.mpackage (no FieryTest profile to stage)"
fi
