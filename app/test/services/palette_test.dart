import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shoot_studio/services/palette_extractor.dart';

Uint8List _solidPng(int r, int g, int b, {int w = 64, int h = 64}) {
  final image = img.Image(width: w, height: h);
  for (final p in image) {
    p.r = r;
    p.g = g;
    p.b = b;
  }
  return Uint8List.fromList(img.encodePng(image));
}

Uint8List _stripesPng() {
  final image = img.Image(width: 128, height: 64);
  for (var x = 0; x < 128; x++) {
    final r = x < 64 ? 220 : 40;
    for (var y = 0; y < 64; y++) {
      image.setPixelRgb(x, y, r, r ~/ 2, r ~/ 3);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  test('纯色图 → 主色命中且补齐五色', () {
    final palette = PaletteExtractor.extract(_solidPng(194, 78, 42));
    expect(palette.colors.take(3), contains('#c24e2a'));
    expect(palette.colors, hasLength(5));
  });

  test('双色条纹 → 明暗两族都被选中', () {
    final palette = PaletteExtractor.extract(_stripesPng());
    final reds = palette.colors
        .map((String c) => int.parse(c.substring(1, 3), radix: 16))
        .toList();
    expect(reds.any((int r) => r > 150), isTrue);
    expect(reds.any((int r) => r < 100), isTrue);
    expect(palette.colors.toSet().length, 5);
  });

  test('非法字节 → 灰色占位不崩溃', () {
    final palette = PaletteExtractor.extract(
      Uint8List.fromList(<int>[1, 2, 3]),
    );
    expect(palette.colors, hasLength(5));
  });

  test('色距计算', () {
    expect(
      PaletteExtractor.colorDistance('#000000', '#ffffff'),
      closeTo(441.67, 0.1),
    );
    expect(PaletteExtractor.colorDistance('#123456', '#123456'), 0);
  });
}
