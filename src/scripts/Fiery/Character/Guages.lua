Fierymud = Fierymud or {}
Fierymud.Guages = Fierymud.Guages or {}

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


local function createVitalsGuage(name, vitals)
  local window_width, window_height = getMainWindowSize()
  local y_offset = 0
  local x_offset = 0
  local container_height = 100
  local console_width = Fierymud.Config["left_container_width"]
  local bar_width = 200
  local bar_height = 20
  local bar_spacing = 3

  Fierymud.Guages.vitals = Fierymud.Guages.vitals or {}
  Fierymud.Guages.character_profiles = Fierymud.Guages.character_profiles or {}
  
  Fierymud.Guages.vitals_container = Fierymud.Guages.vitals_container or Geyser.Container:new({
    name = 'vitals_container',
    x = 0, y = 0,
    width = '100%', height = (window_height - 120) .. "px"
  }, Fierymud.GUI.left_container)

  if not table.contains(Fierymud.Guages.character_profiles, name) then
    local level = table.size(Fierymud.Guages.vitals)
      y_offset=container_height * level

    local container = Geyser.Container:new({
      name = "left_container_top",
      width = "100%", height=container_height,
    }, Fierymud.Guages.vitals_container)

    -- Header
    local header = Geyser.Label:new({
      name=name.."header",
      x=x_offset .. "px",
      y= y_offset .. "px",
      width=bar_width .. "px",
      height=bar_height .. "px",
      message="<center>"..vitals["name"].." ("..vitals["level"]..")</center>"
    }, container)

    -- HP BAR
    y_offset = y_offset + bar_height + bar_spacing
    local hpbar = Geyser.Gauge:new({
      name=name.."hpbar",
      x=x_offset .. "px",
      y=y_offset .. "px",
      width=bar_width .. "px",
      height=bar_height .. "px",
    }, container)
    hpbar.front:setStyleSheet(stylesheets.hp_front)
    hpbar.back:setStyleSheet(stylesheets.hp_back)

    -- Movement Bar
    y_offset = y_offset + bar_height + bar_spacing
    local movebar = Geyser.Gauge:new({
      name=name.."movebar",
      x=x_offset .. "px",
      y=y_offset .. "px",
      width=bar_width .. "px",
      height=bar_height .. "px",
    }, container)
    movebar.front:setStyleSheet(stylesheets.move_front)
    movebar.back:setStyleSheet(stylesheets.move_back)

    -- XP Bar
    y_offset = y_offset + bar_height + bar_spacing
    local xpbar = Geyser.Gauge:new({
      name=name.."xpbar",
      x=x_offset .. "px",
      y=y_offset .. "px",
      width=bar_width .. "px",
      height=bar_height .. "px",
    }, container)
    xpbar.front:setStyleSheet(stylesheets.xp_front)
    xpbar.back:setStyleSheet(stylesheets.xp_back)

    -- Guage
    Fierymud.Guages.vitals[name] = {
      container = container,
      header = header,
      hp = hpbar,
      move = movebar,
      xp = xpbar
    }

    y_offset=y_offset + 20
    table.insert(Fierymud.Guages.character_profiles, name)
  end
end

