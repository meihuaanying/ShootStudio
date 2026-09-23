import 'dart:io';

import 'package:flutter/services.dart'
    show MethodChannel, MissingPluginException;
import 'package:path/path.dart' as p;

/// V7/D135：本机显卡信息与 GPU 模式（DXGI 枚举 + WebView2 参数）。
///
/// 模式写入 `%LOCALAPPDATA%\ShootStudio\gpu_mode.txt`，Windows runner 启动时
/// 读取并注入 WebView2 浏览器参数（discrete → --force_high_performance_gpu；
/// software → SwiftShader 软渲；auto/integrated → 默认）。
class GpuAdapter {
  const GpuAdapter({
    required this.index,
    required this.name,
    required this.vendorId,
    required this.deviceId,
    required this.dedicatedVideoMb,
    required this.discrete,
  });

  final int index;
  final String name;
  final int vendorId;
  final int deviceId;
  final int dedicatedVideoMb;
  final bool discrete;

  String get vendorLabel {
    switch (vendorId) {
      case 0x10DE:
        return 'NVIDIA';
      case 0x8086:
        return 'Intel';
      case 0x1002:
      case 0x1022:
        return 'AMD';
      case 0x1414:
        return 'Microsoft';
      default:
        return '其他';
    }
  }

  String get memoryLabel =>
      dedicatedVideoMb <= 0 ? '共享显存' : '$dedicatedVideoMb MB';

  String get kindLabel => discrete ? '独显' : '核显/集成';

  static GpuAdapter fromMap(Map<String, Object?> m) => GpuAdapter(
    index: (m['index'] as num?)?.toInt() ?? 0,
    name: '${m['name'] ?? ''}',
    vendorId: (m['vendorId'] as num?)?.toInt() ?? 0,
    deviceId: (m['deviceId'] as num?)?.toInt() ?? 0,
    dedicatedVideoMb: (m['dedicatedVideoMb'] as num?)?.toInt() ?? 0,
    discrete: m['discrete'] == true,
  );
}

class GpuService {
  GpuService._();

  static const MethodChannel _channel = MethodChannel('shoot_studio/gpu');

  /// GPU 模式：auto（默认）/ discrete（独显优先）/ integrated（核显优先）/ software（软渲排障）。
  static const List<String> modes = <String>[
    'auto',
    'discrete',
    'integrated',
    'software',
  ];

  static const Map<String, String> modeLabels = <String, String>{
    'auto': '自动',
    'discrete': '独显优先',
    'integrated': '核显优先',
    'software': '软件渲染（排障）',
  };

  /// 识别后端：cpu / gpu（D141 高精度模式使用；Windows 走 DirectML EP）。
  static const List<String> recognizeBackends = <String>['cpu', 'gpu'];

  static List<GpuAdapter>? _cache;

  /// 测试钩子：覆盖 gpu_mode 文件路径（生产代码不调用）。
  static String? debugModePathOverride;

  static String modeFilePath() {
    final String? override = debugModePathOverride;
    if (override != null && override.isNotEmpty) return override;
    final String base =
        Platform.environment['LOCALAPPDATA'] ??
        Platform.environment['APPDATA'] ??
        Directory.systemTemp.path;
    return p.join(base, 'ShootStudio', 'gpu_mode.txt');
  }

  /// DXGI 适配器列表（非 Windows / 通道不可用时返回空表，UI 显示降级提示）。
  static Future<List<GpuAdapter>> adapters({bool refresh = false}) async {
    final List<GpuAdapter>? cached = _cache;
    if (cached != null && !refresh) return cached;
    if (!Platform.isWindows) return _cache = <GpuAdapter>[];
    try {
      final List<Object?>? raw = await _channel.invokeMethod<List<Object?>>(
        'listAdapters',
      );
      final List<GpuAdapter> out = <GpuAdapter>[
        for (final Object? item in raw ?? <Object?>[])
          if (item is Map) GpuAdapter.fromMap(item.cast<String, Object?>()),
      ];
      return _cache = out;
    } on MissingPluginException {
      return _cache = <GpuAdapter>[];
    } catch (_) {
      return _cache = <GpuAdapter>[];
    }
  }

  /// 写入 GPU 模式（runner 下次启动/引擎重建时生效）。
  static Future<void> writeMode(String mode) async {
    final String value = modes.contains(mode) ? mode : 'auto';
    try {
      final File file = File(modeFilePath());
      await file.parent.create(recursive: true);
      await file.writeAsString('$value\n', flush: true);
    } catch (_) {
      // 写入失败不阻塞设置保存（下次启动仍用默认 auto）。
    }
  }

  /// 同步读取当前模式（文件不存在/非法 → auto）。
  static String readModeSync() {
    try {
      final File file = File(modeFilePath());
      if (!file.existsSync()) return 'auto';
      final String value = file.readAsStringSync().trim();
      return modes.contains(value) ? value : 'auto';
    } catch (_) {
      return 'auto';
    }
  }
}
