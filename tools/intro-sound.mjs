#!/usr/bin/env node
// Sounds of VD VR's start animation (scripts/intro.gd), synthesised from scratch: oscillators, noise,
// filters and a reverb – no samples, no third-party sounds. The times match intro.gd's timeline.
//   node tools/intro-sound.mjs   →   intro/sound/*.wav
//
// bed-main.wav    stereo, from 0.0 s: darkness, riser, braam with the beams (1.45 s), burst of the
//                 programs (2.0 s), club pulse while they circle, braam with the logo (3.95 s),
//                 reverse swell as they fly back (5.35 s), breath into the reveal
// bed-reveal.wav  stereo, from 5.75 s: warm D-major chord while the lounge appears
// The rest are mono and play in 3D where things happen (intro.gd puts them on the objects):
// ring (floor line), fader-0…4 (knobs), beam (beams), orbit (programs circling), shing (logo
// wipe), suck (programs flying back), sparkle (logo dissolves), fly (VD to the start screen),
// land (VD lands on the sign).
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const OUT = join(dirname(fileURLToPath(import.meta.url)), '..', 'intro', 'sound');
const SR = 44100;
const TAU = Math.PI * 2;

let seed = 7512;
const rnd = () => (seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0) / 4294967296;
const noise = () => rnd() * 2 - 1;
const N = (s) => Math.round(s * SR);
const clamp = (x, a = 0, b = 1) => Math.min(b, Math.max(a, x));
const smooth = (a, b, x) => { x = clamp((x - a) / (b - a)); return x * x * (3 - 2 * x); };
const io = (x) => { x = clamp(x); return x * x * x * (x * (x * 6 - 15) + 10); };
/** Speed of io() (0…1, peak in the middle). */
const iov = (x) => { if (x <= 0 || x >= 1) return 0; return 30 * x * x * (1 - x) * (1 - x) / 1.875; };
const back = (x) => { x = clamp(x); const c = 1.4; return 1 + (c + 1) * (x - 1) ** 3 + c * (x - 1) ** 2; };
const midi = (m) => 440 * 2 ** ((m - 69) / 12);
const cents = (c) => 2 ** (c / 1200);

class BQ {
  constructor(type) { this.t = type; this.x1 = this.x2 = this.y1 = this.y2 = 0; }
  set(f, q = 0.707) {
    f = Math.min(Math.max(f, 10), SR * 0.45);
    const w = TAU * f / SR, c = Math.cos(w), s = Math.sin(w), a = s / (2 * q);
    let b0, b1, b2;
    if (this.t === 'lp') { b0 = (1 - c) / 2; b1 = 1 - c; b2 = b0; }
    else if (this.t === 'hp') { b0 = (1 + c) / 2; b1 = -(1 + c); b2 = b0; }
    else { b0 = a; b1 = 0; b2 = -a; }
    const a0 = 1 + a;
    this.b0 = b0 / a0; this.b1 = b1 / a0; this.b2 = b2 / a0; this.a1 = -2 * c / a0; this.a2 = (1 - a) / a0;
    return this;
  }
  run(x) {
    const y = this.b0 * x + this.b1 * this.x1 + this.b2 * this.x2 - this.a1 * this.y1 - this.a2 * this.y2;
    this.x2 = this.x1; this.x1 = x; this.y2 = this.y1; this.y1 = y;
    return y;
  }
}

/** Band-limited saw (polyBLEP). */
class Saw {
  constructor() { this.p = rnd(); }
  run(f) {
    const dt = f / SR;
    this.p += dt;
    if (this.p >= 1) this.p -= 1;
    const t = this.p;
    let v = 2 * t - 1;
    if (t < dt) { const x = t / dt; v -= x + x - x * x - 1; }
    else if (t > 1 - dt) { const x = (t - 1) / dt; v -= x * x + x + x + 1; }
    return v;
  }
}

const mono = (sec) => new Float32Array(N(sec));
const stereo = (sec) => ({ L: new Float32Array(N(sec)), R: new Float32Array(N(sec)) });

