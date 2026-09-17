// Q1 高面数（D62/R18/R26）：为 assets/models/characters/manifest.json 登记运行时细分后的
// 三角面数。细分在引擎运行时执行（character.js / subdivision.js），因此本工具不重写 GLB，
// 只计算并写回元数据（triCount），并校验每个角色落入 40k–120k。
// 用法（工作目录 app/）：node tool/subdivide_characters.mjs [--dry-run]
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  planSubdivision,
  plannedTriangles,
  levelTargets,
} from '../assets/engine/js/subdivision_plan.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const appRoot = path.resolve(here, '..');
const modelDir = path.join(appRoot, 'assets', 'models', 'characters');
const manifestPath = path.join(modelDir, 'manifest.json');
const realisticDir = path.join(modelDir, 'realistic');

// D64：精选内置 2–4 个（男女各 1–2），其余保留原 GLB 作为轻量模式（R26）并记录下载来源。
const BUNDLED_IDS = new Set(['qs-men-casual', 'qs-women-casual', 'qs-men-suit']);
const DEFAULT_DOWNLOAD_BASE = 'https://raw.githubusercontent.com/trebeljahr/quaternius-showcase/main/public/glb';

const args = process.argv.slice(2);
const dryRun = args.includes('--dry-run');

function readGLB(filePath) {
  const buffer = fs.readFileSync(filePath);
  if (buffer.readUInt32LE(0) !== 0x46546c67) throw new Error(`不是 GLB：${filePath}`);
  const jsonLength = buffer.readUInt32LE(12);
  return JSON.parse(buffer.subarray(20, 20 + jsonLength).toString('utf8'));
}

// 每个 glTF primitive 会被 GLTFLoader 实例化为一个独立网格，按 primitive 统计
// 才能与运行时 planSubdivision 的输入一致。
function primitiveTriangleCounts(json) {
  const counts = [];
  for (const mesh of json.meshes || []) {
    for (const primitive of mesh.primitives || []) {
      if (primitive.mode !== undefined && primitive.mode !== 4) continue;
      const accessor = primitive.indices != null
        ? json.accessors[primitive.indices]
        : json.accessors[primitive.attributes?.POSITION];
      if (!accessor) continue;
      counts.push(Math.round(accessor.count / 3));
    }
  }
  return counts;
}

function inspectCharacter(entry) {
  const filePath = path.join(modelDir, entry.file);
  if (!fs.existsSync(filePath)) {
    throw new Error(`缺少 GLB：${entry.file}`);
  }
  const json = readGLB(filePath);
  const counts = primitiveTriangleCounts(json);
  const plan = planSubdivision(counts, 1);
  const base = counts.reduce((a, b) => a + b, 0);
  const total = plannedTriangles(counts, 1);
  const skinned = counts.length > 0
    && (json.meshes || []).every((m) => (m.primitives || []).every((p) => p.attributes?.JOINTS_0 != null));
  return { base, total, plan, meshes: counts.length, skinned };
}

function inspectRealistic() {
  if (!fs.existsSync(realisticDir)) return null;
  const files = fs.readdirSync(realisticDir).filter((f) => f.endsWith('.glb')).sort();
  if (!files.length) return null;
  const items = [];
  for (const file of files) {
    const counts = primitiveTriangleCounts(readGLB(path.join(realisticDir, file)));
    items.push({
      file: `realistic/${file}`,
      baseTriCount: counts.reduce((a, b) => a + b, 0),
      triCount: plannedTriangles(counts, 1),
    });
  }
  return items;
}

const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
const characters = Array.isArray(manifest.characters) ? manifest.characters : [];
console.log(`[subdivide] manifest ${characters.length} 个角色，默认 level=1（运行时 Loop 细分，不重写 GLB）`);
const report = [];
let failed = 0;
for (const entry of characters) {
  const info = inspectCharacter(entry);
  const { min, max } = levelTargets(1);
  const ok = info.total >= min && info.total <= 120000;
  if (!ok) failed += 1;
  entry.triCount = info.total;
  entry.baseTriCount = info.base;
  entry.subdivision = {
    mode: 'runtime-loop',
    level: 1,
    meshIterations: info.plan,
    target: [min, max],
  };
  entry.bundled = BUNDLED_IDS.has(entry.id);
  if (entry.bundled) {
    delete entry.downloadUrl;
    delete entry.needsDownload;
  } else {
    entry.downloadUrl = entry.source || `${DEFAULT_DOWNLOAD_BASE}/modular_${entry.gender === 'female' ? 'women' : 'men'}/${entry.file.replace(/^qs_(men|women)_/, '')}`;
    entry.needsDownload = false; // 原 GLB 已随包（R26 轻量资源），此处仅登记云端来源
  }
  report.push({
    id: entry.id,
    base: info.base,
    triCount: info.total,
    plan: info.plan.join('+'),
    bundled: entry.bundled,
    ok,
  });
  console.log(
    `  ${ok ? 'OK ' : '!! '}${entry.id.padEnd(22)} base=${String(info.base).padStart(6)} → triCount=${String(info.total).padStart(6)} (iters: ${info.plan.join(',')}) bundled=${entry.bundled}`,
  );
}

const realistic = inspectRealistic();
manifest.realisticAvailable = !!realistic;
if (realistic) {
  manifest.realistic = {
    note: 'D61 写实模式：MakeHuman 官方便携版/资产直链不可达，采用 CC-BY 4.0 等价写实替代（Cesium Man），triCount 为运行时细分默认值。',
    items: realistic.map((r) => ({ ...r, subdivision: { mode: 'runtime-loop', level: 1 } })),
  };
  for (const item of realistic) {
    console.log(`  [realistic] ${item.file} base=${item.baseTriCount} → triCount=${item.triCount}`);
  }
} else {
  manifest.realistic = manifest.realistic || {
    note: 'D61 写实模式待办：MakeHuman 官方管线不可达，暂无可直接用于 glTF 的写实角色。',
    items: [],
  };
  console.log('  [realistic] 无可用的写实 GLB，realisticAvailable=false');
}

manifest.subdivision = {
  mode: 'runtime-loop',
  defaultLevel: 1,
  levels: [0, 1, 2],
  implementation: 'skin-preserving-loop (three-subdivide vendored, MIT)',
  targetTriangles: levelTargets(1),
  hardMaxTriangles: 120000,
};

if (failed) {
  console.error(`[subdivide] ${failed} 个角色面数不在 40k–120k，请检查 planSubdivision 参数`);
  process.exitCode = 1;
}
if (!dryRun) {
  fs.writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`, 'utf8');
  console.log(`[subdivide] 已写回 ${path.relative(appRoot, manifestPath)}（triCount/bundled/subdivision/realisticAvailable）`);
} else {
  console.log('[subdivide] --dry-run：未写入 manifest');
}
