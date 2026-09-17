// 内容包生成器 · S4 扩展：设备数据库（D19/D20）/ 服装目录（D21）/ 道具预设（D22）。
// 运行：dart run tool/gen_content_s4.dart
import 'dart:convert';
import 'dart:io';

void _writeJson(String path, Object data) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
  stdout.writeln('written $path');
}

List<Map<String, Object?>> _gear() {
  final items = <Map<String, Object?>>[];

  void cam(String brand, String model, String mount, String sensor, double mp,
      double weight, double price,
      {String series = ''}) {
    items.add(<String, Object?>{
      'id': 'cam-${items.length + 1}',
      'kind': 'camera',
      'brand': brand,
      'model': model,
      'mount': mount,
      'specs': <String, Object?>{
        'sensor': sensor,
        'megapixel': mp,
        'weight_g': weight,
        'series': series,
      },
      'priceRef': price,
    });
  }

  void lens(String brand, String model, String mount, String focal,
      String aperture, double weight, double price,
      {String type = '变焦'}) {
    items.add(<String, Object?>{
      'id': 'lens-${items.length + 1}',
      'kind': 'lens',
      'brand': brand,
      'model': model,
      'mount': mount,
      'specs': <String, Object?>{
        'focal': focal,
        'aperture': aperture,
        'weight_g': weight,
        'type': type,
      },
      'priceRef': price,
    });
  }

  void light(String brand, String model, double power, String cct, int cri,
      String mount, double price,
      {String type = 'COB 常亮'}) {
    items.add(<String, Object?>{
      'id': 'light-${items.length + 1}',
      'kind': 'light',
      'brand': brand,
      'model': model,
      'mount': mount,
      'specs': <String, Object?>{
        'power_w': power,
        'cct': cct,
        'cri': cri,
        'type': type,
      },
      'priceRef': price,
    });
  }

  // ---- 机身（≥80） ----
  cam('佳能', 'EOS R5', 'RF', '全画幅', 45, 738, 22999, series: 'EOS R');
  cam('佳能', 'EOS R6 Mark II', 'RF', '全画幅', 24.2, 670, 16499, series: 'EOS R');
  cam('佳能', 'EOS R8', 'RF', '全画幅', 24.2, 461, 10499, series: 'EOS R');
  cam('佳能', 'EOS R50', 'RF', 'APS-C', 24.2, 375, 4999, series: 'EOS R');
  cam('佳能', 'EOS R10', 'RF', 'APS-C', 24.2, 429, 6499, series: 'EOS R');
  cam('佳能', 'EOS R7', 'RF', 'APS-C', 32.5, 612, 8999, series: 'EOS R');
  cam('佳能', 'EOS R3', 'RF', '全画幅', 24.1, 1015, 34999, series: 'EOS R');
  cam('佳能', 'EOS RP', 'RF', '全画幅', 26.2, 485, 6999, series: 'EOS R');
  cam('佳能', 'EOS R100', 'RF', 'APS-C', 24.1, 356, 3299, series: 'EOS R');
  cam('佳能', 'EOS R5 C', 'RF', '全画幅', 45, 770, 27999, series: 'EOS R');
  cam('佳能', 'EOS R1', 'RF', '全画幅', 24.2, 920, 42999, series: 'EOS R');
  cam('佳能', 'EOS 5D Mark IV', 'EF', '全画幅', 30.4, 890, 12999, series: 'EOS 单反');
  cam('佳能', 'EOS 6D Mark II', 'EF', '全画幅', 26.2, 765, 8999, series: 'EOS 单反');
  cam('佳能', 'EOS 90D', 'EF', 'APS-C', 32.5, 701, 7499, series: 'EOS 单反');
  cam('佳能', 'EOS 200D II', 'EF', 'APS-C', 24.1, 449, 3799, series: 'EOS 单反');
  cam('索尼', 'A7 IV', 'E', '全画幅', 33, 658, 16999, series: 'Alpha');
  cam('索尼', 'A7R V', 'E', '全画幅', 61, 723, 25999, series: 'Alpha');
  cam('索尼', 'A7S III', 'E', '全画幅', 12.1, 699, 23999, series: 'Alpha');
  cam('索尼', 'A7C II', 'E', '全画幅', 33, 514, 14999, series: 'Alpha');
  cam('索尼', 'A7C R', 'E', '全画幅', 61, 515, 20999, series: 'Alpha');
  cam('索尼', 'A1 II', 'E', '全画幅', 50.1, 743, 49999, series: 'Alpha');
  cam('索尼', 'A9 III', 'E', '全画幅', 24.6, 702, 45999, series: 'Alpha');
  cam('索尼', 'A6700', 'E', 'APS-C', 26, 493, 9999, series: 'Alpha');
  cam('索尼', 'ZV-E1', 'E', '全画幅', 12.1, 483, 15999, series: 'ZV');
  cam('索尼', 'ZV-E10 II', 'E', 'APS-C', 26, 377, 7499, series: 'ZV');
  cam('索尼', 'FX3', 'E', '全画幅', 10.2, 715, 29999, series: 'Cinema');
  cam('索尼', 'FX30', 'E', 'APS-C', 26, 646, 13999, series: 'Cinema');
  cam('尼康', 'Z9', 'Z', '全画幅', 45.7, 1340, 35999, series: 'Z');
  cam('尼康', 'Z8', 'Z', '全画幅', 45.7, 910, 27999, series: 'Z');
  cam('尼康', 'Z6 III', 'Z', '全画幅', 24.5, 760, 18999, series: 'Z');
  cam('尼康', 'Z6 II', 'Z', '全画幅', 24.5, 705, 12999, series: 'Z');
  cam('尼康', 'Z7 II', 'Z', '全画幅', 45.7, 705, 18999, series: 'Z');
  cam('尼康', 'Z5', 'Z', '全画幅', 24.3, 675, 7999, series: 'Z');
  cam('尼康', 'Zf', 'Z', '全画幅', 24.5, 710, 14999, series: 'Z');
  cam('尼康', 'Zfc', 'Z', 'APS-C', 20.9, 445, 6499, series: 'Z');
  cam('尼康', 'Z30', 'Z', 'APS-C', 20.9, 405, 4799, series: 'Z');
  cam('尼康', 'Z50', 'Z', 'APS-C', 20.9, 450, 6299, series: 'Z');
  cam('尼康', 'Z50 II', 'Z', 'APS-C', 20.9, 495, 6899, series: 'Z');
  cam('尼康', 'D850', 'F', '全画幅', 45.7, 1005, 19999, series: 'D 单反');
  cam('尼康', 'D780', 'F', '全画幅', 24.5, 840, 13999, series: 'D 单反');
  cam('尼康', 'D7500', 'F', 'APS-C', 20.9, 720, 6499, series: 'D 单反');
  cam('富士', 'X-T5', 'X', 'APS-C', 40.2, 557, 11990, series: 'X');
  cam('富士', 'X-T4', 'X', 'APS-C', 26.1, 607, 8990, series: 'X');
  cam('富士', 'X-H2', 'X', 'APS-C', 40.2, 660, 13390, series: 'X');
  cam('富士', 'X-H2S', 'X', 'APS-C', 26.1, 660, 14990, series: 'X');
  cam('富士', 'X-S20', 'X', 'APS-C', 26.1, 491, 8790, series: 'X');
  cam('富士', 'X-Pro3', 'X', 'APS-C', 26.1, 497, 12990, series: 'X');
  cam('富士', 'X-E4', 'X', 'APS-C', 26.1, 364, 5990, series: 'X');
  cam('富士', 'X100VI', '固定', 'APS-C', 40.2, 521, 11390, series: 'X100');
  cam('富士', 'X-T30 II', 'X', 'APS-C', 26.1, 378, 6590, series: 'X');
  cam('富士', 'X-M5', 'X', 'APS-C', 26.1, 355, 5690, series: 'X');
  cam('富士', 'GFX 100S II', 'GF', '中画幅', 102, 883, 39990, series: 'GFX');
  cam('富士', 'GFX 50S II', 'GF', '中画幅', 51.4, 900, 28990, series: 'GFX');
  cam('富士', 'GFX100 II', 'GF', '中画幅', 102, 948, 53990, series: 'GFX');
  cam('松下', 'S5 II', 'L', '全画幅', 24.2, 740, 13998, series: 'Lumix S');
  cam('松下', 'S5 IIX', 'L', '全画幅', 24.2, 740, 15998, series: 'Lumix S');
  cam('松下', 'S1R', 'L', '全画幅', 47.3, 1020, 19998, series: 'Lumix S');
  cam('松下', 'S1H', 'L', '全画幅', 24.2, 1052, 21998, series: 'Lumix S');
  cam('松下', 'S9', 'L', '全画幅', 24.2, 486, 9998, series: 'Lumix S');
  cam('松下', 'GH6', 'M4/3', 'M4/3', 25.2, 823, 12998, series: 'Lumix G');
  cam('松下', 'G9 II', 'M4/3', 'M4/3', 25.2, 658, 13498, series: 'Lumix G');
  cam('松下', 'G100', 'M4/3', 'M4/3', 20.3, 345, 4798, series: 'Lumix G');
  cam('徕卡', 'Q3', '固定', '全画幅', 60, 743, 49999, series: 'Q');
  cam('徕卡', 'SL3', 'L', '全画幅', 60, 769, 62800, series: 'SL');
  cam('徕卡', 'M11', 'M', '全画幅', 60, 530, 69900, series: 'M');
  cam('适马', 'fp L', 'L', '全画幅', 61, 427, 13999, series: 'fp');
  cam('适马', 'fp', 'L', '全画幅', 24.6, 422, 9999, series: 'fp');
  cam('奥林巴斯', 'OM-1 Mark II', 'M4/3', 'M4/3', 20.4, 599, 13999, series: 'OM');
  cam('奥林巴斯', 'PEN E-P7', 'M4/3', 'M4/3', 20.3, 337, 5499, series: 'PEN');
  cam('理光', 'GR IIIx', '固定', 'APS-C', 24.2, 262, 7299, series: 'GR');
  cam('理光', 'GR III', '固定', 'APS-C', 24.2, 257, 6999, series: 'GR');
  cam('哈苏', 'X2D 100C', 'XCD', '中画幅', 100, 895, 48900, series: 'X');
  cam('哈苏', '907X & CFV 100C', 'XCD', '中画幅', 100, 900, 45900, series: 'V');
  cam('佳能', 'EOS M50 Mark II', 'EF-M', 'APS-C', 24.1, 387, 4699,
      series: 'EOS M');
  cam('索尼', 'A6400', 'E', 'APS-C', 24.2, 403, 7299, series: 'Alpha');
  cam('索尼', 'A6600', 'E', 'APS-C', 24.2, 503, 9899, series: 'Alpha');
  cam('索尼', 'A7 V', 'E', '全画幅', 33, 700, 18999, series: 'Alpha');
  cam('索尼', 'A6100', 'E', 'APS-C', 24.2, 396, 5599, series: 'Alpha');
  cam('佳能', 'EOS R50 V', 'RF', 'APS-C', 24.2, 370, 4799, series: 'EOS R');
  cam('尼康', 'Z6 III Kit', 'Z', '全画幅', 24.5, 760, 20999, series: 'Z');
  cam('富士', 'X-T3', 'X', 'APS-C', 26.1, 539, 7390, series: 'X');

  // ---- 镜头（≥120） ----
  lens('佳能', 'RF 15-35mm F2.8L IS', 'RF', '15-35mm', 'F2.8', 840, 15999);
  lens('佳能', 'RF 24-70mm F2.8L IS', 'RF', '24-70mm', 'F2.8', 900, 16999);
  lens('佳能', 'RF 70-200mm F2.8L IS', 'RF', '70-200mm', 'F2.8', 1070, 17999);
  lens('佳能', 'RF 24-105mm F4L IS', 'RF', '24-105mm', 'F4', 700, 7899);
  lens('佳能', 'RF 50mm F1.2L', 'RF', '50mm', 'F1.2', 950, 16999, type: '定焦');
  lens('佳能', 'RF 85mm F1.2L', 'RF', '85mm', 'F1.2', 1195, 19999, type: '定焦');
  lens('佳能', 'RF 35mm F1.8 Macro', 'RF', '35mm', 'F1.8', 305, 3799, type: '定焦');
  lens('佳能', 'RF 50mm F1.8 STM', 'RF', '50mm', 'F1.8', 160, 1199, type: '定焦');
  lens('佳能', 'RF 85mm F2 Macro', 'RF', '85mm', 'F2', 500, 3999, type: '定焦');
  lens('佳能', 'RF 100mm F2.8L Macro', 'RF', '100mm', 'F2.8', 730, 8999,
      type: '微距');
  lens('佳能', 'RF 70-200mm F4L IS', 'RF', '70-200mm', 'F4', 695, 9999);
  lens('佳能', 'RF 14-35mm F4L IS', 'RF', '14-35mm', 'F4', 540, 9999);
  lens('佳能', 'RF 28-70mm F2L', 'RF', '28-70mm', 'F2', 1430, 21999);
  lens('佳能', 'RF 135mm F1.8L', 'RF', '135mm', 'F1.8', 935, 13999, type: '定焦');
  lens('佳能', 'RF 24mm F1.8 Macro', 'RF', '24mm', 'F1.8', 270, 3699, type: '定焦');
  lens('佳能', 'RF 16mm F2.8 STM', 'RF', '16mm', 'F2.8', 165, 1699, type: '定焦');
  lens('佳能', 'RF 28mm F2.8 STM', 'RF', '28mm', 'F2.8', 120, 1799, type: '定焦');
  lens('佳能', 'RF 100-500mm F4.5-7.1L', 'RF', '100-500mm', 'F4.5-7.1', 1530,
      19999);
  lens('佳能', 'EF 50mm F1.4 USM', 'EF', '50mm', 'F1.4', 290, 2499, type: '定焦');
  lens('佳能', 'EF 85mm F1.8 USM', 'EF', '85mm', 'F1.8', 425, 2199, type: '定焦');
  lens('索尼', 'FE 16-35mm F2.8 GM II', 'E', '16-35mm', 'F2.8', 547, 15999);
  lens('索尼', 'FE 24-70mm F2.8 GM II', 'E', '24-70mm', 'F2.8', 695, 15999);
  lens('索尼', 'FE 70-200mm F2.8 GM II', 'E', '70-200mm', 'F2.8', 1045, 17999);
  lens('索尼', 'FE 35mm F1.4 GM', 'E', '35mm', 'F1.4', 524, 11999, type: '定焦');
  lens('索尼', 'FE 50mm F1.2 GM', 'E', '50mm', 'F1.2', 778, 15999, type: '定焦');
  lens('索尼', 'FE 50mm F1.4 GM', 'E', '50mm', 'F1.4', 516, 9999, type: '定焦');
  lens('索尼', 'FE 85mm F1.4 GM', 'E', '85mm', 'F1.4', 820, 11999, type: '定焦');
  lens('索尼', 'FE 135mm F1.8 GM', 'E', '135mm', 'F1.8', 950, 12999, type: '定焦');
  lens('索尼', 'FE 24mm F1.4 GM', 'E', '24mm', 'F1.4', 445, 9599, type: '定焦');
  lens('索尼', 'FE 24-105mm F4 G', 'E', '24-105mm', 'F4', 663, 7999);
  lens('索尼', 'FE 20-70mm F4 G', 'E', '20-70mm', 'F4', 488, 8299);
  lens('索尼', 'FE 70-200mm F4 G II', 'E', '70-200mm', 'F4', 794, 10999);
  lens('索尼', 'FE 16-25mm F2.8 G', 'E', '16-25mm', 'F2.8', 409, 8499);
  lens('索尼', 'FE 12-24mm F2.8 GM', 'E', '12-24mm', 'F2.8', 847, 21999);
  lens('索尼', 'FE PZ 16-35mm F4 G', 'E', '16-35mm', 'F4', 353, 7499);
  lens('索尼', 'FE 24-50mm F2.8 G', 'E', '24-50mm', 'F2.8', 440, 8999);
  lens('索尼', 'FE 90mm F2.8 Macro G', 'E', '90mm', 'F2.8', 602, 6499,
      type: '微距');
  lens('索尼', 'FE 70-200mm F2.8 GM OSS', 'E', '70-200mm', 'F2.8', 1480, 15999);
  lens('索尼', 'FE 40mm F2.5 G', 'E', '40mm', 'F2.5', 173, 4299, type: '定焦');
  lens('索尼', 'FE 300mm F2.8 GM OSS', 'E', '300mm', 'F2.8', 1470, 39999,
      type: '定焦');
  lens('索尼', 'E 15mm F1.4 G', 'E', '15mm', 'F1.4', 219, 4499, type: '定焦');
  lens('索尼', 'E 11mm F1.8', 'E', '11mm', 'F1.8', 181, 3999, type: '定焦');
  lens('尼康', 'Z 14-24mm F2.8 S', 'Z', '14-24mm', 'F2.8', 650, 13999);
  lens('尼康', 'Z 24-70mm F2.8 S', 'Z', '24-70mm', 'F2.8', 805, 15999);
  lens('尼康', 'Z 70-200mm F2.8 S', 'Z', '70-200mm', 'F2.8', 1360, 16999);
  lens('尼康', 'Z 50mm F1.2 S', 'Z', '50mm', 'F1.2', 1090, 15999, type: '定焦');
  lens('尼康', 'Z 85mm F1.2 S', 'Z', '85mm', 'F1.2', 1160, 18999, type: '定焦');
  lens('尼康', 'Z 35mm F1.8 S', 'Z', '35mm', 'F1.8', 370, 4599, type: '定焦');
  lens('尼康', 'Z 50mm F1.8 S', 'Z', '50mm', 'F1.8', 415, 3799, type: '定焦');
  lens('尼康', 'Z 85mm F1.8 S', 'Z', '85mm', 'F1.8', 470, 5499, type: '定焦');
  lens('尼康', 'Z 24-120mm F4 S', 'Z', '24-120mm', 'F4', 630, 7999);
  lens('尼康', 'Z 100-400mm F4.5-5.6', 'Z', '100-400mm', 'F4.5-5.6', 1435, 16999);
  lens('尼康', 'Z 105mm F2.8 Macro', 'Z', '105mm', 'F2.8', 630, 6999, type: '微距');
  lens('尼康', 'Z 135mm F1.8 Plena', 'Z', '135mm', 'F1.8', 995, 16999,
      type: '定焦');
  lens('尼康', 'Z 14-30mm F4 S', 'Z', '14-30mm', 'F4', 485, 7499);
  lens('尼康', 'Z 28-75mm F2.8', 'Z', '28-75mm', 'F2.8', 565, 6999);
  lens('尼康', 'Z 40mm F2 SE', 'Z', '40mm', 'F2', 170, 1999, type: '定焦');
  lens('尼康', 'Z 24mm F1.8 S', 'Z', '24mm', 'F1.8', 450, 4999, type: '定焦');
  lens('尼康', 'Z 20mm F1.8 S', 'Z', '20mm', 'F1.8', 505, 5499, type: '定焦');
  lens('尼康', 'Z 70-180mm F2.8', 'Z', '70-180mm', 'F2.8', 795, 7999);
  lens('尼康', 'Z 26mm F2.8', 'Z', '26mm', 'F2.8', 125, 3599, type: '定焦');
  lens('富士', 'XF 16-55mm F2.8', 'X', '16-55mm', 'F2.8', 655, 8290);
  lens('富士', 'XF 50-140mm F2.8', 'X', '50-140mm', 'F2.8', 995, 9990);
  lens('富士', 'XF 56mm F1.2 R', 'X', '56mm', 'F1.2', 405, 6990, type: '定焦');
  lens('富士', 'XF 35mm F1.4 R', 'X', '35mm', 'F1.4', 187, 4290, type: '定焦');
  lens('富士', 'XF 23mm F1.4 R LM', 'X', '23mm', 'F1.4', 375, 5990, type: '定焦');
  lens('富士', 'XF 18mm F1.4 R LM', 'X', '18mm', 'F1.4', 370, 5990, type: '定焦');
  lens('富士', 'XF 33mm F1.4 R LM', 'X', '33mm', 'F1.4', 360, 5490, type: '定焦');
  lens('富士', 'XF 90mm F2 R LM', 'X', '90mm', 'F2', 540, 6990, type: '定焦');
  lens('富士', 'XF 8-16mm F2.8', 'X', '8-16mm', 'F2.8', 805, 11990);
  lens('富士', 'XF 16-80mm F4', 'X', '16-80mm', 'F4', 440, 5490);
  lens('富士', 'XF 70-300mm F4-5.6', 'X', '70-300mm', 'F4-5.6', 580, 5990);
  lens('富士', 'XF 80mm F2.8 Macro', 'X', '80mm', 'F2.8', 750, 8990, type: '微距');
  lens('富士', 'XF 150-600mm F5.6-8', 'X', '150-600mm', 'F5.6-8', 1605, 12490);
  lens('富士', 'XC 15-45mm F3.5-5.6', 'X', '15-45mm', 'F3.5-5.6', 135, 1290);
  lens('富士', 'XF 27mm F2.8 R WR', 'X', '27mm', 'F2.8', 84, 3490, type: '定焦');
  lens('富士', 'GF 32-64mm F4', 'GF', '32-64mm', 'F4', 875, 14990);
  lens('富士', 'GF 110mm F2', 'GF', '110mm', 'F2', 1010, 19990, type: '定焦');
  lens('适马', '35mm F1.4 DG DN Art', 'E', '35mm', 'F1.4', 645, 5999, type: '定焦');
  lens('适马', '50mm F1.4 DG DN Art', 'E', '50mm', 'F1.4', 670, 6299, type: '定焦');
  lens('适马', '85mm F1.4 DG DN Art', 'E', '85mm', 'F1.4', 630, 6499, type: '定焦');
  lens('适马', '24-70mm F2.8 DG DN II', 'E', '24-70mm', 'F2.8', 745, 7999);
  lens('适马', '70-200mm F2.8 DG DN OS', 'E', '70-200mm', 'F2.8', 1345, 10999);
  lens('适马', '18-50mm F2.8 DC DN', 'E', '18-50mm', 'F2.8', 290, 2999);
  lens('适马', '135mm F1.8 DG HSM Art', 'E', '135mm', 'F1.8', 1130, 8999,
      type: '定焦');
  lens('适马', 'Art 24-35mm F2 DG HSM', 'E', '24-35mm', 'F2', 940, 6999);
  lens('适马', '100-400mm F5-6.3 DG DN OS', 'E', '100-400mm', 'F5-6.3', 1135,
      6299);
  lens('适马', '65mm F2 DG DN', 'E', '65mm', 'F2', 405, 4299, type: '定焦');
  lens('适马', '20mm F1.4 DG DN Art', 'E', '20mm', 'F1.4', 635, 6499, type: '定焦');
  lens('腾龙', '28-75mm F2.8 G2 A063', 'E', '28-75mm', 'F2.8', 540, 5999);
  lens('腾龙', '17-28mm F2.8 Di III RXD', 'E', '17-28mm', 'F2.8', 420, 5499);
  lens('腾龙', '70-180mm F2.8 Di III VC G2', 'E', '70-180mm', 'F2.8', 855, 8299);
  lens('腾龙', '35-150mm F2-2.8 Di III VXD', 'E', '35-150mm', 'F2-2.8', 1165,
      12999);
  lens('腾龙', '90mm F2.8 Macro VXD', 'E', '90mm', 'F2.8', 630, 5299, type: '微距');
  lens('腾龙', '50-400mm F4.5-6.3 VC', 'E', '50-400mm', 'F4.5-6.3', 1155, 8999);
  lens('腾龙', '20-40mm F2.8 Di III VXD', 'E', '20-40mm', 'F2.8', 365, 4999);
  lens('腾龙', '150-500mm F5-6.7 VC', 'E', '150-500mm', 'F5-6.7', 1725, 9999);
  lens('腾龙', '28-200mm F2.8-5.6', 'E', '28-200mm', 'F2.8-5.6', 575, 5499);
  lens('腾龙', '24mm F1.4 Di III VXD', 'E', '24mm', 'F1.4', 665, 5799,
      type: '定焦');
  lens('腾龙', '70-300mm F4.5-6.3 VC G2', 'E', '70-300mm', 'F4.5-6.3', 545, 3999);
  lens('松下', 'Lumix S 24-70mm F2.8', 'L', '24-70mm', 'F2.8', 935, 13998);
  lens('松下', 'Lumix S 70-200mm F2.8', 'L', '70-200mm', 'F2.8', 1570, 16998);
  lens('松下', 'Lumix S 50mm F1.4', 'L', '50mm', 'F1.4', 955, 10998, type: '定焦');
  lens('松下', 'Lumix S 85mm F1.8', 'L', '85mm', 'F1.8', 355, 4298, type: '定焦');
  lens('松下', 'Lumix S 35mm F1.8', 'L', '35mm', 'F1.8', 295, 3998, type: '定焦');
  lens('松下', 'Lumix S 18mm F1.8', 'L', '18mm', 'F1.8', 340, 4498, type: '定焦');
  lens('松下', 'Lumix S 100mm F2.8 Macro', 'L', '100mm', 'F2.8', 420, 4998,
      type: '微距');
  lens('松下', 'Lumix G 12-35mm F2.8 II', 'M4/3', '12-35mm', 'F2.8', 305, 5998);
  lens('松下', 'Lumix G 35-100mm F2.8 II', 'M4/3', '35-100mm', 'F2.8', 357, 6998);
  lens(
      '奥林巴斯', 'M.Zuiko 12-40mm F2.8 PRO', 'M4/3', '12-40mm', 'F2.8', 382, 6999);
  lens('奥林巴斯', 'M.Zuiko 40-150mm F2.8 PRO', 'M4/3', '40-150mm', 'F2.8', 880,
      10999);
  lens('奥林巴斯', 'M.Zuiko 45mm F1.2 PRO', 'M4/3', '45mm', 'F1.2', 410, 8999,
      type: '定焦');
  lens('奥林巴斯', 'M.Zuiko 17mm F1.2 PRO', 'M4/3', '17mm', 'F1.2', 390, 8999,
      type: '定焦');
  lens('蔡司', 'Batis 40mm F2 CF', 'E', '40mm', 'F2', 361, 8999, type: '定焦');
  lens('蔡司', 'Otus 85mm F1.4', 'EF', '85mm', 'F1.4', 1200, 29999, type: '定焦');

  lens(
      '佳能', 'RF 200-800mm F6.3-9 IS', 'RF', '200-800mm', 'F6.3-9', 2050, 14999);
  lens('索尼', 'FE 100-400mm F4.5-5.6 GM', 'E', '100-400mm', 'F4.5-5.6', 1395,
      16999);
  lens('尼康', 'Z 400mm F4.5 VR S', 'Z', '400mm', 'F4.5', 1160, 22999,
      type: '定焦');
  lens('富士', 'XF 56mm F1.2 R WR', 'X', '56mm', 'F1.2', 445, 7490, type: '定焦');
  lens('适马', '28-105mm F2.8 DG DN Art', 'E', '28-105mm', 'F2.8', 990, 8999);
  lens('腾龙', '11-20mm F2.8 Di III-A', 'E', '11-20mm', 'F2.8', 335, 4299);
  lens('松下', 'Lumix S 28-200mm F4-7.1', 'L', '28-200mm', 'F4-7.1', 413, 4498);
  lens('佳能', 'RF 85mm F1.4L VCM', 'RF', '85mm', 'F1.4', 780, 12999, type: '定焦');
  // ---- 灯具（≥20） ----
  light('神牛 Godox', 'SL60W', 60, '5600K 固定', 95, '保荣', 599);
  light('神牛 Godox', 'SL100 III', 100, '5600K 固定', 96, '保荣', 1099);
  light('神牛 Godox', 'SL150 III', 150, '5600K 固定', 96, '保荣', 1599);
  light('神牛 Godox', 'SL60Bi', 60, '2800-6500K', 96, '保荣', 1099);
  light('神牛 Godox', 'AD200 Pro', 200, '5600K 固定', 96, '保荣/pro', 2499,
      type: '闪光灯');
  light('神牛 Godox', 'AD400 Pro', 400, '5600K 固定', 96, '保荣', 4299, type: '闪光灯');
  light('神牛 Godox', 'AD600 Pro II', 600, '5600K 固定', 96, '保荣', 6399,
      type: '闪光灯');
  light('神牛 Godox', 'ML30Bi', 30, '2800-6500K', 95, '保荣', 499);
  light('神牛 Godox', 'R200 环形闪光灯', 200, '5600K 固定', 96, '保荣', 1899, type: '环闪');
  light('爱图仕 Aputure', 'LS 120D II', 135, '5500K 固定', 96, '保荣', 2599);
  light('爱图仕 Aputure', 'LS 300D II', 350, '5500K 固定', 96, '保荣', 5499);
  light('爱图仕 Aputure', 'LS 300X', 350, '2700-6500K', 95, '保荣', 6499);
  light('爱图仕 Aputure', 'LS 600D Pro', 720, '5600K 固定', 96, '保荣', 16999);
  light('爱图仕 Aputure', 'LS 600X Pro', 720, '2700-6500K', 95, '保荣', 18999);
  light('爱图仕 Aputure', 'MT Pro', 12, '2000-10000K RGBWW', 95, '磁吸', 1199,
      type: '全彩板灯');
  light('爱图仕 Aputure', 'LC 120', 120, '2700-6500K', 95, '保荣', 1499,
      type: '轻便板灯');
  light(
      '爱图仕 Aputure', 'INFINIBAR PB6', 36, '2000-10000K RGBWW', 95, '管灯夹', 2299,
      type: '像素管灯');
  light('南光 Nanlux', 'Evoke 600C', 600, '2700-20000K 全彩', 96, '保荣', 12999);
  light('南光 Nanlux', 'Evoke 1200B', 1200, '2700-6500K', 96, '保荣', 27999);
  light('南光 Nanlite', 'Forza 60B II', 72, '2700-6500K', 96, '保荣', 1599);
  light('南光 Nanlite', 'Forza 300B II', 350, '2700-6500K', 96, '保荣', 5299);
  light('智云 Zhiyun', 'Molus X100', 100, '2700-6500K', 95, '保荣', 999);
  light('智云 Zhiyun', 'Molus G200', 200, '2700-6500K', 95, '保荣', 2999);
  light('永诺 YONGNUO', 'YN360 III', 21, '2000-9900K RGB', 94, '管灯夹', 499,
      type: '像素管灯');
  light('永诺 YONGNUO', 'LUX200', 200, '5600K 固定', 95, '保荣', 1299);

  return items;
}