/** Adds a mono voice into a stereo buffer at `at` seconds (equal-power pan −1…1). */
function put(dst, src, at, gain = 1, pan = 0) {
  const o = N(at);
  const gl = gain * Math.cos((pan + 1) * Math.PI / 4), gr = gain * Math.sin((pan + 1) * Math.PI / 4);
  for (let i = 0; i < src.length && o + i < dst.L.length; i++) {
    if (o + i < 0) continue;
    dst.L[o + i] += src[i] * gl;
    dst.R[o + i] += src[i] * gr;
  }
}

/** Freeverb (Jezar's public-domain design), stereo in place-free. */
function reverb(L, R, { room = 0.88, damp = 0.4, wet = 0.6, dry = 1 } = {}) {
  const sc = SR / 44100;
  const mk = (len) => ({ b: new Float32Array(Math.round(len * sc)), i: 0, s: 0 });
  const C = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617], A = [556, 441, 341, 225];
  const cl = C.map(mk), cr = C.map((l) => mk(l + 23)), al = A.map(mk), ar = A.map((l) => mk(l + 23));
  const comb = (c, x) => { const y = c.b[c.i]; c.s = y * (1 - damp) + c.s * damp; c.b[c.i] = x + c.s * room; if (++c.i >= c.b.length) c.i = 0; return y; };
  const ap = (a, x) => { const y = a.b[a.i]; a.b[a.i] = x + y * 0.5; if (++a.i >= a.b.length) a.i = 0; return y - x; };
  const n = L.length, oL = new Float32Array(n), oR = new Float32Array(n);
  for (let i = 0; i < n; i++) {
    const x = (L[i] + R[i]) * 0.015;
    let a = 0, b = 0;
    for (const c of cl) a += comb(c, x);
    for (const c of cr) b += comb(c, x);
    for (const p of al) a = ap(p, a);
    for (const p of ar) b = ap(p, b);
    oL[i] = L[i] * dry + a * wet * 3;
    oR[i] = R[i] * dry + b * wet * 3;
  }
  return { L: oL, R: oR };
}

// ------------------------------------------------------------------ instruments
/** Deep hit: sine falling in pitch, saturated so small speakers hear it too. */
function boom(dur, f0, f1, decay = 2.6, drive = 2.5) {
  const out = mono(dur);
  let ph = 0;
  for (let i = 0; i < out.length; i++) {
    const t = i / SR;
    ph += TAU * (f1 + (f0 - f1) * Math.exp(-t * 9)) / SR;
    const a = Math.exp(-t * decay) * smooth(0, 0.004, t);
    out[i] = Math.tanh(Math.sin(ph) * a * drive) / Math.tanh(drive);
  }
  return out;
}

function kick() {
  const out = mono(0.5);
  let ph = 0;
  for (let i = 0; i < out.length; i++) {
    const t = i / SR;
    ph += TAU * (48 + 110 * Math.exp(-t * 30)) / SR;
    const a = Math.exp(-t * 7) * smooth(0, 0.002, t);
    out[i] = Math.tanh(Math.sin(ph) * a * 3) / Math.tanh(3) + noise() * Math.exp(-t * 400) * 0.3;
  }
  return out;
}

function hat() {
  const out = mono(0.25), hp = new BQ('hp').set(7500, 0.8);
  for (let i = 0; i < out.length; i++) out[i] = hp.run(noise()) * Math.exp(-i / SR * 26);
  return out;
}

/** Noise burst through a band-pass; f(t) and a(t) shape it. */
function swoosh(dur, f, a, q = 1.4) {
  const out = mono(dur), bp = new BQ('bp');
  for (let i = 0; i < out.length; i++) {
    const t = i / SR;
    if (i % 16 === 0) bp.set(f(t), q);
    out[i] = bp.run(noise()) * a(t);
  }
  return out;
}

