Fierymud = Fierymud or {}
Fierymud.GUI = Fierymud.GUI or {}

local label_style = "border: 2px groove grey;"

local function setup()
  -- Set Left Column
  Fierymud.GUI.left_container = Fierymud.GUI.left_container or Adjustable.Container:new({
    name = 'Vitals', x = "0%", y = "0%", width = "20%", height = '100%', attached = 'left', adjLabelstyle = label_style, titleTxtColor = "grey", titleText = "Vitals"
  })

  -- Setup Right Column
  Fierymud.GUI.right_container = Fierymud.GUI.right_container or Adjustable.Container:new({
    name = 'Right', x = "-20%", y = "0%", width = "-20%", height = '100%', attached = 'right', adjLabelstyle = label_style, titleTxtColor = "grey", titleText = "Chat/Map"
  })

  Fierymud.GUI.chat_container = Fierymud.GUI.chat_container or Geyser.Container:new({
    name = 'Chat and Map', x = 0, y = 0, width = "100%", height = '60%'
  }, Fierymud.GUI.right_container)

  Fierymud.GUI.Map = Fierymud.GUI.Map or Geyser.Mapper:new({
    name = "fiery_map", x = 0, y = "-40%", width = "100%", height = "40%",
  }, Fierymud.GUI.right_container)

  -- Setup Effects Bar
  local location
  if Fierymud.Config.spell_effect_location == "top" then
    location = 'top'
  else
    location = 'bottom'
  end
  Fierymud.GUI.effects_container = Fierymud.GUI.effects_container or Adjustable.Container:new({
    name = 'Active Effects', y = "0%", height = '10%', attached = location, adjLabelstyle = label_style, titleTxtColor = "grey", titleText = "Active Affects"
  })
  Fierymud.GUI.effects_container:connectToBorder("left")
  Fierymud.GUI.effects_container:connectToBorder("right")

  Fierymud.GUI.effects_window = Fierymud.GUI.effects_window or Geyser.HBox:new({
    name = 'effects_window', x = 0, y = 0, width = "100%", height = "100%"
  }, Fierymud.GUI.effects_container)

  Fierymud.Chat:setup()
  Fierymud.Effects:setup()
  Fierymud.Guages:setup()

  Fierymud.Initialized = true

  -- Show welcome message on first install
  if not Fierymud.Config.seen_welcome then
    local version = getPackageInfo("FierymudOfficial", "version") or "Unknown"
    cecho("\n<green>Welcome to FieryMud Client v" .. version .. "!<reset>\n")
    cecho("<white>Commands:<reset>\n")
    cecho("  <green>fm help<reset>   - Show all commands\n")
    cecho("  <green>fm status<reset> - Show current status\n")
    cecho("  <green>fm config<reset> - View/change settings\n")
    cecho("\n<grey>Report issues: https://github.com/stridera/FierymudMudletClient/issues<reset>\n\n")
    Fierymud.Config.seen_welcome = true
    table.save(getMudletHomeDir():gsub("\\", "/") .. "/fierymud_config.lua", Fierymud.Config)
  end
end

function Fierymud.GUI.handleReposition(name, x, y, width, height)
  -- TODO: Handle Hiding
  -- TODO: Make visible after hiding

  -- if name == "Vitals" then
  --   Fierymud.GUI.left_container:resize(x, y, width, height)
  -- elseif name == "Chat" then
  --   Fierymud.GUI.right_container:resize(x, y, width, height)
  -- elseif name == "Active Effects" then
  --   Fierymud.GUI.effects_container:resize(x, y, width, height)
  -- end

end

function Fierymud.eventHandler(event, ...)
  local args = {...}
  if event == "sysLoadEvent" or event == "sysInstall" then
    Fierymud.Config:initConfig();
    if not Fierymud.Config.enabled then return end

    setup()
  else
    if not Fierymud.Initialized then return end

    if event == "onTell" then
      Fierymud.Chat:onRemoteTell(args[1], args[2], args[3], args[4])
    elseif event == "onPrompt" then
      Fierymud.Character:update()
    elseif event == "onRemoteVitalsUpdate" then
      Fierymud.Character:onRemoteVitalsUpdate(unpack(args))
    elseif event == "AdjustableContainerReposition" then
      Fierymud.GUI.handleReposition(unpack(args))
    end
  end
end

-- Store event handler IDs for cleanup
Fierymud.EventHandlers = Fierymud.EventHandlers or {}

local function registerHandler(event, handler)
  local id = registerAnonymousEventHandler(event, handler)
  table.insert(Fierymud.EventHandlers, id)
  return id
end

function Fierymud.cleanup()
  -- Kill all event handlers
  for _, handler in ipairs(Fierymud.EventHandlers) do
    killAnonymousEventHandler(handler)
  end
  Fierymud.EventHandlers = {}

  -- Kill timers
  if Fierymud.Effects and Fierymud.Effects.updateTimer then
    killTimer(Fierymud.Effects.updateTimer)
    Fierymud.Effects.updateTimer = nil
  end
  if Fierymud.Guages and Fierymud.Guages.ProfileChecker then
    killTimer(Fierymud.Guages.ProfileChecker)
    Fierymud.Guages.ProfileChecker = nil
  end

  debugc("FieryMud cleanup complete")
end

registerHandler("sysLoadEvent", "Fierymud.eventHandler")
registerHandler("sysInstall", "Fierymud.eventHandler")
registerHandler("sysUninstall", "Fierymud.cleanup")
registerHandler("onTell", "Fierymud.eventHandler")
registerHandler("onPrompt", "Fierymud.eventHandler")
registerHandler("onRemoteVitalsUpdate", "Fierymud.eventHandler")
registerHandler("AdjustableContainerReposition", "Fierymud.eventHandler")
