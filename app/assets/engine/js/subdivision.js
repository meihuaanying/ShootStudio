// 运行时细分：蒙皮保真 Loop 细分 + 非蒙皮网格走 vendored three-subdivide（MIT）。
//
// 背景（D61/D62/R18/R26）：
//   three-subdivide 的 LoopSubdivision.smooth() 逐属性复制时只按 Vector3 处理，
//   itemSize=4 的 skinIndex/skinWeight 会被截断并写入 undefined（NaN），蒙皮必然损坏。
//   因此对 SkinnedMesh 改用自研「边界保持 Loop」：拓扑与 Loop 位置规则一致，
//   但 skinIndex/skinWeight 与位置使用同一组凸组合系数（自身/邻点/对顶点），
//   输出后做 Top-4 归一化，保证骨骼索引合法且权重和为 1，蒙皮随骨骼正常变形。
//   边界顶点保持原位（1/8-3/4 规则仅用于内部点），避免分件网格张开裂缝。
import * as THREE from 'three';
import { LoopSubdivision } from './vendor/three-subdivide/LoopSubdivision.js';

// 焊接量子：仅合并“完全相同”的接缝顶点。Quaternius 头部件局部坐标可小到 ~5e-4
// （节点 scale=100），用量子 1e4 会误并不同顶点导致面数减少；1e7 只影响浮点噪声。
const POSITION_QUANT = 1e7;
const geometryCache = new WeakMap(); // BufferGeometry -> Map(key -> BufferGeometry)

export function triangleCount(geometry) {
  if (!geometry) return 0;
  if (geometry.index) return Math.floor(geometry.index.count / 3);
  const position = geometry.getAttribute && geometry.getAttribute('position');
  return position ? Math.floor(position.count / 3) : 0;
}

export function meshTriangleCounts(meshes) {
  return (meshes || []).map((mesh) => triangleCount(mesh && mesh.geometry));
}

// 带缓存的细分入口：同一原始几何只算一次（相同层级）。
export function subdivideForPlan(baseGeometry, iterations, skinned = true) {
  if (!baseGeometry || iterations <= 0) return baseGeometry;
  let perGeometry = geometryCache.get(baseGeometry);
  if (!perGeometry) {
    perGeometry = new Map();
    geometryCache.set(baseGeometry, perGeometry);
  }
  const key = `${skinned ? 'skin' : 'plain'}:${iterations}`;
  if (!perGeometry.has(key)) {
    perGeometry.set(
      key,
      skinned ? subdivideSkinned(baseGeometry, iterations) : subdividePlain(baseGeometry, iterations),
    );
  }
  return perGeometry.get(key);
}

function subdividePlain(geometry, iterations) {
  return LoopSubdivision.modify(geometry, iterations, {
    split: true,
    uvSmooth: false,
    preserveEdges: false,
  });
}

function subdivideSkinned(geometry, iterations) {
  let current = geometry;
  for (let i = 0; i < iterations; i++) current = loopStepSkinned(current);
  return current;
}

function positionHash(x, y, z) {
  return `${Math.round(x * POSITION_QUANT)},${Math.round(y * POSITION_QUANT)},${Math.round(z * POSITION_QUANT)}`;
}

function normalizeSkin(acc) {
  let sum = 0;
  for (const weight of acc.values()) sum += weight;
  if (!(sum > 0)) return null;
  const entries = [...acc.entries()].sort((a, b) => b[1] - a[1]).slice(0, 4);
  let top = 0;
  for (const entry of entries) top += entry[1];
  if (!(top > 0)) return null;
  return entries.map(([bone, weight]) => [bone, weight / top]);
}

