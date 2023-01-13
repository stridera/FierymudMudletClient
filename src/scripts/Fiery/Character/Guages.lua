Fierymud = Fierymud or {}
Fierymud.Guages = Fierymud.Guages or {}

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
  print("New Profile " .. name)

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
  guage['header']:echo("<center>" .. character.name .. " (" .. level .. ") " .. character.class:upper() .. "</center>")
  guage["hp"]:setValue(getCappedVal(vitals.hp, vitals.hp_max), tonumber(vitals.hp_max),
    "<center>HP: " .. tonumber(vitals.hp) .. " / " .. tonumber(vitals.hp_max) .. "</center>")
  guage["move"]:setValue(getCappedVal(vitals.move, vitals.move_max), tonumber(vitals.move_max),
    "<center>Move: " .. tonumber(vitals.move) .. " / " .. tonumber(vitals.move_max) .. "</center>")
  if level > 99 then
    guage["xp"]:setValue(1, 1, "<center>GOD</center>")
  elseif level == 99 and tonumber(character.exp_percent) == 100 then
    guage["xp"]:setValue(1, 1, "<center>**</center>")
  else
    guage["xp"]:setValue(tonumber(character.exp_percent), 100,
      "<center>XP: " .. tonumber(character.exp_percent) .. "%</center>")
  end
  guage["container"]:show()
end

-- Combat
local function createCombatGuage()
  local container = Geyser.VBox:new({
    name = "Combat", width = "-5px", height = container_height,
  }, Fierymud.Guages.combat_container)
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

  Fierymud.Guages.CombatGuages = {
    container = container,
    tank_header = tank_header,
    tank_hpbar = tank_hpbar,
    opp_header = opp_header,
    opp_hpbar = opp_hpbar,
  }
end

-- Public Functions

function Fierymud.Guages:updateVitals(vitals, profile)
  if profile then
    local guage = Fierymud.Guages.allies[profile] or createVitalsGuage(Fierymud.Guages.ally_container, profile)
    print("Updating profile " .. profile)
    updateVitalsGuage(guage, vitals)
    Fierymud.Guages.allies[profile] = guage
  else
    updateVitalsGuage(Fierymud.Guages.character_container, vitals)
  end

end

function Fierymud.Guages:removeGuage(profile)
  local guage = Fierymud.Guages.allies[profile]
  print("Removing profile " .. profile)
  if guage then
    print("Removing guage")
    guage.container:hide()
    Fierymud.Guages.ally_container:remove(guage.container)
    Fierymud.Guages.allies[profile] = nil
  end
end

function Fierymud.Guages:updateCombat(combat)
  local guage = Fierymud.Guages.CombatGuages
  guage.tank_header:echo("<center>Tank: " .. combat.tank.name .. "</center>")
  guage["tank_hpbar"]:setValue(getCappedVal(combat.tank.hp, combat.tank.max_hp), tonumber(combat.tank.max_hp),
    "<center>HP: " .. tonumber(combat.tank.hp) .. " / " .. tonumber(combat.tank.max_hp) .. "</center>")

  guage.opp_header:echo("<center>Opponent: " .. combat.opponent.name .. "</center>")
  guage["opp_hpbar"]:setValue(tonumber(combat.opponent.hp_percent), 100,
    "<center>HP: " .. tonumber(combat.opponent.hp_percent) .. "%</center>")
  guage.container:show()
end

function Fierymud.Guages:clearCombat()
  Fierymud.Guages.combat_container:hide()
end

function Fierymud.Guages:setup()
  print("SETUP")
  -- Character Vital Window
  Fierymud.Guages.character_container = Fierymud.Guages.character_container or Geyser.Container:new({
    name = "Characters", x = 0, y = 0, height = container_height, width = "-5px"
  }, Fierymud.GUI.left_container)
  Fierymud.Guages.character_container = createVitalsGuage(Fierymud.Guages.character_container, "character")
  Fierymud.Guages:updateVitals(Fierymud.Character)

  Fierymud.Guages.ally_container = Fierymud.Guages.ally_container or Geyser.VBox:new({
    name = "Allies", x = 10, y = container_height + 10, height = "80%", width = -10
  }, Fierymud.GUI.left_container)
  Fierymud.Guages.allies = {}

  Fierymud.Guages.combat_container = Fierymud.Guages.combat_container or Geyser.Container:new({
    name = 'Combat', x = 0, y = "-120px", width = '-1%', height = "120px"
  }, Fierymud.GUI.left_container)
  createCombatGuage()
end
