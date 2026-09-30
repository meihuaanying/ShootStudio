// V8/S2（D156）3D 引擎架构 spike：现有 WebView2 + three.js r186 路线实测（帧率 p50/p95 + CPU + 内存）。
//
// 用法（在 app/ 下）：
//   node tool/engine_perf_qa.mjs --label gtx4060-headed          # 独显 + headed（生产等效渲染栈）
//   node tool/engine_perf_qa.mjs --label headless-swiftshader --headless=1
//   可调：--idle=3 --drag=4 --wheel=2（每段秒数）、--warmup=6、--port=9993
//
// 测量口径（R78：实测值原样落盘，异常不修饰）：
//   1) 帧间隔：页面内 rAF 采样 performance.now() 差值（分段切片），统计 p50/p95/p99/max 与 >50ms 长帧数；
//   2) 交互：CDP Input.dispatchMouseEvent **不等响应**（避免与渲染线程往返耦合）脚本化 ——
//      画布空白处拖拽 = OrbitControls 旋转；灯体拖拽 = 沿地面移动灯（engine.js pointerdown 命中 light 分支）；滚轮 = 推拉；
//   3) 预热与稳态：等引擎 frames 稳定推进且 Performance.getMetrics 的 TaskDuration 增量 < 250ms/s 后才开始采样
//      （否则会把首帧着色器编译 / HDR PMREM / 资产加载的卡顿算进交互帧率）；
//   4) CPU：每段 TaskDuration 增量 / 帧数 = 每帧主线程耗时；
//   5) 内存：Runtime.getHeapUsage + Performance.getMetrics + performance.memory（--enable-precise-memory-info）。
// 输出：docs/qa/v8-s2-engine-perf-<label>.json

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import http from 'node:http';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const appRoot = path.resolve(here, '..');
const repoRoot = path.resolve(appRoot, '..');
const outDir = path.join(repoRoot, 'docs', 'qa');
fs.mkdirSync(outDir, { recursive: true });

const argv = process.argv.slice(2);
const arg = (name, dflt) => {
  const hit = argv.find((a) => a.startsWith(`--${name}=`) || a === `--${name}`);
  if (!hit) return dflt;
  const eq = hit.indexOf('=');
  return eq >= 0 ? hit.slice(eq + 1) : (argv[argv.indexOf(hit) + 1] ?? dflt);
};
const label = String(arg('label', 'headed'));
const headed = String(arg('headless', '0')) !== '1';
const edgePort = Number(arg('port', 9993));
const idleSec = Number(arg('idle', 3));
const dragSec = Number(arg('drag', 4));
const wheelSec = Number(arg('wheel', 2));
const warmupSec = Number(arg('warmup', 6));
const dpr = String(arg('dpr', '1'));
const swiftshader = String(arg('swiftshader', '0')) === '1';
// gpumode: high=--force_high_performance_gpu（默认，锁定独显）；default=用系统默认适配器（可落到核显）
const gpumode = String(arg('gpumode', 'high'));

const EDGE = [
  'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
  'C:/Program Files/Microsoft/Edge/Application/msedge.exe',
].find((p) => fs.existsSync(p));
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json',
  '.glb': 'model/gltf-binary',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.hdr': 'application/octet-stream',
  '.woff2': 'font/woff2',
  '.otf': 'font/otf',
  '.css': 'text/css; charset=utf-8',
};

const server = http.createServer((req, res) => {
  const pathname = decodeURIComponent(new URL(req.url, 'http://127.0.0.1').pathname);
  fs.readFile(path.join(appRoot, pathname), (err, data) => {
    if (err) { res.writeHead(404); res.end(); return; }
    res.writeHead(200, {
      'Content-Type': MIME[path.extname(pathname).toLowerCase()] || 'application/octet-stream',
      'Cache-Control': 'no-store',
    });
    res.end(data);
  });
});
await new Promise((r) => server.listen(0, '127.0.0.1', r));
const serverPort = server.address().port;

const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'ss-perf-'));
const edgeArgs = [
  '--hide-scrollbars',
  '--no-first-run',
  '--no-default-browser-check',
  '--enable-precise-memory-info',
  '--disable-backgrounding-occluded-windows',
  '--disable-renderer-backgrounding',
  '--disable-background-timer-throttling',
  `--remote-debugging-port=${edgePort}`,
  `--user-data-dir=${profile}`,
  '--window-size=1280,900',
];
if (dpr === '1') edgeArgs.push('--force-device-scale-factor=1');
if (swiftshader) edgeArgs.push('--use-angle=swiftshader', '--use-gl=angle');
if (headed && gpumode === 'high') edgeArgs.unshift('--force_high_performance_gpu');
else edgeArgs.unshift('--headless=new');
edgeArgs.push('about:blank');
const proc = spawn(EDGE, edgeArgs, { stdio: 'ignore' });

