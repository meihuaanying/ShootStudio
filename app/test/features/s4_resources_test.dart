import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/features/planner/planner_diff.dart';
import 'package:shoot_studio/features/planner/planner_models.dart';
import 'package:shoot_studio/services/content_packs.dart';

PlanModuleData _module(String id, PlanModuleType type, String title,
        Map<String, Object?> data) =>
    PlanModuleData(id: id, type: type, title: title, data: data);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('模块级 diff（D17）', () {
    test('新增 / 删除 / 修改 / 未变 四类变化', () {
      final base = <PlanModuleData>[
        _module(
            'm1', PlanModuleType.theme, '主题', <String, Object?>{'text': '旧文案'}),
        _module('m2', PlanModuleType.budget, '预算', <String, Object?>{
          'rows': <Object?>[
            <String, Object?>{'item': '场地', 'price': 300},
          ],
        }),
        _module('m3', PlanModuleType.crew, '分工',
            <String, Object?>{'rows': <Object?>[]}),
      ];
      final current = <PlanModuleData>[
        _module(
            'm1', PlanModuleType.theme, '主题', <String, Object?>{'text': '新文案'}),
        _module('m3', PlanModuleType.crew, '分工',
            <String, Object?>{'rows': <Object?>[]}),
        _module('m4', PlanModuleType.poses, '姿势',
            <String, Object?>{'poses': <Object?>[]}),
      ];
      final diff = diffPlans(base, current);
      expect(diff.added, hasLength(1));
      expect(diff.added.first.id, 'm4');
      expect(diff.removed, hasLength(1));
      expect(diff.removed.first.id, 'm2');
      expect(diff.changed, hasLength(1));
      expect(diff.changed.first.changedKeys, contains('文本'));
      expect(diff.unchanged, 1);
      expect(diff.totalChanges, 3);
    });

    test('标题变化单独识别', () {
      final base = <PlanModuleData>[
        _module(
            'm1', PlanModuleType.theme, '旧标题', <String, Object?>{'text': 'x'})
      ];
      final current = <PlanModuleData>[
        _module(
            'm1', PlanModuleType.theme, '新标题', <String, Object?>{'text': 'x'})
      ];
      final diff = diffPlans(base, current);
      expect(diff.changed.single.changedKeys, contains('标题'));
    });

    test('完全一致为空 diff', () {
      final modules = <PlanModuleData>[
        _module('m1', PlanModuleType.theme, 'T', <String, Object?>{'text': 'x'})
      ];
      expect(diffPlans(modules, modules).isEmpty, isTrue);
    });
  });

  group('内容包数据完整性（D19–D22）', () {
    test('设备库数量达标（相机≥80 / 镜头≥120 / 灯具≥20）', () async {
      final gear = await ContentPacks.gear();
      final cameras = gear.where((g) => g.kind == 'camera').length;
      final lenses = gear.where((g) => g.kind == 'lens').length;
      final lights = gear.where((g) => g.kind == 'light').length;
      expect(cameras, greaterThanOrEqualTo(80), reason: '相机机身不足');
      expect(lenses, greaterThanOrEqualTo(120), reason: '镜头不足');
      expect(lights, greaterThanOrEqualTo(20), reason: '灯具不足');
      for (final gearItem in gear) {
        expect(gearItem.brand.isNotEmpty, isTrue);
        expect(gearItem.model.isNotEmpty, isTrue);
      }
    });

    test('服装目录 ≥9 类且含示例与渐变', () async {
      final categories = await ContentPacks.clothingCategories();
      expect(categories.length, greaterThanOrEqualTo(9));
      for (final category in categories) {
        expect(category.gradient, hasLength(2));
        expect(category.examples, isNotEmpty);
      }
    });

    test('道具预设 ≥14 条且含价格与分工', () async {
      final props = await ContentPacks.propPresets();
      expect(props.length, greaterThanOrEqualTo(14));
      for (final prop in props) {
        expect(prop.price, greaterThan(0));
        expect(prop.owner, isNotEmpty);
      }
    });

    test('布光预设 ≥20 且设备可实例化', () async {
      final presets = await ContentPacks.lightPresets();
      expect(presets.length, greaterThanOrEqualTo(20));
      for (final preset in presets) {
        expect(preset.devices, isNotEmpty);
      }
    });

    test('模板 ≥8 且照片姿势 ≥120', () async {
      expect((await ContentPacks.templates()).length, greaterThanOrEqualTo(8));
      expect((await ContentPacks.poses()).length, greaterThanOrEqualTo(120));
    });
  });
}
