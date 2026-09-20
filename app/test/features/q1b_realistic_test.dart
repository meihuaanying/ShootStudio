import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Q1b 写实模式验收（D61）：MakeHuman/MPFB2 最高标准路线产出可被 UI 选择、可被引擎加载。
// 证据链：
//   tool/gen_realistic_character.py（Blender 4.5 + MPFB2 + makehuman_system_assets CC0）
//     → assets/models/characters/realistic/mh-men-01.glb（84,550 三角面 / 53 骨游戏骨架）
//     → manifest.characters[realistic=true] + manifest.realistic.items
//     → engine bundle 的 realistic 挂载/骨骼模糊匹配特征串
//     → docs/screenshots/realistic-view0.png / realistic-view1.png / realistic-posed.png
//     → docs/screenshots/realistic-build-report.json（构建报告）
// 注：写实条目运行时不叠加 Loop 细分（基础网格已 ≥60k），故 triCount == 构建期细分后面数，
// baseTriCount 记录未细分的基础网格面数。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, Object?> manifest;
  late List<Map<String, Object?>> characters;
  late Map<String, Object?> realistic;

  setUpAll(() {
    final File file = File('assets/models/characters/manifest.json');
    expect(
      file.existsSync(),
      isTrue,
      reason: '缺少 assets/models/characters/manifest.json',
    );
    manifest = (jsonDecode(file.readAsStringSync()) as Map)
        .cast<String, Object?>();
    characters = (manifest['characters'] as List<Object?>? ?? <Object?>[])
        .map((Object? e) => (e as Map).cast<String, Object?>())
        .toList();
    realistic =
        (manifest['realistic'] as Map?)?.cast<String, Object?>() ??
        <String, Object?>{};
  });

  group('Q1b 写实模式（D61）', () {
    test('manifest 写实条目存在、文件存在、triCount ≥60k 且记录来源与许可', () {
      final List<Map<String, Object?>> entries = characters
          .where((Map<String, Object?> c) => c['realistic'] == true)
          .toList();
      expect(entries, isNotEmpty, reason: 'characters 中没有 realistic:true 条目');
      expect(manifest['realisticAvailable'], isTrue);

      for (final Map<String, Object?> entry in entries) {
        final String file = '${entry['file'] ?? ''}';
        expect(file, isNotEmpty, reason: '${entry['id']} 缺 file');
        final File glb = File('assets/models/characters/$file');
        expect(glb.existsSync(), isTrue, reason: '写实 GLB 缺失：$file');
        expect(glb.lengthSync(), greaterThan(1024 * 100), reason: '$file 体积异常');

        final int triCount = (entry['triCount'] as num?)?.toInt() ?? 0;
        expect(
          triCount,
          greaterThanOrEqualTo(60000),
          reason: '${entry['id']} 写实面数不足 60k',
        );
        expect(
          triCount,
          lessThanOrEqualTo(120000),
          reason: '${entry['id']} 写实面数超过 120k 硬上限',
        );
        final int base = (entry['baseTriCount'] as num?)?.toInt() ?? 0;
        expect(
          base,
          lessThan(triCount),
          reason: '${entry['id']} 应记录构建期细分前的基础面数',
        );
        expect(
          '${entry['license'] ?? ''}'.isNotEmpty,
          isTrue,
          reason: '${entry['id']} 缺 license',
        );
        expect(
          '${entry['source'] ?? ''}'.isNotEmpty,
          isTrue,
          reason: '${entry['id']} 缺 source',
        );
      }

      // 最高标准路线（MakeHuman/MPFB2）产出必须可追溯；等价替代（CC-BY）若存在也不得沉默。
      final String allSources = entries
          .map((Map<String, Object?> c) => '${c['source']} ${c['file']}')
          .join(' | ');
      expect(
        allSources.toLowerCase().contains('makehuman'),
        isTrue,
        reason: '写实条目未记录 MakeHuman 管线来源',
      );
      expect(
        realistic['pipeline'],
        isA<Map<Object?, Object?>>(),
        reason: 'realistic.pipeline 必须记录管线各步骤（Blender/插件/资产/骨架）',
      );
    });

    test('realistic.items 与 characters 条目一致，且保持轻量/兜底资产不删除（R26）', () {
      final List<Object?> items =
          realistic['items'] as List<Object?>? ?? <Object?>[];
      expect(
        items.length,
        greaterThanOrEqualTo(2),
        reason: 'realistic.items 应同时登记 MakeHuman 产出与等价兜底资产',
      );
      for (final Object? raw in items) {
        final Map<String, Object?> item = (raw as Map).cast<String, Object?>();
        final File glb = File('assets/models/characters/${item['file']}');
        expect(glb.existsSync(), isTrue, reason: '写实资产缺失：${item['file']}');
        expect(
          (item['triCount'] as num?)?.toInt() ?? 0,
          greaterThanOrEqualTo(40000),
        );
      }
    });

    test('引擎 bundle 含写实挂载与骨骼模糊映射特征串（UI 可加载）', () {
      final File bundle = File('assets/engine/js/engine.bundle.js');
      expect(bundle.existsSync(), isTrue);
      final String js = bundle.readAsStringSync();
      for (final String feature in <String>[
        'realisticAvailable',
        'listRealisticCharacters',
        'boneMappingStats',
        'realistic',
      ]) {
        expect(
          js.contains(feature),
          isTrue,
          reason: 'engine.bundle.js 缺少写实特征串 $feature',
        );
      }
      // 骨骼模糊匹配的候选键必须覆盖 MakeHuman 命名（game_engine 骨架）。
      final File character = File('assets/engine/js/character.js');
      final String src = character.readAsStringSync();
      for (final String key in <String>[
        'upperarm',
        'lowerarm',
        'thigh',
        'calf',
        'neck01',
        'spine01',
      ]) {
        expect(src.contains(key), isTrue, reason: 'character.js 骨骼模糊匹配缺少 $key');
      }
      expect(
        src.contains('REALISTIC_IDENTITY_REMAP'),
        isTrue,
        reason: '缺少写实躯干链矫正豁免（避免头颈被拧到非自然角度）',
      );
      expect(src.contains('isRealisticEntry'), isTrue, reason: '缺少写实条目判定');
    });

    test('构建报告与三张截图证据存在（正/侧/非直立姿势）', () {
      final File report = File(
        '../docs/screenshots/realistic-build-report.json',
      );
      expect(report.existsSync(), isTrue, reason: '缺少写实构建报告');
      final Map<String, Object?> data =
          (jsonDecode(report.readAsStringSync()) as Map)
              .cast<String, Object?>();
      expect(data['ok'], isTrue, reason: '构建报告标记失败');
      expect(
        (data['totalTris'] as num?)?.toInt() ?? 0,
        greaterThanOrEqualTo(60000),
      );
      expect(data['rig'], isA<Map<Object?, Object?>>(), reason: '构建报告缺骨架信息');
      final List<Object?> bones =
          ((data['rig'] as Map)['bones'] as List<Object?>?) ?? <Object?>[];
      expect(bones.length, greaterThanOrEqualTo(40), reason: '骨架关节数不足');

      for (final String shot in <String>[
        'realistic-view0.png',
        'realistic-view1.png',
        'realistic-posed.png',
      ]) {
        final File png = File('../docs/screenshots/$shot');
        expect(png.existsSync(), isTrue, reason: '缺少截图 $shot');
        expect(png.lengthSync(), greaterThan(10 * 1024), reason: '$shot 内容异常');
      }
    });
  });
}