List<Map<String, Object?>> _clothing() {
  const categories = <String>[
    '正装',
    '休闲',
    '汉服',
    'JK',
    'Lolita',
    'Cos',
    '婚纱',
    '民族',
    '运动'
  ];
  const gradients = <String, List<String>>{
    '正装': <String>['#2f3a4a', '#5b6b80'],
    '休闲': <String>['#e7dfd4', '#b9a893'],
    '汉服': <String>['#8c3f3f', '#c9a24b'],
    'JK': <String>['#2f4a7a', '#d9dee8'],
    'Lolita': <String>['#d77b9f', '#f2d9e2'],
    'Cos': <String>['#4d3f8f', '#d94f78'],
    '婚纱': <String>['#ffffff', '#d8dde6'],
    '民族': <String>['#c9563c', '#e0a83c'],
    '运动': <String>['#2ba471', '#9adfc2'],
  };
  const examples = <String, List<String>>{
    '正装': <String>['西装套装', '衬衫领带', '职业裙装'],
    '休闲': <String>['针织开衫', '白 T 牛仔', '风衣外套'],
    '汉服': <String>['齐胸襦裙', '明制袄裙', '圆领袍', '大袖衫'],
    'JK': <String>['水手服', '格裙套装', '西式制服'],
    'Lolita': <String>['JSK 背心裙', 'OP 连衣裙', '头饰手袖'],
    'Cos': <String>['角色还原套', '假发配件', '道具武器'],
    '婚纱': <String>['主纱', '敬酒服', '外景轻纱'],
    '民族': <String>['苗服', '藏服', '蒙古袍'],
    '运动': <String>['运动套装', '球衣', '瑜伽服'],
  };
  return categories.map((String name) {
    return <String, Object?>{
      'id': 'cloth-${categories.indexOf(name) + 1}',
      'category': name,
      'gradient': gradients[name],
      'examples': examples[name],
      'description': '示例：${examples[name]!.join('、')}（示意图为本地程序化图案，可自定义上传实拍图）',
    };
  }).toList();
}

