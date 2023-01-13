Fierymud = Fierymud or {}
Fierymud.Config = Fierymud.Config or {}

local profilePath = getMudletHomeDir():gsub("\\", "/")
local configPath = profilePath .. "/fierymud_config.lua"

Fierymud.Defaults = {
    -- Global
    enabled = true,

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

function Fierymud.Config:initConfig()
    local config = Fierymud.Config or {}

    -- load stored configs from file if it exists
    if io.exists(configPath) then
        table.load(configPath, config)
    end

    config = table.update(Fierymud.Defaults, config)
    Fierymud.Config = config
end

local function save_config()
    table.save(configPath, Fierymud.Config)
end

local function config(key, value)
    if value == nil then
        return tostring(Fierymud.Config[key])
    end

    Fierymud.Config[key] = value
    save_config()
end

local function toggle_config(key)
    Fierymud.Config[key] = not Fierymud.Config[key]
    save_config()
    return Fierymud.Config[key]
end

function Fierymud.Config:do_config(args)
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
            print("Fierymud GUI Enabled.")
        else
            print("Fierymud GUI Disabled.")
            setBorderLeft(0)
            setBorderRight(0)
            setBorderTop(0)
            setBorderBottom(0)
            Fierymud.GUI.left_container:hide()
            Fierymud.GUI.right_container:hide()
        end
        resetProfile()
    elseif table.contains(integers, key) then
        config(key, tonumber(value))
        print("Fierymud Config: " .. key .. " set to " .. value)
    elseif table.contains(strings, key) then
        config(key, value)
        print("Fierymud Config: " .. key .. " set to " .. value)
    elseif table.contains(toggles, key) then
        toggle_config(key)
        print("Fierymud Config: " .. key .. " set to " .. value)
    else
        print("Fierymud Config: Invalid config key: " .. key)
    end
end
