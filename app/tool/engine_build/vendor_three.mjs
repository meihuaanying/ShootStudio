// three.js vendor 重建脚本（V7/D136）。
//
// 背景：three r18x 起 `build/` 不再提供自包含的 minified ESM（three.module.min.js 已移除，
// 且 three.module.js 依赖同目录 three.core.js），而引擎 bundle 需要单文件 `three` 别名。
// 本脚本用项目 esbuild 把官方源码打成自包含 minified ESM，产出与旧版 vendor 文件同形态。
//
// 用法（工作目录 app/）：
//   cd tool/engine_build && npm install three@<version> --no-save && cd ../..
//   node tool/engine_build/vendor_three.mjs <version>
//   # 例如：node tool/engine_build/vendor_three.mjs 0.186.0
//
// 随后按需同步 examples/jsm 下的 addons（见 HANDOFF_V7.md §2 S3.1 清单）并重打 bundle：
//   node tool/engine_build/bundle.mjs
import { build } from 'esbuild';
import { fileURLToPath } from 'node:url';
import fs from 'node:fs';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const appRoot = path.resolve(here, '..', '..');
const version = (process.argv[2] || '').trim();
if (!version) {
  console.error('用法：node tool/engine_build/vendor_three.mjs <three-version>（如 0.186.0）');
  process.exit(1);
}

const pkgDir = path.join(here, 'node_modules', 'three');
const entry = path.join(pkgDir, 'build', 'three.module.js');
if (!fs.existsSync(entry)) {
  console.error(`未找到 ${entry}；请先：cd tool/engine_build && npm install three@${version} --no-save`);
  process.exit(1);
}

const license = fs
  .readFileSync(path.join(pkgDir, 'LICENSE'), 'utf8')
  .split('\n')
  .map((line) => (line.trim() ? ` * ${line}` : ' *'))
  .join('\n');

const outfile = path.join(appRoot, 'assets', 'engine', 'js', 'vendor', 'three.module.min.js');
await build({
  entryPoints: [entry],
  outfile,
  bundle: true,
  minify: true,
  format: 'esm',
  target: ['chrome90'],
  legalComments: 'none',
  banner: { js: `/**\n * three.js r${version.split('.')[1]} (three@${version}) — MIT License\n *\n${license}\n */` },
  logLevel: 'info',
});

fs.copyFileSync(
  path.join(pkgDir, 'LICENSE'),
  path.join(appRoot, 'assets', 'engine', 'js', 'vendor', 'THREE_LICENSE'),
);
console.log(`vendor/three.module.min.js 已生成（three@${version}）`);
