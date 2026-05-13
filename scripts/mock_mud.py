#!/usr/bin/env python3
"""Mock telnet+GMCP MUD daemon for deterministic GUI testing.

Two TCP listeners:
  - `:4099` (--port)       Mudlet attaches here. One persistent
                           Mudlet connection at a time; survives
                           Mudlet's autoreconnect cycles.
  - `:4100` (--ctrl-port)  Control channel. Any number of driver
                           clients connect via plain TCP. Commands
                           sent here are translated into GMCP/text
                           frames on the Mudlet socket. Async events
                           (Mudlet connect/disconnect, GMCP frames
                           the client sends back, plain input lines)
                           flow back to every subscribed control
                           client.

Command grammar (one per line, identical on REPL, scenario file, and
control channel):

    # any comment
    text <free text — \\n escapes to a real newline>
    line <text>            shorthand for `text <text>\\n`
    prompt                 sends "HP:100/100 MV:100/100 > "; fires onPrompt
    gmcp <package> <json>  e.g.  gmcp Char.Vitals {"hp":50,"maxhp":200}
    delay <seconds>        pause server-side before the next command
    screenshot <name>      call scripts/screenshot.sh, copy to <name>.png
    reset                  send default GMCP frames to clear UI state
    quit                   (control) close this control connection
    close                  (control) terminate the Mudlet connection

Control-only meta-commands:

    status                 + status mudlet=<connected|disconnected> sent=<N>
    wait_connected [secs]  block until Mudlet is attached; default 30s

Control responses:
    + ok ...               command accepted
    ! <kind>: <msg>        command failed
    < <event> [...]        async event broadcast (mudlet_connected, etc.)

Run:
    scripts/mock_mud.py                              # daemon, no initial script
    scripts/mock_mud.py --scenario scripts/...txt    # daemon, plays scenario on first conn
    scripts/mock_mud.py --scenario file --once       # legacy one-shot, exits after
    scripts/mock_mud.py --repl                       # daemon + stdin REPL
"""

from __future__ import annotations

import argparse
import json
import os
import queue
import shutil
import socket
import subprocess
import sys
import threading
import time
import uuid
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

# --- Telnet bytes ----------------------------------------------------------
IAC = bytes([255])
DONT = bytes([254])
DO = bytes([253])
WONT = bytes([252])
WILL = bytes([251])
SB = bytes([250])
SE = bytes([240])

OPT_GMCP = bytes([201])  # 0xC9
GA = bytes([249])        # Go-Ahead — terminates a prompt line

REPO_ROOT = Path(__file__).resolve().parent.parent


# --- GMCP framing ----------------------------------------------------------
def encode_gmcp(package: str, payload) -> bytes:
    """Encode one GMCP message as a telnet subnegotiation block."""
    if isinstance(payload, (dict, list)):
        body = json.dumps(payload, separators=(",", ":"))
    elif payload is None:
        body = ""
    else:
        body = str(payload)
    full = (package + (" " + body if body else "")).encode("utf-8")
    return IAC + SB + OPT_GMCP + full + IAC + SE


# Default GMCP frames sent by `reset`. Matches the package's
# consumer expectations (see src/scripts/FierymudRs/Vitals/Vitals.lua
# for the canonical schema). New consumers should add their reset
# frame here so `reset` returns the UI to a known-blank state.
RESET_FRAMES = [
    ("Char.Status", {"name": "", "class": "", "level": 0, "xp": 0, "wealth": 0}),
    ("Char.Vitals", {"hp": 1, "maxhp": 1, "mv": 1, "maxmv": 1, "nl": 0, "string": ""}),
    ("Char.Effects", []),
    ("Group", {}),
    ("Char.Aggro", {"hating": [], "remembering": []}),
    ("Room.Players", []),
    ("Char.Combat", {}),
]


