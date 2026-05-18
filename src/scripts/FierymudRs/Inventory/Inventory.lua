-- Interactive inventory + equipment panels.
--
-- Driven by `gmcp.Char.Items.List` frames the server emits on
-- every inventory mutation (get/drop/wear/remove/give) and at
-- login. Each frame's `location` selects which panel is updated:
--   "inv"  → the floating Inventory window  (`fm inv`)
--   "wear" → the floating Equipment window  (`fm eq`)
--
-- Each item line is rendered via `cechoPopup`, which makes the
-- whole line clickable with a per-item context menu. Available
-- actions are picked from the item's `type` field (also pushed
-- in the GMCP frame) so weapons get a "Wield" option, food gets
-- "Eat", drink containers get "Drink", and so on. `Look` is
-- always present and is the default left-click action when
-- there's only one menu entry.
--
-- Identified items are flagged with a `*` marker before the
-- name. The server's `cmd_examine` already shows the full stat
-- block when the item carries the `Identified` component, so
-- clicking "Look" on an identified item naturally surfaces the
-- richer view in the main window.

FierymudRs = FierymudRs or {}
FierymudRs.Inventory = FierymudRs.Inventory or {}

-- Per-item-type click menu config. Each entry is an array of
-- `{verb, label}` pairs. The first entry is the primary action
-- (left-click default); subsequent ones land in the context
-- menu. "Look" is appended to every list as a no-side-effect
-- fallback. Item type strings come straight from the server's
-- `r#type.label()` enum (see the Rust ObjectType enum) so the
-- spelling has to match.
local TYPE_ACTIONS = {
  Weapon         = { { "wield",  "Wield"  }, { "remove", "Remove" } },
  Armor          = { { "wear",   "Wear"   }, { "remove", "Remove" } },
  Treasure       = { },
  Worn           = { { "wear",   "Wear"   }, { "remove", "Remove" } },
  Light          = { { "hold",   "Hold"   }, { "remove", "Remove" } },
  Container      = { { "open",   "Open"   } },
  Drinkcontainer = { { "drink",  "Drink"  }, { "taste",  "Taste" }, { "pour",  "Pour" } },
  Food           = { { "eat",    "Eat"    } },
  Pill           = { { "swallow","Swallow"} },
  Potion         = { { "quaff",  "Quaff"  } },
  Scroll         = { { "recite", "Recite" } },
  Wand           = { { "use",    "Use"    } },
  Staff          = { { "use",    "Use"    } },
  Spellbook      = { { "study",  "Study"  } },
  Note           = { { "read",   "Read"   } },
  Key            = { },
  Boat           = { },
  Fountain       = { { "drink",  "Drink"  } },
  Money          = { },
  Trash          = { { "junk",   "Junk"   } },
}

-- Visual style per item type. `icon` is a 2-char prefix that
-- gives the eye a fast type cue without depending on font glyph
-- support; `color` colors the item name. Unknown types fall
-- back to a neutral white.
-- `<b:color>` is the wrong shape for Mudlet cecho — it parses as
-- background `color` with a stub foreground, so the text renders
-- invisible on a colored block. Hex literals give us the bright
-- variants the original code was reaching for.
local TYPE_STYLE = {
  Weapon         = { icon = "wp", color = "<red>"      },
  Armor          = { icon = "ar", color = "<c_128_255_255>"  },
  Worn           = { icon = "wn", color = "<cyan>"     },
  Light          = { icon = "li", color = "<c_255_215_0>"  },
  Container      = { icon = "co", color = "<dim_grey>" },
  Drinkcontainer = { icon = "dr", color = "<magenta>"  },
  Food           = { icon = "fo", color = "<green>"    },
  Pill           = { icon = "pi", color = "<c_80_255_80>"  },
  Potion         = { icon = "po", color = "<c_255_128_255>"  },
  Scroll         = { icon = "sc", color = "<yellow>"   },
  Wand           = { icon = "wa", color = "<c_255_128_255>"  },
  Staff          = { icon = "st", color = "<c_255_128_255>"  },
  Spellbook      = { icon = "sb", color = "<c_255_215_0>"  },
  Note           = { icon = "nt", color = "<yellow>"   },
  Key            = { icon = "ky", color = "<c_255_215_0>"  },
  Boat           = { icon = "bt", color = "<cyan>"     },
  Fountain       = { icon = "fn", color = "<c_128_255_255>"  },
  Money          = { icon = "$$", color = "<c_255_215_0>"  },
  Treasure       = { icon = "gm", color = "<c_128_255_255>"  },
  Trash          = { icon = "tr", color = "<dim_grey>" },
}

