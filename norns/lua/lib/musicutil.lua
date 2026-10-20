-- musicutil
local MusicUtil = {}
MusicUtil.NOTE_NAMES = { 'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B' }
MusicUtil.SCALES = {
  { name = 'Major', alt_names = { 'Ionian' }, intervals = { 0, 2, 4, 5, 7, 9, 11, 12 }, chords = {} },
  { name = 'Natural Minor', alt_names = { 'Minor', 'Aeolian' }, intervals = { 0, 2, 3, 5, 7, 8, 10, 12 }, chords = {} },
  { name = 'Harmonic Minor', intervals = { 0, 2, 3, 5, 7, 8, 11, 12 }, chords = {} },
  { name = 'Melodic Minor', intervals = { 0, 2, 3, 5, 7, 9, 11, 12 }, chords = {} },
  { name = 'Dorian', intervals = { 0, 2, 3, 5, 7, 9, 10, 12 }, chords = {} },
  { name = 'Phrygian', intervals = { 0, 1, 3, 5, 7, 8, 10, 12 }, chords = {} },
  { name = 'Lydian', intervals = { 0, 2, 4, 6, 7, 9, 11, 12 }, chords = {} },
  { name = 'Mixolydian', intervals = { 0, 2, 4, 5, 7, 9, 10, 12 }, chords = {} },
  { name = 'Locrian', intervals = { 0, 1, 3, 5, 6, 8, 10, 12 }, chords = {} },
  { name = 'Whole Tone', intervals = { 0, 2, 4, 6, 8, 10, 12 }, chords = {} },
  { name = 'Major Pentatonic', alt_names = { 'Gagaku Ryo Sen Pou' }, intervals = { 0, 2, 4, 7, 9, 12 }, chords = {} },
  { name = 'Minor Pentatonic', alt_names = { 'Zokugaku Yo Sen Pou' }, intervals = { 0, 3, 5, 7, 10, 12 }, chords = {} },
  { name = 'Major Bebop', intervals = { 0, 2, 4, 5, 7, 8, 9, 11, 12 }, chords = {} },
  { name = 'Altered Scale', intervals = { 0, 1, 3, 4, 6, 8, 10, 12 }, chords = {} },
  { name = 'Dorian Bebop', intervals = { 0, 2, 3, 4, 5, 7, 9, 10, 12 }, chords = {} },
  { name = 'Mixolydian Bebop', intervals = { 0, 2, 4, 5, 7, 9, 10, 11, 12 }, chords = {} },
  { name = 'Blues Scale', alt_names = { 'Blues' }, intervals = { 0, 3, 5, 6, 7, 10, 12 }, chords = {} },
  { name = 'Diminished Whole Half', intervals = { 0, 2, 3, 5, 6, 8, 9, 11, 12 }, chords = {} },
  { name = 'Diminished Half Whole', intervals = { 0, 1, 3, 4, 6, 7, 9, 10, 12 }, chords = {} },
  { name = 'Neapolitan Major', intervals = { 0, 1, 3, 5, 7, 9, 11, 12 }, chords = {} },
  { name = 'Hungarian Major', intervals = { 0, 3, 4, 6, 7, 9, 10, 12 }, chords = {} },
  { name = 'Harmonic Major', intervals = { 0, 2, 4, 5, 7, 8, 11, 12 }, chords = {} },
  { name = 'Hungarian Minor', intervals = { 0, 2, 3, 6, 7, 8, 11, 12 }, chords = {} },
  { name = 'Lydian Minor', intervals = { 0, 2, 4, 6, 7, 8, 10, 12 }, chords = {} },
  { name = 'Neapolitan Minor', alt_names = { 'Byzantine' }, intervals = { 0, 1, 3, 5, 7, 8, 11, 12 }, chords = {} },
  { name = 'Major Locrian', intervals = { 0, 2, 4, 5, 6, 8, 10, 12 }, chords = {} },
  { name = 'Leading Whole Tone', intervals = { 0, 2, 4, 6, 8, 10, 11, 12 }, chords = {} },
  { name = 'Six Tone Symmetrical', intervals = { 0, 1, 4, 5, 8, 9, 11, 12 }, chords = {} },
  { name = 'Balinese', intervals = { 0, 1, 3, 7, 8, 12 }, chords = {} },
  { name = 'Persian', intervals = { 0, 1, 4, 5, 6, 8, 11, 12 }, chords = {} },
  { name = 'East Indian Purvi', intervals = { 0, 1, 4, 6, 7, 8, 11, 12 }, chords = {} },
  { name = 'Oriental', intervals = { 0, 1, 4, 5, 6, 9, 10, 12 }, chords = {} },
  { name = 'Double Harmonic', intervals = { 0, 1, 4, 5, 7, 8, 11, 12 }, chords = {} },
  { name = 'Enigmatic', intervals = { 0, 1, 4, 6, 8, 10, 11, 12 }, chords = {} },
  { name = 'Overtone', intervals = { 0, 2, 4, 6, 7, 9, 10, 12 }, chords = {} },
  { name = 'Eight Tone Spanish', intervals = { 0, 1, 3, 4, 5, 6, 8, 10, 12 }, chords = {} },
  { name = 'Prometheus', intervals = { 0, 2, 4, 6, 9, 10, 12 }, chords = {} },
  { name = 'Gagaku Rittsu Sen Pou', intervals = { 0, 2, 5, 7, 9, 10, 12 }, chords = {} },
  { name = 'In Sen Pou', intervals = { 0, 1, 5, 2, 8, 12 }, chords = {} },
  { name = 'Okinawa', intervals = { 0, 4, 5, 7, 11, 12 }, chords = {} },
  { name = 'Chromatic', intervals = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }, chords = {} },
}
MusicUtil.CHORDS = {
  { name = 'Major', alt_names = { 'Maj' }, intervals = { 0, 4, 7 } },
  { name = 'Major 6', alt_names = { 'Maj6' }, intervals = { 0, 4, 7, 9 } },
  { name = 'Major 7', alt_names = { 'Maj7' }, intervals = { 0, 4, 7, 11 } },
  { name = 'Major 69', alt_names = { 'Maj69' }, intervals = { 0, 4, 7, 9, 14 } },
  { name = 'Major 9', alt_names = { 'Maj9' }, intervals = { 0, 4, 7, 11, 14 } },
  { name = 'Major 11', alt_names = { 'Maj11' }, intervals = { 0, 4, 7, 11, 14, 17 } },
  { name = 'Major 13', alt_names = { 'Maj13' }, intervals = { 0, 4, 7, 11, 14, 17, 21 } },
  { name = 'Dominant 7', intervals = { 0, 4, 7, 10 } },
  { name = 'Ninth', intervals = { 0, 4, 7, 10, 14 } },
  { name = 'Eleventh', intervals = { 0, 4, 7, 10, 14, 17 } },
  { name = 'Thirteenth', intervals = { 0, 4, 7, 10, 14, 17, 21 } },
  { name = 'Augmented', intervals = { 0, 4, 8 } },
  { name = 'Augmented 7', intervals = { 0, 4, 8, 10 } },
  { name = 'Sus4', intervals = { 0, 5, 7 } },
  { name = 'Seventh sus4', intervals = { 0, 5, 7, 10 } },
  { name = 'Minor Major 7', alt_names = { 'MinMaj7' }, intervals = { 0, 3, 7, 11 } },
  { name = 'Minor', alt_names = { 'Min' }, intervals = { 0, 3, 7 } },
  { name = 'Minor 6', alt_names = { 'Min6' }, intervals = { 0, 3, 7, 9 } },
  { name = 'Minor 7', alt_names = { 'Min7' }, intervals = { 0, 3, 7, 10 } },
  { name = 'Minor 69', alt_names = { 'Min69' }, intervals = { 0, 3, 7, 9, 14 } },
  { name = 'Minor 9', alt_names = { 'Min9' }, intervals = { 0, 3, 7, 10, 14 } },
  { name = 'Minor 11', alt_names = { 'Min11' }, intervals = { 0, 3, 7, 10, 14, 17 } },
  { name = 'Minor 13', alt_names = { 'Min13' }, intervals = { 0, 3, 7, 10, 14, 17, 21 } },
  { name = 'Diminished', alt_names = { 'Dim' }, intervals = { 0, 3, 6 } },
  { name = 'Diminished 7', alt_names = { 'Dim7' }, intervals = { 0, 3, 6, 9 } },
  { name = 'Half Diminished 7', alt_names = { 'Min7b5' }, intervals = { 0, 3, 6, 10 } },
}
local function lookup(list, t)
  if type(t) == 'number' then return list[t] end
  local s = string.lower(tostring(t or ''))
  for _, v in ipairs(list) do
    if string.lower(v.name) == s then return v end
    if v.alt_names then for _, a in ipairs(v.alt_names) do if string.lower(a) == s then return v end end end
  end
  return nil
