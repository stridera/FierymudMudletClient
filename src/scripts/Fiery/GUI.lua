Fierymud = Fierymud or {}
Fierymud.GUI = Fierymud.GUI or {}


local function setup()
  local window_width, window_height = getMainWindowSize()
  debugc("Window Size: " .. window_width .. "x" .. window_height)

  -- Set Left Column
  setBorderLeft(235)
  Fierymud.GUI.left_container = Fierymud.GUI.left_container or Geyser.Container:new({
    name = 'left_container',
    x = 10, y = 10,
    width = Fierymud.Config.left_container_width, height = '100%'
  })

  -- Setup Right Column
  local right_container_width = Fierymud.Config.right_container_width
  if type(right_container_width) == "number" then
    right_container_width = right_container_width
  elseif type(right_container_width) == "string" then
    if right_container_width:sub(-1) == "%" then
      right_container_width = tonumber(right_container_width:sub(1, -2))
    end
    right_container_width = window_width * (right_container_width / 100) - 10
  end
  setBorderRight(right_container_width)

  Fierymud.GUI.right_container_width = right_container_width
  Fierymud.GUI.left_container_width = Fierymud.Config.left_container_width
  Fierymud.GUI.window_width = window_width
  Fierymud.GUI.window_height = window_height

  Fierymud.GUI.right_container = Fierymud.right_container or Geyser.Container:new({
    name = 'right_container',
    x = "-" .. right_container_width, y = 0,
    width = right_container_width, height = '100%'
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

  Fierymud.Initialized = true
end

function Fierymud.eventHandler(event, ...)
  if event == "sysLoadEvent" or event == "sysInstall" then
    Fierymud.Config:initConfig();
    if not Fierymud.Config.enabled then return end

    setup()
    Fierymud.Chat:setup()
    Fierymud.Effects:setup()
  else
    if not Fierymud.Initialized then return end

    if event == "onTell" then
      Fierymud.Chat:onRemoteTell(arg[1], arg[2], arg[3], arg[4])
    elseif event == "onPrompt" then
      Fierymud.Character:update()
    elseif event == "onRemoteVitalsUpdate" then
      Fierymud.Character:onRemoteVitalsUpdate(unpack(arg))
    end
  end
end

registerAnonymousEventHandler("sysLoadEvent", "Fierymud.eventHandler")
registerAnonymousEventHandler("sysInstall", "Fierymud.eventHandler")
registerAnonymousEventHandler("onTell", "Fierymud.eventHandler")
registerAnonymousEventHandler("onPrompt", "Fierymud.eventHandler")
registerAnonymousEventHandler("onRemoteVitalsUpdate", "Fierymud.eventHandler")