-- Render order for grouped sections. Roughly "things you'd
-- equip first" → "things you'd consume" → "rest". Types
-- omitted from this list (or unknown ones) bucket into "Other"
-- at the bottom.
local TYPE_GROUP_ORDER = {
  "Weapon", "Armor", "Worn", "Light",
  "Container", "Drinkcontainer", "Food", "Pill", "Potion",
  "Scroll", "Wand", "Staff", "Spellbook", "Note",
  "Key", "Boat", "Fountain",
  "Money", "Treasure", "Trash",
}

-- Per-location panel config. Each panel is an Adjustable
-- container the user can drag/resize; the inner MiniConsole is
-- where item lines land.
local PANEL_CONFIG = {
  inv = {
    name = "InventoryPanel",
    title = "Inventory",
    x = "-22%", y = "30%", width = "20%", height = "40%",
  },
  wear = {
    name = "EquipmentPanel",
    title = "Equipment",
    x = "-44%", y = "30%", width = "20%", height = "40%",
  },
}

-- Cached state per location. Filled in on setup; mutated by
-- onItemsList → render.
FierymudRs.Inventory.panels = FierymudRs.Inventory.panels or {}

-- Extract the first keyword from a name so click commands can
-- target the item without the player typing the whole adjective
-- chain. "a glittering ruby ring" → "ring" via the rightmost
-- word — server-side keyword matching is generous enough that
-- this works for the vast majority of items. Strips color tags
-- and articles ("a", "an", "the") first.
local function pickKeyword(name)
  if not name or name == "" then return "" end
  -- Strip XML-Lite color tags so they don't end up in the
  -- command. Server-side names usually arrive plain (the GMCP
  -- frame strips colors), but defend in case that changes.
  local plain = name:gsub("<[^>]+>", "")
  -- Trailing punctuation (e.g., commas in "a sword, of doom")
  -- — strip just to be safe.
  plain = plain:gsub("[,.!?]+$", "")
  -- Last whitespace-separated token. Drops articles and
  -- adjectives reliably enough for typical fantasy item names.
  local last = plain:match("(%S+)%s*$")
  return last or plain
end

local function buildPanel(location)
  local cfg = PANEL_CONFIG[location]
  if not cfg then return end
  local container = Adjustable.Container:new({
    name = cfg.name,
    x = cfg.x, y = cfg.y,
    width = cfg.width, height = cfg.height,
    titleText = cfg.title,
    titleTxtColor = "white",
    -- Match the interior to the MiniConsole's black so any
    -- residual edge between the adjustable's drag-frame and the
    -- console reads as a frame, not a background-bleed gap.
    adjLabelstyle = "background-color: black; border: 2px groove grey;",
  })
  -- Fully fill the Adjustable.Container's content rectangle.
  -- Earlier versions used `x=5, y=25, width="-5px"` which left
  -- a visible strip of the parent label (with the screen
  -- background showing through) around the black console. The
  -- adjustable handles its title region internally; child
  -- coordinates are relative to the available content area.
  local console = Geyser.MiniConsole:new({
    name = cfg.name .. "Console",
    x = 0, y = 0, width = "100%", height = "100%",
    color = "black",
    fontSize = 9,
    autoWrap = true,
  }, container)
  container:hide()
  return { container = container, console = console, items = {} }
end

function FierymudRs.Inventory:setup()
  for location, _ in pairs(PANEL_CONFIG) do
    if not self.panels[location] then
      self.panels[location] = buildPanel(location)
    end
  end
  -- Subsystem setup runs ~1s after login (sysConnectionEvent +
  -- tempTimer debounce). The server-side login flow already
  -- pushes Char.Items.List for inv + wear immediately after
  -- spawn — those frames typically arrive *before* setup runs,
  -- so the panels miss them on first open. Ask the server for
  -- a fresh push to backfill. The handler in login.rs treats
  -- Char.Items.Inv / Char.Items.Worn as a refresh trigger and
  -- re-emits both lists.
  sendGMCP("Char.Items.Inv")
