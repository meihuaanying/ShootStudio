# V8 / S2 3D 引擎架构 spike 报告（D156 · R77 先报告）

> **结论先行：保留「WebView2 + three.js r186」现状路线，不迁 Flutter 原生渲染；把交互层重构（桥接批处理 / 事件节流 / 骨架屏）作为 S6 布光预演重构的交付项。**
> 本报告在 S6 动工前定稿；R77 要求先出报告再动架构 —— 报告后**未改动任何引擎架构代码**，本步只新增测量工具与探针。

---

## 1. 候选与判据

| 候选 | 说明 |
| --- | --- |
| **A 现状** | `flutter_inappwebview_windows`（WebView2）内嵌 `assets/engine/`（three.js r186 + 自研灯光/人物/道具/布光逻辑 + three-gpu-pathtracer 0.0.24） |
| **B 备选** | Flutter 原生渲染（Impeller Scene / `flutter_gpu` 路线），即用 Dart/Impeller 重写整个 3D 引擎 |

判据（D156 + R78）：交互帧率 p95、内存、集成成本、双端可行性、资产迁移代价、风险。

---

## 2. 候选 A 实测（现有路线）

工具：`app/tool/engine_perf_qa.mjs`（静态伺服 `app/` + Edge CDP，脚本化拖灯/旋转/推拉；页面内 rAF 采样帧间隔）。
场景：`qa.html?char=qs-women-casual&view=0&duration=0&clean=1&lights=1`，high 档（VSM 软阴影）、3 盏灯、画布 1259×810。
预热：等引擎 frames 稳定推进且 `TaskDuration` 增速 < 250ms/s 后才开始采样（否则首帧着色器编译会污染帧率）。

| 配置 | 实际 GPU | idle p50/p95 | orbit p95 | 拖灯 p95 | 推拉 p95 | CPU/帧 | >50ms 长帧 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `gtx4060-dpr1` | RTX 4060 Laptop（ANGLE D3D11） | 16.6 / **17.7ms** | **17.8ms** | **17.8ms** | **17.6ms** | 2.3–3.1ms | 0 |
| `gtx4060-dpr2` | 同上，devicePixelRatio=2 | 16.7 / **17.7ms** | **17.8ms** | **17.8ms** | **17.7ms** | 2.8–3.4ms | 0 |
| `default-adapter-dpr1` | **Intel Iris Xe 核显** | 16.7 / **17.4ms** | **17.7ms** | **18.3ms** | **18.4ms** | 3.2–3.9ms | 0 |
| `swiftshader-dpr1` | **SwiftShader 纯软件** | 1500.2ms | 1574.1ms | 1554.8ms | 1469.4ms | 16.8–28.3ms（主线程） | 全程 |

- 有 GPU（独显或核显）时**稳定 60fps**：p95 ≤ 18.4ms、无长帧，主线程每帧仅 2.3–3.9ms —— 瓶颈在 GPU 而非 CPU，帧率被 vsync 锁在 16.7ms。
- **唯一失败边界是纯软件渲染**（≈0.66fps）。应用侧已有对策：`detectPerformanceProfile()` 命中 software/swiftshader 时降为 low 档并回退超采样静帧（R69，见 `v7` S3.3），无需换架构。
- 内存：JS 堆 used 12.0–20.2MB（`Runtime.getHeapUsage`）/ 21.3–29.5MB（precise），total 43–58MB；GPU 侧 28 纹理 / 62–65 geometry / 21–29 program；draw calls 111–131，三角形 ≈163k。
- DPR=2（≈2520×1620 实际像素）帧率不掉，说明当前场景离填充率上限很远。

证据文件：`docs/qa/v8-s2-engine-perf-{gtx4060-dpr1,gtx4060-dpr2,default-adapter-dpr1,swiftshader-dpr1}.json`

### 2.1 宿主侧合成成本（Flutter + WebView2）

工具：`app/lib/dev/perf_probe.dart`（门控 `--dart-define=SS_PERF_PROBE=1` 或 `SS_PERF_PROBE=1`；默认关闭，正常启动零影响）。
Windows release 实测（24 个 3D 变换卡片持续动画 + 内嵌 WebView2 引擎视图，各采样 5s）：

| 阶段 | 帧数 | totalSpan p50 | p95 | max | build p95 | raster p95 | 实际帧率 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `flutterOnly`（纯 Flutter） | 293 | 10.12ms | 17.34ms | 38.57ms | 0.69ms | 1.38ms | 58.6fps |
| `withWebView`（+ WebView2 引擎） | 290 | 10.73ms | 17.78ms | 32.98ms | 0.96ms | 2.17ms | 58.0fps |

