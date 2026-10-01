import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

import '../../core/db/database.dart';
import '../ai/ai_panel.dart';
import '../ai/ai_side_panel.dart';
import '../export/export_panel.dart';
import '../export/exporter.dart';
import '../../core/design/widgets.dart';
import '../../core/providers.dart';
import '../../services/content_packs.dart';
import '../../services/geocoding.dart';
import '../../services/image_store.dart';
import '../../services/palette_extractor.dart';
import '../../services/richtext_lite.dart';
import '../../services/search/planner_refs.dart';
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

part 'planner_page_canvas.dart';
part 'planner_page_layout.dart';
part 'planner_page_dialogs.dart';
part 'planner_module_editor.dart';
part 'planner_module_editors_a.dart';
part 'planner_module_editors_b.dart';

class Option {
  const Option(this.id, this.name);
  final String id;
  final String name;
}

/// 已保存布光方案列表（供布光图模块绑定）。
final lightingScenesProvider = FutureProvider.autoDispose<List<Option>>((
  ref,
) async {
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

  /// AI 策划联动（D121）：插入模块后按主题自动搜集 5–10 张参考图。

  /// extension 里不能直接调 protected setState，统一走这层薄封装。
  void refresh(void Function() fn) => setState(fn);

  String? _selectedModuleId;
  String? _aiTargetId;
  final Set<String> _expandedIds = <String>{};
  int _rightTab = 0; // 0 编辑 / 1 AI 助手

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
          kind: SsButtonKind.outline,
          onPressed: () => showDialog<void>(
            context: context,
            builder: (BuildContext ctx) => AiPanel(
              onInsertAll: (List<PlanModuleData> modules) {
                controller.insertModules(modules);
                unawaited(_autoCollectRefs(modules));
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
          kind: SsButtonKind.text,
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
                // D150：旧版包会被迁移，迁移事实要明示给用户（不要静默成功）。
                final String? migrated = imported.migratedFrom == null
                    ? null
                    : '（已从 v${imported.migratedFrom} 自动迁移）';
                ssToast(
                  context,
                  '已导入「${imported.title}」（${imported.moduleCount} 个模块）$migrated',
                );
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
          kind: SsButtonKind.text,
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
                _buildLeftPanel(context, state, controller),
                const SizedBox(width: AppSpace.s3),
                Expanded(child: _buildCanvas(state, controller)),
                const SizedBox(width: AppSpace.s3),
                SizedBox(width: 348, child: _buildEditor(state, controller)),
              ],
            ),
    );
  }
}
