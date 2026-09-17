import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/db/database.dart';
import '../ai/ai_panel.dart';
import '../ai/ai_side_panel.dart';
import '../export/export_panel.dart';
import '../export/exporter.dart';
import '../../core/design/widgets.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../services/content_packs.dart';
import '../../services/geocoding.dart';
import '../../services/image_store.dart';
import '../../services/palette_extractor.dart';
import '../../services/richtext_lite.dart';
import '../../services/solar_calculator.dart';
import '../lighting/lighting_controller.dart';
import '../poses/pose_skeleton.dart';
import '../refs/refs_controller.dart';
import '../shell/app_shell.dart';
import 'budget_estimator.dart';
import 'planner_controller.dart';
import 'planner_diff.dart';
import 'module_content_view.dart';
import 'planner_models.dart';
import 'planner_pending.dart';

/// 选项（资源/布光方案）：避免记录类型嵌套泛型的解析歧义。
class Option {
  const Option(this.id, this.name);
  final String id;
  final String name;
}

/// 已保存布光方案列表（供布光图模块绑定）。
final lightingScenesProvider =
    FutureProvider.autoDispose<List<Option>>((ref) async {
  final db = ref.watch(databaseProvider);
  final rows = await db.select(db.lightingScenes).get();
  return rows.map((r) => Option(r.id, r.name)).toList();
});

/// M5 积木式策划编辑器。
class PlannerPage extends ConsumerStatefulWidget {
  const PlannerPage({super.key});

  @override
  ConsumerState<PlannerPage> createState() => _PlannerPageState();
}

