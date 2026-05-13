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

| Field             | Type    | Notes                                              |
|-------------------|---------|----------------------------------------------------|
| `hp`              | number  | Current HP                                         |
| `max_hp`          | number  | Max HP                                             |
| `mp`              | number  | Current mana (0 for non-casters)                   |
| `max_mp`          | number  | Max mana (0 for non-casters → client hides gauge)  |
| `mv`              | number  | Current move/stamina                               |
| `max_mv`          | number  | Max move/stamina                                   |
| `next_level_pct`  | number  | % progress to next level (0..100, 100 = pre-ding)  |
| `string`          | string  | Pre-formatted prompt body (`H:hp/max_hp M:mp/max_mp V:mv/max_mv`) |

**Cadence:** Every prompt. Cheap; the client expects this frame on
every prompt cycle.

**Consumer:** `Vitals/Vitals.lua`, `Vitals/Guages.lua`, `Tracker/Tracker.lua`.

---

## Combat

### `Char.Combat`  — **Live**

Tank + opponent + (optional) the viewer's current target for the
bottom-left TARGET panel.

```ts
{
  tank: {
    name: string,
    hp: number,
    max_hp: number,
  },
  opponent: {
    name: string,
    hp_percent: number,   // 0..100, server reports % only
  },
  target?: {
    name: string,
    hp_percent: number,
  },
}
```

`target` is the player's current swing (`Fighting`); `opponent` is
the group's main mob (today both are the same — they diverge when a
group-main concept lands). When `target` matches `opponent`, render
one combat row; when they differ, stack `Opponent: X` above
`Target: Y` with the Target row in a brighter accent.

