import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/design/widgets.dart';
import '../updater/updater.dart';

/// 当前平台在公告 JSON 里的键名。
String updaterPlatformKey() => Platform.isWindows ? 'windows' : 'android';

/// 取下载链接：优先国内镜像，回落 GitHub Release。
String downloadUrlOf(DownloadEntry? entry) {
  if (entry == null) return '';
  return entry.mirror.isNotEmpty ? entry.mirror : entry.github;
}

/// 展示官方 SHA-256 便于人工核对（只取前 12 位，肉眼比对够用）。
///
/// **这里刻意不做应用内自动校验** —— 应用只负责把官方公布的摘要摊开给用户看，
/// 校验需要下载整包再流式计算摘要，是独立的一条链路。
/// 详见 `docs/qa/v8-r71-deviations.md` 偏差 2。
String? shortDigest(String sha256) {
  final String s = sha256.trim().toLowerCase();
  if (s.length < 12) return null;
  return s.substring(0, 12);
}

/// 统一的「打开下载链接」确认弹窗。
///
/// 之前 `settings_page` 与 `shell_update_banner` 各自复制了一份
/// 「算 platform → 取 entry → 挑 mirror/github → 空则 toast → 否则 launchUrl」，
/// 两份都会静默忽略 [DownloadEntry.sha256]。现在收口到一处，
/// 并且必须让用户看见官方摘要与「应用不代你校验」的说明。
Future<void> confirmDownload(
  BuildContext context,
  Announcement announcement,
) async {
  final DownloadEntry? entry = announcement.downloadFor(updaterPlatformKey());
  final String url = downloadUrlOf(entry);
  if (url.isEmpty) {
    ssToast(context, '请前往官网下载 v${announcement.version}');
    return;
  }

  final String? digest = entry == null ? null : shortDigest(entry.sha256);
  await showDialog<void>(
    context: context,
    builder: (BuildContext ctx) {
      final AppPalette p = ctx.palette;
      return AlertDialog(
        title: const Text('确认下载'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('即将用浏览器打开 v${announcement.version} 安装包。'),
            const SizedBox(height: AppSpace.s3),
            if (digest != null) ...<Widget>[
              const Text('官方 SHA-256（前 12 位）：'),
              const SizedBox(height: AppSpace.s1),
              SelectableText(
                digest,
                style: appMono(p.ink, size: AppFontSize.smallLg),
              ),
              const SizedBox(height: AppSpace.s3),
            ],
            Text(
              digest == null
                  ? '该版本未公布 SHA-256，下载后请自行确认来源可信。'
                  : '请在下载完成后用官方公布的完整摘要核对文件，'
                        '确认一致再安装。本应用不代你校验下载完整性。',
              style: TextStyle(fontSize: AppFontSize.smallLg, color: p.muted),
            ),
          ],
        ),
        actions: <Widget>[
          SsButton(
            label: '取消',
            dense: true,
            onPressed: () => Navigator.pop(ctx),
          ),
          SsButton(
            label: '打开下载',
            dense: true,
            onPressed: () {
              Navigator.pop(ctx);
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            },
          ),
        ],
      );
    },
  );
}
