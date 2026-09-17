import 'dart:io';

import 'package:image/image.dart' as img;

/// W3 verification: hero screenshot must show aperture art, headline text and
/// CTA buttons above the fold. Usage: dart run tool/verify_hero_shot.dart <png>
void main(List<String> args) {
  final String path = args.isNotEmpty ? args.first : 'docs/screenshots/web-hero.png';
  final File file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('missing $path');
    exit(2);
  }
  final img.Image? image = img.decodePng(file.readAsBytesSync());
  if (image == null) {
    stderr.writeln('decode failed');
    exit(2);
  }
  var accentBlue = 0;
  var accent2 = 0;
  var orange = 0;
  var darkTextTopLeft = 0;
  var leftCtaBlue = 0;
  var stripDark = 0;
  for (final img.Pixel p in image) {
    final int r = p.r.toInt(), g = p.g.toInt(), b = p.b.toInt();
    // 胶片带区域（右侧视觉列左缘，实测 x≈735–800）应为深色带。
    if (r < 90 && g < 90 && b < 100 && p.x > 730 && p.x < 805) stripDark++;
    if (b > 190 && r < 130 && g < 150) {
      accentBlue++;
      if (p.x < image.width ~/ 2 && p.y > image.height * 0.4 && p.y < image.height) {
        leftCtaBlue++;
      }
    }
    if (b > 200 && r > 90 && r < 160 && g < 130) accent2++;
    if (r > 200 && g > 80 && g < 150 && b < 80) orange++;
    if (r < 60 && g < 60 && b < 70 && p.x < image.width ~/ 2 && p.y < image.height ~/ 2) {
      darkTextTopLeft++;
    }
  }
  final double total = (image.width * image.height).toDouble();
  stdout.writeln('size=${image.width}x${image.height} '
      'accentBlue=${(accentBlue / total * 100).toStringAsFixed(2)}% '
      'accent2=${(accent2 / total * 100).toStringAsFixed(2)}% '
      'orange=$orange leftCtaBlue=${(leftCtaBlue / total * 100).toStringAsFixed(2)}% '
      'darkTextTopLeft=$darkTextTopLeft stripDark=$stripDark');
  final bool ok = accentBlue / total > 0.004 &&
      leftCtaBlue / total > 0.002 &&
      darkTextTopLeft > 120 &&
      orange > 3 &&
      stripDark > 1500;
  stdout.writeln(ok ? 'HERO-OK' : 'HERO-FAIL');
  exit(ok ? 0 : 1);
}
