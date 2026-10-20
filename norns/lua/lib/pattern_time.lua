-- pattern_time
local pattern = {}
pattern.__index = pattern
function pattern.new(name)
  local i = setmetatable({}, pattern)
  i.name = name or 'pattern'
  i.rec = 0; i.play = 0; i.overdub = 0
  i.prev_time = 0; i.event = {}; i.time = {}; i.count = 0; i.step = 0
  i.time_factor = 1
  i.metro = metro.init(function() i:next_event() end, 1, 1)
  i.process = function(_) end
  return i
end
function pattern:clear()
  self.metro:stop()
  self.rec = 0; self.play = 0; self.overdub = 0
  self.prev_time = 0; self.event = {}; self.time = {}; self.count = 0; self.step = 0
  self.time_factor = 1
end
function pattern:set_time_factor(f) self.time_factor = f or 1 end
function pattern:rec_start() self.rec = 1 end
function pattern:rec_stop()
  if self.rec == 1 then
    self.rec = 0
    if self.count ~= 0 then
      local t = self.prev_time
      self.prev_time = util.time()
      self.time[self.count] = self.prev_time - t
    end
  end
end
function pattern:watch(e)
  if self.rec == 1 then self:rec_event(e)
  elseif self.overdub == 1 then self:overdub_event(e) end
end
function pattern:rec_event(e)
  local c = self.count + 1
  if c == 1 then self.prev_time = util.time()
  else
    local t = self.prev_time
    self.prev_time = util.time()
    self.time[c - 1] = self.prev_time - t
  end
  self.count = c
  self.event[c] = e
end
function pattern:overdub_event(e)
  local c = self.step + 1
  local t = self.prev_time
  self.prev_time = util.time()
  local a = self.time[c - 1] or 0
  self.time[c - 1] = self.prev_time - t
  table.insert(self.time, c, math.max(0.001, a - self.time[c - 1]))
  table.insert(self.event, c, e)
  self.step = self.step + 1
  self.count = self.count + 1
end
function pattern:start()
  if self.count > 0 then
    self.prev_time = util.time()
    self.process(self.event[1])
    self.play = 1
    self.step = 1
    self.metro.time = math.max(0.001, self.time[1] * self.time_factor)
    self.metro:start()
  end
end
function pattern:next_event()
  self.prev_time = util.time()
  if self.step == self.count then self.step = 1 else self.step = self.step + 1 end
  self.process(self.event[self.step])
  self.metro.time = math.max(0.001, (self.time[self.step] or 0.1) * self.time_factor)
  self.metro:start()
end
function pattern:stop()
  if self.play == 1 then self.play = 0; self.overdub = 0; self.metro:stop() end
end
function pattern:set_overdub(s)
  if s == 1 and self.play == 1 and self.rec == 0 then self.overdub = 1 else self.overdub = 0 end
end
return pattern
