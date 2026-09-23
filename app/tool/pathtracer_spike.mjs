// V7/D138 spike：three-gpu-pathtracer 与 three r186 兼容性最小验证（R67）。
// 用法（工作目录 app/）：
//   node tool/pathtracer_spike.mjs [--w 320] [--h 240] [--samples 8] [--gpu 1]
// 说明：默认 SwiftShader（headless，稳定可复现）；--gpu 1 尝试真实 GPU（本机 RTX 4060，用于真实耗时）。
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import http from 'node:http';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const appRoot = path.resolve(here, '..');

const EDGE_CANDIDATES = [
  'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
  'C:/Program Files/Microsoft/Edge/Application/msedge.exe',
  process.env.EDGE,
].filter(Boolean);

const MIME = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8', '.png': 'image/png',
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
    if (pathname === '/spike.html') {
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store' });
      res.end(fs.readFileSync(path.join(here, 'spike_pt.html')));
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
  call(method, params = {}, timeoutMs = 300000) {
    return new Promise((resolve, reject) => {
      const id = ++this.id;
      const timer = setTimeout(() => { this.pending.delete(id); reject(new Error(`CDP 超时：${method}`)); }, timeoutMs);
      this.pending.set(id, (msg) => { clearTimeout(timer); resolve(msg); });
      this.ws.send(JSON.stringify({ id, method, params }));
    });
  }
  async evaluate(expression, timeoutMs = 300000) {
    const r = await this.call('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true }, timeoutMs);
    return r?.result?.result?.value;
  }
  async close() { try { this.ws.close(); } catch (_) {} }
}

async function startEdge(port, useGpu, headed) {
  const edge = EDGE_CANDIDATES.find((p) => fs.existsSync(p));
  if (!edge) throw new Error('未找到 msedge.exe，可用 EDGE 环境变量指定路径');
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'ss-ptspike-'));
  const args = [
    '--hide-scrollbars', '--mute-audio', '--no-first-run',
    '--no-default-browser-check', '--disable-extensions', '--window-size=640,480',
    `--remote-debugging-port=${port}`, `--user-data-dir=${profile}`, 'about:blank',
  ];
  if (!headed) args.unshift('--headless=new');
  if (!useGpu) {
    args.splice(1, 0, '--disable-gpu', '--use-angle=swiftshader', '--enable-unsafe-swiftshader');
  } else {
    args.splice(1, 0, '--force_high_performance_gpu');
  }
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
  return { proc, profile, version };
}

const args = parseArgs(process.argv.slice(2));
const { server, port } = await startServer();
const edgePort = 9900 + Math.floor(Math.random() * 80);
const useGpu = args.gpu === '1' || args.gpu === true;
const headed = args.headed === '1' || args.headed === true;
const edge = await startEdge(edgePort, useGpu, headed);
const info = await (await fetch(`http://127.0.0.1:${edgePort}/json/new?url=${encodeURIComponent('about:blank')}`, { method: 'PUT' })).json();
const page = new CdpPage(info.webSocketDebuggerUrl);
await page.open();
try {
  await page.call('Page.enable');
  const query = `w=${args.w || 320}&h=${args.h || 240}&samples=${args.samples || 8}&bounces=${args.bounces || 3}`;
  await page.call('Page.navigate', { url: `http://127.0.0.1:${port}/spike.html?${query}` });
  const deadline = Date.now() + 300000;
  let result = null;
  while (Date.now() < deadline) {
    const err = await page.evaluate('window.__spikeError || null');
    if (err) throw new Error(String(err));
    result = await page.evaluate('window.__spikeResult || null');
    if (result) break;
    await sleep(250);
  }
  if (!result) throw new Error('spike 超时');
  const shot = await page.call('Page.captureScreenshot', { format: 'png', fromSurface: true });
  const b64 = shot?.result?.data;
  const mode = useGpu ? (headed ? 'gpu-headed' : 'gpu') : 'swiftshader';
  const outFile = path.join(appRoot, '..', 'docs', 'qa', `pathtracer-spike-${mode}.json`);
  fs.mkdirSync(path.dirname(outFile), { recursive: true });
  if (b64) {
    fs.writeFileSync(path.join(path.dirname(outFile), `pathtracer-spike-${mode}.png`), Buffer.from(b64, 'base64'));
  }
  const out = {
    at: new Date().toISOString(),
    gpu: useGpu,
    headed,
    edge: edge.version['Browser'],
    ...result,
    ok: result.ok === true && result.samples > 0,
    screenshot: b64 ? `docs/qa/pathtracer-spike-${mode}.png` : null,
  };
  fs.writeFileSync(outFile, JSON.stringify(out, null, 2), 'utf8');
  console.log(JSON.stringify(out, null, 2));
  console.log(`[spike] 结果已写入 ${path.relative(appRoot, outFile)}`);
  if (!out.ok) process.exitCode = 1;
} finally {
  try { await page.close(); } catch (_) {}
  edge.proc.kill();
  server.close();
}
