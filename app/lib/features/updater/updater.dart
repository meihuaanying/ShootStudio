import 'dart:convert';

import 'package:dio/dio.dart';

import '../../services/net.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../core/utils/json_utils.dart';
import '../../services/content_packs.dart';
import '../../services/semver.dart';

/// 当前应用版本（构建时写入；与 CI Tag / 公告 JSON 保证一致）。
const String kAppVersion = '1.3.0';

/// 默认公告 JSON 地址（官网 Pages；设置页可改，用于自建站点/内网）。
const String kDefaultAnnouncementUrl =
    'https://shootstudio.example.com/announcements.json';

/// 更新检查状态（PRD 6.9：三态 + 静默降级）。
enum UpdateState { hasUpdate, upToDate, failed, silent }

/// 平台下载入口。
class DownloadEntry {
  const DownloadEntry({
    required this.mirror,
    required this.github,
    required this.sha256,
  });

  final String mirror;
  final String github;
  final String sha256;

  static DownloadEntry fromJson(Map<String, Object?> json) => DownloadEntry(
    mirror: json['mirror'] as String? ?? '',
    github: json['github'] as String? ?? '',
    sha256: json['sha256'] as String? ?? '',
  );
}

/// 内容包条目（模板/姿势包增量）。
class ContentPackEntry {
  const ContentPackEntry({
    required this.type,
    required this.version,
    required this.url,
  });

  final String type;
  final int version;
  final String url;

  static ContentPackEntry fromJson(Map<String, Object?> json) =>
      ContentPackEntry(
        type: json['type'] as String? ?? '',
        version: (json['version'] as num?)?.toInt() ?? 0,
        url: json['url'] as String? ?? '',
      );
}

/// 官网公告 JSON。
class Announcement {
  const Announcement({
    required this.version,
    required this.notes,
    required this.publishedAt,
    required this.downloads,
    required this.contentPacks,
    required this.ops,
  });

  final String version;
  final List<String> notes;
  final String publishedAt;
  final Map<String, DownloadEntry> downloads;
  final List<ContentPackEntry> contentPacks;

  /// 运营公告（新模板包上架等）。
  final List<({String title, String date})> ops;

  DownloadEntry? downloadFor(String platform) => downloads[platform];

  static Announcement fromJson(Map<String, Object?> json) => Announcement(
    version: json['version'] as String? ?? '0.0.0',
    notes: asStringList(json['notes']).isNotEmpty
        ? asStringList(json['notes'])
        : <String>[json['releaseNotes'] as String? ?? ''],
    publishedAt: json['publishedAt'] as String? ?? '',
    downloads: asMap(json['downloads']).map(
      (String key, Object? value) =>
          MapEntry(key, DownloadEntry.fromJson(asMap(value))),
    ),
    contentPacks: asMapList(
      json['contentPacks'],
    ).map(ContentPackEntry.fromJson).toList(),
    ops: asMapList(json['ops'])
        .map(
          (Map<String, Object?> op) => (
            title: op['title'] as String? ?? '',
            date: op['date'] as String? ?? '',
          ),
        )
        .toList(),
  );
}

/// 更新检查器（D3：版本走公告 JSON；内容包走独立增量通道）。
class UpdateChecker {
  UpdateChecker({required this.dio, this.appVersion = kAppVersion});

  final Dio dio;
  final String appVersion;

  /// 检查更新。manual=false 时失败静默（PRD 6.9）。
  Future<(UpdateState, Announcement?)> check({
    required String announcementUrl,
    required bool manual,
  }) async {
    try {
      final response = await dio.get<dynamic>(announcementUrl);
      final data = response.data;
      final json = data is String ? asMap(jsonDecode(data)) : asMap(data);
      final announcement = Announcement.fromJson(json);
      final remote = SemVer.parse(announcement.version);
      if (remote.isNewerThan(SemVer.parse(appVersion))) {
        return (UpdateState.hasUpdate, announcement);
      }
      return (UpdateState.upToDate, announcement);
    } catch (_) {
      return (manual ? UpdateState.failed : UpdateState.silent, null);
    }
  }

