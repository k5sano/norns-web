-- er: euclidean rhythms (Bjorklund)
local er = {}
function er.gen(k, n, w)
  w = w or 0
  local s = {}
  if n <= 0 then return s end
  k = math.max(0, math.min(k, n))
  if k == 0 then for i = 1, n do s[i] = false end return s end
  local groups = {}
  for i = 1, n do groups[i] = { i <= k } end
  local function bj(a, b)
    -- a: front groups, b: remainder groups
    while #b > 1 do
      local na, nb = {}, {}
      local m = math.min(#a, #b)
      for i = 1, m do local g = {} for _, x in ipairs(a[i]) do g[#g + 1] = x end for _, x in ipairs(b[i]) do g[#g + 1] = x end na[#na + 1] = g end
      if #a > m then for i = m + 1, #a do nb[#nb + 1] = a[i] end else for i = m + 1, #b do nb[#nb + 1] = b[i] end end
      a, b = na, nb
    end
    local out = {}
    for _, g in ipairs(a) do for _, x in ipairs(g) do out[#out + 1] = x end end
    for _, g in ipairs(b) do for _, x in ipairs(g) do out[#out + 1] = x end end
    return out
  end
  local a, b = {}, {}
  for i = 1, n do if i <= k then a[#a + 1] = { true } else b[#b + 1] = { false } end end
  s = bj(a, b)
  if w ~= 0 then
    local r = {}
    for i = 1, n do r[i] = s[((i - 1 - w) % n) + 1] end
    s = r
  end
  return s
end
return er
