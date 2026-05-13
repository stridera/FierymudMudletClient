-- Per-prompt skill liveness — driven by the new `Char.Skills`
-- GMCP frame (separate from `Char.Skills.List`, which stays as
-- the static skill directory consumed by `Char.Skills.Get`).
--
-- Wire scope (v0.1): cache the frame on `FierymudRs.Skills.state`
-- and expose a small accessor so the future skill-bar widget can
-- read cooldowns / availability without re-parsing GMCP. No UI
-- yet — the bar lands in a follow-up.
--
-- Why a stub now: the server emits this every prompt, so absence
-- of a handler means the data lands in `gmcp.Char.Skills` and
-- overwrites the `.List` directory each tick (Mudlet's GMCP
-- parser replaces the whole subtree under a package name). The
-- stub gives us a single point that owns the per-prompt cache
-- and a place to layer the widget onto when it's ready.

FierymudRs = FierymudRs or {}
FierymudRs.Skills = FierymudRs.Skills or {
  -- Last per-prompt snapshot. Map of lowercased skill name →
  -- { cooldown = seconds_remaining, available = bool, mp_cost? }.
  -- Lowercase keys so consumers can lookup by typed-name without
  -- caring about server casing.
  state = {},
  -- Ordered list of the same data, preserving server emission
  -- order. The skill-bar widget will iterate this for layout
  -- (server order is roughly "primary → utility" for each class).
  ordered = {},
  -- Wall-clock of the most recent frame. Lets the widget show a
  -- "stale" indicator if onPrompt stops firing.
  updated_at = 0,
}

