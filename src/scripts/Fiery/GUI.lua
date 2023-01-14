Fierymud = Fierymud or {}
Fierymud.GUI = Fierymud.GUI or {}


local function setup()
  -- Set Left Column
  Fierymud.GUI.left_container = Fierymud.GUI.left_container or Adjustable.Container:new({
    name = 'Vitals', x = "0%", y = "0%", width = "20%", height = '100%', attached = 'left'
  })

  -- Setup Right Column
  Fierymud.GUI.right_container = Fierymud.GUI.right_container or Adjustable.Container:new({
    name = 'Right', x = "-20%", y = "0%", width = "-20%", height = '100%', attached = 'right'
  })

  Fierymud.GUI.chat_container = Fierymud.chat_container or Geyser.Container:new({
    name = 'Chat and Map', x = 0, y = 0, width = "100%", height = '60%'
  }, Fierymud.GUI.right_container)

  Fierymud.GUI.Map = Geyser.Mapper:new({
    name = "fiery_map", x = 0, y = "-40%", width = "100%", height = "40%",
  }, Fierymud.GUI.right_container)

  -- Setup Effects Bar
  if Fierymud.Config.spell_effect_location == "top" then
    Fierymud.GUI.effects_container = Fierymud.GUI.effects_container or Adjustable.Container:new({
      name = 'Active Effects', y = "0%", height = '10%', attached = 'top'
    })
  else
    Fierymud.GUI.effects_container = Fierymud.GUI.effects_container or Adjustable.Container:new({
      name = 'Active Effects', y = "-10%", height = '10%', attached = 'bottom',
    })
  end
  Fierymud.GUI.effects_container:connectToBorder("left")
  Fierymud.GUI.effects_container:connectToBorder("right")

  Fierymud.GUI.effects_window = Fierymud.GUI.effects_window or Geyser.HBox:new({
    name = 'effects_window', x = 0, y = 0, width = "100%", height = "100%"
  }, Fierymud.GUI.effects_container)

  Fierymud.Chat:setup()
  Fierymud.Effects:setup()
  Fierymud.Guages:setup()

  Fierymud.Initialized = true
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
  if event == "sysLoadEvent" or event == "sysInstall" then
    Fierymud.Config:initConfig();
    if not Fierymud.Config.enabled then return end

    setup()
  else
    if not Fierymud.Initialized then return end

    if event == "onTell" then
      Fierymud.Chat:onRemoteTell(arg[1], arg[2], arg[3], arg[4])
    elseif event == "onPrompt" then
      Fierymud.Character:update()
    elseif event == "onRemoteVitalsUpdate" then
      Fierymud.Character:onRemoteVitalsUpdate(unpack(arg))
    elseif event == "AdjustableContainerReposition" then
      Fierymud.GUI.handleReposition(unpack(arg))
    end
  end
end

registerAnonymousEventHandler("sysLoadEvent", "Fierymud.eventHandler")
registerAnonymousEventHandler("sysInstall", "Fierymud.eventHandler")
registerAnonymousEventHandler("onTell", "Fierymud.eventHandler")
registerAnonymousEventHandler("onPrompt", "Fierymud.eventHandler")
registerAnonymousEventHandler("onRemoteVitalsUpdate", "Fierymud.eventHandler")
registerAnonymousEventHandler("AdjustableContainerReposition", "Fierymud.eventHandler")
