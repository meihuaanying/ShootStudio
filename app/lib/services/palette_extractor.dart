import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// 五色主色卡提取（PRD M1：静帧/导入图自动色卡）。
/// 流程：解码 → 64×64 缩略 → RGB 4bit 分桶统计 → 频次优先 + 最小色距贪心 → 派生补齐。
class PaletteExtractor {
  PaletteExtractor._();

  static const List<String> fallback = <String>[
    '#888888',
    '#777777',
    '#666666',
    '#555555',
    '#444444',
  ];

  static PaletteResult extract(
    Uint8List bytes, {
    int count = 5,
    int minDistance = 48,
  }) {
    img.Image? image;
    try {
      image = img.decodeImage(bytes);
    } catch (_) {
      image = null;
    }
    if (image == null) return const PaletteResult(fallback);

    final small = img.copyResize(
      image,
      width: 64,
      height: 64,
      interpolation: img.Interpolation.average,
    );
    final buckets = <int, int>{};
    final sums = <int, List<int>>{};
    for (final p in small) {
      final r = p.r.toInt(), g = p.g.toInt(), b = p.b.toInt();
      final key = _bucket(r, g, b);
      buckets[key] = (buckets[key] ?? 0) + 1;
      final s = sums.putIfAbsent(key, () => <int>[0, 0, 0]);
      s[0] += r;
      s[1] += g;
      s[2] += b;
    }

    final order = buckets.keys.toList()
      ..sort((int a, int b) => buckets[b]!.compareTo(buckets[a]!));

    final picked = <List<int>>[];
    for (final key in order) {
      final rgb = _avg(sums[key]!, buckets[key]!);
      if (picked.every(
        (List<int> c) => _dist2(rgb, c) >= minDistance * minDistance,
      )) {
        picked.add(rgb);
        if (picked.length >= count) break;
      }
    }
    // 放宽距离补齐。
    if (picked.length < count) {
      for (final key in order) {
        if (picked.length >= count) break;
        final rgb = _avg(sums[key]!, buckets[key]!);
        if (picked.every((List<int> c) => _dist2(rgb, c) > 4)) picked.add(rgb);
      }
    }
    // 纯色/低彩度图派生明度阶梯补齐。
    if (picked.length < count) {
      final base = picked.isNotEmpty ? picked.first : <int>[136, 136, 136];
      var i = 1;
      while (picked.length < count) {
        final t = i * 0.16;
        picked.add(
          i.isOdd
              ? <int>[
                  (base[0] + (255 - base[0]) * t).round(),
                  (base[1] + (255 - base[1]) * t).round(),
                  (base[2] + (255 - base[2]) * t).round(),
                ]
              : <int>[
                  (base[0] * (1 - t)).round(),
                  (base[1] * (1 - t)).round(),
                  (base[2] * (1 - t)).round(),
                ],
        );
        i++;
      }
    }
    return PaletteResult(picked.map(_hex).toList(growable: false));
  }

  static int _bucket(int r, int g, int b) =>
      (r >> 4 << 8) | (g >> 4 << 4) | (b >> 4);

  static List<int> _avg(List<int> sum, int n) => <int>[
    (sum[0] / n).round(),
    (sum[1] / n).round(),
    (sum[2] / n).round(),
  ];

  static int _dist2(List<int> a, List<int> b) {
    final dr = a[0] - b[0], dg = a[1] - b[1], db = a[2] - b[2];
    return dr * dr + dg * dg + db * db;
  }

  static String _hex(List<int> c) =>
      '#${c[0].toRadixString(16).padLeft(2, '0')}'
      '${c[1].toRadixString(16).padLeft(2, '0')}'
      '${c[2].toRadixString(16).padLeft(2, '0')}';

  /// 色距（供 UI 排序/合并）。
  static double colorDistance(String hexA, String hexB) {
    final a = int.tryParse(hexA.replaceFirst('#', ''), radix: 16) ?? 0;
    final b = int.tryParse(hexB.replaceFirst('#', ''), radix: 16) ?? 0;
    final dr = ((a >> 16) & 0xFF) - ((b >> 16) & 0xFF);
    final dg = ((a >> 8) & 0xFF) - ((b >> 8) & 0xFF);
    final db = (a & 0xFF) - (b & 0xFF);
    return math.sqrt((dr * dr + dg * dg + db * db).toDouble());
  }
}

class PaletteResult {
  const PaletteResult(this.colors);
  final List<String> colors;

  String get joined => colors.join(',');
}
