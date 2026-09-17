import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/design/widgets.dart';
import 'core/providers.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/tokens.dart';
import 'features/onboarding/onboarding_page.dart';
import 'features/shell/app_shell.dart';

/// 主题模式（D12：默认跟随系统；设置页可覆盖）。
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

class ShootStudioApp extends ConsumerWidget {
  const ShootStudioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: '正片工坊 ShootStudio',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      home: const _RootGate(),
    );
  }
}

/// 根路由门：初始化中 → 启动页；未选工作区 → 引导页；就绪 → 工作台。
class _RootGate extends ConsumerWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runtime = ref.watch(appRuntimeProvider);
    return runtime.when(
      data: (_) => const AppShell(),
      loading: () => const _Splash(),
      error: (Object error, StackTrace stack) {
        if (error is NeedWorkspaceException) {
          return const OnboardingPage();
        }
        return _InitError(error: error);
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            SizedBox(height: AppTokens.s16),
            Text('正在准备工作区…', style: TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _InitError extends ConsumerWidget {
  const _InitError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(AppTokens.s24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(Icons.error_outline_rounded,
                    size: 40, color: AppTokens.danger),
                const SizedBox(height: AppTokens.s12),
                const Text('工作区初始化失败',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: AppTokens.s8),
                SsBanner(text: '$error', kind: SsBannerKind.danger),
                const SizedBox(height: AppTokens.s16),
                SsButton(
                  label: '重试',
                  icon: Icons.refresh_rounded,
                  onPressed: () => ref.invalidate(appRuntimeProvider),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
