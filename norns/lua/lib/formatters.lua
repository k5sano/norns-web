-- formatters
local F = {}
local function num(p) if type(p) == 'table' and p.get then return p:get() end return p end
function F.default(p) return tostring(num(p)) end
function F.round(n) return function(p) return util.round(num(p), n or 1) end end
function F.round_with_label(n, label) return function(p) return util.round(num(p), n or 1) .. ' ' .. (label or '') end end
function F.format_freq_raw(v)
  if v >= 10000 then return string.format('%.0f kHz', v / 1000) elseif v >= 1000 then return string.format('%.1f kHz', v / 1000) end
  return string.format('%.0f Hz', v)
end
function F.format_freq(p) return F.format_freq_raw(num(p)) end
function F.percentage(p) return string.format('%.0f%%', num(p)) end
function F.unipolar_as_percentage(p) return string.format('%.0f%%', num(p) * 100) end
function F.bipolar_as_percentage(p) return string.format('%.0f%%', num(p) * 100) end
function F.unipolar_as_true_false(p) return num(p) > 0 and 'true' or 'false' end
function F.true_false(p) return num(p) == 1 and 'true' or 'false' end
function F.on_off(p) return num(p) == 1 and 'on' or 'off' end
function F.secs_as_ms(p) return string.format('%.0f ms', num(p) * 1000) end
function F.format_secs_raw(v) if v >= 1 then return string.format('%.2f s', v) end return string.format('%.0f ms', v * 1000) end
function F.format_secs(p) return F.format_secs_raw(num(p)) end
function F.bipolar_as_pan_widget(p)
  local v = num(p)
  local w = 9
  local pos = math.floor((v + 1) / 2 * (w - 1) + 0.5) + 1
  local s = ''
  for i = 1, w do s = s .. (i == pos and '|' or (i == (w + 1) // 2 and '.' or '-')) end
  return 'L ' .. s .. ' R'
end
function F.bipolar_as_multimode_filter_widget(p) return string.format('%.2f', num(p)) end
return setmetatable(F, { __index = function() return F.default end })
