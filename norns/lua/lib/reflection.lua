-- reflection: clock-synced pattern recorder (subset)
local R = {}
R.__index = R
local PPQN = 96
local function safe(f, ...) if type(f) ~= 'function' then return end local ok, e = pcall(f, ...) if not ok then __report(tostring(e)) end end
function R.new()
  local p = setmetatable({}, R)
  p.rec = 0; p.play = 0; p.loop = 1; p.count = 0; p.step = 0; p.endpoint = 0; p.event = {}; p.queued_rec = nil
  p.quantize = 1 / 48; p.time_factor = 1; p.rec_dur = nil
  p.process = function() end
  p.start_callback = function() end; p.end_of_loop_callback = function() end; p.end_of_rec_callback = function() end; p.end_callback = function() end; p.step_callback = function() end
  return p
end
function R:_beat() return math.floor(clock.get_beats() * PPQN) end
function R:watch(e)
  if self.rec ~= 1 then return end
  if self.count == 0 and not self.rec_start then self.rec_start = self:_beat() end
  local s = self:_beat() - (self.rec_start or self:_beat())
  if self.play == 1 then s = self.step end
  self.event[s] = self.event[s] or {}
  table.insert(self.event[s], e)
  self.count = self.count + 1
end
function R:set_rec(r, dur)
  if r == 1 then
    self.rec = 1; self.rec_start = self:_beat()
    if self.play == 0 then self.event = {}; self.count = 0 end
    if dur then self.rec_dur = dur; self.endpoint = math.floor(dur * PPQN) end
  else
    if self.rec == 1 and self.play == 0 then
      self.endpoint = math.max(1, self:_beat() - (self.rec_start or self:_beat()))
      if self.quantize and self.quantize > 0 then local q = math.max(1, math.floor(self.quantize * PPQN * 4)); self.endpoint = math.max(q, math.floor(self.endpoint / q + 0.5) * q) end
      self.rec = 0
      safe(self.end_of_rec_callback)
      if self.count > 0 then self:start() end
    end
    self.rec = 0
  end
end
function R:set_loop(l) self.loop = l end
function R:set_length(beats) self.endpoint = math.floor(beats * PPQN) end
function R:set_quantization(q) self.quantize = q end
function R:set_time_factor(f) self.time_factor = f or 1 end
function R:start(sync)
  if self.endpoint <= 0 then return end
  self.play = 1; self.step = 0
  safe(self.start_callback)
  if self.clock then clock.cancel(self.clock) end
  self.clock = clock.run(function()
    if sync then clock.sync(sync) end
    while self.play == 1 do
      local evs = self.event[self.step]
      if evs then for _, e in ipairs(evs) do safe(self.process, e) end end
      safe(self.step_callback, self.step)
      clock.sync(self.time_factor / PPQN)
      self.step = self.step + 1
      if self.step >= self.endpoint then
        self.step = 0
        safe(self.end_of_loop_callback)
        if self.loop ~= 1 then self.play = 0; safe(self.end_callback) end
      end
    end
  end)
end
function R:stop() self.play = 0; if self.clock then clock.cancel(self.clock); self.clock = nil end; safe(self.end_callback) end
function R:clear() self:stop(); self.rec = 0; self.event = {}; self.count = 0; self.step = 0; self.endpoint = 0 end
function R:undo() end
function R:save(path) tab.save({ event = self.event, endpoint = self.endpoint, count = self.count }, path) end
function R:load(path) local t = tab.load(path); if t then self.event = t.event or {}; self.endpoint = t.endpoint or 0; self.count = t.count or 0 end end
return R
