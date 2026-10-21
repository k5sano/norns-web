-- crow emulation: 2 inputs, 4 outputs, ASL actions (to / loop / times / held / dyn and the usual helpers)
local crow = {}
local now = 0
local function report(e) __report(tostring(e)) end
local function safe(f, ...) if type(f) ~= 'function' then return end local ok, e = pcall(f, ...) if not ok then report(e) end end
local warned = {}
local function warn(k, msg) if not warned[k] then warned[k] = true; __sys(msg or __tr('crow: ' .. k .. ' は未実装のため無視されます', 'crow: ' .. k .. ' is not implemented and is ignored')) end end

-- shapes ----------------------------------------------------------------------------
local function bounce(x)
  if x < 1 / 2.75 then return 7.5625 * x * x
  elseif x < 2 / 2.75 then x = x - 1.5 / 2.75; return 7.5625 * x * x + 0.75
  elseif x < 2.5 / 2.75 then x = x - 2.25 / 2.75; return 7.5625 * x * x + 0.9375 end
  x = x - 2.625 / 2.75; return 7.5625 * x * x + 0.984375
end
local SHAPES = {
  linear = function(x) return x end,
  sine = function(x) return 0.5 - 0.5 * math.cos(math.pi * x) end,
  logarithmic = function(x) return 1 - (1 - x) ^ 3 end,
  exponential = function(x) return x ^ 3 end,
  now = function() return 1 end,
  wait = function(x) return x >= 1 and 1 or 0 end,
  over = function(x) local s = 1.70158; x = x - 1; return x * x * ((s + 1) * x + s) + 1 end,
  under = function(x) local s = 1.70158; return x * x * ((s + 1) * x - s) end,
  rebound = bounce,
}
SHAPES.lin = SHAPES.linear; SHAPES.log = SHAPES.logarithmic; SHAPES.expo = SHAPES.exponential; SHAPES.exp = SHAPES.exponential
local function shape_fn(s)
  if type(s) == 'function' then return s end
  return SHAPES[string.lower(tostring(s or 'linear'))] or SHAPES.linear
end

-- dynamic values ----------------------------------------------------------------------
local Dyn = {}
local function resolve(x, o)
  if type(x) == 'table' then
    if x.__dyn then local v = o.dyn[x.__dyn]; if v == nil then v = x.def end return resolve(v, o) end
    if x.__expr then return x.__expr(o) end
  end
  return tonumber(x) or 0
end
local function expr(f) return setmetatable({ __expr = f }, Dyn) end
Dyn.__add = function(a, b) return expr(function(o) return resolve(a, o) + resolve(b, o) end) end
Dyn.__sub = function(a, b) return expr(function(o) return resolve(a, o) - resolve(b, o) end) end
Dyn.__mul = function(a, b) return expr(function(o) return resolve(a, o) * resolve(b, o) end) end
Dyn.__div = function(a, b) return expr(function(o) local d = resolve(b, o); return d ~= 0 and resolve(a, o) / d or 0 end) end
Dyn.__unm = function(a) return expr(function(o) return -resolve(a, o) end) end

-- ASL constructors ------------------------------------------------------------------------
local ASL = {}
function ASL.to(v, t, s) return { k = 'to', v = v or 0, t = t or 0, s = s or 'linear' } end
function ASL.loop(body) return { k = 'loop', body = body or {} } end
function ASL.times(n, body) return { k = 'times', n = n or 1, body = body or {} } end
function ASL.held(body) return { k = 'held', body = body or {} } end
function ASL.lock(body) return { k = 'seq', body = body or {} } end
function ASL.dyn(t) for k, v in pairs(t) do return setmetatable({ __dyn = k, def = v }, Dyn) end end
function ASL.lfo(time, level, shape)
  time = time or 1; level = level or 5; shape = shape or 'sine'
  return ASL.loop{ ASL.to(level, time / 2, shape), ASL.to(-level, time / 2, shape) }
end
function ASL.oscillate(freq, level, shape)
  freq = freq or 1; level = level or 5; shape = shape or 'sine'
  return ASL.loop{ ASL.to(level, 1 / freq / 2, shape), ASL.to(-level, 1 / freq / 2, shape) }
end
function ASL.ramp(time, skew, level)
  time = time or 1; skew = skew or 0.5; level = level or 5
  return ASL.loop{ ASL.to(level, time * skew), ASL.to(-level, time * (1 - skew)) }
end
function ASL.pulse(time, level, polarity)
  time = time or 0.01; level = level or 5; polarity = polarity or 1
  local on, off = level, 0
  if polarity == 0 then on, off = 0, level end
  return { ASL.to(on, 0, 'now'), ASL.to(on, time), ASL.to(off, 0, 'now') }
end
function ASL.ar(a, r, level, shape)
  a = a or 0.05; r = r or 0.5; level = level or 7; shape = shape or 'log'
  return { ASL.to(level, a, shape), ASL.to(0, r, shape) }
