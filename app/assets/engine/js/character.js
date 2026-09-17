// 角色模块（B1/B3/B4/B5）：GLB 人形加载、12 关节语义映射、换人/换装/发型/肤色。
// 映射层不直接使用 GLB 绑定姿态：为每根骨骼计算「绑定世界朝向→假人静止朝向」的
// 重映射四元数 R，令 Qb = Qj * R * B0（Qj 为假人语义链世界朝向，B0 为绑定世界朝向，
// 由局部旋转反解），从而保持 setJoints/setPose/animateTo 的角度语义与旧假人一致。
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { clone as cloneSkinned } from 'three/addons/utils/SkeletonUtils.js';

import { DEG, easeInOut, lerp } from './util.js';
import { planSubdivision } from './subdivision_plan.js';
import { subdivideForPlan, triangleCount } from './subdivision.js';
import {
  applyMaterialPreset,
  DEFAULT_MATERIAL_PRESET,
  MATERIAL_PRESETS,
} from './materials.js';

export const JOINT_NAMES = [
  'spine', 'neck',
  'shoulder_l', 'elbow_l', 'wrist_l',
  'shoulder_r', 'elbow_r', 'wrist_r',
  'hip_l', 'knee_l', 'hip_r', 'knee_r',
];

export function defaultJoints() {
  return {
    spine: [0, 0, 0], neck: [0, 0, 0],
    shoulder_l: [0, 0, 8], elbow_l: [-12, 0, 0], wrist_l: [0, 0, 0],
    shoulder_r: [0, 0, -8], elbow_r: [-12, 0, 0], wrist_r: [0, 0, 0],
    hip_l: [-2, 0, 2], knee_l: [4, 0, 0], hip_r: [-2, 0, -2], knee_r: [4, 0, 0],
  };
}

const SEMANTIC_PARENT = {
  spine: null, neck: 'spine',
  shoulder_l: 'spine', elbow_l: 'shoulder_l', wrist_l: 'elbow_l',
  shoulder_r: 'spine', elbow_r: 'shoulder_r', wrist_r: 'elbow_r',
  hip_l: null, knee_l: 'hip_l',
  hip_r: null, knee_r: 'hip_r',
};

// 假人静止时各关节段的朝向（模型空间，人物面向 +Z）。
const DUMMY_REST_DIR = {
  spine: [0, 1, 0], neck: [0, 1, 0],
  shoulder_l: [0, -1, 0], elbow_l: [0, -1, 0], wrist_l: [0, -1, 0],
  shoulder_r: [0, -1, 0], elbow_r: [0, -1, 0], wrist_r: [0, -1, 0],
  hip_l: [0, -1, 0], knee_l: [0, -1, 0],
  hip_r: [0, -1, 0], knee_r: [0, -1, 0],
};

const BONE_SPECS = {
  spine: { keys: ['abdomen', 'spine', 'torso', 'spine01', 'spine1', 'spine02', 'chest'] },
  neck: { keys: ['neck', 'neck01', 'neck1'] },
  shoulder_l: { side: 'l', keys: ['upperarm', 'arm', 'shoulder'] },
  elbow_l: { side: 'l', keys: ['lowerarm', 'forearm', 'elbow'] },
  wrist_l: { side: 'l', keys: ['hand', 'wrist'] },
  shoulder_r: { side: 'r', keys: ['upperarm', 'arm', 'shoulder'] },
  elbow_r: { side: 'r', keys: ['lowerarm', 'forearm', 'elbow'] },
  wrist_r: { side: 'r', keys: ['hand', 'wrist'] },
  hip_l: { side: 'l', keys: ['upperleg', 'thigh', 'upleg', 'hip'] },
  knee_l: { side: 'l', keys: ['lowerleg', 'calf', 'shin', 'knee'] },
  hip_r: { side: 'r', keys: ['upperleg', 'thigh', 'upleg', 'hip'] },
  knee_r: { side: 'r', keys: ['lowerleg', 'calf', 'shin', 'knee'] },
};

function normBoneName(name) {
  return String(name || '').toLowerCase().replace(/mixamorig[:_\-\s]?/g, '').replace(/[^a-z0-9]/g, '');
}

function sideOf(name, norm) {
  const raw = String(name || '').toLowerCase();
  if (/(^|[._\-\s])left([._\-\s]|$)/.test(raw) || norm.startsWith('left')) return 'l';
  if (/(^|[._\-\s])right([._\-\s]|$)/.test(raw) || norm.startsWith('right')) return 'r';
  if (/[._\-\s]l$/.test(raw) || /l$/.test(norm)) return 'l';
  if (/[._\-\s]r$/.test(raw) || /r$/.test(norm)) return 'r';
  return null;
}

function findBone(bones, spec) {
  let best = null;
  let bestScore = -Infinity;
  for (const bone of bones) {
    const norm = normBoneName(bone.name);
    let score = 0;
    if (spec.side) {
      if (sideOf(bone.name, norm) !== spec.side) continue;
      score += 20;
    }
    let keyIndex = spec.keys.findIndex((k) => norm === k);
    if (keyIndex >= 0) {
      score += 200 - keyIndex * 4;
    } else {
      keyIndex = spec.keys.findIndex((k) => norm.includes(k));
      if (keyIndex < 0) continue;
      score += 100 - keyIndex * 4;
    }
    if (spec.side && !/(arm|hand|leg|foot|thigh|calf|shoulder|hip)/.test(norm)) score -= 5;
    if (score > bestScore) { best = bone; bestScore = score; }
  }
  return best;
}

// ---------------- V5 手部（D86–D88、R35）：手指骨发现 + 语义弯曲 ----------------

const HAND_FINGERS = ['thumb', 'index', 'middle', 'ring', 'pinky'];
const FINGER_KEYWORDS = {
  thumb: /thumb/i,
  index: /index/i,
  middle: /middle/i,
  ring: /ring/i,
  pinky: /pinky|little/i,
};
// 每关节最大屈曲角（度，近端→远端；不足时取最后一档）。
const FINGER_MAX_ANGLES = {
  index: [85, 100, 70],
  middle: [85, 100, 70],
  ring: [85, 100, 70],
  pinky: [85, 100, 70],
  thumb: [55, 50, 40],
};

