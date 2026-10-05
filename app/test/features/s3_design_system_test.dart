/// V8/D147 · S3 设计系统门禁测试（令牌逐字锁定 / 组件清单 / R73 行数 / 旧令牌清零 / 字体许可）。
///
/// 门禁依据：FIX_CONTRACT_V8.0.md §3（设计系统）、R71（令牌唯一来源）、R73（文件行数）、R79（不回归）。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/core/design/widgets.dart';

int _lines(String file) => File(file).readAsLinesSync().length;

List<File> _dartFiles(String dir) {
  final Directory root = Directory(dir);
  if (!root.existsSync()) return <File>[];
  return root
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .toList();
}

String _read(String file) => File(file).readAsStringSync();

/// §3.5 组件清单（16 项）→ 对应实现类；缺一即视为组件收口失败（R74）。
const Map<String, String> kComponentChecklist = <String, String>{
  '按钮 · 主红': 'SsButton',
  '按钮 · 描边': 'SsButton',
  '按钮 · 文字': 'SsButton',
  '按钮 · 图标': 'SsIconButton',
  '输入框': 'SsTextInput',
  '搜索框': 'SsSearchField',
  '卡片 · 图卡': 'SsImageCard',
  '卡片 · 文卡': 'SsCard',
  '卡片 · 数据卡': 'SsDataCard',
  '对话框': 'SsDialog',
  '底部抽屉': 'SsSheet',
  'Chip / 标签': 'SsTag',
  'Tabs': 'SsTabs',
  '空态': 'SsEmpty',
  '加载骨架屏': 'SsSkeleton',
  'Toast': 'ssToast',
  'Tooltip': 'SsTooltip',
  '分割线': 'SsDivider',
  '区块眉题': 'SsEyebrow',
  '图片帧': 'SsImageFrame',
  'KV 读数行': 'SsKvRow',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('S3 §3.1 色彩：12 令牌 × 双主题逐字锁定', () {
    test('纸面亮 paper', () {
      final AppPalette p = AppPalette.paper;
      expect(p.bg, const Color(0xFFFAF7F1));
      expect(p.surface, const Color(0xFFFFFFFF));
      expect(p.surfaceSunken, const Color(0xFFF3EFE7));
      expect(p.ink, const Color(0xFF1C1917));
      expect(p.inkSoft, const Color(0xFF57534E));
      expect(p.muted, const Color(0xFF8A857C));
      expect(p.rule, const Color(0xFFE4DECF));
      expect(p.accent, const Color(0xFFB43A2B));
      expect(p.accentSoft, const Color(0x14B43A2B));
      expect(p.film, const Color(0xFF2F5D50));
      expect(p.gold, const Color(0xFFA97E2F));
      expect(p.danger, const Color(0xFFB3261E));
      expect(p.brightness, Brightness.light);
    });

    test('暗房暗 darkroom', () {
      final AppPalette p = AppPalette.darkroom;
      expect(p.bg, const Color(0xFF131110));
      expect(p.surface, const Color(0xFF1B1815));
      expect(p.surfaceSunken, const Color(0xFF100E0C));
      expect(p.ink, const Color(0xFFF0EBE3));
      expect(p.inkSoft, const Color(0xFFA8A29A));
      expect(p.muted, const Color(0xFF78716B));
      expect(p.rule, const Color(0xFF2E2A24));
      expect(p.accent, const Color(0xFFD9563F));
      expect(p.accentSoft, const Color(0x1FD9563F));
      expect(p.film, const Color(0xFF4E8A77));
      expect(p.gold, const Color(0xFFC9A24B));
      expect(p.danger, const Color(0xFFE06C60));
      expect(p.brightness, Brightness.dark);
    });

    test('AppTokensV2 入口按变体/上下文解析', () {
      expect(
        AppTokensV2.paletteOf(AppThemeVariant.paper).accent,
        AppPalette.paper.accent,
      );
      expect(
        AppTokensV2.paletteOf(AppThemeVariant.darkroom).accent,
        AppPalette.darkroom.accent,
      );
    });
  });

  group('S3 §3.2–§3.4 字号 / 间距 / 圆角 / 栅格 / 动效', () {
    test('字号阶梯 7 档（字号 + 行高）', () {
      expect(AppType.display.size, 40);
      expect(AppType.display.lineHeight, 1.2);
      expect(AppType.h1.size, 28);
      expect(AppType.h1.lineHeight, 1.3);
      expect(AppType.h2.size, 22);
      expect(AppType.h2.lineHeight, 1.35);
      expect(AppType.h3.size, 17);
      expect(AppType.h3.lineHeight, 1.4);
      expect(AppType.body.size, 14);
      expect(AppType.body.lineHeight, 1.6);
      expect(AppType.small.size, 12.5);
      expect(AppType.small.lineHeight, 1.5);
      expect(AppType.caption.size, 11);
      expect(AppType.caption.lineHeight, 1.4);
      expect(AppType.display.isHeading, isTrue);
      expect(AppType.body.isHeading, isFalse);
      expect(AppType.eyebrowLetterSpacing, 1.5);
    });

    test('行高真实生效（style().height 等于倍数而非倍数比）', () {
      expect(AppType.display.style(const Color(0xFF000000)).height, 1.2);
      expect(AppType.caption.style(const Color(0xFF000000)).height, 1.4);
    });

    test('8pt 间距 4/8/12/16/24/32/48/64', () {
      expect(
        <double>[
          AppSpace.s1,
          AppSpace.s2,
          AppSpace.s3,
          AppSpace.s4,
          AppSpace.s5,
          AppSpace.s6,
          AppSpace.s7,
          AppSpace.s8,
        ],
        <double>[4, 8, 12, 16, 24, 32, 48, 64],
      );
    });

    test('圆角仅 2/4/8', () {
      expect(
        <double>[AppRadius.chip, AppRadius.control, AppRadius.frame],
        <double>[2, 4, 8],
      );
    });

    test('栅格：最大宽 1280 / 12 列 / 列距 24 / 页边距 32(≥1600)', () {
      expect(AppGrid.maxContentWidth, 1280);
      expect(AppGrid.columns, 12);
      expect(AppGrid.gutter, 24);
      expect(AppGrid.pageMargin(1280), 24);
      expect(AppGrid.pageMargin(1600), 32);
      // 7+5 / 8+4 等跨列合计 = 内容宽 - 一条共享列距（24）。
      expect(
        AppGrid.span(1280, 7) + AppGrid.span(1280, 5),
        1280 - AppGrid.gutter,
      );
    });

    test('动效 160/280/420 + 页面切换 200ms + easeOutCubic', () {
      expect(AppMotion.fast, const Duration(milliseconds: 160));
      expect(AppMotion.normal, const Duration(milliseconds: 280));
      expect(AppMotion.slow, const Duration(milliseconds: 420));
      expect(AppMotion.page, const Duration(milliseconds: 200));
      expect(AppMotion.curve, Curves.easeOutCubic);
    });

    test('阴影仅两级（纸感 y1 blur4 8% / 弹层 y8 blur24 12%）', () {
      final AppPalette p = AppPalette.paper;
      final BoxShadow paper = appShadowPaper(p.ink).single;
      expect(paper.offset, const Offset(0, 1));
      expect(paper.blurRadius, 4);
      expect(paper.color.a, closeTo(0.08, 0.001));
      final BoxShadow overlay = appShadowOverlay(p.ink).single;
      expect(overlay.offset, const Offset(0, 8));
      expect(overlay.blurRadius, 24);
      expect(overlay.color.a, closeTo(0.12, 0.001));
    });

    test('mono 回退链含正文字族（中文不出豆腐块）', () {
      expect(AppFonts.monoFallback, contains(AppFonts.body));
      expect(
        appMono(const Color(0xFF000000)).fontFamilyFallback,
        AppFonts.monoFallback,
      );
    });
  });

  group('S3 §3.5 组件清单（≥15 项，R74 收口）', () {
    test('清单条目 ≥ 15', () {
      expect(kComponentChecklist.length, greaterThanOrEqualTo(15));
    });

    test('每个条目在 lib/core/design 中有实现', () {
      final String source = _dartFiles(
        'lib/core/design',
      ).map((File f) => f.readAsStringSync()).join('\n');
      for (final MapEntry<String, String> entry
          in kComponentChecklist.entries) {
        final String symbol = entry.value;
        final String needle = symbol.startsWith('ss')
            ? 'void $symbol('
            : 'class $symbol ';
        expect(
          source.contains(needle),
          isTrue,
          reason: '§3.5「${entry.key}」缺少实现 $symbol',
        );
      }
    });

    test('barrel 导出全部组件文件', () {
      final String barrel = _read('lib/core/design/widgets.dart');
      for (final String part in <String>[
        'tokens.dart',
        'theme.dart',
        'ss_button.dart',
        'ss_card.dart',
        'ss_chip.dart',
        'ss_dialog.dart',
        'ss_empty.dart',
        'ss_feedback.dart',
        'ss_image_frame.dart',
        'ss_input.dart',
        'ss_text.dart',
        'ss_transitions.dart',
      ]) {
        expect(barrel.contains(part), isTrue, reason: 'barrel 未导出 $part');
      }
    });
  });

  group('S3 R73 文件行数门禁', () {
    test('lib/core/design 单文件 ≤ 300', () {
      for (final File f in _dartFiles('lib/core/design')) {
        expect(
          _lines(f.path) <= 300,
          isTrue,
          reason: '${f.path} 超过 300 行（R73）',
        );
      }
    });

    test('lib/features 单文件 ≤ 600 或在基线白名单内', () {
      final Map<String, dynamic> baseline =
          jsonDecode(_read('tool/file_size_baseline.json'))
              as Map<String, dynamic>;
      final Map<String, dynamic> allow =
          baseline['baseline'] as Map<String, dynamic>;
      final Map<String, int> lines = <String, int>{
        for (final File f in _dartFiles('lib/features'))
          f.path.replaceAll('\\', '/'): _lines(f.path),
      };
      for (final MapEntry<String, int> e in lines.entries) {
        if (e.value <= 600) continue;
        final int ceiling = (allow[e.key] as num?)?.toInt() ?? 0;
        expect(
          e.value <= ceiling,
          isTrue,
          reason: '${e.key} ${e.value} 行超过白名单 $ceiling（R73）',
        );
      }
      // 白名单是「临时欠账台账」：每条都必须对应一个当前仍超 600 的文件。
      // 这条断言原来写反了方向（要求白名单非空），于是「所有文件都达标」
      // 反而会被判失败 —— 恰好把 R73 想要的结果判成违规。
      // 现在改成：白名单里每条都必须真的还在超限，防止有人靠调高白名单
      // 把红线绕过（这才是白名单唯一合理的用途）。
      for (final String key in allow.keys) {
        final int actual = lines[key.replaceAll('\\', '/')] ?? 0;
        expect(
          actual > 600,
          isTrue,
          reason:
              '白名单条目 $key 当前 $actual 行，已不超 600，'
              '应从基线中删除（R73 只降不升）',
        );
      }
    });
  });

  group('S3 R71 旧令牌清零 + 迁移壳已删除（R76）', () {
    test('lib 内不再有 AppTokens. 引用', () {
      final List<String> hits = <String>[];
      for (final File f in _dartFiles('lib')) {
        final String rel = f.path.replaceAll('\\', '/');
        final int count = RegExp(
          r'AppTokens\.',
        ).allMatches(f.readAsStringSync()).length;
        if (count > 0) hits.add('$rel ×$count');
      }
      expect(hits, isEmpty, reason: '旧令牌残留：${hits.join(', ')}');
    });

    // R76：旧令牌与旧主题壳已在「一个迭代后」真正删除（R71/R76 收口）。
    // 这里断言**文件不存在**，比原先「标了 @Deprecated 仍保留」更强 ——
    // 后者允许死代码长期躺在仓库里，正是本条要杜绝的状态。
    test('旧令牌 lib/core/theme/ 已整体删除', () {
      expect(
        File('lib/core/theme/tokens.dart').existsSync(),
        isFalse,
        reason: 'core/theme/tokens.dart 应已删除（R71/R76）',
      );
      expect(
        File('lib/core/theme/app_theme.dart').existsSync(),
        isFalse,
        reason: 'core/theme/app_theme.dart 迁移壳应已删除（R71/R76）',
      );
      expect(
        Directory('lib/core/theme').existsSync(),
        isFalse,
        reason: 'core/theme/ 目录应整体清空',
      );
    });

    test('lib 内不再 import core/theme/', () {
      // 只认真正的 import/export 语句：文档注释里为说明迁移史而提到旧路径
      // 是合法的（tokens.dart / theme.dart 的抬头就写了「旧 core/theme/
      // 已删除」），按裸字符串扫会把说明文字误判成残留。
      final RegExp directive = RegExp(
        r'''^\s*(?:import|export)\s+['"][^'"]*core/theme/''',
        multiLine: true,
      );
      final List<String> hits = <String>[];
      for (final File f in _dartFiles('lib')) {
        if (directive.hasMatch(f.readAsStringSync())) {
          hits.add(f.path.replaceAll('\\', '/'));
        }
      }
      expect(hits, isEmpty, reason: '旧主题入口残留：${hits.join(', ')}');
    });
  });

  group('S3 字体随包与许可登记（R80）', () {
    test('assets/fonts 含 NotoSerifSC 子集 + OFL + README', () {
      expect(
        File('assets/fonts/NotoSerifSC-ShootStudio.otf').existsSync(),
        isTrue,
      );
      expect(File('assets/fonts/NotoSerifSC-OFL.txt').existsSync(), isTrue);
      expect(File('assets/fonts/README.md').existsSync(), isTrue);
    });

    test('pubspec 登记 fonts 段与 assets/fonts', () {
      final String pubspec = _read('pubspec.yaml');
      expect(pubspec.contains('fonts:'), isTrue);
      expect(pubspec.contains('NotoSerifSC-ShootStudio.otf'), isTrue);
      expect(pubspec.contains('assets/fonts/'), isTrue);
    });
  });
}
