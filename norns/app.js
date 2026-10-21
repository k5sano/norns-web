/* norns web emulator — browser side */
(() => {
'use strict';

const BASE = 'norns/';
const LUA_LIBS = ['util', 'tabutil', 'controlspec', 'musicutil', 'er', 'sequins', 'lattice', 'formatters', 'intonation',
  'filters', 'beatclock', 'pattern_time', 'ui', 'fileselect', 'textentry', 'listselect', 'paramset', 'crow_emu', 'menu_emu',
  'lfo', 'reflection', 'graph', 'polysub', 'filtergraph', 'envgraph', 'voice', 'gridbuf', 'container_deque', 'bit32', 'cjson_emu', 'param_option'];
const DUST = '/home/we/dust/';
const CODE = DUST + 'code/';
const AUDIO_EXT = /\.(wav|aif|aiff|flac|mp3|ogg|opus|m4a)$/i;
const $ = id => document.getElementById(id);
const enc = new TextEncoder(), dec = new TextDecoder();
const css = getComputedStyle(document.documentElement);
const tok = (n, d) => css.getPropertyValue(n).trim() || d;

/* ============ console / status ============ */
const logEl = $('log'), statusEl = $('status'), statusText = $('statusText');
function log(msg, cls) {
  const line = document.createElement('div');
  if (cls) line.className = cls;
  line.textContent = msg;
  logEl.appendChild(line);
  while (logEl.childNodes.length > 400) logEl.removeChild(logEl.firstChild);
  logEl.scrollTop = logEl.scrollHeight;
}
let lastErr = '', lastErrT = 0;
function report(msg) {
  msg = String(msg == null ? 'error' : msg).split('/home/we/dust/code/').join('');
  const t = performance.now();
  if (msg === lastErr && t - lastErrT < 2000) return;
  lastErr = msg; lastErrT = t;
  log('### ' + msg, 'e');
  setStatus('err', 'エラー — ' + scriptLabel());
}
const warnedSet = new Set();
function warnOnce(key, msg) { if (!warnedSet.has(key)) { warnedSet.add(key); log('# ' + (msg || key + ' は未実装のため無視されます'), 's'); } }
function setStatus(kind, text) { statusEl.className = 'status ' + (kind || ''); statusText.textContent = text; }

/* ============ virtual filesystem (dust) ============ */
const VFS = new Map();
let db = null;
function idbOpen() {
  return new Promise(res => {
    try {
      const r = indexedDB.open('norns-web-emulator', 1);
      r.onupgradeneeded = () => r.result.createObjectStore('files');
      r.onsuccess = () => res(r.result);
      r.onerror = () => res(null);
      r.onblocked = () => res(null);
    } catch (e) { res(null); }
  });
}
function idbLoadAll() {
  if (!db) return Promise.resolve();
  return new Promise(res => {
    try {
      const req = db.transaction('files', 'readonly').objectStore('files').openCursor();
      req.onsuccess = e => { const c = e.target.result; if (c) { VFS.set(c.key, new Uint8Array(c.value)); c.continue(); } else res(); };
      req.onerror = () => res();
    } catch (e) { res(); }
  });
}
function idbPut(p, data) { if (!db) return; try { db.transaction('files', 'readwrite').objectStore('files').put(data, p); } catch (e) {} }
function idbDel(p) { if (!db) return; try { db.transaction('files', 'readwrite').objectStore('files').delete(p); } catch (e) {} }
let vfsTimer = 0;
function vfsChanged() { clearTimeout(vfsTimer); vfsTimer = setTimeout(() => { refreshFileSelect(); renderInstalled(); renderAudioList(); }, 150); }
const vfs = {
  read: p => VFS.get(p) || null,
  text: p => { const b = VFS.get(p); return b ? dec.decode(b) : null; },
  write(p, data, quiet) {
    if (typeof data === 'string') data = enc.encode(data);
    VFS.set(p, data);
    if (p.startsWith(DUST)) idbPut(p, data);
    if (!quiet) vfsChanged();
  },
  exists(p) {
    if (VFS.has(p)) return true;
    const d = p.endsWith('/') ? p : p + '/';
    for (const k of VFS.keys()) if (k.startsWith(d)) return true;
    return false;
  },
  list(d) {
    if (!d.endsWith('/')) d += '/';
    const s = new Set();
    for (const k of VFS.keys()) if (k.startsWith(d)) { const r = k.slice(d.length); const i = r.indexOf('/'); s.add(i < 0 ? r : r.slice(0, i + 1)); }
    return [...s].sort();
  },
  remove(p) {
    const d = p.endsWith('/') ? p : p + '/';
    for (const k of [...VFS.keys()]) if (k === p || k.startsWith(d)) { VFS.delete(k); idbDel(k); }
    vfsChanged();
  },
  scripts() {
    const out = [];
    for (const k of VFS.keys()) {
      const m = k.match(/^\/home\/we\/dust\/code\/([^/]+)\/([^/]+)\.lua$/);
      if (m && !/^(lib|test|tests)$/.test(m[2])) out.push(m[1] + '/' + m[2]);
    }
    return out.sort();
  },
  projects() { return vfs.list(CODE).filter(n => n.endsWith('/')).map(n => n.slice(0, -1)); },
};

/* ============ screen: two surfaces (script / menu) ============ */
function makeSurface() {
  const c = document.createElement('canvas');
  c.width = 128; c.height = 64;
  const ctx = c.getContext('2d');
  ctx.fillStyle = '#000'; ctx.fillRect(0, 0, 128, 64);
  return { c, ctx, path: [], col: 'rgb(255,255,255)', lw: 1, fs: 8, face: 1, cx: 0, cy: 0 };
}
const surf = [makeSurface(), makeSurface()];
let tgt = 0, shown = 0;
const oled = $('oled');
const dc = oled.getContext('2d');
let DW = oled.width, DH = oled.height, PX = DW / 128, gapPattern = null;
const canFilter = typeof dc.filter === 'string';
function sizeOled() {
  const dpr = Math.min(3, window.devicePixelRatio || 1);
  const w = oled.getBoundingClientRect().width;
  if (!w) return;
  PX = Math.max(1, Math.floor(w * dpr / 128));
  DW = oled.width = PX * 128; DH = oled.height = PX * 64;
  gapPattern = null;
  if (PX >= 4) {
    const gap = document.createElement('canvas');
    gap.width = PX; gap.height = PX;
    const g = gap.getContext('2d'), t = Math.max(1, Math.round(PX * 0.14));
    g.fillStyle = '#fff'; g.fillRect(0, 0, PX, PX); g.fillStyle = '#3c3c3c'; g.fillRect(PX - t, 0, t, PX); g.fillRect(0, PX - t, PX, t);
    gapPattern = dc.createPattern(gap, 'repeat');
  }
  present(shown);
}
new ResizeObserver(sizeOled).observe(oled);
const OLED_TINT = tok('--oled', '#eaf2ff');
const BLEND = ['source-over', 'destination-out', 'copy', 'source-over', 'source-in', 'source-out', 'source-atop', 'destination-over',
  'destination-over', 'destination-in', 'destination-out', 'destination-atop', 'xor', 'lighter', 'lighter', 'multiply', 'screen',
  'overlay', 'darken', 'lighten', 'color-dodge', 'color-burn', 'hard-light', 'soft-light', 'difference', 'exclusion'];
const BLEND_NAMES = { none: 0, clear: 1, source: 2, over: 3, in: 4, out: 5, atop: 6, dest: 7, dest_over: 8, dest_in: 9, dest_out: 10,
  dest_atop: 11, xor: 12, add: 13, saturate: 14, multiply: 15, screen: 16, overlay: 17, darken: 18, lighten: 19, color_dodge: 20,
  color_burn: 21, hard_light: 22, soft_light: 23, difference: 24, exclusion: 25 };

function present(i) {
  if (i !== shown) return;
  const src = surf[i].c;
  dc.globalCompositeOperation = 'source-over'; dc.globalAlpha = 1;
  dc.imageSmoothingEnabled = false;
  if (canFilter) dc.filter = 'none';
  dc.drawImage(src, 0, 0, DW, DH);
  dc.globalCompositeOperation = 'multiply';
  dc.fillStyle = OLED_TINT; dc.fillRect(0, 0, DW, DH);
  if (gapPattern) { dc.fillStyle = gapPattern; dc.fillRect(0, 0, DW, DH); }
  if (canFilter) {
    dc.globalCompositeOperation = 'lighter'; dc.globalAlpha = 0.26;
    dc.imageSmoothingEnabled = true; dc.filter = `blur(${Math.max(2, PX * 0.9)}px)`;
    dc.drawImage(src, 0, 0, DW, DH);
    dc.filter = 'none';
  }
  dc.globalAlpha = 1; dc.globalCompositeOperation = 'source-over';
}
function resetSurface(s) {
  s.ctx.setTransform(1, 0, 0, 1, 0, 0);
  s.ctx.globalCompositeOperation = 'source-over';
  s.ctx.fillStyle = '#000'; s.ctx.fillRect(0, 0, 128, 64);
  s.path = []; s.lw = 1; s.fs = 8; s.face = 1; s.cx = 0; s.cy = 0; s.col = 'rgb(255,255,255)';
  s.ctx.lineCap = 'butt'; s.ctx.lineJoin = 'miter';
}
function levelColor(l) { l = Math.max(0, Math.min(15, Math.floor(+l || 0))); const v = Math.round(l / 15 * 255); return `rgb(${v},${v},${v})`; }
function replay(s, o) {
  const c = s.ctx;
  c.beginPath();
  for (const p of s.path) {
    switch (p[0]) {
      case 'M': c.moveTo(p[1] + o, p[2] + o); break;
      case 'L': c.lineTo(p[1] + o, p[2] + o); break;
      case 'R': c.rect(p[1] + o, p[2] + o, p[3], p[4]); break;
      case 'O': c.moveTo(p[1] + p[3] + o, p[2] + o); c.arc(p[1] + o, p[2] + o, Math.max(0, p[3]), 0, Math.PI * 2); break;
      case 'A': c.arc(p[1] + o, p[2] + o, Math.max(0, p[3]), p[4], p[5]); break;
      case 'C': c.bezierCurveTo(p[1] + o, p[2] + o, p[3] + o, p[4] + o, p[5] + o, p[6] + o); break;
      case 'P': c.rect(p[1], p[2], 1, 1); break;
      case 'Z': c.closePath(); break;
    }
  }
}
function fontFor(s) {
  const pixel = s.face <= 2 || s.face >= 25;
  return pixel ? `${s.fs}px Silkscreen, ui-monospace, monospace` : `${s.fs}px "IBM Plex Sans JP", system-ui, sans-serif`;
}
function drawText(str, align) {
  const s = surf[tgt], c = s.ctx;
  c.font = fontFor(s);
  const w = c.measureText(str).width;
  let x = s.cx;
  if (align === 'r') x -= w; else if (align === 'c') x -= w / 2;
  c.fillStyle = s.col;
  c.fillText(str, Math.round(x), Math.round(s.cy));
  if (!align) s.cx += w;
}
const images = new Map();
function getImage(path) {
  let e = images.get(path);
  if (e) return e.ready ? e.canvas : null;
  e = { ready: false, canvas: null };
  images.set(path, e);
  const bytes = vfs.read(path);
  if (!bytes || typeof createImageBitmap !== 'function') { warnOnce('png:' + path, '画像が見つかりません: ' + path); return null; }
  createImageBitmap(new Blob([bytes])).then(bm => {
    const c = document.createElement('canvas'); c.width = bm.width; c.height = bm.height;
    const x = c.getContext('2d'); x.drawImage(bm, 0, 0);
    const d = x.getImageData(0, 0, c.width, c.height);
    for (let i = 0; i < d.data.length; i += 4) {
      const l = 0.3 * d.data[i] + 0.59 * d.data[i + 1] + 0.11 * d.data[i + 2];
      d.data[i] = d.data[i + 1] = d.data[i + 2] = l;
    }
    x.putImageData(d, 0, 0);
    e.canvas = c; e.ready = true;
  }).catch(() => warnOnce('png:' + path, '画像を読み込めません: ' + path));
  return null;
}
const multi = (...a) => { a.multi = true; return a; };
const S = () => surf[tgt];
const screenFns = {
  __s_target(i) { tgt = i ? 1 : 0; },
  __s_show(i) { shown = i ? 1 : 0; },
  __s_clear() { const c = S().ctx; c.save(); c.setTransform(1, 0, 0, 1, 0, 0); c.globalCompositeOperation = 'source-over'; c.fillStyle = '#000'; c.fillRect(0, 0, 128, 64); c.restore(); },
  __s_update(i) { present(i ? 1 : 0); },
  __s_level(l) { S().col = levelColor(l); },
  __s_move(x, y) { const s = S(); s.cx = +x || 0; s.cy = +y || 0; s.path.push(['M', s.cx, s.cy]); },
  __s_line(x, y) { const s = S(); s.cx = +x || 0; s.cy = +y || 0; s.path.push(['L', s.cx, s.cy]); },
  __s_move_rel(x, y) { const s = S(); s.cx += +x || 0; s.cy += +y || 0; s.path.push(['M', s.cx, s.cy]); },
  __s_line_rel(x, y) { const s = S(); s.cx += +x || 0; s.cy += +y || 0; s.path.push(['L', s.cx, s.cy]); },
  __s_rect(x, y, w, h) { S().path.push(['R', +x || 0, +y || 0, +w || 0, +h || 0]); },
  __s_circle(x, y, r) { S().path.push(['O', +x || 0, +y || 0, +r || 0]); },
  __s_arc(x, y, r, a1, a2) { S().path.push(['A', +x || 0, +y || 0, +r || 0, +a1 || 0, +a2 || 0]); },
  __s_curve(x1, y1, x2, y2, x3, y3) { const s = S(); s.path.push(['C', +x1, +y1, +x2, +y2, +x3, +y3]); s.cx = +x3; s.cy = +y3; },
  __s_curve_rel(x1, y1, x2, y2, x3, y3) { const s = S(), bx = s.cx, by = s.cy; s.path.push(['C', bx + x1, by + y1, bx + x2, by + y2, bx + x3, by + y3]); s.cx = bx + x3; s.cy = by + y3; },
  __s_close() { S().path.push(['Z']); },
  __s_stroke() { const s = S(); s.ctx.strokeStyle = s.col; s.ctx.lineWidth = s.lw; replay(s, (Math.round(s.lw) % 2 === 1) ? 0.5 : 0); s.ctx.stroke(); s.path = []; },
  __s_fill() { const s = S(); s.ctx.fillStyle = s.col; replay(s, 0); s.ctx.fill(); s.path = []; },
  __s_pixel(x, y) { S().path.push(['P', Math.floor(x), Math.floor(y)]); },
  __s_text(t) { drawText(t); },
  __s_text_right(t) { drawText(t, 'r'); },
  __s_text_center(t) { drawText(t, 'c'); },
  __s_text_extents(t) { const s = S(); s.ctx.font = fontFor(s); return multi(s.ctx.measureText(t).width, s.fs); },
  __s_text_rotate(x, y, t, deg, center) {
    const s = S(), c = s.ctx;
    c.save(); c.font = fontFor(s); c.fillStyle = s.col;
    c.translate(+x, +y); c.rotate((+deg || 0) * Math.PI / 180);
    c.fillText(t, center ? -c.measureText(t).width / 2 : 0, 0);
    c.restore();
  },
  __s_current_point() { const s = S(); return multi(s.cx, s.cy); },
  __s_font_size(n) { S().fs = Math.max(4, Math.min(64, +n || 8)); },
  __s_font_face(n) { S().face = Math.max(1, +n || 1); },
  __s_line_width(w) { S().lw = Math.max(0.1, +w || 1); },
  __s_line_cap(c) { if (['butt', 'round', 'square'].includes(c)) S().ctx.lineCap = c; },
  __s_line_join(j) { if (['miter', 'round', 'bevel'].includes(j)) S().ctx.lineJoin = j; },
  __s_aa() {},
  __s_save() { S().ctx.save(); },
  __s_restore() { S().ctx.restore(); },
  __s_translate(x, y) { S().ctx.translate(+x || 0, +y || 0); },
  __s_rotate(r) { S().ctx.rotate(+r || 0); },
  __s_blend_mode(m) {
    let i = typeof m === 'string' ? BLEND_NAMES[m.toLowerCase()] : m;
    S().ctx.globalCompositeOperation = BLEND[i | 0] || 'source-over';
  },
  __s_display_png(p, x, y, l, t, w, h) {
    const img = getImage(String(p)); if (!img) return;
    const c = S().ctx;
    if (w != null) c.drawImage(img, +l, +t, +w, +h, +x, +y, +w, +h); else c.drawImage(img, +x || 0, +y || 0);
  },
  __s_peek(x, y, w, h) {
    const d = S().ctx.getImageData(+x || 0, +y || 0, Math.max(1, +w || 1), Math.max(1, +h || 1)).data;
    const out = new Uint8Array(d.length / 4);
    for (let i = 0; i < out.length; i++) out[i] = Math.round(d[i * 4] / 17);
    return { bytes: out };
  },
  __s_poke() { warnOnce('screen.poke'); },
};

/* ============ audio graph, engines, softcut ============ */
let AC = null;
const A = {};
const MIX_DEFAULT = { level_dac: 1, level_eng: 1, level_cut: 1, level_monitor: 1, level_adc: 1, level_eng_cut: 0, level_adc_cut: 1,
  level_tape_cut: 0, level_cut_rev: 0, level_eng_rev: 0.25, level_monitor_rev: 0, rev_return_level: 0.6, rev_on: 1, comp_on: 1 };
const MIX_ALIAS = { level_ext: 'level_eng', level_ext_cut: 'level_eng_cut', level_ext_rev: 'level_eng_rev' };
const userMix = { level_dac: 1, level_eng: 1, level_cut: 1, rev_return_level: 0.6 };
let mixState = { ...MIX_DEFAULT, ...userMix };

function gain(v) { const g = AC.createGain(); g.gain.value = v; return g; }
function makeIR(sec) {
  const len = Math.floor(AC.sampleRate * sec), b = AC.createBuffer(2, len, AC.sampleRate);
  for (let ch = 0; ch < 2; ch++) {
    const d = b.getChannelData(ch);
    for (let i = 0; i < len; i++) d[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / len, 3.2) * (i < 200 ? i / 200 : 1);
  }
  return b;
}
function initAudio() {
  if (AC) return;
  const C = window.AudioContext || window.webkitAudioContext;
  if (!C) { warnOnce('noaudio', 'このブラウザでは Web Audio が使えません'); return; }
  try { AC = new C({ latencyHint: 'interactive' }); } catch (e) { AC = new C(); }
  A.mix = gain(1);
  A.dac = gain(1);
  A.comp = AC.createDynamicsCompressor();
  A.comp.threshold.value = -10; A.comp.ratio.value = 4; A.comp.attack.value = 0.005; A.comp.release.value = 0.15;
  A.out = gain(1);
  A.splitOut = AC.createChannelSplitter(2);
  A.anaL = AC.createAnalyser(); A.anaR = AC.createAnalyser(); A.anaL.fftSize = A.anaR.fftSize = 1024;
  A.mix.connect(A.dac);
  A.out.connect(AC.destination);
  A.out.connect(A.splitOut); A.splitOut.connect(A.anaL, 0); A.splitOut.connect(A.anaR, 1);
  A.eng = gain(1);
  A.engOut = gain(1); A.eng.connect(A.engOut).connect(A.mix);
  A.revIn = gain(1);
  A.rev = AC.createConvolver(); A.rev.buffer = makeIR(2.6);
  A.revOut = gain(0.6);
  A.revIn.connect(A.rev).connect(A.revOut).connect(A.mix);
  A.engRev = gain(0.25); A.eng.connect(A.engRev).connect(A.revIn);
  A.scIn = AC.createGain(); A.scIn.channelCount = 2; A.scIn.channelCountMode = 'explicit';
  A.engCut = gain(0); A.eng.connect(A.engCut).connect(A.scIn);
  A.adc = gain(1);
  A.adcCut = gain(1); A.adc.connect(A.adcCut).connect(A.scIn);
  A.monitor = gain(1); A.adc.connect(A.monitor).connect(A.mix);
  A.anaIn = AC.createAnalyser(); A.anaIn.fftSize = 1024; A.adc.connect(A.anaIn);
  A.cutOut = gain(1); A.cutOut.connect(A.mix);
  A.cutRev = gain(0); A.cutOut.connect(A.cutRev).connect(A.revIn);
  A.crowBus = gain(1); A.crowBus.connect(A.mix);
  applyMix();
  initSoftcut();
}
function setG(node, v) { if (node) { try { node.gain.setTargetAtTime(v, AC.currentTime, 0.015); } catch (e) { node.gain.value = v; } } }
function applyMix() {
  if (!AC) return;
  const m = mixState;
  setG(A.dac, m.level_dac); setG(A.engOut, m.level_eng); setG(A.cutOut, m.level_cut); setG(A.monitor, m.level_monitor);
  setG(A.adc, m.level_adc); setG(A.engCut, m.level_eng_cut); setG(A.adcCut, m.level_adc_cut);
  setG(A.cutRev, m.level_cut_rev); setG(A.engRev, m.level_eng_rev); setG(A.revOut, m.rev_on ? m.rev_return_level : 0);
  try { A.dac.disconnect(); } catch (e) {}
  if (m.comp_on) { A.dac.connect(A.comp); try { A.comp.disconnect(); } catch (e) {} A.comp.connect(A.out); } else A.dac.connect(A.out);
}
function mixNative(name, a) {
  name = MIX_ALIAS[name] || name;
  if (name === 'file_info') return;
  if (name in MIX_DEFAULT) {
    const v = typeof a === 'boolean' ? (a ? 1 : 0) : Math.max(0, +a || 0);
    mixState[name] = v;
    if (name in userMix) userMix[name] = v;
    applyMix();
  }
}
function resumeAudio() {
  initAudio();
  if (AC && AC.state !== 'running') AC.resume().then(updateAudioHint).catch(() => {});
  updateAudioHint();
}
function updateAudioHint() { $('audioHint').hidden = !!(AC && AC.state === 'running'); }

/* ---- softcut facade ---- */
const SC = { node: null, core: null, ready: false, queue: [], pending: new Map(), id: 0 };
async function initSoftcut() {
  try {
    if (!AC.audioWorklet) throw new Error('no worklet');
    await AC.audioWorklet.addModule(BASE + 'softcut.js');
    SC.node = new AudioWorkletNode(AC, 'softcut', { numberOfInputs: 1, numberOfOutputs: 1, outputChannelCount: [2], channelCount: 2, channelCountMode: 'explicit' });
    SC.node.port.onmessage = e => {
      const m = e.data;
      if (m.t === 'reply') { const cb = SC.pending.get(m.id); SC.pending.delete(m.id); if (cb) cb(m.r); }
      else if (m.t === 'phase') onPhase(m.e);
    };
    A.scIn.connect(SC.node); SC.node.connect(A.cutOut);
  } catch (e) {
    if (typeof SoftcutCore !== 'function') { warnOnce('softcut', 'softcut を初期化できませんでした'); return; }
    SC.core = new SoftcutCore(AC.sampleRate);
    const sp = AC.createScriptProcessor(1024, 2, 2);
    sp.onaudioprocess = ev => {
      const i = ev.inputBuffer, o = ev.outputBuffer;
      SC.core.process(i.getChannelData(0), i.getChannelData(1), o.getChannelData(0), o.getChannelData(1), o.length);
      if (SC.core.events.length) { const ev2 = SC.core.events; SC.core.events = []; onPhase(ev2); }
    };
    A.scIn.connect(sp); sp.connect(A.cutOut);
    SC.sp = sp;
  }
  SC.ready = true;
  const q = SC.queue; SC.queue = [];
  for (const [fn, args, cb] of q) scCall(fn, args, cb);
}
function scCall(fn, args, cb) {
  if (!SC.ready) { if (SC.queue.length < 20000) SC.queue.push([fn, args, cb]); return; }
  if (SC.node) {
    const m = { fn, args };
    if (cb) { m.id = ++SC.id; SC.pending.set(m.id, cb); }
    const tr = args.filter(a => a instanceof Float32Array).map(a => a.buffer);
    SC.node.port.postMessage(m, tr);
  } else if (SC.core) {
    const r = SC.core.call(fn, args);
    if (cb) setTimeout(() => cb(r), 0);
  }
}
function onPhase(ev) {
  const last = new Map();
  for (let i = 0; i < ev.length; i += 2) last.set(ev[i], ev[i + 1]);
  for (const [v, p] of last) callLua('__sc_phase', v + 1, p);
}
const decoded = new Map();
const audioInfo = new Map();
function parseWavInfo(b) {
  if (!b || b.length < 44) return null;
  const dv = new DataView(b.buffer, b.byteOffset, b.byteLength);
  const tag = s => String.fromCharCode(b[s], b[s + 1], b[s + 2], b[s + 3]);
  if (tag(0) !== 'RIFF' || tag(8) !== 'WAVE') return null;
  let p = 12, ch = 0, sr = 0, bits = 16, frames = 0;
  while (p + 8 <= b.length) {
    const id = tag(p), size = dv.getUint32(p + 4, true);
    if (id === 'fmt ') { ch = dv.getUint16(p + 10, true); sr = dv.getUint32(p + 12, true); bits = dv.getUint16(p + 22, true); }
    if (id === 'data') { frames = Math.floor(Math.min(size, b.length - p - 8) / (ch * bits / 8)); break; }
    p += 8 + size + (size & 1);
  }
  return ch ? { ch, frames, sr } : null;
}
function fileInfo(path) {
  if (audioInfo.has(path)) return audioInfo.get(path);
  const b = vfs.read(path);
  if (!b) return null;
  const w = parseWavInfo(b);
  if (w) { audioInfo.set(path, w); return w; }
  decodeFile(path).catch(() => {});
  return null;
}
function decodeFile(path) {
  if (decoded.has(path)) return decoded.get(path);
  const bytes = vfs.read(path);
  if (!bytes) return Promise.reject(new Error('missing'));
  initAudio();
  const pr = new Promise((res, rej) => {
    const buf = bytes.slice().buffer;
    AC.decodeAudioData(buf, ab => {
      if (!audioInfo.has(path)) audioInfo.set(path, { ch: ab.numberOfChannels, frames: Math.round(ab.duration * ab.sampleRate), sr: ab.sampleRate });
      res(ab);
    }, err => rej(err || new Error('decode')));
  });
  decoded.set(path, pr);
  pr.catch(() => decoded.delete(path));
  return pr;
}
function scLoadFile(path, startSrc, startDst, dur, chSrc, chDst, preserve, mix) {
  path = String(path);
  if (!vfs.read(path)) { report('softcut: ファイルがありません ' + path + '（ライブラリから音声を読み込めます）'); return; }
  decodeFile(path).then(ab => {
    const sr = ab.sampleRate;
    const src = ab.getChannelData(Math.min(ab.numberOfChannels - 1, Math.max(0, chSrc - 1)));
    const a = Math.max(0, Math.floor(startSrc * sr));
    const b = dur < 0 ? src.length : Math.min(src.length, a + Math.floor(dur * sr));
    scCall('load', [chDst - 1, startDst, src.slice(a, b), preserve, mix]);
  }).catch(() => report('softcut: 音声をデコードできません ' + path));
}
function encodeWav(chans, sr) {
  const n = chans[0].length, nc = chans.length, b = new ArrayBuffer(44 + n * nc * 2), v = new DataView(b);
  const w = (o, s) => { for (let i = 0; i < s.length; i++) v.setUint8(o + i, s.charCodeAt(i)); };
  w(0, 'RIFF'); v.setUint32(4, 36 + n * nc * 2, true); w(8, 'WAVE'); w(12, 'fmt '); v.setUint32(16, 16, true);
  v.setUint16(20, 1, true); v.setUint16(22, nc, true); v.setUint32(24, sr, true); v.setUint32(28, sr * nc * 2, true);
  v.setUint16(32, nc * 2, true); v.setUint16(34, 16, true); w(36, 'data'); v.setUint32(40, n * nc * 2, true);
  let o = 44;
  for (let i = 0; i < n; i++) for (let c = 0; c < nc; c++) { const x = Math.max(-1, Math.min(1, chans[c][i])); v.setInt16(o, x * 32767, true); o += 2; }
  return new Uint8Array(b);
}
function scWriteFile(path, start, dur, chs) {
  const got = [];
  chs.forEach((ch, i) => scCall('region', [ch - 1, start, dur], r => {
    got[i] = r;
    if (got.filter(Boolean).length === chs.length) {
      vfs.write(String(path), encodeWav(got, AC ? AC.sampleRate : 48000));
      log('# softcut: ' + String(path).replace('/home/we/', '') + ' に書き出しました', 's');
    }
  }));
}
const SC_VOICE = new Set(['enable', 'buffer', 'level', 'pan', 'rate', 'play', 'rec', 'rec_level', 'pre_level', 'loop', 'loop_start',
  'loop_end', 'fade_time', 'rate_slew_time', 'level_slew_time', 'pan_slew_time', 'recpre_slew_time', 'phase_quant', 'phase_offset',
  'post_filter_fc', 'post_filter_rq', 'post_filter_lp', 'post_filter_hp', 'post_filter_bp', 'post_filter_br', 'post_filter_dry']);
const SC_ALIAS = { filter_fc: 'post_filter_fc', filter_rq: 'post_filter_rq', filter_lp: 'post_filter_lp', filter_hp: 'post_filter_hp',
  filter_bp: 'post_filter_bp', filter_br: 'post_filter_br', filter_dry: 'post_filter_dry' };
const num = (x, d = 0) => (x === null || x === undefined) ? d : (typeof x === 'boolean' ? (x ? 1 : 0) : (+x || 0));
function scNative(name, ...a) {
  name = SC_ALIAS[name] || name;
  if (SC_VOICE.has(name)) { scCall('set', [num(a[0], 1) - 1, name, num(a[1])]); return; }
  const v0 = num(a[0], 1) - 1;
  switch (name) {
    case 'position': scCall('position', [v0, num(a[1])]); break;
    case 'level_input_cut': scCall('level_input_cut', [v0, num(a[1], 1) - 1, num(a[2])]); break;
    case 'level_cut_cut': scCall('level_cut_cut', [v0, num(a[1], 1) - 1, num(a[2])]); break;
    case 'voice_sync': scCall('voice_sync', [v0, num(a[1], 1) - 1, num(a[2])]); break;
    case 'query_position': scCall('query', [v0], r => callLua('__sc_position', v0 + 1, r)); break;
    case 'buffer_clear': scCall('clear', []); break;
    case 'buffer_clear_channel': scCall('clear_channel', [v0]); break;
    case 'buffer_clear_region': scCall('clear_region', [-1, num(a[0]), a[1] == null ? -1 : num(a[1])]); break;
    case 'buffer_clear_region_channel': scCall('clear_region', [v0, num(a[1]), a[2] == null ? -1 : num(a[2])]); break;
    case 'buffer_copy_mono': scCall('copy', [v0, num(a[1], 1) - 1, num(a[2]), num(a[3]), a[4] == null ? -1 : num(a[4]), num(a[5]), num(a[6]), !!a[7]]); break;
    case 'buffer_copy_stereo': for (const ch of [0, 1]) scCall('copy', [ch, ch, num(a[0]), num(a[1]), a[2] == null ? -1 : num(a[2]), num(a[3]), num(a[4]), !!a[5]]); break;
    case 'buffer_read_mono': scLoadFile(a[0], num(a[1]), num(a[2]), a[3] == null ? -1 : num(a[3]), num(a[4], 1), num(a[5], 1), num(a[6]), a[7] == null ? 1 : num(a[7])); break;
    case 'buffer_read_stereo':
      scLoadFile(a[0], num(a[1]), num(a[2]), a[3] == null ? -1 : num(a[3]), 1, 1, num(a[4]), a[5] == null ? 1 : num(a[5]));
      scLoadFile(a[0], num(a[1]), num(a[2]), a[3] == null ? -1 : num(a[3]), 2, 2, num(a[4]), a[5] == null ? 1 : num(a[5]));
      break;
    case 'buffer_write_mono': scWriteFile(a[0], num(a[1]), a[2] == null ? -1 : num(a[2]), [num(a[3], 1)]); break;
    case 'buffer_write_stereo': scWriteFile(a[0], num(a[1]), a[2] == null ? -1 : num(a[2]), [1, 2]); break;
    case 'render_buffer': {
      const ch = num(a[0], 1), st = num(a[1]);
      scCall('render', [ch - 1, st, num(a[2], 1), num(a[3], 128)], r => callLua('__sc_render', ch, st, r[1], Array.from(r[0])));
      break;
    }
    case 'poll_start_phase': scCall('phase_poll', [true]); break;
    case 'poll_stop_phase': scCall('phase_poll', [false]); break;
    case 'reset': case 'init': scCall('reset', []); break;
    case 'pre_filter_fc': case 'pre_filter_rq': case 'pre_filter_lp': case 'pre_filter_hp': case 'pre_filter_bp': case 'pre_filter_br':
    case 'pre_filter_dry': case 'pre_filter_fc_mod': case 'filter_fc_mod': case 'rec_offset': case 'rec_once': break;
    default: warnOnce('softcut.' + name);
  }
}

/* ---- engines ---- */
const ENGINE_INFO = {
  PolyPerc: 'hz amp cutoff release pw gain pan',
  TestSine: 'hz amp',
  PolySub: 'start stop stopAll level shape timbre noise cut fgain cutEnvAmt detune width ampAtk ampDec ampSus ampRel cutAtk cutDec cutSus cutRel',
  MollyThePoly: 'noteOn noteOff noteOffAll noteKill noteKillAll oscWaveShape lpFilterCutoff lpFilterResonance env2Attack env2Decay env2Sustain env2Release amp mainOscLevel subOscLevel noiseLevel',
  None: '',
};
let engineName = 'None';
let eng = {};
const voices = new Map();
let voiceCount = 0;
const waves = new Map();
function pulseWave(pw) {
  const key = Math.round(Math.max(0.02, Math.min(0.98, pw)) * 40);
  if (waves.has(key)) return waves.get(key);
  const d = key / 40, N = 48, re = new Float32Array(N), im = new Float32Array(N);
  for (let n = 1; n < N; n++) re[n] = 2 * Math.sin(Math.PI * n * d) / (Math.PI * n);
  const w = AC.createPeriodicWave(re, im);
  waves.set(key, w);
  return w;
}
function audioOk() { return AC && AC.state === 'running' && voiceCount < 48; }
function perc(hz, p) {
  if (!audioOk() || !(hz > 0)) return;
  const t = AC.currentTime + 0.005, rel = Math.max(0.02, p.release);
  const o = AC.createOscillator(); o.setPeriodicWave(pulseWave(p.pw)); o.frequency.value = Math.min(hz, 12000);
  const f = AC.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = Math.max(30, Math.min(p.cutoff, AC.sampleRate / 2 - 100)); f.Q.value = 0.6 + Math.max(0, p.gain) * 1.4;
  const g = AC.createGain();
  g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(Math.max(0.0002, p.amp * 0.45), t + 0.004);
  g.gain.exponentialRampToValueAtTime(0.0001, t + 0.004 + rel);
  const pn = AC.createStereoPanner ? AC.createStereoPanner() : null;
  o.connect(f).connect(g);
  if (pn) { pn.pan.value = Math.max(-1, Math.min(1, p.pan)); g.connect(pn).connect(A.eng); } else g.connect(A.eng);
  voiceCount++;
  o.onended = () => { voiceCount--; try { g.disconnect(); if (pn) pn.disconnect(); } catch (e) {} };
  o.start(t); o.stop(t + rel + 0.05);
}
function sustainVoice(hz, p) {
  if (!audioOk() || !(hz > 0)) return null;
  const t = AC.currentTime + 0.005;
  const o = AC.createOscillator();
  if (p.wave === 'pulse') o.setPeriodicWave(pulseWave(p.pw || 0.5)); else o.type = p.wave || 'sawtooth';
  o.frequency.value = Math.min(hz, 12000);
  const nodes = [o];
  const f = AC.createBiquadFilter(); f.type = 'lowpass';
  f.frequency.value = Math.max(30, Math.min(p.cutoff, AC.sampleRate / 2 - 100)); f.Q.value = p.q || 0.8;
  const oscG = gain(p.oscLevel == null ? 1 : p.oscLevel); o.connect(oscG).connect(f);
  if (p.sub) { const s = AC.createOscillator(); s.type = 'square'; s.frequency.value = hz / 2; const sg = gain(p.sub * 0.6); s.connect(sg).connect(f); nodes.push(s); }
  if (p.noise) {
    const nb = AC.createBuffer(1, AC.sampleRate, AC.sampleRate), d = nb.getChannelData(0);
    for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
    const ns = AC.createBufferSource(); ns.buffer = nb; ns.loop = true; const ng = gain(p.noise * 0.5); ns.connect(ng).connect(f); nodes.push(ns);
  }
  const g = AC.createGain();
  const peak = Math.max(0.0002, p.amp * 0.3 * (p.vel == null ? 1 : p.vel));
  g.gain.setValueAtTime(0, t);
  g.gain.linearRampToValueAtTime(peak, t + Math.max(0.003, p.a));
  g.gain.linearRampToValueAtTime(Math.max(0.0001, peak * p.s), t + Math.max(0.003, p.a) + Math.max(0.003, p.d));
  f.connect(g).connect(A.eng);
  nodes.forEach(n => n.start(t));
  voiceCount++;
  let done = false;
  const end = when => { if (done) return; done = true; nodes.forEach(n => { try { n.stop(when); } catch (e) {} }); setTimeout(() => { voiceCount--; try { g.disconnect(); } catch (e) {} }, (when - AC.currentTime) * 1000 + 100); };
  return {
    release() {
      const now = AC.currentTime;
      g.gain.cancelScheduledValues(now);
      g.gain.setValueAtTime(Math.max(0.0001, g.gain.value), now);
      g.gain.exponentialRampToValueAtTime(0.0001, now + Math.max(0.01, p.r));
      end(now + Math.max(0.01, p.r) + 0.05);
    },
    kill() { const now = AC.currentTime; g.gain.cancelScheduledValues(now); g.gain.setTargetAtTime(0, now, 0.005); end(now + 0.05); },
  };
}
let sine = null;
function resetEngine() {
  for (const v of voices.values()) try { v.kill(); } catch (e) {}
  voices.clear();
  if (sine) { try { sine.o.stop(); } catch (e) {} sine = null; }
  eng = {
    amp: 0.5, cutoff: 800, release: 0.5, pw: 0.5, gain: 1, pan: 0,
    sAmp: 0.2, sHz: 0,
    level: 0.2, shape: 0, timbre: 0.5, noise: 0, cut: 8, fgain: 0, ampAtk: 0.05, ampDec: 0.1, ampSus: 1, ampRel: 1,
    oscWaveShape: 1, lpFilterCutoff: 1200, lpFilterResonance: 0.1, env2Attack: 0.01, env2Decay: 0.3, env2Sustain: 0.6, env2Release: 0.5,
    mAmp: 0.5, mainOscLevel: 1, subOscLevel: 0, noiseLevel: 0, pulseWidthMod: 0,
  };
  engineName = 'None';
}
function testSine() {
  if (!AC) return;
  if (!sine) {
    const o = AC.createOscillator(), g = gain(0); o.connect(g).connect(A.eng); o.start();
    sine = { o, g };
  }
  sine.o.frequency.setTargetAtTime(eng.sHz || 220, AC.currentTime, 0.01);
  setG(sine.g, eng.sAmp * 0.4);
}
function midiToHz(n) { return 440 * Math.pow(2, (n - 69) / 12); }
function guessFreq(cmd, args) {
  const nums = args.filter(x => typeof x === 'number');
  if (/hz|freq/i.test(cmd)) return nums.find(x => x > 0);
  const f = nums.find(x => x >= 20 && x <= 20000 && !Number.isInteger(x));
  if (f) return f;
  if (/note|midi/i.test(cmd)) { const n = nums.find(x => Number.isInteger(x) && x >= 0 && x <= 127 && x > 12); if (n != null) return midiToHz(n); }
  return nums.find(x => x >= 20 && x <= 20000);
}
function engineNative(cmd, ...args) {
  const n0 = num(args[0]);
  switch (engineName) {
    case 'PolyPerc':
      if (cmd === 'hz') return perc(n0, eng);
      if (['amp', 'cutoff', 'release', 'pw', 'gain', 'pan'].includes(cmd)) { eng[cmd] = n0; return; }
      break;
    case 'TestSine':
      if (cmd === 'hz') { eng.sHz = n0; return testSine(); }
      if (cmd === 'amp') { eng.sAmp = n0; return testSine(); }
      break;
    case 'PolySub': {
      if (cmd === 'start') {
        const id = String(args[0]); if (voices.has(id)) voices.get(id).release();
        const hz = num(args[1]);
        const v = sustainVoice(hz, { wave: eng.shape > 0.5 ? 'sawtooth' : 'pulse', pw: 0.2 + eng.timbre * 0.6, cutoff: hz * Math.max(1, eng.cut), q: 0.7 + eng.fgain * 2,
          amp: Math.min(1, eng.level * 3), a: eng.ampAtk, d: eng.ampDec, s: eng.ampSus, r: eng.ampRel, noise: eng.noise });
        if (v) voices.set(id, v);
        return;
      }
      if (cmd === 'stop') { const v = voices.get(String(args[0])); if (v) { v.release(); voices.delete(String(args[0])); } return; }
      if (cmd === 'stopAll') { for (const v of voices.values()) v.release(); voices.clear(); return; }
      if (cmd in eng) { eng[cmd] = n0; return; }
      return;
    }
    case 'MollyThePoly': {
      if (cmd === 'noteOn') {
        const id = String(args[0]); if (voices.has(id)) voices.get(id).release();
        const shape = ['triangle', 'sawtooth', 'pulse'][Math.round(eng.oscWaveShape)] || 'sawtooth';
        const v = sustainVoice(num(args[1]), { wave: shape, pw: 0.5, cutoff: eng.lpFilterCutoff, q: 0.7 + eng.lpFilterResonance * 8, amp: Math.min(1.5, eng.mAmp * 1.5),
          vel: args[2] == null ? 1 : num(args[2]), a: eng.env2Attack, d: eng.env2Decay, s: eng.env2Sustain, r: eng.env2Release,
          oscLevel: eng.mainOscLevel, sub: eng.subOscLevel, noise: eng.noiseLevel });
        if (v) voices.set(id, v);
        return;
      }
      if (cmd === 'noteOff') { const v = voices.get(String(args[0])); if (v) { v.release(); voices.delete(String(args[0])); } return; }
      if (cmd === 'noteKill') { const v = voices.get(String(args[0])); if (v) { v.kill(); voices.delete(String(args[0])); } return; }
      if (cmd === 'noteOffAll') { for (const v of voices.values()) v.release(); voices.clear(); return; }
      if (cmd === 'noteKillAll') { for (const v of voices.values()) v.kill(); voices.clear(); return; }
      if (cmd === 'amp') { eng.mAmp = n0; return; }
      if (cmd in eng) { eng[cmd] = n0; return; }
      return;
    }
    case 'None': return;
  }
  // fallback: unknown engine or command
  if (/off|stop|release|kill|free/i.test(cmd)) return;
  if (/hz|freq|note|trig|play|start|on$|pluck|strike|bang|perc|gate|hit/i.test(cmd)) {
    const f = guessFreq(cmd, args);
    if (f) { perc(f, { ...eng, release: 0.6, cutoff: 2000 }); return; }
  }
  warnOnce('engine:' + engineName + '.' + cmd, `engine.${cmd} は ${engineName} の簡易版では無視されます`);
}
function engineNameNative(n) {
  resetEngine();
  if (n in ENGINE_INFO) { engineName = n; if (n !== 'PolyPerc' && n !== 'None') log(`# engine ${n}: 簡易シンセで近似しています`, 's'); }
  else { engineName = n; log(`# engine ${n} は SuperCollider 製で未実装です。音名らしいコマンドは代替のパーカッシブ音で鳴らします`, 's'); }
}

/* ============ grid ============ */
const gridCanvas = $('grid'), gctx = gridCanvas.getContext('2d');
const gBuf = new Uint8Array(128), gShown = new Uint8Array(128);
const PAD = tok('--pad', '#26272b'), LED = tok('--led', '#f4b13e');
function drawGrid() {
  const w = gridCanvas.width, h = gridCanvas.height;
  if (!w || !h) return;
  gctx.clearRect(0, 0, w, h);
  const cw = w / 16, ch = h / 8, inset = cw * 0.1, r = cw * 0.16;
  const view = (window.NornsHW && window.NornsHW.preview) ? window.NornsHW.preview(gShown) : gShown;
  for (let y = 0; y < 8; y++) for (let x = 0; x < 16; x++) {
    const px = x * cw + inset, py = y * ch + inset, s = cw - inset * 2, l = view[y * 16 + x];
    gctx.beginPath();
    gctx.roundRect ? gctx.roundRect(px, py, s, s, r) : gctx.rect(px, py, s, s);
    gctx.fillStyle = PAD; gctx.globalAlpha = 1; gctx.shadowBlur = 0; gctx.fill();
    if (l > 0) { gctx.fillStyle = LED; gctx.globalAlpha = 0.12 + (l / 15) * 0.88; gctx.shadowColor = LED; gctx.shadowBlur = l > 6 ? cw * 0.35 * (l / 15) : 0; gctx.fill(); }
  }
  gctx.globalAlpha = 1; gctx.shadowBlur = 0;
}
const lv = l => Math.max(0, Math.min(15, Math.floor(+l || 0)));
const gridFns = {
  __g_led(x, y, l) { x = Math.floor(x) - 1; y = Math.floor(y) - 1; if (x < 0 || x > 15 || y < 0 || y > 7) return; gBuf[y * 16 + x] = lv(l); },
  __g_all(l) { gBuf.fill(lv(l)); },
  __g_refresh() { gShown.set(gBuf); drawGrid(); if (window.NornsHW) window.NornsHW.frame(gShown); },
};
const gridHeld = new Map();
function gridCell(e) {
  const r = gridCanvas.getBoundingClientRect();
  const x = Math.floor((e.clientX - r.left) / r.width * 16) + 1, y = Math.floor((e.clientY - r.top) / r.height * 8) + 1;
  return (x >= 1 && x <= 16 && y >= 1 && y <= 8) ? [x, y] : null;
}
gridCanvas.addEventListener('pointerdown', e => {
  const c = gridCell(e); if (!c) return;
  e.preventDefault();
  try { gridCanvas.setPointerCapture(e.pointerId); } catch (_) {}
  gridHeld.set(e.pointerId, c);
  callLua('__grid_key', c[0], c[1], 1);
});
const gridUp = e => { const c = gridHeld.get(e.pointerId); if (!c) return; gridHeld.delete(e.pointerId); callLua('__grid_key', c[0], c[1], 0); };
gridCanvas.addEventListener('pointerup', gridUp);
gridCanvas.addEventListener('pointercancel', gridUp);

/* ============ arc ============ */
const TAU = Math.PI * 2;
const arcCanvas = $('arc'), actx = arcCanvas.getContext('2d');
const aBuf = new Uint8Array(256), aShown = new Uint8Array(256);
const ALU_HI = tok('--alu-hi', '#3b3e43'), ALU_LO = tok('--alu-lo', '#232529'), GROUND = tok('--ground', '#141517');
function drawArc() {
  const w = arcCanvas.width, h = arcCanvas.height;
  if (!w || !h) return;
  actx.clearRect(0, 0, w, h);
  const cw = w / 4, R = Math.min(cw, h) * 0.4;
  for (let r = 0; r < 4; r++) {
    const cx = cw * (r + 0.5), cy = h / 2;
    actx.globalAlpha = 1; actx.shadowBlur = 0;
    actx.beginPath(); actx.arc(cx, cy, R * 1.17, 0, TAU); actx.fillStyle = GROUND; actx.fill();
    const kg = actx.createRadialGradient(cx - R * 0.2, cy - R * 0.25, R * 0.05, cx, cy, R * 0.66);
    kg.addColorStop(0, ALU_HI); kg.addColorStop(1, ALU_LO);
    actx.beginPath(); actx.arc(cx, cy, R * 0.64, 0, TAU); actx.fillStyle = kg; actx.fill();
    const dot = Math.max(1.2, R * 0.045);
    for (let i = 0; i < 64; i++) {
      const ang = (i + 0.5) / 64 * TAU - Math.PI / 2, x = cx + Math.cos(ang) * R, y = cy + Math.sin(ang) * R, l = aShown[r * 64 + i];
      actx.beginPath(); actx.arc(x, y, dot, 0, TAU);
      actx.globalAlpha = 1; actx.shadowBlur = 0; actx.fillStyle = PAD; actx.fill();
      if (l > 0) { actx.fillStyle = LED; actx.globalAlpha = 0.12 + (l / 15) * 0.88; actx.shadowColor = LED; actx.shadowBlur = l > 6 ? dot * 3 * (l / 15) : 0; actx.fill(); }
    }
  }
  actx.globalAlpha = 1; actx.shadowBlur = 0;
}
const arcFns = {
  __a_led(r, x, l) { r = Math.floor(r) - 1; if (r < 0 || r > 3) return; aBuf[r * 64 + ((((Math.floor(x) - 1) % 64) + 64) % 64)] = lv(l); },
  __a_all(l) { aBuf.fill(lv(l)); },
  __a_segment(r, from, to, l) {
    r = Math.floor(r) - 1; if (r < 0 || r > 3) return;
    from = +from; to = +to; l = lv(l);
    const span = to - from;
    if (!(Math.abs(span) > 1e-9)) return;
    const a = ((from % TAU) + TAU) % TAU;
    const b = a + (Math.abs(span) >= TAU - 1e-9 ? TAU : ((span % TAU) + TAU) % TAU);
    const ov = (s, e) => Math.max(0, Math.min(e, b) - Math.max(s, a));
    const w = TAU / 64;
    for (let i = 0; i < 64; i++) { const s = i * w, frac = Math.min(1, (ov(s, s + w) + ov(s + TAU, s + w + TAU)) / w); if (frac > 0.02) aBuf[r * 64 + i] = Math.round(l * frac); }
  },
  __a_refresh() { aShown.set(aBuf); drawArc(); },
};
const arcDrag = new Map();
function arcHit(e) {
  const rc = arcCanvas.getBoundingClientRect();
  const cw = rc.width / 4, n = Math.max(0, Math.min(3, Math.floor((e.clientX - rc.left) / cw)));
  const cx = rc.left + cw * (n + 0.5), cy = rc.top + rc.height / 2, R = Math.min(cw, rc.height) * 0.4;
  return { n: n + 1, cx, cy, R, dist: Math.hypot(e.clientX - cx, e.clientY - cy), ang: Math.atan2(e.clientY - cy, e.clientX - cx) };
}
arcCanvas.addEventListener('pointerdown', e => {
  const h = arcHit(e);
  e.preventDefault();
  try { arcCanvas.setPointerCapture(e.pointerId); } catch (_) {}
  if (h.dist < h.R * 0.6) { arcDrag.set(e.pointerId, { key: true, n: h.n }); callLua('__arc_key', h.n, 1); }
  else arcDrag.set(e.pointerId, { n: h.n, cx: h.cx, cy: h.cy, ang: h.ang, acc: 0 });
});
arcCanvas.addEventListener('pointermove', e => {
  const st = arcDrag.get(e.pointerId); if (!st || st.key) return;
  const ang = Math.atan2(e.clientY - st.cy, e.clientX - st.cx);
  let da = ang - st.ang;
  if (da > Math.PI) da -= TAU; else if (da < -Math.PI) da += TAU;
  st.ang = ang; st.acc += da / TAU * 1024;
  const d = Math.trunc(st.acc);
  if (d) { st.acc -= d; callLua('__arc_delta', st.n, d); }
});
const arcUp = e => { const st = arcDrag.get(e.pointerId); if (!st) return; arcDrag.delete(e.pointerId); if (st.key) callLua('__arc_key', st.n, 0); };
arcCanvas.addEventListener('pointerup', arcUp);
arcCanvas.addEventListener('pointercancel', arcUp);
arcCanvas.addEventListener('wheel', e => { e.preventDefault(); callLua('__arc_delta', arcHit(e).n, e.deltaY < 0 ? 8 : -8); }, { passive: false });

/* ============ crow panel ============ */
const crowOut = [0, 0, 0, 0];
const crowIn = [0, 0];
let crowDirty = true;
const crowCanvas = $('crow'), cctx = crowCanvas.getContext('2d');
const INK = tok('--ink', '#dfe2dc'), MUTED = tok('--muted', '#8d918a'), LINE = tok('--line', '#2d2f33');
function drawCrow() {
  crowDirty = false;
  const w = crowCanvas.width, h = crowCanvas.height;
  if (!w || !h) return;
  const dpr = w / crowCanvas.getBoundingClientRect().width || 1;
  cctx.clearRect(0, 0, w, h);
  const rowH = h / 4, x0 = w * 0.16, x1 = w * 0.8, zero = x0 + (x1 - x0) * (5 / 15);
  cctx.font = `${11 * dpr}px "IBM Plex Mono", monospace`;
  cctx.textBaseline = 'middle';
  for (let i = 0; i < 4; i++) {
    const y = rowH * (i + 0.5), v = crowOut[i];
    cctx.fillStyle = MUTED; cctx.textAlign = 'left'; cctx.fillText('OUT ' + (i + 1), 0, y);
    cctx.fillStyle = PAD; cctx.fillRect(x0, y - rowH * 0.18, x1 - x0, rowH * 0.36);
    cctx.fillStyle = LINE; cctx.fillRect(zero - dpr / 2, y - rowH * 0.28, dpr, rowH * 0.56);
    const xv = x0 + (x1 - x0) * ((Math.max(-5, Math.min(10, v)) + 5) / 15);
    cctx.fillStyle = LED; cctx.globalAlpha = 0.85;
    cctx.fillRect(Math.min(zero, xv), y - rowH * 0.18, Math.abs(xv - zero), rowH * 0.36);
    cctx.globalAlpha = 1;
    cctx.fillStyle = INK; cctx.textAlign = 'right'; cctx.fillText(v.toFixed(2) + ' V', w, y);
  }
}
function sizeCanvas(c, ratio, draw) {
  const dpr = Math.min(2, window.devicePixelRatio || 1), r = c.getBoundingClientRect();
  if (!r.width) return;
  c.width = Math.max(1, Math.round(r.width * dpr)); c.height = Math.max(1, Math.round(r.width / ratio * dpr));
  draw();
}
let listen = null;
function crowListen(on) {
  initAudio();
  if (on && !listen && AC) {
    const o = AC.createOscillator(); o.type = 'triangle';
    const f = AC.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = 2400;
    const g = gain(0);
    o.connect(f).connect(g).connect(A.crowBus); o.start();
    listen = { o, g };
    updateListen();
  } else if (!on && listen) { try { listen.o.stop(); listen.g.disconnect(); } catch (e) {} listen = null; }
}
function updateListen() {
  if (!listen || !AC) return;
  listen.o.frequency.setTargetAtTime(261.63 * Math.pow(2, Math.max(-5, Math.min(10, crowOut[0]))), AC.currentTime, 0.003);
  listen.g.gain.setTargetAtTime(Math.max(0, Math.min(1, crowOut[1] / 8)) * 0.35, AC.currentTime, 0.004);
}
function crowOutNative(n, v) {
  n = (n | 0) - 1; if (n < 0 || n > 3) return;
  crowOut[n] = +v || 0;
  if (!devUsed.crow && Math.abs(crowOut[n]) > 0.001) usedNative('crow');
  crowDirty = true;
  if (n < 2) updateListen();
}
document.querySelectorAll('.crow-in').forEach(inp => {
  const n = +inp.dataset.in;
  const out = document.querySelector(`.crow-in-val[data-in="${n}"]`);
  const set = v => { crowIn[n - 1] = v; inp.value = v; out.textContent = (+v).toFixed(2) + ' V'; callLua('__crow_input', n, +v); };
  inp.addEventListener('input', () => set(+inp.value));
  const gate = document.querySelector(`.crow-gate[data-in="${n}"]`);
  let prev = 0;
  gate.addEventListener('pointerdown', e => { e.preventDefault(); try { gate.setPointerCapture(e.pointerId); } catch (_) {} prev = crowIn[n - 1]; gate.classList.add('down'); set(5); });
  const up = () => { if (!gate.classList.contains('down')) return; gate.classList.remove('down'); set(prev); };
  gate.addEventListener('pointerup', up); gate.addEventListener('pointercancel', up);
});
$('crowListen').addEventListener('change', e => { resumeAudio(); crowListen(e.target.checked); });

/* ============ device tabs ============ */
const devUsed = { grid: false, arc: false, crow: false };
let devAutoSwitched = false;
function showDev(name) {
  document.querySelectorAll('.devtab').forEach(b => b.setAttribute('aria-selected', b.dataset.dev === name ? 'true' : 'false'));
  document.querySelectorAll('.devpanel').forEach(p => { p.hidden = p.dataset.dev !== name; });
  if (name === 'grid') sizeCanvas(gridCanvas, 2, drawGrid);
  if (name === 'arc') sizeCanvas(arcCanvas, 4, drawArc);
  if (name === 'crow') sizeCanvas(crowCanvas, 2.6, drawCrow);
}
document.querySelectorAll('.devtab').forEach(b => b.addEventListener('click', () => showDev(b.dataset.dev)));
function usedNative(kind) {
  if (devUsed[kind]) return;
  devUsed[kind] = true;
  const t = document.querySelector(`.devtab[data-dev="${kind}"]`);
  if (t) t.classList.add('used');
  if (!devAutoSwitched) { devAutoSwitched = true; showDev(kind); }
}
function resetDevices() {
  for (const k in devUsed) devUsed[k] = false;
  devAutoSwitched = false;
  document.querySelectorAll('.devtab').forEach(t => t.classList.remove('used'));
  gBuf.fill(0); gShown.fill(0); drawGrid(); if (window.NornsHW) window.NornsHW.frame(gShown);
  aBuf.fill(0); aShown.fill(0); drawArc();
  crowOut.fill(0); crowDirty = true; updateListen();
}
new ResizeObserver(() => { sizeCanvas(gridCanvas, 2, drawGrid); sizeCanvas(arcCanvas, 4, drawArc); sizeCanvas(crowCanvas, 2.6, drawCrow); }).observe($('devbox'));

/* ============ audio input source ============ */
let inputNode = null;
function setInputSource(v) {
  initAudio();
  if (!AC) return;
  if (inputNode) { try { inputNode.stop(); inputNode.disconnect(); } catch (e) {} inputNode = null; }
  if (v === 'tone') {
    const o = AC.createOscillator(); o.type = 'sawtooth';
    const f = AC.createBiquadFilter(); f.frequency.value = 1400;
    const g = gain(0); o.connect(f).connect(g).connect(A.adc);
    const t0 = AC.currentTime, notes = [57, 60, 64, 67, 69, 72, 67, 64];
    for (let i = 0; i < 400; i++) {
      const t = t0 + i * 0.25;
      o.frequency.setValueAtTime(midiToHz(notes[i % notes.length]), t);
      g.gain.setValueAtTime(0.25, t); g.gain.exponentialRampToValueAtTime(0.01, t + 0.22);
    }
    o.start(); o.stop(t0 + 100);
    inputNode = o;
  } else if (v) {
    decodeFile(v).then(ab => {
      const s = AC.createBufferSource(); s.buffer = ab; s.loop = true; s.connect(A.adc); s.start();
      inputNode = s;
    }).catch(() => report('音声をデコードできません: ' + v));
  }
}
$('inputSrc').addEventListener('change', e => { resumeAudio(); setInputSource(e.target.value); });
function refreshInputSelect() {
  const sel = $('inputSrc'), cur = sel.value;
  sel.innerHTML = '';
  const add = (v, t) => { const o = document.createElement('option'); o.value = v; o.textContent = t; sel.appendChild(o); };
  add('', 'なし（無音）'); add('tone', 'テストトーン（アルペジオ）');
  for (const p of [...VFS.keys()].filter(k => AUDIO_EXT.test(k)).sort()) add(p, p.replace(DUST, ''));
  sel.value = [...sel.options].some(o => o.value === cur) ? cur : '';
}

/* ============ Lua runtime ============ */
const F = window.fengari;
let lua, lauxlib, lualib, to_luastring;
if (F) ({ lua, lauxlib, lualib, to_luastring } = F);
let L = null, timer = null, t0 = 0, deadline = Infinity, currentPath = '', BOOT = null;
function scriptLabel() { return currentPath ? currentPath.replace(CODE, '').replace(/\.lua$/, '') : '—'; }

function pushVal(Ls, v) {
  if (v && v.bytes instanceof Uint8Array) lua.lua_pushstring(Ls, v.bytes);
  else if (typeof v === 'number') { Number.isInteger(v) && Math.abs(v) < 2147483647 ? lua.lua_pushinteger(Ls, v) : lua.lua_pushnumber(Ls, v); }
  else if (typeof v === 'string') lua.lua_pushstring(Ls, to_luastring(v));
  else if (typeof v === 'boolean') lua.lua_pushboolean(Ls, v);
  else if (Array.isArray(v)) { lua.lua_createtable(Ls, v.length, 0); v.forEach((x, i) => { pushVal(Ls, x); lua.lua_rawseti(Ls, -2, i + 1); }); }
  else if (v && typeof v === 'object') { lua.lua_createtable(Ls, 0, 0); for (const k of Object.keys(v)) { pushVal(Ls, v[k]); lua.lua_setfield(Ls, -2, to_luastring(k)); } }
  else lua.lua_pushnil(Ls);
}
function def(name, fn, raw) {
  lua.lua_pushcfunction(L, Ls => {
    const n = lua.lua_gettop(Ls), args = [];
    for (let i = 1; i <= n; i++) {
      const t = lua.lua_type(Ls, i);
      if (t === lua.LUA_TNUMBER) args.push(lua.lua_tonumber(Ls, i));
      else if (t === lua.LUA_TSTRING) args.push(raw ? lua.lua_tolstring(Ls, i).slice() : lua.lua_tojsstring(Ls, i));
      else if (t === lua.LUA_TBOOLEAN) args.push(lua.lua_toboolean(Ls, i));
      else args.push(null);
    }
    const r = fn(...args);
    if (r === undefined) return 0;
    const rs = Array.isArray(r) && r.multi ? r : [r];
    rs.forEach(v => pushVal(Ls, v));
    return rs.length;
  });
  lua.lua_setglobal(L, to_luastring(name));
}
function errString() { const m = lua.lua_tojsstring(L, -1); lua.lua_pop(L, 1); return m || 'error'; }
function loadChunk(bytes, chunk) {
  deadline = performance.now() + 4000;
  let st = lauxlib.luaL_loadbuffer(L, bytes, bytes.length, to_luastring('=' + chunk));
  if (st !== lua.LUA_OK) { report(errString()); return false; }
  st = lua.lua_pcall(L, 0, 0, 0);
  if (st !== lua.LUA_OK) { report(errString()); return false; }
  return true;
}
let inLua = 0;
function callLua(fname, ...args) {
  if (!L) return;
  inLua++;
  try {
    lua.lua_getglobal(L, to_luastring(fname));
    if (lua.lua_type(L, -1) !== lua.LUA_TFUNCTION) { lua.lua_pop(L, 1); return; }
    args.forEach(a => pushVal(L, a));
    if (inLua === 1) deadline = performance.now() + 1500;
    const st = lua.lua_pcall(L, args.length, 0, 0);
    if (st !== lua.LUA_OK) report(errString());
  } finally { inLua--; }
}

function stop(quiet) {
  if (timer) { clearInterval(timer); timer = null; }
  if (L) {
    callLua('__cleanup');
    try { lua.lua_close(L); } catch (e) {}
    L = null;
  }
  resetEngine();
  scCall('reset', []); scCall('phase_poll', [false]);
  surf.forEach(resetSurface); shown = 0; tgt = 0; present(0);
  resetDevices();
  $('menuBtn').setAttribute('aria-pressed', 'false');
  if (!quiet) { setStatus('', '停止'); log('# script stopped', 's'); }
}

function run(path) {
  if (!F) { report('Lua ランタイム (fengari) を読み込めませんでした。ネットワークを確認して再読み込みしてください。'); return; }
  if (!BOOT) { report('ランタイムの読み込みが終わっていません'); return; }
  if (!vfs.read(path)) { report('スクリプトがありません: ' + path); return; }
  stop(true);
  mixState = { ...MIX_DEFAULT, ...userMix }; applyMix();
  scCall('clear', []);
  warnedSet.clear(); lastErr = '';
  currentPath = path;
  L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);
  try {
    lua.lua_sethook(L, Ls => {
      if (performance.now() > deadline) { deadline = Infinity; lauxlib.luaL_error(Ls, to_luastring('timeout: 処理が長時間止まらないため中断しました（無限ループ？）')); }
    }, lua.LUA_MASKCOUNT, 20000);
  } catch (e) {}
  const natives = {
    __print: s => log(s), __report: s => report(s), __sys: s => warnOnce(s, s),
    __seed: () => Math.floor(Math.random() * 2147483646), __time: () => Date.now() / 1000,
    __fs_exists: p => vfs.exists(String(p)), __fs_list: p => vfs.list(String(p)),
    __fs_remove: p => vfs.remove(String(p)), __fs_scripts: () => vfs.scripts(),
    __load: p => setTimeout(() => { if (p) { openFile(String(p)); run(String(p)); } else stop(); }, 0),
    __sc: scNative, __mix: mixNative, __engine: engineNative, __engine_name: engineNameNative,
    __engine_commands: () => { const o = {}; (ENGINE_INFO[engineName] || '').split(' ').filter(Boolean).forEach(c => { o[c] = { name: c, fmt: 'f' }; }); return o; },
    __engine_commands_list: () => (ENGINE_INFO[engineName] || '').split(' ').filter(Boolean),
    __file_info: p => { const i = fileInfo(String(p)); return i ? multi(i.ch, i.frames, i.sr) : multi(0, 0, 0); },
    __poll_value: name => pollValue(String(name)),
    __crow_out: crowOutNative, __used: usedNative,
    __menu_state: open => { $('menuBtn').setAttribute('aria-pressed', open ? 'true' : 'false'); },
  };
  def('__fs_read', p => { const b = vfs.read(String(p)); return b ? { bytes: b } : null; });
  def('__fs_write', (p, s) => { vfs.write(dec.decode(p), s); }, true);
  for (const [k, f] of Object.entries(natives)) def(k, f);
  for (const [k, f] of Object.entries(screenFns)) def(k, f);
  for (const [k, f] of Object.entries(gridFns)) def(k, f);
  for (const [k, f] of Object.entries(arcFns)) def(k, f);
  if (!loadChunk(BOOT, 'norns')) { L = null; return; }
  log('# script load: ' + scriptLabel(), 's');
  setStatus('run', '実行中 — ' + scriptLabel());
  t0 = performance.now();
  callLua('__start', path);
  timer = setInterval(() => { if (L) callLua('__tick', (performance.now() - t0) / 1000); if (crowDirty) drawCrow(); }, 5);
  try { localStorage.setItem('norns-emu:file', path); } catch (e) {}
}
function rms(an) {
  if (!an) return 0;
  const d = new Float32Array(an.fftSize); an.getFloatTimeDomainData(d);
  let s = 0; for (let i = 0; i < d.length; i++) s += d[i] * d[i];
  return Math.sqrt(s / d.length);
}
function pollValue(name) {
  switch (name) {
    case 'amp_out_l': return rms(A.anaL);
    case 'amp_out_r': return rms(A.anaR);
    case 'amp_in_l': case 'amp_in_r': return rms(A.anaIn);
    case 'cpu_avg': case 'cpu_peak': return 8;
    case 'tape_play_pos': case 'tape_rec_dur': return 0;
    default: return 0;
  }
}

/* ============ controls ============ */
function sendKey(n, z) { callLua('__key', n, z); }
function sendEnc(n, d) {
  const el = document.querySelector(`.enc[data-e="${n}"]`);
  const a = (parseFloat(el.dataset.a || '0') + d * 15) % 360;
  el.dataset.a = a; el.style.setProperty('--rot', a + 'deg');
  callLua('__enc', n, d);
}
document.querySelectorAll('.key').forEach(b => {
  const n = +b.dataset.k;
  let down = false;
  const up = () => { if (!down) return; down = false; b.classList.remove('down'); sendKey(n, 0); };
  b.addEventListener('pointerdown', e => { e.preventDefault(); try { b.setPointerCapture(e.pointerId); } catch (_) {} down = true; b.classList.add('down'); sendKey(n, 1); });
  b.addEventListener('pointerup', up); b.addEventListener('pointercancel', up);
  b.addEventListener('keydown', e => { if ((e.key === ' ' || e.key === 'Enter') && !e.repeat && !down) { e.preventDefault(); down = true; b.classList.add('down'); sendKey(n, 1); } });
  b.addEventListener('keyup', e => { if (e.key === ' ' || e.key === 'Enter') up(); });
});
document.querySelectorAll('.enc').forEach(el => {
  const n = +el.dataset.e;
  let lastY = 0, lastX = 0, acc = 0, active = false;
  el.addEventListener('pointerdown', e => { e.preventDefault(); try { el.setPointerCapture(e.pointerId); } catch (_) {} active = true; lastY = e.clientY; lastX = e.clientX; acc = 0; });
  el.addEventListener('pointermove', e => {
    if (!active) return;
    acc += (lastY - e.clientY) + (e.clientX - lastX); lastY = e.clientY; lastX = e.clientX;
    while (Math.abs(acc) >= 6) { const d = Math.sign(acc); acc -= d * 6; sendEnc(n, d); }
  });
  const end = () => { active = false; };
  el.addEventListener('pointerup', end); el.addEventListener('pointercancel', end);
  el.addEventListener('wheel', e => { e.preventDefault(); sendEnc(n, e.deltaY < 0 ? 1 : -1); }, { passive: false });
  el.addEventListener('keydown', e => {
    if (e.key === 'ArrowUp' || e.key === 'ArrowRight') { e.preventDefault(); sendEnc(n, 1); }
    else if (e.key === 'ArrowDown' || e.key === 'ArrowLeft') { e.preventDefault(); sendEnc(n, -1); }
  });
});
const KEYMAP = { '1': ['k', 1], '2': ['k', 2], '3': ['k', 3], q: ['e', 1, -1], w: ['e', 1, 1], a: ['e', 2, -1], s: ['e', 2, 1], z: ['e', 3, -1], x: ['e', 3, 1] };
const typing = t => t && (t.tagName === 'TEXTAREA' || t.tagName === 'INPUT' || t.tagName === 'SELECT');
window.addEventListener('keydown', e => {
  resumeAudio();
  if (typing(e.target) || e.metaKey || e.ctrlKey || e.altKey) return;
  const m = KEYMAP[e.key.toLowerCase()]; if (!m) return;
  e.preventDefault();
  if (m[0] === 'k') { if (e.repeat) return; document.querySelector(`.key[data-k="${m[1]}"]`).classList.add('down'); sendKey(m[1], 1); }
  else sendEnc(m[1], m[2]);
});
window.addEventListener('keyup', e => {
  if (typing(e.target)) return;
  const m = KEYMAP[e.key.toLowerCase()];
  if (m && m[0] === 'k') { document.querySelector(`.key[data-k="${m[1]}"]`).classList.remove('down'); sendKey(m[1], 0); }
});
window.addEventListener('pointerdown', resumeAudio, true);

/* ============ editor ============ */
const srcEl = $('src'), fileSel = $('file');
let currentFile = '';
const originals = new Map();
function refreshFileSelect() {
  const files = [...VFS.keys()].filter(k => k.startsWith(CODE) && k.endsWith('.lua')).sort();
  fileSel.innerHTML = '';
  const groups = new Map();
  for (const f of files) {
    const proj = f.slice(CODE.length).split('/')[0];
    if (!groups.has(proj)) { const g = document.createElement('optgroup'); g.label = proj; groups.set(proj, g); fileSel.appendChild(g); }
    const o = document.createElement('option'); o.value = f; o.textContent = f.slice(CODE.length);
    groups.get(proj).appendChild(o);
  }
  if (currentFile && files.includes(currentFile)) fileSel.value = currentFile;
  refreshInputSelect();
  $('revert').hidden = !originals.has(currentFile);
}
function openFile(path) {
  if (!vfs.read(path)) return;
  flushSave();
  currentFile = path;
  srcEl.value = vfs.text(path);
  fileSel.value = path;
  $('revert').hidden = !originals.has(path);
  try { localStorage.setItem('norns-emu:open', path); } catch (e) {}
}
let saveT = 0, saveDirty = false;
function flushSave() { if (saveDirty && currentFile) { vfs.write(currentFile, srcEl.value, true); saveDirty = false; } clearTimeout(saveT); }
srcEl.addEventListener('input', () => { saveDirty = true; clearTimeout(saveT); saveT = setTimeout(flushSave, 400); });
srcEl.addEventListener('keydown', e => {
  if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') { e.preventDefault(); resumeAudio(); flushSave(); run(currentFile); return; }
  if (e.key === 'Tab' && !e.shiftKey) { e.preventDefault(); srcEl.setRangeText('  ', srcEl.selectionStart, srcEl.selectionEnd, 'end'); srcEl.dispatchEvent(new Event('input')); }
});
fileSel.addEventListener('change', () => openFile(fileSel.value));
$('run').addEventListener('click', () => { resumeAudio(); flushSave(); run(currentFile); });
$('stop').addEventListener('click', () => stop());
$('revert').addEventListener('click', () => {
  const o = originals.get(currentFile); if (o == null) return;
  vfs.write(currentFile, o); openFile(currentFile);
  log('# ' + currentFile.replace(CODE, '') + ' を元に戻しました', 's');
});
$('newScript').addEventListener('click', () => {
  let i = 1; while (vfs.exists(CODE + 'untitled' + i)) i++;
  const name = 'untitled' + i, p = `${CODE}${name}/${name}.lua`;
  vfs.write(p, `-- ${name}\n\nfunction init()\n  print('hello')\nend\n\nfunction redraw()\n  screen.clear()\n  screen.level(15)\n  screen.move(64, 32)\n  screen.text_center('${name}')\n  screen.update()\nend\n`);
  refreshFileSelect(); openFile(p); showView('editor'); srcEl.focus();
});
$('clr').addEventListener('click', () => { logEl.textContent = ''; });
$('repl').addEventListener('keydown', e => {
  if (e.key !== 'Enter') return;
  const v = e.target.value.trim(); if (!v) return;
  log('>> ' + v, 'r'); e.target.value = '';
  if (!L) { log('# スクリプトが動いていません。先に実行してください', 's'); return; }
  callLua('__repl', v);
});
$('menuBtn').addEventListener('click', () => { resumeAudio(); callLua('__menu_toggle'); });

/* ============ views ============ */
function showView(v) {
  document.querySelectorAll('.viewtab').forEach(b => b.setAttribute('aria-selected', b.dataset.view === v ? 'true' : 'false'));
  document.querySelectorAll('.view').forEach(p => { p.hidden = p.dataset.view !== v; });
  if (v === 'library') ensureLibrary();
}
document.querySelectorAll('.viewtab').forEach(b => b.addEventListener('click', () => showView(b.dataset.view)));

/* ============ library ============ */
let CATALOG = [];
function b64(s) { const bin = atob(s); const u = new Uint8Array(bin.length); for (let i = 0; i < bin.length; i++) u[i] = bin.charCodeAt(i); return u; }

/* ---- fetching straight from GitHub (raw.githubusercontent.com + GitHub API) ---- */
const AUDIO_MAX_FILE = 12e6, AUDIO_MAX_TOTAL = 60e6;
function keepFile(path, size) {
  if (/(^|\/)(\.github|screenshots?)\//i.test(path)) return null;
  if (path.endsWith('.lua')) return size < 1.5e6 ? 'text' : null;
  if (/(^|\/)(readme|license|licence|changelog)[^/]*$/i.test(path)) return null;
  if (/\.(json|txt|csv|pset|data|tab|lua\.txt)$/i.test(path)) return size < 1e6 ? 'text' : null;
  if (/\.png$/i.test(path)) return /(^|\/)(docs?|images?|img)\//i.test(path) ? null : (size < 500e3 ? 'bin' : null);
  if (AUDIO_EXT.test(path)) return size < AUDIO_MAX_FILE ? 'audio' : null;
  return null;
}
function ghRepo(u) {
  const m = String(u || '').match(/github\.com[/:]([^/]+)\/([^/#?\s]+?)(?:\.git)?\/?$/);
  return m ? { owner: m[1], repo: m[2] } : null;
}
async function ghTree(owner, repo, ref) {
  const r = await fetch(`https://api.github.com/repos/${owner}/${repo}/git/trees/${ref}?recursive=1`, { headers: { Accept: 'application/vnd.github+json' } });
  if (r.status === 403 || r.status === 429) {
    const reset = +r.headers.get('x-ratelimit-reset');
    const e = new Error('GitHub API の回数制限（1時間60回）に達しました' + (reset ? `。${new Date(reset * 1000).toLocaleTimeString()} 以降にもう一度押してください` : ''));
    e.code = 'rate'; throw e;
  }
  if (!r.ok) throw new Error(`${owner}/${repo} の一覧を取得できません (${r.status})`);
  const j = await r.json();
  return { sha: j.sha, tree: j.tree || [], truncated: j.truncated };
}
const rawUrl = (o, r, ref, p) => `https://raw.githubusercontent.com/${o}/${r}/${ref}/${p.split('/').map(encodeURIComponent).join('/')}`;
async function rawFetch(o, r, ref, p, kind) {
  const res = await fetch(rawUrl(o, r, ref, p));
  if (!res.ok) throw new Error(p + ' (' + res.status + ')');
  return new Uint8Array(await res.arrayBuffer());
}
function parseGitmodules(txt) {
  const out = [];
  let cur = null;
  for (const line of String(txt).split(/\r?\n/)) {
    if (/^\s*\[submodule/.test(line)) { cur = {}; out.push(cur); continue; }
    const m = line.match(/^\s*(path|url)\s*=\s*(.+?)\s*$/);
    if (m && cur) cur[m[1]] = m[2];
  }
  return out.filter(x => x.path && x.url);
}
async function pool(items, n, fn) {
  let i = 0;
  const workers = Array.from({ length: Math.min(n, items.length) }, async () => { while (i < items.length) { const k = i++; await fn(items[k], k); } });
  await Promise.all(workers);
}
// downloads repo (and its git submodules) into dust/code/<dest>/<prefix>
async function fetchRepo(owner, repo, ref, dest, prefix, progress, depth, stats) {
  const { sha, tree, truncated } = await ghTree(owner, repo, ref);
  if (truncated) log(`# ${owner}/${repo} はファイル数が多いため一部だけ取得します`, 's');
  const blobs = tree.filter(t => t.type === 'blob').map(t => ({ ...t, kind: keepFile(t.path, t.size || 0) })).filter(t => t.kind);
  const audio = blobs.filter(t => t.kind === 'audio');
  let audioTotal = 0;
  const take = blobs.filter(t => {
    if (t.kind !== 'audio') return true;
    if (audioTotal + t.size > AUDIO_MAX_TOTAL) { stats.skippedAudio++; return false; }
    audioTotal += t.size; return true;
  });
  stats.total += take.length;
  await pool(take, 6, async t => {
    const bytes = await rawFetch(owner, repo, sha, t.path);
    vfs.write(CODE + dest + '/' + prefix + t.path, bytes, true);
    stats.done++;
    progress(`取得中 ${stats.done}/${stats.total}`);
  });
  const subs = tree.filter(t => t.type === 'commit');
  if (!subs.length) return;
  const gm = tree.find(t => t.path === '.gitmodules');
  let defs = [];
  if (gm) { try { defs = parseGitmodules(dec.decode(await rawFetch(owner, repo, sha, '.gitmodules'))); } catch (e) {} }
  for (const sm of subs) {
    const d = defs.find(x => x.path === sm.path);
    const gr = d && ghRepo(d.url.replace(/^\.\.\//, `https://github.com/${owner}/`));
    if (!gr || depth >= 2) { stats.missingSubs.push(sm.path); continue; }
    try {
      progress(`サブモジュール ${sm.path}`);
      await fetchRepo(gr.owner, gr.repo, sm.sha, dest, prefix + sm.path + '/', progress, depth + 1, stats);
    } catch (e) {
      if (e.code === 'rate') throw e;
      stats.missingSubs.push(sm.path);
    }
  }
}
async function fetchFromGitHub(c, progress) {
  const gr = ghRepo(c.u);
  if (!gr) { report(c.n + ': GitHub 以外のリポジトリは自動取得できません。ZIP を上の枠に入れてください'); return false; }
  const stats = { total: 0, done: 0, skippedAudio: 0, missingSubs: [] };
  progress('一覧を取得中…');
  await fetchRepo(gr.owner, gr.repo, 'HEAD', c.n, '', progress, 0, stats);
  log(`# ${c.n} を GitHub から取得しました (${stats.done} files)`, 's');
  if (stats.missingSubs.length) log(`# 取得できなかった git submodule: ${stats.missingSubs.join(', ')}`, 's');
  if (stats.skippedAudio) log(`# 大きいため音声ファイル ${stats.skippedAudio} 個は取得していません`, 's');
  for (const k of VFS.keys()) if (k.startsWith(CODE + c.n + '/') && AUDIO_EXT.test(k)) fileInfo(k);
  return true;
}
async function installProject(name, progress, depth = 0) {
  if (vfs.exists(CODE + name)) return true;
  const c = CATALOG.find(x => x.n === name);
  if (!c) { report('カタログに ' + name + ' がありません'); return false; }
  try {
    if (!(await fetchFromGitHub(c, progress))) return false;
  } catch (e) {
    vfs.remove(CODE + name);
    report(name + ' の取得に失敗しました: ' + (e && e.message || e) + (e && e.code === 'rate' ? '' : '（ネットワーク接続を確認してください）'));
    return false;
  }
  for (const r of new Set(c.r || [])) {
    if (depth < 2 && !vfs.exists(CODE + r) && CATALOG.some(x => x.n === r)) {
      log(`# 必要なプロジェクト ${r} も入れます`, 's');
      await installProject(r, progress, depth + 1);
    }
  }
  vfsChanged();
  return true;
}
function ensureLibrary() { renderCatalog(); renderInstalled(); renderAudioList(); }
const catSearch = $('catSearch'), catFilter = $('catFilter');
catSearch.addEventListener('input', () => renderCatalog());
catFilter.addEventListener('change', () => renderCatalog());
function el(tag, cls, text) { const e = document.createElement(tag); if (cls) e.className = cls; if (text != null) e.textContent = text; return e; }
const SUPPORTED_ENGINES = new Set(['PolyPerc', 'TestSine', 'PolySub', 'MollyThePoly', 'None']);
function renderCatalog() {
  const box = $('catalog'); if (!box) return;
  const q = catSearch.value.trim().toLowerCase(), f = catFilter.value;
  let rows = CATALOG.filter(c => {
    if (f === 'ok' && c.s !== 'ok') return false;
    if (f === 'grid' && !c.f.includes('g')) return false;
    if (f === 'arc' && !c.f.includes('a')) return false;
    if (f === 'crow' && !c.f.includes('c')) return false;
    if (f === 'softcut' && !c.f.includes('s')) return false;
    if (f === 'engine' && !(c.e.length === 0 || c.e.every(e => SUPPORTED_ENGINES.has(e)))) return false;
    if (!q) return true;
    return (c.n + ' ' + c.a + ' ' + c.d + ' ' + c.t.join(' ')).toLowerCase().includes(q);
  });
  const rank = c => c.s === 'ok' ? 0 : 1;
  rows.sort((a, b) => (rank(a) - rank(b)) || a.n.localeCompare(b.n));
  $('catCount').textContent = `${rows.length} / ${CATALOG.length} 件`;
  box.innerHTML = '';
  const frag = document.createDocumentFragment();
  for (const c of rows.slice(0, 200)) {
    const li = el('li', 'cat');
    const main = el('div', 'cat-main');
    const h = el('div', 'cat-head');
    h.appendChild(el('span', 'cat-name', c.n));
    h.appendChild(el('span', 'cat-author', c.a));
    main.appendChild(h);
    if (c.d) main.appendChild(el('p', 'cat-desc', c.d));
    const tags = el('div', 'chips');
    const engs = c.e.length ? c.e : [];
    for (const e of engs) tags.appendChild(el('span', 'chip ' + (SUPPORTED_ENGINES.has(e) ? 'ok' : 'warn'), e === 'None' ? 'エンジンなし' : e + (SUPPORTED_ENGINES.has(e) ? '' : ' (代替音)')));
    if (c.f.includes('s')) tags.appendChild(el('span', 'chip', 'softcut'));
    if (c.f.includes('g')) tags.appendChild(el('span', 'chip', 'grid'));
    if (c.f.includes('a')) tags.appendChild(el('span', 'chip', 'arc'));
    if (c.f.includes('c')) tags.appendChild(el('span', 'chip', 'crow'));
    if (c.f.includes('m')) tags.appendChild(el('span', 'chip warn', 'midi (未対応)'));
    for (const r of (c.r || [])) tags.appendChild(el('span', 'chip warn', '要: ' + r));
    main.appendChild(tags);
    li.appendChild(main);
    if (c.s === 'ok') tags.appendChild(el('span', 'chip ok', '起動確認済'));
    const act = el('div', 'cat-act');
    const installed = vfs.exists(CODE + c.n);
    const label = installed ? '実行' : 'インストール';
    const btn = el('button', installed ? '' : 'primary', label);
    const prog = el('span', 'cat-author');
    btn.addEventListener('click', async () => {
      resumeAudio();
      if (!vfs.exists(CODE + c.n)) {
        btn.disabled = true; btn.textContent = '…';
        const ok = await installProject(c.n, t => { prog.textContent = t; });
        btn.disabled = false; prog.textContent = '';
        if (!ok) { btn.textContent = label; return; }
      }
      const main = mainScriptOf(c.n);
      if (main) { openFile(main); run(main); } else report(c.n + ' に起動できる .lua が見つかりません');
      renderCatalog(); renderInstalled();
    });
    act.appendChild(btn);
    if (c.u) { const gh = el('a', 'btn', 'GitHub'); gh.href = c.u; gh.target = '_blank'; gh.rel = 'noopener'; act.appendChild(gh); }
    main.appendChild(prog);
    li.appendChild(act);
    frag.appendChild(li);
  }
  box.appendChild(frag);
  if (rows.length > 200) box.appendChild(el('li', 'cat-more', `ほか ${rows.length - 200} 件。検索で絞り込めます。`));
}
function mainScriptOf(proj) {
  const d = CODE + proj + '/';
  if (vfs.read(d + proj + '.lua')) return d + proj + '.lua';
  const tops = vfs.list(d).filter(n => n.endsWith('.lua'));
  for (const t of tops) { const s = vfs.text(d + t) || ''; if (/function\s+init\s*\(/.test(s)) return d + t; }
  return tops.length ? d + tops[0] : null;
}
function renderInstalled() {
  const box = $('installed'); if (!box || $('libraryView').hidden) return;
  box.innerHTML = '';
  const projs = vfs.projects();
  if (!projs.length) box.appendChild(el('li', 'cat-more', 'まだありません'));
  for (const p of projs) {
    const li = el('li', 'inst');
    const files = [...VFS.keys()].filter(k => k.startsWith(CODE + p + '/')).length;
    li.appendChild(el('span', 'cat-name', p));
    li.appendChild(el('span', 'cat-author', files + ' files'));
    const sp = el('span', 'spacer'); li.appendChild(sp);
    const upd = el('button', '', '更新');
    upd.title = 'GitHub から最新版を取り直します（編集した内容は消えます）';
    upd.addEventListener('click', async () => {
      if (!CATALOG.some(x => x.n === p)) { report(p + ' はカタログにないため更新できません'); return; }
      upd.disabled = true; upd.textContent = '…';
      if (currentPath.startsWith(CODE + p + '/')) stop(true);
      const backup = [...VFS.entries()].filter(([k]) => k.startsWith(CODE + p + '/'));
      vfs.remove(CODE + p);
      const ok = await installProject(p, t => { upd.textContent = t; });
      if (!ok) { for (const [k, v] of backup) vfs.write(k, v, true); vfsChanged(); }
      upd.disabled = false; upd.textContent = '更新';
    });
    li.appendChild(upd);
    const runB = el('button', '', '実行');
    runB.addEventListener('click', () => { resumeAudio(); const m = mainScriptOf(p); if (m) { openFile(m); run(m); } else report(p + ' に .lua がありません'); });
    const del = el('button', 'danger', '削除');
    let armed = false;
    del.addEventListener('click', () => {
      if (!armed) { armed = true; del.textContent = '本当に削除'; setTimeout(() => { armed = false; del.textContent = '削除'; }, 3000); return; }
      if (currentPath.startsWith(CODE + p + '/')) stop(true);
      vfs.remove(CODE + p);
      for (const k of [...originals.keys()]) if (k.startsWith(CODE + p + '/')) originals.delete(k);
      log(`# ${p} を削除しました`, 's');
      if (currentFile.startsWith(CODE + p + '/')) { const s = vfs.scripts()[0]; if (s) openFile(CODE + s + '.lua'); }
    });
    li.appendChild(runB); li.appendChild(del);
    box.appendChild(li);
  }
}
function renderAudioList() {
  const box = $('audioFiles'); if (!box || $('libraryView').hidden) return;
  box.innerHTML = '';
  const files = [...VFS.keys()].filter(k => AUDIO_EXT.test(k) || /\.png$/i.test(k)).filter(k => !k.startsWith(CODE)).sort();
  if (!files.length) box.appendChild(el('li', 'cat-more', 'dust/audio はまだ空です'));
  for (const f of files) {
    const li = el('li', 'inst');
    li.appendChild(el('span', 'cat-name', f.replace(DUST, '')));
    const info = fileInfo(f);
    li.appendChild(el('span', 'cat-author', info ? `${info.ch}ch · ${(info.frames / info.sr).toFixed(1)}s` : ''));
    li.appendChild(el('span', 'spacer'));
    const del = el('button', 'danger', '削除');
    del.addEventListener('click', () => vfs.remove(f));
    li.appendChild(del);
    box.appendChild(li);
  }
}
function catalogNameForRepo(repo) {
  const r = repo.toLowerCase();
  const hit = CATALOG.find(c => c.u && c.u.replace(/\/$/, '').split('/').pop().toLowerCase() === r);
  return hit ? hit.n : null;
}
async function importFiles(list) {
  for (const file of list) {
    const name = file.name;
    try {
      if (/\.zip$/i.test(name)) await importZip(file);
      else if (/\.lua$/i.test(name)) {
        const base = name.replace(/\.lua$/i, '').replace(/[^\w.-]+/g, '_');
        const p = `${CODE}${base}/${base}.lua`;
        vfs.write(p, new Uint8Array(await file.arrayBuffer()));
        log(`# ${name} を dust/code/${base}/ に入れました`, 's');
        openFile(p);
      } else if (AUDIO_EXT.test(name)) {
        const p = DUST + 'audio/' + name.replace(/[^\w.\- ]+/g, '_');
        vfs.write(p, new Uint8Array(await file.arrayBuffer()));
        fileInfo(p);
        log(`# ${name} を dust/audio/ に入れました`, 's');
      } else if (/\.png$/i.test(name)) {
        const p = DUST + 'data/images/' + name;
        vfs.write(p, new Uint8Array(await file.arrayBuffer()));
        log(`# ${name} を dust/data/images/ に入れました`, 's');
      } else log('# 未対応のファイル形式です: ' + name, 's');
    } catch (e) { report('読み込みに失敗しました: ' + name + ' (' + (e.message || e) + ')'); }
  }
  vfsChanged();
}
async function importZip(file) {
  if (!window.JSZip) { report('ZIP を開くライブラリを読み込めませんでした'); return; }
  const zip = await JSZip.loadAsync(file);
  const entries = Object.values(zip.files).filter(f => !f.dir && !/(^|\/)(\.git|__MACOSX)\//.test(f.name) && !/\.DS_Store$/.test(f.name));
  if (!entries.length) { report('ZIP が空です'); return; }
  const roots = new Set(entries.map(e => e.name.split('/')[0]));
  let strip = '', repo = file.name.replace(/\.zip$/i, '');
  if (roots.size === 1 && entries.every(e => e.name.includes('/'))) { strip = [...roots][0] + '/'; repo = [...roots][0]; }
  repo = repo.replace(/-(main|master|HEAD|[0-9a-f]{7,40})$/i, '').replace(/ \(\d+\)$/, '');
  let proj = catalogNameForRepo(repo) || repo;
  proj = proj.replace(/[^\w.\-]+/g, '_');
  // a zip that is a dust/code bundle (contains code/<proj>/...) keeps its layout
  let total = 0, count = 0;
  for (const e of entries) {
    let rel = e.name.slice(strip.length);
    if (!rel) continue;
    const data = await e.async('uint8array');
    total += data.length;
    if (data.length > 40e6) { log('# 大きすぎるため除外: ' + rel, 's'); continue; }
    vfs.write(CODE + proj + '/' + rel, data, true);
    count++;
  }
  vfsChanged();
  log(`# ${file.name} → dust/code/${proj}/ (${count} files, ${(total / 1e6).toFixed(1)} MB)`, 's');
  const main = mainScriptOf(proj);
  if (main) { openFile(main); log('# ' + main.replace(CODE, '') + ' を開きました。▶ 実行 で動きます', 's'); }
}
const drop = $('drop'), picker = $('picker');
drop.addEventListener('click', () => picker.click());
drop.addEventListener('keydown', e => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); picker.click(); } });
picker.addEventListener('change', () => { importFiles([...picker.files]); picker.value = ''; });
['dragenter', 'dragover'].forEach(t => drop.addEventListener(t, e => { e.preventDefault(); drop.classList.add('over'); }));
['dragleave', 'drop'].forEach(t => drop.addEventListener(t, e => { e.preventDefault(); drop.classList.remove('over'); }));
drop.addEventListener('drop', e => { if (e.dataTransfer && e.dataTransfer.files.length) importFiles([...e.dataTransfer.files]); });
window.addEventListener('dragover', e => e.preventDefault());
window.addEventListener('drop', e => { e.preventDefault(); if (e.target.closest && e.target.closest('#drop')) return; if (e.dataTransfer && e.dataTransfer.files.length) { showView('library'); importFiles([...e.dataTransfer.files]); } });

/* ============ hooks for hardware controllers (hwgrid.js) ============ */
window.NornsEmu = {
  gridKey(x, y, z) { callLua('__grid_key', x, y, z); },
  redrawGrid() { drawGrid(); },
  frame() { return gShown; },
  log: (m) => log('# ' + m, 's'),
  error: (m) => report(m),
  resumeAudio: () => resumeAudio(),
};

/* ============ boot ============ */
async function fetchBytes(p) { const r = await fetch(p); if (!r.ok) throw new Error(p + ' ' + r.status); return new Uint8Array(await r.arrayBuffer()); }
async function boot() {
  surf.forEach(resetSurface); present(0);
  db = await idbOpen();
  await idbLoadAll();
  try {
    const [boot, ...libs] = await Promise.all([fetchBytes(BASE + 'lua/boot.lua'), ...LUA_LIBS.map(n => fetchBytes(BASE + 'lua/lib/' + n + '.lua'))]);
    BOOT = boot;
    LUA_LIBS.forEach((n, i) => VFS.set('/home/we/norns/lua/lib/' + n + '.lua', libs[i]));
  } catch (e) { report('ランタイムを読み込めませんでした: ' + e.message); }
  const ex = window.NORNS_EXAMPLES || [];
  for (const e of ex) {
    const p = `${CODE}${e.name}/${e.name}.lua`;
    originals.set(p, e.code);
    if (!VFS.has(p) && !(e.name === 'blank' && VFS.size > 40)) vfs.write(p, e.code, true);
  }
  fetch(BASE + 'catalog.json').then(r => r.json()).then(j => { CATALOG = j; renderCatalog(); }).catch(() => {});
  initAudio();
  for (const k of VFS.keys()) if (AUDIO_EXT.test(k)) fileInfo(k);
  refreshFileSelect();
  let start = null;
  try { start = localStorage.getItem('norns-emu:file'); } catch (e) {}
  if (!start || !VFS.has(start)) start = `${CODE}step/step.lua`;
  if (!VFS.has(start)) { const s = vfs.scripts()[0]; start = s ? CODE + s + '.lua' : null; }
  showDev('grid');
  if (start) {
    openFile(start);
    const fontReady = document.fonts && document.fonts.load ? document.fonts.load('8px Silkscreen') : Promise.resolve();
    await Promise.race([fontReady, new Promise(r => setTimeout(r, 1500))]);
    log('norns web emulator — matron ready', 's');
    run(start);
  }
}
boot();
})();
