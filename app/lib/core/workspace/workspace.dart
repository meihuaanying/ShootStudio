import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 工作区：本地优先存储的根目录（D2）。
/// Windows: `<Documents>/ShootStudio` ｜ Android: `<应用文档目录>/workspace`
/// 目录结构与 PRD §6.4 一致：database.sqlite + exports/ + images/<五库+refs+plans>
final class Workspace {
  Workspace._(this.root);
  final Directory root;

  static Workspace? _instance;
  static Workspace get I =>
      _instance ??= throw StateError('Workspace 未初始化，请先调用 Workspace.init()');

  static Future<Workspace> init() async {
    if (_instance != null) return _instance!;
    final base = await getApplicationDocumentsDirectory();
    final root = Directory(
        p.join(base.path, Platform.isWindows ? 'ShootStudio' : 'workspace'));
    return _open(root);
  }

  /// 在指定目录打开/创建工作区（PRD M4：用户首次启动指定本地目录）。
  static Future<Workspace> initAt(String path) async {
    if (_instance != null && _instance!.root.path == path) return _instance!;
    return _open(Directory(path));
  }

  static Future<Workspace> _open(Directory root) async {
    await root.create(recursive: true);
    final ws = Workspace._(root);
    for (final dir in Workspace.imageDirs.values) {
      await Directory(p.join(root.path, dir)).create(recursive: true);
    }
    await Directory(ws.exportsPath).create(recursive: true);
    _instance = ws;
    return ws;
  }

  /// 目录可写校验（PRD 边界：无写入权限时引导重新选择）。
  static Future<bool> isWritable(String path) async {
    try {
      final dir = Directory(path);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final probe = File(p.join(path, '.write_probe'));
      await probe.writeAsString('ok');
      await probe.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  String get dbPath => p.join(root.path, 'database.sqlite');
  String get exportsPath => p.join(root.path, 'exports');
  String get configPath => p.join(root.path, 'config.json');

  /// 五大资源库 + 参考画板 + 策划案素材的图片目录
  static const Map<String, String> imageDirs = {
    'models': 'images/models',
    'locations': 'images/locations',
    'clothing': 'images/clothing',
    'props': 'images/props',
    'makeup': 'images/makeup',
    'refs': 'images/refs',
    'plans': 'images/plans',
  };

  String imagePathOf(String category, String fileName) {
    final dir = imageDirs[category] ?? 'images/misc';
    return p.joinAll(<String>[root.path, ...dir.split('/'), fileName]);
  }
}
