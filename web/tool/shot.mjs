// V8/S1 设计 spike：官网样板页截图（R72：明暗双主题 × 1280×800 / 1920×1080）。
//
// 用法（在仓库根或 web/ 下均可）：
//   node web/tool/shot.mjs                     # 默认 4 张：web-hero × {paper,darkroom} × {1280x800,1920x1080}
//   node web/tool/shot.mjs --path=/features    # 换页面
// 前置：web/ 内已 `npm run build`（Astro 产出 dist/）。
// 输出：docs/screenshots/v8/s1-web-hero-<theme>-<w>x<h>.png + docs/qa/v8-s1-web-screenshots.json
//
// 说明：
//  - 主题用 URL 参数 ?t=darkroom 切换（spike-hero.astro 内联脚本），一次构建覆盖双主题；
//  - 字体用 web/public/fonts/NotoSerifSC-ShootStudio.otf（§3 令牌唯一来源同款子集字体）；
//  - 视口用 Emulation.setDeviceMetricsOverride 固定，不受窗口尺寸影响。

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import http from 'node:http';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const webRoot = path.resolve(here, '..');
const repoRoot = path.resolve(webRoot, '..');
const distDir = path.join(webRoot, 'dist');
const shotDir = path.join(repoRoot, 'docs', 'screenshots', 'v8');
const qaDir = path.join(repoRoot, 'docs', 'qa');

const argv = process.argv.slice(2);
const argOf = (name, dflt) => {
  const hit = argv.find((a) => a.startsWith(`--${name}=`));
  return hit ? hit.slice(name.length + 3) : dflt;
};
const pagePath = argOf('path', '/spike-hero');
const themes = argOf('themes', 'paper,darkroom').split(',').filter(Boolean);
const viewports = argOf('viewports', '1280x800,1920x1080').split(',').filter(Boolean);

if (!fs.existsSync(path.join(distDir, 'index.html'))) {
  console.error('[shot] 未找到 web/dist/index.html：请先在 web/ 执行 npm run build');
  process.exit(2);
}
fs.mkdirSync(shotDir, { recursive: true });
fs.mkdirSync(qaDir, { recursive: true });

const EDGE = [
  'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
  'C:/Program Files/Microsoft/Edge/Application/msedge.exe',
].find((p) => fs.existsSync(p));
if (!EDGE) {
  console.error('[shot] 未找到 Edge 可执行文件');
  process.exit(2);
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.otf': 'font/otf',
  '.ttf': 'font/ttf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.txt': 'text/plain; charset=utf-8',
  '.xml': 'application/xml; charset=utf-8',
  '.ico': 'image/x-icon',
};

const server = http.createServer((req, res) => {
  let pathname = decodeURIComponent(new URL(req.url, 'http://127.0.0.1').pathname);
  if (pathname.endsWith('/')) pathname += 'index.html';
  const file = path.join(distDir, pathname);
  if (!file.startsWith(distDir)) { res.writeHead(403); res.end(); return; }
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404); res.end('not found'); return; }
    res.writeHead(200, {
      'Content-Type': MIME[path.extname(pathname).toLowerCase()] || 'application/octet-stream',
      'Cache-Control': 'no-store',
    });
    res.end(data);
  });
});
await new Promise((r) => server.listen(0, '127.0.0.1', r));
const serverPort = server.address().port;

const edgePort = 9991;
const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'ss-webshot-'));
const proc = spawn(EDGE, [
  '--headless=new',
  '--hide-scrollbars',
  '--no-first-run',
  '--no-default-browser-check',
  '--force-device-scale-factor=1',
  '--disable-lcd-text',
  '--font-render-hinting=none',
  `--remote-debugging-port=${edgePort}`,
  `--user-data-dir=${profile}`,
  'about:blank',
], { stdio: 'ignore' });

