# RTMPose/RTMW3D spike 报告（V7/S5 · D141）

> 日期：2026-09-24 ｜ 结论：**可行**（RTMW3D-x ONNX + YOLOX ONNX，均 Apache-2.0；随包方案 = **fp16 转换** + 小型检测器）
> 产物：`app/tool/rtmpose_spike.py`（spike 脚本，含 fetch/specs/infer/compare/detcompare/quantize/bench）
> 证据：`docs/qa/rtmpose-spike-{specs,infer,angle,detectors,quant,bench,bench-dml}.json`（本机实测，RTX 4060 Laptop + i7；Windows 11）

## 1. 模型来源、许可与下载通道

| 项 | 结果 |
|---|---|
| 通道 | `huggingface.co` 本机**不可达**（超时）；`hf-mirror.com` **可达（HTTP 200，整包下载字节数与 API 声明一致）** |
| 姿态模型 | `Soykaf/RTMW3D-x` → `onnx/rtmw3d-x_8xb64_cocktail14-384x288-b0a0eab7_20240626.onnx`，**369,330,857 B（352.2 MiB）**，许可 **apache-2.0**（模型卡：Converted from mmpose `projects/rtmpose3d`，配套 rtmlib） |
| 备镜像 | `bukuroo/RTMW3D-ONNX`（`rtmw3d-x-384.onnx`，**字节数完全相同**，apache-2.0） |
| 检测模型 | `hr16/yolox-onnx`（apache-2.0，reupload 自 Megvii-BaseDetection/YOLOX ONNXRuntime demo）：nano **3.66MB** / tiny **20.2MB** / s **35.9MB** / m **101.3MB** / l **216.7MB** |
| 许可结论 | 两者均可随包（R63/R64）；随包时在 `assets/engine/NOTICE.md` 同类位置登记 RTMW3D/mmpose 与 YOLOX 署名及许可文本 |

## 2. ONNX 规格与参考实现（Dart 端必须逐字移植的口径）

### 2.1 RTMW3D-x IO

- 输入 `input`：float32 `[1,3,384,288]`（NCHW，H=384，W=288）。
- 输出：`output` `[1,133,576]`（simcc_x，Wx=288×2）、`1554` `[1,133,768]`（simcc_y，Wy=384×2）、`1556` `[1,133,576]`（simcc_z）。

### 2.2 预处理（rtmlib `RTMPose3d.preprocess` + `pre_processings.py`）

1. `bbox_xyxy2cs(padding=1.25)`：`center=((x1+x2)/2,(y1+y2)/2)`，`scale=(w*1.25,h*1.25)`。
2. 3:4 等比扩展（`top_down_affine`）：`w0>h0*0.75` → `(w0, w0/0.75)`，否则 `(h0*0.75, h0)`。
3. 仿射到 **288×384**（`cv2.warpAffine`，`INTER_LINEAR`，默认 `BORDER_CONSTANT` 0 = 黑边；等价于「按 `scale` 裁剪后双线性缩放」，均匀比例 = 288/src_w）。
4. 归一化：`(x - mean) / std`，`mean=(123.675,116.28,103.53)`，`std=(58.395,57.12,57.375)`。
5. **通道顺序 = BGR**（rtmlib 不做 BGR→RGB 交换，实测全库无 `cvtColor/::-1` 转换）→ Dart 端若解码为 RGB，必须先交换 R/B（否则与 Python 参考不一致）。

### 2.3 后处理（rtmlib `RTMPose3d.postprocess`）

- `locs = argmax(simcc_*)`（逐轴），`vals = min(max_val_x, max_val_y)`；`vals<=0` 的关键点置 `-1`。
- `keypoints = locs / 2.0` → x/y 为 **crop 像素**（288×384 空间），z 为原始 simcc 值。
- **z 换算**：`z_m = (z / (384/2) - 1) * 2.1744869`（`z_range` 默认 2.1744869）。
- 2D 重投影（骨架叠加用）：`kp2d = kp_xy / (288,384) * scale + center - 0.5*scale`。
- 实测坐标约定：x/y crop 像素；z 为米级、**负值朝相机**（与 MediaPipe world z 同向）。

### 2.4 133 → BlazePose 33 子集与 12 关节

- 映射（spike 脚本 `MAP33`）：nose 0；ears 3/4；shoulders 5/6；elbows 7/8；wrists 9/10；index 99/120；hips 11/12；knees 13/14；ankles 15/16；heel 19/22；big toe 17/20。
- **米制尺度 s（m/crop-px）**：由骨长先验中位数估计（humerus 0.316 / forearm 0.248 / thigh 0.417 / shank 0.418 / shoulder width 0.44 / hip width 0.325 m；`s_i = sqrt(max(p²-dz²,0.01))/dxy`，取中位数；实测 0.0042–0.0069）。
- `world33 = [x*s, y*s, z] - 髋中心`（y 向下，与 `skeleton_to_joints.WORLD_UP=[0,-1,0]` 一致）→ 直接复用现有 `derive()`/Dart `deriveJoints()` 得 12 关节 + rootY/rootPitch（`rootY=(max_y-hip_y)-0.96`，clamp [-1.15,0.6]）。