// 单手预设（curls ∈ [0,1]；spread ∈ [0,1]；wrist 为手部附加旋转，度）。
const HAND_PRESETS = {
  relax: { name: '自然放松', emoji: '🤚', curls: { thumb: 0.18, index: 0.22, middle: 0.26, ring: 0.3, pinky: 0.32 }, spread: 0.15 },
  open: { name: '五指张开', emoji: '🖐️', curls: { thumb: 0.05, index: 0, middle: 0, ring: 0, pinky: 0 }, spread: 1 },
  fist: { name: '握拳', emoji: '✊', curls: { thumb: 0.78, index: 1, middle: 1, ring: 1, pinky: 1 }, spread: 0 },
  halfGrip: { name: '半握', emoji: '🤏', curls: { thumb: 0.4, index: 0.55, middle: 0.6, ring: 0.65, pinky: 0.65 }, spread: 0.15 },
  thumbsUp: { name: '点赞', emoji: '👍', curls: { thumb: 0, index: 1, middle: 1, ring: 1, pinky: 1 }, spread: 0, wrist: [0, 0, -30] },
  peace: { name: '比耶', emoji: '✌️', curls: { thumb: 0.45, index: 0, middle: 0, ring: 1, pinky: 1 }, spread: 0.7 },
  ok: { name: 'OK 手势', emoji: '👌', curls: { thumb: 0.55, index: 0.62, middle: 0.05, ring: 0.05, pinky: 0.05 }, spread: 0.35 },
  point: { name: '食指指向', emoji: '☝️', curls: { thumb: 0.7, index: 0, middle: 1, ring: 1, pinky: 1 }, spread: 0.2 },
  heart: { name: '比心', emoji: '🫶', curls: { thumb: 0.35, index: 0.5, middle: 0.85, ring: 1, pinky: 1 }, spread: 0.45 },
  pinch: { name: '捏合', emoji: '🤏', curls: { thumb: 0.72, index: 0.72, middle: 0.15, ring: 0.15, pinky: 0.15 }, spread: 0.1 },
  wave: { name: '挥手', emoji: '👋', curls: { thumb: 0.2, index: 0, middle: 0, ring: 0, pinky: 0 }, spread: 0.9, wrist: [0, 0, -22] },
  chinRest: { name: '托腮', emoji: '🤔', curls: { thumb: 0.35, index: 0.62, middle: 0.7, ring: 0.75, pinky: 0.75 }, spread: 0.1, wrist: [52, -8, -14] },
};

// 双手组合预设：仅手指/手部部分（手臂角度由前端姿势系统叠加，见 lighting_controller）。
const HAND_DUAL_PRESETS = {
  gongshou: {
    name: '抱拳（双手）',
    hands: {
      l: { curls: { thumb: 0.55, index: 0.95, middle: 1, ring: 1, pinky: 1 }, spread: 0.05 },
      r: { curls: { thumb: 0.55, index: 0.95, middle: 1, ring: 1, pinky: 1 }, spread: 0.05 },
    },
  },
  qigong: {
    name: '拱手（双手）',
    hands: {
      l: { curls: { thumb: 0.45, index: 0.85, middle: 0.95, ring: 0.95, pinky: 0.95 }, spread: 0.3 },
      r: { curls: { thumb: 0.45, index: 0.85, middle: 0.95, ring: 0.95, pinky: 0.95 }, spread: 0.3 },
    },
  },
  prayer: {
    name: '双手合十',
    hands: {
      l: { curls: { thumb: 0.5, index: 0.05, middle: 0.05, ring: 0.05, pinky: 0.05 }, spread: 0.02, wrist: [42, -12, 0] },
      r: { curls: { thumb: 0.5, index: 0.05, middle: 0.05, ring: 0.05, pinky: 0.05 }, spread: 0.02, wrist: [42, 12, 0] },
    },
  },
};

function fingerOrder(name) {
  const nums = String(name || '').match(/\d+/g);
  if (!nums || !nums.length) return 0;
  return parseInt(nums[nums.length - 1], 10);
}

// 发现手指骨并计算屈伸/张开轴（自标定：符号由“卷向手腕/远离中指”判定，适配任意骨架）。
function discoverHands(inst) {
  const handJoints = new Map();
  const support = {
    l: { supported: false, fingers: {} },
    r: { supported: false, fingers: {} },
  };
  for (const side of ['l', 'r']) {
    const handBone = inst.mapped['wrist_' + side];
    if (!handBone) continue;
    const handPos = inst.bindPos.get(handBone).clone();
    const perFinger = {};
    for (const finger of HAND_FINGERS) {
      const chain = inst.bones
        .filter((b) => FINGER_KEYWORDS[finger].test(String(b.name)) && sideOf(b.name, normBoneName(b.name)) === side)
        .sort((a, b) => fingerOrder(a.name) - fingerOrder(b.name));
      if (chain.length >= 2) perFinger[finger] = chain;
    }
    if (Object.keys(perFinger).length < 3) continue; // 至少三指才视为可驱动
    const midChain = perFinger.middle || null;
    const midBase = midChain ? inst.bindPos.get(midChain[0]).clone() : handPos.clone();
    const idxBase = perFinger.index ? inst.bindPos.get(perFinger.index[0]).clone() : handPos.clone();
    const pkyBase = perFinger.pinky ? inst.bindPos.get(perFinger.pinky[0]).clone() : handPos.clone();
    const along = midBase.clone().sub(handPos);
    if (along.lengthSq() < 1e-8) along.set(0, -1, 0);
    const across = pkyBase.clone().sub(idxBase);
    const palmN = new THREE.Vector3().crossVectors(along, across);
    if (palmN.lengthSq() < 1e-8) palmN.set(0, 0, 1);
    palmN.normalize();

    for (const finger of Object.keys(perFinger)) {
      const chain = perFinger[finger];
      const maxAngles = FINGER_MAX_ANGLES[finger] || [80, 90, 70];
      for (let i = 0; i < chain.length; i++) {
        const bone = chain[i];
        const jointPos = inst.bindPos.get(bone).clone();
        const child = chain[i + 1] || bone.children.find((c) => inst.boneSet.has(c)) || null;
        const dir = child
          ? inst.bindPos.get(child).clone().sub(jointPos)
          : new THREE.Vector3(0, -1, 0);
        if (dir.lengthSq() < 1e-8) dir.set(0, -1, 0);
        dir.normalize();
        let axis = new THREE.Vector3().crossVectors(dir, palmN);
        if (axis.lengthSq() < 1e-8) axis.set(1, 0, 0);
        axis.normalize();
        const toPalm = handPos.clone().sub(jointPos).normalize();
        const probe = dir.clone().applyQuaternion(
          new THREE.Quaternion().setFromAxisAngle(axis, 25 * Math.PI / 180),
        );
        if (probe.dot(toPalm) < dir.dot(toPalm)) axis.negate();
        const parentQ = (bone.parent && inst.bindQuat.get(bone.parent)) || new THREE.Quaternion();
        const parentInv = parentQ.clone().invert();
        const entry = {
          side,
          finger,
          index: i,
          maxAngle: maxAngles[Math.min(i, maxAngles.length - 1)] || 70,
          axisParent: axis.clone().applyQuaternion(parentInv).normalize(),
          restLocal: (inst.restLocal.get(bone) || bone.quaternion).clone(),
          spreadAxisParent: null,
          spreadSign: 0,
        };
        if (i === 0 && finger !== 'middle') {
          const away = jointPos.clone().sub(midBase);
          if (away.lengthSq() > 1e-8) away.normalize();
          else away.copy(across).normalize();
          const spreadAxis = palmN.clone();
          const probeS = dir.clone().applyQuaternion(
            new THREE.Quaternion().setFromAxisAngle(spreadAxis, 20 * Math.PI / 180),
          );
          const sign = probeS.dot(away) >= dir.dot(away) ? 1 : -1;
          entry.spreadAxisParent = spreadAxis.applyQuaternion(parentInv).normalize();
          entry.spreadSign = sign;
        }
        handJoints.set(bone, entry);
      }
    }
    support[side] = {
      supported: true,
      fingers: Object.fromEntries(Object.entries(perFinger).map(([k, v]) => [k, v.length])),
    };
  }
  inst.handJoints = handJoints;
  inst.handSupport = support;
}

