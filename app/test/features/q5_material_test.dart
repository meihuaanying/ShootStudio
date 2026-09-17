import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/core/db/database.dart';
import 'package:shoot_studio/core/providers.dart';
import 'package:shoot_studio/features/lighting/lighting_controller.dart';

/// Q5 写实材质 + HDRI + 接触阴影门禁（D89–D91 / R37–R38）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('材质分类与贴图保护（D89/R37）', () {
    late String src;
    setUpAll(() {
      final File file = File('assets/engine/js/materials.js');
      expect(file.existsSync(), isTrue, reason: '缺少 materials.js');
      src = file.readAsStringSync();
    });

    test('分类规则：皮肤/头发/眼睛/金属/鞋/布料（含 Human.* 名单）', () {
      // D89 名单：body/lips/ears/fingernails/teeth/tongue/face → skin。
      expect(
        RegExp(r'/skin\|body\|lips\?\|ear\|fingernail\|teeth\|tongue\|face/')
            .hasMatch(src),
        isTrue,
        reason: '缺少皮肤分类正则',
      );
      // eyelashes/brow/short01 → hair。
      expect(RegExp(r'/hair\|brow\|moustache\|beard\|eyelash/').hasMatch(src),
          isTrue);
      expect(RegExp(r'/short0\?\\d\+\$/').hasMatch(src), isTrue,
          reason: '缺少 Human.short01 短发分类');
      // high-poly → eye。
      expect(RegExp(r'/high-\?poly/').hasMatch(src), isTrue);
      // 金属/鞋/布料兜底。
      expect(
        RegExp(r'/metal\|gold\|silver\|earring\|visor\|buckle\|zipper\|chain\|armor/')
            .hasMatch(src),
        isTrue,
      );
      expect(
          RegExp(r'/shoe\|boot\|sneaker\|sandal\|heel/').hasMatch(src), isTrue);
      // 顺序红线：hair 先于 skin（Human.eyelashes01 不得被判成皮肤）。
      expect(src.indexOf('hair|brow') < src.indexOf('skin|body'), isTrue);
      // 眼睛先于皮肤（Human.high-poly）。
      expect(src.indexOf('high-?poly') < src.indexOf('skin|body'), isTrue);
    });

    test('R37：baseSnapshot 记录 authored 贴图，预设切换先恢复再注入', () {
      for (final String field in <String>[
        'normalMap: material.normalMap || null',
        'roughnessMap: material.roughnessMap || null',
        'metalnessMap: material.metalnessMap || null',
        'alphaMap: material.alphaMap || null',
      ]) {
        expect(src.contains(field), isTrue, reason: 'baseSnapshot 缺少 $field');
      }
      // 预设应用时先恢复 authored 贴图（绝不清除）。
      expect(src.contains('material.normalMap = base.normalMap'), isTrue);
      expect(src.contains('material.roughnessMap = base.roughnessMap'), isTrue);
      expect(src.contains('material.metalnessMap = base.metalnessMap'), isTrue);
      expect(src.contains('material.alphaMap = base.alphaMap'), isTrue);
      // 布料噪声仅在「无 authored normalMap 且 hasUV」时注入。
      expect(src.contains('!base.normalMap'), isTrue);
      // 每次预设切换清理旧注入（可逆）。
      expect(src.contains('material.onBeforeCompile = () => {}'), isTrue);
      expect(src.contains('delete material.customProgramCacheKey'), isTrue);
    });

    test('D89：预积分皮肤 BRDF LUT + wrap 光照 + 布料 sheen', () {
      expect(src.contains('getSkinLutTexture'), isTrue);
      expect(src.contains('ssSkinLut'), isTrue);
      expect(src.contains('ss-skin-sss-v2'), isTrue);
      expect(src.contains('ss-cloth-sheen-'), isTrue);
      // wrap diffuse：软化明暗交界。
      expect(src.contains('+ 0.32 ) / 1.32'), isTrue);
      // LUT 运行时程序化生成（DataTexture，无外部资源）。
      expect(src.contains('new THREE.DataTexture'), isTrue);
      expect(src.contains('realistic'), isTrue);
      expect(src.contains('light'), isTrue);
    });
  });

  group('引擎 bundle 材质/HDRI/接触阴影静态门禁', () {
    test('bundle 含关键特征串（压缩后仍保留）', () {
      final String js =
          File('assets/engine/js/engine.bundle.js').readAsStringSync();
      for (final String token in <String>[
        'ss-skin-sss-v2',
        'ss-cloth-sheen-',
        'ssSkinLut',
        'studio_small_03_1k.hdr',
        'RGBELoader',
        'setContactShadow',
        'getContactShadow',
        'contact-shadow',
        'getEnvironmentSource',
        'environmentChanged',
        'qaFocusJoint',
      ]) {
        expect(js.contains(token), isTrue, reason: '引擎缺少 $token');
      }
      // 分类正则（minify 不改正则字面量）。
      expect(js.contains('/skin|body|lips?|ear|fingernail|teeth|tongue|face/'),
          isTrue);
      expect(js.contains('/hair|brow|moustache|beard|eyelash/'), isTrue);
      expect(RegExp(r'/high-\?poly/').hasMatch(js), isTrue);
      // 预算：≤2.2MB（R21 延续）。
      expect(js.length, lessThan(2.2 * 1024 * 1024));
    });
  });

  group('HDRI 资产与登记（D90）', () {
    test('HDRI 文件存在 + pubspec 声明 + attribution 登记', () {
      final File hdr = File('assets/engine/env/studio_small_03_1k.hdr');
      expect(hdr.existsSync(), isTrue, reason: '缺少 studio HDRI');
      expect(hdr.lengthSync(), greaterThan(1024 * 100));

      final String pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec.contains('assets/engine/env/'), isTrue,
          reason: 'pubspec 未声明 assets/engine/env/');

      final Map<String, Object?> attribution = (jsonDecode(
                  File('assets/content/attribution.json').readAsStringSync())
              as Map)
          .cast<String, Object?>();
      final List<Map<String, Object?>> items =
          (attribution['items'] as List<Object?>? ?? <Object?>[])
              .map((Object? e) => (e as Map).cast<String, Object?>())
              .toList();
      final Iterable<Map<String, Object?>> hdrItems = items.where(
          (Map<String, Object?> e) =>
              '${e['file']}'.contains('studio_small_03'));
      expect(hdrItems.length, 1, reason: 'HDRI 未在 attribution 登记');
      final Map<String, Object?> entry = hdrItems.first;
      expect('${entry['license']}'.toUpperCase(), contains('CC0'));
      expect('${entry['source']}'.contains('polyhaven.com'), isTrue);
      expect('${entry['author']}'.contains('Poly Haven'), isTrue);
    });

    test('qa.html 支持材质/接触阴影/特写/探针 QA 参数', () {
      final String qa = File('assets/engine/qa.html').readAsStringSync();
      for (final String token in <String>[
        "q.get('preset')",
        "q.get('contact')",
        "q.get('focus')",
        "q.get('probe')",
        'setMaterialPreset',
        'setContactShadow',
        'qaFocusJoint',
        'getEnvironmentSource',
      ]) {
        expect(qa.contains(token), isTrue, reason: 'qa.html 缺少 $token');
      }
    });
  });

  group('材质 QA 证据（D91/Q3 门禁）', () {
    test('对比截图齐备（皮肤/布料/金属 × realistic/standard + 接触阴影 + 环境光）', () {
      const List<String> files = <String>[
        'docs/screenshots/material-skin-realistic.png',
        'docs/screenshots/material-skin-standard.png',
        'docs/screenshots/material-cloth-realistic.png',
        'docs/screenshots/material-cloth-standard.png',
        'docs/screenshots/material-metal-realistic.png',
        'docs/screenshots/material-metal-standard.png',
        'docs/screenshots/material-contact-on.png',
        'docs/screenshots/material-contact-off.png',
        'docs/screenshots/material-contact-standard.png',
        'docs/screenshots/env-ambient-on.png',
        'docs/screenshots/env-ambient-off.png',
        'docs/screenshots/env-ambient-dark.png',
      ];
      for (final String path in files) {
        final File file = File('../$path');
        expect(file.existsSync(), isTrue, reason: '缺少 QA 证据 $path');
        expect(file.lengthSync(), greaterThan(4096), reason: '$path 内容异常');
      }
    });
  });

  group('LightingController 接触阴影（D91/R38）', () {
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

    test('默认开 + 持久化 + 重启恢复', () async {
      final LightingController controller =
          container.read(lightingControllerProvider.notifier);
      expect(container.read(lightingControllerProvider).contactShadow, isTrue,
          reason: '接触阴影默认应为开（R38 性能退路由用户关闭）');
      await controller.setContactShadow(false);
      expect(container.read(lightingControllerProvider).contactShadow, isFalse);
      expect(await db.getSetting('quality_contact_shadow'), '0');

      final ProviderContainer container2 = ProviderContainer(
        overrides: <Override>[databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container2.dispose);
      await container2.read(lightingControllerProvider.notifier).init();
      expect(
          container2.read(lightingControllerProvider).contactShadow, isFalse);
    });

    test('环境光与接触阴影互不联动（D85 语义不冲突）', () async {
      final LightingController controller =
          container.read(lightingControllerProvider.notifier);
      await controller.setAmbientEnabled(false);
      expect(container.read(lightingControllerProvider).contactShadow, isTrue);
      await controller.setContactShadow(false);
      expect(
          container.read(lightingControllerProvider).ambientEnabled, isFalse);
    });
  });
}
