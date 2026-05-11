-- Combat ability queue (v0.1). FIFO command sender that fires
-- one queued command per prompt. Useful for chaining skill
-- rotations during autobash without typing every step.
--
-- v0.1 scope (deliberately small):
--   * push / clear / list operations via `fm cq` aliases
--   * one command sent per onPrompt tick
--   * no cooldown awareness, no balance / GCD modeling
--   * no per-class rotation config
--   * no persistence across sessions
--
-- v1 requires server-side help:
--   * a `Char.Cooldowns` GMCP frame so the queue can defer a
--     command until the relevant skill is off cooldown
--   * a "balance / equilibrium" readiness signal (boolean per
--     resource type)
--   * optional per-class rotation packs (e.g. "warrior basic
--     melee" → bash → kick → gore)
--
-- Until then, the queue is intentionally dumb: it sends the next
-- command and trusts the server to reject if the player isn't
-- ready. That's good enough for travel-style chaining and most
-- spell rotations where the cast can wait for a free moment.

FierymudRs = FierymudRs or {}
FierymudRs.CombatQueue = FierymudRs.CombatQueue or {
  queue = {},
  paused = false,
}

function FierymudRs.CombatQueue:push(cmd)
  cmd = (cmd or ""):match("^%s*(.-)%s*$")
  if cmd == "" then
    cecho("<red>Usage: fm cq <command><reset>\n")
    return
  end
  table.insert(self.queue, cmd)
  cecho(string.format(
    "<green>Queued (%d):<reset> %s\n",
    #self.queue, cmd
  ))
end

function FierymudRs.CombatQueue:clear()
  local n = #self.queue
  self.queue = {}
  if n > 0 then
    cecho(string.format("<yellow>Cleared %d queued command(s).<reset>\n", n))
  else
    cecho("<dim_grey>Queue already empty.<reset>\n")
  end
end

function FierymudRs.CombatQueue:list()
  if #self.queue == 0 then
    cecho("<dim_grey>Queue is empty. <yellow>fm cq <command><dim_grey> to add.<reset>\n")
    return
  end
  cecho(string.format(
    "<green>Queue (%d, %s):<reset>\n",
    #self.queue,
    self.paused and "<red>paused</>" or "<green>running</>"
  ))
  for i, cmd in ipairs(self.queue) do
    cecho(string.format("  <yellow>%2d.<reset> %s\n", i, cmd))
  end
end

function FierymudRs.CombatQueue:pause()
  self.paused = true
  cecho("<yellow>Queue paused. <green>fm cq resume<yellow> to continue.<reset>\n")
end

function FierymudRs.CombatQueue:resume()
  self.paused = false
  cecho("<green>Queue resumed.<reset>\n")
end

-- Called from the onPrompt branch in GUI.lua. Fires the head of
-- the queue and pops it; bails when paused or empty. The send
-- happens via Mudlet's standard `send()` so the server sees it
-- as a normal player input (same path as anything else the
-- player types).
function FierymudRs.CombatQueue:advance()
  if self.paused then return end
  if #self.queue == 0 then return end
  local cmd = table.remove(self.queue, 1)
  send(cmd)
end
