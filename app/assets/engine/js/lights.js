// 灯光系统（V6/D105–D111 重写）：参数化灯架/灯头/控光件 + 几何自动瞄准 + 光锥 + 附件光学。
// 灯具语义与参数改编自 direct-light（MIT）；V6 起朝向不再依赖预设 rotationY（自动对准被摄体）。
import * as THREE from 'three';
import { DEG, mixColor, clamp } from './util.js';
import {
  buildStand,
  buildHead,
  buildModifierVisual,
  applyAim,
  computeAim,
  RIG_MATERIALS,
} from './rig.js';

// 灯具预设（导演语言；数值为沟通级语义，非物理仿真）。
export const LIGHT_FIXTURES = [
  { id: 'cob-600d', label: '600W COB 白光', kind: 'hard', beam: 45, softness: 0.12, cct: [5600, 5600] },
  { id: 'cob-300d', label: '300W COB 白光', kind: 'hard', beam: 50, softness: 0.14, cct: [5600, 5600] },
  { id: 'cob-300b', label: '300W COB 双色温', kind: 'hard', beam: 52, softness: 0.16, cct: [2700, 6500] },
  { id: 'rgb-tube', label: 'RGB 像素管灯', kind: 'soft', beam: 120, softness: 0.35, cct: [2000, 10000] },
  { id: 'panel-120', label: '120W 平板灯', kind: 'panel', beam: 100, softness: 0.5, cct: [2700, 7500] },
  { id: 'speedlight', label: '机顶闪光灯', kind: 'hard', beam: 60, softness: 0.1, cct: [5600, 5600] },
  { id: 'strobe-400', label: '400Ws 影室闪光灯', kind: 'hard', beam: 55, softness: 0.12, cct: [5500, 5500] },
  { id: 'fresnel', label: '菲涅尔聚光灯', kind: 'hard', beam: 30, softness: 0.08, cct: [3200, 5600] },
];

// 控光件（V6 扩充：八角/长条/伞/旗板/色片/柔光箱格栅；V7/D137：图案片投光）。
export const LIGHT_MODIFIERS = [
  { id: 'bare', label: '裸灯', intensity: 1, beamDelta: 0, softnessDelta: 0, shadowRadius: 2, visual: 'bare' },
  { id: 'standard-reflector', label: '标准反光罩', intensity: 1.12, beamDelta: -8, softnessDelta: -0.04, shadowRadius: 3, visual: 'reflector' },
  { id: 'softbox-medium', label: '中号柔光箱', intensity: 0.76, beamDelta: 24, softnessDelta: 0.36, shadowRadius: 9, visual: 'softbox' },
  { id: 'softbox-large', label: '大号柔光箱', intensity: 0.68, beamDelta: 34, softnessDelta: 0.45, shadowRadius: 12, visual: 'softbox' },
  { id: 'octa-softbox', label: '八角柔光箱', intensity: 0.72, beamDelta: 30, softnessDelta: 0.42, shadowRadius: 11, visual: 'octa' },
  { id: 'strip-softbox', label: '长条柔光箱', intensity: 0.74, beamDelta: 22, softnessDelta: 0.34, shadowRadius: 9, visual: 'strip' },
  { id: 'umbrella-silver', label: '反光伞', intensity: 0.9, beamDelta: 26, softnessDelta: 0.3, shadowRadius: 10, visual: 'umbrella' },
  { id: 'umbrella-translucent', label: '透光伞', intensity: 0.7, beamDelta: 30, softnessDelta: 0.4, shadowRadius: 12, visual: 'umbrella' },
  { id: 'honeycomb-grid', label: '蜂巢', intensity: 0.82, beamDelta: -18, softnessDelta: -0.08, shadowRadius: 3, visual: 'grid', pattern: 'grid' },
  { id: 'diffusion-cloth', label: '柔光布', intensity: 0.72, beamDelta: 18, softnessDelta: 0.3, shadowRadius: 10, visual: 'diffusion' },
  { id: 'beauty-dish', label: '雷达罩', intensity: 1.05, beamDelta: 6, softnessDelta: 0.08, shadowRadius: 6, visual: 'beauty' },
  { id: 'snoot', label: '束光筒', intensity: 0.9, beamDelta: -26, softnessDelta: -0.06, shadowRadius: 2, visual: 'snoot' },
  { id: 'softbox-grid', label: '柔光箱格栅', intensity: 0.7, beamDelta: 18, softnessDelta: 0.28, shadowRadius: 8, visual: 'softbox-grid', pattern: 'grid' },
  { id: 'gobo-blinds', label: '百叶窗光影（图案片）', intensity: 0.88, beamDelta: 4, softnessDelta: 0.08, shadowRadius: 5, visual: 'gobo', pattern: 'blinds' },
  { id: 'flag', label: '旗板/黑旗', intensity: 0.85, beamDelta: -6, softnessDelta: -0.02, shadowRadius: 3, visual: 'flag' },
  { id: 'gel-cto', label: '色片 CTO', intensity: 0.86, beamDelta: -2, softnessDelta: 0, shadowRadius: 3, visual: 'gel-cto', tint: 0xffa04d },
  { id: 'gel-ctb', label: '色片 CTB', intensity: 0.86, beamDelta: -2, softnessDelta: 0, shadowRadius: 3, visual: 'gel-ctb', tint: 0x6db4ff },
];

