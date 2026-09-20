import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Q1 高面数 3D 与材质升级验收（D61–D64、R18/R21/R26）。
// 细分方案为运行时 Loop（character.js + subdivision.js），manifest 的 triCount
// 由 tool/subdivide_characters.mjs 依据同一个 subdivision_plan.js 计算写回。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, Object?> manifest;
  late List<Map<String, Object?>> characters;

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
  });

  group('Q1 3D 高面数与材质', () {
    test('manifest ≥21 角色，每个 triCount ∈ [40000, 120000]（D62/R18）', () {
      expect(characters.length, greaterThanOrEqualTo(21));
      for (final Map<String, Object?> character in characters) {
        final Object? triCount = character['triCount'];
        expect(triCount, isA<num>(), reason: '${character['id']} 缺 triCount');
        expect(
          (triCount! as num).toInt(),
          inInclusiveRange(40000, 120000),
          reason: '${character['id']} 细分后三角面数越界',
        );
        final Object? base = character['baseTriCount'];
        expect(base, isA<num>(), reason: '${character['id']} 缺 baseTriCount');
        expect(
          (triCount as num).toInt(),
          greaterThan((base! as num).toInt()),
          reason: '${character['id']} 细分后应高于原始面数',
        );
      }
      final Map<String, Object?> subdivision =
          (manifest['subdivision'] as Map?)?.cast<String, Object?>() ??
          <String, Object?>{};
      expect(subdivision['mode'], 'runtime-loop');
      expect(
        (subdivision['levels'] as List<Object?>? ?? <Object?>[])
            .map((Object? e) => '$e')
            .toList(),
        containsAll(<String>['0', '1', '2']),
      );
    });

    test('D64：精选内置 2–4 个，其余带 downloadUrl 或 needsDownload', () {
      final List<Map<String, Object?>> bundled = characters
          .where((Map<String, Object?> c) => c['bundled'] == true)
          .toList();
      expect(bundled.length, inInclusiveRange(2, 4));
      for (final Map<String, Object?> character in characters) {
        expect(
          character.containsKey('bundled'),
          isTrue,
          reason: '${character['id']} 缺 bundled 字段',
        );
        if (character['bundled'] == true) continue;
        final bool hasUrl = '${character['downloadUrl'] ?? ''}'.isNotEmpty;
        final bool needsDownload = character['needsDownload'] == true;
        expect(
          hasUrl || needsDownload,
          isTrue,
          reason: '${character['id']} 非精选但既无 downloadUrl 也无 needsDownload',
        );
      }
    });

    test('R26：轻量模式原 GLB 全部保留且非空', () {
      for (final Map<String, Object?> character in characters) {
        final File glb = File('assets/models/characters/${character['file']}');
        expect(
          glb.existsSync(),
          isTrue,
          reason: '${character['file']} 被删除（违反 R26）',
        );
        expect(
          glb.lengthSync(),
          greaterThan(1024),
          reason: '${character['file']} 内容异常',
        );
      }
    });

    test('D62/D63：引擎包含细分与材质预设实现', () {
      final File bundle = File('assets/engine/js/engine.bundle.js');
      expect(bundle.existsSync(), isTrue);
      final String js = bundle.readAsStringSync();
      expect(
        js.contains('LoopSubdivision'),
        isTrue,
        reason: '缺少 LoopSubdivision 特征串',
      );
      expect(js.contains('skin-preserving-loop'), isTrue, reason: '缺少蒙皮保持细分实现');
      expect(
        js.contains('setSubdivision'),
        isTrue,
        reason: '缺少 setSubdivision API',
      );
      expect(
        js.contains('setMaterialPreset'),
        isTrue,
        reason: '缺少 setMaterialPreset API',
      );
      expect(js.contains('realistic'), isTrue, reason: '缺少 realistic 预设');
      expect(js.contains('standard'), isTrue, reason: '缺少 standard 预设');
      expect(js.contains('light'), isTrue, reason: '缺少 light 预设');
      expect(js.contains('qaSkinningProbe'), isTrue, reason: '缺少蒙皮变形探针');
      expect(
        bundle.lengthSync(),
        lessThanOrEqualTo(2200 * 1024),
        reason: 'engine.bundle.js 超出 2.2MB 预算',
      );
    });

    test('D61：写实模式状态可追溯，素材存在性一致', () {
      expect(manifest.containsKey('realisticAvailable'), isTrue);
      final Map<String, Object?> realistic =
          (manifest['realistic'] as Map?)?.cast<String, Object?>() ??
          <String, Object?>{};
      expect(
        '${realistic['note'] ?? ''}'.isNotEmpty,
        isTrue,
        reason: '写实模式必须记录尝试/偏差说明',
      );
      final List<Object?> items =
          realistic['items'] as List<Object?>? ?? <Object?>[];
      if (manifest['realisticAvailable'] == true) {
        expect(items, isNotEmpty);
        for (final Object? raw in items) {
          final Map<String, Object?> item = (raw as Map)
              .cast<String, Object?>();
          final File file = File('assets/models/characters/${item['file']}');
          expect(file.existsSync(), isTrue, reason: '写实素材缺失：${item['file']}');
          expect(
            (item['triCount'] as num?)?.toInt() ?? 0,
            greaterThanOrEqualTo(40000),
          );
        }
      } else {
        expect(items, isEmpty);
      }
      final File attribution = File(
        'assets/models/characters/realistic/attribution.json',
      );
      if (manifest['realisticAvailable'] == true) {
        expect(attribution.existsSync(), isTrue, reason: '写实素材缺署名文件');
        final Map<String, Object?> data =
            (jsonDecode(attribution.readAsStringSync()) as Map)
                .cast<String, Object?>();
        final List<Object?> attributionItems =
            data['items'] as List<Object?>? ?? <Object?>[];
        final Set<String> files = attributionItems
            .map((Object? e) => '${(e as Map)['file']}')
            .toSet();
        expect(
          files.length,
          attributionItems.length,
          reason: '署名文件按 file 去重后数量不一致',
        );
        expect(
          files.any((String f) => f.contains('realistic/')),
          isTrue,
          reason: '署名缺少写实素材条目',
        );
      }
    });
  });
}
