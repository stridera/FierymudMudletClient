-- Room mob panels — driven by the per-prompt `Room.Mobs` GMCP
-- frame. Splits the array into two panels:
--
--   THREATS    — hostile mobs in the room (HP% bar per row, status,
--                targeting indicator). The bar is the primary
--                glance signal: at-a-glance "how close am I to
--                killing this thing" without typing `consider`.
--   FRIENDLIES — non-hostile NPCs. No HP bar (don't waste pixels
--                on something you're not fighting); shows the
--                mob name plus a row of profession chips
--                (shop/bank/inn/...) so the player can spot a
--                vendor without examining each NPC.
--
-- Both panels support click-to-detail via `Room.Mob.Get`. The
-- response (`Room.Mob.Info`) opens a floating Adjustable
-- container with the full description + shop inventory.
--
-- Also handles `Room.Services` — the union of all mob professions
-- in the room — and renders it as a single chip strip above the
-- chat pane so the player can see at a glance "this room has a
-- shop and a bank" without scanning the THREATS/FRIENDLIES
-- panels.

FierymudRs = FierymudRs or {}
FierymudRs.Mobs = FierymudRs.Mobs or {}

-- Per-profession visual style. Color picked along role axis so
-- the eye can pre-attentively distinguish "buy/sell" services
-- (shop/bank — gold/yellow) from "rest/recover" (inn — cyan)
-- from "advancement" (trainer/guild — purple). Unknown
-- professions fall through to a neutral grey badge so a future
-- server-side profession addition still shows up.
-- Mudlet cecho color tag note: `<b:color>` is NOT a "bold color"
-- shortcut. It parses as `fg="b"` + `bg="color"` — so `<b:yellow>`
-- gives yellow *background* with an invalid foreground that renders
-- as a yellow-on-yellow invisible chip. Use plain `<color>` names
-- or `<r,g,b>` decimal literals (which cecho parses universally).
--
-- Each profession gets a Unicode pictogram so the chip reads as
-- a glance signal — eyes land on "shop here?" without scanning
-- text. Picked from the Miscellaneous Symbols + Pictographs
-- block so they render on common system fonts without an emoji
-- font installed. `icon` keeps the visual cue compact (3-4
-- chars when combined with the bracket); `label` is kept for
-- accessibility (screen readers / when the font fails to render
-- the glyph).
local PROFESSION_STYLE = {
  shop    = { color = "<255,215,0>",   icon = "⚒", label = "shop"    },  -- gold
  bank    = { color = "<yellow>",      icon = "$",  label = "bank"    },
  inn     = { color = "<cyan>",        icon = "☖", label = "inn"     },
  mail    = { color = "<128,255,255>", icon = "✉", label = "mail"    },  -- light cyan
  guild   = { color = "<208,144,255>", icon = "⚔", label = "guild"   },  -- violet
  trainer = { color = "<160,96,255>",  icon = "✦", label = "trainer" },  -- purple
}

local function chip(profession)
  local style = PROFESSION_STYLE[profession]
  if not style then
    return string.format("<dim_grey>[%s]<reset>", tostring(profession))
  end
  -- Chip format: icon + space + label inside brackets. The
  -- bracket keeps the chip visually delimited even if the
  -- icon glyph fails to render (rare on Win/Mac fonts but
  -- possible on minimal Linux installs).
  return string.format("%s[%s %s]<reset>", style.color, style.icon, style.label)
end

local function chips_line(professions)
  if type(professions) ~= "table" or #professions == 0 then return "" end
  local parts = {}
  for _, p in ipairs(professions) do
    parts[#parts + 1] = chip(p)
  end
  return table.concat(parts, " ")
end

-- Same color band thresholds the on-screen score command uses,
-- so a yellow bar here means the same thing as "looks bruised"
-- in the main window — consistency across UI surfaces.
local function hp_color(pct)
  pct = tonumber(pct) or 0
  if pct >= 75 then return "<green>"
  elseif pct >= 40 then return "<yellow>"
  elseif pct >= 15 then return "<orange>"
  else return "<red>" end
end

-- Stylesheets borrowed from Guages.lua's HP bar — keeps the
-- visual language consistent across all "HP indicator" surfaces
-- (self, party, target, hostile mob).
local hp_front = [[
  background-color: QLinearGradient( x1: 0, y1: 0, x2: 0, y2: 1, stop: 0 #a20e2c, stop: 0.5 #930f27, stop: 0.51 #8a0a1d, stop: 1 #6f0f14);
  border-top: 1px black solid;
  border-left: 1px black solid;
  border-bottom: 1px black solid;
  border-radius: 5;
  padding: 1px;
]]
local hp_back = [[
  background-color: QLinearGradient( x1: 0, y1: 0, x2: 0, y2: 1, stop: 0 #793744, stop: 0.5 #6f333e, stop: 0.51 #672d36, stop: 1 #542a2c);
  border-width: 1px;
  border-color: black;
  border-style: solid;
  border-radius: 5;
  padding: 1px;
]]

-- Section header geometry. 14px was too tight for fontSize 8 +
-- 1px borders + 1px padding — the descenders on lowercase letters
-- got chopped off (most visibly on the "S" in "NPCS"). Scale
-- both height and font with `text_scale` so HiDPI / large
-- monitors get readable chrome too.
local function header_height()
  return FierymudRs.fontSize(8) + 10
end
local function header_font_size()
  return FierymudRs.fontSize(8)
end
local section_tints = {
  threats   = { bg = "rgba(56,28,28,220)", border = "#723b3b", text = "#c49a9a" },
  friends   = { bg = "rgba(28,48,40,220)", border = "#3b6a52", text = "#9ac4b0" },
  services  = { bg = "rgba(28,40,56,220)", border = "#3b5572", text = "#9ab0c4" },
}

local function build_header_style(tint)
  return string.format([[
    background-color: %s;
    color: %s;
    border-bottom: 1px solid %s;
    font-weight: bold;
    letter-spacing: 1px;
    padding: 1px 6px;
  ]], tint.bg, tint.text, tint.border)
end

local function make_section_header(parent, name, y, title, role)
  local tint = section_tints[role] or section_tints.threats
  local label = Geyser.Label:new({
    name = name, x = 5, y = y, height = header_height(),
    width = "-10px", fontSize = header_font_size(),
  }, parent)
  pcall(function() label:setStyleSheet(build_header_style(tint)) end)
  label:cecho("<center>" .. title .. "</center>")
  return label
end

-- Status icon — short token surfaced after the mob's name. Empty
-- string when the server reports no status (which is the common
-- case). Today the server only ever emits "stunned"; the spec
-- reserves "casting" and "fleeing" for future use, so this map
-- is forward-compatible.
-- `type ~= "string"` rejects both Lua `nil` AND Mudlet's
-- `yajl.null` userdata sentinel (which JSON `null` decodes to —
-- the gotcha is that `yajl.null` is truthy, so a `not status`
-- check passes it through to `string.format` and errors with
-- "bad argument #2 to 'format' (string expected, got userdata)".
local function status_token(status)
  if type(status) ~= "string" or status == "" then return "" end
  if status == "stunned"  then return " <170,170,0>*stun*<reset>" end
  if status == "casting"  then return " <255,128,255>*cast*<reset>"   end
  if status == "fleeing"  then return " <dim_grey>*flee*<reset>"  end
  return string.format(" <dim_grey>*%s*<reset>", status)
end

-- Targeting indicator — calls out the mob currently swinging at
-- the player (matches Char.Vitals' implied "me" by name match
-- with FierymudRs.Character.name). Other names (party member,
-- another mob) get a generic arrow so the player can read
-- threat-routing at a glance. Same `type ~= "string"` guard as
-- status_token for JSON-null safety.
local function targeting_token(targeting)
  if type(targeting) ~= "string" or targeting == "" then return "" end
  local me = FierymudRs.Character and FierymudRs.Character.name
  if me and targeting == me then
    return " <255,80,80>→ YOU<reset>"
  end
  return string.format(" <dim_grey>→ %s<reset>", targeting)
end

-- Friendly NPC row styles. Hover swap brightens the row so the
-- player gets visual feedback that the line is clickable.
-- Defined above createFriendlyRow because Lua `local` is not
-- hoisted — referencing them after the function but before they
-- exist made every freshly-built row render unstyled until the
-- first hover triggered `bindFriendlyHover`.
local FRIENDLY_BASE_STYLE = [[
  background-color: rgba(18,28,22,245);
  color: #e0f0e0;
  padding: 2px 6px;
  border-bottom: 1px solid #1a241e;
]]
local FRIENDLY_HOVER_STYLE = [[
  background-color: rgba(40,72,52,250);
  color: #ffffff;
  padding: 2px 6px;
  border-bottom: 1px solid #4ca070;
]]

local function createHostileRow(parent, idx)
  -- 22px row: the gauge does double duty as the visual indicator
  -- AND the click target — its front Label captures clicks, the
  -- back is purely decorative.
  local gauge = Geyser.Gauge:new({
    name = "hostile_hp_" .. idx,
    width = "-5px",
    height = "22px",
    v_policy = Geyser.Fixed,
  }, parent)
  gauge.front:setStyleSheet(hp_front)
  gauge.back:setStyleSheet(hp_back)
  return gauge
end

local function createFriendlyRow(parent, idx)
  local label = Geyser.Label:new({
    name = "friendly_" .. idx,
    width = "-5px",
    height = "16px",
    fontSize = 9,
    v_policy = Geyser.Fixed,
  }, parent)
  pcall(function() label:setStyleSheet(FRIENDLY_BASE_STYLE) end)
  return label
end

-- Outbound: ask the server for full detail on `id`. Server
-- enforces same-room scope; a stale id (mob walked away between
-- frame + click) is silently dropped server-side, so we don't
-- need an error path here.
function FierymudRs.Mobs:requestDetail(id)
  if not id or id == "" then return end
  -- sendGMCP serializes the payload to JSON; both string and
  -- table second args work. We send the object form for clarity
  -- — server expects { id: string }.
  sendGMCP("Room.Mob.Get", { id = tostring(id) })
end

-- Single source of truth for Mobs panel layout. Both this file
-- (during setup) and Guages.lua / Skills.lua (for downstream
-- anchoring) call this. Recomputes from `header_height()` each
-- call so a live text_scale change re-anchors correctly.
function FierymudRs.Mobs.layout()
  local hh = header_height()
  local panel_h = 80
  local gap = 6
  local threats_header_y    = 375
  local threats_panel_y     = threats_header_y + hh + gap
  local friendlies_header_y = threats_panel_y + panel_h + gap
  local friendlies_panel_y  = friendlies_header_y + hh + gap
  return {
    hh = hh, panel_h = panel_h, gap = gap,
    threats_header_y = threats_header_y,
    threats_panel_y = threats_panel_y,
    friendlies_header_y = friendlies_header_y,
    friendlies_panel_y = friendlies_panel_y,
    bottom_y = friendlies_panel_y + panel_h + gap,
  }
end

function FierymudRs.Mobs:setup()
  local parent = FierymudRs.GUI and FierymudRs.GUI.left_container
  if not parent then return end

  local L = FierymudRs.Mobs.layout()
  local panel_h = L.panel_h
  local threats_header_y    = L.threats_header_y
  local threats_panel_y     = L.threats_panel_y
  local friendlies_header_y = L.friendlies_header_y
  local friendlies_panel_y  = L.friendlies_panel_y

  -- THREATS header (red tint — hostility).
  self.threats_header = self.threats_header
    or make_section_header(parent, "MobsThreatHeader",
                           threats_header_y, "THREATS", "threats")
  self.threats_header:hide()

  -- Hostile mob panel. VBox-of-gauges so each mob gets its own
  -- click-to-detail target.
  self.threats_container = self.threats_container or Geyser.VBox:new({
    name = "MobsThreats", x = 5, y = threats_panel_y,
    height = panel_h .. "px", width = "-10px",
  }, parent)
  self.threats_container:hide()
  self.threats_rows = self.threats_rows or {}

  -- FRIENDLIES header. Green-cyan tint distinguishes "safe to
  -- interact with" from the red hostile header above.
  self.friendlies_header = self.friendlies_header
    or make_section_header(parent, "MobsFriendlyHeader",
                           friendlies_header_y, "NPCS", "friends")
  self.friendlies_header:hide()

  self.friendlies_container = self.friendlies_container or Geyser.VBox:new({
    name = "MobsFriendlies", x = 5, y = friendlies_panel_y,
    height = panel_h .. "px", width = "-10px",
  }, parent)
  self.friendlies_container:hide()
  self.friendlies_rows = self.friendlies_rows or {}

  -- Services chip strip. Top row of the room-header (services
  -- on top, players-here on the bottom row — see Guages.lua).
  -- Parented to room_header (not chat_container) so EMCO can't
  -- cover it. Hidden when the union of professions is empty.
  local header_parent = FierymudRs.GUI.room_header
  if header_parent then
    self.services_label = self.services_label or Geyser.Label:new({
      name = "RoomServices",
      x = 0, y = 0, width = "100%", height = "50%",
      fontSize = FierymudRs.fontSize(10),
    }, header_parent)
    -- Brighter blue, slightly thicker bottom border, and a touch
    -- more vertical padding so the chip text reads clearly at
    -- the narrow column width. The earlier muted background was
    -- visually indistinguishable from the chat tab strip.
    pcall(function() self.services_label:setStyleSheet([[
      background-color: rgba(36,52,74,235);
      color: #c7d6ea;
      border-bottom: 2px solid #5e7ea6;
      padding: 2px 6px;
    ]]) end)
    self.services_label:hide()
  end

  -- Floating Mob Info popup — built lazily on first Room.Mob.Info
  -- frame so a player who never clicks a mob doesn't pay for the
  -- widget allocation. See `ensureDetailPanel` below.
end

local function ensureDetailPanel(self)
  if self.detail and self.detail.container then return self.detail end
  -- Positioned to overlap only a portion of the main text area —
  -- the previous 56%×60% covered nearly the whole game text,
  -- which was too intrusive for a click-to-detail popup. 38%×52%
  -- still fits the typical 8-12-item shop inventory with the
  -- description block and leaves the main text area visible.
  local container = Adjustable.Container:new({
    name = "MobInfoPanel",
    x = "30%", y = "15%",
    width = "38%", height = "52%",
    titleText = "Mob Info",
    titleTxtColor = "white",
    adjLabelstyle = "background-color: black; border: 2px groove grey;",
  })
  -- Console occupies most of the container; the close button
  -- sits in the top-right corner at width=24px height=24px, so
  -- shrink the console by that much on the right + top to avoid
  -- overlapping with it.
  local console = Geyser.MiniConsole:new({
    name = "MobInfoConsole",
    x = 0, y = 0, width = "-26px", height = "100%",
    color = "black",
    fontSize = 10,
    autoWrap = true,
  }, container)
  -- Image-button-style close X. Pulls in a stylesheet that draws
  -- a circle background and a white "✕" glyph so it reads as a
  -- proper close button rather than chrome-as-text. Click hides
  -- the panel without destroying it (re-show on next mob click).
  local close_btn = Geyser.Label:new({
    name = "MobInfoClose",
    x = "-26px", y = 2, width = "24px", height = "24px",
    fontSize = 12,
  }, container)
  pcall(function() close_btn:setStyleSheet([[
    background-color: rgba(80,20,20,230);
    color: #ffffff;
    border: 1px solid #c04040;
    border-radius: 12px;
    font-weight: bold;
    qproperty-alignment: AlignCenter;
  ]]) end)
  close_btn:echo([[<center>✕</center>]])
  pcall(function()
    close_btn:setClickCallback(function()
      FierymudRs.Mobs:hideDetail()
    end)
    close_btn:setToolTip("Close")
  end)
  -- Subtle hover state so the close-X feels alive.
  pcall(function()
    close_btn:setOnEnter(function()
      close_btn:setStyleSheet([[
        background-color: rgba(180,40,40,250);
        color: #ffffff;
        border: 1px solid #ff8080;
        border-radius: 12px;
        font-weight: bold;
        qproperty-alignment: AlignCenter;
      ]])
    end)
    close_btn:setOnLeave(function()
      close_btn:setStyleSheet([[
        background-color: rgba(80,20,20,230);
        color: #ffffff;
        border: 1px solid #c04040;
        border-radius: 12px;
        font-weight: bold;
        qproperty-alignment: AlignCenter;
      ]])
    end)
  end)
  container:hide()
  self.detail = { container = container, console = console, close_btn = close_btn }
  return self.detail
end

-- Public: hide the floating Mob Info popup. Bound to the panel's
-- close button via setClickCallback once the panel exists; also
-- callable from `fm` aliases.
function FierymudRs.Mobs:hideDetail()
  if self.detail and self.detail.container then
    self.detail.container:hide()
  end
end

-- Build a coin-string from a copper price. FieryMUD uses
-- 1 plat = 100 gold = 10000 silver = 1000000 copper; we render
-- only the leading non-zero unit to keep the line short
-- ("12g 50c" → "12g" when copper is 0). Zero copper = "—" so
-- "use prototype base × buy_profit" shows as a clear placeholder
-- rather than "0c".
local function format_price(copper)
  copper = tonumber(copper) or 0
  if copper <= 0 then return "<dim_grey>—<reset>" end
  if copper >= 1000000 then
    return string.format("<white>%dp<reset>", math.floor(copper / 1000000))
  elseif copper >= 10000 then
    return string.format("<255,215,0>%dg<reset>", math.floor(copper / 10000))
  elseif copper >= 100 then
    return string.format("<yellow>%ds<reset>", math.floor(copper / 100))
  else
    return string.format("<170,170,0>%dc<reset>", copper)
  end
end

local function format_stock(stock)
  stock = tonumber(stock) or 0
  if stock < 0 then return "<green>∞<reset>" end
  if stock == 0 then return "<red>0<reset>" end
  return string.format("<white>%d<reset>", stock)
end

-- Render a Room.Mob.Info frame into the floating detail panel.
-- Description first (full RP text), then a chip strip of
-- professions, then optional blocks (shop today; bank/trainer
-- to come). Each future block follows the same optional-key
-- pattern so a new top-level field in Room.Mob.Info just needs
-- a render branch added here.
function FierymudRs.Mobs:renderDetail(info)
  local panel = ensureDetailPanel(self)
  local c = panel.console
  -- `:clear()` alone resets the MiniConsole buffer. (Some older
  -- snippets paired it with `:setBuffer({})`, but that method
  -- doesn't exist on Geyser.MiniConsole and raises a runtime
  -- nil-method error before the `:show()` below can run —
  -- leaving the popup invisible despite the frame arriving.)
  c:clear()
  -- Bright white for the headline name — the popup background is
  -- black so we want maximum contrast for the title line.
  c:cecho(string.format("<white>%s<reset>\n", info.name or "(unknown)"))
  c:cecho(string.format("<dim_grey>id: %s<reset>\n", tostring(info.id or "?")))
  if info.description and info.description ~= "" then
    c:cecho("<white>" .. info.description .. "<reset>\n")
  end
  if type(info.professions) == "table" and #info.professions > 0 then
    c:cecho("\n<dim_grey>Services: <reset>" .. chips_line(info.professions) .. "\n")
  end
  if type(info.shop) == "table" then
    c:cecho("\n<255,215,0>Shop<reset>\n")
    c:cecho("<dim_grey>" .. string.rep("─", 30) .. "<reset>\n")
    local items = info.shop.items or {}
    if #items == 0 then
      c:cecho("  <dim_grey>(no inventory)<reset>\n")
    else
      for _, it in ipairs(items) do
        -- Each item line: name (clickable to buy), price, stock.
        -- cechoPopup makes the whole line a click target with a
        -- single-action menu ("Buy"); the trailing newline is
        -- part of the popup so the entire row is the hit zone.
        local kw = tostring(it.name or ""):match("(%S+)%s*$") or ""
        local buy_cmd = "buy " .. kw
        local line = string.format(
          "  <white>%s<reset>  %s  <dim_grey>x<reset>%s\n",
          tostring(it.name or "(?)"),
          format_price(it.price),
          format_stock(it.stock)
        )
        -- Fourth arg `useCurrentFormat`: TRUE means "render the
        -- text in the console's current format and IGNORE cecho
        -- color tags" — so an embedded `<color>tag<reset>` would
        -- render as literal text. We want the opposite (parse
        -- the tags), which is the `false` branch of this flag.
        c:cechoPopup(line, { buy_cmd, "look " .. kw }, { "Buy", "Look" }, false)
      end
    end
    if type(info.shop.accepts) == "table" and #info.shop.accepts > 0 then
      c:cecho("\n<dim_grey>Buys: " .. table.concat(info.shop.accepts, ", ") .. "<reset>\n")
    end
  end
  panel.container:show()
  -- Belt-and-suspenders raise. The popup is centered over the
  -- main text area (no overlap with the chat/map column today)
  -- so z-order rarely matters in practice, but a future
  -- layout could put a HUD over the main area too. Both APIs
  -- are guarded: `raiseAll` is the Geyser method (raises the
  -- container plus all its child widgets); `raiseWindow` is
  -- Mudlet's lower-level escape hatch. pcall against the
  -- version-skew case where one isn't implemented.
  pcall(function() panel.container:raiseAll() end)
  pcall(function() raiseWindow(panel.container.name) end)
end

-- Public: gmcp.Room.Mob.Info arrival. The reply is the
-- response to our `Room.Mob.Get` request. Server enforces
-- same-room scope and silently drops mismatches, so a missing
-- frame is the normal "no longer visible" path — not an error.
function FierymudRs.Mobs:onRoomMobInfo()
  local info = gmcp and gmcp.Room and gmcp.Room.Mob and gmcp.Room.Mob.Info
  if type(info) ~= "table" then return end
  -- Remember which mob the popup is currently showing — used by
  -- onRoomMobs to auto-hide the popup when the mob walks away or
  -- the player moves to a new room.
  self._detail_mob_id = info.id
  self:renderDetail(info)
end

-- Bind a row's click + tooltip. `target` is the widget that
-- captures clicks — for hostile rows that's `gauge.front` (the
-- gauge's own front Label); for friendly rows it's the row
-- Label itself. The `_bound_id` guard skips re-binding when the
-- slot's mob id is unchanged across renders — `setClickCallback`
-- closure allocation + Mudlet API calls aren't free in the
-- per-prompt hot path.
local function bindRowClick(row, target, id, name)
  if row._bound_id == id then return end
  row._bound_id = id
  pcall(function()
    target:setClickCallback(function()
      FierymudRs.Mobs:requestDetail(id)
    end)
    target:setToolTip(string.format(
      "%s — click for details", tostring(name or "(unknown)")
    ))
  end)
end

local function bindFriendlyHover(label)
  if label._hover_bound then return end
  label._hover_bound = true
  pcall(function()
    label:setOnEnter(function() label:setStyleSheet(FRIENDLY_HOVER_STYLE) end)
    label:setOnLeave(function() label:setStyleSheet(FRIENDLY_BASE_STYLE) end)
  end)
end

-- Change-detection signature for the mob list. Server emits the
-- Room.Mobs frame per prompt regardless of whether anything
-- actually changed — without this guard we rebuild every gauge
-- stylesheet + click binding multiple times per second during
-- combat. id|hostile|hp_percent|status|targeting captures the
-- fields the renderer actually reads.
local function mobs_signature(mobs)
  local parts = {}
  for _, m in ipairs(mobs) do
    if type(m) == "table" then
      parts[#parts + 1] = string.format(
        "%s|%s|%d|%s|%s",
        tostring(m.id), tostring(m.hostile),
        math.floor(tonumber(m.hp_percent) or 0),
        tostring(m.status or ""),
        tostring(m.targeting or "")
      )
    end
  end
  return table.concat(parts, ";")
end

-- Public: refresh hostile + friendly panels from gmcp.Room.Mobs.
-- Empty array hides both panels. Server emits this every prompt,
-- so the panels stay current as mobs walk / die / spawn.
function FierymudRs.Mobs:onRoomMobs()
  local mobs = gmcp and gmcp.Room and gmcp.Room.Mobs
  if type(mobs) ~= "table" then
    self:_renderHostiles({})
    self:_renderFriendlies({})
    -- Popup mob can't be in a room with no mobs — auto-close.
    if self._detail_mob_id then self:hideDetail() end
    self._detail_mob_id = nil
    self._mobs_sig = ""
    return
  end
  local sig = mobs_signature(mobs)
  if sig == self._mobs_sig then return end
  self._mobs_sig = sig
  local hostile, friendly = {}, {}
  -- Build a quick lookup of mob ids in this room so we can detect
  -- when the popup's mob is no longer present (the player walked
  -- away, the mob walked away, or the mob died).
  local present_ids = {}
  for _, m in ipairs(mobs) do
    if m and m.id then present_ids[tostring(m.id)] = true end
    if m and m.hostile then
      hostile[#hostile + 1] = m
    elseif m then
      friendly[#friendly + 1] = m
    end
  end
  self:_renderHostiles(hostile)
  self:_renderFriendlies(friendly)
  -- Auto-hide the popup when its subject leaves the room. The
  -- detail panel showing stale info is worse than no panel —
  -- the player might try `buy <item>` against a mob that's no
  -- longer here.
  if self._detail_mob_id and not present_ids[tostring(self._detail_mob_id)] then
    self:hideDetail()
    self._detail_mob_id = nil
  end
end

function FierymudRs.Mobs:_renderHostiles(list)
  local container = self.threats_container
  local header = self.threats_header
  if not container then return end
  if #list == 0 then
    container:hide()
    if header then header:hide() end
    return
  end
  for i, mob in ipairs(list) do
    local row = self.threats_rows[i] or createHostileRow(container, i)
    self.threats_rows[i] = row
    local pct = tonumber(mob.hp_percent) or 0
    -- Overlay text: HP color + name + status + targeting. Keeps
    -- the row compact while surfacing the three most useful
    -- glance signals during combat.
    local label = string.format(
      "<center>%s%s<reset>%s%s <dim_grey>%d%%<reset></center>",
      hp_color(pct), tostring(mob.name or "?"),
      status_token(mob.status), targeting_token(mob.targeting),
      pct
    )
    row:setValue(math.max(1, pct), 100, label)
    row:show()
    bindRowClick(row, row.front, mob.id, mob.name)
  end
  for i = #list + 1, #self.threats_rows do
    self.threats_rows[i]:hide()
  end
  container:show()
  if header then header:show() end
end

function FierymudRs.Mobs:_renderFriendlies(list)
  local container = self.friendlies_container
  local header = self.friendlies_header
  if not container then return end
  if #list == 0 then
    container:hide()
    if header then header:hide() end
    return
  end
  for i, mob in ipairs(list) do
    local row = self.friendlies_rows[i] or createFriendlyRow(container, i)
    self.friendlies_rows[i] = row
    local chips = chips_line(mob.professions)
    local body = string.format(
      "<white>%s<reset>%s%s",
      tostring(mob.name or "?"),
      status_token(mob.status),
      chips ~= "" and ("  " .. chips) or ""
    )
    row:cecho(body)
    row:show()
    bindRowClick(row, row, mob.id, mob.name)
    bindFriendlyHover(row)
  end
  for i = #list + 1, #self.friendlies_rows do
    self.friendlies_rows[i]:hide()
  end
  container:show()
  if header then header:show() end
end

-- Public: refresh the room services chip strip from
-- gmcp.Room.Services.services. Empty list hides the strip; the
-- server may emit per-prompt, so the change-detection guard
-- avoids re-rendering both the strip AND the (cascaded)
-- Inventory panel every tick.
function FierymudRs.Mobs:onRoomServices()
  local label = self.services_label
  local data = gmcp and gmcp.Room and gmcp.Room.Services
  local list = data and data.services
  -- Sort+join produces a stable signature regardless of server-
  -- side emission order. Empty list signature is the empty
  -- string, which distinguishes "no services" from "uninitialized".
  local sig
  if type(list) == "table" then
    local sorted = {}
    for i, s in ipairs(list) do sorted[i] = tostring(s) end
    table.sort(sorted)
    sig = table.concat(sorted, "|")
  else
    sig = "<nil>"
  end
  if sig == self._services_sig then return end
  self._services_sig = sig
  if label then
    if type(list) ~= "table" or #list == 0 then
      label:hide()
    else
      label:cecho("<dim_grey>Services:<reset>  " .. chips_line(list))
      label:show()
    end
  end
  -- Cascade to Inventory so its click menu reflects the new
  -- room's services (Sell when shop, Deposit when bank, etc.).
  -- Only fires on actual room changes thanks to the sig guard.
  if FierymudRs.Inventory and FierymudRs.Inventory.panels then
    for location, panel in pairs(FierymudRs.Inventory.panels) do
      if panel and panel.items and FierymudRs.Inventory.render then
        FierymudRs.Inventory:render(location)
      end
    end
  end
end

FierymudRs._subsystems = FierymudRs._subsystems or {}
FierymudRs._subsystems.Mobs = {
  name = "Mobs",
  setup = function() FierymudRs.Mobs:setup() end,
  isReady = function()
    return FierymudRs.Mobs ~= nil
       and FierymudRs.Mobs.threats_container ~= nil
  end,
  -- Mob panel widgets live under left_container / chat_container;
  -- the top-level cleanup walk reaches them. We just nil the
  -- cached refs so isReady flips false. The floating detail panel
  -- is top-level (Adjustable.Container with no parent), so we
  -- destroy it explicitly here.
  teardown = function()
    if not FierymudRs.Mobs then return end
    if FierymudRs.Mobs.detail and FierymudRs.Mobs.detail.container
       and FierymudRs._destroyGeyserSubtree then
      FierymudRs._destroyGeyserSubtree(FierymudRs.Mobs.detail.container)
    end
    FierymudRs.Mobs.detail = nil
    FierymudRs.Mobs.threats_container = nil
    FierymudRs.Mobs.threats_header = nil
    FierymudRs.Mobs.threats_rows = nil
    FierymudRs.Mobs.friendlies_container = nil
    FierymudRs.Mobs.friendlies_header = nil
    FierymudRs.Mobs.friendlies_rows = nil
    FierymudRs.Mobs.services_label = nil
  end,
}
