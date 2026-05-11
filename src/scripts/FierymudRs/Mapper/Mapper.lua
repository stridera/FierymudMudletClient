-- FierymudRs Mapper
--
-- Consumes the Rust server's IRE-shaped Room.Info GMCP frame:
--
--     {
--       "num":  zone * 100000 + id,    -- composite room key
--       "name": "Room title",
--       "area": "Zone display name",
--       "environment": "Forest",        -- Sector enum label
--       "exits":  { "north": <num>, "south": <num>, ... },
--       "doors":  { "north": "closed" | "locked", ... }
--     }
--
-- Layout strategy: compass-walk auto-place. We track the
-- direction the player most recently *moved* through and offset
-- the new room from the previous one by the corresponding
-- (dx, dy, dz) vector. This is the same trick Mudlet's stock
-- generic_mapper uses; it falls back gracefully when the player
-- teleports (no recent direction → drop the room at the area's
-- next free corner). Server-supplied coordinates would replace
-- this entirely; we'll prefer `room.coords` when the server
-- emits it (today it doesn't).
--
-- Persistence: Mudlet stores the map per profile. Composite
-- room nums are stable across server restarts (they're derived
-- from the schema's (zoneId, id) keys), so the map survives
-- reconnects and even server restarts.

uninstallPackage("generic_mapper") -- prevent the stock mapper from clashing with our handler.

mudlet = mudlet or {}
mudlet.mapper_script = true

FierymudRs = FierymudRs or {}
FierymudRs.Mapper = FierymudRs.Mapper or {}

FierymudRs.Mapper.config = FierymudRs.Mapper.config or {
  enabled = true,
  speedwalk_delay = 0.5,
}

-- Last direction the player moved through (recorded by the
-- alias hook in Commands.lua's movement helpers, or by Mudlet's
-- generic command-history if you wire it). Defaults to nil; the
-- placement code falls back to "next free corner" when nil.
FierymudRs.Mapper.last_direction = FierymudRs.Mapper.last_direction or nil

-- Direction → (dx, dy, dz) offset for compass-walk placement.
-- Diagonals follow the standard MUD convention (NE = +1+1).
-- Up / down step on the z axis so multi-level zones stack.
local coordmap = {
  north     = { 0,  1, 0 },
  south     = { 0, -1, 0 },
  east      = { 1,  0, 0 },
  west      = {-1,  0, 0 },
  northeast = { 1,  1, 0 },
  northwest = {-1,  1, 0 },
  southeast = { 1, -1, 0 },
  southwest = {-1, -1, 0 },
  up        = { 0,  0, 1 },
  down      = { 0,  0,-1 },
}

-- Inverse: opposite direction so we can ask "if I came from
-- room A by moving north, place A south of where I am now".
local opposite = {
  north = "south", south = "north",
  east  = "west",  west  = "east",
  northeast = "southwest", southwest = "northeast",
  northwest = "southeast", southeast = "northwest",
  up = "down",     down = "up",
}

-- Sector → Mudlet env id + RGB color + path weight. Labels
-- match the strings the server emits in Room.Info.environment
-- (sector_label() in mud-server::commands maps the Rust enum
-- variants to these names). New sectors added on the server
-- side need a row here or they'll fall through to Default.
local sectors = {
  Structure     = { id = 100, weight = 1, rgba = { 153,   0, 153, 255 } }, -- purple
  City          = { id = 101, weight = 1, rgba = { 153,  76,   0, 255 } }, -- burnt orange
  Field         = { id = 102, weight = 2, rgba = {   0, 153,   0, 255 } }, -- green
  Forest        = { id = 103, weight = 3, rgba = {   0,  51,   0, 255 } }, -- dark green
  Mountains     = { id = 104, weight = 6, rgba = { 128, 128, 128, 255 } }, -- gray
  Hills         = { id = 105, weight = 6, rgba = { 163,  85,  21, 255 } }, -- brown
  Shallows      = { id = 106, weight = 4, rgba = {   0, 102, 204, 255 } }, -- pale blue
  Water         = { id = 107, weight = 2, rgba = { 102, 178, 255, 255 } }, -- light blue
  Underwater    = { id = 108, weight = 5, rgba = {   0,   0, 102, 255 } }, -- dark blue
  Air           = { id = 109, weight = 1, rgba = { 102, 178, 255, 127 } }, -- transparent blue
  Road          = { id = 110, weight = 2, rgba = { 244, 164,  96, 255 } }, -- sandy brown
  Grasslands    = { id = 111, weight = 2, rgba = { 124, 252,   0, 255 } }, -- lawn green
  Cave          = { id = 112, weight = 2, rgba = { 105, 105, 105, 255 } }, -- light gray
  Ruins         = { id = 113, weight = 2, rgba = { 210, 180, 140, 255 } }, -- tan
  Swamp         = { id = 114, weight = 4, rgba = {   0, 102,   0, 255 } }, -- swamp green
  Beach         = { id = 115, weight = 2, rgba = { 255, 215,   0, 255 } }, -- gold
  Underdark     = { id = 116, weight = 2, rgba = { 128,   0,   0, 255 } }, -- maroon
  Astralplane   = { id = 117, weight = 1, rgba = { 255, 255, 255, 255 } }, -- white
  Airplane      = { id = 118, weight = 1, rgba = { 220, 220, 255, 255 } }, -- pale violet
  Fireplane     = { id = 119, weight = 1, rgba = { 255, 100,   0, 255 } }, -- bright orange
  Earthplane    = { id = 120, weight = 1, rgba = { 139,  69,  19, 255 } }, -- saddle brown
  Etherealplane = { id = 121, weight = 1, rgba = { 200, 200, 255, 255 } }, -- pale lavender
  Avernus       = { id = 122, weight = 1, rgba = { 102,   0,   0, 255 } }, -- dark red
  Default       = { id = 200, weight = 1, rgba = { 128,   0,   0, 255 } }, -- red
}

-- Resolve the Mudlet area id for a server-supplied area name.
-- Mudlet keys areas by name (case-insensitive lookup), creating
-- a new one on first sight. Returns -1 on failure (which
-- shouldn't happen — addAreaName is documented as infallible
-- given a non-empty string).
local function ensure_area(name)
  if not name or name == "" then name = "(unknown area)" end
  local areas = getAreaTable()
  for k, id in pairs(areas) do
    if string.lower(name) == string.lower(k) then
      return id
    end
  end
  local id = addAreaName(name)
  return id or -1
end

-- Parse the server's "x,y,z" coords string into three numbers.
-- Returns nil on malformed input; caller falls back to
-- compass-walk placement.
local function parse_coords(s)
  if type(s) ~= "string" then return nil end
  local x, y, z = s:match("^(-?%d+),(-?%d+),(-?%d+)$")
  if not x then return nil end
  return tonumber(x), tonumber(y), tonumber(z)
end

-- Compute (x, y, z) coordinates for a freshly-discovered room.
-- Strategy precedence:
--   0. Server-supplied `coords` ("x,y,z" string in Room.Info).
--      Builder-authored layout — place exactly here. Means the
--      whole zone renders correctly even on first sight, no
--      compass-walk dance needed.
--   1. Compass walk: offset from the previous room by
--      coordmap[last_direction]. The common case during
--      normal play.
--   2. Coords from the previous room minus the OPPOSITE of an
--      exit that points BACK to it. (E.g., the new room's
--      `west` exit goes to old_room → place new_room east of
--      old_room.) Catches one-way arrivals via portals where
--      we can still find a back-edge.
--   3. Next free corner: offset the area's bounding box and
--      mark as orphaned. The map will look disconnected for
--      teleport arrivals; user can walk back to graft.
local function place_new_room(new_num, prev_num, prev_dir, exits, area_id, coords_str)
  -- 0: server-authored coords win every time.
  local sx, sy, sz = parse_coords(coords_str)
  if sx then
    setRoomCoordinates(new_num, sx, sy, sz)
    return
  end
  local px, py, pz
  if prev_num and roomExists(prev_num) then
    px, py, pz = getRoomCoordinates(prev_num)
  end

  -- 1: compass-walk from prev.
  if px and prev_dir and coordmap[prev_dir] then
    local d = coordmap[prev_dir]
    setRoomCoordinates(new_num, px + d[1], py + d[2], pz + d[3])
    return
  end

  -- 2: back-edge from new room to a known room.
  if exits then
    for dir, dest in pairs(exits) do
      if dest and dest ~= 0 and roomExists(dest) and opposite[dir] then
        local dx, dy, dz = getRoomCoordinates(dest)
        local back = coordmap[opposite[dir]]
        if dx and back then
          setRoomCoordinates(new_num, dx + back[1], dy + back[2], dz + back[3])
          return
        end
      end
    end
  end

  -- 3: orphan corner. Walk the area's existing rooms to find
  -- the bounding box and offset by 50 (Mudlet's stock spacing
  -- between unconnected clusters). Mark with user data so we
  -- know it needs gluing.
  local rooms = getAreaRooms(area_id) or {}
  if #rooms == 0 then
    setRoomCoordinates(new_num, 0, 0, 0)
  else
    local minx, maxx, miny, maxy = nil, nil, nil, nil
    for _, rid in ipairs(rooms) do
      local rx, ry = getRoomCoordinates(rid)
      if rx then
        minx = (minx and math.min(minx, rx)) or rx
        maxx = (maxx and math.max(maxx, rx)) or rx
        miny = (miny and math.min(miny, ry)) or ry
        maxy = (maxy and math.max(maxy, ry)) or ry
      end
    end
    setRoomCoordinates(new_num, (maxx or 0) + 50, (miny or 0), 0)
    setRoomUserData(new_num, "is_orphaned", "true")
  end
end

-- Apply the IRE-shape exits + doors maps onto an existing room.
-- Mudlet stores per-direction edges; we set each direction's
-- destination plus door state. Stub destinations get an
-- addRoom() so subsequent moves through can fill in the room
-- name/env when the player actually steps there.
local function apply_exits(num, exits, doors, area_id)
  if type(exits) ~= "table" then return end
  for dir, dest in pairs(exits) do
    if dest and dest ~= 0 then
      if not roomExists(dest) then
        addRoom(dest)
        setRoomArea(dest, area_id)
      end
      setExit(num, dest, dir)
    end
  end
  if type(doors) == "table" then
    for dir, state in pairs(doors) do
      -- Mudlet: 1 = open (drawn green), 2 = closed (yellow),
      -- 3 = locked (red). Server emits "closed" / "locked"
      -- only; absence in the doors map means open / no door.
      local door_status = 1
      if state == "closed" then door_status = 2
      elseif state == "locked" then door_status = 3 end
      -- setDoor only recognizes the abbreviated cardinal forms
      -- ('n','s','e','w','ne','nw','se','sw','u','d'); long
      -- names like 'south' are treated as special-exit labels
      -- and emit "does not have a special exit in direction
      -- 'south'" warnings. Map to short form before the call.
      local short = ({
        north = "n", south = "s", east = "e", west = "w",
        northeast = "ne", northwest = "nw",
        southeast = "se", southwest = "sw",
        up = "u", down = "d",
      })[dir] or dir
      setDoor(num, short, door_status)
    end
  end
end

-- Push sector colors into Mudlet's env table once. Mudlet
-- persists these per profile but a fresh install needs them
-- registered before any setRoomEnv call paints the right hue.
local function ensure_env_colors()
  for _, env in pairs(sectors) do
    setCustomEnvColor(env.id, env.rgba[1], env.rgba[2], env.rgba[3], env.rgba[4])
  end
end

-- Public: handle a Room.Info GMCP frame. Wired to the
-- gmcp.Room.Info anonymous event handler at the bottom.
function FierymudRs.Mapper.onRoomInfo()
  if not FierymudRs.Mapper.config.enabled then return end
  local r = gmcp and gmcp.Room and gmcp.Room.Info
  if not r or not r.num or r.num == 0 then return end

  ensure_env_colors()

  local area_id = ensure_area(r.area)
  if area_id == -1 then return end
  FierymudRs.Mapper.current_area = area_id

  local prev_num = FierymudRs.Mapper.current_room
  local prev_dir = FierymudRs.Mapper.last_direction

  if not roomExists(r.num) then
    addRoom(r.num)
    setRoomArea(r.num, area_id)
    place_new_room(r.num, prev_num, prev_dir, r.exits, area_id, r.coords)
  end

  -- Re-anchor existing rooms to server coords if they arrived
  -- after the room was originally compass-walk-placed. Builder
  -- authoring the layout post-hoc should snap rooms onto the
  -- intended grid the next time anyone walks through them.
  local sx, sy, sz = parse_coords(r.coords)
  if sx then
    local cx, cy, cz = getRoomCoordinates(r.num)
    if cx ~= sx or cy ~= sy or cz ~= sz then
      setRoomCoordinates(r.num, sx, sy, sz)
      setRoomUserData(r.num, "is_orphaned", "false")
    end
  end

  -- Always-update fields. Builders may rename rooms / change
  -- sector type; refreshing on every visit keeps the map
  -- accurate without rebuilding from scratch.
  setRoomName(r.num, r.name or "")
  setRoomArea(r.num, area_id)
  local env = sectors[r.environment] or sectors.Default
  setRoomEnv(r.num, env.id)
  setRoomWeight(r.num, env.weight)

  -- Cache the original (zone, id) on the room so future
  -- consumers (custom mappers, third-party tooling) can recover
  -- the schema-level keys without re-parsing the composite.
  setRoomUserData(r.num, "zone", tostring(math.floor(r.num / 100000)))
  setRoomUserData(r.num, "id",   tostring(r.num % 100000))

  apply_exits(r.num, r.exits, r.doors, area_id)

  FierymudRs.Mapper.current_room = r.num
  -- Reset last_direction; the next movement command sets it,
  -- and arriving in the same room twice (Look without moving)
  -- shouldn't carry stale movement state.
  FierymudRs.Mapper.last_direction = nil

  centerview(r.num)
end

-- Speedwalk handler — Mudlet's mapper calls into this when the
-- user clicks a destination room. Walks the path, one step per
-- speedwalk_delay seconds. God-level characters bypass with
-- `goto <num>` since they have no movement cost.
function doSpeedWalk()
  if not speedWalkDir or #speedWalkDir == 0 then return end
  local dest = speedWalkPath[#speedWalkPath]
  print("Path to " .. (getRoomName(dest) or tostring(dest)) ..
        ": " .. table.concat(speedWalkDir, ", "))

  if FierymudRs.Character and FierymudRs.Character.level
     and FierymudRs.Character.level > 99 then
    print("You're a god. Where you're going, you don't need roads!")
    send("goto " .. dest)
    return
  end

  local delay = FierymudRs.Mapper.config.speedwalk_delay or 0.5
  local path = table.deepcopy(speedWalkDir)
  local next_step
  next_step = function()
    if #path == 0 then return end
    send(table.remove(path, 1))
    if #path > 0 then tempTimer(delay, next_step) end
  end
  next_step()
end

-- Movement-direction observer. Each directional command the
-- player types stamps the corresponding direction so the next
-- Room.Info frame can compass-walk from the previous room.
-- Aliases (n/s/e/w/...) all normalize to full names since the
-- server's exit dict uses full names.
local dir_aliases = {
  n = "north",  s = "south",  e = "east",   w = "west",
  ne = "northeast", nw = "northwest",
  se = "southeast", sw = "southwest",
  u = "up",  d = "down",
  north = "north", south = "south",
  east = "east",   west = "west",
  northeast = "northeast", northwest = "northwest",
  southeast = "southeast", southwest = "southwest",
  up = "up", down = "down",
}

function FierymudRs.Mapper.observeMovement(line)
  if not FierymudRs.Mapper.config.enabled then return end
  local trimmed = (line or ""):match("^%s*(%S+)")
  if not trimmed then return end
  local dir = dir_aliases[string.lower(trimmed)]
  if dir then
    FierymudRs.Mapper.last_direction = dir
  end
end

-- Named handlers replace in place across reloads — the
-- `_handlers_registered` guard the old anonymous version used
-- isn't needed anymore.
registerNamedEventHandler("FierymudRs", "Mapper.roomInfo",
  "gmcp.Room.Info", "FierymudRs.Mapper.onRoomInfo")
-- sysDataSendRequest fires for every command the user submits,
-- before it goes to the server. Perfect hook for tracking the
-- direction-of-last-movement without modifying every alias.
registerNamedEventHandler("FierymudRs", "Mapper.observeMovement",
  "sysDataSendRequest", function(_, line)
    FierymudRs.Mapper.observeMovement(line)
  end)

-- ----------------------------------------------------------------
-- Room tagging + speedwalk goto
-- ----------------------------------------------------------------
--
-- `fm tag <name>` saves the current room's composite id (zone *
-- 100000 + local id) under the given tag. `fm goto <name>` looks
-- up the tag, asks Mudlet's mapper for the shortest path from the
-- current room, then walks it command-by-command with a small
-- delay between sends (configurable via
-- FierymudRs.Mapper.config.speedwalk_delay).
--
-- Persistence: tags live in a lua table saved alongside Mudlet's
-- home dir so they survive Mudlet restarts but stay per-profile.
-- That's the right granularity — a player's "bank" is character-
-- specific, while a single named tag like "recall" might mean
-- different rooms for different alts.

local TAGS_FILE = function()
  return getMudletHomeDir():gsub("\\", "/") .. "/fierymud_rs_room_tags.lua"
end

function FierymudRs.Mapper:loadTags()
  if not self.tags then
    self.tags = {}
    if io.exists(TAGS_FILE()) then
      local ok = pcall(table.load, TAGS_FILE(), self.tags)
      if not ok then
        cecho("\n<red>Failed to load room tags from " .. TAGS_FILE() .. "<reset>\n")
        self.tags = {}
      end
    end
  end
  return self.tags
end

function FierymudRs.Mapper:saveTags()
  table.save(TAGS_FILE(), self.tags or {})
end

-- Composite room id of the room the player is in right now.
-- Sourced from gmcp.Room.Info (kept current by the server's
-- per-prompt push). Returns nil if no Room.Info has arrived yet
-- (very brief window between connection and first prompt).
local function currentRoomNum()
  return gmcp and gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.num
end

function FierymudRs.Mapper:tagRoom(name)
  name = (name or ""):lower():match("^%s*(.-)%s*$")
  if name == "" then
    cecho("<red>Usage: fm tag <name><reset>\n")
    return
  end
  local num = currentRoomNum()
  if not num then
    cecho("<red>No current room — try moving once first.<reset>\n")
    return
  end
  local tags = self:loadTags()
  tags[name] = num
  self:saveTags()
  cecho(string.format(
    "<green>Tagged room %d as <yellow>%s<reset>.\n", num, name
  ))
end

function FierymudRs.Mapper:untagRoom(name)
  name = (name or ""):lower():match("^%s*(.-)%s*$")
  if name == "" then
    cecho("<red>Usage: fm untag <name><reset>\n")
    return
  end
  local tags = self:loadTags()
  if not tags[name] then
    cecho(string.format("<red>No tag named '%s'.<reset>\n", name))
    return
  end
  tags[name] = nil
  self:saveTags()
  cecho(string.format("<green>Untagged <yellow>%s<reset>.\n", name))
end

-- Speedwalk to a tagged room. Resolves tag → room num → path,
-- then walks the path one direction at a time with the
-- configured delay between sends.
function FierymudRs.Mapper:gotoTag(name)
  name = (name or ""):lower():match("^%s*(.-)%s*$")
  local tags = self:loadTags()
  if name == "" then
    -- No arg → list known tags so the player can pick.
    if not next(tags) then
      cecho("<red>No tags saved. Use <yellow>fm tag <name><red> in a room to add one.<reset>\n")
      return
    end
    cecho("<green>Tagged rooms:<reset>\n")
    -- Sorted listing; alphabetical name is the obvious order.
    local keys = {}
    for k in pairs(tags) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do
      cecho(string.format("  <yellow>%-12s<reset> <dim_grey>(room %d)<reset>\n", k, tags[k]))
    end
    return
  end

  local target = tags[name]
  if not target then
    cecho(string.format(
      "<red>No tag named '%s'. Try <yellow>fm goto<red> for the list.<reset>\n",
      name
    ))
    return
  end
  local from = currentRoomNum()
  if not from then
    cecho("<red>No current room — try moving once first.<reset>\n")
    return
  end
  if from == target then
    cecho(string.format("<green>Already at <yellow>%s<reset>.\n", name))
    return
  end

  -- Mudlet's getPath sets the globals `speedWalkPath` and
  -- `speedWalkDir` as a side effect. The boolean return tells
  -- us whether a path was found at all.
  local found = getPath(from, target)
  if not found then
    cecho(string.format(
      "<red>No path from current room to <yellow>%s<red> (room %d).<reset>\n",
      name, target
    ))
    return
  end
  local dirs = speedWalkDir or {}
  if #dirs == 0 then
    cecho(string.format(
      "<green>Already at <yellow>%s<reset>.\n", name
    ))
    return
  end

  cecho(string.format(
    "<green>Walking <yellow>%s<reset>: %s (%d steps)\n",
    name, table.concat(dirs, " "), #dirs
  ))
  local delay = (FierymudRs.Mapper.config and FierymudRs.Mapper.config.speedwalk_delay) or 0.5
  for i, dir in ipairs(dirs) do
    -- Stagger the sends with tempTimer so the server can echo
    -- each step's room before the next command lands. Direct
    -- send without delay would arrive as one burst, which is
    -- antisocial to the server and breaks GMCP synchronization.
    tempTimer((i - 1) * delay, function() send(dir) end)
  end
end

-- Load tags lazily; the first tagRoom / gotoTag call will
-- hydrate them. No setup() needed — `FierymudRs.Mapper` is
-- already a ready-on-script-load namespace.
