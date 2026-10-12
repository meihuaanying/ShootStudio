// V8/P2 · 引擎性能门禁（CI 版）。
//
// 用法：node tool/engine_perf_gate.mjs   （可用 PERF_GATE_ATTEMPTS 覆盖尝试次数）
// 前置：app/assets/engine/ 已就位；CI 需安装 Edge（见 ci.yml 的 engine-gate job）。
//
// ── 为什么这个门禁不长这样：「p95 <= 16ms」──
//
// 合同 D152 写「拖动灯具 p95 帧耗时 <=16ms，记录实测；达不到则在 spike 报告说明并
// 给降档策略」。该口径是**有独显的真实工作机**口径，已在 S2 spike 实测登记：
//   docs/qa/v8-s2-engine-perf-gtx4060-dpr1.json  lightDrag p95 17.5ms
//   docs/qa/v8-s2-engine-perf-gtx4060-dpr2.json
// 这些数字来自本机手动运行（headless + --force_high_performance_gpu）。
//
// 而 GitHub runner **没有 GPU**：同一指标在 runner 上用 SwiftShader 软渲染跑出来是
//   docs/qa/v8-s2-engine-perf-swiftshader-dpr1.json
//     idle frames=2 p95=1500.2 | orbit frames=3 p95=1574.1
//     lightDrag frames=3 p95=1554.8 | dolly frames=1 p95=1469.4   fps=0.7
// 每段只有 1~3 个采样点、p95 超过 1.4 秒 —— 这个数字既不是「引擎慢」，也不是
// 「GPU 不行」，而是**统计上无意义**。
//
// 所以本门禁**刻意不设绝对帧耗时阈值**：在 GPU-less 环境设绝对阈值，结果只能是
// 「阈值定得很松所以永远绿」（装饰）或者「永远红」（阻碍合入），两者都是假门禁。
//
// ── 本门禁判定什么（P2-3 修订：逐相位帧数不再硬判，见下）──
//
// 硬判（CI 真能稳定抓到的回归）：
//   1. 测量链路仍然可用 —— Edge 起得来、CDP 连得上、引擎页面能加载、进程 exit 0；
//   2. 引擎仍在出帧 —— 全部尝试合并后总帧数 > 0（渲染循环真被打断时这里归零）
//      【注意判据是「总帧数 > 0」而不是「每个相位都 > 0」，原因见下一节】；
//   3. 统计字段齐全且为数值 —— 有人把 stats() 改坏会红；
//   4. 预热确实 settled、灯体确实被拖到（lightPoint.ok）—— 保证采的不是冷启动抖动。
//
// 只登记、不判红（打印 NOTE，并写进入库证据 JSON）：
//   5. 逐相位 engineFrames 与入库 swiftshader 基线的差距。
//
// 绝对帧耗时阈值仍是人工判据：改动渲染路径后，按 HANDOFF 的口径在独显机上
// 手动跑 `node tool/engine_perf_qa.mjs --label <说明>` 并把 JSON 入库。
//
// ── 为什么「逐相位 engineFrames > 0」这个判据被撤掉（v8.4.0 的 CI 红就是它）──
//
// 初版门禁要求四个相位各自 engineFrames > 0。v8.4.0 的 run 38109551427 上它红了 8 项：
//   FAIL idle 引擎有出帧 :: engineFrames=0
//   FAIL dolly 引擎有出帧 :: engineFrames=0
//   FAIL idle/dolly 帧数未灾难回退 (>= 1)
//   FAIL idle/dolly 的 mean / fpsMean 为数值
// 而同一次运行 orbit=1、lightDrag=1 —— **渲染循环明明是活的**。
// （v8.4.0 本身只加了一个 Dart 测试文件，与引擎无关；v8.3.0 上同一条门禁是绿的。）
//
// 根因不是产品回归，是判据本身站不住：
//   - 引擎是**连续 rAF 循环**（engine.js:1483 `requestAnimationFrame(frame)`），
//     不是 render-on-demand，所以 idle 理论上也该持续出帧；
//   - 但在 headless 下 rAF 的触发取决于页面是否被浏览器当作可见/前台
//     （V8-s2 基线 SwiftShader 下 fps 仅 0.7，即 2 秒 ≈ 1.4 帧），
//     于是「某一段窗口里一帧都没采到」是**二值噪音**，不是性能回归；
//   - 基线本身只有 1~3 帧，与噪音底噪同量级 —— 拿它当硬阈值，等于抛硬币。
//
// 处置：把「渲染循环是否活着」的判据从逐相位改成**整次测量总帧数 > 0**。
// 真回归（循环被打断）会让四个相位同时归零，总帧数判据照样红；
// 噪音只会让个别相位归零，不再误伤。为吸收噪音另加多次尝试取代表运行。
// 代价是门禁比初版松 —— 这是有意的取舍，松在「逐相位帧数」这种测不准的量上，
// 换来的是门禁不再随机红。逐相位数字仍然全部打印并入库，供人工判读。

