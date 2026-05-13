-- Session tracker: XP, gold, time-to-level. Drops a compact
-- panel into the left column showing what the player has gained
-- this session and the per-hour rate. Updates every prompt off
-- gmcp.Char.Status (xp + wealth fields).
--
-- Time-to-level is computed two ways and the more confident one
-- wins:
--   1. nl% rate — how fast the "next level %" is rising. Most
--      reliable mid-session because it's a direct measure of
--      level-progress velocity, immune to whatever XP curve the
--      server applies.
--   2. xp/hr fallback — used while the nl% rate is too noisy
--      (early session) or when level-up resets nl. Hidden when
--      we don't have enough data to estimate.
--
-- Level-up detection: when `nl` decreases (e.g. 95 → 5), we
-- reset the nl-rate baseline so the next minute of play
-- recalibrates instead of reporting nonsense.

FierymudRs = FierymudRs or {}
FierymudRs.Tracker = FierymudRs.Tracker or {}

local function fmt_int(n)
  -- Compact thousand separators: 12,450 not 12450.
  local s = tostring(math.floor(n))
  local sign = ""
  if s:sub(1, 1) == "-" then sign = "-"; s = s:sub(2) end
  local rev = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
  rev = rev:gsub("^,", "")
  return sign .. rev
end

local function fmt_signed(n)
  if n > 0 then return "+" .. fmt_int(n) end
  return fmt_int(n)
end

local function fmt_duration_seconds(s)
  if s < 60 then return string.format("%ds", math.floor(s)) end
  if s < 3600 then return string.format("%dm %ds", math.floor(s / 60), math.floor(s % 60)) end
  return string.format("%dh %dm", math.floor(s / 3600), math.floor((s % 3600) / 60))
end