/** Trailer braam: a chord of detuned saws, a filter that opens hard and closes slowly, saturated. */
function braam(notes, dur, open = 3200) {
  const L = mono(dur), R = mono(dur);
  for (const m of notes) {
    for (const [dc, pan] of [[-14, -0.8], [-6, -0.3], [0, 0], [6, 0.3], [14, 0.8]]) {
      const o = new Saw(), lp = new BQ('lp');
      const f = midi(m) * cents(dc);
      for (let i = 0; i < L.length; i++) {
        const t = i / SR;
        if (i % 16 === 0) lp.set(220 + open * Math.exp(-t * 3.2) + 500 * Math.exp(-t * 0.6), 1.3);
        const v = lp.run(o.run(f)) * smooth(0, 0.015, t) * Math.exp(-t * 0.85) * (1 - smooth(dur - 0.3, dur, t));
        L[i] += v * (1 - pan) * 0.5;
        R[i] += v * (1 + pan) * 0.5;
      }
    }
  }
  for (let i = 0; i < L.length; i++) { L[i] = Math.tanh(L[i] * 0.6); R[i] = Math.tanh(R[i] * 0.6); }
  return { L, R };
}

/** FM bell. */
function bell(f, dur, index = 3, ratio = 1.4, decay = 2.2) {
  const out = mono(dur);
  let pc = 0, pm = 0;
  for (let i = 0; i < out.length; i++) {
    const t = i / SR;
    pm += TAU * f * ratio / SR;
    pc += TAU * f / SR + index * Math.exp(-t * 4) * Math.sin(pm) * TAU * f * ratio / SR * 0.15;
    out[i] = Math.sin(pc) * Math.exp(-t * decay) * smooth(0, 0.003, t);
  }
  return out;
}

/** Glitter: short high sine grains, density and level from `rate(t)`. */
function grains(dst, from, to, rate, lo = 2500, hi = 8000, gain = 0.08) {
  for (let t = from; t < to;) {
    t += -Math.log(1 - rnd() * 0.999) / Math.max(rate(t), 0.1);
    if (t >= to) break;
    const f = lo * (hi / lo) ** rnd(), d = 0.04 + rnd() * 0.2, g = gain * (0.3 + rnd() * 0.7);
    const v = mono(d);
    for (let i = 0; i < v.length; i++) { const x = i / SR; v[i] = Math.sin(TAU * f * x) * Math.exp(-x * 4 / d) * smooth(0, 0.004, x); }
    if (dst.L) put(dst, v, t, g, rnd() * 2 - 1);
    else for (let i = 0; i < v.length && N(t) + i < dst.length; i++) dst[N(t) + i] += v[i] * g;
  }
}

function pluck(m, dur, bright, pan, dst, at, gain) {
  const v = mono(dur), a = new Saw(), b = new Saw(), lp = new BQ('lp');
  for (let i = 0; i < v.length; i++) {
    const t = i / SR;
    if (i % 16 === 0) lp.set(350 + bright * Math.exp(-t * 14), 2.2);
    v[i] = lp.run(a.run(midi(m) * cents(-6)) + b.run(midi(m) * cents(6))) * Math.exp(-t * 9) * smooth(0, 0.003, t) * 0.5;
  }
  put(dst, v, at, gain, pan);
}

function pad(notes, dur, cutoff, amp) {
  const L = mono(dur), R = mono(dur);
  for (const m of notes) {
    for (const [dc, pan] of [[-16, -0.9], [-8, -0.4], [0, 0], [8, 0.4], [16, 0.9]]) {
      const o = new Saw(), lp = new BQ('lp'), f = midi(m) * cents(dc);
      for (let i = 0; i < L.length; i++) {
        const t = i / SR;
        if (i % 32 === 0) lp.set(cutoff(t), 0.8);
        const v = lp.run(o.run(f)) * amp(t);
        L[i] += v * (1 - pan) * 0.5;
        R[i] += v * (1 + pan) * 0.5;
      }
    }
  }
  return { L, R };
}

