-- textentry overlay
local te = {}
local CHARS = ' abcdefghijklmnopqrstuvwxyz0123456789-_.'
function te.enter(callback, default, heading, check)
  local o = { txt = default or '', heading = heading or '', pos = 2, row = 0, warn = nil }
  local items = { 'DEL', 'OK' }
  local function finish(v) norns.overlay_pop(); if callback then callback(v) end end
  function o.redraw()
    screen.level(4); screen.move(0, 8); screen.text(o.heading)
    screen.level(15); screen.move(0, 24); screen.text(o.txt .. '_')
    if o.warn then screen.level(8); screen.move(0, 36); screen.text(o.warn) end
    if o.row == 0 then
      for i = -6, 6 do
        local p = ((o.pos - 1 + i) % #CHARS) + 1
        screen.level(i == 0 and 15 or 3)
        screen.move(64 + i * 9, 52)
        local c = CHARS:sub(p, p)
        screen.text_center(c == ' ' and '_' or c)
      end
    end
    for i, it in ipairs(items) do
      screen.level((o.row == i) and 15 or 3)
      screen.move(i == 1 and 0 or 127, 62)
      if i == 1 then screen.text(it) else screen.text_right(it) end
    end
  end
  function o.enc(_, n, d)
    if n == 2 then o.pos = ((o.pos - 1 + d) % #CHARS) + 1; o.row = 0
    elseif n == 3 then o.row = util.clamp(o.row + d, 0, 2) end
  end
  function o.key(_, n, z)
    if z ~= 1 then return end
    if n == 3 then
      if o.row == 0 then o.txt = o.txt .. CHARS:sub(o.pos, o.pos)
      elseif o.row == 1 then o.txt = o.txt:sub(1, -2)
      else finish(o.txt) return end
      o.warn = check and check(o.txt) or nil
    elseif n == 2 then finish(nil) end
  end
  norns.overlay_push(o)
end
return te
