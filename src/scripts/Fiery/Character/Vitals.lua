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
  Fierymud.Character.name = gmcp.Char.name
  Fierymud.Character.class = gmcp.Char.class
  Fierymud.Character.level = gmcp.Char.level
  Fierymud.Character.exp_percent = gmcp.Char.exp_percent

  Fierymud.Character.Vitals.hp = gmcp.Char.Vitals.hp
  Fierymud.Character.Vitals.hp_max = gmcp.Char.Vitals.max_hp
  Fierymud.Character.Vitals.move = gmcp.Char.Vitals.mv
  Fierymud.Character.Vitals.move_max = gmcp.Char.Vitals.max_mv

  Fierymud.Guages:updateVitals(Fierymud.Character.name, Fierymud.Character)
  if not table.is_empty(gmcp.Char.Combat) then
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

-- Handle other profile information
function Fierymud.Character:onRemoteVitalsUpdate(event, name, class, level, hp, hp_max, move, move_max, exp_percent, profile)
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
		}
  }
  Fierymud.OtherProfiles[profile] = vitals
  Fierymud.Guages:updateVitals(profile, vitals)
end