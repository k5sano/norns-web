-- graph (subset)
local Graph = {}
Graph.__index = Graph
function Graph.new(x_min, x_max, x_warp, y_min, y_max, y_warp, style, show_x_axis, show_y_axis)
  local g = setmetatable({}, Graph)
  g.x_min = x_min or 0; g.x_max = x_max or 1; g.x_warp = x_warp or 'lin'
  g.y_min = y_min or 0; g.y_max = y_max or 1; g.y_warp = y_warp or 'lin'
  g.style = style or 'line'; g.show_x_axis = show_x_axis; g.show_y_axis = show_y_axis
  g.x = 10; g.y = 10; g.width = 108; g.height = 44; g.points = {}; g.functions = {}; g.active = true
  return g
end
function Graph:set_position_and_size(x, y, w, h) self.x, self.y, self.width, self.height = x, y, w, h end
function Graph:set_active(a) self.active = a end
function Graph:get_x_min() return self.x_min end
function Graph:get_x_max() return self.x_max end
function Graph:get_y_min() return self.y_min end
function Graph:get_y_max() return self.y_max end
function Graph:set_x_min(v) self.x_min = v end
function Graph:set_x_max(v) self.x_max = v end
function Graph:set_y_min(v) self.y_min = v end
function Graph:set_y_max(v) self.y_max = v end
function Graph:add_point(px, py, curve, highlight) self.points[#self.points + 1] = { x = px, y = py, curve = curve, highlight = highlight } end
function Graph:edit_point(i, px, py, curve, highlight) local p = self.points[i]; if not p then return end if px then p.x = px end if py then p.y = py end if curve then p.curve = curve end if highlight ~= nil then p.highlight = highlight end end
function Graph:remove_point(i) table.remove(self.points, i) end
function Graph:remove_all_points() self.points = {} end
function Graph:highlight_point(i) if self.points[i] then self.points[i].highlight = true end end
function Graph:highlight_exclusive_point(i) for j, p in ipairs(self.points) do p.highlight = (j == i) end end
function Graph:clear_highlight() for _, p in ipairs(self.points) do p.highlight = false end end
function Graph:get_point(i) return self.points[i] end
function Graph:count_points() return #self.points end
function Graph:add_function(fn, q) self.functions[#self.functions + 1] = { fn = fn, q = q or 1 } end
function Graph:remove_all_functions() self.functions = {} end
function Graph:update_functions() end
function Graph:_sx(v) return self.x + util.linlin(self.x_min, self.x_max, 0, self.width, v) end
function Graph:_sy(v) return self.y + self.height - util.linlin(self.y_min, self.y_max, 0, self.height, v) end
function Graph:redraw()
  local lvl = self.active and 15 or 5
  screen.line_width(1)
  if self.show_x_axis then screen.level(3); screen.move(self.x, self:_sy(math.max(self.y_min, math.min(0, self.y_max)))); screen.line_rel(self.width, 0); screen.stroke() end
  if self.show_y_axis then screen.level(3); screen.move(self:_sx(math.max(self.x_min, math.min(0, self.x_max))), self.y); screen.line_rel(0, self.height); screen.stroke() end
  for _, f in ipairs(self.functions) do
    screen.level(lvl)
    for i = 0, self.width do
      local xv = util.linlin(0, self.width, self.x_min, self.x_max, i)
      local ok, yv = pcall(f.fn, xv)
      if ok and yv then local sy = self:_sy(util.clamp(yv, math.min(self.y_min, self.y_max), math.max(self.y_min, self.y_max))); if i == 0 then screen.move(self.x + i, sy) else screen.line(self.x + i, sy) end end
    end
    screen.stroke()
  end
  if #self.points > 0 then
    if self.style ~= 'point' then
      screen.level(lvl)
      for i, p in ipairs(self.points) do if i == 1 then screen.move(self:_sx(p.x), self:_sy(p.y)) else screen.line(self:_sx(p.x), self:_sy(p.y)) end end
      screen.stroke()
    end
    if self.style ~= 'line' and self.style ~= 'spline' then
      for _, p in ipairs(self.points) do screen.level(p.highlight and 15 or lvl); screen.rect(self:_sx(p.x) - 1, self:_sy(p.y) - 1, 3, 3); screen.fill() end
    end
  end
end
return Graph
