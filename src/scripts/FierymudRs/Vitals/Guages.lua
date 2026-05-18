FierymudRs = FierymudRs or {}
FierymudRs.Guages = FierymudRs.Guages or {}

-- GMCP event handlers — register once per package load. Mudlet
-- dispatches gmcp.X.Y.Z events when an SB GMCP frame for that
-- dotted path arrives. Room.Players snapshot fires on look /
-- move; Add/RemovePlayer fire on enter/leave. Char.Items.List
-- fires on inv / equipment / get / drop / wear / remove. We
-- guard each handler with `Initialized` so frames arriving
-- before tryInit completes don't try to render into containers
-- that don't exist yet.
local function safe_call(fn, ...)
  if not FierymudRs.Initialized then return end
  fn(...)
end
-- Named handlers replace in place on reload, so the
-- `_gmcp_handlers_registered` guard the old anonymous version
-- needed is no longer required — re-running the script body
-- safely re-binds.
registerNamedEventHandler("FierymudRs", "Guages.roomPlayers",
  "gmcp.Room.Players", function()
    safe_call(function() FierymudRs.Guages:updateRoomPlayers() end)
  end)
registerNamedEventHandler("FierymudRs", "Guages.roomAddPlayer",
  "gmcp.Room.AddPlayer", function()
    safe_call(function() FierymudRs.Guages:updateRoomPlayers() end)
  end)
registerNamedEventHandler("FierymudRs", "Guages.roomRemovePlayer",
  "gmcp.Room.RemovePlayer", function()
    safe_call(function() FierymudRs.Guages:updateRoomPlayers() end)
  end)

