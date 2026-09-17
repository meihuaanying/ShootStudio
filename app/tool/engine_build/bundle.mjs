// 引擎打包：把 ES Module 源码打成单文件 classic script，
// 规避 WebView 对 file:// 下 ES module / importmap 的兼容问题。
// 用法：node tool/engine_build/bundle.mjs
import { build } from 'esbuild';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const appRoot = path.resolve(here, '..', '..');
const engineDir = path.join(appRoot, 'assets', 'engine', 'js');

await build({
  entryPoints: [path.join(engineDir, 'engine.js')],
  outfile: path.join(engineDir, 'engine.bundle.js'),
  bundle: true,
  minify: true,
  format: 'iife',
  target: ['chrome90'],
  legalComments: 'none',
  alias: {
    three: path.join(engineDir, 'vendor', 'three.module.min.js'),
    'three/addons': path.join(engineDir, 'jsm'),
  },
  logLevel: 'info',
});
console.log('engine.bundle.js 已生成');
