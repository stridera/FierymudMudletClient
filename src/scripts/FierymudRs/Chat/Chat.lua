FierymudRs = FierymudRs or {}
FierymudRs.Chat = FierymudRs.Chat or {}

function FierymudRs.Chat:setup()
  -- See all constraints here:  https://github.com/demonnic/EMCO/wiki/Valid-Constraints
  FierymudRs.Chat = EMCO:new({
    x = 0,
    y = 0,
    width = "100%",
    height = "100%",
    timestamp = true,
    timestampFormat = "HH:mm:ss",
    customTimestampColor = false,
    timestampFGColor = "dim_grey",
    timestampBGColor = "black",
    consoles = {
      "All",
      "Tells",
      "Gossip",
      "Group",
      "Local"
    },
    allTab = true,
    allTabName = "All",
    mapTab = false,
    blink = true,
    blinkFromAll = false,
    fontSize = 10,
    tabHeight = 28,
    preserveBackground = false,
    gag = false,
    activeTabBGColor = "<0,180,0>",
    inactiveTabBGColor = "<60,60,60>",
    consoleColor = "<0,0,0>",
    activeTabFGColor = "white",
    inactiveTabFGColor = "<200,200,200>"
  }, FierymudRs.GUI.chat_container)

  -- Tab re-layout helper. Geyser HBox uses calculate_dynamic_window_size
  -- which depends on the parent's actual rendered width. Adjustable.Container
  -- defers its border attach by 200ms+, so the first organize() runs
  -- against a stub parent and produces wonky widths. Calling organize()
  -- after the parent has settled re-runs the math against real geometry.
  local function balanceTabs()
    local chat = FierymudRs.Chat
    if not chat or not chat.tabBox then return end
    pcall(function() chat.tabBox:organize() end)
  end
  balanceTabs()
  FierymudRs.Chat._balanceTabs = balanceTabs

  function FierymudRs.Chat:fromTrigger(chat)
    if chat == "Wiz" and not table.contains(self.consoles, "Wiz") then
      self:addTab("Wiz", 0)
    end

    selectCurrentLine()
    self:append(chat)
    deselect()
    resetFormat()

    if not hasFocus() and FierymudRs.Config.os_alerts then
      showNotification("Mudlet - FierymudRs", getCurrentLine())
    end
  end

  function FierymudRs.Chat:onRemoteTell(to, from, msg, profile)
    -- Cross-profile relay path. Other Mudlet profiles raise the
    -- `onTell` event when they receive a tell; we surface that
    -- in the local Tells tab so a multi-character setup shares
    -- the chat history without each profile needing its own
    -- triggers.
    if FierymudRs.Config.disable_chat then return end
    local text = from .. " told " .. to .. ", " .. msg .. "\n"
    FierymudRs.Chat:cecho('Tells', text)
  end

  -- GMCP-driven chat routing. Server emits `Comm.Channel.Text`
  -- with `{channel, talker, text}` for every channel message;
  -- we map `channel` to a tab + color and cecho the body.
  -- Replaces screen-scraping regex triggers (the old Wiznet
  -- trigger, for example, was hardcoded to a static staff name
  -- list and broke whenever someone new immortted).
  --
  -- Unknown channels fall back to the All tab so a server-side
  -- channel addition doesn't get silently dropped while the
  -- package catches up.
  --
  -- Tabs that don't exist in the EMCO at startup (Wiz, Music,
  -- Quest, Clan) get auto-added on first use — no fixed
  -- `consoles` array bloat for channels the player may never
  -- touch.
  -- Per-channel STYLES — local preference for color, sound, and
  -- self-name highlighting. The server doesn't dictate these
  -- (it's purely a client choice), so the styles map lives here.
  -- Keys are the GMCP channel name (matches the `channel` field
  -- in `Comm.Channel.Text` frames).
  --
  -- `highlightSelf`: color-flag the player's own name when
  -- another speaker mentions it. Useful for catching mentions
  -- in busy gossip streams.
  -- `sound`: optional path passed to playSoundFile when a
  -- message arrives on a non-active tab. nil = silent.
  FierymudRs.Chat.channelStyles = {
    gossip  = { color = "<yellow>",   highlightSelf = true },
    music   = { color = "<magenta>" },
    shout   = { color = "<b:red>",    highlightSelf = true },
    quest   = { color = "<b:green>",  highlightSelf = true },
    wiznet  = { color = "<cyan>",     highlightSelf = true },
    tells   = { color = "<cyan>",     highlightSelf = true },
    clan    = { color = "<b:yellow>", highlightSelf = true },
    group   = { color = "<white>",    highlightSelf = true },
    say     = { color = "<green>",    highlightSelf = true },
    emote   = { color = "<white>" },
    ask     = { color = "<dim_grey>" },
    whisper = { color = "<dim_grey>", highlightSelf = true },
    insult  = { color = "<red>",      highlightSelf = true },
  }

  -- Resolved channel routing — populated either from the
  -- server's `Comm.Channel.List` push (preferred — server-aware)
  -- or from the static fallback baked in below for legacy
  -- servers / pre-list connections. `tab` is the EMCO tab name
  -- (auto-created on first use); the `color`/`highlightSelf`
  -- fields come from `channelStyles` keyed by channel name.
  FierymudRs.Chat.channelTabs = {
    gossip  = { tab = "Gossip", color = "<yellow>",   highlightSelf = true },
    music   = { tab = "Music",  color = "<magenta>" },
    shout   = { tab = "Local",  color = "<b:red>",    highlightSelf = true },
    quest   = { tab = "Quest",  color = "<b:green>",  highlightSelf = true },
    wiznet  = { tab = "Wiz",    color = "<cyan>",     highlightSelf = true },
    tells   = { tab = "Tells",  color = "<cyan>",     highlightSelf = true },
    clan    = { tab = "Clan",   color = "<b:yellow>", highlightSelf = true },
    group   = { tab = "Group",  color = "<white>",    highlightSelf = true },
    say     = { tab = "Local",  color = "<green>",    highlightSelf = true },
    emote   = { tab = "Local",  color = "<white>" },
    ask     = { tab = "Local",  color = "<dim_grey>" },
    whisper = { tab = "Local",  color = "<dim_grey>", highlightSelf = true },
    insult  = { tab = "Local",  color = "<red>",      highlightSelf = true },
  }

  -- Apply a server-pushed `Comm.Channel.List` directory.
  -- Replaces the entire channelTabs map so role-gated channels
  -- (wiznet for immortals only) auto-disappear from the client
  -- when the server stops listing them. The local `channelStyles`
  -- preferences are merged in by name; channels the server lists
  -- but we have no style for fall back to plain white.
  function FierymudRs.Chat:applyChannelList(list)
    if type(list) ~= "table" then return end
    local newTabs = {}
    for _, entry in ipairs(list) do
      if type(entry) == "table" and entry.name then
        local style = self.channelStyles[entry.name] or {}
        newTabs[entry.name] = {
          tab = entry.caption or entry.name,
          color = style.color or "<white>",
          highlightSelf = style.highlightSelf,
          sound = style.sound,
          command = entry.command,
        }
      end
    end
    self.channelTabs = newTabs
  end

  function FierymudRs.Chat:onCommChannelList()
    local list = gmcp and gmcp.Comm and gmcp.Comm.Channel
                 and gmcp.Comm.Channel.List
    self:applyChannelList(list)
  end

  -- Per-channel message format. The server emits {channel, talker,
  -- text}; channels render the same line three different ways
  -- (gossip uses third-person verb, tells uses "tells you", wiznet
  -- brackets the talker). Default falls through to "talker: text"
  -- so a newly-introduced channel still shows the sender.
  FierymudRs.Chat.channelFormat = {
    gossip  = '%s gossips, "%s"',
    music   = '%s sings, "%s"',
    shout   = '%s shouts, "%s"',
    quest   = '[Quest] %s: %s',
    wiznet  = '[%s] %s',
    tells   = '%s tells you, "%s"',
    clan    = '[%s] %s',
    group   = '%s tellgroups, "%s"',
    say     = '%s says, "%s"',
    emote   = '%s %s',
    ask     = '%s asks, "%s"',
    whisper = '%s whispers to you, "%s"',
    insult  = '%s insults you, "%s"',
  }

  -- Color used for self-name highlights. Bright yellow on bold
  -- contrasts every channel's body color without colliding with
  -- any of them. After `<reset>` we re-prepend the channel's open
  -- color so the rest of the line keeps its tab tint.
  FierymudRs.Chat.selfHighlightColor = "<b:yellow>"

  -- Plain-text replace, escaping pattern characters in the
  -- player name so unusual characters in legacy character names
  -- (rare but possible) don't get treated as Lua patterns. Runs
  -- on the body only; channel/talker fields stay raw.
  local function highlightSelf(text, name, channelColor)
    if not name or name == "" then return text end
    -- Escape Lua pattern magic chars in the search literal.
    local pat = name:gsub("([%-%.%+%[%]%(%)%$%^%%%?%*])", "%%%1")
    return (text:gsub(pat,
      FierymudRs.Chat.selfHighlightColor .. name .. "<reset>" .. channelColor))
  end

  function FierymudRs.Chat:onCommChannelText()
    if FierymudRs.Config.disable_chat then return end
    local frame = gmcp and gmcp.Comm and gmcp.Comm.Channel and gmcp.Comm.Channel.Text
    if type(frame) ~= "table" then return end
    local channel = frame.channel or ""
    local talker = frame.talker or ""
    local text = frame.text or ""
    if text == "" then return end

    local route = self.channelTabs[channel]
    local tab = route and route.tab or "All"
    local color = route and route.color or "<white>"

    if not table.contains(self.consoles, tab) then
      self:addTab(tab, 0)
    end

    -- Render the line with the channel's preferred phrasing
    -- (e.g. 'Mejna gossips, "..."') so the speaker is visible.
    -- Falls back to "talker: text" for unknown channels.
    local fmt = self.channelFormat[channel] or "%s: %s"
    local body
    if talker == "" then
      body = text
    else
      body = string.format(fmt, talker, text)
    end

    -- Self-mention highlight. Skip when the player is the talker
    -- (no point flagging their own name in their own gossip)
    -- and only when the route opted in.
    local selfName = FierymudRs.Character and FierymudRs.Character.name
    local mentioned = false
    if route and route.highlightSelf and selfName and talker ~= selfName then
      local before = body
      body = highlightSelf(body, selfName, color)
      mentioned = (body ~= before)
    end

    self:cecho(tab, color .. body .. "<reset>\n")

    -- Sound alert when the tab is not the currently active one
    -- (active tab already gets the player's eye). Self-mentions
    -- play even on the active tab — they're the loudest signal.
    if route and route.sound and (mentioned or self.currentTab ~= tab) then
      pcall(playSoundFile, route.sound)
    end

    -- Fan tells out to other Mudlet profiles via the legacy
    -- onTell channel (cross-profile chat aggregator).
    if channel == "tells" and selfName then
      raiseGlobalEvent("onTell", selfName, talker, text)
    end

    if not hasFocus() and FierymudRs.Config.os_alerts then
      showNotification("Mudlet - FierymudRs [" .. channel .. "]", text)
    end
  end

  -- Adjustable.Container defers border-attachment via tempTimer
  -- chains; EMCO's createContainers runs synchronously against the
  -- right_container's pre-attach stub geometry, baking a 27px tab
  -- strip and a `-0px` console area against a parent height of ~0.
  -- Result: only the tab strip paints; manually dragging the panel
  -- triggers :reposition() and snaps the console open.
  --
  -- Two fixes layered: (1) listen for sysWindowResizeEvent so any
  -- main-window-border change cascades a reposition through the
  -- chat tree; (2) a delayed kick at 1.5s as a safety net for the
  -- case where the initial border-attach doesn't raise the resize
  -- event (or fires before our handler is registered).
  --
  -- Named handler so repeated Chat:setup calls replace in place
  -- instead of stacking.
  local function cascadeReposition()
    if FierymudRs.GUI and FierymudRs.GUI.chat_container then
      pcall(function() FierymudRs.GUI.chat_container:reposition() end)
    end
    -- Rebalance tabs every time the layout settles — handles
    -- the initial-load case AND any post-load tab additions
    -- (e.g. Wiz auto-added on first wiznet message). The
    -- balanceTabs closure is set inside Chat:setup just above.
    if FierymudRs.Chat and FierymudRs.Chat._balanceTabs then
      pcall(FierymudRs.Chat._balanceTabs)
    end
  end
  registerNamedEventHandler("FierymudRs", "Chat.resize",
    "sysWindowResizeEvent", cascadeReposition)
  -- Multi-kick: 0.5s catches the fast path, 1.5s catches the
  -- slow path where Adjustable.Container's tempTimer chain
  -- hasn't fully settled, and 3s is the safety net for stubborn
  -- Qt sub-pixel reshuffling on Windows.
  tempTimer(0.5, cascadeReposition)
  tempTimer(1.5, cascadeReposition)
  tempTimer(3.0, cascadeReposition)
end

-- Register with the subsystem registry. The master setup loop
-- in GUI.lua iterates the registry instead of hardcoding names,
-- so adding/removing subsystems doesn't touch lifecycle code.
-- isReady picks the post-setup marker `channelTabs` (only set
-- by `:setup`) to detect "already initialized" cleanly.
FierymudRs._subsystems = FierymudRs._subsystems or {}
FierymudRs._subsystems.Chat = {
  name = "Chat",
  setup = function() FierymudRs.Chat:setup() end,
  isReady = function()
    return type(FierymudRs.Chat) == "table"
       and FierymudRs.Chat.channelTabs ~= nil
  end,
  -- Chat:setup reassigns FierymudRs.Chat to an EMCO instance;
  -- on hot-reload we nuke that whole subtree so the next
  -- reinstall's `Chat = Chat or {}` lands on a plain table and
  -- EMCO:new can re-claim its tab-console names.
  teardown = function()
    if FierymudRs._destroyGeyserSubtree and type(FierymudRs.Chat) == "table" then
      FierymudRs._destroyGeyserSubtree(FierymudRs.Chat)
    end
    FierymudRs.Chat = nil
  end,
}
