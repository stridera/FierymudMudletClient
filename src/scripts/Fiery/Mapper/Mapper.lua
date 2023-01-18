-- Fierymud Mapping Script

uninstallPackage("generic_mapper") -- Remove existing generic mapper if installed to prevent clashes.

mudlet = mudlet or {}
mudlet.mapper_script = true

Fierymud = Fierymud or {}
Fierymud.Mapper = Fierymud.Mapper or {}

Fierymud.Mapper.enabled = true
Fierymud.Mapper.current_room = -1
Fierymud.Mapper.current_area = -1

Fierymud.Mapper.config = {
  enabled = true,
  speedwalk_delay = 0,
}

local exitmap = { n = 'north', e = 'east', w = 'west', s = 'south', u = 'up', d = 'down' }
local coordmap = { n = { 0, 1, 0 }, e = { 1, 0, 0 }, w = { -1, 0, 0 }, s = { 0, -1, 0 }, u = { 0, 0, 1 },
  d = { 0, 0, -1 } }

local sectors = {
  Structure     = { id = 100, weight = 1, rgba = { 153, 0, 153, 255 } }, -- purple
  City          = { id = 101, weight = 1, rgba = { 153, 76, 0, 255 } }, -- burnt orange
  Field         = { id = 102, weight = 2, rgba = { 0, 153, 0, 255 } }, -- green
  Forest        = { id = 103, weight = 3, rgba = { 0, 51, 0, 255 } }, -- dark green
  Mountains     = { id = 104, weight = 6, rgba = { 128, 128, 128, 255 } }, -- gray
  Shallows      = { id = 105, weight = 4, rgba = { 0, 102, 204, 255 } }, -- pale blue
  Water         = { id = 106, weight = 2, rgba = { 102, 178, 255, 255 } }, -- light blue
  Underwater    = { id = 107, weight = 5, rgba = { 0, 0, 102, 255 } }, -- dark blue
  Air           = { id = 108, weight = 1, rgba = { 102, 178, 255, 127 } }, -- transparent light blue
  Road          = { id = 109, weight = 2, rgba = { 244, 164, 96, 255 } }, -- sandy brown
  Grasslands    = { id = 110, weight = 2, rgba = { 124, 252, 0, 255 } }, -- lawn green
  Cave          = { id = 111, weight = 2, rgba = { 105, 105, 105, 255 } }, -- light gray
  Ruins         = { id = 112, weight = 2, rgba = { 210, 180, 140, 255 } }, -- tan
  Swamp         = { id = 113, weight = 4, rgba = { 0, 102, 0, 255 } }, -- darkish green
  Beach         = { id = 114, weight = 2, rgba = { 255, 215, 0, 255 } }, -- gold
  Underdark     = { id = 115, weight = 2, rgba = { 128, 0, 0, 255 } }, -- maroon
  Astraplane    = { id = 116, weight = 1, rgba = { 255, 255, 255, 255 } }, -- White
  Airplane      = { id = 117, weight = 1, rgba = { 255, 255, 255, 255 } }, -- White
  Fireplane     = { id = 118, weight = 1, rgba = { 255, 255, 255, 255 } }, -- White
  Earthplane    = { id = 119, weight = 1, rgba = { 255, 255, 255, 255 } }, -- White
  Etherealplane = { id = 120, weight = 1, rgba = { 255, 255, 255, 255 } }, -- White
  Avernus       = { id = 121, weight = 1, rgba = { 255, 255, 255, 255 } }, -- White
}

local function find_area(name)
  -- searches for the named area, and creates it if necessary
  local areas = getAreaTable()
  local area_id
  for k, v in pairs(areas) do
    if string.lower(name) == string.lower(k) then
      area_id = v
      break
    end
  end
  if not area_id then area_id = addAreaName(name) end
  if not area_id then
    cecho("<red>Invalid Area. No such area found, and area could not be added.<reset>")
    return -1
  end
  Fierymud.Mapper.currentArea = area_id
  return area_id
end

local function find_area_limits(area_id)
  -- used to find min and max coordinate limits for an area
  if not area_id then
    error("Find Limits: Missing area ID", 2)
  end
  local rooms = getAreaRooms(area_id)
  local minx, miny, minz = getRoomCoordinates(rooms[0])
  local maxx, maxy, maxz = minx, miny, minz
  local x, y, z
  for k, v in pairs(rooms) do
    x, y, z = getRoomCoordinates(v)
    minx = math.min(x, minx)
    maxx = math.max(x, maxx)
    miny = math.min(y, miny)
    maxy = math.max(y, maxy)
    minz = math.min(z, minz)
    maxz = math.max(z, maxz)
  end
  return minx, maxx, miny, maxy, minz, maxz
