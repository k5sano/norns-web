-- core/params/option: standalone option param object
local Option = {}
Option.__index = Option
function Option.new(id, name, options, default)
  local ps = paramset.new('tmp', 'tmp')
  return ps:add{ type = 'option', id = id, name = name, options = options, default = default }
end
return Option
