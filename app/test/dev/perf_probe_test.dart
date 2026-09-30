// V8/S2（D156）性能探针：阶段统计口径单测（R62：CI 常跑，不依赖桌面构建）。
//
// 覆盖：PerfProbePhase.toJson 的分位/极值/均值/帧率计算与空样本保护；
// 以及 PerfProbeConfig 的默认值与「默认关闭」门禁（R79：正常启动路径不受影响）。

import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/dev/perf_probe.dart';

void main() {
  group('PerfProbePhase 统计口径', () {
    test('已知样本 → p50/p95/max/mean/fps 可复算（最近秩口径）', () {
      final phase = PerfProbePhase('withWebView');
      // 1..100 ms 递增样本。分位口径 = 最近秩：index = round((n-1) * q)
      //   p50 → index 50 → 51.0；p95 → index 94 → 95.0；max = 100；mean = 50.5
      for (var i = 1; i <= 100; i++) {
        phase.total.add(i.toDouble());
        phase.build.add(i / 10);
        phase.raster.add(i / 5);
      }
      final json = phase.toJson();
      expect(json['phase'], 'withWebView');
      expect(json['frames'], 100);
      expect(json['totalMsP50'], closeTo(51.0, 0.001));
      expect(json['totalMsP95'], closeTo(95.0, 0.001));
      expect(json['totalMsMax'], closeTo(100, 0.001));
      expect(json['totalMsMean'], closeTo(50.5, 0.001));
      // fpsMean = 1000 / mean
      expect(json['fpsMean'], closeTo(1000 / 50.5, 0.01));
      expect(json['buildMsP95'], closeTo(9.5, 0.001));
      expect(json['rasterMsP95'], closeTo(19.0, 0.001));
    });

    test('空样本 → 不抛异常且分位为 null', () {
      final json = PerfProbePhase('flutterOnly').toJson();
      expect(json['frames'], 0);
      expect(json['totalMsP50'], isNull);
      expect(json['totalMsP95'], isNull);
      expect(json['totalMsMax'], isNull);
      expect(json['fpsMean'], isNull);
    });

    test('单样本 → p50/p95/max 三者相等', () {
      final phase = PerfProbePhase('idle')..total.add(16.7);
      final json = phase.toJson();
      expect(json['frames'], 1);
      expect(json['totalMsP50'], 16.7);
      expect(json['totalMsP95'], 16.7);
      expect(json['totalMsMax'], 16.7);
    });
  });

  group('PerfProbeConfig 门禁', () {
    test('默认关闭（未传 dart-define / 环境变量时不启用探针）', () {
      // 测试进程不带 SS_PERF_PROBE 环境变量；dart-define 同样未开启。
      expect(const bool.fromEnvironment('SS_PERF_PROBE'), isFalse);
      expect(PerfProbeConfig.enabled, isFalse);
    });

    test('时长参数有默认值（3s 预热 / 5s 采样）', () {
      expect(PerfProbeConfig.warmupMs, 3000);
      expect(PerfProbeConfig.measureMs, 5000);
    });

    test('默认启用引擎视图阶段（webViewInPhase1 = true）', () {
      expect(PerfProbeConfig.showEngine, isTrue);
      expect(PerfProbeConfig.label, isNotEmpty);
    });
  });
}
