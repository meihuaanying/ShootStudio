import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/core/db/database.dart';
import 'package:shoot_studio/core/providers.dart';
import 'package:shoot_studio/features/lighting/lighting_controller.dart';
import 'package:shoot_studio/services/engine/engine_bridge.dart';
import 'package:shoot_studio/services/engine/engine_reload.dart';
import 'package:shoot_studio/services/gpu/gpu_info.dart';

/// V6 阶段 A 门禁：错误分级 / 心跳 / 缓存 LRU / 性能档（D100–D104、R41–R43）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('引擎错误分级与心跳（R41/R43）', () {
    test('error 事件 fatal 透传：局部错误不致命', () async {
      final EngineBridge bridge = EngineBridge();
      final List<EngineEvent> events = <EngineEvent>[];
      bridge.events.listen(events.add);

      bridge.handleMessage(
        '{"type":"error","message":"角色模型加载失败","fatal":false,"source":"character"}',
      );
      bridge.handleMessage(
        '{"type":"error","message":"引擎引导失败","fatal":true,"source":"boot"}',
      );
      await pumpEventQueue();

      expect(events.length, 2);
      final EngineErrorEvent local = events[0] as EngineErrorEvent;
      final EngineErrorEvent fatal = events[1] as EngineErrorEvent;
      expect(local.fatal, isFalse);
      expect(local.source, 'character');
      expect(fatal.fatal, isTrue);
      expect(fatal.source, 'boot');
      bridge.dispose();
    });

    test('心跳事件解析（frames/fps/内存）', () async {
      final EngineBridge bridge = EngineBridge();
      final List<EngineEvent> events = <EngineEvent>[];
      bridge.events.listen(events.add);

      bridge.handleMessage(
        '{"type":"engineHeartbeat","frames":321,"fps":59,"memory":{"usedMB":128.5}}',
      );
      await pumpEventQueue();

      final EngineHeartbeat hb = events.single as EngineHeartbeat;
      expect(hb.frames, 321);
      expect(hb.fps, 59);
      expect(hb.usedHeapMB, 128.5);
      bridge.dispose();
    });

    test('控制台事件解析', () async {
      final EngineBridge bridge = EngineBridge();
      final List<EngineEvent> events = <EngineEvent>[];
      bridge.events.listen(events.add);
      bridge.handleMessage(
        '{"type":"engineConsole","level":"error","message":"THREE.WebGLRenderer: context lost"}',
      );
      await pumpEventQueue();
      final EngineConsole c = events.single as EngineConsole;
      expect(c.level, 'error');
      expect(c.message, contains('context lost'));
      bridge.dispose();
    });
  });

  group('引擎 bundle 静态门禁（V6 阶段 A）', () {
    test('bundle 含错误分级/心跳/缓存/性能档特征串', () {
      final String js = File(
        'assets/engine/js/engine.bundle.js',
      ).readAsStringSync();
      for (final String token in <String>[
        'engineHeartbeat',
        'getEngineStats',
        'evictCharacterCache',
        'cache-lru',
        'setPerformanceProfile',
        'performance-profile',
      ]) {
        expect(js.contains(token), isTrue, reason: '引擎缺少 $token');
      }
      // 控制台落盘在 Dart 侧（WebView onConsoleMessage）。
      final String view = File(
        'lib/services/engine/engine_view.dart',
      ).readAsStringSync();
      expect(
        view.contains('onConsoleMessage'),
        isTrue,
        reason: 'engine_view 缺少控制台转发',
      );
      expect(
        view.contains('_heartbeatTimeout'),
        isTrue,
        reason: 'engine_view 缺少心跳超时监控',
      );
      // 错误来源字符串（minify 保留字符串字面量）。
      expect(js.contains('character'), isTrue);
      expect(js.contains('boot'), isTrue);
      // LRU 上限常量存在（实例 2 / GLB 3）。
      expect(RegExp(r'MAX_INSTANCES|maxInstances').hasMatch(js), isTrue);
    });

    test('bundle 暴露 GPU 渲染器信息（V7/D135）', () {
      final String js = File(
        'assets/engine/js/engine.bundle.js',
      ).readAsStringSync();
      // minify 会重命名局部变量，用保留的字符串字面量做门禁。
      expect(js.contains('gpu-info-v7'), isTrue, reason: '缺少 GPU 信息标记');
      expect(js.contains('UNMASKED_RENDERER_WEBGL'), isTrue);
      final String view = File(
        'lib/services/engine/engine_view.dart',
      ).readAsStringSync();
      expect(view.contains('_captureGpuRenderer'), isTrue);
      expect(view.contains('engineReloadTick'), isTrue);
    });
  });

  group('显卡设置（V7/D135）', () {
    test('GPU 模式文件读写 + 非法值回退 auto', () async {
      final Directory dir = await Directory.systemTemp.createTemp('ss_gpu');
      addTearDown(() async {
        GpuService.debugModePathOverride = null;
        if (await dir.exists()) await dir.delete(recursive: true);
      });
      GpuService.debugModePathOverride = '${dir.path}/gpu_mode.txt';
      expect(GpuService.readModeSync(), 'auto', reason: '缺文件回退 auto');
      await GpuService.writeMode('discrete');
      expect(GpuService.readModeSync(), 'discrete');
      await GpuService.writeMode('bogus');
      expect(GpuService.readModeSync(), 'auto', reason: '非法值回退 auto');
      await GpuService.writeMode('software');
      expect(GpuService.readModeSync(), 'software');
    });

    test('DXGI 适配器解析：独显/核显/厂商标签', () {
      final GpuAdapter nvidia = GpuAdapter.fromMap(<String, Object?>{
        'index': 1,
        'name': 'NVIDIA GeForce RTX 4060 Laptop GPU',
        'vendorId': 0x10DE,
        'deviceId': 0x28E0,
        'dedicatedVideoMb': 8188,
        'discrete': true,
      });
      expect(nvidia.discrete, isTrue);
      expect(nvidia.vendorLabel, 'NVIDIA');
      expect(nvidia.memoryLabel, contains('8188'));
      final GpuAdapter intel = GpuAdapter.fromMap(<String, Object?>{
        'index': 0,
        'name': 'Intel(R) Iris(R) Xe Graphics',
        'vendorId': 0x8086,
        'dedicatedVideoMb': 0,
        'discrete': false,
      });
      expect(intel.kindLabel, '核显/集成');
      expect(intel.memoryLabel, '共享显存');
    });

    test('引擎重载信号可触发（V7/D135）', () {
      final int before = engineReloadTick.value;
      requestEngineReload();
      expect(engineReloadTick.value, before + 1);
    });

    test('显卡设置持久化（gpu_mode / gpu_recognize_backend）', () async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await db.setSetting('gpu_mode', 'discrete');
      await db.setSetting('gpu_recognize_backend', 'gpu');
      expect(await db.getSetting('gpu_mode'), 'discrete');
      expect(await db.getSetting('gpu_recognize_backend'), 'gpu');
    });
  });

  group('性能档持久化（D104）', () {
    late AppDatabase db;
    late ProviderContainer container;
    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: <Override>[databaseProvider.overrideWithValue(db)],
      );
      await container.read(lightingControllerProvider.notifier).init();
    });
    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('默认 auto + 持久化 + 非法值回退', () async {
      final LightingController controller = container.read(
        lightingControllerProvider.notifier,
      );
      expect(
        container.read(lightingControllerProvider).performanceProfile,
        'auto',
      );

      await controller.setPerformanceProfile('low');
      expect(
        container.read(lightingControllerProvider).performanceProfile,
        'low',
      );
      expect(await db.getSetting('quality_performance_profile'), 'low');

      final ProviderContainer container2 = ProviderContainer(
        overrides: <Override>[databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container2.dispose);
      await container2.read(lightingControllerProvider.notifier).init();
      expect(
        container2.read(lightingControllerProvider).performanceProfile,
        'low',
      );

      await controller.setPerformanceProfile('bogus');
      expect(
        container.read(lightingControllerProvider).performanceProfile,
        'auto',
      );
    });
  });
}