# --- Incoming-byte handler -------------------------------------------------
class IncomingDrain(threading.Thread):
    """Read client bytes; surface plain input + signal GMCP negotiation.

    `gmcp_agreed` flips when we observe the client send `IAC DO 201`,
    confirming it's ready to receive GMCP frames. Sending frames
    before that point is a race — Mudlet's GMCP receiver isn't yet
    armed and our subnegotiations get discarded silently.

    `on_text` and `on_gmcp` callbacks let the daemon forward
    Mudlet-side events to control subscribers.
    """

    def __init__(self, conn: socket.socket, verbose: bool,
                 on_text=None, on_gmcp=None):
        super().__init__(daemon=True)
        self.conn = conn
        self.verbose = verbose
        self.alive = True
        self.gmcp_agreed = threading.Event()
        self.on_text = on_text
        self.on_gmcp = on_gmcp

    def run(self):
        buf = bytearray()
        while self.alive:
            try:
                chunk = self.conn.recv(4096)
            except OSError:
                return
            if not chunk:
                return
            if self.verbose:
                print(f"<- raw {len(chunk):3}B: {chunk.hex()}", flush=True)
            buf.extend(chunk)
            text, sb_frames, buf[:] = _parse_telnet(buf, self)
            if text:
                if self.verbose:
                    print(f"<- client text: {text!r}", flush=True)
                if self.on_text:
                    self.on_text(text)
            for sb in sb_frames:
                if len(sb) >= 1 and sb[0] == 201:
                    body = bytes(sb[1:]).decode("utf-8", errors="replace")
                    if self.verbose:
                        print(f"<- client GMCP: {body}", flush=True)
                    if self.on_gmcp:
                        self.on_gmcp(body)


def _parse_telnet(buf: bytearray, drain: "IncomingDrain"):
    """Consume telnet bytes from buf; return (text, sb_frames, leftover).

    `text` is plain (non-IAC) bytes decoded as UTF-8.
    `sb_frames` is a list of subnegotiation payloads (bytes), with the
    option byte still at index 0 (so GMCP frames start with 0xC9).
    `leftover` is whatever's left after partial IAC sequences — should
    be carried forward so we don't double-process on the next recv.
    """
    out = bytearray()
    sb_frames = []
    i = 0
    n = len(buf)
    while i < n:
        b = buf[i]
        if b == 255:  # IAC
            if i + 1 >= n:
                break  # need more bytes
            cmd = buf[i + 1]
            if cmd in (253, 254, 251, 252):  # DO / DONT / WILL / WONT
                if i + 2 >= n:
                    break
                opt = buf[i + 2]
                if cmd == 253 and opt == 201:
                    drain.gmcp_agreed.set()
                i += 3
                continue
            if cmd == 250:  # SB ... SE
                j = i + 2
                end = -1
                while j < n - 1:
                    if buf[j] == 255 and buf[j + 1] == 240:
                        end = j
                        break
                    j += 1
                if end < 0:
                    break  # SE not arrived yet
                sb_frames.append(bytes(buf[i + 2 : end]))
                i = end + 2
                continue
            i += 2
            continue
        out.append(b)
        i += 1
    leftover = buf[i:]
    try:
        text = bytes(out).decode("utf-8", errors="replace")
    except Exception:
        text = ""
    return text, sb_frames, leftover


# --- Client state ----------------------------------------------------------
@dataclass
class ClientState:
    conn: socket.socket
    addr: tuple
    drain: "IncomingDrain"
    sent: int = 0


def greet(state: ClientState) -> None:
    """Initial banner + GMCP negotiation."""
    state.conn.sendall(
        b"\033[1;36m== Mock FieryMUD test server ==\033[0m\r\n"
        b"GMCP daemon. Drive via :4100 control channel.\r\n"
    )
    state.conn.sendall(IAC + WILL + OPT_GMCP)


def await_gmcp_agreement(state: ClientState, timeout: float = 5.0) -> bool:
    """Block until the client confirms GMCP with `IAC DO 201`."""
    if state.drain.gmcp_agreed.wait(timeout):
        return True
    print(
        f"warning: no IAC DO GMCP within {timeout}s — "
        "client may not support GMCP; sending anyway",
        file=sys.stderr,
    )
    return False


