// Q1 三点光渲染验收（D62/D74）：Edge headless + CDP 打开 assets/engine/qa.html，
// 每角色 × 视角（默认 0/1/3）截图到 docs/screenshots/3d-fidelity-<char>-v<n>.png，
// 并读取 window.ss.getSubjectStatus().triangles 作为面数证据、qaSkinningProbe 作为蒙皮证据。
// 用法（工作目录 app/）：
//   node tool/qa_3d_lighting.mjs [--chars qs-men-casual,...] [--views 0,1,3] [--out ../docs/screenshots]
// 说明：优先使用 file:// + --allow-file-access-from-files 打开 qa.html；若 WebView 拦截 XHR，
// 自动回退内置静态 HTTP 服务（不改动 pose_qa.mjs）。
import http from 'node:http';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const appRoot = path.resolve(here, '..');
const repoRoot = path.resolve(appRoot, '..');
const qaFile = path.join(appRoot, 'assets', 'engine', 'qa.html');

const EDGE_CANDIDATES = [
  'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
  'C:/Program Files/Microsoft/Edge/Application/msedge.exe',
  process.env.EDGE,
].filter(Boolean);

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.glb': 'model/gltf-binary',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.css': 'text/css; charset=utf-8',
};

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

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
        'Access-Control-Allow-Origin': '*',
      });
      res.end(data);
    });
  });
  return new Promise((resolve) => {
    server.listen(0, '127.0.0.1', () => resolve({ server, port: server.address().port }));
  });
}

