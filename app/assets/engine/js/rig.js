// V6/D105–D109：机位/灯架/灯具/控光件参数化建模 + 瞄准数学（纯函数可被 Node 测试）。
// 约定：所有灯头/相机默认沿 +Z 发射；朝向由 computeAim 计算（YXZ 欧拉角）。
import * as THREE from 'three';
import { computeAim, aimDirection } from './aim.js';

const DEG = Math.PI / 180;

export { computeAim, aimDirection };

// 应用朝向到对象（YXZ：先偏航后俯仰，附加手动偏移）。
export function applyAim(object, origin, target, offsets = {}) {
  const { yaw, pitch } = computeAim(origin, target, offsets);
  object.rotation.set(pitch * DEG, yaw * DEG, 0, 'YXZ');
}

const MAT = {
  black: new THREE.MeshStandardMaterial({ color: 0x23262d, roughness: 0.55, metalness: 0.55 }),
  dark: new THREE.MeshStandardMaterial({ color: 0x14161b, roughness: 0.6, metalness: 0.35 }),
  silver: new THREE.MeshStandardMaterial({ color: 0xc9ced6, roughness: 0.32, metalness: 0.85 }),
  chrome: new THREE.MeshStandardMaterial({ color: 0xdde1e7, roughness: 0.18, metalness: 0.95 }),
  white: new THREE.MeshStandardMaterial({
    color: 0xf6f7f9, roughness: 0.82, metalness: 0, side: THREE.DoubleSide,
  }),
  cloth: new THREE.MeshStandardMaterial({
    color: 0xf2f3f6, roughness: 0.9, metalness: 0,
    transparent: true, opacity: 0.85, side: THREE.DoubleSide,
  }),
  canopy: new THREE.MeshStandardMaterial({
    color: 0xf4f6f9, roughness: 0.6, metalness: 0,
    transparent: true, opacity: 0.55, side: THREE.DoubleSide,
  }),
  canopySilver: new THREE.MeshStandardMaterial({
    color: 0xd8dde6, roughness: 0.25, metalness: 0.7, side: THREE.DoubleSide,
  }),
  flag: new THREE.MeshStandardMaterial({ color: 0x0c0e12, roughness: 0.95, side: THREE.DoubleSide }),
  gelBase: new THREE.MeshBasicMaterial({
    color: 0xff8a3c, transparent: true, opacity: 0.6, side: THREE.DoubleSide,
  }),
};

function mesh(geometry, material, { cast = true, receive = true } = {}) {
  const m = new THREE.Mesh(geometry, material);
  m.castShadow = cast;
  m.receiveShadow = receive;
  return m;
}

