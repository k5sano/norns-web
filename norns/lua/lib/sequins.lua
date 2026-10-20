-- sequins (compatible subset)
local S = {}
local SKIP, DEAD = {}, {}
local Seq = {}

local function is_seq(v) return type(v) == 'table' and getmetatable(v) == Seq end

local function new(t)
  local s = { _ = { data = {}, length = 0, ix = nil, n = 1, flw = nil, hold = false, fn = nil, qix = nil } }
  setmetatable(s, Seq)
  s:settable(t or {})
  return s
end

Seq.__index = function(self, k)
  if type(k) == 'number' then return rawget(self, '_').data[k] end
  local raw = rawget(self, '_')
  if k == 'ix' then return raw.ix or 1 end
  if k == 'length' then return raw.length end
  if k == 'data' then return raw.data end
  if k == 'n' then return raw.n end
  return Seq[k]
end
Seq.__newindex = function(self, k, v)
  local raw = rawget(self, '_')
  if type(k) == 'number' then raw.data[k] = v; raw.length = #raw.data
  elseif k == 'ix' then raw.ix = v
  else rawset(self, k, v) end
end
Seq.__len = function(self) return rawget(self, '_').length end
Seq.__call = function(self, ...)
  local v = self:_next(0)
  if v == SKIP or v == DEAD then return nil end
  return v
end

function Seq:settable(t)
  local raw = rawget(self, '_')
  if type(t) == 'string' then
    local d = {}
    for c in t:gmatch('.') do d[#d + 1] = c end
    t = d
  elseif is_seq(t) then
    t = rawget(t, '_').data
  end
  local d = {}
  for i, v in ipairs(t) do d[i] = v end
  raw.data = d; raw.length = #d
  if raw.ix and raw.ix > raw.length then raw.ix = nil end
  return self
end
function Seq:step(n) rawget(self, '_').n = n or 1; return self end
function Seq:select(i) rawget(self, '_').qix = i; return self end
function Seq:peek() local r = rawget(self, '_'); return r.data[r.ix or 1] end
function Seq:copy() local c = new(rawget(self, '_').data); return c end
function Seq:map(fn) rawget(self, '_').fn = fn; return self end
function Seq:reset()
  local r = rawget(self, '_')
  r.ix = nil; r.hold = false
  if r.flw then r.flw.c = 0 end
  for _, v in ipairs(r.data) do if is_seq(v) then v:reset() end end
  return self
end
local function flow(self, kind, n) rawget(self, '_').flw = { kind = kind, n = n, c = 0 }; return self end
function Seq:every(n) return flow(self, 'every', n or 1) end
function Seq:times(n) return flow(self, 'times', n or 1) end
function Seq:count(n) return flow(self, 'count', n or 1) end
function Seq:all() return flow(self, 'all', 0) end
function Seq:cond(fn) local r = flow(self, 'cond', 0); rawget(self, '_').flw.fn = fn; return r end
function Seq:condr(fn) local r = flow(self, 'condr', 0); rawget(self, '_').flw.fn = fn; return r end
function Seq:once() return self:times(1) end

function Seq:_advance()
  local r = rawget(self, '_')
  if r.length == 0 then return nil end
  if r.qix then r.ix = ((r.qix - 1) % r.length) + 1; r.qix = nil
  elseif r.ix == nil then r.ix = 1
  else r.ix = ((r.ix - 1 + r.n) % r.length) + 1 end
  return r.ix
end

function Seq:_value(depth)
  local r = rawget(self, '_')
  if depth > 32 then return SKIP end
  if r.hold then
    local child = r.data[r.ix]
    local cr = rawget(child, '_')
    local v = child:_next(depth + 1)
    if cr.flw and cr.flw.kind == 'count' then
      cr.flw.c = cr.flw.c + 1
      if cr.flw.c >= cr.flw.n then cr.flw.c = 0; r.hold = false end
    elseif cr.flw and cr.flw.kind == 'all' then
      if cr.ix == cr.length then r.hold = false; cr.ix = nil end
    else r.hold = false end
    if v == SKIP or v == DEAD then return self:_value(depth + 1) end
    return v
  end
  local i = self:_advance()
  if not i then return nil end
  local v = r.data[i]
  if is_seq(v) then
    local cf = rawget(v, '_').flw
    if cf and (cf.kind == 'count' or cf.kind == 'all') then r.hold = true; return self:_value(depth + 1) end
    local x = v:_next(depth + 1)
    if x == SKIP or x == DEAD then
      local allskip = true
      for _, e in ipairs(r.data) do if not is_seq(e) then allskip = false end end
      if allskip and depth > 4 then return SKIP end
      return self:_value(depth + 1)
    end
    return x
  end
  if type(v) == 'function' then v = v() end
  return v
end

function Seq:_next(depth)
  local r = rawget(self, '_')
  local f = r.flw
  if f then
    if f.kind == 'every' then
      f.c = f.c + 1
      if (f.c - 1) % f.n ~= 0 then return SKIP end
    elseif f.kind == 'times' then
      if f.c >= f.n then return DEAD end
      f.c = f.c + 1
    elseif f.kind == 'cond' then
      if not f.fn() then return SKIP end
    elseif f.kind == 'condr' then
      if not f.fn() then return DEAD end
    end
  end
  local v = self:_value(depth or 0)
  if v ~= SKIP and v ~= DEAD and r.fn then v = r.fn(v) end
  return v
end

S.new = new
S.is_sequins = is_seq
S.wrap = function(t) return new(t) end
setmetatable(S, { __call = function(_, t) return new(t) end })
return S
