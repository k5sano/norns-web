-- pure Lua replacement for lua-cjson
local json = {}
json.null = setmetatable({}, { __tostring = function() return 'null' end })
local escapes = { ['"'] = '\\"', ['\\'] = '\\\\', ['\b'] = '\\b', ['\f'] = '\\f', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }
local function is_array(t)
  local n = 0
  for k in pairs(t) do
    if type(k) ~= 'number' or k <= 0 or math.floor(k) ~= k then return false end
    if k > n then n = k end
  end
  for i = 1, n do if t[i] == nil then return false end end
  return true, n
end
local function enc(v, seen)
  local t = type(v)
  if v == nil or v == json.null then return 'null' end
  if t == 'boolean' then return tostring(v) end
  if t == 'number' then
    if v ~= v or v == math.huge or v == -math.huge then return 'null' end
    if math.type and math.type(v) == 'integer' then return tostring(v) end
    if v == math.floor(v) and math.abs(v) < 1e15 then return string.format('%d', v) end
    return string.format('%.14g', v)
  end
  if t == 'string' then return '"' .. v:gsub('[%c"\\]', function(c) return escapes[c] or string.format('\\u%04x', c:byte()) end) .. '"' end
  if t == 'table' then
    if seen[v] then error('cjson: circular reference') end
    seen[v] = true
    local arr, n = is_array(v)
    local out = {}
    if arr and (n > 0 or next(v) == nil) then
      for i = 1, n do out[i] = enc(v[i], seen) end
      seen[v] = nil
      return '[' .. table.concat(out, ',') .. ']'
    end
    for k, val in pairs(v) do
      if type(val) ~= 'function' then out[#out + 1] = enc(tostring(k), seen) .. ':' .. enc(val, seen) end
    end
    seen[v] = nil
    return '{' .. table.concat(out, ',') .. '}'
  end
  return 'null'
end
function json.encode(v) return enc(v, {}) end
local function dec(s)
  local i = 1
  local function ws() i = s:find('[^ \t\r\n]', i) or #s + 1 end
  local function err(m) error('cjson: ' .. m .. ' at ' .. i, 0) end
  local val
  local function str()
    i = i + 1
    local out = {}
    while true do
      local c = s:sub(i, i)
      if c == '' then err('unterminated string') end
      if c == '"' then i = i + 1; break end
      if c == '\\' then
        local e = s:sub(i + 1, i + 1)
        local map = { b = '\b', f = '\f', n = '\n', r = '\r', t = '\t', ['"'] = '"', ['\\'] = '\\', ['/'] = '/' }
        if e == 'u' then
          local cp = tonumber(s:sub(i + 2, i + 5), 16) or 63
          i = i + 6
          if cp >= 0xD800 and cp <= 0xDBFF and s:sub(i, i + 1) == '\\u' then
            local lo = tonumber(s:sub(i + 2, i + 5), 16) or 0
            cp = 0x10000 + (cp - 0xD800) * 0x400 + (lo - 0xDC00); i = i + 6
          end
          out[#out + 1] = utf8.char(cp)
        else out[#out + 1] = map[e] or e; i = i + 2 end
      else
        local j = s:find('["\\]', i) or #s + 1
        out[#out + 1] = s:sub(i, j - 1); i = j
      end
    end
    return table.concat(out)
  end
  function val()
    ws()
    local c = s:sub(i, i)
    if c == '{' then
      i = i + 1; local t = {}; ws()
      if s:sub(i, i) == '}' then i = i + 1; return t end
      while true do
        ws(); if s:sub(i, i) ~= '"' then err('expected key') end
        local k = str(); ws()
        if s:sub(i, i) ~= ':' then err('expected :') end
        i = i + 1
        local v = val()
        t[k] = v
        ws(); local d = s:sub(i, i); i = i + 1
        if d == '}' then return t end
        if d ~= ',' then err('expected , or }') end
      end
    elseif c == '[' then
      i = i + 1; local t = {}; ws()
      if s:sub(i, i) == ']' then i = i + 1; return t end
      local n = 0
      while true do
        n = n + 1; t[n] = val(); ws()
        local d = s:sub(i, i); i = i + 1
        if d == ']' then return t end
        if d ~= ',' then err('expected , or ]') end
      end
    elseif c == '"' then return str()
    elseif s:sub(i, i + 3) == 'true' then i = i + 4; return true
    elseif s:sub(i, i + 4) == 'false' then i = i + 5; return false
    elseif s:sub(i, i + 3) == 'null' then i = i + 4; return json.null
    else
      local a, b = s:find('^-?%d+%.?%d*[eE]?[-+]?%d*', i)
      if not a then err('unexpected character') end
      i = b + 1
      return tonumber(s:sub(a, b))
    end
  end
  local r = val()
  return r
end
function json.decode(s)
  if type(s) ~= 'string' then error('cjson.decode expects a string', 2) end
  return dec(s)
end
function json.encode_sparse_array() end
function json.encode_empty_table_as_object() end
function json.decode_array_with_array_mt() end
function json.encode_number_precision() end
function json.encode_escape_forward_slash() end
function json.new() return json end
return json