end

-- Render the full panel for one location. Called whenever a
-- Char.Items.List frame for that location arrives. Items are
-- grouped by type so the eye can scan to "weapons" or
-- "potions" without re-reading every line. Each line carries
-- a 2-char type icon, a color key, the item name, and an
-- identified marker. Click on the line opens a contextual
-- menu via cechoPopup.
function FierymudRs.Inventory:render(location)
  local panel = self.panels[location]
  if not panel or not panel.console then return end
  local console = panel.console
  -- `:setBuffer({})` doesn't exist on Geyser.MiniConsole — it
  -- raises "attempt to call method 'setBuffer' (a nil value)"
  -- and aborts the render. `:clear()` alone is the correct
  -- buffer-reset call.
  console:clear()

  local total = #panel.items
  local title = (PANEL_CONFIG[location] and PANEL_CONFIG[location].title) or location

  -- Header summary: total count + identified count + a thin
  -- divider line. Reads as a small "stats line" before the
  -- bulk of the panel.
  local id_count = 0
  for _, it in ipairs(panel.items) do
    if it.identified then id_count = id_count + 1 end
  end
  console:cecho(string.format(
    "<c_128_255_255>%s<reset>  <dim_grey>(%d total",
    title, total
  ))
  if id_count > 0 then
    console:cecho(string.format(
      ", <green>%d identified<dim_grey>", id_count
    ))
  end
  console:cecho(")<reset>\n")
  console:cecho("<dim_grey>" .. string.rep("─", 30) .. "<reset>\n")

  if total == 0 then
    console:cecho("  <dim_grey>(empty)<reset>")
    return
  end

  -- Bucket by item type so the rendered panel has Weapons,
  -- Armor, Potions, etc. as visual sections. Unknown types
  -- bucket into "Other" so a future server-side enum addition
  -- doesn't silently drop items off the panel.
  local groups = {}
  for _, it in ipairs(panel.items) do
    local key = it.type or "Other"
    if not TYPE_STYLE[key] then key = "Other" end
    groups[key] = groups[key] or {}
    table.insert(groups[key], it)
  end

  -- Stable alphabetical sort within each group.
  for _, list in pairs(groups) do
    table.sort(list, function(a, b)
      return tostring(a.name or ""):lower() < tostring(b.name or ""):lower()
    end)
  end

  -- Resolve room context once per render. `gmcp.Room.Services
  -- .services` is the union of in-room mob professions
  -- (server-emitted, per-prompt). Earlier this was rebuilt
  -- once per type group — wasteful when groups iterate dozens
  -- of items.
  local room_services = {}
  local services_frame = gmcp and gmcp.Room and gmcp.Room.Services
  if type(services_frame) == "table" and type(services_frame.services) == "table" then
    for _, s in ipairs(services_frame.services) do
      room_services[s] = true
    end
  end
  local has_shop = room_services.shop or false
  local has_bank = room_services.bank or false

  -- Walk the configured order; trailing "Other" catches anything
  -- not covered by TYPE_GROUP_ORDER.
  local seen_types = {}
  local function renderGroup(type_key, list)
    if not list or #list == 0 then return end
    local style = TYPE_STYLE[type_key] or { icon = "??", color = "<white>" }
    -- Section heading with type label and count.
    console:cecho(string.format(
      "\n%s%s<reset> <dim_grey>(%d)<reset>\n",
      style.color, type_key, #list
    ))
    for _, item in ipairs(list) do
      local marker = item.identified and "<green>*<reset>" or " "
      local name = item.name or "(unknown)"
      local keyword = pickKeyword(name)
      local actions = TYPE_ACTIONS[item.type] or {}
      local commands, hints = {}, {}
      for _, pair in ipairs(actions) do
        commands[#commands + 1] = pair[1] .. " " .. keyword
        hints[#hints + 1] = pair[2]
      end
      commands[#commands + 1] = "look " .. keyword
      hints[#hints + 1] = "Look"
      -- Room-aware extras. Sell when a shop is in the room;
      -- Deposit when a bank is in the room (money items only).
      if has_shop and item.type ~= "Money" then
        commands[#commands + 1] = "sell " .. keyword
        hints[#hints + 1] = "Sell"
      end
      if has_bank and item.type == "Money" then
        commands[#commands + 1] = "deposit " .. keyword
        hints[#hints + 1] = "Deposit"
      end
      commands[#commands + 1] = "drop " .. keyword
      hints[#hints + 1] = "Drop"
      -- Two-space indent + 2-char icon + space + colored name.
      -- The trailing newline is part of the popup line so the
      -- entire row (icon through end-of-line) is the click
      -- target.
      local line = string.format(
        "  <dim_grey>%s<reset> %s %s%s<reset>\n",
        style.icon, marker, style.color, name
      )
      -- cechoPopup evaluates each command string as **Lua**, not
      -- as a MUD command — a bare "drop longsword" hits the
      -- parser as `drop longsword` and dies with "'=' expected
      -- near 'longsword'". Wrap each one in send(%q ...) so the
      -- popup actually sends it; %q is quote-safe for any odd
      -- characters that pickKeyword might surface.
      local lua_commands = {}
      for i, cmd in ipairs(commands) do
        lua_commands[i] = string.format("send(%q)", cmd)
      end
      -- `useCurrentFormat=false` so cecho color tags in `line`
      -- (the type icon, identified marker, name color) actually
      -- render with those colors. The `true` variant uses the
      -- console's current format and renders the tags as raw
      -- text, which is what the original code did.
      console:cechoPopup(line, lua_commands, hints, false)
    end
  end
  for _, type_key in ipairs(TYPE_GROUP_ORDER) do
    if groups[type_key] then
      renderGroup(type_key, groups[type_key])
      seen_types[type_key] = true
    end
  end
  -- Catch-all "Other" bucket: any keys present in `groups` that
  -- the configured order didn't render.
  for type_key, list in pairs(groups) do
    if not seen_types[type_key] then
      renderGroup(type_key, list)
    end
  end
end

-- Public: handle a `gmcp.Char.Items.List` frame. Routes to the
-- right panel by `location`, ignoring frames for locations we
-- don't track (e.g. when the server starts emitting room item
-- lists for some other UI).
function FierymudRs.Inventory:onItemsList()
  local frame = gmcp and gmcp.Char and gmcp.Char.Items and gmcp.Char.Items.List
  if type(frame) ~= "table" then return end
  local location = frame.location
  if not location then return end
  local panel = self.panels[location]
  if not panel then return end
  panel.items = frame.items or {}
  self:render(location)
end

function FierymudRs.Inventory:show(location)
  local panel = self.panels[location]
  if panel and panel.container then panel.container:show() end
end

function FierymudRs.Inventory:hide(location)
  local panel = self.panels[location]
  if panel and panel.container then panel.container:hide() end
end

function FierymudRs.Inventory:toggle(location)
  local panel = self.panels[location]
  if not panel or not panel.container then return end
  if panel.container.hidden then
    panel.container:show()
  else
    panel.container:hide()
  end
end

FierymudRs._subsystems = FierymudRs._subsystems or {}
FierymudRs._subsystems.Inventory = {
  name = "Inventory",
  setup = function() FierymudRs.Inventory:setup() end,
  isReady = function()
    return FierymudRs.Inventory ~= nil
       and FierymudRs.Inventory.panels ~= nil
       and FierymudRs.Inventory.panels.inv ~= nil
  end,
  -- Panels are top-level Adjustable.Containers (not parented to
  -- left/right_container), so cleanup() won't reach them via the
  -- subtree walk. Destroy them by name here.
  teardown = function()
    if not FierymudRs.Inventory or not FierymudRs.Inventory.panels then return end
    for _, panel in pairs(FierymudRs.Inventory.panels) do
      if panel and panel.container and FierymudRs._destroyGeyserSubtree then
        FierymudRs._destroyGeyserSubtree(panel.container)
      end
    end
    FierymudRs.Inventory.panels = {}
  end,
}
