# FierymudMudletClient — `rust-port` branch

[Mudlet](https://www.mudlet.org/) client package for **fierymud-rs**, the
Rust ECS rewrite of FieryMUD. This branch is a parallel of `main` (which
targets the legacy C++ server). The package identifier on this branch is
`FierymudRs` so a single Mudlet install can hold both packages without
collision.

> **Mainline package**: install the `main`-branch build for legacy
> `fierymud.org:4000` (C++ server). It uses the package name
> `FierymudOfficial` and the global namespace `Fierymud`.
>
> **This branch**: install the `rust-port` build for the Rust port. It
> uses package name `FierymudRs` and global namespace `FierymudRs`. The
> package gates on MSSP `NAME = "fierymud-rs"` and silently idles on
> any other server.

## Features

- **Server-identity gate** — package only initializes when the
  connected server advertises MSSP `NAME = "fierymud-rs"`. Won't load
  on the legacy C++ FieryMUD or any other MUD; explicit override via
  `FierymudRs.Config.force_rust_mode = true` for development.
- **Vitals gauges** — HP / Stamina / XP bars driven by GMCP
  `Char.Vitals` and `Char.Status`. Stamina replaces the legacy
  "movement" axis; gauge code is unchanged.
- **Active effects panel** — buffs / debuffs from GMCP `Char.Effects`.
  Permanent effects render `∞`; effects under a minute show seconds.
  Color escalates to orange under 60s and red under 30s.
- **Tabbed chat** — All / Tells / Gossip / Group / Local channels via
  EMCO. (Channel triggers will be re-tuned for the Rust server's
  output once GMCP `Comm.Channel.Text` is wired server-side.)
- **Combat panel** — tank + opponent HP bars driven by `Char.Combat`.
- **Aggro radar** — list of mobs that hate you anywhere in the world,
  driven by the Rust port's `Char.Aggro` GMCP feed.
- **Mapper (currently dormant)** — re-enable once the server emits
  the legacy structured `Room.Exits` shape or a Lua adapter
  synthesizes it from the flat `Room.Info` feed.
- **OS notifications** — desktop alerts for chat messages when Mudlet
  is not focused.

## Installation

### From source

```bash
git clone https://github.com/stridera/FierymudMudletClient.git
cd FierymudMudletClient
git checkout rust-port
docker run --rm -it -u "$(id -u):$(id -g)" -v "$PWD:/$PWD" -w "/$PWD" demonnic/muddler
```

The `.mpackage` lands in `build/tmp/FierymudRs.mpackage`. Install it via
Mudlet's **Package Manager → Install**.

## Connecting

Point Mudlet at the Rust port — `minastirith.utaboshi.com:4003` (telnet)
or `:4443` (TLS). The package will auto-initialize once MSSP confirms
the server identity.

## Commands

| Command | Description |
|---------|-------------|
| `fm help` | Show all available commands |
| `fm status` | Show current status (character, effects, allies) |
| `fm config` | Display current configuration |
| `fm config <key>` | Show value of a specific setting |
| `fm config <key> <value>` | Change a setting |
| `fm reload` | Reload scripts from disk |
| `fm reset` | Destroy and rebuild GUI (use when UI is broken) |
| `fm version` | Show version and credits |

## Configuration Options

Run `fm config` to see all options. Key settings:

| Setting | Default | Description |
|---------|---------|-------------|
| `enabled` | true | Enable/disable the entire GUI |
| `force_rust_mode` | false | Bypass the MSSP identity gate (dev / testing) |
| `disable_vitals` | false | Hide the vitals panel |
| `disable_chat` | false | Hide the chat panel |
| `disable_map` | true | Hide the map panel (default: dormant — see Mapper note above) |
| `disable_spell_effects` | false | Hide the spell effects bar |
| `os_alerts` | true | Enable desktop notifications for chat |
| `spell_effect_location` | top | Position of effects bar (top/bottom) |
| `spell_effect_type` | icon | Display type for effects (icon/text) |
| `vitals_life` | 60 | Seconds before other character vitals fade |

## GMCP shape consumed

The Rust port emits these GMCP packages on every prompt cadence; the
package consumes them as listed:

| Package | Shape | Consumer |
|--|--|--|
| `Char.Vitals` | `{hp, max_hp, sp, max_sp, level}` | Vitals.lua → HP / Stamina gauges |
| `Char.Status` | `{name, level, xp, class, race, wealth}` | Vitals.lua → identity strip |
| `Char.Effects` | `[{name, duration, source, strength}]` | Effects.lua → effect tiles |
| `Char.Aggro` | `{hating: [...], remembering: [...]}` | (planned) aggro radar widget |
| `Char.Combat` | `{tank, opponent}` | Guages.lua → combat bars |
| `Room.Info` | `{name, zone, id, exits: [...]}` | (planned) mapper rewrite |

Note: `duration` on `Char.Effects` is now seconds (was minutes on the
legacy server). The package handles the new shape directly.

## Requirements

- [Mudlet](https://www.mudlet.org/) 4.10+
- fierymud-rs server (any version with GMCP support — currently every
  build)

## Contributing

Pull requests welcome! See [CODING.md](CODING.md) for development setup.
This branch (`rust-port`) tracks the Rust server; mainline (`main`)
tracks the C++ server. Cross-cutting fixes typically land on both.

Report bugs and request features:
[GitHub Issues](https://github.com/stridera/FierymudMudletClient/issues)

## Credits

Written by **Strider**, with the rust-port adaptation made by Claude.
