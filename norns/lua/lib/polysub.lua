-- polysub engine params helper
local polysub = {}
function polysub.params()
  local function add(id, name, cs) params:add_control(id, name, cs); params:set_action(id, function(v) engine[id](v) end) end
  local C = controlspec.new
  add('shape', 'shape', C(0, 1, 'lin', 0, 0, ''))
  add('timbre', 'timbre', C(0, 1, 'lin', 0, 0.5, ''))
  add('noise', 'noise', C(0, 1, 'lin', 0, 0, ''))
  add('cut', 'cut', C(0, 32, 'lin', 0, 8, ''))
  add('fgain', 'fgain', C(0, 6, 'lin', 0, 0, ''))
  add('ampAtk', 'amp atk', C(0.01, 10, 'exp', 0, 0.05, 's'))
  add('ampDec', 'amp dec', C(0, 2, 'lin', 0, 0.1, 's'))
  add('ampSus', 'amp sus', C(0, 1, 'lin', 0, 1, ''))
  add('ampRel', 'amp rel', C(0.01, 10, 'exp', 0, 1, 's'))
  add('level', 'level', C(0, 1, 'lin', 0, 0.2, ''))
end
return polysub
