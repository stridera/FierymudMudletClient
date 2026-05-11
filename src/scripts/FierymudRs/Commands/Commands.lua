FierymudRs = FierymudRs or {}
FierymudRs.Commands = FierymudRs.Commands or {}

function FierymudRs.Commands:reload()
  resetProfile()
  print("Reloaded FieryMud")
  send("\n")
end

function FierymudRs.Commands:reset()
  print("Resetting FieryMud GUI...")

  -- Drop everything registered under our user namespace. Both
  -- helpers no-op when the registry is empty, so this is safe
  -- to run before resetProfile() re-binds fresh handlers.
  deleteAllNamedEventHandlers("FierymudRs")
  deleteAllNamedTimers("FierymudRs")

  -- Subsystem timers that aren't named-registered yet.
  if FierymudRs.Effects and FierymudRs.Effects.updateTimer then
    killTimer(FierymudRs.Effects.updateTimer)
    FierymudRs.Effects.updateTimer = nil
  end
  if FierymudRs.Guages and FierymudRs.Guages.ProfileChecker then
    killTimer(FierymudRs.Guages.ProfileChecker)
    FierymudRs.Guages.ProfileChecker = nil
  end

  -- Clear all state so the 'or' guards in setup() will create fresh objects
  FierymudRs.GUI = nil
  FierymudRs.Guages = nil
  FierymudRs.Effects = nil
  FierymudRs.Chat = nil
  FierymudRs.OtherProfiles = nil
  FierymudRs.Initialized = nil
  FierymudRs.wizEnabled = nil

  -- Reset borders
  setBorderLeft(0)
  setBorderRight(0)
  setBorderTop(0)
  setBorderBottom(0)

  -- resetProfile() properly destroys all Geyser objects and reloads scripts
  resetProfile()
  print("FieryMud GUI reset complete.")
end

function FierymudRs.Commands:status()
  cecho("<green>FieryMud Status:<reset>\n")

  -- Version
  local version = getPackageInfo("FierymudRs", "version") or "Unknown"
  cecho("  <white>Version:<reset> " .. version .. "\n")

  -- Initialized state
  local init_status = FierymudRs.Initialized and "<green>Yes" or "<red>No"
  cecho("  <white>Initialized:<reset> " .. init_status .. "<reset>\n")

  -- GUI enabled
  local gui_status = FierymudRs.Config.enabled and "<green>Enabled" or "<red>Disabled"
  cecho("  <white>GUI:<reset> " .. gui_status .. "<reset>\n")

  -- Character info
  cecho("\n<green>Character:<reset>\n")
  if FierymudRs.Character then
    cecho("  <white>Name:<reset> " .. (FierymudRs.Character.name or "Unknown") .. "\n")
    cecho("  <white>Class:<reset> " .. (FierymudRs.Character.class or "Unknown") .. "\n")
    cecho("  <white>Level:<reset> " .. (FierymudRs.Character.level or 0) .. "\n")
    if FierymudRs.Character.Vitals then
      cecho("  <white>HP:<reset> " .. (FierymudRs.Character.Vitals.hp or 0) .. "/" .. (FierymudRs.Character.Vitals.hp_max or 0) .. "\n")
      cecho("  <white>Move:<reset> " .. (FierymudRs.Character.Vitals.move or 0) .. "/" .. (FierymudRs.Character.Vitals.move_max or 0) .. "\n")
    end
    local combat_status = FierymudRs.Character.in_combat and "<red>In Combat" or "<green>Not in Combat"
    cecho("  <white>Combat:<reset> " .. combat_status .. "<reset>\n")
  else
    cecho("  <red>No character data available<reset>\n")
  end

  -- Active effects
  cecho("\n<green>Active Effects:<reset>\n")
  if FierymudRs.Effects and FierymudRs.Effects.Active then
    local count = 0
    for name, effect in pairs(FierymudRs.Effects.Active) do
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
  if FierymudRs.OtherProfiles then
    local count = 0
    for profile, vitals in pairs(FierymudRs.OtherProfiles) do
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
