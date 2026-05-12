# Agent dev loop

Setup for iterating on `src/` with hot-reload into a running Mudlet, plus
screenshot + layout-dump verification an agent can drive on its own.

This repo is WSL-side; Mudlet runs as a Windows app. All paths and
tooling assume that arrangement on this machine. If the WSL distro is
renamed or Mudlet is moved off Windows, the hard-coded paths in
`scripts/capture-mudlet.ps1` and `MuddlerReload.mpackage` need a touch.

## One-time setup

1. **Open Mudlet** → connect to the **FieryDev** profile (already set up
   pointing at `utaboshi.com:4003`).
2. **Package Manager → Install package** → choose either
   `state/companion/MuddlerReload.mpackage` from this repo or the copy
   sitting at `<FieryDev profile>/MuddlerReload.mpackage`.
   - On install, MuddlerReload immediately installs the current
     `build/FierymudRs.mpackage` for you — no second install needed.
   - You'll see a `[MuddlerReload] watching ...` line in Mudlet's main
     window confirming the file watcher is active.

After that, leave Mudlet open. The companion lives across restarts and
re-arms its file watch on every profile load.

## Loop

```bash
# Terminal: start the Muddler rebuilder
scripts/dev-watch.sh
```

Edit any file under `src/`. Muddler rebuilds `build/FierymudRs.mpackage`
and rewrites `.output`. Mudlet's QFileSystemWatcher polls the UNC path
into WSL (no native cross-boundary notifications) so reload latency is
~1-3 s. The companion then uninstalls and reinstalls `FierymudRs` in
place — Geyser containers tear down via the per-subsystem `teardown`
hooks in `_subsystems`, then the new install rebuilds them.

## Verifying a change

```bash
# Capture the current Mudlet window
scripts/screenshot.sh
# → state/screenshots/latest.png (and a timestamped sibling)

# Dump the Geyser widget tree (run inside Mudlet)
# fm layout
# → state/layout.txt
```

For an agent's pipeline:

- **`state/screenshots/latest.png`** — read via the Read tool to see the
  current Mudlet UI.
- **`state/layout.txt`** — written by `fm layout` from inside Mudlet.
  Stable, sorted widget tree with name, type, hidden state, and
  geometry. Useful when a widget exists but has zero size or is hidden
  off-screen, which a pixel grab can't distinguish from "not created".

The `fm layout` command has to be triggered from inside Mudlet (it's a
Lua alias). Type it in the Mudlet input line or send it via any
trigger/automation you have wired.

## What's actually in the companion

MuddlerReload v0.4 in `state/companion/MuddlerReload.mpackage` does
**not** rely on `addFileWatch` / `sysPathChanged`. Mudlet's underlying
QFileSystemWatcher does not deliver change events for UNC paths into
WSL — confirmed empirically. The companion instead polls
`lfs.attributes(<mpackage>).modification` every 2 s, on the mpackage
itself (not on `.output`, whose body is identical across every build).
Latency is bounded by that 2 s poll plus ~1 s for the package install
and the `scheduleTryInit` debounce, so total edit → visible reload is
roughly 3 s.

## Failure modes you'll actually hit

- **`scripts/screenshot.sh` says "Mudlet process not found"** — Mudlet
  isn't running, or it's minimized (PrintWindow refuses on iconic
  windows). Restore the window and retry.
- **Edit saved but Mudlet doesn't reload** — companion polls every 2 s.
  Wait 4-5 s. If it never fires, check Mudlet's main console for
  `[MuddlerReload]` lines; absence means the script didn't start
  (reinstall the companion). The polling watches the *mpackage*'s
  `lfs.attributes` fingerprint; `.output`'s bytes never change.
- **Reload runs but the GUI vanishes / stays hidden** — Adjustable
  containers persist `hidden` state through their global
  `Adjustable.Container.all[name]` registry. If a teardown calls
  `:hide()` and doesn't also clear that registry entry, the next
  `:new()` inherits the hidden flag. The cleanup helper in
  `src/scripts/FierymudRs/GUI.lua` (`destroyGeyserSubtree`) does this;
  copy the pattern when adding new top-level Adjustable containers.
