// V8/S6 · D152：布光预演的落盘 IO（诊断包 zip / 效果预览图）。
//
// 原本内联在布光预演页里，让页面体积逼近行数门禁；抽出为顶层函数便于单测与复用。
// 依赖注入（Workspace / 状态 / 引擎桥）→ 纯 IO，不碰 UI 状态。

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

import '../../core/workspace/workspace.dart';
import '../../services/app_logger.dart';
import '../../services/engine/engine_bridge.dart';
import '../../services/image_store.dart';
import 'lighting_controller.dart';

/// 导出诊断包（app.log + engine-stats.json + scene.json + env.json）到工作区
/// `diagnostics/diag-<时间戳>.zip`，返回 zip 路径。失败抛异常由调用方提示。
Future<String> exportLightingDiagnostics({
  required Workspace workspace,
  required LightingState state,
  EngineBridge? bridge,
}) async {
  final DateTime now = DateTime.now();
  final String stamp =
      '${now.year}'
      '${now.month.toString().padLeft(2, '0')}'
      '${now.day.toString().padLeft(2, '0')}-'
      '${now.hour.toString().padLeft(2, '0')}'
      '${now.minute.toString().padLeft(2, '0')}'
      '${now.second.toString().padLeft(2, '0')}';
  final Directory dir = Directory(
    path.join(workspace.root.path, 'diagnostics', 'diag-$stamp'),
  );
  await dir.create(recursive: true);

  // 1) 应用日志（引擎控制台 / JS 错误均已写入）。
  final File log = File(path.join(AppLogger.I.logDir, 'app.log'));
  if (await log.exists()) {
    await log.copy(path.join(dir.path, 'app.log'));
  }

  // 2) 引擎统计（缓存/内存/FPS）。
  final Object? engineStats = await bridge?.evaluate(
    'JSON.stringify(window.ss && window.ss.getEngineStats ? window.ss.getEngineStats() : null)',
  );
  await File(
    path.join(dir.path, 'engine-stats.json'),
  ).writeAsString('${engineStats ?? 'null'}');

  // 3) 当前布光场景。
  await File(path.join(dir.path, 'scene.json')).writeAsString(
    const JsonEncoder.withIndent('  ').convert(
      state.scene.toEngineJson(
        poseJoints: state.pendingPose,
        hands: state.scene.hands,
      ),
    ),
  );

  // 4) 环境信息。
  await File(path.join(dir.path, 'env.json')).writeAsString(
    const JsonEncoder.withIndent('  ').convert(<String, Object?>{
      'os': Platform.operatingSystem,
      'osVersion': Platform.operatingSystemVersion,
      'processors': Platform.numberOfProcessors,
      'dartVersion': Platform.version,
      'viewMode': state.viewMode,
      'materialPreset': state.materialPreset,
      'subdivision': state.subdivisionLevel,
      'ambientEnabled': state.ambientEnabled,
      'contactShadow': state.contactShadow,
      'exportedAt': now.toIso8601String(),
    }),
  );

  // 5) 打包 zip。
  final Archive archive = Archive();
  for (final FileSystemEntity entity in dir.listSync()) {
    if (entity is File) {
      archive.addFile(
        ArchiveFile(
          path.basename(entity.path),
          entity.lengthSync(),
          entity.readAsBytesSync(),
        ),
      );
    }
  }
  final File zip = File(
    path.join(workspace.root.path, 'diagnostics', 'diag-$stamp.zip'),
  );
  await zip.writeAsBytes(ZipEncoder().encode(archive)!, flush: true);
  return zip.path;
}

/// 保存「保存预览图 / 出片」的 PNG dataURL 到工作区 `images/plans/`，返回文件名。
Future<String> saveLightingPreview({
  required Workspace workspace,
  required String dataUrl,
}) async {
  final String base64Part = dataUrl.contains(',')
      ? dataUrl.split(',').last
      : dataUrl;
  final List<int> bytes = base64Decode(base64Part);
  final Directory dir = Directory(
    path.join(workspace.root.path, 'images', 'plans'),
  );
  await dir.create(recursive: true);
  final String name = '布光预览_${DateTime.now().millisecondsSinceEpoch}.png';
  await File(path.join(dir.path, name)).writeAsBytes(bytes);
  return name;
}

/// 选一张贴图 → 压到 160KB/512px → 返回 `data:image/jpeg;base64,…`；
/// 用户取消返回 null，处理失败抛异常由调用方提示。
Future<String?> pickTextureDataUrl() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    dialogTitle: '选择贴图图片',
  );
  final String? filePath = result?.files.single.path;
  if (filePath == null) return null;
  final Uint8List raw = await File(filePath).readAsBytes();
  final Uint8List compressed = ImageStore.compress(
    raw,
    maxKb: 160,
    maxEdge: 512,
  );
  return 'data:image/jpeg;base64,${base64Encode(compressed)}';
}

/// 「落盘动作 + 状态/提示」通用包装：成功与失败都写到 controller status，
/// 并回调页面给 toast（页面里几处 IO 动作共用同一套提示口径）。
Future<void> runLightingFileAction({
  required Future<String> Function() action,
  required String Function(String result) successStatus,
  required String Function(Object error) failureStatus,
  required void Function(String message) onStatus,
  required void Function(String message) onToast,
}) async {
  try {
    final String result = await action();
    onStatus(successStatus(result));
    onToast(successStatus(result));
  } catch (e) {
    onStatus(failureStatus(e));
    onToast(failureStatus(e));
  }
}
