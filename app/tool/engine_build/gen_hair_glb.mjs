// 程序化发型 GLB 生成器（CC0/程序生成，无第三方版权）。
// 用法：node tool/engine_build/gen_hair_glb.mjs --out ../assets/models/characters/hair
// 产物：hair_<id>.glb + hair_index.json（id/name/color/parts），供 gen_characters.dart 合并清单。
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const appRoot = path.resolve(here, '..', '..');
function argValue(flag, fallback) {
  const i = process.argv.indexOf(flag);
  return i >= 0 && process.argv[i + 1] ? process.argv[i + 1] : fallback;
}
const outDir = path.resolve(appRoot, argValue('--out', 'assets/models/characters/hair'));

function spherePart({ c = [0, 0, 0], r = [0.1, 0.1, 0.1], rot = [0, 0, 0], lat = 12, lon = 18 }) {
  const positions = [];
  const normals = [];
  const indices = [];
  const [rx, ry, rz] = r;
  const cx = Math.cos(rot[0]);
  const sx = Math.sin(rot[0]);
  const cy = Math.cos(rot[1]);
  const sy = Math.sin(rot[1]);
  const cz = Math.cos(rot[2]);
  const sz = Math.sin(rot[2]);
  const rotate = (x, y, z) => {
    let x1 = x * cz - y * sz;
    let y1 = x * sz + y * cz;
    const z1 = z;
    let x2 = x1 * cy + z1 * sy;
    const y2 = y1;
    let z2 = -x1 * sy + z1 * cy;
    const y3 = y2 * cx - z2 * sx;
    const z3 = y2 * sx + z2 * cx;
    return [x2, y3, z3];
  };
  for (let i = 0; i <= lat; i++) {
    const v = i / lat;
    const phi = v * Math.PI;
    for (let j = 0; j <= lon; j++) {
      const u = j / lon;
      const theta = u * Math.PI * 2;
      const nx = Math.sin(phi) * Math.cos(theta);
      const ny = Math.cos(phi);
      const nz = Math.sin(phi) * Math.sin(theta);
      const [rxp, ryp, rzp] = rotate(nx * rx, ny * ry, nz * rz);
      positions.push(c[0] + rxp, c[1] + ryp, c[2] + rzp);
      const nn = [nx / (rx * rx), ny / (ry * ry), nz / (rz * rz)];
      const [rnx, rny, rnz] = rotate(nn[0], nn[1], nn[2]);
      const len = Math.hypot(rnx, rny, rnz) || 1;
      normals.push(rnx / len, rny / len, rnz / len);
    }
  }
  for (let i = 0; i < lat; i++) {
    for (let j = 0; j < lon; j++) {
      const a = i * (lon + 1) + j;
      const b = a + lon + 1;
      indices.push(a, b, a + 1, b, b + 1, a + 1);
    }
  }
  return { positions, normals, indices };
}

