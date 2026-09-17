import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// F8 桌面成品：确定性生成应用图标（暗底 + 光圈 + 品牌蓝紫）。
/// 产出：assets/icon/app_icon.png、Windows .ico、Android 全密度 mipmap。
void main() {
  final img.Image master = _drawIcon(1024);
  Directory('assets/icon').createSync(recursive: true);
  File('assets/icon/app_icon.png')
      .writeAsBytesSync(img.encodePng(master, level: 9));

  // Windows ICO（256 为任务栏/资源管理器最佳尺寸）。
  final img.Image win = img.copyResize(master,
      width: 256, height: 256, interpolation: img.Interpolation.average);
  File('windows/runner/resources/app_icon.ico')
      .writeAsBytesSync(img.encodeIco(win));
  File('assets/icon/app_icon.ico').writeAsBytesSync(img.encodeIco(win));

  // Android mipmap 全密度。
  const Map<String, int> densities = <String, int>{
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
  };
  for (final MapEntry<String, int> entry in densities.entries) {
    final File target =
        File('android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png');
    if (!target.parent.existsSync()) continue;
    final img.Image sized = img.copyResize(master,
        width: entry.value,
        height: entry.value,
        interpolation: img.Interpolation.average);
    target.writeAsBytesSync(img.encodePng(sized, level: 9));
  }

  stdout.writeln('icons generated: png/ico/android');
}

img.Image _drawIcon(int size) {
  final img.Image image = img.Image(width: size, height: size, numChannels: 4);
  img.fill(image, color: img.ColorRgba8(0, 0, 0, 0));

  // 圆角暗底。
  const int r = 180;
  final img.ColorRgba8 bg = img.ColorRgba8(16, 20, 28, 255);
  img.fillRect(image, x1: 0, y1: 0, x2: size - 1, y2: size - 1, color: bg);
  img.fillCircle(image, x: r, y: r, radius: r, color: bg, antialias: true);
  img.fillCircle(image,
      x: size - 1 - r, y: r, radius: r, color: bg, antialias: true);
  img.fillCircle(image,
      x: r, y: size - 1 - r, radius: r, color: bg, antialias: true);
  img.fillCircle(image,
      x: size - 1 - r, y: size - 1 - r, radius: r, color: bg, antialias: true);
  // 透明度修角（四角外透明）。
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final bool corner =
          (x < r || x > size - 1 - r) && (y < r || y > size - 1 - r);
      if (!corner) continue;
      final double cx = (x < r ? r : size - 1 - r).toDouble();
      final double cy = (y < r ? r : size - 1 - r).toDouble();
      final double d = math.sqrt(math.pow(x - cx, 2) + math.pow(y - cy, 2));
      if (d > r) image.setPixelRgba(x, y, 0, 0, 0, 0);
    }
  }

  // 胶片边框。
  img.drawRect(image,
      x1: 96,
      y1: 96,
      x2: size - 97,
      y2: size - 97,
      color: img.ColorRgba8(232, 234, 240, 235),
      thickness: 14);

  // 光圈叶片（6 片，品牌蓝紫交替）。
  const int blades = 6;
  final double cx = size / 2;
  final double cy = size / 2;
  const double outer = 330;
  const double inner = 155;
  for (var i = 0; i < blades; i++) {
    final double a0 = i * (360 / blades) - 90;
    final double a1 = a0 + 78;
    final double a2 = a0 + 40;
    final img.ColorRgba8 color = i.isEven
        ? img.ColorRgba8(77, 107, 254, 255)
        : img.ColorRgba8(123, 92, 255, 255);
    img.fillPolygon(
      image,
      vertices: <img.Point>[
        img.Point((cx + outer * math.cos(a0 * math.pi / 180)).round(),
            (cy + outer * math.sin(a0 * math.pi / 180)).round()),
        img.Point((cx + outer * math.cos(a1 * math.pi / 180)).round(),
            (cy + outer * math.sin(a1 * math.pi / 180)).round()),
        img.Point((cx + inner * math.cos(a2 * math.pi / 180)).round(),
            (cy + inner * math.sin(a2 * math.pi / 180)).round()),
      ],
      color: color,
    );
  }
  // 中心通光孔。
  img.fillCircle(image,
      x: (cx).round(),
      y: (cy).round(),
      radius: 132,
      color: bg,
      antialias: true);

  // 高光橙点（品牌点缀）。
  img.fillCircle(image,
      x: size - 210,
      y: 210,
      radius: 34,
      color: img.ColorRgba8(227, 115, 24, 255),
      antialias: true);
  return image;
}