## 3. 实测（本机，CPU EP）

| 项 | 结果 |
|---|---|
| 端到端 | 检测框合理（p001 `[208.5,93.0,536.2,1045.5]`）；2D 重投影与图像吻合；`scale` 估计稳定（n=10 条骨全部有效） |
| 纯推理延迟（ORT 1.30 CPU，5 次中位数） | fp32 **600.9ms**；fp16 609.7ms；static-int8 400.4ms；dynamic-int8 3307.4ms（`rtmpose-spike-bench.json`） |
| 端到端耗时（同机负载波动大） | 检测 0.03–1.3s + 姿态 0.3–2.2s/图；空闲时 fp32 姿态 ≈150ms（ORT 1.24.4 CPU 实测） |

## 4. 精度对比（RTMW3D-x vs 现有 poses3.json 的 MediaPipe 参考）

`rtmpose-spike-angle.json`（p001 站姿 / p013 坐姿 / p025 蹲姿 / p037 动态，144 个关节角）：

| 指标 | 值 |
|---|---|
| 均差 | **20.13°** |
| ≤5° / ≤10° 占比 | **35.4% / 43.8%** |

- **口径说明（重要）**：D141 门禁 `q6_pose_accuracy` 衡量的是「端上移植 vs Python 参考」的一致性（D128 现为均值 14.48° / 67.0% ≤10°），**不是**两个模型之间的差异。两模型差异大 → 若把参考库管线整体切到 RTMW3D，需按 R68 全量重跑骨架/关节/QA（S5 主体阶段决策）。

## 5. 检测器选项（对 yolox_m 参考框的 IoU，6 张实测）

| 模型 | 体积 | IoU 均值（最小） | 中位耗时 | COCO AP（论文） |
|---|---|---|---|---|
| yolox_s | 35.9MB | 0.882（0.629） | 533ms | 40.5 |
| yolox_tiny | 20.2MB | 0.881（0.637） | 232ms | 32.8 |
| yolox_nano | 3.66MB | 0.875（0.646） | 33ms | 25.8 |

- 结论：三者在「单主体全身照」上框差异小（IoU≥0.87）；**建议随包 `yolox_tiny`（20.2MB）**（对导入的任意场景更稳），`yolox_nano` 可作为轻量档；接口一致，后续可无痛替换 `yolox_s/m`。
- 注意：`yolox_tiny/nano` 的 ONNX 输入固定 **416×416**（`yolox_m` 为 640×640）→ 代码需按模型读取输入尺寸（spike 脚本已实现）。

## 6. 量化与 fp16（`rtmpose-spike-quant.json`）

| 变体 | 体积 | 关键点偏差（xy 均 / z 均） | 12 关节角偏差（均 / 最大） | 结论 |
|---|---|---|---|---|
| fp32（基准） | 352.2 MB | — | — | 基准 |
| dynamic int8 | 92.9 MB | 154.83 px / 0.093 m | **48.73° / 220.84°** | ❌ 不可用（精度崩溃 + 更慢） |
| static int8（30 张真图校准，QDQ per-channel） | 93.9 MB | 11.65 px / 0.061 m | **22.66° / 175.58°** | ❌ 不可用（仍远超 5° 门禁） |
| **fp16（keep_io_types）** | **184.8 MB** | **0.02 px / 0.000 m** | **0.16° / 8.88°** | ✅ **推荐随包**（体积 −47.5%，精度等价） |

- fp16 模型在 ORT **1.24.4 / 1.30**（CPU EP）均可加载并推理，IO 仍为 float32（`keep_io_types=True`，Dart 端无需改喂数据）。
- 静态 int8 的校准集用真实姿态照裁剪（与推理同预处理）；如需更小体积只能走「DML + fp16」或换小模型，不推荐继续压 int8。

## 7. 执行提供者（EP）与运行库

| 环境 | CPU | DirectML |
|---|---|---|
| ORT 1.30（主环境，仅 CPU/Azure） | fp32 600.9 / fp16 609.7 / static 400.4 / dyn 3307.4 ms | — |
| ORT 1.24.4 + `onnxruntime-directml` | fp32 264.4 / fp16 385.5 / static 93.9 / dyn 3923.6 ms | fp32 **26.3** / **fp16 8.7** / static 44.5 / dyn 39.7 ms |

