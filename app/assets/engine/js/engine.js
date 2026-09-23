// ShootStudio 3D 引擎主入口：白棚 + 人体假人 + 灯光/道具 + 双向桥接。
// 领域语义改编自 direct-light（MIT，Copyright (c) 2026 Keming Ou），
// 由 React/R3F 重写为无框架 three.js 单页；人像模型为自研关节假人。
import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { RectAreaLightUniformsLib } from 'three/addons/lights/RectAreaLightUniformsLib.js';
import { HDRLoader } from 'three/addons/loaders/HDRLoader.js';

import { buildStudio } from './studio.js';
import { buildPerson, JOINT_NAMES } from './person.js';
import { createCharacterManager } from './character.js';
import {
  createLight,
  updateLight,
  setLightSelected,
  setShadowMapSize,
  setLightCones,
  getLightCones,
} from './lights.js';
import { buildCameraRig, applyAim, focalToFov } from './rig.js';
import { buildProp, placeProp, applyPropTexture } from './props.js';
import { nowMs, clamp } from './util.js';

const $ = (id) => document.getElementById(id);
const boot = (text, isError = false) => {
  const el = $('boot');
  if (!el) return;
  if (!text) { el.style.display = 'none'; return; }
  el.textContent = text;
  el.style.display = 'flex';
  el.classList.toggle('error', isError);
};

function send(type, payload = {}) {
  const msg = JSON.stringify({ type, ...payload });
  try {
    if (window.flutter_inappwebview?.callHandler) {
      window.flutter_inappwebview.callHandler('ssBridge', msg);
      return;
    }
  } catch (e) { /* 桥不可用时静默，改用 outbox（浏览器调试） */ }
  (window.__ssOutbox = window.__ssOutbox || []).push(msg);
}

// V6/R43：JS 未捕获错误 / 未处理 Promise 全量上报（非致命，Flutter 侧仅提示不降级）。
window.addEventListener('error', (e) => {
  try {
    send('error', {
      message: `JS 错误：${e.message || e.error || 'unknown'} @ ${e.filename || ''}:${e.lineno || 0}`,
      fatal: false,
      source: 'js',
    });
  } catch (_) { /* 上报失败静默 */ }
});
window.addEventListener('unhandledrejection', (e) => {
  try {
    const reason = e.reason && (e.reason.message || e.reason);
    send('error', { message: `未处理的 Promise 拒绝：${reason}`, fatal: false, source: 'promise' });
  } catch (_) { /* 上报失败静默 */ }
});

// 心跳与内存采样：Flutter 侧以此判定渲染是否存活并触发自动重载（D102）。
let frameCount = 0;
let lastFps = 0;
let framesSinceHeartbeat = 0;
let lastHeartbeatAt = 0;
function perfMemory() {
  const m = performance && performance.memory;
  if (!m) return null;
  return {
    usedMB: Number((m.usedJSHeapSize / 1048576).toFixed(1)),
    totalMB: Number((m.totalJSHeapSize / 1048576).toFixed(1)),
    limitMB: Number((m.jsHeapSizeLimit / 1048576).toFixed(1)),
  };
}
function heartbeatPayload() {
  return {
    frames: frameCount,
    fps: lastFps,
    paused,
    memory: perfMemory(),
  };
}

// ---------------- 基础场景 ----------------
const canvas = $('stage');
const renderer = new THREE.WebGLRenderer({
  canvas, antialias: true, preserveDrawingBuffer: true, alpha: false,
});
renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
renderer.shadowMap.enabled = true;
// V7/D137：r186 移除了 PCFSoftShadowMap；软阴影改用 VSM（支持 shadow.radius），
// 低配档/关闭软阴影时回退 PCF。
renderer.shadowMap.type = THREE.VSMShadowMap;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.06;
renderer.outputColorSpace = THREE.SRGBColorSpace;

const scene = new THREE.Scene();
scene.background = new THREE.Color(0xeef1f5);

// V5：环境反射统一由 studio.buildStudio 创建（RoomEnvironment→PMREM），此处仅设初值。
let environmentIntensity = 0.55;
let ambientEnabled = true;
scene.environmentIntensity = environmentIntensity;

const camera = new THREE.PerspectiveCamera(42, 1, 0.05, 80);
camera.position.set(2.4, 2.0, 3.6);

const controls = new OrbitControls(camera, renderer.domElement);
controls.enableDamping = true;
controls.dampingFactor = 0.08;
controls.target.set(0, 1.05, 0);
controls.minDistance = 1.2;
controls.maxDistance = 14;
controls.maxPolarAngle = Math.PI * 0.495;

RectAreaLightUniformsLib.init(); // G4：面板灯 LTC 初始化（此前面光不可用）
const studio = buildStudio(scene, renderer, { width: 6, depth: 8, height: 3.2 });

// V6/D105：摄影师机位（三脚架 + 相机），可一键切 POV。
const cameraRig = buildCameraRig();
scene.add(cameraRig);
const cameraRigState = {
  x: 0, y: 3.2, height: 1.35, yaw: 0, pitch: 0, focal: 50, enabled: true,
};
let cameraPov = false;
function applyCameraRig() {
  cameraRig.visible = cameraRigState.enabled !== false;
  const px = Number(cameraRigState.x) || 0;
  const py = Number(cameraRigState.y) || 0;
  const height = Math.max(0.4, Number(cameraRigState.height) || 1.35);
  cameraRig.position.set(px, 0, -py);
  const head = cameraRig.userData.head;
  if (head) {
    head.position.y = height;
    applyAim(head, { x: px, y: height, z: -py }, new THREE.Vector3(0, 1.2, 0), {
      offsetYaw: Number(cameraRigState.yaw) || 0,
      offsetPitch: Number(cameraRigState.pitch) || 0,
    });
    if (cameraPov) applyCameraPov();
  }
}
function applyCameraPov() {
  const head = cameraRig.userData.head;
  if (!head) return;
  head.updateWorldMatrix(true, false);
  const pos = new THREE.Vector3();
  head.getWorldPosition(pos);
  const quat = new THREE.Quaternion();
  head.getWorldQuaternion(quat);
  // 相机沿 -Z 观察；灯位模型沿 +Z，补 180°。
  quat.multiply(new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0, 1, 0), Math.PI));
  camera.position.copy(pos);
  camera.quaternion.copy(quat);
  camera.fov = focalToFov(cameraRigState.focal);
  camera.updateProjectionMatrix();
}
function setCameraPov(on) {
  cameraPov = !!on;
  if (cameraPov) {
    applyCameraRig();
    applyCameraPov();
    controls.enabled = false;
  } else {
    controls.enabled = true;
    camera.fov = 42;
    camera.updateProjectionMatrix();
    setView('default');
  }
  return cameraPov;
}
applyCameraRig();

// V5/D85：环境光开关（半球光 + 环境贴图贡献，含金属反射）。
function applyAmbient() {
  scene.environmentIntensity = ambientEnabled ? environmentIntensity : 0;
  if (studio && typeof studio.setAmbientEnabled === 'function') {
    studio.setAmbientEnabled(ambientEnabled);
  }
}
applyAmbient();