List<Map<String, Object?>> _props() {
  final list = <List<Object>>[
    <Object>['反光板', 80, '银色/金色双面', '摄影师带'],
    <Object>['透明伞', 35, '长柄透明伞，夜景反光', '道具组买'],
    <Object>['花束', 120, '仿真花束优先', '妆造带'],
    <Object>['烟饼', 30, '注意场地明火规定', '摄影助理买'],
    <Object>['复古箱体', 150, '皮箱/木箱', '模特自带'],
    <Object>['背景布', 200, '绒布 3×6m', '工作室提供'],
    <Object>['折椅', 90, '便携马扎', '后勤带'],
    <Object>['扇子', 45, '团扇/折扇', '妆造带'],
    <Object>['灯笼', 60, '暖光灯笼配 LED', '道具组买'],
    <Object>['气球', 25, '氦气球与配重', '后勤买'],
    <Object>['书本', 40, '旧书做旧质感', '模特自带'],
    <Object>['风车', 20, '迎风拍摄用', '后勤买'],
    <Object>['蜡烛', 35, 'LED 电子蜡烛更安全', '摄影助理买'],
    <Object>['纱幔', 70, '轻薄纱帘透光', '工作室提供'],
  ];
  return list.map((List<Object> row) {
    return <String, Object?>{
      'id': 'prop-${list.indexOf(row) + 1}',
      'name': row[0],
      'price': row[1],
      'note': row[2],
      'owner': row[3],
      'category': '常用道具',
    };
  }).toList();
}

void main() {
  final gear = _gear();
  final cameras = gear.where((g) => g['kind'] == 'camera').length;
  final lenses = gear.where((g) => g['kind'] == 'lens').length;
  final lights = gear.where((g) => g['kind'] == 'light').length;
  _writeJson('assets/content/gear/gear.json', <String, Object?>{
    'version': 1,
    'note': '参数与参考价为参考值（实采整理），可在内容包更新中修正',
    'items': gear,
  });
  _writeJson('assets/content/clothing/clothing.json',
      <String, Object?>{'version': 1, 'categories': _clothing()});
  _writeJson('assets/content/props/props_presets.json',
      <String, Object?>{'version': 1, 'props': _props()});
  stdout.writeln(
      'gear total=${gear.length} cameras=$cameras lenses=$lenses lights=$lights');
}
