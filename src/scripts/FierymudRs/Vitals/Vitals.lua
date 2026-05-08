FierymudRs = FierymudRs or {}
FierymudRs.Character = FierymudRs.Character or {
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

-- GMCP package shapes from mud-server::commands::send_prompt:
--   Char.Vitals  → { hp, max_hp, sp, max_sp, level }
--   Char.Status  → { name, level, xp, class, race, wealth }
-- Note `sp` / `max_sp` (stamina) replaces the legacy `mv` /
-- `max_mv` field name. Keep the local field names `move` /
-- `move_max` so the gauge code stays stable; just remap.
function FierymudRs.Character:update()
  if not gmcp or not gmcp.Char then return end
  if not gmcp.Char.Vitals then return end

  -- Identity / level / xp come from Char.Status.
  if gmcp.Char.Status then
    FierymudRs.Character.name = gmcp.Char.Status.name or FierymudRs.Character.name
    FierymudRs.Character.class = gmcp.Char.Status.class or FierymudRs.Character.class
    FierymudRs.Character.level = gmcp.Char.Status.level or FierymudRs.Character.level
    -- Server emits raw xp; estimate percent from level catalog
    -- once we wire that resource. For now leave exp_percent at
    -- whatever Vitals last reported (or default).
  end

  FierymudRs.Character.Vitals.hp = gmcp.Char.Vitals.hp or FierymudRs.Character.Vitals.hp
  FierymudRs.Character.Vitals.hp_max = gmcp.Char.Vitals.max_hp or FierymudRs.Character.Vitals.hp_max
  FierymudRs.Character.Vitals.move = gmcp.Char.Vitals.sp or FierymudRs.Character.Vitals.move
  FierymudRs.Character.Vitals.move_max = gmcp.Char.Vitals.max_sp or FierymudRs.Character.Vitals.move_max

  FierymudRs.Guages:updateVitals(FierymudRs.Character)

  -- Check combat status with proper nil handling
  if gmcp.Char.Combat and type(gmcp.Char.Combat) == "table" and not table.is_empty(gmcp.Char.Combat) then
    FierymudRs.Character.in_combat = true
    FierymudRs.Guages:updateCombat(gmcp.Char.Combat)
  elseif FierymudRs.Character.in_combat then
    FierymudRs.Character.in_combat = false
    FierymudRs.Guages:clearCombat()
  end

  raiseGlobalEvent("onRemoteVitalsUpdate",
    FierymudRs.Character.name,
    FierymudRs.Character.class,
    FierymudRs.Character.level,
    FierymudRs.Character.Vitals.hp,
    FierymudRs.Character.Vitals.hp_max,
    FierymudRs.Character.Vitals.move,
    FierymudRs.Character.Vitals.move_max,
    FierymudRs.Character.exp_percent
  )
end

local function checkExternalProfiles()
  for profile, vitals in pairs(FierymudRs.OtherProfiles) do
    vitals.ticks_since_update = vitals.ticks_since_update + 1
    if vitals.ticks_since_update > FierymudRs.Config['vitals_life'] then
      FierymudRs.OtherProfiles[profile] = nil
      FierymudRs.Guages:removeGuage(profile)
    end
  end
end

-- Handle other profile information
function FierymudRs.Character:onRemoteVitalsUpdate(name, class, level, hp, hp_max, move, move_max, exp_percent, profile)
  FierymudRs.OtherProfiles = FierymudRs.OtherProfiles or {}
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
  FierymudRs.OtherProfiles[profile] = vitals
  FierymudRs.Guages:updateVitals(vitals, profile)
  if not FierymudRs.Guages.ProfileChecker then
    FierymudRs.Guages.ProfileChecker = tempTimer(1, checkExternalProfiles, true)
  end
end