// V7/D137：图案片纹理（程序生成，避免额外资产；SpotLight.map 投光）。
let gridPatternTexture = null;
let blindsPatternTexture = null;
function patternTexture(kind) {
  if (kind === 'grid') {
    if (gridPatternTexture) return gridPatternTexture;
    const canvas = document.createElement('canvas');
    canvas.width = canvas.height = 256;
    const ctx = canvas.getContext('2d');
    ctx.fillStyle = '#ffffff';
    ctx.fillRect(0, 0, 256, 256);
    ctx.strokeStyle = 'rgba(0, 0, 0, 0.5)';
    ctx.lineWidth = 12;
    for (let i = 0; i <= 256; i += 64) {
      ctx.beginPath(); ctx.moveTo(i, 0); ctx.lineTo(i, 256); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(0, i); ctx.lineTo(256, i); ctx.stroke();
    }
    gridPatternTexture = new THREE.CanvasTexture(canvas);
    gridPatternTexture.wrapS = gridPatternTexture.wrapT = THREE.RepeatWrapping;
    return gridPatternTexture;
  }
  if (kind === 'blinds') {
    if (blindsPatternTexture) return blindsPatternTexture;
    const canvas = document.createElement('canvas');
    canvas.width = 256;
    canvas.height = 256;
    const ctx = canvas.getContext('2d');
    ctx.fillStyle = '#ffffff';
    ctx.fillRect(0, 0, 256, 256);
    // 百叶窗横条：亮缝 + 暗叶（与投影条纹对应）。
    ctx.fillStyle = 'rgba(0, 0, 0, 0.72)';
    for (let y = 0; y < 256; y += 42) {
      ctx.fillRect(0, y, 256, 18);
    }
    blindsPatternTexture = new THREE.CanvasTexture(canvas);
    blindsPatternTexture.wrapS = blindsPatternTexture.wrapT = THREE.RepeatWrapping;
    return blindsPatternTexture;
  }
  return null;
}

export function fixtureById(id) { return LIGHT_FIXTURES.find((f) => f.id === id) || LIGHT_FIXTURES[0]; }
export function modifierById(id) { return LIGHT_MODIFIERS.find((m) => m.id === id) || LIGHT_MODIFIERS[0]; }

// 计算控光件叠加后的有效参数。
export function effectiveParams(cfg) {
  const mod = modifierById(cfg.modifier);
  const fixture = fixtureById(cfg.fixture);
  const beam = clamp((cfg.beamAngle ?? fixture.beam) + mod.beamDelta, 8, 150);
  const softness = clamp((cfg.softness ?? fixture.softness) + mod.softnessDelta, 0.02, 1);
  const intensity = clamp((cfg.intensity ?? 60) / 100 * mod.intensity, 0.01, 2);
  return { beam, softness, intensity, mod, fixture };
}

function dims(cfg) {
  if (cfg.type === 'panel') return { w: 1.15, h: 0.75 };
  const mod = modifierById(cfg.modifier);
  if (mod.visual === 'strip') return { w: 0.3, h: 1.1 };
  if (mod.visual === 'octa') return { w: 0.95, h: 0.95 };
  if (mod.visual === 'softbox' || mod.visual === 'softbox-grid') return { w: 0.8, h: 0.6 };
  if (mod.visual === 'umbrella') return { w: 0.5, h: 0.5 };
  return { w: 0.38, h: 0.32 };
}

// 光锥开关（性能可退回，R52）。
let lightConesVisible = false;
export function setLightCones(on) {
  lightConesVisible = !!on;
  for (const obj of lightObjs) {
    const cone = obj.getObjectByName?.('lightCone');
    if (cone) cone.visible = lightConesVisible;
  }
}
export function getLightCones() { return lightConesVisible; }

const lightObjs = new Set();

// V7/S3.3 修复（VSM 回归）：r186 的 WebGLShadowMap 在 VSM 下把 receiveShadow 的物体
// 也渲染进阴影贴图；灯具自身（柔光箱箱体/前脸等）位于灯前 0.1–0.6m 且在光锥内，
// 会把整个场景压进阴影（实测画面亮度 32→115）。灯具硬件一律不参与阴影。
function excludeFromShadows(root) {
  root?.traverse?.((o) => {
    if (o.isMesh) {
      o.castShadow = false;
      o.receiveShadow = false;
    }
  });
}

