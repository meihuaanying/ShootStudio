# pose3d 模型许可与来源（V7/S5 · D141）

本目录为「RTMPose/RTMW3D 端上识别」随包模型（R64：识别模型不得首次使用时下载）。

## 模型清单

| 文件 | 体积 | 说明 |
|---|---|---|
| `rtmw3d-x-fp16.onnx.part0` / `.part1` | 各 92,394,513 B | RTMW3D-x（3D 关键点）**fp16 权重、IO 保持 float32**；拼装后 184,789,026 B，SHA256 `2ca95a4ab47b9711c4900ec7f746122aa9e741b5b6caf8b487940856b1187bec` |
| `yolox_tiny.onnx` | 20,219,662 B | YOLOX-tiny 人体检测（ONNX，416×416）；SHA256 `427cc366d34e27ff7a03e2899b5e3671425c262ea2291f88bb942bc1cc70b0f7` |

分片原因：GitHub 单文件 100 MiB 限制；拼装逻辑见 `lib/services/pose3d/pose3d_assembly.dart`（首次使用时拼装到应用支持目录，已存在且尺寸正确则跳过）。

## 来源与许可

| 模型 | 来源 | 许可 | 备注 |
|---|---|---|---|
| RTMW3D-x（`rtmw3d-x_8xb64_cocktail14-384x288-b0a0eab7_20240626.onnx`） | HuggingFace `Soykaf/RTMW3D-x`（hf-mirror 通道下载）；上游 OpenMMLab [mmpose](https://github.com/open-mmlab/mmpose) `projects/rtmpose3d` | **Apache-2.0** | 由 PyTorch 导出；fp16 转换（onnxconverter-common，`keep_io_types=True`）由本项目执行，精度损失 12 关节角均差 0.16°（见 `docs/qa/rtmpose-spike-quant.json`） |
| YOLOX-tiny（`yolox_tiny.onnx`） | HuggingFace `hr16/yolox-onnx`（hf-mirror 通道下载）；上游 [Megvii YOLOX](https://github.com/Megvii-BaseDetection/YOLOX) | **Apache-2.0** | ONNX 导出（YOLOX 官方 ONNXRuntime demo 格式） |

- 许可全文：Apache License 2.0 <https://www.apache.org/licenses/LICENSE-2.0>
- 精度/耗时/量化对照：`docs/qa/rtmpose-spike-report.md`、`docs/qa/rtmpose-spike-{specs,infer,angle,detectors,quant,bench,bench-dml}.json`
- 端上运行库：`flutter_onnxruntime`（MIT，内置 ONNX Runtime；Windows 由插件 CMake 下载 ORT 官方 release，Android 使用 `com.microsoft.onnxruntime:onnxruntime-android`）
