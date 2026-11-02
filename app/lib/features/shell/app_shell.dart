import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/widgets.dart';
import '../home/home_page.dart';
import '../field/field_page.dart';
import '../field/field_controller.dart';
import '../libraries/libraries_page.dart';
import '../lighting/lighting_page.dart';
import '../lighting/lighting_controller.dart';
import '../planner/planner_page.dart';
import '../planner/planner_controller.dart';
import '../planner/planner_pending.dart';
import '../poses/poses_page.dart';
import '../refs/refs_page.dart';
import '../refs/refs_controller.dart';
import '../projects/project_controller.dart';
import '../projects/project_switcher.dart';
import '../settings/settings_page.dart';
import '../updater/updater.dart';
import 'shell_nav.dart';
import 'mobile_more_page.dart';
import 'shell_update_banner.dart';

/// 当前导航页（跨模块跳转用：如「姿势送入布光预演」切到布光页）。
/// **下标语义固定**（S4 信息架构，见 `shell_nav.dart`）：0 开案 / 1 画面参考 / 2 布光预演 /
/// 3 动作摆姿 / 4 资源库 / 5 策划案 / 6 设置。
final shellTabProvider = StateProvider<int>((ref) => 0);

/// 工作台外壳：自研左侧导航 + 内容区（拒绝 Material 默认脸，D12/D13；V8/S4 改为画册风信息架构）。
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
      if (!mounted) return;
      ref.read(updaterProvider.notifier).silentCheck();
      ref.read(pendingPosesProvider.notifier).init();
    });
  }

  static const List<Widget> _pages = <Widget>[
    HomePage(),
    RefsPage(),
    LightingPage(),
    PosesPage(),
    LibrariesPage(),
    PlannerPage(),
    SettingsPage(),
    FieldPage(),
    MobileMorePage(),
  ];

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final int index = ref.watch(shellTabProvider);
    final UpdaterState updater = ref.watch(updaterProvider);
    ref.listen<String>(currentProjectIdProvider, (
      String? previous,
      String next,
    ) {
      if (previous == next) return;
      WidgetsBinding.instance.addPostFrameCallback((Duration _) {
        if (!mounted) return;
        ref.read(plannerControllerProvider.notifier).init();
        ref.read(refsControllerProvider.notifier).init();
        ref.read(lightingControllerProvider.notifier).init();
        ref.read(pendingPosesProvider.notifier).init();
        ref.read(fieldControllerProvider.notifier).init();
      });
    });
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool mobile = constraints.maxWidth < 840 || Platform.isAndroid;
        if (!mobile && index > 6) {
          WidgetsBinding.instance.addPostFrameCallback((Duration _) {
            if (mounted) ref.read(shellTabProvider.notifier).state = 0;
          });
        }
        return mobile
            ? _buildMobile(p, index, updater)
            : _buildDesktop(p, index, updater);
      },
    );
  }

  Widget _buildDesktop(AppPalette p, int index, UpdaterState updater) {
    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        children: <Widget>[
          if (updater.showBanner) ShellUpdateBanner(updater: updater),
          Expanded(
            child: Row(
              children: <Widget>[
                ShellSideNav(index: index, onSelect: _selectTab),
                const VerticalHairline(),
                Expanded(
                  child: _LazyIndexStack(index: index, children: _pages),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobile(AppPalette p, int index, UpdaterState updater) {
    const List<int> tabs = <int>[0, 7, 1, 3, 8];
    final int selected = switch (index) {
      0 => 0,
      7 => 1,
      1 => 2,
      3 => 3,
      _ => 4,
    };
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            if (updater.showBanner) ShellUpdateBanner(updater: updater),
            ColoredBox(color: p.surfaceSunken, child: const ProjectSwitcher()),
            Expanded(
              child: _LazyIndexStack(index: index, children: _pages),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        height: 68,
        selectedIndex: selected,
        onDestinationSelected: (int i) => _selectTab(tabs[i]),
        backgroundColor: p.surface,
        indicatorColor: p.accentSoft,
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: '开案',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist_rounded),
            label: '现场',
          ),
          NavigationDestination(
            icon: Icon(Icons.movie_filter_outlined),
            selectedIcon: Icon(Icons.movie_filter),
            label: '参考',
          ),
          NavigationDestination(
            icon: Icon(Icons.accessibility_new_outlined),
            selectedIcon: Icon(Icons.accessibility_new),
            label: '摆姿',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz_rounded),
            label: '更多',
          ),
        ],
      ),
    );
  }

  void _selectTab(int index) {
    ref.read(shellTabProvider.notifier).state = index;
  }
}

/// 纵向 1px hairline（§3.3：只用 1px）。
class VerticalHairline extends StatelessWidget {
  const VerticalHairline({super.key});

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return Container(width: 1, color: p.rule);
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
