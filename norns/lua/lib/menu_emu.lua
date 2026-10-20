-- norns system menu (K1 toggles): MIX / TAPE / HOME / PARAMETERS
local menu = { mode = false }
local h
local PAGES = { 'MIX', 'TAPE', 'HOME', 'PARAMS' }
local page = 3
local home_items = { 'SELECT', 'SYSTEM', 'SLEEP' }
local home_pos = 1
local sub = nil           -- nil | 'select' | 'preview' | 'system' | 'sleep'
local scripts, sel_pos = {}, 1
local preview_lines = {}
local ppos = 1
local mix = { { name = 'out', key = 'level_dac', v = 1 }, { name = 'eng', key = 'level_eng', v = 1 },
  { name = 'cut', key = 'level_cut', v = 1 }, { name = 'rev', key = 'rev_return_level', v = 0.6 } }
local mix_pos = 1
local last_draw = 0
local held_binary = nil

function menu.init(helpers) h = helpers end

local function line(y, s, lvl, right)
  screen.level(lvl)
  if right then screen.move(127, y); screen.text_right(right) end
  screen.move(0, y); screen.text(s)
end

local function header(title)
  screen.level(4)
  screen.move(0, 7)
  screen.text(title)
  for i = 1, #PAGES do
    screen.level(i == page and 10 or 2)
    screen.rect(100 + i * 6, 2, 4, 4)
    screen.fill()
  end
end

local draw = {}
function draw.MIX()
  header('MIX')
  for i, c in ipairs(mix) do
    local x = 14 + (i - 1) * 30
    screen.level(2)
    screen.rect(x, 14, 8, 40)
    screen.stroke()
    screen.level(i == mix_pos and 15 or 6)
    local hh = math.floor(c.v * 40 + 0.5)
    screen.rect(x, 54 - hh, 8, hh)
    screen.fill()
    screen.level(i == mix_pos and 15 or 4)
    screen.move(x + 4, 62)
    screen.text_center(c.name)
  end
end
function draw.TAPE()
  header('TAPE')
  line(26, 'tape is not emulated', 8)
  line(38, 'in the web version', 4)
  line(56, 'E1: change page', 3)