const H = 1.62; // 归一化后头部中心高度（1.7m 基准）
const styles = [
  {
    id: 'hair-short', name: '短发', color: 0x1f1a16,
    parts: [
      spherePart({ c: [0, H + 0.015, -0.012], r: [0.118, 0.105, 0.122] }),
      spherePart({ c: [0, H + 0.035, 0.038], r: [0.105, 0.06, 0.085] }),
      spherePart({ c: [0, H - 0.02, -0.06], r: [0.1, 0.09, 0.07] }),
    ],
  },
  {
    id: 'hair-buzz', name: '寸头', color: 0x2c211a,
    parts: [
      spherePart({ c: [0, H + 0.018, -0.005], r: [0.113, 0.1, 0.115] }),
    ],
  },
  {
    id: 'hair-bob', name: '波波头', color: 0x33241a,
    parts: [
      spherePart({ c: [0, H + 0.02, -0.01], r: [0.122, 0.11, 0.125] }),
      spherePart({ c: [-0.095, H - 0.075, -0.02], r: [0.045, 0.14, 0.1] }),
      spherePart({ c: [0.095, H - 0.075, -0.02], r: [0.045, 0.14, 0.1] }),
      spherePart({ c: [0, H - 0.085, -0.075], r: [0.1, 0.13, 0.07] }),
    ],
  },
  {
    id: 'hair-long', name: '长发', color: 0x201713,
    parts: [
      spherePart({ c: [0, H + 0.02, -0.012], r: [0.124, 0.112, 0.128] }),
      spherePart({ c: [-0.1, H - 0.05, -0.02], r: [0.045, 0.16, 0.1] }),
      spherePart({ c: [0.1, H - 0.05, -0.02], r: [0.045, 0.16, 0.1] }),
      spherePart({ c: [0, H - 0.28, -0.085], r: [0.13, 0.3, 0.08] }),
    ],
  },
  {
    id: 'hair-pony', name: '马尾', color: 0x3d2a1b,
    parts: [
      spherePart({ c: [0, H + 0.02, -0.01], r: [0.12, 0.108, 0.124] }),
      spherePart({ c: [0, H + 0.06, -0.115], r: [0.07, 0.07, 0.07] }),
      spherePart({ c: [0, H - 0.19, -0.15], r: [0.055, 0.24, 0.055], rot: [-0.35, 0, 0] }),
    ],
  },
  {
    id: 'hair-spiky', name: '刺猬头', color: 0x171412,
    parts: [
      spherePart({ c: [0, H + 0.02, -0.005], r: [0.115, 0.1, 0.118] }),
      ...[-0.06, -0.02, 0.02, 0.06].map((x, i) => spherePart({
        c: [x, H + 0.13 - Math.abs(x) * 0.5, -0.02 + (i % 2 ? 0.03 : -0.02)],
        r: [0.03, 0.06, 0.035], rot: [0, 0, -x * 4],
      })),
    ],
  },
  {
    id: 'hair-bun', name: '丸子头', color: 0x241a14,
    parts: [
      spherePart({ c: [0, H + 0.02, -0.008], r: [0.116, 0.104, 0.12] }),
      spherePart({ c: [0, H + 0.145, -0.045], r: [0.075, 0.075, 0.075] }),
    ],
  },
  {
    id: 'hair-side', name: '侧分', color: 0x4a3524,
    parts: [
      spherePart({ c: [0, H + 0.02, -0.01], r: [0.12, 0.106, 0.124] }),
      spherePart({ c: [-0.045, H + 0.06, 0.075], r: [0.085, 0.055, 0.055], rot: [0.2, 0, 0.25] }),
      spherePart({ c: [0.07, H - 0.03, 0.02], r: [0.04, 0.09, 0.09] }),
    ],
  },
];

