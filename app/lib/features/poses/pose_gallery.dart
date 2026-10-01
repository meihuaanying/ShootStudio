// V8/S7 · D153：姿势库大图瀑布流（图卡 + 分类眉题）与详情半屏抽屉。
//
// D153 要求「杂志式大图流 + 分类眉题」「详情半屏抽屉（大图 + 骨架叠加开关 +
// 镜头建议 + 送入布光主行动）」。瀑布流复用 S5 的列式布局原语 RefsMasonryGrid
// （lib/features/refs/refs_masonry.dart），本文件只加姿势语义（图卡 + 眉题 + 抽屉）。

import 'package:flutter/material.dart';

import '../../core/design/widgets.dart';
import '../../services/content_packs.dart';
import '../refs/refs_masonry.dart';
import 'pose_skeleton.dart';

/// 分类眉题（杂志式：分类名 + 该类数量 + 一条 hairline）。
class PoseCategoryEyebrow extends StatelessWidget {
  const PoseCategoryEyebrow({
    super.key,
    required this.category,
    required this.count,
  });

  final String category;
  final int count;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s3, bottom: AppSpace.s2),
      child: Row(
        children: <Widget>[
          Text(category, style: AppType.h3.style(p.ink)),
          const SizedBox(width: 6),
          Text('$count', style: appMono(p.muted, size: 11)),
          const SizedBox(width: AppSpace.s2),
          Expanded(child: Container(height: 1, color: p.rule)),
        ],
      ),
    );
  }
}

/// 姿势图卡（大图 4:5 + 底部信息条：名称 / 分类 · 难度）。
class PoseGalleryCard extends StatelessWidget {
  const PoseGalleryCard({
    super.key,
    required this.pose,
    required this.showSkeleton,
    this.selected = false,
    this.onTap,
  });

  final PoseEntry pose;
  final bool showSkeleton;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? p.accent : p.rule,
            width: selected ? 1.6 : 1,
          ),
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            RefsMasonryImage(
              width: 720,
              height: 960,
              placeholderLabel: pose.name,
              child: PosePhotoView(
                photo: pose.photo,
                skeleton: pose.skeleton,
                showSkeleton: showSkeleton,
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    pose.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: selected ? p.accent : p.ink,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${pose.category} · ${pose.difficulty}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: appMono(p.muted, size: 10.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 大图瀑布流（列数随宽度自适应；纵向图更高）。
class PoseGalleryGrid extends StatelessWidget {
  const PoseGalleryGrid({
    super.key,
    required this.poses,
    required this.showSkeleton,
    required this.selectedId,
    required this.onTap,
    this.maxColumnWidth = 236,
    this.headerBuilder,
  });

  final List<PoseEntry> poses;
  final bool showSkeleton;
  final String selectedId;
  final void Function(PoseEntry pose) onTap;
  final double maxColumnWidth;

  /// 每张图卡之前的可选分类眉题（D153 杂志式版面）。返回 null 表示该卡没有眉题。
  final Widget? Function(int index)? headerBuilder;

  @override
  Widget build(BuildContext context) {
    if (poses.isEmpty) {
      return const SsEmpty(
        icon: Icons.accessibility_new,
        art: SsArt.pose,
        title: '没有匹配的姿势',
        hint: '换个分类或清空搜索词',
      );
    }
    final bool withHeaders = headerBuilder != null;
    return RefsMasonryGrid(
      itemCount: withHeaders ? poses.length * 2 : poses.length,
      maxColumnWidth: maxColumnWidth,
      itemBuilder: (BuildContext context, int i) {
        final int poseIndex = withHeaders ? i ~/ 2 : i;
        if (withHeaders && i.isOdd) {
          return headerBuilder!(poseIndex) ?? const SizedBox.shrink();
        }
        return PoseGalleryCard(
          pose: poses[poseIndex],
          showSkeleton: showSkeleton,
          selected: poses[poseIndex].id == selectedId,
          onTap: () => onTap(poses[poseIndex]),
        );
      },
    );
  }
}

/// 详情半屏抽屉：大图 + 骨架叠加开关 + 镜头/机位建议 + 送入布光主行动。
Future<void> showPoseDetailSheet({
  required BuildContext context,
  required PoseEntry pose,
  required bool showSkeleton,
  required bool favorite,
  required VoidCallback onToggleSkeleton,
  required VoidCallback onToggleFavorite,
  required VoidCallback onInjectLighting,
  VoidCallback? onAddToPending,
}) {
  final AppPalette p = context.palette;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: p.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadius.frame),
      ),
    ),
    constraints: const BoxConstraints(maxWidth: 720),
    builder: (BuildContext sheetContext) {
      // 半屏抽屉在无 Scaffold 的宿主（测试壳）里可能拿到无界宽度：
      // SsSectionTitle 内部是 Row + flex，无界宽度会直接抛
      // "RenderFlex children have non-zero flex but incoming width
      // constraints are unbounded"。这里用 ConstrainedBox 兜一层硬上限，
      // 并把底部按钮的 Expanded 换成 Flexible（loose），无界时也能收缩。
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    // SsSectionTitle 内部是 Row + flex：放在 Row 的非 flex 位会拿到
                    // 无界宽度 → 必须用 Expanded 把它约束住（否则报
                    // "RenderFlex children have non-zero flex but incoming width
                    // constraints are unbounded"）。
                    Expanded(
                      child: SsSectionTitle(
                        pose.name,
                        subtitle: '${pose.category} · ${pose.difficulty}',
                      ),
                    ),
                    SsChip(
                      label: showSkeleton ? '骨架叠加开' : '骨架叠加',
                      selected: showSkeleton,
                      onTap: () {
                        onToggleSkeleton();
                        Navigator.pop(sheetContext);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.s3),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.control),
                    child: PosePhotoView(
                      photo: pose.photo,
                      skeleton: pose.skeleton,
                      showSkeleton: showSkeleton,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.s3),
                if (pose.lens.isNotEmpty)
                  _SheetLine(label: '镜头建议', value: pose.lens),
                if (pose.cameraPosition.isNotEmpty)
                  _SheetLine(label: '机位建议', value: pose.cameraPosition),
                if (pose.weight.isNotEmpty)
                  _SheetLine(label: '重心', value: pose.weight),
                const SizedBox(height: AppSpace.s3),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: SsButton(
                        label: favorite ? '取消收藏' : '收藏到姿势清单',
                        icon: favorite
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        kind: SsButtonKind.text,
                        dense: true,
                        onPressed: () {
                          onToggleFavorite();
                          Navigator.pop(sheetContext);
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: SsButton(
                        label: '送入布光',
                        icon: Icons.wb_sunny_outlined,
                        dense: true,
                        onPressed: () {
                          onInjectLighting();
                          Navigator.pop(sheetContext);
                        },
                      ),
                    ),
                  ],
                ),
                if (onAddToPending != null) ...<Widget>[
                  const SizedBox(height: 6),
                  SsButton(
                    label: '加入策划案姿势清单',
                    kind: SsButtonKind.text,
                    dense: true,
                    onPressed: () {
                      onAddToPending();
                      Navigator.pop(sheetContext);
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _SheetLine extends StatelessWidget {
  const _SheetLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 62,
            child: Text(label, style: appMono(p.muted, size: 11)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 12.5, color: p.inkSoft),
            ),
          ),
        ],
      ),
    );
  }
}