// ------------------------------------------------------------------ output
function finish(buf, peak = 0.89, soft = 1.6) {
  const chans = buf.L ? [buf.L, buf.R] : [buf];
  // Nothing below 30 Hz: headset speakers cannot play it, it would only eat headroom.
  for (const c of chans) { const hp = new BQ('hp').set(30, 0.7); for (let i = 0; i < c.length; i++) c[i] = hp.run(c[i]); }
  let m = 1e-9;
  for (const c of chans) for (const v of c) m = Math.max(m, Math.abs(v));
  for (const c of chans) for (let i = 0; i < c.length; i++) c[i] = Math.tanh(soft * c[i] / m) / Math.tanh(soft);
  m = 1e-9;
  for (const c of chans) for (const v of c) m = Math.max(m, Math.abs(v));
  for (const c of chans) for (let i = 0; i < c.length; i++) c[i] *= peak / m;
  // 5 ms fade at both ends: no clicks.
  for (const c of chans) for (let i = 0; i < N(0.005); i++) { const g = i / N(0.005); c[i] *= g; c[c.length - 1 - i] *= g; }
  return chans;
}

function wav(name, chans) {
  const n = chans[0].length, ch = chans.length, data = Buffer.alloc(n * ch * 2);
  for (let i = 0; i < n; i++) for (let c = 0; c < ch; c++) data.writeInt16LE(Math.round(clamp(chans[c][i], -1, 1) * 32767), (i * ch + c) * 2);
  const h = Buffer.alloc(44);
  h.write('RIFF', 0); h.writeUInt32LE(36 + data.length, 4); h.write('WAVE', 8);
  h.write('fmt ', 12); h.writeUInt32LE(16, 16); h.writeUInt16LE(1, 20); h.writeUInt16LE(ch, 22);
  h.writeUInt32LE(SR, 24); h.writeUInt32LE(SR * ch * 2, 28); h.writeUInt16LE(ch * 2, 32); h.writeUInt16LE(16, 34);
  h.write('data', 36); h.writeUInt32LE(data.length, 40);
  writeFileSync(join(OUT, name + '.wav'), Buffer.concat([h, data]));
  console.log(`${name}.wav  ${(n / SR).toFixed(2)} s  ${ch === 2 ? 'stereo' : 'mono'}`);
}

/** Mono one-shot with a little room around it. */
function oneShot(name, v, wet = 0.35, peak = 0.89) {
  const tail = mono(v.length / SR + 1.2);
  tail.set(v);
  const r = reverb(tail, tail, { room: 0.84, damp: 0.45, wet });
  const m = mono(tail.length / SR);
  for (let i = 0; i < m.length; i++) m[i] = (r.L[i] + r.R[i]) * 0.5;
  wav(name, finish(m, peak, 1.2));
}

mkdirSync(OUT, { recursive: true });