def do_command(state: ClientState, cmd: str) -> tuple[bool, str]:
    """Execute one command line against the connected Mudlet client.

    Returns (keep_going, response_text). `keep_going=False` means
    the caller should close the *Mudlet* connection (e.g. `close`).
    `response_text` is what the control channel echoes back; for
    one-shot scenario / REPL invocation it's just printed.
    """
    cmd = cmd.rstrip("\r\n")
    if not cmd or cmd.lstrip().startswith("#"):
        return True, "+ ok empty\n"

    head, _, rest = cmd.partition(" ")
    head = head.lower()
    rest = rest.lstrip()

    if head == "text":
        payload = rest.replace("\\n", "\n").replace("\\t", "\t")
        state.conn.sendall(payload.encode("utf-8"))
        state.sent += 1
        return True, "+ ok text\n"
    elif head == "line":
        state.conn.sendall((rest + "\r\n").encode("utf-8"))
        state.sent += 1
        return True, "+ ok line\n"
    elif head == "prompt":
        # Send the text WITHOUT a trailing newline and follow with IAC GA.
        # Mudlet's prompt-type triggers fire on Go-Ahead (or EOR); without
        # it the prompt line is treated as regular output and the
        # FierymudRs `onPrompt` chain (Character:update etc.) never runs.
        state.conn.sendall(b"\r\nHP:100/100 MV:100/100 > " + IAC + GA)
        state.sent += 1
        return True, "+ ok prompt\n"
    elif head == "gmcp":
        pkg, _, body = rest.partition(" ")
        body = body.strip()
        if not pkg:
            return True, "! usage: gmcp <package> [json]\n"
        if body == "":
            payload = None
        else:
            try:
                payload = json.loads(body)
            except json.JSONDecodeError as e:
                return True, f"! json: {e}\n"
        state.conn.sendall(encode_gmcp(pkg, payload))
        state.sent += 1
        return True, f"+ ok gmcp {pkg}\n"
    elif head == "delay":
        try:
            secs = float(rest)
        except ValueError:
            return True, f"! usage: delay <seconds>\n"
        time.sleep(secs)
        return True, f"+ ok delay {secs}\n"
    elif head == "screenshot":
        name = rest or f"shot_{int(time.time())}"
        if not name.endswith(".png"):
            name += ".png"
        ok, msg = take_screenshot(name)
        return True, ("+ ok screenshot " + msg + "\n") if ok else ("! screenshot " + msg + "\n")
    elif head == "reset":
        for pkg, body in RESET_FRAMES:
            state.conn.sendall(encode_gmcp(pkg, body))
            state.sent += 1
        return True, f"+ ok reset ({len(RESET_FRAMES)} frames)\n"
    elif head == "close":
        return False, "+ ok closing\n"
    elif head == "help":
        return True, "+ ok see scripts/mock_mud.py docstring\n"
    else:
        return True, f"! unknown_command {head}\n"


def take_screenshot(name: str) -> tuple[bool, str]:
    """Invoke scripts/screenshot.sh and copy the latest png to <name>."""
    script = REPO_ROOT / "scripts" / "screenshot.sh"
    if not script.exists():
        return False, f"missing {script}"
    try:
        result = subprocess.run(
            ["bash", str(script)],
            capture_output=True,
            text=True,
            timeout=10,
        )
    except Exception as e:
        return False, f"{type(e).__name__}: {e}"
    if result.returncode != 0:
        return False, f"exited {result.returncode}: {result.stderr.strip()}"
    src = REPO_ROOT / "state" / "screenshots" / "latest.png"
    dst = REPO_ROOT / "state" / "screenshots" / name
    if src.exists():
        shutil.copyfile(src, dst)
        print(f"-> screenshot {dst}", flush=True)
        return True, str(dst.relative_to(REPO_ROOT))
    return False, f"expected {src} not found"


# --- Daemon ----------------------------------------------------------------
def make_listener(host: str, port: int) -> socket.socket:
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind((host, port))
    s.listen(8)
    return s


