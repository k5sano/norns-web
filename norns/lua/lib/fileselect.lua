-- fileselect overlay
local fs = {}
function fs.enter(folder, callback, filter)
  folder = tostring(folder or _path.dust)
  if folder:sub(-1) ~= '/' then folder = folder .. '/' end
  local root = folder
  local o = { dir = folder, list = {}, pos = 1 }
  local function load()
    o.list = {}
    for _, n in ipairs(__fs_list(o.dir)) do
      if n:sub(-1) == '/' or filter == nil or filter == 'all' or n:lower():match('%.' .. tostring(filter):lower() .. '$') or (filter == 'audio' and n:lower():match('%.[wafmo][apilg][vfc3g]?[fc]?$')) then
        o.list[#o.list + 1] = n
      end
    end
    o.pos = 1
  end
  load()
  local function finish(v) norns.overlay_pop(); if callback then callback(v) end end
  function o.redraw()
    screen.level(4); screen.move(0, 7)
    screen.text(screen.text_trim and screen.text_trim(o.dir:gsub('^/home/we/', ''), 128) or o.dir)
    if #o.list == 0 then screen.level(4); screen.move(0, 30); screen.text('(empty)') end
    local first = util.clamp(o.pos - 3, 1, math.max(1, #o.list - 5))
    for i = first, math.min(#o.list, first + 5) do
      screen.level(i == o.pos and 15 or 4)
      screen.move(0, 18 + (i - first) * 9)
      screen.text(o.list[i])
    end
  end
  function o.enc(_, n, d) if n == 2 then o.pos = util.clamp(o.pos + d, 1, math.max(1, #o.list)) end end
  function o.key(_, n, z)
    if z ~= 1 then return end
    if n == 3 then
      local e = o.list[o.pos]
      if not e then return end
      if e:sub(-1) == '/' then o.dir = o.dir .. e; load() else finish(o.dir .. e) end
    elseif n == 2 then
      if o.dir ~= root then o.dir = o.dir:gsub('[^/]+/$', ''); load() else finish('cancel') end
    end
  end
  norns.overlay_push(o)
end
return fs
