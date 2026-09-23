// V7/S3.3：VSM 回归修复专项 QA（headed + 独显；R61 证据）。
//
// 背景：r186 的 WebGLShadowMap 在 VSM 下会把 receiveShadow 的物体也渲染进阴影贴图，
// 灯具自身（柔光箱箱体等）位于灯前且处于光锥内 → 整个场景被压进阴影（修复前实测
// VSM 画面亮度 32.6 vs PCF 109.8；0 灯与 3 灯画面几乎无差异）。修复见 lights.js
// excludeFromShadows()（灯具视觉不投影也不接收阴影）。
//
// 本脚本在 headed + 独显环境（避免 SwiftShader 低配档回退 PCF）量测：
//   A. VSM + 3 灯   B. PCF + 3 灯   C. VSM + 0 灯
// 判据：A >= 0.6 × B（不再被压黑）；A - C >= 15（灯光可见贡献）。
//
// 用法：node tool/vsm_regression_qa.mjs [--suffix r186s33] [--port 9987]
// 输出：docs/qa/vsm-regression-<suffix>.json + docs/qa/vsm-regression-<suffix>-{vsm, pcf, vsm-off}.png

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import http from 'node:http';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const appRoot = path.resolve(here, '..');
const repoRoot = path.resolve(appRoot, '..');
const argv = process.argv.slice(2);
const arg = (name, dflt) => {
  const hit = argv.find((a) => a.startsWith(`--${name}=`) || a === `--${name}`);
  if (!hit) return dflt;
  const eq = hit.indexOf('=');
  return eq >= 0 ? hit.slice(eq + 1) : (argv[argv.indexOf(hit) + 1] ?? dflt);
};
const suffix = arg('suffix', 'r186s33');
const edgePort = Number(arg('port', 9987));
const outDir = path.join(repoRoot, 'docs', 'qa');
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
  '.hdr': 'application/octet-stream',
};

const server = http.createServer((req, res) => {
  const pathname = decodeURIComponent(new URL(req.url, 'http://127.0.0.1').pathname);
  fs.readFile(path.normalize(path.join(appRoot, pathname)), (err, data) => {
    if (err) { res.writeHead(404); res.end(); return; }
    res.writeHead(200, {
      'Content-Type': MIME[path.extname(pathname).toLowerCase()] || 'application/octet-stream',
      'Cache-Control': 'no-store',
    });
    res.end(data);
  });
});
await new Promise((r) => server.listen(0, '127.0.0.1', r));
const port = server.address().port;

const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'ss-vsmqa-'));
const proc = spawn(EDGE, [
  '--force_high_performance_gpu',
  '--hide-scrollbars',
  '--no-first-run',
  `--remote-debugging-port=${edgePort}`,
  `--user-data-dir=${profile}`,
  '--window-size=1280,900',
  'about:blank',
], { stdio: 'ignore' });

