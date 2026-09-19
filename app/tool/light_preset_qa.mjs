// V6 阶段 B 门禁：27 套布光预设渲染（after 引擎）与指定 before 引擎对比。
// 用法（工作目录 app/）：
//   node tool/light_preset_qa.mjs [--out docs/screenshots/lighting-v6] [--char qs-women-casual]
//        [--cones 1] [--ids three-point,butterfly] [--bundle <path>] [--suffix after]
// 说明：--bundle 可指向任意 engine.bundle.js（如从 git 取出的旧版本），用于 before/after 对比。
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import http from 'node:http';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const appRoot = path.resolve(here, '..');
const repoRoot = path.resolve(appRoot, '..');

const EDGE_CANDIDATES = [
  'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
  'C:/Program Files/Microsoft/Edge/Application/msedge.exe',
  process.env.EDGE,
].filter(Boolean);

const MIME = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8', '.glb': 'model/gltf-binary',
  '.png': 'image/png', '.jpg': 'image/jpeg', '.css': 'text/css; charset=utf-8',
  '.hdr': 'application/octet-stream',
};
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function parseArgs(argv) {
  const out = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith('--')) {
      const key = a.slice(2);
      const next = argv[i + 1];
      if (next !== undefined && !next.startsWith('--')) { out[key] = next; i++; }
      else out[key] = true;
    } else out._.push(a);
  }
  return out;
}