// V5/D90：影棚 HDRI（Poly Haven CC0 1K）→ PMREM 环境反射；失败回退 studio 的 RoomEnvironment。
// V7/D138：同时保留原始等距柱状 HDR 纹理——路径追踪器无法消费 PMREM（CubeUV）纹理。
let environmentSource = 'room'; // room | hdr
let studioEquirectEnv = null;
let envPmrem = new THREE.PMREMGenerator(renderer);
function finishEnvironment(source) {
  environmentSource = source;
  applyAmbient();
  send('environmentChanged', { source });
}
function loadStudioEnvironment() {
  new HDRLoader().load(
    new URL('env/studio_small_03_1k.hdr', document.baseURI).href,
    (hdr) => {
      let source = 'room';
      try {
        const rt = envPmrem.fromEquirectangular(hdr);
        const previous = studio.envTexture;
        scene.environment = rt.texture;
        if (previous && previous !== rt.texture && typeof previous.dispose === 'function') {
          previous.dispose();
        }
        // 保留原始 HDR（不 dispose）：路径追踪静帧需要等距柱状数据（D138）。
        studioEquirectEnv = hdr;
        source = 'hdr';
      } catch (_) {
        source = 'room';
      } finally {
        if (source !== 'hdr' && typeof hdr.dispose === 'function') hdr.dispose();
        envPmrem.dispose();
        envPmrem = null;
      }
      finishEnvironment(source);
    },
    undefined,
    () => {
      if (envPmrem) {
        envPmrem.dispose();
        envPmrem = null;
      }
      finishEnvironment('room');
    },
  );
}
loadStudioEnvironment();

// V5/D91：接触阴影（脚下柔和接地，程序化径向渐变；仅 realistic 预设 + 开关，R38）。
function createContactShadowTexture() {
  const size = 256;
  const canvas = document.createElement('canvas');
  canvas.width = size;
  canvas.height = size;
  const ctx = canvas.getContext('2d');
  const gradient = ctx.createRadialGradient(
    size / 2, size / 2, size * 0.02,
    size / 2, size / 2, size / 2,
  );
  gradient.addColorStop(0, 'rgba(0,0,0,0.55)');
  gradient.addColorStop(0.45, 'rgba(0,0,0,0.24)');
  gradient.addColorStop(0.75, 'rgba(0,0,0,0.07)');
  gradient.addColorStop(1, 'rgba(0,0,0,0)');
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, size, size);
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  return texture;
}
const contactShadow = new THREE.Mesh(
  new THREE.PlaneGeometry(1, 1),
  new THREE.MeshBasicMaterial({
    map: createContactShadowTexture(),
    transparent: true,
    depthWrite: false,
    opacity: 0.9,
  }),
);
contactShadow.rotation.x = -Math.PI / 2;
contactShadow.position.y = 0.004;
contactShadow.renderOrder = 1;
contactShadow.visible = false;
scene.add(contactShadow);
let contactShadowEnabled = true;
let contactShadowSupported = false; // 仅 realistic 预设显示（standard/light 与 V4 一致）。
let contactShadowClock = 1;

function applyContactShadow() {
  // V6/D104：性能优先档关闭接触阴影（R52 可退回）。
  const visible = contactShadowEnabled && contactShadowSupported && effectiveProfile() !== 'low';
  contactShadow.visible = visible;
  if (visible) contactShadowClock = 1;
}

function updateContactShadowTransform() {
  const bounds = computeSubjectBounds();
  if (!bounds) return;
  const width = Math.max(0.24, bounds.maxX - bounds.minX);
  const depth = Math.max(0.24, bounds.maxZ - bounds.minZ);
  contactShadow.position.set(
    (bounds.minX + bounds.maxX) / 2,
    0.004,
    (bounds.minZ + bounds.maxZ) / 2,
  );
  contactShadow.scale.set(width * 1.6, depth * 1.5, 1);
}

function syncContactShadowPreset() {
  contactShadowSupported = character.getStatus().materialPreset === 'realistic';
  applyContactShadow();
}

// V6/D104：性能档（auto | high | low）——低配自动/手动降档，可随时切回。
let performanceProfile = 'auto';
let shadowMapSize = 2048;
let maxPixelRatio = 2;
let desiredSubdivision = 1;
// V7/D137：软阴影（VSM）开关；低配档强制 PCF。
let softShadows = true;
// V7/D135：GPU 渲染器字符串（供设置页校验独显/软渲切换是否生效）。
let gpuRendererName = '';

function detectPerformanceProfile() {
  try {
    const gl = renderer.getContext();
    const info = gl.getExtension('WEBGL_debug_renderer_info');
    const name = info ? String(gl.getParameter(info.UNMASKED_RENDERER_WEBGL) || '') : '';
    gpuRendererName = name;
    if (/swiftshader|software|basic render/i.test(name)) return 'low';
    const mem = Number(navigator.deviceMemory || 0);
    if (mem > 0 && mem <= 4) return 'low';
  } catch (_) { /* 探测失败按 high */ }
  return 'high';
}

function effectiveProfile() {
  return performanceProfile === 'auto' ? detectPerformanceProfile() : performanceProfile;
}

// V7/D137：阴影类型切换（VSM 支持 radius 软阴影；低配/关闭时 PCF）。
function applyShadowType() {
  const wantVsm = softShadows && effectiveProfile() !== 'low';
  const type = wantVsm ? THREE.VSMShadowMap : THREE.PCFShadowMap;
  if (renderer.shadowMap.type === type) return;
  renderer.shadowMap.type = type;
  renderer.shadowMap.needsUpdate = true;
  scene.traverse((obj) => {
    if (!obj.material) return;
    const mats = Array.isArray(obj.material) ? obj.material : [obj.material];
    for (const m of mats) m.needsUpdate = true;
  });
}

function applyPerformanceProfile() {
  const profile = effectiveProfile();
  const low = profile === 'low';
  shadowMapSize = low ? 1024 : 2048;
  maxPixelRatio = low ? 1 : 2;
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, maxPixelRatio));
  setShadowMapSize(shadowMapSize);
  applyContactShadow();
  applyShadowType();
  const subdivision = low ? Math.min(desiredSubdivision, 1) : desiredSubdivision;
  Promise.resolve(character.setSubdivision(subdivision)).catch(() => {});
  for (const obj of lightObjs.values()) {
    const spot = obj.getObjectByName?.('spot');
    if (spot && spot.shadow) {
      spot.shadow.mapSize.set(shadowMapSize, shadowMapSize);
      if (spot.shadow.map) {
        spot.shadow.map.dispose();
        spot.shadow.map = null;
      }
    }
  }
  for (const cfg of sceneState.lights || []) {
    const obj = lightObjs.get(cfg.id);
    if (obj) updateLight(obj, cfg);
  }
}

const person = buildPerson({ height: 1.7 });
scene.add(person.root);
person.root.visible = false; // 轻量假人仅在显式 legacy 模式显示（R15）
const character = createCharacterManager({ send });
scene.add(character.root);
character.root.visible = true;

// ---------------- 场景状态 ----------------
let sceneState = { lights: [], props: [], subject: { rotationY: 0 } };
let linkage = true;
let subjectMode = 'character'; // 'character'（GLB 骨骼）| 'legacy'（显式轻量假人）
const lightObjs = new Map();
const propObjs = new Map();
applyPerformanceProfile(); // 初始化性能档（自动探测或默认 high）
let selected = null; // { kind:'light'|'prop'|'joint', id }
let jointMode = false;

function activeSubject() {
  return subjectMode === 'legacy' ? person : character;
}

function setSubjectMode(mode) {
  subjectMode = mode === 'legacy' ? 'legacy' : 'character';
  person.root.visible = subjectMode === 'legacy';
  character.root.visible = subjectMode === 'character';
}

let characterRequested = false;

async function useCharacter(id) {
  characterRequested = true;
  if (id === 'legacy') {
    setSubjectMode('legacy');
    boot(null);
    send('characterChanged', { character: 'legacy', name: '轻量假人', gender: person.gender() });
    return true;
  }
  try {
    await character.setCharacter(id);
    setSubjectMode('character');
    syncContactShadowPreset();
    boot(null);
    return true;
  } catch (err) {
    const message = String(err?.message || err);
    if (character.getStatus().error !== message) {
      send('error', { message, fatal: false, source: 'character' });
    }
    // 保留 3D 场景可用（灯位/道具照常渲染）；错误由 UI 以提示呈现，不遮挡舞台。
    boot(null);
    return false;
  }
}

