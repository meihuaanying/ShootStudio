import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/core/db/database.dart';
import 'package:shoot_studio/core/providers.dart';
import 'package:shoot_studio/features/lighting/lighting_controller.dart';
import 'package:shoot_studio/services/engine/engine_bridge.dart';

/// V6 阶段 A 门禁：错误分级 / 心跳 / 缓存 LRU / 性能档（D100–D104、R41–R43）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('引擎错误分级与心跳（R41/R43）', () {
    test('error 事件 fatal 透传：局部错误不致命', () async {
      final EngineBridge bridge = EngineBridge();
      final List<EngineEvent> events = <EngineEvent>[];
      bridge.events.listen(events.add);

      bridge.handleMessage(
          '{"type":"error","message":"角色模型加载失败","fatal":false,"source":"character"}');
      bridge.handleMessage(
          '{"type":"error","message":"引擎引导失败","fatal":true,"source":"boot"}');
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
          '{"type":"engineHeartbeat","frames":321,"fps":59,"memory":{"usedMB":128.5}}');
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
          '{"type":"engineConsole","level":"error","message":"THREE.WebGLRenderer: context lost"}');
      await pumpEventQueue();
      final EngineConsole c = events.single as EngineConsole;
      expect(c.level, 'error');
      expect(c.message, contains('context lost'));
      bridge.dispose();
    });
  });

  group('引擎 bundle 静态门禁（V6 阶段 A）', () {
    test('bundle 含错误分级/心跳/缓存/性能档特征串', () {
      final String js =
          File('assets/engine/js/engine.bundle.js').readAsStringSync();
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
      final String view = File('lib/services/engine/engine_view.dart').readAsStringSync();
      expect(view.contains('onConsoleMessage'), isTrue,
          reason: 'engine_view 缺少控制台转发');
      expect(view.contains('_heartbeatTimeout'), isTrue,
          reason: 'engine_view 缺少心跳超时监控');
      // 错误来源字符串（minify 保留字符串字面量）。
      expect(js.contains('character'), isTrue);
      expect(js.contains('boot'), isTrue);
      // LRU 上限常量存在（实例 2 / GLB 3）。
      expect(RegExp(r'MAX_INSTANCES|maxInstances').hasMatch(js), isTrue);
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
      final LightingController controller =
          container.read(lightingControllerProvider.notifier);
      expect(container.read(lightingControllerProvider).performanceProfile,
          'auto');

      await controller.setPerformanceProfile('low');
      expect(
          container.read(lightingControllerProvider).performanceProfile, 'low');
      expect(await db.getSetting('quality_performance_profile'), 'low');

      final ProviderContainer container2 = ProviderContainer(
        overrides: <Override>[databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container2.dispose);
      await container2.read(lightingControllerProvider.notifier).init();
      expect(container2.read(lightingControllerProvider).performanceProfile,
          'low');

      await controller.setPerformanceProfile('bogus');
      expect(container.read(lightingControllerProvider).performanceProfile,
          'auto');
    });
  });
}
