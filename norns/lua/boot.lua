-- norns web emulator runtime (matron side)
-- everything a script sees lives here; JS natives are the __xxx globals.

local _now = 0
local _beats = 0
local function report(e) __report(tostring(e)) end
local function safe(f, ...)
  if type(f) ~= 'function' then return end
  local ok, e = pcall(f, ...)
  if not ok then report(e) end
  return ok, e
end
local function safe_global(name, ...) return safe(rawget(_G, name), ...) end
local warned = {}
local function warn_once(key, msg)
  if not warned[key] then warned[key] = true; __sys(msg or (key .. ' は未実装のため無視されます')) end
end
local function stub(name)
  local mt = {}
  mt.__index = function(t, k)
    warn_once(name .. '.' .. tostring(k))
    local child
    child = setmetatable({}, { __index = function() return child end, __call = function() end })
    return child
  end
  mt.__call = function() end
  return setmetatable({}, mt)
end

print = function(...)
  local n = select('#', ...)
  local t = {}
  for i = 1, n do t[i] = tostring((select(i, ...))) end
  __print(table.concat(t, '\t'))
end
math.randomseed(__seed())
if not math.pow then math.pow = function(a, b) return a ^ b end end
if not table.getn then table.getn = function(t) return #t end end
if not unpack then unpack = table.unpack end
if not loadstring then loadstring = load end

-- paths -------------------------------------------------------------------
_path = {
  home = '/home/we/', dust = '/home/we/dust/', code = '/home/we/dust/code/',
  data = '/home/we/dust/data/', audio = '/home/we/dust/audio/', tape = '/home/we/dust/audio/tape/',
  extn = '/home/we/dust/code/', norns = '/home/we/norns/',
  favorites = '/home/we/dust/data/system.favorites',
  enabled_mods = '/home/we/dust/data/system.mods',
  keyboard_layout = '/home/we/dust/data/system.kbd_layout',
}
local CORE = '/home/we/norns/lua/lib/'

local function short(p) return (p:gsub('^' .. _path.code:gsub('%p', '%%%0'), '')) end

-- io over the virtual dust filesystem -------------------------------------
local File = {}; File.__index = File
local real_io = io
io = {}
function io.open(path, mode)
  mode = mode or 'r'
  path = tostring(path)
  local f = setmetatable({ path = path, mode = mode, pos = 1, buf = '' }, File)
  if mode:find('r') then
    local s = __fs_read(path)
    if not s then return nil, path .. ': No such file or directory', 2 end
    f.buf = s
    f.writable = mode:find('+') ~= nil
  elseif mode:find('a') then
    f.buf = __fs_read(path) or ''; f.pos = #f.buf + 1; f.writable = true; f.dirty = true
  else
    f.writable = true; f.dirty = true
  end
  return f
end
function File:read(fmt, ...)
  fmt = fmt or 'l'
  if type(fmt) == 'number' then
    if self.pos > #self.buf then return nil end
    local s = self.buf:sub(self.pos, self.pos + fmt - 1); self.pos = self.pos + #s; return s
  end
  fmt = tostring(fmt):gsub('^%*', '')
  local c = fmt:sub(1, 1)
  if c == 'a' then local s = self.buf:sub(self.pos); self.pos = #self.buf + 1; return s end
  if c == 'n' then
    local s, e = self.buf:find('^%s*[-+]?%d*%.?%d+[eE]?[-+]?%d*', self.pos)
    if not s then return nil end
    local v = tonumber(self.buf:sub(s, e)); self.pos = e + 1; return v
  end
  if self.pos > #self.buf then return nil end
  local e = self.buf:find('\n', self.pos, true)
  local line
  if e then
    line = self.buf:sub(self.pos, c == 'L' and e or e - 1); self.pos = e + 1
  else
    line = self.buf:sub(self.pos); self.pos = #self.buf + 1
  end
  return (line:gsub('\r$', ''))
