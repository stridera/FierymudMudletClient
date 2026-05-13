FierymudRs = FierymudRs or {}
FierymudRs.GUI = FierymudRs.GUI or {}

local label_style = "border: 2px groove grey;"

-- Append-mode error log. Surfaces failures that the cecho red
-- text shows in the main console — and which are otherwise
-- impossible for an external agent to read without taking a
-- screenshot. Path resolution prefers the dev-loop's UNC into
-- the repo (set by `MuddlerReload.repoPath`); falls back to
-- the Mudlet profile dir on plain installs.
local function errorLogPath()
  if MuddlerReload and MuddlerReload.repoPath then
    return MuddlerReload.repoPath .. "/state/errors.txt"
  end
  return (getMudletHomeDir():gsub("\\", "/")) .. "/errors.txt"
end

function FierymudRs.logError(source, err)
  local line = string.format(
    "[%s] %s: %s\n",
    os.date("!%Y-%m-%dT%H:%M:%SZ"),
    tostring(source or "?"),
    tostring(err or "?")
  )
  local f = io.open(errorLogPath(), "a")
  if f then
    f:write(line)
    f:close()
  end
  -- Also echo to the main console — visible during interactive
  -- dev sessions where the agent isn't reading the file.
  cecho(string.format(
    "\n<red>[FierymudRs error]<reset> %s: %s\n",
    tostring(source or "?"), tostring(err or "?")
  ))
end

-- Force-show a freshly-built top-level container. With the
-- registry-clear in `destroyGeyserSubtree`, the new
-- `:new()` call already starts visible — so this is mostly
-- belt-and-suspenders. It still earns its keep when:
--   (a) a profile is upgrading FROM a buggy MuddlerReload
--       (pre-v0.5) that left stuck `hidden=true` in
--       `Adjustable.Container.all`;
--   (b) the user closed the panel via the X button and then
--       runs `fm reset` — they explicitly asked for a clean
--       GUI, so honoring their prior hide-preference would
--       contradict the command.
-- Trade-off: a normal hot-reload also force-shows panels,
-- which means closing a panel and editing src/ will bring
-- it back. Acceptable for dev iteration; revisit if production
-- users hot-reload often enough to care.
local function forceVisible(c)
  if c and c.show then pcall(function() c:show() end) end
end

local function setup()
  -- Set Left Column
  FierymudRs.GUI.left_container = FierymudRs.GUI.left_container or Adjustable.Container:new({
    name = 'Vitals', x = "0%", y = "0%", width = "20%", height = '100%', attached = 'left', adjLabelstyle = label_style, titleTxtColor = "grey", titleText = "Vitals"
  })
  forceVisible(FierymudRs.GUI.left_container)

  -- Setup Right Column. Declared width must match the rendered
  -- width — Geyser treats `width="-20%"` as `100% - 20% = 80%`
  -- internally, so `get_width()` returns ~1300px even though the
  -- visible panel is only ~360px. EMCO's HBox:organize() reads
  -- get_width() to size its tabs, so a bogus 1300 means each tab
  -- is sized for a 1300px parent — only the first fits in the
  -- visible column. Positive "20%" makes Geyser's internal state
  -- and rendered size agree.
  FierymudRs.GUI.right_container = FierymudRs.GUI.right_container or Adjustable.Container:new({
    name = 'Right', x = "80%", y = "0%", width = "20%", height = '100%', attached = 'right', adjLabelstyle = label_style, titleTxtColor = "grey", titleText = "Chat/Map"
  })
  forceVisible(FierymudRs.GUI.right_container)

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
  forceVisible(FierymudRs.GUI.effects_container)
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
        FierymudRs.logError(
          (sub.name or "?") .. ".setup", err
        )
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
  -- Script load order puts GUI.lua before Config.lua, so the
  -- bottom-of-script kick can't init Config there. tryInit
  -- runs after a 1s timer, by which time every script body
  -- has loaded; this is the safe place to drive initConfig.
  if FierymudRs.Config and FierymudRs.Config.initConfig then
    local ok, err = pcall(function() FierymudRs.Config:initConfig() end)
    if not ok then FierymudRs.logError("Config.initConfig", err) end
  end
  if not FierymudRs.Config or not FierymudRs.Config.enabled then return end
  -- Wrap setup() so an error in container creation (Adjustable
  -- registry hiccups, invalid constraints, Geyser version
  -- drift) lands in `state/errors.txt` rather than vanishing
  -- into Mudlet's internal pcall.
  local ok, err = pcall(setup)
  if not ok then FierymudRs.logError("setup", err) end
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

