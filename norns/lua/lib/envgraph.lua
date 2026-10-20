-- envgraph (drawing helper, simplified)
local EG = {}; EG.__index = EG
function EG.new_adsr(x_min, x_max, y_min, y_max, a, d, s, r, level, curve)
  return setmetatable({ kind = 'adsr', a = a or 0.01, d = d or 0.3, s = s or 0.5, r = r or 1, level = level or 1, curve = curve or -4, x = 10, y = 10, w = 108, h = 44, active = true, xmax = x_max or 4 }, EG)
end
function EG.new_ar(x_min, x_max, y_min, y_max, a, r, level, curve)
  return setmetatable({ kind = 'ar', a = a or 0.01, d = 0, s = 0, r = r or 1, level = level or 1, curve = curve or -4, x = 10, y = 10, w = 108, h = 44, active = true, xmax = x_max or 4 }, EG)
end
EG.new = EG.new_adsr
function EG:set_position_and_size(x, y, w, h) self.x, self.y, self.w, self.h = x, y, w, h end
function EG:set_active(a) self.active = a end
function EG:edit_adsr(a, d, s, r, level, curve) if a then self.a = a end if d then self.d = d end if s then self.s = s end if r then self.r = r end if level then self.level = level end if curve then self.curve = curve end end
function EG:edit_ar(a, r, level, curve) if a then self.a = a end if r then self.r = r end if level then self.level = level end if curve then self.curve = curve end end
function EG:redraw()
  local tot = math.max(0.01, self.a + self.d + 0.3 + self.r)
  local sx = function(t) return self.x + t / tot * self.w end
  local sy = function(v) return self.y + self.h - v * self.h end
  screen.level(self.active and 15 or 5); screen.line_width(1)
  screen.move(sx(0), sy(0)); screen.line(sx(self.a), sy(self.level))
  if self.kind == 'adsr' then screen.line(sx(self.a + self.d), sy(self.s * self.level)); screen.line(sx(self.a + self.d + 0.3), sy(self.s * self.level)); screen.line(sx(tot), sy(0))
  else screen.line(sx(self.a + self.r), sy(0)) end
  screen.stroke()
end
return EG
