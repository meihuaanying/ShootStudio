// V8/S2（D156）3D 引擎架构 spike：Flutter 侧帧耗时探针。
//
// 目的：为「WebView2 + three.js r186（现状） vs Flutter 原生渲染」的决策提供**本机实测**数据：
//   阶段 A `flutterOnly`  纯 Flutter 合成负载（24 个 3D 变换卡片持续动画）的 build/raster 帧耗时；
//   阶段 B `withWebView`  同一负载 + 内嵌 WebView2 引擎视图（EngineView）时的帧耗时。
//   B − A 的差值即「宿主合成 WebView」的边际成本；A 本身给出 Flutter/Impeller 的帧预算基线。
// S6（布光预演重构）要求的「交互帧率 p95 实测」也复用本探针。
//
// 门控（R75/R79：不改变正常启动路径）：仅当 `--dart-define=SS_PERF_PROBE=1` 或环境变量
// `SS_PERF_PROBE=1` 时启用；默认关闭，正常启动与 CI 门禁不受影响。
// 产出：`<exe 同目录>/perf-probe-<label>.json`（桌面）或应用缓存目录（移动端），并打印摘要。
// 用法（app/ 下）：
//   flutter build windows --release --dart-define=SS_PERF_PROBE=1
//   $env:SS_PERF_PROBE='1'; $env:SS_PERF_PROBE_LABEL='win-webview'; & build\windows\x64\runner\Release\shoot_studio.exe
library;

import '../core/design/tokens.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../services/engine/engine_view.dart';
import '../core/design/widgets.dart';

/// 探针开关与参数（环境变量优先于 dart-define，便于复用同一份构建产物跑多组配置）。
class PerfProbeConfig {
  static const bool _dartDefine = bool.fromEnvironment('SS_PERF_PROBE');

  static bool get enabled => _dartDefine || _env == '1';

  static String get _env => Platform.environment['SS_PERF_PROBE'] ?? '';

  static String get label =>
      Platform.environment['SS_PERF_PROBE_LABEL'] ??
      (Platform.isWindows ? 'win' : 'other');

  /// 每阶段预热（等首帧着色器/纹理/引擎就绪）。
  static int get warmupMs =>
      int.tryParse(Platform.environment['SS_PERF_PROBE_WARMUP'] ?? '') ?? 3000;

  /// 每阶段采样时长。
  static int get measureMs =>
      int.tryParse(Platform.environment['SS_PERF_PROBE_MEASURE'] ?? '') ?? 5000;

  static bool get showEngine =>
      Platform.environment['SS_PERF_PROBE_NO_WEBVIEW'] != '1';
}

/// 单阶段帧耗时统计（p50/p95/max + 每帧 build/raster），JSON 直接入证据文件。
class PerfProbePhase {
  PerfProbePhase(this.name);

  final String name;
  final List<double> total = <double>[];
  final List<double> build = <double>[];
  final List<double> raster = <double>[];

  Map<String, Object?> toJson() {
    double? q(List<double> v, double p) {
      if (v.isEmpty) return null;
      final s = [...v]..sort();
      return double.parse(s[((s.length - 1) * p).round()].toStringAsFixed(2));
    }

    double mean(List<double> v) => v.isEmpty
        ? double.nan
        : double.parse(
            (v.reduce((a, b) => a + b) / v.length).toStringAsFixed(2),
          );

    return <String, Object?>{
      'phase': name,
      'frames': total.length,
      'totalMsP50': q(total, 0.5),
      'totalMsP95': q(total, 0.95),
      'totalMsMax': total.isEmpty
          ? null
          : double.parse(
              total.reduce((a, b) => a > b ? a : b).toStringAsFixed(2),
            ),
      'totalMsMean': mean(total),
      'buildMsP95': q(build, 0.95),
      'rasterMsP95': q(raster, 0.95),
      'fpsMean': mean(total).isNaN
          ? null
          : double.parse((1000 / mean(total)).toStringAsFixed(1)),
    };
  }
}

class PerfProbeApp extends StatelessWidget {
  const PerfProbeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const PerfProbePage(),
    );
  }
}

/// 探针页：阶段 A 纯负载 → 阶段 B 负载 + WebView 引擎 → 写 JSON → 退出进程。
class PerfProbePage extends StatefulWidget {
  const PerfProbePage({super.key});

  @override
  State<PerfProbePage> createState() => _PerfProbePageState();
}