class CdpPage {
  constructor(wsUrl) {
    this.wsUrl = wsUrl;
    this.id = 0;
    this.pending = new Map();
    this.events = [];
  }

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
      } else if (msg.method) {
        this.events.push(msg);
      }
    };
  }

  call(method, params = {}, timeoutMs = 30000) {
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

  async evaluate(expression, timeoutMs = 30000) {
    const r = await this.call('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true }, timeoutMs);
    return r?.result?.result?.value;
  }

  async close() {
    try { this.ws.close(); } catch (_) {}
  }
}

async function startEdge(port) {
  const edge = EDGE_CANDIDATES.find((p) => fs.existsSync(p));
  if (!edge) throw new Error('未找到 msedge.exe，可用 EDGE 环境变量指定路径');
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'ss-lightqa-'));
  const proc = spawn(edge, [
    '--headless=new', '--disable-gpu', '--use-angle=swiftshader', '--enable-unsafe-swiftshader',
    '--allow-file-access-from-files',
    '--hide-scrollbars', '--mute-audio', '--no-first-run', '--no-default-browser-check',
    '--disable-extensions', '--disable-background-networking', '--window-size=720,980',
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

async function createPage(port) {
  const r = await fetch(`http://127.0.0.1:${port}/json/new?url=${encodeURIComponent('about:blank')}`, { method: 'PUT' });
  if (!r.ok) throw new Error(`创建页面失败：HTTP ${r.status}`);
  const info = await r.json();
  const page = new CdpPage(info.webSocketDebuggerUrl);
  page.targetId = info.id;
  await page.open();
  page.call('Page.enable').catch(() => {});
  page.call('Log.enable').catch(() => {});
  return page;
}

const PROBE_POSE = JSON.stringify({
  shoulder_l: [0, 0, 26],
  shoulder_r: [0, 0, -26],
  elbow_l: [-88, 0, 0],
  elbow_r: [-88, 0, 0],
  spine: [10, 0, 0],
});

async function renderJob(page, { url, out, width, height, charId, view, timeoutMs, keepPose = false, subdivision, preset, probeOnly = false }) {
  await page.call('Emulation.setDeviceMetricsOverride', {
    width, height, deviceScaleFactor: 1, mobile: false,
  });
  await page.call('Page.navigate', { url });
  const deadline = Date.now() + timeoutMs;
  let ready = false;
  let error = null;
  while (Date.now() < deadline) {
    const value = await page.evaluate(
      'window.__qaError ? ("ERR:" + window.__qaError) : (window.__qaReady === true ? "READY" : "")',
    );
    if (typeof value === 'string' && value.startsWith('ERR:')) { error = value.slice(4); break; }
    if (value === 'READY') { ready = true; break; }
    await sleep(200);
  }
  if (!ready) throw new Error(error || 'qa 页面未就绪（超时）');
  await sleep(400);

  // 可选：验证桥接 API setSubdivision / setMaterialPreset 的运行时行为。
  if (subdivision !== undefined && subdivision !== null) {
    await page.evaluate(`window.ss.setSubdivision(${Number(subdivision)})`, 90000);
    await sleep(400);
  }
  if (preset) {
    await page.evaluate(`window.ss.setMaterialPreset(${JSON.stringify(String(preset))})`, 60000);
    await sleep(400);
  }

  const statusRaw = await page.evaluate('JSON.stringify(window.ss.getSubjectStatus())');
  const status = JSON.parse(statusRaw || '{}');
  const meshInfoRaw = await page.evaluate('JSON.stringify(window.ss.qaMeshInfo ? window.ss.qaMeshInfo() : null)');
  const meshInfo = JSON.parse(meshInfoRaw || 'null');
  let probe = null;
  if (!probeOnly) {
    await page.evaluate('window.__qaDefaultJoints = JSON.stringify(window.ss.getSubjectStatus().joints)');
    await page.evaluate(`window.ss.setPose(${PROBE_POSE}, 0)`);
    await sleep(650);
    const probeRaw = await page.evaluate('JSON.stringify(window.ss.qaSkinningProbe ? window.ss.qaSkinningProbe() : null)');
    probe = JSON.parse(probeRaw || 'null');
    if (!keepPose) {
      await page.evaluate('window.ss.setPose(JSON.parse(window.__qaDefaultJoints), 0)');
      await sleep(350);
    }
  }

  let bytes = 0;
  let file = null;
  if (!probeOnly) {
    const shot = await page.call('Page.captureScreenshot', { format: 'png', fromSurface: true });
    const b64 = shot?.result?.data;
    if (!b64 || b64.length < 2000) throw new Error('截图数据为空');
    fs.mkdirSync(path.dirname(out), { recursive: true });
    fs.writeFileSync(out, Buffer.from(b64, 'base64'));
    bytes = Buffer.from(b64, 'base64').length;
    file = path.relative(repoRoot, out).replaceAll('\\', '/');
  }
  return {
    char: charId,
    view,
    file,
    bytes,
    triangles: status.triangles,
    subdivision: status.subdivision,
    materialPreset: status.materialPreset,
    missingJoints: status.missingJoints,
    skinProbe: probe,
    meshInfo,
    meshTriangles: Array.isArray(meshInfo)
      ? meshInfo.reduce((sum, m) => sum + (m.applied || 0), 0)
      : null,
  };
}

const args = parseArgs(process.argv.slice(2));
const chars = String(args.chars || 'qs-men-casual,qs-women-casual,qs-men-suit').split(',').filter(Boolean);
const views = String(args.views || '0,1,3').split(',').map(Number).filter((n) => !Number.isNaN(n));
const outDir = path.resolve(repoRoot, args.out || 'docs/screenshots');
const width = Number(args.width || 640);
const height = Number(args.height || 900);
const label = args.label || '3d-fidelity-%char-v%v.png';
const subdivision = args.subdivision === undefined ? null : Number(args.subdivision);
const preset = args.preset ? String(args.preset) : null;
const probeOnly = args['probe-only'] === true;
const manifestPath = path.join(appRoot, 'assets', 'models', 'characters', 'manifest.json');
let manifestChars = [];
try {
  manifestChars = JSON.parse(fs.readFileSync(manifestPath, 'utf8')).characters || [];
} catch (_) { /* manifest 缺失时只打印运行时面数 */ }

const edgePort = 9700 + Math.floor(Math.random() * 200);
const edge = await startEdge(edgePort);
const page = await createPage(edgePort);
const jobs = [];
for (const charId of chars) {
  for (const view of views) {
    const name = label.replaceAll('%char', charId).replaceAll('%v', String(view));
    jobs.push({ charId, view, out: path.join(outDir, name) });
  }
}
// 蒙皮证据：附加一张保持弯关节姿势的截图（正常截图仍为默认姿势）。
const poseChar = args['pose-char'] ? String(args['pose-char']) : '';
if (poseChar) {
  jobs.push({
    charId: poseChar,
    view: 0,
    keepPose: true,
    out: path.join(outDir, `3d-fidelity-${poseChar}-pose.png`),
  });
}

let server = null;
let mode = 'file';
const results = [];
const failures = [];
async function runJobs(useServer) {
  for (const job of jobs) {
    const params = new URLSearchParams();
    params.set('char', job.charId);
    params.set('view', String(job.view));
    params.set('duration', '0');
    const url = useServer
      ? `http://127.0.0.1:${server.port}/assets/engine/qa.html?${params.toString()}`
      : `${pathToFileURL(qaFile).href}?${params.toString()}`;
    try {
      const result = await renderJob(page, {
        ...job, url, width, height, timeoutMs: 120000, subdivision, preset, probeOnly,
      });
      results.push(result);
      if (probeOnly) {
        const entry = manifestChars.find((c) => c.id === job.charId) || {};
        const match = entry.triCount == null || entry.triCount === result.triangles;
        console.log(
          `[verify] ${job.charId.padEnd(22)} runtime=${String(result.triangles).padStart(6)} ` +
          `manifest=${String(entry.triCount ?? 'n/a').padStart(6)} ${match ? 'OK' : 'MISMATCH'}`,
        );
        if (!match && !failures.some((f) => f.char === job.charId)) {
          failures.push({ char: job.charId, view: job.view, error: `面数不一致 runtime=${result.triangles} manifest=${entry.triCount}` });
        }
      } else {
        console.log(
          `[lighting] v${job.view} ${job.charId}${job.keepPose ? '(pose)' : ''}: triangles=${result.triangles} subdivision=${result.subdivision} ` +
          `preset=${result.materialPreset} skinDeform=${result.skinProbe ? result.skinProbe.maxDeform : 'n/a'} ` +
          `skinDeformNorm=${result.skinProbe ? result.skinProbe.maxDeformNorm : 'n/a'} -> ${result.file}`,
        );
      }
    } catch (err) {
      failures.push({ char: job.charId, view: job.view, error: String(err.message || err) });
      console.log(`[lighting] v${job.view} ${job.charId} 失败：${err.message || err}`);
      return false;
    }
  }
  return true;
}

mode = 'file';
let ok = await runJobs(false);
if (!ok) {
  console.log('[lighting] file:// 模式失败，回退内置 HTTP 服务重试…');
  results.length = 0;
  failures.length = 0;
  const started = await startServer();
  server = started.server;
  mode = 'http';
  ok = await runJobs(true);
}

const report = {
  generatedAt: new Date().toISOString(),
  mode,
  chars,
  views,
  width,
  height,
  results,
  failures,
};
fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(path.join(outDir, '3d-fidelity-report.json'), `${JSON.stringify(report, null, 2)}\n`, 'utf8');

try { await page.close(); } catch (_) {}
edge.proc.kill();
if (server) server.close();

console.log(`[lighting] 完成 ${results.length}/${jobs.length} 张（mode=${mode}）`);
if (failures.length) {
  for (const f of failures) console.log(`  - 失败 ${f.char} v${f.view}: ${f.error}`);
  process.exit(1);
}
