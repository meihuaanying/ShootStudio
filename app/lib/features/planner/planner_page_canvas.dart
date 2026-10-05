// V8/S8 · D158：策划案画布（左侧清单 + 中央模块流 + 右侧检查器）版面。
// 从 planner_page_layout.dart 拆出，使两个 part 文件都 ≤600 行（R73 行数门禁）。
part of 'planner_page.dart';

extension _PlannerPageCanvas on _PlannerPageState {
  Widget _buildCanvas(PlannerState state, PlannerController controller) {
    if (state.modules.isEmpty) {
      return SsCard(
        child: SsEmpty(
          icon: Icons.dashboard_customize_outlined,
          art: SsArt.film,
          title: '空策划案',
          hint: '从模板开始，或从左侧添加模块（14 种积木）',
          action: SsButton(
            label: '选择模板',
            icon: Icons.apps_rounded,
            onPressed: () => _showTemplatePicker(controller),
          ),
        ),
      );
    }
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: TextEditingController(text: state.title),
                decoration: const InputDecoration(
                  hintText: '策划案标题',
                  isDense: true,
                ),
                style: const TextStyle(
                  fontSize: AppFontSize.body,
                  fontWeight: AppFontWeight.bold,
                ),
                onChanged: controller.setTitle,
              ),
            ),
            const SizedBox(width: AppSpace.s2),
            for (final PlanDocStatus s in PlanDocStatus.values)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: SsChip(
                  label: s.label,
                  selected: state.status == s,
                  onTap: () => controller.setStatus(s),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            state.statusText.isEmpty
                ? '模块 ${state.moduleCount} 个'
                : state.statusText,
            style: appMono(context.palette.inkSoft, size: 11.5),
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: ReorderableListView.builder(
            itemCount: state.modules.length,
            onReorderItem: controller.reorder,
            itemBuilder: (BuildContext context, int index) {
              final AppPalette p = context.palette;

              final module = state.modules[index];
              final selected = _selectedModuleId == module.id;
              return Padding(
                key: ValueKey<String>(module.id),
                padding: const EdgeInsets.only(bottom: 6),
                child: SsCard(
                  selected: selected,
                  padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                  onTap: () => refresh(() => _selectedModuleId = module.id),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.drag_indicator_rounded, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '${index + 1}'.padLeft(2, '0'),
                        style: appMono(p.inkSoft),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              module.title.isEmpty
                                  ? module.type.label
                                  : module.title,
                              style: const TextStyle(
                                fontSize: AppFontSize.smallLg,
                                fontWeight: AppFontWeight.medium,
                              ),
                            ),
                            Text(
                              module.summary.isEmpty
                                  ? module.type.category
                                  : module.summary,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: AppFontSize.caption,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (_expandedIds.contains(module.id)) ...<Widget>[
                              const SizedBox(height: 6),
                              Container(
                                constraints: const BoxConstraints(
                                  maxHeight: 260,
                                ),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.chip,
                                  ),
                                ),
                                child: SingleChildScrollView(
                                  child: ModuleContentView(
                                    module: module,
                                    compact: true,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: _expandedIds.contains(module.id)
                            ? '收起全文'
                            : '展开全文',
                        icon: Icon(
                          _expandedIds.contains(module.id)
                              ? Icons.unfold_less_rounded
                              : Icons.unfold_more_rounded,
                          size: 16,
                        ),
                        onPressed: () => refresh(() {
                          if (!_expandedIds.remove(module.id)) {
                            _expandedIds.add(module.id);
                          }
                        }),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'AI 改写此模块',
                        icon: const Icon(Icons.auto_awesome_rounded, size: 15),
                        onPressed: () => refresh(() {
                          _selectedModuleId = module.id;
                          _aiTargetId = module.id;
                          _rightTab = 1;
                        }),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          module.folded ? Icons.expand_more : Icons.expand_less,
                          size: 17,
                        ),
                        onPressed: () => controller.toggleFold(module.id),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.copy_rounded, size: 15),
                        onPressed: () => controller.duplicateModule(module.id),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 16,
                        ),
                        onPressed: () => controller.removeModule(module.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