end

local function set_room_position(room_id, area_id)
  if not area_id or area_id == -1 or not type(area_id) == "number" or not room_id or room_id == -1 then
    cecho("<red>Invalid area or room id in set_room_position.")
  end

  local x, y, z = unpack({ 0, 0, 0 })

  -- If there is currently nothing at 0, 0, 0, then set the first room to that position
  if next(getRoomsByPosition(area_id, 0, 0, 0)) ~= nil then
    -- If we are here, it means that we found ourself in a room that is not connected to another
    -- room we have been in.  For example, we teleported or came in via another exit.  Lets throw
    -- it off to the side and mark it as orphaned and we'll check new rooms as they're added and
    -- eventually link it back to the main room.
    local minx, maxx, miny, maxy, minz, maxz = find_area_limits(area_id)
    if math.abs(minx) < maxx then x = minx - 50 else x = maxx + 50 end
    if math.abs(miny) < maxy then y = miny - 50 else y = maxy + 50 end
    z = 0
    setRoomUserData(room_id, "is_orphaned", "true")
  end

  setRoomCoordinates(room_id, x, y, z)
end

local function check_exits(room_id, exits)
  local existing_exits = getRoomExits(room_id)
  local dx, dy, dz = getRoomCoordinates(room_id)


  for dir, dir_name in pairs(exitmap) do -- Step through each exit
    -- We check to see if the exit exists already.  This means that the first time we see a
    -- door, we keep it in that state.  (So if a door was locked, we remember it was locked.)
    if not existing_exits[dir] then
      local exit = exits[string.upper(dir)]
      if exit then
        local to_room = exit.to_room

        if not roomExists(to_room) then
          addRoom(to_room)

          local coords = coordmap[dir]
          setRoomCoordinates(to_room, dx + coords[1], dy + coords[2], dz + coords[3])

          if getRoomUserData(to_room, "is_orphaned") == "true" then
            setRoomUserData(to_room, "is_orphaned", "true")
          end
        end

        setExit(room_id, to_room, dir)
        if exit.is_door then
          -- 1 means open door (will draw a green square on exit),
          -- 2 means closed door (yellow square)
          -- 3 means locked door (red square).
          local door_status = 1
          if exit.door == "closed" then
            door_status = 2
          elseif exit.door == "locked" then
            door_status = 3
          end


          setDoor(room_id, dir, door_status)
          setRoomUserData(room_id, "door_name_" .. dir_name, exit.door_name)
        end
      end
    end
  end
end

local function set_structure(room_id, room_type)
  local env = sectors[room_type]
  local r, g, b, a = unpack(env.rgba)
  setRoomEnv(room_id, env.id)
  setCustomEnvColor(env.id, r, g, b, a)
  setRoomWeight(room_id, env.weight)
end

function doSpeedWalk()
  print("Path to " .. getRoomName(speedWalkPath[#speedWalkPath]) .. ": " .. table.concat(speedWalkDir, ", "))

  if Fierymud.Character.level > 99 then
    print("You're a god.  Where you're going, you don't need roads!")
    send("goto " .. speedWalkPath[#speedWalkPath])
    return
  end

  local delay = 0.5
  local path = table.deepcopy(speedWalkDir)
  local next_step
  next_step = function() send(table.remove(path, 1)) if #path > 0 then tempTimer(delay, next_step) end end
  next_step()
end

function Fierymud.Mapper.on_prompt()
  if not gmcp or not Fierymud.Mapper.config.enabled then return end

  if gmcp and gmcp.Room then
    local room = gmcp.Room

    area_id = find_area(room.zone)

    if area_id == -1 then
      return
    end

    Fierymud.Mapper.current_room = room.id

    if not roomExists(room.id) then
      addRoom(room.id)
      set_room_position(room.id, area_id)
    end

    -- No harm to updating this every time, right?
    setRoomName(room.id, room.name)
    setRoomArea(room.id, area_id)
    set_structure(room.id, room.type)
    check_exits(room.id, room.Exits)
    centerview(room.id)
  end

end

registerAnonymousEventHandler("onPrompt", "Fierymud.Mapper.on_prompt")
