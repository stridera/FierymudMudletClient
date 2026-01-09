Fierymud = Fierymud or {}
Fierymud.Effects = Fierymud.Effects or {}
Fierymud.Effects.Active = Fierymud.Effects.Active or {}
local profilePath = getMudletHomeDir():gsub("\\", "/")

local function add_effect(name, duration)
    local effect_type = Fierymud.Config.spell_effect_type
    local effects_window = Fierymud.GUI.effects_window

    if not effects_window then return end

    local effect = Geyser.VBox:new({
        name = name, h_policy = Geyser.Fixed, width = "64px", height = "80px"
    }, effects_window)

    local path = profilePath .. "/FierymudOfficial/" .. name .. ".png"
    local spellLabel = Geyser.Label:new({
        name = name .. "_label", width = "100%", height = "64px", fgColor = "white", fontSize = 12,
        v_policy = Geyser.Fixed,
        message = [[<center>]] .. name .. [[</center>]],
    }, effect)
    spellLabel:setToolTip(name)
    if effect_type == "icon" and io.exists(path) then
        setBackgroundImage(name .. "_label", path)
    end
    local duration_label = Geyser.Label:new({
        name = name .. "_duration", width = "100%", height = "16px", fgColor = "white", fontSize = 10,
        v_policy = Geyser.Fixed,
        message = [[<center>]] .. math.ceil(duration / 60) .. [[</center>]],
    }, effect)

    Fierymud.Effects.Active[name] = {
        container = effect,
        duration_label = duration_label,
        duration = duration,
    }
end

local function updateEffectsWindow()
    if Fierymud.Config.disable_spell_effects then return end

    local effects_window = Fierymud.GUI.effects_window
    if not effects_window then return end

    for _, effect in pairs(Fierymud.Effects.Active) do
        effect.duration = effect.duration - 1
        if effect.duration < 0 then
            effect.container:hide()
            effects_window:remove(effect.container)
            Fierymud.Effects.Active[effect.container.name] = nil
            debugc("Removing effect: " .. effect.container.name)
        else
            local minutes = math.ceil(effect.duration / 60)
            local color = "white"
            -- Warning colors for expiring effects
            if effect.duration <= 30 then
                color = "red"
            elseif effect.duration <= 60 then
                color = "orange"
            end
            effect.duration_label:echo([[<center><]] .. color .. [[>]] .. minutes .. [[</]] .. color .. [[></center>]])
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
            add_effect(effect.name, effect.duration * 60 + 1)
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
    if not Fierymud.Effects.updateTimer then
        Fierymud.Effects.updateTimer = tempTimer(1, updateEffectsWindow, true)
    end
end

registerAnonymousEventHandler("gmcp.Char", "Fierymud.Effects:onGMCPUpdate")
