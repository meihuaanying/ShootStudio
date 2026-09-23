import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/core/theme/app_theme.dart';
import 'package:shoot_studio/core/workspace/workspace.dart';
import 'package:shoot_studio/features/lighting/camera_helpers.dart';
import 'package:shoot_studio/features/lighting/still_export.dart';

void main() {
  group('V7/D139 焦段 → 视野/画幅换算', () {
    test('垂直/水平视场角与引擎 focalToFov 同口径（全画幅 24×36mm）', () {
      expect(verticalFovDeg(50), closeTo(26.99, 0.02));
      expect(horizontalFovDeg(50), closeTo(39.60, 0.02));
      expect(verticalFovDeg(14), closeTo(81.20, 0.02));
      expect(horizontalFovDeg(14), closeTo(104.25, 0.02));
      expect(verticalFovDeg(200), closeTo(6.87, 0.02));
      expect(horizontalFovDeg(200), closeTo(10.29, 0.02));
    });

    test('指定距离画幅尺寸（50mm @3m ≈ 1.44m 高 / 2.16m 宽）', () {
      expect(frameHeightAt(50, 3), closeTo(1.4396, 0.001));
      expect(frameWidthAt(50, 3), closeTo(2.16, 0.001));
      // 长焦压缩：200mm @3m 画幅仅约 0.36m 高。
      expect(frameHeightAt(200, 3), closeTo(0.3600, 0.002));
    });

    test('焦段分档标签', () {
      expect(focalClassLabel(14), '超广角');
      expect(focalClassLabel(21), '超广角');
      expect(focalClassLabel(22), '广角');
      expect(focalClassLabel(35), '广角');
      expect(focalClassLabel(50), '标准');
      expect(focalClassLabel(70), '标准');
      expect(focalClassLabel(85), '中长焦');
      expect(focalClassLabel(135), '中长焦');
      expect(focalClassLabel(200), '长焦');
    });
  });

  group('V7/D139 构图辅助设置', () {
    test('默认值 / enabled / 裁切比例', () {
      const CameraGuideSettings s = CameraGuideSettings();
      expect(s.thirds, isTrue);
      expect(s.safeArea, isTrue);
      expect(s.centerCross, isFalse);
      expect(s.crop, 'none');
      expect(s.enabled, isTrue);
      expect(s.cropAspect, isNull);
      expect(s.copyWith(crop: '16:9').cropAspect, closeTo(16 / 9, 1e-9));
      expect(
        const CameraGuideSettings(crop: '2.35:1').cropAspect,
        closeTo(2.35, 1e-9),
      );
      const CameraGuideSettings off = CameraGuideSettings(
        thirds: false,
        safeArea: false,
        info: false,
      );
      expect(off.enabled, isFalse);
    });

    test('toJson/fromJson 往返（非法裁切值回退 none）', () {
      const CameraGuideSettings s = CameraGuideSettings(
        thirds: false,
        safeArea: true,
        centerCross: true,
        crop: '9:16',
        info: false,
      );
      final CameraGuideSettings back = CameraGuideSettings.fromJson(s.toJson());
      expect(back.thirds, isFalse);
      expect(back.safeArea, isTrue);
      expect(back.centerCross, isTrue);
      expect(back.crop, '9:16');
      expect(back.info, isFalse);
      expect(
        CameraGuideSettings.fromJson(<String, Object?>{'crop': '3:2'}).crop,
        'none',
      );
    });

    test('copyWith 只改指定字段', () {
      const CameraGuideSettings s = CameraGuideSettings();
      final CameraGuideSettings next = s.copyWith(thirds: false, crop: '1:1');
      expect(next.thirds, isFalse);
      expect(next.crop, '1:1');
      expect(next.safeArea, isTrue);
      expect(next.info, isTrue);
    });
  });

  group('V7/D139 构图线绘制', () {
    testWidgets('构图线/安全框/裁切/信息叠加可绘制且不抛异常', (WidgetTester tester) async {
      for (final String crop in CameraGuideSettings.cropOptions) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 320,
                  height: 240,
                  child: CustomPaint(
                    painter: CompositionGuidePainter(
                      settings: CameraGuideSettings(
                        thirds: true,
                        safeArea: true,
                        centerCross: true,
                        crop: crop,
                      ),
                      focalMm: 85,
                      distanceM: 3.2,
                      color: Colors.white,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: '裁切 $crop 绘制失败');
      }
    });

    test('shouldRepaint 仅在参数变化时为真', () {
      const CompositionGuidePainter a = CompositionGuidePainter(
        settings: CameraGuideSettings(),
        focalMm: 50,
        distanceM: 3,
        color: Colors.white,
      );
      const CompositionGuidePainter same = CompositionGuidePainter(
        settings: CameraGuideSettings(),
        focalMm: 50,
        distanceM: 3,
        color: Colors.white,
      );
      const CompositionGuidePainter other = CompositionGuidePainter(
        settings: CameraGuideSettings(),
        focalMm: 85,
        distanceM: 3,
        color: Colors.white,
      );
      expect(a.shouldRepaint(same), isFalse);
      expect(a.shouldRepaint(other), isTrue);
    });
  });

  group('V7/D139 引擎门禁与导出景深接线', () {
    test('引擎包含景深/相机辅助产物（R64/R66）', () {
      final String js = File(
        'assets/engine/js/engine.bundle.js',
      ).readAsStringSync();
      for (final String token in <String>[
        'camera-assist',
        'getCameraAssist',
        'fStop',
        'focusDistance',
        'PhysicalCamera',
        'dofFallback',
      ]) {
        expect(js.contains(token), isTrue, reason: '引擎缺少 $token');
      }
      final String pt = File(
        'assets/engine/js/pathtracer.bundle.js',
      ).readAsStringSync();
      expect(pt.contains('PhysicalCamera'), isTrue, reason: '路径追踪包缺少物理相机');
    });

    testWidgets('效果预览对话框：路径追踪模式有景深开关，超采样模式无', (WidgetTester tester) async {
      // testWidgets 运行在 FakeAsync 中，真实 IO 的 Future 需用 runAsync 推进。
      late Directory dir;
      late Workspace ws;
      await tester.runAsync(() async {
        dir = await Directory.systemTemp.createTemp('ss_cam_w1_');
        ws = await Workspace.initAt(dir.path);
      });
      final StillExportSession session = StillExportSession(workspace: ws);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(body: StillExportDialog(session: session)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // 默认路径追踪：景深开关存在（默认关）。
      expect(find.text('景深'), findsOneWidget);
      expect(find.text('光圈'), findsNothing);

      // 打开景深 → 光圈/对焦控件出现。
      await tester.tap(find.byType(Switch));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('光圈'), findsOneWidget);
      expect(find.text('f/2.8'), findsOneWidget);
      expect(find.text('对焦'), findsOneWidget);

      // 切到超采样 → 景深控件消失。
      await tester.tap(find.text('快速（超采样）'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('景深'), findsNothing);
      expect(find.text('光圈'), findsNothing);

      session.dispose();
      await tester.runAsync(() => dir.delete(recursive: true));
    });
  });
}