// 阴影贴图尺寸随性能档联动（默认 2048，低配 1024）。
let shadowMapSize = 2048;
export function setShadowMapSize(size) {
  const value = Number(size);
  if (Number.isFinite(value) && value > 0) shadowMapSize = Math.round(value);
}

// 创建灯对象（含灯架/灯体/控光件视觉与实体光源）。cfg 为画布语义 JSON。
export function createLight(cfg) {
  const group = new THREE.Group();
  group.userData = { lightId: cfg.id, kind: 'light' };
  group.name = `light:${cfg.id}`;
  lightObjs.add(group);

  const stand = buildStand(cfg.stand || 'normal', { height: clamp(cfg.height ?? 1.9, 0.3, 3.0) });
  stand.name = 'stand';
  group.add(stand);

  const head = new THREE.Group();
  head.name = 'head';
  group.add(head);
  const mount = stand.userData.mountOffset;
  if (mount) head.position.copy(mount).setY(clamp(cfg.height ?? 1.9, 0.3, 3.0));
  else head.position.y = clamp(cfg.height ?? 1.9, 0.3, 3.0);

  const headBody = buildHead(cfg.fixture, { size: dims(cfg) });
  head.add(headBody);

  // 控光件视觉容器。
  const modVisual = new THREE.Group();
  modVisual.name = 'modifier';
  head.add(modVisual);

  // 实体光源（spot | panel）。
  const spot = new THREE.SpotLight(0xffffff, 60, 0, 25 * DEG, 0.4, 1.6);
  spot.position.set(0, 0, 0.05);
  spot.name = 'spot';
  head.add(spot);
  const spotTarget = new THREE.Object3D();
  spotTarget.name = 'spotTarget';
  group.add(spotTarget); // 世界目标点（挂在未旋转的 group 下）
  spot.target = spotTarget;

  const rect = new THREE.RectAreaLight(0xffffff, 0, dims(cfg).w, dims(cfg).h);
  rect.position.set(0, 0, 0.12);
  rect.name = 'rect';
  head.add(rect);

  // 光锥可视化（随灯头朝向）。
  const cone = new THREE.Mesh(
    new THREE.CylinderGeometry(0, 1, 1, 24, 1, true),
    new THREE.MeshBasicMaterial({
      color: 0xffffff, transparent: true, opacity: 0.055,
      blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide,
    }),
  );
  cone.name = 'lightCone';
  cone.rotation.x = -Math.PI / 2; // 顶点朝向 +Z（锥体从灯头向前展开）
  cone.visible = false;
  head.add(cone);

  rebuildModifierVisual(modVisual, cfg);
  excludeFromShadows(stand);
  excludeFromShadows(headBody);
  excludeFromShadows(modVisual);
  excludeFromShadows(cone);
  updateLight(group, cfg);

  // 选中环。
  const ring = new THREE.Mesh(
    new THREE.TorusGeometry(0.34, 0.014, 8, 40),
    new THREE.MeshBasicMaterial({ color: 0x4d6bfe, transparent: true, opacity: 0.9 }),
  );
  ring.rotation.x = Math.PI / 2;
  ring.position.y = 0.06;
  ring.visible = false;
  group.add(ring);
  excludeFromShadows(ring);
  group.userData.ring = ring;

  return group;
}

function disposeChildren(container) {
  while (container.children.length) {
    const child = container.children.pop();
    child.traverse?.((n) => {
      if (n.geometry) n.geometry.dispose();
      const mats = Array.isArray(n.material) ? n.material : n.material ? [n.material] : [];
      for (const m of mats) {
        if (!m.userData?.ssShared) m.dispose();
      }
    });
  }
}

function rebuildModifierVisual(modVisual, cfg) {
  disposeChildren(modVisual);
  const result = buildModifierVisual(cfg.modifier, dims(cfg));
  result.visual.userData.emissiveHidden = result.emissiveHidden;
  modVisual.add(result.visual);
  excludeFromShadows(result.visual);
  modVisual.userData.key = `${cfg.modifier}|${cfg.type}|${cfg.fixture}`;
}

// 轻量重建：仅当控光件变化时重建视觉（避免每帧 dispose）。
function rebuildModifierVisualKeep(modVisual, cfg) {
  const key = `${cfg.modifier}|${cfg.type}|${cfg.fixture}`;
  if (modVisual.userData.key === key) return;
  rebuildModifierVisual(modVisual, cfg);
}

function findEmissiveVisual(head) {
  // 优先使用控光件自带发光面（柔光箱前脸），否则用灯头裸灯发光面。
  const modVisual = head.getObjectByName('modifier');
  const modEmissive = modVisual?.getObjectByName('emissive') || null;
  const bare = head.getObjectByName('headBody')?.getObjectByName('emissive') || null;
  if (bare) bare.visible = !modEmissive;
  return modEmissive || bare;
}

