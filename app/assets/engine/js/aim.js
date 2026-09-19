// V6/R49：纯函数瞄准数学（无依赖，可被 Node 单测；rig.js 复用并 re-export）。
// 约定：对象默认沿 +Z 发射；返回 YXZ 欧拉角（度）：yaw 绕 Y，pitch 绕 X（向上为负）。
const DEG = Math.PI / 180;

export function computeAim(origin, target, { offsetYaw = 0, offsetPitch = 0 } = {}) {
  const dx = (target.x ?? 0) - (origin.x ?? 0);
  const dy = (target.y ?? 0) - (origin.y ?? 0);
  const dz = (target.z ?? 0) - (origin.z ?? 0);
  const horizontal = Math.hypot(dx, dz);
  const yaw = Math.atan2(dx, dz) / DEG + (Number(offsetYaw) || 0);
  const pitch = -Math.atan2(dy, horizontal) / DEG + (Number(offsetPitch) || 0);
  return { yaw, pitch };
}

// 反解验证：由 yaw/pitch 计算朝向单位向量（与 three.js Euler 'YXZ' 一致）。
export function aimDirection({ yaw, pitch }) {
  const y = yaw * DEG;
  const p = pitch * DEG;
  const cosP = Math.cos(p);
  return {
    x: cosP * Math.sin(y),
    y: -Math.sin(p),
    z: cosP * Math.cos(y),
  };
}
