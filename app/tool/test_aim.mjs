// V6 阶段 B 门禁：灯位瞄准数学单测（纯函数，无 three 依赖）。
// 用法：node tool/test_aim.mjs
import { computeAim, aimDirection } from '../assets/engine/js/aim.js';

let failed = 0;
function check(name, cond, detail = '') {
  if (cond) {
    console.log(`  PASS ${name}`);
  } else {
    failed++;
    console.log(`  FAIL ${name}${detail ? ' :: ' + detail : ''}`);
  }
}

function directionFrom(origin, target, offsets) {
  const { yaw, pitch } = computeAim(origin, target, offsets);
  return aimDirection({ yaw, pitch });
}

function approxVec(dir, expect) {
  const len = Math.hypot(expect[0], expect[1], expect[2]) || 1;
  const e = expect.map((v) => v / len);
  return Math.abs(dir.x - e[0]) < 1e-6
    && Math.abs(dir.y - e[1]) < 1e-6
    && Math.abs(dir.z - e[2]) < 1e-6;
}

console.log('[aim] 基本方向');
{
  const dir = directionFrom({ x: 0, y: 2.5, z: 0 }, { x: 0, y: 1.25, z: 0 });
  check('正上方灯 → 垂直向下', approxVec(dir, [0, -1, 0]),
    JSON.stringify(dir));
}
{
  const dir = directionFrom({ x: 0, y: 1.5, z: 3 }, { x: 0, y: 1.25, z: 0 });
  check('正面灯 → 指向 -Z', approxVec(dir, [0, -0.25, -3]),
    JSON.stringify(dir));
}
{
  const dir = directionFrom({ x: 2, y: 2, z: 0 }, { x: 0, y: 1.25, z: 0 });
  check('右侧灯 → 指向 -X（含俯角）', approxVec(dir, [-2, -0.75, 0]),
    JSON.stringify(dir));
}
{
  const dir = directionFrom({ x: -1.5, y: 1.2, z: -1.5 }, { x: 0, y: 1.25, z: 0 });
  check('左后灯 → 指向右下前', approxVec(dir, [1.5, 0.05, 1.5]),
    JSON.stringify(dir));
}

console.log('[aim] 手动偏移');
{
  const base = directionFrom({ x: 0, y: 2, z: 2 }, { x: 0, y: 1.25, z: 0 });
  const shifted = directionFrom({ x: 0, y: 2, z: 2 }, { x: 0, y: 1.25, z: 0 }, { offsetYaw: 10 });
  check('offsetYaw 改变水平方向', Math.abs(base.x - shifted.x) > 1e-4);
}
{
  const down = directionFrom({ x: 0, y: 2.5, z: 0 }, { x: 0, y: 1.25, z: 0 }, { offsetPitch: 5 });
  check('offsetPitch 叠加俯仰', down.y < -0.99 && down.z < 0, JSON.stringify(down));
}

console.log('[aim] 往返一致性（任意位置，指向误差 <1e-6）');
{
  const cases = [
    [{ x: 1.556, y: 2.0, z: 1.556 }, { x: 0, y: 1.25, z: 0 }],
    [{ x: -1.838, y: 1.7, z: 1.838 }, { x: 0, y: 1.25, z: 0 }],
    [{ x: 0, y: 2.5, z: -2.8 }, { x: 0, y: 1.25, z: 0 }],
    [{ x: 3.2, y: 0.8, z: -1.2 }, { x: 0, y: 1.25, z: 0 }],
  ];
  let ok = true;
  for (const [origin, target] of cases) {
    const dir = directionFrom(origin, target);
    const expect = [target.x - origin.x, target.y - origin.y, target.z - origin.z];
    if (!approxVec(dir, expect)) { ok = false; break; }
  }
  check('四组随机位姿往返', ok);
}

console.log(failed === 0 ? '[aim] ALL PASS' : `[aim] ${failed} FAIL`);
process.exit(failed === 0 ? 0 : 1);
