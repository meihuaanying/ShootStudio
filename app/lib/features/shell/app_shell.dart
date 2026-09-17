import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/design/widgets.dart';
import '../../core/theme/tokens.dart';
import '../home/home_page.dart';
import '../libraries/libraries_page.dart';
import '../lighting/lighting_page.dart';
import '../planner/planner_page.dart';
import '../poses/poses_page.dart';
import '../refs/refs_page.dart';
import '../settings/settings_page.dart';
import '../updater/updater.dart';

/// 当前导航页（跨模块跳转用：如「姿势送入布光预演」切到布光页）。
final shellTabProvider = StateProvider<int>((ref) => 0);

/// 工作台外壳：自研左侧导航 + 内容区（拒绝 Material 默认脸，D12/D13）。
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      // 启动静默检查（PRD 6.9：有新版仅横幅提示，不打断使用）。
      ref.read(updaterProvider.notifier).silentCheck();
    });
  }

  static const List<_NavItem> _items = <_NavItem>[
    _NavItem('开案', Icons.auto_awesome_outlined, Icons.auto_awesome),
    _NavItem('画面参考', Icons.movie_filter_outlined, Icons.movie_filter),
    _NavItem('布光预演', Icons.wb_incandescent_outlined, Icons.wb_incandescent),
    _NavItem('动作摆姿', Icons.accessibility_new_outlined, Icons.accessibility_new),
    _NavItem('资源库', Icons.grid_view_outlined, Icons.grid_view),
    _NavItem(
        '策划案', Icons.dashboard_customize_outlined, Icons.dashboard_customize),
    _NavItem('设置', Icons.tune_outlined, Icons.tune),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final index = ref.watch(shellTabProvider);
    final updater = ref.watch(updaterProvider);
    return Scaffold(
      body: Column(
        children: <Widget>[
          if (updater.showBanner) _UpdateBanner(updater: updater),
          Expanded(
            child: Row(
              children: <Widget>[
                _SideNav(
                  items: _items,
                  index: index,
                  onSelect: (int i) =>
                      ref.read(shellTabProvider.notifier).state = i,
                ),
                VerticalDivider(width: 1, color: theme.colorScheme.outline),
                Expanded(
                  child: _LazyIndexStack(
                    index: index,
                    children: const <Widget>[
                      HomePage(),
                      RefsPage(),
                      LightingPage(),
                      PosesPage(),
                      LibrariesPage(),
                      PlannerPage(),
                      SettingsPage(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 懒加载 IndexedStack（F5）：页面首次访问才构建，隐藏页 Offstage + TickerMode 暂停。
/// 修复 v1.0.0「启动即创建两个 WebView」的启动性能问题。
class _LazyIndexStack extends StatefulWidget {
  const _LazyIndexStack({required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<_LazyIndexStack> createState() => _LazyIndexStackState();
}

class _LazyIndexStackState extends State<_LazyIndexStack> {
  final Set<int> _built = <int>{0};

  @override
  void didUpdateWidget(covariant _LazyIndexStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _built.add(widget.index);
  }

  @override
  Widget build(BuildContext context) {
    return SsFadeSwitch(
      index: widget.index,
      child: Stack(
        children: <Widget>[
          for (var i = 0; i < widget.children.length; i++)
            if (_built.contains(i))
              Positioned.fill(
                child: Offstage(
                  offstage: i != widget.index,
                  child: TickerMode(
                    enabled: i == widget.index,
                    child: widget.children[i],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// 可关闭更新横幅（PRD 6.9：展示更新要点与镜像下载）。
class _UpdateBanner extends ConsumerWidget {
  const _UpdateBanner({required this.updater});

  final UpdaterState updater;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcement = updater.announcement!;
    return Material(
      color: AppTokens.accent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: <Widget>[
            const Icon(Icons.system_update_alt_rounded,
                size: 17, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '发现新版本 v${announcement.version}：${announcement.notes.take(2).join('；')}',
                style: const TextStyle(color: Colors.white, fontSize: 12.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () =>
                  ref.read(updaterProvider.notifier).dismissBanner(),
              child: const Text('下次再说',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ),
            FilledButton(
              onPressed: () {
                final entry = announcement.downloadFor(
                  Theme.of(context).platform == TargetPlatform.windows
                      ? 'windows'
                      : 'android',
                );
                final url = entry == null
                    ? ''
                    : (entry.mirror.isNotEmpty ? entry.mirror : entry.github);
                if (url.isEmpty) {
                  ssToast(context, '请前往官网下载 v${announcement.version}');
                } else {
                  launchUrl(Uri.parse(url),
                      mode: LaunchMode.externalApplication);
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTokens.accent,
              ),
              child: const Text('立即更新', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon, this.activeIcon);
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

class _SideNav extends StatelessWidget {
  const _SideNav(
      {required this.items, required this.index, required this.onSelect});

  final List<_NavItem> items;
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Container(
      width: 218,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
            child: Row(
              children: <Widget>[
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: <Color>[AppTokens.accent, Color(0xFF7B5CFF)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '正',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15),
                  ),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('正片工坊',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800)),
                    Text(
                      'SHOOTSTUDIO',
                      style: TextStyle(
                          fontSize: 9, letterSpacing: 1.6, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              '工作流',
              style:
                  TextStyle(fontSize: 10.5, letterSpacing: 1.2, color: muted),
            ),
          ),
          const SizedBox(height: 6),
          for (int i = 0; i < 4; i++) _navTile(context, i),
          const SizedBox(height: AppTokens.s16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              '成案',
              style:
                  TextStyle(fontSize: 10.5, letterSpacing: 1.2, color: muted),
            ),
          ),
          const SizedBox(height: 6),
          for (int i = 4; i < 6; i++) _navTile(context, i),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Divider(color: theme.colorScheme.outline, height: 1),
          ),
          for (int i = 6; i < items.length; i++) _navTile(context, i),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
            child: Text(
              'v$kAppVersion · MIT 开源',
              style: TextStyle(fontSize: 10.5, color: muted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navTile(BuildContext context, int i) {
    final theme = Theme.of(context);
    final selected = i == index;
    final item = items[i];
    return InkWell(
      onTap: () => onSelect(i),
      child: AnimatedContainer(
        duration: AppTokens.dFast,
        curve: AppTokens.cEmphasis,
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTokens.accentSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTokens.rSm),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              selected ? item.activeIcon : item.icon,
              size: 17,
              color: selected
                  ? AppTokens.accent
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 13,
                color:
                    selected ? AppTokens.accent : theme.colorScheme.onSurface,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
