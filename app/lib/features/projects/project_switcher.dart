import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/design/widgets.dart';
import 'project_controller.dart';

class ProjectSwitcher extends ConsumerWidget {
  const ProjectSwitcher({super.key});

  Future<void> _createProject(BuildContext context, WidgetRef ref) async {
    final TextEditingController controller = TextEditingController();
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('新建拍摄项目'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 120,
          decoration: const InputDecoration(
            labelText: '项目名称',
            hintText: '例如：品牌秋季人像 · 上海',
          ),
          onSubmitted: (String value) => Navigator.of(context).pop(value),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('创建并切换'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty || !context.mounted) return;
    try {
      await ref.read(projectsProvider.notifier).createProject(name);
      if (context.mounted) ssToast(context, '已创建并切换到「${name.trim()}」');
    } catch (error) {
      if (context.mounted) {
        ssToast(context, '创建项目失败：$error', kind: SsBannerKind.danger);
      }
    }
  }

  Future<void> _switch(
    BuildContext context,
    WidgetRef ref,
    String projectId,
  ) async {
    try {
      await ref.read(projectsProvider.notifier).switchProject(projectId);
    } catch (error) {
      if (context.mounted) {
        ssToast(context, '切换项目失败：$error', kind: SsBannerKind.danger);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette p = context.palette;
    final AsyncValue<List<ShootProject>> asyncProjects = ref.watch(
      projectsProvider,
    );
    final List<ShootProject> projects =
        asyncProjects.valueOrNull ?? const <ShootProject>[];
    final String currentId = ref.watch(currentProjectIdProvider);
    final bool hasCurrent = projects.any(
      (ShootProject project) => project.id == currentId,
    );
    final String currentName =
        projects
            .where((ShootProject project) => project.id == currentId)
            .map((ShootProject project) => project.name)
            .firstOrNull ??
        '默认拍摄项目';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s3,
        AppSpace.s3,
        AppSpace.s2,
        AppSpace.s2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('当前拍摄项目', style: appMono(p.muted).copyWith(letterSpacing: 1.2)),
          Row(
            children: <Widget>[
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: hasCurrent ? currentId : null,
                    isExpanded: true,
                    isDense: true,
                    hint: Text(
                      currentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.small.style(p.ink),
                    ),
                    selectedItemBuilder: (BuildContext context) => <Widget>[
                      for (final ShootProject project in projects)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            project.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.small.style(p.ink),
                          ),
                        ),
                    ],
                    items: <DropdownMenuItem<String>>[
                      for (final ShootProject project in projects)
                        DropdownMenuItem<String>(
                          value: project.id,
                          child: Text(
                            project.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: projects.isEmpty
                        ? null
                        : (String? id) {
                            if (id != null && id != currentId) {
                              _switch(context, ref, id);
                            }
                          },
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: '新建拍摄项目',
                onPressed: () => _createProject(context, ref),
                icon: Icon(
                  Icons.add_rounded,
                  size: AppType.h3.size,
                  color: p.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
