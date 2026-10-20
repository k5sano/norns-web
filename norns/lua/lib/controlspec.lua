-- controlspec
local ControlSpec = {}
ControlSpec.__index = ControlSpec
function ControlSpec.new(minval, maxval, warp, step, default, units, quantum, wrap)
  local s = setmetatable({}, ControlSpec)
  s.minval = minval or 0
  s.maxval = maxval or 1
  s.warp = warp or 'lin'
  if type(s.warp) == 'table' then s.warp = 'lin' end
  s.step = step or 0
  s.default = default or s.minval
  s.units = units or ''
  s.quantum = quantum or 0.01
  s.wrap = wrap or false
  return s
end
function ControlSpec.def(t) return ControlSpec.new(t.min, t.max, t.warp, t.step, t.default, t.units, t.quantum, t.wrap) end
function ControlSpec:map(x)
  x = math.min(math.max(x, 0), 1)
  local v
  if self.warp == 'exp' and self.minval > 0 then v = self.minval * (self.maxval / self.minval) ^ x
  else v = self.minval + (self.maxval - self.minval) * x end
  if self.step > 0 then v = math.floor(v / self.step + 0.5) * self.step end
  return v
end
function ControlSpec:unmap(v)
  if self.maxval == self.minval then return 0 end
  if self.warp == 'exp' and self.minval > 0 and v > 0 then return math.log(v / self.minval) / math.log(self.maxval / self.minval) end
  return (v - self.minval) / (self.maxval - self.minval)
end
function ControlSpec:constrain(v) return math.min(math.max(v, math.min(self.minval, self.maxval)), math.max(self.minval, self.maxval)) end
function ControlSpec:copy() return ControlSpec.new(self.minval, self.maxval, self.warp, self.step, self.default, self.units, self.quantum, self.wrap) end
function ControlSpec:print() for k, v in pairs(self) do print(k, v) end end
local N = ControlSpec.new
ControlSpec.UNIPOLAR = N(0, 1, 'lin', 0, 0, '')
ControlSpec.BIPOLAR = N(-1, 1, 'lin', 0, 0, '')
ControlSpec.FREQ = N(20, 20000, 'exp', 0, 440, 'Hz')
ControlSpec.LOFREQ = N(0.1, 100, 'exp', 0, 6, 'Hz')
ControlSpec.MIDFREQ = N(25, 4200, 'exp', 0, 440, 'Hz')
ControlSpec.WIDEFREQ = N(0.1, 20000, 'exp', 0, 440, 'Hz')
ControlSpec.PHASE = N(0, math.pi, 'lin', 0, 0, '')
ControlSpec.RQ = N(0.001, 2, 'exp', 0, 0.707, '')
ControlSpec.MIDI = N(0, 127, 'lin', 0, 64, '')
ControlSpec.MIDINOTE = N(0, 127, 'lin', 0, 60, '')
ControlSpec.MIDIVELOCITY = N(1, 127, 'lin', 0, 64, '')
ControlSpec.DB = N(-60, 0, 'db', 0, 0, 'dB')
ControlSpec.AMP = N(0, 1, 'lin', 0, 0, '')
ControlSpec.BOOSTCUT = N(-20, 20, 'lin', 0, 0, 'dB')
ControlSpec.PAN = N(-1, 1, 'lin', 0, 0, '')
ControlSpec.DETUNE = N(-20, 20, 'lin', 0, 0, 'Hz')
ControlSpec.RATE = N(0.125, 8, 'exp', 0, 1, '')
ControlSpec.BEATS = N(0, 20, 'lin', 0, 0, '')
ControlSpec.DELAY = N(0.0001, 1, 'exp', 0, 0.3, 'secs')
return ControlSpec