class _PlannerPageState extends ConsumerState<PlannerPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      ref.read(plannerControllerProvider.notifier).init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(plannerControllerProvider);
    final controller = ref.read(plannerControllerProvider.notifier);

    return SsPage(
      title: '策划案',
      subtitle: '积木式模块 · 模板库 · 编辑停顿 3 秒自动快照 · 定稿只是标签',
      actions: <Widget>[
        SsButton(
          label: 'AI 补全',
          icon: Icons.auto_awesome_rounded,
          dense: true,
          kind: SsButtonKind.soft,
          onPressed: () => showDialog<void>(
            context: context,
            builder: (BuildContext ctx) => AiPanel(
              onInsertAll: (List<PlanModuleData> modules) {
                controller.insertModules(modules);
              },
              onInsertModule: (PlanModuleData module) {
                controller.insertModule(module);
              },
            ),
          ),
        ),
        const SizedBox(width: 6),
        SsButton(
          label: '导入 .sspak',
          icon: Icons.file_open_outlined,
          kind: SsButtonKind.ghost,
          dense: true,
          onPressed: () async {
            final result = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: <String>['sspak'],
              dialogTitle: '选择 .sspak 数据包',
            );
            final path = result?.files.single.path;
            if (path == null || !context.mounted) return;
            try {
              final imported = await SspakImporter(
                workspace: ref.read(workspaceProvider),
                db: ref.read(databaseProvider),
              ).import(path);
              await controller.reloadLatest();
              if (context.mounted) {
                ssToast(context,
                    '已导入「${imported.title}」（${imported.moduleCount} 个模块）');
              }
            } catch (e) {
              if (context.mounted) ssToast(context, '导入失败：$e');
            }
          },
        ),
        const SizedBox(width: 6),
        SsButton(
          label: '导出',
          icon: Icons.ios_share_rounded,
          dense: true,
          onPressed: () async {
            await controller.saveNow();
            if (!context.mounted) return;
            final latest = ref.read(plannerControllerProvider);
            await showDialog<void>(
              context: context,
              builder: (BuildContext ctx) => ExportPanel(
                title: latest.title,
                status: latest.status,
                modules: latest.modules,
              ),
            );
          },
        ),
        const SizedBox(width: 6),
        SsButton(
          label: '历史版本',
          icon: Icons.history_rounded,
          kind: SsButtonKind.ghost,
          dense: true,
          onPressed: () => _showHistory(state),
        ),
        const SizedBox(width: 6),
        SsButton(
          label: '保存',
          icon: Icons.save_outlined,
          dense: true,
          onPressed: () async {
            await controller.saveNow();
            if (context.mounted) ssToast(context, '已保存并记录快照');
          },
        ),
      ],
      body: !state.loaded
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _buildLeftPanel(state, controller),
                const SizedBox(width: AppTokens.s12),
                Expanded(child: _buildCanvas(state, controller)),
                const SizedBox(width: AppTokens.s12),
                SizedBox(width: 348, child: _buildEditor(state, controller)),
              ],
            ),
    );
  }

  Widget _buildLeftPanel(PlannerState state, PlannerController controller) {
    return SizedBox(
      width: 196,
      child: SsCard(
        padding: const EdgeInsets.all(AppTokens.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SsSectionTitle('开始', subtitle: '从模板或空白'),
            const SizedBox(height: AppTokens.s8),
            SsButton(
              label: '模板库',
              icon: Icons.dashboard_customize_outlined,
              dense: true,
              onPressed: () => _showTemplatePicker(controller),
            ),
            const SizedBox(height: 6),
            SsButton(
              label: '空白策划案',
              kind: SsButtonKind.ghost,
              dense: true,
              onPressed: () => controller.newBlank(),
            ),
            const SizedBox(height: AppTokens.s12),
            const SsSectionTitle('添加模块'),
            const SizedBox(height: AppTokens.s8),
            Expanded(
              child: ListView(
                children: <Widget>[
                  for (final PlanModuleType type in PlanModuleType.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: SsCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        onTap: state.modules.length >= 50
                            ? null
                            : () => controller.addModule(type),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(type.label,
                                  style: const TextStyle(fontSize: 12.5)),
                            ),
                            if (type.category == '绑定')
                              const Text(
                                '绑',
                                style: TextStyle(
                                    fontSize: 9, color: AppTokens.accent),
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
                decoration:
                    const InputDecoration(hintText: '策划案标题', isDense: true),
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                onChanged: controller.setTitle,
              ),
            ),
            const SizedBox(width: AppTokens.s8),
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
            style: AppTokens.mono(
              context,
              size: 11.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: ReorderableListView.builder(
            itemCount: state.modules.length,
            onReorderItem: controller.reorder,
            itemBuilder: (BuildContext context, int index) {
              final module = state.modules[index];
              final selected = _selectedModuleId == module.id;
              return Padding(
                key: ValueKey<String>(module.id),
                padding: const EdgeInsets.only(bottom: 6),
                child: SsCard(
                  selected: selected,
                  padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                  onTap: () => setState(() => _selectedModuleId = module.id),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.drag_indicator_rounded, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '${index + 1}'.padLeft(2, '0'),
                        style: AppTokens.mono(context, size: 10.5),
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
                                  fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              module.summary.isEmpty
                                  ? module.type.category
                                  : module.summary,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                            if (_expandedIds.contains(module.id)) ...<Widget>[
                              const SizedBox(height: 6),
                              Container(
                                constraints:
                                    const BoxConstraints(maxHeight: 260),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  borderRadius:
                                      BorderRadius.circular(AppTokens.rSm),
                                ),
                                child: SingleChildScrollView(
                                  child: ModuleContentView(
                                      module: module, compact: true),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip:
                            _expandedIds.contains(module.id) ? '收起全文' : '展开全文',
                        icon: Icon(
                          _expandedIds.contains(module.id)
                              ? Icons.unfold_less_rounded
                              : Icons.unfold_more_rounded,
                          size: 16,
                        ),
                        onPressed: () => setState(() {
                          if (!_expandedIds.remove(module.id)) {
                            _expandedIds.add(module.id);
                          }
                        }),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'AI 改写此模块',
                        icon: const Icon(Icons.auto_awesome_rounded, size: 15),
                        onPressed: () => setState(() {
                          _selectedModuleId = module.id;
                          _aiTargetId = module.id;
                          _rightTab = 1;
                        }),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                            module.folded
                                ? Icons.expand_more
                                : Icons.expand_less,
                            size: 17),
                        onPressed: () => controller.toggleFold(module.id),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.copy_rounded, size: 15),
                        onPressed: () => controller.duplicateModule(module.id),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon:
                            const Icon(Icons.delete_outline_rounded, size: 16),
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

  String? _selectedModuleId;
  String? _aiTargetId;
  final Set<String> _expandedIds = <String>{};
  int _rightTab = 0; // 0 编辑 / 1 AI 助手

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
              onTap: () => setState(() => _rightTab = 0),
            ),
            const SizedBox(width: 6),
            SsChip(
              label: 'AI 助手',
              selected: _rightTab == 1,
              onTap: () => setState(() => _rightTab = 1),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.s8),
        Expanded(
          child: _rightTab == 1
              ? AiSidePanel(
                  modules: state.modules,
                  targetModuleId: _aiTargetId,
                  onApply: (List<PlanModuleData> modules) async {
                    await controller.replaceModules(modules);
                    if (mounted) {
                      setState(() => _aiTargetId = null);
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
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
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
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
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
              padding: const EdgeInsets.all(12),
              child: Row(
                children: <Widget>[
                  const Text('版本历史（无限保留）',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  SsButton(
                    label: '创建里程碑',
                    kind: SsButtonKind.ghost,
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
                padding: EdgeInsets.all(20),
                child: Text('暂无快照'),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: latest.snapshots.length,
                  itemBuilder: (BuildContext context, int i) {
                    final PlanSnapshotInfo snap = latest.snapshots[i];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        snap.label != null
                            ? Icons.bookmark_rounded
                            : Icons.history_rounded,
                        size: 18,
                        color: snap.label != null ? AppTokens.warning : null,
                      ),
                      title: Text(
                        snap.label ?? '自动快照',
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        '${snap.createdAt.toString().substring(0, 19)} · ${snap.moduleCount} 个模块',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          IconButton(
                            tooltip: '对比当前',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.compare_arrows_rounded,
                                size: 17),
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
                      style: const TextStyle(fontSize: 12.5),
                    ),
                    const SizedBox(height: 8),
                    for (final PlanModuleData m in diff.added)
                      _diffLine(Icons.add_circle_outline_rounded,
                          AppTokens.success, '新增：${m.title}（${m.type.label}）'),
                    for (final PlanModuleData m in diff.removed)
                      _diffLine(Icons.remove_circle_outline_rounded,
                          AppTokens.danger, '删除：${m.title}（${m.type.label}）'),
                    for (final ModuleChange c in diff.changed)
                      _diffLine(Icons.change_circle_outlined, AppTokens.warning,
                          '修改：${c.after.title} · ${c.changedKeys.join('、')}'),
                  ],
                ),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
        ],
      ),
    );
  }

  Widget _diffLine(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5))),
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
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctl.text),
              child: const Text('确定')),
        ],
      ),
    );
  }
}

/// 右侧模块编辑区。
class _ModuleEditor extends ConsumerWidget {
  const _ModuleEditor({required this.module, required this.controller});

  final PlanModuleData module;
  final PlannerController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SsCard(
      child: ListView(
        children: <Widget>[
          SsSectionTitle('编辑 · ${module.type.label}'),
          const SizedBox(height: AppTokens.s8),
          TextField(
            controller: TextEditingController(text: module.title),
            decoration: const InputDecoration(hintText: '模块标题', isDense: true),
            onChanged: (String v) => controller.updateModule(
                module.id, (PlanModuleData m) => m.title = v),
          ),
          const SizedBox(height: AppTokens.s12),
          ..._body(context, ref),
        ],
      ),
    );
  }

  List<Widget> _body(BuildContext context, WidgetRef ref) {
    switch (module.type) {
      case PlanModuleType.theme:
      case PlanModuleType.richText:
        return _richTextEditor(context, ref);
      case PlanModuleType.sun:
        return _sunEditor(context, ref);
      case PlanModuleType.refs:
        return _refsEditor(context, ref);
      case PlanModuleType.palette:
        return _paletteEditor(context, ref);
      case PlanModuleType.lighting:
        return _lightingEditor(context, ref);
      case PlanModuleType.poses:
        return _posesEditor(context, ref);
      case PlanModuleType.storyboard:
        return _storyboardEditor(context, ref);
      case PlanModuleType.crew:
        return _rowsEditor(context, <String>['role', 'who', 'time'],
            <String>['角色', '成员', '时间']);
      case PlanModuleType.budget:
        return _budgetEditor(context, ref);
      default:
        return _bindingEditor(context, ref);
    }
  }

  List<Widget> _sunEditor(BuildContext context, WidgetRef ref) {
    final place = module.data['place'] as String? ?? '';
    final date = module.data['date'] as String? ?? '';
    final lat = (module.data['lat'] as num?)?.toDouble() ?? 31.23;
    final lon = (module.data['lon'] as num?)?.toDouble() ?? 121.47;
    SolarDay? solar;
    final parts = date.split('-');
    if (date.isNotEmpty && parts.length == 3) {
      solar = SolarCalculator.compute(
        year: int.tryParse(parts[0]) ?? DateTime.now().year,
        month: int.tryParse(parts[1]) ?? 1,
        day: int.tryParse(parts[2]) ?? 1,
        latitude: lat,
        longitude: lon,
      );
    }
    return <Widget>[
      _CitySearchField(
        initial: place,
        onPick: (String name, double la, double lo) {
          controller.updateModule(module.id, (PlanModuleData m) {
            m.data['place'] = name;
            m.data['lat'] = la;
            m.data['lon'] = lo;
          });
        },
      ),
      const SizedBox(height: 6),
      Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: TextEditingController(text: lat.toStringAsFixed(4)),
              decoration: const InputDecoration(labelText: '纬度', isDense: true),
              onChanged: (String v) => controller.updateModule(
                  module.id,
                  (PlanModuleData m) =>
                      m.data['lat'] = double.tryParse(v) ?? m.data['lat']),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: TextEditingController(text: lon.toStringAsFixed(4)),
              decoration: const InputDecoration(labelText: '经度', isDense: true),
              onChanged: (String v) => controller.updateModule(
                  module.id,
                  (PlanModuleData m) =>
                      m.data['lon'] = double.tryParse(v) ?? m.data['lon']),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      TextField(
        controller: TextEditingController(text: date),
        decoration:
            const InputDecoration(hintText: '日期 yyyy-MM-dd', isDense: true),
        onChanged: (String v) => controller.updateModule(
            module.id, (PlanModuleData m) => m.data['date'] = v),
      ),
      const SizedBox(height: 10),
      if (solar != null)
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppTokens.rSm),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '日出 ${SolarCalculator.fmt(solar.sunrise)} · 日落 ${SolarCalculator.fmt(solar.sunset)}',
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              for (final SolarWindow? w in <SolarWindow?>[
                solar.goldenMorning,
                solar.goldenEvening,
                solar.blueMorning,
                solar.blueEvening,
              ])
                if (w != null)
                  Text(
                    '${w.label} ${SolarCalculator.fmt(w.startMin)} – ${SolarCalculator.fmt(w.endMin)}',
                    style: const TextStyle(
                        fontSize: 11.5, color: AppTokens.success),
                  ),
            ],
          ),
        )
      else
        const Text('输入日期后自动计算黄金时刻 / 蓝调时刻', style: TextStyle(fontSize: 11.5)),
    ];
  }

  List<Widget> _refsEditor(BuildContext context, WidgetRef ref) {
    final refs = (module.data['refs'] as List? ?? <Object?>[])
        .cast<Map<String, Object?>>();
    final pending = ref.watch(pendingFramesProvider);
    final workspace = ref.watch(workspaceProvider);

    Future<void> upload() async {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      final String? path = result?.files.single.path;
      if (path == null) return;
      final store = ImageStore(workspace.root.path);
      final (String fileName, PaletteResult palette) =
          await store.importFile(path, category: 'refs');
      controller.updateModule(module.id, (PlanModuleData m) {
        final list = <Object?>[...(m.data['refs'] as List? ?? <Object?>[])];
        list.add(<String, Object?>{
          'name': p.basenameWithoutExtension(path),
          'palette': palette.colors,
          'gradient': palette.colors.take(2).toList(),
          'sourceUrl': '',
          'imageRef': fileName,
        });
        m.data['refs'] = list;
      });
    }

    return <Widget>[
      Row(
        children: <Widget>[
          Text('已插入 ${refs.length} 张', style: const TextStyle(fontSize: 12.5)),
          const Spacer(),
          SsButton(
            label: '上传图片',
            dense: true,
            kind: SsButtonKind.ghost,
            onPressed: upload,
          ),
          const SizedBox(width: 6),
          SsButton(
            label: '插入待选（${pending.length}）',
            dense: true,
            kind: SsButtonKind.soft,
            onPressed: pending.isEmpty
                ? null
                : () {
                    controller.updateModule(module.id, (PlanModuleData m) {
                      final list = <Object?>[
                        ...(m.data['refs'] as List? ?? <Object?>[])
                      ];
                      for (final PendingFrame f in pending) {
                        list.add(<String, Object?>{
                          'name': f.name,
                          'palette': f.palette,
                          'gradient': f.gradient,
                          'sourceUrl': f.sourceUrl,
                          'imageRef': f.imagePath,
                        });
                      }
                      m.data['refs'] = list;
                    });
                  },
          ),
        ],
      ),
      const SizedBox(height: 6),
      for (var i = 0; i < refs.length; i++)
        Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: BorderRadius.circular(AppTokens.rSm),
          ),
          child: Row(
            children: <Widget>[
              _refThumb(context, workspace.root.path, refs[i]),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      refs[i]['name'] as String? ?? '',
                      style: const TextStyle(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (((refs[i]['imageRef'] as String?) ?? '').isNotEmpty)
                      const Text('真实图片 · 导出随附', style: TextStyle(fontSize: 10))
                    else if (((refs[i]['sourceUrl'] as String?) ?? '')
                        .isNotEmpty)
                      Text(
                        '出处保留 · 导出时附带',
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 14),
                onPressed: () =>
                    controller.updateModule(module.id, (PlanModuleData m) {
                  final list = <Object?>[
                    ...(m.data['refs'] as List? ?? <Object?>[])
                  ]..removeAt(i);
                  m.data['refs'] = list;
                }),
              ),
            ],
          ),
        ),
      if (refs.isEmpty && pending.isEmpty)
        const Text('可本地上传图片，或去「画面参考库」选静帧 →「插入策划案样片」',
            style: TextStyle(fontSize: 11.5)),
    ];
  }

  Widget _refThumb(
      BuildContext context, String workspaceRoot, Map<String, Object?> item) {
    final palette = (item['palette'] as List? ?? <Object?>[]).cast<String>();
    final imageRef = item['imageRef'] as String? ?? '';
    Widget fallback = Container(
      width: 42,
      height: 30,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            _hexColor(palette.isNotEmpty ? palette[0] : '#888888'),
            _hexColor(palette.length > 1 ? palette[1] : '#333333'),
          ],
        ),
        borderRadius: BorderRadius.circular(6),
      ),
    );
    if (imageRef.isEmpty) return fallback;
    final file = File(p.join(workspaceRoot, 'images', 'refs', imageRef));
    if (!file.existsSync()) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.file(file, width: 42, height: 30, fit: BoxFit.cover),
    );
  }

  Color _hexColor(String hex) => Color(0xFF000000 |
      (int.tryParse(hex.replaceFirst('#', ''), radix: 16) ?? 0x888888));

  List<Widget> _paletteEditor(BuildContext context, WidgetRef ref) {
    final colors =
        (module.data['colors'] as List? ?? <Object?>[]).cast<String>();

    void setColors(List<String> next) => controller.updateModule(
        module.id, (PlanModuleData m) => m.data['colors'] = next);

    return <Widget>[
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: <Widget>[
          for (var i = 0; i < colors.length; i++)
            Tooltip(
              message: '${colors[i]} · 点击复制',
              child: InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: colors[i]));
                  ssToast(context, '已复制 ${colors[i]}');
                },
                onLongPress: () {
                  final next = <String>[...colors]..removeAt(i);
                  setColors(next);
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Container(
                      width: 48,
                      height: 34,
                      decoration: BoxDecoration(
                        color: _hexColor(colors[i]),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: Theme.of(context).colorScheme.outline),
                      ),
                    ),
                    Positioned(
                      right: -4,
                      top: -4,
                      child: InkWell(
                        onTap: () {
                          final next = <String>[...colors]..removeAt(i);
                          setColors(next);
                        },
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xCC1F2329),
                          ),
                          child: const Icon(Icons.close_rounded,
                              size: 11, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: <Widget>[
          SsButton(
            label: '添加颜色',
            kind: SsButtonKind.ghost,
            dense: true,
            onPressed: () async {
              final String? hex = await showDialog<String>(
                context: context,
                builder: (_) => const _ColorPickerDialog(),
              );
              if (hex == null) return;
              setColors(<String>[...colors, hex]);
            },
          ),
          SsButton(
            label: '从图片提取',
            kind: SsButtonKind.ghost,
            dense: true,
            onPressed: () async {
              final result =
                  await FilePicker.platform.pickFiles(type: FileType.image);
              final String? path = result?.files.single.path;
              if (path == null) return;
              final bytes = await File(path).readAsBytes();
              final PaletteResult palette = PaletteExtractor.extract(bytes);
              setColors(palette.colors.take(5).toList());
              if (context.mounted) ssToast(context, '已提取 5 色');
            },
          ),
          SsButton(
            label: '从待插入样片取色',
            kind: SsButtonKind.ghost,
            dense: true,
            onPressed: () {
              final pending = ref.read(pendingFramesProvider);
              if (pending.isEmpty) {
                ssToast(context, '待插入样片为空：先去画面参考库收帧');
                return;
              }
              setColors(pending
                  .expand((PendingFrame f) => f.palette)
                  .take(5)
                  .toList());
            },
          ),
          SsButton(
            label: '取画板最近一帧',
            kind: SsButtonKind.ghost,
            dense: true,
            onPressed: () {
              final board = ref.read(refsControllerProvider).board;
              if (board.isEmpty) {
                ssToast(context, '画板为空');
                return;
              }
              setColors(board.first.palette);
            },
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text('长按色块或点右上角 × 删除；导出长图取前 5 色',
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          )),
    ];
  }

  List<Widget> _lightingEditor(BuildContext context, WidgetRef ref) {
    final scenes = ref.watch(lightingScenesProvider);
    final currentId = module.data['sceneId'] as String? ?? '';
    return <Widget>[
      scenes.when(
        data: (List<Option> list) => list.isEmpty
            ? Row(
                children: <Widget>[
                  const Expanded(
                    child: Text('还没有已保存的布光方案：去「布光预演」页保存一个',
                        style: TextStyle(fontSize: 11.5)),
                  ),
                  SsButton(
                    label: '刷新',
                    kind: SsButtonKind.ghost,
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
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              currentId == scene.id
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_off_rounded,
                              size: 16,
                              color: currentId == scene.id
                                  ? AppTokens.accent
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Text(scene.name,
                                style: const TextStyle(fontSize: 12.5)),
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
                          kind: SsButtonKind.ghost,
                          dense: true,
                          onPressed: () =>
                              ref.invalidate(lightingScenesProvider),
                        ),
                        if (currentId.isNotEmpty) ...<Widget>[
                          const SizedBox(width: 6),
                          SsButton(
                            label: '打开预演',
                            dense: true,
                            kind: SsButtonKind.soft,
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
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (Object e, _) =>
            Text('读取失败：$e', style: const TextStyle(fontSize: 12)),
      ),
      const SizedBox(height: 6),
      const Text('导出时渲染为：灯位图 + 位置清单 + 效果预览', style: TextStyle(fontSize: 11)),
    ];
  }

  List<Widget> _posesEditor(BuildContext context, WidgetRef ref) {
    final poses = (module.data['poses'] as List? ?? <Object?>[])
        .cast<Map<String, Object?>>();
    final pending = ref.watch(pendingPosesProvider);

    void setPoses(List<Object?> next) => controller.updateModule(
        module.id, (PlanModuleData m) => m.data['poses'] = next);

    return <Widget>[
      Row(
        children: <Widget>[
          Text('清单 ${poses.length} 个 · 拖拽排序',
              style: const TextStyle(fontSize: 12.5)),
          const Spacer(),
          SsButton(
            label: '插入待选（${pending.length}）',
            dense: true,
            kind: SsButtonKind.soft,
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
                fontSize: 11.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          SsChip(
            label: '照片',
            selected: (module.data['poseRenderMode'] as String? ?? 'photo') ==
                'photo',
            onTap: () => controller.updateModule(module.id,
                (PlanModuleData m) => m.data['poseRenderMode'] = 'photo'),
          ),
          SsChip(
            label: '骨架示意',
            selected: module.data['poseRenderMode'] == 'skeleton',
            onTap: () => controller.updateModule(module.id,
                (PlanModuleData m) => m.data['poseRenderMode'] = 'skeleton'),
          ),
          if (poses.any((Map<String, Object?> p) =>
              (p['photo'] as String? ?? '').isEmpty))
            Text('部分姿势无照片，导出回退骨架示意',
                style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
              title: Text(poses[i]['name'] as String? ?? '',
                  style: const TextStyle(fontSize: 12.5)),
              subtitle: Text(
                <String>[
                  if ((poses[i]['lens'] as String? ?? '').isNotEmpty)
                    poses[i]['lens'] as String,
                  if ((poses[i]['cameraPosition'] as String? ?? '').isNotEmpty)
                    poses[i]['cameraPosition'] as String,
                ].join(' · '),
                style: const TextStyle(fontSize: 11),
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
        const Text('去「动作摆姿库」收藏姿势 → 加入策划案', style: TextStyle(fontSize: 11.5)),
    ];
  }

  List<Widget> _storyboardEditor(BuildContext context, WidgetRef ref) {
    final List<Map<String, Object?>> shots =
        (module.data['shots'] as List? ?? <Object?>[])
            .cast<Map<String, Object?>>();

    void setShots(List<Object?> next) => controller.updateModule(
        module.id, (PlanModuleData m) => m.data['shots'] = next);

    void patch(int index, String key, Object? value) {
      final List<Object?> list = <Object?>[...shots];
      (list[index] as Map)[key] = value;
      setShots(list);
    }

    return <Widget>[
      Row(
        children: <Widget>[
          Text('共 ${shots.length} 镜 · 第一镜/末镜为重点',
              style: const TextStyle(fontSize: 12.5)),
          const Spacer(),
          SsButton(
            label: '添加镜头',
            dense: true,
            kind: SsButtonKind.ghost,
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
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(
                color: shots[i]['key'] == true
                    ? AppTokens.accent
                    : Theme.of(context).colorScheme.outline),
            borderRadius: BorderRadius.circular(AppTokens.rSm),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text('${i + 1}'.padLeft(2, '0'),
                      style: AppTokens.mono(context, size: 11)),
                  const SizedBox(width: 6),
                  DropdownButton<String>(
                    value: <String>['远景', '全身', '中景', '近景', '特写', '空镜']
                            .contains(shots[i]['shotSize'])
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
                            child:
                                Text(v, style: const TextStyle(fontSize: 12))),
                    ],
                    onChanged: (String? v) {
                      if (v != null) patch(i, 'shotSize', v);
                    },
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: TextEditingController(
                          text: shots[i]['lens'] as String? ?? ''),
                      decoration:
                          const InputDecoration(hintText: '焦段', isDense: true),
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
                      color: shots[i]['key'] == true ? AppTokens.warning : null,
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
                          text: shots[i]['camera'] as String? ?? ''),
                      decoration:
                          const InputDecoration(hintText: '机位', isDense: true),
                      onChanged: (String v) => patch(i, 'camera', v),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: TextEditingController(
                          text: shots[i]['pose'] as String? ?? ''),
                      decoration:
                          const InputDecoration(hintText: '姿势', isDense: true),
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
                          text: shots[i]['note'] as String? ?? ''),
                      decoration: const InputDecoration(
                          hintText: '备注（可选）', isDense: true),
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
                    icon:
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
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
        const Text('分镜为空：可让 AI 生成 8–12 镜，或手动添加',
            style: TextStyle(fontSize: 11.5)),
    ];
  }

  List<Widget> _budgetEditor(BuildContext context, WidgetRef ref) {
    final rows = (module.data['rows'] as List? ?? <Object?>[])
        .cast<Map<String, Object?>>();
    final double total = BudgetEstimator.total(rows);

    void setRows(List<Object?> next) => controller.updateModule(
        module.id, (PlanModuleData m) => m.data['rows'] = next);

    return <Widget>[
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppTokens.rSm),
        ),
        child: Row(
          children: <Widget>[
            const Text('自动合计', style: TextStyle(fontSize: 12)),
            const Spacer(),
            Text('¥${total.toStringAsFixed(0)}',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            SsButton(
              label: 'AI 估算',
              dense: true,
              kind: SsButtonKind.soft,
              onPressed: () async {
                final result = await showDialog<
                    ({
                      String city,
                      String tier,
                      double multiplier,
                      int people
                    })>(
                  context: context,
                  builder: (_) => const _BudgetEstimateDialog(),
                );
                if (result == null) return;
                final items = await ContentPacks.budgetRefs();
                final List<Map<String, Object?>> estimated =
                    BudgetEstimator.estimate(
                  items: items,
                  multiplier: result.multiplier,
                  tier: result.tier,
                  people: result.people,
                );
                setRows(estimated
                    .map((Map<String, Object?> r) => r as Object?)
                    .toList());
                if (context.mounted) {
                  ssToast(context,
                      '已按 ${result.city}（${result.tier}）估算 ${estimated.length} 项，可继续手动微调');
                }
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      for (var i = 0; i < rows.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: <Widget>[
              Expanded(
                flex: 2,
                child: TextField(
                  controller:
                      TextEditingController(text: '${rows[i]['item'] ?? ''}'),
                  decoration:
                      const InputDecoration(hintText: '项目', isDense: true),
                  onChanged: (String v) =>
                      controller.updateModule(module.id, (PlanModuleData m) {
                    final list = (m.data['rows'] as List? ?? <Object?>[]);
                    (list[i] as Map)['item'] = v;
                    m.data['rows'] = list;
                  }),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: TextField(
                  controller:
                      TextEditingController(text: '${rows[i]['price'] ?? 0}'),
                  decoration:
                      const InputDecoration(hintText: '金额', isDense: true),
                  onChanged: (String v) =>
                      controller.updateModule(module.id, (PlanModuleData m) {
                    final list = (m.data['rows'] as List? ?? <Object?>[]);
                    (list[i] as Map)['price'] = double.tryParse(v) ?? 0;
                    m.data['rows'] = list;
                  }),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                flex: 2,
                child: TextField(
                  controller:
                      TextEditingController(text: '${rows[i]['note'] ?? ''}'),
                  decoration:
                      const InputDecoration(hintText: '备注', isDense: true),
                  onChanged: (String v) =>
                      controller.updateModule(module.id, (PlanModuleData m) {
                    final list = (m.data['rows'] as List? ?? <Object?>[]);
                    (list[i] as Map)['note'] = v;
                    m.data['rows'] = list;
                  }),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 14),
                onPressed: () {
                  final list = <Object?>[...rows]..removeAt(i);
                  setRows(list);
                },
              ),
            ],
          ),
        ),
      SsButton(
        label: '添加一行',
        kind: SsButtonKind.ghost,
        dense: true,
        onPressed: () => setRows(<Object?>[
          ...rows,
          <String, Object?>{'item': '', 'price': 0, 'note': ''},
        ]),
      ),
    ];
  }

  List<Widget> _rowsEditor(
      BuildContext context, List<String> fields, List<String> labels) {
    final rows = (module.data['rows'] as List? ?? <Object?>[])
        .cast<Map<String, Object?>>();
    return <Widget>[
      for (var i = 0; i < rows.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: <Widget>[
              for (var f = 0; f < fields.length; f++) ...<Widget>[
                Expanded(
                  flex: f == 1 ? 1 : 2,
                  child: TextField(
                    controller: TextEditingController(
                        text: '${rows[i][fields[f]] ?? ''}'),
                    decoration:
                        InputDecoration(hintText: labels[f], isDense: true),
                    onChanged: (String v) =>
                        controller.updateModule(module.id, (PlanModuleData m) {
                      final list = (m.data['rows'] as List? ?? <Object?>[]);
                      (list[i] as Map)[fields[f]] =
                          fields[f] == 'price' ? (double.tryParse(v) ?? 0) : v;
                      m.data['rows'] = list;
                    }),
                  ),
                ),
                if (f != fields.length - 1) const SizedBox(width: 4),
              ],
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 14),
                onPressed: () =>
                    controller.updateModule(module.id, (PlanModuleData m) {
                  final list = <Object?>[
                    ...(m.data['rows'] as List? ?? <Object?>[])
                  ]..removeAt(i);
                  m.data['rows'] = list;
                }),
              ),
            ],
          ),
        ),
      SsButton(
        label: '添加一行',
        kind: SsButtonKind.ghost,
        dense: true,
        onPressed: () => controller.updateModule(module.id, (PlanModuleData m) {
          final list = <Object?>[...(m.data['rows'] as List? ?? <Object?>[])];
          list.add(<String, Object?>{
            for (final String f in fields) f: f == 'price' ? 0 : ''
          });
          m.data['rows'] = list;
        }),
      ),
    ];
  }

  List<Widget> _richTextEditor(BuildContext context, WidgetRef ref) {
    return <Widget>[
      _RichTextInput(
        key: ValueKey<String>('rich-${module.id}'),
        initial: module.data['text'] as String? ?? '',
        hint: module.type == PlanModuleType.theme
            ? '拍摄主题、氛围与表达目标…（支持 **加粗** 与 - 列表）'
            : '自由文本…（支持 **加粗** 与 - 列表）',
        onChanged: (String v) => controller.updateModule(
            module.id, (PlanModuleData m) => m.data['text'] = v),
      ),
      const SizedBox(height: 4),
      Text('导出长图 / PDF 将同步渲染格式',
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          )),
    ];
  }

  Future<List<Option>> _resourcesOf(WidgetRef ref, String kind) async {
    final db = ref.watch(databaseProvider);
    final rows = await (db.select(db.resources)
          ..where((t) => t.type.equals(kind)))
        .get();
    return rows.map((Resource r) => Option(r.id, r.name)).toList();
  }

  List<Widget> _bindingEditor(BuildContext context, WidgetRef ref) {
    final kind = module.type.resourceKind;
    if (kind == null) return <Widget>[];
    final ids = (module.data['ids'] as List? ?? <Object?>[]).cast<String>();
    return <Widget>[
      FutureBuilder<List<Option>>(
        future: _resourcesOf(ref, kind),
        builder: (BuildContext context, AsyncSnapshot<List<Option>> snap) {
          final list = snap.data ?? <Option>[];
          if (list.isEmpty) {
            return Text(
              '${module.type.label}：资源库还没有条目（去「资源库」新建）',
              style: const TextStyle(fontSize: 11.5),
            );
          }
          return Column(
            children: <Widget>[
              for (final Option item in list)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: ids.contains(item.id),
                  title:
                      Text(item.name, style: const TextStyle(fontSize: 12.5)),
                  onChanged: (bool? v) =>
                      controller.updateModule(module.id, (PlanModuleData m) {
                    final list2 = <String>[
                      ...(m.data['ids'] as List? ?? <Object?>[]).cast<String>()
                    ];
                    if (v == true) {
                      list2.add(item.id);
                    } else {
                      list2.remove(item.id);
                    }
                    m.data['ids'] = list2;
                    m.data['placeholder'] = list2.isEmpty;
                  }),
                ),
              TextField(
                controller: TextEditingController(
                    text: module.data['note'] as String? ?? ''),
                decoration:
                    const InputDecoration(hintText: '补充说明（可空）', isDense: true),
                onChanged: (String v) => controller.updateModule(
                    module.id, (PlanModuleData m) => m.data['note'] = v),
              ),
            ],
          );
        },
      ),
    ];
  }
}

/// 富文本输入（F4）：加粗 / 无序列表轻量标记。
class _RichTextInput extends StatefulWidget {
  const _RichTextInput({
    super.key,
    required this.initial,
    required this.onChanged,
    required this.hint,
  });

  final String initial;
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  State<_RichTextInput> createState() => _RichTextInputState();
}

class _RichTextInputState extends State<_RichTextInput> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _apply(({String text, int selection}) result) {
    _controller.value = TextEditingValue(
      text: result.text,
      selection: TextSelection.collapsed(offset: result.selection),
    );
    widget.onChanged(result.text);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final TextSelection selection = _controller.selection;
    final int start = selection.isValid ? selection.start : 0;
    final int end = selection.isValid ? selection.end : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: '加粗',
              icon: const Icon(Icons.format_bold_rounded, size: 18),
              onPressed: () =>
                  _apply(RichTextLite.toggleBold(_controller.text, start, end)),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: '无序列表',
              icon: const Icon(Icons.format_list_bulleted_rounded, size: 18),
              onPressed: () => _apply(
                  RichTextLite.toggleBullet(_controller.text, start, end)),
            ),
          ],
        ),
        TextField(
          controller: _controller,
          focusNode: _focus,
          maxLines: 8,
          decoration: InputDecoration(hintText: widget.hint),
          onChanged: widget.onChanged,
        ),
      ],
    );
  }
}

/// 城市搜索（F10）：内置 73 城即时过滤 + Nominatim 在线兜底。
class _CitySearchField extends StatefulWidget {
  const _CitySearchField({required this.initial, required this.onPick});

  final String initial;
  final void Function(String name, double lat, double lon) onPick;

  @override
  State<_CitySearchField> createState() => _CitySearchFieldState();
}

class _CitySearchFieldState extends State<_CitySearchField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);
  List<CityEntry> _all = <CityEntry>[];
  List<CityEntry> _matches = <CityEntry>[];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    ContentPacks.cities().then((List<CityEntry> cities) {
      if (mounted) setState(() => _all = cities);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _filter(String query) {
    final String q = query.trim();
    setState(() {
      _matches = q.isEmpty
          ? <CityEntry>[]
          : _all.where((CityEntry c) => c.name.contains(q)).take(6).toList();
    });
  }

  Future<void> _onlineSearch() async {
    setState(() => _searching = true);
    final ({String name, double lat, double lon})? result =
        await GeocodingService().search(_controller.text);
    if (!mounted) return;
    setState(() => _searching = false);
    if (result == null) {
      ssToast(context, '在线搜索无结果或断网：可手输经纬度，或从内置城市选择');
      return;
    }
    _controller.text = result.name;
    widget.onPick(result.name, result.lat, result.lon);
    ssToast(context, '已定位：${result.name}');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: '城市（内置城市库，输入即筛选）',
                  isDense: true,
                ),
                onChanged: _filter,
              ),
            ),
            const SizedBox(width: 6),
            SsButton(
              label: _searching ? '搜索中…' : '在线搜索',
              kind: SsButtonKind.ghost,
              dense: true,
              onPressed: _searching ? null : _onlineSearch,
            ),
          ],
        ),
        for (final CityEntry city in _matches)
          Material(
            type: MaterialType.transparency,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('${city.name} · ${city.tier}',
                  style: const TextStyle(fontSize: 12.5)),
              onTap: () {
                _controller.text = city.name;
                setState(() => _matches = <CityEntry>[]);
                widget.onPick(city.name, city.lat, city.lon);
              },
            ),
          ),
      ],
    );
  }
}

