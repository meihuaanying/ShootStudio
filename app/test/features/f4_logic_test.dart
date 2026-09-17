import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/features/planner/budget_estimator.dart';
import 'package:shoot_studio/services/content_packs.dart';
import 'package:shoot_studio/services/geocoding.dart';
import 'package:shoot_studio/services/richtext_lite.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      handler(options);

  @override
  void close({bool force = false}) {}
}

void main() {
  group('预算估算（F4/F9）', () {
    const List<BudgetItemEntry> items = <BudgetItemEntry>[
      BudgetItemEntry(
          key: 'studio', label: '影棚（小时）', min: 150, max: 600, note: ''),
      BudgetItemEntry(key: 'meal', label: '餐费（人）', min: 30, max: 80, note: ''),
    ];

    test('区间的中值 × 档位系数，标注估算值', () {
      final List<Map<String, Object?>> rows = BudgetEstimator.estimate(
        items: items,
        multiplier: 1.4,
        tier: '一线',
        people: 1,
      );
      expect(rows, hasLength(2));
      // (150+600)/2*1.4 = 525 → round 530。
      expect(rows[0]['price'], 530);
      expect('${rows[0]['note']}', contains('估算值'));
      expect('${rows[0]['note']}', contains('1.40'));
    });

    test('餐饮按人数放大，合计可累加', () {
      final List<Map<String, Object?>> rows = BudgetEstimator.estimate(
        items: items,
        multiplier: 1.0,
        tier: '二线',
        people: 4,
      );
      // (30+80)/2*1*4 = 220。
      expect(rows[1]['price'], 220);
      expect(
        BudgetEstimator.total(rows),
        ((rows[0]['price'] as num) + 220).toDouble(),
      );
    });

    test('合计容忍空值与字符串数字', () {
      expect(
        BudgetEstimator.total(<Object?>[
          <String, Object?>{'price': 100},
          <String, Object?>{'price': '50'},
          <String, Object?>{'price': null},
        ]),
        150,
      );
    });
  });

  group('富文本轻量解析（F12）', () {
    test('列表与加粗解析', () {
      final List<RichLine> lines =
          RichTextLite.parse('**重点**普通文字\n- 第一项\n- **第二项**');
      expect(lines, hasLength(3));
      expect(lines[0].bullet, isFalse);
      expect(lines[0].spans[0].bold, isTrue);
      expect(lines[0].spans[0].text, '重点');
      expect(lines[1].bullet, isTrue);
      expect(lines[2].spans.first.bold, isTrue);
    });

    test('加粗切换可往返', () {
      final ({String text, int selection}) bold =
          RichTextLite.toggleBold('氛围要突出', 0, 4);
      expect(bold.text, '**氛围要突**出');
      final ({String text, int selection}) again =
          RichTextLite.toggleBold(bold.text, 0, bold.selection);
      expect(again.text, '氛围要突出');
    });

    test('无序列表切换可往返', () {
      final ({String text, int selection}) bullet =
          RichTextLite.toggleBullet('第一行\n第二行', 0, 7);
      expect(bullet.text, '- 第一行\n- 第二行');
      final ({String text, int selection}) again =
          RichTextLite.toggleBullet(bullet.text, 0, bullet.text.length);
      expect(again.text, '第一行\n第二行');
    });

    test('plain 去除标记', () {
      expect(RichTextLite.plain('- **重点**\n正文'), '重点\n正文');
    });
  });

  group('在线地名搜索（F10）', () {
    test('成功解析 Nominatim 结果', () async {
      final Dio dio = Dio()
        ..httpClientAdapter = _FakeAdapter((RequestOptions options) async {
          expect('${options.uri}', contains('nominatim.openstreetmap.org'));
          return ResponseBody.fromString(
            jsonEncode(<Object?>[
              <String, Object?>{
                'display_name': '横店镇, 东阳市, 金华市, 浙江省, 中国',
                'lat': '29.1561',
                'lon': '120.3219',
              },
            ]),
            200,
            headers: <String, List<String>>{
              Headers.contentTypeHeader: <String>[Headers.jsonContentType],
            },
          );
        });
      final ({String name, double lat, double lon})? result =
          await GeocodingService(dio: dio).search('横店');
      expect(result, isNotNull);
      expect(result!.name, '横店镇');
      expect(result.lat, closeTo(29.1561, 0.0001));
      expect(result.lon, closeTo(120.3219, 0.0001));
    });

    test('断网/无结果返回 null（离线回退）', () async {
      final Dio dio = Dio()
        ..httpClientAdapter = _FakeAdapter((RequestOptions options) async {
          throw DioException(requestOptions: options, message: 'offline');
        });
      expect(await GeocodingService(dio: dio).search('不存在的地方'), isNull);
      final Dio empty = Dio()
        ..httpClientAdapter = _FakeAdapter((RequestOptions options) async {
          return ResponseBody.fromString('[]', 200);
        });
      expect(await GeocodingService(dio: empty).search('x'), isNull);
      expect(await GeocodingService(dio: empty).search('  '), isNull);
    });
  });
}