end
function MusicUtil.generate_scale_of_length(root, t, len)
  local sc = lookup(MusicUtil.SCALES, t) or MusicUtil.SCALES[1]
  local iv = sc.intervals
  local out = {}
  local i, o = 1, 0
  len = len or 8
  while #out < len do
    out[#out + 1] = root + o * 12 + iv[i]
    i = i + 1
    if i >= #iv then i = 1; o = o + 1 end
  end
  return out
end
function MusicUtil.generate_scale(root, t, octaves)
  local sc = lookup(MusicUtil.SCALES, t) or MusicUtil.SCALES[1]
  octaves = octaves or 1
  return MusicUtil.generate_scale_of_length(root, sc.name, (#sc.intervals - 1) * octaves + 1)
end
function MusicUtil.generate_chord(root, t, inversion)
  local ch = lookup(MusicUtil.CHORDS, t) or MusicUtil.CHORDS[1]
  local out = {}
  for _, v in ipairs(ch.intervals) do out[#out + 1] = root + v end
  for _ = 1, (inversion or 0) do local n = table.remove(out, 1); out[#out + 1] = n + 12 end
  return out
end
function MusicUtil.generate_chord_scale_degree(root, mode, degree, seventh)
  local sc = MusicUtil.generate_scale_of_length(root, mode, 16)
  local d = degree or 1
  local out = { sc[d], sc[d + 2], sc[d + 4] }
  if seventh then out[#out + 1] = sc[d + 6] end
  return out
end
function MusicUtil.chord_types_for_note() return {} end
function MusicUtil.note_num_to_freq(n) return 440 * 2 ^ ((n - 69) / 12) end
function MusicUtil.note_nums_to_freqs(t) local r = {} for i, n in ipairs(t) do r[i] = MusicUtil.note_num_to_freq(n) end return r end
function MusicUtil.freq_to_note_num(f) return math.floor(12 * math.log(f / 440, 2) + 69 + 0.5) end
function MusicUtil.freqs_to_note_nums(t) local r = {} for i, f in ipairs(t) do r[i] = MusicUtil.freq_to_note_num(f) end return r end
function MusicUtil.note_num_to_name(n, oct)
  n = math.floor(n)
  local s = MusicUtil.NOTE_NAMES[n % 12 + 1]
  if oct then s = s .. math.floor(n / 12 - 1) end
  return s
end
function MusicUtil.note_nums_to_names(t, oct) local r = {} for i, n in ipairs(t) do r[i] = MusicUtil.note_num_to_name(n, oct) end return r end
function MusicUtil.interval_to_ratio(i) return 2 ^ (i / 12) end
function MusicUtil.intervals_to_ratios(t) local r = {} for i, v in ipairs(t) do r[i] = 2 ^ (v / 12) end return r end
function MusicUtil.ratio_to_interval(r) return 12 * math.log(r, 2) end
function MusicUtil.snap_note_to_array(note, arr)
  local best, bd = arr[1], math.huge
  for _, v in ipairs(arr) do local d = math.abs(v - note); if d < bd then best, bd = v, d end end
  return best
end
function MusicUtil.snap_notes_to_array(notes, arr) local r = {} for i, n in ipairs(notes) do r[i] = MusicUtil.snap_note_to_array(n, arr) end return r end
return MusicUtil
