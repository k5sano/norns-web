/* USB monome grid over Web Serial (Chrome / Edge).
   Protocols follow monome/libmonome: mext (2011+), series (2007-2010), 40h. */
(() => {
'use strict';
const $ = id => document.getElementById(id);
const KEY = 'norns-emu:hwgrid';
const DEFAULTS = { proto: 'auto', size: 'auto', mode: '16', t1: 4, t2: 8, t3: 12, mono: 8, out: [0, 5, 10, 15], bright: 15, rot: 0, baud: 115200, mirror: true };
let cfg = { ...DEFAULTS };
try { Object.assign(cfg, JSON.parse(localStorage.getItem(KEY) || '{}')); } catch (e) {}
const save = () => { try { localStorage.setItem(KEY, JSON.stringify(cfg)); } catch (e) {} };

const S = { port: null, reader: null, writer: null, proto: null, cols: 16, rows: 8, sent: null, pending: false, test: false, lastFrame: new Uint8Array(128), closing: false };
const emu = () => window.NornsEmu;

/* ---------- level mapping ---------- */
function stepOf(l) {
  if (cfg.mode === '2') return l >= cfg.mono ? 1 : 0;
  if (cfg.mode === '4') return l >= cfg.t3 ? 3 : l >= cfg.t2 ? 2 : l >= cfg.t1 ? 1 : 0;
  return l;
}
function outLevel(l) {
  const s = stepOf(l);
  if (cfg.mode === '2') return s ? 15 : 0;
  if (cfg.mode === '4') return cfg.out[s];
  return s;
}
// what the on-screen grid shows when "mirror" is on
function previewLevel(l) {
  const s = stepOf(l);
  if (cfg.mode === '2') return s ? 15 : 0;
  if (cfg.mode === '4') return [0, 5, 10, 15][s];
  return l;
}

/* ---------- serial io ---------- */
async function write(bytes) {
  if (!S.writer) return;
  try { await S.writer.write(bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes)); }
  catch (e) { disconnect(T('hw.err.send', { e: e.message || e })); }
}
function rot(x, y) {
  if (cfg.rot === 180) return [S.cols - 1 - x, S.rows - 1 - y];
  return [x, y];
}
function unrot(x, y) { return rot(x, y); }

/* build the hardware frame (cols x rows, physical coords) from the emulator's 16x8 frame */
function hwFrame(src) {
  const f = new Uint8Array(S.cols * S.rows);
  for (let y = 0; y < 8; y++) for (let x = 0; x < 16; x++) {
    const [px, py] = rot(x, y);
    if (px < 0 || py < 0 || px >= S.cols || py >= S.rows) continue;
    f[py * S.cols + px] = S.test ? testLevel(x) : outLevel(src[y * 16 + x]);
  }
  return f;
}
function testLevel(x) { return outLevel(x); }

let flushTimer = 0, lastFlush = 0;
function schedule() {
  if (!S.writer || S.pending || S.proto === 'probe') return;
  const wait = Math.max(0, 1000 / 60 - (performance.now() - lastFlush));
  S.pending = true;
  flushTimer = setTimeout(flush, wait);
}
async function flush() {
  S.pending = false;
  lastFlush = performance.now();
  if (!S.writer || S.proto === 'probe') return;
  const f = hwFrame(S.lastFrame);
  const prev = S.sent;
  S.sent = f;
  const msgs = [];
  if (S.proto === 'mext') {
    for (let qy = 0; qy < S.rows; qy += 8) for (let qx = 0; qx < S.cols; qx += 8) {
      let changed = !prev;
      for (let y = 0; y < 8 && !changed; y++) for (let x = 0; x < 8; x++) { const i = (qy + y) * S.cols + qx + x; if (prev[i] !== f[i]) { changed = true; break; } }
      if (!changed) continue;
      if (cfg.mode === '2') {
        const m = [0x14, qx, qy];
        for (let y = 0; y < 8; y++) { let b = 0; for (let x = 0; x < 8; x++) if (f[(qy + y) * S.cols + qx + x]) b |= 1 << x; m.push(b); }
        msgs.push(...m);
      } else {
        const m = [0x1A, qx, qy];
        for (let i = 0; i < 64; i += 2) {
          const a = f[(qy + (i >> 3)) * S.cols + qx + (i & 7)], b = f[(qy + ((i + 1) >> 3)) * S.cols + qx + ((i + 1) & 7)];
          m.push(((a & 15) << 4) | (b & 15));
        }
        msgs.push(...m);
      }
    }
  } else {
    for (let y = 0; y < S.rows; y++) {
      let changed = !prev;
      for (let x = 0; x < S.cols && !changed; x++) if (prev[y * S.cols + x] !== f[y * S.cols + x]) changed = true;
      if (!changed) continue;
      let lo = 0, hi = 0;
      for (let x = 0; x < S.cols; x++) if (f[y * S.cols + x] > 7) { if (x < 8) lo |= 1 << x; else hi |= 1 << (x - 8); }
      if (S.proto === '40h') msgs.push(0x70 | (y & 7), lo);
      else if (S.cols > 8) msgs.push(0x60 | (y & 15), lo, hi);
      else msgs.push(0x40 | (y & 15), lo);
    }
  }
  if (msgs.length) await write(msgs);
}
async function setIntensity() {
  const i = Math.max(0, Math.min(15, cfg.bright | 0));
  if (S.proto === 'mext') await write([0x17, i]);
  else if (S.proto === '40h') await write([0x30, i]);
  else if (S.proto === 'series') await write([0xA0 | i]);
}

/* ---------- input parsing ---------- */
let rx = [];
const MEXT_IN = { 0x00: 2, 0x01: 32, 0x02: 3, 0x03: 2, 0x04: 2, 0x0F: 8, 0x20: 2, 0x21: 2, 0x50: 2, 0x51: 1, 0x52: 1, 0x80: 1, 0x81: 7 };
let mextSeen = null;
function key(hx, hy, z) {
  const [x, y] = unrot(hx, hy);
  if (x < 0 || x > 15 || y < 0 || y > 7) return;
  emu().gridKey(x + 1, y + 1, z);
}
function parse() {
  while (rx.length) {
    const h = rx[0];
    if (S.proto === 'mext' || S.proto === 'probe') {
      const n = MEXT_IN[h];
      if (n === undefined) { rx.shift(); continue; }
      if (rx.length < 1 + n) return;
      const p = rx.slice(1, 1 + n); rx = rx.slice(1 + n);
      if (mextSeen) mextSeen(h, p);
      if (h === 0x21 || h === 0x20) key(p[0], p[1], h === 0x21 ? 1 : 0);
      else if (h === 0x03 && cfg.size === 'auto') { S.cols = p[0] || 16; S.rows = p[1] || 8; S.sent = null; updateStatus(); schedule(); }
    } else if (S.proto === 'series') {
      if (rx.length < 2) return;
      const [a, b] = rx.splice(0, 2);
      if (a === 0x00 || a === 0x10) key(b >> 4, b & 15, a === 0x00 ? 1 : 0);
    } else if (S.proto === '40h') {
      if (rx.length < 2) return;
      const [a, b] = rx.splice(0, 2);
      if (a === 0x01 || a === 0x00) key(b >> 4, b & 15, a === 0x01 ? 1 : 0);
    } else { rx = []; }
  }
}
async function readLoop() {
  while (S.port && S.port.readable && !S.closing) {
    S.reader = S.port.readable.getReader();
    try {
      for (;;) {
        const { value, done } = await S.reader.read();
        if (done) break;
        if (value) { for (const b of value) rx.push(b); parse(); }
      }
    } catch (e) { if (!S.closing) disconnect(T('hw.err.lost')); }
    finally { try { S.reader.releaseLock(); } catch (e) {} }
  }
}

/* ---------- connect / probe ---------- */
function probeMext() {
  return new Promise(res => {
    let got = false;
    mextSeen = (h, p) => {
      if (h === 0x00 || h === 0x03 || h === 0x01) {
        if (!got) { got = true; setTimeout(() => { mextSeen = null; res(true); }, 120); }
      }
    };
    write([0x00]).then(() => write([0x05])).then(() => write([0x01]));
    setTimeout(() => { if (!got) { mextSeen = null; res(false); } }, 600);
  });
}
function applySize() {
  if (cfg.size === '64') { S.cols = 8; S.rows = 8; }
  else if (cfg.size === '128') { S.cols = 16; S.rows = 8; }
  else if (cfg.size === '256') { S.cols = 16; S.rows = 16; }
  if (S.proto === '40h') { S.cols = 8; S.rows = 8; }
}
async function connect() {
  if (!('serial' in navigator)) { emu().error(T('hw.err.browser')); return; }
  emu().resumeAudio();
  let port;
  try { port = await navigator.serial.requestPort({ filters: [{ usbVendorId: 0x0403 }] }); }
  catch (e) {
    try { port = await navigator.serial.requestPort(); } catch (e2) { return; }
  }
  await open(port);
}
async function open(port) {
  await disconnect();
  S.closing = false;
  try { await port.open({ baudRate: +cfg.baud || 115200, dataBits: 8, stopBits: 1, parity: 'none', bufferSize: 4096 }); }
  catch (e) { emu().error(T('hw.err.open', { e: e.message || e })); return; }
  S.port = port;
  S.writer = port.writable.getWriter();
  S.sent = null; rx = [];
  const info = port.getInfo ? port.getInfo() : {};
  S.proto = cfg.proto === 'auto' ? 'probe' : cfg.proto;
  readLoop();
  if (S.proto === 'probe') {
    S.cols = 16; S.rows = 8;
    const isMext = await probeMext();
    S.proto = isMext ? 'mext' : 'series';
  }
  applySize();
  updateStatus();
  emu().log(T('hw.log.connected', { p: protoLabel(), c: S.cols, r: S.rows, pid: info.usbProductId ? ', pid ' + info.usbProductId.toString(16) : '' }));
  await setIntensity();
  S.lastFrame = new Uint8Array(emu().frame());
  schedule();
}
async function disconnect(msg) {
  const port = S.port;
  if (!port) return;
  S.closing = true;
  clearTimeout(flushTimer); S.pending = false;
  try {
    if (S.writer) {
      if (S.proto === 'mext') await S.writer.write(new Uint8Array([0x12]));
      else if (S.proto === 'series') await S.writer.write(new Uint8Array([0x90]));
      else if (S.proto === '40h') { const z = []; for (let y = 0; y < 8; y++) z.push(0x70 | y, 0); await S.writer.write(new Uint8Array(z)); }
    }
  } catch (e) {}
  try { if (S.reader) await S.reader.cancel(); } catch (e) {}
  try { if (S.writer) S.writer.releaseLock(); } catch (e) {}
  try { await port.close(); } catch (e) {}
  S.port = null; S.writer = null; S.reader = null; S.proto = null; S.sent = null;
  updateStatus();
  if (msg) emu().error(msg);
}
if ('serial' in navigator) navigator.serial.addEventListener('disconnect', e => { if (e.target === S.port) disconnect(T('hw.err.removed')); });

/* ---------- UI ---------- */
const protoLabel = () => ({ mext: T('hw.proto.mext'), series: T('hw.proto.series.short'), '40h': '40h' })[S.proto] || '';
function updateStatus() {
  const st = $('hwStatus'), btn = $('hwConnect');
  if (!st) return;
  if (S.port) { st.textContent = T('hw.connected', { p: protoLabel(), c: S.cols, r: S.rows }); st.className = 'hw-status on'; btn.textContent = T('hw.disconnect'); }
  else { st.textContent = T('serial' in navigator ? 'hw.idle' : 'hw.unsupported'); st.className = 'hw-status'; btn.textContent = T('hw.connect'); }
  btn.disabled = !('serial' in navigator);
}
function renderStrip() {
  const strip = $('hwStrip'); if (!strip) return;
  strip.innerHTML = '';
  for (let l = 0; l < 16; l++) {
    const c = document.createElement('div');
    c.className = 'hw-cell';
    const s = stepOf(l);
    const p = previewLevel(l);
    c.style.setProperty('--a', String(p === 0 ? 0 : 0.15 + (p / 15) * 0.85));
    c.title = cfg.mode === '16' ? `level ${l}` : `level ${l} → ${cfg.mode === '2' ? T(s ? 'hw.cell.on' : 'hw.cell.off') : T('hw.cell.step', { n: s })}`;
    const n = document.createElement('span'); n.textContent = l;
    const m = document.createElement('b'); m.textContent = cfg.mode === '16' ? '' : (cfg.mode === '2' ? (s ? '●' : '·') : String(s));
    c.appendChild(n); c.appendChild(m);
    strip.appendChild(c);
  }
}
function syncInputs() {
  const set = (id, v) => { const e = $(id); if (e) e.value = v; };
  set('hwProto', cfg.proto); set('hwSize', cfg.size); set('hwMode', cfg.mode);
  set('hwT1', cfg.t1); set('hwT2', cfg.t2); set('hwT3', cfg.t3); set('hwMono', cfg.mono);
  set('hwO1', cfg.out[1]); set('hwO2', cfg.out[2]); set('hwO3', cfg.out[3]);
  set('hwBright', cfg.bright); set('hwRot', cfg.rot); set('hwBaud', cfg.baud);
  const mir = $('hwMirror'); if (mir) mir.checked = !!cfg.mirror;
  const lbl = (id, v) => { const e = $(id); if (e) e.textContent = v; };
  lbl('hwT1v', cfg.t1); lbl('hwT2v', cfg.t2); lbl('hwT3v', cfg.t3); lbl('hwMonov', cfg.mono);
  lbl('hwO1v', cfg.out[1]); lbl('hwO2v', cfg.out[2]); lbl('hwO3v', cfg.out[3]); lbl('hwBrightv', cfg.bright);
  document.querySelectorAll('.hw-4').forEach(e => { e.hidden = cfg.mode !== '4'; });
  document.querySelectorAll('.hw-2').forEach(e => { e.hidden = cfg.mode !== '2'; });
  renderStrip();
}
function changed(resend) {
  save(); syncInputs();
  if (resend) { S.sent = null; schedule(); }
  emu().redrawGrid();
}
function bind() {
  $('hwConnect').addEventListener('click', () => S.port ? disconnect() : connect());
  const num = (id, fn) => $(id).addEventListener('input', e => fn(+e.target.value));
  $('hwProto').addEventListener('change', e => { cfg.proto = e.target.value; changed(false); if (S.port) open(S.port); });
  $('hwSize').addEventListener('change', e => { cfg.size = e.target.value; applySize(); updateStatus(); changed(true); });
  $('hwBaud').addEventListener('change', e => { cfg.baud = +e.target.value; changed(false); if (S.port) open(S.port); });
  $('hwMode').addEventListener('change', e => { cfg.mode = e.target.value; changed(true); });
  num('hwT1', v => { cfg.t1 = Math.min(v, cfg.t2); changed(true); });
  num('hwT2', v => { cfg.t2 = Math.max(cfg.t1, Math.min(v, cfg.t3)); changed(true); });
  num('hwT3', v => { cfg.t3 = Math.max(v, cfg.t2); changed(true); });
  num('hwMono', v => { cfg.mono = v; changed(true); });
  num('hwO1', v => { cfg.out[1] = v; changed(true); });
  num('hwO2', v => { cfg.out[2] = v; changed(true); });
  num('hwO3', v => { cfg.out[3] = v; changed(true); });
  num('hwBright', v => { cfg.bright = v; save(); syncInputs(); setIntensity(); });
  $('hwRot').addEventListener('change', e => { cfg.rot = +e.target.value; changed(true); });
  $('hwMirror').addEventListener('change', e => { cfg.mirror = e.target.checked; changed(false); });
  const test = $('hwTest');
  test.addEventListener('pointerdown', () => { S.test = true; S.sent = null; schedule(); test.classList.add('down'); });
  const end = () => { if (!S.test) return; S.test = false; S.sent = null; schedule(); test.classList.remove('down'); };
  test.addEventListener('pointerup', end); test.addEventListener('pointerleave', end); test.addEventListener('pointercancel', end);
  $('hwReset').addEventListener('click', () => { cfg = { ...DEFAULTS, out: [...DEFAULTS.out] }; changed(true); setIntensity(); });
  syncInputs(); updateStatus();
  if (window.I18N) window.I18N.onChange(() => { updateStatus(); renderStrip(); });
  // reconnect to a port the viewer already granted
  if ('serial' in navigator && navigator.serial.getPorts) navigator.serial.getPorts().then(ps => { if (ps.length === 1) $('hwConnect').title = T('hw.prev'); });
}

window.NornsHW = {
  frame(f) { S.lastFrame = new Uint8Array(f); schedule(); },
  preview(f) {
    if (!cfg.mirror || cfg.mode === '16') return f;
    const out = new Uint8Array(f.length);
    for (let i = 0; i < f.length; i++) out[i] = previewLevel(f[i]);
    return out;
  },
};
if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', bind); else bind();
})();