function applyScene(json) {
  const data = typeof json === 'string' ? JSON.parse(json) : json;
  sceneState = { ...sceneState, ...data };

  // V6/D105：机位随场景同步。
  if (data.camera) {
    Object.assign(cameraRigState, data.camera);
    applyCameraRig();
  }

  // 被摄体：GLB 角色优先；未知字段忽略（保持向后兼容）。
  const subject = data.subject || {};
  if (subject.character) useCharacter(String(subject.character));
  const active = subjectMode === 'legacy' ? person : character;
  if (subject.height) active.root.scale.setScalar(subject.height / 1.7);
  active.root.rotation.y = (subject.rotationY || 0) * Math.PI / 180;
  if (subject.gender) Promise.resolve(active.setGender(subject.gender)).catch(() => {});
  if (typeof subject.skeleton === 'boolean') active.setSkeletonMode(subject.skeleton);
  if (subject.pose?.joints) active.animateTo(subject.pose.joints, subject.pose.duration ?? 280);
  // V5/D88：手部随场景/姿势注入（{l:{curls,spread,wrist,preset}, r:{...}}）。
  if (subject.hands && subjectMode !== 'legacy') {
    for (const side of ['l', 'r']) {
      const h = subject.hands[side];
      if (!h) continue;
      if (h.preset && typeof h.preset === 'string' && h.preset !== 'custom') {
        character.setHandPose(side, h.preset);
        if (h.curls || typeof h.spread === 'number' || h.wrist) {
          character.setHandCurls(side, h);
        }
      } else {
        character.setHandCurls(side, h);
      }
    }
  }
  if (subject.outfit !== undefined) character.setOutfit(subject.outfit).catch(() => {});
  if (subject.hair !== undefined) character.setHair(subject.hair).catch(() => {});
  if (subject.skinTone) character.setSkinTone(subject.skinTone).catch(() => {});

  // 灯光增删改。
  const seenLights = new Set();
  for (const cfg of data.lights || []) {
    seenLights.add(cfg.id);
    let obj = lightObjs.get(cfg.id);
    if (!obj) {
      obj = createLight(cfg);
      scene.add(obj);
      lightObjs.set(cfg.id, obj);
    }
    updateLight(obj, cfg);
  }
  for (const [id, obj] of [...lightObjs]) {
    if (!seenLights.has(id)) {
      scene.remove(obj);
      obj.traverse?.((n) => { if (n.geometry) n.geometry.dispose(); });
      lightObjs.delete(id);
    }
  }

  // 影棚尺寸。
  if (data.studio) studio.setGridVisible(false);

  // 道具增删改。
  const seenProps = new Set();
  for (const cfg of data.props || []) {
    seenProps.add(cfg.id);
    let obj = propObjs.get(cfg.id);
    if (!obj || obj.userData.propType !== cfg.type) {
      if (obj) { scene.remove(obj); propObjs.delete(cfg.id); }
      obj = buildProp(cfg.type);
      obj.userData.propType = cfg.type;
      obj.userData.kind = 'prop';
      obj.userData.propId = cfg.id;
      scene.add(obj);
      propObjs.set(cfg.id, obj);
      if (cfg.texture) applyPropTexture(obj, cfg.texture);
    }
    placeProp(obj, cfg);
  }
  for (const [id, obj] of [...propObjs]) {
    if (!seenProps.has(id)) {
      scene.remove(obj);
      propObjs.delete(id);
    }
  }

  // 阴影预算：最亮的三盏（含面板灯阴影代理）投影。
  const casters = (data.lights || [])
    .filter((l) => l.on !== false)
    .sort((a, b) => (b.intensity || 0) - (a.intensity || 0))
    .slice(0, 3)
    .map((l) => l.id);
  for (const [id, obj] of lightObjs) {
    obj.userData.castShadow = casters.includes(id);
    const cfg = (data.lights || []).find((l) => l.id === id);
    if (cfg) updateLight(obj, cfg);
  }

  refreshSelection();
}

function refreshSelection() {
  for (const [id, obj] of lightObjs) setLightSelected(obj, selected?.kind === 'light' && selected.id === id);
}

function computeSubjectBounds() {
  const target = activeSubject().root;
  target.updateMatrixWorld(true);
  const box = new THREE.Box3();
  const tmp = new THREE.Box3();
  target.traverse((o) => {
    if (!o.visible) return;
    if (o.isSkinnedMesh) {
      if (typeof o.computeBoundingBox === 'function') o.computeBoundingBox();
      const bb = o.boundingBox || o.geometry?.boundingBox;
      if (bb && !bb.isEmpty()) { tmp.copy(bb).applyMatrix4(o.matrixWorld); box.union(tmp); }
    } else if (o.isMesh && o.geometry) {
      if (!o.geometry.boundingBox) o.geometry.computeBoundingBox();
      if (o.geometry.boundingBox && !o.geometry.boundingBox.isEmpty()) {
        tmp.copy(o.geometry.boundingBox).applyMatrix4(o.matrixWorld);
        box.union(tmp);
      }
    }
  });
  if (box.isEmpty()) return null;
  return {
    minY: Number(box.min.y.toFixed(4)),
    maxY: Number(box.max.y.toFixed(4)),
    minX: Number(box.min.x.toFixed(4)),
    maxX: Number(box.max.x.toFixed(4)),
    minZ: Number(box.min.z.toFixed(4)),
    maxZ: Number(box.max.z.toFixed(4)),
  };
}

person.setMarkerMode(jointMode);
character.setJointMode(jointMode);

// ---------------- 交互 ----------------
const raycaster = new THREE.Raycaster();
const pointer = new THREE.Vector2();
const groundPlane = new THREE.Plane(new THREE.Vector3(0, 1, 0), 0);
let drag = null; // { kind, id, obj, startPos, offset }
let lastSend = 0;

function setPointer(e) {
  const rect = renderer.domElement.getBoundingClientRect();
  pointer.x = ((e.clientX - rect.left) / rect.width) * 2 - 1;
  pointer.y = -((e.clientY - rect.top) / rect.height) * 2 + 1;
}

function pickObject() {
  raycaster.setFromCamera(pointer, camera);
  const targets = [];
  if (jointMode) {
    const markers = activeSubject().markers || {};
    for (const name of JOINT_NAMES) if (markers[name]) targets.push(markers[name]);
  }
  for (const obj of lightObjs.values()) targets.push(obj);
  for (const obj of propObjs.values()) targets.push(obj);
  const hits = raycaster.intersectObjects(targets, true);
  if (!hits.length) return null;
  const hitHead = (() => {
    let o = hits[0].object;
    while (o) {
      if (o.name === 'head') return true;
      o = o.parent;
    }
    return false;
  })();
  let obj = hits[0].object;
  while (obj) {
    if (obj.userData?.joint) return { kind: 'joint', id: obj.userData.joint, obj };
    if (obj.userData?.lightId !== undefined && obj.userData?.kind === 'light') {
      const part = hitHead ? 'head' : 'body';
      return { kind: 'light', id: obj.userData.lightId, obj, part };
    }
    if (obj.userData?.kind === 'prop') return { kind: 'prop', id: obj.userData.propId, obj };
    obj = obj.parent;
  }
  return null;
}

function groundPoint() {
  raycaster.setFromCamera(pointer, camera);
  const p = new THREE.Vector3();
  return raycaster.ray.intersectPlane(groundPlane, p) ? p : null;
}

