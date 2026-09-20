import '../../services/content_packs.dart';

/// 预算估算（F4）：内置价格区间 × 城市档位系数，产出带「估算值」标注的行。
class BudgetEstimator {
  BudgetEstimator._();

  /// 生成预算行（价格取区间中值 × 系数，四舍五入到十位）。
  static List<Map<String, Object?>> estimate({
    required List<BudgetItemEntry> items,
    required double multiplier,
    required String tier,
    bool markEstimate = true,
    int? people,
  }) {
    final List<Map<String, Object?>> rows = <Map<String, Object?>>[];
    for (final BudgetItemEntry item in items) {
      double mid = (item.min + item.max) / 2 * multiplier;
      // 餐饮按人数放大。
      if (item.key == 'meal' && people != null && people > 1) {
        mid *= people;
      }
      final int price = (mid / 10).round() * 10;
      rows.add(<String, Object?>{
        'item': item.label,
        'price': price,
        'note': markEstimate
            ? '估算值（参考 ${item.min.round()}–${item.max.round()} · $tier系数 ${multiplier.toStringAsFixed(2)}）'
            : item.note,
      });
    }
    return rows;
  }

  /// 计算合计（供「自动合计」展示与评分使用；容忍字符串数字与空值）。
  static double total(List<Object?> rows) {
    var sum = 0.0;
    for (final Object? row in rows) {
      if (row is Map) {
        final Object? price = row['price'];
        if (price is num) {
          sum += price.toDouble();
        } else if (price is String) {
          sum += double.tryParse(price) ?? 0;
        }
      }
    }
    return sum;
  }

  /// 按城市名解析系数（未知城市按二线）。
  static double multiplierFor(
    String city,
    Map<String, double> multipliers, {
    String? tier,
  }) {
    if (tier != null && multipliers.containsKey(tier)) {
      return multipliers[tier]!;
    }
    // 兼容：调用方仅给城市名时按二线处理（城市档位在 editors 内已解析）。
    return multipliers['二线'] ?? 1.0;
  }
}
