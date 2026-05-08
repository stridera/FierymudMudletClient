FierymudRs = FierymudRs or {}
FierymudRs.GUI = FierymudRs.GUI or {}

local label_style = "border: 2px groove grey;"

-- Server-identity gate. The Rust port advertises MSSP `NAME =
-- "fierymud-rs"`; the legacy C++ FieryMUD advertises `NAME =
-- "FieryMUD"` (or a related label). The gate prevents this
-- package from initializing on the legacy server, where its
-- GMCP shape and Lua mapper conventions don't apply. A config
-- override (`FierymudRs.Config.force_rust_mode`) lets developers
-- bypass the gate when testing against an MSSP-less endpoint.
function FierymudRs.serverIsRustPort()
  if type(mssp) == "table" and mssp.NAME == "fierymud-rs" then
    return true, "MSSP NAME"
  end
  if FierymudRs.Config and FierymudRs.Config.force_rust_mode then
    return true, "force_rust_mode override"
  end
  return false, "MSSP NAME absent or mismatched"
end

local function setup()
  -- Set Left Column
  FierymudRs.GUI.left_container = FierymudRs.GUI.left_container or Adjustable.Container:new({
    name = 'Vitals', x = "0%", y = "0%", width = "20%", height = '100%', attached = 'left', adjLabelstyle = label_style, titleTxtColor = "grey", titleText = "Vitals"
  })

  -- Setup Right Column
  FierymudRs.GUI.right_container = FierymudRs.GUI.right_container or Adjustable.Container:new({
    name = 'Right', x = "-20%", y = "0%", width = "-20%", height = '100%', attached = 'right', adjLabelstyle = label_style, titleTxtColor = "grey", titleText = "Chat/Map"
  })

  FierymudRs.GUI.chat_container = FierymudRs.GUI.chat_container or Geyser.Container:new({
    name = 'Chat and Map', x = 0, y = 0, width = "100%", height = '60%'
  }, FierymudRs.GUI.right_container)

  FierymudRs.GUI.Map = FierymudRs.GUI.Map or Geyser.Mapper:new({
    name = "fiery_map", x = 0, y = "-40%", width = "100%", height = "40%",
  }, FierymudRs.GUI.right_container)

  -- Setup Effects Bar
  local location
  if FierymudRs.Config.spell_effect_location == "top" then
    location = 'top'
  else
    location = 'bottom'
  end
  FierymudRs.GUI.effects_container = FierymudRs.GUI.effects_container or Adjustable.Container:new({
    name = 'Active Effects', y = "0%", height = '10%', attached = location, adjLabelstyle = label_style, titleTxtColor = "grey", titleText = "Active Affects"
  })
  FierymudRs.GUI.effects_container:connectToBorder("left")
  FierymudRs.GUI.effects_container:connectToBorder("right")

  FierymudRs.GUI.effects_window = FierymudRs.GUI.effects_window or Geyser.HBox:new({
    name = 'effects_window', x = 0, y = 0, width = "100%", height = "100%"
  }, FierymudRs.GUI.effects_container)

  FierymudRs.Chat:setup()
  FierymudRs.Effects:setup()
  FierymudRs.Guages:setup()

  FierymudRs.Initialized = true

  -- Show welcome message on first install
  if not FierymudRs.Config.seen_welcome then
    local version = getPackageInfo("FierymudRs", "version") or "Unknown"
    cecho("\n<green>Welcome to FieryMud Client v" .. version .. "!<reset>\n")
    cecho("<white>Commands:<reset>\n")
    cecho("  <green>fm help<reset>   - Show all commands\n")
    cecho("  <green>fm status<reset> - Show current status\n")
    cecho("  <green>fm config<reset> - View/change settings\n")
    cecho("\n<grey>Report issues: https://github.com/stridera/FierymudMudletClient/issues<reset>\n\n")
    FierymudRs.Config.seen_welcome = true
    table.save(getMudletHomeDir():gsub("\\", "/") .. "/fierymud_rs_config.lua", FierymudRs.Config)
  end
end

function FierymudRs.GUI.handleReposition(name, x, y, width, height)
  -- TODO: Handle Hiding
  -- TODO: Make visible after hiding

  -- if name == "Vitals" then
  --   FierymudRs.GUI.left_container:resize(x, y, width, height)
  -- elseif name == "Chat" then
  --   FierymudRs.GUI.right_container:resize(x, y, width, height)
  -- elseif name == "Active Effects" then
  --   FierymudRs.GUI.effects_container:resize(x, y, width, height)
  -- end

