Fierymud = Fierymud or {}
Fierymud.Character = Fierymud.Character or {
  name = "Unnamed",
  class = "Unclassed",
  level = 0,
  exp_percent = 0,
  in_combat = false,
  Vitals = {
    hp = 1,
    hp_max = 1,
    move = 1,
    move_max = 1,
  }
}

-- Private functions
function Fierymud.Character:update()
  -- Guard against missing GMCP data
  if not gmcp or not gmcp.Char then return end
  if not gmcp.Char.Vitals then return end

  Fierymud.Character.name = gmcp.Char.name or Fierymud.Character.name
  Fierymud.Character.class = gmcp.Char.class or Fierymud.Character.class
  Fierymud.Character.level = gmcp.Char.level or Fierymud.Character.level
  Fierymud.Character.exp_percent = gmcp.Char.exp_percent or Fierymud.Character.exp_percent

  Fierymud.Character.Vitals.hp = gmcp.Char.Vitals.hp or Fierymud.Character.Vitals.hp
  Fierymud.Character.Vitals.hp_max = gmcp.Char.Vitals.max_hp or Fierymud.Character.Vitals.hp_max
  Fierymud.Character.Vitals.move = gmcp.Char.Vitals.mv or Fierymud.Character.Vitals.move
  Fierymud.Character.Vitals.move_max = gmcp.Char.Vitals.max_mv or Fierymud.Character.Vitals.move_max

  Fierymud.Guages:updateVitals(Fierymud.Character)

  -- Check combat status with proper nil handling
  if gmcp.Char.Combat and type(gmcp.Char.Combat) == "table" and not table.is_empty(gmcp.Char.Combat) then
    Fierymud.Character.in_combat = true
    Fierymud.Guages:updateCombat(gmcp.Char.Combat)
  elseif Fierymud.Character.in_combat then
    Fierymud.Character.in_combat = false
    Fierymud.Guages:clearCombat()
  end

  raiseGlobalEvent("onRemoteVitalsUpdate",
    Fierymud.Character.name,
    Fierymud.Character.class,
    Fierymud.Character.level,
    Fierymud.Character.Vitals.hp,
    Fierymud.Character.Vitals.hp_max,
    Fierymud.Character.Vitals.move,
    Fierymud.Character.Vitals.move_max,
    Fierymud.Character.exp_percent
  )
end

local function checkExternalProfiles()
  for profile, vitals in pairs(Fierymud.OtherProfiles) do
    vitals.ticks_since_update = vitals.ticks_since_update + 1
    if vitals.ticks_since_update > Fierymud.Config['vitals_life'] then
      Fierymud.OtherProfiles[profile] = nil
      Fierymud.Guages:removeGuage(profile)
    end
  end
end

-- Handle other profile information
function Fierymud.Character:onRemoteVitalsUpdate(name, class, level, hp, hp_max, move, move_max, exp_percent, profile)
  Fierymud.OtherProfiles = Fierymud.OtherProfiles or {}
  local vitals = {
    name = name,
    class = class,
    level = level,
    exp_percent = exp_percent,
    Vitals = {
      hp = hp,
      hp_max = hp_max,
      move = move,
      move_max = move_max
    },
    ticks_since_update = 0
  }
  Fierymud.OtherProfiles[profile] = vitals
  Fierymud.Guages:updateVitals(vitals, profile)
  if not Fierymud.Guages.ProfileChecker then
    Fierymud.Guages.ProfileChecker = tempTimer(1, checkExternalProfiles, true)
  end
end