class _PerfProbePageState extends State<PerfProbePage>
    with SingleTickerProviderStateMixin {
  final List<PerfProbePhase> _phases = <PerfProbePhase>[];
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: AppWait.probeRun,
  )..repeat();
  bool _engineReady = false;
  String _engineNote = '未启用引擎视图';
  int _phase = 0;
  PerfProbePhase? _current;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    WidgetsBinding.instance.addPostFrameCallback((_) => _runPhase(0));
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _ctrl.dispose();
    super.dispose();
  }

  void _onTimings(List<FrameTiming> timings) {
    final cur = _current;
    if (cur == null) return;
    for (final t in timings) {
      cur.total.add(t.totalSpan.inMicroseconds / 1000);
      cur.build.add(t.buildDuration.inMicroseconds / 1000);
      cur.raster.add(t.rasterDuration.inMicroseconds / 1000);
    }
  }

  Future<void> _runPhase(int index) async {
    if (index >= 2) {
      await _finish();
      return;
    }
    setState(() => _phase = index);
    // 阶段 0：纯负载；阶段 1：负载 + WebView 引擎视图（等 bridge ready 后再采样）。
    await Future<void>.delayed(
      Duration(milliseconds: PerfProbeConfig.warmupMs),
    );
    if (index == 1 && PerfProbeConfig.showEngine && !_engineReady) {
      final deadline = DateTime.now().add(AppWait.probeSample);
      while (!_engineReady && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(AppMotion.page);
      }
      await Future<void>.delayed(
        Duration(milliseconds: PerfProbeConfig.warmupMs),
      );
    }
    _current = PerfProbePhase(index == 0 ? 'flutterOnly' : 'withWebView');
    await Future<void>.delayed(
      Duration(milliseconds: PerfProbeConfig.measureMs),
    );
    _phases.add(_current!);
    _current = null;
    await _runPhase(index + 1);
  }

  Future<void> _finish() async {
    final payload = <String, Object?>{
      'label': PerfProbeConfig.label,
      'at': DateTime.now().toUtc().toIso8601String(),
      'platform':
          '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
      'executable': Platform.resolvedExecutable,
      'webViewInPhase1': PerfProbeConfig.showEngine,
      'engineReady': _engineReady,
      'engineNote': _engineNote,
      'warmupMs': PerfProbeConfig.warmupMs,
      'measureMs': PerfProbeConfig.measureMs,
      'phases': _phases.map((p) => p.toJson()).toList(),
    };
    final text = const JsonEncoder.withIndent('  ').convert(payload);
    debugPrint('[perf-probe] $text');
    try {
      final dir = File(Platform.resolvedExecutable).parent;
      final out = File(
        '${dir.path}${Platform.pathSeparator}perf-probe-${PerfProbeConfig.label}.json',
      );
      await out.writeAsString('$text\n');
    } catch (e) {
      debugPrint('[perf-probe] 写文件失败：$e');
    }
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.darkroomBg,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'PERF PROBE · phase $_phase · $_engineNote',
                style: const TextStyle(
                  color: AppPalette.darkroomAccent,
                  fontFamily: 'monospace',
                  fontSize: AppFontSize.smallLg,
                ),
              ),
            ),
            Expanded(
              child: Row(
                children: <Widget>[
                  Expanded(flex: 4, child: _Workload(controller: _ctrl)),
                  if (_phase >= 1 && PerfProbeConfig.showEngine)
                    Expanded(
                      flex: 6,
                      child: Container(
                        color: AppPalette.darkroomSurfaceSunken,
                        child: EngineView(
                          backgroundColor: AppPalette.darkroomSurfaceSunken,
                          onBridgeReady: (bridge) {
                            bridge.setPerformanceProfile('high');
                            setState(() {
                              _engineReady = true;
                              _engineNote = 'WebView2 引擎已就绪（high）';
                            });
                          },
                          onEvent: (event) {
                            if (event.runtimeType.toString().contains(
                                  'EngineErrorEvent',
                                ) &&
                                !_engineReady) {
                              setState(() => _engineNote = '引擎异常：$event');
                            }
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 合成负载：24 个带 3D 变换的卡片持续动画（build + raster 都有真实开销）。
class _Workload extends StatelessWidget {
  const _Workload({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return GridView.count(
          crossAxisCount: 3,
          padding: const EdgeInsets.all(8),
          children: List<Widget>.generate(24, (i) {
            final a = controller.value * 2 * 3.14159 + i * 0.26;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0016)
                ..rotateY(a * 0.6)
                ..rotateX(a * 0.25)
                ..translateByDouble(0.0, (a % 1) * 24 - 12, 0.0, 1.0),
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Color.fromARGB(200, 47 + i * 6, 93, 80),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
