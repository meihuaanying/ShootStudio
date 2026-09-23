import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:shoot_studio/core/theme/app_theme.dart';
import 'package:shoot_studio/core/workspace/workspace.dart';
import 'package:shoot_studio/features/lighting/ab_compare.dart';
import 'package:shoot_studio/features/lighting/still_export.dart';
import 'package:shoot_studio/services/engine/engine_bridge.dart';

/// V7/D138 门禁：A/B 差异统计与合成、静帧导出会话状态机。
Uint8List _png(int r, int g, int b) {
  final img.Image image = img.Image(width: 480, height: 360);
  img.fill(image, color: img.ColorRgb8(r, g, b));
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('A/B 差异统计（V7/D138）', () {
    test('相同图：零差异且结论为轻微', () {
      final Uint8List png = _png(90, 90, 90);
      final AbDiffStats? stats = abDiffStats(png, png);
      expect(stats, isNotNull);
      expect(stats!.meanAbs, closeTo(0, 0.001));
      expect(stats.changedRatio, 0);
      expect(stats.maxDelta, closeTo(0, 0.001));
      expect(stats.pixels, abPaneWidth * abPaneHeight);
      expect(stats.verdict, '差异轻微');
    });

    test('全图大幅变化：平均差/最大差/变化比例与「显著」结论', () {
      final AbDiffStats stats = abDiffStats(
        _png(0, 0, 0),
        _png(255, 255, 255),
      )!;
      expect(stats.meanAbs, closeTo(255, 0.5));
      expect(stats.changedRatio, 1.0);
      expect(stats.maxDelta, closeTo(255, 0.5));
      expect(stats.verdict, '差异显著');
    });

    test('阈值内微差（10/255）不计入变化像素', () {
      final AbDiffStats stats = abDiffStats(
        _png(100, 100, 100),
        _png(110, 110, 110),
      )!;
      expect(stats.meanAbs, closeTo(10, 0.01));
      expect(stats.changedRatio, 0);
      expect(stats.verdict, '差异轻微');
    });

    test('中等差异口径：约 5.6% 变化像素 → 差异中等', () {
      final img.Image a = img.Image(width: 480, height: 360);
      img.fill(a, color: img.ColorRgb8(60, 60, 60));
      final img.Image b = img.Image.from(a);
      for (int y = 0; y < 20; y++) {
        for (int x = 0; x < 480; x++) {
          b.setPixelRgb(x, y, 140, 140, 140);
        }
      }
      final AbDiffStats stats = abDiffStats(
        Uint8List.fromList(img.encodePng(a)),
        Uint8List.fromList(img.encodePng(b)),
      )!;
      expect(stats.changedRatio, closeTo(20 * 480 / (480 * 360), 0.01));
      expect(stats.verdict, '差异中等');
    });

    test('解码失败返回 null；toJson 含口径字段', () {
      expect(
        abDiffStats(Uint8List.fromList(<int>[1, 2, 3]), _png(0, 0, 0)),
        isNull,
      );
      final AbDiffStats stats = abDiffStats(
        _png(0, 0, 0),
        _png(255, 255, 255),
      )!;
      final Map<String, Object?> json = stats.toJson();
      expect(json['threshold'], abDiffThreshold);
      expect(json['verdict'], '差异显著');
      expect(json['pixels'], abPaneWidth * abPaneHeight);
    });
  });

  group('A/B 并排合成图（V7/D138）', () {
    test('尺寸 960×416、左 A 右 B、可解码', () {
      final Uint8List a = _png(0, 0, 0);
      final Uint8List b = _png(255, 255, 255);
      final AbDiffStats stats = abDiffStats(a, b)!;
      final Uint8List? out = abComposeSideBySide(a, b, stats);
      expect(out, isNotNull);
      final img.Image canvas = img.decodeImage(out!)!;
      expect(canvas.width, abPaneWidth * 2);
      expect(canvas.height, abPaneHeight + 56);
      expect(canvas.getPixel(10, 10).r, lessThan(20));
      expect(canvas.getPixel(abPaneWidth + 10, 10).r, greaterThan(235));
    });

    test('解码失败返回 null', () {
      final AbDiffStats stats = abDiffStats(_png(0, 0, 0), _png(1, 1, 1))!;
      expect(
        abComposeSideBySide(
          Uint8List.fromList(<int>[9, 9]),
          _png(0, 0, 0),
          stats,
        ),
        isNull,
      );
    });
  });

  group('AbSlots 冻结槽（V7/D138）', () {
    test('withSlot/cleared/hasBoth', () {
      const AbSlots empty = AbSlots();
      expect(empty.hasBoth, isFalse);
      final AbSlots a = empty.withSlot('a', 'data:image/png;base64,AA');
      expect(a.a, isNotEmpty);
      expect(a.hasBoth, isFalse);
      final AbSlots both = a.withSlot('b', 'data:image/png;base64,BB');
      expect(both.hasBoth, isTrue);
      expect(both.cleared().hasBoth, isFalse);
      expect(both.toJson()['hasA'], isTrue);
      expect(both.toJson()['hasB'], isTrue);
    });
  });

  group('StillExportSession 状态机（V7/D138）', () {
    test('未接引擎时 start 报错且不进入运行态', () async {
      final Directory dir = await Directory.systemTemp.createTemp(
        'ss_still_n_',
      );
      final Workspace ws = await Workspace.initAt(dir.path);
      final StillExportSession session = StillExportSession(workspace: ws);
      session.start(
        mode: 'path',
        width: 640,
        height: 480,
        samples: 128,
        factor: 2,
        useCameraRig: true,
      );
      expect(session.running, isFalse);
      expect(session.error, contains('引擎未就绪'));
      await dir.delete(recursive: true);
      session.dispose();
    });

    test('进度/完成事件更新状态并自动保存到工作区 images/plans/', () async {
      final Directory dir = await Directory.systemTemp.createTemp('ss_still_');
      final Workspace ws = await Workspace.initAt(dir.path);
      final StillExportSession session = StillExportSession(workspace: ws);

      session.onProgress(
        const EngineStillProgress(
          mode: 'path',
          phase: 'render',
          samples: 64,
          target: 128,
          elapsedMs: 1200,
          width: 480,
          height: 360,
        ),
      );
      expect(session.running, isTrue);
      expect(session.samples, 64);
      expect(session.target, 128);
      expect(session.statusLabel, contains('64'));

      final Uint8List png = _png(128, 128, 128);
      await session.onRendered(
        EngineStillRendered(
          ok: true,
          mode: 'path',
          dataUrl: 'data:image/png;base64,${base64Encode(png)}',
          width: 480,
          height: 360,
          samples: 128,
          ms: 19000,
        ),
      );
      expect(session.running, isFalse);
      expect(session.hasResult, isTrue);
      expect(session.error, isNull);
      expect(session.savedPath, isNotNull);
      expect(File(session.savedPath!).existsSync(), isTrue);
      expect(p.basename(session.savedPath!), startsWith('静帧_路径追踪_'));
      expect(p.basename(session.savedPath!), endsWith('.png'));
      expect(session.savedRelative, startsWith('images'));
      await dir.delete(recursive: true);
      session.dispose();
    });

    test('失败事件记录错误、不保存、状态可读', () async {
      final Directory dir = await Directory.systemTemp.createTemp(
        'ss_still_e_',
      );
      final Workspace ws = await Workspace.initAt(dir.path);
      final StillExportSession session = StillExportSession(workspace: ws);
      await session.onRendered(
        const EngineStillRendered(
          ok: false,
          mode: 'path',
          dataUrl: '',
          error: 'WebGL context lost',
        ),
      );
      expect(session.hasResult, isFalse);
      expect(session.error, contains('WebGL context lost'));
      expect(session.savedPath, isNull);
      expect(session.statusLabel, contains('失败'));
      await dir.delete(recursive: true);
      session.dispose();
    });
  });

  group('效果预览对话框（V7/D138 widget）', () {
    testWidgets('模式切换时采样数收敛到合法值，且无桥接时给出未就绪提示', (WidgetTester tester) async {
      // testWidgets 运行在 FakeAsync 中，真实 IO 的 Future 需用 runAsync 推进（见 test/app_boot_test.dart）。
      late Directory dir;
      late Workspace ws;
      await tester.runAsync(() async {
        dir = await Directory.systemTemp.createTemp('ss_still_w1_');
        ws = await Workspace.initAt(dir.path);
      });
      final StillExportSession session = StillExportSession(workspace: ws);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(body: StillExportDialog(session: session)),
        ),
      );
      expect(find.text('效果预览（静帧导出）'), findsOneWidget);
      expect(find.text('128'), findsOneWidget);

      // 路径追踪 128 → 超采样模式：128 不在 [2,3] 内，必须自动收敛（否则 DropdownButton 断言崩溃）。
      await tester.tap(find.text('快速（超采样）'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.text('2×'), findsOneWidget);

      // 无引擎桥接：点「渲染并保存」给出未就绪提示，不进入运行态。
      await tester.tap(find.text('渲染并保存'));
      await tester.pump();
      expect(session.running, isFalse);
      expect(session.error, isNotNull);
      expect(find.textContaining('引擎未就绪'), findsWidgets);

      session.dispose();
      await tester.runAsync(() => dir.delete(recursive: true));
    });

    testWidgets('渲染完成后展示结果预览与保存路径', (WidgetTester tester) async {
      late Directory dir;
      late Workspace ws;
      await tester.runAsync(() async {
        dir = await Directory.systemTemp.createTemp('ss_still_w2_');
        ws = await Workspace.initAt(dir.path);
      });
      final StillExportSession session = StillExportSession(workspace: ws);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(body: StillExportDialog(session: session)),
        ),
      );
      final Uint8List png = _png(96, 112, 128);
      await tester.runAsync(
        () => session.onRendered(
          EngineStillRendered(
            ok: true,
            mode: 'supersample',
            dataUrl: 'data:image/png;base64,${base64Encode(png)}',
            width: 960,
            height: 720,
            samples: 2,
            ms: 84,
          ),
        ),
      );
      await tester.pump();
      expect(session.hasResult, isTrue);
      expect(find.byType(Image), findsOneWidget);
      expect(find.textContaining('960×720'), findsOneWidget);
      expect(find.textContaining('已存'), findsOneWidget);
      session.dispose();
      await tester.runAsync(() => dir.delete(recursive: true));
    });
  });
}
