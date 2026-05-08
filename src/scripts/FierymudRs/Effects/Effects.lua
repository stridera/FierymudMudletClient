FierymudRs = FierymudRs or {}
FierymudRs.Effects = FierymudRs.Effects or {}
FierymudRs.Effects.Active = FierymudRs.Effects.Active or {}
local profilePath = getMudletHomeDir():gsub("\\", "/")

-- Format an effect's seconds-remaining for display. Permanent
-- effects (server-side `remaining_secs == -1`) render as `∞`;
-- effects under a minute show seconds; otherwise minutes
-- rounded up. Mirrors the score-sheet rendering on the server
-- so the visible labels stay consistent.
local function format_duration(secs)
    if secs and secs < 0 then return "∞" end
    if not secs or secs <= 0 then return "0" end
    if secs < 60 then return tostring(secs) .. "s" end
    return tostring(math.ceil(secs / 60)) .. "m"
end

local function add_effect(name, duration)
    local effect_type = FierymudRs.Config.spell_effect_type
    local effects_window = FierymudRs.GUI.effects_window

    if not effects_window then return end

    local effect = Geyser.VBox:new({
        name = name, h_policy = Geyser.Fixed, width = "64px", height = "80px"
    }, effects_window)

    local path = profilePath .. "/FierymudRs/" .. name .. ".png"
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
        message = [[<center>]] .. format_duration(duration) .. [[</center>]],
    }, effect)

    FierymudRs.Effects.Active[name] = {
        container = effect,
        duration_label = duration_label,
        duration = duration,
    }
end

local function updateEffectsWindow()
    if FierymudRs.Config.disable_spell_effects then return end

    local effects_window = FierymudRs.GUI.effects_window
    if not effects_window then return end

    for _, effect in pairs(FierymudRs.Effects.Active) do
        -- Permanent effects (duration == -1) tick at -1 forever
        -- so their countdown stays static. The next GMCP update
        -- will refresh the value if the server changes it.
        if effect.duration > 0 then
            effect.duration = effect.duration - 1
        end
        if effect.duration == 0 then
            effect.container:hide()
            effects_window:remove(effect.container)
            FierymudRs.Effects.Active[effect.container.name] = nil
            debugc("Removing effect: " .. effect.container.name)
        else
            local color = "white"
            -- Warning colors as the effect approaches expiry.
            if effect.duration > 0 and effect.duration <= 30 then
                color = "red"
            elseif effect.duration > 0 and effect.duration <= 60 then
                color = "orange"
            end
            effect.duration_label:echo(string.format(
                "<center><%s>%s</%s></center>",
                color, format_duration(effect.duration), color
            ))
        end
    end
end

-- Consume `Char.Effects` GMCP frames. Server emits an array of
-- `{name, duration, source, strength}` per the schema we wrote
-- in mud-server::commands::send_prompt. `duration` is seconds
-- remaining (-1 = permanent); we cache the value and decrement
-- locally each second between GMCP refreshes.
function FierymudRs.Effects:onGMCPUpdate(event, ...)
    if FierymudRs.Config.disable_spell_effects then return end
    if not gmcp or not gmcp.Char or type(gmcp.Char.Effects) ~= "table" then
        return
    end

    local seen = {}
    for _, effect in pairs(gmcp.Char.Effects) do
        if effect and effect.name then
            table.insert(seen, effect.name)
            local existing = FierymudRs.Effects.Active[effect.name]
            if existing then
                -- Refresh the cached duration; the server's
                -- value is authoritative against any local drift
                -- introduced by tempTimer slop.
                existing.duration = effect.duration
            else
                debugc("Adding effect (gmcp): " .. effect.name)
                add_effect(effect.name, effect.duration)
            end
        end
    end

    for _, effect in pairs(FierymudRs.Effects.Active) do
        if not table.contains(seen, effect.container.name) then
            effect.container:hide()
            FierymudRs.GUI.effects_window:remove(effect.container)
            FierymudRs.Effects.Active[effect.container.name] = nil
            debugc("Removing effect (gmcp): " .. effect.container.name)
        end
    end
end

function FierymudRs.Effects:setup()
    if FierymudRs.Config.disable_spell_effects then return end
    if not FierymudRs.Effects.updateTimer then
        FierymudRs.Effects.updateTimer = tempTimer(1, updateEffectsWindow, true)
    end
end

registerAnonymousEventHandler("gmcp.Char", "FierymudRs.Effects:onGMCPUpdate")