end
function ASL.adsr(a, d, s, r, shape)
  a = a or 0.05; d = d or 0.3; s = s or 2; r = r or 2; shape = shape or 'linear'
  return { ASL.held{ ASL.to(5, a, shape), ASL.to(s, d, shape) }, ASL.to(0, r, shape) }
end
ASL.note = function(n, t) return { ASL.to((n or 0) / 12, 0, 'now'), ASL.to((n or 0) / 12, t or 0.1) } end
crow.asl = ASL

local env = setmetatable({}, { __index = function(_, k)
  if ASL[k] then return ASL[k] end
  if k == 'linear' or SHAPES[k] then return k end
  return _G[k]
end })
local function compile(action)
  if type(action) == 'table' then return action end
  if type(action) ~= 'string' then return nil end
  local f, e = load('return ' .. action, '=crow action', 't', env)
  if not f then f, e = load(action, '=crow action', 't', env) end
  if not f then report(e) return nil end
  local ok, r = pcall(f)
  if not ok then report(r) return nil end
  return r
end
local function as_list(node)
  if type(node) ~= 'table' then return {} end
  if node.k then return { node } end
  return node
end

-- outputs ---------------------------------------------------------------------------------
local outs, outp = {}, {}
local function new_out(n)
  return { n = n, v = 0, from = 0, target = 0, t0 = 0, dur = 0, fn = SHAPES.linear, slew = 0, shapeName = 'linear',
    stack = nil, gate = false, holding = false, prog = nil, action_src = nil, dyn = {}, sent = nil, sent_t = -1 }
end

local function start_segment(o, v, t, s)
  o.from = o.v; o.target = v; o.t0 = now; o.dur = math.max(0, t); o.fn = shape_fn(s)
  if o.dur <= 0 then o.v = v end
end

