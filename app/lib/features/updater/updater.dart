import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../services/net.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../core/utils/json_utils.dart';
import '../../services/content_packs.dart';
import '../../services/semver.dart';
import '../../core/design/tokens.dart';
import 'updater_downloader.dart';

/// 当前应用版本（构建时写入；与 CI Tag / 公告 JSON 保证一致）。
const String kAppVersion = '2.0.0';

/// 默认公告 JSON 地址（官网 Pages；设置页可改，用于自建站点/内网）。
const String kDefaultAnnouncementUrl =
    'https://meihuaanying.github.io/ShootStudio/announcements.json';

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
    this.sha256,
  });

  final String type;
  final int version;
  final String url;

  /// 公布的包摘要（64 位十六进制）；未公布为 null，此时按未通过校验处理。
  final String? sha256;

  static ContentPackEntry fromJson(Map<String, Object?> json) =>
      ContentPackEntry(
        type: json['type'] as String? ?? '',
        version: (json['version'] as num?)?.toInt() ?? 0,
        url: json['url'] as String? ?? '',
        sha256: json['sha256'] as String?,
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

  /// 当前平台在公告 JSON 里的键名（Windows 用 windows，其余走 android）。
  static String platformKey() => Platform.isWindows ? 'windows' : 'android';

  /// 取下载链接：优先国内镜像，回落 GitHub Release。
  static String urlOf(DownloadEntry? entry) {
    if (entry == null) return '';
    return entry.mirror.isNotEmpty ? entry.mirror : entry.github;
  }

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
      final String? expected = normalizeSha256(pack.sha256 ?? '');
      if (expected == null) continue; // 未公布可校验摘要 → 与安装包同口径：跳过。
      final File tmp = File(
        '${Directory.systemTemp.path}/shootstudio-pack-${pack.type}-${pack.version}.json',
      );
      try {
        await dio.download(pack.url, tmp.path);
        final String actual = await sha256OfFile(tmp);
        if (actual != expected) {
          await tmp.delete().catchError((Object _) => tmp);
          continue;
        }
        final Map<String, Object?> json = asMap(
          jsonDecode(await tmp.readAsString()),
        );
        await tmp.delete().catchError((Object _) => tmp);
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
        if (await tmp.exists()) {
          await tmp.delete().catchError((Object _) => tmp);
        }
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
    return makeDio(proxy: proxy, timeout: AppWait.network);
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
    if (announcement != null && result != UpdateState.silent) {
      await _pullAndPersistPacks(checker, announcement);
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
        await _pullAndPersistPacks(checker, announcement!);
      case UpdateState.upToDate:
        state = state.copyWith(status: '已是最新版本（v$kAppVersion）');
      case UpdateState.failed:
        state = state.copyWith(status: '网络异常，请稍后重试');
      case UpdateState.silent:
        state = state.copyWith(status: '检查未完成');
    }
    return result;
  }

  /// 内容包增量拉取 + 记账 + 持久化（manualCheck 与 silentCheck 共用）。
  Future<void> _pullAndPersistPacks(
    UpdateChecker checker,
    Announcement announcement,
  ) async {
    final applied = await checker.pullContentPacks(
      announcement,
      currentVersion:
          int.tryParse(await _db.getSetting('content_pack_version') ?? '') ??
          ContentPacks.builtinVersion,
    );
    if (applied > 0) {
      final int maxPackVersion = announcement.contentPacks.fold<int>(
        ContentPacks.builtinVersion,
        (int acc, ContentPackEntry p) => p.version > acc ? p.version : acc,
      );
      await _db.setSetting('content_pack_version', '$maxPackVersion');
      await _db.setSetting(
        'cloud_templates_json',
        jsonEncode(ContentPacks.templatesCache ?? <String, Object?>{}),
      );
      await _db.setSetting(
        'cloud_poses_json',
        jsonEncode(ContentPacks.posesCache ?? <String, Object?>{}),
      );
      state = state.copyWith(status: '${state.status}；已更新 $applied 个内容包');
    }
  }

  /// 偏差 2 闭环：应用内下载 + 流式 SHA-256 校验 + 校验通过才启动安装器。
  ///
  /// 这里**只做下载与校验**，不直接启动安装器 —— 安装由 UI 在拿到
  /// [UpdateVerifyState.verified] 之后再决定，避免「校验失败也弹安装」。
  Future<UpdateDownloadResult> downloadUpdate(
    Announcement announcement, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final DownloadEntry? entry = announcement.downloadFor(
      Announcement.platformKey(),
    );
    final String url = Announcement.urlOf(entry);
    if (url.isEmpty || entry == null) {
      return UpdateDownloadResult(
        state: UpdateVerifyState.digestMissing,
        message: '该版本未提供当前平台的下载地址。',
      );
    }
    final Directory dir = await getApplicationSupportDirectory();
    final String fileName = url.split('/').last.split('?').first;
    final String savePath =
        '${dir.path}/updates/'
        '${fileName.isEmpty ? 'shootstudio-${announcement.version}' : fileName}';
    final UpdaterDownloader downloader = UpdaterDownloader(
      dio: await _client(),
    );
    final UpdateDownloadResult result = await downloader.download(
      url: url,
      sha256: entry.sha256,
      savePath: savePath,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    state = state.copyWith(status: result.message);
    return result;
  }

  /// 校验通过后才允许启动安装器；失败一律拒绝（含摘要缺失/不匹配）。
  Future<bool> installVerified(UpdateDownloadResult result) async {
    if (!result.canInstall) {
      state = state.copyWith(status: result.message);
      return false;
    }
    final bool launched = await launchLocalInstaller(result.filePath);
    state = state.copyWith(
      status: launched ? '校验通过，已启动安装器。' : '校验通过，但安装器启动失败。',
    );
    return launched;
  }

  void dismissBanner() => state = state.copyWith(dismissed: true);
}
