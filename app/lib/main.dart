import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'services/app_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 全局异常兜底（F5）：先于任何 UI 初始化，保证首帧崩溃也有日志与错误页。
  final logger = await AppLogger.init();
  FlutterError.onError = (FlutterErrorDetails details) {
    logger.error(details.exception, stack: details.stack, tag: 'flutter');
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    logger.error(error, stack: stack, tag: 'platform');
    return true;
  };
  ErrorWidget.builder =
      (FlutterErrorDetails details) => AppErrorWidget(details: details);

  // 桌面窗口规范（F5/F8）：标题、默认与最小尺寸、居中、尺寸记忆。
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    try {
      await windowManager.ensureInitialized();
      const WindowOptions options = WindowOptions(
        size: Size(1440, 900),
        minimumSize: Size(1100, 720),
        center: true,
        title: '正片工坊 ShootStudio',
        titleBarStyle: TitleBarStyle.normal,
        skipTaskbar: false,
      );
      await windowManager.waitUntilReadyToShow(options, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    } catch (e, st) {
      logger.error(e, stack: st, tag: 'window');
    }
  }

  runApp(const ProviderScope(child: ShootStudioApp()));
}

/// 友好错误页（替代 release 灰屏）：错误码可复制 + 日志目录提示 + 重试入口。
class AppErrorWidget extends StatelessWidget {
  const AppErrorWidget({super.key, required this.details});

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    final code = AppLogger.codeOf(details.exception);
    final logDir = AppLogger.I.logDir;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        color: const Color(0xFF0B0E14),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              '页面渲染出错',
              style: TextStyle(
                  color: Color(0xFFE8EAF0),
                  fontSize: 18,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              '该问题已记录到本地日志，可复制错误码反馈。',
              style: TextStyle(color: Color(0xFF8A919E), fontSize: 13),
            ),
            const SizedBox(height: 12),
            SelectableText(
              '错误码：$code',
              style: const TextStyle(
                color: Color(0xFF4D6BFE),
                fontSize: 13,
                fontFamily: 'monospace',
              ),
            ),
            if (logDir.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              SelectableText(
                '日志目录：$logDir',
                style: const TextStyle(color: Color(0xFF8A919E), fontSize: 11),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              constraints: const BoxConstraints(maxWidth: 720),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF161B25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${details.exception}',
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFB9BEC8),
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
