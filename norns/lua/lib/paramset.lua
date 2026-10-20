-- paramset for the norns web emulator
local ParamSet = {}
ParamSet.__index = ParamSet

ParamSet.tSEPARATOR = 0
ParamSet.tNUMBER = 1
ParamSet.tOPTION = 2
ParamSet.tCONTROL = 3
ParamSet.tFILE = 4
ParamSet.tTAPER = 5
ParamSet.tTRIGGER = 6
ParamSet.tGROUP = 7
ParamSet.tTEXT = 8
ParamSet.tBINARY = 9

local TYPES = { separator = 0, number = 1, option = 2, control = 3, file = 4, taper = 5, trigger = 6, group = 7, text = 8, binary = 9 }

local function report(e) __report(tostring(e)) end
local function safe(f, ...) if type(f) ~= 'function' then return end local ok, e = pcall(f, ...) if not ok then report(e) end end

local Param = {}
Param.__index = Param

local function clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end

-- control mapping helpers
local function cs_map(cs, raw)
  raw = clamp(raw, 0, 1)
  local lo, hi = cs.minval, cs.maxval
  local v
  if cs.warp == 'exp' and lo > 0 and hi > 0 then
    v = lo * (hi / lo) ^ raw
  elseif cs.warp == 'db' then
    v = lo + (hi - lo) * raw ^ 2
  else
    v = lo + (hi - lo) * raw
  end
  if cs.step and cs.step > 0 then v = math.floor(v / cs.step + 0.5) * cs.step end
  return v
end
local function cs_unmap(cs, v)
  local lo, hi = cs.minval, cs.maxval
  if hi == lo then return 0 end
  if cs.warp == 'exp' and lo > 0 and hi > 0 and v > 0 then
    return clamp(math.log(v / lo) / math.log(hi / lo), 0, 1)
  elseif cs.warp == 'db' then
    return clamp(math.sqrt(math.max(0, (v - lo) / (hi - lo))), 0, 1)
  end
  return clamp((v - lo) / (hi - lo), 0, 1)
end

function Param:get()
  if self.t == TYPES.control or self.t == TYPES.taper then return self.value end
  return self.value
end

