// 人体模型 v2（G4 / D32 降级实现）：写实比例假人 + 五官 + 手指 + 发型 +
// 性别切换 + 骨骼模式（Posemaniacs 式可旋转骨骼预览）。
// 12 个可控关节（角度制，[rx, ry, rz]）：spine/neck/shoulder_l/elbow_l/wrist_l/
// shoulder_r/elbow_r/wrist_r/hip_l/knee_l/hip_r/knee_r。
import * as THREE from 'three';
import { DEG, lerp, easeInOut } from './util.js';

export const JOINT_NAMES = [
  'spine', 'neck',
  'shoulder_l', 'elbow_l', 'wrist_l',
  'shoulder_r', 'elbow_r', 'wrist_r',
  'hip_l', 'knee_l', 'hip_r', 'knee_r',
];

export const JOINT_LABELS = {
  spine: '腰', neck: '颈',
  shoulder_l: '左肩', elbow_l: '左肘', wrist_l: '左腕',
  shoulder_r: '右肩', elbow_r: '右肘', wrist_r: '右腕',
  hip_l: '左髋', knee_l: '左膝', hip_r: '右髋', knee_r: '右膝',
};

export function defaultJoints() {
  return {
    spine: [0, 0, 0], neck: [0, 0, 0],
    shoulder_l: [0, 0, 8], elbow_l: [-12, 0, 0], wrist_l: [0, 0, 0],
    shoulder_r: [0, 0, -8], elbow_r: [-12, 0, 0], wrist_r: [0, 0, 0],
    hip_l: [-2, 0, 2], knee_l: [4, 0, 0], hip_r: [-2, 0, -2], knee_r: [4, 0, 0],
  };
}

function capsuleMesh(radius, length, material) {
  const geo = new THREE.CapsuleGeometry(radius, Math.max(0.001, length), 6, 14);
  const mesh = new THREE.Mesh(geo, material);
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  return mesh;
}

function sphereMesh(radius, material, seg = 20) {
  const mesh = new THREE.Mesh(
    new THREE.SphereGeometry(radius, seg, Math.max(10, seg - 6)),
    material,
  );
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  return mesh;
}

function boxMesh(w, h, d, material) {
  const mesh = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), material);
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  return mesh;
}

