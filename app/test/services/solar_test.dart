import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/services/solar_calculator.dart';

void main() {
  group('SolarCalculator 北京（39.90, 116.40, UTC+8）', () {
    test('夏至日出约 04:46 / 日落约 19:46', () {
      final day = SolarCalculator.compute(
        year: 2026,
        month: 6,
        day: 21,
        latitude: 39.90,
        longitude: 116.40,
      );
      expect(day.sunrise, isNotNull);
      expect(day.sunset, isNotNull);
      expect(day.sunrise!, closeTo(4 * 60 + 46, 15));
      expect(day.sunset!, closeTo(19 * 60 + 46, 15));
    });

    test('冬至日出约 07:32 / 日落约 16:53', () {
      final day = SolarCalculator.compute(
        year: 2026,
        month: 12,
        day: 22,
        latitude: 39.90,
        longitude: 116.40,
      );
      expect(day.sunrise!, closeTo(7 * 60 + 32, 15));
      expect(day.sunset!, closeTo(16 * 60 + 53, 15));
    });

    test('黄金时刻窗口在日出日落内且有序', () {
      final day = SolarCalculator.compute(
        year: 2026,
        month: 6,
        day: 21,
        latitude: 39.90,
        longitude: 116.40,
      );
      final gm = day.goldenMorning!;
      final ge = day.goldenEvening!;
      expect(gm.startMin, greaterThanOrEqualTo(day.sunrise! - 1));
      expect(gm.endMin, lessThan(720));
      expect(ge.startMin, greaterThan(720));
      expect(ge.endMin, lessThanOrEqualTo(day.sunset! + 1));
    });

    test('蓝调时刻早于日出 / 晚于日落', () {
      final day = SolarCalculator.compute(
        year: 2026,
        month: 6,
        day: 21,
        latitude: 39.90,
        longitude: 116.40,
      );
      expect(day.blueMorning!.endMin, lessThanOrEqualTo(day.sunrise! + 1));
      expect(day.blueEvening!.startMin, greaterThanOrEqualTo(day.sunset! - 1));
    });

    test('格式化 HH:mm', () {
      expect(SolarCalculator.fmt(286), '04:46');
      expect(SolarCalculator.fmt(null), '—');
      expect(SolarCalculator.fmt(19 * 60 + 46), '19:46');
    });
  });
}
