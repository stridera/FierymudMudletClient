Fierymud = Fierymud or {}
Fierymud.Commands = Fierymud.Commands or {}

function Fierymud.Commands:reload()
  resetProfile()
  print("Reloaded FieryMud")
  send("\n")
end