**Cadence:** On every prompt. Empty `{}` when out of combat
(the client uses that as a hide signal).

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
  group_name: string,    // display name ("X's group")
  leader: string,        // name of the party leader
  count: number,         // member count; 0 or missing = solo
  members: Array<{
    name: string,
    with_leader: boolean,  // "here in the leader's room"
    level: number,
    race: string,
    class: string,         // first 3 chars used for tinting ("Sor", "War", "Pri")
    stats: {
      hp: number, max_hp: number,
      mp: number, max_mp: number,
      mv: number, max_mv: number,
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
  full_name: string,    // same as name today; reserved for color-bearing display form
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
    id: string,               // session-scoped runtime id; not stable across server restarts
    name: string,             // display name with article ("a glittering ruby ring")
    keyword?: string,         // optional — if absent, client uses the last word of `name`
    type: string,             // "weapon" | "armor" | "container" | "scroll" | "potion" | ...
    identified: boolean,      // shows a `*` marker before the name in the panel
    location?: string,        // worn slot ("head", "neck", "finger (left)", ...) — emitted only when the outer `location` is `"wear"`
  }>
}
```

The client requests this on init by sending `Char.Items.Inv` outbound.
Server should respond with `Char.Items.List` for both `inv` and
`wear` locations on login + after any inventory mutation (get / drop
/ wear / remove / give / quaff / etc.).

**Consumer:** `Inventory/Inventory.lua`.

---

### `Room.Mobs`  — **Live**

Every mob in the current room, with a `hostile` flag and service
`professions`. Drives both the threat panel (filter `hostile:true`)
and the friendly-NPC panel (filter `hostile:false`).

```ts
Array<{
  id: string,             // session-scoped runtime id; pass back to Room.Mob.Get for detail. Not stable across server restarts.
  name: string,           // display name ("a vicious goblin")
  hostile: boolean,       // currently engaged, hates/remembers viewer, OR alignment ≤ aggro threshold
  hp_percent: number,     // 0..100; emit for all mobs (client can hide bar on friendlies)
  targeting: string | null, // who the mob is swinging at; null when not engaged
  status?: string,        // "stunned" (more later: casting / fleeing)
  professions: string[],  // ["shop","bank","inn","mail","guild","trainer"] — empty array on plain mobs
}>
```

`professions` strings match the keys in `Room.Services.services` and
are the routing keys for service-related UI affordances (a shop
icon, a bank button, etc.).

**Cadence:** Every prompt. Empty array clears the panels.

**Consumer:** Threat panel + friendly-NPC panel (to be wired).

### `Room.Services`  — **Live**

Derived room-level service summary. Union of every present mob's
`professions`, deduped, insertion-stable. Lets the client paint a
service chip on the room header without walking `Room.Mobs`.

```ts
{
  services: string[],   // ["shop","bank","inn","mail","guild","trainer"]
}
```

Service tag mapping (server-side, from `MobProfession`):
- `Shopkeeper`   → `"shop"`
- `Banker`       → `"bank"`
- `Receptionist` → `"inn"`
- `Postmaster`   → `"mail"`
- `Guildmaster`  → `"guild"`
- `Trainer`      → `"trainer"`

**Cadence:** Every prompt. Empty array means no services here.

**Consumer:** Room-header chips (to be wired).

### `Room.Mob.Get` / `Room.Mob.Info`  — **Live**

Click-to-detail request/response. Client sends `Room.Mob.Get` with
an id from `Room.Mobs[i].id`; server replies with `Room.Mob.Info`.
Server-side validates the mob is in the requesting player's room
(silent no-op on mismatch — request fishing fails silent).

**Outbound** (client → server):
```ts
{ id: string }
```

**Inbound** (server → client) — `Room.Mob.Info`:
```ts
{
  id: string,              // echoes the requested mob id (session-scoped, like Room.Mobs[i].id)
  name: string,
  description: string,
  professions: string[],
  shop?: {
    items: Array<{
      id: string,          // "<zone>:<id>" of the object proto — stable across restarts (content key)
      name: string,
      price: number,       // copper; 0 means "use proto base × buy_profit"
      stock: number,       // -1 = unlimited
    }>,
    accepts: string[],     // ObjectType strings the shop will buy from the player
  },
}
```

Two ID schemes coexist intentionally: top-level `id` is the live mob
entity (session-scoped, unstable across restarts); `shop.items[i].id`
is the content-key `"<zone>:<id>"` (stable, useful for client-side
caching of item details).

`shop` is present only when the mob is registered in `ShopCatalog`
(keeper of a defined shop). Future blocks (`trainer`, `bank`, …)
follow the same optional-key pattern.

**Cadence:** On demand — one `Room.Mob.Info` per `Room.Mob.Get`.

**Consumer:** Mob detail popover (to be wired).

### `Char.Skills`  — **Live**

Per-skill cooldown + available flag for the (future) skill-bar
widget. One entry per known ability.

```ts
{
  skills: Array<{
    name: string,
    cooldown: number,   // seconds remaining; 0 = available
    available: boolean, // mirror of cooldown == 0; precomputed for cheap filtering
    mp_cost?: number,   // reserved — not emitted today (cost is circle-derived)
  }>
}
```

**Cadence:** Every prompt.

**Consumer:** Skill bar (to be wired).

Distinct from `Char.Skills.List` (flat array of names emitted in
response to client `Char.Skills.Get`) — that's the legacy IRE
directory; `Char.Skills` is the per-prompt liveness feed.

---

## Wanted — server work needed to unlock UI features

*(Nothing currently. Wanted entries graduated to Live land here when
new client-side UX requests turn up.)*

---

## Outbound (client → server)

- `Char.Items.Inv` — at startup, asks the server to send a fresh
  `Char.Items.List` for `inv` + `wear`. Server should treat this as
  a "snapshot please" request.

- `Char.Skills.Get` — asks for the flat `Char.Skills.List` directory
  (separate from the per-prompt `Char.Skills` liveness feed).

- `Room.Mob.Get` — `{ id: string }` from a `Room.Mobs[i].id`. Server
  replies with `Room.Mob.Info` if the mob is in the requesting
  player's room; silent no-op otherwise.

- `MRResult` — internal client→test-runner channel (see
  `docs/AGENT_DEV.md`). Server can ignore.

- `Test.Result` — same; safe to ignore server-side.

There's no `Core.Supports.Add` round-trip — the server can emit any
of the packages above unconditionally and the client will consume
what it knows.

---

## Implementation notes for the Rust side

- **Field naming:** All payload keys are snake_case across the
  contract (`max_hp`, `hp_percent`, `next_level_pct`, `full_name`,
  `group_name`, `application_id`, `small_image`, `start_time`).
  We diverge from IRE/Mudlet's stock camelCase — the client is
  fully custom, so consistency beats community precedent.
  Server keys and client keys must match exactly; the client does
  no normalization.

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
