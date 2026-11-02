import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/widgets.dart';
import 'app_shell.dart';

class MobileMorePage extends ConsumerWidget {
  const MobileMorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SsPage(
      title: '更多',
      subtitle: '完整编辑与项目资源',
      body: ListView(
        children: <Widget>[
          _entry(
            context,
            ref,
            icon: Icons.dashboard_customize_outlined,
            title: '策划案',
            subtitle: '查看和编辑当前项目的策划内容',
            tab: 5,
          ),
          _entry(
            context,
            ref,
            icon: Icons.grid_view_outlined,
            title: '资源库',
            subtitle: '模特、场地、服装、道具和设备',
            tab: 4,
          ),
          _entry(
            context,
            ref,
            icon: Icons.wb_incandescent_outlined,
            title: '布光预演',
            subtitle: '完整 3D 编辑建议使用横屏或桌面端',
            tab: 2,
          ),
          _entry(
            context,
            ref,
            icon: Icons.tune_outlined,
            title: '设置',
            subtitle: '工作区、主题、内容包与提供方',
            tab: 6,
          ),
        ],
      ),
    );
  }

  Widget _entry(
    BuildContext context,
    WidgetRef ref, {
    required IconData icon,
    required String title,
    required String subtitle,
    required int tab,
  }) {
    final AppPalette p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s2),
      child: SsCard(
        onTap: () => ref.read(shellTabProvider.notifier).state = tab,
        child: Row(
          children: <Widget>[
            Icon(icon, color: p.accent),
            const SizedBox(width: AppSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: AppType.h3.style(p.ink)),
                  Text(subtitle, style: AppType.small.style(p.muted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: p.muted),
          ],
        ),
      ),
    );
  }
}