const shots = [];
let failed = 0;
try {
  let ready = false;
  for (let i = 0; i < 100; i++) {
    try { if ((await fetch(`http://127.0.0.1:${edgePort}/json/version`)).ok) { ready = true; break; } } catch (_) { /* retry */ }
    await sleep(200);
  }
  if (!ready) throw new Error('Edge 调试端口未就绪');
  const target = await (await fetch(`http://127.0.0.1:${edgePort}/json/new?url=about:blank`, { method: 'PUT' })).json();
  const ws = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((res, rej) => { ws.onopen = res; ws.onerror = rej; });
  let id = 0;
  const pending = new Map();
  ws.onmessage = (ev) => {
    const m = JSON.parse(ev.data);
    if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); }
  };
  const call = (method, params = {}) => new Promise((res) => {
    const i = ++id;
    pending.set(i, res);
    ws.send(JSON.stringify({ id: i, method, params }));
  });
  const ev = async (expr) => {
    const r = await call('Runtime.evaluate', { expression: expr, returnByValue: true, awaitPromise: true });
    if (r?.result?.exceptionDetails) {
      console.log('  [JS 异常]', JSON.stringify(r.result.exceptionDetails).slice(0, 300));
    }
    return r?.result?.result?.value;
  };
  await call('Page.enable');
  await call('Runtime.enable');

  for (const theme of themes) {
    for (const vp of viewports) {
      const [w, h] = vp.split('x').map(Number);
      await call('Emulation.setDeviceMetricsOverride', {
        width: w, height: h, deviceScaleFactor: 1, mobile: false,
      });
      const url = `http://127.0.0.1:${serverPort}${pagePath}/?t=${encodeURIComponent(theme)}`;
      await call('Page.navigate', { url });
      let loaded = false;
      for (let i = 0; i < 120; i++) {
        const state = await ev("document.readyState === 'complete' && document.documentElement.classList.contains('spike-ready')");
        if (state) { loaded = true; break; }
        await sleep(150);
      }
      if (!loaded) console.log(`  [warn] ${theme}/${vp} 就绪标记超时，仍尝试截图`);
      await ev('document.fonts.ready.then(() => true)');
      await sleep(350);
      const info = await ev('JSON.stringify({theme: document.documentElement.getAttribute("data-theme"), fonts: document.fonts.status, h: document.body.scrollHeight})');
      const meta = info ? JSON.parse(info) : {};
      const cap = await call('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false, fromSurface: true });
      const data = cap?.result?.data;
      const name = `s1-web-hero-${theme}-${vp}`;
      if (!data) {
        console.error(`[shot] 截图失败：${name}`);
        failed += 1;
        continue;
      }
      const buf = Buffer.from(data, 'base64');
      fs.writeFileSync(path.join(shotDir, `${name}.png`), buf);
      shots.push({
        name, page: 'web-hero', theme, size: vp, bytes: buf.length,
        domTheme: meta.theme ?? null, fontsStatus: meta.fonts ?? null, scrollHeight: meta.h ?? null,
      });
      console.log(`[shot] ${name}.png  ${buf.length} B  theme=${meta.theme} fonts=${meta.fonts}`);
    }
  }
  ws.close();
} finally {
  try { proc.kill(); } catch (_) { /* ignore */ }
  server.close();
  try { fs.rmSync(profile, { recursive: true, force: true }); } catch (_) { /* ignore */ }
}

const payload = {
  version: 1,
  note: 'V8/S1 设计 spike · 官网样板页截图（R72：明暗双主题 × 1280×800 / 1920×1080）',
  at: new Date().toISOString(),
  path: pagePath,
  themes,
  viewports,
  count: shots.length,
  shots,
};
const outJson = path.join(qaDir, 'v8-s1-web-screenshots.json');
fs.writeFileSync(outJson, `${JSON.stringify(payload, null, 2)}\n`);
console.log(`[shot] 写出 ${shots.length} 张 → ${path.relative(repoRoot, shotDir)}；索引 ${path.relative(repoRoot, outJson)}`);
if (failed) process.exit(1);