function quatFromDir(from, to) {
  const a = from.clone().normalize();
  const b = to.clone().normalize();
  const q = new THREE.Quaternion();
  const dot = THREE.MathUtils.clamp(a.dot(b), -1, 1);
  if (dot < -0.9999) {
    const axis = Math.abs(a.x) < 0.9 ? new THREE.Vector3(1, 0, 0) : new THREE.Vector3(0, 0, 1);
    axis.crossVectors(a, axis).normalize();
    q.setFromAxisAngle(axis, Math.PI);
  } else {
    q.setFromUnitVectors(a, b);
  }
  return q;
}

function loadArrayBuffer(url) {
  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    xhr.open('GET', url, true);
    xhr.responseType = 'arraybuffer';
    xhr.onload = () => {
      const ok = xhr.status === 0 || (xhr.status >= 200 && xhr.status < 300);
      if (ok && xhr.response) resolve(xhr.response);
      else reject(new Error(`资源加载失败（HTTP ${xhr.status}）：${url}`));
    };
    xhr.onerror = () => reject(new Error(`资源加载失败（网络错误）：${url}`));
    xhr.send();
  });
}

async function loadJSON(url) {
  const buffer = await loadArrayBuffer(url);
  return JSON.parse(new TextDecoder('utf-8').decode(buffer));
}