function FierymudRs.Tracker:setup()
  -- One-line "session strip" docked directly under the HP/Move/XP
  -- vitals gauges (which occupy y=0..90px in left_container).
  -- This collapses the previous 4-line panel-with-header into a
  -- single compact row so the bottom of the left column is free
  -- for group/aggro/target widgets — the prime real estate for
  -- combat-time glance information.
  local STRIP_HEIGHT = 18
  local container = FierymudRs.Tracker.container
    or Geyser.Container:new({
      name = "TrackerPanel",
      x = 5, y = 92,
      height = STRIP_HEIGHT, width = "-10px",
      v_policy = Geyser.Fixed,
    }, FierymudRs.GUI.left_container)
  FierymudRs.Tracker.container = container

  local label = FierymudRs.Tracker.label
    or Geyser.Label:new({
      name = "TrackerLabel",
      x = 0, y = 0, width = "100%", height = "100%",
      fontSize = 8,
    }, container)
  -- Subtle background so the strip reads as part of the vitals
  -- group rather than floating. Border-top-only ties it visually
  -- to the gauges above without doubling up borders.
  label:setStyleSheet([[
    background-color: rgba(0,0,0,180);
    border-top: 1px solid #333;
    color: #cccccc;
    padding: 1px 4px;
  ]])
  FierymudRs.Tracker.label = label

  -- Session-state baseline. `started` flips true once we've
  -- observed our first Char.Status frame; deltas before that
  -- are zero (rather than the player's full lifetime XP).
  FierymudRs.Tracker.session = {
    started = false,
    started_at = os.time(),
    start_xp = 0,
    start_wealth = 0,
    last_xp = 0,
    last_wealth = 0,
    -- nl% baseline for the level-progress rate. Reset on
    -- detected level-up.
    nl_baseline_pct = nil,
    nl_baseline_at = os.time(),
  }
  -- Initial render so the panel isn't blank until the first prompt.
  FierymudRs.Tracker:render()
end

-- Reset the session counters back to "now". Bound to
-- `fm tracker reset`. Useful for sessions that span a long
-- AFK / idle stretch where the per-hour rates went stale.
function FierymudRs.Tracker:reset()
  local s = self.session
  if not s then return end
  s.started = false
  s.started_at = os.time()
  s.start_xp = s.last_xp
  s.start_wealth = s.last_wealth
  s.nl_baseline_pct = nil
  s.nl_baseline_at = os.time()
  self:render()
end

function FierymudRs.Tracker:update()
  local s = FierymudRs.Tracker.session
  if not s then return end
  local status = gmcp and gmcp.Char and gmcp.Char.Status
  if not status then return end

  local xp = tonumber(status.xp) or 0
  local wealth = tonumber(status.wealth) or 0
  local nl = (gmcp.Char.Vitals and tonumber(gmcp.Char.Vitals.next_level_pct)) or nil

  -- First observation: anchor the baseline. Subsequent calls
  -- compute deltas relative to this anchor.
  if not s.started then
    s.started = true
    s.start_xp = xp
    s.start_wealth = wealth
    if nl then
      s.nl_baseline_pct = nl
      s.nl_baseline_at = os.time()
    end
  end

  -- Level-up detection. When nl drops by more than 50 percentage
  -- points in a single tick, the player almost certainly leveled
  -- (rather than the server emitting a stale frame). Re-anchor
  -- the nl baseline so the next minute of play recalibrates.
  if nl and s.nl_baseline_pct and (s.nl_baseline_pct - nl) > 50 then
    s.nl_baseline_pct = nl
    s.nl_baseline_at = os.time()
  end

  s.last_xp = xp
  s.last_wealth = wealth
  self:render()
end

function FierymudRs.Tracker:render()
  local s = self.session
  if not s or not self.label then return end

  local elapsed = os.time() - s.started_at
  if elapsed < 1 then elapsed = 1 end
  local elapsed_hr = elapsed / 3600

  local xp_delta = s.last_xp - s.start_xp
  local gold_delta = s.last_wealth - s.start_wealth
  local xp_per_hr = elapsed_hr > 0 and (xp_delta / elapsed_hr) or 0
  local gold_per_hr = elapsed_hr > 0 and (gold_delta / elapsed_hr) or 0

  -- TTL via nl-rate: percentage points per second since the
  -- baseline was anchored. Need at least 30s of data and a
  -- positive rate before showing an estimate — otherwise the
  -- numbers are all noise.
  local ttl_str = "<dim_grey>—</>"
  local nl = (gmcp and gmcp.Char and gmcp.Char.Vitals and gmcp.Char.Vitals.next_level_pct)
  if nl and s.nl_baseline_pct then
    local nl_elapsed = os.time() - s.nl_baseline_at
    local nl_progress = nl - s.nl_baseline_pct
    if nl_elapsed >= 30 and nl_progress > 0 then
      local pct_remaining = 100 - nl
      local seconds_to_level = pct_remaining / (nl_progress / nl_elapsed)
      ttl_str = "<green>" .. fmt_duration_seconds(seconds_to_level) .. "</>"
    elseif nl < 100 then
      ttl_str = string.format("<dim_grey>%d%%</>", math.floor(nl))
    end
  end

  -- One-line "session strip" — dim-grey labels + bright values
  -- so the eye lands on numbers, not chrome. Dots separate
  -- groups; per-hour rates stay parenthesized + dim so they
  -- don't compete with the running totals.
  local out = string.format(
    "<dim_grey>XP</> %s <dim_grey>(%s/h)</> "
      .. "<dim_grey>·</> <yellow>$</>%s <dim_grey>(%s/h)</> "
      .. "<dim_grey>·</> <dim_grey>TTL</> %s",
    fmt_signed(xp_delta), fmt_int(xp_per_hr),
    fmt_signed(gold_delta), fmt_int(gold_per_hr),
    ttl_str
  )
  self.label:cecho(out)
end

FierymudRs._subsystems = FierymudRs._subsystems or {}
FierymudRs._subsystems.Tracker = {
  name = "Tracker",
  setup = function() FierymudRs.Tracker:setup() end,
  isReady = function()
    return FierymudRs.Tracker ~= nil and FierymudRs.Tracker.session ~= nil
  end,
  -- container + label live under left_container so the subtree
  -- walk in cleanup() will hide and free them. We only need to
  -- nil the cached refs + session so isReady flips false.
  teardown = function()
    if not FierymudRs.Tracker then return end
    FierymudRs.Tracker.container = nil
    FierymudRs.Tracker.label = nil
    FierymudRs.Tracker.session = nil
  end,
}
