// V8/P3 · D157 首屏图宽门禁：首屏真实产品截图必须 >= 50% 视口宽。
//
// 用法：node tool/hero_gate.mjs        （前置：web/ 已 npm run build）
// 退出码：0 = PASS，1 = FAIL（占比不足 / 图片被裁 / 文档横向溢出），2 = 环境不可用。
//
// ── 为什么需要这条门禁 ──
//
// 合同 §5 首页条款写得很死：「首屏 = 真实产品静帧/截图大图（**≥50% 视口宽**）
// + 衬线大标题 + 双下载 CTA」。但在 V8.5 之前，这个「≥50%」**没有任何门禁在守**：
// shot_s10.mjs 只截 30 张图（人看），不量任何宽度，所以这条合同条款实际处于
// 「靠自觉」状态 —— 而它当时就已经不达标了：
//
//   实测（V8.5 探针，改动前）：
//     vw=1280  imgW=637.4  pctViewport=49.79%   ← 差 0.21pp
//     vw=1920  imgW=637.4  pctViewport=33.2%    ← 差 16.8pp
//   根因：hero 容器 max-w-[1280px] 把栅格封顶，figure 落在 1.08/2 的列里，
//   图宽被钉死在 637.4px，视口再大也不增长。
//
// 这正是 R82 点名的反模式：条款写了、没人验，于是「不达标」可以一直存在。
// 本门禁把它变成 CI 会红的事。
//
// ── 判据（三选一不过就红）──
//
//   1. 每个视口下首屏图的宽度 >= 50% 视口宽（照合同字面口径量 img，不是量容器）；
//   2. 图片右缘不出视口（**必须单独查**：全站 html/body 是 overflow-x:hidden，
//      越界会被静默裁掉 —— 只看 scrollWidth 是查不出来的，图已经没了）；
//   3. 文档横向溢出 = 0（scrollWidth <= innerWidth），即别把整页拱出横向滚动。
//
// 视口覆盖：[1024,768] 是 lg 断点下界（最容易越界的最小档），[2560,1440] 是最宽档，
// 中间覆盖截图门禁在用的 1280x800 / 1920x1080 两档。
//
// 手持档（390x844）不在本门禁范围：该档首屏是单列堆叠，图宽天然 100%，
// 不需要额外守（见 shot_s10.mjs 移动档截图）。

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import http from 'node:http';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const webRoot = path.resolve(here, '..');
const distDir = path.join(webRoot, 'dist');
if (!fs.existsSync(path.join(distDir, 'index.html'))) {
  console.error('[hero-gate] 缺 dist/index.html，请先 npm run build');
  process.exit(2);
}

// 与 engine_perf_qa / shot_s10 同因：Node 22.4+ 才有可用的 WebSocket。
let WebSocketCtor = null;
try { ({ WebSocket: WebSocketCtor } = await import('node:http')); } catch { /* 旧版无 */ }
if (typeof WebSocketCtor !== 'function' && typeof globalThis.WebSocket === 'function') {
  WebSocketCtor = globalThis.WebSocket;
}
if (typeof WebSocketCtor !== 'function') {
  console.error('[hero-gate] 无 WebSocket 实现，需 Node 22.4+');
  process.exit(2);
}

const MIME = {
  '.html': 'text/html; charset=utf-8', '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8', '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json', '.svg': 'image/svg+xml', '.png': 'image/png',
  '.jpg': 'image/jpeg', '.woff2': 'font/woff2', '.otf': 'font/otf', '.ttf': 'font/ttf',
};

const server = http.createServer((req, res) => {
  const p = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  const f = path.join(distDir, p === '/' ? 'index.html' : p);
  if (!f.startsWith(distDir) || !fs.existsSync(f)) { res.writeHead(404); res.end('nf'); return; }
  res.writeHead(200, { 'Content-Type': MIME[path.extname(f)] || 'application/octet-stream' });
  res.end(fs.readFileSync(f));
});
await new Promise((r) => server.listen(0, '127.0.0.1', r));
const port = server.address().port;

function edgeExecutable() {
  if (process.env.SS_EDGE && fs.existsSync(process.env.SS_EDGE)) return process.env.SS_EDGE;
  const candidates = process.platform === 'win32'
    ? ['C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
       'C:/Program Files/Microsoft/Edge/Application/msedge.exe']
    : ['/usr/bin/microsoft-edge-stable', '/usr/bin/microsoft-edge'];
  return candidates.find((p) => fs.existsSync(p));
}

