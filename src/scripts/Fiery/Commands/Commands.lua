Fierymud = Fierymud or {}
Fierymud.Commands = Fierymud.Commands or {}

function Fierymud.Commands:reload()
  resetProfile()
  print("Reloaded FieryMud")
  send("\n")
end

function Fierymud.Commands:reset()
  print("Resetting FieryMud GUI...")

  -- Kill timers
  if Fierymud.Effects and Fierymud.Effects.updateTimer then
    killTimer(Fierymud.Effects.updateTimer)
    Fierymud.Effects.updateTimer = nil
  end
  if Fierymud.Guages and Fierymud.Guages.ProfileChecker then
    killTimer(Fierymud.Guages.ProfileChecker)
    Fierymud.Guages.ProfileChecker = nil
  end

  -- Clear all state so the 'or' guards in setup() will create fresh objects
  Fierymud.GUI = nil
  Fierymud.Guages = nil
  Fierymud.Effects = nil
  Fierymud.Chat = nil
  Fierymud.OtherProfiles = nil
  Fierymud.Initialized = nil
  Fierymud.wizEnabled = nil
  Fierymud.EventHandlers = nil

  -- Reset borders
  setBorderLeft(0)
  setBorderRight(0)
  setBorderTop(0)
  setBorderBottom(0)

  -- resetProfile() properly destroys all Geyser objects and reloads scripts
  resetProfile()
  print("FieryMud GUI reset complete.")
end

function Fierymud.Commands:status()
  cecho("<green>FieryMud Status:<reset>\n")

  -- Version
  local version = getPackageInfo("FierymudOfficial", "version") or "Unknown"
  cecho("  <white>Version:<reset> " .. version .. "\n")

  -- Initialized state
  local init_status = Fierymud.Initialized and "<green>Yes" or "<red>No"
  cecho("  <white>Initialized:<reset> " .. init_status .. "<reset>\n")

  -- GUI enabled
  local gui_status = Fierymud.Config.enabled and "<green>Enabled" or "<red>Disabled"
  cecho("  <white>GUI:<reset> " .. gui_status .. "<reset>\n")

  -- Character info
  cecho("\n<green>Character:<reset>\n")
  if Fierymud.Character then
    cecho("  <white>Name:<reset> " .. (Fierymud.Character.name or "Unknown") .. "\n")
    cecho("  <white>Class:<reset> " .. (Fierymud.Character.class or "Unknown") .. "\n")
    cecho("  <white>Level:<reset> " .. (Fierymud.Character.level or 0) .. "\n")
    if Fierymud.Character.Vitals then
      cecho("  <white>HP:<reset> " .. (Fierymud.Character.Vitals.hp or 0) .. "/" .. (Fierymud.Character.Vitals.hp_max or 0) .. "\n")
      cecho("  <white>Move:<reset> " .. (Fierymud.Character.Vitals.move or 0) .. "/" .. (Fierymud.Character.Vitals.move_max or 0) .. "\n")
    end
    local combat_status = Fierymud.Character.in_combat and "<red>In Combat" or "<green>Not in Combat"
    cecho("  <white>Combat:<reset> " .. combat_status .. "<reset>\n")
  else
    cecho("  <red>No character data available<reset>\n")
  end

  -- Active effects
  cecho("\n<green>Active Effects:<reset>\n")
  if Fierymud.Effects and Fierymud.Effects.Active then
    local count = 0
    for name, effect in pairs(Fierymud.Effects.Active) do
      count = count + 1
      local minutes = math.ceil(effect.duration / 60)
      cecho("  <white>" .. name .. ":<reset> " .. minutes .. " min\n")
    end
    if count == 0 then
      cecho("  <grey>None<reset>\n")
    end
  else
    cecho("  <grey>None<reset>\n")
  end

  -- Ally profiles
  cecho("\n<green>Ally Profiles:<reset>\n")
  if Fierymud.OtherProfiles then
    local count = 0
    for profile, vitals in pairs(Fierymud.OtherProfiles) do
      count = count + 1
      cecho("  <white>" .. vitals.name .. "<reset> (Lvl " .. vitals.level .. " " .. vitals.class .. ")\n")
    end
    if count == 0 then
      cecho("  <grey>None<reset>\n")
    end
  else
    cecho("  <grey>None<reset>\n")
  end
end
