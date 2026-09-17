import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../core/design/widgets.dart';
import 'engine_bridge.dart';

/// 3D 引擎视图：打包 three.js 单页经 WebView 加载（Windows WebView2 / Android WebView）。
/// 未就绪或加载失败时给出可重试的降级面板，不影响其它功能（本地优先原则）。
class EngineView extends StatefulWidget {
  const EngineView({
    super.key,
    this.onEvent,
    this.onBridgeReady,
    this.backgroundColor,
  });

  final void Function(EngineEvent event)? onEvent;
  final void Function(EngineBridge bridge)? onBridgeReady;
  final Color? backgroundColor;

  @override
  State<EngineView> createState() => _EngineViewState();
}

class _EngineViewState extends State<EngineView> {
  late final EngineBridge _bridge = EngineBridge();
  StreamSubscription<EngineEvent>? _sub;
  bool _ready = false;
  bool _failed = false;
  Timer? _timeout;
  Key _webviewKey = UniqueKey();
  bool _lastActive = true;

  /// 测试环境（flutter_test / golden）不创建平台视图，显示稳定占位（F16）。
  bool get _isTestEnv =>
      !kIsWeb && Platform.environment['FLUTTER_TEST'] == 'true';

  @override
  void initState() {
    super.initState();
    _sub = _bridge.events.listen((EngineEvent e) {
      if (e is EngineReady) {
        _timeout?.cancel();
        setState(() => _ready = true);
        // 应用当前可见性（隐藏页暂停渲染）。
        _bridge.setPaused(!_lastActive);
      }
      if (e is EngineErrorEvent) {
        setState(() => _failed = true);
      }
      widget.onEvent?.call(e);
    });
    _timeout = Timer(const Duration(seconds: 12), () {
      if (mounted && !_ready) setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    _timeout?.cancel();
    _sub?.cancel();
    _bridge.dispose();
    super.dispose();
  }

  void _retry() {
    setState(() {
      _failed = false;
      _ready = false;
      _webviewKey = UniqueKey();
    });
    _timeout?.cancel();
    _timeout = Timer(const Duration(seconds: 12), () {
      if (mounted && !_ready) setState(() => _failed = true);
    });
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
          action: SsButton(
            label: '重新加载引擎',
            icon: Icons.refresh_rounded,
            kind: SsButtonKind.ghost,
            onPressed: _retry,
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
          onReceivedError: (InAppWebViewController controller,
              WebResourceRequest request, WebResourceError error) {
            if (request.isForMainFrame ?? false) {
              setState(() => _failed = true);
            }
          },
        ),
        if (!_ready)
          Positioned.fill(
            child: ColoredBox(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.7),
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
