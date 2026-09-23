// V7/S3.4：相机辅助专项 QA（headed + 独显；R61 证据）。
//
// 验证内容（D139）：
//   1. getCameraAssist() 焦段 → 视野/画幅/主体距离数值正确（与 rig.js focalToFov 同口径）；
//   2. 路径追踪景深真实生效：同机位三张静帧对比
//        A. 无景深      B. f/1.4 自动对焦（主体）    C. f/1.4 手动对焦 1.0m（主体失焦）
//      判据：C 清晰度 <= 0.6 × A（景深确实生效）；B >= 0.75 × A（自动对焦对准主体）。
//   3. stillRendered 事件回传 dof/fStop/focusDistance（R69 降级标记另见 dofFallback）。
//
// 用法：node tool/camera_assist_qa.mjs [--suffix r186s34] [--port 9988] [--samples 48]
// 清晰度口径说明：主体带（subject）梯度用于景深判据；分辨率/采样数越高，噪声越低、判据越可靠
// （默认 480×360 × 48 samples ≈ 2.3s/sample；首次另含路径追踪编译 ~30s）。
// 输出：docs/qa/camera-assist-<suffix>.json + docs/qa/camera-assist-<suffix>-{nodof,dof-auto,dof-near}.png

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
const suffix = arg('suffix', 'r186s34');
const edgePort = Number(arg('port', 9988));
const samples = Number(arg('samples', 48));
const width = Number(arg('w', 480));
const height = Number(arg('h', 360));
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