// ================================================================== bed-main (from 0.0 s)
{
  const B = stereo(7.0);
  const beat = (6.0 - 2.0) / 8.2; // 0.4875 s ≈ 123 BPM: beats on 2.0, ~3.46 (logo wipe), 3.95 (logo complete)
  // darkness: sub drone on D, a low D-minor pad, wind
  {
    const sub = mono(6.6), lp = new BQ('lp').set(500, 0.7);
    let p1 = 0, p2 = 0;
    for (let i = 0; i < sub.length; i++) {
      const t = i / SR, e = smooth(0, 1.4, t) * (1 - smooth(5.5, 6.3, t)) * (1 + 0.3 * smooth(1.4, 2.0, t));
      p1 += TAU * midi(26) / SR; p2 += TAU * midi(38) / SR;
      sub[i] = (Math.sin(p1) * 0.7 + Math.sin(p2) * 0.5 + lp.run(noise()) * 0.25) * e;
    }
    put(B, sub, 0, 0.3);
    const p = pad([38, 45, 50, 53], 6.6, (t) => 260 + 260 * smooth(0, 2, t) + 900 * smooth(2.0, 3.9, t) * (1 - smooth(4.6, 5.5, t)),
      (t) => smooth(0.1, 1.6, t) * (1 - smooth(5.4, 6.2, t)));
    put(B, p.L, 0, 0.09, -0.6); put(B, p.R, 0, 0.09, 0.6);
  }
  // stars: glitter, then a little all the way through
  grains(B, 0, 6.0, (t) => 3 + 14 * smooth(0, 1.2, t) * (1 - smooth(1.4, 2.0, t)) + 4, 2500, 8000, 0.08);
  // riser into the beams
  put(B, swoosh(1.3, (t) => 300 * 20 ** ((t / 1.25) ** 1.5), (t) => (t / 1.25) ** 2 * (1 - smooth(1.24, 1.25, t)), 3), 0.2, 0.75);
  {
    const v = mono(1.3);
    let ph = 0;
    for (let i = 0; i < v.length; i++) { const t = i / SR, x = t / 1.25; ph += TAU * 220 * 4 ** (x * x) / SR; v[i] = Math.sin(ph) * x * x * (1 - smooth(1.24, 1.25, t)); }
    put(B, v, 0.2, 0.12);
  }
  // beams: braam in D minor
  { const b = braam([38, 45, 50, 53, 57], 2.3); put(B, b.L, 1.45, 0.28, -1); put(B, b.R, 1.45, 0.28, 1); }
  put(B, boom(1.8, 120, 40), 1.45, 0.85);
  put(B, swoosh(1.0, () => 4200, (t) => Math.exp(-t * 5) * smooth(0, 0.003, t), 0.6), 1.45, 0.4, -0.3);
  // burst of the programs
  put(B, boom(1.4, 170, 45, 3.2), 2.0, 0.75);
  put(B, swoosh(0.8, (t) => 6000 - 3000 * t, (t) => Math.exp(-t * 7) * smooth(0, 0.002, t), 0.7), 2.0, 0.45, 0.3);
  // club pulse while they circle: kick, offbeat hats, D-minor arpeggio, then B♭ with the logo
  for (let k = 1; k <= 5; k++) if (k !== 4) put(B, kick(), 2.0 + k * beat, 0.55);
  for (let k = 0; k <= 5; k++) put(B, hat(), 2.0 + (k + 0.5) * beat, 0.16, (k % 2) * 0.6 - 0.3);
  const arpA = [62, 69, 65, 69, 74, 69, 65, 69], arpB = [58, 65, 62, 65, 70, 65, 62, 65];
  for (let s = 0; s < 24; s++) {
    const at = 2.0 + s * beat / 4, pr = s / 23;
    pluck((s < 16 ? arpA : arpB)[s % 8], 0.3, 1200 + 3200 * pr, s % 2 ? 0.55 : -0.55, B, at, 0.17 + 0.12 * pr);
  }
  // logo complete: big braam in B♭
  { const b = braam([34, 41, 46, 50, 53, 58], 2.8, 3800); put(B, b.L, 3.95, 0.32, -1); put(B, b.R, 3.95, 0.32, 1); }
  put(B, boom(2.0, 130, 36, 2.0), 3.95, 0.9);
  put(B, swoosh(1.4, () => 3800, (t) => Math.exp(-t * 3.5) * smooth(0, 0.003, t), 0.5), 3.95, 0.4, 0.2);
  // the programs fly back: reverse swell into a soft hit when they meet (5.35 s)
  {
    const v = mono(0.72), lp = new BQ('lp');
    for (let i = 0; i < v.length; i++) { const t = i / SR, x = t / 0.7; if (i % 16 === 0) lp.set(700 + 8000 * x * x, 0.9); v[i] = lp.run(noise()) * x ** 3 * (1 - smooth(0.695, 0.7, t)); }
    put(B, v, 4.65, 0.35);
    const r = mono(0.72);
    for (let i = 0; i < r.length; i++) { const t = i / SR, x = t / 0.7; r[i] = Math.sin(TAU * midi(74) * t) * x ** 4 * (1 - smooth(0.695, 0.7, t)); }
    put(B, r, 4.65, 0.08);
  }
  put(B, boom(1.2, 90, 40, 3.5, 2), 5.35, 0.5);
  put(B, bell(midi(86), 1.6, 2, 1.4, 2.5), 5.35, 0.07, 0.2);
  // breath into the reveal
  put(B, swoosh(0.7, (t) => 600 + 2600 * t / 0.6, (t) => smooth(0, 0.55, t) * (1 - smooth(0.58, 0.62, t)), 1.2), 5.4, 0.12);
  const r = reverb(B.L, B.R, { room: 0.88, damp: 0.4, wet: 0.5 });
  for (let i = 0; i < r.L.length; i++) { const g = 1 - smooth(6.2, 7.0, i / SR); r.L[i] *= g; r.R[i] *= g; }
  wav('bed-main', finish(r));
}

