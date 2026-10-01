import 'dart:io';
import '../../core/db/database.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import '../../services/net.dart';
import '../../services/net_router.dart';
import 'package:file_picker/file_picker.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app.dart';
import '../../core/design/widgets.dart';
import '../../core/providers.dart';
import '../../dev/design_demo_page.dart';
import '../../services/gear_photo_sync.dart';
import '../../services/engine/engine_reload.dart';
import '../../services/gpu/gpu_info.dart';
import '../../services/search/search_cache.dart';
import '../ai/ai_controller.dart';
import '../onboarding/demo_content.dart';
import '../updater/updater.dart';

part 'settings_page_cards.dart';
part 'settings_page_sources.dart';
part 'settings_page_gpu.dart';

/// 示例内容状态（设置页可一键移除）。
final demoSeededProvider = FutureProvider.autoDispose<bool>(
  (ref) => DemoContentService.isSeeded(ref.watch(databaseProvider)),
);

/// 设置：外观 / 工作区 / 示例内容 / 关于与更新（PRD 6.9：三态 + 静默降级 + 内容包通道）。
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  String? _announcementUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((Duration _) async {
      final url = await ref.read(updaterProvider.notifier).announcementUrl();
      if (mounted) setState(() => _announcementUrl = url);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;

    final theme = Theme.of(context);
    final mode = ref.watch(themeModeProvider);
    final workspace = ref.watch(workspaceProvider);
    final updater = ref.watch(updaterProvider);

    return SsPage(
      title: '设置',
      subtitle: '外观 · 工作区 · AI 通道 · 图片素材 · 显卡 · 关于与更新',
      body: ListView(
        children: <Widget>[
          SsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SsSectionTitle('外观', subtitle: 'D12：统一设计令牌，明暗双主题跟随系统'),
                const SizedBox(height: AppSpace.s3),
                Row(
                  children: <Widget>[
                    for (final entry in <(String, ThemeMode)>[
                      ('跟随系统', ThemeMode.system),
                      ('亮色', ThemeMode.light),
                      ('暗色', ThemeMode.dark),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: SsChip(
                          label: entry.$1,
                          selected: mode == entry.$2,
                          onTap: () =>
                              ref.read(themeModeProvider.notifier).state =
                                  entry.$2,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s3),
          SsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SsSectionTitle('工作区', subtitle: '本地优先：数据随目录整体迁移'),
                const SizedBox(height: AppSpace.s3),
                Text(
                  workspace.root.path,
                  style: appMono(theme.colorScheme.onSurfaceVariant, size: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s3),
          Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? _) {
              final AsyncValue<bool> seeded = ref.watch(demoSeededProvider);
              return seeded.maybeWhen(
                data: (bool isSeeded) => isSeeded
                    ? SsCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const SsSectionTitle(
                              '示例内容',
                              subtitle:
                                  '首次引导载入的演示数据（策划案 / 参考帧 / 布光方案 / 资源 / 姿势）',
                            ),
                            const SizedBox(height: AppSpace.s2),
                            SsButton(
                              label: '移除示例内容',
                              icon: Icons.delete_sweep_outlined,
                              kind: SsButtonKind.text,
                              dense: true,
                              onPressed: () async {
                                await DemoContentService.remove(
                                  ref.read(databaseProvider),
                                );
                                ref.invalidate(demoSeededProvider);
                                if (context.mounted) {
                                  ssToast(context, '示例内容已移除（你的数据未被触碰）');
                                }
                              },
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
                orElse: () => const SizedBox.shrink(),
              );
            },
          ),
          const SizedBox(height: AppSpace.s3),
          const _AiChannelsCard(),
          const SizedBox(height: AppSpace.s3),
          const _AssetSourcesCard(),
          const SizedBox(height: AppSpace.s3),
          const _GpuCard(),
          const SizedBox(height: AppSpace.s3),
          // V8/D147 · S3：设计组件预览入口（合同 §6 L203：仅 debug 构建可见）。
          if (kDebugMode)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s3),
              child: SsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SsSectionTitle(
                      '设计系统',
                      subtitle: 'V8/D147 · 组件库预览（仅 debug 构建可见）',
                    ),
                    const SizedBox(height: AppSpace.s3),
                    SsButton(
                      label: '设计组件预览',
                      icon: Icons.palette_outlined,
                      kind: SsButtonKind.outline,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (BuildContext _) => DesignDemoPage(
                            variant: AppTokensV2.of(context).variant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SsSectionTitle(
                  '关于与更新',
                  subtitle: 'GitHub Release 为唯一事实源 · 版本与内容包双通道',
                ),
                const SizedBox(height: AppSpace.s3),
                Row(
                  children: <Widget>[
                    Text(
                      '当前版本 v$kAppVersion',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const Spacer(),
                    SsButton(
                      label: updater.checking ? '检查中…' : '检查更新',
                      kind: SsButtonKind.text,
                      dense: true,
                      onPressed: updater.checking ? null : _manualCheck,
                    ),
                  ],
                ),
                if (updater.status.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    updater.status,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (updater.announcement != null &&
                    updater.lastState == UpdateState.hasUpdate) ...<Widget>[
                  const SizedBox(height: 8),
                  SsBanner(
                    text:
                        'v${updater.announcement!.version} · ${updater.announcement!.publishedAt}\n'
                        '${updater.announcement!.notes.take(4).map((String n) => '· $n').join('\n')}',
                    kind: SsBannerKind.info,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      SsButton(
                        label: '立即更新（国内镜像）',
                        dense: true,
                        onPressed: () {
                          final entry = updater.announcement!.downloadFor(
                            Platform.isWindows ? 'windows' : 'android',
                          );
                          final url = entry == null
                              ? ''
                              : (entry.mirror.isNotEmpty
                                    ? entry.mirror
                                    : entry.github);
                          if (url.isEmpty) {
                            ssToast(context, '请前往官网下载最新版本');
                          } else {
                            launchUrl(
                              Uri.parse(url),
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      SsButton(
                        label: '稍后再说',
                        kind: SsButtonKind.text,
                        dense: true,
                        onPressed: () =>
                            ref.read(updaterProvider.notifier).dismissBanner(),
                      ),
                    ],
                  ),
                ],
                for (final op
                    in updater.announcement?.ops ??
                        const <({String date, String title})>[])
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '公告：${op.title}${op.date.isEmpty ? '' : '（${op.date}）'}',
                      style: TextStyle(fontSize: 11.5, color: p.accent),
                    ),
                  ),
                const SizedBox(height: 10),
                TextField(
                  controller: TextEditingController(
                    text: _announcementUrl ?? '',
                  ),
                  decoration: const InputDecoration(
                    labelText: '公告 JSON 地址（空 = 官方默认；支持自建站点 / 内网）',
                    isDense: true,
                  ),
                  onSubmitted: (String v) async {
                    await ref
                        .read(updaterProvider.notifier)
                        .setAnnouncementUrl(v);
                    if (mounted) setState(() => _announcementUrl = v.trim());
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _manualCheck() async {
    final result = await ref.read(updaterProvider.notifier).manualCheck();
    if (!mounted) return;
    final message = switch (result) {
      UpdateState.hasUpdate => '发现新版本，请查看下方更新要点',
      UpdateState.upToDate => '已是最新版本',
      UpdateState.failed => '网络异常，请稍后重试',
      UpdateState.silent => '检查未完成',
    };
    ssToast(context, message);
  }
}

/// D40：AI 通道管理（设置页）：Key、启用、自动拉模型、自动选模、故障转移顺序。