@dataclass
class Daemon:
    telnet_host: str
    telnet_port: int
    ctrl_host: str
    ctrl_port: int
    verbose: bool
    initial_scenario: Optional[Path] = None
    lock: threading.Lock = field(default_factory=threading.Lock)
    client_state: Optional[ClientState] = None
    ctrl_clients: list = field(default_factory=list)
    pending_execs: dict = field(default_factory=dict)  # id -> queue.Queue
    mudlet_connected_event: threading.Event = field(default_factory=threading.Event)
    mudlet_ready_event: threading.Event = field(default_factory=threading.Event)
    shutdown: threading.Event = field(default_factory=threading.Event)

    def broadcast(self, msg: str) -> None:
        """Send an async event line to every control subscriber."""
        line = f"< {msg}\n"
        with self.lock:
            clients = list(self.ctrl_clients)
        for c in clients:
            c.send(line)

    def _on_mudlet_gmcp(self, body: str) -> None:
        """Drain callback for inbound GMCP from Mudlet.

        Broadcasts the raw frame as an event AND routes responses
        from the remote-eval channel to whatever `eval_sync` call is
        blocked on the matching id. Accepts both `Test.Result` (GMCP
        request path) and `MRResult` (text-trigger MREXEC path); the
        latter is the reliable mechanism since custom-package inbound
        GMCP doesn't fire Mudlet handlers in this version.
        """
        self.broadcast(f"mudlet_gmcp {body}")
        sp = body.find(" ")
        if sp < 0:
            return
        pkg = body[:sp]
        if pkg == "MRReady":
            # Companion is loaded AND the MUD socket has settled —
            # safe to push commands and expect responses now.
            self.mudlet_ready_event.set()
            self.broadcast(f"mudlet_ready {body[sp + 1:]}")
            return
        if pkg != "Test.Result" and pkg != "MRResult":
            return
        try:
            data = json.loads(body[sp + 1:])
        except json.JSONDecodeError:
            return
        rid = data.get("id")
        if not rid:
            return
        with self.lock:
            q = self.pending_execs.get(rid)
        if q is not None:
            q.put(data)

    def telnet_loop(self) -> None:
        srv = make_listener(self.telnet_host, self.telnet_port)
        print(f"telnet listener on {self.telnet_host}:{self.telnet_port}", flush=True)
        while not self.shutdown.is_set():
            try:
                conn, addr = srv.accept()
            except OSError:
                return
            print(f"Mudlet connected from {addr[0]}:{addr[1]}", flush=True)

            on_text = lambda t: self.broadcast(f"mudlet_text {json.dumps(t)}")
            drain = IncomingDrain(conn, self.verbose, on_text=on_text,
                                  on_gmcp=self._on_mudlet_gmcp)
            drain.start()
            state = ClientState(conn=conn, addr=addr, drain=drain)
            greet(state)
            await_gmcp_agreement(state)
            with self.lock:
                self.client_state = state
            self.mudlet_connected_event.set()
            self.broadcast(f"mudlet_connected {addr[0]}:{addr[1]}")
            print("Mudlet agreed to GMCP — ready for commands", flush=True)

            # Run initial scenario, if any, on the very first connection.
            if self.initial_scenario is not None:
                self._run_scenario_locked(self.initial_scenario)
                self.initial_scenario = None  # one-time

            # Wait for drain to die (client disconnect).
            drain.join()
            with self.lock:
                self.client_state = None
                self.mudlet_connected_event.clear()
                self.mudlet_ready_event.clear()
            try:
                conn.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass
            conn.close()
            print(f"Mudlet disconnected (sent {state.sent} cmds)", flush=True)
            self.broadcast("mudlet_disconnected")

    def ctrl_loop(self) -> None:
        srv = make_listener(self.ctrl_host, self.ctrl_port)
        print(f"control listener on {self.ctrl_host}:{self.ctrl_port}", flush=True)
        while not self.shutdown.is_set():
            try:
                conn, addr = srv.accept()
            except OSError:
                return
            CtrlClient(self, conn, addr).start()

    def _run_scenario_locked(self, path: Path) -> None:
        """Replay a scenario file against the current Mudlet conn.

        Runs in the telnet thread holding no lock; `client_state` is
        captured at call time and stable until the drain dies.
        """
        with self.lock:
            state = self.client_state
        if not state:
            print(f"no Mudlet conn — skipping scenario {path}", file=sys.stderr)
            return
        print(f"replaying {path}", flush=True)
        passed = 0
        failed = 0
        with path.open() as f:
            for raw in f:
                line = raw.rstrip("\n")
                if line.strip():
                    print(f"-> {line}", flush=True)
                head = line.split(maxsplit=1)
                if head and head[0].lower() in ("assert", "expect"):
                    ok, msg = self._scenario_assert(line)
                    if ok:
                        passed += 1
                        print(f"   + {msg}", flush=True)
                    else:
                        failed += 1
                        print(f"   ! {msg}", flush=True, file=sys.stderr)
                    continue
                keep, _ = do_command(state, line)
                if not keep:
                    return
        if passed or failed:
            print(f"scenario {path.name}: {passed} passed, {failed} failed",
                  flush=True)

    def _scenario_assert(self, line: str) -> tuple[bool, str]:
        """Run a scenario-level `assert <expr>` via the eval channel.

        Truthy / non-nil / non-false result = pass. Anything else
        (including a Lua error or eval timeout) = fail. The reason
        is included in the message for both.
        """
        _, _, body = line.partition(" ")
        body = body.strip()
        if not body:
            return False, "empty assert"
        data, err = self.eval_sync(body, timeout=5.0)
        if err:
            return False, f"eval_error: {err}  ({body})"
        if not data.get("ok"):
            return False, f"lua_error: {data.get('error')}  ({body})"
        # Lua falsy: nil, false. Anything else passes.
        result = data.get("result")
        if result is None or result == "nil" or result == "false":
            return False, f"falsy: {result!r}  ({body})"
        return True, f"{body} => {result}"

    def execute(self, line: str) -> tuple[bool, str]:
        """Execute a single command line against the current Mudlet conn."""
        head = line.split(maxsplit=1)
        if head and head[0].lower() in ("assert", "expect"):
            ok, msg = self._scenario_assert(line)
            return True, ("+ ok " if ok else "! ") + msg + "\n"
        with self.lock:
            state = self.client_state
        if not state:
            return True, "! no_mudlet_connection\n"
        try:
            return do_command(state, line)
        except Exception as e:
            return True, f"! {type(e).__name__}: {e}\n"

    def send_exec_async(self, code: str) -> Optional[str]:
        """Push code at Mudlet via the MREXEC text trigger; return the id.

        Sends `MREXEC:<id>:<code>\\r\\n` as a plain line — the
        MuddlerReload trigger fires, runs the code, and sends back
        `gmcp MRResult {id, ok, result, error, printed}` (outbound
        GMCP works reliably; inbound to handlers does not).
        The result arrives asynchronously to ctrl subscribers.
        """
        with self.lock:
            state = self.client_state
        if not state:
            return None
        rid = uuid.uuid4().hex[:8]
        line = f"MREXEC:{rid}:{code}\r\n".encode("utf-8")
        try:
            state.conn.sendall(line)
            state.sent += 1
        except OSError:
            return None
        return rid

    def eval_sync(self, code: str, timeout: float = 10.0):
        """Send via MREXEC, block until the matching MRResult arrives.

        Returns (result_dict, error_msg). result_dict is the parsed
        MRResult payload {id, ok, result, error, printed}.
        """
        with self.lock:
            state = self.client_state
            if not state:
                return None, "no_mudlet_connection"
            rid = uuid.uuid4().hex[:8]
            q: queue.Queue = queue.Queue()
            self.pending_execs[rid] = q
        line = f"MREXEC:{rid}:{code}\r\n".encode("utf-8")
        try:
            state.conn.sendall(line)
            state.sent += 1
        except OSError as e:
            with self.lock:
                self.pending_execs.pop(rid, None)
            return None, f"send_failed: {e}"
        try:
            data = q.get(timeout=timeout)
            return data, None
        except queue.Empty:
            return None, "timeout"
        finally:
            with self.lock:
                self.pending_execs.pop(rid, None)

    def status_line(self) -> str:
        with self.lock:
            state = self.client_state
            n_ctrl = len(self.ctrl_clients)
        if state:
            return (f"+ status mudlet=connected addr={state.addr[0]}:{state.addr[1]} "
                    f"sent={state.sent} ctrl_clients={n_ctrl}\n")
        return f"+ status mudlet=disconnected ctrl_clients={n_ctrl}\n"

    def wait_connected(self, timeout: float) -> bool:
        return self.mudlet_connected_event.wait(timeout)

    def wait_ready(self, timeout: float) -> bool:
        """Block until MuddlerReload announces it's loaded + connected.

        Stronger than `wait_connected` — that only fires when the
        socket comes up. `wait_ready` waits for `MRReady` GMCP from
        the companion, which confirms the trigger is armed and exec
        commands will be routed.
        """
        return self.mudlet_ready_event.wait(timeout)