renderer.domElement.addEventListener('pointerdown', (e) => {
  if (e.button !== 0) return;
  setPointer(e);
  const hit = pickObject();
  if (!hit) {
    selected = null;
    refreshSelection();
    send('selection', { kind: null });
    return;
  }
  selected = { kind: hit.kind, id: hit.id };
  refreshSelection();
  send('selection', { kind: hit.kind, id: hit.id });

  if (hit.kind === 'joint') {
    send('jointClicked', { joint: hit.id });
    return;
  }
  const obj = hit.kind === 'light' ? lightObjs.get(hit.id) : propObjs.get(hit.id);
  if (!obj) return;
  if (hit.kind === 'light' && hit.part === 'head') {
    const cfg = (sceneState.lights || []).find((l) => l.id === hit.id) || {};
    controls.enabled = false;
    drag = {
      kind: 'lightHead',
      id: hit.id,
      startX: e.clientX,
      startRotation: cfg.rotationY || 0,
    };
    return;
  }
  const p = groundPoint();
  if (!p) return;
  controls.enabled = false;
  drag = {
    kind: hit.kind,
    id: hit.id,
    offset: new THREE.Vector2(obj.position.x - p.x, obj.position.z - p.z),
  };
});

renderer.domElement.addEventListener('pointermove', (e) => {
  if (!drag) return;
  if (drag.kind === 'lightHead') {
    const cfg = (sceneState.lights || []).find((l) => l.id === drag.id);
    const obj = lightObjs.get(drag.id);
    if (cfg && obj) {
      cfg.rotationY = Math.round(
        (drag.startRotation + (e.clientX - drag.startX) * 0.8 + 720) % 360,
      );
      updateLight(obj, cfg);
      if (linkage && nowMs() - lastSend > 90) {
        lastSend = nowMs();
        send('sceneChanged', {
          lights: (sceneState.lights || []).map((l) => ({
            id: l.id,
            x: l.x,
            y: l.y,
            rotationY: l.rotationY || 0,
          })),
        });
      }
    }
    return;
  }
  setPointer(e);
  const p = groundPoint();
  if (!p) return;
  const obj = drag.kind === 'light' ? lightObjs.get(drag.id) : propObjs.get(drag.id);
  if (!obj) return;
  obj.position.x = p.x + drag.offset.x;
  obj.position.z = p.z + drag.offset.y;
  // 3D → Flutter 同步（联动开启时）。
  if (linkage && nowMs() - lastSend > 110) {
    lastSend = nowMs();
    if (drag.kind === 'light') {
      const cfg = (sceneState.lights || []).find((l) => l.id === drag.id);
      if (cfg) {
        cfg.x = Number(obj.position.x.toFixed(3));
        cfg.y = Number((-obj.position.z).toFixed(3));
        updateLight(obj, cfg);
      }
      send('sceneChanged', {
        lights: (sceneState.lights || []).map((l) => ({
          id: l.id,
          x: l.x,
          y: l.y,
          rotationY: l.rotationY || 0,
        })),
      });
    } else {
      const cfg = (sceneState.props || []).find((p2) => p2.id === drag.id);
      if (cfg) {
        cfg.x = Number(obj.position.x.toFixed(3));
        cfg.y = Number((-obj.position.z).toFixed(3));
      }
      send('sceneChanged', {
        props: (sceneState.props || []).map((p2) => ({ id: p2.id, x: p2.x, y: p2.y })),
      });
    }
  }
});

function endDrag() {
  if (!drag) return;
  if (linkage) send('dragEnded', { kind: drag.kind, id: drag.id });
  drag = null;
  controls.enabled = true;
}
renderer.domElement.addEventListener('pointerup', endDrag);
renderer.domElement.addEventListener('pointerleave', endDrag);

// ---------------- 视图模式 ----------------
function setView(mode) {
  const t = new THREE.Vector3(0, 1.05, 0);
  controls.enabled = true;
  switch (mode) {
    case 'front':
      camera.position.set(0, 1.35, 3.7);
      t.set(0, 1.1, 0);
      controls.enabled = false;
      break;
    case 'side':
      camera.position.set(3.7, 1.35, 0);
      t.set(0, 1.1, 0);
      controls.enabled = false;
      break;
    case 'top':
      camera.position.set(0, 5.6, 0.02);
      t.set(0, 0, 0);
      controls.enabled = false;
      break;
    default:
      camera.position.set(2.4, 2.0, 3.6);
  }
  controls.target.copy(t);
  controls.update();
}

// ---------------- 主题 ----------------
function setTheme(mode) {
  const dark = mode === 'dark';
  scene.background = new THREE.Color(dark ? 0x11151d : 0xeef1f5);
  renderer.toneMappingExposure = dark ? 1.12 : 1.06;
}

// QA 特写：临时放宽 OrbitControls 最近距离（每帧 update 会按 minDistance 钳制）。
function qaAllowDistance(distance) {
  const d = Math.max(0.05, Number(distance) || 0.5);
  if (d < controls.minDistance) controls.minDistance = d;
  return d;
}

// ---------------- V7/D138：照片级静帧（路径追踪 / 超采样） ----------------
// three-gpu-pathtracer 以独立 classic 脚本按需加载（file:// 兼容；约 220KB 不进首屏）；
// pathtracer 通过全局 shim 复用引擎同一份 three（见 tool/engine_build/pathtracer_build.mjs）。
window.__ssThree = THREE;

const pathTracerModule = { loaded: false, loading: null, error: '' };
function loadPathTracerBundle() {
  if (pathTracerModule.loaded) return Promise.resolve(true);
  if (pathTracerModule.loading) return pathTracerModule.loading;
  pathTracerModule.loading = new Promise((resolve) => {
    const script = document.createElement('script');
    script.src = new URL('js/pathtracer.bundle.js', document.baseURI).href;
    script.onload = () => {
      pathTracerModule.loaded = !!(window.SSPathTracer && window.SSPathTracer.WebGLPathTracer);
      if (!pathTracerModule.loaded) pathTracerModule.error = '路径追踪器缺少 WebGLPathTracer';
      resolve(pathTracerModule.loaded);
    };
    script.onerror = () => {
      pathTracerModule.error = '路径追踪器脚本加载失败';
      resolve(false);
    };
    document.head.appendChild(script);
  });
  return pathTracerModule.loading;
}

let pathTracer = null;
let pathTracerWarmDone = false;
let pathTracerWarmRun = null;
function ensurePathTracer() {
  if (pathTracer) return pathTracer;
  const PT = window.SSPathTracer;
  if (!PT || !PT.WebGLPathTracer) throw new Error('路径追踪器未加载');
  const pt = new PT.WebGLPathTracer(renderer);
  pt.renderScale = 1;
  pt.minSamples = 1;
  pt.renderDelay = 0;
  pt.fadeDuration = 0;
  pt.dynamicLowRes = false;
  pt.rasterizeScene = true;
  pt.bounces = 4;
  pathTracer = pt;
  return pt;
}

// 静帧渲染任务（必须由主循环驱动：compileAsync 是异步的，同步循环会让 Promise 永不结算）。
let stillRun = null;
let stillSeq = 0;

function snapshotRendererSize() {
  return { pixelRatio: renderer.getPixelRatio() };
}
function restoreRendererSize() {
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, maxPixelRatio));
  resize();
}
function snapshotCameraState() {
  return {
    pov: cameraPov,
    pos: camera.position.clone(),
    quat: camera.quaternion.clone(),
    fov: camera.fov,
    target: controls.target.clone(),
    controlsEnabled: controls.enabled,
  };
}
function restoreCameraState(state) {
  cameraPov = state.pov;
  camera.position.copy(state.pos);
  camera.quaternion.copy(state.quat);
  camera.fov = state.fov;
  camera.updateProjectionMatrix();
  controls.target.copy(state.target);
  controls.enabled = state.controlsEnabled;
  controls.update();
}
// 静帧不包含编辑辅助对象（接触阴影贴片/网格/光锥/选中环），出图干净且避免黑方块。
function hideStillHelpers() {
  const hidden = [];
  const remember = (obj) => {
    if (obj && obj.visible) {
      hidden.push(obj);
      obj.visible = false;
    }
  };
  remember(contactShadow);
  scene.traverse((o) => { if (o.isGridHelper) remember(o); });
  for (const obj of lightObjs.values()) {
    remember(obj.getObjectByName?.('lightCone'));
    remember(obj.userData?.ring);
  }
  return hidden;
}
function restoreStillHelpers(hidden) {
  for (const obj of hidden) obj.visible = true;
}

