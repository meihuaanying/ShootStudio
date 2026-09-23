// V7/S3.3 专项 QA（D138）：静帧导出（路径追踪 / 超采样）+ A/B 对比证据。
// 用法（工作目录 app/）：
//   node tool/light_still_qa.mjs [--gpu 1] [--headed 1] [--samples 2] [--w 320] [--h 240]
// 产物：
//   docs/screenshots/lighting-v6/still-path-r186s33.png      路径追踪静帧
//   docs/screenshots/lighting-v6/still-supersample-r186s33.png 超采样静帧
//   docs/screenshots/lighting-v6/ab-compare-r186s33.png      A/B 对比合成图
//   docs/qa/light-still-ab-s33.json                          耗时/差异统计
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import http from 'node:http';
import crypto from 'node:crypto';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const appRoot = path.resolve(here, '..');
const repoRoot = path.resolve(appRoot, '..');
const outShots = path.join(repoRoot, 'docs', 'screenshots', 'lighting-v6');
const outQa = path.join(repoRoot, 'docs', 'qa');

const EDGE_CANDIDATES = [
  'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
  'C:/Program Files/Microsoft/Edge/Application/msedge.exe',
  process.env.EDGE,
].filter(Boolean);
const MIME = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8', '.glb': 'model/gltf-binary',
  '.png': 'image/png', '.jpg': 'image/jpeg', '.hdr': 'application/octet-stream',
};
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith('--')) {
      const key = a.slice(2);
      const next = argv[i + 1];
      if (next !== undefined && !next.startsWith('--')) { out[key] = next; i++; }
      else out[key] = true;
    }
  }
  return out;
}

function startServer() {
  const server = http.createServer((req, res) => {
    let pathname = '/';
    try { pathname = decodeURIComponent(new URL(req.url, 'http://127.0.0.1').pathname); } catch (_) {}
    const full = path.normalize(path.join(appRoot, pathname));
    if (!full.startsWith(appRoot)) { res.writeHead(403); res.end('forbidden'); return; }
    fs.readFile(full, (err, data) => {
      if (err) { res.writeHead(404); res.end('not found'); return; }
      res.writeHead(200, {
        'Content-Type': MIME[path.extname(full).toLowerCase()] || 'application/octet-stream',
        'Cache-Control': 'no-store',
      });
      res.end(data);
    });
  });
  return new Promise((resolve) => {
    server.listen(0, '127.0.0.1', () => resolve({ server, port: server.address().port }));
  });
}

class CdpPage {
  constructor(wsUrl) { this.wsUrl = wsUrl; this.id = 0; this.pending = new Map(); }
  async open() {
    this.ws = new WebSocket(this.wsUrl);
    await new Promise((resolve, reject) => {
      this.ws.onopen = resolve;
      this.ws.onerror = () => reject(new Error('CDP 连接失败'));
    });
    this.ws.onmessage = (ev) => {
      const msg = JSON.parse(ev.data);
      if (msg.id && this.pending.has(msg.id)) { this.pending.get(msg.id)(msg); this.pending.delete(msg.id); }
    };
  }
  call(method, params = {}, timeoutMs = 600000) {
    return new Promise((resolve, reject) => {
      const id = ++this.id;
      const timer = setTimeout(() => { this.pending.delete(id); reject(new Error(`CDP 超时：${method}`)); }, timeoutMs);
      this.pending.set(id, (msg) => { clearTimeout(timer); resolve(msg); });
      this.ws.send(JSON.stringify({ id, method, params }));
    });
  }
  async evaluate(expression, timeoutMs = 600000) {
    const r = await this.call('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true }, timeoutMs);
    return r?.result?.result?.value;
  }
  async close() { try { this.ws.close(); } catch (_) {} }
}

async function startEdge(port, useGpu, headed) {
  const edge = EDGE_CANDIDATES.find((p) => fs.existsSync(p));
  if (!edge) throw new Error('未找到 msedge.exe，可用 EDGE 环境变量指定路径');
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'ss-stillqa-'));
  const args = [
    '--hide-scrollbars', '--mute-audio', '--no-first-run', '--no-default-browser-check',
    '--disable-extensions', '--window-size=900,700',
    `--remote-debugging-port=${port}`, `--user-data-dir=${profile}`, 'about:blank',
  ];
  if (!headed) args.unshift('--headless=new');
  if (!useGpu) args.splice(1, 0, '--disable-gpu', '--use-angle=swiftshader', '--enable-unsafe-swiftshader');
  else args.splice(1, 0, '--force_high_performance_gpu');
  const proc = spawn(edge, args, { stdio: 'ignore' });
  let version = null;
  for (let i = 0; i < 80; i++) {
    try {
      const r = await fetch(`http://127.0.0.1:${port}/json/version`);
      if (r.ok) { version = await r.json(); break; }
    } catch (_) {}
    await sleep(200);
  }
  if (!version) { proc.kill(); throw new Error('Edge headless 启动失败'); }
  return { proc, version };
}