// ================================================================== bed-reveal (from 5.75 s; landing at +1.0 s)
{
  const B = stereo(4.8);
  const env = (t) => smooth(0.1, 1.0, t) * (1 - smooth(1.4, 4.6, t) * 0.999);
  const p = pad([50, 57, 62, 66, 69, 74], 4.8, (t) => 450 + 2600 * smooth(0.15, 1.0, t) * (1 - 0.65 * smooth(1.0, 4.0, t)), env);
  put(B, p.L, 0, 0.05, -0.7); put(B, p.R, 0, 0.05, 0.7);
  const s = mono(4.8);
  for (let i = 0; i < s.length; i++) { const t = i / SR; s[i] = Math.sin(TAU * midi(38) * t) * env(t); }
  put(B, s, 0, 0.18);
  grains(B, 0.9, 3.5, (t) => 10 * (1 - smooth(1.0, 3.5, t)) + 1, 3000, 9000, 0.03);
  const r = reverb(B.L, B.R, { room: 0.9, damp: 0.35, wet: 0.55 });
  wav('bed-reveal', finish(r, 0.89, 1.1));
}

// ================================================================== 3D one-shots
// floor line: whoosh with a gliding tone, as loud as the line draws fast (0.25 → 1.55 s)
{
  const v = swoosh(1.4, (t) => 500 + 2600 * io(t / 1.3), (t) => iov(t / 1.3) * smooth(0, 0.05, t), 1.1);
  let ph = 0;
  for (let i = 0; i < v.length; i++) { const t = i / SR; ph += TAU * (880 * 2 ** io(t / 1.3)) / SR; v[i] += Math.sin(ph) * 0.25 * iov(t / 1.3); }
  const hp = new BQ('hp').set(6000, 0.7);
  for (let i = 0; i < v.length; i++) v[i] += hp.run(noise()) * 0.25 * iov(i / SR / 1.3);
  oneShot('ring', v, 0.4);
}
// knobs: slide up a minor-pentatonic step each, click at the top (slide 0.55 s, like intro.gd)
[62, 65, 67, 69, 72].forEach((m, k) => {
  const v = mono(0.9), bp = new BQ('bp');
  let ph = 0;
  for (let i = 0; i < v.length; i++) {
    const t = i / SR, x = t / 0.55, p = back(x);
    if (i % 16 === 0) bp.set(700 + 2600 * clamp(p, 0, 1.2), 4);
    ph += TAU * midi(m - 12) * 2 ** p / SR;
    const a = t < 0.55 ? smooth(0, 0.03, t) * (0.4 + 0.6 * x) : Math.exp(-(t - 0.55) * 14);
    v[i] = bp.run(noise()) * 0.5 * (t < 0.55 ? a : 0) + Math.sin(ph) * 0.35 * a;
    if (t >= 0.55) { const c = t - 0.55; v[i] += Math.sin(TAU * 2600 * c) * Math.exp(-c * 120) * 0.6 + noise() * Math.exp(-c * 300) * 0.3; }
  }
  oneShot('fader-' + k, v, 0.3);
});
// beams: zap, power hum, fwoosh
{
  const v = mono(1.6), lp = new BQ('lp').set(1200, 1), a = new Saw(), b = new Saw();
  let ph = 0;
  const w = swoosh(1.6, (t) => 300 + 1200 * smooth(0, 0.5, t), (t) => Math.exp(-t * 2.5) * smooth(0, 0.02, t), 1);
  for (let i = 0; i < v.length; i++) {
    const t = i / SR;
    ph += TAU * (180 + 2400 * Math.exp(-t * 25)) / SR;
    v[i] = Math.sin(ph) * Math.exp(-t * 6) * 0.5 + lp.run(a.run(90) + b.run(135)) * smooth(0.02, 0.15, t) * Math.exp(-t * 1.5) * 0.3 + w[i] * 0.45;
  }
  oneShot('beam', v, 0.45);
}
// programs circling: burst (0 → 0.9 s), then one turn (0.5 → 2.6 s)
{
  const amp = (t) => Math.max(0.6 * smooth(0, 0.08, t) * Math.exp(-t * 3), iov((t - 0.5) / 2.1)) * (1 - smooth(2.6, 2.9, t));
  const f = (t) => 350 + 1700 * Math.max(Math.exp(-t * 3), iov((t - 0.5) / 2.1));
  const v = swoosh(2.9, f, amp, 1.4);
  const w = swoosh(2.9, (t) => f(t) * 2.1, amp, 3);
  for (let i = 0; i < v.length; i++) v[i] += w[i] * 0.4;
  oneShot('orbit', v, 0.3);
}
// logo wipe: metallic shing
{
  const v = mono(1.0), hp = new BQ('hp');
  for (const [r, d, g] of [[1, 3, 0.5], [2.76, 4, 0.35], [5.4, 6, 0.25], [8.93, 8, 0.15]]) {
    for (let i = 0; i < v.length; i++) { const t = i / SR; v[i] += Math.sin(TAU * midi(86) * r * t) * Math.exp(-t * d) * smooth(0, 0.02, t) * g; }
  }
  for (let i = 0; i < v.length; i++) { const t = i / SR; if (i % 16 === 0) hp.set(3000 + 7000 * smooth(0, 0.5, t), 0.8); v[i] += hp.run(noise()) * iov(t / 0.5) * 0.35; }
  oneShot('shing', v, 0.45);
}
// programs flying back: reversed whoosh, ends where they vanish (0.7 s)
{
  const v = swoosh(0.75, (t) => 400 + 2600 * (t / 0.7) ** 2, (t) => (t / 0.7) ** 2.5 * (1 - smooth(0.69, 0.7, t)), 2);
  for (let i = 0; i < v.length; i++) { const t = i / SR, x = t / 0.7; v[i] += Math.sin(TAU * 300 * 4 ** x * t) * x ** 3 * 0.2 * (t < 0.7 ? 1 : 0); }
  oneShot('suck', v, 0.25);
}
// logo dissolves: glitter
{
  const v = mono(1.3);
  grains(v, 0, 1.1, (t) => 90 * Math.exp(-t * 2.5), 2500, 9000, 0.5);
  oneShot('sparkle', v, 0.5);
}
// VD flies to the start screen (0.75 s)
{
  const v = swoosh(0.9, (t) => 400 + 1800 * iov(t / 0.75), (t) => iov(t / 0.75), 1.3);
  let ph = 0;
  for (let i = 0; i < v.length; i++) { const t = i / SR; ph += TAU * 440 * 2 ** io(t / 0.75) / SR; v[i] += Math.sin(ph) * 0.15 * iov(t / 0.75); }
  oneShot('fly', v, 0.35);
}
// VD lands: two-note chime and a soft thump
{
  const v = mono(2.6);
  const add = (src, at, g) => { for (let i = 0; i < src.length && N(at) + i < v.length; i++) v[N(at) + i] += src[i] * g; };
  add(boom(0.6, 70, 45, 8, 1.5), 0, 0.5);
  add(bell(midi(81), 2.4, 2.5), 0, 0.4);
  add(bell(midi(86), 2.4, 2.5), 0.09, 0.45);
  add(bell(midi(90), 2.2, 2, 1.4, 2.8), 0.18, 0.18);
  oneShot('land', v, 0.5);
}