function buildGLB(parts, colorHex) {
  const positions = [];
  const normals = [];
  const indices = [];
  for (const part of parts) {
    const base = positions.length / 3;
    positions.push(...part.positions);
    normals.push(...part.normals);
    for (const idx of part.indices) indices.push(base + idx);
  }
  const vertexCount = positions.length / 3;
  const indexCount = indices.length;
  const posBytes = new Uint8Array(new Float32Array(positions).buffer);
  const nrmBytes = new Uint8Array(new Float32Array(normals).buffer);
  const idxArray = vertexCount > 65535 ? new Uint32Array(indices) : new Uint16Array(indices);
  const idxBytes = new Uint8Array(idxArray.buffer);
  const pad = (n, align) => (align - (n % align)) % align;
  const posViewOffset = 0;
  const nrmViewOffset = posViewOffset + posBytes.byteLength + pad(posBytes.byteLength, 4);
  const idxViewOffset = nrmViewOffset + nrmBytes.byteLength + pad(nrmBytes.byteLength, 4);
  const binLength = idxViewOffset + idxBytes.byteLength + pad(idxBytes.byteLength, 4);
  const bin = new Uint8Array(binLength);
  bin.set(posBytes, posViewOffset);
  bin.set(nrmBytes, nrmViewOffset);
  bin.set(idxBytes, idxViewOffset);
  const min = [Infinity, Infinity, Infinity];
  const max = [-Infinity, -Infinity, -Infinity];
  for (let i = 0; i < positions.length; i += 3) {
    for (let k = 0; k < 3; k++) {
      min[k] = Math.min(min[k], positions[i + k]);
      max[k] = Math.max(max[k], positions[i + k]);
    }
  }
  const r = ((colorHex >> 16) & 255) / 255;
  const g = ((colorHex >> 8) & 255) / 255;
  const b = (colorHex & 255) / 255;
  const json = {
    asset: { version: '2.0', generator: 'ShootStudio gen_hair_glb.mjs (procedural CC0)' },
    scene: 0,
    scenes: [{ nodes: [0] }],
    nodes: [{ mesh: 0, name: 'Hair' }],
    meshes: [{
      name: 'Hair',
      primitives: [{
        attributes: { POSITION: 0, NORMAL: 1 },
        indices: 2,
        material: 0,
        mode: 4,
      }],
    }],
    materials: [{
      name: 'Hair',
      pbrMetallicRoughness: {
        baseColorFactor: [r, g, b, 1],
        metallicFactor: 0,
        roughnessFactor: 0.85,
      },
    }],
    accessors: [
      { bufferView: 0, componentType: 5126, count: vertexCount, type: 'VEC3', min, max },
      { bufferView: 1, componentType: 5126, count: vertexCount, type: 'VEC3' },
      { bufferView: 2, componentType: vertexCount > 65535 ? 5125 : 5123, count: indexCount, type: 'SCALAR' },
    ],
    bufferViews: [
      { buffer: 0, byteOffset: posViewOffset, byteLength: posBytes.byteLength, target: 34962 },
      { buffer: 0, byteOffset: nrmViewOffset, byteLength: nrmBytes.byteLength, target: 34962 },
      { buffer: 0, byteOffset: idxViewOffset, byteLength: idxBytes.byteLength, target: 34963 },
    ],
    buffers: [{ byteLength: binLength }],
  };
  const jsonBytes = new Uint8Array(Buffer.from(JSON.stringify(json), 'utf8'));
  const jsonPad = pad(jsonBytes.byteLength, 4);
  const jsonLen = jsonBytes.byteLength + jsonPad;
  const total = 12 + 8 + jsonLen + 8 + binLength;
  const out = Buffer.alloc(total, 0);
  out.writeUInt32LE(0x46546c67, 0);
  out.writeUInt32LE(2, 4);
  out.writeUInt32LE(total, 8);
  out.writeUInt32LE(jsonLen, 12);
  out.writeUInt32LE(0x4e4f534a, 16);
  out.set(jsonBytes, 20);
  for (let i = 0; i < jsonPad; i++) out[20 + jsonBytes.byteLength + i] = 0x20;
  const binHeader = 20 + jsonLen;
  out.writeUInt32LE(binLength, binHeader);
  out.writeUInt32LE(0x004e4942, binHeader + 4);
  out.set(bin, binHeader + 8);
  return out;
}

fs.mkdirSync(outDir, { recursive: true });
const index = [];
for (const style of styles) {
  const file = `${style.id}.glb`;
  const target = path.join(outDir, file);
  fs.writeFileSync(target, buildGLB(style.parts, style.color));
  index.push({
    id: style.id,
    name: style.name,
    file: `hair/${file}`,
    color: `#${style.color.toString(16).padStart(6, '0')}`,
    generated: true,
    parts: style.parts.length,
  });
  console.log('hair ->', path.relative(appRoot, target));
}
fs.writeFileSync(path.join(outDir, 'hair_index.json'), JSON.stringify({ hair: index }, null, 2));
console.log(`发型生成完成：${index.length} 个 -> ${path.relative(appRoot, outDir)}`);
