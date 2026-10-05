// V8/S8 · D158：策划案页版面与交互方法（左侧清单 / 画布 / 右编辑器 / 模板 / 历史 /
// 对比 / 命名）。part + extension 形式：extension 与宿主同库可访问私有字段；
// protected setState 统一走宿主暴露的 refresh()。
part of 'planner_page.dart';

extension _PlannerPageLayout on _PlannerPageState {
  Future<void> _autoCollectRefs(List<PlanModuleData> inserted) async {
    if (!mounted) return;
    String theme = '';
    for (final PlanModuleData m in inserted) {
      if (m.type == PlanModuleType.theme) {
        theme = (m.data['text'] as String? ?? '').trim();
        if (theme.isNotEmpty) break;
      }
    }
    if (theme.isEmpty) return;
    final PlannerState state = ref.read(plannerControllerProvider);
    PlanModuleData? target;
    for (final PlanModuleData m in state.modules.reversed) {
      if (m.type == PlanModuleType.refs) {
        target = m;
        break;
      }
    }
    if (target == null) return;
    ssToast(context, '正在为主题自动搜集参考图（5–10 张）…');
    try {
      final PlannerRefsService service = PlannerRefsService(
        db: ref.read(databaseProvider),
        workspaceRoot: ref.read(workspaceProvider).root.path,
      );
      final List<Map<String, Object?>> entries = await service.searchForTheme(
        theme,
        target: 8,
      );
      if (!mounted) return;
      if (entries.isEmpty) {
        ssToast(context, '自动参考图未搜集到（可检查网络/Key，或在搜图工作台手动搜索）');
        return;
      }
      final String targetId = target.id;
      ref.read(plannerControllerProvider.notifier).updateModule(targetId, (
        PlanModuleData m,
      ) {
        final List<Object?> list = <Object?>[
          ...(m.data['refs'] as List? ?? <Object?>[]),
          ...entries,
        ];
        m.data['refs'] = list;
      });
      ssToast(context, '已自动附入 ${entries.length} 张参考图（含来源与许可，可换/删）');
    } catch (e) {
      if (mounted) ssToast(context, '自动参考图失败：$e');
    }
  }

