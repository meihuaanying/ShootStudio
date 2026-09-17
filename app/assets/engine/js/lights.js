// 灯光系统：灯具语义 + 控光件（语义与参数改编自 direct-light（MIT）），实时 3D 沟通级预览。
import * as THREE from 'three';
import { DEG, mixColor, clamp } from './util.js';

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

// 控光件（乘数与增量的语义参照 direct-light V0_6_MODIFIER_SPEC）。
export const LIGHT_MODIFIERS = [
  { id: 'bare', label: '裸灯', intensity: 1, beamDelta: 0, softnessDelta: 0, visual: 'none' },
  { id: 'standard-reflector', label: '标准反光罩', intensity: 1.12, beamDelta: -8, softnessDelta: -0.04, visual: 'reflector' },
  { id: 'softbox-medium', label: '中号柔光箱', intensity: 0.76, beamDelta: 24, softnessDelta: 0.36, visual: 'softbox' },
  { id: 'softbox-large', label: '大号柔光箱', intensity: 0.68, beamDelta: 34, softnessDelta: 0.45, visual: 'softbox' },
  { id: 'honeycomb-grid', label: '蜂巢', intensity: 0.82, beamDelta: -18, softnessDelta: -0.08, visual: 'grid' },
  { id: 'diffusion-cloth', label: '柔光布', intensity: 0.72, beamDelta: 18, softnessDelta: 0.3, visual: 'diffusion' },
  { id: 'beauty-dish', label: '雷达罩', intensity: 1.05, beamDelta: 6, softnessDelta: 0.08, visual: 'reflector' },
  { id: 'snoot', label: '束光筒', intensity: 0.9, beamDelta: -26, softnessDelta: -0.06, visual: 'grid' },
];

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
  return cfg.type === 'panel' ? { w: 1.15, h: 0.75 } : { w: 0.38, h: 0.32 };
}

// 创建灯对象（含灯体视觉与实体光源）。cfg 为画布语义 JSON。
export function createLight(cfg) {
  const group = new THREE.Group();
  group.userData = { lightId: cfg.id, kind: 'light' };
  group.name = `light:${cfg.id}`;

  const bodyMat = new THREE.MeshStandardMaterial({ color: 0x2a2f38, roughness: 0.5, metalness: 0.5 });
  const standMat = new THREE.MeshStandardMaterial({ color: 0x3a404c, roughness: 0.6, metalness: 0.4 });

  // 灯架：底座 + 立柱。
  const base = new THREE.Mesh(new THREE.CylinderGeometry(0.16, 0.2, 0.04, 18), standMat);
  base.position.y = 0.02;
  base.castShadow = true;
  group.add(base);
  const pole = new THREE.Mesh(new THREE.CylinderGeometry(0.02, 0.02, 1, 8), standMat);
  pole.position.y = 0.5;
  pole.castShadow = true;
  group.add(pole);

  // 灯头组（位于 height 高度）。
  const head = new THREE.Group();
  head.name = 'head';
  group.add(head);
  const headBox = new THREE.Mesh(new THREE.BoxGeometry(dims(cfg).w * 0.7, dims(cfg).h * 0.7, 0.16), bodyMat);
  headBox.castShadow = true;
  head.add(headBox);

  // 发光面。
  const emissive = new THREE.Mesh(
    new THREE.PlaneGeometry(dims(cfg).w * 0.62, dims(cfg).h * 0.62),
    new THREE.MeshBasicMaterial({ color: 0xffffff, side: THREE.DoubleSide }),
  );
  emissive.name = 'emissive';
  emissive.position.z = -0.085;
  head.add(emissive);

  // 控光件视觉。
  const modVisual = new THREE.Group();
  modVisual.name = 'modifier';
  head.add(modVisual);

  // 实际光源（spot | panel）。
  const spot = new THREE.SpotLight(0xffffff, 60, 0, 25 * DEG, 0.4, 1.6);
  spot.position.set(0, 0, 0);
  spot.name = 'spot';
  head.add(spot);
  const spotTarget = new THREE.Object3D();
  spotTarget.name = 'spotTarget';
  head.add(spotTarget);
  spot.target = spotTarget;

  const rect = new THREE.RectAreaLight(0xffffff, 0, dims(cfg).w, dims(cfg).h);
  rect.position.set(0, 0, -0.1);
  rect.name = 'rect';
  head.add(rect);

  rebuildModifierVisual(modVisual, cfg, emissive);

  // 选中环。
  const ring = new THREE.Mesh(
    new THREE.TorusGeometry(0.3, 0.012, 8, 40),
    new THREE.MeshBasicMaterial({ color: 0x4d6bfe, transparent: true, opacity: 0.9 }),
  );
  ring.rotation.x = Math.PI / 2;
  ring.position.y = 0.05;
  ring.visible = false;
  group.add(ring);
  group.userData.ring = ring;

  updateLight(group, cfg);
  return group;
}