差值：p95 总帧 **+0.44ms**、build **+0.27ms**、raster **+0.79ms**，帧数 −1.0%。**内嵌 WebView 对 Flutter 合成线程几乎无成本**（WebView 在独立进程/合成器里跑），`engineReady=true`。
证据：`docs/qa/v8-s2-flutter-perf-win-webview.json`（探针原始输出；构建时也会落在 exe 同目录）。

---

## 3. 候选 B 能力与迁移成本（证据）

### 3.1 能力边界（本机 Flutter 3.47.2，engine `a804b261645ef8c13eb3d5c44a5c2fb0340c5539`）

| 事实 | 证据 |
| --- | --- |
| `dart:ui` 有 `Scene` / `SceneBuilder`（Impeller 场景树入口） | `flutter/bin/cache/pkg/sky_engine/lib/ui/compositing.dart`：`abstract class Scene`（L12）、`abstract class SceneBuilder`（L259） |
| 但它是 **2D layer/paint 操作栈**（pushLayer / pushTransform / pushClip / pushOpacity / pushColorFilter…） | 同上；文档注释为「objects are transformed by the given matrix before rasterization」 |
| Flutter 自身渲染就走它 | `packages/flutter/lib/src/rendering/view.dart` L11 导入、L355 `createSceneBuilder()`、L356 `layer.buildScene(builder)` |
| **没有** mesh / material / light / camera / 3D render target 等 3D 原语 | `dart:ui` 全量 grep 无 `GpuMesh` / `Texture3D` / `RenderTarget3D`；该版本未暴露 `Node`/`NodeBuilder` 保留式 API |
| 唯一可自写 GPU 着色的是 2D 片段着色器（SkSL） | `painting.dart` L5409 `base class FragmentProgram`、L5981 `base class FragmentShader` |
| 现有原生计算能力是 2D CV，不是 3D | 依赖 `dartcv4`（OpenCV）/ `opencv_dart`（解码、缩放、轮廓） |

**结论：Flutter 原生渲染无法承载本项目的 3D 场景**（灯光模型、软阴影 VSM、人物骨架、道具、相机机位、路径追踪静帧 + 景深）。要保留同等能力，等价于自研一个 3D 渲染器 —— 这不是「换架构」，是「重写产品核心」。

### 3.2 迁移成本（可数证据）

| 项 | 数量 | 说明 |
| --- | --- | --- |
| 自有引擎源码 | 12 文件 / **4,435 行** / 188.5KB | `character.js` 1,304 行、`engine.js` 1,381 行为大头 |
| three.js 调用点 | **238 处** `THREE.*` | 每处都要有原生等价实现 |
| 桥接 API 面积 | **65 个** `window.ss` 命令/事件 | `engine_bridge.dart` 与 `lighting_page.dart` 事件路由全部依赖 |
| 打包产物 | `engine.bundle.js` **1,133.7KB** + `pathtracer.bundle.js` **220.4KB** | 含 vendored three r186 + jsm |
| 不可等价能力 | 路径追踪静帧（three-gpu-pathtracer 0.0.24）、物理相机景深（`PhysicalCamera`）、VSM 软阴影、PMREM 环境 | Impeller 无对等实现 → 要么放弃（砍掉 v1.3.0 已交付的 D138/D139 能力），要么以 SkSL + 离屏渲染自行实现（工程量另计） |

---

## 4. 对比表（决策依据）

| 维度 | A：WebView2 + three r186（现状） | B：Flutter 原生渲染（Impeller Scene） |
| --- | --- | --- |
| 交互帧率 p95 | **17.4–18.4ms（60fps，长帧 0）** 独显/核显均达标 | 无 3D 原语，无法给出（本项目场景不可实现） |
| 内存 | JS 堆 12–29MB / total 43–58MB；GPU 28 纹理 | 需从零实现 3D 资源管线，未知 |
| 集成成本 | 0（现状） | 重写 4,435 行 + 238 个 three 调用 + 65 个桥接 API |
| 双端可行性 | Windows WebView2 ✅ / Android WebView ✅（已随 v1.3.0 发布） | 需自研渲染器后再谈双端 |
| 资产迁移代价 | 0 | 全部场景/预设/人物/道具逻辑重写；路径追踪与景深能力可能丢失 |
| 风险 | 软件渲染下 0.66fps → 已有 low 档回退（R69） | 高：重写期功能不可用 + 能力倒退 |
| 结论 | **保留** | **不采纳** |

---

## 5. 明确结论与后续动作

