const fs = require('fs'), zlib = require('zlib'), path = require('path');
const [,, outTga, outPng] = process.argv;

const mix = (a, b, t) => a.map((v, i) => v + (b[i] - v) * t);
const clamp = (x, a = 0, b = 1) => Math.max(a, Math.min(b, x));
const hex = h => [1, 3, 5].map(i => parseInt(h.substr(i, 2), 16) / 255);
const circle = (x, y, cx, cy, r) => Math.hypot(x - cx, y - cy) - r;
const ellipse = (x, y, cx, cy, rx, ry) => (Math.hypot((x - cx) / rx, (y - cy) / ry) - 1) * Math.min(rx, ry);
const bust = (x, y, s) => Math.min(circle(x, y, s.hx, s.hy, s.hr), ellipse(x, y, s.bx, s.by, s.rx, s.ry));

const FRONT = { hx: 25, hy: 27, hr: 10.5, bx: 25, by: 60, rx: 20, ry: 18 };
const BACK  = { hx: 43, hy: 21, hr: 8.5,  bx: 43, by: 50, rx: 15, ry: 14 };
const GAP = 2.4;

function shade(x, y) {               // x, y in 0..64, y down
  // background: deep blue radial with vignette
  const d = Math.hypot(x - 30, y - 24) / 46;
  let c = mix(hex('#2c4a7e'), hex('#0a1326'), clamp(d));
  // back friend: muted gold, cut where the front one is near
  const sb = bust(x, y, BACK), sf = bust(x, y, FRONT);
  if (sb < 0 && sf > GAP) c = mix(hex('#c79a45'), hex('#7a5a22'), clamp((y - 10) / 50));
  else if (sb < 0 && sf > 0) c = mix(c, hex('#05080f'), 0.85);
  // front friend: bright parchment-gold with top light
  if (sf < 0) {
    c = mix(hex('#fff0b8'), hex('#d9a536'), clamp((y - 14) / 46));
    const rim = clamp(1 + sf / 1.6);  // darker rim at the edge
    c = mix(c, hex('#8a5f17'), rim * 0.6);
  }
  // green "online" dot with dark ring
  const dot = circle(x, y, 52, 52, 6);
  if (dot < 2) c = mix(c, hex('#05080f'), 0.9);
  if (dot < 0) c = mix(hex('#8dff7a'), hex('#1f9e2a'), clamp((Math.hypot(x - 50, y - 50)) / 8));
  // edge vignette (icons get a frame from the UI)
  const e = Math.min(x, y, 64 - x, 64 - y);
  c = mix(c, [0, 0, 0], clamp(1 - e / 5) * 0.45);
  return c;
}

function render(N, ss = 4) {
  const px = Buffer.alloc(N * N * 4);
  for (let j = 0; j < N; j++) for (let i = 0; i < N; i++) {
    let acc = [0, 0, 0];
    for (let sy = 0; sy < ss; sy++) for (let sx = 0; sx < ss; sx++) {
      const c = shade((i + (sx + 0.5) / ss) * 64 / N, (j + (sy + 0.5) / ss) * 64 / N);
      acc = acc.map((v, k) => v + c[k]);
    }
    const o = (j * N + i) * 4;
    for (let k = 0; k < 3; k++) px[o + k] = Math.round(clamp(acc[k] / (ss * ss)) * 255);
    px[o + 3] = 255;
  }
  return px;
}

function tga(N, rgba) {
  const h = Buffer.alloc(18);
  h[2] = 2; h.writeUInt16LE(N, 12); h.writeUInt16LE(N, 14); h[16] = 32; h[17] = 0x28;
  const body = Buffer.alloc(N * N * 4);
  for (let p = 0; p < N * N; p++) {
    body[p * 4] = rgba[p * 4 + 2]; body[p * 4 + 1] = rgba[p * 4 + 1];
    body[p * 4 + 2] = rgba[p * 4]; body[p * 4 + 3] = rgba[p * 4 + 3];
  }
  return Buffer.concat([h, body]);
}

function png(N, rgba) {
  const crc = b => zlib.crc32(b) >>> 0;
  const chunk = (type, data) => {
    const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
    const td = Buffer.concat([Buffer.from(type), data]);
    const c = Buffer.alloc(4); c.writeUInt32BE(crc(td));
    return Buffer.concat([len, td, c]);
  };
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(N, 0); ihdr.writeUInt32BE(N, 4); ihdr[8] = 8; ihdr[9] = 6;
  const raw = Buffer.alloc(N * (N * 4 + 1));
  for (let y = 0; y < N; y++) rgba.copy(raw, y * (N * 4 + 1) + 1, y * N * 4, (y + 1) * N * 4);
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw)), chunk('IEND', Buffer.alloc(0))]);
}

fs.mkdirSync(path.dirname(outTga), { recursive: true });
fs.writeFileSync(outTga, tga(64, render(64)));
fs.writeFileSync(outPng, png(256, render(256, 3)));
fs.writeFileSync(outPng.replace('.png', '-64.png'), png(64, render(64)));
console.log('ok');