- `flutter_onnxruntime 1.8.5`（pub.dev，MIT，内置 **ORT 1.23.0**）**Windows 不支持 DML**：其 `windows/CMakeLists.txt` 固定下载官方 **CPU** 版压缩包；插件源码只接受 providers `"CPU"/"CUDA"`（其他返回 `INVALID_PROVIDER`）。→ **端上高精度路径 = CPU EP**（fp16/fp32 均可）；DML 仅 Python 侧可用（≈57× 加速，作为未来「自编译 ORT + 自写绑定」的备选，登记为后续项）。
- 插件 FP16 支持矩阵：Android/iOS/macOS ✅、Linux/Windows/Web「计划中」——本方案 `keep_io_types=True` 使 IO 保持 fp32，**模型权重 fp16 由 CPU EP 自动插 cast**（已在 1.24.4/1.30 验证）；Windows 插件实测验证放到 S5 主体（失败则回退 fp32 或 MediaPipe，R69）。
- 其他插件约束：Android 需 `android/app/proguard-rules.pro` 加 `-keep class ai.onnxruntime.** { *; }`。

## 8. 集成方案（S5 主体）

1. **随包（R64）与 GitHub 100 MiB 单文件限制**：fp16 模型 184,789,026 B **超过 GitHub 单文件 100 MiB 硬限制**（fp32 352MB 更不可能）。采用 **分片随包 + 首次使用本地拼装**（已实测，见 `rtmpose-spike-split.json`）：
   - `app/assets/models/pose3d/rtmw3d-x-fp16.onnx.part0` / `.part1`（各 92,394,513 B，< 100 MiB）入库；`yolox_tiny.onnx`（20.2MB）单文件入库。
   - 首次识别时把分片按序拼装为 `<应用支持目录>/models/rtmw3d-x-fp16.onnx`（校验总字节数，已存在则跳过），再 `createSession(path)`；**无任何网络请求**（R64 语义：随包而非下载）。
   - 实测：拼装耗时 0.23s（本机 SSD），拼装文件 SHA256 与原文件一致（`2ca95a4a…87bec`），ORT 加载后三个输出与原文件 **逐元素完全相同**（max abs diff = 0.0）。
   - 备选（已评估未采用）：Git LFS（CI 免费额度 1GB/月，单次 checkout 即耗 185MB，风险高）；int8（精度不达标）；RTMW3D-L（无现成 ONNX；`download.openmmlab.com` 404）；2D RTMW（`Izymka/rtmw-dw-x-l` 218.7MiB / LiteRT `RTMW-m` 63MB tflite）无 z 输出，会破坏 3D 关节推导。
2. **新服务**：YOLOX 检测（按模型读输入尺寸）→ RTMW3D 3D（2.2/2.3 口径）→ MAP33 + 骨长先验尺度 → 现有 `deriveJoints()` 12 关节 + 接地校准；`flutter_onnxruntime` 依赖（`OrtSessionOptions(providers: [OrtProvider.CPU])`，`OrtValue.fromList`）。
3. **回退（R69）**：模型缺失/加载失败/低配 → 保留现有 MediaPipe 路径（`pose_detection` 包），设置页「识别后端」沿用 S2 的四态（自动/CPU/GPU）。
4. **离线 fixture（R62）**：纯 Dart 单测覆盖 2.2/2.3/2.4 的数学（仿射、归一化、simcc 解码、尺度估计、MAP33），加一个**微型 ONNX fixture**（几十 KB，验证 ORT 管道与张量形状）；真实模型测试用环境变量门控（`SS_POSE_ACCURACY=1`，同现有模式）。
5. **门禁**：`q6_pose_accuracy` 重跑「端上 vs Python」一致性（冲均值 ≤5° / 90% ≤10°，或按偏差登记）；`q6_pose_test` 导入契约保持绿。

## 9. 偏差与风险登记

1. **口径**：D141 的「≤5°/90%≤10°」是**移植一致性**指标（端上 vs Python 同模型），非模型间差异；spike 的 20.13° 对比数据仅供决策参考。
2. **DML 不可用（Windows 插件）**：端上仅 CPU EP；fp32 空闲 ≈150ms/图、fp16 ≈400–600ms/图（负载相关），导入一张照片含检测约 1–3s 可接受；若需 GPU 加速需自编译 ORT（登记为后续项）。
3. **fp16 在 Windows 插件「计划中」**：以 `keep_io_types` 规避 IO 类型问题，S5 主体需真机验证；失败回退 fp32（体积 ×1.9）或 MediaPipe。
4. **体积**：随包 +205MB（fp16 + tiny）——D95 不限包体，但 S7 必须记录 APK 体积（R65）。
5. **int8 路线关闭**：动态/静态 int8 精度不达标（22.7–48.7°），不再尝试（除非未来做逐层混合量化）。
6. **预处理易错点**：BGR 通道顺序、1.25 padding、3:4 扩展、黑边填充、`locs/2`、`z_range=2.1744869` —— Dart 端移植需逐项对齐（fixture 单测覆盖）。
7. **分片拼装成本**：首次识别需将 2×92.4MB 分片写入应用支持目录（本机 0.23s；移动端预计数秒 + 185MB 磁盘占用）；实现时需做「目标文件已存在且字节数正确则跳过」与失败回退（R69）。
