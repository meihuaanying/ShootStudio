import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// 测试环境路径 Mock（F15/F16）：
/// flutter_test 不注册平台插件，path_provider 需用方法通道 Mock 提供临时目录。
class TestEnv {
  TestEnv._();

  static late Directory root;

  static Future<void> install({Directory? base}) async {
    root = base ?? await Directory.systemTemp.createTemp('ss_test_env_');
    final TestDefaultBinaryMessenger messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async {
        final Directory dir = Directory(p.join(root.path, call.method));
        await dir.create(recursive: true);
        return dir.path;
      },
    );
  }

  static Future<void> dispose() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  }
}
