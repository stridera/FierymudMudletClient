Fierymud = Fierymud or {}
 
Fierymud.right_container = Fierymud.right_container or Geyser.Container:new({
  name = 'right_container',
  x = "-20%", y = 0,
  width = "20%", height = '100%'
})
 
Fierymud.chat_container = Fierymud.chat_container or Geyser.Container:new({
  name = 'chat_container',
  x = 0, y = 0,
  width = "100%", height = '60%'
}, Fierymud.right_container)
   
Fierymud.Map = Geyser.Mapper:new({
  name = "myMap",
  x = 0, y = "-40%",
  width = "100%",
  height = "40%",
}, Fierymud.right_container)