import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shoot_studio/core/db/database.dart';
import 'package:shoot_studio/core/design/widgets.dart';
import 'package:shoot_studio/core/providers.dart';
import 'package:shoot_studio/core/workspace/workspace.dart';
import 'package:shoot_studio/features/lighting/lighting_controller.dart';
import 'package:shoot_studio/features/lighting/lighting_models.dart';
import 'package:shoot_studio/features/lighting/widgets/lighting_effect_widgets.dart';
import 'package:shoot_studio/features/lighting/widgets/lighting_exposure_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  late Workspace workspace;
  late AppDatabase db;
  late ProviderContainer container;
  late LightingController controller;

  LightingState state() => container.read(lightingControllerProvider);

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('ss_exposure_panel_');
    workspace = await Workspace.initAt(p.join(temp.path, 'ws'));
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: <Override>[
        databaseProvider.overrideWithValue(db),
        workspaceProvider.overrideWithValue(workspace),
      ],
    );
    controller = container.read(lightingControllerProvider.notifier);
    await controller.init();
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  Widget host() {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.of(AppThemeVariant.darkroom),
        home: Scaffold(
          body: SizedBox(
            width: 520,
            child: Consumer(
              builder: (BuildContext context, WidgetRef ref, Widget? child) {
                final LightingState current = ref.watch(
                  lightingControllerProvider,
                );
                return ListView(
                  children: <Widget>[
                    LightingExposurePanel(
                      scene: current.scene,
                      onModeChanged: controller.setMode,
                      onExposureChanged: ({int? iso, double? shutterSeconds}) =>
                          controller.setExposure(
                            iso: iso,
                            shutterSeconds: shutterSeconds,
                          ),
                      onCalibrate: controller.calibrateExposure,
                    ),
                    LightingMeterCard(scene: current.scene),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> selectCalibratedMode(WidgetTester tester) async {
    await tester.tap(find.text('校准曝光'));
    await tester.pumpAndSettle();
  }

  Future<void> enterCalibration(WidgetTester tester, String value) async {
    await tester.enterText(
      find.byKey(const Key('calibration-lux-input')),
      value,
    );
    final Finder button = find.byKey(const Key('calibrate-exposure-button'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('实测校准生成读数，改灯后明确提示复校', (WidgetTester tester) async {
    await tester.pumpWidget(host());
    expect(find.text('虚拟测光表'), findsOneWidget);

    await selectCalibratedMode(tester);
    expect(find.text('校准曝光读数'), findsOneWidget);
    expect(find.textContaining('尚未校准'), findsWidgets);

    await enterCalibration(tester, '1000');
    expect(state().scene.exposure.measuredLux, 1000);
    expect(state().scene.exposure.isCalibrated, isTrue);
    expect(find.textContaining('1000 lux'), findsWidgets);
    expect(find.textContaining('尚未校准'), findsNothing);

    controller.select(state().scene.lights.first.id);
    controller.updateSelected((DeviceSpec light) => light.intensity = 91);
    await tester.pumpAndSettle();
    expect(find.textContaining('布光已变化'), findsWidgets);
    expect(find.text('重新校准'), findsOneWidget);
  });

  testWidgets('拒绝无效实测照度', (WidgetTester tester) async {
    await tester.pumpWidget(host());
    await selectCalibratedMode(tester);
    await enterCalibration(tester, '0');
    expect(state().scene.exposure.isCalibrated, isFalse);
    expect(find.text('请输入大于 0 的实测照度'), findsOneWidget);
  });

  test('模式、曝光参数和校准凭证随场景保存并恢复', () async {
    controller.setMode(LightingMode.calibrated);
    controller.setExposure(iso: 400, shutterSeconds: 1 / 60);
    expect(controller.calibrateExposure(850), isTrue);
    await controller.save();
    final String sceneId = state().scene.id;

    controller.setMode(LightingMode.creative);
    controller.setExposure(iso: 1600, shutterSeconds: 1 / 250);
    await controller.openScene(sceneId);

    expect(state().scene.mode, LightingMode.calibrated);
    expect(state().scene.exposure.iso, 400);
    expect(state().scene.exposure.shutterSeconds, 1 / 60);
    expect(state().scene.exposure.measuredLux, 850);
    expect(state().scene.exposure.isCalibrated, isTrue);
    expect(state().dirty, isFalse);
  });
}
