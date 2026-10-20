-- voice allocator (norns lib/voice subset)
local Voice = {}; Voice.__index = Voice
local Slot = {}; Slot.__index = Slot
function Voice.new(n, mode)
  local v = setmetatable({ count = n or 1, style = mode or 1, slots = {}, n = 0 }, Voice)
  for i = 1, v.count do v.slots[i] = setmetatable({ pool = v, id = i, active = false, n = 0, on_release = function() end, on_steal = function() end }, Slot) end
  return v
end
Voice.ROTATE = 1; Voice.RANDOM = 2; Voice.LRU = 3; Voice.ROUND_ROBIN = 1
function Voice:get()
  self.n = self.n + 1
  local best
  for _, s in ipairs(self.slots) do if not s.active and (not best or s.n < best.n) then best = s end end
  if not best then
    for _, s in ipairs(self.slots) do if not best or s.n < best.n then best = s end end
    pcall(best.on_steal, best)
  end
  best.active = true; best.n = self.n
  return best
end
function Voice:release(slot) if slot then slot:release() end end
function Slot:release() if self.active then self.active = false; pcall(self.on_release, self) end end
return Voice