const edgePort = 9996;
const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'ss-hero-gate-'));
const edge = spawn(edgeExecutable(), [
  '--headless=new', '--no-sandbox', '--hide-scrollbars',
  `--remote-debugging-port=${edgePort}`, `--user-data-dir=${profile}`, 'about:blank',
], { stdio: 'ignore' });

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let target = null;
for (let i = 0; i < 80; i++) {
  try {
    const r = await fetch(`http://127.0.0.1:${edgePort}/json/new?url=about:blank`, { method: 'PUT' });
    if (r.ok) { target = await r.json(); break; }
  } catch { /* 还没起来 */ }
  await sleep(250);
}
if (!target) {
  console.error('[hero-gate] Edge 未就绪');
  edge.kill(); server.close();
  process.exit(2);
}

const ws = new WebSocketCtor(target.webSocketDebuggerUrl);
await new Promise((res, rej) => { ws.onopen = res; ws.onerror = rej; });
let msgId = 0;
const pending = new Map();
ws.onmessage = (e) => {
  const m = JSON.parse(e.data);
  if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); }
};
const cmd = (method, params = {}) => new Promise((res) => {
  const id = ++msgId;
  pending.set(id, res);
  ws.send(JSON.stringify({ id, method, params }));
});

const MIN_PCT = 50;
const VIEWPORTS = [
  [1024, 768],    // lg 断点下界：越界风险最大的一档
  [1280, 800], [1920, 1080],  // 与 shot_s10.mjs 一致的两档桌面视口
  [2560, 1440],   // 最宽档：封顶失效类改动在这里现形
];

let failed = 0;
const check = (name, cond, detail = '') => {
  console.log(`  ${cond ? 'PASS' : 'FAIL'} ${name}${detail ? ' :: ' + detail : ''}`);
  if (!cond) failed++;
};

const rows = [];
for (const [w, h] of VIEWPORTS) {
  await cmd('Emulation.setDeviceMetricsOverride',
    { width: w, height: h, deviceScaleFactor: 1, mobile: false });
  await cmd('Page.navigate', { url: `http://127.0.0.1:${port}/` });
  await sleep(1800);
  const r = await cmd('Runtime.evaluate', {
    expression: `(() => {
      const fig = document.querySelector('[data-hero-visual]');
      const img = fig && fig.querySelector('img');
      if (!img) return JSON.stringify({ ok: false, why: '未找到 [data-hero-visual] 里的 img' });
      const b = img.getBoundingClientRect();
      return JSON.stringify({
        ok: true,
        vw: window.innerWidth,
        imgW: +b.width.toFixed(1),
        imgRight: +b.right.toFixed(1),
        rightGap: +(window.innerWidth - b.right).toFixed(1),
        pctViewport: +((b.width / window.innerWidth) * 100).toFixed(2),
        naturalW: img.naturalWidth,
        complete: img.complete,
        docOverflow: document.documentElement.scrollWidth - window.innerWidth,
      });
    })()`,
    returnByValue: true,
  });
  const v = JSON.parse(r.result?.result?.value || '{}');
  const tag = `${w}x${h}`;
  if (!v.ok) {
    check(`${tag} 首屏图存在`, false, v.why || '');
    rows.push({ viewport: tag, ok: false, why: v.why });
    continue;
  }
  // 图没加载完就没有尺寸可言 —— 先排除这一种假绿。
  check(`${tag} 图片已加载`, v.complete === true && v.naturalW > 0,
    `complete=${v.complete} natural=${v.naturalW}`);
  check(`${tag} 图宽 >= ${MIN_PCT}% 视口宽`, v.pctViewport >= MIN_PCT,
    `${v.pctViewport}% (imgW=${v.imgW} / vw=${v.vw})`);
  check(`${tag} 图未被裁（右缘在视口内）`, v.imgRight <= v.vw + 0.5,
    `右缘余量=${v.rightGap}px`);
  check(`${tag} 文档无横向溢出`, v.docOverflow <= 0, `overflow=${v.docOverflow}px`);
  rows.push({ viewport: tag, ...v });
}

console.log(`[hero-gate] ${failed === 0 ? 'PASS' : `FAIL (${failed})`}`);

const evidence = {
  gate: 'D157 首屏图宽（>= 50% 视口宽）',
  at: new Date().toISOString(),
  minPctRequired: MIN_PCT,
  verdict: failed === 0 ? 'PASS' : 'FAIL',
  failedChecks: failed,
  rows,
};
const evDir = path.resolve(webRoot, '..', 'docs', 'qa');
fs.writeFileSync(path.join(evDir, 'v8-6-hero-width-gate.json'),
  `${JSON.stringify(evidence, null, 2)}\n`);

ws.close();
edge.kill();
server.close();
process.exit(failed === 0 ? 0 : 1);
