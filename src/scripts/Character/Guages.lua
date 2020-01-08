Fierymud.Guages = Fierymud.Guages or {}

local function createVitalsGuage(name, vitals)
  local y_offset = 0
  local x_offset = 0
  local console_width = 200
  local window_width, window_height = getMainWindowSize()
  local bar_width = 200
  local bar_height = 20
  local bar_spacing = 3
  local container_height = 100
  
  Fierymud.Guages.vitals = Fierymud.Guages.vitals or {}
  Fierymud.Guages.character_profiles = Fierymud.Guages.character_profiles or {}

  Fierymud.Guages.vitals_container = Fierymud.Guages.vitals_container or Geyser.Container:new({
    name = 'vitals_container',
    x = 10, y = 10,
    width = console_width, height = '100%'
  })

  if not table.contains(Fierymud.Guages.character_profiles, name) then
    setBorderLeft(235)

    local level = table.size(Fierymud.Guages.vitals)
      y_offset=container_height * level

    local container = Geyser.Container:new({
      name = "left_container_top",
      width = "100%", height=container_height,
    }, Fierymud.Guages.vitals_container)

    -- Header
    local header = Geyser.Label:new({
      name=name.."header",
      x=( console_width - bar_width - x_offset) .. "px",
      y= y_offset .. "px",
      width=bar_width .. "px",
      height=bar_height .. "px",
      message="<center>"..vitals["name"].." ("..vitals["level"]..")</center>"
    }, container)

    -- HP BAR
    y_offset = y_offset + bar_height + bar_spacing
    local hpbar = Geyser.Gauge:new({
      name=name.."hpbar",
      x=( console_width - bar_width - x_offset) .. "px",
      y=y_offset .. "px",
      width=bar_width .. "px",
      height=bar_height .. "px",
    }, container)
    hpbar.front:setStyleSheet([[
      background-color: QLinearGradient( x1: 0, y1: 0, x2: 0, y2: 1, stop: 0 #a20e2c, stop: 0.5 #930f27, stop: 0.51 #8a0a1d, stop: 1 #6f0f14);
      border-top: 1px black solid;
      border-left: 1px black solid;
      border-bottom: 1px black solid;
      border-radius: 7;
      padding: 3px;
    ]])
    hpbar.back:setStyleSheet([[
      background-color: QLinearGradient( x1: 0, y1: 0, x2: 0, y2: 1, stop: 0 #793744, stop: 0.5 #6f333e, stop: 0.51 #672d36, stop: 1 #542a2c);
      border-width: 1px;
      border-color: black;
      border-style: solid;
      border-radius: 7;
      padding: 3px;
    ]])

    -- Movement Bar
    y_offset = y_offset + bar_height + bar_spacing
    local movebar = Geyser.Gauge:new({
      name=name.."movebar",
      x=( console_width - bar_width - x_offset) .. "px",
      y=y_offset .. "px",
      width=bar_width .. "px",
      height=bar_height .. "px",
    }, container)
    movebar.front:setStyleSheet([[
      background-color: QLinearGradient( x1: 0, y1: 0, x2: 0, y2: 1, stop: 0 #10ae2b, stop: 0.5 #109e2a, stop: 0.51 #0b9329, stop: 1 #117731);
      border-top: 1px black solid;
      border-left: 1px black solid;
      border-bottom: 1px black solid;
      border-radius: 7;
      padding: 3px;
    ]])
    movebar.back:setStyleSheet([[
      background-color: QLinearGradient( x1: 0, y1: 0, x2: 0, y2: 1, stop: 0 #377942, stop: 0.5 #336f3e, stop: 0.51 #2d673a, stop: 1 #2a5437);
      border-width: 1px;
      border-color: black;
      border-style: solid;
      border-radius: 7;
      padding: 3px;
    ]])

    -- XP Bar
    y_offset = y_offset + bar_height + bar_spacing
    local xpbar = Geyser.Gauge:new({
      name=name.."xpbar",
      x=( console_width - bar_width - x_offset) .. "px",
      y=y_offset .. "px",
      width=bar_width .. "px",
      height=bar_height .. "px",
    }, container)
    xpbar.front:setStyleSheet([[
      background-color: QLinearGradient( x1: 0, y1: 0, x2: 0, y2: 1, stop: 0 #8d209e, stop: 0.5 #831e90, stop: 0.51 #7c1886, stop: 1 #6d1b6c);
      border-top: 1px black solid;
      border-left: 1px black solid;
      border-bottom: 1px black solid;
      border-radius: 7;
      padding: 3px;
    ]])
    xpbar.back:setStyleSheet([[
      background-color: QLinearGradient( x1: 0, y1: 0, x2: 0, y2: 1, stop: 0 #8d209e, stop: 0.5 #831e90, stop: 0.51 #7c1886, stop: 1 #6d1b6c);
      border-width: 1px;
      border-color: black;
      border-style: solid;
      border-radius: 7;
      padding: 3px;
    ]])

        -- Guage
    Fierymud.Guages.vitals[name] = {
      container = container,
      header = header,
      hp = hpbar,
      move = movebar,
      xp = xpbar
    }

    y=y_offset + 20
    table.insert(Fierymud.Guages.character_profiles, name)
  end
end

function Fierymud.Guages:updateVitals(name, character)
  createVitalsGuage(name, character)
  local guage = Fierymud.Guages.vitals[name]
  local vitals = character.Vitals
  local level = tonumber(character.level)
  if guage then
    guage['header']:echo("<center>"..character.name.." ("..level..") "..character.class:upper().."</center>")
    guage["hp"]:setValue( tonumber( vitals.hp ), tonumber( vitals.hp_max ), "<center>HP: " .. tonumber( vitals.hp ) .. " / " .. tonumber( vitals.hp_max ) .. "</center>")
    guage["move"]:setValue( tonumber( vitals.move ), tonumber( vitals.move_max ), "<center>Move: " .. tonumber( vitals.move ) .. " / " .. tonumber( vitals.move_max ) .. "</center>" )
    if level > 99 then
      guage["xp"]:setValue( 1, 1, "<center>GOD</center>" )
    elseif level == 99 and tonumber(character.exp_percent) == 100 then
      guage["xp"]:setValue( 1, 1, "<center>**</center>" )
    else
      guage["xp"]:setValue( tonumber( character.exp_percent ), 100, "<center>XP: " .. tonumber( character.exp_percent ) .. "%</center>" )
    end
  end
end