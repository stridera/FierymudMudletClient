# Coding Guide

This guide covers development setup, project structure, and conventions for contributing to FierymudMudletClient.

## Prerequisites

- [Docker](https://www.docker.com/) (recommended) or Java 11+ for Muddler
- [Mudlet](https://www.mudlet.org/) for testing
- A code editor (VS Code recommended - workspace settings included)

## Building the Package

This project uses [Muddler](https://github.com/demonnic/muddler) to compile the `src/` directory into a Mudlet `.mpackage` file.

### Using Docker (Recommended)

```bash
# Pull the Muddler container (first time only)
docker pull demonnic/muddler:latest

# Build the package
docker run --rm -it -u $(id -u):$(id -g) -v $PWD:/$PWD -w /$PWD demonnic/muddler
```

The built package will be at `build/tmp/FierymudOfficial.mpackage`.

### Optional: Create a Build Script

Save this as `build.sh` for convenience:

```bash
#!/bin/bash
docker run --rm -it -u $(id -u):$(id -g) -v $PWD:/$PWD -w /$PWD demonnic/muddler
```

Then run with `./build.sh`.

## Project Structure

```
FierymudMudletClient/
├── mfile                    # Muddler config (package name, version)
├── src/
│   ├── aliases/             # User input aliases
│   │   └── Commands/
│   │       ├── aliases.json # Alias definitions
│   │       └── fm.lua       # `fm` command handler
│   ├── scripts/             # Lua modules (loaded on startup)
│   │   └── Fiery/
│   │       ├── GUI.lua      # Main entry point, event handlers
│   │       ├── Config/      # Configuration system
│   │       ├── Chat/        # EMCO tabbed chat
│   │       ├── Vitals/      # HP/Move/XP gauges
│   │       ├── Effects/     # Spell effect tracking
│   │       ├── Commands/    # Command implementations
│   │       ├── Mapper/      # Map integration
│   │       └── Utils/       # Utility functions
│   ├── triggers/            # Pattern-matched triggers
│   │   └── Fiery/
│   │       ├── Prompt.lua   # Prompt detection
│   │       └── Chat/        # Chat channel triggers
│   └── resources/           # Static assets (images, etc.)
└── build/                   # Generated output (gitignored)
```

### Muddler JSON Files

Each directory can have a JSON file defining its contents:

- `scripts.json` - Script load order
- `triggers.json` - Trigger definitions with patterns
- `aliases.json` - Alias definitions with patterns

## Architecture Overview

### Global Namespace

All code uses the `Fierymud` global table to avoid polluting the global namespace:

```lua
Fierymud = Fierymud or {}
Fierymud.ModuleName = Fierymud.ModuleName or {}
```

### Event Flow

1. **Startup**: `sysLoadEvent`/`sysInstall` → `Fierymud.eventHandler()` → `setup()`
2. **Prompt**: MUD sends prompt → trigger fires `onPrompt` → `Fierymud.Character:update()`
3. **GMCP Updates**: Mudlet receives GMCP → handlers update `Fierymud.Character`, `Fierymud.Effects`
4. **Chat**: Trigger matches chat line → `Fierymud.Chat:fromTrigger(channel)` → routes to EMCO tab

### Key Components

| Component | File | Purpose |
|-----------|------|---------|
| Entry Point | `GUI.lua` | Initializes containers, registers events |
| Config | `Config/Config.lua` | Persistent settings via `table.save/load` |
| Chat | `Chat/EMCO.lua` | Tabbed console widget (third-party) |
| Chat Setup | `Chat/GUI.lua` | Configures EMCO tabs and callbacks |
| Vitals | `Vitals/Vitals.lua` | Character state from GMCP |
| Gauges | `Vitals/Guages.lua` | Geyser.Gauge UI widgets |
| Effects | `Effects/Effects.lua` | Spell tracking with timers |

### GMCP Data

The package relies on FieryMUD's GMCP implementation:

- `gmcp.Char.name`, `gmcp.Char.class`, `gmcp.Char.level`
- `gmcp.Char.Vitals` - `hp`, `max_hp`, `mv`, `max_mv`
- `gmcp.Char.Combat` - `tank`, `opponent` with health info
- `gmcp.Char.Effects` - Active spells with duration

## Development Workflow

### Auto-Reload on Build

Mudlet can automatically reload packages when they change. See the [Muddler CI documentation](https://github.com/demonnic/muddler/wiki/CI) for setup instructions.

### Testing Changes

1. Build the package: `./build.sh` (or docker command)
2. In Mudlet, uninstall the old package if installed
3. Install the new `.mpackage` from `build/tmp/`
4. Connect to FieryMUD and test

Or use auto-reload for faster iteration.

### VS Code Setup

The project includes `.vscode/settings.json` with Lua diagnostics configured for Mudlet globals. Install the [Lua Language Server](https://marketplace.visualstudio.com/items?itemName=sumneko.lua) extension for best results.

## Adding New Features

### Adding a New Script Module

1. Create `src/scripts/Fiery/YourModule/YourModule.lua`
2. Create `src/scripts/Fiery/YourModule/scripts.json`:
   ```json
   [{ "name": "YourModule" }]
   ```
3. Use the namespace pattern:
   ```lua
   Fierymud = Fierymud or {}
   Fierymud.YourModule = Fierymud.YourModule or {}

   function Fierymud.YourModule:setup()
       -- initialization
   end
   ```
4. Call setup from `GUI.lua` if needed

### Adding a New Trigger

1. Add the trigger definition to the appropriate `triggers.json`
2. Create the Lua handler file
3. Trigger patterns use Mudlet's pattern syntax (regex, substring, etc.)

### Adding a New Config Option

1. Add the default value to `Fierymud.Defaults` in `Config.lua`
2. Add the option to the appropriate category in `do_config()` display
3. Add to the correct type list (`toggles`, `integers`, or `strings`)

## Code Style

- Use `local` for module-private functions
- Prefix private functions with module table for public API
- Use `debugc()` for debug output (only shows when debug enabled)
- Keep UI styling in stylesheet strings for maintainability
- Use Geyser widgets for all UI components

## Resources

- [Mudlet Manual](https://wiki.mudlet.org/w/Manual:Contents)
- [Geyser UI Framework](https://wiki.mudlet.org/w/Manual:Geyser)
- [EMCO Documentation](https://github.com/demonnic/EMCO/wiki)
- [Muddler Documentation](https://github.com/demonnic/muddler/wiki)
- [GMCP Specification](https://tintin.mudhalla.net/protocols/gmcp/)
