import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../core/design/widgets.dart';
import '../app_logger.dart';
import 'engine_bridge.dart';
import 'engine_reload.dart';

/// 3D 引擎视图：打包 three.js 单页经 WebView 加载（Windows WebView2 / Android WebView）。
/// 未就绪或加载失败时给出可重试的降级面板，不影响其它功能（本地优先原则）。
/// V6/R41–R43：错误分级（仅致命错误降级）、心跳监控、控制台日志落盘、自动重载。
class EngineView extends StatefulWidget {
  const EngineView({
    super.key,
    this.onEvent,
    this.onBridgeReady,
    this.backgroundColor,
    this.onExportDiagnostics,
  });

  final void Function(EngineEvent event)? onEvent;
  final void Function(EngineBridge bridge)? onBridgeReady;
  final Color? backgroundColor;

  /// V6/D103：错误面板上的「导出诊断包」入口。
  final Future<void> Function()? onExportDiagnostics;

  @override
  State<EngineView> createState() => _EngineViewState();
}

class _EngineViewState extends State<EngineView> {
  static const Duration _heartbeatTimeout = Duration(seconds: 20);
  static const int _maxAutoRecover = 2;

  late final EngineBridge _bridge = EngineBridge();
  StreamSubscription<EngineEvent>? _sub;
  bool _ready = false;
  bool _failed = false;
  Timer? _timeout;
  Timer? _healthTimer;
  DateTime? _lastHeartbeatAt;
  int _recoverAttempts = 0;
  Key _webviewKey = UniqueKey();
  bool _lastActive = true;

  /// 测试环境（flutter_test / golden）不创建平台视图，显示稳定占位（F16）。
  bool get _isTestEnv =>
      !kIsWeb && Platform.environment['FLUTTER_TEST'] == 'true';

  @override
  void initState() {
    super.initState();
    engineReloadTick.addListener(_onExternalReload);
    _sub = _bridge.events.listen((EngineEvent e) {
      if (e is EngineReady) {
        _timeout?.cancel();
        _recoverAttempts = 0;
        _lastHeartbeatAt = DateTime.now();
        setState(() => _ready = true);
        // 应用当前可见性（隐藏页暂停渲染）。
        _bridge.setPaused(!_lastActive);
        AppLogger.I.info('引擎就绪', tag: 'engine');
        _captureGpuRenderer();
      }
      if (e is EngineHeartbeat) {
        _lastHeartbeatAt = DateTime.now();
      }
      if (e is EngineConsole) {
        if (e.level == 'error') {
          AppLogger.I.error(e.message, tag: 'engine-console');
        } else {
          AppLogger.I.info(e.message, tag: 'engine-console');
        }
      }
      if (e is EngineErrorEvent) {
        AppLogger.I.error(
          '${e.fatal ? '致命' : '局部'}错误[${e.source}]：${e.message}',
          tag: 'engine',
        );
        if (e.fatal) {
          // V6/R41：仅致命错误降级整体面板；局部错误只落盘并由页面提示。
          setState(() => _failed = true);
        }
      }
      widget.onEvent?.call(e);
    });
    _timeout = Timer(const Duration(seconds: 12), () {
      if (mounted && !_ready) setState(() => _failed = true);
    });
    _healthTimer = Timer.periodic(const Duration(seconds: 5), (Timer _) {
      _checkHealth();
    });
  }

  @override
  void dispose() {
    engineReloadTick.removeListener(_onExternalReload);
    _timeout?.cancel();
    _healthTimer?.cancel();
    _sub?.cancel();
    _bridge.dispose();
    super.dispose();
  }

  /// V7/D135：外部请求重载（显卡设置切换）→ 重建 WebView。
  void _onExternalReload() {
    if (mounted) {
      _restartWebView(logMessage: '外部请求重载（显卡设置变更）');
    }
  }

  /// V7/D135：引擎就绪后读取 GPU 渲染器字符串，供设置页校验切换是否生效。
  Future<void> _captureGpuRenderer() async {
    try {
      final Object? stats = await _bridge.evaluate(
        'window.ss && window.ss.getEngineStats ? window.ss.getEngineStats() : null',
      );
      if (stats is Map) {
        final Object? gpu = stats['gpu'];
        if (gpu is Map) {
          final String renderer = '${gpu['renderer'] ?? ''}'.trim();
          if (renderer.isNotEmpty) engineGpuRenderer.value = renderer;
        }
      }
    } catch (_) {
      // 引擎未暴露统计信息时忽略（不影响渲染）。
    }
  }