function savePng(name, dataUrl) {
  const b64 = String(dataUrl || '').split(',').pop();
  if (!b64) return 0;
  const buf = Buffer.from(b64, 'base64');
  fs.mkdirSync(outShots, { recursive: true });
  fs.writeFileSync(path.join(outShots, name), buf);
  return buf.length;
}

function sha1(dataUrl) {
  const b64 = String(dataUrl || '').split(',').pop();
  if (!b64) return '';
  return crypto.createHash('sha1').update(Buffer.from(b64, 'base64')).digest('hex').slice(0, 12);
}

const args = parseArgs(process.argv.slice(2));
const useGpu = args.gpu === '1' || args.gpu === true;
const headed = args.headed === '1' || args.headed === true;
const { server, port } = await startServer();
const edgePort = 9950 + Math.floor(Math.random() * 40);
const edge = await startEdge(edgePort, useGpu, headed);
const info = await (await fetch(`http://127.0.0.1:${edgePort}/json/new?url=${encodeURIComponent('about:blank')}`, { method: 'PUT' })).json();
const page = new CdpPage(info.webSocketDebuggerUrl);
await page.open();

const report = {
  at: new Date().toISOString(),
  edge: edge.version['Browser'],
  gpu: useGpu,
  headed,
  stills: {},
  ab: {},
};
try {
  await page.call('Emulation.setDeviceMetricsOverride', { width: 900, height: 700, deviceScaleFactor: 1, mobile: false });
  await page.call('Page.enable');
  const url = `http://127.0.0.1:${port}/assets/engine/qa.html?char=qs-women-casual&view=0&duration=0&clean=1&lights=1`;
  await page.call('Page.navigate', { url });
  const deadline = Date.now() + 180000;
  let ready = false;
  while (Date.now() < deadline) {
    const value = await page.evaluate('window.__qaError ? ("ERR:" + window.__qaError) : (window.__qaReady === true ? "READY" : "")');
    if (typeof value === 'string' && value.startsWith('ERR:')) throw new Error(value.slice(4));
    if (value === 'READY') { ready = true; break; }
    await sleep(250);
  }
  if (!ready) throw new Error('qa 页面未就绪');
  console.log('[still-qa] 页面就绪，开始静帧导出');

  async function callStill(opts, label) {
    await page.evaluate(
      `window.__qaStillResult = null; window.__qaStillError = null; window.__ssOutbox = [];` +
      `window.ss.renderStill(${JSON.stringify(opts)}).then((r) => { window.__qaStillResult = r; })` +
      `.catch((e) => { window.__qaStillError = String((e && e.message) || e); }); 'started'`,
    );
    const deadline = Date.now() + 900000;
    let last = '';
    while (Date.now() < deadline) {
      const err = await page.evaluate('window.__qaStillError || null');
      if (err) throw new Error(`${label} 失败：${err}`);
      const res = await page.evaluate('window.__qaStillResult || null');
      if (res) return res;
      const progress = await page.evaluate(`(() => { const items = (window.__ssOutbox || []).filter((m) => m.includes('"type":"stillProgress"')); return items.length ? items[items.length - 1] : ''; })()`);
      if (progress && progress !== last) { last = progress; console.log(`[still-qa] ${label} 进度：${String(progress).slice(0, 150)}`); }
      await sleep(400);
    }
    throw new Error(`${label} 超时`);
  }

  // 1) 超采样静帧（快速模式）。
  const superResult = await callStill({ mode: 'supersample', width: 640, height: 480, factor: 2, useCameraRig: false }, '超采样');
  report.stills.supersample = {
    ok: superResult?.ok, mode: superResult?.mode, ms: superResult?.ms,
    width: superResult?.width, height: superResult?.height, factor: superResult?.factor,
  };
  const superBytes = savePng('still-supersample-r186s33.png', superResult?.dataUrl);
  report.stills.supersample.bytes = superBytes;
  console.log(`[still-qa] 超采样：${superResult?.ms}ms（${superBytes} bytes）`);

  // 2) 路径追踪静帧（首次 = 编译 + 采样；二次 = 程序缓存命中）。
  //    低配档（软件渲染）应自动回退超采样（R69），此处顺带验证降级路径。
  const samples = Number(args.samples || 2);
  const width = Number(args.w || 320);
  const height = Number(args.h || 240);
  const profile = await page.evaluate('window.ss.getPerformanceProfile()');
  report.profile = profile;
  if (profile && profile.effective === 'low') {
    const fallback = await callStill({ mode: 'path', width, height, samples, bounces: 3, useCameraRig: false }, '低配回退');
    report.stills.path = {
      ok: fallback?.ok, mode: fallback?.mode, requested: fallback?.requested,
      fallbackReason: fallback?.fallbackReason, ms: fallback?.ms,
      width: fallback?.width, height: fallback?.height,
    };
    console.log(`[still-qa] 低配档回退：mode=${fallback?.mode}（${fallback?.fallbackReason}）${fallback?.ms}ms`);
  } else {
    const path1 = await callStill({ mode: 'path', width, height, samples, bounces: 3, useCameraRig: false }, '路径追踪首次');
    const pathBytes = savePng('still-path-r186s33.png', path1?.dataUrl);
    report.stills.path = {
      ok: path1?.ok, mode: path1?.mode, reason: path1?.reason, ms: path1?.ms,
      samples: path1?.samples, width: path1?.width, height: path1?.height,
      msPerSample: path1?.msPerSample, bytes: pathBytes, sha1: sha1(path1?.dataUrl),
      error: path1?.error || '',
    };
    console.log(`[still-qa] 路径追踪首次：${path1?.ms}ms / ${path1?.samples} samples（${pathBytes} bytes）`);
    const path2 = await callStill({ mode: 'path', width, height, samples, bounces: 3, useCameraRig: false }, '路径追踪二次');
    report.stills.pathSecond = { ms: path2?.ms, samples: path2?.samples, msPerSample: path2?.msPerSample, sha1: sha1(path2?.dataUrl) };
    console.log(`[still-qa] 路径追踪二次：${path2?.ms}ms（缓存命中）`);
  }

  // 3) A/B 对比：同一场景，主光强度 75 → 25。
  await page.evaluate('window.__ssOutbox = []');
  const abScene = await page.evaluate(`(async () => {
    const lights = [
      { id: 'qa-key', type: 'hard', fixture: 'cob-600d', modifier: 'softbox-medium', x: 1.556, y: -1.556, height: 2.0, intensity: 75, kelvin: 5500, beamAngle: 55, softness: 0.4 },
      { id: 'qa-fill', type: 'soft', fixture: 'panel-120', modifier: 'diffusion-cloth', x: -1.838, y: -1.838, height: 1.7, intensity: 35, kelvin: 5500, beamAngle: 70, softness: 0.55 },
      { id: 'qa-rim', type: 'hard', fixture: 'cob-600d', modifier: 'honeycomb-grid', x: 0, y: 2.8, height: 2.5, intensity: 80, kelvin: 5500, beamAngle: 30, softness: 0.15 },
    ];
    window.ss.applyScene({ lights, props: [], subject: {} });
    await new Promise((r) => setTimeout(r, 600));
    return JSON.stringify(lights);
  })()`);
  await page.evaluate(`window.ss.capturePhoto('ab-a')`);
  const dataUrlA = await page.evaluate(`(() => { const items = (window.__ssOutbox || []).filter((m) => m.includes('"type":"captured"') && m.includes('"token":"ab-a"')); return items.length ? JSON.parse(items[items.length - 1]).dataUrl : null; })()`);
  if (!dataUrlA) throw new Error('A 快照取图失败');
  report.ab.lightsA = await page.evaluate('window.ss.getLightDebug()');
  // 变更布光：主光 75 → 25。
  await page.evaluate(`(() => {
    const lights = [
      { id: 'qa-key', type: 'hard', fixture: 'cob-600d', modifier: 'softbox-medium', x: 1.556, y: -1.556, height: 2.0, intensity: 25, kelvin: 5500, beamAngle: 55, softness: 0.4 },
      { id: 'qa-fill', type: 'soft', fixture: 'panel-120', modifier: 'diffusion-cloth', x: -1.838, y: -1.838, height: 1.7, intensity: 35, kelvin: 5500, beamAngle: 70, softness: 0.55 },
      { id: 'qa-rim', type: 'hard', fixture: 'cob-600d', modifier: 'honeycomb-grid', x: 0, y: 2.8, height: 2.5, intensity: 80, kelvin: 5500, beamAngle: 30, softness: 0.15 },
    ];
    window.ss.applyScene({ lights, props: [], subject: {} });
  })()`);
  await sleep(600);
  await page.evaluate(`window.ss.capturePhoto('ab-b')`);
  const dataUrlB = await page.evaluate(`(() => { const items = (window.__ssOutbox || []).filter((m) => m.includes('"type":"captured"') && m.includes('"token":"ab-b"')); return items.length ? JSON.parse(items[items.length - 1]).dataUrl : null; })()`);
  if (!dataUrlB) throw new Error('B 快照取图失败');
  report.ab.lightsB = await page.evaluate('window.ss.getLightDebug()');

  // 页内合成（与 Dart 侧 ab_compare 同口径：逐像素 RGB 平均差；阈值 12 计变化像素）。
  const compose = await page.evaluate(`(async () => {
    const load = (src) => new Promise((res, rej) => { const img = new Image(); img.onload = () => res(img); img.onerror = rej; img.src = src; });
    const a = await load(${JSON.stringify(dataUrlA)});
    const b = await load(${JSON.stringify(dataUrlB)});
    const w = 480, h = 360;
    const canvas = document.createElement('canvas');
    canvas.width = w * 2;
    canvas.height = h + 56;
    const ctx = canvas.getContext('2d');
    ctx.fillStyle = '#11151d';
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.drawImage(a, 0, 0, a.width, a.height, 0, 0, w, h);
    ctx.drawImage(b, 0, 0, b.width, b.height, w, 0, w, h);
    const read = (img) => {
      const c = document.createElement('canvas');
      c.width = w; c.height = h;
      const cx = c.getContext('2d');
      cx.drawImage(img, 0, 0, img.width, img.height, 0, 0, w, h);
      return cx.getImageData(0, 0, w, h).data;
    };
    const da = read(a), db = read(b);
    let sum = 0, changed = 0, max = 0;
    const n = w * h;
    for (let i = 0; i < da.length; i += 4) {
      const d = (Math.abs(da[i] - db[i]) + Math.abs(da[i + 1] - db[i + 1]) + Math.abs(da[i + 2] - db[i + 2])) / 3;
      sum += d;
      if (d > max) max = d;
      if (d > 12) changed++;
    }
    const meanAbs = Number((sum / n).toFixed(2));
    const changedRatio = Number((changed / n).toFixed(4));
    const verdict = changedRatio < 0.02 ? '差异轻微' : (changedRatio < 0.10 ? '差异中等' : '差异显著');
    ctx.font = '16px "Microsoft YaHei", sans-serif';
    ctx.fillStyle = '#e6ebf5';
    ctx.fillText('A 冻结', 12, h + 24);
    ctx.fillText('B 变更后（主光 75 → 25）', w + 12, h + 24);
    ctx.fillStyle = '#9fb0c8';
    ctx.font = '14px "Microsoft YaHei", sans-serif';
    ctx.fillText('平均差 ' + meanAbs + '/255 · 变化像素 ' + (changedRatio * 100).toFixed(1) + '% · ' + verdict + '（阈值 12/255）', 12, h + 46);
    return { dataUrl: canvas.toDataURL('image/png'), meanAbs, changedRatio, verdict, maxDelta: Number(max.toFixed(1)), width: w * 2, height: h + 56 };
  })()`);
  const abBytes = savePng('ab-compare-r186s33.png', compose?.dataUrl);
  const aBytes = savePng('ab-a-r186s33.png', dataUrlA);
  const bBytes = savePng('ab-b-r186s33.png', dataUrlB);
  report.ab = {
    meanAbs: compose?.meanAbs, changedRatio: compose?.changedRatio, verdict: compose?.verdict,
    maxDelta: compose?.maxDelta, bytes: abBytes, width: compose?.width, height: compose?.height,
    aBytes, bBytes, aSha1: sha1(dataUrlA), bSha1: sha1(dataUrlB),
    change: '主光 intensity 75 → 25（其余不变）',
  };
  console.log(`[still-qa] A/B：平均差 ${compose?.meanAbs}/255，变化像素 ${(compose?.changedRatio * 100).toFixed(1)}%（${compose?.verdict}） A=${report.ab.aSha1} B=${report.ab.bSha1}`);

  fs.mkdirSync(outQa, { recursive: true });
  fs.writeFileSync(path.join(outQa, 'light-still-ab-s33.json'), JSON.stringify(report, null, 2), 'utf8');
  console.log('[still-qa] 报告已写入 docs/qa/light-still-ab-s33.json');
  if (!report.stills.path?.ok || !report.stills.supersample?.ok || !compose?.dataUrl) process.exitCode = 1;
} finally {
  try { await page.close(); } catch (_) {}
  edge.proc.kill();
  server.close();
}
