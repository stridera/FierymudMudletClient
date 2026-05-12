#!/usr/bin/env bash
# Drive scripts/scenarios/*.txt through a running mock_mud daemon.
#
# Expects the daemon to already be running (start with `scripts/mock_mud.py`).
# Connects to the control channel on localhost:4100, waits for a Mudlet
# attachment, then for each scenario:
#   1. reset      — blank the UI state
#   2. cat <file> — replay one command per line
#   3. delay 1    — let the screenshot capture the post-scenario frame
#
# Screenshots land in state/screenshots/<scenario-name>.png from inside
# the scenario file's `screenshot <name>` line.
#
# Usage:
#   scripts/test-runner.sh                          # all scenarios in order
#   scripts/test-runner.sh effects_full vitals_low_hp  # subset, no .txt suffix
#
# Requires nc (netcat). On Debian/WSL: `sudo apt install ncat`.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCENARIO_DIR="$REPO_DIR/scripts/scenarios"
CTRL_HOST="${MOCK_MUD_HOST:-127.0.0.1}"
CTRL_PORT="${MOCK_MUD_CTRL_PORT:-4100}"

NC="$(command -v ncat || command -v nc || true)"
if [ -z "$NC" ]; then
  echo "error: ncat or nc required — install with: sudo apt install ncat" >&2
  exit 1
fi

# Pick scenarios — args, or the full set in scenarios/.
declare -a SCENARIOS=()
if [ "$#" -gt 0 ]; then
  for name in "$@"; do
    f="$SCENARIO_DIR/${name%.txt}.txt"
    if [ ! -f "$f" ]; then
      echo "error: scenario not found: $f" >&2
      exit 2
    fi
    SCENARIOS+=("$f")
  done
else
  while IFS= read -r f; do SCENARIOS+=("$f"); done < <(find "$SCENARIO_DIR" -name '*.txt' | sort)
fi
if [ "${#SCENARIOS[@]}" -eq 0 ]; then
  echo "error: no scenarios found in $SCENARIO_DIR" >&2
  exit 2
fi

# Build a single command stream and pipe it to nc. ncat closes when stdin
# closes, so we wait for all responses by sleeping briefly at the end.
build_commands() {
  echo "wait_connected 30"
  # After Mudlet attaches, the FierymudRs package may still be installing
  # (companion polls every 2s; install + scheduleTryInit debounce ~1.5s).
  # Until init completes, gmcp.Char handlers aren't registered, so frames
  # arrive at a UI that ignores them. 4s gives both first-install and
  # already-installed paths headroom to settle.
  echo "delay 4"
  for f in "${SCENARIOS[@]}"; do
    name="$(basename "$f" .txt)"
    echo "# === scenario: $name ==="
    echo "reset"
    echo "delay 0.5"
    cat "$f"
    # Each scenario file ends with its own `screenshot <name>` line — no extra
    # capture needed here. Just give the screenshot subprocess time to flush.
    echo "delay 0.5"
  done
  echo "quit"
}

# nc -q1: exit 1s after EOF on stdin. ncat uses --idle-timeout for similar.
case "$(basename "$NC")" in
  ncat) NCFLAGS=(--idle-timeout 3) ;;
  *)    NCFLAGS=(-q 3) ;;
esac

echo "==> driver: ${#SCENARIOS[@]} scenarios via $NC -> $CTRL_HOST:$CTRL_PORT" >&2
build_commands | "$NC" "${NCFLAGS[@]}" "$CTRL_HOST" "$CTRL_PORT"
