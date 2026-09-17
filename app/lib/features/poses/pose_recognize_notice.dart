import 'package:flutter/material.dart';

/// 端上照片识别不可用提示（R21/R23；合同 §4.4 允许的降级路径）。
///
/// 本版本未集成 `pose_detection`（其依赖 OpenCV 原生库，会显著超出 APK
/// 150MB 体积预算，R22）；此处给出可读提示并引导改用内置骨架姿势或手动微调。
Future<void> showPoseRecognizeNotice(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: const Text('端上照片识别暂不可用', style: TextStyle(fontSize: 16)),
      content: const SizedBox(
        width: 380,
        child: Text(
          '本版本未集成端上识别人体骨架的模型插件：其依赖的原生库会显著增大安装包体积，'
          '超出本应用的包体预算，故降级为「内置骨架」方案。\n\n'
          '可以这样做：\n'
          '· 从 120 条实拍照片姿势中挑选最接近的一张（左侧网格，可切换骨架叠加）；\n'
          '· 导入布光预演后，在右栏「关节微调」中手动调整 12 个关节角度。',
          style: TextStyle(fontSize: 13, height: 1.6),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('知道了'),
        ),
      ],
    ),
  );
}
