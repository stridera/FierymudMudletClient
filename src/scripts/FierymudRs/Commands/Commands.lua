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

-- Dump the Geyser widget tree as a hierarchical text summary.
-- Used by the dev iteration loop so an agent can verify layout
-- changes without paying for a screenshot read; covers cases
-- where a widget is created but invisible (off-screen, zero
-- size, hidden) that a pixel grab can't tell apart from "not
-- created at all".
--
-- Writes to `<repo>/state/layout.txt` when MuddlerReload (the
-- companion package) is installed and exposes its `repoPath` —
-- that's the dev-machine UNC into WSL. Otherwise falls back to
-- `getMudletHomeDir() .. "/layout.txt"` inside the profile dir.
function FierymudRs.Commands:dumpLayout(pathOverride)
  local repoBase = MuddlerReload and MuddlerReload.repoPath
  local path
  if pathOverride and pathOverride ~= "" then
    path = pathOverride
  elseif repoBase then
    path = repoBase .. "/state/layout.txt"
  else
    path = (getMudletHomeDir():gsub("\\", "/")) .. "/layout.txt"
  end

  local lines = {}
  local function emit(s) lines[#lines + 1] = s end

  local function describe(w)
    local parts = { w.type or "?", w.name or "(unnamed)" }
    if w.hidden ~= nil then
      parts[#parts + 1] = w.hidden and "[hidden]" or "[visible]"
    end
    -- Position/size — Geyser stashes raw constraints in fields
    -- whose names vary by class. Cover the common ones; missing
    -- fields just drop out.
    local geom = {}
    for _, field in ipairs({ "x", "y", "width", "height" }) do
      local v = w[field]
      if v ~= nil then geom[#geom + 1] = field .. "=" .. tostring(v) end
    end
    if #geom > 0 then
      parts[#parts + 1] = "(" .. table.concat(geom, ", ") .. ")"
    end
    return table.concat(parts, " ")
  end

  local function walk(w, depth, seen)
    if not w or seen[w] then return end
    seen[w] = true
    emit(string.rep("  ", depth) .. describe(w))
    if type(w.windowList) == "table" then
      -- Sort by name for stable diffs across runs.
      local names = {}
      for n in pairs(w.windowList) do names[#names + 1] = n end
      table.sort(names)
      for _, n in ipairs(names) do
        walk(w.windowList[n], depth + 1, seen)
      end
    end
  end

  emit(string.format("# Geyser layout dump  %s", os.date("!%Y-%m-%dT%H:%M:%SZ")))
  emit(string.format("# Mudlet home: %s", getMudletHomeDir()))
  emit("")

  local seen = {}
  if Geyser and Geyser.windowList then
    -- Top-level: walk every widget that doesn't appear as a
    -- child elsewhere. Simpler: walk *all* entries; the `seen`
    -- table dedupes when a recursive descent revisits one.
    local names = {}
    for n in pairs(Geyser.windowList) do names[#names + 1] = n end
    table.sort(names)
    for _, n in ipairs(names) do
      walk(Geyser.windowList[n], 0, seen)
    end
  else
    emit("Geyser.windowList not available")
  end

  local body = table.concat(lines, "\n") .. "\n"
  local f, err = io.open(path, "w")
  if not f then
    cecho(string.format(
      "<red>fm layout: cannot open %s — %s<reset>\n",
      path, tostring(err)
    ))
    return
  end
  f:write(body)
  f:close()
  cecho(string.format(
    "<green>fm layout: wrote %d widgets to <yellow>%s<reset>\n",
    #lines, path
  ))
end

-- Read the error log written by FierymudRs.logError. Each
-- subsystem failure during setup() lands here, plus any
-- non-fatal pcall'd error path explicitly routed through it.
-- Useful when an external dev-loop agent needs to learn what
-- broke without screenshotting Mudlet's main console.
function FierymudRs.Commands:showErrors(lastN)
  lastN = tonumber(lastN) or 20
  local path
  if MuddlerReload and MuddlerReload.repoPath then
    path = MuddlerReload.repoPath .. "/state/errors.txt"
  else
    path = (getMudletHomeDir():gsub("\\", "/")) .. "/errors.txt"
  end
  local f = io.open(path, "r")
  if not f then
    cecho(string.format(
      "<grey>no error log at <yellow>%s<reset>\n", path
    ))
    return
  end
  local lines = {}
  for line in f:lines() do lines[#lines + 1] = line end
  f:close()
  if #lines == 0 then
    cecho(string.format(
      "<grey>error log empty (<yellow>%s<grey>)<reset>\n", path
    ))
    return
  end
  local start = math.max(1, #lines - lastN + 1)
  cecho(string.format(
    "<grey># Last %d of %d entries from <yellow>%s<reset>\n",
    #lines - start + 1, #lines, path
  ))
  for i = start, #lines do
    cecho("<red>" .. lines[i] .. "<reset>\n")
  end
end

function FierymudRs.Commands:clearErrors()
  local path
  if MuddlerReload and MuddlerReload.repoPath then
    path = MuddlerReload.repoPath .. "/state/errors.txt"
  else
    path = (getMudletHomeDir():gsub("\\", "/")) .. "/errors.txt"
  end
  local f = io.open(path, "w")
  if f then f:close() end
  cecho(string.format("<green>cleared <yellow>%s<reset>\n", path))
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
