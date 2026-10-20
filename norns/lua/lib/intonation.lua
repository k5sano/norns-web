local I = {}
function I.ji() return { 1, 16/15, 9/8, 6/5, 5/4, 4/3, 45/32, 3/2, 8/5, 5/3, 16/9, 15/8 } end
function I.ptolemy() return { 1, 9/8, 5/4, 4/3, 3/2, 5/3, 15/8 } end
function I.pythagorean() return { 1, 256/243, 9/8, 32/27, 81/64, 4/3, 729/512, 3/2, 128/81, 27/16, 16/9, 243/128 } end
function I.et12() local t = {} for i = 0, 11 do t[#t + 1] = 2 ^ (i / 12) end return t end
function I.normal() return I.ji() end
function I.overtone() return { 1, 17/16, 9/8, 19/16, 5/4, 21/16, 11/8, 3/2, 13/8, 27/16, 7/4, 15/8 } end
function I.undertone() return { 1, 16/15, 8/7, 16/13, 4/3, 16/11, 32/21, 8/5, 32/19, 16/9, 32/17 } end
function I.lamonte() return { 1, 567/512, 9/8, 147/128, 21/16, 1323/1024, 189/128, 3/2, 49/32, 7/4, 441/256, 63/32 } end
return I
