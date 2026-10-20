-- container/deque
local D = {}; D.__index = D
function D.new(t) local d = setmetatable({ first = 1, last = 0, items = {} }, D); for _, v in ipairs(t or {}) do d:push_back(v) end return d end
function D:push(v) self.first = self.first - 1; self.items[self.first] = v end
function D:push_back(v) self.last = self.last + 1; self.items[self.last] = v end
function D:pop() if self.first > self.last then return nil end local v = self.items[self.first]; self.items[self.first] = nil; self.first = self.first + 1; return v end
function D:pop_back() if self.first > self.last then return nil end local v = self.items[self.last]; self.items[self.last] = nil; self.last = self.last - 1; return v end
function D:count() return self.last - self.first + 1 end
function D:clear() self.first = 1; self.last = 0; self.items = {} end
function D:peek() return self.items[self.first] end
function D:peek_back() return self.items[self.last] end
function D:ipairs() local i = self.first - 1; return function() i = i + 1; if i <= self.last then return i - self.first + 1, self.items[i] end end end
function D:to_array() local t = {} for i = self.first, self.last do t[#t + 1] = self.items[i] end return t end
function D:remove(v) local t = self:to_array(); self:clear(); local found = false for _, x in ipairs(t) do if x == v and not found then found = true else self:push_back(x) end end return found and v or nil end
function D:find(v) for i = self.first, self.last do if self.items[i] == v then return v end end end
function D:extend_back(o) for _, v in o:ipairs() do self:push_back(v) end end
D.__len = D.count
return D