end
function File:lines(fmt) return function() return self:read(fmt or 'l') end end
function File:write(...)
  for i = 1, select('#', ...) do
    local s = tostring((select(i, ...)))
    self.buf = self.buf:sub(1, self.pos - 1) .. s .. self.buf:sub(self.pos + #s)
    self.pos = self.pos + #s
  end
  self.dirty = true
  return self
end
function File:seek(whence, off)
  whence = whence or 'cur'; off = off or 0
  if whence == 'set' then self.pos = off + 1 elseif whence == 'end' then self.pos = #self.buf + off + 1 else self.pos = self.pos + off end
  return self.pos - 1
end
function File:flush() if self.writable and self.dirty then __fs_write(self.path, self.buf); self.dirty = false end end
function File:close() self:flush(); return true end
function File:setvbuf() return true end
function io.lines(path, fmt)
  if not path then if cur_in then return cur_in:lines(fmt) end return function() return nil end end
  local f, e = io.open(path); if not f then error(e, 2) end
  return f:lines(fmt)
end
local cur_in, cur_out = nil, nil
function io.input(f)
  if f == nil then return cur_in end
  if type(f) == 'string' then local h, e = io.open(f, 'r'); if not h then error(e, 2) end f = h end
  cur_in = f; return f
end
function io.output(f)
  if f == nil then return cur_out end
  if type(f) == 'string' then local h, e = io.open(f, 'w'); if not h then error(e, 2) end f = h end
  cur_out = f; return f
end
function io.write(...)
  if cur_out then return cur_out:write(...) end
  local t = {} for i = 1, select('#', ...) do t[#t + 1] = tostring((select(i, ...))) end __print(table.concat(t))
end
function io.read(...) if cur_in then return cur_in:read(...) end return nil end
function io.popen(cmd)
  warn_once('io.popen', 'os コマンド (' .. tostring(cmd):sub(1, 40) .. ') は実行できません')
  return setmetatable({ buf = '', pos = 1, path = '' }, File)
end
function io.close(f) f = f or cur_out; if f then f:close() end if f == cur_out then cur_out = nil end end
io.stdout = { write = function(self, ...) io.write(...) end, flush = function() end }
io.stderr = io.stdout
os.execute = function() return true end
os.remove = function(p) __fs_remove(tostring(p)); return true end
os.rename = function(a, b) local s = __fs_read(a); if s then __fs_write(b, s); __fs_remove(a) end; return true end
os.getenv = function() return nil end
os.exit = function() end
os.tmpname = function() return '/tmp/lua_' .. math.random(100000) end

function loadfile(path, mode, env)
  local s = __fs_read(path)
  if not s then return nil, 'cannot open ' .. short(path) end
  return load(s, '@' .. path, mode, env or _G)
end
function dofile(path)
  local f, e = loadfile(path)
  if not f then error(e, 2) end
  return f()
end

-- norns global --------------------------------------------------------------
norns = {
  version = { update = '260101', web = true },
  state = { script = '', name = 'none', shortname = 'none', path = _path.code, data = _path.data, lib = _path.code },
  script = {},
  enc = {},
  battery_percent = 100, battery_current = 0,
  is_norns = true, is_shield = false,
}
local enc_sens = { 1, 1, 1 }
local enc_acc = { 0, 0, 0 }
function norns.enc.sens(n, s) if n >= 1 and n <= 3 then enc_sens[n] = math.max(1, math.floor(s or 1)) elseif n == 0 then for i = 1, 3 do enc_sens[i] = math.max(1, math.floor(s or 1)) end end end
function norns.enc.accel() end
function norns.script.load(path) __load(path or norns.state.script) end
function norns.script.clear() __load('') end
function norns.shutdown() end
function norns.rerun() __load(norns.state.script) end
norns.none = function() end
norns.crow = { connected = function() return true end }
paths = setmetatable({ this = norns.state }, { __index = _path })
norns.encoders = { accel = { false, false, false }, sens = { 1, 1, 1 }, set_sens = function(n, s) norns.enc.sens(n, s) end, set_accel = function() end }
inf = math.huge
osc = { send = function() end, event = nil }
wifi = setmetatable({ state = 0, ip = '127.0.0.1' }, { __index = function() return function() end end })
_norns = setmetatable({}, { __index = function(t, k)
  k = tostring(k)
  if k:match('^screen_') and screen[k:sub(8)] then return screen[k:sub(8)] end
  warn_once('_norns.' .. k)
  local node
  node = setmetatable({}, { __index = function() return node end, __call = function() end })
  return node
end })
math.atan2 = math.atan2 or math.atan
norns.system_cmd = function(cmd, cb) if cb then clock.run(function() clock.sleep(0.01); cb('') end) end end
local keycode_n = 0
local KEYCODES = setmetatable({}, { __index = function(t, k) keycode_n = keycode_n + 1; rawset(t, k, keycode_n); return keycode_n end })
package.preload['core/mods'] = function()
  return { hook = { register = function() end }, menu = { register = function() end, redraw = function() end, exit = function() end }, this_name = 'mod', is_enabled = function() return false end, loaded_mod_names = function() return {} end, get_loaded_mod_names = function() return {} end }
end
package.cpath = package.cpath or ''
package.path = (package.path or '') .. ';/home/we/norns/lua/lib/?.lua'

local function set_state(path)
  local rel = short(path)
  local dir = rel:match('^(.*)/[^/]*$') or ''
  local file = rel:match('([^/]+)%.lua$') or rel
  local proj = rel:match('^([^/]+)/') or file
  local name = (dir ~= '' and proj == file) and proj or (dir ~= '' and (dir .. '/' .. file) or file)
  norns.state.script = path
  norns.state.name = name
  norns.state.shortname = file
  norns.state.path = _path.code .. (dir ~= '' and (dir .. '/') or '')
  norns.state.data = _path.data .. proj .. '/'
  norns.state.lib = norns.state.path .. 'lib/'
end

-- require / include -----------------------------------------------------------
local function find_module(name)
  local n = tostring(name):gsub('%.lua$', '')
  local slash = n:gsub('%.', '/')
  local cands = {
    CORE .. n .. '.lua', CORE .. slash .. '.lua',
    norns.state.path .. n .. '.lua', norns.state.path .. slash .. '.lua',
    _path.code .. n .. '.lua', _path.code .. slash .. '.lua',
    norns.state.lib .. n .. '.lua',
  }
  for _, p in ipairs(cands) do if __fs_exists(p) then return p end end
  -- tolerate 'core/xxx' and 'lib/xxx' prefixes used by some scripts
  local base = slash:gsub('^core/', ''):gsub('^lib/', '')
  if __fs_exists(CORE .. base .. '.lua') then return CORE .. base .. '.lua' end
  return nil
end
package.searchers = {
  package.searchers[1],
  function(name)
    local p = find_module(name)
    if not p then return '\n\tno file \'' .. tostring(name) .. '\' in dust or norns/lua/lib' end
    local f, e = loadfile(p)
    if not f then error(e, 0) end
    return f, p
  end,
}
function include(file)
  file = tostring(file):gsub('%.lua$', '')
  local cands = { _path.code .. file .. '.lua', norns.state.path .. file .. '.lua', norns.state.lib .. file .. '.lua' }
  for _, p in ipairs(cands) do if __fs_exists(p) then return dofile(p) end end
  local p = find_module(file)
  if p then return dofile(p) end
  local proj = file:match('^([^/]+)/')
  if proj and proj ~= '..' and not __fs_exists(_path.code .. proj) then
    error('include: ' .. file .. ' が見つかりません — 別プロジェクト「' .. proj .. '」が必要です（ライブラリから入れてください）', 2)
  end
  error('include: ' .. file .. ' が見つかりません（git submodule のファイルは GitHub の ZIP に含まれません）', 2)
end

-- core libraries as globals ----------------------------------------------------
util = require 'util'
tab = require 'tabutil'
controlspec = require 'controlspec'
function util.time() return __time() end
util.system_cmd = norns.system_cmd

-- screen ---------------------------------------------------------------------
screen = {}
for _, k in ipairs({ 'clear', 'level', 'move', 'line', 'move_rel', 'line_rel', 'rect', 'circle', 'arc', 'curve',
  'curve_rel', 'stroke', 'fill', 'close', 'pixel', 'font_size', 'font_face', 'line_width', 'line_cap', 'line_join',
  'aa', 'save', 'restore', 'translate', 'rotate', 'blend_mode', 'display_png' }) do
  local native = _G['__s_' .. k]
  screen[k] = function(...) return native(...) end
end
local menu -- forward
local overlay = nil
local function script_visible() return not (menu and menu.mode) and not overlay end
screen.update = function() __s_update(0) end
screen.text = function(s) __s_text(tostring(s)) end
screen.text_right = function(s) __s_text_right(tostring(s)) end
screen.text_center = function(s) __s_text_center(tostring(s)) end
screen.text_extents = function(s) return __s_text_extents(tostring(s)) end
screen.text_trim = function(s, w) s = tostring(s); while #s > 0 and __s_text_extents(s) > w do s = s:sub(1, -2) end return s end
screen.text_rotate = function(x, y, s, d) __s_text_rotate(x, y, tostring(s), d or 0, 0) end
screen.text_center_rotate = function(x, y, s, d) __s_text_rotate(x, y, tostring(s), d or 0, 1) end
screen.current_point = function() return __s_current_point() end
screen.load_png = function(p) return { __png = p } end
screen.display_image = function(img, x, y) if img then __s_display_png(img.__png or img, x or 0, y or 0) end end
screen.display_image_region = function(img, l, t, w, h, x, y) if img then __s_display_png(img.__png or img, x or 0, y or 0, l, t, w, h) end end
screen.ping = function() end
screen.sleep = function() end
screen.dirty = false
screen.peek = function(x, y, w, h) return __s_peek(x or 0, y or 0, w or 1, h or 1) end
screen.poke = function(x, y, w, h, s) __s_poke(x or 0, y or 0, w or 1, h or 1, s or '') end
screen.BLEND_MODES = { 'NONE', 'CLEAR', 'SOURCE', 'OVER', 'IN', 'OUT', 'ATOP', 'DEST', 'DEST_OVER', 'DEST_IN', 'DEST_OUT',
  'DEST_ATOP', 'XOR', 'ADD', 'SATURATE', 'MULTIPLY', 'SCREEN', 'OVERLAY', 'DARKEN', 'LIGHTEN', 'COLOR_DODGE',
  'COLOR_BURN', 'HARD_LIGHT', 'SOFT_LIGHT', 'DIFFERENCE', 'EXCLUSION' }
setmetatable(screen, { __index = function(t, k)
  warn_once('screen.' .. tostring(k))
  return function() end
end })

-- engine ----------------------------------------------------------------------
local engine_name = nil
engine = setmetatable({}, {
  __index = function(t, k)
    if k == 'name' then return engine_name end
    if k == 'commands' then return __engine_commands() end
    if k == 'names' then return { 'PolyPerc', 'TestSine', 'PolySub', 'MollyThePoly', 'None' } end
    if k == 'list_commands' then return function() for _, c in ipairs(__engine_commands_list()) do print(c) end end end
    if k == 'load' then return function(n, cb) engine_name = n; __engine_name(n); if cb then clock.run(function() clock.sleep(0.05); cb() end) end end end
    return function(...) __engine(tostring(k), ...) end
  end,
  __newindex = function(t, k, v)
    if k == 'name' then engine_name = tostring(v); __engine_name(engine_name) else rawset(t, k, v) end
  end,
})

-- metro -----------------------------------------------------------------------
metro = { num_metros = 36 }
local metros = {}
local M = {}
M.__index = function(t, k)
  if k == 'props' then return t end
  return M[k]
end
function metro.init(arg, time, count)
  local m = setmetatable({ time = 1, count = -1, stage = 1, init_stage = 1, running = false, next = 0, is_running = false }, M)
  if type(arg) == 'table' then
    m.event = arg.event; m.time = arg.time or 1; m.count = arg.count or -1
  else
    m.event = arg; m.time = time or 1; m.count = count or -1
  end
  metros[#metros + 1] = m
  m.id = #metros
  metro[m.id] = m
  return m
end
function M:start(time, count, stage)
  if type(time) == 'table' then time, count, stage = time.time, time.count, time.stage end
  if time then self.time = time end
  if count then self.count = count end
  self.stage = stage or self.init_stage or 1
  self.running = true; self.is_running = true
  self.next = _now + math.max(self.time, 0.001)
end
function M:stop() self.running = false; self.is_running = false end
function metro.free(id) if metros[id] then metros[id]:stop() end end
function metro.free_all() for _, m in ipairs(metros) do m:stop() end end

-- clock -----------------------------------------------------------------------
clock = { tempo = 110, transport = {}, threads = {} }
local cos = {}
local cid = 0
local current_co = nil
local function resume(id)
  local e = cos[id]
  if not e then return end
  current_co = id
  local ok, kind, val, off = coroutine.resume(e.co)
  current_co = nil
  if not ok then report(kind); cos[id] = nil; return end
  if coroutine.status(e.co) == 'dead' then cos[id] = nil; return end
  if kind == 'sleep' then
    e.mode = 't'; e.wake = math.max(e.wake or _now, _now - 0.05) + (tonumber(val) or 0)
  elseif kind == 'sync' then
    local q = tonumber(val) or 1
    if q <= 0 then q = 1 / 96 end
    off = tonumber(off) or 0
    e.mode = 'b'
    e.wakeb = (math.floor((_beats - off) / q + 1e-4) + 1) * q + off
  else
    e.mode = 't'; e.wake = _now
  end
end
function clock.run(f, ...)
  if type(f) ~= 'function' then error('clock.run には関数を渡してください', 2) end
  local args = table.pack(...)
  cid = cid + 1
  local id = cid
  cos[id] = { co = coroutine.create(function() f(table.unpack(args, 1, args.n)) end), mode = 't', wake = _now }
  resume(id)
  return id
end
function clock.sleep(s) coroutine.yield('sleep', s) end
function clock.sync(b, off) coroutine.yield('sync', b, off) end
function clock.cancel(id) if id then cos[id] = nil end end
function clock.cancel_all() cos = {} end
function clock.get_beats() return _beats end
function clock.get_tempo() return clock.tempo end
function clock.get_beat_sec(x) return (x or 1) * 60 / clock.tempo end
function clock.set_source() end
function clock.internal_set_tempo(t) params:set('clock_tempo', t) end
clock.internal = { set_tempo = function(t) params:set('clock_tempo', t) end, start = function() end, stop = function() end }
clock.link = { set_tempo = function() end, start = function() end, stop = function() end, set_quantum = function() end }
clock.crow = { in_div = function() end }
clock.midi = {}
function clock.add_params() end
function clock.lookup() return nil end

-- params ----------------------------------------------------------------------
paramset = require 'paramset'
params = paramset.new('params', 'params')
params:add_number('clock_tempo', 'tempo', 1, 300, 110)
params:set_action('clock_tempo', function(v)
  clock.tempo = v
  if clock.tempo_change_handler then safe(clock.tempo_change_handler, v) end
end)
params:hide('clock_tempo')
params:add_option('clock_source', 'source', { 'internal', 'midi', 'link', 'crow' }, 1)
params:hide('clock_source')
params:add_trigger('clock_reset', 'reset')
params:hide('clock_reset')
for _, id in ipairs({ 'clock_crow_out', 'clock_crow_in_div', 'clock_midi_out', 'link_quantum', 'clock_crow_out_div', 'clock_link_quantum', 'clock_link_start_stop_sync', 'clock_midi_out_1', 'clock_midi_out_2', 'clock_midi_out_3', 'clock_midi_out_4', 'clock_midi_out_5', 'clock_midi_out_6', 'clock_midi_out_7', 'clock_midi_out_8', 'clock_midi_out_9', 'clock_midi_out_10', 'clock_midi_out_11', 'clock_midi_out_12', 'clock_midi_out_13', 'clock_midi_out_14', 'clock_midi_out_15', 'clock_midi_out_16', 'clock_crow_out_1', 'clock_crow_out_2', 'clock_crow_out_3', 'clock_crow_out_4' }) do params:add_number(id, id, 0, 16, 1); params:hide(id) end
-- system audio params (dB like norns) mapped onto the mixer
local function dbamp(db) if db <= -60 then return 0 end return 10 ^ (db / 20) end
local DBSPEC = controlspec.new(-math.huge, 6, 'db', 0, 0, 'dB')
DBSPEC.minval = -60
local function audio_param(id, mixkey, default)
  params:add_control(id, id, controlspec.new(-60, 6, 'lin', 0, default or 0, 'dB'))
  params:set_action(id, function(v) __mix(mixkey, dbamp(v)) end)
  params:hide(id)
end
audio_param('output_level', 'level_dac', 0)
audio_param('input_level', 'level_adc', 0)
audio_param('monitor_level', 'level_monitor', 0)
audio_param('engine_level', 'level_eng', 0)
audio_param('softcut_level', 'level_cut', 0)
audio_param('tape_level', 'level_tape', 0)
audio_param('rev_eng_input', 'level_eng_rev', -12)
audio_param('rev_cut_input', 'level_cut_rev', -60)
audio_param('rev_monitor_input', 'level_monitor_rev', -60)
audio_param('rev_tape_input', 'level_tape_rev', -60)
audio_param('rev_return_level', 'rev_return_level', -4)
audio_param('cut_input_adc', 'level_adc_cut', 0)
audio_param('cut_input_eng', 'level_eng_cut', -60)
audio_param('cut_input_tape', 'level_tape_cut', -60)
params:add_option('reverb', 'reverb', { 'OFF', 'ON' }, 2)
params:set_action('reverb', function(v) __mix('rev_on', v == 2 and 1 or 0) end)
params:hide('reverb')
params:add_option('compressor', 'compressor', { 'OFF', 'ON' }, 2)
params:set_action('compressor', function(v) __mix('comp_on', v == 2 and 1 or 0) end)
params:hide('compressor')
params:add_option('monitor_mode', 'monitor mode', { 'STEREO', 'MONO' }, 1)
params:hide('monitor_mode')
params:add_number('headphone_gain', 'headphone', 0, 63, 40)
params:hide('headphone_gain')
for _, id in ipairs({ 'rev_pre_delay', 'rev_lf_fc', 'rev_low_time', 'rev_mid_time', 'rev_hf_damping', 'comp_mix', 'comp_ratio',
  'comp_threshold', 'comp_attack', 'comp_release', 'comp_pre_gain', 'comp_post_gain' }) do
  params:add_number(id, id, -1000, 20000, 0); params:hide(id)
end
params._system_count = #params.params
local MIXMAP = { output = 'output_level', input = 'input_level', monitor = 'monitor_level', engine = 'engine_level', cut = 'softcut_level', softcut = 'softcut_level', tape = 'tape_level' }
mix = setmetatable({}, { __index = function(t, k)
  local f = params[k]
  if type(f) ~= 'function' then return nil end
  return function(self, id, ...) return f(params, MIXMAP[id] or id, ...) end
end })

-- grid ------------------------------------------------------------------------
grid = { vports = {}, devices = {}, update_devices = function() end, add = nil, remove = nil }
local G = {}; G.__index = G
local gdev = setmetatable({ cols = 16, rows = 8, name = 'monome 128', id = 1, port = 1, device = { cols = 16, rows = 8, name = 'monome 128', id = 1, port = 1 } }, G)
grid.vports[1] = gdev
for i = 2, 4 do grid.vports[i] = setmetatable({ cols = 0, rows = 0, name = 'none' }, G) end
local gused = false
function grid.connect(n) if (n or 1) == 1 then __used('grid'); return gdev end return grid.vports[n] or grid.vports[2] end
function G:led(x, y, l) if self == gdev then __g_led(x, y, l) end end
function G:all(l) if self == gdev then __g_all(l) end end
function G:refresh() if self == gdev then __g_refresh() end end
function G:rotation() end
function G:intensity() end
function G:tilt_enable() end
function G.cleanup() end
function grid.cleanup() end
function __grid_key(x, y, z) if gdev.key then safe(gdev.key, x, y, z) end end

-- arc -------------------------------------------------------------------------
arc = { vports = {} }
local A = {}; A.__index = A
local adev = setmetatable({ name = 'monome arc 4', id = 1, port = 1, device = { name = 'monome arc 4' } }, A)
arc.vports[1] = adev
arc.devices = {}
arc.update_devices = function() end
function arc.connect(n) __used('arc'); return adev end
function A:led(r, x, l) __a_led(r, x, l) end
function A:all(l) __a_all(l) end
function A:segment(r, from, to, l) __a_segment(r, from, to, l) end
function A:refresh() __a_refresh() end
function A:intensity() end
function __arc_delta(n, d) if adev.delta then safe(adev.delta, n, d) end end
function __arc_key(n, z) if adev.key then safe(adev.key, n, z) end end

-- midi / hid (not emulated) ----------------------------------------------------
local function null_device(name)
  return setmetatable({ name = 'none', device = nil }, { __index = function() return function() end end })
end
midi = setmetatable({ vports = {}, devices = {} }, { __index = function() return function() end end })
for i = 1, 16 do midi.vports[i] = null_device('midi') end
function midi.connect() return null_device('midi') end
function midi.to_msg() return {} end
function midi.to_data() return {} end
hid = { vports = { null_device('hid'), null_device('hid'), null_device('hid'), null_device('hid') }, devices = {}, update_devices = function() end, connect = function() return null_device('hid') end, codes = KEYCODES, types = setmetatable({}, { __index = function() return 1 end }) }
keyboard = { code = function() end, char = function() end, state = {}, codes = KEYCODES, shift = function() return false end, ctrl = function() return false end, alt = function() return false end, meta = function() return false end }
gamepad = {}

-- audio -----------------------------------------------------------------------
audio = setmetatable({}, { __index = function(t, k)
  local f = function(...) return __mix(k, ...) end
  rawset(t, k, f)
  return f
end })
function audio.file_info(path) return __file_info(tostring(path)) end
function audio.rev_on() __mix('rev_on', 1) end
function audio.rev_off() __mix('rev_on', 0) end
function audio.comp_on() __mix('comp_on', 1) end
function audio.comp_off() __mix('comp_on', 0) end

-- poll ------------------------------------------------------------------------
poll = { polls = {} }
local Poll = {}; Poll.__index = Poll
local active_polls = {}
function poll.set(name, cb)
  local p = setmetatable({ name = name, callback = cb, time = 0.25, next = 0, running = false }, Poll)
  poll.polls[name] = p
  return p
end
function poll.list_names() for _, n in ipairs({ 'amp_in_l', 'amp_in_r', 'amp_out_l', 'amp_out_r', 'pitch_in_l', 'pitch_in_r', 'cpu_avg' }) do print(n) end end
function Poll:start() self.running = true; self.next = _now; active_polls[self] = true end
function Poll:stop() self.running = false; active_polls[self] = nil end
function Poll:update() if self.callback then safe(self.callback, __poll_value(self.name)) end end
function Poll:set_time(t) self.time = t end
function poll.clear_all() for p in pairs(active_polls) do p:stop() end end
poll.clear_all_ = poll.clear_all

-- softcut ---------------------------------------------------------------------
softcut = setmetatable({ VOICE_COUNT = 6, BUFFER_SIZE = 2 ^ 22 / 48000 }, { __index = function(t, k)
  local f = function(...) return __sc(k, ...) end
  rawset(t, k, f)
  return f
end })
local sc_phase, sc_render, sc_position = nil, nil, nil
function softcut.event_phase(f) sc_phase = f end
function softcut.event_render(f) sc_render = f end
function softcut.event_position(f) sc_position = f end
function softcut.poll_start_phase() __sc('poll_start_phase') end
function softcut.poll_stop_phase() __sc('poll_stop_phase') end
function softcut.voice_count() return 6 end
function __sc_phase(v, p) if sc_phase then safe(sc_phase, v, p) end end
function __sc_render(ch, start, sps, samples) if sc_render then safe(sc_render, ch, start, sps, samples) end end
function __sc_position(v, p) if sc_position then safe(sc_position, v, p) end end
function softcut.defaults()
  local d = {}
  for i = 1, 6 do d[i] = { enable = 0, play = 0, rec = 0, level = 1, pan = 0, rate = 1, loop = 1, loop_start = 0, loop_end = 1, fade_time = 0.005, rec_level = 0, pre_level = 0, buffer = (i % 2 == 1) and 1 or 2 } end
  return d
end
function softcut.params() return {} end

-- crow ------------------------------------------------------------------------
crow = require 'crow_emu'
package.preload['crow'] = function() return crow end
package.preload['audio'] = function() return audio end
package.preload['cjson'] = function() return require 'cjson_emu' end
package.preload['cjson.safe'] = package.preload['cjson']
package.preload['params/option'] = function() return require 'param_option' end
package.preload['core/params/option'] = package.preload['params/option']
package.preload['core/audio'] = package.preload['audio']
package.preload['script'] = function() return norns.script end
package.preload['encoders'] = function() return norns.encoders end
package.preload['core/keyboard'] = function() return keyboard end
package.preload['hid_events'] = function() return { codes = KEYCODES, types = hid.types } end
package.preload['core/hid_events'] = package.preload['hid_events']
package.preload['core/midi'] = function() return midi end
package.preload['container/deque'] = function() return require 'container_deque' end
package.preload['container.deque'] = package.preload['container/deque']
norns.crow.public = crow.public
for _, k in ipairs({ 'loadscript', 'send', 'reset', 'init', 'version', 'identity', 'clear' }) do if not norns.crow[k] then norns.crow[k] = function(...) local f = crow[k]; if f then return f(...) end end end end
package.preload['core/crow'] = package.preload['crow']
package.preload['we/lib/polysub'] = function() return require 'polysub' end
function __crow_input(n, v) crow._input(n, v) end

-- overlays (fileselect / textentry / listselect) -------------------------------
function norns.overlay_push(o)
  overlay = o
  __s_show(1)
  if overlay.redraw then norns.overlay_redraw() end
end
function norns.overlay_pop()
  overlay = nil
  if menu.mode then __s_show(1); menu.redraw() else __s_show(0); __s_update(0); safe_global('redraw') end
end
function norns.overlay_redraw()
  if not overlay then return end
  __s_target(1)
  __s_clear(); __s_level(15); __s_font_size(8); __s_font_face(1); __s_line_width(1)
  safe(overlay.redraw, overlay)
  __s_update(1)
  __s_target(0)
end

-- menu ------------------------------------------------------------------------
menu = require 'menu_emu'
menu.init({ safe = safe, safe_global = safe_global, report = report, get_now = function() return _now end })
norns.menu = { status = function() return menu.mode end, toggle = function(s) menu.set_mode(s) end, set_status = function() end, redraw = function() menu.redraw() end, rebuild_params = function() end }
_menu = setmetatable({ rebuild_params = function() menu.redraw() end, redraw = function() menu.redraw() end, set_mode = function(m) menu.set_mode(m) end, panel = 1, page = 'HOME', alt = false, keyboardcode = function() end, keychar = function() end },
  { __index = function(t, k) if k == 'mode' then return menu.mode end end })

-- input routing -----------------------------------------------------------------
local k1_down, k1_other, k1_script = nil, false, false
function __key(n, z)
  if overlay then safe(overlay.key, overlay, n, z); norns.overlay_redraw(); return end
  if n == 1 then
    if z == 1 then
      k1_down = _now; k1_other = false; k1_script = not menu.mode
      if k1_script then safe_global('key', 1, 1) end
    else
      if k1_script then safe_global('key', 1, 0) end
      if k1_down and (_now - k1_down) < 0.3 and not k1_other then menu.set_mode(not menu.mode) end
      k1_down = nil
    end
    return
  end
  if k1_down then k1_other = true end
  if menu.mode then menu.key(n, z) else safe_global('key', n, z) end
end
function __enc(n, d)
  if overlay then safe(overlay.enc, overlay, n, d); norns.overlay_redraw(); return end
  if k1_down then k1_other = true end
  if menu.mode then menu.enc(n, d); return end
  local s = enc_sens[n] or 1
  if s > 1 then
    enc_acc[n] = enc_acc[n] + d
    if math.abs(enc_acc[n]) < s then return end
    d = enc_acc[n] > 0 and 1 or -1
    enc_acc[n] = 0
  end
  safe_global('enc', n, d)
end
function __menu_toggle() menu.set_mode(not menu.mode) end

-- lifecycle -----------------------------------------------------------------------
function __start(path)
  set_state(path)
  __s_show(0)
  local f, err = loadfile(path)
  if not f then report(err); return false end
  local ok, e = pcall(f)
  if not ok then report(e); return false end
  safe_global('init')
  local pub = norns.crow.public
  if type(rawget(pub, 'discovered')) == 'function' then safe(pub.discovered) end
  if menu.mode then menu.redraw() else safe_global('redraw') end
  return true
end
function __cleanup()
  safe_global('cleanup')
  metro.free_all()
  cos = {}
end

function __tick(now)
  local dt = now - _now
  if dt < 0 then dt = 0 end
  _now = now
  _beats = _beats + dt * clock.tempo / 60
  for i = 1, #metros do
    local m = metros[i]
    if m.running and _now >= m.next then
      if _now - m.next > 0.25 then m.next = _now end
      m.next = m.next + math.max(m.time, 0.001)
      local stage = m.stage
      m.stage = m.stage + 1
      if m.count > 0 and m.stage > m.count + (m.init_stage or 1) - 1 then m.running = false; m.is_running = false end
      if m.event then safe(m.event, stage) end
    end
  end
  local due = {}
  for id, e in pairs(cos) do
    if (e.mode == 'b' and _beats >= e.wakeb) or (e.mode ~= 'b' and e.wake <= _now) then due[#due + 1] = id end
  end
  table.sort(due)
  for _, id in ipairs(due) do resume(id) end
  for p in pairs(active_polls) do
    if p.running and _now >= p.next then
      p.next = _now + math.max(0.01, p.time or 0.25)
      if p.callback then safe(p.callback, __poll_value(p.name)) end
    end
  end
  crow._tick(_now, dt)
  menu.tick(_now)
end

function __repl(s)
  local f, err = load('return ' .. s, '=repl')
  if not f then f, err = load(s, '=repl') end
  if not f then report(err) return end
  local r = table.pack(pcall(f))
  if not r[1] then report(r[2]) return end
  if r.n > 1 then
    local t = {}
    for i = 2, r.n do t[#t + 1] = tostring(r[i]) end
    print(table.concat(t, '\t'))
  end
end

-- convenience: musicutil global for scripts that expect it
musicutil = require 'musicutil'
