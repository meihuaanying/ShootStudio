import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/features/updater/updater.dart';
import 'package:shoot_studio/services/semver.dart';

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

ResponseBody _json(Object data) => ResponseBody.fromString(
      jsonEncode(data),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );

void main() {
  group('SemVer', () {
    test('主/次/修订与预发布', () {
      expect(SemVer.parse('1.1.0').isNewerThan(SemVer.parse('1.0.0')), isTrue);
      expect(SemVer.parse('1.0.0').isNewerThan(SemVer.parse('1.0.0-rc.1')),
          isTrue);
      expect(SemVer.parse('1.0.0-rc.1').isNewerThan(SemVer.parse('1.0.0')),
          isFalse);
      expect(SemVer.parse('v2.0.0').isNewerThan(SemVer.parse('1.9.9')), isTrue);
      expect(SemVer.parse('1.0.10').isNewerThan(SemVer.parse('1.0.9')), isTrue);
    });
  });

  group('更新检查三态（PRD 6.9）', () {
    test('有新版本 → hasUpdate + 解析下载与内容包', () async {
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter(
        (RequestOptions options) async => _json(<String, Object?>{
          'version': '1.2.0',
          'publishedAt': '2026-10-01',
          'notes': <String>['云端模板市场', '双人姿势包'],
          'downloads': <String, Object?>{
            'windows': <String, Object?>{
              'mirror': 'https://cdn.example.com/ss-1.2.0.zip',
              'github':
                  'https://github.com/x/y/releases/download/v1.2.0/ss.zip',
              'sha256': 'abc',
            },
            'android': <String, Object?>{
              'mirror': 'https://cdn.example.com/ss-1.2.0.apk',
              'github':
                  'https://github.com/x/y/releases/download/v1.2.0/ss.apk',
              'sha256': 'def',
            },
          },
          'contentPacks': <Object?>[
            <String, Object?>{
              'type': 'templates',
              'version': 2,
              'url': 'https://cdn.example.com/templates-2.json',
            },
          ],
          'ops': <Object?>[
            <String, String>{'title': '新姿势包上架', 'date': '2026-10-01'},
          ],
        }),
      );
      final checker = UpdateChecker(dio: dio);
      final (UpdateState state, Announcement? announcement) =
          await checker.check(
        announcementUrl: 'https://cdn.example.com/announcements.json',
        manual: true,
      );
      expect(state, UpdateState.hasUpdate);
      expect(announcement!.version, '1.2.0');
      expect(announcement.downloadFor('windows')!.mirror, contains('cdn'));
      expect(announcement.contentPacks.single.type, 'templates');
      expect(announcement.ops.single.title, contains('姿势包'));
    });

    test('已是最新 → upToDate', () async {
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter(
          (RequestOptions options) async => _json(<String, Object?>{
                'version': '1.0.0',
                'notes': <String>[],
              }));
      final checker = UpdateChecker(dio: dio);
      final (UpdateState state, _) = await checker.check(
        announcementUrl: 'https://cdn.example.com/announcements.json',
        manual: true,
      );
      expect(state, UpdateState.upToDate);
    });

    test('断网：手动 → failed；自动 → silent', () async {
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter(
        (RequestOptions options) async => throw DioException.connectionError(
          requestOptions: options,
          reason: '断网',
        ),
      );
      final checker = UpdateChecker(dio: dio);
      final (UpdateState manual, _) = await checker.check(
        announcementUrl: 'https://cdn.example.com/announcements.json',
        manual: true,
      );
      final (UpdateState silent, _) = await checker.check(
        announcementUrl: 'https://cdn.example.com/announcements.json',
        manual: false,
      );
      expect(manual, UpdateState.failed);
      expect(silent, UpdateState.silent);
    });

    test('内容包增量拉取（模板/姿势合并，无重复）', () async {
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter((RequestOptions options) async {
        if (options.uri.path.contains('templates')) {
          return _json(<String, Object?>{
            'templates': <Object?>[
              <String, Object?>{
                'id': 'cloud-tpl-1',
                'name': '云端模板',
                'category': '写真',
                'description': '来自云端',
                'modules': <Object?>[
                  <String, Object?>{
                    'type': 'theme',
                    'title': '拍摄主题',
                    'preset': <String, Object?>{'text': '云端'},
                  },
                ],
              },
            ],
          });
        }
        return _json(<String, Object?>{'poses': <Object?>[]});
      });
      final checker = UpdateChecker(dio: dio);
      final announcement = Announcement.fromJson(<String, Object?>{
        'version': '1.1.0',
        'contentPacks': <Object?>[
          <String, Object?>{
            'type': 'templates',
            'version': 2,
            'url': 'https://x/templates.json'
          },
          <String, Object?>{
            'type': 'poses',
            'version': 2,
            'url': 'https://x/poses.json'
          },
        ],
      });
      final applied =
          await checker.pullContentPacks(announcement, currentVersion: 1);
      expect(applied, 2);
    });
  });
}