// 一次 Loop 细分（边界保持 + 蒙皮属性守恒）。
function loopStepSkinned(geometry) {
  const position = geometry.getAttribute('position');
  const uv = geometry.getAttribute('uv');
  const skinIndex = geometry.getAttribute('skinIndex');
  const skinWeight = geometry.getAttribute('skinWeight');
  const sourceCount = position.count;
  const index = geometry.index ? geometry.index.array : null;
  const triangleTotal = index ? Math.floor(index.length / 3) : Math.floor(sourceCount / 3);

  // 1) 按位置焊接顶点（同时恢复 UV/法线裂缝处的共享拓扑）。
  const positionMap = new Map();
  const sourceToUnique = new Int32Array(sourceCount);
  const uniquePos = [];
  let uniqueUv = uv ? [] : null;
  const uniqueSkinAcc = [];
  for (let s = 0; s < sourceCount; s++) {
    const hash = positionHash(position.getX(s), position.getY(s), position.getZ(s));
    let u = positionMap.get(hash);
    if (u === undefined) {
      u = uniquePos.length / 3;
      positionMap.set(hash, u);
      uniquePos.push(position.getX(s), position.getY(s), position.getZ(s));
      if (uniqueUv) uniqueUv.push(uv.getX(s), uv.getY(s));
      uniqueSkinAcc.push(new Map());
    }
    sourceToUnique[s] = u;
    if (skinIndex && skinWeight) {
      const acc = uniqueSkinAcc[u];
      for (let j = 0; j < 4; j++) {
        const weight = skinWeight.getComponent(s, j);
        if (weight > 0) {
          const bone = skinIndex.getComponent(s, j);
          acc.set(bone, (acc.get(bone) || 0) + weight);
        }
      }
    }
  }
  const uniqueCount = uniqueSkinAcc.length;
  const uniqueSkin = uniqueSkinAcc.map(normalizeSkin);

  // 2) 拓扑邻接（边计数 + 对顶点 + 顶点邻居）。
  const neighbors = Array.from({ length: uniqueCount }, () => new Set());
  const edges = new Map();
  const triangles = [];
  const edgeKey = (a, b) => (a < b ? `${a}_${b}` : `${b}_${a}`);
  const addEdge = (a, b, opposite) => {
    const key = edgeKey(a, b);
    let edge = edges.get(key);
    if (!edge) {
      edge = { a: Math.min(a, b), b: Math.max(a, b), count: 0, opposite: [] };
      edges.set(key, edge);
    }
    edge.count += 1;
    edge.opposite.push(opposite);
  };
  for (let t = 0; t < triangleTotal; t++) {
    const i0 = index ? index[t * 3] : t * 3;
    const i1 = index ? index[t * 3 + 1] : t * 3 + 1;
    const i2 = index ? index[t * 3 + 2] : t * 3 + 2;
    const a = sourceToUnique[i0];
    const b = sourceToUnique[i1];
    const c = sourceToUnique[i2];
    // 退化三角形也保留（输出为零面积三角形），否则面数不再严格 4 倍、
    // 与 tool/subdivide_characters.mjs 登记的 triCount 会产生偏差。
    triangles.push(a, b, c);
    addEdge(a, b, c);
    addEdge(b, c, a);
    addEdge(c, a, b);
  }
  for (const edge of edges.values()) {
    if (edge.a !== edge.b) {
      neighbors[edge.a].add(edge.b);
      neighbors[edge.b].add(edge.a);
    }
  }

  // 3) 输出顶点：偶数点沿用原索引，边点追加。
  const outputCount = uniqueCount + edges.size;
  const outPosition = new Float32Array(outputCount * 3);
  const outUv = uniqueUv ? new Float32Array(outputCount * 2) : null;
  const outSkin = new Array(outputCount).fill(null);
  const edgeIndex = new Map();

  const blend = (target, sources) => {
    const x = (v) => uniquePos[v * 3];
    const y = (v) => uniquePos[v * 3 + 1];
    const z = (v) => uniquePos[v * 3 + 2];
    let px = 0;
    let py = 0;
    let pz = 0;
    for (const [v, c] of sources) {
      px += x(v) * c;
      py += y(v) * c;
      pz += z(v) * c;
    }
    outPosition[target * 3] = px;
    outPosition[target * 3 + 1] = py;
    outPosition[target * 3 + 2] = pz;
    if (outUv && uniqueUv) {
      let u = 0;
      let v = 0;
      for (const [src, c] of sources) {
        u += uniqueUv[src * 2] * c;
        v += uniqueUv[src * 2 + 1] * c;
      }
      outUv[target * 2] = u;
      outUv[target * 2 + 1] = v;
    }
    const acc = new Map();
    for (const [src, c] of sources) {
      const weights = uniqueSkin[src];
      if (!weights) continue;
      for (const [bone, weight] of weights) acc.set(bone, (acc.get(bone) || 0) + c * weight);
    }
    outSkin[target] = normalizeSkin(acc) || [];
  };

  for (let u = 0; u < uniqueCount; u++) {
    const list = [...neighbors[u]];
    const boundary = list.filter((v) => {
      const key = edgeKey(u, v);
      const edge = edges.get(key);
      return edge && edge.count === 1;
    });
    if (boundary.length >= 2) {
      // 边界保持：顶点与蒙皮权重都保持原样，边界折线 = 原折线中点细化，不产生分件裂缝。
      blend(u, [[u, 1]]);
    } else if (list.length >= 3) {
      const k = list.length;
      const beta = (1 / k) * (5 / 8 - (3 / 8 + 0.25 * Math.cos((2 * Math.PI) / k)) ** 2);
      const sources = [[u, 1 - k * beta]];
      for (const v of list) sources.push([v, beta]);
      blend(u, sources);
    } else {
      blend(u, [[u, 1]]);
    }
  }

  for (const edge of edges.values()) {
    const target = uniqueCount + edgeIndex.size;
    edgeIndex.set(edgeKey(edge.a, edge.b), target);
    let sources;
    if (edge.a === edge.b) {
      sources = [[edge.a, 1]];
    } else if (edge.count === 2 && edge.opposite.length === 2 && edge.opposite[0] !== edge.opposite[1]) {
      sources = [
        [edge.a, 3 / 8],
        [edge.b, 3 / 8],
        [edge.opposite[0], 1 / 8],
        [edge.opposite[1], 1 / 8],
      ];
    } else {
      sources = [[edge.a, 0.5], [edge.b, 0.5]];
    }
    blend(target, sources);
  }

  // 4) 组装几何：索引化 + computeVertexNormals() 得到平滑法线。
  const out = new THREE.BufferGeometry();
  out.setAttribute('position', new THREE.BufferAttribute(outPosition, 3));
  if (outUv) out.setAttribute('uv', new THREE.BufferAttribute(outUv, 2));
  const outIndex = new Uint16Array(outputCount * 4);
  const outWeight = new Float32Array(outputCount * 4);
  for (let i = 0; i < outputCount; i++) {
    const weights = outSkin[i] || [];
    for (let j = 0; j < 4; j++) {
      const entry = weights[j];
      outIndex[i * 4 + j] = entry ? entry[0] : 0;
      outWeight[i * 4 + j] = entry ? entry[1] : (j === 0 ? 1 : 0);
    }
  }
  out.setAttribute('skinIndex', new THREE.BufferAttribute(outIndex, 4));
  out.setAttribute('skinWeight', new THREE.BufferAttribute(outWeight, 4));
  const indices = new Uint32Array(triangles.length * 4);
  let cursor = 0;
  for (let t = 0; t < triangles.length; t += 3) {
    const a = triangles[t];
    const b = triangles[t + 1];
    const c = triangles[t + 2];
    const ab = edgeIndex.get(edgeKey(a, b));
    const bc = edgeIndex.get(edgeKey(b, c));
    const ca = edgeIndex.get(edgeKey(c, a));
    indices[cursor++] = a; indices[cursor++] = ab; indices[cursor++] = ca;
    indices[cursor++] = ab; indices[cursor++] = b; indices[cursor++] = bc;
    indices[cursor++] = ca; indices[cursor++] = bc; indices[cursor++] = c;
    indices[cursor++] = ab; indices[cursor++] = bc; indices[cursor++] = ca;
  }
  out.setIndex(new THREE.BufferAttribute(indices, 1));
  out.computeVertexNormals();
  out.userData = { source: 'skin-preserving-loop', mode: 'loop' };
  return out;
}
