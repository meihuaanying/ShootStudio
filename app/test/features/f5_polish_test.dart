import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/core/design/widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('F8 应用图标制品', () {
    test('主图 / ICO / Android 全密度均生成且格式合法', () {
      final File png = File('assets/icon/app_icon.png');
      expect(png.existsSync(), isTrue);
      final List<int> pngBytes = png.readAsBytesSync();
      expect(pngBytes.sublist(0, 4), <int>[0x89, 0x50, 0x4E, 0x47]);

      final File ico = File('windows/runner/resources/app_icon.ico');
      expect(ico.existsSync(), isTrue);
      final List<int> icoBytes = ico.readAsBytesSync();
      // ICO 头：0x0000 保留 + 图片类型 1。
      expect(icoBytes.sublist(0, 4), <int>[0, 0, 1, 0]);
      expect(icoBytes.length, greaterThan(1024));

      const Map<String, int> densities = <String, int>{
        'mdpi': 48,
        'hdpi': 72,
        'xhdpi': 96,
        'xxhdpi': 144,
        'xxxhdpi': 192,
      };
      for (final MapEntry<String, int> entry in densities.entries) {
        final File mipmap = File(
            'android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png');
        expect(mipmap.existsSync(), isTrue, reason: '缺少 ${entry.key}');
        final List<int> bytes = mipmap.readAsBytesSync();
        expect(bytes.sublist(0, 4), <int>[0x89, 0x50, 0x4E, 0x47]);
        expect(bytes.length, greaterThan(200), reason: '${entry.key} 过小');
      }
    });
  });

  group('F7 动效与空态', () {
    testWidgets('SsFadeSwitch：切换索引重放淡入', (WidgetTester tester) async {
      Widget build(int index) => MaterialApp(
            home: SsFadeSwitch(
              index: index,
              child: const Text('内容', key: ValueKey<String>('content')),
            ),
          );
      await tester.pumpWidget(build(0));
      FadeTransition fade() => tester.widget<FadeTransition>(find
          .descendant(
            of: find.byType(SsFadeSwitch),
            matching: find.byType(FadeTransition),
          )
          .first);
      expect(fade().opacity.value, 1.0);

      await tester.pumpWidget(build(1));
      await tester.pump(const Duration(milliseconds: 40));
      final double mid = fade().opacity.value;
      expect(mid, lessThan(1.0));
      expect(mid, greaterThanOrEqualTo(0.0));
      await tester.pump(const Duration(milliseconds: 300));
      expect(fade().opacity.value, 1.0);
      // 子页面状态容器不因切换被替换（Key 不变）。
      expect(find.byKey(const ValueKey<String>('content')), findsOneWidget);
    });

    testWidgets('SsShimmer：流光持续动画且不抛异常', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: SsShimmer(label: '正在生成…')),
      ));
      expect(find.text('正在生成…'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 320));
      await tester.pump(const Duration(milliseconds: 320));
      expect(tester.takeException(), isNull);
    });

    testWidgets('SsEmpty：程序绘制插画可渲染（四种变体）', (WidgetTester tester) async {
      for (final SsArt art in SsArt.values) {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: SsEmpty(icon: Icons.star, art: art, title: '空态 ${art.name}'),
          ),
        ));
        expect(find.text('空态 ${art.name}'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(SsEmpty),
            matching: find.byType(CustomPaint),
          ),
          findsWidgets,
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('SsCard：悬停轻抬 + 时长令牌一致', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SsCard(
              onTap: () {},
              child: const SizedBox(width: 120, height: 60),
            ),
          ),
        ),
      ));
      Matrix4 transformOf() => tester
          .widget<AnimatedContainer>(find.byType(AnimatedContainer))
          .transform!;
      expect(transformOf().getTranslation().y, 0);

      final TestGesture gesture =
          await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();
      await gesture.moveTo(tester.getCenter(find.byType(SsCard)));
      await tester.pump(const Duration(milliseconds: 200));
      expect(transformOf().getTranslation().y, lessThan(0));

      await gesture.moveTo(const Offset(1, 1));
      await tester.pump(const Duration(milliseconds: 200));
      expect(transformOf().getTranslation().y, 0);
    });
  });
}