1. **架构不变**：V8 全程保留 WebView2 + three.js r186；S3–S11 的重做只动 UI 层与交互层，不动渲染技术栈。
2. **S6 必须交付的交互层重构**（本次结论带来的硬要求）：
   - 桥接批处理：高频事件（heartbeat / transform 回写 / 选中态）合并为帧级节流；
   - 事件节流：拖灯/旋转期间不做逐帧 Dart 往返；
   - 骨架屏 / 加载态：WebView 首帧与 HDR/GLB 加载期间给占位；
   - 交互帧率 p95 证据：**复用 `app/lib/dev/perf_probe.dart`** 取数（本报告 §2.1 即其首次产出）。
3. **性能预算**（S6/S11 验收口径）：在有 GPU 的机器上，拖灯/旋转/推拉 p95 ≤ 20ms、无 >50ms 长帧；核显需同样达标。
4. **低配边界**：纯软件渲染（SwiftShader）不追求交互帧率，沿用 low 档 + 超采样静帧回退。

---

## 6. 方法论与坑（复用价值）

1. **必须等稳态再采样**：首轮直接采样得到 p95 ≈ 940ms、max ≈ 1.9s 的假数据（首帧着色器编译 / HDR PMREM / GLB 加载全被算进交互帧率）。修法：循环检测 `getEngineStats().frames` 推进 + `Performance.getMetrics` 的 `TaskDuration` 增速 < 250ms/s。
2. **CDP 输入不要 await 响应**：每帧 `await Input.dispatchMouseEvent` 会把渲染线程往返时延算成帧间隔（实测 p95 虚高到 978ms）。改为 fire-and-forget + 在飞请求上限 40。
3. **headed + `--force_high_performance_gpu` 会强制独显**：想测核显必须用 `--gpumode=default`（实测该模式落到 Intel Iris Xe）；`--headless=new` 同样会用真实 GPU，不是 SwiftShader —— 要真软件渲染得显式 `--use-angle=swiftshader`。
4. **DPR 影响像素量**：headed 默认 devicePixelRatio=2，报告里必须标注，并用 `--dpr=1` 跑对照。
5. **`getEngineStats().frames` 可用但 `fps` 字段不可信**（返回 0）；统计以页面内 rAF 采样为准，两者互校（本轮 rAF 帧数与引擎帧数逐段完全一致）。
6. **Windows release 探针**：`flutter build windows --release --dart-define=SS_PERF_PROBE=1` → 需先为 17 个插件建 junction（Developer Mode 未开）；探针 JSON 落在 exe 同目录。

---

## 7. 复现命令

```powershell
# 候选 A：引擎帧率（四组配置）
cd app
node tool\engine_perf_qa.mjs --label gtx4060-dpr1 --dpr=1
node tool\engine_perf_qa.mjs --label gtx4060-dpr2 --dpr=2 --port=9995
node tool\engine_perf_qa.mjs --label default-adapter-dpr1 --gpumode=default --dpr=1 --port=9998
node tool\engine_perf_qa.mjs --label swiftshader-dpr1 --swiftshader=1 --headless=1 --dpr=1 --port=9997

# 宿主侧：Flutter + WebView2 合成成本
C:\dev\flutter\bin\flutter.bat build windows --release --no-pub --dart-define=SS_PERF_PROBE=1
$env:SS_PERF_PROBE='1'; $env:SS_PERF_PROBE_LABEL='win-webview'
& build\windows\x64\runner\Release\shoot_studio.exe
```

## 8. 证据清单

| 文件 | 内容 |
| --- | --- |
| `docs/qa/v8-s2-engine-arch-spike.md` | 本报告 |
| `docs/qa/v8-s2-engine-perf-gtx4060-dpr1.json` | 独显 DPR1：四阶段帧间隔 + CPU/帧 + 内存 + 渲染统计 |
| `docs/qa/v8-s2-engine-perf-gtx4060-dpr2.json` | 独显 DPR2（填充率对照） |
| `docs/qa/v8-s2-engine-perf-default-adapter-dpr1.json` | 核显 Iris Xe |
| `docs/qa/v8-s2-engine-perf-swiftshader-dpr1.json` | 纯软件渲染下界 |
| `docs/qa/v8-s2-flutter-perf-win-webview.json` | Flutter 宿主两阶段帧耗时（纯负载 vs +WebView2） |
| `app/tool/engine_perf_qa.mjs` | 引擎帧率测量工具 |
| `app/lib/dev/perf_probe.dart` | 宿主帧耗时探针（门控；S6 复用） |
| `app/test/dev/perf_probe_test.dart` | 探针统计口径与门禁单测（6 用例，CI 常跑） |