class CtrlClient(threading.Thread):
    """One control-channel connection. Reads command lines, executes them,
    writes responses + async events back."""

    def __init__(self, daemon: Daemon, conn: socket.socket, addr: tuple):
        super().__init__(daemon=True)
        self.d = daemon
        self.conn = conn
        self.addr = addr
        self.send_lock = threading.Lock()

    def start(self):
        with self.d.lock:
            self.d.ctrl_clients.append(self)
        super().start()

    def send(self, line: str) -> None:
        with self.send_lock:
            try:
                self.conn.sendall(line.encode("utf-8"))
            except OSError:
                pass

    def run(self) -> None:
        try:
            self.send("+ welcome mock_mud daemon\n")
            self.send(self.d.status_line())
            f = self.conn.makefile("r", encoding="utf-8", errors="replace")
            for raw in f:
                line = raw.rstrip("\r\n")
                if not line:
                    continue
                head, _, rest = line.partition(" ")
                head = head.lower()
                if head == "quit":
                    self.send("+ ok bye\n")
                    return
                if head == "status":
                    self.send(self.d.status_line())
                    continue
                if head == "wait_connected":
                    try:
                        secs = float(rest) if rest else 30.0
                    except ValueError:
                        self.send("! usage: wait_connected [seconds]\n")
                        continue
                    if self.d.wait_connected(secs):
                        self.send("+ ok connected\n")
                    else:
                        self.send("! timeout\n")
                    continue
                if head == "wait_ready":
                    try:
                        secs = float(rest) if rest else 30.0
                    except ValueError:
                        self.send("! usage: wait_ready [seconds]\n")
                        continue
                    if self.d.wait_ready(secs):
                        self.send("+ ok ready\n")
                    else:
                        self.send("! timeout\n")
                    continue
                if head == "exec":
                    if not rest:
                        self.send("! usage: exec <lua statement or expression>\n")
                        continue
                    rid = self.d.send_exec_async(rest)
                    if rid:
                        self.send(f"+ ok exec {rid}\n")
                    else:
                        self.send("! no_mudlet_connection\n")
                    continue
                if head == "eval":
                    if not rest:
                        self.send("! usage: eval <lua>\n")
                        continue
                    parts = rest.split(maxsplit=1)
                    try:
                        timeout_s = float(parts[0])
                        code = parts[1] if len(parts) > 1 else ""
                    except ValueError:
                        timeout_s = 10.0
                        code = rest
                    if not code:
                        self.send("! usage: eval [timeout_s] <lua>\n")
                        continue
                    data, err = self.d.eval_sync(code, timeout=timeout_s)
                    if err:
                        self.send(f"! eval {err}\n")
                    else:
                        # One-line JSON response so driver can json.loads it.
                        self.send("+ ok eval " + json.dumps(data) + "\n")
                    continue
                _, resp = self.d.execute(line)
                self.send(resp)
        finally:
            with self.d.lock:
                try:
                    self.d.ctrl_clients.remove(self)
                except ValueError:
                    pass
            try:
                self.conn.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass
            self.conn.close()


