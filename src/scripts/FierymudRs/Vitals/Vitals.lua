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

-- GMCP package shapes from mud-server::commands::send_prompt
-- (IRE convention; matches Mudlet stock gauge bindings):
--   Char.Vitals  → { hp, maxhp, mp, maxmp, mv, maxmv, nl, string }
--   Char.Status  → { name, level, xp, class, race, wealth }
--   Char.Name    → { name, fullname }
-- Stamina maps onto `mv`/`maxmv` so Mudlet's stock movement
-- gauge (Geyser.Gauge.SP / VP) renders without a per-MUD
-- override. Mana fields are present-but-zero — we don't have
-- mana yet; clients that don't draw 0/0 gauges skip rendering.
function FierymudRs.Character:update()
  if not gmcp or not gmcp.Char then return end
  if not gmcp.Char.Vitals then return end

  -- Identity / level / class / race come from Char.Status.
  if gmcp.Char.Status then
    FierymudRs.Character.name = gmcp.Char.Status.name or FierymudRs.Character.name
    FierymudRs.Character.class = gmcp.Char.Status.class or FierymudRs.Character.class
    FierymudRs.Character.level = gmcp.Char.Status.level or FierymudRs.Character.level
  end
  -- exp_percent comes from Char.Vitals.nl (IRE convention).
  if gmcp.Char.Vitals.nl then
    FierymudRs.Character.exp_percent = gmcp.Char.Vitals.nl
  end

  FierymudRs.Character.Vitals.hp = gmcp.Char.Vitals.hp or FierymudRs.Character.Vitals.hp
  FierymudRs.Character.Vitals.hp_max = gmcp.Char.Vitals.maxhp or FierymudRs.Character.Vitals.hp_max
  FierymudRs.Character.Vitals.move = gmcp.Char.Vitals.mv or FierymudRs.Character.Vitals.move
  FierymudRs.Character.Vitals.move_max = gmcp.Char.Vitals.maxmv or FierymudRs.Character.Vitals.move_max

  FierymudRs.Guages:updateVitals(FierymudRs.Character)

  -- Group panel refresh — server sends gmcp.Group every prompt.
  if FierymudRs.Guages.updateGroup then
    FierymudRs.Guages:updateGroup()
  end

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
