// PBR 材质预设（D63/V5-D89）：standard | realistic | light，默认 realistic。
// V5 升级：
// - 皮肤：预积分皮肤 BRDF LUT（运行时生成，无外部资源）+ wrap 光照 + 边缘散射注入；
// - 布料：程序噪声法线（保留）+ 注入式 sheen 近似；
// - R37：写实模型 authored 贴图（normal/roughness/metalness/baseColor）不再被清除；
// - 分类修复：MakeHuman 的 Human.body/lips/ears/fingernails/teeth/tongue → skin，
//   eyelashes/eyebrow/short01 → hair，high-poly → eye。
import * as THREE from 'three';

export const MATERIAL_PRESETS = ['standard', 'realistic', 'light'];
export const DEFAULT_MATERIAL_PRESET = 'realistic';

const SSS_TINT = 0xff8a66;

export function classifyMaterialName(name) {
  const n = String(name || '').toLowerCase();
  // 头发/眉毛/睫毛（先于皮肤判定，避免 Human.eyelashes01 误判）。
  if (/hair|brow|moustache|beard|eyelash/.test(n)) return 'hair';
  if (/short0?\d+$/.test(n)) return 'hair'; // MakeHuman Human.short01（短发）
  // 眼睛（含 MakeHuman 眼球网格 Human.high-poly）。
  if (n.includes('eye') || /high-?poly/.test(n)) return 'eye';
  if (/skin|body|lips?|ear|fingernail|teeth|tongue|face/.test(n)) return 'skin';
  if (/metal|gold|silver|earring|visor|buckle|zipper|chain|armor/.test(n)) return 'metal';
  if (/shoe|boot|sneaker|sandal|heel/.test(n)) return 'shoe';
  return 'cloth';
}

const PRESET_PARAMS = {
  realistic: {
    skin: { roughness: 0.45, metalness: 0.0, envMapIntensity: 1.15, sss: true },
    hair: { roughness: 0.58, metalness: 0.05, envMapIntensity: 0.9 },
    eye: { roughness: 0.1, metalness: 0.0, envMapIntensity: 1.8 },
    metal: { roughness: 0.28, metalness: 0.92, envMapIntensity: 1.6 },
    shoe: { roughness: 0.5, metalness: 0.1, envMapIntensity: 0.9 },
    cloth: { roughness: 0.85, metalness: 0.0, envMapIntensity: 0.65, clothNoise: true, normalScale: 0.22, sheen: 0.07 },
  },
  standard: {
    skin: { roughness: 0.55, metalness: 0.0, envMapIntensity: 0.7 },
    hair: { roughness: 0.65, metalness: 0.05, envMapIntensity: 0.6 },
    eye: { roughness: 0.2, metalness: 0.0, envMapIntensity: 1.0 },
    metal: { roughness: 0.42, metalness: 0.8, envMapIntensity: 1.0 },
    shoe: { roughness: 0.6, metalness: 0.0, envMapIntensity: 0.6 },
    cloth: { roughness: 0.8, metalness: 0.0, envMapIntensity: 0.5, clothNoise: true, normalScale: 0.12 },
  },
  light: {
    skin: { roughness: 0.62, metalness: 0.0, envMapIntensity: 0.3 },
    hair: { roughness: 0.7, metalness: 0.0, envMapIntensity: 0.25 },
    eye: { roughness: 0.3, metalness: 0.0, envMapIntensity: 0.4 },
    metal: { roughness: 0.5, metalness: 0.6, envMapIntensity: 0.5 },
    shoe: { roughness: 0.65, metalness: 0.0, envMapIntensity: 0.3 },
    cloth: { roughness: 0.82, metalness: 0.0, envMapIntensity: 0.3 },
  },
};

let clothNoiseTexture = null;