  /// V6/R43/D102：心跳超时（引擎假死/进程崩溃）→ 自动重建 WebView 并重放场景；
  /// 连续失败超过上限才降级面板。
  void _checkHealth() {
    if (!mounted || !_ready || _failed || !_lastActive) return;
    final DateTime? last = _lastHeartbeatAt;
    if (last == null) return;
    if (DateTime.now().difference(last) <= _heartbeatTimeout) return;
    AppLogger.I.error(
      '渲染心跳超时（${_heartbeatTimeout.inSeconds}s 无心跳），尝试自动重载（第 ${_recoverAttempts + 1} 次）',
      tag: 'engine',
    );
    if (_recoverAttempts >= _maxAutoRecover) {
      setState(() => _failed = true);
      return;
    }
    _recoverAttempts++;
    _restartWebView(logMessage: '心跳超时自动重载');
  }

  void _restartWebView({required String logMessage}) {
    AppLogger.I.info(logMessage, tag: 'engine');
    setState(() {
      _failed = false;
      _ready = false;
      _lastHeartbeatAt = DateTime.now();
      _webviewKey = UniqueKey();
    });
    _timeout?.cancel();
    _timeout = Timer(const Duration(seconds: 12), () {
      if (mounted && !_ready) setState(() => _failed = true);
    });
  }

  void _retry() {
    _recoverAttempts = 0;
    _restartWebView(logMessage: '手动重新加载引擎');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_isTestEnv) {
      return Container(
        color:
            widget.backgroundColor ?? theme.colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: const Text(
          '3D 引擎（测试环境占位）',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    }
    // 隐藏页暂停渲染（F5）：随 TickerMode 变化同步到引擎。
    final active = TickerMode.valuesOf(context).enabled;
    if (active != _lastActive) {
      _lastActive = active;
      WidgetsBinding.instance.addPostFrameCallback((Duration _) {
        _bridge.setPaused(!active);
      });
    }
    if (_failed) {
      return Container(
        color:
            widget.backgroundColor ?? theme.colorScheme.surfaceContainerHighest,
        child: SsEmpty(
          icon: Icons.threed_rotation_outlined,
          title: '3D 引擎未就绪',
          hint:
              'Windows 需要 WebView2 Runtime（Win11 与新版 Win10 已内置）；Android 需要系统 WebView。'
              '其余功能不受影响。',
          action: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SsButton(
                label: '重新加载引擎',
                icon: Icons.refresh_rounded,
                kind: SsButtonKind.ghost,
                onPressed: _retry,
              ),
              if (widget.onExportDiagnostics != null) ...<Widget>[
                const SizedBox(width: 8),
                SsButton(
                  label: '导出诊断包',
                  icon: Icons.bug_report_outlined,
                  kind: SsButtonKind.ghost,
                  onPressed: () => widget.onExportDiagnostics?.call(),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Stack(
      children: <Widget>[
        InAppWebView(
          key: _webviewKey,
          initialFile: 'assets/engine/engine.html',
          initialSettings: InAppWebViewSettings(
            transparentBackground: false,
            verticalScrollBarEnabled: false,
            horizontalScrollBarEnabled: false,
            supportZoom: false,
            disableHorizontalScroll: true,
            disableVerticalScroll: true,
            allowFileAccessFromFileURLs: true,
            allowUniversalAccessFromFileURLs: true,
          ),
          onWebViewCreated: (InAppWebViewController controller) {
            _bridge.attach(controller);
            controller.addJavaScriptHandler(
              handlerName: 'ssBridge',
              callback: (List<dynamic> args) {
                if (args.isNotEmpty && args.first is String) {
                  _bridge.handleMessage(args.first as String);
                }
                return null;
              },
            );
            widget.onBridgeReady?.call(_bridge);
          },
          onReceivedError:
              (
                InAppWebViewController controller,
                WebResourceRequest request,
                WebResourceError error,
              ) {
                if (request.isForMainFrame ?? false) {
                  AppLogger.I.error(
                    '主框架加载失败：${error.description}',
                    tag: 'engine',
                  );
                  setState(() => _failed = true);
                }
              },
          onConsoleMessage:
              (
                InAppWebViewController controller,
                ConsoleMessage consoleMessage,
              ) {
                // V6/R43：WebView 控制台全量落盘（供诊断包定位）。
                final String level = '${consoleMessage.messageLevel}'
                    .split('.')
                    .last
                    .toLowerCase();
                if (level.contains('error')) {
                  AppLogger.I.error(
                    consoleMessage.message,
                    tag: 'engine-console',
                  );
                } else {
                  AppLogger.I.info(
                    consoleMessage.message,
                    tag: 'engine-console',
                  );
                }
              },
        ),
        if (!_ready)
          Positioned.fill(
            child: ColoredBox(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.7,
              ),
              child: const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
