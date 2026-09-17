import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bootstrap/app_bootstrap.dart';
import '../../core/design/widgets.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/workspace/workspace.dart';

/// 首次启动引导：选择本地工作区目录（PRD M4 / D2 本地优先）。
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  String? _defaultPath;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    AppBootstrap.defaultWorkspacePath().then((String path) {
      if (mounted) {
        setState(() => _defaultPath = path);
      }
    });
  }

  Future<void> _confirm(String path, {bool withDemo = false}) async {
    setState(() => _busy = true);
    if (!await Workspace.isWritable(path)) {
      if (mounted) {
        setState(() => _busy = false);
        ssToast(context, '该目录不可写入，请换一个位置');
      }
      return;
    }
    await ref
        .read(appRuntimeProvider.notifier)
        .chooseWorkspace(path, withDemo: withDemo);
    if (mounted) {
      setState(() => _busy = false);
    }
  }

  Future<void> _pick() async {
    final path =
        await FilePicker.platform.getDirectoryPath(dialogTitle: '选择工作区目录');
    if (path == null || path.isEmpty) return;
    await _confirm(path);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Padding(
            padding: const EdgeInsets.all(AppTokens.s32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: <Color>[AppTokens.accent, Color(0xFF7B5CFF)],
                    ),
                    borderRadius: BorderRadius.circular(AppTokens.rMd),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '正',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: AppTokens.s24),
                const Text(
                  '正片工坊 ShootStudio',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: AppTokens.s8),
                Text(
                  '画面参考 → 布光预演 → 动作摆姿 → 一键成案\n本地优先，数据全部保存在你选择的目录里，可整体迁移。',
                  style: TextStyle(
                      fontSize: 13.5,
                      height: 1.7,
                      color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppTokens.s24),
                Row(
                  children: <Widget>[
                    for (final (int i, String label, IconData icon)
                        in <(int, String, IconData)>[
                      (1, '找画面参考', Icons.movie_filter_outlined),
                      (2, '摆灯光与姿势', Icons.wb_incandescent_outlined),
                      (3, '一键成案导出', Icons.ios_share_rounded),
                    ])
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: i == 3 ? 0 : 10),
                          child: SsCard(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: <Color>[
                                            AppTokens.accent,
                                            AppTokens.accent2
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '$i',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(icon,
                                        size: 15, color: AppTokens.accent),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(label,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppTokens.s24),
                SsCard(
                  padding: const EdgeInsets.all(AppTokens.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('工作区目录',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: AppTokens.s8),
                      Text(
                        _defaultPath ?? '（正在准备默认目录…）',
                        style: AppTokens.mono(
                          context,
                          size: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppTokens.s16),
                      Wrap(
                        spacing: AppTokens.s12,
                        runSpacing: AppTokens.s8,
                        children: <Widget>[
                          SsButton(
                            label: _busy ? '正在初始化…' : '开始空白工作区',
                            icon: Icons.play_arrow_rounded,
                            onPressed: _busy || _defaultPath == null
                                ? null
                                : () => _confirm(_defaultPath!),
                          ),
                          SsButton(
                            label: '载入示例内容',
                            icon: Icons.auto_awesome_rounded,
                            kind: SsButtonKind.soft,
                            onPressed: _busy || _defaultPath == null
                                ? null
                                : () => _confirm(_defaultPath!, withDemo: true),
                          ),
                          SsButton(
                            label: '选择其他目录…',
                            icon: Icons.folder_open_rounded,
                            kind: SsButtonKind.ghost,
                            onPressed: _busy ? null : _pick,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTokens.s16),
                Text(
                  Platform.isWindows
                      ? '提示：目录内会自动创建 database.sqlite、images/ 与 exports/ 子目录。'
                      : '提示：建议选择存储空间充足的目录；数据仅存留在本机。',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
