import 'package:flutter/foundation.dart';

/// V7/D135：全局引擎重载信号（显卡设置切换后热重载引擎 WebView）。
final ValueNotifier<int> engineReloadTick = ValueNotifier<int>(0);

/// 最近一次引擎报告的 GPU 渲染器字符串（WebGL UNMASKED_RENDERER_WEBGL）。
final ValueNotifier<String> engineGpuRenderer = ValueNotifier<String>('');

/// 请求引擎重载（EngineView 监听后重建 WebView 并重放场景）。
void requestEngineReload() => engineReloadTick.value++;
