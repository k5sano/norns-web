local b = {}
local M = 0xFFFFFFFF
function b.band(...) local r = M for i = 1, select('#', ...) do r = r & (select(i, ...) & M) end return r end
function b.bor(...) local r = 0 for i = 1, select('#', ...) do r = r | (select(i, ...) & M) end return r end
function b.bxor(...) local r = 0 for i = 1, select('#', ...) do r = r ~ (select(i, ...) & M) end return r end
function b.bnot(x) return (~x) & M end
function b.lshift(x, n) return (x << n) & M end
function b.rshift(x, n) return (x & M) >> n end
function b.arshift(x, n) x = x & M; if x & 0x80000000 ~= 0 then return ((x >> n) | ~(M >> n)) & M end return x >> n end
function b.btest(...) return b.band(...) ~= 0 end
function b.extract(x, f, w) w = w or 1; return (x >> f) & ((1 << w) - 1) end
function b.replace(x, v, f, w) w = w or 1; local m = ((1 << w) - 1) << f; return (x & ~m | ((v << f) & m)) & M end
function b.lrotate(x, n) n = n % 32; x = x & M; return ((x << n) | (x >> (32 - n))) & M end
function b.rrotate(x, n) return b.lrotate(x, -n) end
return b