// V7/D139：相机辅助 —— 主体对焦距离 + 景深物理相机（路径追踪专用）+ 焦段/视野信息。
const FOCUS_HEIGHT = 1.35; // 对焦参考高度（人像取景以面部/胸口为中心）
function subjectFocusPoint(target = new THREE.Vector3()) {
  const root = activeSubject()?.root;
  if (root) {
    root.updateWorldMatrix(true, false);
    root.getWorldPosition(target);
  } else {
    target.set(0, 0, 0);
  }
  target.y += FOCUS_HEIGHT;
  return target;
}
function subjectFocusDistance() {
  camera.updateWorldMatrix(true, false);
  return camera.position.distanceTo(subjectFocusPoint());
}
let dofCamera = null;
function ensureDofCamera() {
  const PT = window.SSPathTracer;
  if (!PT || !PT.PhysicalCamera) return null;
  if (!dofCamera) dofCamera = new PT.PhysicalCamera();
  return dofCamera;
}
// 物理相机与场景相机同步位置/朝向/投影，仅额外携带 fStop 与对焦距离（路径追踪景深）。
// 关键：**始终**用 PhysicalCamera 渲染路径静帧（即使不开景深），让材质 FEATURE_DOF 定义恒为 1，
// 避免「非景深 ↔ 景深」切换触发 r186 的材质重编译死锁（compileAsync 轮询 isReady 与
// PathTracingRenderer.isCompiling 互等 → samples 永远 0）。无景深时用极大 f 值把散景压到亚毫米。
const NO_DOF_FSTOP = 1000;
function syncDofCamera(spec) {
  const pc = ensureDofCamera();
  if (!pc) return null;
  camera.updateWorldMatrix(true, false);
  pc.position.copy(camera.position);
  pc.quaternion.copy(camera.quaternion);
  pc.fov = camera.fov;
  pc.aspect = camera.aspect;
  pc.near = camera.near;
  pc.far = camera.far;
  pc.filmGauge = 36; // 全画幅 36×24，与 rig.js focalToFov 的 24mm 传感器高一致
  const dof = (spec && spec.dof) || {};
  const dofOn = dof.enabled === true;
  pc.fStop = dofOn ? clamp(Number(dof.fStop) || 2.8, 1, 22) : NO_DOF_FSTOP;
  pc.focusDistance = dofOn && dof.focusMode === 'manual'
    ? clamp(Number(dof.focusDistance) || 2, 0.3, 30)
    : clamp(subjectFocusDistance(), 0.3, 30);
  pc.updateProjectionMatrix();
  pc.updateMatrixWorld(true);
  return pc;
}
// 焦段/视野辅助信息（Flutter 侧「机位」面板与构图辅助使用）。
function getCameraAssist() {
  const focal = clamp(Number(cameraRigState.focal) || 50, 14, 200);
  const vFov = focalToFov(focal);
  const aspect = camera.aspect || 1.5;
  const hFov = 2 * Math.atan(Math.tan((vFov * Math.PI / 180) / 2) * aspect) * 180 / Math.PI;
  const distance = subjectFocusDistance();
  const frameHeight = 2 * distance * Math.tan((vFov * Math.PI / 180) / 2);
  return {
    focal,
    fovDeg: Number(vFov.toFixed(2)),
    fovDegHorizontal: Number(hFov.toFixed(2)),
    aspect: Number(aspect.toFixed(4)),
    subjectDistance: Number(distance.toFixed(2)),
    frameHeightAtSubject: Number(frameHeight.toFixed(2)),
    frameWidthAtSubject: Number((frameHeight * aspect).toFixed(2)),
    cameraView: cameraPov,
    // R69：低配档（软件渲染）与路径追踪不可用时景深不可用（导出会回退超采样）。
    dofAvailable: effectiveProfile() !== 'low' && !pathTracerModule.error,
    dofLoaded: !!(window.SSPathTracer && window.SSPathTracer.PhysicalCamera),
  };
}

function downscaleToDataUrl(source, width, height) {
  const dst = document.createElement('canvas');
  dst.width = width;
  dst.height = height;
  const ctx = dst.getContext('2d');
  ctx.imageSmoothingEnabled = true;
  ctx.imageSmoothingQuality = 'high';
  ctx.drawImage(source, 0, 0, source.width, source.height, 0, 0, width, height);
  return dst.toDataURL('image/png');
}

// 超采样静帧（快速模式 / 低配回退 / 路径追踪不可用时）：高像素比渲染 + 高质量降采样。
async function supersampleStill(spec) {
  const factor = Math.max(1, Math.min(3, Math.round(spec.factor || 2)));
  const startedAt = nowMs();
  const size = snapshotRendererSize();
  const cameraState = spec.cameraState;
  const hidden = hideStillHelpers();
  try {
    renderer.setPixelRatio(1);
    renderer.setSize(spec.width * factor, spec.height * factor, false);
    // 两帧渲染，确保贴图/环境/阴影稳定后再抓图。
    renderer.render(scene, camera);
    await new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)));
    renderer.render(scene, camera);
    const dataUrl = downscaleToDataUrl(renderer.domElement, spec.width, spec.height);
    const ms = Math.round(nowMs() - startedAt);
    return {
      ok: true,
      mode: 'supersample',
      requested: spec.requested || 'supersample',
      fallbackReason: spec.fallbackReason || '',
      width: spec.width,
      height: spec.height,
      factor,
      samples: factor,
      ms,
      // R69：超采样无法做真实景深；请求了景深时明确回报回退标记。
      dofFallback: spec.dof?.enabled === true,
      dataUrl,
    };
  } finally {
    restoreStillHelpers(hidden);
    restoreRendererSize(size);
    if (cameraState) restoreCameraState(cameraState);
  }
}

function startPathStill(spec) {
  const size = snapshotRendererSize();
  const hidden = hideStillHelpers();
  // V7/D138：路径追踪器要求等距柱状环境贴图（PMREM/CubeUV 会崩）；无 HDR 时置空。
  const prevEnvironment = scene.environment;
  try {
    const pt = ensurePathTracer();
    renderer.setPixelRatio(1);
    renderer.setSize(spec.width, spec.height, false);
    scene.environment = studioEquirectEnv || null;
    pt.renderScale = 1;
    pt.bounces = spec.bounces;
    // V7/D139：始终用 PhysicalCamera 渲染（FEATURE_DOF 定义恒为 1，避免材质重编译死锁）；
    // 景深参数（fStop/对焦距离）仅在 spec.dof.enabled 时生效。
    const stillCam = syncDofCamera(spec) || camera;
    const dofOn = !!spec.dof && spec.dof.enabled === true && stillCam !== camera;
    pt.setScene(scene, stillCam);
    pt.reset();
    stillSeq += 1;
    stillRun = {
      seq: stillSeq,
      pt,
      spec,
      hidden,
      size,
      prevEnvironment,
      dof: {
        enabled: dofOn,
        fStop: dofOn ? Number(stillCam.fStop.toFixed(1)) : 0,
        focusDistance: Number(stillCam.focusDistance.toFixed(2)),
        focusMode: dofOn ? (spec.dof.focusMode || 'auto') : '',
      },
      startedAt: nowMs(),
      lastProgressAt: 0,
      resolved: false,
    };
    send('stillProgress', {
      seq: stillRun.seq,
      mode: 'path',
      phase: 'compile',
      samples: 0,
      target: spec.samples,
      elapsedMs: 0,
      width: spec.width,
      height: spec.height,
    });
  } catch (err) {
    scene.environment = prevEnvironment;
    restoreStillHelpers(hidden);
    restoreRendererSize(size);
    if (spec.cameraState) restoreCameraState(spec.cameraState);
    throw err;
  }
}

