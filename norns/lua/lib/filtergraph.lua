-- filtergraph (drawing helper, simplified)
local FG = {}; FG.__index = FG
function FG.new(fmin, fmax, dbmin, dbmax, ftype, slope, freq, res)
  return setmetatable({ fmin = fmin or 20, fmax = fmax or 20000, dbmin = dbmin or -60, dbmax = dbmax or 32, ftype = ftype or 'lowpass', slope = slope or 12, freq = freq or 2000, res = res or 0, x = 10, y = 10, w = 108, h = 44, active = true }, FG)
end
function FG:set_position_and_size(x, y, w, h) self.x, self.y, self.w, self.h = x, y, w, h end
function FG:edit(ftype, slope, freq, res) if ftype then self.ftype = ftype end if slope then self.slope = slope end if freq then self.freq = freq end if res then self.res = res end end
function FG:set_active(a) self.active = a end
function FG:redraw()
  screen.level(self.active and 15 or 5); screen.line_width(1)
  local lf, hf = math.log(self.fmin), math.log(self.fmax)
  for i = 0, self.w do
    local f = math.exp(lf + (hf - lf) * i / self.w)
    local r = f / math.max(1, self.freq)
    local g
    if self.ftype == 'highpass' then g = r ^ (self.slope / 6) / (1 + r ^ (self.slope / 6)) elseif self.ftype == 'bandpass' then g = 1 / (1 + math.abs(math.log(r)) * 3) else g = 1 / (1 + r ^ (self.slope / 6)) end
    g = g * (1 + (self.res or 0) * math.exp(-(math.log(r)) ^ 2 * 20))
    local y = self.y + self.h - math.min(self.h, g * self.h * 0.8)
    if i == 0 then screen.move(self.x + i, y) else screen.line(self.x + i, y) end
  end
  screen.stroke()
end
return FG
