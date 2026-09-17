// 白棚影棚：地面 + 无缝弧形背景 + 环境光照（communication-oriented，语义参考 direct-light，MIT）。
import * as THREE from 'three';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';

export function buildStudio(scene, renderer, { width = 6, depth = 8, height = 3.2 } = {}) {
  const group = new THREE.Group();
  scene.add(group);

  const white = new THREE.MeshStandardMaterial({ color: 0xf4f5f7, roughness: 0.92, metalness: 0 });

  // 地面（略大，视觉上无边界）。
  const floor = new THREE.Mesh(new THREE.PlaneGeometry(width + 8, depth + 8), white.clone());
  floor.rotation.x = -Math.PI / 2;
  floor.receiveShadow = true;
  group.add(floor);

  // 无缝弧形背景（后墙 + 弧形过渡），朝 -Z 方向。
  const backZ = -depth / 2;
  const radius = Math.min(1.4, height * 0.45);
  const curve = new THREE.Mesh(
    new THREE.CylinderGeometry(radius, radius, width, 28, 1, true, Math.PI / 2, Math.PI / 2),
    white.clone(),
  );
  // 圆柱侧面：让弧形从地面过渡到后墙。
  curve.position.set(0, radius, backZ + radius);
  curve.material.side = THREE.DoubleSide;
  curve.receiveShadow = true;
  group.add(curve);

  const backWall = new THREE.Mesh(new THREE.PlaneGeometry(width, height - radius), white.clone());
  backWall.position.set(0, radius + (height - radius) / 2, backZ);
  backWall.receiveShadow = true;
  group.add(backWall);

  // 侧墙（默认存在，可开关）。
  const sideL = new THREE.Mesh(new THREE.PlaneGeometry(depth, height), white.clone());
  sideL.rotation.y = Math.PI / 2;
  sideL.position.set(-width / 2, height / 2, 0);
  sideL.receiveShadow = true;
  const sideR = sideL.clone();
  sideR.rotation.y = -Math.PI / 2;
  sideR.position.x = width / 2;
  group.add(sideL, sideR);

  // 顶棚（弱反射可能造成光斑问题，默认关闭渲染：仅照明语义）。
  const ceilingMat = white.clone();
  const ceiling = new THREE.Mesh(new THREE.PlaneGeometry(width, depth), ceilingMat);
  ceiling.rotation.x = Math.PI / 2;
  ceiling.position.y = height;
  ceiling.visible = false;
  group.add(ceiling);

  // 环境反射（RoomEnvironment 提供柔和白色反弹，避免黑箱感）。
  // V5：PMREM 只在此处创建一次（此前 engine.js 也建过一次且未释放，本次修复泄漏）。
  const pmrem = new THREE.PMREMGenerator(renderer);
  const envRT = pmrem.fromScene(new RoomEnvironment(), 0.04);
  scene.environment = envRT.texture;
  pmrem.dispose();

  // 半球光：白棚基础反弹（V5/D85：可随环境光开关隐藏）。
  const hemi = new THREE.HemisphereLight(0xffffff, 0xdadde2, 0.55);
  scene.add(hemi);
  let ambientOn = true;
  function setAmbientEnabled(on) {
    ambientOn = !!on;
    hemi.visible = ambientOn;
  }

  // 地面网格（编辑辅助，默认隐藏）。
  const grid = new THREE.GridHelper(Math.max(width, depth), Math.max(width, depth), 0xb9c0cc, 0xd8dde5);
  grid.position.y = 0.002;
  grid.visible = false;
  scene.add(grid);

  function setGridVisible(v) { grid.visible = v; }

  // V5/D90：envTexture 供 engine.js 在 HDRI 替换后释放 RoomEnvironment 贴图。
  return {
    group,
    setGridVisible,
    setAmbientEnabled,
    envTexture: envRT.texture,
    dimensions: { width, depth, height },
  };
}