// ---------------- 灯架 ----------------
// standType: normal（三脚灯架）| c（C 架）| boom（横臂）。
export function buildStand(standType = 'normal', { height = 1.9 } = {}) {
  const group = new THREE.Group();
  group.name = 'stand';
  const poleH = Math.max(0.6, height);
  if (standType === 'c') {
    // C 架：龟形底座 + 立柱 + 斜撑 + 横臂抓头。
    const base = mesh(new THREE.TorusGeometry(0.28, 0.03, 8, 24), MAT.silver);
    base.rotation.x = Math.PI / 2;
    base.position.y = 0.04;
    const wheelGeom = new THREE.CylinderGeometry(0.035, 0.035, 0.05, 10);
    for (let i = 0; i < 3; i++) {
      const a = (i / 3) * Math.PI * 2;
      const wheel = mesh(wheelGeom, MAT.dark);
      wheel.rotation.z = Math.PI / 2;
      wheel.position.set(Math.cos(a) * 0.28, 0.035, Math.sin(a) * 0.28);
      group.add(wheel);
    }
    const column = mesh(new THREE.CylinderGeometry(0.025, 0.028, poleH, 12), MAT.silver);
    column.position.y = poleH / 2;
    const brace = mesh(new THREE.CylinderGeometry(0.012, 0.012, 0.42, 8), MAT.silver);
    brace.position.set(0.14, 0.2, 0);
    brace.rotation.z = -0.6;
    const grip = mesh(new THREE.BoxGeometry(0.09, 0.07, 0.09), MAT.dark);
    grip.position.y = poleH;
    group.add(base, column, brace, grip);
  } else if (standType === 'boom') {
    // 横臂：灯架 + 水平臂 + 配重。
    const base = mesh(new THREE.CylinderGeometry(0.2, 0.26, 0.05, 18), MAT.dark);
    base.position.y = 0.025;
    const column = mesh(new THREE.CylinderGeometry(0.024, 0.03, poleH * 0.8, 12), MAT.silver);
    column.position.y = poleH * 0.4;
    const armLen = 0.85;
    const arm = mesh(new THREE.CylinderGeometry(0.016, 0.016, armLen, 10), MAT.silver);
    arm.rotation.z = Math.PI / 2;
    arm.position.set(armLen / 2 - 0.06, poleH * 0.8, 0);
    const weight = mesh(new THREE.CylinderGeometry(0.07, 0.07, 0.16, 12), MAT.dark);
    weight.position.set(-0.24, poleH * 0.8, 0);
    const joint = mesh(new THREE.BoxGeometry(0.08, 0.08, 0.08), MAT.dark);
    joint.position.set(0, poleH * 0.8, 0);
    group.add(base, column, arm, weight, joint);
    group.userData.mountOffset = new THREE.Vector3(armLen - 0.12, poleH * 0.8, 0);
  } else {
    const base = mesh(new THREE.CylinderGeometry(0.16, 0.22, 0.04, 18), MAT.dark);
    base.position.y = 0.02;
    const legGeom = new THREE.CylinderGeometry(0.014, 0.014, 0.5, 8);
    for (let i = 0; i < 3; i++) {
      const a = (i / 3) * Math.PI * 2 + Math.PI / 6;
      const leg = mesh(legGeom, MAT.silver);
      leg.position.set(Math.cos(a) * 0.17, 0.16, Math.sin(a) * 0.17);
      leg.rotation.z = Math.cos(a) * 0.55;
      leg.rotation.x = -Math.sin(a) * 0.55;
      group.add(leg);
    }
    const pole = mesh(new THREE.CylinderGeometry(0.018, 0.022, poleH, 10), MAT.silver);
    pole.position.y = poleH / 2;
    const collar = mesh(new THREE.CylinderGeometry(0.032, 0.032, 0.05, 12), MAT.dark);
    collar.position.y = Math.min(poleH * 0.55, 1.0);
    const knob = mesh(new THREE.CylinderGeometry(0.014, 0.014, 0.05, 8), MAT.black);
    knob.rotation.z = Math.PI / 2;
    knob.position.set(0.035, collar.position.y, 0);
    group.add(base, pole, collar, knob);
  }
  return group;
}