// 应用 cfg 到灯光对象（位置 / 高度 / 光学参数 / 自动瞄准 / 光锥）。
export function updateLight(group, cfg) {
  const { beam, softness, intensity, mod } = effectiveParams(cfg);
  const fixture = fixtureById(cfg.fixture);

  const x = cfg.x ?? 0;
  const y = -(cfg.y ?? 0);
  group.position.set(x, 0, y);

  const head = group.getObjectByName('head');
  const height = clamp(cfg.height ?? 1.9, 0.3, 3.0);
  const stand = group.getObjectByName('stand');
  const mountOffset = stand?.userData?.mountOffset;
  if (mountOffset) {
    head.position.set(mountOffset.x, height, mountOffset.z);
  } else {
    head.position.set(0, height, 0);
  }

  const target = new THREE.Vector3(0, cfg.targetLift ?? 1.25, 0);
  const origin = new THREE.Vector3(
    x + (mountOffset?.x || 0), height, y + (mountOffset?.z || 0));
  // V6/R49：统一走几何瞄准（此前把目标挂成灯头子对象导致正上方灯算成水平照射）。
  applyAim(head, origin, target, {
    offsetYaw: cfg.offsetYaw ?? cfg.rotationY ?? 0,
    offsetPitch: cfg.offsetPitch ?? 0,
  });

  const color = mixColor(cfg.color || '#ffffff', cfg.kelvin ?? 5500, cfg.color ? 0.25 : 0.75);
  const c = new THREE.Color(color.r, color.g, color.b);
  if (mod.tint) c.lerp(new THREE.Color(mod.tint), 0.35);

  const spot = head.getObjectByName('spot');
  const rect = head.getObjectByName('rect');
  const modVisual = head.getObjectByName('modifier');
  rebuildModifierVisualKeep(modVisual, cfg);

  const isPanel = cfg.type === 'panel';
  const on = cfg.on !== false;
  const intensityScale = isPanel ? 6.5 : 55;
  const lightDistance = Math.max(0.4, origin.distanceTo(target));

  spot.intensity = on && !isPanel ? intensity * intensityScale : 0;
  spot.angle = clamp((beam / 2) * DEG, 3 * DEG, 75 * DEG);
  spot.penumbra = clamp(softness * (cfg.type === 'soft' ? 0.95 : 0.6), 0.05, 1);
  spot.color = c;
  // V7/D137：图案片投光（格栅/百叶窗）——SpotLight.map 投影纹理。
  spot.map = mod.pattern ? patternTexture(mod.pattern) : null;
  // V7/D137：面板灯以同位置 SpotLight 作「阴影代理」（intensity=0，仅投影），
  // 近似区域光软阴影；阴影预算由 engine 统一控制。
  spot.castShadow = on && group.userData.castShadow === true;
  spot.shadow.mapSize.set(shadowMapSize, shadowMapSize);
  spot.shadow.bias = -0.0005;
  spot.shadow.normalBias = 0.025;
  // V7/D137：软硬阴影由附件/柔度/灯距决定（VSM 支持 radius 软阴影）。
  spot.shadow.radius = clamp(
    (mod.shadowRadius || 3) * (0.5 + softness) * (0.7 + lightDistance * 0.35), 1, 24);
  spot.shadow.blurSamples = 8;
  spot.shadow.camera.near = 0.2;
  spot.shadow.camera.far = 15;

  rect.intensity = on && isPanel ? intensity * intensityScale * 3.2 : 0;
  rect.color = c;
  rect.width = dims(cfg).w;
  rect.height = dims(cfg).h;

  // 发光面颜色反馈色温（柔光箱前脸或裸灯面）。
  const emissive = findEmissiveVisual(head);
  if (emissive?.material) emissive.material.color = c;

  // 光源目标：被摄体胸部（世界坐标）。
  const targetObj = group.getObjectByName('spotTarget');
  targetObj.position.set(-x, target.y, -y);

  // 光锥：长度/半径随距离与束角实时更新（锥顶在灯头，向 +Z 展开）。
  const cone = head.getObjectByName('lightCone');
  if (cone) {
    const dist = Math.max(0.4, origin.distanceTo(target));
    const radius = Math.tan(clamp((beam / 2) * DEG, 3 * DEG, 75 * DEG)) * dist;
    cone.scale.set(radius, dist, radius);
    cone.position.set(0, 0, dist / 2);
    cone.visible = lightConesVisible && on;
    cone.material.color = c;
  }
}

export function setLightSelected(group, selected) {
  const ring = group.userData.ring;
  if (ring) ring.visible = selected;
}