end

-- Defer init until MSSP has had a chance to land. Mudlet
-- populates the global `mssp` table within ~100 ms of the IAC
-- SB MSSP frame; the Rust server sends that frame
-- unconditionally on connect. A 1-second tempTimer is generous
-- headroom and matches the cadence DiscworldUI uses for the
-- same gate. The `Initialized` flag prevents double-setup if the
-- check fires twice (sysLoadEvent + sysConnectionEvent both
-- arrive on first connect).
function FierymudRs.tryInit()
  if FierymudRs.Initialized then return end
  if not FierymudRs.Config or not FierymudRs.Config.enabled then return end

  local ok, reason = FierymudRs.serverIsRustPort()
  if not ok then
    cecho(string.format(
      "\n<grey>FierymudRs idle: %s. (set <yellow>FierymudRs.Config.force_rust_mode = true<grey> to override.)<reset>\n\n",
      reason
    ))
    return
  end

  cecho(string.format("\n<green>FierymudRs detected (%s) — loading UI...<reset>\n", reason))
  setup()
end

function FierymudRs.eventHandler(event, ...)
  local args = {...}
  if event == "sysLoadEvent" or event == "sysInstall" then
    FierymudRs.Config:initConfig()
    -- MSSP almost certainly hasn't arrived yet; defer the
    -- identity check by 1s. If the user reconnects later
    -- without disconnecting (rare), the sysConnectionEvent
    -- branch below picks it up.
    tempTimer(1, function() FierymudRs.tryInit() end)
  elseif event == "sysConnectionEvent" then
    -- Reconnects (Mudlet auto-reconnect, or `disconnect` +
    -- manual reconnect). MSSP fires fresh; re-gate.
    tempTimer(1, function() FierymudRs.tryInit() end)
  elseif event == "sysDisconnectionEvent" then
    -- Drop the `Initialized` flag so the next connect re-gates
    -- through MSSP. Existing UI widgets stay (Mudlet keeps
    -- Geyser containers across disconnect/reconnect cycles), so
    -- we don't tear them down.
    FierymudRs.Initialized = false
  else
    if not FierymudRs.Initialized then return end

    if event == "onTell" then
      FierymudRs.Chat:onRemoteTell(args[1], args[2], args[3], args[4])
    elseif event == "onPrompt" then
      FierymudRs.Character:update()
    elseif event == "onRemoteVitalsUpdate" then
      FierymudRs.Character:onRemoteVitalsUpdate(unpack(args))
    elseif event == "AdjustableContainerReposition" then
      FierymudRs.GUI.handleReposition(unpack(args))
    end
  end
end

-- Store event handler IDs for cleanup
FierymudRs.EventHandlers = FierymudRs.EventHandlers or {}

local function registerHandler(event, handler)
  local id = registerAnonymousEventHandler(event, handler)
  table.insert(FierymudRs.EventHandlers, id)
  return id
end

function FierymudRs.cleanup()
  -- Kill all event handlers
  for _, handler in ipairs(FierymudRs.EventHandlers) do
    killAnonymousEventHandler(handler)
  end
  FierymudRs.EventHandlers = {}

  -- Kill timers
  if FierymudRs.Effects and FierymudRs.Effects.updateTimer then
    killTimer(FierymudRs.Effects.updateTimer)
    FierymudRs.Effects.updateTimer = nil
  end
  if FierymudRs.Guages and FierymudRs.Guages.ProfileChecker then
    killTimer(FierymudRs.Guages.ProfileChecker)
    FierymudRs.Guages.ProfileChecker = nil
  end

  debugc("FieryMud cleanup complete")
end

registerHandler("sysLoadEvent", "FierymudRs.eventHandler")
registerHandler("sysInstall", "FierymudRs.eventHandler")
registerHandler("sysUninstall", "FierymudRs.cleanup")
registerHandler("sysConnectionEvent", "FierymudRs.eventHandler")
registerHandler("sysDisconnectionEvent", "FierymudRs.eventHandler")
registerHandler("onTell", "FierymudRs.eventHandler")
registerHandler("onPrompt", "FierymudRs.eventHandler")
registerHandler("onRemoteVitalsUpdate", "FierymudRs.eventHandler")
registerHandler("AdjustableContainerReposition", "FierymudRs.eventHandler")