// ---------------- 灯头 ----------------
export function buildHead(fixtureId = 'cob-600d', { size = { w: 0.38, h: 0.32 } } = {}) {
  const group = new THREE.Group();
  group.name = 'headBody';
  const w = size.w;
  const h = size.h;
  // U 形支架。
  const bracketGeom = new THREE.BoxGeometry(0.03, h * 1.25, 0.06);
  const bracketL = mesh(bracketGeom, MAT.dark);
  bracketL.position.set(-w * 0.62, 0, -0.05);
  const bracketR = bracketL.clone();
  bracketR.position.x = w * 0.62;
  const crossbar = mesh(new THREE.CylinderGeometry(0.014, 0.014, w * 1.24, 8), MAT.silver);
  crossbar.rotation.z = Math.PI / 2;
  crossbar.position.y = -h * 0.62;
  group.add(bracketL, bracketR, crossbar);
  // 灯体。
  const bodyGeom = fixtureId === 'fresnel'
    ? new THREE.CylinderGeometry(w * 0.34, w * 0.42, 0.3, 20)
    : new THREE.BoxGeometry(w * 0.8, h * 0.8, 0.3);
  if (fixtureId === 'fresnel') {
    const body = mesh(bodyGeom, MAT.black);
    body.rotation.x = Math.PI / 2;
    group.add(body);
  } else {
    const body = mesh(bodyGeom, MAT.black);
    body.position.z = -0.06;
    // 散热槽。
    const finGeom = new THREE.BoxGeometry(w * 0.84, 0.012, 0.24);
    for (let i = 0; i < 4; i++) {
      const fin = mesh(finGeom, MAT.dark, { cast: false });
      fin.position.set(0, h * 0.42 - i * 0.028, -0.08);
      group.add(fin);
    }
    group.add(body);
  }
  // 发光面（沿 +Z）。
  const emissive = new THREE.Mesh(
    new THREE.PlaneGeometry(w * 0.62, h * 0.62),
    new THREE.MeshBasicMaterial({ color: 0xffffff, side: THREE.DoubleSide }),
  );
  emissive.name = 'emissive';
  emissive.position.z = 0.1;
  group.add(emissive);
  return group;
}

