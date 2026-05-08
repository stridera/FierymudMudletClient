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

-- The icon set ships with one PNG per spell name (armor.png,
-- bless.png, ...). The server emits both the `ability` field
-- (the spell that caused the effect — "armor", "stone skin")
-- and the `name` field (the effect itself — "ward",
-- "resistance"). Prefer the ability for lookup so icons line up
-- with what the player cast. Falls back to the effect name for
-- admin / environmental effects with no originating ability.
local function icon_key_for(eff)
    if eff.ability and eff.ability ~= "" then
        return eff.ability
    end
    return eff.name
end

local function add_effect(eff)
    local effect_type = FierymudRs.Config.spell_effect_type
    local effects_window = FierymudRs.GUI.effects_window
    if not effects_window then return end

    local key = icon_key_for(eff)
    local label_text = key

    local container = Geyser.VBox:new({
        name = key, h_policy = Geyser.Fixed, width = "64px", height = "80px"
    }, effects_window)

    local path = profilePath .. "/FierymudRs/" .. key .. ".png"
    local spell_label = Geyser.Label:new({
        name = key .. "_label", width = "100%", height = "64px", fgColor = "white", fontSize = 12,
        v_policy = Geyser.Fixed,
        message = [[<center>]] .. label_text .. [[</center>]],
    }, container)
    -- Tooltip shows both names so a curious player can see what
    -- spell mapped to what effect.
    if eff.ability and eff.ability ~= "" and eff.ability ~= eff.name then
        spell_label:setToolTip(string.format("%s (%s)", eff.ability, eff.name))
    else
        spell_label:setToolTip(eff.name or "")
    end
    if effect_type == "icon" and io.exists(path) then
        setBackgroundImage(key .. "_label", path)
    end
    local duration_label = Geyser.Label:new({
        name = key .. "_duration", width = "100%", height = "16px", fgColor = "white", fontSize = 10,
        v_policy = Geyser.Fixed,
        message = [[<center>]] .. format_duration(eff.duration) .. [[</center>]],
    }, container)

    FierymudRs.Effects.Active[key] = {
        container = container,
        duration_label = duration_label,
        duration = eff.duration,
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
-- `{name, ability, duration, source, strength}`. We key tiles by
-- the icon-friendly identifier (`ability` when set, `name`
-- otherwise — see `icon_key_for`); a re-emit with the same key
-- updates the existing tile's duration.
function FierymudRs.Effects:onGMCPUpdate(event, ...)
    if FierymudRs.Config.disable_spell_effects then return end
    if not gmcp or not gmcp.Char or type(gmcp.Char.Effects) ~= "table" then
        return
    end

    local seen = {}
    for _, effect in pairs(gmcp.Char.Effects) do
        if effect and effect.name then
            local key = icon_key_for(effect)
            table.insert(seen, key)
            local existing = FierymudRs.Effects.Active[key]
            if existing then
                existing.duration = effect.duration
            else
                debugc("Adding effect (gmcp): " .. key)
                add_effect(effect)
            end
        end
    end

    for _, active in pairs(FierymudRs.Effects.Active) do
        if not table.contains(seen, active.container.name) then
            active.container:hide()
            FierymudRs.GUI.effects_window:remove(active.container)
            FierymudRs.Effects.Active[active.container.name] = nil
            debugc("Removing effect (gmcp): " .. active.container.name)
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
