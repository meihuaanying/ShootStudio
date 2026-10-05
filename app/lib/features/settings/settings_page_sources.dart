// V8/S9 · D158：资源来源卡片（网络探测 / 归属与许可 / 缓存统计）。
// 从 settings_page.dart 拆出（R73 行数门禁）；part 同库，私有成员无需公开化。
part of 'settings_page.dart';

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
      final String? saved = await db.getSetting('image_pexels_key');
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
        _pexels.text = (saved ?? '').isNotEmpty ? saved! : defaults.pexelsKey;
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
    final AppPalette p = context.palette;

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
          const SizedBox(height: AppSpace.s3),
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
                  fontSize: AppFontSize.caption,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              SsButton(
                label: '清空搜图缓存',
                kind: SsButtonKind.text,
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
                  fontSize: AppFontSize.smallSm,
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
                kind: SsButtonKind.text,
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
                style: TextStyle(
                  fontSize: AppFontSize.caption,
                  color: p.inkSoft,
                ),
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
                kind: SsButtonKind.text,
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
                kind: SsButtonKind.text,
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
              fontSize: AppFontSize.caption,
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
                kind: SsButtonKind.text,
                dense: true,
                onPressed: () => setState(() => _showLicense = !_showLicense),
              ),
              const SizedBox(width: 6),
              Text(
                _attribution.isEmpty
                    ? '当前版本内置素材为程序生成插画（无需署名）'
                    : '真实图片素材逐条署名（Wikimedia CC0/PD/CC BY）',
                style: TextStyle(
                  fontSize: AppFontSize.caption,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (_showLicense) ...<Widget>[
            const SizedBox(height: 6),
            if (_attribution.isEmpty)
              const Text(
                '（无第三方真实图片素材）',
                style: TextStyle(fontSize: AppFontSize.captionLg),
              )
            else
              for (final Map<String, Object?> item in _attribution)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    '· ${item['name']} · ${item['license']} · ${item['author']}\n  ${item['source']}',
                    style: const TextStyle(fontSize: AppFontSize.caption),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

/// V7/D135：显卡设置（DXGI 枚举 + 3D 引擎独显优先 + 识别后端）。
