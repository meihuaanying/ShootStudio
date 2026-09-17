// 道具预设：沙发 / 透明伞 / 箱体 / 背景布 / 反光板 / 花束（D5、D22）。
import * as THREE from 'three';
import { DEG } from './util.js';

const mats = {
  fabric: new THREE.MeshStandardMaterial({ color: 0x8c93a3, roughness: 0.9 }),
  darkFabric: new THREE.MeshStandardMaterial({ color: 0x596170, roughness: 0.92 }),
  wood: new THREE.MeshStandardMaterial({ color: 0xb08a5e, roughness: 0.7 }),
  metal: new THREE.MeshStandardMaterial({ color: 0x9aa2ad, roughness: 0.4, metalness: 0.6 }),
  clear: new THREE.MeshStandardMaterial({
    color: 0xf3f6fa, roughness: 0.15, metalness: 0.05, transparent: true, opacity: 0.32,
  }),
  backdrop: new THREE.MeshStandardMaterial({ color: 0xe8e4dc, roughness: 0.95 }),
  flower: new THREE.MeshStandardMaterial({ color: 0xd77389, roughness: 0.8 }),
  leaf: new THREE.MeshStandardMaterial({ color: 0x5d8b57, roughness: 0.85 }),
  reflector: new THREE.MeshStandardMaterial({ color: 0xf6f7f9, roughness: 0.25, metalness: 0.6, side: THREE.DoubleSide }),
};

export const PROP_TYPES = [
  { id: 'sofa', label: '沙发' },
  { id: 'umbrella', label: '透明伞' },
  { id: 'crate', label: '箱体' },
  { id: 'backdrop', label: '背景布' },
  { id: 'reflector', label: '反光板' },
  { id: 'bouquet', label: '花束' },
];

function mesh(geo, mat, cast = true) {
  const m = new THREE.Mesh(geo, mat);
  m.castShadow = cast;
  m.receiveShadow = true;
  return m;
}

export function buildProp(type) {
  const g = new THREE.Group();
  switch (type) {
    case 'sofa': {
      const seat = mesh(new THREE.BoxGeometry(1.5, 0.32, 0.75), mats.fabric);
      seat.position.y = 0.34;
      const back = mesh(new THREE.BoxGeometry(1.5, 0.55, 0.22), mats.fabric);
      back.position.set(0, 0.75, -0.28);
      const armL = mesh(new THREE.BoxGeometry(0.22, 0.5, 0.75), mats.darkFabric);
      armL.position.set(-0.75, 0.48, 0);
      const armR = armL.clone();
      armR.position.x = 0.75;
      g.add(seat, back, armL, armR);
      break;
    }
    case 'umbrella': {
      const stem = mesh(new THREE.CylinderGeometry(0.012, 0.012, 0.95, 10), mats.metal);
      stem.position.y = 0.48;
      const canopy = mesh(new THREE.ConeGeometry(0.55, 0.28, 22, 1, true), mats.clear, false);
      canopy.position.y = 0.95;
      g.add(stem, canopy);
      break;
    }
    case 'crate': {
      const box = mesh(new THREE.BoxGeometry(0.55, 0.55, 0.55), mats.wood);
      box.position.y = 0.28;
      g.add(box);
      break;
    }
    case 'backdrop': {
      const rod = mesh(new THREE.CylinderGeometry(0.02, 0.02, 2.2, 10), mats.metal);
      rod.rotation.z = Math.PI / 2;
      rod.position.y = 2.05;
      const cloth = mesh(new THREE.PlaneGeometry(2.2, 2.0), mats.backdrop);
      cloth.position.set(0, 1.05, 0.01);
      cloth.receiveShadow = true;
      const legL = mesh(new THREE.CylinderGeometry(0.018, 0.018, 2.05, 8), mats.metal);
      legL.position.set(-1.05, 1.02, 0);
      const legR = legL.clone();
      legR.position.x = 1.05;
      g.add(rod, cloth, legL, legR);
      break;
    }
    case 'reflector': {
      const board = mesh(new THREE.PlaneGeometry(0.9, 1.2), mats.reflector);
      board.position.y = 0.8;
      board.rotation.x = -0.12;
      const frame = mesh(new THREE.BoxGeometry(0.94, 1.24, 0.03), mats.metal, false);
      frame.position.set(0, 0.8, 0.02);
      g.add(board, frame);
      break;
    }
    case 'bouquet': {
      const wrap = mesh(new THREE.ConeGeometry(0.14, 0.3, 14, 1, true), mats.clear, false);
      wrap.position.y = 0.32;
      g.add(wrap);
      for (let i = 0; i < 6; i++) {
        const bloom = mesh(new THREE.SphereGeometry(0.055, 10, 8), mats.flower, false);
        const a = (i / 6) * Math.PI * 2;
        bloom.position.set(Math.cos(a) * 0.07, 0.44 + (i % 2) * 0.04, Math.sin(a) * 0.07);
        g.add(bloom);
      }
      const leaves = mesh(new THREE.SphereGeometry(0.1, 10, 8), mats.leaf, false);
      leaves.scale.set(1.4, 0.5, 1.4);
      leaves.position.y = 0.36;
      g.add(leaves);
      break;
    }
    default: {
      const box = mesh(new THREE.BoxGeometry(0.4, 0.4, 0.4), mats.wood);
      box.position.y = 0.2;
      g.add(box);
    }
  }
  return g;
}

// 用户上传贴图（D23）：把 dataURL 贴到自定义道具立方体贴图占位。
export async function applyPropTexture(group, dataUrl) {
  if (!dataUrl) return;
  const loader = new THREE.TextureLoader();
  const tex = await loader.loadAsync(dataUrl);
  tex.colorSpace = THREE.SRGBColorSpace;
  group.traverse((n) => {
    if (n.isMesh && n.material?.map !== undefined && !n.userData.keepMaterial) {
      n.material = new THREE.MeshStandardMaterial({ map: tex, roughness: 0.85 });
    }
  });
}

export function placeProp(group, cfg) {
  group.position.set(cfg.x ?? 0, 0, -(cfg.y ?? 0));
  group.rotation.y = (cfg.rotation ?? 0) * DEG;
  const scale = cfg.scale ?? 1;
  group.scale.setScalar(scale);
}
