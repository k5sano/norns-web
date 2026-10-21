-- gridbuf
local GB = {}; GB.__index = GB
function GB.new(w, h) local b = setmetatable({ width = w or 16, height = h or 8, data = {} }, GB); b:all(0); return b end
function GB:led(x, y, z) if x >= 1 and x <= self.width and y >= 1 and y <= self.height then self.data[(y - 1) * self.width + x] = z end end
function GB:all(z) for i = 1, self.width * self.height do self.data[i] = z end end
function GB:get(x, y) return self.data[(y - 1) * self.width + x] or 0 end
function GB:led_level_set(x, y, l) self:led(x, y, l) end
function GB:led_level_all(l) self:all(l) end
function GB:led_level_get(x, y) return self:get(x, y) end
function GB:led_level_row(x, y, levels) for i, l in ipairs(levels) do self:led(x + i - 1, y, l) end end
function GB:led_level_col(x, y, levels) for i, l in ipairs(levels) do self:led(x, y + i - 1, l) end end
function GB:render(g) for y = 1, self.height do for x = 1, self.width do g:led(x, y, self.data[(y - 1) * self.width + x] or 0) end end end
return GB
