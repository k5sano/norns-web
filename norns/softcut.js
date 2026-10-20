/* softcut DSP core for the norns web emulator.
   Loaded both as an AudioWorklet module and as a plain script (ScriptProcessor fallback). */
(function (G) {
  'use strict';
  const NV = 6;
  const BUF_BITS = 22;
  const N = 1 << BUF_BITS;           // frames per buffer (~87 s at 48 kHz)
  const MASK = N - 1;

  function newVoice(i, sr) {
    return {
      i, enabled: 0, buf: i % 2, play: 0, rec: 0, loop: 1,
      ls: 0, le: sr, fade: 0.005,
      rate: 1, rateCur: 1, rateSlew: 0,
      level: 1, levelCur: 1, levelSlew: 0,
      pan: 0, panCur: 0, panSlew: 0,
      recLevel: 0, preLevel: 0, recCur: 0, preCur: 0, recpreSlew: 0,
      inL: 0, inR: 0, cut: new Float32Array(NV),
      heads: [{ pos: 0, f: 1, st: 2 }, { pos: 0, f: 0, st: 0 }], active: 0,
      fc: 12000, rq: 2, lp: 0, hp: 0, bp: 0, br: 0, dry: 1,
      ic1: 0, ic2: 0, fa1: 0, fa2: 0, fa3: 0, fk: 0, fdirty: true,
      quant: 0, phaseOff: 0, lastQ: NaN,
    };
  }

  class SoftcutCore {
    constructor(sr) {
      this.sr = sr;
      this.bufs = [new Float32Array(N), new Float32Array(N)];
      this.prev = new Float32Array(NV);
      this.phaseOn = false;
      this.events = [];
      this.reset();
    }
    reset() {
      this.v = [];
      for (let i = 0; i < NV; i++) this.v.push(newVoice(i, this.sr));
      this.prev.fill(0);
      return true;
    }
    slewCoef(t) { return t > 0 ? Math.exp(-1 / (t * this.sr)) : 0; }
    clampFrame(s) { return Math.max(0, s * this.sr); }

    set(vi, key, x) {
      const v = this.v[vi]; if (!v) return;
      const sr = this.sr;
      switch (key) {
        case 'enable': v.enabled = x ? 1 : 0; break;
        case 'buffer': v.buf = (x | 0) === 2 ? 1 : 0; break;
        case 'level': v.level = +x; if (!v.levelSlew) v.levelCur = v.level; break;
        case 'pan': v.pan = Math.max(-1, Math.min(1, +x)); if (!v.panSlew) v.panCur = v.pan; break;
        case 'rate': v.rate = +x; if (!v.rateSlew) v.rateCur = v.rate; break;
        case 'play': v.play = x ? 1 : 0; break;
        case 'rec': v.rec = x ? 1 : 0; break;
        case 'rec_level': v.recLevel = +x; if (!v.recpreSlew) v.recCur = v.recLevel; break;
        case 'pre_level': v.preLevel = +x; if (!v.recpreSlew) v.preCur = v.preLevel; break;
        case 'loop': v.loop = x ? 1 : 0; break;
        case 'loop_start': v.ls = this.clampFrame(+x); if (v.le <= v.ls) v.le = v.ls + 2; break;
        case 'loop_end': v.le = Math.max(v.ls + 2, this.clampFrame(+x)); break;
        case 'fade_time': v.fade = Math.max(0, +x); break;
        case 'rate_slew_time': v.rateSlew = this.slewCoef(+x); break;
        case 'level_slew_time': v.levelSlew = this.slewCoef(+x); break;
        case 'pan_slew_time': v.panSlew = this.slewCoef(+x); break;
        case 'recpre_slew_time': v.recpreSlew = this.slewCoef(+x); break;
        case 'phase_quant': v.quant = Math.max(0, +x); v.lastQ = NaN; break;
        case 'phase_offset': v.phaseOff = +x; break;
        case 'post_filter_fc': v.fc = Math.max(10, Math.min(+x, sr * 0.45)); v.fdirty = true; break;
        case 'post_filter_rq': v.rq = Math.max(0.01, +x); v.fdirty = true; break;
        case 'post_filter_lp': v.lp = +x; break;
        case 'post_filter_hp': v.hp = +x; break;
        case 'post_filter_bp': v.bp = +x; break;
        case 'post_filter_br': v.br = +x; break;
        case 'post_filter_dry': v.dry = +x; break;
        default: break;
      }
    }
    position(vi, s) { const v = this.v[vi]; if (v) this.cutTo(v, this.clampFrame(+s)); }
    cutTo(v, frame) {
      const a = v.heads[v.active], b = v.heads[1 - v.active];
      if (v.fade <= 0) {
        a.st = 0; a.f = 0;
        b.pos = frame; b.f = 1; b.st = 2;
      } else {
        if (a.st === 1 || a.st === 2) a.st = 3;
        b.pos = frame; b.f = 0; b.st = 1;
      }
      v.active = 1 - v.active;
    }
    levelInputCut(ch, vi, amt) { const v = this.v[vi]; if (!v) return; if (ch === 0) v.inL = +amt; else v.inR = +amt; }
    levelCutCut(src, dst, amt) { const v = this.v[dst]; if (v && src >= 0 && src < NV) v.cut[src] = +amt; }
    voiceSync(dst, src, offset) {
      const d = this.v[dst], s = this.v[src]; if (!d || !s) return;
      this.cutTo(d, s.heads[s.active].pos + (+offset || 0) * this.sr);
    }
    query(vi) { const v = this.v[vi]; return v ? v.heads[v.active].pos / this.sr : 0; }

    bufClear() { this.bufs[0].fill(0); this.bufs[1].fill(0); }
    bufClearChannel(ch) { if (this.bufs[ch]) this.bufs[ch].fill(0); }
    bufClearRegion(ch, start, dur) {
      const chans = ch < 0 ? [0, 1] : [ch];
      const a = Math.floor(Math.max(0, start) * this.sr);
      const n = dur < 0 ? N - a : Math.floor(dur * this.sr);
      for (const c of chans) for (let i = 0; i < n; i++) this.bufs[c][(a + i) & MASK] = 0;
    }
    bufCopy(srcCh, dstCh, srcStart, dstStart, dur, fade, preserve, reverse) {
      const S = this.bufs[srcCh], D = this.bufs[dstCh]; if (!S || !D) return;
      const a = Math.floor(srcStart * this.sr), b = Math.floor(dstStart * this.sr);
      const n = Math.floor((dur < 0 ? (N / this.sr - srcStart) : dur) * this.sr);
      const tmp = new Float32Array(n);
      for (let i = 0; i < n; i++) tmp[i] = S[(a + i) & MASK];
      if (reverse) tmp.reverse();
      const fadeN = Math.max(1, Math.floor((fade || 0) * this.sr));
      const pre = +preserve || 0;
      for (let i = 0; i < n; i++) {
        const g = Math.min(1, i / fadeN, (n - 1 - i) / fadeN);
        const k = (b + i) & MASK;
        D[k] = D[k] * (pre + (1 - pre) * (1 - g)) + tmp[i] * g;
      }
    }
    bufLoad(ch, dstStart, data, preserve, mix) {
      const D = this.bufs[ch]; if (!D) return;
      const b = Math.floor(Math.max(0, dstStart) * this.sr);
      const pre = +preserve || 0, m = mix === undefined || mix === null ? 1 : +mix;
      for (let i = 0; i < data.length; i++) {
        const k = (b + i) & MASK;
        D[k] = D[k] * pre + data[i] * m;
      }
    }
    getRegion(ch, start, dur) {
      const S = this.bufs[ch]; if (!S) return new Float32Array(0);
      const a = Math.floor(Math.max(0, start) * this.sr);
      const n = Math.min(N, Math.floor((dur < 0 ? N / this.sr : dur) * this.sr));
      const out = new Float32Array(n);
      for (let i = 0; i < n; i++) out[i] = S[(a + i) & MASK];
      return out;
    }
    render(ch, start, dur, count) {
      const S = this.bufs[ch]; if (!S) return [new Float32Array(0), 0];
      count = Math.max(1, Math.min(4096, count | 0));
      const a = Math.floor(Math.max(0, start) * this.sr);
      const n = Math.max(count, Math.floor(dur * this.sr));
      const step = n / count;
      const out = new Float32Array(count);
      for (let j = 0; j < count; j++) {
        let peak = 0, signed = 0;
        const s0 = Math.floor(j * step), s1 = Math.max(s0 + 1, Math.floor((j + 1) * step));
        const inc = Math.max(1, Math.floor((s1 - s0) / 64));
        for (let i = s0; i < s1; i += inc) { const x = S[(a + i) & MASK]; if (Math.abs(x) > peak) { peak = Math.abs(x); signed = x; } }
        out[j] = signed;
      }
      return [out, (n / count) / this.sr];
    }

    updateFilter(v) {
      const g = Math.tan(Math.PI * v.fc / this.sr), k = v.rq;
      v.fk = k;
      v.fa1 = 1 / (1 + g * (g + k));
      v.fa2 = g * v.fa1;
      v.fa3 = g * v.fa2;
      v.fdirty = false;
    }

    process(inL, inR, outL, outR, frames) {
      const sr = this.sr, prev = this.prev, bufs = this.bufs;
      outL.fill(0); if (outR !== outL) outR.fill(0);
      const cur = new Float32Array(NV);
      for (let n = 0; n < frames; n++) {
        const xl = inL ? inL[n] : 0, xr = inR ? inR[n] : xl;
        let L = 0, R = 0;
        for (let vi = 0; vi < NV; vi++) {
          const v = this.v[vi];
          if (!v.enabled) { cur[vi] = 0; continue; }
          v.rateCur = v.rateSlew ? v.rate + (v.rateCur - v.rate) * v.rateSlew : v.rate;
          v.levelCur = v.levelSlew ? v.level + (v.levelCur - v.level) * v.levelSlew : v.level;
          v.panCur = v.panSlew ? v.pan + (v.panCur - v.pan) * v.panSlew : v.pan;
          if (v.recpreSlew) {
            v.recCur = v.recLevel + (v.recCur - v.recLevel) * v.recpreSlew;
            v.preCur = v.preLevel + (v.preCur - v.preLevel) * v.recpreSlew;
          } else { v.recCur = v.recLevel; v.preCur = v.preLevel; }
          if (!v.play) { cur[vi] = 0; continue; }
          let inp = v.inL * xl + v.inR * xr;
          for (let j = 0; j < NV; j++) if (v.cut[j]) inp += v.cut[j] * prev[j];
          const B = bufs[v.buf];
          const rate = v.rateCur;
          const finc = v.fade > 0 ? 1 / (v.fade * sr) : 1;
          let out = 0;
          for (let hi = 0; hi < 2; hi++) {
            const h = v.heads[hi];
            if (h.st === 0) continue;
            if (h.st === 1) { h.f += finc; if (h.f >= 1) { h.f = 1; h.st = 2; } }
            else if (h.st === 3) { h.f -= finc; if (h.f <= 0) { h.f = 0; h.st = 0; continue; } }
            const g = Math.sin(h.f * 1.5707963);
            const p = h.pos, i0 = Math.floor(p), fr = p - i0;
            const a = B[i0 & MASK], b = B[(i0 + 1) & MASK];
            out += (a + (b - a) * fr) * g;
            if (v.rec) {
              const k = Math.round(p) & MASK;
              B[k] = B[k] * (1 - g * (1 - v.preCur)) + inp * v.recCur * g;
            }
            h.pos += rate;
            if (hi === v.active && h.st !== 3) {
              if (rate >= 0 && h.pos >= v.le) {
                if (v.loop) this.cutTo(v, v.ls + (h.pos - v.le)); else h.st = 3;
              } else if (rate < 0 && h.pos < v.ls) {
                if (v.loop) this.cutTo(v, v.le - (v.ls - h.pos)); else h.st = 3;
              }
            }
          }
          if (v.dry !== 1 || v.lp || v.hp || v.bp || v.br) {
            if (v.fdirty) this.updateFilter(v);
            const v3 = out - v.ic2, v1 = v.fa1 * v.ic1 + v.fa2 * v3, v2 = v.ic2 + v.fa2 * v.ic1 + v.fa3 * v3;
            v.ic1 = 2 * v1 - v.ic1; v.ic2 = 2 * v2 - v.ic2;
            const low = v2, band = v1, high = out - v.fk * v1 - v2;
            out = v.dry * out + v.lp * low + v.hp * high + v.bp * band + v.br * (low + high);
          }
          out *= v.levelCur;
          cur[vi] = out;
          const ang = (v.panCur + 1) * 0.7853982;
          L += out * Math.cos(ang); R += out * Math.sin(ang);
          if (this.phaseOn && v.quant > 0) {
            const ph = v.heads[v.active].pos / sr + v.phaseOff;
            const q = Math.floor(ph / v.quant);
            if (q !== v.lastQ) { v.lastQ = q; this.events.push(vi, q * v.quant); }
          }
        }
        prev.set(cur);
        outL[n] = L; if (outR !== outL) outR[n] = R;
      }
    }

    call(fn, args) {
      switch (fn) {
        case 'set': return this.set(args[0], args[1], args[2]);
        case 'position': return this.position(args[0], args[1]);
        case 'level_input_cut': return this.levelInputCut(args[0], args[1], args[2]);
        case 'level_cut_cut': return this.levelCutCut(args[0], args[1], args[2]);
        case 'voice_sync': return this.voiceSync(args[0], args[1], args[2]);
        case 'query': return this.query(args[0]);
        case 'clear': return this.bufClear();
        case 'clear_channel': return this.bufClearChannel(args[0]);
        case 'clear_region': return this.bufClearRegion(args[0], args[1], args[2]);
        case 'copy': return this.bufCopy(...args);
        case 'load': return this.bufLoad(args[0], args[1], args[2], args[3], args[4]);
        case 'region': return this.getRegion(args[0], args[1], args[2]);
        case 'render': return this.render(args[0], args[1], args[2], args[3]);
        case 'phase_poll': this.phaseOn = !!args[0]; return;
        case 'reset': return this.reset();
      }
    }
  }
  G.SoftcutCore = SoftcutCore;

  if (typeof AudioWorkletProcessor !== 'undefined' && typeof registerProcessor === 'function') {
    class SoftcutProcessor extends AudioWorkletProcessor {
      constructor() {
        super();
        this.core = new SoftcutCore(sampleRate);
        this.port.onmessage = e => {
          const msgs = Array.isArray(e.data) ? e.data : [e.data];
          for (const m of msgs) {
            const r = this.core.call(m.fn, m.args || []);
            if (m.id !== undefined) this.port.postMessage({ t: 'reply', id: m.id, r });
          }
        };
      }
      process(inputs, outputs) {
        const inp = inputs[0] || [], out = outputs[0];
        const L = out[0], R = out[1] || out[0];
        this.core.process(inp[0] || null, inp[1] || inp[0] || null, L, R, L.length);
        if (this.core.events.length) { this.port.postMessage({ t: 'phase', e: this.core.events }); this.core.events = []; }
        return true;
      }
    }
    registerProcessor('softcut', SoftcutProcessor);
  }
})(typeof globalThis !== 'undefined' ? globalThis : this);
