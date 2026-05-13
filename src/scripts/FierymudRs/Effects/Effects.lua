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

-- Urgency tiers — drives the duration text color AND the tile
-- border tint. Four bands give a coarse-to-fine read across the
-- bar's lifespan: permanent/long → caution → warning → critical.
-- Mirrors the band thinking from WoW raid timers and POE flask
-- UI, where the eye can pick the most urgent icon out of a row
-- without reading numbers. Returns (mudlet_color_name, hex) —
-- Mudlet's color tags only take named colors in cecho, while Qt
-- stylesheets want hex.
local function urgency_tier(duration)
    if not duration or duration < 0 then return "green",  "#7ad07a" end
    if duration <= 10                 then return "red",    "#ff4040" end
    if duration <= 30                 then return "orange", "#ff8c2a" end
    if duration <= 120                then return "yellow", "#e8d048" end
    return "green", "#7ad07a"
end

-- Stylesheet for the tile's icon area — border color escalates
-- with urgency so the whole tile (not just the text) signals
-- expiry. 2px solid border + rounded corners; faint dark inset
-- so the icon doesn't bleed into the border at sub-pixel
-- rounding.
local function tile_stylesheet(hex)
    return string.format([[
        background-color: rgba(20,20,25,180);
        border: 2px solid %s;
        border-radius: 4px;
    ]], hex)
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
    local color_name, color_hex = urgency_tier(eff.duration)

    local path = profilePath .. "/FierymudRs/" .. key .. ".png"
    local spell_label = Geyser.Label:new({
        name = key .. "_label", width = "100%", height = "62px", fgColor = "white", fontSize = 12,
        v_policy = Geyser.Fixed,
        message = [[<center>]] .. label_text .. [[</center>]],
    }, container)
    -- Border lives on the spell_label (icon area) rather than the
    -- VBox container — Geyser.VBox doesn't propagate stylesheet
    -- to a visible widget, so styling on it is a silent no-op.
    -- The label tints its frame which reads as a tile border on
    -- screen.
    pcall(function() spell_label:setStyleSheet(tile_stylesheet(color_hex)) end)
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
        name = key .. "_duration", width = "100%", height = "14px", fgColor = "white", fontSize = 9,
        v_policy = Geyser.Fixed,
        message = string.format(
            "<center><%s>%s</%s></center>",
            color_name, format_duration(eff.duration), color_name
        ),
    }, container)

    FierymudRs.Effects.Active[key] = {
        container = container,
        spell_label = spell_label,
        duration_label = duration_label,
        duration = eff.duration,
        last_color = color_name,
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
            local color_name, color_hex = urgency_tier(effect.duration)
            -- Only restyle the tile border when the urgency band
            -- changes — Qt stylesheets aren't cheap to re-apply at
            -- 1Hz across many widgets, and within a band there's
            -- nothing visually new to convey.
            if color_name ~= effect.last_color and effect.spell_label then
                pcall(function() effect.spell_label:setStyleSheet(tile_stylesheet(color_hex)) end)
                effect.last_color = color_name
            end
            effect.duration_label:echo(string.format(
                "<center><%s>%s</%s></center>",
                color_name, format_duration(effect.duration), color_name
            ))
        end
    end
end

-- Re-add all active effects to the window in expiring-first
-- order. Permanents drop to the right; everything else is
-- ascending by remaining duration so the eye lands on the most
-- urgent tile at the left edge of the bar — the same convention
-- POE flasks and WoW raid timers use. Called from the GMCP
-- update path (not the per-second tick) so we don't pay the
-- container-rebuild cost at 1Hz.
local function resort_effects_window()
    local effects_window = FierymudRs.GUI.effects_window
    if not effects_window then return end

    local ordered = {}
    for _, effect in pairs(FierymudRs.Effects.Active) do
        ordered[#ordered + 1] = effect
    end
    table.sort(ordered, function(a, b)
        local ad, bd = a.duration, b.duration
        -- Permanents (negative durations) bucket as +infinity so
        -- they sort to the right of any finite duration.
        if ad < 0 then ad = math.huge end
        if bd < 0 then bd = math.huge end
        return ad < bd
    end)

    -- HBox layout reads child order from windowList. Geyser
    -- doesn't expose a direct "sort children" call, so we
    -- remove + re-add each tile (cheap — the underlying Qt
    -- widget objects are reused, just re-parented).
    for _, effect in ipairs(ordered) do
        effects_window:remove(effect.container)
    end
    for _, effect in ipairs(ordered) do
        effects_window:add(effect.container)
        effect.container:show()
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

    -- Server-side change is the only time the effect set can
    -- gain a new urgency ordering — re-sort here, not on the
    -- per-second tick.
    resort_effects_window()
end

function FierymudRs.Effects:setup()
    if FierymudRs.Config.disable_spell_effects then return end
    if not FierymudRs.Effects.updateTimer then
        FierymudRs.Effects.updateTimer = tempTimer(1, updateEffectsWindow, true)
    end
end

-- Named handler so package upgrade / fm reset replaces in
-- place instead of stacking — anonymous handlers leaked across
-- reloads before the migration to the named registry.
registerNamedEventHandler("FierymudRs", "Effects.gmcpChar",
  "gmcp.Char", "FierymudRs.Effects:onGMCPUpdate")

FierymudRs._subsystems = FierymudRs._subsystems or {}
FierymudRs._subsystems.Effects = {
  name = "Effects",
  setup = function() FierymudRs.Effects:setup() end,
  teardown = function()
    if not FierymudRs.Effects then return end
    if FierymudRs.Effects.updateTimer then
      killTimer(FierymudRs.Effects.updateTimer)
      FierymudRs.Effects.updateTimer = nil
    end
    FierymudRs.Effects.Active = nil
  end,
  isReady = function()
    return FierymudRs.Effects ~= nil
       and FierymudRs.Effects.updateTimer ~= nil
  end,
}