- **`Guages subsystem setup failed: ...GeyserSetConstraints.lua:111`**
  — a width / height constraint is unparseable. Strings like `"auto"`
  are *not* valid Geyser constraints; the parser strips letters and
  then `tonumber("")` returns nil. Use a concrete value (`"200px"`,
  `"30%"`) or omit the field entirely to inherit the Geyser default.
- **Reload "works" but the UI looks stacked / duplicated** — a subsystem
  is missing a `teardown` hook in `_subsystems`, so its widgets survive
  reinstall and the new setup runs on top. Add a teardown that nils
  the subsystem's `isReady` marker fields and walks any widgets it
  owns through `FierymudRs._destroyGeyserSubtree`.
- **`fm layout` writes to the wrong path** — falls back to
  `getMudletHomeDir() .. /layout.txt` when MuddlerReload isn't
  installed. Install MuddlerReload (it sets the `repoPath`) or pass an
  explicit path: `fm layout /some/abs/path.txt`.

## Init kick — why `scheduleTryInit()` runs at script-body end

On a fresh Mudlet open, `sysLoadEvent` / `sysInstall` fire and the
registered `onSession` handler kicks off init. On hot-reload (the
companion uninstalls + reinstalls this package), `sysInstall` does
*not* reliably reach the newly-registered handler — sometimes it
fires before `bindHandlers()` runs, sometimes it's dropped when the
previous package's handler is deleted mid-flight. The unconditional
`scheduleTryInit()` at the bottom of GUI.lua covers that case;
`scheduleTryInit` debounces via a named timer so first-load and
hot-reload paths don't double-init.

## Deterministic GUI testing — mock GMCP daemon

`scripts/mock_mud.py` is a stdlib-only Python daemon that speaks just
enough telnet+GMCP for Mudlet to attach to it as a regular MUD.
Mudlet stays connected to it across test cycles; scenarios get pushed
in over a separate **control channel**.

### Two ports

- **`:4099`** — Mudlet-facing telnet+GMCP socket. Holds one
  persistent Mudlet connection. If Mudlet disconnects, the daemon
  accepts the next reconnect without restart.
- **`:4100`** — control channel. Any number of TCP clients can
  connect (driver scripts, `nc`, future tooling) and stream
  commands. Async events from Mudlet (plain text, GMCP frames the
  client sends back, connect / disconnect) get broadcast to every
  control subscriber.

### One-time setup

The `FieryTest` Mudlet profile is pre-configured at `localhost:4099`
with `autoreconnect=true` and `MuddlerReload.path` populated. Install
`state/companion/MuddlerReload.mpackage` the first time the profile
opens (same drill as FieryDev). Autoreconnect handles every later
disconnect — no manual Reconnect click needed.

### Run the daemon

```bash
scripts/mock_mud.py             # daemon, no auto-scenario
scripts/mock_mud.py --repl      # daemon + stdin REPL
scripts/mock_mud.py --verbose   # log raw bytes + forwarded GMCP/text
```

Leave it running in a terminal. Mudlet connects (and reconnects)
automatically when its profile is open.

### Drive scenarios via test-runner

```bash
scripts/test-runner.sh                          # all scenarios
scripts/test-runner.sh effects_full vitals_low_hp  # subset by name
```

The runner pipes commands into the control channel on `:4100`,
waits for Mudlet, runs `reset` between scenarios, and lets the
scenario's own `screenshot <name>` lines capture into
`state/screenshots/<name>.png`. Requires `ncat` (or `nc`).

### Ad-hoc commands via the control channel

Any TCP client works. With `ncat`:

```bash
echo 'gmcp Char.Vitals {"hp":50,"maxhp":200,"mv":80,"maxmv":100,"nl":33}
prompt
screenshot manual_test
quit' | ncat --idle-timeout 2 localhost 4100
```

