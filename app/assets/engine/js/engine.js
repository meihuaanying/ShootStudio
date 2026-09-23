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
import { nowMs } from './util.js';

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
let environmentSource = 'room'; // room | hdr
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
        source = 'hdr';
      } catch (_) {
        source = 'room';
      } finally {
        hdr.dispose();
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

// ---------------- 对外 API（Flutter / 调试） ----------------
let paused = false;
window.ss = {
  features: 'GLTFLoader GLTF gltf-parser SkeletonUtils retarget AnimationMixer BufferGeometryUtils LoopSubdivision skin-preserving-loop setSubdivision setMaterialPreset PMREM RoomEnvironment setAmbientEnabled setHandPose setHandCurls getHandState listHandPresets hand-bones HDRLoader HDRI setContactShadow getContactShadow contact-shadow getEnvironmentSource engineHeartbeat getEngineStats evictCharacterCache cache-lru setPerformanceProfile performance-profile gpu-info-v7 setSoftShadows getSoftShadows gobo-blinds blinds',
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
  capturePhoto: () => {
    renderer.render(scene, camera);
    const dataUrl = renderer.domElement.toDataURL('image/png');
    send('captured', { dataUrl });
    return true;
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
