# FierymudMudletClient

Official [Mudlet](https://www.mudlet.org/) client package for [FieryMUD](http://fierymud.org) (`fierymud.org:4000`).

## Features

- **Vitals Display** - HP, Movement, and XP gauges for your character with gradient-styled bars
- **Multi-Character Support** - Track vitals from other profiles/characters in your group
- **Combat Tracking** - Tank and opponent health bars during combat via GMCP
- **Tabbed Chat** - Organized chat tabs (All, Tells, Gossip, Group, Local) with timestamps and tab blinking
- **Spell Effects** - Visual display of active spell effects with countdown timers and optional icons
- **Integrated Map** - Mudlet mapper embedded in the GUI
- **OS Notifications** - Desktop alerts for chat messages when Mudlet is not focused
- **Configurable Layout** - Adjustable containers for vitals, chat, and effects panels

## Installation

### From Release

1. Download the latest `.mpackage` file from [Releases](https://github.com/stridera/FierymudMudletClient/releases)
2. In Mudlet, go to **Package Manager** → **Install**
3. Select the downloaded `.mpackage` file
4. Connect to FieryMUD (`fierymud.org:4000`)

### From Source

See [CODING.md](CODING.md) for build instructions.

## Commands

| Command | Description |
|---------|-------------|
| `fm help` | Show all available commands |
| `fm config` | Display current configuration |
| `fm config <key>` | Show value of a specific setting |
| `fm config <key> <value>` | Change a setting |
| `fm reload` | Reload the GUI and scripts |
| `fm version` | Show version and credits |

## Configuration Options

Run `fm config` to see all options. Key settings:

| Setting | Default | Description |
|---------|---------|-------------|
| `enabled` | true | Enable/disable the entire GUI |
| `disable_vitals` | false | Hide the vitals panel |
| `disable_chat` | false | Hide the chat panel |
| `disable_map` | false | Hide the map panel |
| `disable_spell_effects` | false | Hide the spell effects bar |
| `os_alerts` | true | Enable desktop notifications for chat |
| `spell_effect_location` | top | Position of effects bar (top/bottom) |
| `spell_effect_type` | icon | Display type for effects (icon/text) |
| `vitals_life` | 60 | Seconds before other character vitals fade |

## Requirements

- [Mudlet](https://www.mudlet.org/) 4.10+
- FieryMUD server with GMCP support

## Contributing

Pull requests welcome! Please see [CODING.md](CODING.md) for development setup.

Report bugs and request features: [GitHub Issues](https://github.com/stridera/FierymudMudletClient/issues)

## Credits

Written by **Strider**

## License

This project is open source. See the repository for license details.
