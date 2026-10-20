-- beatclock (legacy, driven by clock)
local BC = {}
BC.__index = BC
function BC.new(name)
  local b = setmetatable({}, BC)
  b.name = name or 'beatclock'
  b.playing = false; b.ticks_per_step = 6; b.current_ticks = 0
  b.steps_per_beat = 4; b.beats_per_bar = 4; b.step = 0; b.beat = 0; b.bpm = 110
  b.external = false
  b.on_step = function() end; b.on_start = function() end; b.on_stop = function() end
  b.metro = metro.init()
  b.metro.event = function() b:tick() end
  b.metro.time = 60 / (b.ticks_per_step * b.steps_per_beat * b.bpm)
  return b
end
function BC:start() self.playing = true; self.metro:start(); self.on_start() end
function BC:stop() self.playing = false; self.metro:stop(); self.on_stop() end
function BC:reset() self.step = 0; self.beat = 0; self.current_ticks = self.ticks_per_step - 1 end
function BC:tick()
  self.current_ticks = (self.current_ticks + 1) % self.ticks_per_step
  if self.playing and self.current_ticks == 0 then
    self.step = (self.step + 1) % self.steps_per_beat
    if self.step == 0 then self.beat = (self.beat + 1) % self.beats_per_bar end
    self.on_step()
  end
end
function BC:bpm_change(bpm) self.bpm = bpm; self.metro.time = 60 / (self.ticks_per_step * self.steps_per_beat * bpm) end
function BC:clock_source_change() end
function BC:process_midi() end
function BC:enable_midi_clock_out() end
function BC:add_clock_params()
  params:add_number('bpm', 'bpm', 1, 480, self.bpm)
  params:set_action('bpm', function(x) self:bpm_change(x) end)
end
return BC
