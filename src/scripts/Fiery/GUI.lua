Fierymud = Fierymud or {}
Fierymud.GUI = Fierymud.GUI or {}

local profilePath = getMudletHomeDir()
profilePath = profilePath:gsub("\\","/")
local configPath = profilePath.."/fierymud_config.lua"

Fierymud.Defaults = {
  -- Global
  enabled = true,
  debug = false,

  -- Left Container
  left_container_width = 200,

  -- Vitals
  disable_vitals = false,

  -- Chat
  disable_chat = false,

  -- Mapper
  disable_map = false,

}

local function config()
  local config = Fierymud.Config or {}

  -- load stored configs from file if it exists
  if io.exists(configPath) then
    table.load(configPath, config)
  end

  config = table.update(Fierymud.Defaults, config)
  
  
  Fierymud.Config = config
end

local function setup()
  config()

  local window_width, window_height = getMainWindowSize()
  
   -- Set Left Column
  setBorderLeft(235)
  Fierymud.GUI.left_container = Fierymud.GUI.left_container or Geyser.Container:new({
    name = 'left_container',
    x = 10, y = 10,
    width = Fierymud.Config.left_console_width, height = '100%'
  })

  -- Setup Right Column
  setBorderRight(window_width * 0.2 + 10)

  Fierymud.GUI.right_container = Fierymud.right_container or Geyser.Container:new({
    name = 'right_container',
    x = "-20%", y = 0,
    width = "20%", height = '100%'
  })

  Fierymud.GUI.chat_container = Fierymud.chat_container or Geyser.Container:new({
    name = 'chat_container',
    x = 0, y = 0,
    width = "100%", height = '60%'
  }, Fierymud.GUI.right_container)

  Fierymud.GUI.Map = Geyser.Mapper:new({
    name = "fiery_map",
    x = 0, y = "-40%",
    width = "100%",
    height = "40%",
  }, Fierymud.GUI.right_container)
end

function Fierymud:reload()
  Fierymud.GUI = {}
  Fierymud.Guages.vitals = nil
  Fierymud.Guages.character_profiles = nil
  Fierymud.Guages.vitals_container = nil
  Fierymud.Guages.combat_container = nil
  Fierymud.Guages.CombatGuages = nil
  setup()
  echo("Reloaded.")
end

function Fierymud.eventHandler(event, ...)
  if event == "sysLoadEvent" or event == "sysInstall" then
    setup()
    Fierymud.Chat:setup()
    Fierymud.Initialized = True
  else
    if not Fierymud.Initialized then return end

    if event == "onTell" then
      Fierymud.Chat:onRemoteTell(arg[1], arg[2], arg[3], arg[4], arg[5])
    elseif event == "onPrompt" then
      Fierymud.Character:update()
    elseif event == "onRemoteVitalsUpdate" then
      Fierymud.Character:onRemoteVitalsUpdate(unpack(arg))
    end
  end
end

registerAnonymousEventHandler("sysLoadEvent", "Fierymud.eventHandler")
registerAnonymousEventHandler("onTell", "Fierymud.eventHandler")
registerAnonymousEventHandler("onPrompt", "Fierymud.eventHandler")
registerAnonymousEventHandler("onRemoteVitalsUpdate", "Fierymud.eventHandler")