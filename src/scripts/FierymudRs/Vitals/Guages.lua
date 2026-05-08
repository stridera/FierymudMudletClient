FierymudRs = FierymudRs or {}
FierymudRs.Guages = FierymudRs.Guages or {}

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

-- Combat
local function createCombatGuage()
  local container = Geyser.VBox:new({
    name = "Combat", width = "-5px", height = container_height,
  }, FierymudRs.Guages.combat_container)
  container:hide()

  -- Opponent Header
  local tank_header = Geyser.Label:new({
    name = "tank_header", width = "-5px", height = bar_height .. "px",
    message = "<center>TANK:</center>"
  }, container)

  -- Tank HP BAR
  local tank_hpbar = Geyser.Gauge:new({
    name = "tank_hpbar", width = "-5px", height = bar_height .. "px",
  }, container)
  tank_hpbar.front:setStyleSheet(stylesheets.hp_front)
  tank_hpbar.back:setStyleSheet(stylesheets.hp_back)

  -- Opponent Header
  local opp_header = Geyser.Label:new({
    name = "opp_header", width = "-5px", height = bar_height .. "px",
    message = "<center>TANK:</center>"
  }, container)

  -- Tank HP BAR
  local opp_hpbar = Geyser.Gauge:new({
    name = "opp_hpbar", width = "-5px", height = bar_height .. "px",
  }, container)
  opp_hpbar.front:setStyleSheet(stylesheets.hp_front)
  opp_hpbar.back:setStyleSheet(stylesheets.hp_back)

  FierymudRs.Guages.CombatGuages = {
    container = container,
    tank_header = tank_header,
    tank_hpbar = tank_hpbar,
    opp_header = opp_header,
    opp_hpbar = opp_hpbar,
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

  -- Update tank info
  local tank_name = combat.tank.name or "Unknown"
  local tank_hp = tonumber(combat.tank.hp) or 0
  local tank_max_hp = tonumber(combat.tank.max_hp) or 1
  guage.tank_header:echo("<center>Tank: " .. tank_name .. "</center>")
  guage.tank_hpbar:setValue(getCappedVal(tank_hp, tank_max_hp), tank_max_hp,
    "<center>HP: " .. tank_hp .. " / " .. tank_max_hp .. "</center>")

  -- Update opponent info
  local opp_name = combat.opponent.name or "Unknown"
  local opp_hp_percent = tonumber(combat.opponent.hp_percent) or 0
  guage.opp_header:echo("<center>Opponent: " .. opp_name .. "</center>")
  guage.opp_hpbar:setValue(opp_hp_percent, 100,
    "<center>HP: " .. opp_hp_percent .. "%</center>")

  guage.container:show()
end

function FierymudRs.Guages:clearCombat()
  if FierymudRs.Guages.CombatGuages and FierymudRs.Guages.CombatGuages.container then
    FierymudRs.Guages.CombatGuages.container:hide()
  end
end

function FierymudRs.Guages:setup()
  -- Character Vital Window
  local char_container = FierymudRs.Guages.character_container or Geyser.Container:new({
    name = "Characters", x = 0, y = 0, height = container_height, width = "-5px"
  }, FierymudRs.GUI.left_container)
  FierymudRs.Guages.character_container = char_container

  FierymudRs.Guages.CharacterGuage = FierymudRs.Guages.CharacterGuage or createVitalsGuage(char_container, "character")
  FierymudRs.Guages:updateVitals(FierymudRs.Character)

  FierymudRs.Guages.ally_container = FierymudRs.Guages.ally_container or Geyser.VBox:new({
    name = "Allies", x = 10, y = container_height + 10, height = "80%", width = -10
  }, FierymudRs.GUI.left_container)
  FierymudRs.Guages.allies = FierymudRs.Guages.allies or {}

  -- Group panel — consumes gmcp.Group (server emits {leader,
  -- members:[{name, with_leader, level, class, stats:{hp, maxhp,
  -- mv, maxmv}}]} on every prompt). Hidden when solo (server
  -- emits an empty `{}` frame in that case). Each member row is
  -- a single-line label showing name, level/class, current HP/MV
  -- ratio, and a marker for "in this room".
  FierymudRs.Guages.group_container = FierymudRs.Guages.group_container or Geyser.VBox:new({
    name = "Group", x = 10, y = container_height + 220, height = "auto", width = -10
  }, FierymudRs.GUI.left_container)
  FierymudRs.Guages.group_container:hide()
  FierymudRs.Guages.group_rows = FierymudRs.Guages.group_rows or {}

  FierymudRs.Guages.combat_container = FierymudRs.Guages.combat_container or Geyser.Container:new({
    name = 'Combat', x = 0, y = "-120px", width = '-1%', height = "120px"
  }, FierymudRs.GUI.left_container)

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

-- Render one group-member line. Format:
--   [here] <yellow>Strider<reset>  L104 Avatar  <green>150/200<reset>hp 80/100mv
-- The leading marker is "here" (in same room) or "away".
local function render_group_member_line(m, viewer_in_same_room)
  local hp = (m.stats and m.stats.hp) or 0
  local maxhp = (m.stats and m.stats.maxhp) or 1
  local mv = (m.stats and m.stats.mv) or 0
  local maxmv = (m.stats and m.stats.maxmv) or 1
  local hpcol = vital_color(hp, maxhp)
  local mvcol = vital_color(mv, maxmv)
  local marker = m.with_leader and "<green>·<reset>" or "<grey>·<reset>"
  return string.format(
    "%s <yellow>%s<reset> <grey>L%s %s<reset> <%s>%d/%d<reset>hp %d/%dmv",
    marker, tostring(m.name or "?"), tostring(m.level or "?"),
    tostring(m.class or ""):sub(1, 8),
    hpcol, hp, maxhp, mv, maxmv
  )
end

-- Public: refresh the group panel from gmcp.Group. Called from
-- the Vitals onPrompt path. Solo case (empty {} frame, or
-- gmcp.Group nil) hides the container; grouped case shows it
-- with one row per member. Old rows beyond the current count
-- are hidden so transient party-size shrinks render cleanly.
function FierymudRs.Guages:updateGroup()
  local container = FierymudRs.Guages.group_container
  if not container then return end
  local g = gmcp and gmcp.Group
  -- IRE convention: empty Group frame = solo (no members table
  -- or count == 0). Hide and bail.
  if not g or type(g) ~= "table" or not g.members or g.count == 0 then
    container:hide()
    return
  end

  -- Update / create rows. Re-using existing Geyser.Label objects
  -- where we can keeps Mudlet from churning the layout on every
  -- prompt; only the message text gets re-echoed.
  local count = #g.members
  for i = 1, count do
    local row = FierymudRs.Guages.group_rows[i]
    if not row then
      row = Geyser.Label:new({
        name = "group_row_" .. i, height = 16, fontSize = 9, fgColor = "white"
      }, container)
      FierymudRs.Guages.group_rows[i] = row
    end
    row:show()
    row:cecho(render_group_member_line(g.members[i], true))
  end
  -- Hide stale rows from a previously larger party so the panel
  -- shrinks cleanly when someone leaves the group.
  for i = count + 1, #FierymudRs.Guages.group_rows do
    FierymudRs.Guages.group_rows[i]:hide()
  end
  container:show()
end
