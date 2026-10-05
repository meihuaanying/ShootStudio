import '../../core/design/feature_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/design/widgets.dart';
import '../../services/content_packs.dart';
import '../lighting/lighting_controller.dart';
import '../planner/planner_pending.dart';
import '../shell/app_shell.dart';
import 'cinematic_refs.dart';
import 'pose_gallery.dart';
import 'pose_import_page.dart';
import 'pose_skeleton.dart';

import 'poses_controller.dart';

part 'poses_page_layout.dart';

/// M3 动作摆姿库（V4 / D69）：实拍照片 + MediaPipe 骨架为主；
/// 网格 → 详情（大图/骨架/镜头机位要领）→ 导入布光预演；关节微调在布光页。
class PosesPage extends ConsumerStatefulWidget {
  const PosesPage({super.key});

  @override
  ConsumerState<PosesPage> createState() => _PosesPageState();
}

class _PosesPageState extends ConsumerState<PosesPage> {
  bool _showSkeleton = true;

  /// 版面方法在 part 里（extension），setState 是 State 的 protected 成员，走这个公开入口触发重建。
  void refresh(void Function() fn) => setState(fn);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      ref.read(posesControllerProvider.notifier).init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(posesControllerProvider);
    final controller = ref.read(posesControllerProvider.notifier);

    return SsPage(
      title: '动作摆姿库',
      subtitle: '真实照片姿势 · BlazePose 骨架与 12 关节 · 一键导入布光预演',
      actions: <Widget>[
        SsButton(
          label: '今日姿势',
          icon: Icons.auto_awesome_outlined,
          dense: true,
          onPressed: () => controller.today(),
        ),
        const SizedBox(width: 8),
        SsButton(
          label: '影视感参考',
          icon: Icons.movie_filter_outlined,
          kind: SsButtonKind.text,
          dense: true,
          onPressed: () => showCinematicRefsDialog(context),
        ),
        const SizedBox(width: 8),
        SsButton(
          label: '导入照片识别',
          icon: Icons.add_a_photo_outlined,
          kind: SsButtonKind.text,
          dense: true,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext _) => const PoseImportPage(),
            ),
          ),
        ),
      ],
      body: !state.initialized
          ? const Center(
              child: CircularProgressIndicator(strokeWidth: AppStroke.ringBold),
            )
          : Column(
              children: <Widget>[
                _buildFilters(state, controller),
                const SizedBox(height: AppSpace.s2),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      SizedBox(
                        width: 252,
                        child: _buildGrid(state, controller),
                      ),
                      const SizedBox(width: AppSpace.s3),
                      Expanded(child: _buildDetail(context, state, controller)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _openSource(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) ssToast(context, '无法打开链接：$url');
      }
    } catch (_) {
      if (mounted) ssToast(context, '打开失败：原始链接已登记在「设置 → 开源与素材许可」');
    }
  }

  Widget _tip(BuildContext context, String label, String text) {
    final AppPalette p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpaceFine.n10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              fontSize: AppFontSize.captionLg,
              color: p.accent,
              fontWeight: AppFontWeight.medium,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            text.isEmpty ? '—' : text,
            style: const TextStyle(fontSize: AppFontSize.small, height: 1.5),
          ),
        ],
      ),
    );
  }
}
