-- ui widgets
local UI = {}

-- Pages
UI.Pages = {}; UI.Pages.__index = UI.Pages
function UI.Pages.new(index, num_pages) return setmetatable({ index = index or 1, num_pages = num_pages or 3 }, UI.Pages) end
function UI.Pages:set_index(i) self.index = util.clamp(i, 1, self.num_pages) end
function UI.Pages:set_index_delta(d, wrap)
  local i = self.index + d
  if wrap then i = ((i - 1) % self.num_pages) + 1 end
  self:set_index(i)
end
function UI.Pages:redraw()
  local h = math.floor(64 / self.num_pages)
  screen.line_width(1)
  for i = 1, self.num_pages do
    screen.level(i == self.index and 5 or 1)
    screen.move(127, (i - 1) * h + 1)
    screen.line(127, i * h - 1)
    screen.stroke()
  end
end

-- Tabs
UI.Tabs = {}; UI.Tabs.__index = UI.Tabs
function UI.Tabs.new(index, titles) return setmetatable({ index = index or 1, titles = titles or {}, active = true }, UI.Tabs) end
function UI.Tabs:set_index(i) self.index = util.clamp(i, 1, #self.titles) end
function UI.Tabs:set_index_delta(d, wrap)
  local i = self.index + d
  if wrap then i = ((i - 1) % #self.titles) + 1 end
  self:set_index(i)
end
function UI.Tabs:redraw()
  local w = 128 / math.max(1, #self.titles)
  for i, t in ipairs(self.titles) do
    screen.level(i == self.index and (self.active and 15 or 5) or 3)
    screen.move((i - 1) * w + w / 2, 6)
    screen.text_center(t)
  end
end

-- ListBox
UI.ListBox = {}; UI.ListBox.__index = UI.ListBox
function UI.ListBox.new(x, y, entries, index)
  return setmetatable({ x = x or 0, y = y or 0, entries = entries or {}, index = index or 1, len = 5, active = true, text_align = 'left' }, UI.ListBox)
end
function UI.ListBox:set_index(i) self.index = util.clamp(i, 1, math.max(1, #self.entries)) end
function UI.ListBox:set_index_delta(d, wrap)
  local i = self.index + d
  if wrap then i = ((i - 1) % math.max(1, #self.entries)) + 1 end
  self:set_index(i)
end
function UI.ListBox:set_entries(e) self.entries = e; self:set_index(self.index) end
function UI.ListBox:redraw()
  local first = util.clamp(self.index - 2, 1, math.max(1, #self.entries - self.len + 1))
  for i = first, math.min(#self.entries, first + self.len - 1) do
    screen.level(i == self.index and (self.active and 15 or 4) or 3)
    local y = self.y + (i - first) * 11 + 8
    screen.move(self.text_align == 'right' and (self.x + 127) or (self.text_align == 'center' and (self.x + 64) or self.x), y)
    local s = tostring(self.entries[i])
    if self.text_align == 'right' then screen.text_right(s) elseif self.text_align == 'center' then screen.text_center(s) else screen.text(s) end
  end
end

-- ScrollingList
UI.ScrollingList = {}; UI.ScrollingList.__index = UI.ScrollingList
function UI.ScrollingList.new(x, y, index, entries)
  return setmetatable({ x = x or 0, y = y or 0, index = index or 1, entries = entries or {}, num_visible = 5, num_above_selected = 1, text_align = 'left', active = true }, UI.ScrollingList)
end
UI.ScrollingList.set_index = UI.ListBox.set_index
UI.ScrollingList.set_index_delta = UI.ListBox.set_index_delta
function UI.ScrollingList:redraw()
  local n = #self.entries
  local first = util.clamp(self.index - self.num_above_selected, 1, math.max(1, n - self.num_visible + 1))
  for i = first, math.min(n, first + self.num_visible - 1) do
    screen.level(i == self.index and (self.active and 15 or 4) or 3)
    local y = self.y + (i - first) * 11
    if self.text_align == 'right' then screen.move(self.x, y); screen.text_right(tostring(self.entries[i]))
    elseif self.text_align == 'center' then screen.move(self.x, y); screen.text_center(tostring(self.entries[i]))
    else screen.move(self.x, y); screen.text(tostring(self.entries[i])) end
  end
end

-- List
UI.List = {}; UI.List.__index = UI.List
function UI.List.new(x, y, index, entries) return setmetatable({ x = x or 0, y = y or 0, index = index or 1, entries = entries or {}, active = true, text_align = 'left' }, UI.List) end
UI.List.set_index = UI.ListBox.set_index
UI.List.set_index_delta = UI.ListBox.set_index_delta
function UI.List:redraw()
  for i, e in ipairs(self.entries) do
    screen.level(i == self.index and (self.active and 15 or 4) or 3)
    screen.move(self.x, self.y + (i - 1) * 11)
    local s = tostring(e)
    if self.text_align == 'right' then screen.text_right(s) elseif self.text_align == 'center' then screen.text_center(s) else screen.text(s) end
  end
end

-- Dial
UI.Dial = {}; UI.Dial.__index = UI.Dial
function UI.Dial.new(x, y, size, value, min_value, max_value, rounding, start_value, markers, units, title)
  local d = setmetatable({}, UI.Dial)
  d.x = x or 0; d.y = y or 0; d.size = size or 22
  d.value = value or 0; d.min_value = min_value or 0; d.max_value = max_value or 1
  d.rounding = rounding or 0.01; d.start_value = start_value or d.min_value
  d.markers = markers or {}; d.units = units; d.title = title; d.active = true
  return d
end
function UI.Dial:set_value(v) self.value = util.clamp(v, self.min_value, self.max_value) end
function UI.Dial:set_value_delta(d) self:set_value(self.value + d) end
function UI.Dial:set_marker_position(i, v) self.markers[i] = util.clamp(v, self.min_value, self.max_value) end
function UI.Dial:redraw()
  local r = self.size / 2
  local cx, cy = self.x + r, self.y + r
  local a0, span = math.pi * 0.75, math.pi * 1.5
  local function ang(v) return a0 + util.linlin(self.min_value, self.max_value, 0, 1, v) * span end
  screen.line_width(2.5)
  screen.level(3)
  screen.arc(cx, cy, r - 1.5, a0, a0 + span)
  screen.stroke()
  screen.level(self.active and 15 or 5)
  local s, e = ang(self.start_value), ang(self.value)
  if e < s then s, e = e, s end
  screen.arc(cx, cy, r - 1.5, s, math.max(e, s + 0.05))
  screen.stroke()
  screen.line_width(1)
  for _, m in ipairs(self.markers) do
    local a = ang(m)
    screen.level(self.active and 15 or 5)
    screen.move(cx + math.cos(a) * (r - 4), cy + math.sin(a) * (r - 4))
    screen.line(cx + math.cos(a) * (r + 1), cy + math.sin(a) * (r + 1))
    screen.stroke()
  end
  local v = util.round(self.value, self.rounding)
  screen.level(self.active and 15 or 3)
  screen.move(cx, self.y + self.size + 6)
  screen.text_center(tostring(v) .. (self.units and (' ' .. self.units) or ''))
  if self.title then screen.level(3); screen.move(cx, self.y - 2); screen.text_center(self.title) end
end

-- Slider
UI.Slider = {}; UI.Slider.__index = UI.Slider
function UI.Slider.new(x, y, width, height, value, min_value, max_value, markers, direction)
  return setmetatable({ x = x or 0, y = y or 0, width = width or 3, height = height or 36, value = value or 0,
    min_value = min_value or 0, max_value = max_value or 1, markers = markers or {}, direction = direction or 'up', active = true }, UI.Slider)
end
function UI.Slider:set_value(v) self.value = util.clamp(v, self.min_value, self.max_value) end
function UI.Slider:set_value_delta(d) self:set_value(self.value + d) end
function UI.Slider:set_marker_position(i, v) self.markers[i] = util.clamp(v, self.min_value, self.max_value) end
function UI.Slider:redraw()
  screen.level(3)
  screen.rect(self.x + 0.5, self.y + 0.5, self.width - 1, self.height - 1)
  screen.stroke()
  local f = util.linlin(self.min_value, self.max_value, 0, 1, self.value)
  screen.level(self.active and 15 or 5)
  if self.direction == 'up' then local h = math.floor(self.height * f + 0.5); screen.rect(self.x, self.y + self.height - h, self.width, h)
  elseif self.direction == 'down' then screen.rect(self.x, self.y, self.width, math.floor(self.height * f + 0.5))
  elseif self.direction == 'left' then local w = math.floor(self.width * f + 0.5); screen.rect(self.x + self.width - w, self.y, w, self.height)
  else screen.rect(self.x, self.y, math.floor(self.width * f + 0.5), self.height) end
  screen.fill()
end

-- PlaybackIcon
UI.PlaybackIcon = {}; UI.PlaybackIcon.__index = UI.PlaybackIcon
function UI.PlaybackIcon.new(x, y, size, status) return setmetatable({ x = x or 0, y = y or 0, size = size or 6, status = status or 1, active = true }, UI.PlaybackIcon) end
function UI.PlaybackIcon:redraw()
  local x, y, s = self.x, self.y, self.size
  screen.level(self.active and 15 or 5)
  if self.status == 1 then screen.move(x, y); screen.line(x + s, y + s / 2); screen.line(x, y + s); screen.close(); screen.fill()
  elseif self.status == 2 then screen.move(x + s, y); screen.line(x, y + s / 2); screen.line(x + s, y + s); screen.close(); screen.fill()
  elseif self.status == 3 then screen.rect(x, y, s / 3, s); screen.rect(x + s * 2 / 3, y, s / 3, s); screen.fill()
  else screen.rect(x, y, s, s); screen.fill() end
end

-- Message
UI.Message = {}; UI.Message.__index = UI.Message
function UI.Message.new(text_array) return setmetatable({ text = text_array or {}, active = true }, UI.Message) end
function UI.Message:redraw()
  local n = #self.text
  local y = 32 - (n - 1) * 5
  for i, t in ipairs(self.text) do
    screen.level(self.active and 15 or 5)
    screen.move(64, y + (i - 1) * 10 + 3)
    screen.text_center(t)
  end
end
return UI
