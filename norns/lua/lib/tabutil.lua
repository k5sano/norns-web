-- tabutil
local tab = {}
function tab.print(t) for k, v in pairs(t) do print(tostring(k) .. '\t' .. tostring(v)) end end
function tab.sort(t) local keys = {} for k in pairs(t) do keys[#keys + 1] = k end table.sort(keys, function(a, b) return tostring(a) < tostring(b) end) return keys end
function tab.count(t) local c = 0 for _ in pairs(t) do c = c + 1 end return c end
function tab.contains(t, e) for _, v in pairs(t) do if v == e then return true end end return false end
function tab.key(t, e) for k, v in pairs(t) do if v == e then return k end end return nil end
function tab.invert(t) local r = {} for k, v in pairs(t) do r[v] = k end return r end
function tab.lines(s) local t = {} for l in (tostring(s) .. '\n'):gmatch('(.-)\r?\n') do t[#t + 1] = l end return t end
function tab.split(s, sep) local t = {} for p in string.gmatch(s, '([^' .. sep .. ']+)') do t[#t + 1] = p end return t end
function tab.reverse(t) local r = {} for i = #t, 1, -1 do r[#r + 1] = t[i] end return r end
function tab.gather(a, b) local r = {} for k, v in pairs(a) do r[k] = v end for k, v in pairs(b or {}) do r[k] = v end return r end
function tab.update(a, b) for k, v in pairs(b or {}) do a[k] = v end return a end
function tab.select_values(t, cond) local r = {} for k, v in pairs(t) do if cond(v, k) then r[#r + 1] = v end end return r end
function tab.readonly(p) return setmetatable({}, { __index = p.table, __newindex = function() error('readonly', 2) end }) end
function tab.truncate(t, n) for i = #t, n + 1, -1 do t[i] = nil end end
local function ser(v, ind, seen)
  seen = seen or {}
  local t = type(v)
  if t == 'number' or t == 'boolean' or t == 'nil' then return tostring(v) end
  if t == 'string' then return string.format('%q', v) end
  if t == 'table' then
    if seen[v] then return 'nil' end
    seen[v] = true
    local parts = {}
    for k, val in pairs(v) do
      local key = type(k) == 'string' and ('[' .. string.format('%q', k) .. ']') or ('[' .. tostring(k) .. ']')
      parts[#parts + 1] = ind .. '  ' .. key .. ' = ' .. ser(val, ind .. '  ', seen)
    end
    return '{\n' .. table.concat(parts, ',\n') .. '\n' .. ind .. '}'
  end
  return 'nil'
end
function tab.save(t, path)
  local f = io.open(path, 'w'); if not f then return nil end
  f:write('return ' .. ser(t, '')); f:close(); return true
end
function tab.load(path)
  local s = __fs_read(path); if not s then return nil end
  local f = load(s, '@' .. path)
  if not f then return nil end
  local ok, r = pcall(f)
  if ok then return r end
  return nil
end
return tab