function startServer(bundleOverride) {
  const server = http.createServer((req, res) => {
    let pathname = '/';
    try { pathname = decodeURIComponent(new URL(req.url, 'http://127.0.0.1').pathname); } catch (_) {}
    if (pathname === '/') pathname = '/assets/engine/qa.html';
    if (bundleOverride && pathname === '/assets/engine/js/engine.bundle.js') {
      res.writeHead(200, { 'Content-Type': 'text/javascript; charset=utf-8', 'Cache-Control': 'no-store' });
      res.end(fs.readFileSync(bundleOverride));
      return;
    }
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
  call(method, params = {}, timeoutMs = 60000) {
    return new Promise((resolve, reject) => {
      const id = ++this.id;
      const timer = setTimeout(() => { this.pending.delete(id); reject(new Error(`CDP 超时：${method}`)); }, timeoutMs);
      this.pending.set(id, (msg) => { clearTimeout(timer); resolve(msg); });
      this.ws.send(JSON.stringify({ id, method, params }));
    });
  }
  async evaluate(expression, timeoutMs = 60000) {
    const r = await this.call('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true }, timeoutMs);
    return r?.result?.result?.value;
  }
  async close() { try { this.ws.close(); } catch (_) {} }
}

async function startEdge(port) {
  const edge = EDGE_CANDIDATES.find((p) => fs.existsSync(p));
  if (!edge) throw new Error('未找到 msedge.exe，可用 EDGE 环境变量指定路径');
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'ss-lpqa-'));
  const proc = spawn(edge, [
    '--headless=new', '--disable-gpu', '--use-angle=swiftshader', '--enable-unsafe-swiftshader',
    '--hide-scrollbars', '--mute-audio', '--no-first-run', '--no-default-browser-check',
    '--disable-extensions', '--window-size=560,760',
    `--remote-debugging-port=${port}`, `--user-data-dir=${profile}`, 'about:blank',
  ], { stdio: 'ignore' });
  let version = null;
  for (let i = 0; i < 80; i++) {
    try {
      const r = await fetch(`http://127.0.0.1:${port}/json/version`);
      if (r.ok) { version = await r.json(); break; }
    } catch (_) {}
    await sleep(200);
  }
  if (!version) { proc.kill(); throw new Error('Edge headless 启动失败'); }
  return { proc, profile };
}

function toEngineLights(preset) {
  return (preset.devices || []).map((d, i) => ({
    id: `lp-${preset.id}-${i}`,
    type: d.type || 'hard',
    fixture: d.fixture || 'cob-600d',
    modifier: d.modifier || 'bare',
    x: d.x ?? 0, y: d.y ?? 0, height: d.height ?? 1.9,
    intensity: d.intensity ?? 60, kelvin: d.kelvin ?? 5500,
    beamAngle: d.beamAngle ?? 45, softness: d.softness ?? 0.15,
    color: d.color || '#ffffff',
    rotationY: d.rotationY ?? 0,
    offsetYaw: d.offsetYaw ?? 0,
    offsetPitch: d.offsetPitch ?? 0,
    stand: d.stand || 'normal',
    on: true,
  }));
}

const args = parseArgs(process.argv.slice(2));
const outDir = path.resolve(repoRoot, args.out || path.join('docs', 'screenshots', 'lighting-v6'));
const charId = String(args.char || 'qs-women-casual');
const suffix = String(args.suffix || 'after');
const withCones = args.cones === '1' || args.cones === true;
const bundleOverride = args.bundle ? path.resolve(String(args.bundle)) : null;
const presetData = JSON.parse(fs.readFileSync(
  path.join(appRoot, 'assets', 'content', 'light_presets', 'light_presets.json'), 'utf8'));
const ids = args.ids ? String(args.ids).split(',') : null;
const presets = presetData.presets.filter((p) => !ids || ids.includes(p.id));

const { server, port } = await startServer(bundleOverride);
const edgePort = 9800 + Math.floor(Math.random() * 90);
const edge = await startEdge(edgePort);
const info = await (await fetch(`http://127.0.0.1:${edgePort}/json/new?url=${encodeURIComponent('about:blank')}`, { method: 'PUT' })).json();
const page = new CdpPage(info.webSocketDebuggerUrl);
await page.open();

fs.mkdirSync(outDir, { recursive: true });
const failures = [];
let ok = 0;
try {
  await page.call('Emulation.setDeviceMetricsOverride', { width: 560, height: 760, deviceScaleFactor: 1, mobile: false });
  await page.call('Page.enable');
  const url = `http://127.0.0.1:${port}/assets/engine/qa.html?char=${encodeURIComponent(charId)}&view=0&duration=0&clean=1&lights=0`;
  await page.call('Page.navigate', { url });
  const deadline = Date.now() + 120000;
  let ready = false;
  while (Date.now() < deadline) {
    const value = await page.evaluate('window.__qaError ? ("ERR:" + window.__qaError) : (window.__qaReady === true ? "READY" : "")');
    if (typeof value === 'string' && value.startsWith('ERR:')) throw new Error(value.slice(4));
    if (value === 'READY') { ready = true; break; }
    await sleep(200);
  }
  if (!ready) throw new Error('qa 页面未就绪');
  console.log(`[preset-qa] ${presets.length} 套 × char=${charId}${bundleOverride ? '（before bundle）' : ''}${withCones ? ' + 光锥' : ''}`);

  for (const preset of presets) {
    try {
      await page.evaluate(`window.__ssOutbox = []`);
      const lights = JSON.stringify(toEngineLights(preset));
      await page.evaluate(`window.ss.applyScene({ lights: ${lights}, props: [], subject: {} })`);
      await page.evaluate(`window.ss.setLightCones && window.ss.setLightCones(${withCones ? 'true' : 'false'})`);
      await sleep(500);
      const outbox = await page.evaluate('JSON.stringify(window.__ssOutbox || [])');
      const messages = JSON.parse(outbox || '[]');
      const errors = messages.filter((m) => m.includes('"type":"error"'));
      if (errors.length) throw new Error(errors.join(' | ').slice(0, 300));
      const shot = await page.call('Page.captureScreenshot', { format: 'png', fromSurface: true });
      const b64 = shot?.result?.data;
      if (!b64 || b64.length < 2000) throw new Error('截图数据为空');
      const name = `${preset.id}-${suffix}.png`;
      fs.writeFileSync(path.join(outDir, name), Buffer.from(b64, 'base64'));
      ok++;
      console.log(`[preset-qa] ${preset.id.padEnd(14)} -> ${name}`);
    } catch (err) {
      failures.push({ id: preset.id, error: String(err.message || err) });
      console.log(`[preset-qa] ${preset.id} 失败：${err.message || err}`);
    }
  }
  const report = {
    at: new Date().toISOString(),
    char: charId,
    suffix,
    cones: withCones,
    bundle: bundleOverride ? path.relative(repoRoot, bundleOverride) : 'current',
    count: ok,
    failures,
  };
  fs.writeFileSync(path.join(outDir, `qa-${suffix}.json`), JSON.stringify(report, null, 2), 'utf8');
  console.log(`[preset-qa] 完成 ${ok}/${presets.length}，失败 ${failures.length}`);
  if (failures.length) process.exitCode = 1;
} finally {
  try { await page.close(); } catch (_) {}
  edge.proc.kill();
  server.close();
}
