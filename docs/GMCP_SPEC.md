# GMCP server-side spec

What `fierymud-rs` needs to emit so the Mudlet client's panels light up.

The client (`FierymudRs` package) is a passive consumer — it never
asks the server "send me Char.Vitals", it just reads `gmcp.Char.Vitals`
whenever Mudlet's GMCP receiver populates it. The server is
responsible for emitting the right frames at the right cadence; the
client wires a small set of named handlers to act on them.

Each section below lists:
- **Package name** — the GMCP package path (`Char.Vitals`, `Comm.Channel.Text`, …).
- **When to emit** — the cadence that keeps panels current.
- **Shape** — TypeScript-ish for clarity. All payloads are JSON.
- **Consumer** — the Lua file that reads the frame.
- **Status** — `Live` (working in the test scenarios), `Planned` (referenced
  in code but not yet wired server-side), or `Wanted` (would unblock a UI
  feature that's currently impossible).

The legacy server uses largely the same shapes; this doc is the
canonical client-side contract for the Rust port.

---

## Character identity & state

### `Char.Status`  — **Live**

Identity strip + tracker baseline.

| Field    | Type    | Notes                                       |
|----------|---------|---------------------------------------------|
| `name`   | string  | Character name                              |
| `class`  | string  | Full class name (`"Sorcerer"`)              |
| `level`  | number  | 1–100; 100+ flips to `GOD` in the UI        |
| `xp`     | number  | Lifetime XP — drives Tracker delta + rate   |
| `wealth` | number  | Lifetime gold — drives Tracker delta + rate |
| `race`   | string  | Optional (reserved; unused today)           |

**Cadence:** On login + on any change to the listed fields (level-up,
class change, wealth tick). At minimum, re-emit on every prompt so
the Tracker can compute XP/hr without integrating gaps.

**Consumer:** `src/scripts/FierymudRs/Vitals/Vitals.lua` (identity)
+ `Tracker/Tracker.lua` (XP/wealth delta).

### `Char.Vitals`  — **Live**

Main vitals gauges + level-progress for Tracker TTL.

| Field    | Type    | Notes                                              |
|----------|---------|----------------------------------------------------|
| `hp`     | number  | Current HP                                         |
| `maxhp`  | number  | Max HP                                             |
| `mv`     | number  | Current move/stamina                               |
| `maxmv`  | number  | Max move/stamina                                   |
| `nl`     | number  | % progress to next level (0..100, `nl=100` = pre-ding) |
| `string` | string  | Optional pre-formatted prompt body                 |
| `mp`     | number  | Optional mana (caster-only — schema reserves it)   |
| `maxmp`  | number  | Optional max mana                                  |

**Cadence:** Every prompt. Cheap; the client expects this frame on
every prompt cycle.

**Consumer:** `Vitals/Vitals.lua`, `Vitals/Guages.lua`, `Tracker/Tracker.lua`.

---

## Combat

### `Char.Combat`  — **Live**

Tank + opponent for the bottom-left TARGET panel.

```ts
{
  tank: {
    name: string,
    hp: number,
    max_hp: number,   // note: legacy snake_case, not maxhp
  },
  opponent: {
    name: string,
    hp_percent: number,   // 0..100, server reports % only
  },
}
```

**Cadence:** On combat enter, on every round / damage tick, on combat
exit (emit an empty `{}` to clear). The client hides the panel on
empty.

**Consumer:** `Vitals/Guages.lua` `updateCombat()`.

### `Char.Aggro`  — **Live**

Threats panel (top of the THREATS section).

```ts
{
  hating: string[],      // mobs actively attacking / chasing
  remembering: string[], // mobs that walked away but remember
}
```

**Cadence:** Only emit when at least one array is non-empty. The
server gates emission; the client's render is null-safe but the panel
is hidden when the frame is absent.

**Consumer:** `Vitals/Guages.lua` `updateAggro()`.

### `Char.Effects`  — **Live**

Active buffs/debuffs — top center icon bar.

```ts
Array<{
  name: string,        // human display name ("Sanctuary")
  ability: string,     // spell key for icon lookup ("sanctuary" → sanctuary.png)
  duration: number,    // seconds remaining; -1 = permanent
  source: string,      // who cast it ("Self", "Mejna", etc.)
  strength: number,    // 1..n stacking strength
}>
```

**Cadence:** On effect add/remove. Snapshot every effect each
emission — the client diffs by ability/name key. Permanent effects
(`duration: -1`) tick at -1 forever; the client just doesn't decrement
them.

**Consumer:** `Effects/Effects.lua`.

---

## Group / Party

### `Group`  — **Live**

Party panel mid-left.

```ts
{
  leader: string,    // name of the party leader
  count: number,     // member count; 0 or missing = solo
  members: Array<{
    name: string,
    with_leader: boolean,  // "here in the leader's room"
    level: number,
    class: string,         // abbreviation — first 3 chars used for tinting ("Sor", "War", "Pri")
    stats: {
      hp: number, maxhp: number,
      mv: number, maxmv: number,
    },
  }>
}
```

**Cadence:** Every prompt while grouped. Send an empty `{}` (or omit
the frame entirely) to indicate solo — the client hides the panel.

**Consumer:** `Vitals/Guages.lua` `updateGroup()`.

---

## Room

### `Room.Info`  — **Live**

Map widget + current-room tracking.

```ts
{
  num: number,             // composite room key: zone * 100000 + id
  name: string,            // room title
  area: string,            // zone display name
  environment: string,     // sector enum label ("Forest", "Inside", "City", "Mountains", ...)
  exits: { [direction: string]: number },  // dir → adjacent room num
  doors: { [direction: string]: string },  // dir → "closed" | "locked"; absent = no door
  coords?: string,         // optional "x,y,z" — preferred over compass-walk inference
}
```

**Cadence:** On room entry + look. Coordinates are optional but
strongly preferred — without them, the mapper falls back to dead
reckoning (offsets from the previous room by the player's last
movement direction), which gets corner cases wrong.

**Consumer:** `Mapper/Mapper.lua`.

### `Room.Players`  — **Live**

"Who else is in this room" strip (header bar inside the chat panel).

```ts
Array<{
  name: string,
  // potentially: class, level, with_leader — currently unused
}>
```

**Cadence:** On room entry + on player connect/disconnect in the
current room. Empty array shows `(no one else here)`.

**Consumer:** `Vitals/Guages.lua` `updateRoomPlayers()`.

### `Room.AddPlayer` / `Room.RemovePlayer`  — **Live**

Diff events for incremental updates so the server doesn't need to
re-emit the full snapshot on every step.

```ts
// AddPlayer
{ name: string }
// RemovePlayer
{ name: string }
```

The client's handler ignores the diff payload and just re-reads
`gmcp.Room.Players` (Mudlet's GMCP receiver mutates the table
in-place before firing the event). So the server can either:

- Emit a fresh `Room.Players` snapshot AND nothing else, or
- Mutate `Room.Players` in-place AND emit `Room.AddPlayer` /
  `Room.RemovePlayer` for the diff — either works.

---

## Chat / Communication

### `Comm.Channel.Text`  — **Live**

Every channel utterance (gossip, tell, group, shout, wiznet, …).

```ts
{
  channel: string,   // lowercase channel name: "gossip" | "tells" | "group" | "shout" | "wiznet" | ...
  talker: string,    // speaker's name (or "a herald" / "an angry guard" for NPCs)
  text: string,      // message body, **plain text** — server strips color codes
}
```

**Cadence:** On every channel send, including the player's own
messages (the client formats `talker == self.name` differently for
self-mention highlighting).

**Consumer:** `Chat/Chat.lua` `onCommChannelText()`. Channel names map to
chat tabs via `channelTabs` (gossip→Gossip, shout→Local, wiznet→Wiz, …).

### `Comm.Channel.List`  — **Live**

Optional channel directory — replaces the hardcoded client-side
list with a server-aware one. When the server sends this, the
client rebuilds its tab routing table.

```ts
Array<{
  name: string,       // canonical key (matches `channel` in Comm.Channel.Text)
  caption?: string,   // pretty name for the tab label; defaults to `name`
  command?: string,   // command the player runs to use this channel; for future tab-click-to-target
}>
```

**Cadence:** Once on login. Re-emit if the player gains/loses access
(e.g., immortal promotion, clan join, quest channel unlock).

**Consumer:** `Chat/Chat.lua` `onCommChannelList()`.

---

## Inventory

### `Char.Items.List`  — **Live**

Inventory + equipment panels.

```ts
{
  location: "inv" | "wear",   // selects which panel to update
  items: Array<{
    name: string,             // display name with article ("a glittering ruby ring")
    keyword?: string,         // optional — if absent, client uses the last word of `name`
    type: string,             // "weapon" | "armor" | "container" | "scroll" | "potion" | ...
    identified: boolean,      // shows a `*` marker before the name in the panel
    location?: string,        // worn slot ("finger", "neck", ...) — for `wear` only
  }>
}
```

The client requests this on init by sending `Char.Items.Inv` outbound.
Server should respond with `Char.Items.List` for both `inv` and
`wear` locations on login + after any inventory mutation (get / drop
/ wear / remove / give / quaff / etc.).

**Consumer:** `Inventory/Inventory.lua`.

---

## Wanted — server work needed to unlock UI features

### `Room.Mobs`  — **Wanted**

To build the "enemies with their targets" widget in the mid-left
column. The user's proposed layout puts hostile mobs as cards between
the group and target panels, each showing what they're currently
attacking.

```ts
Array<{
  name: string,           // mob display name ("a vicious goblin")
  hp_percent?: number,    // 0..100 — if absent, panel hides the bar
  targeting?: string,     // who they're hitting: "TestUser" / "Brendan" / mob name / null
  status?: string,        // optional "casting" / "fleeing" / "stunned" tag
}>
```

**Cadence:** On room entry, on combat round (so HP percentages
update), on mob spawn/death in current room. Empty array (or absent
frame) means no hostile mobs — widget hides.

This unblocks the mid-column slot reserved in Iter 4 of the UI loop.

### `Char.Combat.target`  — **Wanted (extension)**

Today's `Char.Combat` has `tank` + `opponent`. The user's mental model
is **tank → opponent → my current target** — opponent is the mob the
group is fighting, but "my current target" can be a different mob
(e.g., a Sorcerer focus-firing a caster while the tank holds the
main boss). Add a third field:

```ts
{
  tank:     { name, hp, max_hp },
  opponent: { name, hp_percent },
  target?:  { name, hp_percent },   // *my* current target if different from opponent
}
```

When `target` matches `opponent`, the client renders one combat row;
when they differ, it stacks "Opponent: X" above "Target: Y" with the
Target row in a brighter accent (this is the "current target
highlighted at the bottom" of the user's design).

### `Char.Skills`  — **Wanted**

Skill cooldowns / mana costs for a future skill bar widget.

```ts
{
  skills: Array<{
    name: string,
    mp_cost?: number,
    cooldown?: number,  // seconds remaining; 0 = available
    available: boolean,
  }>
}
```

**Cadence:** On every prompt (or every N prompts for cheap updates).

---

## Outbound (client → server)

The client sends very little:

- `Char.Items.Inv` — at startup, asks the server to send a fresh
  `Char.Items.List` for `inv` + `wear`. Server should treat this as
  a "snapshot please" request.

- `MRResult` — internal client→test-runner channel (see
  `docs/AGENT_DEV.md`). Server can ignore.

- `Test.Result` — same; safe to ignore server-side.

That's it. There's no `Core.Supports.Add` round-trip — the server can
emit any of the packages above unconditionally and the client will
consume what it knows.

---

## Implementation notes for the Rust side

- **Field naming:** GMCP convention is camelCase; FieryMUD historically
  used a mix (`maxhp` and `max_hp` both appear). The shapes here are
  the **client's** ground truth — match these exactly. Specifically
  `Char.Vitals` uses `maxhp` / `maxmv` (no underscores) while
  `Char.Combat.tank.max_hp` uses underscore. Both are intentional;
  changing either breaks the client.

- **Empty-frame semantics:** Many packages use "absent or empty" to
  mean "hide this UI section." Prefer sending an empty object `{}`
  for `Group` and `Char.Combat` over omitting the frame entirely —
  it makes the client's clear-on-transition logic cleaner.

- **Frame frequency:** Don't worry about over-emitting. The client
  uses cached state + diffs at the render layer; identical frames
  are no-ops.

- **JSON encoding:** Plain UTF-8 JSON in the GMCP body (everything
  after `Package.Name ` and before `IAC SE`). The client uses
  Mudlet's bundled `yajl` parser which is tolerant of whitespace and
  trailing commas but strict about quoting.

- **Testing the contract:** Each package above has a corresponding
  scenario in `scripts/scenarios/`:
  - `vitals_low_hp.txt` — Char.Status + Char.Vitals
  - `effects_full.txt` — Char.Effects
  - `group_and_aggro.txt` — Group + Char.Aggro
  - `combat_engaged.txt` — Char.Combat + Char.Aggro
  - `chat_channels.txt` — Comm.Channel.Text
  - `room_explored.txt` — Room.Info

  Run any scenario against the mock daemon and screenshot the result
  to validate the exact bytes the client expects.
