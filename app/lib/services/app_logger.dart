import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 应用日志（F5）：写入应用支持目录 logs/app.log，供错误页与设置页定位问题。
/// release 下任何未捕获异常都会落盘，不再出现"无信息灰屏"。
class AppLogger {
  AppLogger._(this._file, this.logDir);

  static AppLogger? _instance;
  static AppLogger get I => _instance ??= AppLogger._(null, '');
  static bool _initialized = false;

  final File? _file;
  final String logDir;

  static const int _maxBytes = 512 * 1024;

  static Future<AppLogger> init() async {
    if (_initialized) return _instance!;
    try {
      final support = await getApplicationSupportDirectory();
      final dir = Directory(p.join(support.path, 'logs'));
      await dir.create(recursive: true);
      final file = File(p.join(dir.path, 'app.log'));
      final logger = AppLogger._(file, dir.path);
      _instance = logger;
      _initialized = true;
      logger.info('==== app start ====', tag: 'boot');
      return logger;
    } catch (_) {
      final logger = AppLogger._(null, '');
      _instance = logger;
      _initialized = true;
      return logger;
    }
  }

  void info(String message, {String tag = 'app'}) =>
      _write('INFO ', tag, message);

  void error(Object error, {StackTrace? stack, String tag = 'app'}) {
    _write('ERROR', tag, '$error');
    if (stack != null) {
      _write('TRACE', tag, stack.toString());
    }
  }

  void _write(String level, String tag, String message) {
    final line =
        '${DateTime.now().toIso8601String()} [$level] [$tag] $message${Platform.lineTerminator}';
    if (kDebugMode) {
      debugPrint(line.trimRight());
    }
    final file = _file;
    if (file == null) return;
    try {
      if (file.existsSync() && file.lengthSync() > _maxBytes) {
        file.writeAsStringSync('', mode: FileMode.write); // 简单截断，避免无限增长。
      }
      file.writeAsStringSync(line, mode: FileMode.append, flush: false);
    } catch (_) {
      // 日志写入失败不影响主流程。
    }
  }

  /// 错误码（供错误页展示与用户反馈定位）。
  static String codeOf(Object error) {
    final raw = error.hashCode.toRadixString(36).toUpperCase();
    return 'E${raw.padLeft(6, '0')}';
  }
}
