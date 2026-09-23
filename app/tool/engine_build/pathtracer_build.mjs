// 路径追踪器打包（V7/D138）：把 three-gpu-pathtracer 打成可在 file:// 下加载的 classic 脚本。
//
// 背景：WebView 对 file:// 下的 ES module / importmap 兼容性差（见 bundle.mjs），
// 因此路径追踪器以独立 IIFE 产物按需加载（window.SSPathTracer），不拖慢引擎启动。
// 为避免打包出第二份 three（跨拷贝 instanceof/原型问题 + 体积），本脚本自动生成
// 全局 shim：three-gpu-pathtracer 与 three-mesh-bvh 的 'three' 导入全部指向引擎
// 已加载的同一份 three（引擎启动时暴露 window.__ssThree）。
//
// 用法（工作目录 app/）：
//   cd tool/engine_build && npm install three@0.186.0 three-gpu-pathtracer@0.0.24 three-mesh-bvh@0.9.15 --no-save --legacy-peer-deps && cd ../..
//   node tool/engine_build/pathtracer_build.mjs
import { build } from 'esbuild';
import { fileURLToPath } from 'node:url';
import fs from 'node:fs';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const appRoot = path.resolve(here, '..', '..');
const engineDir = path.join(appRoot, 'assets', 'engine', 'js');

const vendoredThree = path.join(engineDir, 'vendor', 'three.module.min.js');
const ptPkg = path.join(here, 'node_modules', 'three-gpu-pathtracer');
const bvhPkg = path.join(here, 'node_modules', 'three-mesh-bvh');
for (const p of [vendoredThree, path.join(ptPkg, 'package.json'), path.join(bvhPkg, 'package.json')]) {
  if (!fs.existsSync(p)) {
    console.error(`缺少 ${p}；请先按文件头部注释安装依赖`);
    process.exit(1);
  }
}

// 1) 从 vendored three 的末尾 export{} 中提取导出名，生成全局 shim（ESM 命名导出 → 全局对象属性）。
const threeSource = fs.readFileSync(vendoredThree, 'utf8');
const match = threeSource.match(/export\s*\{([^}]*)\}\s*;?\s*$/);
if (!match) {
  console.error('无法解析 vendored three 的导出列表（格式变化？）');
  process.exit(1);
}
const names = match[1]
  .split(',')
  .map((item) => item.trim())
  .filter(Boolean)
  .map((item) => {
    const m = item.match(/^(?:[\w$]+)\s+as\s+([\w$]+)$/);
    return m ? m[1] : item;
  });
const genDir = path.join(here, '.gen');
fs.mkdirSync(genDir, { recursive: true });
const shimPath = path.join(genDir, 'three_global_shim.js');
fs.writeFileSync(
  shimPath,
  [
    '// 自动生成（pathtracer_build.mjs）：把引擎已加载的同一份 three 转成 ESM 命名导出。',
    'const T = globalThis.__ssThree;',
    "if (!T) throw new Error('three_global_shim：window.__ssThree 未设置（引擎未就绪？）');",
    ...names.map((n) => `export const ${n} = T.${n};`),
    'export default T;',
    '',
  ].join('\n'),
  'utf8',
);
console.log(`[pathtracer] shim 生成：${names.length} 个导出`);

// 2) 打包为 IIFE classic 脚本（window.SSPathTracer）。
const ptVersion = JSON.parse(fs.readFileSync(path.join(ptPkg, 'package.json'), 'utf8')).version;
const bvhVersion = JSON.parse(fs.readFileSync(path.join(bvhPkg, 'package.json'), 'utf8')).version;
await build({
  entryPoints: [path.join(ptPkg, 'src', 'index.js')],
  outfile: path.join(engineDir, 'pathtracer.bundle.js'),
  bundle: true,
  minify: true,
  format: 'iife',
  globalName: 'SSPathTracer',
  target: ['chrome90'],
  legalComments: 'none',
  alias: {
    three: shimPath,
    'three/examples/jsm': path.join(engineDir, 'jsm'),
  },
  banner: {
    js: `/**\n * three-gpu-pathtracer@${ptVersion} + three-mesh-bvh@${bvhVersion}（均 MIT）\n * 打包产物：仅含路径追踪器，three 复用 window.__ssThree（引擎 vendor 版）。\n */`,
  },
  logLevel: 'info',
});

// 3) 许可与 NOTICE 素材（R63/R64：第三方许可随包登记）。
fs.copyFileSync(
  path.join(ptPkg, 'LICENSE'),
  path.join(engineDir, 'vendor', 'PATHTRACER_LICENSE'),
);
fs.copyFileSync(
  path.join(bvhPkg, 'LICENSE'),
  path.join(engineDir, 'vendor', 'MESHBVH_LICENSE'),
);
console.log('assets/engine/js/pathtracer.bundle.js 已生成（vendor/PATHTRACER_LICENSE、vendor/MESHBVH_LICENSE 同步）');
