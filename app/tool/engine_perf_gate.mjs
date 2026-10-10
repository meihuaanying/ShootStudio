// V8/P2 · 引擎性能门禁（CI 版）。
//
// 用法：node tool/engine_perf_gate.mjs
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
// 本门禁真正守的是**会被 CI 抓到的回归**：
//   1. 测量链路仍然可用 —— Edge 起得来、CDP 连得上、引擎页面能加载；
//   2. 引擎仍在出帧 —— 各阶段 engineFrames > 0（渲染循环真被打断时这里归零）；
//   3. 统计字段齐全且为数值 —— 防止有人把 stats() 改坏却没人发现；
//   4. 预热确实 settled、灯体确实被拖到（lightPoint.ok）—— 保证采的不是冷启动抖动；
//   5. 帧数未灾难性回退 —— 与入库的 swiftshader 基线比，低于基线 50% 判红
//      （基线本身只有 1~3 帧，所以这条的语义是「从 3 帧掉到 0~1 帧」）。
//
// 绝对帧耗时阈值仍是人工判据：改动渲染路径后，按 HANDOFF 的口径在独显机上
// 手动跑 `node tool/engine_perf_qa.mjs --label <说明>` 并把 JSON 入库。

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

let failed = 0;
const check = (name, cond, detail = '') => {
  console.log(`  ${cond ? 'PASS' : 'FAIL'} ${name}${detail ? ' :: ' + detail : ''}`);
  if (!cond) failed++;
};

const readJson = (p) => JSON.parse(fs.readFileSync(p, 'utf-8'));

// ── 1. 跑测量（短时段 + SwiftShader + headless，控制在 CI 预算内）
console.log('[perf-gate] 运行引擎测量（swiftshader / headless / 短时段）');
{
  const args = [
    'tool/engine_perf_qa.mjs',
    '--label', 'ci-gate',
    '--headless=1',
    '--swiftshader=1',
    '--idle=2', '--drag=2', '--wheel=1', '--warmup=4',
    '--gpumode=default',
  ];
  const r = spawn(process.execPath, args, { cwd: appRoot, stdio: 'inherit' });
  const code = await new Promise((res) => r.on('exit', res));
  check('测量进程正常退出', code === 0, `exit=${code}`);
}

const outFile = path.join(repoRoot, 'docs', 'qa', 'v8-s2-engine-perf-ci-gate.json');
if (!fs.existsSync(outFile)) {
  console.error(`[perf-gate] 缺少输出 ${path.relative(repoRoot, outFile)}`);
  process.exit(1);
}
const d = readJson(outFile);

// ── 2. 链路与结构
console.log('[perf-gate] 链路与统计结构');
check('无 error 字段', d.error == null, String(d.error ?? ''));
check('预热已 settled', d.warmup?.settled === true, JSON.stringify(d.warmup?.settled));
check('灯体命中（拖拽采到的是灯）', d.lightPoint?.ok === true, JSON.stringify(d.lightPoint?.ok));

const PHASES = ['idle', 'orbit', 'lightDrag', 'dolly'];
for (const ph of PHASES) {
  const v = d.phases?.[ph];
  check(`${ph} 阶段存在`, v != null);
  if (!v) continue;
  check(`${ph} 引擎有出帧`, Number(v.engineFrames) > 0, `engineFrames=${v.engineFrames}`);
  for (const k of ['p50', 'p95', 'p99', 'max', 'mean', 'fpsMean', 'cpuMsPerFrame']) {
    check(`${ph}.${k} 为数值`, Number.isFinite(Number(v[k])), `${v[k]}`);
  }
}

// ── 3. 对照入库基线的帧数下限（唯一允许的「回归」判据）
console.log('[perf-gate] 帧数下限（对照 swiftshader 基线，非绝对耗时）');
if (fs.existsSync(BASELINE)) {
  const base = readJson(BASELINE);
  for (const ph of PHASES) {
    const b = Number(base.phases?.[ph]?.engineFrames ?? 0);
    const now = Number(d.phases?.[ph]?.engineFrames ?? 0);
    // 基线本身只有 1~3 帧，所以「基线 50%」的实义是「从 3 帧掉到 0~1 帧」。
    const floor = Math.max(1, Math.floor(b * 0.5));
    check(`${ph} 帧数未灾难回退 (>= ${floor})`, now >= floor,
      `baseline=${b} now=${now}`);
  }
} else {
  console.log('  (跳过：未找到入库基线，首次运行可由人工核对后固化)');
}

// ── 4. 结论
console.log(`[perf-gate] ${failed === 0 ? 'PASS' : `FAIL (${failed})`}`);
process.exit(failed === 0 ? 0 : 1);