Or interactively:

```bash
ncat localhost 4100
+ welcome mock_mud daemon
+ status mudlet=connected addr=127.0.0.1:53412 sent=0 ctrl_clients=1
status
wait_connected 5
reset
gmcp Char.Vitals {"hp":20,"maxhp":200,"mv":50,"maxmv":100,"nl":10}
prompt
screenshot low_hp_manual
quit
```

### Control protocol

Same scenario syntax as before plus a few meta-commands:

| Line                         | Behavior |
|------------------------------|----------|
| `text <body>`                | raw bytes to Mudlet; `\n` → newline |
| `line <body>`                | text + CRLF |
| `prompt`                     | `\r\nHP:100/100 MV:100/100 > ` (fires onPrompt) |
| `gmcp <pkg> <json>`          | one IAC SB 201 ... IAC SE frame |
| `delay <secs>`               | server-side sleep |
| `screenshot <name>`          | call `scripts/screenshot.sh`, copy to `<name>.png` |
| `reset`                      | send default frames for every known package |
| `status`                     | `+ status mudlet=... sent=... ctrl_clients=...` |
| `wait_connected [secs]`      | block until Mudlet attaches (default 30s) |
| `quit`                       | close this control connection |
| `close`                      | terminate the Mudlet connection |

Responses: `+ ok ...` (success), `! <kind>: <msg>` (error).
Async events: `< mudlet_connected <addr>`, `< mudlet_disconnected`,
`< mudlet_text "..."`, `< mudlet_gmcp <pkg> <body>`.

### Writing a new scenario

Drop a `.txt` file in `scripts/scenarios/`. One command per line; the
shape of GMCP payloads must match what the package's consumers
expect — see `src/scripts/FierymudRs/Vitals/Vitals.lua` for the
canonical schema (`Char.Vitals` uses `maxhp`/`mv`/`maxmv`/`nl`,
not `max_hp`). Existing scenarios under `scripts/scenarios/` are
the worked reference.

### Visual diff workflow

The mock loop pairs with hot-reload: edit `src/`, the dev-watch
rebuilds and the companion reloads, then re-run scenarios via the
runner and compare `state/screenshots/<name>.png` against the
prior version. (No golden-image storage yet, just timestamped
history under `state/screenshots/`.)

## Diagnostic outputs at a glance

| File                            | Written by                  | Read for                                  |
|---------------------------------|-----------------------------|-------------------------------------------|
| `state/screenshots/latest.png`  | `scripts/screenshot.sh`     | What the GUI currently looks like         |
| `state/screenshots/<UTC>.png`   | `scripts/screenshot.sh`     | History — diff against an older capture   |
| `state/screenshots/<name>.png`  | `screenshot <name>` (mock)  | Named capture from a scenario             |
| `state/layout.txt`              | `fm layout` (Mudlet alias)  | Geyser widget tree — visibility & geometry |
| `state/errors.txt`              | `FierymudRs.logError`       | Subsystem setup failures with timestamps  |

The `fm` aliases for reading these inside Mudlet:
`fm layout`, `fm errors [N]`, `fm clearerrors`.

## Files this loop touches

```
scripts/dev-watch.sh           # Muddler -w in Docker
scripts/screenshot.sh          # PowerShell-driven window capture
scripts/capture-mudlet.ps1     # PrintWindow → PNG, called by above
scripts/mock_mud.py            # daemon: :4099 telnet, :4100 control
scripts/test-runner.sh         # pipes scenarios into the control channel
scripts/scenarios/*.txt        # example test scenarios
state/companion/MuddlerReload.mpackage  # hot-reload companion (v0.5+)
state/screenshots/             # screenshot output
state/layout.txt               # fm layout output
state/errors.txt               # FierymudRs.logError append target
.output                        # Muddler's "fresh build" pointer
build/FierymudRs.mpackage      # what the companion reinstalls
<MudletProfile>/MuddlerReload.path  # per-profile repo path override
```
