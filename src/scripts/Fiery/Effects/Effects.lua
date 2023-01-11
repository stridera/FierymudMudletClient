Fierymud.Effects = Fierymud.Effects or {}
Fierymud.Effects.Active = Fierymud.Effects.Active or {}
local profilePath = getMudletHomeDir():gsub("\\", "/")

local function add_effect(name, duration)
    local effect_type = Fierymud.Config.spell_effect_type
    local effects_window = Fierymud.GUI.effects_window

    if not effects_window then return end

    local effect = Geyser.VBox:new({
        name = name,
        h_policy = Geyser.Fixed,
        width = "68px", height = "80px",
    }, effects_window)


    path = profilePath .. "/FierymudOfficial/" .. name .. ".png"
    if effect_type == "icon" and io.exists(path) then
        local icon = Geyser.Label:new({
            name = name .. "_icon",
            x = 0, y = 0,
            width = "64px", height = "64px",
            fgColor = "white",
            fontSize = 12,
            message = name,
        }, effect)
        setBackgroundImage(name .. "_icon", path)
        icon:setToolTip(name)
    else
        local label = Geyser.Label:new({
            name = name .. "_label",
            x = 0, y = 0,
            width = "64px", height = "64px",
            fgColor = "white",
            fontSize = 12,
            message = [[<center>]] .. name .. [[</center>]],
        }, effect)
    end
    local duration_label = Geyser.Label:new({
        name = name .. "_duration",
        x = 0, y = 0,
        width = "64px", height = "16px",
        fgColor = "white",
        fontSize = 12,
        message = [[<center>]] .. math.ceil(duration / 60) .. [[</center>]],
    }, effect)


    Fierymud.Effects.Active[name] = {
        container = effect,
        duration = duration,
        duration_label = duration_label,
    }
end

local function updateEffectsWindow()
    if Fierymud.Config.disable_spell_effects then return end

    local effects_window = Fierymud.GUI.effects_window
    for _, effect in pairs(Fierymud.Effects.Active) do
        effect.duration = effect.duration - 1
        if effect.duration < 0 then
            -- effect.container:flash()
            effect.container:hide()
            effects_window:remove(effect.container)
            Fierymud.Effects.Active[effect.container.name] = nil
            debugc("Removing effect: " .. effect.container.name)
        else
            effect.duration_label:echo([[<center>]] .. math.ceil(effect.duration / 60) .. [[</center>]])
        end
    end


end

function Fierymud.Effects:onGMCPUpdate(event, ...)
    if Fierymud.Config.disable_spell_effects then return end

    local seen = {}
    for _, effect in pairs(gmcp.Char.Effects) do
        table.insert(seen, effect.name)
        if not Fierymud.Effects.Active[effect.name] then
            debugc("Adding effect (gmcp): " .. effect.name)
            add_effect(effect.name, effect.duration * 60)
        end
    end

    for _, effect in pairs(Fierymud.Effects.Active) do
        if not table.contains(seen, effect.container.name) then
            -- effect.container:flash()
            effect.container:hide()
            Fierymud.GUI.effects_window:remove(effect.container)
            Fierymud.Effects.Active[effect.container.name] = nil
            debugc("Removing effect (gmcp): " .. effect.container.name)
        end
    end
end

function Fierymud.Effects:setup()
    if Fierymud.Config.disable_spell_effects then return end
    local rcw = Fierymud.GUI.right_container_width
    local lcw = Fierymud.GUI.left_container_width
    local ww = Fierymud.GUI.window_width

    if Fierymud.Config.spell_effect_location == "top" then
        setBorderBottom(0)
        Fierymud.GUI.effects_window = Fierymud.GUI.effects_window or Geyser.HBox:new({
            name = 'effects_window',
            x = lcw + 35, y = 0,
            width = ww - rcw - lcw - 50, height = '100'
        })
    else
        setBorderBottom(100)
        Fierymud.GUI.effects_window = Fierymud.GUI.effects_window or Geyser.HBox:new({
            name = 'effects_window',
            x = lcw, y = -100,
            width = ww - rcw - lcw - 10, height = '100'
        })
    end
    Fierymud.GUI.effects_window:show()
    if not Fierymud.Effects.updateTimer then
        Fierymud.Effects.updateTimer = tempTimer(1, updateEffectsWindow, true)
    end
end

registerAnonymousEventHandler("gmcp.Char", "Fierymud.Effects:onGMCPUpdate")