  /// 拉取内容包（模板/姿势包），合并进内容层（无需升级应用）。
  Future<int> pullContentPacks(
    Announcement announcement, {
    required int currentVersion,
  }) async {
    var applied = 0;
    for (final ContentPackEntry pack in announcement.contentPacks) {
      if (pack.version <= currentVersion || pack.url.isEmpty) continue;
      try {
        final response = await dio.get<dynamic>(pack.url);
        final data = response.data;
        final json = data is String ? asMap(jsonDecode(data)) : asMap(data);
        switch (pack.type) {
          case 'templates':
            ContentPacks.mergeCloudTemplates(json);
          case 'poses':
            ContentPacks.mergeCloudPoses(json);
          default:
            break;
        }
        applied++;
      } catch (_) {
        // 单个内容包失败不影响其它。
      }
    }
    return applied;
  }
}

/// 更新检查状态（用于横幅与设置页）。
class UpdaterState {
  const UpdaterState({
    this.announcement,
    this.lastState,
    this.checking = false,
    this.status = '',
    this.dismissed = false,
  });

  final Announcement? announcement;
  final UpdateState? lastState;
  final bool checking;
  final String status;
  final bool dismissed;

  bool get showBanner =>
      announcement != null && lastState == UpdateState.hasUpdate && !dismissed;

  UpdaterState copyWith({
    Object? announcement = _sentinel,
    Object? lastState = _sentinel,
    bool? checking,
    String? status,
    bool? dismissed,
  }) {
    return UpdaterState(
      announcement: announcement == _sentinel
          ? this.announcement
          : announcement as Announcement?,
      lastState: lastState == _sentinel
          ? this.lastState
          : lastState as UpdateState?,
      checking: checking ?? this.checking,
      status: status ?? this.status,
      dismissed: dismissed ?? this.dismissed,
    );
  }

  static const Object _sentinel = Object();
}

final updaterProvider = NotifierProvider<UpdaterController, UpdaterState>(
  UpdaterController.new,
);

class UpdaterController extends Notifier<UpdaterState> {
  late final AppDatabase _db = ref.read(databaseProvider);
  Dio? _dioOverride;

  @override
  UpdaterState build() => const UpdaterState();

  /// 测试注入。
  void useDio(Dio dio) => _dioOverride = dio;

  /// 读取设置页代理（未注入测试 Dio 时生效）。
  Future<Dio> _client() async {
    final Dio? injected = _dioOverride;
    if (injected != null) return injected;
    final String proxy = await _db.getSetting('proxy_url') ?? '';
    return makeDio(proxy: proxy, timeout: const Duration(seconds: 20));
  }

  Future<String> _announcementUrl() async =>
      await _db.getSetting('announcement_url') ?? kDefaultAnnouncementUrl;

  Future<void> setAnnouncementUrl(String url) async {
    await _db.setSetting('announcement_url', url.trim());
    state = state.copyWith(status: '公告地址已保存');
  }

  Future<String> announcementUrl() => _announcementUrl();

  /// 启动静默检查（只显示横幅，不打断）。
  Future<void> silentCheck() async {
    final checker = UpdateChecker(dio: await _client());
    final (UpdateState result, Announcement? announcement) = await checker
        .check(announcementUrl: await _announcementUrl(), manual: false);
    if (result == UpdateState.hasUpdate) {
      state = state.copyWith(
        lastState: result,
        announcement: announcement,
        dismissed: false,
      );
    }
  }

  /// 手动检查（三态提示 + 内容包增量拉取）。
  Future<UpdateState> manualCheck() async {
    state = state.copyWith(checking: true, status: '正在检查更新…');
    final checker = UpdateChecker(dio: await _client());
    final (UpdateState result, Announcement? announcement) = await checker
        .check(announcementUrl: await _announcementUrl(), manual: true);
    state = state.copyWith(
      checking: false,
      lastState: result,
      announcement: announcement,
    );
    switch (result) {
      case UpdateState.hasUpdate:
        state = state.copyWith(
          status:
              '发现新版本 v${announcement?.version}（含 ${announcement?.notes.length ?? 0} 条更新要点）',
          dismissed: false,
        );
        final applied = await checker.pullContentPacks(
          announcement!,
          currentVersion: ContentPacks.builtinVersion,
        );
        if (applied > 0) {
          await _db.setSetting(
            'content_version',
            '${ContentPacks.builtinVersion}',
          );
          state = state.copyWith(status: '${state.status}；已更新 $applied 个内容包');
        }
      case UpdateState.upToDate:
        state = state.copyWith(status: '已是最新版本（v$kAppVersion）');
      case UpdateState.failed:
        state = state.copyWith(status: '网络异常，请稍后重试');
      case UpdateState.silent:
        state = state.copyWith(status: '检查未完成');
    }
    return result;
  }

  void dismissBanner() => state = state.copyWith(dismissed: true);
}
