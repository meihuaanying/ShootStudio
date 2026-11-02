import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/core/db/database.dart';
import 'package:shoot_studio/core/providers.dart';
import 'package:shoot_studio/features/updater/updater.dart';
import 'package:shoot_studio/features/updater/updater_downloader.dart';
import 'package:shoot_studio/services/content_packs.dart';
import 'package:shoot_studio/services/semver.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options);

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

String _sha256Json(Object data) =>
    sha256.convert(utf8.encode(jsonEncode(data))).toString();

void main() {
  group('SemVer', () {
    test('主/次/修订与预发布', () {
      expect(SemVer.parse('1.1.0').isNewerThan(SemVer.parse('1.0.0')), isTrue);
      expect(
        SemVer.parse('1.0.0').isNewerThan(SemVer.parse('1.0.0-rc.1')),
        isTrue,
      );
      expect(
        SemVer.parse('1.0.0-rc.1').isNewerThan(SemVer.parse('1.0.0')),
        isFalse,
      );
      expect(SemVer.parse('v2.0.0').isNewerThan(SemVer.parse('1.9.9')), isTrue);
      expect(SemVer.parse('1.0.10').isNewerThan(SemVer.parse('1.0.9')), isTrue);
    });
  });

  group('更新检查三态（PRD 6.9）', () {
    test('有新版本 → hasUpdate + 解析下载与内容包', () async {
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter(
        (RequestOptions options) async => _json(<String, Object?>{
          // 固定远高于当前版本的「未来版本」，避免每次发版都要改用例。
          'version': '9.9.9',
          'publishedAt': '2026-10-01',
          'notes': <String>['云端模板市场', '双人姿势包'],
          'downloads': <String, Object?>{
            'windows': <String, Object?>{
              'mirror': 'https://cdn.example.com/ss-9.9.9.zip',
              'github':
                  'https://github.com/x/y/releases/download/v9.9.9/ss.zip',
              'sha256': 'abc',
            },
            'android': <String, Object?>{
              'mirror': 'https://cdn.example.com/ss-9.9.9.apk',
              'github':
                  'https://github.com/x/y/releases/download/v9.9.9/ss.apk',
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
      final (UpdateState state, Announcement? announcement) = await checker
          .check(
            announcementUrl: 'https://cdn.example.com/announcements.json',
            manual: true,
          );
      expect(state, UpdateState.hasUpdate);
      expect(announcement!.version, '9.9.9');
      expect(announcement.downloadFor('windows')!.mirror, contains('cdn'));
      expect(announcement.contentPacks.single.type, 'templates');
      expect(announcement.ops.single.title, contains('姿势包'));
    });

    test('已是最新 → upToDate', () async {
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter(
        (RequestOptions options) async =>
            _json(<String, Object?>{'version': '1.0.0', 'notes': <String>[]}),
      );
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
      final Map<String, Object?> templatesData = <String, Object?>{
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
      };
      final Map<String, Object?> posesData = <String, Object?>{
        'poses': <Object?>[],
      };
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter((RequestOptions options) async {
        if (options.uri.path.contains('templates')) {
          return _json(templatesData);
        }
        return _json(posesData);
      });
      final checker = UpdateChecker(dio: dio);
      final announcement = Announcement.fromJson(<String, Object?>{
        'version': '1.1.0',
        'contentPacks': <Object?>[
          <String, Object?>{
            'type': 'templates',
            'version': 2,
            'url': 'https://x/templates.json',
            'sha256': _sha256Json(templatesData),
          },
          <String, Object?>{
            'type': 'poses',
            'version': 2,
            'url': 'https://x/poses.json',
            'sha256': _sha256Json(posesData),
          },
        ],
      });
      final applied = await checker.pullContentPacks(
        announcement,
        currentVersion: 1,
      );
      expect(applied, 2);
    });
  });

  group('内容包记账与持久化（_pullAndPersistPacks）', () {
    late AppDatabase db;
    late ProviderContainer container;

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    /// 公告 version 固定 9.9.9（远高于 kAppVersion），两个 v3 内容包。
    void installDb() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: <Override>[databaseProvider.overrideWithValue(db)],
      );
    }

    test('manualCheck：记账 content_pack_version 并持久化云端合并 JSON', () async {
      installDb();
      final Map<String, Object?> templatesData = <String, Object?>{
        'templates': <Object?>[
          <String, Object?>{
            'id': 'cloud-tpl-2',
            'name': '云端模板二',
            'category': '写真',
            'description': 'v3 增量',
            'modules': <Object?>[],
          },
        ],
      };
      final Map<String, Object?> posesData = <String, Object?>{
        'poses': <Object?>[
          <String, Object?>{'id': 'cloud-pose-1', 'name': '云端姿势'},
        ],
      };
      final Dio dio = Dio();
      dio.httpClientAdapter = _FakeAdapter((RequestOptions options) async {
        if (options.uri.path.contains('templates')) {
          return _json(templatesData);
        }
        if (options.uri.path.contains('poses')) {
          return _json(posesData);
        }
        return _json(<String, Object?>{
          'version': '9.9.9',
          'publishedAt': '2026-10-01',
          'notes': <String>['a'],
          'contentPacks': <Object?>[
            <String, Object?>{
              'type': 'templates',
              'version': 3,
              'url': 'https://cdn.example.com/templates-3.json',
              'sha256': _sha256Json(templatesData),
            },
            <String, Object?>{
              'type': 'poses',
              'version': 3,
              'url': 'https://cdn.example.com/poses-3.json',
              'sha256': _sha256Json(posesData),
            },
          ],
        });
      });
      final UpdaterController controller = container.read(
        updaterProvider.notifier,
      );
      controller.useDio(dio);
      await controller.manualCheck();
      // 记账：max(包版本) = 3，写 content_pack_version 而非 builtinVersion。
      expect(await db.getSetting('content_pack_version'), '3');
      // 持久化：云端合并快照写入设置，重启后可经 loadCloudOverrides 恢复。
      expect(
        await db.getSetting('cloud_templates_json'),
        contains('cloud-tpl-2'),
      );
      expect(await db.getSetting('cloud_poses_json'), contains('cloud-pose-1'));
      expect(container.read(updaterProvider).status, contains('已更新 2 个内容包'));
    });

    test('manualCheck 二次调用：已达 maxPackVersion 的包不再重复下载', () async {
      installDb();
      int templateFetches = 0;
      final Map<String, Object?> templatesData = <String, Object?>{
        'templates': <Object?>[
          <String, Object?>{
            'id': 'cloud-tpl-2',
            'name': '云端模板二',
            'category': '写真',
            'description': 'v3 增量',
            'modules': <Object?>[],
          },
        ],
      };
      final Map<String, Object?> posesData = <String, Object?>{
        'poses': <Object?>[
          <String, Object?>{'id': 'cloud-pose-1', 'name': '云端姿势'},
        ],
      };
      final Dio dio = Dio();
      dio.httpClientAdapter = _FakeAdapter((RequestOptions options) async {
        if (options.uri.path.contains('templates')) {
          templateFetches++;
          return _json(templatesData);
        }
        if (options.uri.path.contains('poses')) {
          return _json(posesData);
        }
        return _json(<String, Object?>{
          'version': '9.9.9',
          'publishedAt': '2026-10-01',
          'notes': <String>['a'],
          'contentPacks': <Object?>[
            <String, Object?>{
              'type': 'templates',
              'version': 3,
              'url': 'https://cdn.example.com/templates-3.json',
              'sha256': _sha256Json(templatesData),
            },
            <String, Object?>{
              'type': 'poses',
              'version': 3,
              'url': 'https://cdn.example.com/poses-3.json',
              'sha256': _sha256Json(posesData),
            },
          ],
        });
      });
      final UpdaterController controller = container.read(
        updaterProvider.notifier,
      );
      controller.useDio(dio);
      await controller.manualCheck();
      expect(await db.getSetting('content_pack_version'), '3');
      await controller.manualCheck();
      expect(await db.getSetting('content_pack_version'), '3');
      expect(templateFetches, 1);
      expect(container.read(updaterProvider).status, isNot(contains('已更新')));
    });

    test('silentCheck：已是最新也增量拉取内容包并记账', () async {
      installDb();
      final Map<String, Object?> posesData = <String, Object?>{
        'poses': <Object?>[
          <String, Object?>{'id': 'cloud-pose-1', 'name': '云端姿势'},
        ],
      };
      final Dio dio = Dio();
      dio.httpClientAdapter = _FakeAdapter((RequestOptions options) async {
        if (options.uri.path.contains('poses')) {
          return _json(posesData);
        }
        return _json(<String, Object?>{
          'version': kAppVersion,
          'publishedAt': '2026-10-01',
          'notes': <String>[],
          'contentPacks': <Object?>[
            <String, Object?>{
              'type': 'poses',
              'version': 3,
              'url': 'https://cdn.example.com/poses-3.json',
              'sha256': _sha256Json(posesData),
            },
          ],
        });
      });
      final UpdaterController controller = container.read(
        updaterProvider.notifier,
      );
      controller.useDio(dio);
      await controller.silentCheck();
      expect(await db.getSetting('content_pack_version'), '3');
      expect(await db.getSetting('cloud_poses_json'), contains('cloud-pose-1'));
    });

    test('silentCheck 断网 → silent，不拉取内容包', () async {
      installDb();
      final Dio dio = Dio();
      dio.httpClientAdapter = _FakeAdapter(
        (RequestOptions options) async => throw DioException.connectionError(
          requestOptions: options,
          reason: '断网',
        ),
      );
      final UpdaterController controller = container.read(
        updaterProvider.notifier,
      );
      controller.useDio(dio);
      await controller.silentCheck();
      expect(await db.getSetting('content_pack_version'), isNull);
      expect(await db.getSetting('cloud_poses_json'), isNull);
    });
  });

  group('内容包 SHA-256 校验（与安装包同口径）', () {
    final File tmpFile = File(
      '${Directory.systemTemp.path}/shootstudio-pack-templates-3.json',
    );

    setUp(() async {
      if (await tmpFile.exists()) await tmpFile.delete();
    });

    tearDown(() async {
      if (await tmpFile.exists()) await tmpFile.delete();
    });

    String templatesPackJson() => jsonEncode(<String, Object?>{
      'templates': <Object?>[
        <String, Object?>{
          'id': 'cloud-tpl-verified',
          'name': '校验模板',
          'category': '写真',
          'description': '摘要匹配',
          'modules': <Object?>[],
        },
      ],
    });

    Dio dioForPack(List<int> payload) {
      final Dio dio = Dio();
      dio.httpClientAdapter = _FakeAdapter(
        (RequestOptions options) async => ResponseBody.fromBytes(
          payload,
          200,
          headers: <String, List<String>>{
            Headers.contentLengthHeader: <String>['${payload.length}'],
          },
        ),
      );
      return dio;
    }

    Announcement announcementFor({String? sha256}) =>
        Announcement.fromJson(<String, Object?>{
          'version': '1.1.0',
          'contentPacks': <Object?>[
            <String, Object?>{
              'type': 'templates',
              'version': 3,
              'url': 'https://cdn.example.com/templates-3.json',
              if (sha256 != null) 'sha256': sha256,
            },
          ],
        });

    test('无 sha256 的内容包 → 跳过，不请求不合并', () async {
      int packRequests = 0;
      final Dio dio = Dio();
      dio.httpClientAdapter = _FakeAdapter((RequestOptions options) async {
        packRequests++;
        return ResponseBody.fromBytes(utf8.encode(templatesPackJson()), 200);
      });
      final checker = UpdateChecker(dio: dio);
      final applied = await checker.pullContentPacks(
        announcementFor(),
        currentVersion: 1,
      );
      expect(applied, 0);
      expect(packRequests, 0);
      expect(
        jsonEncode(ContentPacks.templatesCache ?? <String, Object?>{}),
        isNot(contains('cloud-tpl-verified')),
      );
    });

    test('摘要不匹配的内容包 → 跳过且临时文件被删', () async {
      final List<int> payload = utf8.encode(templatesPackJson());
      final checker = UpdateChecker(dio: dioForPack(payload));
      final String wrongDigest = List<String>.filled(64, 'b').join();
      final applied = await checker.pullContentPacks(
        announcementFor(sha256: wrongDigest),
        currentVersion: 1,
      );
      expect(applied, 0);
      expect(await tmpFile.exists(), isFalse);
      expect(
        jsonEncode(ContentPacks.templatesCache ?? <String, Object?>{}),
        isNot(contains('cloud-tpl-verified')),
      );
    });

    test('摘要匹配的内容包 → 正常合并', () async {
      final List<int> payload = utf8.encode(templatesPackJson());
      final String digest = sha256.convert(payload).toString();
      final checker = UpdateChecker(dio: dioForPack(payload));
      final applied = await checker.pullContentPacks(
        announcementFor(sha256: digest),
        currentVersion: 1,
      );
      expect(applied, 1);
      expect(await tmpFile.exists(), isFalse);
      expect(
        jsonEncode(ContentPacks.templatesCache ?? <String, Object?>{}),
        contains('cloud-tpl-verified'),
      );
    });
  });

  group('偏差 2 · 应用内下载 + 流式 SHA-256 校验（PRD 6.9）', () {
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('ss_updater_');
    });

    tearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    /// 下载接口返回固定字节（模拟安装包）。
    Dio bytesDio(List<int> payload) {
      final Dio dio = Dio();
      dio.httpClientAdapter = _FakeAdapter(
        (RequestOptions options) async => ResponseBody.fromBytes(
          payload,
          200,
          headers: <String, List<String>>{
            Headers.contentLengthHeader: <String>['${payload.length}'],
          },
        ),
      );
      return dio;
    }

    test('normalizeSha256 只认 64 位十六进制，占位串视为未公布', () {
      final String good = List<String>.filled(64, 'a').join();
      expect(normalizeSha256(good), good);
      expect(normalizeSha256('  ${good.toUpperCase()}  '), good);
      expect(normalizeSha256('发布时由 CI 写入'), isNull);
      expect(normalizeSha256(''), isNull);
      expect(normalizeSha256('abc123'), isNull);
      expect(normalizeSha256(List<String>.filled(64, 'z').join()), isNull);
    });

    test('sha256OfFile 与 sha256.convert 一致（分块读取）', () async {
      final File file = File('${temp.path}/payload.bin');
      final List<int> payload = List<int>.generate(70000, (int i) => i % 251);
      await file.writeAsBytes(payload);
      expect(await sha256OfFile(file), sha256.convert(payload).toString());
    });

    test('摘要一致 → verified，且允许启动安装器', () async {
      final List<int> payload = utf8.encode('installer-payload-v2');
      final String digest = sha256.convert(payload).toString();
      final List<String> launched = <String>[];
      final UpdaterDownloader downloader = UpdaterDownloader(
        dio: bytesDio(payload),
        launcher: (String path) async {
          launched.add(path);
          return true;
        },
      );
      final String savePath = '${temp.path}/updates/pkg.zip';
      final UpdateDownloadResult result = await downloader.download(
        url: 'https://mirror.example.com/pkg.zip',
        sha256: digest,
        savePath: savePath,
      );
      expect(result.state, UpdateVerifyState.verified);
      expect(result.canInstall, isTrue);
      expect(result.actualDigest, digest);
      expect(await File(savePath).exists(), isTrue);

      final bool installed = await downloader.downloadAndInstall(
        url: 'https://mirror.example.com/pkg.zip',
        sha256: digest,
        savePath: savePath,
      );
      expect(installed, isTrue);
      expect(launched, <String>[savePath]);
    });

    test('校验失败必须拒绝安装：不匹配 → mismatch + 删文件 + 不启动安装器', () async {
      final List<int> payload = utf8.encode('tampered-installer');
      final String wrongDigest = List<String>.filled(64, 'b').join();
      final List<String> launched = <String>[];
      final UpdaterDownloader downloader = UpdaterDownloader(
        dio: bytesDio(payload),
        launcher: (String path) async {
          launched.add(path);
          return true;
        },
      );
      final String savePath = '${temp.path}/updates/pkg.zip';
      final UpdateDownloadResult result = await downloader.download(
        url: 'https://mirror.example.com/pkg.zip',
        sha256: wrongDigest,
        savePath: savePath,
      );
      expect(result.state, UpdateVerifyState.mismatch);
      expect(result.canInstall, isFalse);
      expect(result.expectedDigest, wrongDigest);
      expect(result.actualDigest, isNot(wrongDigest));
      expect(await File(savePath).exists(), isFalse);

      final bool installed = await downloader.downloadAndInstall(
        url: 'https://mirror.example.com/pkg.zip',
        sha256: wrongDigest,
        savePath: savePath,
      );
      expect(installed, isFalse);
      expect(launched, isEmpty);
      expect(await File(savePath).exists(), isFalse);
    });

    test('公告未公布可校验摘要 → digestMissing + 拒绝安装 + 删文件', () async {
      final List<int> payload = utf8.encode('installer-payload');
      final List<String> launched = <String>[];
      final UpdaterDownloader downloader = UpdaterDownloader(
        dio: bytesDio(payload),
        launcher: (String path) async {
          launched.add(path);
          return true;
        },
      );
      final String savePath = '${temp.path}/updates/pkg.zip';
      final bool installed = await downloader.downloadAndInstall(
        url: 'https://mirror.example.com/pkg.zip',
        sha256: '发布时由 CI 写入',
        savePath: savePath,
      );
      expect(installed, isFalse);
      expect(launched, isEmpty);
      expect(await File(savePath).exists(), isFalse);
    });

    test('下载失败 → downloadFailed，不留残包', () async {
      final Dio dio = Dio();
      dio.httpClientAdapter = _FakeAdapter(
        (RequestOptions options) async => throw const SocketException('boom'),
      );
      final UpdaterDownloader downloader = UpdaterDownloader(
        dio: dio,
        launcher: (String path) async {
          fail('校验未通过时不得启动安装器');
        },
      );
      final String savePath = '${temp.path}/updates/pkg.zip';
      final UpdateDownloadResult result = await downloader.download(
        url: 'https://mirror.example.com/pkg.zip',
        sha256: List<String>.filled(64, 'c').join(),
        savePath: savePath,
      );
      expect(result.state, UpdateVerifyState.downloadFailed);
      expect(result.canInstall, isFalse);
      expect(await File(savePath).exists(), isFalse);
    });

    test('Announcement.platformKey / urlOf：镜像优先、回落 GitHub', () {
      expect(<String>[
        'windows',
        'android',
      ], contains(Announcement.platformKey()));
      const DownloadEntry mirrored = DownloadEntry(
        mirror: 'https://mirror.example.com/a.zip',
        github: 'https://github.com/x/y/releases',
        sha256: 'abc',
      );
      const DownloadEntry noMirror = DownloadEntry(
        mirror: '',
        github: 'https://github.com/x/y/releases',
        sha256: 'abc',
      );
      expect(Announcement.urlOf(mirrored), mirrored.mirror);
      expect(Announcement.urlOf(noMirror), noMirror.github);
      expect(Announcement.urlOf(null), '');
    });
  });
}
