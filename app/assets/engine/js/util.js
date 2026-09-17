// 通用工具：色温换算、角度、缓动（自研，MIT）。
export const DEG = Math.PI / 180;

export function clamp(v, a, b) { return Math.min(b, Math.max(a, v)); }

export function lerp(a, b, t) { return a + (b - a) * t; }

// 色温 → RGB（Tanner Helland 近似，用于灯色可视化与白光染色）。
export function kelvinToColor(k) {
  const t = clamp(k, 1000, 40000) / 100;
  let r, g, b;
  if (t <= 66) {
    r = 255;
    g = 99.4708025861 * Math.log(t) - 161.1195681661;
    b = t <= 19 ? 0 : 138.5177312231 * Math.log(t - 10) - 305.0447927307;
  } else {
    r = 329.698727446 * Math.pow(t - 60, -0.1332047592);
    g = 288.1221695283 * Math.pow(t - 60, -0.0755148492);
    b = 255;
  }
  return {
    r: clamp(r, 0, 255) / 255,
    g: clamp(g, 0, 255) / 255,
    b: clamp(b, 0, 255) / 255,
  };
}

// 将 hex 颜色按色温混合（保持用户指定颜色时色温只做微调）。
export function mixColor(hex, kelvin, kelvinWeight = 0.55) {
  const c = kelvinToColor(kelvin);
  const parsed = parseInt((hex || '#ffffff').replace('#', ''), 16);
  const r = ((parsed >> 16) & 255) / 255;
  const g = ((parsed >> 8) & 255) / 255;
  const b = (parsed & 255) / 255;
  return {
    r: lerp(r, c.r, kelvinWeight),
    g: lerp(g, c.g, kelvinWeight),
    b: lerp(b, c.b, kelvinWeight),
  };
}

// 方位角（画布约定：0° = 画布上方 = 被摄体正面 = three 世界 +Z；顺时针）→ 世界坐标。
export function azimuthToWorld(azDeg, distM) {
  const rad = azDeg * DEG;
  return { x: Math.sin(rad) * distM, z: Math.cos(rad) * distM };
}

// 世界坐标 → 方位角（0–360，画布顺时针）与距离。
export function worldToAzimuth(x, z) {
  let deg = Math.atan2(x, z) / DEG;
  if (deg < 0) deg += 360;
  return { azimuth: deg % 360, distance: Math.hypot(x, z) };
}

// 画布坐标（x 右、y 下）→ 世界坐标（x 右、z 为画布 y 的反向）。
export function canvasToWorld(x, y) {
  return { x, z: -y };
}

export function worldToCanvas(x, z) {
  return { x, y: -z };
}

export function easeInOut(t) { return t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2; }

export function nowMs() { return performance.now(); }
