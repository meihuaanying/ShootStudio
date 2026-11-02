import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/core/design/widgets.dart';
import 'package:shoot_studio/features/field/field_exposure_brief.dart';
import 'package:shoot_studio/features/lighting/light_meter.dart';
import 'package:shoot_studio/features/lighting/lighting_models.dart';

LightingSceneData _scene({required LightingMode mode}) {
  final LightingSceneData scene = LightingSceneData(
    id: 'scene',
    name: '三点布光',
    devices: <DeviceSpec>[
      DeviceSpec(
        id: 'key',
        kind: 'light',
        name: '主灯',
        type: 'soft',
        x: -1.2,
        y: -1.6,
        intensity: 70,
        modifier: 'softbox-large',
      ),
    ],
  )..mode = mode;
  if (mode == LightingMode.calibrated) {
    scene.exposure
      ..iso = 400
      ..shutterSeconds = 1 / 125
      ..measuredLux = 800
      ..calibrationFactor = LightMeter.calibrationFactorFor(scene, 800)
      ..calibrationSignature = LightMeter.signatureOf(scene);
  }
  return scene;
}

Widget _host(
  LightingSceneData? scene, {
  String sceneId = 'scene',
  VoidCallback? onRefresh,
}) {
  return MaterialApp(
    theme: AppTheme.of(AppThemeVariant.darkroom),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 350,
          child: FieldExposureBrief(
            sceneId: sceneId,
            scene: scene,
            onRefresh: onRefresh ?? () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('创意模式显示参考参数并明确不可当测光结果', (WidgetTester tester) async {
    await tester.pumpWidget(_host(_scene(mode: LightingMode.creative)));
    expect(find.text('创意预演 · 经验参考'), findsOneWidget);
    expect(find.textContaining('ISO 100'), findsOneWidget);
    expect(find.textContaining('不代表绝对测光'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('有效校准显示 ISO、快门、光圈与总照度', (WidgetTester tester) async {
    await tester.pumpWidget(_host(_scene(mode: LightingMode.calibrated)));
    expect(find.text('校准曝光 · 现场参数'), findsOneWidget);
    expect(find.text('ISO 400 · 1/125 · f/2.8'), findsOneWidget);
    expect(find.textContaining('总照度 800 lux'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('改灯后的旧校准隐藏参数并要求复校', (WidgetTester tester) async {
    final LightingSceneData scene = _scene(mode: LightingMode.calibrated);
    scene.lights.single.intensity = 100;
    await tester.pumpWidget(_host(scene));
    expect(find.text('校准曝光 · 需要复校'), findsOneWidget);
    expect(find.textContaining('ISO 400'), findsNothing);
    expect(find.textContaining('重新测量'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('方案删除或未关联时不展示虚假参数，刷新按钮可用', (WidgetTester tester) async {
    var refreshed = 0;
    await tester.pumpWidget(
      _host(null, sceneId: 'deleted', onRefresh: () => refreshed++),
    );
    expect(find.textContaining('不存在或无法读取'), findsOneWidget);
    expect(find.textContaining('ISO '), findsNothing);
    await tester.tap(find.byKey(const Key('field-exposure-refresh')));
    expect(refreshed, 1);

    await tester.pumpWidget(_host(null, sceneId: ''));
    expect(find.textContaining('未关联布光方案'), findsOneWidget);
  });
}
