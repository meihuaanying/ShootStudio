import 'core/design/tokens.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'dev/perf_probe.dart';
import 'services/app_logger.dart';
import './core/design/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // V8/S2（D156）引擎架构 spike：性能探针（仅 --dart-define=SS_PERF_PROBE=1 或环境变量 SS_PERF_PROBE=1 时启用）。
  // 正常启动路径完全不变（R79）。
  if (PerfProbeConfig.enabled) {
    runApp(const PerfProbeApp());
    return;
  }

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
  ErrorWidget.builder = (FlutterErrorDetails details) =>
      AppErrorWidget(details: details);

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
        color: AppPalette.darkroomBg,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(AppSpace.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              '页面渲染出错',
              style: TextStyle(
                color: AppPalette.darkroomInk,
                fontSize: AppFontSize.h3Lg,
                fontWeight: AppFontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '该问题已记录到本地日志，可复制错误码反馈。',
              style: TextStyle(
                color: AppPalette.darkroomMuted,
                fontSize: AppFontSize.smallLg,
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(
              '错误码：$code',
              style: const TextStyle(
                color: AppPalette.darkroomGold,
                fontSize: AppFontSize.smallLg,
                fontFamily: 'monospace',
              ),
            ),
            if (logDir.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              SelectableText(
                '日志目录：$logDir',
                style: const TextStyle(
                  color: AppPalette.darkroomMuted,
                  fontSize: AppFontSize.caption,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              constraints: const BoxConstraints(maxWidth: 720),
              padding: const EdgeInsets.all(AppSpace.s3),
              decoration: BoxDecoration(
                color: AppPalette.darkroomSurface,
                borderRadius: BorderRadius.circular(AppRadius.frame),
              ),
              child: Text(
                '${details.exception}',
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppPalette.darkroomInkSoft,
                  fontSize: AppFontSize.caption,
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
