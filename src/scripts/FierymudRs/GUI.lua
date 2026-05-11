FierymudRs = FierymudRs or {}
FierymudRs.GUI = FierymudRs.GUI or {}

local label_style = "border: 2px groove grey;"

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

  -- Iterate the subsystem registry. Each subsystem self-
  -- registers (`FierymudRs._subsystems.<Name> = {setup,
  -- isReady, ...}`) at the bottom of its script body, so adding
  -- a new one is just "drop a new file + register it" — no edit
  -- to this loop needed. `isReady` lets idempotent setups
  -- (re-running on reconnect / fm reset) cleanly skip when
  -- they're already initialized; subsystems that mutate their
  -- own namespace and drop `:setup` (Chat does this) need the
  -- marker to avoid blowing up on a second call.
  for _, sub in pairs(FierymudRs._subsystems or {}) do
    local already = sub.isReady and sub.isReady()
    if not already and type(sub.setup) == "function" then
      local ok, err = pcall(sub.setup)
      if not ok then
        cecho(string.format(
          "\n<red>%s subsystem setup failed: %s<reset>\n",
          tostring(sub.name or "?"), tostring(err)
        ))
      end
    end
  end

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

-- The package is purpose-built for the Rust port. No server-
-- identity gate: if it's installed, the user wants it loaded.
-- Subsystem `isReady` checks make setup() idempotent, so calling
-- it from multiple session events is harmless.
function FierymudRs.tryInit()
  if FierymudRs.Initialized then return end
  if not FierymudRs.Config or not FierymudRs.Config.enabled then return end
  setup()
end

-- Debounce session events (sysLoadEvent / sysInstall /
-- sysConnectionEvent often arrive within milliseconds of each
-- other) via a named one-shot timer. Re-registering the same
-- name replaces the prior timer in place — "the latest schedule
-- wins" without manual bookkeeping.
local function scheduleTryInit()
  registerNamedTimer("FierymudRs", "tryInit", 1, function()
    FierymudRs.tryInit()
  end, true)
end

local function onSession(event, ...)
  if event == "sysLoadEvent" or event == "sysInstall" then
    FierymudRs.Config:initConfig()
    scheduleTryInit()
  elseif event == "sysConnectionEvent" then
    -- Reconnects (Mudlet auto-reconnect, or `disconnect` +
    -- manual reconnect). MSSP fires fresh; re-gate.
    scheduleTryInit()
  end
  -- sysDisconnectionEvent: intentional no-op. Setup helpers
  -- (notably Chat:setup) mutate their namespaces and only run
  -- once; Mudlet keeps Geyser containers, EMCO state, and
  -- effect icons across disconnect/reconnect anyway. `fm reset`
  -- is the manual recovery path if a re-init is ever needed.
end

local function onPostInit(event, ...)
  if not FierymudRs.Initialized then return end
  local args = {...}
  if event == "onTell" then
    FierymudRs.Chat:onRemoteTell(args[1], args[2], args[3], args[4])
  elseif event == "onPrompt" then
    FierymudRs.Character:update()
    if FierymudRs.Tracker and FierymudRs.Tracker.update then
      FierymudRs.Tracker:update()
    end
    if FierymudRs.CombatQueue and FierymudRs.CombatQueue.advance then
      FierymudRs.CombatQueue:advance()
    end
  elseif event == "onRemoteVitalsUpdate" then
    FierymudRs.Character:onRemoteVitalsUpdate(...)
  elseif event == "AdjustableContainerReposition" then
    FierymudRs.GUI.handleReposition(...)
  elseif event == "gmcp.Comm.Channel.Text" then
    if FierymudRs.Chat and FierymudRs.Chat.onCommChannelText then
      FierymudRs.Chat:onCommChannelText()
    end
  elseif event == "gmcp.Comm.Channel.List" then
    if FierymudRs.Chat and FierymudRs.Chat.onCommChannelList then
      FierymudRs.Chat:onCommChannelList()
    end
  elseif event == "gmcp.Char.Items.List" then
    if FierymudRs.Inventory and FierymudRs.Inventory.onItemsList then
      FierymudRs.Inventory:onItemsList()
    end
  end
end

function FierymudRs.cleanup()
  -- Mudlet's named-handler registry tracks every handler under
  -- the "FierymudRs" user; one call wipes them all without us
  -- maintaining a parallel list. Same story for named timers.
  deleteAllNamedEventHandlers("FierymudRs")
  deleteAllNamedTimers("FierymudRs")

  -- Subsystem-specific timers that aren't named-registered yet.
  -- (Once the subsystems get their own named registrations,
  -- this whole block can collapse.)
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

-- Named-handler registration. Each (user, name) pair is unique;
-- re-registering the same name replaces the prior handler in
-- place (the IDManager calls stop() before re-register), so
-- this block is also the canonical "rebind everything" path —
-- safe to run on package upgrade without leaking handlers.
local function bindHandlers()
  local sessionEvents = {
    "sysLoadEvent", "sysInstall", "sysConnectionEvent",
    "sysDisconnectionEvent",
  }
  for _, ev in ipairs(sessionEvents) do
    registerNamedEventHandler("FierymudRs", "session." .. ev, ev, onSession)
  end

  local postInitEvents = {
    "onTell", "onPrompt", "onRemoteVitalsUpdate",
    "AdjustableContainerReposition",
    "gmcp.Comm.Channel.Text", "gmcp.Comm.Channel.List",
    "gmcp.Char.Items.List",
  }
  for _, ev in ipairs(postInitEvents) do
    registerNamedEventHandler("FierymudRs", "postinit." .. ev, ev, onPostInit)
  end

  registerNamedEventHandler("FierymudRs", "lifecycle.uninstall",
    "sysUninstall", FierymudRs.cleanup)
end
bindHandlers()