-- Public: pull the current cooldown / availability for a skill
-- by name (case-insensitive). Returns nil when the skill isn't
-- in the most recent frame (server may omit class-locked skills
-- the player can't use). The widget should treat nil as "hidden"
-- rather than "available" to avoid surfacing skills the player
-- doesn't have access to.
function FierymudRs.Skills:get(name)
  if not name then return nil end
  return self.state[tostring(name):lower()]
end

-- Public: iterate all skills in server emission order. Each entry
-- is `{name, cooldown, available, mp_cost?}` exactly as emitted.
-- Returns the cached ordered array (do not mutate — caller should
-- treat it as read-only).
function FierymudRs.Skills:list()
  return self.ordered
end

-- Public: refresh the cached state from `gmcp.Char.Skills`. Called
-- from the onPrompt branch in GUI.lua. Server emits an array under
-- `.skills`; we mirror it into both a map (for fast lookup) and an
-- ordered list (for layout). A missing or wrong-shape frame leaves
-- state untouched so a transient bad frame doesn't blank the bar.
-- Change-detection signature: name|cooldown|available joined per
-- skill. Cooldowns tick down at ~1Hz but onPrompt fires multiple
-- times per second during combat — skipping the rebuild+render
-- when the frame is byte-identical avoids per-prompt churn on
-- every chip's setStyleSheet + click/hover rebind.
local function skills_signature(arr)
  local parts = {}
  for _, s in ipairs(arr) do
    if type(s) == "table" and s.name then
      parts[#parts + 1] = string.format(
        "%s|%d|%s", s.name,
        math.floor(tonumber(s.cooldown) or 0),
        tostring(s.available == true)
      )
    end
  end
  return table.concat(parts, ";")
end

function FierymudRs.Skills:update()
  local frame = gmcp and gmcp.Char and gmcp.Char.Skills
  if type(frame) ~= "table" then return end
  local arr = frame.skills
  if type(arr) ~= "table" then return end
  local sig = skills_signature(arr)
  if sig == self._last_sig then return end
  self._last_sig = sig
  -- Rebuild from scratch rather than mutate-in-place: skills can
  -- be added / removed from the frame between ticks (server side
  -- gates by class progression), and stale entries would survive
  -- a partial update.
  local new_state = {}
  local new_ordered = {}
  for _, s in ipairs(arr) do
    if type(s) == "table" and s.name then
      local entry = {
        name = s.name,
        cooldown = tonumber(s.cooldown) or 0,
        available = s.available == true,
        mp_cost = tonumber(s.mp_cost),
      }
      new_state[tostring(s.name):lower()] = entry
      new_ordered[#new_ordered + 1] = entry
    end
  end
  self.state = new_state
  self.ordered = new_ordered
  self.updated_at = os.time()
  self:render()
end

-- Skill bar widget — horizontal strip of chips below the
-- THREATS/NPCS panels in the left column. Each chip shows the
-- skill name and (when on cooldown) the remaining seconds in
-- dim text. Available skills get a bright green border;
-- cooldown skills get a dim red border so the player can see
-- "what's ready" at a glance.
--
-- v0 limits to 6 chips. The server emits the player's "useful
-- right now" skills (class-gated + recently practiced), so 6
-- visible covers the common rotation. Future v1: filter by
-- "favorites" via a `fm skill pin <name>` alias.
local MAX_VISIBLE_SKILLS = 6
local CHIP_HEIGHT = 22

local CHIP_AVAILABLE = [[
  background-color: rgba(20,40,24,235);
  color: #d8f0d8;
  border: 1px solid #4ca84c;
  border-radius: 4px;
  padding: 1px 4px;
  qproperty-alignment: AlignCenter;
]]
local CHIP_AVAILABLE_HOVER = [[
  background-color: rgba(36,72,44,250);
  color: #ffffff;
  border: 1px solid #7ce06c;
  border-radius: 4px;
  padding: 1px 4px;
  qproperty-alignment: AlignCenter;
]]
local CHIP_COOLDOWN = [[
  background-color: rgba(40,20,20,235);
  color: #b0a0a0;
  border: 1px solid #884040;
  border-radius: 4px;
  padding: 1px 4px;
  qproperty-alignment: AlignCenter;
]]

local function chip_style(skill)
  return skill.available and CHIP_AVAILABLE or CHIP_COOLDOWN
end

function FierymudRs.Skills:setup()
  local parent = FierymudRs.GUI and FierymudRs.GUI.left_container
  if not parent then return end
  -- Skill bar sits below the ally panel. Mobs.layout() is the
  -- shared source of truth for left-column geometry; reading it
  -- here keeps the bar y in sync with header_height() at the
  -- current text_scale.
  local L = (FierymudRs.Mobs and FierymudRs.Mobs.layout and FierymudRs.Mobs.layout())
            or { bottom_y = 580, hh = 18, gap = 6 }
  -- Below mobs bottom: ally header (hh) + ally container (100) + gap.
  self.bar_y = L.bottom_y + L.hh + L.gap + 100 + L.gap

  self.bar_container = self.bar_container or Geyser.HBox:new({
    name = "SkillBar",
    x = 5, y = self.bar_y, width = "-10px", height = (CHIP_HEIGHT + 4) .. "px",
  }, parent)
  self.bar_container:hide()
  self.bar_rows = self.bar_rows or {}
end

-- Build a single chip Geyser.Label. Each chip's click sends the
-- skill name as a cast/use command — the server picks the right
-- skill→command mapping. For unavailable skills the click is a
-- no-op (the cooldown timer is visible; no point firing a known
-- failure).
local function createChip(parent, idx)
  local label = Geyser.Label:new({
    name = "skill_chip_" .. idx,
    width = "-2px", height = CHIP_HEIGHT .. "px",
    fontSize = FierymudRs.fontSize(8),
  }, parent)
  return label
end

function FierymudRs.Skills:render()
  if not self.bar_container then return end
  local list = self.ordered or {}
  if #list == 0 then
    self.bar_container:hide()
    return
  end
  -- Reuse existing chip labels; create more if needed; hide
  -- excess from prior renders (same pattern as Mobs.lua).
  local count = math.min(#list, MAX_VISIBLE_SKILLS)
  for i = 1, count do
    local skill = list[i]
    local chip = self.bar_rows[i] or createChip(self.bar_container, i)
    self.bar_rows[i] = chip
    -- Chip body: name (uppercased to read as a button) + optional
    -- cooldown seconds. The cooldown text is dim so the eye sees
    -- "available skills" first.
    local body
    if skill.available then
      body = string.format("<center>%s</center>", skill.name:upper())
    else
      body = string.format(
        "<center>%s <dim_grey>%ds</dim_grey></center>",
        skill.name:upper(), math.ceil(skill.cooldown or 0)
      )
    end
    pcall(function() chip:setStyleSheet(chip_style(skill)) end)
    chip:cecho(body)
    -- Click sends the skill name as a command. The server's
    -- alias system maps it to the correct cast/use verb. Hover
    -- state is only meaningful for available skills — for
    -- cooldown chips we don't bind setOnEnter at all (Mudlet
    -- treats absent handlers as no-ops, no need for empty fns).
    local cmd = skill.name:lower()
    local available = skill.available
    pcall(function()
      chip:setClickCallback(function() send(cmd) end)
      chip:setToolTip(available
        and ("Click to use: " .. skill.name)
        or string.format("On cooldown: %ds remaining", math.ceil(skill.cooldown or 0)))
      if available then
        chip:setOnEnter(function() chip:setStyleSheet(CHIP_AVAILABLE_HOVER) end)
        chip:setOnLeave(function() chip:setStyleSheet(CHIP_AVAILABLE) end)
      end
    end)
    chip:show()
  end
  for i = count + 1, #self.bar_rows do
    self.bar_rows[i]:hide()
  end
  self.bar_container:show()
end

FierymudRs._subsystems = FierymudRs._subsystems or {}
FierymudRs._subsystems.Skills = {
  name = "Skills",
  setup = function() FierymudRs.Skills:setup() end,
  isReady = function()
    return FierymudRs.Skills ~= nil
       and FierymudRs.Skills.state ~= nil
       and FierymudRs.Skills.bar_container ~= nil
  end,
  teardown = function()
    if not FierymudRs.Skills then return end
    FierymudRs.Skills.state = {}
    FierymudRs.Skills.ordered = {}
    FierymudRs.Skills.updated_at = 0
    FierymudRs.Skills.bar_container = nil
    FierymudRs.Skills.bar_rows = nil
  end,
}