/// 构建人体假人。性别：male | female；骨骼模式：只显示骨架（Posemaniacs 式）。
export function buildPerson({ height = 1.7, gender = 'male' } = {}) {
  const s = height / 1.7;
  const skinMat = new THREE.MeshStandardMaterial({ color: 0xd9c5ae, roughness: 0.55, metalness: 0.02 });
  const skinDarkMat = new THREE.MeshStandardMaterial({ color: 0xc9b096, roughness: 0.6, metalness: 0.02 });
  const hairMat = new THREE.MeshStandardMaterial({ color: 0x2f2a27, roughness: 0.72, metalness: 0.05 });
  const eyeMat = new THREE.MeshStandardMaterial({ color: 0x2a2e35, roughness: 0.35 });
  const lipMat = new THREE.MeshStandardMaterial({ color: 0xb06a5e, roughness: 0.5 });
  const boneMat = new THREE.MeshStandardMaterial({ color: 0xece7de, roughness: 0.5, metalness: 0.03 });
  const jointMat = new THREE.MeshStandardMaterial({ color: 0xcfc6b8, roughness: 0.45, metalness: 0.05 });

  const root = new THREE.Group();
  const skinMeshes = [];
  const boneMeshes = [];
  const hairMale = [];
  const hairFemale = [];
  let currentGender = gender;

  const skin = (mesh) => { skinMeshes.push(mesh); return mesh; };
  const bone = (mesh) => { mesh.visible = false; boneMeshes.push(mesh); return mesh; };
  const boneJoint = (radius, pos) => {
    const m = sphereMesh(radius, jointMat, 12);
    m.position.copy(pos);
    return bone(m);
  };

  // ---- 关键骨架尺寸（米，1.7m 基准；7.5 头身）----
  const hipY = 0.96 * s;
  const chestY = 1.44 * s;
  const neckY = 1.53 * s;
  const headY = 1.62 * s;
  const headR = 0.098 * s;

  // 髋
  const hips = new THREE.Group();
  hips.position.set(0, hipY, 0);
  root.add(hips);
  const pelvis = skin(capsuleMesh(0.125 * s, 0.07 * s, skinMat));
  pelvis.rotation.z = Math.PI / 2;
  pelvis.scale.set(1, 1, 0.82);
  hips.add(pelvis);
  boneJoint(0.02 * s, new THREE.Vector3(0, 0, 0));

  // 脊柱 → 胸腔
  const spine = new THREE.Group();
  spine.name = 'j:spine';
  hips.add(spine);
  const waist = skin(capsuleMesh(0.115 * s, 0.16 * s, skinMat));
  waist.position.y = 0.14 * s;
  waist.scale.set(1, 1, 0.78);
  spine.add(waist);
  const chest = skin(capsuleMesh(0.155 * s, 0.2 * s, skinMat));
  chest.position.y = 0.32 * s;
  chest.scale.set(1.14, 1, 0.68);
  spine.add(chest);
  const chestBone = bone(capsuleMesh(0.03 * s, 0.3 * s, boneMat));
  chestBone.position.y = 0.24 * s;
  spine.add(chestBone);
  const ribBone = bone(capsuleMesh(0.02 * s, 0.16 * s, boneMat));
  ribBone.position.y = 0.33 * s;
  ribBone.rotation.z = Math.PI / 2;
  ribBone.scale.set(1, 1, 0.7);
  spine.add(ribBone);

  // 颈 → 头（含五官）
  const neck = new THREE.Group();
  neck.name = 'j:neck';
  neck.position.y = 0.46 * s;
  spine.add(neck);
  const neckMesh = skin(capsuleMesh(0.047 * s, 0.07 * s, skinDarkMat));
  neckMesh.position.y = 0.03 * s;
  neck.add(neckMesh);
  const neckBone = bone(capsuleMesh(0.016 * s, 0.08 * s, boneMat));
  neckBone.position.y = 0.03 * s;
  neck.add(neckBone);

  const skull = skin(sphereMesh(headR, skinMat, 26));
  skull.position.y = 0.15 * s;
  skull.scale.set(0.92, 1.06, 0.98);
  neck.add(skull);
  const jaw = skin(sphereMesh(headR * 0.72, skinMat, 20));
  jaw.position.set(0, 0.105 * s, 0.012 * s);
  jaw.scale.set(0.86, 0.82, 0.94);
  neck.add(jaw);
  // 耳
  for (const sign of [1, -1]) {
    const ear = skin(sphereMesh(headR * 0.2, skinDarkMat, 10));
    ear.position.set(sign * headR * 0.94, 0.145 * s, -0.004 * s);
    ear.scale.set(0.5, 1.1, 0.7);
    neck.add(ear);
  }
  // 眼（含眼窝阴影）、眉、鼻、嘴（人物面向 +Z）
  for (const sign of [1, -1]) {
    const socket = skin(sphereMesh(headR * 0.24, skinDarkMat, 12));
    socket.position.set(sign * headR * 0.36, 0.165 * s, headR * 0.82);
    socket.scale.set(1.15, 0.85, 0.5);
    neck.add(socket);
    const eye = new THREE.Mesh(new THREE.SphereGeometry(headR * 0.115, 10, 8), eyeMat);
    eye.position.set(sign * headR * 0.36, 0.163 * s, headR * 0.9);
    eye.scale.set(1, 1, 0.55);
    neck.add(eye);
    const brow = new THREE.Mesh(new THREE.BoxGeometry(headR * 0.4, headR * 0.06, headR * 0.1), hairMat);
    brow.position.set(sign * headR * 0.38, 0.235 * s, headR * 0.86);
    brow.rotation.z = sign * -0.12;
    neck.add(brow);
  }
  const nose = skin(boxMesh(headR * 0.16, headR * 0.3, headR * 0.24, skinMat));
  nose.position.set(0, 0.135 * s, headR * 0.94);
  nose.rotation.x = 0.28;
  neck.add(nose);
  const mouth = new THREE.Mesh(new THREE.BoxGeometry(headR * 0.34, headR * 0.055, headR * 0.08), lipMat);
  mouth.position.set(0, 0.075 * s, headR * 0.86);
  neck.add(mouth);
  // 发型：男短发 / 女长发（切换显示）
  const hairCap = new THREE.Mesh(
    new THREE.SphereGeometry(headR * 1.06, 22, 16, 0, Math.PI * 2, 0, Math.PI * 0.62),
    hairMat,
  );
  hairCap.position.y = 0.155 * s;
  hairCap.scale.set(0.98, 1.02, 1.04);
  hairMale.push(hairCap);
  const hairBackF = new THREE.Mesh(new THREE.SphereGeometry(headR * 0.95, 18, 14), hairMat);
  hairBackF.position.set(0, 0.06 * s, -headR * 0.42);
  hairBackF.scale.set(0.95, 1.7, 0.72);
  hairFemale.push(hairBackF);
  for (const sign of [1, -1]) {
    const strand = new THREE.Mesh(new THREE.CapsuleGeometry(headR * 0.26, headR * 1.7, 5, 10), hairMat);
    strand.position.set(sign * headR * 0.82, -0.08 * s, -headR * 0.28);
    strand.rotation.z = sign * 0.08;
    hairFemale.push(strand);
  }
  neck.add(hairCap, hairBackF, ...hairFemale.slice(1));

  // 肩 / 臂 / 手（含手指）
  function buildArm(side) {
    const sign = side === 'l' ? 1 : -1;
    const shoulder = new THREE.Group();
    shoulder.name = `j:shoulder_${side}`;
    shoulder.position.set(sign * 0.195 * s, 0.4 * s, 0);
    spine.add(shoulder);

    const shoulderBall = skin(sphereMesh(0.062 * s, skinDarkMat, 14));
    shoulderBall.scale.set(1.05, 0.9, 1);
    shoulder.add(shoulderBall);
    boneJoint(0.02 * s, new THREE.Vector3(0, 0, 0));

    const upperArm = skin(capsuleMesh(0.052 * s, 0.23 * s, skinMat));
    upperArm.position.y = -0.16 * s;
    shoulder.add(upperArm);
    const humerus = bone(capsuleMesh(0.017 * s, 0.24 * s, boneMat));
    humerus.position.y = -0.16 * s;
    shoulder.add(humerus);

    const elbow = new THREE.Group();
    elbow.name = `j:elbow_${side}`;
    elbow.position.y = -0.32 * s;
    shoulder.add(elbow);
    const elbowBall = skin(sphereMesh(0.045 * s, skinDarkMat, 12));
    elbow.add(elbowBall);
    boneJoint(0.018 * s, new THREE.Vector3(0, 0, 0));

    const foreArm = skin(capsuleMesh(0.045 * s, 0.22 * s, skinMat));
    foreArm.position.y = -0.14 * s;
    foreArm.scale.set(1, 1, 0.94);
    elbow.add(foreArm);
    const radiusBone = bone(capsuleMesh(0.014 * s, 0.22 * s, boneMat));
    radiusBone.position.y = -0.14 * s;
    elbow.add(radiusBone);

    const wrist = new THREE.Group();
    wrist.name = `j:wrist_${side}`;
    wrist.position.y = -0.29 * s;
    elbow.add(wrist);
    boneJoint(0.014 * s, new THREE.Vector3(0, 0, 0));

    // 手掌 + 四指 + 拇指（简化分指，Posemaniacs 式可辨识手型）。
    const palm = skin(boxMesh(0.062 * s, 0.085 * s, 0.026 * s, skinMat));
    palm.position.y = -0.05 * s;
    wrist.add(palm);
    for (let f = 0; f < 4; f++) {
      const finger = skin(capsuleMesh(0.011 * s, 0.036 * s, skinMat));
      finger.position.set((f - 1.5) * 0.0155 * s, -0.115 * s, 0);
      finger.rotation.x = 0.14 + f * 0.02;
      wrist.add(finger);
    }
    const thumb = skin(capsuleMesh(0.013 * s, 0.032 * s, skinMat));
    thumb.position.set(sign * 0.036 * s, -0.055 * s, 0.012 * s);
    thumb.rotation.z = sign * 0.7;
    thumb.rotation.x = 0.3;
    wrist.add(thumb);

    return { shoulder, elbow, wrist };
  }

  // 腿（含脚趾示意）
  function buildLeg(side) {
    const sign = side === 'l' ? 1 : -1;
    const hip = new THREE.Group();
    hip.name = `j:hip_${side}`;
    hip.position.set(sign * 0.095 * s, -0.06 * s, 0);
    hips.add(hip);

    const hipBall = skin(sphereMesh(0.072 * s, skinMat, 14));
    hipBall.scale.set(1, 1.05, 1);
    hip.add(hipBall);
    boneJoint(0.02 * s, new THREE.Vector3(0, 0, 0));

    const thigh = skin(capsuleMesh(0.08 * s, 0.34 * s, skinMat));
    thigh.position.y = -0.24 * s;
    thigh.scale.set(1, 1, 0.96);
    hip.add(thigh);
    const femur = bone(capsuleMesh(0.02 * s, 0.36 * s, boneMat));
    femur.position.y = -0.24 * s;
    hip.add(femur);

    const knee = new THREE.Group();
    knee.name = `j:knee_${side}`;
    knee.position.y = -0.48 * s;
    hip.add(knee);
    const kneeBall = skin(sphereMesh(0.055 * s, skinDarkMat, 12));
    kneeBall.scale.set(0.95, 1, 1);
    knee.add(kneeBall);
    boneJoint(0.018 * s, new THREE.Vector3(0, 0, 0));

    const shin = skin(capsuleMesh(0.058 * s, 0.34 * s, skinMat));
    shin.position.y = -0.23 * s;
    shin.scale.set(1, 1, 0.94);
    knee.add(shin);
    const tibia = bone(capsuleMesh(0.015 * s, 0.34 * s, boneMat));
    tibia.position.y = -0.23 * s;
    knee.add(tibia);

    const ankle = new THREE.Group();
    ankle.name = `j:ankle_${side}`;
    ankle.position.y = -0.46 * s;
    knee.add(ankle);
    boneJoint(0.012 * s, new THREE.Vector3(0, 0, 0));
    const foot = skin(boxMesh(0.088 * s, 0.05 * s, 0.2 * s, skinDarkMat));
    foot.position.set(0, -0.025 * s, 0.05 * s);
    ankle.add(foot);
    const toes = skin(capsuleMesh(0.024 * s, 0.05 * s, skinMat));
    toes.position.set(0, -0.028 * s, 0.15 * s);
    toes.rotation.x = Math.PI / 2;
    toes.scale.set(1.5, 1, 0.8);
    ankle.add(toes);

    return { hip, knee, ankle };
  }

  const armL = buildArm('l');
  const armR = buildArm('r');
  const legL = buildLeg('l');
  const legR = buildLeg('r');

  const joints = {
    spine, neck,
    shoulder_l: armL.shoulder, elbow_l: armL.elbow, wrist_l: armL.wrist,
    shoulder_r: armR.shoulder, elbow_r: armR.elbow, wrist_r: armR.wrist,
    hip_l: legL.hip, knee_l: legL.knee, hip_r: legR.hip, knee_r: legR.knee,
  };

  // 关节标记（点击可微调；仅在关节模式显示）。
  const markerMat = new THREE.MeshBasicMaterial({ color: 0x4d6bfe, transparent: true, opacity: 0.85 });
  const markers = {};
  for (const name of JOINT_NAMES) {
    const marker = new THREE.Mesh(new THREE.SphereGeometry(0.032 * s, 10, 10), markerMat.clone());
    marker.userData = { joint: name };
    marker.visible = false;
    joints[name].add(marker);
    markers[name] = marker;
  }

  let current = defaultJoints();
  let rootY = 0;
  let rootPitch = 0;
  let anim = null;

  function applyOne(name, rot) {
    const j = joints[name];
    if (!j) return;
    j.rotation.set((rot[0] || 0) * DEG, (rot[1] || 0) * DEG, (rot[2] || 0) * DEG);
  }

  function applyRoot() {
    root.position.y = rootY;
    root.rotation.x = rootPitch * DEG;
  }

  function setJoints(next) {
    if (typeof next.rootY === 'number') rootY = next.rootY;
    if (typeof next.rootPitch === 'number') rootPitch = next.rootPitch;
    for (const name of JOINT_NAMES) {
      if (next[name]) current[name] = next[name];
      applyOne(name, current[name]);
    }
    applyRoot();
  }

  function animateTo(next, duration = 320) {
    const from = {
      joints: JSON.parse(JSON.stringify(current)),
      rootY,
      rootPitch,
    };
    const target = { joints: { ...current }, rootY, rootPitch };
    for (const name of JOINT_NAMES) if (next[name]) target.joints[name] = next[name];
    if (typeof next.rootY === 'number') target.rootY = next.rootY;
    if (typeof next.rootPitch === 'number') target.rootPitch = next.rootPitch;
    anim = { from, target, start: performance.now(), duration };
    current = target.joints;
    rootY = target.rootY;
    rootPitch = target.rootPitch;
  }

  function tick(t) {
    if (!anim) return;
    const p = Math.min(1, (t - anim.start) / anim.duration);
    const e = easeInOut(p);
    for (const name of JOINT_NAMES) {
      const a = anim.from.joints[name] || [0, 0, 0];
      const b = anim.target.joints[name] || [0, 0, 0];
      applyOne(name, [lerp(a[0], b[0], e), lerp(a[1], b[1], e), lerp(a[2], b[2], e)]);
    }
    root.position.y = lerp(anim.from.rootY, anim.target.rootY, e);
    root.rotation.x = lerp(anim.from.rootPitch, anim.target.rootPitch, e) * DEG;
    if (p >= 1) anim = null;
  }

  function setMarkerMode(on) {
    for (const name of JOINT_NAMES) markers[name].visible = on;
  }

  /// 性别切换：肩宽 / 髋宽 / 胸部 / 发型。
  function setGender(g) {
    currentGender = g === 'female' ? 'female' : 'male';
    const female = currentGender === 'female';
    armL.shoulder.position.x = (female ? 0.178 : 0.195) * s;
    armR.shoulder.position.x = -(female ? 0.178 : 0.195) * s;
    legL.hip.position.x = (female ? 0.1 : 0.095) * s;
    legR.hip.position.x = -(female ? 0.1 : 0.095) * s;
    chest.scale.set(female ? 1.06 : 1.14, female ? 0.96 : 1, female ? 0.72 : 0.68);
    pelvis.scale.set(female ? 1.08 : 1, 1, 0.82);
    for (const m of hairMale) m.visible = !female;
    for (const m of hairFemale) m.visible = female;
  }

  /// 骨骼模式（Posemaniacs 式）：隐藏皮肤显示骨架。
  function setSkeletonMode(on) {
    for (const m of skinMeshes) m.visible = !on;
    for (const m of boneMeshes) m.visible = on;
  }

  setJoints(defaultJoints());
  setGender(currentGender);

  return {
    root,
    joints,
    markers,
    setJoints,
    animateTo,
    setMarkerMode,
    tick,
    height: s,
    getJoints: () => current,
    setGender,
    setSkeletonMode,
    gender: () => currentGender,
  };
}