// 运行时程序化微噪声法线（无外部贴图；LCG 保证可复现）。
export function getClothNoiseTexture() {
  if (clothNoiseTexture) return clothNoiseTexture;
  const size = 96;
  const height = new Float32Array(size * size);
  let seed = 20260913;
  const rand = () => {
    seed = (seed * 1664525 + 1013904223) % 4294967296;
    return seed / 4294967296;
  };
  for (let i = 0; i < height.length; i++) height[i] = rand();
  const blur = new Float32Array(size * size);
  for (let pass = 0; pass < 2; pass++) {
    for (let y = 0; y < size; y++) {
      for (let x = 0; x < size; x++) {
        let sum = 0;
        for (let dy = -1; dy <= 1; dy++) {
          for (let dx = -1; dx <= 1; dx++) {
            sum += height[((y + dy + size) % size) * size + ((x + dx + size) % size)];
          }
        }
        blur[y * size + x] = sum / 9;
      }
    }
    height.set(blur);
  }
  const data = new Uint8Array(size * size * 4);
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const hL = height[y * size + ((x - 1 + size) % size)];
      const hR = height[y * size + ((x + 1) % size)];
      const hD = height[((y - 1 + size) % size) * size + x];
      const hU = height[((y + 1) % size) * size + x];
      const nx = (hL - hR) * 2.2;
      const ny = (hD - hU) * 2.2;
      const nz = 1;
      const len = Math.hypot(nx, ny, nz) || 1;
      const offset = (y * size + x) * 4;
      data[offset] = Math.round(((nx / len) * 0.5 + 0.5) * 255);
      data[offset + 1] = Math.round(((ny / len) * 0.5 + 0.5) * 255);
      data[offset + 2] = Math.round(((nz / len) * 0.5 + 0.5) * 255);
      data[offset + 3] = 255;
    }
  }
  clothNoiseTexture = new THREE.DataTexture(data, size, size, THREE.RGBAFormat);
  clothNoiseTexture.wrapS = THREE.RepeatWrapping;
  clothNoiseTexture.wrapT = THREE.RepeatWrapping;
  clothNoiseTexture.repeat.set(3, 3);
  clothNoiseTexture.needsUpdate = true;
  return clothNoiseTexture;
}

// 预积分皮肤 BRDF LUT（V5/D89）：(NoV, curvature) → 散射权重；
// 运行时程序化生成（128×128，纯 JS，无外部资源）；解析近似参考 Penner 预积分皮肤。
let skinLutTexture = null;

export function getSkinLutTexture() {
  if (skinLutTexture) return skinLutTexture;
  const size = 128;
  const data = new Uint8Array(size * size * 4);
  for (let y = 0; y < size; y++) {
    const curvature = y / (size - 1);
    for (let x = 0; x < size; x++) {
      const nl = x / (size - 1);
      // 基础漫反射近似 + 掠射/薄区散射增强（暖色衰减）。
      const base = (nl + 0.32 * curvature + 0.18) / (1.0 + 0.32 * curvature + 0.18);
      const grazing = Math.pow(1.0 - nl, 2.0) * (0.35 + 0.65 * curvature);
      const r = Math.min(1, base + grazing * 0.62);
      const g = Math.min(1, base + grazing * 0.36);
      const b = Math.min(1, base + grazing * 0.16);
      const offset = (y * size + x) * 4;
      data[offset] = Math.round(r * 255);
      data[offset + 1] = Math.round(g * 255);
      data[offset + 2] = Math.round(b * 255);
      data[offset + 3] = 255;
    }
  }
  skinLutTexture = new THREE.DataTexture(data, size, size, THREE.RGBAFormat);
  skinLutTexture.wrapS = THREE.ClampToEdgeWrapping;
  skinLutTexture.wrapT = THREE.ClampToEdgeWrapping;
  skinLutTexture.minFilter = THREE.LinearFilter;
  skinLutTexture.magFilter = THREE.LinearFilter;
  skinLutTexture.needsUpdate = true;
  return skinLutTexture;
}

function baseSnapshot(material) {
  if (!material.userData.ssPbrBase) {
    material.userData.ssPbrBase = {
      color: material.color ? material.color.clone() : null,
      roughness: material.roughness,
      metalness: material.metalness,
      envMapIntensity: material.envMapIntensity,
      normalScale: material.normalScale ? material.normalScale.clone() : null,
      // R37：记录 authored 贴图，切换预设时复原（不做任何清除）。
      normalMap: material.normalMap || null,
      roughnessMap: material.roughnessMap || null,
      metalnessMap: material.metalnessMap || null,
      alphaMap: material.alphaMap || null,
    };
  }
  return material.userData.ssPbrBase;
}

