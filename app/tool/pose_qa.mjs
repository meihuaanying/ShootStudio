// 姿势质量管线（C1–C4）：姿势规则校正/裁剪、Edge headless 批量渲染、QA 报告。
// 用法（工作目录 app/）：
//   node tool/pose_qa.mjs render [--poses ...] [--char qs-men-casual] [--views 0] [--label %id.png]
//   node tool/pose_qa.mjs photo [--poses assets/content/poses3/poses3.json] [--out docs/pose-qa3]
//   node tool/pose_qa.mjs fix
//   node tool/pose_qa.mjs golden
//   node tool/pose_qa.mjs engine
//   node tool/pose_qa.mjs report
// photo：读 poses3.json（照片姿势库），逐条渲染 3D 同姿态（qs-men/qs-women 各半），
//        再调 extract_pose_skeletons.py stitch-batch 拼「原图|叠加|3D」到 compare-<id>.png
//        并另存 overlay-<id>.png。
// 说明：为规避 file:// 下 fetch 限制，脚本内置静态 HTTP 服务（127.0.0.1 随机端口）承载
// app/ 资源，qa.html 通过 URL 查询参数接收单条姿势关节数据，无需在 file:// 下读取 poses.json。
import http from 'node:http';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawn, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const appRoot = path.resolve(here, '..');
const repoRoot = path.resolve(appRoot, '..');
const defaultPoses = path.join(appRoot, 'assets', 'content', 'poses', 'poses.json');
const defaultOut = path.join(repoRoot, 'docs', 'pose-qa');
const statePath = path.join(defaultOut, 'qa_state.json');

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

function readPoses(file) {
  const raw = JSON.parse(fs.readFileSync(file, 'utf8'));
  return {
    root: raw,
    poses: Array.isArray(raw) ? raw : raw.poses,
  };
}

function writePoses(file, root, poses) {
  const out = Array.isArray(root) ? poses : { ...root, poses };
  fs.writeFileSync(file, JSON.stringify(out, null, 2), 'utf8');
}

function encodePose(pose) {
  const joints = { ...pose.joints, rootY: pose.rootY ?? 0, rootPitch: pose.rootPitch ?? 0 };
  return encodeURIComponent(JSON.stringify(joints));
}

// ---------------- 静态服务器 ----------------
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

