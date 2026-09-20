import 'dart:math' as math;

/// 日照计算（PRD M5 日照时间模块）：日出日落 / 黄金时刻 / 蓝调时刻。
/// 简化 NOAA 太阳位置算法：按分钟步进求太阳高度角曲线后提取窗口。
class SolarCalculator {
  SolarCalculator._();

  /// 太阳高度角（度）。[minutesUtcFromMidnight] 可为负。
  static double altitudeDeg({
    required DateTime dateUtc,
    required double latitude,
    required double longitude,
    required double minutesUtcFromMidnight,
  }) {
    final dayOfYear = _dayOfYear(dateUtc);
    final fracYear =
        2 *
        math.pi /
        365 *
        (dayOfYear - 1 + (minutesUtcFromMidnight - 720) / 1440);
    final eqTime =
        229.18 *
        (0.000075 +
            0.001868 * math.cos(fracYear) -
            0.032077 * math.sin(fracYear) -
            0.014615 * math.cos(2 * fracYear) -
            0.040849 * math.sin(2 * fracYear));
    final decl =
        0.006918 -
        0.399912 * math.cos(fracYear) +
        0.070257 * math.sin(fracYear) -
        0.006758 * math.cos(2 * fracYear) +
        0.000907 * math.sin(2 * fracYear) -
        0.002697 * math.cos(3 * fracYear) +
        0.00148 * math.sin(3 * fracYear);
    final tst = minutesUtcFromMidnight + eqTime + 4 * longitude;
    final ha = (tst / 4 - 180) * math.pi / 180;
    final lat = latitude * math.pi / 180;
    final cosZenith =
        math.sin(lat) * math.sin(decl) +
        math.cos(lat) * math.cos(decl) * math.cos(ha);
    final zenith = math.acos(cosZenith.clamp(-1.0, 1.0));
    return 90 - zenith * 180 / math.pi;
  }

  /// 计算某地某天全部窗口（时间为当地分钟数，自 0 点起）。
  static SolarDay compute({
    required int year,
    required int month,
    required int day,
    required double latitude,
    required double longitude,
    double utcOffsetHours = 8,
  }) {
    final altitude = List<double>.filled(1440, 0);
    for (var m = 0; m < 1440; m++) {
      altitude[m] = altitudeDeg(
        dateUtc: DateTime.utc(year, month, day),
        latitude: latitude,
        longitude: longitude,
        minutesUtcFromMidnight: m - utcOffsetHours * 60,
      );
    }

    double? crossing(double target, {required bool rising}) {
      for (var m = 0; m < 1439; m++) {
        final a = altitude[m];
        final b = altitude[m + 1];
        if (rising && a < target && b >= target) {
          return m + (target - a) / (b - a);
        }
        if (!rising && a >= target && b < target) {
          return m + (a - target) / (a - b);
        }
      }
      return null;
    }

    final sunrise = crossing(-0.833, rising: true);
    final sunset = crossing(-0.833, rising: false);
    final goldenMorningEnd = crossing(6, rising: true);
    final goldenEveningStart = crossing(6, rising: false);
    final blueMorningEnd = crossing(-4, rising: true);
    final blueMorningStart = crossing(-6, rising: true);
    final blueEveningStart = crossing(-4, rising: false);
    final blueEveningEnd = crossing(-6, rising: false);

    return SolarDay(
      sunrise: sunrise,
      sunset: sunset,
      goldenMorning:
          (sunrise != null &&
              goldenMorningEnd != null &&
              goldenMorningEnd > sunrise)
          ? SolarWindow('黄金时刻（晨）', sunrise, goldenMorningEnd)
          : null,
      goldenEvening:
          (goldenEveningStart != null &&
              sunset != null &&
              sunset > goldenEveningStart)
          ? SolarWindow('黄金时刻（暮）', goldenEveningStart, sunset)
          : null,
      blueMorning:
          (blueMorningStart != null &&
              blueMorningEnd != null &&
              blueMorningEnd > blueMorningStart)
          ? SolarWindow('蓝调时刻（晨）', blueMorningStart, blueMorningEnd)
          : null,
      blueEvening:
          (blueEveningStart != null &&
              blueEveningEnd != null &&
              blueEveningEnd > blueEveningStart)
          ? SolarWindow('蓝调时刻（暮）', blueEveningStart, blueEveningEnd)
          : null,
    );
  }

  static int _dayOfYear(DateTime d) =>
      d.difference(DateTime(d.year, 1, 1)).inDays + 1;

  /// 分钟 → HH:mm。
  static String fmt(double? minutes) {
    if (minutes == null || minutes < 0) return '—';
    final total = ((minutes.round() % 1440) + 1440) % 1440;
    return '${(total ~/ 60).toString().padLeft(2, '0')}:'
        '${(total % 60).toString().padLeft(2, '0')}';
  }
}

class SolarWindow {
  const SolarWindow(this.label, this.startMin, this.endMin);
  final String label;
  final double startMin;
  final double endMin;
}

class SolarDay {
  const SolarDay({
    required this.sunrise,
    required this.sunset,
    required this.goldenMorning,
    required this.goldenEvening,
    required this.blueMorning,
    required this.blueEvening,
  });

  final double? sunrise;
  final double? sunset;
  final SolarWindow? goldenMorning;
  final SolarWindow? goldenEvening;
  final SolarWindow? blueMorning;
  final SolarWindow? blueEvening;
}
