// V6 阶段 A 内存/缓存门禁：连续切换全部角色并采样引擎内存与缓存 LRU。
// 用法（工作目录 app/）：
//   node tool/engine_mem_qa.mjs [--out docs/qa] [--loops 1] [--char qs-men-casual]
// 产物：docs/qa/engine-mem-<stamp>.json（曲线 + 断言结果）
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
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.glb': 'model/gltf-binary',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.css': 'text/css; charset=utf-8',
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

function startServer() {
  const server = http.createServer((req, res) => {
    let pathname = '/';
    try { pathname = decodeURIComponent(new URL(req.url, 'http://127.0.0.1').pathname); } catch (_) {}
    if (pathname === '/') pathname = '/assets/engine/qa.html';
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
      if (msg.id && this.pending.has(msg.id)) {
        this.pending.get(msg.id)(msg);
        this.pending.delete(msg.id);
      }
    };
  }
  call(method, params = {}, timeoutMs = 60000) {
    return new Promise((resolve, reject) => {
      const id = ++this.id;
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`CDP 超时：${method}`));
      }, timeoutMs);
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
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'ss-engqa-'));
  const proc = spawn(edge, [
    '--headless=new', '--disable-gpu', '--use-angle=swiftshader', '--enable-unsafe-swiftshader',
    '--hide-scrollbars', '--mute-audio', '--no-first-run', '--no-default-browser-check',
    '--disable-extensions', '--window-size=640,800',
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

const args = parseArgs(process.argv.slice(2));
const outDir = path.resolve(repoRoot, args.out || path.join('docs', 'qa'));
const loops = Math.max(1, Number(args.loops || 1));
const startChar = String(args.char || 'qs-men-casual');

const { server, port } = await startServer();
const edgePort = 9900 + Math.floor(Math.random() * 80);
const edge = await startEdge(edgePort);
const page = new CdpPage((await (await fetch(`http://127.0.0.1:${edgePort}/json/new?url=${encodeURIComponent('about:blank')}`, { method: 'PUT' })).json()).webSocketDebuggerUrl);
await page.open();

const samples = [];
const failures = [];
try {
  await page.call('Emulation.setDeviceMetricsOverride', { width: 640, height: 800, deviceScaleFactor: 1, mobile: false });
  const url = `http://127.0.0.1:${port}/assets/engine/qa.html?char=${encodeURIComponent(startChar)}&view=0&duration=0&clean=1`;
  await page.call('Page.enable');
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

  const chars = JSON.parse(await page.evaluate('JSON.stringify(window.ss.listCharacters())') || '[]');
  const ids = chars.map((c) => c.id).filter(Boolean);
  console.log(`[mem-qa] 角色 ${ids.length} 个 × ${loops} 轮`);

  for (let loop = 0; loop < loops; loop++) {
    for (const id of ids) {
      const t0 = Date.now();
      try {
        await page.evaluate(`window.ss.setCharacter(${JSON.stringify(id)})`);
        const ok = await page.evaluate(`(async () => {
          const deadline = performance.now() + 90000;
          while (performance.now() < deadline) {
            const s = window.ss.getSubjectStatus();
            if (s.ready === true && s.loading !== true && s.characterId === ${JSON.stringify(id)}) return true;
            await new Promise((r) => setTimeout(r, 200));
          }
          return false;
        })()`);
        if (!ok) throw new Error('角色切换超时');
        // 顺带触发一次细分与材质切换（曾经的泄漏路径）。
        await page.evaluate('window.ss.setSubdivision(1)');
        await page.evaluate('window.ss.setMaterialPreset("realistic")');
        await page.evaluate('window.ss.setMaterialPreset("standard")');
        await sleep(150);
        const stats = JSON.parse(await page.evaluate('JSON.stringify(window.ss.getEngineStats())') || '{}');
        samples.push({
          loop, id, ms: Date.now() - t0,
          heapMB: stats.memory ? stats.memory.usedMB : null,
          instances: stats.cache ? stats.cache.instances : null,
          glbs: stats.cache ? stats.cache.glbs : null,
          fps: stats.fps,
        });
        console.log(`[mem-qa] L${loop} ${id.padEnd(24)} ${String(Date.now() - t0).padStart(6)}ms heap=${stats.memory ? stats.memory.usedMB + 'MB' : 'n/a'} L1=${stats.cache ? stats.cache.instances : '?'} GLB=${stats.cache ? stats.cache.glbs : '?'}`);
      } catch (err) {
        failures.push({ loop, id, error: String(err.message || err) });
        console.log(`[mem-qa] L${loop} ${id} 失败：${err.message || err}`);
      }
    }
  }

  // LRU 断言：全部切完后缓存不得超过上限（实例 ≤2 / GLB ≤3）。
  const finalStats = JSON.parse(await page.evaluate('JSON.stringify(window.ss.getEngineStats())') || '{}');
  const cache = finalStats.cache || {};
  const lruOk = (cache.instances ?? 99) <= 2 && (cache.glbs ?? 99) <= 3;
  const heaps = samples.map((s) => s.heapMB).filter((v) => typeof v === 'number');
  const peak = heaps.length ? Math.max(...heaps) : null;
  const first = heaps.length ? heaps[0] : null;
  const last = heaps.length ? heaps[heaps.length - 1] : null;
  const growthOk = first != null && last != null ? last - first <= 300 : true;

  fs.mkdirSync(outDir, { recursive: true });
  const stamp = new Date().toISOString().replace(/[:T]/g, '-').slice(0, 19);
  const file = path.join(outDir, `engine-mem-${stamp}.json`);
  const report = {
    at: new Date().toISOString(),
    loops,
    characters: ids.length,
    samples,
    failures,
    finalCache: cache,
    finalMemory: finalStats.memory || null,
    assertions: {
      lruOk,
      growthOk,
      peakHeapMB: peak,
      firstHeapMB: first,
      lastHeapMB: last,
    },
  };
  fs.writeFileSync(file, JSON.stringify(report, null, 2), 'utf8');
  console.log(`[mem-qa] 采样 ${samples.length} 条，失败 ${failures.length}；LRU ${lruOk ? 'PASS' : 'FAIL'}，堆增长 ${growthOk ? 'PASS' : 'FAIL'}（first=${first} peak=${peak} last=${last} MB）`);
  console.log(`[mem-qa] 报告：${path.relative(repoRoot, file)}`);
  if (!lruOk) process.exitCode = 1;
} finally {
  try { await page.close(); } catch (_) {}
  edge.proc.kill();
  server.close();
}