-- Free a Geyser widget *and its descendants*: hide each and
-- unregister from `Geyser.windowList` so a subsequent `:new()`
-- with the same name doesn't collide. Geyser doesn't expose a
-- real destroy; walking the subtree is what lets hot-reload
-- rebuild EMCO tab consoles, gauges, etc. cleanly.
local function destroyGeyserSubtree(w)
  if not w then return end
  if type(w.windowList) == "table" then
    local names = {}
    for n in pairs(w.windowList) do names[#names + 1] = n end
    for _, n in ipairs(names) do
      destroyGeyserSubtree(w.windowList[n])
    end
  end
  pcall(function() w:hide() end)
  if w.name and Geyser and Geyser.windowList then
    Geyser.windowList[w.name] = nil
  end
  -- Adjustable.Container keeps its own global registry,
  -- `Adjustable.Container.all[name]`. On `:new()` with a name
  -- that's already there, the constructor copies the OLD
  -- entry's `hidden` flag onto the new container — so without
  -- this clear, our `:hide()` above causes every re-created
  -- container to come back hidden. Drop the registry entry
  -- and `Adjustable.Container.all_windows` list slot so the
  -- next `:new()` is treated as a brand-new name.
  if w.name and Adjustable and Adjustable.Container
      and Adjustable.Container.all then
    if Adjustable.Container.all[w.name] then
      Adjustable.Container.all[w.name] = nil
      if type(Adjustable.Container.all_windows) == "table" then
        for i = #Adjustable.Container.all_windows, 1, -1 do
          if Adjustable.Container.all_windows[i] == w.name then
            table.remove(Adjustable.Container.all_windows, i)
          end
        end
      end
    end
  end
end

local function destroyGeyserWidget(name)
  if not name then return end
  local w = Geyser and Geyser.windowList and Geyser.windowList[name]
  if not w then return end
  destroyGeyserSubtree(w)
end

FierymudRs._destroyGeyserSubtree = destroyGeyserSubtree
FierymudRs._destroyGeyserWidget = destroyGeyserWidget

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

  -- Per-subsystem teardown. Each subsystem can register a
  -- `teardown` field on `_subsystems` to release widget refs
  -- and clear its `isReady` marker. Runs before the GUI
  -- containers go so subsystems can detach children first.
  for _, sub in pairs(FierymudRs._subsystems or {}) do
    if type(sub.teardown) == "function" then
      local ok, err = pcall(sub.teardown)
      if not ok then
        debugc(string.format("teardown %s failed: %s",
          tostring(sub.name or "?"), tostring(err)))
      end
    end
  end

  -- Tear down top-level GUI containers. Lua globals survive
  -- `sysUninstall`, so without this the next install's
  -- `Adjustable.Container:new` short-circuits via the
  -- `... or new()` idiom and we keep the *old* widgets (with
  -- old code) instead of rebuilding them.
  local containers = {
    "Vitals", "Right", "Chat and Map", "fiery_map",
    "Active Effects", "effects_window",
  }
  for _, name in ipairs(containers) do
    destroyGeyserWidget(name)
  end
  FierymudRs.GUI = {}

  -- Force the next `tryInit` to re-enter `setup`. Without this
  -- the post-reinstall handlers see `Initialized = true` and
  -- short-circuit, so source changes never take visual effect.
  FierymudRs.Initialized = nil

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

-- Belt-and-suspenders init kick. On a fresh Mudlet load the
-- `sysLoadEvent` / `sysInstall` handlers above pick up init
-- duties; on hot-reload (companion uninstalls + reinstalls
-- this package), `sysInstall` doesn't reliably reach the
-- newly-registered handler — sometimes it fires before
-- `bindHandlers` runs, sometimes the queued event is dropped
-- when the previous package's handler is deleted mid-flight.
-- Kick `scheduleTryInit` directly on every script-body
-- execution. `tryInit` is idempotent (short-circuits when
-- `Initialized` is true) and `scheduleTryInit` debounces via
-- a named timer, so the first-load path (sysLoadEvent also
-- fires) doesn't double-init.
scheduleTryInit()
