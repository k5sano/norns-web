-- filters (smoothing helpers)
local F = {}
local Mean = {}; Mean.__index = Mean
function F.mean(n) return setmetatable({ n = n or 8, buf = {}, i = 0 }, Mean) end
function Mean:next(x) self.i = self.i % self.n + 1; self.buf[self.i] = x; local s, c = 0, 0 for _, v in pairs(self.buf) do s = s + v; c = c + 1 end return s / c end
local mean_ctor = F.mean
F.mean = setmetatable({ new = function(n) return mean_ctor(n) end }, { __call = function(_, n) return mean_ctor(n) end })
F.Mean = F.mean
return F
