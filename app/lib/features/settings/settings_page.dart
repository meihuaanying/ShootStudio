import 'dart:io';
import '../../core/db/database.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import '../../services/net.dart';
import '../../services/net_router.dart';
import 'package:file_picker/file_picker.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app.dart';
import '../../core/design/widgets.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../services/gear_photo_sync.dart';
import '../../services/engine/engine_reload.dart';
import '../../services/gpu/gpu_info.dart';
import '../../services/search/search_cache.dart';
import '../ai/ai_controller.dart';
import '../onboarding/demo_content.dart';
import '../updater/updater.dart';

/// 示例内容状态（设置页可一键移除）。
final demoSeededProvider = FutureProvider.autoDispose<bool>(
  (ref) => DemoContentService.isSeeded(ref.watch(databaseProvider)),
);

/// 设置：外观 / 工作区 / 示例内容 / 关于与更新（PRD 6.9：三态 + 静默降级 + 内容包通道）。
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  String? _announcementUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((Duration _) async {
      final url = await ref.read(updaterProvider.notifier).announcementUrl();
      if (mounted) setState(() => _announcementUrl = url);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mode = ref.watch(themeModeProvider);
    final workspace = ref.watch(workspaceProvider);
    final updater = ref.watch(updaterProvider);

    return SsPage(
      title: '设置',
      subtitle: '外观 · 工作区 · AI 通道 · 图片素材 · 显卡 · 关于与更新',
      body: ListView(
        children: <Widget>[
          SsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SsSectionTitle('外观', subtitle: 'D12：统一设计令牌，明暗双主题跟随系统'),
                const SizedBox(height: AppTokens.s12),
                Row(
                  children: <Widget>[
                    for (final entry in <(String, ThemeMode)>[
                      ('跟随系统', ThemeMode.system),
                      ('亮色', ThemeMode.light),
                      ('暗色', ThemeMode.dark),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: SsChip(
                          label: entry.$1,
                          selected: mode == entry.$2,
                          onTap: () =>
                              ref.read(themeModeProvider.notifier).state =
                                  entry.$2,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.s12),
          SsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SsSectionTitle('工作区', subtitle: '本地优先：数据随目录整体迁移'),
                const SizedBox(height: AppTokens.s12),
                Text(
                  workspace.root.path,
                  style: AppTokens.mono(
                    context,
                    size: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.s12),
          Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? _) {
              final AsyncValue<bool> seeded = ref.watch(demoSeededProvider);
              return seeded.maybeWhen(
                data: (bool isSeeded) => isSeeded
                    ? SsCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const SsSectionTitle(
                              '示例内容',
                              subtitle:
                                  '首次引导载入的演示数据（策划案 / 参考帧 / 布光方案 / 资源 / 姿势）',
                            ),
                            const SizedBox(height: AppTokens.s8),
                            SsButton(
                              label: '移除示例内容',
                              icon: Icons.delete_sweep_outlined,
                              kind: SsButtonKind.ghost,
                              dense: true,
                              onPressed: () async {
                                await DemoContentService.remove(
                                  ref.read(databaseProvider),
                                );
                                ref.invalidate(demoSeededProvider);
                                if (context.mounted) {
                                  ssToast(context, '示例内容已移除（你的数据未被触碰）');
                                }
                              },
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
                orElse: () => const SizedBox.shrink(),
              );
            },
          ),
          const SizedBox(height: AppTokens.s12),
          const _AiChannelsCard(),
          const SizedBox(height: AppTokens.s12),
          const _AssetSourcesCard(),
          const SizedBox(height: AppTokens.s12),
          const _GpuCard(),
          const SizedBox(height: AppTokens.s12),
          SsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SsSectionTitle(
                  '关于与更新',
                  subtitle: 'GitHub Release 为唯一事实源 · 版本与内容包双通道',
                ),
                const SizedBox(height: AppTokens.s12),
                Row(
                  children: <Widget>[
                    Text(
                      '当前版本 v$kAppVersion',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const Spacer(),
                    SsButton(
                      label: updater.checking ? '检查中…' : '检查更新',
                      kind: SsButtonKind.ghost,
                      dense: true,
                      onPressed: updater.checking ? null : _manualCheck,
                    ),
                  ],
                ),
                if (updater.status.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    updater.status,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (updater.announcement != null &&
                    updater.lastState == UpdateState.hasUpdate) ...<Widget>[
                  const SizedBox(height: 8),
                  SsBanner(
                    text:
                        'v${updater.announcement!.version} · ${updater.announcement!.publishedAt}\n'
                        '${updater.announcement!.notes.take(4).map((String n) => '· $n').join('\n')}',
                    kind: SsBannerKind.info,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      SsButton(
                        label: '立即更新（国内镜像）',
                        dense: true,
                        onPressed: () {
                          final entry = updater.announcement!.downloadFor(
                            Platform.isWindows ? 'windows' : 'android',
                          );
                          final url = entry == null
                              ? ''
                              : (entry.mirror.isNotEmpty
                                    ? entry.mirror
                                    : entry.github);
                          if (url.isEmpty) {
                            ssToast(context, '请前往官网下载最新版本');
                          } else {
                            launchUrl(
                              Uri.parse(url),
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      SsButton(
                        label: '稍后再说',
                        kind: SsButtonKind.ghost,
                        dense: true,
                        onPressed: () =>
                            ref.read(updaterProvider.notifier).dismissBanner(),
                      ),
                    ],
                  ),
                ],
                for (final op
                    in updater.announcement?.ops ??
                        const <({String date, String title})>[])
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '公告：${op.title}${op.date.isEmpty ? '' : '（${op.date}）'}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppTokens.accent,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                TextField(
                  controller: TextEditingController(
                    text: _announcementUrl ?? '',
                  ),
                  decoration: const InputDecoration(
                    labelText: '公告 JSON 地址（空 = 官方默认；支持自建站点 / 内网）',
                    isDense: true,
                  ),
                  onSubmitted: (String v) async {
                    await ref
                        .read(updaterProvider.notifier)
                        .setAnnouncementUrl(v);
                    if (mounted) setState(() => _announcementUrl = v.trim());
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _manualCheck() async {
    final result = await ref.read(updaterProvider.notifier).manualCheck();
    if (!mounted) return;
    final message = switch (result) {
      UpdateState.hasUpdate => '发现新版本，请查看下方更新要点',
      UpdateState.upToDate => '已是最新版本',
      UpdateState.failed => '网络异常，请稍后重试',
      UpdateState.silent => '检查未完成',
    };
    ssToast(context, message);
  }
}

/// D40：AI 通道管理（设置页）：Key、启用、自动拉模型、自动选模、故障转移顺序。
class _AiChannelsCard extends ConsumerStatefulWidget {
  const _AiChannelsCard();

  @override
  ConsumerState<_AiChannelsCard> createState() => _AiChannelsCardState();
}

class _AiChannelsCardState extends ConsumerState<_AiChannelsCard> {
  final Set<String> _expanded = <String>{};
  final Map<String, TextEditingController> _keys =
      <String, TextEditingController>{};
  final Set<String> _fetching = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      ref.read(aiControllerProvider.notifier).init();
    });
  }

  @override
  void dispose() {
    for (final TextEditingController c in _keys.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _fetch(String id) async {
    setState(() => _fetching.add(id));
    final List<String> models = await ref
        .read(aiControllerProvider.notifier)
        .fetchModels(id);
    if (!mounted) return;
    setState(() => _fetching.remove(id));
    final AiProviderView? view = ref
        .read(aiControllerProvider)
        .providers
        .where((AiProviderView p) => p.preset.id == id)
        .firstOrNull;
    ssToast(
      context,
      models.isEmpty
          ? '拉取失败：检查 Key 与网络（已保留手动模型）'
          : '已拉取 ${models.length} 个模型，自动选模：${view?.model ?? ''}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final AiState ai = ref.watch(aiControllerProvider);
    final ThemeData theme = Theme.of(context);
    final List<AiProviderView> providers = <AiProviderView>[...ai.providers]
      ..sort(
        (AiProviderView a, AiProviderView b) =>
            a.priority.compareTo(b.priority),
      );
    return SsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SsSectionTitle(
            'AI 通道',
            subtitle: 'D40：自动拉取模型列表 · 自动选可用模型 · 失败自动换模型/换商',
          ),
          const SizedBox(height: AppTokens.s12),
          for (final AiProviderView view in providers.take(8)) ...<Widget>[
            _row(context, theme, view),
            const Divider(height: 14),
          ],
          Text(
            'Key 仅保存在本机工作区（AES-256-GCM 加密）；未配置时自动使用本地引擎。',
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, ThemeData theme, AiProviderView view) {
    final bool expanded = _expanded.contains(view.preset.id);
    final TextEditingController key = _keys.putIfAbsent(
      view.preset.id,
      () => TextEditingController(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: view.hasKey
                    ? (view.enabled ? AppTokens.success : AppTokens.warning)
                    : theme.colorScheme.outline,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${view.preset.name}'
                    '${view.hasKey ? ' · ${view.maskedKey}' : ''}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    view.models.isEmpty
                        ? '模型：${view.model.isEmpty ? '未选择（生成时自动探测）' : view.model}'
                        : '模型：${view.model} · 已发现 ${view.models.length} 个',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: '上移优先级',
              icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 18),
              onPressed: () => ref
                  .read(aiControllerProvider.notifier)
                  .movePriority(view.preset.id, -1),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: '下移优先级',
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
              onPressed: () => ref
                  .read(aiControllerProvider.notifier)
                  .movePriority(view.preset.id, 1),
            ),
            SsButton(
              label: _fetching.contains(view.preset.id) ? '拉取中…' : '拉模型',
              dense: true,
              kind: SsButtonKind.ghost,
              onPressed: view.hasKey && !_fetching.contains(view.preset.id)
                  ? () => _fetch(view.preset.id)
                  : null,
            ),
            const SizedBox(width: 4),
            SsButton(
              label: expanded ? '收起' : '配置',
              dense: true,
              kind: SsButtonKind.ghost,
              onPressed: () => setState(() {
                if (!_expanded.remove(view.preset.id)) {
                  _expanded.add(view.preset.id);
                }
              }),
            ),
          ],
        ),
        if (expanded) ...<Widget>[
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: key,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: view.hasKey
                        ? '已保存（重新输入可覆盖）'
                        : view.preset.keyHint,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SsButton(
                label: '保存',
                dense: true,
                onPressed: () async {
                  await ref
                      .read(aiControllerProvider.notifier)
                      .saveProvider(
                        view.preset,
                        apiKey: key.text.trim(),
                        model: view.model,
                        baseUrl: view.preset.baseUrl,
                        enabled: true,
                      );
                  key.clear();
                  if (mounted) {
                    ssToast(this.context, '已保存并启用 ${view.preset.name}');
                  }
                },
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// G6：图片素材通道（Pexels/TMDB Key）+ 开源素材许可页。
class _AssetSourcesCard extends ConsumerStatefulWidget {
  const _AssetSourcesCard();

  @override
  ConsumerState<_AssetSourcesCard> createState() => _AssetSourcesCardState();
}

class _AssetSourcesCardState extends ConsumerState<_AssetSourcesCard> {
  final TextEditingController _pexels = TextEditingController();
  final TextEditingController _tmdb = TextEditingController();
  final TextEditingController _europeana = TextEditingController();
  final TextEditingController _smithsonian = TextEditingController();
  final TextEditingController _harvard = TextEditingController();
  final TextEditingController _rijks = TextEditingController();
  final TextEditingController _cacheLimit = TextEditingController();
  final TextEditingController _proxy = TextEditingController();
  final TextEditingController _packDir = TextEditingController();
  final TextEditingController _gearDir = TextEditingController();
  final TextEditingController _gearCacheLimit = TextEditingController();
  Set<String> _gearSources = <String>{'builtin', 'official', 'jd', 'keyword'};
  List<Map<String, Object?>> _attribution = <Map<String, Object?>>[];
  bool _showLicense = false;
  String _netMode = 'auto';
  bool _probing = false;
  List<String> _probeResults = <String>[];
  int _cacheBytes = 0;
  int _cacheFiles = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((Duration _) async {
      final AppDatabase db = ref.read(databaseProvider);
      final String? p = await db.getSetting('image_pexels_key');
      final String? t = await db.getSetting('image_tmdb_key');
      final String eu = await db.getSetting('search_key_europeana') ?? '';
      final String si = await db.getSetting('search_key_smithsonian') ?? '';
      final String ha = await db.getSetting('search_key_harvard') ?? '';
      final String rk = await db.getSetting('search_key_rijks') ?? '';
      final String cacheLimit =
          await db.getSetting(SearchCache.limitSettingKey) ?? '';
      final String proxy = await db.getSetting('proxy_url') ?? '';
      final String pack = await db.getSetting('user_pack_dir') ?? '';
      final String gear = await db.getSetting('gear_image_dir') ?? '';
      final String gearLimit = await db.getSetting('gear_cache_limit_mb') ?? '';
      final String gearSources = await db.getSetting('gear_sync_sources') ?? '';
      final String netMode = await db.getSetting('net_mode') ?? 'auto';
      final NetConfig defaults = await loadNetConfig();
      final List<Map<String, Object?>> items = await _loadAttribution();
      final SearchCache cache = await SearchCache.from(
        db,
        ref.read(workspaceProvider).root.path,
      );
      final int bytes = await cache.totalBytes();
      final int files = await cache.fileCount();
      if (!mounted) return;
      setState(() {
        _pexels.text = (p ?? '').isNotEmpty ? p! : defaults.pexelsKey;
        _tmdb.text = (t ?? '').isNotEmpty ? t! : defaults.tmdbKey;
        _europeana.text = eu;
        _smithsonian.text = si;
        _harvard.text = ha;
        _rijks.text = rk;
        _cacheLimit.text = cacheLimit.isEmpty
            ? '${SearchCache.defaultLimitMb}'
            : cacheLimit;
        _proxy.text = proxy;
        _packDir.text = pack;
        _gearDir.text = gear;
        _gearCacheLimit.text = gearLimit.isEmpty
            ? GearPhotoSync.defaultCacheLimitMb
            : gearLimit;
        _gearSources = _parseGearSources(gearSources);
        _netMode = netMode;
        _attribution = items;
        _cacheBytes = bytes;
        _cacheFiles = files;
      });
    });
  }

  /// 网络通道测速（D79）：Pexels 直连 + TMDB（经隧道/代理）。
  Future<void> _probeNetwork() async {
    setState(() {
      _probing = true;
      _probeResults = <String>[];
    });
    final NetRouter router = NetRouter.I;
    final List<String> out = <String>[];
    out.add('通道：${router.modeLabel}');
    final (bool ok1, int ms1, String d1) = await router.probe(
      'https://api.pexels.com/v1/search?query=portrait&per_page=1',
    );
    out.add('Pexels API：${ok1 ? '可用' : '失败'} · ${ms1}ms${ok1 ? '' : ' · $d1'}');
    final (bool ok2, int ms2, String d2) = await router.probe(
      'https://api.themoviedb.org/3/configuration?api_key=probe',
    );
    out.add(
      'TMDB API：${ok2 ? '可用' : '失败'} · ${ms2}ms'
      '${ok2 ? '（${d2.contains('401') || d2.contains('200') ? '已连通' : ''}）' : ' · $d2'}',
    );
    final (bool ok3, int ms3, String d3) = await router.probe(
      'https://image.tmdb.org/t/p/w92/8CdXyOlgb3vJzWqBQhQnQ0kZ8rY.jpg',
    );
    out.add('TMDB 图床：${ok3 ? '可用' : '失败'} · ${ms3}ms${ok3 ? '' : ' · $d3'}');
    if (!mounted) return;
    setState(() {
      _probing = false;
      _probeResults = out;
    });
  }

  Future<List<Map<String, Object?>>> _loadAttribution() async {
    try {
      final String raw = await rootBundle.loadString(
        'assets/content/attribution.json',
      );
      final Map<String, Object?> data = (jsonDecode(raw) as Map)
          .cast<String, Object?>();
      return (data['items'] as List<Object?>? ?? <Object?>[])
          .whereType<Map>()
          .map((Map m) => m.cast<String, Object?>())
          .toList();
    } catch (_) {
      return <Map<String, Object?>>[];
    }
  }

  @override
  void dispose() {
    _pexels.dispose();
    _tmdb.dispose();
    _europeana.dispose();
    _smithsonian.dispose();
    _harvard.dispose();
    _rijks.dispose();
    _cacheLimit.dispose();
    _proxy.dispose();
    _packDir.dispose();
    _gearDir.dispose();
    _gearCacheLimit.dispose();
    super.dispose();
  }

  /// 器材图同步源开关（D130/D131）：空/非法值回落默认集合。
  Set<String> _parseGearSources(String raw) {
    const Set<String> defaults = <String>{
      'builtin',
      'official',
      'jd',
      'keyword',
    };
    if (raw.trim().isEmpty) return Set<String>.from(defaults);
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is List) {
        final Set<String> out = decoded.map((Object? e) => '$e').toSet();
        return out.isEmpty ? Set<String>.from(defaults) : out;
      }
    } catch (_) {}
    return Set<String>.from(defaults);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SsSectionTitle(
            '图片素材通道',
            subtitle:
                'V6：搜图工作台 Key（Pexels/TMDB）+ 免 Key 博物馆（Met/芝加哥/克利夫兰/V&A/WikiArt/Artvee/AniList）+ Key 预留源',
          ),
          const SizedBox(height: AppTokens.s12),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _pexels,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Pexels API Key（可空）',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: _tmdb,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'TMDB API Key（可空）',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SsButton(
                label: '保存',
                dense: true,
                onPressed: () async {
                  final AppDatabase db = ref.read(databaseProvider);
                  await db.setSetting('image_pexels_key', _pexels.text.trim());
                  await db.setSetting('image_tmdb_key', _tmdb.text.trim());
                  await db.setSetting(
                    'search_key_europeana',
                    _europeana.text.trim(),
                  );
                  await db.setSetting(
                    'search_key_smithsonian',
                    _smithsonian.text.trim(),
                  );
                  await db.setSetting(
                    'search_key_harvard',
                    _harvard.text.trim(),
                  );
                  await db.setSetting('search_key_rijks', _rijks.text.trim());
                  final int cacheMb =
                      int.tryParse(_cacheLimit.text.trim()) ??
                      SearchCache.defaultLimitMb;
                  await db.setSetting(
                    SearchCache.limitSettingKey,
                    '${cacheMb < 0 ? 0 : cacheMb}',
                  );
                  await db.setSetting('proxy_url', _proxy.text.trim());
                  await db.setSetting('user_pack_dir', _packDir.text.trim());
                  await db.setSetting('gear_image_dir', _gearDir.text.trim());
                  await db.setSetting(
                    'gear_cache_limit_mb',
                    '${int.tryParse(_gearCacheLimit.text.trim()) ?? int.tryParse(GearPhotoSync.defaultCacheLimitMb) ?? 2048}',
                  );
                  await db.setSetting(
                    'gear_sync_sources',
                    jsonEncode(_gearSources.toList()),
                  );
                  await db.setSetting('net_mode', _netMode);
                  await NetRouter.I.configure(
                    userProxy: _proxy.text.trim(),
                    autoTunnel: _netMode != 'direct',
                    forceDirect: _netMode == 'direct',
                  );
                  if (mounted) {
                    ssToast(this.context, '已保存（网络通道：${NetRouter.I.modeLabel}）');
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _europeana,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Europeana Key（可空，填入即启用）',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: _smithsonian,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Smithsonian Key（可空）',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _harvard,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Harvard Art Museums Key（可空）',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: _rijks,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Rijksmuseum Key（可空）',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              SizedBox(
                width: 160,
                child: TextField(
                  controller: _cacheLimit,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '搜图缓存上限（MB）',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '当前 ${(_cacheBytes / (1024 * 1024)).toStringAsFixed(1)}MB / '
                '$_cacheFiles 个文件（LRU，超限自动淘汰）',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              SsButton(
                label: '清空搜图缓存',
                kind: SsButtonKind.ghost,
                dense: true,
                onPressed: () async {
                  final AppDatabase db = ref.read(databaseProvider);
                  final SearchCache cache = await SearchCache.from(
                    db,
                    ref.read(workspaceProvider).root.path,
                  );
                  await cache.clear();
                  if (!mounted) return;
                  setState(() {
                    _cacheBytes = 0;
                    _cacheFiles = 0;
                  });
                  ssToast(this.context, '搜图缓存已清空');
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _proxy,
            decoration: const InputDecoration(
              labelText: '网络代理（http://127.0.0.1:7890，可空；留空时自动使用 DoH 隧道）',
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                '网络通道',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              for (final (String id, String label) in <(String, String)>[
                ('auto', '自动（DoH 隧道）'),
                ('direct', '强制直连'),
                ('proxy', '使用代理'),
              ])
                SsChip(
                  label: label,
                  selected: _netMode == id,
                  onTap: () => setState(() => _netMode = id),
                ),
              SsButton(
                label: _probing ? '测速中…' : '通道测速',
                kind: SsButtonKind.ghost,
                dense: true,
                onPressed: _probing ? null : _probeNetwork,
              ),
            ],
          ),
          if (_probeResults.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            for (final String line in _probeResults)
              Text(
                line,
                style: TextStyle(fontSize: 11, color: AppTokens.lightMuted),
              ),
          ],
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _packDir,
                  decoration: const InputDecoration(
                    labelText: '我的素材包目录（放入剧照/动漫截图，启动自动索引）',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SsButton(
                label: '选择',
                dense: true,
                kind: SsButtonKind.ghost,
                onPressed: () async {
                  final String? dir = await FilePicker.platform
                      .getDirectoryPath(dialogTitle: '选择我的素材包目录');
                  if (dir == null) return;
                  setState(() => _packDir.text = dir);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _gearDir,
                  decoration: const InputDecoration(
                    labelText: '器材官方图目录（“型号.jpg”命名，自动匹配设备库）',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SsButton(
                label: '选择',
                dense: true,
                kind: SsButtonKind.ghost,
                onPressed: () async {
                  final String? dir = await FilePicker.platform
                      .getDirectoryPath(dialogTitle: '选择器材图目录');
                  if (dir == null) return;
                  setState(() => _gearDir.text = dir);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '器材图同步源（官网 > 京东 > 亚马逊 > 淘宝 > 开放图源；D130）',
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: <Widget>[
              for (final (String key, String label) in <(String, String)>[
                ('builtin', '内置/运行时'),
                ('official', '官网'),
                ('jd', '京东'),
                ('amazon', '亚马逊'),
                ('taobao', '淘宝'),
                ('keyword', '开放图源'),
              ])
                SsChip(
                  label: label,
                  selected: _gearSources.contains(key),
                  onTap: () => setState(() {
                    if (!_gearSources.remove(key)) _gearSources.add(key);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 260,
            child: TextField(
              controller: _gearCacheLimit,
              decoration: const InputDecoration(
                labelText: '器材图缓存上限（MB，按最早访问清理）',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              SsButton(
                label: _showLicense
                    ? '收起许可清单'
                    : '开源与素材许可（${_attribution.length}）',
                kind: SsButtonKind.ghost,
                dense: true,
                onPressed: () => setState(() => _showLicense = !_showLicense),
              ),
              const SizedBox(width: 6),
              Text(
                _attribution.isEmpty
                    ? '当前版本内置素材为程序生成插画（无需署名）'
                    : '真实图片素材逐条署名（Wikimedia CC0/PD/CC BY）',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (_showLicense) ...<Widget>[
            const SizedBox(height: 6),
            if (_attribution.isEmpty)
              const Text('（无第三方真实图片素材）', style: TextStyle(fontSize: 11.5))
            else
              for (final Map<String, Object?> item in _attribution)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    '· ${item['name']} · ${item['license']} · ${item['author']}\n  ${item['source']}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

/// V7/D135：显卡设置（DXGI 枚举 + 3D 引擎独显优先 + 识别后端）。
class _GpuCard extends ConsumerStatefulWidget {
  const _GpuCard();

  @override
  ConsumerState<_GpuCard> createState() => _GpuCardState();
}

class _GpuCardState extends ConsumerState<_GpuCard> {
  List<GpuAdapter> _adapters = <GpuAdapter>[];
  String _mode = 'auto';
  String _backend = 'cpu';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final AppDatabase db = ref.read(databaseProvider);
    final List<GpuAdapter> adapters = await GpuService.adapters(refresh: true);
    final String mode =
        await db.getSetting('gpu_mode') ?? GpuService.readModeSync();
    final String backend =
        await db.getSetting('gpu_recognize_backend') ?? 'cpu';
    if (!mounted) return;
    setState(() {
      _adapters = adapters;
      _mode = GpuService.modes.contains(mode) ? mode : 'auto';
      _backend = GpuService.recognizeBackends.contains(backend)
          ? backend
          : 'cpu';
      _loading = false;
    });
  }

  Future<void> _save() async {
    final AppDatabase db = ref.read(databaseProvider);
    await db.setSetting('gpu_mode', _mode);
    await db.setSetting('gpu_recognize_backend', _backend);
    await GpuService.writeMode(_mode);
    // 热切：请求引擎重建 WebView（WebView2 参数在环境创建时读取）。
    requestEngineReload();
    if (!mounted) return;
    ssToast(context, '已保存并请求引擎热重载；若渲染器未切换，请重启应用（识别后端下次识别生效）');
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle small = TextStyle(
      fontSize: 11,
      color: theme.colorScheme.onSurfaceVariant,
    );
    return SsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SsSectionTitle(
            '显卡',
            subtitle: 'V7/D135：DXGI 枚举 · 3D 引擎独显优先 · 端上识别后端',
          ),
          const SizedBox(height: AppTokens.s12),
          if (_loading)
            const LinearProgressIndicator(minHeight: 2)
          else ...<Widget>[
            if (_adapters.isEmpty)
              Text('未检测到适配器（非 Windows 或通道不可用）', style: small)
            else
              for (final GpuAdapter a in _adapters)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.memory_rounded,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${a.name}（${a.vendorLabel} · ${a.kindLabel} · ${a.memoryLabel}）',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5),
                        ),
                      ),
                    ],
                  ),
                ),
            const SizedBox(height: 6),
            Text('3D 引擎（WebView2）', style: small),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: <Widget>[
                for (final String mode in GpuService.modes)
                  SsChip(
                    label: GpuService.modeLabels[mode] ?? mode,
                    selected: _mode == mode,
                    onTap: () => setState(() => _mode = mode),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text('端上识别后端（D141 高精度模式）', style: small),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: <Widget>[
                SsChip(
                  label: 'CPU',
                  selected: _backend == 'cpu',
                  onTap: () => setState(() => _backend = 'cpu'),
                ),
                SsChip(
                  label: 'GPU（独显 / DirectML）',
                  selected: _backend == 'gpu',
                  onTap: () => setState(() => _backend = 'gpu'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<String>(
              valueListenable: engineGpuRenderer,
              builder: (BuildContext _, String renderer, Widget? _) => Text(
                renderer.isEmpty
                    ? '当前引擎 GPU：未报告（打开布光预演后更新）'
                    : '当前引擎 GPU：$renderer',
                style: small,
              ),
            ),
            const SizedBox(height: 8),
            SsButton(label: '保存并应用', dense: true, onPressed: _save),
          ],
        ],
      ),
    );
  }
}
