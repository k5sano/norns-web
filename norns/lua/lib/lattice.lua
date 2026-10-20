-- lattice (v2-compatible subset)
local Lattice, Sprocket = {}, {}
Lattice.__index = Lattice
Sprocket.__index = Sprocket

local function safe(f, ...) if type(f) ~= 'function' then return end local ok, e = pcall(f, ...) if not ok then __report(tostring(e)) end end

function Lattice:new(args)
  local l = setmetatable({}, Lattice)
  args = args or {}
  l.auto = args.auto ~= false
  l.meter = args.meter or 4
  l.ppqn = args.ppqn or 96
  l.enabled = args.enabled ~= false
  l.transport = 0
  l.sprockets = {}
  l.sprocket_ordering = {}
  l.sprocket_id_counter = 100
  if l.auto then
    l.superclock_id = clock.run(function()
      while true do
        clock.sync(1 / l.ppqn)
        l:pulse()
      end
    end)
  end
  return l
end
function Lattice:start() self.enabled = true end
function Lattice:stop() self.enabled = false end
function Lattice:toggle() self.enabled = not self.enabled end
function Lattice:hard_restart()
  self.transport = 0
  for _, s in pairs(self.sprockets) do s.phase = s:_period() - s:_delay_pulses(); s.downbeat = false end
  self:start()
end
function Lattice:destroy()
  self:stop()
  if self.superclock_id then clock.cancel(self.superclock_id) end
  self.sprockets = {}; self.sprocket_ordering = {}
end
function Lattice:set_meter(m) self.meter = m end
function Lattice:pulse()
  if not self.enabled then return end
  local order = {}
  for _, s in pairs(self.sprockets) do order[#order + 1] = s end
  table.sort(order, function(a, b) if a.order ~= b.order then return a.order < b.order end return a.id < b.id end)
  for _, s in ipairs(order) do
    if s.enabled then
      s.phase = s.phase + 1
      local per = s:_period()
      local thr = per
      if s.swing ~= 50 then thr = per * (s.downbeat and (2 - s.swing / 50) or (s.swing / 50)) end
      if s.phase > thr then
        s.phase = s.phase - thr
        s.downbeat = not s.downbeat
        safe(s.action, self.transport)
      end
    elseif s.flag then
      self.sprockets[s.id] = nil
    end
  end
  self.transport = self.transport + 1
end
function Lattice:new_sprocket(args)
  args = args or {}
  self.sprocket_id_counter = self.sprocket_id_counter + 1
  local s = setmetatable({}, Sprocket)
  s.id = self.sprocket_id_counter
  s.lattice = self
  s.division = args.division or 1 / 4
  s.action = args.action or function() end
  s.enabled = args.enabled ~= false
  s.swing = args.swing or 50
  s.delay = args.delay or 0
  s.order = args.order or 3
  s.downbeat = false
  s.flag = false
  s.phase = s:_period() - s:_delay_pulses()
  self.sprockets[s.id] = s
  return s
end
Lattice.new_pattern = Lattice.new_sprocket
function Sprocket:_period() return math.max(1, self.division * self.lattice.ppqn * 4) end
function Sprocket:_delay_pulses() return (self.delay or 0) * self:_period() end
function Sprocket:start() self.enabled = true end
function Sprocket:stop() self.enabled = false end
function Sprocket:toggle() self.enabled = not self.enabled end
function Sprocket:destroy() self.enabled = false; self.flag = true end
function Sprocket:set_division(d) self.division = d end
function Sprocket:set_action(f) self.action = f end
function Sprocket:set_swing(s) self.swing = util.clamp(s, 0, 100) end
function Sprocket:set_delay(d) self.delay = d end
function Sprocket:set_order(o) self.order = o end
return Lattice
