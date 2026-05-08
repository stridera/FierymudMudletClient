FierymudRs = FierymudRs or {}
FierymudRs.Config = FierymudRs.Config or {}

local profilePath = getMudletHomeDir():gsub("\\", "/")
local configPath = profilePath .. "/fierymud_rs_config.lua"

FierymudRs.Defaults = {
    -- Global
    enabled = true,
    seen_welcome = false,

    -- Vitals
    disable_vitals = false,
    vitals_life = 60,

    -- Chat
    disable_chat = false,
    os_alerts = true,

    -- Mapper
    disable_map = false,

    -- Spell Effects
    disable_spell_effects = false,
    spell_effect_location = "top",
    spell_effect_type = "icon",
}

function FierymudRs.Config:initConfig()
    local config = FierymudRs.Config or {}

    -- load stored configs from file if it exists
    if io.exists(configPath) then
        table.load(configPath, config)
    end

    config = table.update(FierymudRs.Defaults, config)
    FierymudRs.Config = config
end

local function save_config()
    table.save(configPath, FierymudRs.Config)
end

local function config(key, value)
    if value == nil then
        return tostring(FierymudRs.Config[key])
    end

    FierymudRs.Config[key] = value
    save_config()
end

local function toggle_config(key)
    FierymudRs.Config[key] = not FierymudRs.Config[key]
    save_config()
    return FierymudRs.Config[key]
end

function FierymudRs.Config:do_config(args)
    if args == nil or string.trim(args) == "" then
        cecho("<green>FieryMud Config:\n")
        cecho("  <white>Basic Settings:<reset>\n")
        cecho("    <green>enabled:<reset>               <red>" .. config("enabled") .. "<reset>\n")
        cecho("        - Toggle.  Enables/Disables the FieryMud GUI\n")
        cecho("    <green>disable_vitals:<reset>        <red>" .. config("disable_vitals") .. "<reset>\n")
        cecho("        - Toggle.  Enables/Disables the character/combat vitals\n")
        cecho("    <green>disable_chat:<reset>          <red>" .. config("disable_chat") .. "<reset>\n")
        cecho("        - Toggle.  Enables/Disables the  chat window\n")
        cecho("    <green>disable_map:<reset>           <red>" .. config("disable_map") .. "<reset>\n")
        cecho("        - Toggle.  Enables/Disables the  map window\n")
        cecho("    <green>os_alerts:<reset>             <red>" .. config("os_alerts") .. "<reset>\n")
        cecho("        - Toggle.  Enables/Disables the OS alerts on chat messages\n")
        cecho("    <green>disable_spell_effects:<reset> <red>" .. config("disable_spell_effects") .. "<reset>\n")
        cecho("        - Toggle.  Enables/Disables the spell effects\n")
        cecho("\n")
        cecho("<white>UI Containers:<reset>\n")
        cecho("    <green>spell_effect_location:<reset>     <red>" .. config("spell_effect_location") .. "<reset>\n")
        cecho("        - Location of spell effects.  Valid values: top, bottom\n")
        cecho("    <green>spell_effect_type:<reset>     <red>" .. config("spell_effect_type") .. "<reset>\n")
        cecho("        - Option of Icon or Text.  Determins how to show the spell effects.\n")
        cecho("\n")
        cecho("<white>Vitals:<reset>\n")
        cecho("    <green>vitals_life:<reset>             <red>" .. config("vitals_life") .. "<reset>\n")
        cecho("        - How long to keep another profiles vitals before they fade away.\n")
        return
    end

    local key, value = args:match("([%w_]+)%s*(.*)")
    local toggles = {
        "enabled",
        "debug",
        "disable_vitals",
        "disable_chat",
        "disable_map",
        "os_alerts",
        "disable_spell_effects",
    }
    local integers = {
        "vitals_life",
    }
    local strings = {
        "spell_effect_location",
        "spell_effect_type",
    }
    if key == 'enabled' then
        if toggle_config('enabled') then
            print("FierymudRs GUI Enabled.")
        else
            print("FierymudRs GUI Disabled.")
            setBorderLeft(0)
            setBorderRight(0)
            setBorderTop(0)
            setBorderBottom(0)
            FierymudRs.GUI.left_container:hide()
            FierymudRs.GUI.right_container:hide()
        end
        resetProfile()
    elseif table.contains(integers, key) then
        config(key, tonumber(value))
        print("FierymudRs Config: " .. key .. " set to " .. value)
    elseif table.contains(strings, key) then
        config(key, value)
        print("FierymudRs Config: " .. key .. " set to " .. value)
    elseif table.contains(toggles, key) then
        value = toggle_config(key)
        print("FierymudRs Config: " .. key .. " set to " .. tostring(value))
    else
        print("FierymudRs Config: Invalid config key: " .. key)
    end
end