// ---------------- 控光件（视觉） ----------------
// 返回 { visual, emissiveHidden }——部分附件（柔光箱）自带发光面，隐藏裸灯发光面。
export function buildModifierVisual(modifierId, size = { w: 0.38, h: 0.32 }) {
  const group = new THREE.Group();
  group.name = 'modifierBody';
  const w = size.w;
  const h = size.h;
  const d = Math.max(w, h) * 0.9;
  const add = (...objs) => group.add(...objs);
  switch (modifierId) {
    case 'softbox-medium':
    case 'softbox-large':
    case 'octa-softbox':
    case 'strip-softbox':
    case 'softbox-grid': {
      const isOcta = modifierId === 'octa-softbox';
      const isStrip = modifierId === 'strip-softbox';
      const fw = isStrip ? w * 0.6 : w;
      const fh = isOcta ? w : h;
      const depth = 0.5;
      if (isOcta) {
        const cone = mesh(
          new THREE.CylinderGeometry(fw * 0.52, fw * 0.16, depth, 8, 1, true),
          MAT.cloth, { cast: false });
        cone.rotation.x = Math.PI / 2;
        cone.position.z = depth / 2 + 0.08;
        const back = mesh(new THREE.CircleGeometry(fw * 0.17, 16), MAT.white, { cast: false });
        back.position.z = 0.08;
        const front = new THREE.Mesh(
          new THREE.CircleGeometry(fw * 0.52, 8),
          new THREE.MeshBasicMaterial({ color: 0xffffff, side: THREE.DoubleSide }),
        );
        front.name = 'emissive';
        front.castShadow = false;
        front.position.z = depth + 0.085;
        add(cone, back, front);
      } else {
        const body = mesh(new THREE.BoxGeometry(fw, fh, depth), MAT.cloth, { cast: false });
        body.position.z = depth / 2 + 0.08;
        const front = new THREE.Mesh(
          new THREE.PlaneGeometry(fw * 0.98, fh * 0.98),
          new THREE.MeshBasicMaterial({ color: 0xffffff, side: THREE.DoubleSide }),
        );
        front.name = 'emissive';
        front.castShadow = false;
        front.receiveShadow = false;
        front.position.z = depth + 0.085;
        add(body, front);
        // 骨架肋条。
        const ribGeom = new THREE.BoxGeometry(0.012, fh * 1.0, 0.012);
        for (let i = -2; i <= 2; i++) {
          const rib = mesh(ribGeom, MAT.dark, { cast: false });
          rib.position.set(i * fw * 0.2, 0, depth + 0.09);
          add(rib);
        }
      }
      if (modifierId === 'softbox-grid') {
        const grid = mesh(new THREE.PlaneGeometry(fw * 0.96, fh * 0.96), MAT.dark, { cast: false });
        grid.position.z = depth + 0.1;
        grid.material = new THREE.MeshStandardMaterial({
          color: 0x0d0f13, roughness: 0.8, transparent: true, opacity: 0.55,
        });
        add(grid);
      }
      return { visual: group, emissiveHidden: false };
    }
    case 'umbrella-silver':
    case 'umbrella-translucent': {
      const r = Math.max(w, h) * 1.05;
      const canopy = mesh(
        new THREE.ConeGeometry(r, r * 0.55, 12, 1, true),
        modifierId === 'umbrella-silver' ? MAT.canopySilver : MAT.canopy,
        { cast: false });
      canopy.rotation.x = Math.PI / 2;
      canopy.position.z = r * 0.28 + 0.05;
      const shaft = mesh(new THREE.CylinderGeometry(0.008, 0.008, r * 0.9, 8), MAT.silver, { cast: false });
      shaft.rotation.x = Math.PI / 2;
      shaft.position.z = r * 0.2;
      add(canopy, shaft);
      const ribGeom = new THREE.CylinderGeometry(0.005, 0.005, r * 0.98, 6);
      for (let i = 0; i < 6; i++) {
        const a = (i / 6) * Math.PI * 2;
        const rib = mesh(ribGeom, MAT.silver, { cast: false });
        rib.position.set(Math.cos(a) * r * 0.5, Math.sin(a) * r * 0.5, r * 0.28 + 0.05);
        rib.rotation.z = a - Math.PI / 2;
        rib.rotation.x = 0.22;
        add(rib);
      }
      return { visual: group, emissiveHidden: false };
    }
    case 'beauty-dish': {
      const dish = mesh(new THREE.ConeGeometry(w * 0.72, 0.22, 24, 1, true), MAT.chrome, { cast: false });
      dish.rotation.x = Math.PI / 2;
      dish.position.z = 0.14;
      const deflector = mesh(new THREE.CircleGeometry(w * 0.22, 20), MAT.dark, { cast: false });
      deflector.position.z = 0.24;
      add(dish, deflector);
      return { visual: group, emissiveHidden: true };
    }
    case 'honeycomb-grid':
    case 'grid': {
      const ring = mesh(new THREE.CylinderGeometry(w * 0.5, w * 0.54, 0.1, 20, 1, true), MAT.dark, { cast: false });
      ring.rotation.x = Math.PI / 2;
      ring.position.z = 0.2;
      const honey = mesh(new THREE.CircleGeometry(w * 0.48, 20), new THREE.MeshStandardMaterial({
        color: 0x101216, roughness: 0.9, transparent: true, opacity: 0.5,
      }), { cast: false });
      honey.position.z = 0.22;
      add(ring, honey);
      return { visual: group, emissiveHidden: false };
    }
    case 'standard-reflector':
    case 'reflector': {
      const cone = mesh(new THREE.ConeGeometry(w * 0.5, 0.24, 24, 1, true), MAT.silver, { cast: false });
      cone.rotation.x = Math.PI / 2;
      cone.position.z = 0.2;
      add(cone);
      return { visual: group, emissiveHidden: false };
    }
    case 'snoot': {
      const snoot = mesh(new THREE.CylinderGeometry(w * 0.16, w * 0.34, 0.42, 18, 1, true), MAT.dark, { cast: false });
      snoot.rotation.x = Math.PI / 2;
      snoot.position.z = 0.3;
      add(snoot);
      return { visual: group, emissiveHidden: false };
    }
    case 'diffusion-cloth': {
      const frame = mesh(new THREE.TorusGeometry(w * 0.6, 0.012, 8, 20), MAT.silver, { cast: false });
      frame.position.z = 0.32;
      const cloth = mesh(new THREE.CircleGeometry(w * 0.58, 20), MAT.cloth, { cast: false });
      cloth.position.z = 0.325;
      add(frame, cloth);
      return { visual: group, emissiveHidden: false };
    }
    case 'flag': {
      const flag = mesh(new THREE.PlaneGeometry(w * 1.2, h * 1.6), MAT.flag, { cast: true });
      flag.position.set(w * 0.9, 0, 0.35);
      const arm = mesh(new THREE.CylinderGeometry(0.008, 0.008, 0.5, 8), MAT.silver, { cast: false });
      arm.rotation.z = Math.PI / 2;
      arm.position.set(w * 0.55, 0, 0.35);
      add(arm, flag);
      return { visual: group, emissiveHidden: false };
    }
    case 'gel-cto': {
      const gel = mesh(new THREE.PlaneGeometry(w * 0.7, h * 0.7), new THREE.MeshBasicMaterial({
        color: 0xffa04d, transparent: true, opacity: 0.55, side: THREE.DoubleSide,
      }), { cast: false });
      gel.position.z = 0.16;
      add(gel);
      return { visual: group, emissiveHidden: false };
    }
    case 'gel-ctb': {
      const gel = mesh(new THREE.PlaneGeometry(w * 0.7, h * 0.7), new THREE.MeshBasicMaterial({
        color: 0x6db4ff, transparent: true, opacity: 0.55, side: THREE.DoubleSide,
      }), { cast: false });
      gel.position.z = 0.16;
      add(gel);
      return { visual: group, emissiveHidden: false };
    }
    default:
      return { visual: group, emissiveHidden: false };
  }
}

