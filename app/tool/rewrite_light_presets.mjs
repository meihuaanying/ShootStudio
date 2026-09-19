// V6/D110：布光预设重写——自动瞄准时代的数据校订 + 附件升级 + 新增预设。
// 用法（工作目录 app/）：node tool/rewrite_light_presets.mjs
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const file = path.join(here, '..', 'assets', 'content', 'light_presets', 'light_presets.json');
const data = JSON.parse(fs.readFileSync(file, 'utf8'));

// 每套预设的附件/支架升级（保守，只改语义明确项）。
const MODIFIER_PATCH = {
  'three-point': { Key: 'octa-softbox', Fill: 'umbrella-translucent', Rim: 'strip-softbox' },
  butterfly: { Key: 'octa-softbox' },
  'rim-double': { 正面柔补: 'umbrella-translucent' },
  'dual-color': { 暖主光: 'gel-cto', 冷轮廓: 'gel-ctb' },
  'neon-night': { 霓虹点缀: 'gel-ctb', 青边光: 'gel-ctb' },
  'cos-rim': { 双色主光: 'octa-softbox' },
  overcast: { 天顶补光: 'diffusion-cloth' },
};

// 明确的色光数据（gel 附件 + 色温/颜色）。
const COLOR_PATCH = {
  'dual-color': {
    暖主光: { kelvin: 3200, color: '#ffb066' },
    冷轮廓: { kelvin: 6500, color: '#9cc4ff' },
  },
  'neon-night': {
    冷主光: { kelvin: 7000, color: '#cfe0ff' },
    青边光: { kelvin: 6500, color: '#7fe3ff' },
  },
};

for (const preset of data.presets) {
  const modPatch = MODIFIER_PATCH[preset.id] || {};
  const colorPatch = COLOR_PATCH[preset.id] || {};
  for (const device of preset.devices || []) {
    // 几何自动瞄准：rotationY 归零（保留字段向后兼容），新增 offsetYaw/offsetPitch。
    device.rotationY = 0;
    device.offsetYaw = 0;
    device.offsetPitch = 0;
    // 支架：高灯位（≥2.4m）用横臂，其余普通灯架。
    device.stand = (device.height ?? 1.9) >= 2.4 ? 'boom' : 'normal';
    if (modPatch[device.name]) device.modifier = modPatch[device.name];
    if (colorPatch[device.name]) Object.assign(device, colorPatch[device.name]);
  }
}

// 新增预设（D110：扩充）。
const NEW_PRESETS = [
  {
    id: 'clamshell',
    name: '美人光（夹光）',
    category: '经典',
    devices: [
      { name: '上主光', x: 0, y: -1.9, height: 2.35, type: 'hard', fixture: 'cob-600d', modifier: 'octa-softbox', intensity: 78, kelvin: 5500, beamAngle: 60, softness: 0.45, color: '#ffffff', rotationY: 0, offsetYaw: 0, offsetPitch: 0, stand: 'normal', note: '眼位上方 30–45°' },
      { name: '下补光', x: 0, y: -1.7, height: 0.95, type: 'hard', fixture: 'cob-600d', modifier: 'octa-softbox', intensity: 38, kelvin: 5500, beamAngle: 70, softness: 0.5, color: '#ffffff', rotationY: 0, offsetYaw: 0, offsetPitch: 0, stand: 'normal', note: '下颌以下，消除颈部阴影' },
    ],
    note: '上下对称夹光，肤质通透；下灯强度约为主灯一半。',
  },
  {
    id: 'hair-light',
    name: '发丝光组合',
    category: '轮廓',
    devices: [
      { name: '发丝光', x: 0, y: 1.2, height: 2.85, type: 'hard', fixture: 'cob-600d', modifier: 'strip-softbox', intensity: 72, kelvin: 5600, beamAngle: 35, softness: 0.2, color: '#ffffff', rotationY: 0, offsetYaw: 0, offsetPitch: 0, stand: 'boom', note: '横臂顶后，勾发丝' },
      { name: '正面柔补', x: -1.5, y: -1.6, height: 1.9, type: 'hard', fixture: 'cob-600d', modifier: 'softbox-large', intensity: 34, kelvin: 5500, beamAngle: 70, softness: 0.5, color: '#ffffff', rotationY: 0, offsetYaw: 0, offsetPitch: 0, stand: 'normal', note: '' },
    ],
    note: '顶后长条勾发丝，正面低比例柔补保证面部可读。',
  },
  {
    id: 'split-rim',
    name: '双轮廓夹击',
    category: '轮廓',
    devices: [
      { name: '左轮廓', x: -1.5, y: 1.5, height: 2.2, type: 'hard', fixture: 'cob-600d', modifier: 'strip-softbox', intensity: 66, kelvin: 5600, beamAngle: 40, softness: 0.25, color: '#ffffff', rotationY: 0, offsetYaw: 0, offsetPitch: 0, stand: 'normal', note: '' },
      { name: '右轮廓', x: 1.5, y: 1.5, height: 2.2, type: 'hard', fixture: 'cob-600d', modifier: 'strip-softbox', intensity: 66, kelvin: 5600, beamAngle: 40, softness: 0.25, color: '#ffffff', rotationY: 0, offsetYaw: 0, offsetPitch: 0, stand: 'normal', note: '' },
      { name: '正面柔补', x: 0, y: -2.1, height: 1.85, type: 'hard', fixture: 'cob-600d', modifier: 'softbox-large', intensity: 26, kelvin: 5500, beamAngle: 75, softness: 0.55, color: '#ffffff', rotationY: 0, offsetYaw: 0, offsetPitch: 0, stand: 'normal', note: '' },
    ],
    note: '左右后 45° 各一条长条光，面部仅留低比例补光。',
  },
  {
    id: 'gel-party',
    name: '色光派对',
    category: '戏剧',
    devices: [
      { name: '暖侧光', x: -1.8, y: -0.6, height: 2.0, type: 'hard', fixture: 'cob-600d', modifier: 'gel-cto', intensity: 70, kelvin: 3000, beamAngle: 55, softness: 0.25, color: '#ffa04d', rotationY: 0, offsetYaw: 0, offsetPitch: 0, stand: 'normal', note: '' },
      { name: '冷侧光', x: 1.8, y: -0.6, height: 2.0, type: 'hard', fixture: 'cob-600d', modifier: 'gel-ctb', intensity: 70, kelvin: 7000, beamAngle: 55, softness: 0.25, color: '#6db4ff', rotationY: 0, offsetYaw: 0, offsetPitch: 0, stand: 'normal', note: '' },
      { name: '背景染光', x: 0, y: 2.6, height: 1.6, type: 'hard', fixture: 'cob-600d', modifier: 'bare', intensity: 55, kelvin: 6500, beamAngle: 90, softness: 0.4, color: '#b78bff', rotationY: 0, offsetYaw: 0, offsetPitch: 0, stand: 'normal', note: '' },
    ],
    note: '暖冷对撞 + 背景染光，适合夜景/舞台氛围。',
  },
];
const existing = new Set(data.presets.map((p) => p.id));
for (const preset of NEW_PRESETS) {
  if (!existing.has(preset.id)) data.presets.push(preset);
}

data.version = 2;
fs.writeFileSync(file, JSON.stringify(data, null, 2) + '\n', 'utf8');
console.log(`[presets] 重写完成：${data.presets.length} 套（新增 ${NEW_PRESETS.length}）`);
