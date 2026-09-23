# 路径追踪 spike 报告（V7/S3.3 · D138）

> 日期：2026-09-23 ｜ 结论：**可行**（three-gpu-pathtracer@0.0.24 + three r186 + three-mesh-bvh@0.9.15）
> 产物：`app/tool/pathtracer_spike.mjs`、`app/tool/spike_pt.html`、`app/tool/engine_build/pathtracer_build.mjs`
> 结果：`docs/qa/pathtracer-spike-swiftshader.json`、`docs/qa/pathtracer-spike-gpu.json`、`docs/qa/pathtracer-spike-gpu-headed.json` + 同名 PNG

## 1. 兼容性

| 项 | 结果 |
|---|---|
| 依赖解析 | `three-gpu-pathtracer@0.0.24` peer：`three>=0.180.0`、`three-mesh-bvh>=0.7.4`、`xatlas-web^0.1.0`（UVUnwrapper 专用；**未被 index 引用**，不打包） |
| three r186 | 正常：BVH 构建、着色器编译、渲染全部通过；`compileAsync` 存在且被库使用 |
| `three/examples/jsm/postprocessing/Pass.js` | r186 源码拷入 `assets/engine/js/jsm/postprocessing/Pass.js`（MIT，仅打包期使用） |
| 双份 three 问题 | 规避：打包时 `three` 指向自动生成的全局 shim（复用引擎同一份 `window.__ssThree`），产物仅 **220KB** |
| file:// 兼容 | 走 classic IIFE（`window.SSPathTracer`），不依赖 ESM/importmap（与引擎 bundle 同策略） |

## 2. 实测数据（本机 Windows / Edge 153 / 640×480 或 320×240）

| 场景 | 首次导出 | 二次导出（同 renderer，程序缓存命中） |
|---|---|---|
| SwiftShader headless 320×240×8 samples | 96.7s | — |
| Iris Xe headless 640×480×16 samples | 72.1s | — |
| **RTX 4060 headed 320×240×2 samples** | **42.8s**（编译 ≈22.7s×3 变体 + 首绘 ≈20s） | **294.7ms，0 次重编译** |

- 吞吐：编译完成后约 **17ms/tile**（3×3 tile/sample，640×480）。
- 编译三次的变体来自 `material.onBeforeRender()` 的 `FEATURE_FOG` / `FEATURE_BACKGROUND_MAP` 变化链（库内部行为，无法完全消除）。
- **结论**：程序缓存按 renderer 复用，同一 WebView 内二次导出为亚秒级 → 引擎侧采用**单例 + 页面打开后台预热**；预热失败/低配档自动回退超采样静帧（R69）。

## 3. 首轮 spike 踩坑（已修）

- **同步循环会卡死编译**：`PathTracingRenderer` 首帧走 `renderer.compileAsync`（异步），用 `while` 同步转 `renderSample()` 会让 Promise 永不结算、`samples` 停在 0，截到的是光栅化回退画面（首轮 `samples:0 / frames:20000` 即此坑）。必须 rAF 驱动并让出事件循环。

## 4. 集成方案

1. `pathtracer_build.mjs` 生成 `assets/engine/js/pathtracer.bundle.js`（IIFE，220KB，非首屏加载）。
2. 引擎 `ss.renderStill({mode:'path'|'supersample', width, height, samples, bounces})`：
   - `path`：单例 `WebGLPathTracer`，`setScene` → rAF 采样（主循环驱动）→ `toDataURL`；进度事件 `stillProgress`。
   - `supersample`：2–3× pixelRatio 渲染 + 高质量降采样（低配档/加载失败自动回退，登记为 `mode:'supersample'`）。
3. `ss.warmPathTracer()`：灯光页就绪后后台预热（触发一次编译），让用户点击「效果预览」时基本即时。
4. UI：布光页「效果预览」对话框（模式/分辨率/采样数 + 进度 + 保存到工作区）。
