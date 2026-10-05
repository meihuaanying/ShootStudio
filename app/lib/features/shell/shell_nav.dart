import 'package:flutter/material.dart';

import '../../core/design/widgets.dart';
import '../updater/updater.dart' show kAppVersion;

/// 外壳信息架构（D147/S4）：分组 + 序号 = `shellTabProvider` 的 tab 下标。
/// 下标被各 feature 直接引用（如「姿势送入布光预演」切 2、「写入画布」切 5），
/// 因此**顺序不可调整**，新增页面只能追加到末尾。
class ShellNavSection {
  const ShellNavSection({
    required this.label,
    required this.eyebrow,
    required this.startIndex,
  });

  /// 侧栏分组标题（衬线 H3）。
  final String label;

  /// 眉题（mono + 字距 1.5，§3.2）。
  final String eyebrow;

  /// 本组第一个 tab 下标。
  final int startIndex;
}

/// 信息架构定义：工作流 4 项 → 成案 2 项 → 系统 1 项。
const List<ShellNavSection> kShellNavSections = <ShellNavSection>[
  ShellNavSection(label: '工作流', eyebrow: 'WORKFLOW', startIndex: 0),
  ShellNavSection(label: '成案', eyebrow: 'DELIVERY', startIndex: 4),
  ShellNavSection(label: '系统', eyebrow: 'SYSTEM', startIndex: 6),
];

/// 单个导航项。
class ShellNavItem {
  const ShellNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.caption,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;

  /// 侧栏右侧 mono 小字（信息量补充，非交互）。
  final String caption;
}

/// 七个主导航项（顺序 = tab 下标，勿改）。
const List<ShellNavItem> kShellNavItems = <ShellNavItem>[
  ShellNavItem(
    label: '开案',
    icon: Icons.auto_awesome_outlined,
    activeIcon: Icons.auto_awesome,
    caption: 'IDEA',
  ),
  ShellNavItem(
    label: '画面参考',
    icon: Icons.movie_filter_outlined,
    activeIcon: Icons.movie_filter,
    caption: 'REF',
  ),
  ShellNavItem(
    label: '布光预演',
    icon: Icons.wb_incandescent_outlined,
    activeIcon: Icons.wb_incandescent,
    caption: 'LIGHT',
  ),
  ShellNavItem(
    label: '动作摆姿',
    icon: Icons.accessibility_new_outlined,
    activeIcon: Icons.accessibility_new,
    caption: 'POSE',
  ),
  ShellNavItem(
    label: '资源库',
    icon: Icons.grid_view_outlined,
    activeIcon: Icons.grid_view,
    caption: 'GEAR',
  ),
  ShellNavItem(
    label: '策划案',
    icon: Icons.dashboard_customize_outlined,
    activeIcon: Icons.dashboard_customize,
    caption: 'PLAN',
  ),
  ShellNavItem(
    label: '设置',
    icon: Icons.tune_outlined,
    activeIcon: Icons.tune,
    caption: 'SET',
  ),
];

/// 品牌标识（衬线首字 + 印相红方章，去掉 V7 的紫蓝渐变脸 → R82）。
class ShellBrandMark extends StatelessWidget {
  const ShellBrandMark({super.key, this.size = 30});

  final double size;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: p.accent,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      alignment: Alignment.center,
      child: Text(
        '正',
        style: AppType.h3.style(
          p.surface,
          font: AppFonts.display,
          weight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 左侧导航（宽 232）：品牌区 + 分组 + 选中态（accentSoft 底 + 1px accent 左标）。
class ShellSideNav extends StatelessWidget {
  const ShellSideNav({super.key, required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  static const double width = 232;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return Container(
      width: width,
      color: p.surfaceSunken,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s4,
              AppSpace.s5,
              AppSpace.s4,
              AppSpace.s4,
            ),
            child: Row(
              children: <Widget>[
                const ShellBrandMark(),
                const SizedBox(width: AppSpace.s2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        '正片工坊',
                        style: AppType.h3.style(p.ink, weight: FontWeight.w600),
                      ),
                      Text(
                        'SHOOTSTUDIO',
                        style: appMono(
                          p.muted,
                          size: AppFontSize.caption,
                        ).copyWith(letterSpacing: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SsDivider(),
          const SizedBox(height: AppSpace.s3),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: AppSpace.s4),
              children: <Widget>[
                for (final ShellNavSection section in kShellNavSections)
                  _section(context, section),
              ],
            ),
          ),
          const SsDivider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s4,
              AppSpace.s3,
              AppSpace.s4,
              AppSpace.s3,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'v$kAppVersion',
                    style: appMono(p.muted, size: AppFontSize.caption),
                  ),
                ),
                Text('MIT 开源', style: AppType.caption.style(p.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, ShellNavSection group) {
    final AppPalette p = context.palette;
    final int end = group == kShellNavSections.last
        ? kShellNavItems.length
        : kShellNavSections
              .firstWhere(
                (ShellNavSection s) => s.startIndex > group.startIndex,
                orElse: () => group,
              )
              .startIndex;
    final int count = end - group.startIndex;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s4,
            AppSpace.s3,
            AppSpace.s4,
            AppSpace.s1,
          ),
          child: Text(
            group.eyebrow,
            style: appMono(
              p.muted,
              size: AppFontSize.caption,
            ).copyWith(letterSpacing: 1.5),
          ),
        ),
        for (int i = 0; i < count; i++)
          _NavTile(
            index: group.startIndex + i,
            selected: group.startIndex + i == index,
            onSelect: onSelect,
          ),
      ],
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.index,
    required this.selected,
    required this.onSelect,
  });

  final int index;
  final bool selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final ShellNavItem item = kShellNavItems[index];
    return InkWell(
      onTap: () => onSelect(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s3,
          vertical: AppSpace.s1,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: selected ? p.accentSoft : null,
            borderRadius: BorderRadius.circular(AppRadius.control),
            border: Border(
              left: BorderSide(
                // 未选中时用令牌色的全透明，避免写死 Material 透明常量（R71）。
                color: selected ? p.accent : p.rule.withValues(alpha: 0),
                width: 1,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s3,
            vertical: AppSpace.s2,
          ),
          child: Row(
            children: <Widget>[
              Icon(
                selected ? item.activeIcon : item.icon,
                size: AppFontSize.h3,
                color: selected ? p.accent : p.inkSoft,
              ),
              const SizedBox(width: AppSpace.s3),
              Expanded(
                child: Text(
                  item.label,
                  style: AppType.body.style(
                    selected ? p.accent : p.ink,
                    weight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              Text(
                item.caption,
                style: appMono(
                  selected ? p.accent : p.muted,
                  size: AppFontSize.caption,
                ).copyWith(letterSpacing: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