function finishPathStill(run, reason) {
  if (run.resolved) return;
  run.resolved = true;
  stillRun = null;
  let dataUrl = '';
  let error = '';
  try {
    dataUrl = renderer.domElement.toDataURL('image/png');
  } catch (err) {
    error = String(err?.message || err);
  }
  const ms = Math.round(nowMs() - run.startedAt);
  const samples = Math.round(run.pt.samples);
  scene.environment = run.prevEnvironment;
  restoreStillHelpers(run.hidden);
  restoreRendererSize(run.size);
  if (run.spec.cameraState) restoreCameraState(run.spec.cameraState);
  const payload = {
    ok: !!dataUrl && !error,
    mode: 'path',
    reason,
    width: run.spec.width,
    height: run.spec.height,
    samples,
    target: run.spec.samples,
    ms,
    msPerSample: samples > 0 ? Number((ms / samples).toFixed(1)) : null,
    dof: !!(run.dof && run.dof.enabled),
    fStop: run.dof ? run.dof.fStop : 0,
    focusDistance: run.dof ? run.dof.focusDistance : 0,
    focusMode: run.dof ? run.dof.focusMode : '',
    error,
  };
  send('stillRendered', { seq: run.seq, ...payload, dataUrl });
  run.spec.resolve({ ...payload, dataUrl });
}

// 主循环调用：推进静帧渲染与后台预热（异常绝不能中断主循环）。
function pathTracerTick() {
  try {
    pathTracerWarmTick();
    stillTick();
  } catch (err) {
    const message = String(err?.message || err);
    send('error', { message: `静帧渲染失败：${message}`, fatal: false, source: 'still' });
    pathTracerWarmRun = null;
    const run = stillRun;
    if (run) {
      stillRun = null;
      run.resolved = true;
      if (run.prevEnvironment !== undefined) scene.environment = run.prevEnvironment;
      restoreStillHelpers(run.hidden);
      restoreRendererSize(run.size);
      if (run.spec.cameraState) restoreCameraState(run.spec.cameraState);
      const payload = { ok: false, mode: 'path', error: message, ms: Math.round(nowMs() - run.startedAt) };
      send('stillRendered', { seq: run.seq, ...payload });
      run.spec.resolve(payload);
    }
  }
}

function pathTracerWarmTick() {
  if (!pathTracerWarmRun) return;
  pathTracerWarmRun.pt.renderSample();
  if (pathTracerWarmRun.pt.samples >= 2 || nowMs() - pathTracerWarmRun.startedAt > 300000) {
    pathTracerWarmDone = true;
    send('stillProgress', {
      mode: 'warm',
      phase: 'done',
      samples: pathTracerWarmRun.pt.samples,
      target: 2,
      elapsedMs: Math.round(nowMs() - pathTracerWarmRun.startedAt),
    });
    pathTracerWarmRun = null;
  }
}

function stillTick() {
  const run = stillRun;
  if (!run || run.resolved) return;
  const elapsed = nowMs() - run.startedAt;
  if (!run.pt.isCompiling) run.pt.renderSample();
  const samples = run.pt.samples;
  if (nowMs() - run.lastProgressAt > 400) {
    run.lastProgressAt = nowMs();
    send('stillProgress', {
      seq: run.seq,
      mode: 'path',
      phase: run.pt.isCompiling ? 'compile' : 'render',
      samples: Math.round(samples),
      target: run.spec.samples,
      elapsedMs: Math.round(elapsed),
      width: run.spec.width,
      height: run.spec.height,
    });
  }
  if (samples >= run.spec.samples) finishPathStill(run, 'done');
  else if (elapsed > run.spec.timeoutMs) finishPathStill(run, 'timeout');
}

// 对外：渲染静帧（返回 Promise；同时用 stillProgress / stillRendered 事件上报）。
function renderStill(opts = {}) {
  return new Promise((resolve) => {
    if (stillRun) {
      resolve({ ok: false, error: '已有静帧渲染进行中' });
      return;
    }
    const spec = {
      mode: opts.mode === 'supersample' ? 'supersample' : 'path',
      requested: opts.mode === 'supersample' ? 'supersample' : 'path',
      width: Math.round(clamp(Number(opts.width) || 960, 160, 2560)),
      height: Math.round(clamp(Number(opts.height) || 720, 120, 1600)),
      samples: Math.round(clamp(Number(opts.samples) || 32, 1, 512)),
      bounces: Math.round(clamp(Number(opts.bounces) || 4, 1, 8)),
      factor: Math.round(clamp(Number(opts.factor) || 2, 1, 3)),
      timeoutMs: clamp(Number(opts.timeoutMs) || 240000, 5000, 600000),
      useCameraRig: opts.useCameraRig === true,
      // V7/D139：景深参数（仅路径追踪生效；超采样回退时以 dofFallback 标记，R69）。
      dof: (() => {
        const raw = opts.dof && typeof opts.dof === 'object' ? opts.dof : null;
        if (!raw || raw.enabled !== true) {
          return { enabled: false, fStop: 2.8, focusMode: 'auto', focusDistance: 2 };
        }
        return {
          enabled: true,
          fStop: Number(clamp(Number(raw.fStop) || 2.8, 1, 22).toFixed(1)),
          focusMode: raw.focusMode === 'manual' ? 'manual' : 'auto',
          focusDistance: Number(clamp(Number(raw.focusDistance) || 2, 0.3, 30).toFixed(2)),
        };
      })(),
      resolve,
    };
    spec.cameraState = snapshotCameraState();
    if (spec.useCameraRig) applyCameraPov();
    if (spec.mode === 'path') {
      loadPathTracerBundle().then((ok) => {
        if (ok && effectiveProfile() !== 'low') {
          camera.updateMatrixWorld(true);
          startPathStill(spec);
        } else {
          supersampleStill({
            ...spec,
            fallbackReason: ok ? '低配档（软件渲染）自动回退超采样' : (pathTracerModule.error || '路径追踪器不可用'),
          }).then(resolve);
        }
      }).catch((err) => {
        if (spec.cameraState) restoreCameraState(spec.cameraState);
        resolve({ ok: false, mode: 'path', error: String(err?.stack || err?.message || err).slice(0, 400) });
      });
    } else {
      supersampleStill(spec).then(resolve).catch((err) => {
        resolve({ ok: false, mode: 'supersample', error: String(err?.message || err) });
      });
    }
  });
}

// 预热：灯光页就绪后调用，提前付掉着色器编译成本（第二次导出亚秒级，见 spike 报告）。
function warmPathTracer() {
  if (pathTracerWarmDone || pathTracerWarmRun) return { ok: true, cached: true };
  if (effectiveProfile() === 'low') return { ok: false, reason: 'low-profile' };
  loadPathTracerBundle().then((ok) => {
    if (!ok) return;
    try {
      const pt = ensurePathTracer();
      camera.updateMatrixWorld(true);
      const prevEnvironment = scene.environment;
      scene.environment = studioEquirectEnv || null;
      // V7/D139：预热同样用 PhysicalCamera（FEATURE_DOF 恒为 1），避免预热后再切景深触发重编译。
      pt.setScene(scene, syncDofCamera(null) || camera);
      scene.environment = prevEnvironment;
      pt.reset();
      pathTracerWarmRun = { pt, startedAt: nowMs() };
    } catch (_) { /* 预热失败不影响正常导出（导出时重试） */ }
  });
  return { ok: true, warming: true };
}