// ---------------- Edge CDP ----------------
class CdpPage {
  constructor(wsUrl) {
    this.wsUrl = wsUrl;
    this.id = 0;
    this.pending = new Map();
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

  async render({ url, out, width, height, timeoutMs }) {
    await this.call('Emulation.setDeviceMetricsOverride', {
      width, height, deviceScaleFactor: 1, mobile: false,
    });
    await this.call('Page.enable');
    await this.call('Page.navigate', { url });
    const deadline = Date.now() + timeoutMs;
    let ready = false;
    let error = null;
    while (Date.now() < deadline) {
      const r = await this.call('Runtime.evaluate', {
        expression: 'window.__qaError ? ("ERR:" + window.__qaError) : (window.__qaReady === true ? "READY" : "")',
        returnByValue: true,
      });
      const value = r?.result?.result?.value || '';
      if (value.startsWith('ERR:')) { error = value.slice(4); break; }
      if (value === 'READY') { ready = true; break; }
      await sleep(150);
    }
    if (!ready) throw new Error(error || 'qa 页面未就绪（超时）');
    await sleep(150);
    const shot = await this.call('Page.captureScreenshot', { format: 'png', fromSurface: true });
    const b64 = shot?.result?.data;
    if (!b64 || b64.length < 2000) throw new Error('截图数据为空');
    fs.mkdirSync(path.dirname(out), { recursive: true });
    fs.writeFileSync(out, Buffer.from(b64, 'base64'));
    return Buffer.from(b64, 'base64').length;
  }

  async close() {
    try { this.ws.close(); } catch (_) {}
    try {
      const r = await fetch(`http://127.0.0.1:${this.port}/json/close/${this.targetId}`);
      await r.text();
    } catch (_) {}
  }
}

async function startEdge(port) {
  const edge = EDGE_CANDIDATES.find((p) => fs.existsSync(p));
  if (!edge) throw new Error('未找到 msedge.exe，可用 EDGE 环境变量指定路径');
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'ss-poseqa-'));
  const proc = spawn(edge, [
    '--headless=new', '--disable-gpu', '--use-angle=swiftshader', '--enable-unsafe-swiftshader',
    '--hide-scrollbars', '--mute-audio', '--no-first-run', '--no-default-browser-check',
    '--disable-extensions', '--disable-background-networking', '--window-size=520,760',
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

async function createPage(port, browserPort) {
  const r = await fetch(`http://127.0.0.1:${browserPort || port}/json/new?url=${encodeURIComponent('about:blank')}`, { method: 'PUT' });
  if (!r.ok) throw new Error(`创建页面失败：HTTP ${r.status}`);
  const info = await r.json();
  const page = new CdpPage(info.webSocketDebuggerUrl);
  page.port = port;
  page.targetId = info.id;
  await page.open();
  return page;
}

async function renderJobs(jobs, opts = {}) {
  const workers = opts.workers || 3;
  const width = opts.width || 520;
  const height = opts.height || 760;
  const timeoutMs = opts.timeoutMs || 40000;
  const { server, port } = await startServer();
  const edgePort = 9500 + Math.floor(Math.random() * 350);
  const edge = await startEdge(edgePort);
  const failures = [];
  let done = 0;
  const total = jobs.length;
  const queue = jobs.slice();
  async function worker(id) {
    let page = null;
    for (;;) {
      const job = queue.shift();
      if (!job) break;
      try {
        if (!page) page = await createPage(port, edgePort);
        const url = `http://127.0.0.1:${port}${job.url}`;
        const bytes = await page.render({ url, out: job.out, width, height, timeoutMs });
        if (opts.onBounds) {
          try {
            const r = await page.call('Runtime.evaluate', {
              expression: 'JSON.stringify(window.__qaBounds || null)',
              returnByValue: true,
            });
            const bounds = JSON.parse(r?.result?.result?.value || 'null');
            if (bounds) opts.onBounds(job, bounds);
          } catch (_) { /* 测量失败不阻塞渲染 */ }
        }
        if (opts.onProbe) {
          try {
            const r = await page.call('Runtime.evaluate', {
              expression: 'JSON.stringify(window.__qaProbe || null)',
              returnByValue: true,
            });
            const probe = JSON.parse(r?.result?.result?.value || 'null');
            if (probe) opts.onProbe(job, probe);
          } catch (_) { /* 探针失败不阻塞渲染 */ }
        }
        done++;
        if (done % 20 === 0 || done === total) {
          process.stdout.write(`[qa] ${done}/${total}\r`);
        }
        if (opts.onDone) opts.onDone(job, null, bytes);
      } catch (err) {
        failures.push({ job, error: String(err.message || err) });
        if (opts.onDone) opts.onDone(job, err, 0);
        try { await page.close(); } catch (_) {}
        page = null;
      }
    }
    if (page) await page.close();
  }
  await Promise.all(Array.from({ length: Math.min(workers, Math.max(1, total)) }, (_, i) => worker(i)));
  process.stdout.write('\n');
  edge.proc.kill();
  server.close();
  return failures;
}

function poseUrl(pose, charId, view, extra = '') {
  const params = new URLSearchParams();
  params.set('char', charId);
  params.set('view', String(view));
  params.set('joints', encodePose(pose));
  params.set('duration', '0');
  return `/assets/engine/qa.html?${params.toString()}${extra}`;
}

function labelFor(pattern, pose, view, charId) {
  return pattern
    .replaceAll('%id', pose.id)
    .replaceAll('%v', String(view))
    .replaceAll('%char', charId)
    .replaceAll('%pose', pose.id);
}

// ---------------- 规则校正（C4 + 解剖限制） ----------------
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const has = (s, ...keys) => keys.some((k) => s.includes(k));

const GLOBAL_LIMITS = {
  elbow: { axis: 0, min: -150, max: 5 },
  knee: { axis: 0, min: 0, max: 140 },
  hip: { axis: 0, min: -120, max: 40 },
};

const CATEGORY_RULES = {
  '站姿': { rootY: [-0.08, 0.12] },
  '坐姿': { rootY: [-0.62, -0.12], hipMax: -45, kneeMin: 55 },
  '蹲姿': { rootY: [-0.64, -0.1], hipMax: -35, kneeMin: 70 },
  '跪姿': { rootY: [-0.7, -0.15], kneeMin: 80 },
  '靠姿': { rootY: [-0.25, 0.2] },
  '躺姿': { rootY: [-0.25, 0.3], pitchAbsMin: 72 },
  '动态': { rootY: [-0.4, 0.7] },
  '手部': { rootY: [-0.1, 0.15] },
  '神态': { rootY: [-0.1, 0.15] },
  '道具互动': { rootY: [-0.4, 0.4] },
};

function correctPose(pose, bounds = null) {
  const changes = [];
  const joints = JSON.parse(JSON.stringify(pose.joints || {}));
  const before = JSON.stringify({ joints, rootY: pose.rootY, rootPitch: pose.rootPitch });
  const name = pose.name || '';
  const category = pose.category || '';
  const set = (joint, axis, value, reason) => {
    if (!joints[joint]) joints[joint] = [0, 0, 0];
    if (joints[joint][axis] === value) return;
    changes.push(`${joint}[${axis}] ${Math.round(joints[joint][axis])}→${Math.round(value)}（${reason}）`);
    joints[joint][axis] = value;
  };
  const get = (joint, axis) => ((joints[joint] || [])[axis] || 0);

  for (const side of ['l', 'r']) {
    const elbow = get(`elbow_${side}`, 0);
    const elbowClamped = clamp(elbow, GLOBAL_LIMITS.elbow.min, GLOBAL_LIMITS.elbow.max);
    if (elbow !== elbowClamped) set(`elbow_${side}`, 0, elbowClamped, '肘关节限位');
    const knee = get(`knee_${side}`, 0);
    const kneeClamped = clamp(knee, GLOBAL_LIMITS.knee.min, GLOBAL_LIMITS.knee.max);
    if (knee !== kneeClamped) set(`knee_${side}`, 0, kneeClamped, '膝关节限位');
    const hip = get(`hip_${side}`, 0);
    const hipClamped = clamp(hip, GLOBAL_LIMITS.hip.min, GLOBAL_LIMITS.hip.max);
    if (hip !== hipClamped) set(`hip_${side}`, 0, hipClamped, '髋关节限位');
  }
  if (has(name, '插兜', '手插口袋', '插手插袋')) {
    for (const side of ['l', 'r']) {
      if (get(`elbow_${side}`, 0) > -40) set(`elbow_${side}`, 0, -58, '标题-插兜一致性');
    }
  }
  if (has(name, '回眸', '回头', '回望')) {
    const ry = get('neck', 1);
    if (Math.abs(ry) < 28) set('neck', 1, ry >= 0 ? 32 : -32, '标题-回眸一致性');
  }
  if (has(name, '跳跃', '跳起', '腾空', '跃起')) {
    const ry = Number(pose.rootY ?? 0);
    if (ry < 0.12) changes.push(`rootY ${ry}→0.2（标题-跳跃一致性）`);
    pose = { ...pose, rootY: Math.max(ry, 0.2) };
  }
  if (category === '躺姿' || has(name, '躺', '仰卧', '俯卧', '趴')) {
    const pitch = Number(pose.rootPitch ?? 0);
    if (Math.abs(pitch) < 72) {
      const target = has(name, '俯卧', '趴') ? 88 : -88;
      changes.push(`rootPitch ${pitch}→${target}（躺姿贴地）`);
      pose = { ...pose, rootPitch: target };
    }
  } else if (Math.abs(Number(pose.rootPitch ?? 0)) > 60 && category !== '动态') {
    changes.push(`rootPitch ${pose.rootPitch}→${clamp(Number(pose.rootPitch), -45, 45)}（非躺姿限制）`);
    pose = { ...pose, rootPitch: clamp(Number(pose.rootPitch), -45, 45) };
  }
  if (has(name, '坐') || category === '坐姿') {
    for (const side of ['l', 'r']) {
      if (get(`hip_${side}`, 0) > -45) set(`hip_${side}`, 0, -72, '标题/分类-坐姿一致性');
      if (get(`knee_${side}`, 0) < 55) set(`knee_${side}`, 0, 82, '标题/分类-坐姿一致性');
    }
  }
  if (has(name, '蹲') || category === '蹲姿') {
    for (const side of ['l', 'r']) {
      if (get(`knee_${side}`, 0) < 70) set(`knee_${side}`, 0, 96, '标题/分类-蹲姿一致性');
      if (get(`hip_${side}`, 0) > -35) set(`hip_${side}`, 0, -62, '标题/分类-蹲姿一致性');
    }
  }
  if (has(name, '跪') || category === '跪姿') {
    for (const side of ['l', 'r']) {
      if (get(`knee_${side}`, 0) < 80) set(`knee_${side}`, 0, 102, '标题/分类-跪姿一致性');
    }
  }
  if (has(name, '抱臂', '交叉抱', '抱胸')) {
    for (const side of ['l', 'r']) {
      if (get(`elbow_${side}`, 0) > -75) set(`elbow_${side}`, 0, -98, '标题-抱臂一致性');
    }
  }
  if (has(name, '鞠躬', '弯腰')) {
    if (get('spine', 0) < 20) set('spine', 0, 32, '标题-鞠躬一致性');
  }
  const rule = CATEGORY_RULES[category];
  let rootY = Number(pose.rootY ?? 0);
  const airborne = has(name, '跳跃', '跳起', '腾空', '跃起') || rootY > 0.25;
  if (bounds && !airborne) {
    const target = Number((rootY - bounds.minY).toFixed(3));
    if (Math.abs(bounds.minY) > 0.015) {
      changes.push(`rootY ${rootY}→${target}（接地校准：模型最低点 ${bounds.minY}）`);
    }
    rootY = target;
  } else if (rule?.rootY) {
    const clamped = clamp(rootY, rule.rootY[0], rule.rootY[1]);
    if (clamped !== rootY) changes.push(`rootY ${rootY}→${clamped}（${category}接地区间）`);
    rootY = clamped;
  }
  rootY = clamp(rootY, -0.8, 0.6);
  pose = { ...pose, joints, rootY, rootPitch: clamp(Number(pose.rootPitch ?? 0), -95, 95) };
  const after = JSON.stringify({ joints: pose.joints, rootY: pose.rootY, rootPitch: pose.rootPitch });
  return { pose, changes, changed: before !== after };
}

function validatePose(pose) {
  const reasons = [];
  const get = (j, a) => ((pose.joints?.[j] || [])[a] || 0);
  for (const side of ['l', 'r']) {
    if (get(`elbow_${side}`, 0) > 5) reasons.push(`elbow_${side} 反关节 ${get(`elbow_${side}`, 0)}`);
    if (get(`elbow_${side}`, 0) < -150) reasons.push(`elbow_${side} 超限 ${get(`elbow_${side}`, 0)}`);
    if (get(`knee_${side}`, 0) < 0) reasons.push(`knee_${side} 反向 ${get(`knee_${side}`, 0)}`);
    if (get(`knee_${side}`, 0) > 140) reasons.push(`knee_${side} 超限 ${get(`knee_${side}`, 0)}`);
    if (get(`hip_${side}`, 0) < -120) reasons.push(`hip_${side} 超限 ${get(`hip_${side}`, 0)}`);
    if (get(`hip_${side}`, 0) > 40) reasons.push(`hip_${side} 超限 ${get(`hip_${side}`, 0)}`);
  }
  const rule = CATEGORY_RULES[pose.category || ''];
  if (rule?.rootY) {
    const ry = Number(pose.rootY ?? 0);
    if (ry < rule.rootY[0] - 0.02 || ry > rule.rootY[1] + 0.02) reasons.push(`rootY ${ry} 超出 ${pose.category} 区间`);
  }
  if ((pose.category === '躺姿' || has(pose.name || '', '躺', '卧', '趴')) && Math.abs(Number(pose.rootPitch ?? 0)) < 72) {
    reasons.push(`躺姿 rootPitch ${pose.rootPitch}`);
  }
  if (has(pose.name || '', '跳跃', '跳起') && Number(pose.rootY ?? 0) < 0.12) reasons.push('跳跃 rootY 未离地');
  if (has(pose.name || '', '插兜') && get('elbow_l', 0) > -40 && get('elbow_r', 0) > -40) reasons.push('插兜肘弯曲不足');
  if (has(pose.name || '', '回眸', '回头') && Math.abs(get('neck', 1)) < 28) reasons.push('回眸颈部旋转不足');
  return reasons;
}

function pickGolden(poses, existing = []) {
  if (existing.length >= 12) return existing.slice(0, 12);
  const golden = [];
  const byCategory = new Map();
  for (const p of poses) {
    if (!byCategory.has(p.category)) byCategory.set(p.category, []);
    byCategory.get(p.category).push(p);
  }
  const titlePriority = ['回眸', '插兜', '跳跃', '躺', '坐', '蹲', '跪', '靠', '抱臂', '举手', '走', '跑'];
  const push = (p) => {
    if (golden.length < 12 && p && !golden.includes(p.id)) golden.push(p.id);
  };
  for (const t of titlePriority) {
    const found = poses.find((p) => (p.name || '').includes(t) && !golden.includes(p.id));
    push(found);
  }
  for (const [cat, list] of byCategory) {
    push(list[Math.floor(list.length / 2)]);
    if (golden.length >= 12) break;
    push(list[0]);
  }
  for (const p of poses) {
    if (golden.length >= 12) break;
    push(p);
  }
  return golden.slice(0, 12);
}

function loadState() {
  try { return JSON.parse(fs.readFileSync(statePath, 'utf8')); } catch (_) { return null; }
}

function saveState(state) {
  fs.mkdirSync(defaultOut, { recursive: true });
  fs.writeFileSync(statePath, JSON.stringify(state, null, 2), 'utf8');
}

function countBy(list, key) {
  const out = {};
  for (const item of list) out[item[key]] = (out[item[key]] || 0) + 1;
  return out;
}

// ---------------- 子命令 ----------------
async function cmdRender(args) {
  const posesFile = path.resolve(appRoot, args.poses || defaultPoses);
  const { poses } = readPoses(posesFile);
  const outDir = path.resolve(repoRoot, args.out || defaultOut);
  const charId = args.char || 'qs-men-casual';
  const views = String(args.views || '0').split(',').map(Number);
  const label = args.label || '%id.png';
  const ids = args.ids ? String(args.ids).split(',') : null;
  const limit = args.limit ? Number(args.limit) : 0;
  const extra = args.extra || '';
  let list = poses.filter((p) => !ids || ids.includes(p.id));
  if (limit > 0) list = list.slice(0, limit);
  const jobs = [];
  for (const p of list) {
    for (const v of views) {
      jobs.push({
        pose: p.id,
        view: v,
        url: poseUrl(p, charId, v, extra),
        out: path.join(outDir, labelFor(label, p, v, charId)),
      });
    }
  }
  console.log(`[qa] 渲染 ${list.length} 条姿势 × ${views.length} 视角 = ${jobs.length} 张（char=${charId}）`);
  const state = loadState() || {};
  state.render = state.render || {};
  state.bounds = state.bounds || {};
  const failures = await renderJobs(jobs, {
    workers: Number(args.workers || 3),
    width: 520,
    height: 760,
    onBounds: (job, bounds) => {
      if (job.view === 0) state.bounds[job.pose] = bounds;
    },
  });
  if (failures.length) {
    console.log(`[qa] 失败 ${failures.length} 张：`);
    for (const f of failures.slice(0, 10)) console.log('  -', f.job.out, f.error);
  }
  state.render[`${charId}-v${views.join('_')}`] = {
    count: jobs.length - failures.length,
    failures: failures.map((f) => ({ out: path.relative(repoRoot, f.job.out), error: f.error })),
    at: new Date().toISOString(),
  };
  saveState(state);
  return failures.length === 0 ? 0 : 1;
}

async function cmdFix(args) {
  const posesFile = path.resolve(appRoot, args.poses || defaultPoses);
  const { root, poses } = readPoses(posesFile);
  const corrections = [];
  const suspicious = [];
  const fixed = [];
  const boundsMap = (loadState() || {}).bounds || {};
  let grounded = 0;
  for (const p of poses) {
    const r = correctPose(p, boundsMap[p.id] || null);
    if (r.changes.some((c) => c.includes('接地校准'))) grounded++;
    fixed.push(r.pose);
    if (r.changed) corrections.push({ id: p.id, name: p.name, category: p.category, changes: r.changes });
    const reasons = validatePose(r.pose);
    if (reasons.length) suspicious.push({ id: p.id, name: p.name, category: p.category, reasons });
  }
  // 质量优先裁剪：目标 140，每类至少 8 条，保护标题性姿势与 golden。
  const suspiciousIds = new Set(suspicious.map((s) => s.id));
  const protectedTitles = ['回眸', '回头', '插兜', '跳跃', '躺', '坐', '蹲', '跪', '抱臂'];
  const score = (p) => {
    const c = corrections.find((x) => x.id === p.id);
    return (c ? c.changes.length : 0) + (suspiciousIds.has(p.id) ? 5 : 0);
  };
  const target = Number(args.target || 140);
  let kept = fixed.filter((p) => !suspiciousIds.has(p.id));
  if (kept.length < 120) kept = fixed.slice();
  kept.sort((a, b) => score(a) - score(b) || a.id.localeCompare(b.id));
  const categoryCount = new Map();
  for (const p of kept) categoryCount.set(p.category, (categoryCount.get(p.category) || 0) + 1);
  const minPerCategory = 8;
  const removed = [];
  const incoming = kept.slice();
  kept = [];
  for (const p of incoming) {
    const count = categoryCount.get(p.category) || 0;
    const protectedPose = protectedTitles.some((t) => (p.name || '').includes(t));
    if (kept.length >= target && count > minPerCategory && !protectedPose) {
      removed.push({ id: p.id, name: p.name, category: p.category, reason: `质量裁剪（评分 ${score(p)}，计数优先裁剪）` });
    } else {
      kept.push(p);
      categoryCount.set(p.category, count - 1);
    }
  }
  kept.sort((a, b) => a.id.localeCompare(b.id));
  const keptIds = new Set(kept.map((p) => p.id));
  for (const p of fixed) {
    if (!keptIds.has(p.id) && !removed.some((r) => r.id === p.id)) {
      removed.push({ id: p.id, name: p.name, category: p.category, reason: '质量裁剪（分类配额）' });
    }
  }
  const state = loadState() || {};
  state.fix = {
    at: new Date().toISOString(),
    totalInput: poses.length,
    kept: kept.length,
    categories: countBy(kept, 'category'),
    corrected: corrections.length,
    grounded,
    corrections,
    removed,
    suspicious: suspicious.filter((s) => keptIds.has(s.id)),
  };
  state.golden = pickGolden(kept, state.golden || []);
  writePoses(posesFile, root, kept);
  saveState(state);
  console.log(`[fix] 输入 ${poses.length} → 保留 ${kept.length}（修正 ${corrections.length}，裁剪 ${removed.length}，仍存疑 ${state.fix.suspicious.length}）`);
  console.log(`[fix] 分类：${JSON.stringify(state.fix.categories)}`);
  console.log(`[fix] golden ${state.golden.join(', ')}`);
  return 0;
}

async function cmdGolden(args) {
  const posesFile = path.resolve(appRoot, args.poses || defaultPoses);
  const { poses } = readPoses(posesFile);
  const state = loadState() || {};
  state.golden = pickGolden(poses, state.golden || []);
  saveState(state);
  const ids = new Set(state.golden);
  const list = poses.filter((p) => ids.has(p.id));
  const jobs = [];
  for (const p of list) {
    for (const v of [0, 1, 2, 3]) {
      jobs.push({
        pose: p.id,
        view: v,
        url: poseUrl(p, args.char || 'qs-men-casual', v),
        out: path.join(defaultOut, `${p.id}-v${v}.png`),
      });
    }
  }
  console.log(`[golden] ${list.length} 条 × 4 视角 = ${jobs.length} 张`);
  const failures = await renderJobs(jobs, { workers: Number(args.workers || 3), width: 520, height: 760 });
  state.goldenRenders = { count: jobs.length - failures.length, failures: failures.map((f) => f.job.out) };
  saveState(state);
  return failures.length ? 1 : 0;
}

async function cmdEngine(args) {
  const posesFile = path.resolve(appRoot, args.poses || defaultPoses);
  const { poses } = readPoses(posesFile);
  const chars = String(args.chars || 'qs-men-casual,f-casual,m-suit').split(',');
  const picks = (args.ids || '')
    ? String(args.ids).split(',')
    : poses.filter((p) => ['站姿', '坐姿', '动态'].some((c) => p.category === c)).slice(0, 3).map((p) => p.id);
  const list = picks.map((id) => poses.find((p) => p.id === id)).filter(Boolean);
  const jobs = [];
  for (const charId of chars) {
    for (const p of list) {
      jobs.push({
        pose: p.id,
        view: 0,
        url: poseUrl(p, charId, 0, '&clean=1'),
        out: path.join(defaultOut, `engine-${charId}-${p.id}.png`),
      });
    }
  }
  console.log(`[engine] ${chars.length} 角色 × ${list.length} 姿势 = ${jobs.length} 张`);
  const failures = await renderJobs(jobs, { workers: Number(args.workers || 2), width: 640, height: 900, timeoutMs: 60000 });
  const state = loadState() || {};
  state.engine = {
    at: new Date().toISOString(),
    chars,
    poses: list.map((p) => p.id),
    count: jobs.length - failures.length,
    failures: failures.map((f) => ({ out: path.relative(repoRoot, f.job.out), error: f.error })),
  };
  saveState(state);
  return failures.length ? 1 : 0;
}

async function cmdHands(args) {
  const outDir = path.resolve(repoRoot, args.out || path.join('docs', 'screenshots', 'hands'));
  const timeoutMs = Number(args.timeout || 90000);
  const chars = String(args.chars || 'qs-men-casual,realistic-man-01').split(',').map((s) => s.trim()).filter(Boolean);
  const sides = String(args.sides || 'l,r').split(',').map((s) => s.trim()).filter(Boolean);
  const presets = String(args.presets || 'relax,open,fist,halfGrip,thumbsUp,peace,ok,point,heart,pinch,wave,chinRest,gongshou,qigong,prayer')
    .split(',').map((s) => s.trim()).filter(Boolean);
  const dist = String(args.dist || '0.35');
  const jobs = [];
  for (const charId of chars) {
    for (const side of sides) {
      for (const preset of presets) {
        const handL = side === 'l' ? preset : 'relax';
        const handR = side === 'r' ? preset : 'relax';
        const params = new URLSearchParams({
          char: charId, view: '0', duration: '0', clean: '1',
          handcam: side, handdist: dist, handL, handR,
        });
        jobs.push({
          pose: preset,
          charId,
          side,
          url: `/assets/engine/qa.html?${params.toString()}`,
          out: path.join(outDir, `hand-${charId}-${side}-${preset}.png`),
        });
      }
    }
  }
  const total = jobs.length;
  const skipExisting = args['skip-existing'] === true;
  const renderList = skipExisting ? jobs.filter((j) => !fs.existsSync(j.out)) : jobs;
  console.log(`[hands] ${chars.length} 角色 × ${sides.length} 手 × ${presets.length} 预设 = ${total} 张`
    + (skipExisting ? `（已有 ${total - renderList.length}，待补 ${renderList.length}）` : ''));
  const failures = await renderJobs(renderList, {
    workers: Number(args.workers || 1),
    width: 560,
    height: 700,
    timeoutMs,
  });
  fs.mkdirSync(outDir, { recursive: true });
  const state = loadState() || {};
  state.hands = {
    at: new Date().toISOString(),
    chars,
    sides,
    presets,
    count: total - failures.length,
    skipped: total - renderList.length,
    failures: failures.map((f) => ({ id: f.job.pose, char: f.job.charId, side: f.job.side, error: f.error })),
  };
  saveState(state);
  if (failures.length) {
    console.log(`[hands] 失败 ${failures.length} 张：`);
    for (const f of failures.slice(0, 10)) console.log('  -', f.job.pose, f.job.charId, f.error);
  }
  return failures.length ? 1 : 0;
}

async function cmdHandsEnv(args) {
  const outDir = path.resolve(repoRoot, args.out || path.join('docs', 'screenshots'));
  const charId = String(args.char || 'qs-men-casual');
  const scene = String(args.scene || '');
  const jobs = [];
  for (const ambient of ['0', '1']) {
    const params = new URLSearchParams({
      char: charId, view: '0', duration: '0', clean: '1', lights: '1', ambient,
    });
    if (scene) params.set('joints', scene);
    jobs.push({
      pose: `ambient-${ambient === '1' ? 'on' : 'off'}`,
      charId,
      side: 'l',
      url: `/assets/engine/qa.html?${params.toString()}`,
      out: path.join(outDir, `env-ambient-${ambient === '1' ? 'on' : 'off'}.png`),
    });
  }
  // R34 数值探针：关环境光 + 关全部摄影灯 → 被摄体应为纯黑（仅背景亮）。
  const darkParams = new URLSearchParams({
    char: charId, view: '0', duration: '0', clean: '1', lights: '0', ambient: '0', probe: '1',
  });
  if (scene) darkParams.set('joints', scene);
  jobs.push({
    pose: 'ambient-dark',
    charId,
    side: 'l',
    url: `/assets/engine/qa.html?${darkParams.toString()}`,
    out: path.join(outDir, 'env-ambient-dark.png'),
  });
  console.log(`[hands-env] 环境光开/关对比 + 纯黑探针 = ${jobs.length} 张`);
  const probes = {};
  const failures = await renderJobs(jobs, {
    workers: 1,
    width: 560,
    height: 700,
    timeoutMs: Number(args.timeout || 90000),
    onProbe: (job, probe) => { probes[job.pose] = probe; },
  });
  const state = loadState() || {};
  state.handsEnv = {
    at: new Date().toISOString(),
    char: charId,
    count: jobs.length - failures.length,
    failures: failures.map((f) => ({ id: f.job.pose, error: f.error })),
    probes,
  };
  saveState(state);
  for (const [id, probe] of Object.entries(probes)) {
    console.log(`[hands-env] 探针 ${id}: ${JSON.stringify(probe)}`);
  }
  return failures.length ? 1 : 0;
}

async function cmdMaterial(args) {
  const outDir = path.resolve(repoRoot, args.out || path.join('docs', 'screenshots'));
  const presets = String(args.presets || 'realistic,standard').split(',').map((s) => s.trim()).filter(Boolean);
  const targets = [
    { id: 'skin', char: String(args['skin-char'] || 'realistic-man-01'), focus: 'neck', dist: 0.33, dy: 0.12 },
    { id: 'cloth', char: String(args['cloth-char'] || 'realistic-man-01'), focus: 'spine', dist: 0.8, dy: 0.22 },
    { id: 'metal', char: String(args['metal-char'] || 'qs-men-king'), focus: 'neck', dist: 0.75, dy: 0.16 },
  ].filter((t) => !args.targets || String(args.targets).split(',').includes(t.id));
  const jobs = [];
  for (const target of targets) {
    for (const preset of presets) {
      const params = new URLSearchParams({
        char: target.char,
        view: '0',
        duration: '0',
        clean: '1',
        preset,
        contact: '1',
        focus: target.focus,
        focusdist: String(target.dist),
        focusdy: String(target.dy),
        probe: '1',
      });
      jobs.push({
        pose: `${target.id}-${preset}`,
        charId: target.char,
        side: 'l',
        url: `/assets/engine/qa.html?${params.toString()}`,
        out: path.join(outDir, `material-${target.id}-${preset}.png`),
      });
    }
  }
  // D91 接触阴影开关证据：realistic 开/关 + standard（预设门控，R38）。
  const wanted = args.targets ? String(args.targets).split(',').map((s) => s.trim()) : null;
  if (!wanted || wanted.includes('contact')) {
    const contactChar = String(args['contact-char'] || 'qs-men-casual');
    const contactJobs = [
      { id: 'contact-on', preset: 'realistic', contact: '1' },
      { id: 'contact-off', preset: 'realistic', contact: '0' },
      { id: 'contact-standard', preset: 'standard', contact: '1' },
    ];
    for (const entry of contactJobs) {
      const params = new URLSearchParams({
        char: contactChar,
        view: '0',
        duration: '0',
        clean: '1',
        preset: entry.preset,
        contact: entry.contact,
      });
      jobs.push({
        pose: entry.id,
        charId: contactChar,
        side: 'l',
        url: `/assets/engine/qa.html?${params.toString()}`,
        out: path.join(outDir, `material-${entry.id}.png`),
      });
    }
  }
  console.log(`[material] 特写/接触阴影共 ${jobs.length} 张`);
  const probes = {};
  const failures = await renderJobs(jobs, {
    workers: 1,
    width: 560,
    height: 700,
    timeoutMs: Number(args.timeout || 90000),
    onProbe: (job, probe) => { probes[job.pose] = probe; },
  });
  const state = loadState() || {};
  state.material = {
    at: new Date().toISOString(),
    presets,
    targets: targets.map((t) => ({ id: t.id, char: t.char, focus: t.focus, dist: t.dist, dy: t.dy })),
    count: jobs.length - failures.length,
    failures: failures.map((f) => ({ id: f.job.pose, error: f.error })),
    probes,
  };
  saveState(state);
  for (const [id, probe] of Object.entries(probes)) {
    console.log(`[material] 探针 ${id}: ${JSON.stringify(probe)}`);
  }
  if (failures.length) {
    console.log(`[material] 失败 ${failures.length} 张：`);
    for (const f of failures.slice(0, 10)) console.log('  -', f.job.pose, f.job.charId, f.error);
  }
  return failures.length ? 1 : 0;
}

async function cmdPhoto(args) {
  const posesFile = path.resolve(appRoot, args.poses || path.join(appRoot, 'assets', 'content', 'poses3', 'poses3.json'));
  const { poses } = readPoses(posesFile);
  const outDir = path.resolve(repoRoot, args.out || path.join(repoRoot, 'docs', 'pose-qa3'));
  const stamps = String(args.stamp || '').trim();
  const rendersDir = stamps
    ? path.resolve(outDir, stamps)
    : fs.mkdtempSync(path.join(os.tmpdir(), 'ss-p3-render-'));
  fs.mkdirSync(rendersDir, { recursive: true });
  const chars = String(args.chars || 'qs-men-casual,qs-women-casual').split(',').map((s) => s.trim()).filter(Boolean);
  const ids = args.ids ? String(args.ids).split(',') : null;
  const limit = args.limit ? Number(args.limit) : 0;
  const ground = args.ground !== false && args['no-ground'] !== true;
  let list = poses.filter((p) => !ids || ids.includes(p.id));
  if (limit > 0) list = list.slice(0, limit);
  const mkJobs = (items) => items.map((p) => {
    const i = list.indexOf(p);
    const charId = chars[(i >= 0 ? i : 0) % chars.length];
    return {
      pose: p.id,
      view: 0,
      charId,
      url: poseUrl(p, charId, 0, '&clean=1'),
      out: path.join(rendersDir, `${p.id}__${charId}.png`),
    };
  });
  const bounds = {};
  const onBounds = (job, b) => { if (b) bounds[job.pose] = { ...b, char: job.charId }; };
  const renderOnce = async (jobs, workers) => renderJobs(jobs, {
    workers,
    width: Number(args.width || 560),
    height: Number(args.height || 820),
    timeoutMs: Number(args.timeout || 60000),
    onBounds,
  });
  const retry = async (failures) => {
    if (!failures.length || args.retry === false) return failures;
    console.log(`[photo] 首轮失败 ${failures.length} 条，单线程重试…`);
    return renderOnce(failures.map((f) => f.job), 1);
  };

  let jobs = mkJobs(list);
  console.log(`[photo] 渲染 ${jobs.length} 条姿势 × 1 视角（char=${chars.join('/')} 交替，临时目录 ${rendersDir}）`);
  let failures = await retry(await renderOnce(jobs, Number(args.workers || 3)));

  const calibrations = [];
  if (ground) {
    const airborneRe = /跳|跃|腾空|flight/i;
    let changed = 0;
    for (const pose of poses) {
      if (ids && !ids.includes(pose.id)) continue;
      const b = bounds[pose.id];
      if (!b || typeof b.minY !== 'number') continue;
      const before = Number(pose.rootY ?? 0);
      const airborne = pose.category === '动态' || airborneRe.test(pose.name || '');
      let after = airborne ? Math.max(before, 0.2) : before - b.minY;
      after = Math.max(-1.15, Math.min(0.6, Number(after.toFixed(3))));
      if (Math.abs(after - before) > 0.001) {
        calibrations.push({ id: pose.id, category: pose.category, before, minY: Number(b.minY.toFixed(3)), after, airborne });
        pose.rootY = after;
        changed++;
      }
    }
    if (changed > 0) {
      const root = JSON.parse(fs.readFileSync(posesFile, 'utf8'));
      root.poses = poses;
      fs.writeFileSync(posesFile, JSON.stringify(root, null, 2), 'utf8');
      console.log(`[photo] 接地校准：${changed} 条 rootY 修正，重渲染…`);
      jobs = mkJobs(list);
      failures = await retry(await renderOnce(jobs, Number(args.workers || 3)));
    } else {
      console.log('[photo] 接地校准：无需修正');
    }
  }
  fs.mkdirSync(outDir, { recursive: true });
  const stateFile = path.join(outDir, 'qa_photo_state.json');
  let state = {};
  try { state = JSON.parse(fs.readFileSync(stateFile, 'utf8')); } catch (_) { state = {}; }
  // 校准记录跨轮累积（按 id 合并，后写入者覆盖）：保证接地校准可追溯（R20/D68）。
  // 骨架/照片重建会重置 rootY，与当前值不符的历史记录已不可追溯，先剔除。
  const currentRootY = new Map(poses.map((p) => [p.id, Number(p.rootY ?? 0)]));
  const previousCalibrations = (
    Array.isArray(state.photo?.calibrations) ? state.photo.calibrations : []
  ).filter(
    (c) => typeof c?.after === 'number' && currentRootY.has(c.id) &&
      Math.abs(currentRootY.get(c.id) - c.after) <= 0.005,
  );
  const mergedCalibrations = new Map(previousCalibrations.map((c) => [c.id, c]));
  for (const c of calibrations) mergedCalibrations.set(c.id, c);
  // bounds 同样跨轮合并：--ids 单点重跑不应清空其余姿势的接地测量证据。
  const previousBounds = (
    state.photo?.bounds && typeof state.photo.bounds === 'object'
      ? state.photo.bounds
      : {}
  );
  const mergedBounds = { ...previousBounds, ...bounds };
  state.photo = {
    at: new Date().toISOString(),
    poses: posesFile,
    chars,
    count: Object.keys(mergedBounds).length,
    renderedThisRun: jobs.length - failures.length,
    failures: failures.map((f) => ({ id: f.job.pose, char: f.job.charId, error: f.error })),
    ground,
    calibrations: Array.from(mergedCalibrations.values()),
    // 全量接地验证快照：每条姿势最终 rootY 下模型最低点（|minY| 越小越贴地）。
    grounding: ground
      ? poses
          .filter((p) => mergedBounds[p.id] && typeof mergedBounds[p.id].minY === 'number')
          .map((p) => ({
            id: p.id,
            rootY: Number(p.rootY ?? 0),
            minY: Number(mergedBounds[p.id].minY.toFixed(3)),
            airborne: p.category === '动态' || /跳|跃|腾空|flight/i.test(p.name || ''),
          }))
      : [],
    bounds: mergedBounds,
  };
  fs.writeFileSync(stateFile, JSON.stringify(state, null, 2), 'utf8');
  if (failures.length) {
    console.log(`[photo] 渲染失败 ${failures.length} 条：`);
    for (const f of failures.slice(0, 10)) console.log('  -', f.job.pose, f.error);
  }
  if (args.stitch === false || args['no-stitch'] === true) return failures.length ? 1 : 0;
  const py = process.env.PYTHON || 'python';
  const pyArgs = [
    path.join(here, 'extract_pose_skeletons.py'), 'stitch-batch',
    '--poses', posesFile, '--renders', rendersDir, '--out', outDir,
  ];
  if (args.ids) pyArgs.push('--ids', String(args.ids));
  console.log(`[photo] 拼接对比图 -> ${outDir}`);
  const res = spawnSync(py, pyArgs, { stdio: 'inherit', cwd: appRoot });
  if (res.error) console.error('[photo] 拼接调用失败：', res.error.message);
  if (res.status !== 0 && res.status !== 1) console.error(`[photo] stitch-batch 退出码 ${res.status}`);
  return failures.length ? 1 : 0;
}

async function cmdReport() {
  const state = loadState() || {};
  fs.mkdirSync(defaultOut, { recursive: true });
  const files = fs.readdirSync(defaultOut).filter((f) => f.endsWith('.png')).sort();
  const poseFiles = files.filter((f) => /^pose-|^[a-z]+-\d+/.test(f) === false && !f.startsWith('engine-'));
  const lines = [];
  lines.push('# 姿势 QA 报告（docs/pose-qa）');
  lines.push('');
  lines.push(`生成时间：${new Date().toISOString()}`);
  lines.push('');
  lines.push('## 渲染方法');
  lines.push('');
  lines.push('- 使用内置静态 HTTP 服务（127.0.0.1 随机端口）承载 app/ 资源，规避 file:// 下 fetch/GLB 外链限制；');
  lines.push('- Edge headless（`--headless=new --use-angle=swiftshader --enable-unsafe-swiftshader`）经 CDP 截屏，视口 520×760（引擎图 640×900）；');
  lines.push('- 姿势数据由 Node 读取 poses.json 并以查询参数传入 qa.html，逐条渲染正视图；golden 12 条渲染 4 视角；');
  lines.push(`- 截图总数：${files.length}（含 golden 4 视角与引擎人物图）。`);
  lines.push('');
  if (state.fix) {
    lines.push('## 分类统计（最终上架）');
    lines.push('');
    lines.push('| 分类 | 数量 |');
    lines.push('| --- | --- |');
    for (const [k, v] of Object.entries(state.fix.categories)) lines.push(`| ${k} | ${v} |`);
    lines.push('');
    lines.push(`- 输入：${state.fix.totalInput} 条；保留：${state.fix.kept} 条；规则修正：${state.fix.corrected} 条；裁剪：${state.fix.removed.length} 条。`);
    lines.push('');
    lines.push('## 被裁姿势及原因');
    lines.push('');
    if (!state.fix.removed.length) lines.push('- 无。');
    for (const r of state.fix.removed) {
      lines.push(`- ${r.id} ${r.name}（${r.category}）：${r.reason}`);
    }
    lines.push('');
    lines.push('## 仍存疑清单（已上架但需人工复核）');
    lines.push('');
    if (!state.fix.suspicious.length) lines.push('- 无。');
    for (const s of state.fix.suspicious) {
      lines.push(`- ${s.id} ${s.name}（${s.category}）：${s.reasons.join('；')}`);
    }
    lines.push('');
    lines.push('## 规则修正统计（前 40 条示例）');
    lines.push('');
    for (const c of state.fix.corrections.slice(0, 40)) {
      lines.push(`- ${c.id} ${c.name}：${c.changes.join('；')}`);
    }
    if (state.fix.corrections.length > 40) lines.push(`- …其余 ${state.fix.corrections.length - 40} 条见 qa_state.json`);
    lines.push('');
  }
  if (state.golden?.length) {
    lines.push('## Golden 12（4 视角）');
    lines.push('');
    for (const id of state.golden) {
      lines.push(`- ${id}：${[0, 1, 2, 3].map((v) => `${id}-v${v}.png`).join('、')}`);
    }
    lines.push('');
  }
  if (state.engine) {
    lines.push('## 引擎人物渲染');
    lines.push('');
    lines.push(`- 角色：${state.engine.chars.join('、')}；姿势：${state.engine.poses.join('、')}；成功 ${state.engine.count} 张。`);
    if (state.engine.failures?.length) {
      for (const f of state.engine.failures) lines.push(`- 失败：${f.out}（${f.error}）`);
    }
    lines.push('');
  }
  if (state.render) {
    lines.push('## 渲染批次');
    lines.push('');
    for (const [k, v] of Object.entries(state.render)) {
      lines.push(`- ${k}：成功 ${v.count}${v.failures?.length ? `，失败 ${v.failures.length}` : ''}`);
    }
    lines.push('');
  }
  lines.push('## 截图清单（最终姿势）');
  lines.push('');
  lines.push('| 姿势 | 正视图 | golden 4 视角 |');
  lines.push('| --- | --- | --- |');
  const finalPoses = JSON.parse(fs.readFileSync(defaultPoses, 'utf8')).poses;
  const goldenOnDisk = new Set(
    files
      .filter((f) => /-v\d+\.png$/.test(f))
      .map((f) => f.replace(/-v\d+\.png$/, '')),
  );
  for (const p of finalPoses) {
    const golden = goldenOnDisk.has(p.id)
      ? [0, 1, 2, 3].map((v) => `${p.id}-v${v}.png`).join('<br>')
      : '—';
    lines.push(`| ${p.id} ${p.name} | ${p.id}.png | ${golden} |`);
  }
  lines.push('');
  lines.push('> 被裁姿势的原始截图仍保留在 docs/pose-qa/ 作为校对证据。');
  fs.writeFileSync(path.join(defaultOut, 'QA_REPORT.md'), lines.join('\n'), 'utf8');
  console.log(`[report] ${path.join(defaultOut, 'QA_REPORT.md')}（${finalPoses.length} 条最终姿势，${files.length} 张截图）`);
  return 0;
}

const args = parseArgs(process.argv.slice(2));
const cmd = args._[0];
let code = 0;
if (cmd === 'render') code = await cmdRender(args);
else if (cmd === 'photo') code = await cmdPhoto(args);
else if (cmd === 'hands') code = await cmdHands(args);
else if (cmd === 'hands-env') code = await cmdHandsEnv(args);
else if (cmd === 'material') code = await cmdMaterial(args);
else if (cmd === 'fix') code = await cmdFix(args);
else if (cmd === 'golden') code = await cmdGolden(args);
else if (cmd === 'engine') code = await cmdEngine(args);
else if (cmd === 'report') code = await cmdReport();
else {
  console.log('用法：node tool/pose_qa.mjs <render|photo|fix|golden|engine|report> [选项]');
  console.log('  render --poses <json> --char qs-men-casual --views 0 --label %id.png --ids a,b --limit N');
  console.log('  photo  --poses assets/content/poses3/poses3.json --out docs/pose-qa3 --chars qs-men-casual,qs-women-casual --ids a,b --limit N');
  console.log('  hands  --chars qs-men-casual,realistic-man-01 --sides l,r --presets a,b --out docs/screenshots/hands [--workers 1] [--timeout 90000]');
  console.log('  hands-env --char qs-men-casual --out docs/screenshots');
  console.log('  material --presets realistic,standard --out docs/screenshots [--skin-char realistic-man-01]');
  console.log('  fix    --target 140');
  console.log('  golden');
  console.log('  engine --chars qs-men-casual,f-casual,m-suit --ids pose-001,pose-010');
  console.log('  report');
}
process.exit(code);