end
function draw.HOME()
  if sub == 'sleep' then return end
  if sub == 'select' then
    header('SELECT')
    if #scripts == 0 then line(30, 'no scripts in dust/code', 4) return end
    local first = util.clamp(sel_pos - 3, 1, math.max(1, #scripts - 5))
    for i = first, math.min(#scripts, first + 5) do
      line(18 + (i - first) * 9, scripts[i], i == sel_pos and 15 or 4)
    end
    return
  end
  if sub == 'preview' then
    for i, l in ipairs(preview_lines) do line(8 + (i - 1) * 9, l, i == 1 and 15 or 6) end
    line(62, 'K3 load   K2 back', 3)
    return
  end
  if sub == 'system' then
    header('SYSTEM')
    line(22, 'norns web emulator', 10)
    line(32, 'script: ' .. tostring(norns.state.shortname), 4)
    line(46, 'K3 restart script', home_pos == 2 and 15 or 4)
    line(56, 'K2 back', 3)
    return
  end
  header('HOME')
  screen.level(15)
  screen.move(0, 20)
  screen.text(tostring(norns.state.shortname or 'none'))
  for i, it in ipairs(home_items) do line(32 + (i - 1) * 10, it .. ' >', i == home_pos and 15 or 4) end
end
function draw.PARAMS()
  header('PARAMETERS')
  local list = params:menu_list()
  if #list == 0 then line(30, 'no parameters', 4) return end
  ppos = util.clamp(ppos, 1, #list)
  local first = util.clamp(ppos - 3, 1, math.max(1, #list - 5))
  for i = first, math.min(#list, first + 5) do
    local p = list[i]
    local y = 18 + (i - first) * 9
    local sel = (i == ppos)
    if p.t == params.tSEPARATOR then
      line(y, p.name ~= '' and p.name or '---', sel and 15 or 4)
    elseif p.t == params.tGROUP then
      line(y, '> ' .. p.name, sel and 15 or 4)
    else
      local ok, s = pcall(function() return p:string() end)
      local name = (p._in_group and ' ' or '') .. tostring(p.name)
      line(y, name, sel and 15 or 4, ok and tostring(s) or '?')
    end
  end
end

function menu.redraw()
  if not menu.mode then return end
  __s_target(1)
  __s_clear(); __s_level(15); __s_font_size(8); __s_font_face(1); __s_line_width(1)
  local ok, e = pcall(draw[PAGES[page]])
  if not ok then h.report(e) end
  __s_update(1)
  __s_target(0)
  last_draw = h.get_now()
end

function menu.set_mode(m)
  menu.mode = m and true or false
  if menu.mode then
    __s_show(1)
    menu.redraw()
  else
    if sub == 'sleep' then sub = nil end
    __s_show(0)
    __s_update(0)
    h.safe_global('redraw')
  end
  __menu_state(menu.mode)
end

local function load_scripts()
  scripts = __fs_scripts()
  sel_pos = 1
  local cur = norns.state.script and norns.state.script:gsub('^' .. _path.code:gsub('%p', '%%%0'), ''):gsub('%.lua$', '')
  for i, s in ipairs(scripts) do if s == cur then sel_pos = i end end
end
local function load_preview()
  preview_lines = {}
  local path = _path.code .. scripts[sel_pos] .. '.lua'
  local src = __fs_read(path) or ''
  for l in (src .. '\n'):gmatch('(.-)\r?\n') do
    local c = l:match('^%s*%-%-+%s?(.*)$')
    if c then
      if #preview_lines < 6 then preview_lines[#preview_lines + 1] = c end
    elseif l:match('%S') then break end
  end
  if #preview_lines == 0 then preview_lines = { scripts[sel_pos] } end
end

function menu.enc(n, d)
  if n == 1 and sub == nil then
    page = util.clamp(page + d, 1, #PAGES)
  elseif PAGES[page] == 'MIX' then
    if n == 2 then mix_pos = util.clamp(mix_pos + d, 1, #mix)
    elseif n == 3 then
      local c = mix[mix_pos]
      c.v = util.clamp(c.v + d * 0.02, 0, 1)
      __mix(c.key, c.v)
    end
  elseif PAGES[page] == 'HOME' then
    if n == 2 then
      if sub == 'select' then sel_pos = util.clamp(sel_pos + d, 1, math.max(1, #scripts))
      elseif sub == nil then home_pos = util.clamp(home_pos + d, 1, #home_items) end
    end
  elseif PAGES[page] == 'PARAMS' then
    local list = params:menu_list()
    if n == 2 then ppos = util.clamp(ppos + d, 1, math.max(1, #list))
    elseif n == 3 then
      local p = list[ppos]
      if p and p.t ~= params.tSEPARATOR and p.t ~= params.tGROUP and p.t ~= params.tTRIGGER and p.t ~= params.tFILE and p.t ~= params.tTEXT then
        local ok, e = pcall(p.delta, p, d)
        if not ok then h.report(e) end
      end
    end
  end
  menu.redraw()
end

function menu.key(n, z)
  local pg = PAGES[page]
  if pg == 'HOME' then
    if sub == 'sleep' then if z == 1 then sub = nil end menu.redraw() return end
    if z ~= 1 then return end
    if sub == nil then
      if n == 3 then
        local it = home_items[home_pos]
        if it == 'SELECT' then load_scripts(); sub = 'select'
        elseif it == 'SYSTEM' then sub = 'system'
        elseif it == 'SLEEP' then sub = 'sleep' end
      end
    elseif sub == 'select' then
      if n == 3 and scripts[sel_pos] then load_preview(); sub = 'preview' elseif n == 2 then sub = nil end
    elseif sub == 'preview' then
      if n == 3 then sub = nil; __load(_path.code .. scripts[sel_pos] .. '.lua') return
      elseif n == 2 then sub = 'select' end
    elseif sub == 'system' then
      if n == 3 then sub = nil; __load(norns.state.script) return elseif n == 2 then sub = nil end
    end
  elseif pg == 'PARAMS' then
    local list = params:menu_list()
    local p = list[ppos]
    if n == 3 and p then
      if p.t == params.tTRIGGER then if z == 1 then p:bang() end
      elseif p.t == params.tBINARY then
        if p.behavior == 'momentary' then p:set(z)
        elseif z == 1 then p:set(p.value == 1 and 0 or 1) end
      elseif p.t == params.tFILE and z == 1 then
        require('fileselect').enter(_path.dust, function(f) if f and f ~= 'cancel' then p:set(f) end end)
        return
      elseif p.t == params.tTEXT and z == 1 then
        require('textentry').enter(function(t) if t then p:set(t) end end, p.value, p.name)
        return
      end
    end
  end
  menu.redraw()
end

function menu.tick(t)
  if menu.mode and t - last_draw > 0.1 and sub ~= 'sleep' then menu.redraw() end
end
return menu