const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'ss-camqa-'));
const proc = spawn(EDGE, [
  '--force_high_performance_gpu',
  '--hide-scrollbars',
  '--no-first-run',
  // 防止窗口被遮挡/后台化时 rAF 与定时器被冻结（路径追踪采样依赖 rAF 驱动）。
  '--disable-backgrounding-occluded-windows',
  '--disable-renderer-backgrounding',
  '--disable-background-timer-throttling',
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
  // 不等待 Promise 的求值（renderStill 会挂起直到采样完成，避免 CDP awaitPromise 卡死）。
  const fire = async (expr) => {
    const r = await call('Runtime.evaluate', { expression: expr, returnByValue: false, awaitPromise: false });
    const ex = r?.result?.exceptionDetails;
    if (ex) console.log('  [JS 异常]', JSON.stringify(ex).slice(0, 300));
    return r?.result?.result?.value;
  };
  await call('Page.enable');
  await call('Page.bringToFront');

  const url = `http://127.0.0.1:${port}/assets/engine/qa.html?char=qs-women-casual&view=0&duration=0&clean=1&lights=1`;
  await call('Page.navigate', { url });
  for (let i = 0; i < 400; i++) { if (await ev('window.__qaReady === true')) break; await sleep(250); }
  const qaError = await ev('window.__qaError || null');
  if (qaError) console.log('  [qaError]', qaError);

  // 清晰度探针：梯度幅值均值（8 邻域 |Δlum|），越模糊越小。
  // 返回两个口径：all（全图）与 subject（主体带：画面中央，机位对准主体；避开近景地面，
  // 因为对焦 1m 时近景地面会变锐，会污染全图口径）。
  await ev(`window.__qaSharp = async (dataUrl) => {
    const im = new Image();
    await new Promise((res, rej) => { im.onload = res; im.onerror = rej; im.src = dataUrl; });
    const w = 160, h = 120;
    const c = document.createElement('canvas');
    c.width = w; c.height = h;
    const ctx = c.getContext('2d');
    ctx.drawImage(im, 0, 0, im.width, im.height, 0, 0, w, h);
    const d = ctx.getImageData(0, 0, w, h).data;
    const lum = new Float32Array(w * h);
    for (let i = 0; i < w * h; i++) {
      lum[i] = 0.2126 * d[i * 4] + 0.7152 * d[i * 4 + 1] + 0.0722 * d[i * 4 + 2];
    }
    const grad = (x0, y0, x1, y1) => {
      let sum = 0, n = 0;
      for (let y = y0; y < y1; y++) {
        for (let x = x0; x < x1; x++) {
          const i = y * w + x;
          const gx = lum[i + 1] - lum[i - 1];
          const gy = lum[i + w] - lum[i - w];
          sum += Math.sqrt(gx * gx + gy * gy);
          n++;
        }
      }
      return n ? Number((sum / n).toFixed(3)) : 0;
    };
    const sub = {
      x0: Math.round(0.30 * w), y0: Math.round(0.10 * h),
      x1: Math.round(0.78 * w), y1: Math.round(0.80 * h),
    };
    return { all: grad(1, 1, w - 1, h - 1), subject: grad(sub.x0, sub.y0, sub.x1, sub.y1), region: sub };
  };`);

  // 主体区峰值边缘锐度（主判据）：主体框（机位始终对准主体 → 主体恒居中，取 x 0.36–0.64 / y 0.05–0.80）
  // 内梯度的 p95（峰值边缘陡度）。景深生效时主体轮廓被模糊 → p95 大幅下降；自动对焦时保持。
  // 为什么不用全图/大范围均值：近景地面在手动对焦 1m 时会变锐、大光圈噪声会抬高平坦区梯度，
  // 两者都会污染均值类口径（实测主体带均值比值仅 0.78–1.29，无法判别）。
  await ev(`window.__qaEdgePeak = async (url) => {
    const W = 160, H = 120;
    const im = new Image();
    await new Promise((res, rej) => { im.onload = res; im.onerror = rej; im.src = url; });
    const c = document.createElement('canvas');
    c.width = W; c.height = H;
    const ctx = c.getContext('2d');
    ctx.drawImage(im, 0, 0, im.width, im.height, 0, 0, W, H);
    const d = ctx.getImageData(0, 0, W, H).data;
    const lum = new Float32Array(W * H);
    for (let i = 0; i < W * H; i++) lum[i] = 0.2126 * d[i * 4] + 0.7152 * d[i * 4 + 1] + 0.0722 * d[i * 4 + 2];
    const x0 = Math.round(0.36 * W), x1 = Math.round(0.64 * W);
    const y0 = Math.round(0.05 * H), y1 = Math.round(0.80 * H);
    const vals = [];
    for (let y = y0; y < y1; y++) {
      for (let x = x0; x < x1; x++) {
        const i = y * W + x;
        const gx = lum[i + 1] - lum[i - 1];
        const gy = lum[i + W] - lum[i - W];
        vals.push(Math.sqrt(gx * gx + gy * gy));
      }
    }
    vals.sort((a, b) => a - b);
    const pick = (q) => vals[Math.min(vals.length - 1, Math.floor(q * vals.length))];
    const mean = vals.reduce((s, v) => s + v, 0) / vals.length;
    return { p95: Number(pick(0.95).toFixed(3)), p90: Number(pick(0.9).toFixed(3)), mean: Number(mean.toFixed(3)), n: vals.length };
  };`);

  const callStill = async (spec) => {
    const before = await ev('(window.__ssOutbox || []).length');
    await fire(`window.ss.renderStill(${JSON.stringify(spec)})`);
    for (let i = 0; i < 1200; i++) {
      const raw = await ev(`(() => {
        const out = (window.__ssOutbox || []).slice(${before});
        const hit = out.filter((m) => m.includes('"stillRendered"')).pop();
        return hit || '';
      })()`);
      if (raw) {
        const parsed = JSON.parse(raw);
        return { ...parsed, sharpness: parsed.dataUrl ? await ev(`window.__qaSharp(${JSON.stringify(parsed.dataUrl)})`) : null };
      }
      await sleep(500);
    }
    return null;
  };

  const gpu = await ev(`(() => {
    const gl = window.__ssQA.renderer.getContext();
    const info = gl.getExtension('WEBGL_debug_renderer_info');
    return info ? String(gl.getParameter(info.UNMASKED_RENDERER_WEBGL)) : 'unknown';
  })()`);

  // 固定量测环境：独显高档 + 关环境光（避免环境亮度干扰清晰度对比）。
  await ev('window.ss.setPerformanceProfile("high")');
  await ev('window.ss.setEnvIntensity(0)');
  await ev('window.ss.setAmbientEnabled(false)');
  await ev('window.ss.setGrid(false)');
  await sleep(800);

  // 机位：85mm、高 1.35m、距离 5.5m（主体充满画面中部，背景可见）。
  await ev('window.ss.setCameraRig({ x: 0, y: 5.5, height: 1.35, yaw: 0, pitch: 0, focal: 85, enabled: true })');
  await ev('window.ss.setCameraView(true)');
  await sleep(600);
  const assistRaw = await ev('JSON.stringify(window.ss.getCameraAssist())');
  const assist = JSON.parse(assistRaw || '{}');

  // 理论值：垂直视场角 = 2·atan(24/(2f))；主体距离 = 相机到 (0, 1.35, 0)。
  const expectedVFov = Number((2 * Math.atan(24 / (2 * 85)) * 180 / Math.PI).toFixed(2));
  const expectedDistance = Number(Math.sqrt(5.5 * 5.5 + (1.35 - 1.35) ** 2).toFixed(2));
  const expectedFrameHeight = Number((2 * expectedDistance * Math.tan((expectedVFov * Math.PI / 180) / 2)).toFixed(2));

  const shotNames = { nodof: 'nodof', 'dof-auto': 'dof-auto', 'dof-near': 'dof-near' };
  const stills = {};
  stills.nodof = await callStill({ mode: 'path', width, height, samples, bounces: 3, useCameraRig: true });
  stills['dof-auto'] = await callStill({
    mode: 'path', width, height, samples, bounces: 3, useCameraRig: true,
    dof: { enabled: true, fStop: 1.4, focusMode: 'auto' },
  });
  stills['dof-near'] = await callStill({
    mode: 'path', width, height, samples, bounces: 3, useCameraRig: true,
    dof: { enabled: true, fStop: 1.4, focusMode: 'manual', focusDistance: 1.0 },
  });

  const shots = {};
  for (const [key, name] of Object.entries(shotNames)) {
    const dataUrl = stills[key]?.dataUrl;
    if (dataUrl && dataUrl.startsWith('data:image/png;base64,')) {
      shots[key] = path.join(outDir, `camera-assist-${suffix}-${name}.png`);
      fs.writeFileSync(shots[key], Buffer.from(dataUrl.split(',')[1], 'base64'));
    }
  }

  // 主体区峰值边缘锐度（主判据）：p95 用于判别，p90/mean 仅作报告参考。
  const peak = async (u) => u ? await ev(`window.__qaEdgePeak(${JSON.stringify(u)})`) : null;
  const pA = await peak(stills.nodof?.dataUrl);
  const pB = await peak(stills['dof-auto']?.dataUrl);
  const pC = await peak(stills['dof-near']?.dataUrl);
  const peakAutoRatio = pA?.p95 && pB?.p95 ? Number((pB.p95 / pA.p95).toFixed(3)) : null;
  const peakNearRatio = pA?.p95 && pC?.p95 ? Number((pC.p95 / pA.p95).toFixed(3)) : null;

  const sA = stills.nodof?.sharpness ?? null;
  const sB = stills['dof-auto']?.sharpness ?? null;
  const sC = stills['dof-near']?.sharpness ?? null;
  const nearRatio = sA && sC ? Number((sC.all / sA.all).toFixed(3)) : null;
  const autoRatio = sA && sB ? Number((sB.all / sA.all).toFixed(3)) : null;
  const subjectNearRatio = sA && sC ? Number((sC.subject / sA.subject).toFixed(3)) : null;
  const subjectAutoRatio = sA && sB ? Number((sB.subject / sA.subject).toFixed(3)) : null;
  const assistOk =
    Math.abs((assist.fovDeg ?? -1) - expectedVFov) <= 0.5 &&
    Math.abs((assist.subjectDistance ?? -1) - expectedDistance) <= 0.15 &&
    Math.abs((assist.frameHeightAtSubject ?? -1) - expectedFrameHeight) <= 0.08 &&
    assist.dofAvailable === true;
  const dofPayloadOk =
    stills['dof-auto']?.dof === true &&
    stills['dof-auto']?.fStop === 1.4 &&
    stills['dof-auto']?.focusDistance > 4.5 && stills['dof-auto']?.focusDistance < 6.5 &&
    stills['dof-near']?.focusDistance === 1;
  const blurOk = peakNearRatio !== null && peakNearRatio <= 0.6;
  const autoFocusOk = peakAutoRatio !== null && peakAutoRatio >= 0.75;

  const report = {
    at: new Date().toISOString(),
    suffix,
    gpu,
    page: url,
    settings: { performanceProfile: 'high', envIntensity: 0, ambient: false, samples, width, height, bounces: 3 },
    rig: { x: 0, y: 5.5, height: 1.35, yaw: 0, pitch: 0, focal: 85 },
    assist,
    expected: { fovDeg: expectedVFov, subjectDistance: expectedDistance, frameHeightAtSubject: expectedFrameHeight },
    stills: {
      nodof: stills.nodof && { ...stills.nodof, dataUrl: undefined },
      dofAuto: stills['dof-auto'] && { ...stills['dof-auto'], dataUrl: undefined },
      dofNear: stills['dof-near'] && { ...stills['dof-near'], dataUrl: undefined },
    },
    sharpness: { nodof: sA, dofAuto: sB, dofNear: sC, nearRatio, autoRatio, subjectNearRatio, subjectAutoRatio },
    edges: { nodof: pA, dofAuto: pB, dofNear: pC, peakAutoRatio, peakNearRatio },
    criteria: {
      assist: 'fovDeg ±0.5 / subjectDistance ±0.15 / frameHeightAtSubject ±0.08 / dofAvailable',
      dofPayload: 'dof=true, fStop=1.4, auto 对焦距离 4.5–6.5m, 手动=1.0m',
      blur: 'peakNearRatio <= 0.6（主体框 p95 边缘锐度：手动对焦 1m 相对无景深下降 = 景深生效）',
      autoFocus: 'peakAutoRatio >= 0.75（自动对焦保持主体框 p95 边缘锐度）',
    },
    shots,
    pass: !!(assistOk && dofPayloadOk && blurOk && autoFocusOk),
  };
  fs.mkdirSync(outDir, { recursive: true });
  const reportPath = path.join(outDir, `camera-assist-${suffix}.json`);
  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2) + '\n');
  console.log(`[cam-qa] GPU: ${gpu}`);
  console.log(`[cam-qa] assist: fov=${assist.fovDeg}°（期望 ${expectedVFov}）｜ 主体距离=${assist.subjectDistance}m（期望 ${expectedDistance}）｜ 画幅高=${assist.frameHeightAtSubject}m（期望 ${expectedFrameHeight}）｜ 景深可用=${assist.dofAvailable}`);
  console.log(`[cam-qa] 清晰度（全图）：无景深 ${sA?.all} ｜ 自动对焦 ${sB?.all}（比值 ${autoRatio}）｜ 手动 1m ${sC?.all}（比值 ${nearRatio}）`);
  console.log(`[cam-qa] 清晰度（主体带）：无景深 ${sA?.subject} ｜ 自动对焦 ${sB?.subject}（比值 ${subjectAutoRatio}）｜ 手动 1m ${sC?.subject}（比值 ${subjectNearRatio}）`);
  console.log(`[cam-qa] 边缘峰值（主判据，主体框 p95）：无景深 ${pA?.p95} ｜ 自动对焦 ${pB?.p95}（比值 ${peakAutoRatio}）｜ 手动 1m ${pC?.p95}（比值 ${peakNearRatio}）`);
  console.log(`[cam-qa] assist=${assistOk} payload=${dofPayloadOk} blur=${blurOk} autoFocus=${autoFocusOk} → ${report.pass ? 'PASS' : 'FAIL'}`);
  console.log(`[cam-qa] 报告：${reportPath}`);
  ws.close();
} finally {
  proc.kill();
  server.close();
}
