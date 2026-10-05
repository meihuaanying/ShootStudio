// V8/S7 · D153：动作摆姿库的版面构建方法（筛选条 / 瀑布流 / 详情舞台 / 信息面板）。
// 与 poses_page.dart 同一库（part），因此 extension 方法可直接访问页面私有状态；
// 只做搬运，让 poses_page.dart 回到 R73 行数门禁以内，行为零变化。
part of 'poses_page.dart';

extension _PosesPageLayout on _PosesPageState {
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
                  padding: const EdgeInsets.only(right: AppSpaceFine.n6),
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
                padding: const EdgeInsets.only(right: AppSpaceFine.n6),
                child: SsChip(
                  label: d,
                  selected: state.difficulty == d,
                  onTap: () => controller.setDifficulty(d),
                ),
              ),
            const SizedBox(width: AppSpace.s2),
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
            const SizedBox(width: AppSpace.s2),
            SsChip(
              label: _showSkeleton ? '骨架叠加开' : '骨架叠加',
              selected: _showSkeleton,
              onTap: () => refresh(() => _showSkeleton = !_showSkeleton),
            ),
            const Spacer(),
            if (state.status.isNotEmpty)
              Text(
                state.status,
                style: appMono(context.palette.inkSoft, size: 11.5),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildGrid(PosesState state, PosesController controller) {
    final List<PoseEntry> list = state.filtered;
    if (list.isEmpty) {
      return const SsCard(
        padding: EdgeInsets.all(AppSpace.s2),
        child: SsEmpty(
          icon: Icons.accessibility_new_outlined,
          art: SsArt.pose,
          title: '没有匹配的姿势',
        ),
      );
    }
    // D153：杂志式大图瀑布流 + 分类眉题（分类变化处插一条眉题）。
    return SsCard(
      padding: const EdgeInsets.all(AppSpace.s2),
      child: PoseGalleryGrid(
        poses: list,
        showSkeleton: _showSkeleton,
        selectedId: state.current?.id ?? '',
        headerBuilder: (int index) => _categoryHeaderFor(state, index),
        onTap: (PoseEntry pose) => _openPoseSheetFor(state, controller, pose),
      ),
    );
  }

  /// D153：瀑布流里每张图卡之前的分类眉题（按当前筛选集合的类别变化切分）。
  Widget? _categoryHeaderFor(PosesState state, int index) {
    final List<PoseEntry> list = state.filtered;
    if (index < 0 || index >= list.length) return null;
    final String category = list[index].category;
    if (index > 0 && list[index - 1].category == category) return null;
    final int count = list
        .where((PoseEntry e) => e.category == category)
        .length;
    return PoseCategoryEyebrow(category: category, count: count);
  }

  /// D153：送入布光预演（与信息面板里的「导入到布光预演」同一条路径）。
  void _injectPose(PosesState state, PoseEntry pose) {
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
  }

  /// D153：加入策划案姿势清单（与信息面板里的「加入策划案姿势清单」同一条路径）。
  void _addToPending(PosesState state, PoseEntry pose) {
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
    ssToast(context, '已加入策划案姿势清单：${pose.name}');
  }

  /// D153：图卡 tap → 详情半屏抽屉（先选中再打开）。
  Future<void> _openPoseSheetFor(
    PosesState state,
    PosesController controller,
    PoseEntry pose,
  ) async {
    final int index = state.filtered.indexOf(pose);
    if (index < 0) return;
    controller.select(index);
    await showPoseDetailSheet(
      context: context,
      pose: pose,
      showSkeleton: _showSkeleton,
      favorite: state.favorites.contains(pose.id),
      onToggleSkeleton: () => refresh(() => _showSkeleton = !_showSkeleton),
      onToggleFavorite: () => controller.toggleFavorite(),
      onInjectLighting: () => _injectPose(state, pose),
      onAddToPending: () => _addToPending(state, pose),
    );
  }

  Widget _buildDetail(
    BuildContext context,
    PosesState state,
    PosesController controller,
  ) {
    final AppPalette p = context.palette;
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
            padding: const EdgeInsets.all(AppSpace.s2),
            child: Column(
              children: <Widget>[
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.control),
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
                                refresh(() => _showSkeleton = !_showSkeleton),
                          ),
                        ),
                        Positioned(
                          left: 10,
                          bottom: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpaceFine.n10,
                              vertical: AppSpaceFine.n6,
                            ),
                            decoration: BoxDecoration(
                              color: AppFeatureColor.imageScrim,
                              borderRadius: BorderRadius.circular(
                                AppRadius.frame,
                              ),
                            ),
                            child: Text(
                              '${pose.name} · ${pose.category} · ${pose.difficulty}',
                              style: const TextStyle(
                                color: AppFeatureColor.onFill,
                                fontSize: AppFontSize.captionLg,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.s2),
                Row(
                  children: <Widget>[
                    SsButton(
                      label: '← 上一个',
                      kind: SsButtonKind.text,
                      dense: true,
                      onPressed: controller.prev,
                    ),
                    const SizedBox(width: 6),
                    SsButton(
                      label: '下一个 →',
                      kind: SsButtonKind.text,
                      dense: true,
                      onPressed: controller.next,
                    ),
                    const Spacer(),
                    Text(
                      '${state.index + 1} / ${state.filtered.length}',
                      style: appMono(p.inkSoft),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpace.s3),
        SizedBox(width: 272, child: _buildInfo(context, state, controller)),
      ],
    );
  }

  Widget _buildInfo(
    BuildContext context,
    PosesState state,
    PosesController controller,
  ) {
    final AppPalette p = context.palette;
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
          const SizedBox(height: AppSpace.s2),
          if (pose.referenceOnly)
            Container(
              padding: const EdgeInsets.all(AppSpace.s2),
              decoration: BoxDecoration(
                color: p.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.chip),
                border: Border.all(color: p.gold.withValues(alpha: 0.4)),
              ),
              child: Text(
                '骨架置信度 $confidence% · 低置信度，仅供构图参考（不可宣称可复现）',
                style: const TextStyle(
                  fontSize: AppFontSize.captionLg,
                  height: 1.5,
                ),
              ),
            )
          else
            Text(
              '骨架置信度 $confidence% · 12 关节由 3D 关键点推导',
              style: TextStyle(
                fontSize: AppFontSize.captionLg,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          if (pose.partialBody) ...<Widget>[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(AppSpace.s2),
              decoration: BoxDecoration(
                color: p.gold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.chip),
                border: Border.all(color: p.gold.withValues(alpha: 0.3)),
              ),
              child: Text(
                '照片局限：${pose.partialReason} · 3D 关节复现仅供构图参考',
                style: const TextStyle(
                  fontSize: AppFontSize.caption,
                  height: 1.5,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpace.s3),
          _tip(context, '重心落点', pose.weight),
          _tip(context, '手部摆放', pose.hands),
          _tip(context, '常见错误', pose.mistake),
          _tip(context, '镜头建议', pose.lens),
          _tip(context, '机位建议', pose.cameraPosition),
          const Divider(height: 18),
          Text(
            '照片出处：${pose.author.isEmpty ? '未署名' : pose.author} · ${pose.license}',
            style: TextStyle(
              fontSize: AppFontSize.caption,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (pose.source.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: SsButton(
                label: '查看原图出处',
                icon: Icons.open_in_new_rounded,
                kind: SsButtonKind.text,
                dense: true,
                onPressed: () => _openSource(pose.source),
              ),
            ),
          const SizedBox(height: AppSpace.s3),
          SsButton(
            label: fav ? '取消收藏' : '收藏到姿势清单',
            icon: fav ? Icons.star_rounded : Icons.star_outline_rounded,
            kind: SsButtonKind.text,
            onPressed: () => controller.toggleFavorite(),
          ),
          const SizedBox(height: 8),
          SsButton(
            label: '替换参考图（导入照片识别）',
            icon: Icons.swap_horiz_rounded,
            kind: SsButtonKind.text,
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
              kind: SsButtonKind.text,
              onPressed: () => controller.restoreBuiltin(pose.id),
            ),
          ],
          if (custom) ...<Widget>[
            const SizedBox(height: 8),
            SsButton(
              label: '删除该自定义姿势',
              icon: Icons.delete_outline_rounded,
              kind: SsButtonKind.text,
              onPressed: () async {
                final bool? confirmed = await showDialog<bool>(
                  context: context,
                  builder: (BuildContext ctx) => AlertDialog(
                    title: const Text(
                      '删除自定义姿势',
                      style: TextStyle(fontSize: AppFontSize.bodyXl),
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
            kind: SsButtonKind.outline,
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
}
