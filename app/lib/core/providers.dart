import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bootstrap/app_bootstrap.dart';
import 'db/database.dart';
import 'workspace/workspace.dart';
import '../features/onboarding/demo_content.dart';
import '../services/content_packs.dart';
import '../services/net_router.dart';

/// 工作区未被选择时抛出，引导层据此展示首次启动页。
final class NeedWorkspaceException implements Exception {
  const NeedWorkspaceException();
}

/// 初始化完成后的运行态：工作区 + 数据库。
final class AppRuntime {
  const AppRuntime({required this.workspace, required this.db});

  final Workspace workspace;
  final AppDatabase db;
}

/// 测试注入通道（F15）：widget/golden 测试用临时工作区启动真实 App。
final bootstrapPathOverrideProvider = Provider<String?>((ref) => null);

/// 应用初始化：读取引导配置 → 打开工作区 → 初始化数据库。
/// 未选择工作区时以 [NeedWorkspaceException] 结束，由根组件切换到引导页。
final appRuntimeProvider =
    AsyncNotifierProvider<AppRuntimeNotifier, AppRuntime>(
      AppRuntimeNotifier.new,
    );

class AppRuntimeNotifier extends AsyncNotifier<AppRuntime> {
  @override
  Future<AppRuntime> build() async {
    final override = ref.read(bootstrapPathOverrideProvider);
    if (override != null && override.isNotEmpty) {
      return _open(override);
    }
    final saved = await AppBootstrap.readWorkspacePath();
    if (saved == null) {
      throw const NeedWorkspaceException();
    }
    return _open(saved);
  }

  Future<AppRuntime> _open(String path) async {
    final workspace = await Workspace.initAt(path);
    final db = await AppDatabase.init();
    // 内置内容包同步（影片索引 / 姿势库），幂等且保留用户状态。
    await ContentPacks.syncToDatabase(db);
    // V5：统一网络通道（用户代理 / DoH 隧道 / 直连三态）。
    // flutter test 环境跳过（保持测试无网络副作用）；显式测试可自行 configure。
    if (Platform.environment['FLUTTER_TEST'] != 'true') {
      final String proxy = await db.getSetting('proxy_url') ?? '';
      final String netMode = await db.getSetting('net_mode') ?? 'auto';
      await NetRouter.I.configure(
        userProxy: proxy,
        autoTunnel: netMode != 'direct',
        forceDirect: netMode == 'direct',
      );
    }
    return AppRuntime(workspace: workspace, db: db);
  }

  /// 引导页确认工作区后调用：持久化路径并重新初始化。
  /// [withDemo] 为 true 时写入示例内容（F6，可在设置页一键移除）。
  Future<void> chooseWorkspace(String path, {bool withDemo = false}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await AppBootstrap.writeWorkspacePath(path);
      final AppRuntime runtime = await _open(path);
      if (withDemo) {
        await DemoContentService.seed(runtime.db);
      }
      return runtime;
    });
  }
}

/// 当前工作区（仅在 [appRuntimeProvider] 就绪后可用）。
final workspaceProvider = Provider<Workspace>(
  (ref) => ref.watch(appRuntimeProvider).requireValue.workspace,
);

/// 当前数据库（仅在 [appRuntimeProvider] 就绪后可用）。
final databaseProvider = Provider<AppDatabase>(
  (ref) => ref.watch(appRuntimeProvider).requireValue.db,
);
