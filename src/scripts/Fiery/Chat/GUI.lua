Fierymud = Fierymud or {}
Fierymud.Chat = Fierymud.Chat or {}

function Fierymud.Chat:setup()
  -- See all constraints here:  https://github.com/demonnic/EMCO/wiki/Valid-Constraints
  Fierymud.Chat = EMCO:new({
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
  }, Fierymud.GUI.chat_container)

  function Fierymud.Chat:fromTrigger(chat)
    if chat == "Wiz" and not Fierymud.wizEnabled then
      Fierymud.Chat:addTab("Wiz", 0)
      Fierymud.wizEnabled = true
    end

    selectCurrentLine()
    Fierymud.Chat:append(chat)
    deselect()
    resetFormat()

    if not hasFocus() and getOS() == "linux" then
      os.execute([[notify-send "Mudlet" "]] .. getCurrentLine() .. [["]])
    end
  end

  function Fierymud.Chat:onRemoteTell(to, from, msg, profile)
    text = from .." told "..to..", "..msg.."\n"
    Fierymud.Chat:cecho('Tells', text)
  end

end