def run_repl(daemon: Daemon) -> None:
    """Read commands from stdin and execute them against the daemon."""
    print("REPL: type commands; `quit` exits the daemon. `help` for syntax.",
          flush=True)
    try:
        for raw in sys.stdin:
            line = raw.rstrip("\r\n")
            if not line:
                continue
            head = line.split(maxsplit=1)[0].lower() if line.strip() else ""
            if head == "quit":
                daemon.shutdown.set()
                return
            if head == "status":
                print(daemon.status_line().rstrip(), flush=True)
                continue
            if head == "wait_connected":
                rest = line.partition(" ")[2].strip()
                try:
                    secs = float(rest) if rest else 30.0
                except ValueError:
                    print("! usage: wait_connected [seconds]", flush=True)
                    continue
                print("+ connected" if daemon.wait_connected(secs) else "! timeout",
                      flush=True)
                continue
            _, resp = daemon.execute(line)
            sys.stdout.write(resp)
            sys.stdout.flush()
    except (KeyboardInterrupt, BrokenPipeError):
        return


# --- One-shot scenario mode (legacy) --------------------------------------
def run_scenario_oneshot(args) -> int:
    """Pre-daemon behavior: accept one Mudlet, run the scenario, exit."""
    if not args.scenario.exists():
        print(f"error: scenario file not found: {args.scenario}", file=sys.stderr)
        return 2
    srv = make_listener(args.host, args.port)
    print(f"waiting for Mudlet on {srv.getsockname()}...", flush=True)
    try:
        conn, addr = srv.accept()
    except KeyboardInterrupt:
        return 130
    print(f"client connected: {addr}", flush=True)
    drain = IncomingDrain(conn, args.verbose)
    drain.start()
    state = ClientState(conn=conn, addr=addr, drain=drain)
    greet(state)
    await_gmcp_agreement(state)
    print(f"replaying {args.scenario}", flush=True)
    try:
        with args.scenario.open() as f:
            for raw in f:
                line = raw.rstrip("\n")
                if line.strip():
                    print(f"-> {line}", flush=True)
                keep, _ = do_command(state, line)
                if not keep:
                    break
    finally:
        try:
            conn.shutdown(socket.SHUT_RDWR)
        except OSError:
            pass
        conn.close()
        srv.close()
        print(f"closed after {state.sent} commands.", flush=True)
    return 0


