-- util
local util = {}
function util.clamp(n, lo, hi) return math.min(math.max(n, lo), hi) end
function util.linlin(slo, shi, dlo, dhi, f)
  if f <= slo then return dlo elseif f >= shi then return dhi end
  return (f - slo) / (shi - slo) * (dhi - dlo) + dlo
end
function util.linexp(slo, shi, dlo, dhi, f)
  if f <= slo then return dlo elseif f >= shi then return dhi end
  return dlo * (dhi / dlo) ^ ((f - slo) / (shi - slo))
end
function util.explin(slo, shi, dlo, dhi, f)
  if f <= slo then return dlo elseif f >= shi then return dhi end
  return math.log(f / slo) / math.log(shi / slo) * (dhi - dlo) + dlo
end
function util.expexp(slo, shi, dlo, dhi, f)
  if f <= slo then return dlo elseif f >= shi then return dhi end
  return dlo * (dhi / dlo) ^ (math.log(f / slo) / math.log(shi / slo))
end
function util.round(n, q) q = q or 1; return math.floor(n / q + 0.5) * q end
function util.round_up(n, q) q = q or 1; return math.ceil(n / q) * q end
function util.wrap(n, lo, hi)
  if hi < lo then lo, hi = hi, lo end
  local r = hi - lo + 1
  return ((n - lo) % r) + lo
end
function util.wrap_max(n, lo, hi) local r = hi - lo; return ((n - lo) % r) + lo end
function util.time() return os.time() end
function util.s_to_hms(s)
  s = math.floor(s or 0)
  local h, m = s // 3600, (s // 60) % 60
  return string.format('%d:%02d:%02d', h, m, s % 60)
end
function util.trim_string_to_width(s, w) s = tostring(s); while #s > 0 and screen.text_extents(s) > w do s = s:sub(1, -2) end return s end
function util.file_exists(p) return __fs_exists(tostring(p)) end
function util.make_dir() return true end
function util.os_capture() return '' end
function util.scandir(dir)
  local t = {}
  for _, n in ipairs(__fs_list(tostring(dir))) do t[#t + 1] = n end
  return t
end
function util.string_starts(s, p) return string.sub(s, 1, #p) == p end
function util.string_ends(s, p) return p == '' or string.sub(s, -#p) == p end
function util.acronym(s) local t = '' for w in tostring(s):gmatch('%w+') do t = t .. w:sub(1, 1) end return t end
function util.dbamp(db) if db <= -math.huge then return 0 end return 10 ^ (db / 20) end
function util.ampdb(a) if a <= 0 then return -math.huge end return 20 * math.log(a, 10) end
function util.degs_to_rads(d) return d * math.pi / 180 end
function util.rads_to_degs(r) return r * 180 / math.pi end
function util.split(s, sep)
  local out = {}
  for part in (tostring(s) .. sep):gmatch('(.-)' .. sep:gsub('%p', '%%%0')) do out[#out + 1] = part end
  return out
end
function util.lerp(a, b, t) return a + (b - a) * t end
function util.formatted_num(n) return tostring(n) end
return util