// ---------------- 对外 API（Flutter / 调试） ----------------
// QA/诊断：暴露渲染上下文（脚本可注入测试灯、读取相机等；应用 UI 不使用）。
window.__ssQA = { renderer, scene, camera, controls };
let paused = false;
window.ss = {
  features: 'GLTFLoader GLTF gltf-parser SkeletonUtils retarget AnimationMixer BufferGeometryUtils LoopSubdivision skin-preserving-loop setSubdivision setMaterialPreset PMREM RoomEnvironment setAmbientEnabled setHandPose setHandCurls getHandState listHandPresets hand-bones HDRLoader HDRI setContactShadow getContactShadow contact-shadow getEnvironmentSource engineHeartbeat getEngineStats evictCharacterCache cache-lru setPerformanceProfile performance-profile gpu-info-v7 setSoftShadows getSoftShadows gobo-blinds blinds renderStill warmPathTracer path-tracer still-export supersample stillProgress stillRendered capture-token camera-assist getCameraAssist dof fStop focusDistance PhysicalCamera',
  ping: () => send('ready', { version: 1 }),
  setPaused: (p) => {
    paused = !!p;
    if (!paused) last = performance.now();
  },
  applyScene,
  setJoint: (joint, rot) => { activeSubject().setJoints({ [joint]: rot }); },
  setJoints: (joints) => { activeSubject().setJoints(joints); },
  setPose: (joints, duration = 300) => { activeSubject().animateTo(joints, duration); },
  setJointMode: (on) => {
    jointMode = !!on;
    person.setMarkerMode(jointMode);
    character.setJointMode(jointMode);
  },
  setView: (mode) => {
    cameraPov = false; // 手动切视角时退出机位 POV
    camera.fov = 42;
    camera.updateProjectionMatrix();
    setView(mode);
  },
  // V6/D105：机位控制与 POV。
  setCameraRig: (cfg) => {
    if (cfg && typeof cfg === 'object') Object.assign(cameraRigState, cfg);
    applyCameraRig();
    return { ...cameraRigState };
  },
  getCameraRig: () => ({ ...cameraRigState }),
  // V7/D139：焦段/视野/对焦距离辅助信息（含景深可用性，R69）。
  getCameraAssist: () => getCameraAssist(),
  setCameraView: (on) => setCameraPov(on),
  getCameraView: () => cameraPov,
  // V6/D111：光锥可视化开关。
  setLightCones: (on) => {
    setLightCones(on);
    for (const [id, obj] of lightObjs) {
      const cfg = (sceneState.lights || []).find((l) => l.id === id);
      if (cfg) updateLight(obj, cfg);
    }
    return getLightCones();
  },
  getLightCones: () => getLightCones(),
  setQaView: (deg) => {
    const rad = (Number(deg) || 0) * Math.PI / 180;
    camera.position.set(Math.sin(rad) * 3.5, 1.18, Math.cos(rad) * 3.5);
    controls.target.set(0, 1.02, 0);
    controls.enabled = false;
    controls.update();
  },
  setGrid: (on) => studio.setGridVisible(!!on),
  setLinkage: (on) => { linkage = !!on; },
  setTheme,
  setSubjectVisible: (on) => { activeSubject().root.visible = !!on; },
  setGender: (g) => { Promise.resolve(activeSubject().setGender(g)).catch(() => {}); },
  setSkeletonMode: (on) => { activeSubject().setSkeletonMode(!!on); },
  setCharacter: (id) => { useCharacter(String(id)).then((ok) => { if (id === 'legacy') person.setSkeletonMode(false); return ok; }); },
  setOutfit: (id) => character.setOutfit(id == null ? null : String(id)).catch(() => false),
  setHair: (id) => character.setHair(id == null ? null : String(id)).catch(() => false),
  setSkinTone: (hex) => character.setSkinTone(hex == null ? null : String(hex)).catch(() => false),
  // D62/D63 桥接 API（Flutter 侧按需接入）。
  setSubdivision: (level) => {
    desiredSubdivision = Number(level) || 0;
    const applied = effectiveProfile() === 'low'
      ? Math.min(desiredSubdivision, 1)
      : desiredSubdivision;
    return character.setSubdivision(applied);
  },
  // V6/D104：性能档（auto | high | low）。
  setPerformanceProfile: (profile) => {
    performanceProfile = profile === 'low' || profile === 'high' ? profile : 'auto';
    applyPerformanceProfile();
    return { requested: performanceProfile, effective: effectiveProfile() };
  },
  getPerformanceProfile: () => ({ requested: performanceProfile, effective: effectiveProfile() }),
  // V7/D137：软阴影（VSM）开关；低配档自动回退 PCF。
  setSoftShadows: (on) => {
    softShadows = !!on;
    applyShadowType();
    return { soft: softShadows, type: renderer.shadowMap.type === THREE.VSMShadowMap ? 'vsm' : 'pcf' };
  },
  getSoftShadows: () => ({
    soft: softShadows,
    type: renderer.shadowMap.type === THREE.VSMShadowMap ? 'vsm' : 'pcf',
  }),
  setMaterialPreset: (name) => {
    const promise = character.setMaterialPreset(name == null ? null : String(name));
    Promise.resolve(promise).then(() => syncContactShadowPreset()).catch(() => {});
    return promise;
  },
  getMaterialPreset: () => character.getStatus().materialPreset,
  // V5/D90：当前环境反射来源（room = RoomEnvironment 回退；hdr = 影棚 HDRI）。
  getEnvironmentSource: () => environmentSource,
  // V5/D91：接触阴影开关（仅 realistic 预设生效）。
  setContactShadow: (on) => {
    contactShadowEnabled = !!on;
    applyContactShadow();
    return contactShadowEnabled;
  },
  getContactShadow: () => contactShadowEnabled,
  setEnvIntensity: (value) => {
    const v = Math.max(0, Number(value) || 0);
    environmentIntensity = v;
    if (ambientEnabled) scene.environmentIntensity = v;
    return v;
  },
  // V5/D85：环境光开关（关 = 半球光隐藏 + 环境贴图贡献置 0，含金属反射）。
  setAmbientEnabled: (on) => {
    ambientEnabled = !!on;
    applyAmbient();
    return ambientEnabled;
  },
  getAmbientEnabled: () => ambientEnabled,
  // V5/D86–D88：手部动作（左右独立 + 双手组合预设）。
  setHandPose: (side, presetId) => character.setHandPose(side == null ? 'l' : String(side), presetId == null ? 'relax' : String(presetId)),
  setHandCurls: (side, curls) => character.setHandCurls(side == null ? 'l' : String(side), curls || {}),
  getHandState: () => character.getHandState(),
  getHandSupport: () => character.getHandSupport(),
  listHandPresets: () => character.listHandPresets(),
  resetHands: () => character.resetHands(),
  // QA：手部特写镜头（手骨骼世界坐标 → 相机）。
  qaFocusHand: (side, distance = 0.5) => {
    const p = character.getHandWorldPosition(side);
    if (!p) return false;
    const target = new THREE.Vector3(p.x, p.y, p.z);
    const dir = new THREE.Vector3(0.3, 0.4, 1).normalize();
    camera.position.copy(target.clone().add(dir.multiplyScalar(qaAllowDistance(distance))));
    controls.target.copy(target);
    controls.update();
    return true;
  },
  // QA：关节近景镜头（focus=neck|spine|wrist_l…；dy 为目标点抬高，米；用于材质特写）。
  qaFocusJoint: (name, distance = 0.8, dy = 0) => {
    const p = character.getJointWorldPosition(String(name));
    if (!p) return false;
    const target = new THREE.Vector3(p.x, p.y + (Number(dy) || 0), p.z);
    const dir = new THREE.Vector3(0.12, 0.06, 1).normalize();
    camera.position.copy(target.clone().add(dir.multiplyScalar(qaAllowDistance(distance))));
    controls.target.copy(target);
    controls.update();
    return true;
  },
  qaSkinningProbe: () => character.qaSkinningProbe(),
  qaMeshInfo: () => character.qaMeshInfo(),
  listCharacters: () => character.listCharacters(),
  // D61：写实模式角色列表（listCharacters() 中 realistic=true 的条目）。
  listRealisticCharacters: () => character.listRealisticCharacters(),
  listOutfits: () => character.listOutfits(),
  listHair: () => character.listHair(),
  getSubjectStatus: () => ({ ...character.getStatus(), mode: subjectMode }),
  getSubjectBounds: () => computeSubjectBounds(),
  getJointMapping: () => character.getJointMapping(),
  capturePhoto: (token) => {
    renderer.render(scene, camera);
    const dataUrl = renderer.domElement.toDataURL('image/png');
    // V7/D138：可选 token 用于 A/B 冻结等定向取图（默认空 = 普通效果预览保存）。
    send('captured', { dataUrl, token: token == null ? '' : String(token) });
    return true;
  },
  // V7/D138：照片级静帧（路径追踪；失败/低配自动回退超采样）。
  renderStill: (opts) => renderStill(opts && typeof opts === 'object' ? opts : {}),
  warmPathTracer: () => warmPathTracer(),
  // 诊断：当前场景灯光（QA/测试核对 applyScene 是否生效）。
  getLightDebug: () => (sceneState.lights || []).map((l) => {
    const obj = lightObjs.get(l.id);
    const spot = obj?.getObjectByName?.('spot');
    const rect = obj?.getObjectByName?.('rect');
    return {
      id: l.id,
      intensity: l.intensity,
      on: l.on !== false,
      fixture: l.fixture,
      modifier: l.modifier,
      x: l.x,
      y: l.y,
      spotIntensity: spot ? Number(spot.intensity.toFixed(2)) : null,
      spotAngleDeg: spot ? Number(((spot.angle * 180) / Math.PI).toFixed(1)) : null,
      spotVisible: spot ? spot.visible : null,
      rectIntensity: rect ? Number(rect.intensity.toFixed(2)) : null,
      groupVisible: obj ? obj.visible : null,
    };
  }),
  getPathTracerState: () => {
    // V7/D139：诊断字段（QA 排查景深重编译等路径追踪状态用；防御式读取内部对象）。
    const dbg = {};
    try {
      if (pathTracer) {
        const ptr = pathTracer._pathTracer;
        const mat = ptr ? ptr.material : null;
        dbg.samples = pathTracer.samples;
        dbg.isCompiling = pathTracer.isCompiling;
        dbg.compilePending = ptr ? !!ptr._compilePromise : null;
        dbg.enablePathTracing = pathTracer.enablePathTracing;
        dbg.pausePathTracing = pathTracer.pausePathTracing;
        dbg.renderDelay = pathTracer.renderDelay;
        if (mat) {
          dbg.dofDefine = mat.defines ? mat.defines.FEATURE_DOF : null;
          dbg.cameraType = mat.defines ? mat.defines.CAMERA_TYPE : null;
          const pc = mat.physicalCamera;
          if (pc) {
            dbg.bokehSize = Number(pc.bokehSize);
            dbg.focusDistance = Number(pc.focusDistance);
            dbg.fStop = Number(pc.fStop);
          }
        }
      }
    } catch (e) {
      dbg.error = String((e && e.message) || e);
    }
    return {
      moduleLoaded: pathTracerModule.loaded,
      moduleError: pathTracerModule.error,
      instance: !!pathTracer,
      warmDone: pathTracerWarmDone,
      warming: !!pathTracerWarmRun,
      rendering: !!stillRun,
      seq: stillSeq,
      profile: effectiveProfile(),
      debug: dbg,
    };
  },
  getOutbox: () => window.__ssOutbox || [],
  // V6/R43：心跳/内存/缓存统计（QA 与诊断包用）。
  heartbeat: () => ({ frames: frameCount, fps: lastFps, at: Math.round(performance.now()) }),
  getEngineStats: () => ({
    frames: frameCount,
    fps: lastFps,
    paused,
    memory: perfMemory(),
    cache: typeof character.getCacheStats === 'function' ? character.getCacheStats() : null,
    environmentSource,
    ambientEnabled,
    contactShadow: contactShadowEnabled && contactShadowSupported,
    performance: { requested: performanceProfile, effective: effectiveProfile() },
    // V7/D135：GPU 渲染器（设置页显卡卡片校验切换结果）。
    gpu: { renderer: gpuRendererName, profile: effectiveProfile(), api: 'gpu-info-v7' },
  }),
  evictCharacterCache: () => {
    if (typeof character.evictAll === 'function') character.evictAll();
    return true;
  },
};

