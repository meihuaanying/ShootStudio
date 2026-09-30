import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/design/widgets.dart';
import '../updater/updater.dart';

/// 更新横幅（S4 信息架构 · 杂志风）：眉题 + 版本号 + 要点 chip + 双行动。
/// 纯展示组件（Consumer 仅为读 provider 与触发动作），便于单测直接构造。
class ShellUpdateBanner extends ConsumerWidget {
  const ShellUpdateBanner({super.key, required this.updater});

  final UpdaterState updater;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette p = context.palette;
    final Announcement? announcement = updater.announcement;
    if (announcement == null) return const SizedBox.shrink();
    return Container(
      color: p.surfaceSunken,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s5,
              vertical: AppSpace.s3,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                const Icon(Icons.system_update_alt_rounded, size: 16),
                const SizedBox(width: AppSpace.s2),
                Text('更新公告', style: appEyebrow(p.accent)),
                const SizedBox(width: AppSpace.s3),
                SsMonoBadge('v${announcement.version}'),
                const SizedBox(width: AppSpace.s3),
                Expanded(
                  child: Wrap(
                    spacing: AppSpace.s2,
                    runSpacing: AppSpace.s1,
                    children: <Widget>[
                      for (final String note in announcement.notes.take(2))
                        Text(
                          note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.caption.style(p.inkSoft),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpace.s3),
                SsButton(
                  label: '下次再说',
                  kind: SsButtonKind.text,
                  dense: true,
                  onPressed: () =>
                      ref.read(updaterProvider.notifier).dismissBanner(),
                ),
                const SizedBox(width: AppSpace.s2),
                SsButton(
                  label: '立即更新',
                  icon: Icons.download_rounded,
                  dense: true,
                  onPressed: () => _download(context, announcement),
                ),
              ],
            ),
          ),
          const SsDivider(),
        ],
      ),
    );
  }

  void _download(BuildContext context, Announcement announcement) {
    final String platform = Theme.of(context).platform == TargetPlatform.windows
        ? 'windows'
        : 'android';
    final DownloadEntry? entry = announcement.downloadFor(platform);
    final String url = entry == null
        ? ''
        : (entry.mirror.isNotEmpty ? entry.mirror : entry.github);
    if (url.isEmpty) {
      ssToast(context, '请前往官网下载 v${announcement.version}');
      return;
    }
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}
