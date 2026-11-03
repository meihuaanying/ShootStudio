import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/design/widgets.dart';
import '../planner/module_content_view.dart';
import '../planner/planner_models.dart';
import '../poses/pose_skeleton.dart';
import 'field_controller.dart';
import 'field_exposure_brief.dart';

class FieldPage extends ConsumerStatefulWidget {
  const FieldPage({super.key});

  @override
  ConsumerState<FieldPage> createState() => _FieldPageState();
}

class _FieldPageState extends ConsumerState<FieldPage> {
  final TextEditingController _notes = TextEditingController();
  final TextEditingController _newTask = TextEditingController();
  String _notesPlanId = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted) ref.read(fieldControllerProvider.notifier).init();
    });
  }

  @override
  void dispose() {
    _notes.dispose();
    _newTask.dispose();
    super.dispose();
  }

  Future<void> _addTask() async {
    final String title = _newTask.text;
    await ref.read(fieldControllerProvider.notifier).addTask(title);
    if (mounted) _newTask.clear();
  }

  @override
  Widget build(BuildContext context) {
    final FieldState state = ref.watch(fieldControllerProvider);
    final FieldController controller = ref.read(
      fieldControllerProvider.notifier,
    );
    if (_notesPlanId != state.selectedPlanId) {
      _notesPlanId = state.selectedPlanId;
      _notes.value = TextEditingValue(
        text: state.notes,
        selection: TextSelection.collapsed(offset: state.notes.length),
      );
    }
    return SsPage(
      title: '拍摄现场',
      subtitle: '离线查看策划 · 清单和备注保存在当前项目',
      body: !state.loaded
          ? const Center(child: CircularProgressIndicator())
          : state.selectedPlan == null
          ? const SsEmpty(
              icon: Icons.checklist_rounded,
              title: '当前项目还没有策划案',
              hint: '请先在开案或策划案中准备好本次拍摄内容。',
            )
          : ListView(
              children: <Widget>[
                _planSelector(context, state, controller),
                const SizedBox(height: AppSpace.s3),
                _checklist(context, state, controller),
                const SizedBox(height: AppSpace.s3),
                _notesCard(context, state, controller),
                const SizedBox(height: AppSpace.s5),
                SsSectionTitle(
                  '策划案内容',
                  subtitle: '${state.modules.length} 个模块 · 点击展开核对',
                ),
                const SizedBox(height: AppSpace.s2),
                for (final PlanModuleData module in state.modules)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.s2),
                    child: _moduleCard(context, state, module),
                  ),
                if (state.status.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
                    child: Text(
                      state.status,
                      style: AppType.small.style(context.palette.accent),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _planSelector(
    BuildContext context,
    FieldState state,
    FieldController controller,
  ) {
    final AppPalette p = context.palette;
    final double progress = state.tasks.isEmpty
        ? 0
        : state.doneCount / state.tasks.length;
    return SsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('本次执行策划案', style: AppType.small.style(p.muted)),
          DropdownButton<String>(
            value: state.selectedPlanId,
            isExpanded: true,
            items: <DropdownMenuItem<String>>[
              for (final Plan plan in state.plans)
                DropdownMenuItem<String>(
                  value: plan.id,
                  child: Text(
                    plan.title,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.h3.style(p.ink),
                  ),
                ),
            ],
            onChanged: (String? id) {
              if (id != null) controller.selectPlan(id);
            },
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '现场进度 ${state.doneCount} / ${state.tasks.length}',
                  style: AppType.bodyLg.style(p.ink),
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: appMono(p.accent, size: AppType.body.size),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s2),
          LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            color: p.accent,
            backgroundColor: p.accentSoft,
            borderRadius: BorderRadius.circular(AppRadius.chip),
          ),
        ],
      ),
    );
  }

  Widget _checklist(
    BuildContext context,
    FieldState state,
    FieldController controller,
  ) {
    final AppPalette p = context.palette;
    return SsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SsSectionTitle('拍摄清单', subtitle: '点按即可勾选，自动保存'),
          for (final FieldTask task in state.tasks)
            Material(
              type: MaterialType.transparency,
              child: CheckboxListTile(
                value: task.done,
                onChanged: (_) => controller.toggleTask(task.id),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  task.title,
                  style: AppType.bodyLg
                      .style(task.done ? p.muted : p.ink)
                      .copyWith(
                        decoration: task.done
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                ),
              ),
            ),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _newTask,
                  decoration: const InputDecoration(hintText: '添加现场事项'),
                  onSubmitted: (_) => _addTask(),
                ),
              ),
              IconButton(
                tooltip: '添加事项',
                onPressed: _addTask,
                icon: const Icon(Icons.add_task_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _notesCard(
    BuildContext context,
    FieldState state,
    FieldController controller,
  ) {
    return SsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SsSectionTitle('现场备注', subtitle: '记录实际灯位、临时调整和交付约定'),
          TextField(
            controller: _notes,
            minLines: 4,
            maxLines: 7,
            onChanged: controller.setNotes,
            decoration: const InputDecoration(
              hintText: '例如：主灯实际左移 0.5m，模特右侧补一块反光板…',
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: SsButton(
              label: '保存备注',
              icon: Icons.save_outlined,
              dense: true,
              onPressed: controller.saveNotes,
            ),
          ),
        ],
      ),
    );
  }

  Widget _moduleCard(
    BuildContext context,
    FieldState state,
    PlanModuleData module,
  ) {
    final String sceneId = '${module.data['sceneId'] ?? ''}'.trim();
    return SsCard(
      child: Material(
        type: MaterialType.transparency,
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          initiallyExpanded:
              module.type == PlanModuleType.storyboard ||
              module.type == PlanModuleType.lighting,
          title: Text(
            module.title,
            style: AppType.h3.style(context.palette.ink),
          ),
          subtitle: Text(module.summary),
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: ModuleContentView(module: module),
            ),
            if (module.type == PlanModuleType.lighting)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.s2),
                child: FieldExposureBrief(
                  sceneId: sceneId,
                  scene: state.lightingById[sceneId],
                  onRefresh: () async {
                    await ref
                        .read(fieldControllerProvider.notifier)
                        .refreshSelectedPlan();
                  },
                ),
              ),
            if (module.type == PlanModuleType.poses) _posePhotos(module),
          ],
        ),
      ),
    );
  }

  Widget _posePhotos(PlanModuleData module) {
    final List<Map> poses = (module.data['poses'] as List? ?? const <Object?>[])
        .whereType<Map>()
        .toList();
    final List<Map> withPhotos = poses
        .where((Map pose) => '${pose['photo'] ?? ''}'.isNotEmpty)
        .toList();
    if (withPhotos.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 280,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: withPhotos.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpace.s2),
        itemBuilder: (BuildContext context, int index) {
          final Map pose = withPhotos[index];
          return SizedBox(
            width: 210,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.control),
                    child: PosePhotoView(
                      photo: '${pose['photo'] ?? ''}',
                      skeleton: '',
                      showSkeleton: false,
                      cacheWidth: 500,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.s1),
                Text(
                  '${pose['name'] ?? '姿势'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
