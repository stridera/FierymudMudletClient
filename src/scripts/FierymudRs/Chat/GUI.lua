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
    timestampFGColor = "red",
    timestampBGColor = "blue",
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
    fontSize = 9,
    preserveBackground = false,
    gag = false,
    activeTabBGColor = "<0,180,0>",
    inactiveTabBGColor = "<60,60,60>",
    consoleColor = "<0,0,0>",
    activeTabFGColor = "purple",
    inactiveTabFGColor = "white"
  }, FierymudRs.GUI.chat_container)

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
    if FierymudRs.Config.disable_chat then return end
    local text = from .. " told " .. to .. ", " .. msg .. "\n"
    FierymudRs.Chat:cecho('Tells', text)
  end

end