// 皮肤注入：wrap 光照（软化明暗交界）+ 预积分 LUT 边缘散射。
function attachSubsurfaceApprox(material) {
  const lut = getSkinLutTexture();
  material.onBeforeCompile = (shader) => {
    shader.uniforms.ssSssTint = { value: new THREE.Color(SSS_TINT) };
    shader.uniforms.ssSkinLut = { value: lut };
    shader.fragmentShader = `uniform vec3 ssSssTint;\nuniform sampler2D ssSkinLut;\n${shader.fragmentShader}`;
    // wrap diffuse：仅影响本材质的物理光照项。
    shader.fragmentShader = shader.fragmentShader.replace(
      'float dotNL = saturate( dot( geometryNormal, directLight.direction ) );',
      'float dotNL = saturate( ( dot( geometryNormal, directLight.direction ) + 0.32 ) / 1.32 );',
    );
    shader.fragmentShader = shader.fragmentShader.replace(
      '#include <lights_fragment_end>',
      `#include <lights_fragment_end>
      {
        float ssNv = clamp(dot(geometryNormal, geometryViewDir), 0.0, 1.0);
        float ssCurv = clamp(length(fwidth(geometryNormal)) * 6.0, 0.0, 1.0);
        vec3 ssLut = texture2D(ssSkinLut, vec2(ssNv, ssCurv)).rgb;
        vec3 ssTerm = diffuseColor.rgb * ssSssTint * ssLut;
        // 边缘/薄区散射（直接光 + 环境各一份，强度保守）。
        reflectedLight.directDiffuse += ssTerm * pow(1.0 - ssNv, 2.0) * 0.22;
        reflectedLight.indirectDiffuse += ssTerm * (1.0 - ssNv) * 0.1;
      }`,
    );
  };
  material.customProgramCacheKey = () => 'ss-skin-sss-v2';
}

// 布料注入：Fresnel sheen 近似（掠射角轻微绒感高光）。
function attachClothSheen(material, strength) {
  const s = Math.max(0, Math.min(0.2, strength || 0.06));
  material.onBeforeCompile = (shader) => {
    shader.uniforms.ssSheen = { value: s };
    shader.fragmentShader = `uniform float ssSheen;\n${shader.fragmentShader}`;
    shader.fragmentShader = shader.fragmentShader.replace(
      '#include <lights_fragment_end>',
      `#include <lights_fragment_end>
      {
        float ssFres = pow(1.0 - clamp(dot(geometryNormal, geometryViewDir), 0.0, 1.0), 3.0);
        reflectedLight.indirectDiffuse += vec3(1.0, 0.98, 0.94) * ssFres * ssSheen;
      }`,
    );
  };
  material.customProgramCacheKey = () => `ss-cloth-sheen-${s}`;
}

export function applyMaterialPreset(material, presetName, { hasUV = false } = {}) {
  if (!material || !material.isMeshStandardMaterial) return;
  const name = MATERIAL_PRESETS.includes(presetName) ? presetName : DEFAULT_MATERIAL_PRESET;
  const params = PRESET_PARAMS[name];
  const base = baseSnapshot(material);
  if (!material.userData.ssCategory) {
    material.userData.ssCategory = classifyMaterialName(material.name);
  }
  const category = material.userData.ssCategory;
  const p = params[category] || params.cloth;
  if (material.color && base.color) material.color.copy(base.color);
  material.roughness = p.roughness;
  material.metalness = p.metalness;
  material.envMapIntensity = p.envMapIntensity;
  // R37：先恢复 authored 贴图（绝不清除），仅在没有 authored 法线时才注入布料噪声。
  material.normalMap = base.normalMap;
  material.roughnessMap = base.roughnessMap;
  material.metalnessMap = base.metalnessMap;
  material.alphaMap = base.alphaMap;
  if (material.normalScale) {
    material.normalScale.copy(base.normalScale || new THREE.Vector2(1, 1));
  }
  material.onBeforeCompile = () => {};
  delete material.customProgramCacheKey; // 恢复原型默认实现（不可赋 null，three 会直接调用）
  if (p.clothNoise && hasUV && !base.normalMap) {
    material.normalMap = getClothNoiseTexture();
    material.normalScale.set(p.normalScale || 0.15, p.normalScale || 0.15);
  }
  if (p.sss) attachSubsurfaceApprox(material);
  if (p.sheen && category === 'cloth') attachClothSheen(material, p.sheen);
  material.userData.ssPreset = name;
  material.needsUpdate = true;
}