function Param:set(v, silent)
  local t = self.t
  if t == TYPES.number then
    v = tonumber(v) or self.min
    v = math.floor(v + 0.5)
    if self.wrap then
      local r = self.max - self.min + 1
      v = ((v - self.min) % r) + self.min
    else
      v = clamp(v, self.min, self.max)
    end
  elseif t == TYPES.option then
    v = math.floor(tonumber(v) or 1)
    v = clamp(v, 1, math.max(1, #self.options))
  elseif t == TYPES.control then
    v = tonumber(v) or self.controlspec.minval
    local cs = self.controlspec
    local lo, hi = math.min(cs.minval, cs.maxval), math.max(cs.minval, cs.maxval)
    v = clamp(v, lo, hi)
    if cs.step and cs.step > 0 then v = math.floor(v / cs.step + 0.5) * cs.step end
    self.raw = cs_unmap(cs, v)
  elseif t == TYPES.taper then
    v = clamp(tonumber(v) or self.min, self.min, self.max)
  elseif t == TYPES.binary then
    v = (v == true or (tonumber(v) or 0) > 0) and 1 or 0
  elseif t == TYPES.text or t == TYPES.file then
    v = tostring(v)
  end
  if self.value == v and t ~= TYPES.binary then
    self.value = v
    if not silent and t == TYPES.file then safe(self.action, v) end
    return
  end
  self.value = v
  if not silent then safe(self.action, v) end
end

function Param:delta(d)
  local t = self.t
  if t == TYPES.number or t == TYPES.option then
    self:set(self.value + d)
  elseif t == TYPES.control then
    local q = self.controlspec.quantum or 0.01
    local raw = clamp((self.raw or cs_unmap(self.controlspec, self.value)) + d * q, 0, 1)
    if self.controlspec.wrap then raw = raw % 1 end
    local v = cs_map(self.controlspec, raw)
    self.raw = raw
    if v ~= self.value then self.value = v; safe(self.action, v) end
  elseif t == TYPES.taper then
    local raw = clamp(self:get_raw() + d * 0.01, 0, 1)
    self:set_raw(raw)
  elseif t == TYPES.binary then
    if d ~= 0 then self:set(d > 0 and 1 or 0) end
  elseif t == TYPES.trigger then
    if d > 0 then self:bang() end
  end
end

function Param:get_raw()
  local t = self.t
  if t == TYPES.control then return self.raw or cs_unmap(self.controlspec, self.value) end
  if t == TYPES.taper then
    local k = self.k or 0
    local x = (self.value - self.min) / (self.max - self.min)
    if k == 0 then return x end
    return math.log(1 + x * (math.exp(k) - 1)) / k
  end
  if self.max and self.min and self.max ~= self.min then return (self.value - self.min) / (self.max - self.min) end
  return 0
end

function Param:set_raw(r, silent)
  r = clamp(r, 0, 1)
  local t = self.t
  if t == TYPES.control then self:set(cs_map(self.controlspec, r), silent)
  elseif t == TYPES.taper then
    local k = self.k or 0
    local x = (k == 0) and r or ((math.exp(k * r) - 1) / (math.exp(k) - 1))
    self:set(self.min + (self.max - self.min) * x, silent)
  elseif self.max and self.min then self:set(self.min + (self.max - self.min) * r, silent) end
end

function Param:string()
  if self.formatter then
    local ok, s = pcall(self.formatter, self)
    if ok and s ~= nil then return tostring(s) end
  end
  local t = self.t
  if t == TYPES.option then return tostring(self.options[self.value]) end
  if t == TYPES.control then
    local u = self.controlspec.units or ''
    local v = self.value
    local s
    if math.abs(v) >= 100 then s = string.format('%.0f', v) elseif math.abs(v) >= 10 then s = string.format('%.1f', v) else s = string.format('%.2f', v) end
    return u ~= '' and (s .. ' ' .. u) or s
  end
  if t == TYPES.taper then return string.format('%.2f', self.value) .. ((self.units and self.units ~= '') and (' ' .. self.units) or '') end
  if t == TYPES.binary then return self.value == 1 and 'on' or 'off' end
  if t == TYPES.trigger then return '' end
  if t == TYPES.file then return tostring(self.value):match('[^/]*$') end
  return tostring(self.value)
end
function Param:bang()
  if self.t == TYPES.trigger then safe(self.action, 1)
  elseif self.t ~= TYPES.separator and self.t ~= TYPES.group then safe(self.action, self.value) end
end
function Param:get_range() return self.min, self.max end
function Param:set_default() if self.default ~= nil then self:set(self.default) end end
function Param:get_delta() return 1 end

-- ParamSet -------------------------------------------------------------------
function ParamSet.new(id, name)
  local ps = setmetatable({}, ParamSet)
  ps.id = id or 'params'; ps.name = name or ''
  ps.params = {}; ps.lookup = {}; ps.count = 0; ps.hidden = {}
  ps.group = 0
  ps.action_write = nil; ps.action_read = nil; ps.action_delete = nil
  return ps
end

function ParamSet:_find(id)
  if type(id) == 'number' then return self.params[id] end
  local i = self.lookup[id]
  return i and self.params[i] or nil
end
local function need(self, id)
  local p = self:_find(id)
  if not p then error('invalid paramset index: ' .. tostring(id), 3) end
  return p
end

function ParamSet:add(args)
  args = args or {}
  local tn = args.type or 'number'
  local t = TYPES[tn]
  if not t then t = TYPES.number end
  local p = setmetatable({ id = args.id, name = args.name or args.id or '', t = t, action = args.action or function() end,
    formatter = args.formatter, allow_pmap = args.allow_pmap ~= false }, Param)
  if t == TYPES.number then
    p.min = args.min or 0; p.max = args.max or 127; p.wrap = args.wrap
    p.default = args.default or p.min; p.value = math.floor(p.default + 0.5)
  elseif t == TYPES.option then
    p.options = args.options or {}; p.min = 1; p.max = #p.options
    p.default = args.default or 1; p.value = p.default
  elseif t == TYPES.control then
    local cs = args.controlspec or controlspec.new(args.min or 0, args.max or 1, args.warp or 'lin', args.step or 0, args.default or args.min or 0, args.units or '')
    p.controlspec = cs; p.min = cs.minval; p.max = cs.maxval
    p.default = cs.default or cs.minval; p.value = p.default; p.raw = cs_unmap(cs, p.value)
  elseif t == TYPES.taper then
    p.min = args.min or 0; p.max = args.max or 1; p.k = args.k or 0; p.units = args.units or ''
    p.default = args.default or p.min; p.value = p.default
  elseif t == TYPES.binary then
    p.behavior = args.behavior or 'toggle'; p.min = 0; p.max = 1
    p.default = args.default or 0; p.value = p.default
  elseif t == TYPES.trigger then
    p.value = 0
  elseif t == TYPES.text then
    p.default = args.text or args.default or ''; p.value = p.default
  elseif t == TYPES.file then
    p.default = args.path or args.default or ''; p.value = p.default
  elseif t == TYPES.group then
    p.n = args.n or 0
  end
  self.count = self.count + 1
  self.params[self.count] = p
  if p.id then self.lookup[p.id] = self.count end
  return p
end
function ParamSet:add_number(id, name, min, max, default, formatter, wrap) return self:add{ type = 'number', id = id, name = name, min = min, max = max, default = default, formatter = formatter, wrap = wrap } end
function ParamSet:add_option(id, name, options, default) return self:add{ type = 'option', id = id, name = name, options = options, default = default } end
function ParamSet:add_control(id, name, cs, formatter) return self:add{ type = 'control', id = id, name = name, controlspec = cs, formatter = formatter } end
function ParamSet:add_taper(id, name, min, max, default, k, units) return self:add{ type = 'taper', id = id, name = name, min = min, max = max, default = default, k = k, units = units } end
function ParamSet:add_binary(id, name, behavior, default) return self:add{ type = 'binary', id = id, name = name, behavior = behavior, default = default } end
function ParamSet:add_trigger(id, name) return self:add{ type = 'trigger', id = id, name = name } end
function ParamSet:add_text(id, name, text) return self:add{ type = 'text', id = id, name = name, text = text } end
function ParamSet:add_file(id, name, path) return self:add{ type = 'file', id = id, name = name, path = path } end
function ParamSet:add_separator(id, name)
  if name == nil then name = id; id = nil end
  return self:add{ type = 'separator', id = id, name = name or '' }
end
function ParamSet:add_group(id, name, n)
  if n == nil then n = name; name = id; id = nil end
  return self:add{ type = 'group', id = id, name = name or '', n = n or 0 }
end

function ParamSet:get(id) return need(self, id):get() end
function ParamSet:set(id, v, silent) local p = self:_find(id); if not p then error('invalid paramset index: ' .. tostring(id), 2) end p:set(v, silent) end
function ParamSet:delta(id, d) need(self, id):delta(d or 1) end
function ParamSet:set_action(id, f) need(self, id).action = f end
function ParamSet:get_action(id) return need(self, id).action end
function ParamSet:string(id) return need(self, id):string() end
function ParamSet:get_raw(id) return need(self, id):get_raw() end
function ParamSet:set_raw(id, v, silent) need(self, id):set_raw(v, silent) end
function ParamSet:get_range(id) return need(self, id):get_range() end
function ParamSet:get_name(id) return need(self, id).name end
function ParamSet:get_id(i) local p = self.params[i]; return p and p.id end
function ParamSet:t(id) return need(self, id).t end
function ParamSet:get_allow_pmap(id) return true end
function ParamSet:lookup_param(id) return need(self, id) end
function ParamSet:hide(id) local p = self:_find(id); if p then self.hidden[p] = true end end
function ParamSet:show(id) local p = self:_find(id); if p then self.hidden[p] = nil end end
function ParamSet:visible(id) local p = self:_find(id); return p and not self.hidden[p] end
function ParamSet:bang(id)
  if id then local p = self:_find(id); if p then p:bang() end return end
  for _, p in ipairs(self.params) do if p.t ~= TYPES.trigger then p:bang() end end
end
function ParamSet:clear()
  local keep = {}
  for i = 1, (self._system_count or 0) do keep[i] = self.params[i] end
  self.params = keep; self.count = #keep; self.lookup = {}
  for i, p in ipairs(keep) do if p.id then self.lookup[p.id] = i end end
end
function ParamSet:list() for _, p in ipairs(self.params) do if p.id then print(p.id) end end end

local function pset_path(filename)
  local name = norns.state.shortname
  local dir = _path.data .. (norns.state.name:match('^[^/]+') or name) .. '/'
  if type(filename) == 'number' or filename == nil then
    return dir .. name .. '-' .. string.format('%02d', filename or 1) .. '.pset', filename
  end
  return filename, nil
end
function ParamSet:write(filename, name)
  local path, n = pset_path(filename)
  local f = io.open(path, 'w')
  if not f then return end
  f:write('-- ' .. (name or '') .. '\n')
  for _, p in ipairs(self.params) do
    if p.id and p.t ~= TYPES.trigger and p.t ~= TYPES.separator and p.t ~= TYPES.group then
      local v = p.value
      if type(v) == 'string' then v = string.format('%q', v) end
      f:write(string.format('%q', p.id) .. ': ' .. tostring(v) .. '\n')
    end
  end
  f:close()
  if self.action_write then safe(self.action_write, path, name, n) end
end
function ParamSet:read(filename, silent)
  local path, n = pset_path(filename)
  local f = io.open(path, 'r')
  if not f then return end
  for line in f:lines() do
    local id, v = line:match('^%s*"?([^":]+)"?%s*:%s*(.-)%s*$')
    if id and v then
      local p = self:_find(id)
      if p then
        if v:match('^".*"$') then v = v:sub(2, -2) else v = tonumber(v) or v end
        p:set(v, silent)
      end
    end
  end
  f:close()
  if self.action_read then safe(self.action_read, path, silent, n) end
end
function ParamSet:delete(filename)
  local path, n = pset_path(filename)
  os.remove(path)
  if self.action_delete then safe(self.action_delete, path, nil, n) end
end
function ParamSet:default()
  local path = pset_path(1)
  if __fs_exists(path) then self:read(1, true) end
  self:bang()
end
function ParamSet:init() end

-- menu helpers: flattened visible list
function ParamSet:menu_list()
  local out = {}
  local i = 1
  while i <= self.count do
    local p = self.params[i]
    if p.t == TYPES.group then
      local hidden = self.hidden[p]
      if not hidden then out[#out + 1] = p end
      for j = 1, p.n do
        local c = self.params[i + j]
        if c and not hidden and not self.hidden[c] then c._in_group = true; out[#out + 1] = c end
      end
      i = i + p.n + 1
    else
      if not self.hidden[p] then out[#out + 1] = p end
      i = i + 1
    end
  end
  return out
end

return ParamSet
