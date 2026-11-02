import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/design/widgets.dart';
import '../updater/updater.dart';
import '../updater/updater_downloader.dart';

/// 展示官方 SHA-256 便于人工核对（只取前 12 位，肉眼比对够用）。
String? shortDigest(String sha256) {
  final String s = sha256.trim().toLowerCase();
  if (s.length < 12) return null;
  return s.substring(0, 12);
}

/// 统一的更新安装入口（偏差 2 闭环）。
///
/// 流程：确认 → 应用内下载 → 流式 SHA-256 校验 → 只有校验通过才启动安装器。
/// 校验失败（含公告未公布可校验摘要）一律拒绝安装并删除半成品文件。
///
/// 公告没有可校验摘要时**不下载**，只提供「打开下载页」这条人工路径 ——
/// 因为无法校验的包不该由应用替用户装。
Future<void> confirmDownload(
  BuildContext context,
  WidgetRef ref,
  Announcement announcement,
) async {
  final DownloadEntry? entry = announcement.downloadFor(
    Announcement.platformKey(),
  );
  final String url = Announcement.urlOf(entry);
  if (url.isEmpty) {
    ssToast(context, '请前往官网下载 v${announcement.version}');
    return;
  }

  final String? expected = normalizeSha256(entry?.sha256 ?? '');
  final String? digest = entry == null ? null : shortDigest(entry.sha256);

  if (expected == null) {
    final bool? openPage = await showSsDialog<bool>(
      context: context,
      title: '前往下载页',
      actions: (BuildContext ctx) => <Widget>[
        SsDialogAction(
          label: '取消',
          primary: false,
          onPressed: () => Navigator.of(ctx).pop(false),
        ),
        SsDialogAction(
          label: '打开下载页',
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
      ],
      child: Text(
        '该版本未公布可校验的 SHA-256，应用内不提供自动安装。'
        '请用浏览器下载 v${announcement.version}，并自行核对来源可信后再安装。',
        style: AppType.small.style(context.palette.muted),
      ),
    );
    if (openPage == true) await openDownloadPage(url);
    return;
  }

  final bool? go = await showSsDialog<bool>(
    context: context,
    title: '下载并校验',
    actions: (BuildContext ctx) => <Widget>[
      SsDialogAction(
        label: '取消',
        primary: false,
        onPressed: () => Navigator.of(ctx).pop(false),
      ),
      SsDialogAction(
        label: '下载并校验',
        onPressed: () => Navigator.of(ctx).pop(true),
      ),
    ],
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('将在应用内下载 v${announcement.version} 安装包，并流式计算 SHA-256。'),
        const SizedBox(height: AppSpace.s3),
        if (digest != null) ...<Widget>[
          const Text('官方 SHA-256（前 12 位）：'),
          const SizedBox(height: AppSpace.s1),
          SelectableText(
            digest,
            style: appMono(context.palette.ink, size: AppType.small.size),
          ),
          const SizedBox(height: AppSpace.s3),
        ],
        Text(
          '只有校验一致才会启动安装器；校验失败会删除文件并拒绝安装。',
          style: AppType.small.style(context.palette.muted),
        ),
      ],
    ),
  );
  if (go != true || !context.mounted) return;

  ssToast(context, '正在下载 v${announcement.version}…', kind: SsBannerKind.info);
  final UpdateDownloadResult result = await ref
      .read(updaterProvider.notifier)
      .downloadUpdate(announcement);
  if (!context.mounted) return;

  if (!result.canInstall) {
    ssToast(context, result.message, kind: SsBannerKind.danger);
    return;
  }

  final bool launched = await ref
      .read(updaterProvider.notifier)
      .installVerified(result);
  if (!context.mounted) return;
  ssToast(
    context,
    launched ? 'SHA-256 校验通过，已启动安装器。' : '校验通过，但安装器启动失败。',
    kind: launched ? SsBannerKind.success : SsBannerKind.warning,
  );
}

/// 兜底：直接打开下载页（公告未提供可校验摘要时的人工路径）。
Future<void> openDownloadPage(String url) async {
  if (url.isEmpty) return;
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
