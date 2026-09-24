import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/design/widgets.dart';
import '../../core/theme/tokens.dart';
import '../../services/content_packs.dart';
import '../lighting/lighting_controller.dart';
import '../planner/planner_pending.dart';
import '../shell/app_shell.dart';
import 'cinematic_refs.dart';
import 'pose_import_page.dart';
import 'pose_skeleton.dart';
import 'poses_controller.dart';

/// M3 动作摆姿库（V4 / D69）：实拍照片 + MediaPipe 骨架为主；
/// 网格 → 详情（大图/骨架/镜头机位要领）→ 导入布光预演；关节微调在布光页。
class PosesPage extends ConsumerStatefulWidget {
  const PosesPage({super.key});

  @override
  ConsumerState<PosesPage> createState() => _PosesPageState();
}

class _PosesPageState extends ConsumerState<PosesPage> {
  bool _showSkeleton = true;

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
          kind: SsButtonKind.ghost,
          dense: true,
          onPressed: () => showCinematicRefsDialog(context),
        ),
        const SizedBox(width: 8),
        SsButton(
          label: '导入照片识别',
          icon: Icons.add_a_photo_outlined,
          kind: SsButtonKind.ghost,
          dense: true,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext _) => const PoseImportPage(),
            ),
          ),
        ),
      ],
      body: !state.initialized
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
          : Column(
              children: <Widget>[
                _buildFilters(state, controller),
                const SizedBox(height: AppTokens.s8),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      SizedBox(
                        width: 252,
                        child: _buildGrid(state, controller),
                      ),
                      const SizedBox(width: AppTokens.s12),
                      Expanded(child: _buildDetail(state, controller)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilters(PosesState state, PosesController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              for (final String c in poseCategories)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: SsChip(
                    label: c,
                    selected: state.category == c,
                    onTap: () => controller.setCategory(c),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            for (final String d in poseDifficulties)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: SsChip(
                  label: d,
                  selected: state.difficulty == d,
                  onTap: () => controller.setDifficulty(d),
                ),
              ),
            const SizedBox(width: AppTokens.s8),
            SizedBox(
              width: 200,
              child: TextField(
                decoration: const InputDecoration(
                  hintText: '搜索姿势名称…',
                  isDense: true,
                ),
                onChanged: controller.setKeyword,
              ),
            ),
            const SizedBox(width: AppTokens.s8),
            SsChip(
              label: _showSkeleton ? '骨架叠加开' : '骨架叠加',
              selected: _showSkeleton,
              onTap: () => setState(() => _showSkeleton = !_showSkeleton),
            ),
            const Spacer(),
            if (state.status.isNotEmpty)
              Text(
                state.status,
                style: AppTokens.mono(
                  context,
                  size: 11.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildGrid(PosesState state, PosesController controller) {
    return SsCard(
      padding: const EdgeInsets.all(AppTokens.s8),
      child: state.filtered.isEmpty
          ? const SsEmpty(
              icon: Icons.accessibility_new_outlined,
              art: SsArt.pose,
              title: '没有匹配的姿势',
            )
          : GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 0.6,
              ),
              itemCount: state.filtered.length,
              itemBuilder: (BuildContext context, int i) {
                final PoseEntry pose = state.filtered[i];
                final bool selected = i == state.index;
                final bool fav = state.favorites.contains(pose.id);
                return SsCard(
                  padding: const EdgeInsets.all(4),
                  selected: selected,
                  onTap: () => controller.select(i),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: PosePhotoView(
                            photo: pose.photo,
                            skeleton: pose.skeleton,
                            showSkeleton: _showSkeleton,
                            fit: BoxFit.cover,
                            cacheWidth: 260,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pose.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected ? AppTokens.accent : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              pose.category,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9.5,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          if (fav)
                            const Icon(
                              Icons.star_rounded,
                              size: 12,
                              color: AppTokens.warning,
                            ),
                          if (pose.referenceOnly || pose.partialBody)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppTokens.warning.withValues(
                                  alpha: 0.16,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                pose.partialBody ? '半身' : '参考',
                                style: const TextStyle(
                                  fontSize: 8.5,
                                  color: AppTokens.warning,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildDetail(PosesState state, PosesController controller) {
    final PoseEntry? pose = state.current;
    if (pose == null) {
      return const SsCard(
        child: SsEmpty(icon: Icons.info_outline_rounded, title: '未选择姿势'),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: SsCard(
            padding: const EdgeInsets.all(AppTokens.s8),
            child: Column(
              children: <Widget>[
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppTokens.rMd),
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        Container(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          child: PosePhotoView(
                            photo: pose.photo,
                            skeleton: pose.skeleton,
                            showSkeleton: _showSkeleton,
                            fit: BoxFit.contain,
                          ),
                        ),
                        Positioned(
                          right: 10,
                          top: 10,
                          child: SsChip(
                            label: _showSkeleton ? '骨架开' : '骨架',
                            selected: _showSkeleton,
                            onTap: () =>
                                setState(() => _showSkeleton = !_showSkeleton),
                          ),
                        ),
                        Positioned(
                          left: 10,
                          bottom: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${pose.name} · ${pose.category} · ${pose.difficulty}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppTokens.s8),
                Row(
                  children: <Widget>[
                    SsButton(
                      label: '← 上一个',
                      kind: SsButtonKind.ghost,
                      dense: true,
                      onPressed: controller.prev,
                    ),
                    const SizedBox(width: 6),
                    SsButton(
                      label: '下一个 →',
                      kind: SsButtonKind.ghost,
                      dense: true,
                      onPressed: controller.next,
                    ),
                    const Spacer(),
                    Text(
                      '${state.index + 1} / ${state.filtered.length}',
                      style: AppTokens.mono(context, size: 11.5),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppTokens.s12),
        SizedBox(width: 272, child: _buildInfo(state, controller)),
      ],
    );
  }

  Widget _buildInfo(PosesState state, PosesController controller) {
    final PoseEntry? pose = state.current;
    if (pose == null) {
      return const SsCard(
        child: SsEmpty(icon: Icons.info_outline_rounded, title: '未选择姿势'),
      );
    }
    final bool fav = state.favorites.contains(pose.id);
    final bool overridden = state.isOverridden(pose.id);
    final bool custom = state.isCustom(pose.id);
    final int confidence = (pose.confidence * 100).round();
    return SsCard(
      child: ListView(
        children: <Widget>[
          SsSectionTitle(
            pose.name,
            subtitle:
                '${pose.category} · ${pose.difficulty}'
                '${overridden
                    ? ' · 已本地覆盖'
                    : custom
                    ? ' · 自定义'
                    : ''}',
          ),
          const SizedBox(height: AppTokens.s8),
          if (pose.referenceOnly)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTokens.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTokens.rSm),
                border: Border.all(
                  color: AppTokens.warning.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                '骨架置信度 $confidence% · 低置信度，仅供构图参考（不可宣称可复现）',
                style: const TextStyle(fontSize: 11.5, height: 1.5),
              ),
            )
          else
            Text(
              '骨架置信度 $confidence% · 12 关节由 3D 关键点推导',
              style: TextStyle(
                fontSize: 11.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          if (pose.partialBody) ...<Widget>[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTokens.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTokens.rSm),
                border: Border.all(
                  color: AppTokens.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                '照片局限：${pose.partialReason} · 3D 关节复现仅供构图参考',
                style: const TextStyle(fontSize: 11, height: 1.5),
              ),
            ),
          ],
          const SizedBox(height: AppTokens.s12),
          _tip('重心落点', pose.weight),
          _tip('手部摆放', pose.hands),
          _tip('常见错误', pose.mistake),
          _tip('镜头建议', pose.lens),
          _tip('机位建议', pose.cameraPosition),
          const Divider(height: 18),
          Text(
            '照片出处：${pose.author.isEmpty ? '未署名' : pose.author} · ${pose.license}',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (pose.source.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: SsButton(
                label: '查看原图出处',
                icon: Icons.open_in_new_rounded,
                kind: SsButtonKind.ghost,
                dense: true,
                onPressed: () => _openSource(pose.source),
              ),
            ),
          const SizedBox(height: AppTokens.s12),
          SsButton(
            label: fav ? '取消收藏' : '收藏到姿势清单',
            icon: fav ? Icons.star_rounded : Icons.star_outline_rounded,
            kind: SsButtonKind.ghost,
            onPressed: () => controller.toggleFavorite(),
          ),
          const SizedBox(height: 8),
          SsButton(
            label: '替换参考图（导入照片识别）',
            icon: Icons.swap_horiz_rounded,
            kind: SsButtonKind.ghost,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext _) => PoseImportPage(overridePose: pose),
              ),
            ),
          ),
          if (overridden) ...<Widget>[
            const SizedBox(height: 8),
            SsButton(
              label: '恢复默认参考图',
              icon: Icons.settings_backup_restore_rounded,
              kind: SsButtonKind.ghost,
              onPressed: () => controller.restoreBuiltin(pose.id),
            ),
          ],
          if (custom) ...<Widget>[
            const SizedBox(height: 8),
            SsButton(
              label: '删除该自定义姿势',
              icon: Icons.delete_outline_rounded,
              kind: SsButtonKind.ghost,
              onPressed: () async {
                final bool? confirmed = await showDialog<bool>(
                  context: context,
                  builder: (BuildContext ctx) => AlertDialog(
                    title: const Text(
                      '删除自定义姿势',
                      style: TextStyle(fontSize: 16),
                    ),
                    content: Text('确定删除「${pose.name}」？该操作不可撤销。'),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('删除'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await controller.deleteCustom(pose.id);
                }
              },
            ),
          ],
          const SizedBox(height: 8),
          SsButton(
            label: '导入到布光预演',
            icon: Icons.wb_incandescent_outlined,
            onPressed: () {
              ref
                  .read(lightingControllerProvider.notifier)
                  .injectPose(
                    state.effectiveJoints,
                    pose.name,
                    handL: pose.handsL,
                    handR: pose.handsR,
                  );
              ref.read(shellTabProvider.notifier).state = 2; // 布光预演
              ssToast(context, '已把「${pose.name}」导入布光预演，可在右栏微调关节与手部');
            },
          ),
          const SizedBox(height: 8),
          SsButton(
            label: '加入策划案姿势清单',
            icon: Icons.playlist_add_rounded,
            kind: SsButtonKind.soft,
            onPressed: () {
              ref
                  .read(pendingPosesProvider.notifier)
                  .add(
                    PendingPose(
                      name: pose.name,
                      joints: state.effectiveJoints,
                      lens: pose.lens,
                      cameraPosition: pose.cameraPosition,
                      photo: pose.photo,
                      author: pose.author,
                      license: pose.license,
                      source: pose.source,
                    ),
                  );
              ssToast(context, '已加入待插入清单（策划案 → 姿势清单模块可插入）');
            },
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

  Widget _tip(String label, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppTokens.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            text.isEmpty ? '—' : text,
            style: const TextStyle(fontSize: 12.5, height: 1.5),
          ),
        ],
      ),
    );
  }
}