  Widget _buildLeftPanel(
    BuildContext context,
    PlannerState state,
    PlannerController controller,
  ) {
    final AppPalette p = context.palette;
    return SizedBox(
      width: 196,
      child: SsCard(
        padding: const EdgeInsets.all(AppSpace.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SsSectionTitle('开始', subtitle: '从模板或空白'),
            const SizedBox(height: AppSpace.s2),
            SsButton(
              label: '模板库',
              icon: Icons.dashboard_customize_outlined,
              dense: true,
              onPressed: () => _showTemplatePicker(controller),
            ),
            const SizedBox(height: 6),
            SsButton(
              label: '空白策划案',
              kind: SsButtonKind.text,
              dense: true,
              onPressed: () => controller.newBlank(),
            ),
            const SizedBox(height: AppSpace.s3),
            const SsSectionTitle('添加模块'),
            const SizedBox(height: AppSpace.s2),
            Expanded(
              child: ListView(
                children: <Widget>[
                  for (final PlanModuleType type in PlanModuleType.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.s1),
                      child: SsCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpaceFine.n10,
                          vertical: AppSpace.s2,
                        ),
                        onTap: state.modules.length >= 50
                            ? null
                            : () => controller.addModule(type),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                type.label,
                                style: const TextStyle(
                                  fontSize: AppFontSize.small,
                                ),
                              ),
                            ),
                            if (type.category == '绑定')
                              Text(
                                '绑',
                                style: TextStyle(
                                  fontSize: AppFontSize.micro,
                                  color: p.accent,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor(PlannerState state, PlannerController controller) {
    final id = _selectedModuleId;
    PlanModuleData? module;
    for (final PlanModuleData m in state.modules) {
      if (m.id == id) module = m;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            SsChip(
              label: '模块编辑',
              selected: _rightTab == 0,
              onTap: () => refresh(() => _rightTab = 0),
            ),
            const SizedBox(width: 6),
            SsChip(
              label: 'AI 助手',
              selected: _rightTab == 1,
              onTap: () => refresh(() => _rightTab = 1),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.s2),
        Expanded(
          child: _rightTab == 1
              ? AiSidePanel(
                  modules: state.modules,
                  targetModuleId: _aiTargetId,
                  onApply: (List<PlanModuleData> modules) async {
                    await controller.replaceModules(modules);
                    if (mounted) {
                      refresh(() => _aiTargetId = null);
                    }
                  },
                )
              : module == null
              ? const SsCard(
                  child: SsEmpty(
                    icon: Icons.edit_note_rounded,
                    art: SsArt.compass,
                    title: '未选中模块',
                    hint: '点击中间画布里的模块卡片进行编辑，或用卡片上的 ✨ 让 AI 改写',
                  ),
                )
              : _ModuleEditor(module: module, controller: controller),
        ),
      ],
    );
  }

  Future<void> _showTemplatePicker(PlannerController controller) async {
    final templates = await ContentPacks.templates();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('模板库（内置 8 套 · 覆盖 Cos/汉服/JK/婚纱/写真/商拍/Lo裙/双人）'),
        content: SizedBox(
          width: 640,
          height: 460,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 300,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.2,
            ),
            itemCount: templates.length,
            itemBuilder: (BuildContext context, int i) {
              final TemplateEntry t = templates[i];
              return SsCard(
                onTap: () async {
                  await controller.newFromTemplate(t);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      t.name,
                      style: const TextStyle(
                        fontSize: AppFontSize.smallLg,
                        fontWeight: AppFontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppFontSize.caption,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  Future<void> _showHistory(PlannerState state) async {
    await ref.read(plannerControllerProvider.notifier).saveNow();
    if (!mounted) return;
    final latest = ref.read(plannerControllerProvider);
    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(AppSpace.s3),
              child: Row(
                children: <Widget>[
                  const Text(
                    '版本历史（无限保留）',
                    style: TextStyle(fontWeight: AppFontWeight.bold),
                  ),
                  const Spacer(),
                  SsButton(
                    label: '创建里程碑',
                    kind: SsButtonKind.text,
                    dense: true,
                    onPressed: () async {
                      final label = await _askLabel(ctx);
                      if (label != null) {
                        await ref
                            .read(plannerControllerProvider.notifier)
                            .milestoneNow(label);
                        if (ctx.mounted) Navigator.pop(ctx);
                      }
                    },
                  ),
                ],
              ),
            ),
            if (latest.snapshots.isEmpty)
              const Padding(
                padding: EdgeInsets.all(AppSpaceFine.n20),
                child: Text('暂无快照'),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: latest.snapshots.length,
                  itemBuilder: (BuildContext context, int i) {
                    final AppPalette p = context.palette;

                    final PlanSnapshotInfo snap = latest.snapshots[i];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        snap.label != null
                            ? Icons.bookmark_rounded
                            : Icons.history_rounded,
                        size: 18,
                        color: snap.label != null ? p.gold : null,
                      ),
                      title: Text(
                        snap.label ?? '自动快照',
                        style: const TextStyle(fontSize: AppFontSize.smallLg),
                      ),
                      subtitle: Text(
                        '${snap.createdAt.toString().substring(0, 19)} · ${snap.moduleCount} 个模块',
                        style: const TextStyle(fontSize: AppFontSize.caption),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          IconButton(
                            tooltip: '对比当前',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(
                              Icons.compare_arrows_rounded,
                              size: 17,
                            ),
                            onPressed: () => _showDiff(ctx, snap.id),
                          ),
                          IconButton(
                            tooltip: '回滚到此版本',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.restore_rounded, size: 17),
                            onPressed: () async {
                              await ref
                                  .read(plannerControllerProvider.notifier)
                                  .restoreSnapshot(snap.id);
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDiff(BuildContext context, String snapshotId) async {
    final AppPalette p = context.palette;

    final controller = ref.read(plannerControllerProvider.notifier);
    final snapshots = ref.read(plannerControllerProvider).snapshots;
    PlanSnapshotInfo? snap;
    for (final PlanSnapshotInfo s in snapshots) {
      if (s.id == snapshotId) snap = s;
    }
    if (snap == null) return;
    final base = await controller.modulesOfSnapshot(snapshotId);
    if (!context.mounted) return;
    final current = ref.read(plannerControllerProvider).modules;
    final diff = diffPlans(base, current);
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('版本对比（历史 → 当前）'),
        content: SizedBox(
          width: 560,
          height: 420,
          child: diff.isEmpty
              ? const Center(child: Text('两版本内容一致'))
              : ListView(
                  children: <Widget>[
                    Text(
                      '新增 ${diff.added.length} · 删除 ${diff.removed.length} · '
                      '修改 ${diff.changed.length} · 未变 ${diff.unchanged}',
                      style: const TextStyle(fontSize: AppFontSize.small),
                    ),
                    const SizedBox(height: 8),
                    for (final PlanModuleData m in diff.added)
                      _diffLine(
                        Icons.add_circle_outline_rounded,
                        p.film,
                        '新增：${m.title}（${m.type.label}）',
                      ),
                    for (final PlanModuleData m in diff.removed)
                      _diffLine(
                        Icons.remove_circle_outline_rounded,
                        p.danger,
                        '删除：${m.title}（${m.type.label}）',
                      ),
                    for (final ModuleChange c in diff.changed)
                      _diffLine(
                        Icons.change_circle_outlined,
                        p.gold,
                        '修改：${c.after.title} · ${c.changedKeys.join('、')}',
                      ),
                  ],
                ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _diffLine(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s1),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: AppFontSize.small),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _askLabel(BuildContext context) async {
    final ctl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('里程碑命名'),
        content: TextField(
          controller: ctl,
          decoration: const InputDecoration(hintText: '如：客户确认版'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctl.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