import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const appRoot = path.resolve(here, '..');
const repoRoot = path.resolve(appRoot, '..');
const BASELINE = path.join(
  repoRoot, 'docs', 'qa', 'v8-s2-engine-perf-swiftshader-dpr1.json',
);
const ATTEMPTS = Math.max(1, Number(process.env.PERF_GATE_ATTEMPTS || 5));
const PHASES = ['idle', 'orbit', 'lightDrag', 'dolly'];
const STAT_KEYS = ['p50', 'p95', 'p99', 'max', 'mean', 'fpsMean', 'cpuMsPerFrame'];

let failed = 0;
const check = (name, cond, detail = '') => {
  console.log(`  ${cond ? 'PASS' : 'FAIL'} ${name}${detail ? ' :: ' + detail : ''}`);
  if (!cond) failed++;
};
// NOTE：只登记不判红。用于「测不准、人工再看」的项（逐相位帧数差距）。
const note = (name, detail = '') => {
  console.log(`  NOTE ${name}${detail ? ' :: ' + detail : ''}`);
};

const readJson = (p) => JSON.parse(fs.readFileSync(p, 'utf-8'));
// 数值判定必须用 typeof：Number(null) === 0 是有限数，会让「为数值」检查
// 对 null 永久通过（v8.4.0 那 8 项 FAIL 里有 4 项正是这个原因放过去的）。
const isNum = (v) => typeof v === 'number' && Number.isFinite(v);

const labelFor = (i) => (ATTEMPTS === 1 ? 'ci-gate' : `ci-gate-${i}`);
const outPathFor = (label) =>
  path.join(repoRoot, 'docs', 'qa', `v8-s2-engine-perf-${label}.json`);

const framesOf = (d, ph) =>
  Number(d?.phases?.[ph]?.engineFrames ?? 0);
const totalFrames = (d) => PHASES.reduce((s, ph) => s + framesOf(d, ph), 0);
// 「健康」= 四相位都出帧 且 统计字段齐全。用于挑代表运行，不作为判红依据。
const isHealthy = (d) =>
  PHASES.every((ph) => framesOf(d, ph) > 0) &&
  PHASES.every((ph) => STAT_KEYS.every((k) => isNum(d.phases[ph][k])));

const runOnce = (label) => new Promise((res) => {
  const args = [
    'tool/engine_perf_qa.mjs',
    '--label', label,
    '--headless=1',
    '--swiftshader=1',
    '--idle=2', '--drag=2', '--wheel=1', '--warmup=4',
    '--gpumode=default',
  ];
  const r = spawn(process.execPath, args, { cwd: appRoot, stdio: 'inherit' });
  r.on('exit', (code) => res(code));
});

// ── 1. 跑测量（多次尝试 + SwiftShader + headless，控制在 CI 预算内）
console.log(`[perf-gate] 运行引擎测量（最多 ${ATTEMPTS} 次尝试；` +
            'GPU-less 下逐相位 0~3 帧是二值噪音，见文件头说明）');