export function createCharacterManager({ send = () => {}, baseUrl = null } = {}) {
  const loader = new GLTFLoader();
  const root = new THREE.Group();
  root.name = 'ssCharacterRoot';
  const inner = new THREE.Group();
  inner.name = 'ssCharacterInner';
  root.add(inner);

  const glbCache = new Map();
  const instanceCache = new Map();
  const preparedInstances = new Set();
  let manifest = null;
  let manifestPromise = null;
  let instance = null;
  let queue = Promise.resolve();
  let subdivisionLevel = 1; // 0=轻量（原模型）|1=默认|2=可选高密度
  let materialPreset = DEFAULT_MATERIAL_PRESET;

  const state = {
    mode: 'none',
    characterId: null,
    outfitId: null,
    hairId: null,
    skinTone: null,
    ready: false,
    loading: false,
    error: null,
    realistic: false,
    // V5/D86：手部状态（左右独立）：{curls:{thumb,index,middle,ring,pinky}, spread, wrist}。
    hands: { l: null, r: null },
    handPreset: { l: null, r: null },
  };

  const pose = { joints: defaultJoints(), rootY: 0, rootPitch: 0 };
  let anim = null;

  function assetBase() {
    if (baseUrl) return baseUrl;
    return new URL('../models/characters/', document.baseURI).href;
  }

  function entryUrl(file) {
    return new URL(file, assetBase()).href;
  }

  function fail(message) {
    state.error = message;
    state.loading = false;
    send('error', { message });
    throw new Error(message);
  }

  async function getManifest() {
    if (manifest) return manifest;
    if (!manifestPromise) {
      const url = new URL('manifest.json', assetBase()).href;
      manifestPromise = loadJSON(url).then((data) => {
        manifest = {
          characters: Array.isArray(data.characters) ? data.characters : [],
          outfits: Array.isArray(data.outfits) ? data.outfits : [],
          hair: Array.isArray(data.hair) ? data.hair : [],
          missing: Array.isArray(data.missing) ? data.missing : [],
          realisticAvailable: !!data.realisticAvailable,
          realistic: data.realistic && typeof data.realistic === 'object' ? data.realistic : null,
        };
        return manifest;
      }).catch((err) => {
        manifestPromise = null;
        throw new Error(`角色清单加载失败：${err.message || err}`);
      });
    }
    return manifestPromise;
  }

  async function getGLB(file) {
    const url = entryUrl(file);
    if (!glbCache.has(url)) {
      glbCache.set(url, (async () => {
        const raw = await loadArrayBuffer(url);
        return new Promise((resolve, reject) => {
          loader.parse(raw, url.slice(0, url.lastIndexOf('/') + 1), resolve, reject);
        });
      })().catch((err) => {
        glbCache.delete(url);
        throw err;
      }));
    }
    return glbCache.get(url);
  }

  // D61 写实模式：manifest.characters 中 realistic=true 的条目（含 MakeHuman/MPFB2 资产），
  // 其基础网格已是高密度（≥60k 三角面）且带 authored PBR 贴图，故运行时不再 Loop 细分、
  // 不覆盖材质预设，避免面数突破 120k 硬上限与贴图丢失。
  function isRealisticEntry(entry) {
    return !!(entry && (entry.realistic === true || entry.realisticAsset === true));
  }

  function prepareInstance(gltf, entry) {
    const realistic = isRealisticEntry(entry);
    const group = cloneSkinned(gltf.scene);
    group.name = `ssModel:${entry.id}`;
    const meshes = [];
    group.traverse((node) => {
      if (!node.isMesh) return;
      node.castShadow = true;
      node.receiveShadow = true;
      node.frustumCulled = false;
      if (node.material) {
        const list = Array.isArray(node.material) ? node.material : [node.material];
        const cloned = list.map((m) => m.clone());
        cloned.forEach((m) => {
          // D61：写实资产（MakeHuman/MPFB2）的 mhclo 薄壳服装/睫毛用 glTF doubleSided 表达，
          // 强制单面会看穿薄壳内壁；写实条目保留 GLTFLoader 解析出的 side，其余仍统一单面。
          if (!realistic) m.side = THREE.FrontSide;
        });
        node.material = Array.isArray(node.material) ? cloned : cloned[0];
      }
      meshes.push(node);
    });

    // D62：蒙皮网格运行时 Loop 细分（默认 1 次 + 不足 40k 时按网格自适应补第 2 次）。
    const baseGeometries = new Map();
    for (const node of meshes) {
      if (node.isSkinnedMesh && node.geometry) baseGeometries.set(node, node.geometry);
    }
    const skinned = meshes.filter((m) => m.isSkinnedMesh && baseGeometries.has(m));
    const triPlan = realistic
      ? skinned.map(() => 0)
      : planSubdivision(
        skinned.map((m) => triangleCount(baseGeometries.get(m))),
        subdivisionLevel,
      );
    skinned.forEach((mesh, i) => {
      mesh.geometry = subdivideForPlan(baseGeometries.get(mesh), triPlan[i], true);
    });
    for (const node of meshes) if (!realistic) applyPresetToMesh(node, materialPreset);

    group.updateMatrixWorld(true);
    const box = new THREE.Box3().setFromObject(group);
    const size = new THREE.Vector3();
    box.getSize(size);
    const scale = 1.7 / Math.max(0.01, size.y);
    group.scale.setScalar(scale);
    group.updateMatrixWorld(true);
    const box2 = new THREE.Box3().setFromObject(group);
    group.position.y -= box2.min.y;

    let skeleton = null;
    for (const mesh of meshes) {
      if (mesh.isSkinnedMesh && mesh.skeleton) { skeleton = mesh.skeleton; break; }
    }
    if (!skeleton) throw new Error(`模型不含骨骼：${entry.file}`);

    const bones = skeleton.bones.slice();
    const boneSet = new Set(bones);
    const mapped = {};
    const missing = [];
    for (const name of JOINT_NAMES) {
      const bone = findBone(bones, BONE_SPECS[name]);
      if (bone) mapped[name] = bone;
      else missing.push(name);
    }
    const boneToJoint = new Map();
    for (const name of JOINT_NAMES) if (mapped[name]) boneToJoint.set(mapped[name], name);

    if (realistic && missing.length) {
      // D61：写实角色骨骼名来自 MakeHuman（pelvis/spine_01/calf…），模糊匹配失败必须可读报错而非静默。
      send('error', { message: `写实模型骨骼映射不完整（${entry.file}）：缺少 ${missing.join(', ')}` });
    }

    group.updateMatrixWorld(true);
    const bindQuat = new Map();
    const restLocal = new Map();
    const bindPos = new Map();
    for (const bone of bones) {
      const pos = new THREE.Vector3();
      const quat = new THREE.Quaternion();
      const scl = new THREE.Vector3();
      bone.matrixWorld.decompose(pos, quat, scl);
      bindQuat.set(bone, quat);
      bindPos.set(bone, pos);
      restLocal.set(bone, bone.quaternion.clone());
    }

    const remap = {};
    // D61：写实资产（MakeHuman/MPFB2）自带自然直立绑定姿势，躯干链（spine/neck）的绑定朝向
    // 本就与假人静止朝向一致；再做「绑定朝向→假人静止朝向」矫正反而会把头颈拧到非自然角度
    // （实测：仰头 + 下颌/口腔形变）。因此写实条目对躯干链取单位矫正，四肢仍按 T 姿→下垂矫正。
    const REALISTIC_IDENTITY_REMAP = new Set(['spine', 'neck']);
    for (const name of JOINT_NAMES) {
      const bone = mapped[name];
      if (!bone) continue;
      if (realistic && REALISTIC_IDENTITY_REMAP.has(name)) {
        remap[name] = new THREE.Quaternion();
        continue;
      }
      const dir = new THREE.Vector3();
      const childJoint = Object.keys(SEMANTIC_PARENT).find((k) => SEMANTIC_PARENT[k] === name && mapped[k]);
      let tipBone = childJoint ? mapped[childJoint] : null;
      if (!tipBone) tipBone = bone.children.find((c) => boneSet.has(c)) || null;
      if (tipBone) dir.copy(bindPos.get(tipBone)).sub(bindPos.get(bone));
      if (dir.lengthSq() < 1e-8) dir.set(0, 1, 0).applyQuaternion(bindQuat.get(bone));
      dir.normalize();
      remap[name] = quatFromDir(dir, new THREE.Vector3(...DUMMY_REST_DIR[name]));
    }

    const markers = {};
    const markerMaterial = new THREE.MeshBasicMaterial({
      color: 0x4d6bfe, transparent: true, opacity: 0.85, depthTest: false,
    });
    for (const name of JOINT_NAMES) {
      const bone = mapped[name];
      if (!bone) continue;
      const marker = new THREE.Mesh(new THREE.SphereGeometry(0.028, 10, 10), markerMaterial.clone());
      marker.userData = { joint: name };
      marker.renderOrder = 9;
      marker.position.copy(bone.worldToLocal(bindPos.get(bone).clone()));
      marker.visible = false;
      bone.add(marker);
      markers[name] = marker;
    }

    let headBone = null;
    for (const bone of bones) {
      if (normBoneName(bone.name) === 'head') { headBone = bone; break; }
    }
    if (!headBone) headBone = mapped.neck || null;

    const skeletonHelper = new THREE.SkeletonHelper(group);
    skeletonHelper.visible = false;

    const inst = {
      entry,
      realistic,
      group,
      meshes,
      baseGeometries,
      triPlan,
      bones,
      boneSet,
      boneToJoint,
      skeleton,
      mapped,
      missing,
      remap,
      bindQuat,
      restLocal,
      bindPos,
      markers,
      headBone,
      skeletonHelper,
      rigidRoots: bones.filter((b) => !boneSet.has(b.parent)),
      mixer: gltf.animations && gltf.animations.length ? new THREE.AnimationMixer(group) : null,
      animations: gltf.animations || [],
      hairRoot: null,
      hairMeshes: [],
      jointMode: false,
      skeletonMode: false,
    };
    discoverHands(inst);
    inner.add(group);
    inner.add(skeletonHelper);
    preparedInstances.add(inst);
    return inst;
  }

  function applyPresetToMesh(mesh, preset) {
    if (!mesh || !mesh.material) return;
    const list = Array.isArray(mesh.material) ? mesh.material : [mesh.material];
    const hasUV = !!(mesh.geometry && mesh.geometry.attributes && mesh.geometry.attributes.uv);
    for (const material of list) applyMaterialPreset(material, preset, { hasUV });
  }

  function applySubdivisionLevel() {
    for (const inst of preparedInstances) {
      if (inst.realistic) continue; // D61：写实基础网格不再细分（保留 authored 密度）
      const skinned = inst.meshes.filter((m) => m.isSkinnedMesh && inst.baseGeometries.has(m));
      const triPlan = planSubdivision(
        skinned.map((m) => triangleCount(inst.baseGeometries.get(m))),
        subdivisionLevel,
      );
      skinned.forEach((mesh, i) => {
        mesh.geometry = subdivideForPlan(inst.baseGeometries.get(mesh), triPlan[i], true);
      });
      inst.triPlan = triPlan;
      for (const mesh of inst.hairMeshes) {
        const base = mesh.userData.ssBaseGeometry;
        if (base) mesh.geometry = subdivideForPlan(base, Math.min(subdivisionLevel, 2), false);
      }
    }
  }

  function currentTriangles(target = instance) {
    if (!target) return 0;
    let total = 0;
    for (const mesh of target.meshes) {
      if (mesh.isSkinnedMesh && mesh.geometry) total += triangleCount(mesh.geometry);
    }
    return total;
  }

  function semanticQuats(joints) {
    const w = {};
    for (const name of JOINT_NAMES) {
      const rot = joints[name] || [0, 0, 0];
      w[name] = new THREE.Quaternion().setFromEuler(
        new THREE.Euler((rot[0] || 0) * DEG, (rot[1] || 0) * DEG, (rot[2] || 0) * DEG, 'XYZ'),
      );
    }
    const qj = {};
    const resolve = (name) => {
      if (qj[name]) return qj[name];
      const parent = SEMANTIC_PARENT[name];
      qj[name] = parent ? resolve(parent).clone().multiply(w[name]) : w[name].clone();
      return qj[name];
    };
    for (const name of JOINT_NAMES) resolve(name);
    return qj;
  }

  // ---------------- V5 手部应用（D86/R35） ----------------

  function handConfigFor(side) {
    const cfg = state.hands ? state.hands[side] : null;
    if (cfg && cfg.curls) return cfg;
    return { curls: HAND_PRESETS.relax.curls, spread: HAND_PRESETS.relax.spread, wrist: null };
  }

  function handLocalQuat(hj) {
    const cfg = handConfigFor(hj.side);
    const raw = cfg.curls ? cfg.curls[hj.finger] : 0;
    const curl = Math.max(0, Math.min(1, typeof raw === 'number' ? raw : 0));
    const q = new THREE.Quaternion();
    if (curl > 0.0005) q.setFromAxisAngle(hj.axisParent, curl * hj.maxAngle * DEG);
    const spread = Math.max(0, Math.min(1, cfg.spread || 0));
    if (hj.spreadAxisParent && spread > 0.0005) {
      q.premultiply(new THREE.Quaternion().setFromAxisAngle(
        hj.spreadAxisParent,
        spread * 26 * DEG * hj.spreadSign,
      ));
    }
    return q.multiply(hj.restLocal);
  }

  function wristDeltaQuat(side) {
    const cfg = handConfigFor(side);
    if (!cfg.wrist || !Array.isArray(cfg.wrist)) return null;
    return new THREE.Quaternion().setFromEuler(new THREE.Euler(
      (cfg.wrist[0] || 0) * DEG, (cfg.wrist[1] || 0) * DEG, (cfg.wrist[2] || 0) * DEG, 'XYZ',
    ));
  }

  function applyPose(target = pose) {
    if (!instance) return;
    const qj = semanticQuats(target.joints);
    const walk = (bone, parentWorld) => {
      let local;
      const name = instance.boneToJoint.get(bone);
      if (name) {
        const world = qj[name].clone().multiply(instance.remap[name]).multiply(instance.bindQuat.get(bone));
        local = parentWorld.clone().invert().multiply(world);
        if (name === 'wrist_l' || name === 'wrist_r') {
          const dq = wristDeltaQuat(name === 'wrist_l' ? 'l' : 'r');
          if (dq) local.multiply(dq);
        }
        bone.quaternion.copy(local);
      } else if (instance.handJoints && instance.handJoints.has(bone)) {
        local = handLocalQuat(instance.handJoints.get(bone));
        bone.quaternion.copy(local);
      } else {
        local = (instance.restLocal.get(bone) || bone.quaternion).clone();
      }
      const world = parentWorld.clone().multiply(local);
      for (const child of bone.children) {
        if (instance.boneSet.has(child)) walk(child, world);
      }
    };
    const identity = new THREE.Quaternion();
    for (const rootBone of instance.rigidRoots) {
      let parentWorld = identity;
      if (rootBone.parent) {
        const p = new THREE.Matrix4().extractRotation(rootBone.parent.matrixWorld);
        parentWorld = new THREE.Quaternion().setFromRotationMatrix(p);
      }
      walk(rootBone, parentWorld.clone());
    }
    inner.position.y = target.rootY || 0;
    inner.rotation.x = (target.rootPitch || 0) * DEG;
  }

  function applySkinTone(inst = instance) {
    if (!inst || !state.skinTone) return;
    const color = new THREE.Color(state.skinTone);
    for (const mesh of inst.meshes) {
      const list = Array.isArray(mesh.material) ? mesh.material : [mesh.material];
      for (const mat of list) {
        if (!mat || !mat.color) continue;
        if (/skin/i.test(mat.name || '')) mat.color.copy(color);
      }
    }
  }

  function applySkeletonVisibility(inst = instance) {
    if (!inst) return;
    const on = !!inst.skeletonMode;
    for (const mesh of inst.meshes) mesh.visible = !on;
    for (const mesh of inst.hairMeshes) mesh.visible = !on;
    inst.skeletonHelper.visible = on;
    for (const name of JOINT_NAMES) {
      const marker = inst.markers[name];
      if (marker) marker.visible = inst.jointMode && !on;
    }
  }

  function clearInstance(inst) {
    if (!inst) return;
    inner.remove(inst.group);
    inner.remove(inst.skeletonHelper);
    if (inst.hairRoot && inst.hairRoot.parent) inst.hairRoot.parent.remove(inst.hairRoot);
    inst.hairRoot = null;
    inst.hairMeshes = [];
  }

  function getInstance(entry) {
    if (!instanceCache.has(entry.id)) {
      instanceCache.set(entry.id, getGLB(entry.file).then((gltf) => prepareInstance(gltf, entry)).catch((err) => {
        instanceCache.delete(entry.id);
        throw err;
      }));
    }
    return instanceCache.get(entry.id);
  }

  async function swapTo(entry) {
    state.loading = true;
    let next;
    try {
      next = await getInstance(entry);
    } catch (err) {
      fail(`角色模型加载失败：${entry.file}（${err.message || err}）`);
      return;
    }
    const previous = instance;
    instance = next;
    if (previous) clearInstance(previous);
    instance.group.visible = true;
    state.ready = true;
    state.loading = false;
    state.error = null;
    state.realistic = isRealisticEntry(entry);
    applyPose();
    applySkinTone();
    if (state.hairId) {
      try { await attachHair(state.hairId, { silentState: true }); }
      catch (err) { send('error', { message: `发型应用失败：${err.message || err}` }); }
    }
    applySkeletonVisibility();
  }

  async function attachHair(hairId, { silentState = false } = {}) {
    if (instance && instance.hairRoot) {
      if (instance.hairRoot.parent) instance.hairRoot.parent.remove(instance.hairRoot);
      instance.hairRoot = null;
      instance.hairMeshes = [];
    }
    if (!hairId || hairId === 'none') {
      if (!silentState) state.hairId = null;
      return;
    }
    const list = await getManifest();
    const entry = list.hair.find((h) => h.id === hairId);
    if (!entry) fail(`未找到发型：${hairId}`);
    if (!instance) {
      if (!silentState) state.hairId = hairId;
      return;
    }
    if (!instance.headBone) {
      fail('模型缺少头部骨骼，无法佩戴发型');
      return;
    }
    const gltf = await getGLB(entry.file);
    const hairRoot = new THREE.Group();
    hairRoot.name = `ssHair:${hairId}`;
    const meshes = [];
    gltf.scene.traverse((node) => {
      if (!node.isMesh) return;
      const mesh = node.clone();
      mesh.material = Array.isArray(node.material)
        ? node.material.map((m) => m.clone())
        : node.material.clone();
      mesh.castShadow = true;
      mesh.frustumCulled = false;
      mesh.userData.ssBaseGeometry = node.geometry;
      mesh.geometry = subdivideForPlan(node.geometry, Math.min(subdivisionLevel, 2), false);
      applyPresetToMesh(mesh, materialPreset);
      hairRoot.add(mesh);
      meshes.push(mesh);
    });
    const headPos = instance.bindPos.get(instance.headBone);
    const tipBone = instance.headBone.children.find((c) => instance.boneSet.has(c));
    const tipPos = tipBone ? instance.bindPos.get(tipBone) : null;
    const headLen = tipPos ? tipPos.distanceTo(headPos) : 0.25;
    const headDir = tipPos ? tipPos.clone().sub(headPos).normalize() : new THREE.Vector3(0, 1, 0);
    const actualCenter = headPos.clone().add(headDir.multiplyScalar(headLen * 0.5));
    const canonCenter = new THREE.Vector3(0, 1.62, -0.01);
    const canonLen = 0.25;
    const fitScale = THREE.MathUtils.clamp(headLen / canonLen, 0.7, 1.4);
    const fit = new THREE.Matrix4()
      .makeTranslation(actualCenter.x, actualCenter.y, actualCenter.z)
      .multiply(new THREE.Matrix4().makeScale(fitScale, fitScale, fitScale))
      .multiply(new THREE.Matrix4().makeTranslation(-canonCenter.x, -canonCenter.y, -canonCenter.z));
    const bindHead = new THREE.Matrix4().compose(
      instance.bindPos.get(instance.headBone).clone(),
      instance.bindQuat.get(instance.headBone).clone(),
      new THREE.Vector3(1, 1, 1),
    );
    hairRoot.matrixAutoUpdate = false;
    hairRoot.matrix.copy(bindHead.invert().multiply(fit));
    instance.headBone.add(hairRoot);
    instance.hairRoot = hairRoot;
    instance.hairMeshes = meshes;
    if (!silentState) state.hairId = hairId;
    applySkeletonVisibility();
  }

  function findCharacter(id) {
    const list = manifest ? manifest.characters : [];
    return list.find((c) => c.id === id) || null;
  }

  // D61：解析写实条目。支持三种写法：
  //   setCharacter('realistic:<id>')、manifest.characters 中 realistic:true 的 id、
  //   以及 manifest.realistic.items 中按文件名（去掉 .glb）匹配的资产。
  function resolveEntry(rawId) {
    const id = String(rawId == null ? '' : rawId);
    const list = manifest ? manifest.characters : [];
    const wanted = id.replace(/^realistic:/i, '');
    let entry = list.find((c) => c.id === id) || list.find((c) => c.id === wanted) || null;
    if (!entry && id.toLowerCase().startsWith('realistic:')) {
      entry = list.find((c) => c.id === `realistic-${wanted}`) || null;
    }
    if (entry) return entry;
    const items = manifest && manifest.realistic && Array.isArray(manifest.realistic.items)
      ? manifest.realistic.items : [];
    const item = items.find((it) => {
      const base = String(it.file || '').split('/').pop().replace(/\.glb$/i, '');
      return it.id === wanted || base === wanted;
    });
    if (!item) return null;
    return {
      id: `realistic:${wanted}`,
      name: item.name || wanted,
      gender: 'male',
      file: item.file,
      realistic: true,
      triCount: item.triCount,
      license: item.license || 'CC0-1.0',
      source: item.source || '',
    };
  }

  function mappingStats(inst = instance) {
    if (!inst) return { hit: 0, total: JOINT_NAMES.length, hitRate: 0, missing: [] };
    const missing = inst.missing.slice();
    const hit = JOINT_NAMES.length - missing.length;
    return {
      hit,
      total: JOINT_NAMES.length,
      hitRate: Number((hit / JOINT_NAMES.length).toFixed(4)),
      missing,
    };
  }

  function findOutfit(id) {
    const list = manifest ? manifest.outfits : [];
    return list.find((o) => o.id === id) || null;
  }

  function enqueue(task) {
    const run = () => task();
    queue = queue.then(run, run);
    return queue;
  }

  async function setCharacterInternal(id) {
    await getManifest();
    const entry = resolveEntry(id);
    if (!entry) fail(`未知角色：${id}`);
    state.outfitId = null;
    await swapTo(entry);
    state.characterId = entry.id;
    state.realistic = isRealisticEntry(entry);
    send('characterChanged', {
      character: entry.id,
      name: entry.name,
      gender: entry.gender,
      body: entry.body || '',
      realistic: state.realistic,
      triangles: currentTriangles(),
      missingJoints: instance.missing,
      boneMapping: manager.getJointMapping(),
      boneMappingStats: mappingStats(),
    });
  }

  async function setOutfitInternal(id) {
    await getManifest();
    const current = findCharacter(state.characterId);
    if (id == null) {
      if (!current) { fail('尚未加载角色'); return; }
      await swapTo(current);
      state.outfitId = null;
      send('outfitChanged', { outfit: null });
      return;
    }
    const entry = findOutfit(id);
    if (!entry) fail(`未知服装：${id}`);
    const gender = current ? current.gender : 'male';
    if (entry.for && entry.for !== 'compat' && entry.for !== gender) {
      fail(`服装「${entry.name}」不适用于当前${gender === 'female' ? '女性' : '男性'}角色`);
      return;
    }
    await swapTo({ ...entry, gender, body: current ? current.body : '' });
    state.outfitId = id;
    send('outfitChanged', { outfit: id, name: entry.name });
  }

  async function setHairInternal(id) {
    await getManifest();
    if (id == null || id === 'none') {
      await attachHair(null);
      send('hairChanged', { hair: null });
      return;
    }
    const entry = manifest.hair.find((h) => h.id === id);
    if (!entry) fail(`未找到发型：${id}`);
    await attachHair(id);
    send('hairChanged', { hair: id, name: entry.name });
  }

  function serializeAnim(t) {
    if (!anim) return;
    const p = Math.min(1, (t - anim.start) / Math.max(1, anim.duration));
    const e = easeInOut(p);
    for (const name of JOINT_NAMES) {
      const a = anim.from.joints[name] || [0, 0, 0];
      const b = anim.target.joints[name] || [0, 0, 0];
      pose.joints[name] = [lerp(a[0], b[0], e), lerp(a[1], b[1], e), lerp(a[2], b[2], e)];
    }
    pose.rootY = lerp(anim.from.rootY, anim.target.rootY, e);
    pose.rootPitch = lerp(anim.from.rootPitch, anim.target.rootPitch, e);
    if (p >= 1) anim = null;
  }

  const manager = {
    root,
    get markers() {
      const out = {};
      if (instance) for (const name of JOINT_NAMES) if (instance.markers[name]) out[name] = instance.markers[name];
      return out;
    },
    get joints() { return pose.joints; },
    init: (url) => enqueue(async () => {
      if (url) baseUrl = url;
      await getManifest();
      return manifest;
    }),
    listCharacters: () => (manifest ? manifest.characters.map((c) => ({
      id: c.id, name: c.name, gender: c.gender, body: c.body || '', default: !!c.default,
      realistic: !!c.realistic,
    })).concat((manifest.realistic && Array.isArray(manifest.realistic.items) ? manifest.realistic.items : [])
      .filter((it) => !manifest.characters.some((c) => c.file === it.file))
      .map((it) => ({
        id: `realistic:${String(it.file || '').split('/').pop().replace(/\.glb$/i, '')}`,
        name: it.name || String(it.file || '').split('/').pop(),
        gender: 'male',
        body: '',
        default: false,
        realistic: true,
      }))) : []),
    // D61：写实模式条目（含 manifest.realistic.items 中的资产，标记 realistic=true）。
    listRealisticCharacters: () => manager.listCharacters().filter((c) => c.realistic),
    listOutfits: () => (manifest ? manifest.outfits.map((o) => ({
      id: o.id, name: o.name, for: o.for || 'compat',
    })) : []),
    listHair: () => (manifest ? manifest.hair.map((h) => ({
      id: h.id, name: h.name, generated: !!h.generated,
    })) : []),
    getManifest: () => manifest,
    isRealistic: () => state.realistic,
    getStatus: () => ({
      ...state,
      joints: pose.joints,
      missingJoints: instance ? instance.missing : [],
      boneMapping: manager.getJointMapping(),
      boneMappingStats: mappingStats(),
      triangles: currentTriangles(),
      subdivision: subdivisionLevel,
      materialPreset,
      handSupport: manager.getHandSupport(),
      hands: manager.getHandState(),
    }),
    getJointMapping: () => {
      if (!instance) return {};
      const out = {};
      for (const name of JOINT_NAMES) out[name] = instance.mapped[name] ? instance.mapped[name].name : null;
      return out;
    },
    // QA/调试：手骨骼世界坐标（用于手部特写镜头）。
    getHandWorldPosition: (side) => {
      if (!instance) return null;
      const bone = instance.mapped[side === 'r' ? 'wrist_r' : 'wrist_l'];
      if (!bone) return null;
      const v = new THREE.Vector3();
      bone.updateWorldMatrix(true, false);
      v.setFromMatrixPosition(bone.matrixWorld);
      return { x: v.x, y: v.y, z: v.z };
    },
    // QA/调试：任意已映射关节世界坐标（材质特写镜头，V5/D89）。
    getJointWorldPosition: (name) => {
      if (!instance) return null;
      const bone = instance.mapped[String(name)];
      if (!bone) return null;
      const v = new THREE.Vector3();
      bone.updateWorldMatrix(true, false);
      v.setFromMatrixPosition(bone.matrixWorld);
      return { x: v.x, y: v.y, z: v.z };
    },
    setCharacter: (id) => enqueue(() => setCharacterInternal(id)),
    setOutfit: (id) => enqueue(() => setOutfitInternal(id)),
    setHair: (id) => enqueue(() => setHairInternal(id)),
    setSkinTone: (hex) => enqueue(async () => {
      state.skinTone = hex || null;
      applySkinTone();
      send('skinToneChanged', { skinTone: state.skinTone });
    }),
    // ---------------- V5 手部（D86–D88） ----------------
    listHandPresets: () => [
      ...Object.keys(HAND_PRESETS).map((id) => ({
        id, name: HAND_PRESETS[id].name, emoji: HAND_PRESETS[id].emoji || '', dual: false,
      })),
      ...Object.keys(HAND_DUAL_PRESETS).map((id) => ({
        id, name: HAND_DUAL_PRESETS[id].name, emoji: '🙏', dual: true,
      })),
    ],
    getHandSupport: () => (instance && instance.handSupport
      ? instance.handSupport
      : { l: { supported: false, fingers: {} }, r: { supported: false, fingers: {} } }),
    getHandState: () => ({
      l: state.hands.l || { preset: 'relax', ...HAND_PRESETS.relax },
      r: state.hands.r || { preset: 'relax', ...HAND_PRESETS.relax },
    }),
    // 应用预设（side='l'|'r'；双手组合预设会同时写入左右手）。
    setHandPose: (side, presetId) => {
      const id = String(presetId || 'relax');
      if (HAND_DUAL_PRESETS[id]) {
        const dual = HAND_DUAL_PRESETS[id];
        state.hands.l = { preset: id, ...JSON.parse(JSON.stringify(dual.hands.l)) };
        state.hands.r = { preset: id, ...JSON.parse(JSON.stringify(dual.hands.r)) };
        state.handPreset.l = id;
        state.handPreset.r = id;
      } else {
        const preset = HAND_PRESETS[id] || HAND_PRESETS.relax;
        const target = side === 'r' ? 'r' : 'l';
        state.hands[target] = { preset: id in HAND_PRESETS ? id : 'relax', ...JSON.parse(JSON.stringify(preset)) };
        state.handPreset[target] = state.hands[target].preset;
      }
      applyPose();
      send('handChanged', { hands: manager.getHandState() });
      return manager.getHandState();
    },
    // 每指微调（curls 0..1；spread 0..1；wrist [rx,ry,rz] 度，可空）。
    setHandCurls: (side, curls) => {
      const target = side === 'r' ? 'r' : 'l';
      const current = state.hands[target] || { preset: 'custom', ...HAND_PRESETS.relax };
      const next = {
        preset: 'custom',
        curls: { ...(current.curls || {}), ...(curls && curls.curls ? curls.curls : {}) },
        spread: typeof curls?.spread === 'number' ? curls.spread : (current.spread || 0),
        wrist: Array.isArray(curls?.wrist) && curls.wrist.length === 3 ? curls.wrist.slice() : (current.wrist || null),
      };
      state.hands[target] = next;
      state.handPreset[target] = 'custom';
      applyPose();
      send('handChanged', { hands: manager.getHandState() });
      return manager.getHandState();
    },
    resetHands: () => {
      state.hands.l = null;
      state.hands.r = null;
      state.handPreset.l = null;
      state.handPreset.r = null;
      applyPose();
      send('handChanged', { hands: manager.getHandState() });
      return manager.getHandState();
    },
    setJoints: (joints) => {
      if (typeof joints.rootY === 'number') pose.rootY = joints.rootY;
      if (typeof joints.rootPitch === 'number') pose.rootPitch = joints.rootPitch;
      for (const name of JOINT_NAMES) if (joints[name]) pose.joints[name] = joints[name];
      anim = null;
      applyPose();
    },
    animateTo: (joints, duration = 320) => {
      if (!duration || duration <= 0) {
        manager.setJoints(joints);
        return;
      }
      const from = {
        joints: JSON.parse(JSON.stringify(pose.joints)),
        rootY: pose.rootY,
        rootPitch: pose.rootPitch,
      };
      const target = {
        joints: JSON.parse(JSON.stringify(pose.joints)),
        rootY: pose.rootY,
        rootPitch: pose.rootPitch,
      };
      for (const name of JOINT_NAMES) if (joints[name]) target.joints[name] = joints[name];
      if (typeof joints.rootY === 'number') target.rootY = joints.rootY;
      if (typeof joints.rootPitch === 'number') target.rootPitch = joints.rootPitch;
      anim = { from, target, start: performance.now(), duration };
    },
    // D62/R18/R26：0=轻量模式（原模型）|1=默认|2=可选高密度；保留原 GLB，不删除。
    setSubdivision: (level) => enqueue(async () => {
      const next = Number(level);
      subdivisionLevel = next === 0 || next === 2 ? next : 1;
      applySubdivisionLevel();
      applyPose();
      send('subdivisionChanged', { subdivision: subdivisionLevel });
      return subdivisionLevel;
    }),
    // D63：材质预设 standard|realistic|light（默认 realistic）。
    setMaterialPreset: (name) => enqueue(async () => {
      const requested = String(name || '');
      materialPreset = MATERIAL_PRESETS.includes(requested) ? requested : DEFAULT_MATERIAL_PRESET;
      for (const inst of preparedInstances) {
        for (const mesh of inst.meshes) applyPresetToMesh(mesh, materialPreset);
        for (const mesh of inst.hairMeshes) applyPresetToMesh(mesh, materialPreset);
      }
      send('materialPresetChanged', { materialPreset });
      return materialPreset;
    }),
    // QA：逐网格细分明细（原始/迭代次数/细分后面数），用于对齐 manifest.triCount。
    qaMeshInfo: () => {
      if (!instance) return [];
      const skinned = instance.meshes.filter((m) => m.isSkinnedMesh && instance.baseGeometries.has(m));
      return skinned.map((mesh, i) => ({
        name: mesh.name,
        base: triangleCount(instance.baseGeometries.get(mesh)),
        iterations: instance.triPlan ? instance.triPlan[i] : null,
        applied: triangleCount(mesh.geometry),
      }));
    },
    // QA：采样顶点的蒙皮变形量（>0 说明细分后仍随骨骼变形）。
    qaSkinningProbe: () => {
      if (!instance) return { meshes: 0, sampled: 0, maxDeform: 0 };
      const rest = new THREE.Vector3();
      const posed = new THREE.Vector3();
      const size = new THREE.Vector3();
      let meshes = 0;
      let sampled = 0;
      let maxDeform = 0;
      let maxDeformNorm = 0;
      for (const mesh of instance.meshes) {
        if (!mesh.isSkinnedMesh || !mesh.geometry) continue;
        meshes += 1;
        if (!mesh.geometry.boundingBox) mesh.geometry.computeBoundingBox();
        const diagonal = mesh.geometry.boundingBox
          ? mesh.geometry.boundingBox.getSize(size).length()
          : 0;
        const count = mesh.geometry.attributes.position.count;
        const step = Math.max(1, Math.floor(count / 160));
        for (let i = 0; i < count; i += step) {
          rest.fromBufferAttribute(mesh.geometry.attributes.position, i);
          posed.copy(rest);
          if (typeof mesh.applyBoneTransform === 'function') mesh.applyBoneTransform(i, posed);
          else if (typeof mesh.boneTransform === 'function') mesh.boneTransform(i, posed);
          else continue;
          const delta = posed.distanceTo(rest);
          if (delta > maxDeform) maxDeform = delta;
          if (diagonal > 0 && delta / diagonal > maxDeformNorm) maxDeformNorm = delta / diagonal;
          sampled += 1;
        }
      }
      return {
        meshes,
        sampled,
        maxDeform: Number(maxDeform.toFixed(5)),
        maxDeformNorm: Number(maxDeformNorm.toFixed(4)),
      };
    },
    setJointMode: (on) => {
      if (!instance) return;
      instance.jointMode = !!on;
      applySkeletonVisibility();
    },
    setSkeletonMode: (on) => {
      if (!instance) return;
      instance.skeletonMode = !!on;
      applySkeletonVisibility();
    },
    setGender: (gender) => enqueue(async () => {
      const list = await getManifest();
      const target = gender === 'female' ? 'female' : 'male';
      const current = findCharacter(state.characterId);
      if (current && current.gender === target) return;
      const entry = list.characters.find((c) => c.gender === target);
      if (!entry) fail(`没有可用的${target === 'female' ? '女性' : '男性'}模型`);
      const keepOutfit = state.outfitId;
      await setCharacterInternal(entry.id);
      if (keepOutfit) {
        const outfit = findOutfit(keepOutfit);
        if (outfit && (outfit.for === 'compat' || outfit.for === target)) await setOutfitInternal(keepOutfit);
      }
    }),
    playAnimation: (name) => {
      if (!instance || !instance.mixer) return false;
      const clip = instance.animations.find((a) => a.name === name) || instance.animations[0];
      if (!clip) return false;
      instance.mixer.stopAllAction();
      instance.mixer.clipAction(clip).play();
      return true;
    },
    tick: () => {
      if (anim) { serializeAnim(performance.now()); applyPose(); }
      if (instance && instance.mixer) instance.mixer.update(0.016);
    },
    dispose: () => {
      anim = null;
      instance = null;
      glbCache.clear();
      instanceCache.clear();
      preparedInstances.clear();
    },
  };

  return manager;
}