// ---------------- 摄影师机位（三脚架 + 相机） ----------------
export function buildCameraRig() {
  const group = new THREE.Group();
  group.name = 'cameraRig';
  const tripod = buildStand('normal', { height: 1.15 });
  const head = new THREE.Group();
  head.name = 'cameraHead';
  head.position.y = 1.18;
  // 云台。
  const ball = mesh(new THREE.SphereGeometry(0.045, 14, 10), MAT.dark);
  const plate = mesh(new THREE.BoxGeometry(0.09, 0.02, 0.09), MAT.silver);
  plate.position.y = 0.045;
  // 机身（沿 +Z 拍摄）。
  const body = mesh(new THREE.BoxGeometry(0.14, 0.1, 0.09), MAT.black);
  body.position.set(0, 0.1, 0.01);
  const grip = mesh(new THREE.BoxGeometry(0.045, 0.1, 0.1), MAT.dark);
  grip.position.set(-0.085, 0.1, 0.01);
  const lens = mesh(new THREE.CylinderGeometry(0.038, 0.045, 0.14, 18), MAT.dark);
  lens.rotation.x = Math.PI / 2;
  lens.position.set(0.02, 0.1, 0.13);
  const hoodRing = mesh(new THREE.TorusGeometry(0.045, 0.008, 8, 20), MAT.black);
  hoodRing.position.set(0.02, 0.1, 0.2);
  const screen = mesh(new THREE.PlaneGeometry(0.09, 0.06), new THREE.MeshBasicMaterial({
    color: 0x9fd4ff, transparent: true, opacity: 0.6,
  }), { cast: false });
  screen.rotation.y = Math.PI;
  screen.position.set(0, 0.1, -0.046);
  head.add(ball, plate, body, grip, lens, hoodRing, screen);
  group.add(tripod, head);
  group.userData.head = head;
  return group;
}

// 焦段（mm，全画幅）→ 垂直视场角（度）。
export function focalToFov(focal) {
  const f = Math.max(8, Math.min(300, Number(focal) || 50));
  return 2 * Math.atan(24 / (2 * f)) / DEG;
}

// 共享材质标记：不随单个控光件销毁而释放。
for (const material of Object.values(MAT)) material.userData.ssShared = true;

export const RIG_MATERIALS = MAT;