// ---------------- 主循环 ----------------
let last = performance.now();
function frame(t) {
  const dt = (t - last) / 1000;
  last = t;
  frameCount++;
  framesSinceHeartbeat++;
  if (!lastHeartbeatAt) lastHeartbeatAt = t;
  if (t - lastHeartbeatAt >= 1000) {
    lastFps = Math.round((framesSinceHeartbeat * 1000) / Math.max(1, t - lastHeartbeatAt));
    framesSinceHeartbeat = 0;
    lastHeartbeatAt = t;
  }
  if (!paused) {
    if (subjectMode === 'legacy') person.tick(t);
    else character.tick();
    if (contactShadow.visible) {
      contactShadowClock += dt;
      if (contactShadowClock > 0.8) {
        contactShadowClock = 0;
        updateContactShadowTransform();
      }
    }
    controls.update(dt);
    renderer.render(scene, camera);
    // V7/D138：静帧渲染/预热在主循环内推进（blit 在普通渲染之后，避免被覆盖）。
    pathTracerTick();
  }
  requestAnimationFrame(frame);
}

function resize() {
  const w = window.innerWidth;
  const h = window.innerHeight;
  renderer.setSize(w, h, false);
  camera.aspect = w / Math.max(1, h);
  camera.updateProjectionMatrix();
}
window.addEventListener('resize', resize);
resize();

// 心跳用 setInterval（rAF 在隐藏页/后台会被节流，setInterval 相对稳定）。
setInterval(() => {
  try {
    send('engineHeartbeat', heartbeatPayload());
  } catch (_) { /* 静默 */ }
}, 1500);

try {
  boot('正在加载角色模型…');
  applyScene({ version: 1, lights: [], props: [], subject: { height: 1.7, pose: { joints: {} } } });
  send('ready', { version: 1 });
  requestAnimationFrame(frame);
  character.init().then(async () => {
    if (characterRequested) return; // 调用方已显式请求（setCharacter/applyScene）
    const list = character.listCharacters();
    const target = list.find((c) => c.default) || list[0];
    if (!target) {
      const message = '角色清单为空：缺少 assets/models/characters/manifest.json（可运行 tool/gen_characters.dart 生成）';
      boot(null);
      send('error', { message });
      return;
    }
    await useCharacter(target.id);
  }).catch((err) => {
    const message = `角色清单加载失败：${err?.message || err}`;
    boot(null);
    send('error', { message });
  });
} catch (err) {
  boot(`3D 引擎加载失败：${err?.message || err}`, true);
  send('error', { message: String(err?.message || err), fatal: true, source: 'boot' });
}