# --- Entrypoint -----------------------------------------------------------
def main() -> int:
    p = argparse.ArgumentParser(description="Mock GMCP MUD daemon for Mudlet GUI tests.")
    p.add_argument("--port", type=int, default=4099,
                   help="Mudlet-facing telnet port (default: 4099)")
    p.add_argument("--host", default="127.0.0.1",
                   help="bind address (default: 127.0.0.1)")
    p.add_argument("--ctrl-port", type=int, default=4100,
                   help="control channel port (default: 4100)")
    p.add_argument("--scenario", type=Path,
                   help="optional scenario file: in daemon mode, runs once "
                        "on first Mudlet connect; with --once, runs and exits")
    p.add_argument("--once", action="store_true",
                   help="legacy mode: accept one Mudlet, play scenario, exit")
    p.add_argument("--repl", action="store_true",
                   help="also read commands from stdin (in addition to ctrl channel)")
    p.add_argument("-v", "--verbose", action="store_true",
                   help="log client input bytes and forwarded events to stdout")
    args = p.parse_args()

    if args.once:
        if not args.scenario:
            print("error: --once requires --scenario", file=sys.stderr)
            return 2
        return run_scenario_oneshot(args)

    if args.scenario and not args.scenario.exists():
        print(f"error: scenario file not found: {args.scenario}", file=sys.stderr)
        return 2

    daemon = Daemon(
        telnet_host=args.host,
        telnet_port=args.port,
        ctrl_host=args.host,
        ctrl_port=args.ctrl_port,
        verbose=args.verbose,
        initial_scenario=args.scenario,
    )

    threading.Thread(target=daemon.telnet_loop, daemon=True).start()
    threading.Thread(target=daemon.ctrl_loop, daemon=True).start()

    try:
        if args.repl:
            run_repl(daemon)
        else:
            # Block forever in the main thread.
            daemon.shutdown.wait()
    except KeyboardInterrupt:
        pass
    finally:
        daemon.shutdown.set()
        print("shutting down", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