local container_height = 90
local bar_height = 20
local stylesheets = {
  hp_front = [[
    background-color: QLinearGradient( x1: 0, y1: 0, x2: 0, y2: 1, stop: 0 #a20e2c, stop: 0.5 #930f27, stop: 0.51 #8a0a1d, stop: 1 #6f0f14);
    border-top: 1px black solid;
    border-left: 1px black solid;
    border-bottom: 1px black solid;
    border-radius: 7;
    padding: 3px;
  ]],
  hp_back = [[
    background-color: QLinearGradient( x1: 0, y1: 0, x2: 0, y2: 1, stop: 0 #793744, stop: 0.5 #6f333e, stop: 0.51 #672d36, stop: 1 #542a2c);
    border-width: 1px;
    border-color: black;
    border-style: solid;
    border-radius: 7;
    padding: 3px;
  ]],
  move_front = [[
    background-color: QLinearGradient( x1: 0, y1: 0, x2: 0, y2: 1, stop: 0 #10ae2b, stop: 0.5 #109e2a, stop: 0.51 #0b9329, stop: 1 #117731);
    border-top: 1px black solid;
    border-left: 1px black solid;
    border-bottom: 1px black solid;
    border-radius: 7;
    padding: 3px;
  ]],
  move_back = [[
    background-color: QLinearGradient( x1: 0, y1: 0, x2: 0, y2: 1, stop: 0 #377942, stop: 0.5 #336f3e, stop: 0.51 #2d673a, stop: 1 #2a5437);
    border-width: 1px;
    border-color: black;
    border-style: solid;
    border-radius: 7;
    padding: 3px;
  ]],
  xp_front = [[
    background-color: QLinearGradient( x1: 0, y1: 0, x2: 0, y2: 1, stop: 0 #8d209e, stop: 0.5 #831e90, stop: 0.51 #7c1886, stop: 1 #6d1b6c);
    border-top: 1px black solid;
    border-left: 1px black solid;
    border-bottom: 1px black solid;
    border-radius: 7;
    padding: 3px;
  ]],
  xp_back = [[
    background-color: QLinearGradient( x1: 0, y1: 0, x2: 0, y2: 1, stop: 0 #8d209e, stop: 0.5 #831e90, stop: 0.51 #7c1886, stop: 1 #6d1b6c);
    border-width: 1px;
    border-color: black;
    border-style: solid;
    border-radius: 7;
    padding: 3px;
  ]]
}

-- Helper
local function getCappedVal(val, max)
  local val_num = tonumber(val)
  local max_num = tonumber(max)
  return math.min(val_num, math.max(100, max_num))
end

-- Vitals
local function createVitalsGuage(parent, name)
  debugc("New Profile " .. name)

  local container = Geyser.VBox:new({
    name = name, width = "-5px", height = container_height, v_policy = Geyser.Fixed,
  }, parent)

  -- Header
  local header = Geyser.Label:new({
    name = "header" .. name, width = "-5px", height = bar_height .. "px", v_policy = Geyser.Fixed,
  }, container)

  -- HP BAR
  local hpbar = Geyser.Gauge:new({
    name = "hpbar" .. name, width = "-5px", height = bar_height .. "px", v_policy = Geyser.Fixed,
  }, container)
  hpbar.front:setStyleSheet(stylesheets.hp_front)
  hpbar.back:setStyleSheet(stylesheets.hp_back)

  -- Movement Bar
  local movebar = Geyser.Gauge:new({
    name = "movebar" .. name, width = "-5px", height = bar_height .. "px", v_policy = Geyser.Fixed,
  }, container)
  movebar.front:setStyleSheet(stylesheets.move_front)
  movebar.back:setStyleSheet(stylesheets.move_back)

  -- XP Bar
  local xpbar = Geyser.Gauge:new({
    name = "xpbar" .. name, width = "-5px", height = bar_height .. "px", v_policy = Geyser.Fixed,
  }, container)
  xpbar.front:setStyleSheet(stylesheets.xp_front)
  xpbar.back:setStyleSheet(stylesheets.xp_back)

  return {
    container = container,
    header = header,
    hp = hpbar,
    move = movebar,
    xp = xpbar
  }
end

local function updateVitalsGuage(guage, character)
  local level = tonumber(character.level)
  local vitals = character.Vitals
  guage.header:echo("<center>" .. character.name .. " (" .. level .. ") " .. character.class:upper() .. "</center>")
  guage.hp:setValue(getCappedVal(vitals.hp, vitals.hp_max), tonumber(vitals.hp_max),
    "<center>HP: " .. tonumber(vitals.hp) .. " / " .. tonumber(vitals.hp_max) .. "</center>")
  guage.move:setValue(getCappedVal(vitals.move, vitals.move_max), tonumber(vitals.move_max),
    "<center>Move: " .. tonumber(vitals.move) .. " / " .. tonumber(vitals.move_max) .. "</center>")
  if level > 99 then
    guage.xp:setValue(1, 1, "<center>GOD</center>")
  elseif level == 99 and tonumber(character.exp_percent) == 100 then
    guage.xp:setValue(1, 1, "<center>**</center>")
  else
    guage.xp:setValue(tonumber(character.exp_percent), 100,
      "<center>XP: " .. tonumber(character.exp_percent) .. "%</center>")
  end
  guage.container:show()
end

-- Combat — three stacked rows (TANK / OPPONENT / TARGET). Target
-- is the mob *I'm swinging at* this round, opponent is the mob
-- currently swinging at the tank. They coincide for solo fights;
-- diverge when the tank holds aggro while DPS focus-fires
-- another mob. When they coincide we collapse to one row so the
-- panel doesn't waste vertical space duplicating data. When they
-- diverge the TARGET row gets a brighter accent so the eye lands
-- on "what's about to take my damage" first.
local target_stylesheets = {
  -- Brighter orange-tinted variant of the HP gradient — same
  -- shape as `hp_front` so the bar geometry/borders match the
  -- tank/opponent rows, just shifted into the target/focus hue.
  target_front = [[
    background-color: QLinearGradient( x1: 0, y1: 0, x2: 0, y2: 1, stop: 0 #ffb347, stop: 0.5 #ff8c1a, stop: 0.51 #f97b00, stop: 1 #c46000);
    border-top: 1px black solid;
    border-left: 1px black solid;
    border-bottom: 1px black solid;
    border-radius: 7;
    padding: 3px;
  ]],
  target_back = [[
    background-color: QLinearGradient( x1: 0, y1: 0, x2: 0, y2: 1, stop: 0 #6b4a2a, stop: 0.5 #5e3f23, stop: 0.51 #54381f, stop: 1 #3f2a17);
    border-width: 1px;
    border-color: black;
    border-style: solid;
    border-radius: 7;
    padding: 3px;
  ]],
}

local function createCombatGuage()
  local container = Geyser.VBox:new({
    name = "Combat", width = "-5px", height = container_height,
  }, FierymudRs.Guages.combat_container)
  container:hide()

  local tank_header = Geyser.Label:new({
    name = "tank_header", width = "-5px", height = bar_height .. "px",
    message = "<center>TANK:</center>"
  }, container)

  local tank_hpbar = Geyser.Gauge:new({
    name = "tank_hpbar", width = "-5px", height = bar_height .. "px",
  }, container)
  tank_hpbar.front:setStyleSheet(stylesheets.hp_front)
  tank_hpbar.back:setStyleSheet(stylesheets.hp_back)

  local opp_header = Geyser.Label:new({
    name = "opp_header", width = "-5px", height = bar_height .. "px",
    message = "<center>OPPONENT:</center>"
  }, container)

  local opp_hpbar = Geyser.Gauge:new({
    name = "opp_hpbar", width = "-5px", height = bar_height .. "px",
  }, container)
  opp_hpbar.front:setStyleSheet(stylesheets.hp_front)
  opp_hpbar.back:setStyleSheet(stylesheets.hp_back)

  -- Target row (my current swing target). Hidden when the target
  -- coincides with the opponent so the panel collapses to the
  -- two-row view. Visible when divergent — DPS focus-firing while
  -- tank holds threat.
  local target_header = Geyser.Label:new({
    name = "target_header", width = "-5px", height = bar_height .. "px",
    message = "<center>TARGET:</center>"
  }, container)
  target_header:hide()

  local target_hpbar = Geyser.Gauge:new({
    name = "target_hpbar", width = "-5px", height = bar_height .. "px",
  }, container)
  target_hpbar.front:setStyleSheet(target_stylesheets.target_front)
  target_hpbar.back:setStyleSheet(target_stylesheets.target_back)
  target_hpbar:hide()

  FierymudRs.Guages.CombatGuages = {
    container = container,
    tank_header = tank_header,
    tank_hpbar = tank_hpbar,
    opp_header = opp_header,
    opp_hpbar = opp_hpbar,
    target_header = target_header,
    target_hpbar = target_hpbar,
  }
end

-- Public Functions

function FierymudRs.Guages:updateVitals(vitals, profile)
  if profile then
    local guage = FierymudRs.Guages.allies[profile] or createVitalsGuage(FierymudRs.Guages.ally_container, profile)
    debugc("Updating profile " .. profile)
    updateVitalsGuage(guage, vitals)
    FierymudRs.Guages.allies[profile] = guage
  else
    if FierymudRs.Guages.CharacterGuage then
      updateVitalsGuage(FierymudRs.Guages.CharacterGuage, vitals)
    end
  end
end

function FierymudRs.Guages:removeGuage(profile)
  local guage = FierymudRs.Guages.allies[profile]
  debugc("Removing profile " .. profile)
  if guage then
    guage.container:hide()
    FierymudRs.Guages.ally_container:remove(guage.container)
    FierymudRs.Guages.allies[profile] = nil
  end
end

function FierymudRs.Guages:updateCombat(combat)
  -- Guard against missing data
  if not combat or not combat.tank or not combat.opponent then return end
  if not FierymudRs.Guages.CombatGuages then return end

  local guage = FierymudRs.Guages.CombatGuages

  -- Tank row — name + absolute HP (the only combat slot the
  -- server exposes raw HP/max for; everything else is %).
  local tank_name = combat.tank.name or "Unknown"
  local tank_hp = tonumber(combat.tank.hp) or 0
  local tank_max_hp = tonumber(combat.tank.max_hp) or 1
  guage.tank_header:echo("<center>Tank: " .. tank_name .. "</center>")
  guage.tank_hpbar:setValue(getCappedVal(tank_hp, tank_max_hp), tank_max_hp,
    "<center>HP: " .. tank_hp .. " / " .. tank_max_hp .. "</center>")

  -- Opponent row — mob currently swinging at the tank.
  local opp_name = combat.opponent.name or "Unknown"
  local opp_hp_percent = tonumber(combat.opponent.hp_percent) or 0
  guage.opp_header:echo("<center>Opponent: " .. opp_name .. "</center>")
  guage.opp_hpbar:setValue(opp_hp_percent, 100,
    "<center>HP: " .. opp_hp_percent .. "%</center>")

  -- Target row — only visible when my swing target differs from
  -- the opponent (DPS focus-firing while tank holds threat).
  -- When they coincide, collapse to the two-row view so we don't
  -- duplicate the same bar at twice the height. Name-match is
  -- the cheapest comparison and handles every legitimate
  -- divergence — server never emits two distinct mobs with the
  -- same display name in one fight.
  local target = combat.target
  local divergent = target
    and target.name
    and target.name ~= opp_name
  if divergent then
    local tgt_pct = tonumber(target.hp_percent) or 0
    guage.target_header:echo("<center>Target: " .. target.name .. "</center>")
    guage.target_hpbar:setValue(tgt_pct, 100,
      "<center>HP: " .. tgt_pct .. "%</center>")
    guage.target_header:show()
    guage.target_hpbar:show()
  else
    guage.target_header:hide()
    guage.target_hpbar:hide()
  end

  guage.container:show()
  if FierymudRs.Guages.combat_container then
    FierymudRs.Guages.combat_container:show()
  end
  if FierymudRs.Guages.combat_header then
    FierymudRs.Guages.combat_header:show()
  end
end

function FierymudRs.Guages:clearCombat()
  if FierymudRs.Guages.CombatGuages and FierymudRs.Guages.CombatGuages.container then
    FierymudRs.Guages.CombatGuages.container:hide()
  end
  if FierymudRs.Guages.combat_container then
    FierymudRs.Guages.combat_container:hide()
  end
  if FierymudRs.Guages.combat_header then
    FierymudRs.Guages.combat_header:hide()
  end
end

-- Section header style — small uppercase letter-spaced label
-- that titles each panel and provides a visual separator. Each
-- header gets a subtle role-tinted background so the eye can
-- pre-attentively identify section type without reading the
-- label. Tints are muted (~25% saturation) to stay chrome-tier
-- and not compete with the data inside.
-- Section header geometry. Scales with the user's font preference
-- so HiDPI / large-monitor setups get readable chrome. The
-- previous fixed 14px height clipped descenders ("the bottom of
-- the S in NPCS") at the default font; computing from fontSize +
-- 10 leaves 4-5px of breathing room top and bottom regardless of
-- scale.
local function header_height()
  return FierymudRs.fontSize(8) + 10
end
local function header_font_size()
  return FierymudRs.fontSize(8)
end

-- Role tints — same dim base, different hue accent. Picked along
-- a "what does this section ask of me" axis: party = trust/blue,
-- threats = hostility/red, target = combat focus/orange,
-- allies = friendly-cyan.
local section_tints = {
  default = { bg = "rgba(28,32,40,220)",  border = "#404652", text = "#9aa1ab" },
  party   = { bg = "rgba(28,40,56,220)",  border = "#3b5572", text = "#9ab0c4" },
  threats = { bg = "rgba(56,28,28,220)",  border = "#723b3b", text = "#c49a9a" },
  target  = { bg = "rgba(56,40,24,220)",  border = "#724f24", text = "#c4b09a" },
  allies  = { bg = "rgba(28,48,48,220)",  border = "#3b6a6a", text = "#9ac4c4" },
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
  local tint = section_tints[role] or section_tints.default
  local label = Geyser.Label:new({
    name = name, x = 5, y = y, height = header_height(),
    width = "-10px", fontSize = header_font_size(),
  }, parent)
  pcall(function() label:setStyleSheet(build_header_style(tint)) end)
  label:cecho("<center>" .. title .. "</center>")
  return label
end

function FierymudRs.Guages:setup()
  -- Left column layout, top → bottom:
  --   0..90    character_container  self vitals (HP/Move/XP + name)
  --   92..110  (Tracker docks here)
  --   115..129 PARTY section header
  --   130..370 group_container       party members (hidden when solo)
  --   375..389 THREATS section header (owned by Mobs.lua)
  --   390..470 hostile mobs          (owned by Mobs.lua)
  --   475..489 NPCS section header   (owned by Mobs.lua)
  --   490..570 friendly mobs         (owned by Mobs.lua)
  --   575..589 ALLIES section header (rare, both hidden when no allies)
  --   590..690 ally_container
  --   -226..-212 TARGET section header (anchored to bottom)
  --   -210..0  combat_container      current fight
  -- Headers ride with their panels — show when the panel shows,
  -- hide when it hides — so the chrome doesn't outlast the data.

  -- Character Vital Window
  local char_container = FierymudRs.Guages.character_container or Geyser.Container:new({
    name = "Characters", x = 0, y = 0, height = container_height, width = "-5px"
  }, FierymudRs.GUI.left_container)
  FierymudRs.Guages.character_container = char_container

  FierymudRs.Guages.CharacterGuage = FierymudRs.Guages.CharacterGuage or createVitalsGuage(char_container, "character")
  FierymudRs.Guages:updateVitals(FierymudRs.Character)

  -- PARTY section (blue-grey tint — trust / allies)
  FierymudRs.Guages.group_header = FierymudRs.Guages.group_header
    or make_section_header(FierymudRs.GUI.left_container,
        "GroupHeader", 115, "PARTY", "party")
  FierymudRs.Guages.group_header:hide()

  -- Group panel — consumes gmcp.Group (server emits {leader,
  -- members:[{name, with_leader, level, class, stats:{hp, max_hp,
  -- mv, max_mv}}]} on every prompt). Hidden when solo (server
  -- emits an empty `{}` frame in that case). Each member row is
  -- a single-line label showing name, level/class, current HP/MV
  -- ratio, and a marker for "in this room".
  FierymudRs.Guages.group_container = FierymudRs.Guages.group_container or Geyser.VBox:new({
    name = "Group", x = 5, y = 130, height = "240px", width = "-10px"
  }, FierymudRs.GUI.left_container)
  FierymudRs.Guages.group_container:hide()
  FierymudRs.Guages.group_rows = FierymudRs.Guages.group_rows or {}
  -- Schema migration: pre-0.10 stored Geyser.Labels in
  -- group_rows; 0.10+ stores mini-bar objects with a .container
  -- field. If we detect the old shape, hide the legacy labels
  -- and start fresh — otherwise the new code blows up trying to
  -- index `.container` on a Geyser.Label.
  if #FierymudRs.Guages.group_rows > 0
      and not FierymudRs.Guages.group_rows[1].container then
    for _, row in ipairs(FierymudRs.Guages.group_rows) do
      if row.hide then pcall(function() row:hide() end) end
    end
    FierymudRs.Guages.group_rows = {}
  end

  -- THREATS + NPCS panels live in `Mobs/Mobs.lua` — they consume
  -- `Room.Mobs` (per-prompt, room-scoped) and the previous
  -- Char.Aggro-driven stub. The Mobs subsystem owns its own
  -- containers at y=375..570 in this column; nothing to set up
  -- here.

  -- ALLIES section anchored to where the Mobs friendly panel
  -- ends. `Mobs.layout()` is the single source of truth (also
  -- read by Skills.lua); recomputed on each call so a live
  -- text_scale change reflows correctly.
  local mobs_bottom = (FierymudRs.Mobs and FierymudRs.Mobs.layout
    and FierymudRs.Mobs.layout().bottom_y) or 580
  FierymudRs.Guages.ally_header = FierymudRs.Guages.ally_header
    or make_section_header(FierymudRs.GUI.left_container,
        "AllyHeader", mobs_bottom, "ALLIES", "allies")
  FierymudRs.Guages.ally_header:hide()

  -- Ally container holds cross-profile vitals — only populated
  -- when the player runs multiple Mudlet profiles for a single
  -- account.
  FierymudRs.Guages.ally_container = FierymudRs.Guages.ally_container or Geyser.VBox:new({
    name = "Allies", x = 5, y = mobs_bottom + header_height() + 6,
    height = "100px", width = "-10px"
  }, FierymudRs.GUI.left_container)
  FierymudRs.Guages.allies = FierymudRs.Guages.allies or {}

  -- Room players strip — consumes gmcp.Room.Players (snapshot)
  -- + gmcp.Room.AddPlayer / Room.RemovePlayer (diffs). Lives in
  -- the bottom half of the right column's room_header strip,
  -- below the services chips (Mobs.lua owns the top half).
  -- Parented OUTSIDE chat_container so EMCO can never cover it —
  -- the old layout parented it inside chat_container, where
  -- EMCO normally hid it but a click sometimes flashed it
  -- visible on top of the chat tab bar, which read as a
  -- glitch.
  local hdr = FierymudRs.GUI.room_header
  if hdr then
    FierymudRs.Guages.room_players_label =
      FierymudRs.Guages.room_players_label or Geyser.Label:new({
        name = "room_players_label",
        x = 0, y = "50%", width = "100%", height = "50%",
        fontSize = FierymudRs.fontSize(9), fgColor = "white",
        message = [[<center><dim_grey>Here:</dim_grey> <dim>(no one else)</dim></center>]]
      }, hdr)
    pcall(function()
      -- 2px bottom border (slightly thicker than the Services
      -- strip's) gives a clear edge against the chat tab row
      -- directly below — without it, the strip's text reads as
      -- a chat-pane footer rather than a room-header element.
      FierymudRs.Guages.room_players_label:setStyleSheet([[
        background-color: rgba(20,28,40,235);
        color: #b8c4d2;
        border-bottom: 2px solid #3b5572;
        padding: 2px 6px;
      ]])
    end)
  end

  -- TARGET section header. Rides with the combat panel — shows
  -- when combat starts, hides when it clears. An always-visible
  -- header looked like orphan chrome when the panel below was
  -- empty.
  FierymudRs.Guages.combat_header = FierymudRs.Guages.combat_header
    or make_section_header(FierymudRs.GUI.left_container,
        "CombatHeader", "-216px", "TARGET", "target")
  FierymudRs.Guages.combat_header:hide()

  -- Combat container — your current fight. Bumped from 120 to
  -- 200px so the opponent HP bar fits without being clipped at
  -- the bottom of the panel. Anchored to the bottom because
  -- this is the most-glanced area: moment-to-moment focus during
  -- combat. Hidden when not engaged (the TARGET header above
  -- still tells the player where to look when a fight starts).
  FierymudRs.Guages.combat_container = FierymudRs.Guages.combat_container or Geyser.Container:new({
    name = 'Combat', x = 0, y = "-200px", width = "-1%", height = "200px"
  }, FierymudRs.GUI.left_container)
  FierymudRs.Guages.combat_container:hide()

  if not FierymudRs.Guages.CombatGuages then
    createCombatGuage()
  end
end

-- Vital-color helpers. Same band ranges score uses on the server
-- so the panel reads consistent across client and server views.
local function vital_color(cur, max)
  if not cur or not max or max <= 0 then return "white" end
  local pct = cur / max
  if pct >= 0.75 then return "green"
  elseif pct >= 0.40 then return "yellow"
  elseif pct >= 0.15 then return "orange"
  else return "red" end
end

-- Compact per-member row: HP bar carries the name AS its overlay
-- text (taking advantage of the gauge's setValue text param), a
-- thin Move bar sits directly below. No separate header label —
-- name lives on top of the HP fill, MMO-raid-frame convention.
-- Total 28px per member; 6 members = 168px (was 240). Gauges
-- reuse the main vitals stylesheets so language stays consistent.
local group_member_height = 28
local group_hp_height = 18
local group_mv_height = 8

local function createGroupMiniBar(parent, idx)
  local row = Geyser.VBox:new({
    name = "group_member_" .. idx,
    width = "-5px",
    height = group_member_height,
    v_policy = Geyser.Fixed,
  }, parent)

  local hp = Geyser.Gauge:new({
    name = "group_hp_" .. idx,
    width = "-5px",
    height = group_hp_height .. "px",
    v_policy = Geyser.Fixed,
  }, row)
  hp.front:setStyleSheet(stylesheets.hp_front)
  hp.back:setStyleSheet(stylesheets.hp_back)

  local move = Geyser.Gauge:new({
    name = "group_mv_" .. idx,
    width = "-5px",
    height = group_mv_height .. "px",
    v_policy = Geyser.Fixed,
  }, row)
  move.front:setStyleSheet(stylesheets.move_front)
  move.back:setStyleSheet(stylesheets.move_back)

  return { container = row, hp = hp, move = move }
end

-- Class abbreviation → tint color. Roles read at a glance:
-- physical melee (warrior/rogue) red, healers (priest/druid)
-- green, casters (sorc/mage) purple, others neutral grey.
-- Mudlet cecho parses `<b:color>` as `fg="b"` + `bg=color`, not
-- "bold color" — using the b: prefix gave us colored background
-- chips with invisible foreground text. Hex literals are the
-- unambiguous way to spell bright variants.
local function class_color(class)
  local c = tostring(class or ""):lower():sub(1, 3)
  if c == "war" or c == "rog" or c == "ber" or c == "ant" then return "<c_255_80_80>" end
  if c == "pri" or c == "dru" or c == "sha" or c == "mon" then return "<c_80_255_80>" end
  if c == "sor" or c == "mag" or c == "wiz" or c == "ill" or c == "nec" then return "<c_208_144_255>" end
  if c == "pal" or c == "cle" then return "<c_255_215_0>" end
  if c == "ran" then return "<c_64_160_64>" end
  return "<white>"
end

-- Push current values into a mini-bar from one members[] entry.
-- The HP bar's overlay text carries name + level + class + a
-- here/away marker so each row reads at a glance: "● Mejna L101
-- Pri  50/150". Class abbreviation tinted by role color.
local function updateGroupMiniBar(bar, m)
  local hp = (m.stats and m.stats.hp) or 0
  local max_hp = (m.stats and m.stats.max_hp) or 1
  local mv = (m.stats and m.stats.mv) or 0
  local max_mv = (m.stats and m.stats.max_mv) or 1
  local marker = m.with_leader and "<green>●<reset>" or "<dim_grey>○<reset>"
  local class = tostring(m.class or ""):sub(1, 3)
  local class_tint = class_color(class)
  local label = string.format(
    "%s <yellow>%s<reset> %sL%s %s<reset> <dim_grey>%d/%d<reset>",
    marker, tostring(m.name or "?"), class_tint,
    tostring(m.level or "?"), class, hp, max_hp
  )
  bar.hp:setValue(getCappedVal(hp, max_hp), max_hp,
    "<center>" .. label .. "</center>")
  -- Move bar carries no text — at 8px there's no room for it
  -- and the player rarely needs an ally's exact stamina.
  bar.move:setValue(getCappedVal(mv, max_mv), max_mv, "")
end

-- Player action menu — click on the "Here:" strip to surface a
-- contextual action list per player in the main console. Each
-- action renders as an `<echoLink>` so the user clicks once on
-- the verb to fire the command. Tell uses `printCmdLine` to
-- pre-fill the input bar instead of sending blind — the player
-- supplies the message before pressing enter.
local function openPlayerActions()
  local players = gmcp and gmcp.Room and gmcp.Room.Players
  if type(players) ~= "table" or #players == 0 then
    cecho("\n<dim_grey>No other players in the room.<reset>\n")
    return
  end
  cecho("\n<dim_grey>──── Players here ────<reset>\n")
  for _, p in ipairs(players) do
    if p and p.name then
      local n = p.name
      cecho(string.format("  <cyan>%s<reset>  ", n))
      -- `cechoLink(text, lua_code, tooltip, useCurrentFormat)`
      -- — text rendered with cecho color parsing; clicking fires
      -- the lua_code string (run via `loadstring`-equivalent
      -- inside Mudlet). We use `send()` for one-shot commands
      -- and `printCmdLine` for the tell-prefill case so the
      -- player can compose the message before pressing enter.
      cechoLink("<green>[whois]<reset> ",
        [[send("whois ]] .. n .. [[")]],
        "Look up " .. n, true)
      cechoLink("<yellow>[consider]<reset> ",
        [[send("consider ]] .. n .. [[")]],
        "Consider attacking " .. n, true)
      cechoLink("<cyan>[tell]<reset> ",
        [[printCmdLine("tell ]] .. n .. [[ ")]],
        "Tell " .. n, true)
      cechoLink("<magenta>[group]<reset> ",
        [[send("group ]] .. n .. [[")]],
        "Invite " .. n .. " to group", true)
      cechoLink("<white>[look]<reset>",
        [[send("look ]] .. n .. [[")]],
        "Look at " .. n, true)
      cecho("\n")
    end
  end
  cecho("<dim_grey>───────────────────────<reset>\n")
end

-- Public: refresh the "who's here" strip from gmcp.Room.Players
-- snapshots and the AddPlayer / RemovePlayer diffs. The strip is
-- a single Geyser.Label; clicking anywhere on it opens the
-- per-player action menu (see openPlayerActions above) in the
-- main console. Single-shot label click vs per-name chips is a
-- deliberate trade-off — at this column width, per-name labels
-- would either be too small to read or overflow.
function FierymudRs.Guages:updateRoomPlayers()
  local label = FierymudRs.Guages.room_players_label
  if not label then return end
  local players = gmcp and gmcp.Room and gmcp.Room.Players
  -- Bind the click handler exactly once per *label instance*.
  -- Marker lives on the label itself (not on FierymudRs.Guages)
  -- because hot-reload destroys+recreates the label while the
  -- module table survives — a module-level flag would stay true
  -- through the reload, and the new label would silently never
  -- get a callback bound (root cause of the players-strip click
  -- regression observed via the click-harness on 2026-05-14).
  if not label._click_bound then
    pcall(function() label:setClickCallback(openPlayerActions) end)
    label._click_bound = true
  end
  if type(players) ~= "table" or #players == 0 then
    -- Keep the "Here:" label visible even when the room is empty
    -- — without it, the bare "(no one else here)" line reads as
    -- a footer of the chat tab strip directly below, with no
    -- indication that it's the room-players strip.
    label:cecho([[<center><dim_grey>Here:</dim_grey> <dim>(no one else)</dim></center>]])
    return
  end
  local names = {}
  for _, p in ipairs(players) do
    if p and p.name then
      names[#names + 1] = "<cyan>" .. p.name .. "<reset>"
    end
  end
  label:cecho(string.format(
    "<center><dim>Here:</dim> %s <dim_grey>(click for actions)</dim_grey></center>",
    table.concat(names, ", ")
  ))
end

-- Public: refresh the group panel from gmcp.Group. Called from
-- the Vitals onPrompt path. Solo case (empty {} frame, or
-- gmcp.Group nil) hides the container; grouped case shows it
-- with one row per member. Old rows beyond the current count
-- are hidden so transient party-size shrinks render cleanly.
function FierymudRs.Guages:updateGroup()
  local container = FierymudRs.Guages.group_container
  local header = FierymudRs.Guages.group_header
  if not container then return end
  local g = gmcp and gmcp.Group
  -- IRE convention: empty Group frame = solo (no members table
  -- or count == 0). Hide and bail.
  if not g or type(g) ~= "table" or not g.members or g.count == 0 then
    container:hide()
    if header then header:hide() end
    return
  end

  -- Update / create per-member mini-bars. Reuse existing rows
  -- so Mudlet doesn't churn the layout on every prompt — gauges
  -- just take new values and re-render in place.
  local count = #g.members
  for i = 1, count do
    local row = FierymudRs.Guages.group_rows[i]
    if not row then
      row = createGroupMiniBar(container, i)
      FierymudRs.Guages.group_rows[i] = row
    end
    row.container:show()
    updateGroupMiniBar(row, g.members[i])
  end
  -- Hide stale rows from a previously larger party so the panel
  -- shrinks cleanly when someone leaves the group.
  for i = count + 1, #FierymudRs.Guages.group_rows do
    FierymudRs.Guages.group_rows[i].container:hide()
  end
  container:show()
  if header then header:show() end
end

FierymudRs._subsystems = FierymudRs._subsystems or {}
FierymudRs._subsystems.Guages = {
  name = "Guages",
  setup = function() FierymudRs.Guages:setup() end,
  isReady = function()
    return FierymudRs.Guages ~= nil
       and FierymudRs.Guages.CharacterGuage ~= nil
  end,
  -- Top-level cleanup hides/unregisters left_container; gauges
  -- inside it are reached via the recursive subtree walk. Nil
  -- the cached refs so `isReady` flips false and the next setup
  -- builds fresh widgets under the new container.
  teardown = function()
    if not FierymudRs.Guages then return end
    FierymudRs.Guages.CharacterGuage = nil
    FierymudRs.Guages.character_container = nil
    FierymudRs.Guages.ally_container = nil
    FierymudRs.Guages.ally_header = nil
    FierymudRs.Guages.allies = nil
    FierymudRs.Guages.group_container = nil
    FierymudRs.Guages.group_header = nil
    FierymudRs.Guages.group_rows = nil
    FierymudRs.Guages.room_players_label = nil
    FierymudRs.Guages.combat_container = nil
    FierymudRs.Guages.combat_header = nil
    FierymudRs.Guages.CombatGuages = nil
  end,
}
