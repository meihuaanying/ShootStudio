import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/services/content_packs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('城市库 ≥60：名称/坐标/档位齐全，档位系数存在（F10）', () async {
    final List<CityEntry> cities = await ContentPacks.cities();
    expect(cities.length, greaterThanOrEqualTo(60));
    for (final CityEntry city in cities) {
      expect(city.name, isNotEmpty);
      expect(city.lat.abs(), lessThanOrEqualTo(90));
      expect(city.lon.abs(), lessThanOrEqualTo(180));
      expect(<String>['一线', '新一线', '二线', '三线'], contains(city.tier));
    }
    final Map<String, double> multipliers =
        await ContentPacks.cityMultipliers();
    expect(multipliers['一线'], greaterThan(1));
    expect(multipliers['三线'], lessThan(1));
  });

  test('预算参考区间 ≥10 项且 min<max（F9）', () async {
    final List<BudgetItemEntry> items = await ContentPacks.budgetRefs();
    expect(items.length, greaterThanOrEqualTo(10));
    for (final BudgetItemEntry item in items) {
      expect(item.label, isNotEmpty);
      expect(item.min, greaterThan(0));
      expect(item.max, greaterThan(item.min));
    }
  });

  test('照片姿势包（V4）全部具备镜头建议与机位建议（F11/D69）', () async {
    final List<PoseEntry> poses = await ContentPacks.poses();
    expect(poses.length, 120);
    for (final PoseEntry pose in poses) {
      expect(pose.photo, isNotEmpty, reason: '${pose.name} 缺实拍照片');
      expect(pose.lens, isNotEmpty, reason: '${pose.name} 缺少镜头建议');
      expect(pose.cameraPosition, isNotEmpty, reason: '${pose.name} 缺少机位建议');
    }
  });
}