local function advance(o)
  local guard = 0
  while o.stack and guard < 256 do
    guard = guard + 1
    local fr = o.stack[#o.stack]
    if not fr then o.stack = nil; return end
    fr.i = fr.i + 1
    local node = fr.list[fr.i]
    if node == nil then
      if fr.kind == 'loop' then fr.i = 0
      elseif fr.kind == 'times' then
        fr.c = fr.c + 1
        if fr.c < fr.n then fr.i = 0 else table.remove(o.stack) end
      elseif fr.kind == 'held' then
        if o.gate then fr.i = #fr.list; o.holding = true; return end
        table.remove(o.stack)
      else
        table.remove(o.stack)
      end
      if #o.stack == 0 then o.stack = nil; safe(outp[o.n] and rawget(outp[o.n], '_done')); return end
    elseif type(node) == 'table' and node.k == 'to' then
      start_segment(o, resolve(node.v, o), resolve(node.t, o), node.s)
      if o.dur > 0 then return end
    elseif type(node) == 'table' and (node.k == 'loop' or node.k == 'times' or node.k == 'held' or node.k == 'seq') then
      o.stack[#o.stack + 1] = { kind = node.k, list = as_list(node.body), i = 0, c = 0, n = math.floor(resolve(node.n or 1, o)) }
    elseif type(node) == 'table' then
      o.stack[#o.stack + 1] = { kind = 'seq', list = node, i = 0 }
    end
  end
end

local function run(o, gate)
  if not o.prog then return end
  o.gate = (gate ~= false)
  o.holding = false
  o.dur = 0
  o.stack = { { kind = 'seq', list = as_list(o.prog), i = 0 } }
  advance(o)
end
local function release(o)
  o.gate = false
  if not o.stack then return end
  -- drop everything up to and including the innermost held frame
  for i = #o.stack, 1, -1 do
    if o.stack[i].kind == 'held' then
      for _ = #o.stack, i, -1 do table.remove(o.stack) end
      o.holding = false
      o.dur = 0
      if #o.stack == 0 then o.stack = nil else advance(o) end
      return
    end
  end
end
local function set_volts(o, v)
  o.stack = nil; o.holding = false
  start_segment(o, v, o.slew, o.shapeName)
end

local function make_output(n)
  local o = new_out(n)
  outs[n] = o
  local proxy
  proxy = setmetatable({}, {
    __index = function(_, k)
      if k == 'volts' then return o.v end
      if k == 'slew' then return o.slew end
      if k == 'shape' then return o.shapeName end
      if k == 'action' then return o.action_src end
      if k == 'dyn' then return o.dyn end
      if k == 'execute' then return function() run(o, true) end end
      if k == 'query' then return function() local r = rawget(proxy, 'receive'); if r then safe(r, o.v) end end end
      if k == 'scale' or k == 'clock' or k == 'reset' then
        return function() warn('output.' .. k) end
      end
      return nil
    end,
    __newindex = function(_, k, v)
      if k == 'volts' then set_volts(o, tonumber(v) or 0)
      elseif k == 'slew' then o.slew = tonumber(v) or 0
      elseif k == 'shape' then o.shapeName = v
      elseif k == 'action' then o.action_src = v; o.prog = compile(v)
      elseif k == 'done' then rawset(proxy, '_done', v)
      else rawset(proxy, k, v) end
    end,
    __call = function(_, arg)
      if type(arg) == 'table' then for k, v in pairs(arg) do proxy[k] = v end return end
      if arg == false then release(o) else run(o, arg) end
    end,
  })
  outp[n] = proxy
  return proxy
end

-- inputs ------------------------------------------------------------------------------------
local ins, inp = {}, {}
local function make_input(n)
  local s = { v = 0, mode = 'none', interval = 0.1, thr = 1, hyst = 0.1, dir = 'both', next = 0, state = false }
  ins[n] = s
  local proxy
  local function set_mode(m, a, b, c)
    m = tostring(m or 'none')
    s.mode = m
    if m == 'stream' then s.interval = math.max(0.005, tonumber(a) or 0.1); s.next = now
    elseif m == 'change' then
      s.thr = tonumber(a) or 1; s.hyst = tonumber(b) or 0.1; s.dir = tostring(c or 'both')
      s.state = s.v > s.thr
    elseif m ~= 'none' then
      warn('input mode ' .. m, __tr('crow: input mode \'' .. m .. '\' は stream として扱います', 'crow: input mode \'' .. m .. '\' is treated as stream'))
      s.mode = 'stream'; s.interval = 0.1
    end
  end
  proxy = setmetatable({}, {
    __index = function(_, k)
      if k == 'volts' then return s.v end
      if k == 'mode' then return set_mode end
      if k == 'query' then return function() local f = rawget(proxy, 'stream'); if f then safe(f, s.v) end end end
      return nil
    end,
    __newindex = function(_, k, v)
      if k == 'mode' and type(v) == 'string' then set_mode(v) else rawset(proxy, k, v) end
    end,
    __call = function(_, t)
      if type(t) == 'table' then
        if t.mode then set_mode(t.mode, t.time or t.threshold, t.hysteresis, t.direction) end
        if t.change then rawset(proxy, 'change', t.change) end
        if t.stream then rawset(proxy, 'stream', t.stream) end
      end
    end,
  })
  inp[n] = proxy
  return proxy
end

crow.output = {}
crow.input = {}
for i = 1, 4 do crow.output[i] = make_output(i) end
for i = 1, 2 do crow.input[i] = make_input(i) end

function crow._input(n, v)
  local s = ins[n]; if not s then return end
  s.v = v
  if s.mode == 'change' then
    local proxy = inp[n]
    if not s.state and v > s.thr + s.hyst / 2 then
      s.state = true
      if s.dir ~= 'falling' then safe(rawget(proxy, 'change'), true) end
    elseif s.state and v < s.thr - s.hyst / 2 then
      s.state = false
      if s.dir ~= 'rising' then safe(rawget(proxy, 'change'), false) end
    end
  end
end

function crow._tick(t, dt)
  now = t
  for i = 1, 4 do
    local o = outs[i]
    if o.dur > 0 then
      local x = (now - o.t0) / o.dur
      if x >= 1 then
        o.v = o.target; o.dur = 0
        if o.stack and not o.holding then advance(o) end
      else
        o.v = o.from + (o.target - o.from) * o.fn(x)
      end
    elseif o.stack and not o.holding then
      advance(o)
    end
    if o.sent == nil or (math.abs(o.v - o.sent) > 0.0005 and now - o.sent_t > 1 / 90) or (o.dur == 0 and o.v ~= o.sent) then
      o.sent = o.v; o.sent_t = now
      __crow_out(i, o.v)
    end
  end
  for i = 1, 2 do
    local s = ins[i]
    if s.mode == 'stream' and now >= s.next then
      s.next = now + s.interval
      safe(rawget(inp[i], 'stream'), s.v)
    end
  end
end

-- misc API ---------------------------------------------------------------------------------
function crow.connected() return true end
function crow.reset()
  for i = 1, 4 do local o = outs[i]; o.stack = nil; o.holding = false; o.dur = 0; o.v = 0; o.slew = 0; o.prog = nil; o.action_src = nil end
  for i = 1, 2 do ins[i].mode = 'none' end
end
crow.clear = crow.reset
crow.init = function() end
function crow.send(s) warn('send', __tr('crow.send(...) で送る crow 側スクリプトは実行されません', 'scripts sent with crow.send(...) do not run on the emulated crow')) end
function crow.loadscript(name) warn('loadscript', __tr('crow.loadscript(' .. tostring(name) .. ') の crow 側スクリプトは実行されません', 'crow.loadscript(' .. tostring(name) .. '): crow-side scripts do not run')) end
crow.version = function() return 'web' end
crow.ii = setmetatable({}, { __index = function(t, k)
  warn('ii', __tr('crow.ii (i2c 機器) はエミュレートされず、呼び出しは無視されます', 'crow.ii (i2c devices) is not emulated; calls are ignored'))
  local dev
  dev = setmetatable({}, { __index = function() return dev end, __call = function() end, __newindex = function() end })
  return dev
end })
crow.public = {}
crow.add = nil
crow.remove = nil
return crow
