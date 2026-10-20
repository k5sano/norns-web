-- listselect overlay
local ls = {}
function ls.enter(list, callback, default)
  local o = { list = list or {}, pos = 1 }
  if default then for i, v in ipairs(o.list) do if v == default then o.pos = i end end end
  local function finish(v) norns.overlay_pop(); if callback then callback(v) end end
  function o.redraw()
    local first = util.clamp(o.pos - 3, 1, math.max(1, #o.list - 6))
    for i = first, math.min(#o.list, first + 6) do
      screen.level(i == o.pos and 15 or 4)
      screen.move(0, 8 + (i - first) * 9)
      screen.text(tostring(o.list[i]))
    end
  end
  function o.enc(_, n, d) if n == 2 then o.pos = util.clamp(o.pos + d, 1, math.max(1, #o.list)) end end
  function o.key(_, n, z)
    if z ~= 1 then return end
    if n == 3 then finish(o.list[o.pos]) elseif n == 2 then finish('cancel') end
  end
  norns.overlay_push(o)
end
return ls