function stats(values) {
  if (!values.length) return { frames: 0, p50: null, p95: null, p99: null, max: null, long50: 0 };
  const sorted = [...values].sort((a, b) => a - b);
  const at = (q) => sorted[Math.min(sorted.length - 1, Math.floor(q * sorted.length))];
  const mean = sorted.reduce((a, b) => a + b, 0) / sorted.length;
  return {
    frames: sorted.length,
    p50: Number(at(0.5).toFixed(2)),
    p95: Number(at(0.95).toFixed(2)),
    p99: Number(at(0.99).toFixed(2)),
    max: Number(sorted[sorted.length - 1].toFixed(2)),
    mean: Number(mean.toFixed(2)),
    fpsMean: Number((1000 / mean).toFixed(1)),
    long50: sorted.filter((v) => v > 50).length,
  };
}

const result = { label, at: new Date().toISOString(), mode: headed ? 'headed' : 'headless-new', dpr, swiftshader, gpumode, phases: {} };
try {
  let ready = false;
  for (let i = 0; i < 100; i++) {
    try { if ((await fetch(`http://127.0.0.1:${edgePort}/json/version`)).ok) { ready = true; break; } } catch (_) { /* retry */ }
    await sleep(200);
  }
  if (!ready) throw new Error('Edge 调试端口未就绪');
  const info = await (await fetch(`http://127.0.0.1:${edgePort}/json/version`)).json();
  result.browser = info.Browser;
  const target = await (await fetch(`http://127.0.0.1:${edgePort}/json/new?url=about:blank`, { method: 'PUT' })).json();
  const ws = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((res, rej) => { ws.onopen = res; ws.onerror = rej; });
  let id = 0;
  const pending = new Map();
  ws.onmessage = (e) => {
    const m = JSON.parse(e.data);
    if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); }
  };
  const call = (method, params = {}) => new Promise((res) => {
    const i = ++id;
    pending.set(i, res);
    ws.send(JSON.stringify({ id: i, method, params }));
  });
  const ev = async (expr) => {
    const r = await call('Runtime.evaluate', { expression: expr, returnByValue: true, awaitPromise: true });
    if (r?.result?.exceptionDetails) console.log('  [JS 异常]', JSON.stringify(r.result.exceptionDetails).slice(0, 240));
    return r?.result?.result?.value;
  };
  await call('Page.enable');
  await call('Runtime.enable');
  await call('Performance.enable');
  if (headed) await call('Page.bringToFront');

  const url = `http://127.0.0.1:${serverPort}/assets/engine/qa.html?char=qs-women-casual&view=0&duration=0&clean=1&lights=1`;
  await call('Page.navigate', { url });
  for (let i = 0; i < 400; i++) { if (await ev('window.__qaReady === true')) break; await sleep(250); }
  await ev("window.ss && window.ss.setPerformanceProfile('high') && true");
  await ev('window.ss.setEnvIntensity(0) && window.ss.setAmbientEnabled(false) && true');

  result.gpu = await ev("(function(){try{const c=document.createElement('canvas');const g=c.getContext('webgl2')||c.getContext('webgl');const d=g.getExtension('WEBGL_debug_renderer_info');return d?g.getParameter(d.UNMASKED_RENDERER_WEBGL):'n/a';}catch(e){return 'err:'+e}})()");
  result.engine = await ev('JSON.stringify(window.ss.getEngineStats ? window.ss.getEngineStats() : {})');

  // 预热 + 稳态判定：frames 稳定推进且 TaskDuration 增速 < 250ms/s
  const taskDuration = async () => {
    const m = await call('Performance.getMetrics');
    const hit = (m?.result?.metrics || []).find((x) => x.name === 'TaskDuration');
    return hit ? hit.value : 0;
  };
  const engineFrames = async () => {
    const v = await ev('(window.ss.getEngineStats ? window.ss.getEngineStats().frames : 0)');
    return Number(v || 0);
  };
  const warmStart = Date.now();
  let warm = { seconds: 0, frames: engineFrames ? 0 : 0, settled: false };
  let prevFrames = await engineFrames();
  let prevTask = await taskDuration();
  while ((Date.now() - warmStart) / 1000 < 90) {
    await sleep(1000);
    const f = await engineFrames();
    const t = await taskDuration();
    const dTask = t - prevTask;
    const settled = f > prevFrames && dTask < 0.25;
    prevFrames = f; prevTask = t;
    if ((Date.now() - warmStart) / 1000 >= warmupSec && settled) { warm = { seconds: Number(((Date.now() - warmStart) / 1000).toFixed(1)), frames: f, taskDeltaPerSec: Number(dTask.toFixed(3)), settled: true }; break; }
  }
  if (!warm.settled) warm = { seconds: Number(((Date.now() - warmStart) / 1000).toFixed(1)), frames: prevFrames, taskDeltaPerSec: null, settled: false };
  result.warmup = warm;
  console.log(`[perf] 预热 ${warm.seconds}s → 稳态=${warm.settled} frames=${warm.frames}`);

  // 帧间隔采样器（分段用下标切片，避免重置竞态）
  await ev(`(function(){
    window.__perf = { t: [], marks: {} };
    let last = performance.now();
    const loop = () => {
      const now = performance.now();
      window.__perf.t.push(now - last);
      last = now;
      requestAnimationFrame(loop);
    };
    requestAnimationFrame(loop);
    return true;
  })()`);

  const canvas = JSON.parse(await ev(`(function(){
    const r = window.__ssQA.renderer.domElement.getBoundingClientRect();
    return JSON.stringify({ x: r.left, y: r.top, w: r.width, h: r.height });
  })()`));
  result.canvas = canvas;
  const lightPt = JSON.parse(await ev(`(function(){
    const qa = window.__ssQA; const T = window.__ssThree;
    let g = null;
    qa.scene.traverse((o) => { if (!g && o.userData && o.userData.kind === 'light' && o.userData.lightId != null) g = o; });
    if (!g || !T) return JSON.stringify({ ok: false });
    const v = new T.Vector3();
    g.getWorldPosition(v); v.y += 0.6; v.project(qa.camera);
    const r = qa.renderer.domElement.getBoundingClientRect();
    return JSON.stringify({ ok: true, id: g.userData.lightId,
      x: r.left + (v.x * 0.5 + 0.5) * r.width, y: r.top + (-v.y * 0.5 + 0.5) * r.height });
  })()`));
  result.lightPoint = lightPt;

  let inflight = 0;
  const fire = (method, params) => {
    inflight += 1;
    call(method, params).then(() => { inflight -= 1; }, () => { inflight -= 1; });
  };
  const mouse = (type, x, y, extra = {}) => {
    if (inflight > 40) return;
    fire('Input.dispatchMouseEvent', {
      type, x: Math.round(x), y: Math.round(y), button: 'left', buttons: 1, clickCount: 1, ...extra,
    });
  };

  const runPhase = async (name, seconds, driver) => {
    const startIdx = Number(await ev('(window.__perf.t.length)'));
    const f0 = await engineFrames();
    const t0 = Date.now();
    const task0 = await taskDuration();
    const wallStart = Date.now();
    while ((Date.now() - wallStart) / 1000 < seconds) {
      await driver((Date.now() - wallStart) / 1000, name);
      await sleep(8);
    }
    const wall = (Date.now() - wallStart) / 1000;
    const task1 = await taskDuration();
    const endIdx = Number(await ev('(window.__perf.t.length)'));
    const slice = JSON.parse(await ev(`JSON.stringify(window.__perf.t.slice(${startIdx}, ${endIdx}))`) || '[]');
    const clean = slice.filter((v) => v > 0 && v < 5000);
    const s = stats(clean);
    const f1 = await engineFrames();
    const cpuTotal = task1 - task0;
    result.phases[name] = {
      requestedSeconds: seconds,
      wallSeconds: Number(wall.toFixed(2)),
      engineFrames: f1 - f0,
      cpuTotalSeconds: Number(cpuTotal.toFixed(3)),
      cpuMsPerFrame: f1 > f0 ? Number(((cpuTotal * 1000) / (f1 - f0)).toFixed(2)) : null,
      ...s,
    };
    console.log(`[perf] ${name.padEnd(10)} 帧=${String(s.frames).padStart(4)} p50=${s.p50}ms p95=${s.p95}ms p99=${s.p99}ms max=${s.max}ms 长帧>50ms=${s.long50} CPU/帧=${result.phases[name].cpuMsPerFrame}ms`);
  };

  await runPhase('idle', idleSec, async () => {});
  const ox = canvas.x + canvas.w * 0.18;
  const oy = canvas.y + canvas.h * 0.22;
  await runPhase('orbit', dragSec, async (t, name) => {
    if (name === 'orbit' && t < 0.05) mouse('mousePressed', ox, oy);
    mouse('mouseMoved', ox + Math.sin(t * Math.PI * 2) * 160, oy + Math.cos(t * Math.PI * 0.7) * 60);
  });
  if (lightPt.ok) {
    await runPhase('lightDrag', dragSec, async (t, name) => {
      if (name === 'lightDrag' && t < 0.05) mouse('mousePressed', lightPt.x, lightPt.y);
      mouse('mouseMoved', lightPt.x + Math.sin(t * Math.PI * 2) * 120, lightPt.y + Math.cos(t * Math.PI * 1.5) * 40);
    });
    await ev(`(function(){ try { const e = new PointerEvent('pointerup', {clientX: ${lightPt.x}, clientY: ${lightPt.y}, bubbles: true, button: 0}); window.__ssQA.renderer.domElement.dispatchEvent(e); } catch (_) {} return true; })()`);
  }
  await runPhase('dolly', wheelSec, async (t) => {
    if (inflight > 40) return;
    fire('Input.dispatchMouseEvent', {
      type: 'mouseWheel',
      x: Math.round(canvas.x + canvas.w / 2), y: Math.round(canvas.y + canvas.h / 2),
      deltaX: 0, deltaY: Math.round(60 * Math.sin(t * Math.PI * 4)),
    });
  });
  await ev('(function(){ const c = window.__ssQA.renderer.domElement; ["pointerup","pointercancel"].forEach((t) => c.dispatchEvent(new PointerEvent(t, {bubbles: true, button: 0}))); return true; })()');

  const heap = await call('Runtime.getHeapUsage');
  result.heap = heap?.result
    ? { usedMB: Number((heap.result.usedSize / 1048576).toFixed(2)), totalMB: Number((heap.result.totalSize / 1048576).toFixed(2)) }
    : null;
  const mem = await ev('(performance.memory ? JSON.stringify({ usedMB: +(performance.memory.usedJSHeapSize / 1048576).toFixed(2), totalMB: +(performance.memory.totalJSHeapSize / 1048576).toFixed(2), limitMB: +(performance.memory.jsHeapSizeLimit / 1048576).toFixed(0) }) : null)');
  result.jsHeapPrecise = mem ? JSON.parse(mem) : null;
  const metrics = await call('Performance.getMetrics');
  const want = ['JSHeapUsedSize', 'JSHeapTotalSize', 'Documents', 'Frames', 'TaskDuration', 'LayoutCount', 'RecalcStyleCount'];
  result.metrics = {};
  for (const m of metrics?.result?.metrics || []) if (want.includes(m.name)) result.metrics[m.name] = m.value;
  const rend = await ev('JSON.stringify({ drawCalls: window.__ssQA.renderer.info.render.calls, triangles: window.__ssQA.renderer.info.render.triangles, textures: window.__ssQA.renderer.info.memory.textures, geometries: window.__ssQA.renderer.info.memory.geometries, programs: window.__ssQA.renderer.info.programs ? window.__ssQA.renderer.info.programs.length : null, pixelRatio: window.__ssQA.renderer.getPixelRatio() })');
  result.renderer = rend ? JSON.parse(rend) : null;
  result.engineAfter = await ev('JSON.stringify(window.ss.getEngineStats ? window.ss.getEngineStats() : {})');
  ws.close();
} catch (e) {
  result.error = String(e && e.stack ? e.stack : e);
  console.error('[perf] 失败：', result.error);
} finally {
  try { proc.kill(); } catch (_) { /* ignore */ }
  server.close();
  try { fs.rmSync(profile, { recursive: true, force: true }); } catch (_) { /* ignore */ }
}

const outFile = path.join(outDir, `v8-s2-engine-perf-${label}.json`);
fs.writeFileSync(outFile, `${JSON.stringify(result, null, 2)}\n`);
console.log(`[perf] 写出 ${path.relative(repoRoot, outFile)}`);
if (result.error) process.exit(1);
