import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 应用引导配置：记录用户选择的工作区路径（PRD M4「首次启动指定本地目录」）。
/// 存于系统应用支持目录，与工作区解耦，保证工作区可整体迁移。
final class AppBootstrap {
  AppBootstrap._();

  static const String _fileName = 'bootstrap.json';

  static Future<File> _configFile() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(support.path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File(p.join(dir.path, _fileName));
  }

  /// 读取已保存的工作区路径；未设置或损坏时返回 null。
  static Future<String?> readWorkspacePath() async {
    try {
      final file = await _configFile();
      if (!await file.exists()) return null;
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map) return null;
      final path = raw['workspacePath'];
      if (path is! String || path.trim().isEmpty) return null;
      if (!await Directory(path).exists()) return null;
      return path;
    } catch (_) {
      return null;
    }
  }

  static Future<void> writeWorkspacePath(String path) async {
    final file = await _configFile();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'workspacePath': path,
        'updatedAt': DateTime.now().toIso8601String(),
      }),
    );
  }

  /// 默认工作区路径：Windows 文档目录 / 移动端应用文档目录。
  /// 平台通道不可用（如测试宿主、受限环境）时降级到系统临时目录，保证引导页可用。
  static Future<String> defaultWorkspacePath() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      return p.join(
          docs.path, Platform.isWindows ? 'ShootStudio' : 'workspace');
    } catch (_) {
      return p.join(Directory.systemTemp.path, 'ShootStudio');
    }
  }
}
