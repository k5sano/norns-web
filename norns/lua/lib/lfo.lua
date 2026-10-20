-- lfo (norns 2.7-style subset)
local LFO = {}
LFO.__index = LFO
local SHAPES = { 'sine', 'tri', 'square', 'random', 'up', 'down' }
local function safe(f, ...) if type(f) ~= 'function' then return end local ok, e = pcall(f, ...) if not ok then __report(tostring(e)) end end
local function shape_val(shape, ph, self)
  if shape == 'sine' then return 0.5 - 0.5 * math.cos(ph * 2 * math.pi)
  elseif shape == 'tri' then return ph < 0.5 and ph * 2 or 2 - ph * 2
  elseif shape == 'square' then return ph < 0.5 and 1 or 0
  elseif shape == 'up' then return ph
  elseif shape == 'down' then return 1 - ph
  elseif shape == 'random' then return self.rand end
  return 0.5 - 0.5 * math.cos(ph * 2 * math.pi)
end
function LFO.new(args)
  args = args or {}
  local l = setmetatable({}, LFO)
  l.shape = args.shape or 'sine'; l.min = args.min or 0; l.max = args.max or 1; l.depth = args.depth or 1
  l.offset = args.offset or 0; l.mode = args.mode or 'clocked'; l.period = args.period or 4; l.phase = args.phase or 0
  l.baseline = args.baseline or 'min'; l.action = args.action or function() end
  l.enabled = 0; l.ph = l.phase % 1; l.rand = math.random(); l.scaled = l.min; l.raw = 0; l.ppqn = args.ppqn or 96
  return l
end
function LFO:add(args) return LFO.new(args) end
function LFO:init(args) return LFO.new(args) end
function LFO:set(k, v)
  if k == 'enabled' then if v == 1 or v == true then self:start() else self:stop() end return end
  if k == 'shape' and type(v) == 'number' then v = SHAPES[v] end
  self[k] = v
end
function LFO:get(k) return self[k] end
function LFO:start()
  if self.clock then return end
  self.enabled = 1
  local last = clock.get_beats()
  local lastt = util.time()
  self.clock = clock.run(function()
    while true do
      clock.sleep(1 / 60)
      local dt
      if self.mode == 'free' then local t = util.time(); dt = (t - lastt) / math.max(0.001, self.period); lastt = t
      else local b = clock.get_beats(); dt = (b - last) / math.max(0.001, self.period); last = b end
      local np = self.ph + dt
      if math.floor(np) ~= math.floor(self.ph) then self.rand = math.random() end
      self.ph = np % 1
      local v = shape_val(self.shape, self.ph, self)
      local d = self.depth
      local x
      if self.baseline == 'center' then x = 0.5 + (v - 0.5) * d elseif self.baseline == 'max' then x = 1 - (1 - v) * d else x = v * d end
      x = x + (self.offset or 0)
      self.raw = v
      self.scaled = self.min + (self.max - self.min) * x
      safe(self.action, self.scaled, self.raw)
    end
  end)
end
function LFO:stop() self.enabled = 0; if self.clock then clock.cancel(self.clock); self.clock = nil end end
function LFO:reset_phase() self.ph = self.phase % 1 end
function LFO:add_params(id, sep, group)
  id = id or ('lfo' .. math.random(9999))
  if group then params:add_group(id .. '_group', type(group) == 'string' and group or id, 4) end
  if sep then params:add_separator(id .. '_sep', type(sep) == 'string' and sep or id) end
  params:add_option(id .. '_enabled', 'lfo', { 'off', 'on' }, self.enabled == 1 and 2 or 1)
  params:set_action(id .. '_enabled', function(v) if v == 2 then self:start() else self:stop() end end)
  params:add_option(id .. '_shape', 'shape', SHAPES, tab.key(SHAPES, self.shape) or 1)
  params:set_action(id .. '_shape', function(v) self.shape = SHAPES[v] end)
  params:add_control(id .. '_period', 'period', controlspec.new(0.1, 64, 'exp', 0, self.period, ''))
  params:set_action(id .. '_period', function(v) self.period = v end)
  params:add_control(id .. '_depth', 'depth', controlspec.new(0, 1, 'lin', 0, self.depth, ''))
  params:set_action(id .. '_depth', function(v) self.depth = v end)
end
setmetatable(LFO, { __call = function(_, args) return LFO.new(args) end })
return LFO