/// HSV 取色器（F4）。
class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog();

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  double _h = 210, _s = 0.7, _v = 0.8;
  late final TextEditingController _hex =
      TextEditingController(text: _hexOf(HSVColor.fromAHSV(1, _h, _s, _v)));

  static String _hexOf(HSVColor c) {
    final int v = c.toColor().toARGB32() & 0xFFFFFF;
    return '#${v.toRadixString(16).padLeft(6, '0')}';
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _syncHex() {
    _hex.text = _hexOf(HSVColor.fromAHSV(1, _h, _s, _v));
  }

  @override
  Widget build(BuildContext context) {
    final Color preview = HSVColor.fromAHSV(1, _h, _s, _v).toColor();
    return AlertDialog(
      title: const Text('添加颜色', style: TextStyle(fontSize: 16)),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: preview,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 8),
            _slider('色相', _h, 360, (double v) {
              setState(() {
                _h = v;
                _syncHex();
              });
            }),
            _slider('饱和', _s, 1, (double v) {
              setState(() {
                _s = v;
                _syncHex();
              });
            }),
            _slider('明度', _v, 1, (double v) {
              setState(() {
                _v = v;
                _syncHex();
              });
            }),
            TextField(
              controller: _hex,
              decoration:
                  const InputDecoration(labelText: '色值 #RRGGBB', isDense: true),
              onChanged: (String v) {
                final int? parsed =
                    int.tryParse(v.replaceFirst('#', ''), radix: 16);
                if (parsed == null || v.replaceFirst('#', '').length != 6) {
                  return;
                }
                final HSVColor hsv =
                    HSVColor.fromColor(Color(0xFF000000 | parsed));
                setState(() {
                  _h = hsv.hue;
                  _s = hsv.saturation;
                  _v = hsv.value;
                });
              },
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        SsButton(
          label: '添加',
          onPressed: () =>
              Navigator.pop(context, _hexOf(HSVColor.fromAHSV(1, _h, _s, _v))),
        ),
      ],
    );
  }

  Widget _slider(
      String label, double value, double max, ValueChanged<double> onChanged) {
    return Row(
      children: <Widget>[
        SizedBox(
            width: 32,
            child: Text(label, style: const TextStyle(fontSize: 12))),
        Expanded(
          child: Slider(
            value: value,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _PoseInfoDialog extends StatelessWidget {
  const _PoseInfoDialog({required this.pose});

  final Map<String, Object?> pose;

  @override
  Widget build(BuildContext context) {
    final String lens = pose['lens'] as String? ?? '';
    final String camera = pose['cameraPosition'] as String? ?? '';
    final String photo = pose['photo'] as String? ?? '';
    final String skeleton = pose['skeleton'] as String? ?? '';
    final String author = pose['author'] as String? ?? '';
    final String license = pose['license'] as String? ?? '';
    final int jointCount =
        (pose['joints'] as Map? ?? <String, Object?>{}).length;
    final String attribution = <String>[
      if (author.isNotEmpty) author,
      if (license.isNotEmpty) license,
    ].join(' · ');
    return AlertDialog(
      title: Text(pose['name'] as String? ?? '姿势',
          style: const TextStyle(fontSize: 16)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (photo.isNotEmpty) ...<Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 220,
                  height: 280,
                  child: PosePhotoView(
                    photo: photo,
                    skeleton: skeleton,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (lens.isNotEmpty)
              Text('镜头建议：$lens', style: const TextStyle(fontSize: 13)),
            if (camera.isNotEmpty)
              Text('机位建议：$camera', style: const TextStyle(fontSize: 13)),
            if (jointCount > 0)
              Text('关节数：$jointCount（导出可选「照片 / 骨架示意」）',
                  style: const TextStyle(fontSize: 12)),
            if (attribution.isNotEmpty)
              Text('照片：$attribution',
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF8A919E))),
            const SizedBox(height: 4),
            if (photo.isEmpty)
              const Text('在「动作摆姿库」可查看照片、骨架与动作要领。',
                  style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

/// 从内置姿势库替换（F4）。
class _PoseReplaceDialog extends StatefulWidget {
  const _PoseReplaceDialog();

  @override
  State<_PoseReplaceDialog> createState() => _PoseReplaceDialogState();
}

class _PoseReplaceDialogState extends State<_PoseReplaceDialog> {
  List<PoseEntry> _all = <PoseEntry>[];
  String _query = '';

  @override
  void initState() {
    super.initState();
    ContentPacks.poses().then((List<PoseEntry> poses) {
      if (mounted) setState(() => _all = poses);
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<PoseEntry> matches = _query.trim().isEmpty
        ? _all.take(30).toList()
        : _all
            .where((PoseEntry p) => p.name.contains(_query.trim()))
            .take(30)
            .toList();
    return AlertDialog(
      title: const Text('替换姿势', style: TextStyle(fontSize: 16)),
      content: SizedBox(
        width: 360,
        height: 380,
        child: Column(
          children: <Widget>[
            TextField(
              decoration: const InputDecoration(
                  hintText: '搜索姿势名，例如：回眸 / 蹲', isDense: true),
              onChanged: (String v) => setState(() => _query = v),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: ListView.builder(
                itemCount: matches.length,
                itemBuilder: (BuildContext context, int i) {
                  final PoseEntry pose = matches[i];
                  return ListTile(
                    dense: true,
                    title:
                        Text(pose.name, style: const TextStyle(fontSize: 12.5)),
                    subtitle: Text(
                      <String>[pose.lens, pose.cameraPosition]
                          .where((String s) => s.isNotEmpty)
                          .join(' · '),
                      style: const TextStyle(fontSize: 11),
                    ),
                    onTap: () => Navigator.pop(context, <String, Object?>{
                      'name': pose.name,
                      'joints': pose.joints,
                      'lens': pose.lens,
                      'cameraPosition': pose.cameraPosition,
                      'photo': pose.photo,
                      'author': pose.author,
                      'license': pose.license,
                      'source': pose.source,
                    }),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ],
    );
  }
}

/// 预算估算参数（F9）：城市档位系数 + 人数。
class _BudgetEstimateDialog extends StatefulWidget {
  const _BudgetEstimateDialog();

  @override
  State<_BudgetEstimateDialog> createState() => _BudgetEstimateDialogState();
}

class _BudgetEstimateDialogState extends State<_BudgetEstimateDialog> {
  List<CityEntry> _cities = <CityEntry>[];
  Map<String, double> _multipliers = <String, double>{};
  CityEntry? _city;
  final TextEditingController _people = TextEditingController(text: '4');

  @override
  void initState() {
    super.initState();
    ContentPacks.cities().then((List<CityEntry> cities) {
      if (!mounted) return;
      setState(() {
        _cities = cities;
        _city = cities.firstWhere(
          (CityEntry c) => c.name == '上海',
          orElse: () => cities.first,
        );
      });
    });
    ContentPacks.cityMultipliers().then((Map<String, double> m) {
      if (mounted) setState(() => _multipliers = m);
    });
  }

  @override
  void dispose() {
    _people.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('AI 预算估算', style: TextStyle(fontSize: 16)),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('按内置价格区间 × 城市档位系数生成，结果标注「估算值」，可手动微调。',
                style: TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            DropdownButtonFormField<CityEntry>(
              initialValue: _city,
              decoration: const InputDecoration(labelText: '城市', isDense: true),
              items: <DropdownMenuItem<CityEntry>>[
                for (final CityEntry c in _cities)
                  DropdownMenuItem<CityEntry>(
                      value: c, child: Text('${c.name} · ${c.tier}')),
              ],
              onChanged: (CityEntry? v) => setState(() => _city = v),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _people,
              decoration: const InputDecoration(
                  labelText: '人数（餐饮按人数估算）', isDense: true),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        SsButton(
          label: '生成估算',
          onPressed: _city == null
              ? null
              : () {
                  final String tier = _city!.tier;
                  Navigator.pop(
                    context,
                    (
                      city: _city!.name,
                      tier: tier,
                      multiplier: _multipliers[tier] ?? 1.0,
                      people: int.tryParse(_people.text) ?? 1,
                    ),
                  );
                },
        ),
      ],
    );
  }
}