local function createCombatGuage()
  local window_width, window_height = getMainWindowSize()
  local console_width = Fierymud.Config["left_container_width"]
  local bar_width = Fierymud.Config["left_container_width"]
  local y_offset = 0
  local bar_height = 20
  local bar_spacing = 3

  Fierymud.Guages.combat_container = Fierymud.Guages.combat_container or Geyser.Container:new({
    name = 'combat_container',
    x = 0, y = (window_height - 120).."px",
    width = '100%', height = "120px"
  }, Fierymud.GUI.left_container)

  if not Fierymud.Guages.CombatGuages then
    -- Opponent Header
    local tank_header = Geyser.Label:new({
      name="tank_header",
      x=0,
      y=0,
      width=bar_width .. "px",
      height=bar_height .. "px",
      message="<center>TANK:</center>"
    }, Fierymud.Guages.combat_container)

    -- Tank HP BAR
    y_offset = bar_height + bar_spacing
    local tank_hpbar = Geyser.Gauge:new({
      name="tank_hpbar",
      x="0px",
      y=(bar_height + bar_spacing) .. "px",
      width=bar_width .. "px",
      height=bar_height .. "px",
    }, Fierymud.Guages.combat_container)
    tank_hpbar.front:setStyleSheet(stylesheets.hp_front)
    tank_hpbar.back:setStyleSheet(stylesheets.hp_back)

    -- Opponent Header
    y_offset = y_offset + bar_height + bar_spacing + bar_spacing
    local opp_header = Geyser.Label:new({
      name="opp_header",
      x="0px",
      y=y_offset .. "px",
      width=bar_width .. "px",
      height=bar_height .. "px",
      message="<center>TANK:</center>"
    }, Fierymud.Guages.combat_container)

    -- Tank HP BAR
    y_offset = y_offset + bar_height + bar_spacing
    local opp_hpbar = Geyser.Gauge:new({
      name="opp_hpbar",
      x="0px",
      y=y_offset .. "px",
      width=bar_width .. "px",
      height=bar_height .. "px",
    }, Fierymud.Guages.combat_container)
    opp_hpbar.front:setStyleSheet(stylesheets.hp_front)
    opp_hpbar.back:setStyleSheet(stylesheets.hp_back)


    Fierymud.Guages.CombatGuages = {
      tank_header = tank_header,
      tank_hpbar = tank_hpbar,
      opp_header = opp_header,
      opp_hpbar = opp_hpbar,
    }
  end
  Fierymud.Guages.combat_container:show()
  return Fierymud.Guages.CombatGuages
end

local function getCappedVal(val, max)
  local val_num = tonumber(val)
  local max_num = tonumber(max)
  return math.min(val_num, max_num)
end

-- Public Functions

function Fierymud.Guages:updateVitals(name, character)
  createVitalsGuage(name, character)
  local guage = Fierymud.Guages.vitals[name]
  local vitals = character.Vitals
  local level = tonumber(character.level)
  if guage then
    guage['header']:echo("<center>"..character.name.." ("..level..") "..character.class:upper().."</center>")
    guage["hp"]:setValue( getCappedVal( vitals.hp, vitals.hp_max ), tonumber( vitals.hp_max ), "<center>HP: " .. tonumber( vitals.hp ) .. " / " .. tonumber( vitals.hp_max ) .. "</center>")
    guage["move"]:setValue( getCappedVal( vitals.move, vitals.move_max ), tonumber( vitals.move_max ), "<center>Move: " .. tonumber( vitals.move ) .. " / " .. tonumber( vitals.move_max ) .. "</center>" )
    if level > 99 then
      guage["xp"]:setValue( 1, 1, "<center>GOD</center>" )
    elseif level == 99 and tonumber(character.exp_percent) == 100 then
      guage["xp"]:setValue( 1, 1, "<center>**</center>" )
    else
      guage["xp"]:setValue( tonumber( character.exp_percent ), 100, "<center>XP: " .. tonumber( character.exp_percent ) .. "%</center>" )
    end
  end
end

function Fierymud.Guages:updateCombat(combat)
  local guage = createCombatGuage()
  if guage then
    guage['tank_header']:echo("<center>Tank: "..combat.tank.name.."</center>")
    guage["tank_hpbar"]:setValue( getCappedVal( combat.tank.hp, combat.tank.max_hp ), tonumber( combat.tank.max_hp ), "<center>HP: " .. tonumber( combat.tank.hp ) .. " / " .. tonumber( combat.tank.max_hp ) .. "</center>")

    guage['opp_header']:echo("<center>Opponent: "..combat.opponent.name.."</center>")
    guage["opp_hpbar"]:setValue( tonumber( combat.opponent.hp_percent ), 100, "<center>HP: " .. tonumber( combat.opponent.hp_percent ) .. "%</center>")
  end
end

function Fierymud.Guages:clearCombat()
  Fierymud.Guages.combat_container:hide()
end