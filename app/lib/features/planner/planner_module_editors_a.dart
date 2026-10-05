// V8/S8 · D158：布光 / 姿势 / 分镜三组面板。
part of 'planner_page.dart';

extension _ModuleEditorPanelsA on _ModuleEditor {
  List<Widget> _lightingEditor(BuildContext context, WidgetRef ref) {
    final AppPalette p = context.palette;

    final scenes = ref.watch(lightingScenesProvider);
    final currentId = module.data['sceneId'] as String? ?? '';
    return <Widget>[
      scenes.when(
        data: (List<Option> list) => list.isEmpty
            ? Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      '还没有已保存的布光方案：去「布光预演」页保存一个',
                      style: TextStyle(fontSize: AppFontSize.captionLg),
                    ),
                  ),
                  SsButton(
                    label: '刷新',
                    kind: SsButtonKind.text,
                    dense: true,
                    onPressed: () => ref.invalidate(lightingScenesProvider),
                  ),
                ],
              )
            : Column(
                children: <Widget>[
                  for (final Option scene in list)
                    InkWell(
                      onTap: () {
                        controller.updateModule(module.id, (PlanModuleData m) {
                          m.data['sceneId'] = scene.id;
                          m.data['sceneName'] = scene.name;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpaceFine.n6,
                        ),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              currentId == scene.id
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_off_rounded,
                              size: 16,
                              color: currentId == scene.id ? p.accent : null,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              scene.name,
                              style: const TextStyle(
                                fontSize: AppFontSize.small,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: <Widget>[
                        SsButton(
                          label: '刷新方案列表',
                          kind: SsButtonKind.text,
                          dense: true,
                          onPressed: () =>
                              ref.invalidate(lightingScenesProvider),
                        ),
                        if (currentId.isNotEmpty) ...<Widget>[
                          const SizedBox(width: 6),
                          SsButton(
                            label: '打开预演',
                            dense: true,
                            kind: SsButtonKind.outline,
                            onPressed: () async {
                              await ref
                                  .read(lightingControllerProvider.notifier)
                                  .openScene(currentId);
                              ref.read(shellTabProvider.notifier).state = 2;
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
        loading: () => const Center(
          child: CircularProgressIndicator(strokeWidth: AppStroke.ringThin),
        ),
        error: (Object e, _) => Text(
          '读取失败：$e',
          style: const TextStyle(fontSize: AppFontSize.smallSm),
        ),
      ),
      const SizedBox(height: 6),
      const Text(
        '导出时渲染为：灯位图 + 位置清单 + 效果预览',
        style: TextStyle(fontSize: AppFontSize.caption),
      ),
    ];
  }

  List<Widget> _posesEditor(BuildContext context, WidgetRef ref) {
    final poses = (module.data['poses'] as List? ?? <Object?>[])
        .cast<Map<String, Object?>>();
    final pending = ref.watch(pendingPosesProvider);

    void setPoses(List<Object?> next) => controller.updateModule(
      module.id,
      (PlanModuleData m) => m.data['poses'] = next,
    );

    return <Widget>[
      Row(
        children: <Widget>[
          Text(
            '清单 ${poses.length} 个 · 拖拽排序',
            style: const TextStyle(fontSize: AppFontSize.small),
          ),
          const Spacer(),
          SsButton(
            label: '插入待选（${pending.length}）',
            dense: true,
            kind: SsButtonKind.outline,
            onPressed: pending.isEmpty
                ? null
                : () => setPoses(<Object?>[
                    ...poses,
                    for (final PendingPose pose in pending)
                      pose.toModuleEntry(),
                  ]),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Text(
            '导出渲染',
            style: TextStyle(
              fontSize: AppFontSize.captionLg,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          SsChip(
            label: '照片',
            selected:
                (module.data['poseRenderMode'] as String? ?? 'photo') ==
                'photo',
            onTap: () => controller.updateModule(
              module.id,
              (PlanModuleData m) => m.data['poseRenderMode'] = 'photo',
            ),
          ),
          SsChip(
            label: '骨架示意',
            selected: module.data['poseRenderMode'] == 'skeleton',
            onTap: () => controller.updateModule(
              module.id,
              (PlanModuleData m) => m.data['poseRenderMode'] = 'skeleton',
            ),
          ),
          if (poses.any(
            (Map<String, Object?> row) =>
                (row['photo'] as String? ?? '').isEmpty,
          ))
            Text(
              '部分姿势无照片，导出回退骨架示意',
              style: TextStyle(
                fontSize: AppFontSize.tiny,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      const SizedBox(height: 6),
      if (poses.isNotEmpty)
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: poses.length,
          onReorderItem: (int from, int to) {
            final list = <Object?>[...poses];
            final Object? item = list.removeAt(from);
            list.insert(to, item);
            setPoses(list);
          },
          itemBuilder: (BuildContext context, int i) => Material(
            key: ValueKey<String>('pose-${poses[i]['name']}-$i'),
            type: MaterialType.transparency,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: ReorderableDragStartListener(
                index: i,
                child: const Icon(Icons.drag_indicator_rounded, size: 16),
              ),
              title: Text(
                poses[i]['name'] as String? ?? '',
                style: const TextStyle(fontSize: AppFontSize.small),
              ),
              subtitle: Text(
                <String>[
                  if ((poses[i]['lens'] as String? ?? '').isNotEmpty)
                    poses[i]['lens'] as String,
                  if ((poses[i]['cameraPosition'] as String? ?? '').isNotEmpty)
                    poses[i]['cameraPosition'] as String,
                ].join(' · '),
                style: const TextStyle(fontSize: AppFontSize.caption),
              ),
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => _PoseInfoDialog(pose: poses[i]),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: '替换姿势',
                    icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                    onPressed: () async {
                      final Map<String, Object?>? picked =
                          await showDialog<Map<String, Object?>>(
                            context: context,
                            builder: (_) => const _PoseReplaceDialog(),
                          );
                      if (picked == null) return;
                      final list = <Object?>[...poses];
                      list[i] = <String, Object?>{
                        'name': picked['name'],
                        'joints': picked['joints'],
                        'lens': picked['lens'],
                        'cameraPosition': picked['cameraPosition'],
                        'photo': picked['photo'] ?? '',
                        'author': picked['author'] ?? '',
                        'license': picked['license'] ?? '',
                        'source': picked['source'] ?? '',
                      };
                      setPoses(list);
                    },
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close_rounded, size: 14),
                    onPressed: () {
                      final list = <Object?>[...poses]..removeAt(i);
                      setPoses(list);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      if (poses.isEmpty && pending.isEmpty)
        const Text(
          '去「动作摆姿库」收藏姿势 → 加入策划案',
          style: TextStyle(fontSize: AppFontSize.captionLg),
        ),
    ];
  }

  List<Widget> _storyboardEditor(BuildContext context, WidgetRef ref) {
    final AppPalette p = context.palette;

    final List<Map<String, Object?>> shots =
        (module.data['shots'] as List? ?? <Object?>[])
            .cast<Map<String, Object?>>();

    void setShots(List<Object?> next) => controller.updateModule(
      module.id,
      (PlanModuleData m) => m.data['shots'] = next,
    );

    void patch(int index, String key, Object? value) {
      final List<Object?> list = <Object?>[...shots];
      (list[index] as Map)[key] = value;
      setShots(list);
    }

    return <Widget>[
      Row(
        children: <Widget>[
          Text(
            '共 ${shots.length} 镜 · 第一镜/末镜为重点',
            style: const TextStyle(fontSize: AppFontSize.small),
          ),
          const Spacer(),
          SsButton(
            label: '添加镜头',
            dense: true,
            kind: SsButtonKind.text,
            onPressed: () => setShots(<Object?>[
              ...shots,
              <String, Object?>{
                'no': shots.length + 1,
                'shotSize': '全身',
                'camera': '腰位',
                'lens': '35mm',
                'pose': '',
                'lighting': '',
                'key': false,
                'note': '',
              },
            ]),
          ),
        ],
      ),
      const SizedBox(height: 6),
      for (var i = 0; i < shots.length; i++) ...<Widget>[
        Container(
          margin: const EdgeInsets.only(bottom: AppSpaceFine.n6),
          padding: const EdgeInsets.all(AppSpace.s2),
          decoration: BoxDecoration(
            border: Border.all(
              color: shots[i]['key'] == true
                  ? p.accent
                  : Theme.of(context).colorScheme.outline,
            ),
            borderRadius: BorderRadius.circular(AppRadius.chip),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text('${i + 1}'.padLeft(2, '0'), style: appMono(p.inkSoft)),
                  const SizedBox(width: 6),
                  DropdownButton<String>(
                    value:
                        <String>[
                          '远景',
                          '全身',
                          '中景',
                          '近景',
                          '特写',
                          '空镜',
                        ].contains(shots[i]['shotSize'])
                        ? shots[i]['shotSize'] as String
                        : '全身',
                    isDense: true,
                    underline: const SizedBox.shrink(),
                    items: <DropdownMenuItem<String>>[
                      for (final String v in <String>[
                        '远景',
                        '全身',
                        '中景',
                        '近景',
                        '特写',
                        '空镜',
                      ])
                        DropdownMenuItem<String>(
                          value: v,
                          child: Text(
                            v,
                            style: const TextStyle(
                              fontSize: AppFontSize.smallSm,
                            ),
                          ),
                        ),
                    ],
                    onChanged: (String? v) {
                      if (v != null) patch(i, 'shotSize', v);
                    },
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: TextEditingController(
                        text: shots[i]['lens'] as String? ?? '',
                      ),
                      decoration: const InputDecoration(
                        hintText: '焦段',
                        isDense: true,
                      ),
                      onChanged: (String v) => patch(i, 'lens', v),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: '标为重点镜',
                    icon: Icon(
                      shots[i]['key'] == true
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: 16,
                      color: shots[i]['key'] == true ? p.gold : null,
                    ),
                    onPressed: () => patch(i, 'key', shots[i]['key'] != true),
                  ),
                ],
              ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: TextEditingController(
                        text: shots[i]['camera'] as String? ?? '',
                      ),
                      decoration: const InputDecoration(
                        hintText: '机位',
                        isDense: true,
                      ),
                      onChanged: (String v) => patch(i, 'camera', v),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: TextEditingController(
                        text: shots[i]['pose'] as String? ?? '',
                      ),
                      decoration: const InputDecoration(
                        hintText: '姿势',
                        isDense: true,
                      ),
                      onChanged: (String v) => patch(i, 'pose', v),
                    ),
                  ),
                ],
              ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: TextEditingController(
                        text: shots[i]['note'] as String? ?? '',
                      ),
                      decoration: const InputDecoration(
                        hintText: '备注（可选）',
                        isDense: true,
                      ),
                      onChanged: (String v) => patch(i, 'note', v),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 16),
                    onPressed: i == 0
                        ? null
                        : () {
                            final List<Object?> list = <Object?>[...shots];
                            final Object? item = list.removeAt(i);
                            list.insert(i - 1, item);
                            setShots(list);
                          },
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                    ),
                    onPressed: i == shots.length - 1
                        ? null
                        : () {
                            final List<Object?> list = <Object?>[...shots];
                            final Object? item = list.removeAt(i);
                            list.insert(i + 1, item);
                            setShots(list);
                          },
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close_rounded, size: 14),
                    onPressed: () {
                      final List<Object?> list = <Object?>[...shots]
                        ..removeAt(i);
                      setShots(list);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
      if (shots.isEmpty)
        const Text(
          '分镜为空：可让 AI 生成 8–12 镜，或手动添加',
          style: TextStyle(fontSize: AppFontSize.captionLg),
        ),
    ];
  }
}