function rebuildModifierVisual(modVisual, cfg, emissive) {
  while (modVisual.children.length) {
    const c = modVisual.children.pop();
    c.traverse?.((n) => { if (n.geometry) n.geometry.dispose(); });
  }
  const mod = modifierById(cfg.modifier);
  const d = dims(cfg);
  const white = new THREE.MeshStandardMaterial({
    color: 0xf7f8fa, roughness: 0.85, metalness: 0, transparent: true, opacity: 0.92,
  });
  const grid = new THREE.MeshStandardMaterial({ color: 0x14161c, roughness: 0.7, metalness: 0.2 });
  const silver = new THREE.MeshStandardMaterial({ color: 0xcfd4dc, roughness: 0.35, metalness: 0.8 });
  switch (mod.visual) {
    case 'softbox': {
      const box = new THREE.Mesh(new THREE.BoxGeometry(d.w, d.h, 0.5), white);
      box.position.z = -0.36;
      box.castShadow = true;
      modVisual.add(box);
      const face = new THREE.Mesh(new THREE.PlaneGeometry(d.w * 0.96, d.h * 0.96), white.clone());
      face.position.z = -0.62;
      face.material.transparent = false;
      modVisual.add(face);
      emissive.visible = false;
      break;
    }
    case 'grid': {
      const honey = new THREE.Mesh(new THREE.CylinderGeometry(d.w * 0.52, d.w * 0.62, 0.16, 24, 1, true), grid);
      honey.rotation.x = Math.PI / 2;
      honey.position.z = -0.14;
      modVisual.add(honey);
      emissive.visible = true;
      break;
    }
    case 'reflector': {
      const cone = new THREE.Mesh(new THREE.ConeGeometry(d.w * 0.62, 0.3, 24, 1, true), silver);
      cone.rotation.x = -Math.PI / 2;
      cone.position.z = -0.16;
      modVisual.add(cone);
      emissive.visible = true;
      break;
    }
    case 'diffusion': {
      const cloth = new THREE.Mesh(new THREE.PlaneGeometry(d.w * 1.25, d.h * 1.25), white.clone());
      cloth.position.z = -0.4;
      cloth.material.opacity = 0.8;
      modVisual.add(cloth);
      emissive.visible = true;
      break;
    }
    default:
      emissive.visible = true;
  }
}

// 应用 cfg 到灯光对象（位置 / 高度 / 光学参数 / 指向）。
export function updateLight(group, cfg) {
  const { beam, softness, intensity } = effectiveParams(cfg);
  const fixture = fixtureById(cfg.fixture);

  group.position.set(cfg.x ?? 0, 0, -(cfg.y ?? 0));
  const head = group.getObjectByName('head');
  const height = clamp(cfg.height ?? 1.9, 0.3, 3.0);
  head.position.y = height;
  head.rotation.y = (cfg.rotationY ?? 0) * DEG;

  // 仰角：灯头向下倾，按高度自动对准被摄体胸部（可通过 aimLift 微调）。
  const targetY = cfg.targetLift ?? 1.25;
  const horizontal = Math.hypot(cfg.x ?? 0, cfg.y ?? 0) || 0.001;
  const pitch = Math.atan2(height - targetY, horizontal);
  head.rotation.x = clamp(pitch, -0.2, 1.1);

  const color = mixColor(cfg.color || '#ffffff', cfg.kelvin ?? 5500, cfg.color ? 0.25 : 0.75);
  const c = new THREE.Color(color.r, color.g, color.b);

  const spot = head.getObjectByName('spot');
  const rect = head.getObjectByName('rect');
  const emissive = head.getObjectByName('emissive');
  const modVisual = head.getObjectByName('modifier');
  rebuildModifierVisualKeep(modVisual, cfg, emissive);

  const isPanel = cfg.type === 'panel';
  const on = cfg.on !== false;
  const intensityScale = isPanel ? 6.5 : 55;

  spot.intensity = on && !isPanel ? intensity * intensityScale : 0;
  spot.angle = clamp((beam / 2) * DEG, 3 * DEG, 75 * DEG);
  spot.penumbra = clamp(softness * (cfg.type === 'soft' ? 0.95 : 0.6), 0.05, 1);
  spot.color = c;
  spot.castShadow = group.userData.castShadow === true && on && !isPanel;
  // V5/D91：阴影质量调优（更高分辨率 + 适配细分网格的 normalBias）。
  spot.shadow.mapSize.set(2048, 2048);
  spot.shadow.bias = -0.0005;
  spot.shadow.normalBias = 0.025;
  spot.shadow.radius = 3;
  spot.shadow.camera.near = 0.2;
  spot.shadow.camera.far = 15;

  rect.intensity = on && isPanel ? intensity * intensityScale * 3.2 : 0;
  rect.color = c;
  rect.width = dims(cfg).w;
  rect.height = dims(cfg).h;

  // 发光面颜色反馈色温。
  if (emissive?.material) {
    emissive.material.color = c;
  }
  // 光源目标：被摄体胸部。
  const target = head.getObjectByName('spotTarget');
  target.position.set(0, targetY - height, 0);
}

// 轻量重建：仅当控光件变化时重建视觉（避免每帧 dispose）。
function rebuildModifierVisualKeep(modVisual, cfg, emissive) {
  const key = `${cfg.modifier}|${cfg.type}`;
  if (modVisual.userData.key === key) return;
  modVisual.userData.key = key;
  rebuildModifierVisual(modVisual, cfg, emissive);
}

export function setLightSelected(group, selected) {
  const ring = group.userData.ring;
  if (ring) ring.visible = selected;
}