try {
  let ready = false;
  for (let i = 0; i < 80; i++) {
    try { if ((await fetch(`http://127.0.0.1:${edgePort}/json/version`)).ok) { ready = true; break; } } catch (_) { /* retry */ }
    await sleep(200);
  }
  if (!ready) throw new Error('Edge 调试端口未就绪');
  const info = await (await fetch(`http://127.0.0.1:${edgePort}/json/new?url=about:blank`, { method: 'PUT' })).json();
  const ws = new WebSocket(info.webSocketDebuggerUrl);
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
    const ex = r?.result?.exceptionDetails;
    if (ex) console.log('  [JS 异常]', JSON.stringify(ex).slice(0, 300));
    return r?.result?.result?.value;
  };
  await call('Page.enable');

  const url = `http://127.0.0.1:${port}/assets/engine/qa.html?char=qs-women-casual&view=0&duration=0&clean=1&lights=1`;
  await call('Page.navigate', { url });
  for (let i = 0; i < 400; i++) { if (await ev('window.__qaReady === true')) break; await sleep(250); }
  const qaError = await ev('window.__qaError || null');
  if (qaError) console.log('  [qaError]', qaError);

  // 量测探针：capturePhoto（engine 显式 render + toDataURL）→ 中心区域亮度统计。
  await ev(`window.__qaMeasure = async (token) => {
    window.ss.capturePhoto(token);
    await new Promise((r) => setTimeout(r, 80));
    const entry = (window.__ssOutbox || []).filter((m) => m.includes('"captured"') && m.includes(token)).pop();
    const dataUrl = JSON.parse(entry).dataUrl;
    window.__qaShots = window.__qaShots || {};
    window.__qaShots[token] = dataUrl;
    const im = new Image();
    await new Promise((res, rej) => { im.onload = res; im.onerror = rej; im.src = dataUrl; });
    const w = 160, h = 160;
    const c = document.createElement('canvas');
    c.width = w; c.height = h;
    const ctx = c.getContext('2d');
    const sx = Math.floor(im.width * 0.35), sy = Math.floor(im.height * 0.2);
    const sw = Math.max(1, Math.floor(im.width * 0.3)), sh = Math.max(1, Math.floor(im.height * 0.5));
    ctx.drawImage(im, sx, sy, sw, sh, 0, 0, w, h);
    const d = ctx.getImageData(0, 0, w, h).data;
    let sum = 0, max = 0, min = 255;
    for (let i = 0; i < d.length; i += 4) {
      const lum = 0.2126 * d[i] + 0.7152 * d[i + 1] + 0.0722 * d[i + 2];
      sum += lum;
      if (lum > max) max = lum;
      if (lum < min) min = lum;
    }
    return { avg: Number((sum / (d.length / 4)).toFixed(1)), min: Number(min.toFixed(1)), max: Number(max.toFixed(1)) };
  };`);

  const gpu = await ev(`(() => {
    const gl = window.__ssQA.renderer.getContext();
    const info = gl.getExtension('WEBGL_debug_renderer_info');
    return info ? String(gl.getParameter(info.UNMASKED_RENDERER_WEBGL)) : 'unknown';
  })()`);

  // 隔离灯光贡献：关环境光/环境强度，仅保留 3 盏 QA 灯。
  await ev('window.ss.setPerformanceProfile("high")');
  await ev('window.ss.setEnvIntensity(0)');
  await ev('window.ss.setAmbientEnabled(false)');
  await ev('window.ss.setGrid(false)');
  await ev('window.ss.setSoftShadows(true)');
  await sleep(1200);

  const typeVsm = await ev('JSON.stringify(window.ss.getSoftShadows())');
  const statsA = await ev('window.__qaMeasure("vsm-lights-on")');

  await ev('window.ss.setSoftShadows(false)');
  await sleep(1200);
  const typePcf = await ev('JSON.stringify(window.ss.getSoftShadows())');
  const statsB = await ev('window.__qaMeasure("pcf-lights-on")');

  await ev('window.ss.setSoftShadows(true)');
  await ev('window.ss.applyScene({ lights: [], props: [], subject: {} })');
  await sleep(1200);
  const statsC = await ev('window.__qaMeasure("vsm-lights-off")');
  const lightsDebug = await ev('JSON.stringify(window.ss.getLightDebug())');

  const shots = {};
  const shotNames = {
    'vsm-lights-on': 'vsm-on',
    'pcf-lights-on': 'pcf-on',
    'vsm-lights-off': 'vsm-off',
  };
  for (const token of Object.keys(shotNames)) {
    const dataUrl = await ev(`window.__qaShots[${JSON.stringify(token)}]`);
    if (dataUrl && dataUrl.startsWith('data:image/png;base64,')) {
      shots[token] = path.join(outDir, `vsm-regression-${suffix}-${shotNames[token]}.png`);
      fs.writeFileSync(shots[token], Buffer.from(dataUrl.split(',')[1], 'base64'));
    }
  }

  const ratio = statsA && statsB ? Number((statsA.avg / statsB.avg).toFixed(3)) : null;
  const lightGain = statsA && statsC ? Number((statsA.avg - statsC.avg).toFixed(1)) : null;
  const pass = ratio !== null && lightGain !== null && ratio >= 0.6 && lightGain >= 15;
  const report = {
    at: new Date().toISOString(),
    suffix,
    gpu,
    page: url,
    settings: { performanceProfile: 'high', envIntensity: 0, ambient: false, grid: false },
    shadowTypes: { vsm: typeVsm, pcf: typePcf },
    stats: { vsmLightsOn: statsA, pcfLightsOn: statsB, vsmLightsOff: statsC },
    ratioVsmOverPcf: ratio,
    lightGainVsm: lightGain,
    criteria: { ratioVsmOverPcf: '>= 0.6', lightGainVsm: '>= 15' },
    lights: JSON.parse(lightsDebug || '[]'),
    shots,
    pass,
  };
  fs.mkdirSync(outDir, { recursive: true });
  const reportPath = path.join(outDir, `vsm-regression-${suffix}.json`);
  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2) + '\n');
  console.log(`[vsm-qa] GPU: ${gpu}`);
  console.log(`[vsm-qa] VSM+灯 avg=${statsA?.avg} ｜ PCF+灯 avg=${statsB?.avg} ｜ VSM+0灯 avg=${statsC?.avg}`);
  console.log(`[vsm-qa] ratio=${ratio}（判据>=0.6）｜ 灯光增益=${lightGain}（判据>=15）→ ${pass ? 'PASS' : 'FAIL'}`);
  console.log(`[vsm-qa] 报告：${reportPath}`);
  ws.close();
} finally {
  proc.kill();
  server.close();
}