const attempts = [];
let representative = null;
for (let i = 1; i <= ATTEMPTS; i++) {
  const label = labelFor(i);
  const code = await runOnce(label);
  const f = outPathFor(label);
  if (!fs.existsSync(f)) {
    check(`第 ${i} 次测量产出 JSON`, false, path.relative(repoRoot, f));
    continue;
  }
  let d;
  try {
    d = readJson(f);
  } catch (e) {
    check(`第 ${i} 次测量 JSON 可解析`, false, String(e).slice(0, 120));
    continue;
  }
  const healthy = isHealthy(d);
  attempts.push({ i, label, code, total: totalFrames(d), healthy, data: d });
  const perPhase = PHASES.map((ph) => framesOf(d, ph)).join('/');
  console.log(`  [尝试 ${i}/${ATTEMPTS}] exit=${code} 逐相位帧数=${perPhase} ` +
              `总帧数=${totalFrames(d)}${healthy ? ' 健康' : ''}`);
  if (healthy && code === 0) {
    representative = d;
    break;
  }
}

if (!representative) {
  // 没有「健康」运行：取总帧数最多的一次作为代表，并把噪音情况如实打出来。
  const best = attempts.slice().sort((a, b) => b.total - a.total)[0];
  if (best) {
    representative = best.data;
    note('未出现四相位全出帧的健康运行',
      `最好一次总帧数=${best.total}（尝试 ${attempts.length} 次，逐相位帧数见上）`);
  }
}
if (!representative) {
  console.error('[perf-gate] 没有任何一次测量成功产出结果');
  process.exit(1);
}

// ── 2. 链路与结构（硬判）
console.log('[perf-gate] 链路与统计结构');
check('无 error 字段', representative.error == null, String(representative.error ?? ''));
check('预热已 settled', representative.warmup?.settled === true,
  JSON.stringify(representative.warmup?.settled));
check('灯体命中（拖拽采到的是灯）', representative.lightPoint?.ok === true,
  JSON.stringify(representative.lightPoint?.ok));

// ── 3. 渲染循环是否活着（硬判：整次测量总帧数 > 0）
const total = totalFrames(representative);
const anyFrames = attempts.some((a) => a.total > 0);
check('渲染循环有出帧（总帧数 > 0）', total > 0 || anyFrames,
  `代表运行总帧数=${total}，全部尝试总帧数=` +
  attempts.map((a) => a.total).join('/'));

// ── 4. 统计字段齐全且为数值（硬判；只查真的出了帧的相位）
console.log('[perf-gate] 统计字段为数值');
for (const ph of PHASES) {
  const v = representative.phases?.[ph];
  check(`${ph} 阶段存在`, v != null);
  if (!v) continue;
  if (framesOf(representative, ph) > 0) {
    for (const k of STAT_KEYS) {
      check(`${ph}.${k} 为数值`, isNum(v[k]), `${v[k]}`);
    }
  } else {
    // 该相位这一帧都没采到 → stats 为空是预期，不是产品缺陷。
    note(`${ph} 本次未采到帧，stats 缺失属预期（GPU-less 噪音）`);
  }
}

// ── 5. 对照入库基线的帧数差距（只登记，不判红）
console.log('[perf-gate] 帧数对照 swiftshader 基线（登记用，非判红口径）');
if (fs.existsSync(BASELINE)) {
  const base = readJson(BASELINE);
  const baseTotal = PHASES.reduce((s, ph) => s + Number(base.phases?.[ph]?.engineFrames ?? 0), 0);
  for (const ph of PHASES) {
    const b = Number(base.phases?.[ph]?.engineFrames ?? 0);
    const now = framesOf(representative, ph);
    note(`${ph} 帧数对照`, `基线=${b} 本次=${now}`);
  }
  note('总帧数对照', `基线=${baseTotal} 本次=${total}`);
} else {
  console.log('  (跳过：未找到入库基线，首次运行可由人工核对后固化)');
}

// ── 6. 结论
console.log(`[perf-gate] ${failed === 0 ? 'PASS' : `FAIL (${failed})`}`);
process.exit(failed === 0 ? 0 : 1);
