import 'dart:convert';
import 'package:path/path.dart' as p;
import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/design/widgets.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/json_utils.dart';
import '../../services/content_packs.dart';
import '../../services/gear_photo_sync.dart';
import '../lighting/lighting_controller.dart';

/// 设备数据库浏览（D19/D20）：相机 / 镜头 / 灯具；灯具可一键放入布光场景。
final gearListProvider = FutureProvider.autoDispose<List<GearEntry>>(
  (ref) async {
    final List<GearEntry> builtin = await ContentPacks.gear();
    final AppDatabase db = ref.watch(databaseProvider);
    final List<GearItem> rows = await db.select(db.gearItems).get();
    final List<GearEntry> custom = rows
        .where((GearItem r) => !r.builtin)
        .map((GearItem r) => GearEntry(
              id: r.id,
              kind: r.kind,
              brand: r.brand,
              model: r.model,
              mount: r.mount,
              specs: asMap(jsonDecode(r.specsJson)),
              priceRef: r.priceRef ?? 0,
              imageSource: 'custom',
            ))
        .toList();
    return <GearEntry>[...builtin, ...custom];
  },
);

final clothingCatalogProvider =
    FutureProvider.autoDispose<List<ClothingCategoryEntry>>(
  (ref) => ContentPacks.clothingCategories(),
);

final propPresetsProvider = FutureProvider.autoDispose<List<PropPresetEntry>>(
  (ref) => ContentPacks.propPresets(),
);

/// V3：器材实拍（Pexels 缓存 + 用户按型号导入目录）。
final gearPhotosProvider = FutureProvider.autoDispose<Map<String, Object?>>(
  (ref) async {
    final Map<String, Object?> bundled = await ContentPacks.gearPhotos();
    final Map<String, Object?> out = <String, Object?>{
      'byKind': bundled['byKind'] ?? <String, Object?>{},
      'byModel': <String, Object?>{
        ...(bundled['byModel'] as Map? ?? <String, Object?>{})
      },
    };
    try {
      final AppDatabase db = ref.watch(databaseProvider);
      final String dir = await db.getSetting('gear_image_dir') ?? '';
      if (dir.isNotEmpty) {
        final Directory directory = Directory(dir);
        if (await directory.exists()) {
          final Map<String, Object?> byModel =
              (out['byModel'] as Map).cast<String, Object?>();
          await for (final FileSystemEntity entity
              in directory.list(recursive: true)) {
            if (entity is! File) continue;
            final String name = p.basenameWithoutExtension(entity.path);
            byModel[name] = <Object?>[
              <String, Object?>{
                'file': entity.path,
                'absolute': true,
                'photographer': '用户导入',
                'photoUrl': '',
              },
            ];
          }
        }
      }
    } catch (_) {
      // 用户目录不可读时忽略。
    }
    return out;
  },
);

/// V4：规范化产品图目录（assets/content/gear/gear_photos2.json，D71–D73）。
final gearPhotos2Provider = FutureProvider.autoDispose<Map<String, Object?>>(
  (ref) => GearPhotoSync.catalog(),
);

/// 从 gear_photos2.json 目录中取该设备的产品图条目（byId 优先，byModel 兜底）。
Map<String, Object?>? gearPhotoEntryOf(
    Map<String, Object?>? catalog, GearEntry entry) {
  if (catalog == null) return null;
  final Object? byIdRaw = catalog['byId'];
  if (byIdRaw is Map) {
    final Object? rec = byIdRaw[entry.id];
    if (rec is Map) return rec.cast<String, Object?>();
  }
  final Object? byModelRaw = catalog['byModel'];
  if (byModelRaw is Map) {
    final Object? rec = byModelRaw[entry.displayName];
    if (rec is Map) return rec.cast<String, Object?>();
  }
  return null;
}

/// 用户目录导入的实拍图（绝对路径优先，来自旧 provider 的合并结果）。
Map<String, Object?>? gearUserPhotoOf(
    Map<String, Object?>? photos, GearEntry entry) {
  final Object? raw = (photos?['byModel'] as Map?)?[entry.displayName];
  if (raw is! List) return null;
  for (final Object? item in raw) {
    if (item is Map && item['absolute'] == true) {
      return item.cast<String, Object?>();
    }
  }
  return null;
}

/// 产品图来源标注（D71）：
/// tier=product → 「摄影·许可」；tier=series → 「同系列示意·非该型号」。
String gearPhotoLabel(Map<String, Object?>? photo2) {
  if (photo2 == null) return '';
  final String tier = '${photo2['tier'] ?? ''}';
  if (tier == 'series') return '同系列示意·非该型号';
  if (tier == 'atmosphere') return '氛围实拍·非该型号';
  final String license = '${photo2['license'] ?? ''}'.trim();
  return '摄影·${license.isEmpty ? '许可' : license}';
}

/// 详情署名（摄影者 · 许可 · 来源）。
String gearPhotoCredit(Map<String, Object?>? photo2) {
  if (photo2 == null) return '';
  final String author = '${photo2['author'] ?? ''}'.trim();
  final String license = '${photo2['license'] ?? ''}'.trim();
  final String source = '${photo2['source'] ?? ''}'.trim();
  final List<String> parts = <String>[
    if (author.isNotEmpty) '摄影：$author',
    if (license.isNotEmpty) license,
    if (source.isNotEmpty) source,
  ];
  return parts.join(' · ');
}

/// V3：服装参考实拍（Pexels 按类目缓存）。
final clothingPhotosProvider = FutureProvider.autoDispose<Map<String, Object?>>(
  (ref) => ContentPacks.clothingPhotos(),
);

/// 设备库视图。
class GearBrowser extends ConsumerStatefulWidget {
  const GearBrowser({super.key});

  @override
  ConsumerState<GearBrowser> createState() => _GearBrowserState();
}

class _GearBrowserState extends ConsumerState<GearBrowser> {
  String _kind = 'camera';
  String _keyword = '';
  String _sort = '默认';
  bool _syncing = false;

  @override
  Widget build(BuildContext context) {
    final gear = ref.watch(gearListProvider);
    return gear.when(
      data: (List<GearEntry> items) {
        final List<String> tokens = _keyword
            .toLowerCase()
            .split(RegExp(r'\\s+'))
            .where((String t) => t.isNotEmpty)
            .toList();
        final List<GearEntry> filtered = items
            .where((GearEntry g) => g.kind == _kind)
            .where((GearEntry g) =>
                tokens.isEmpty ||
                tokens.every((String t) => g.searchText.contains(t)))
            .toList();
        switch (_sort) {
          case '价格↑':
            filtered.sort(
                (GearEntry a, GearEntry b) => a.priceRef.compareTo(b.priceRef));
          case '价格↓':
            filtered.sort(
                (GearEntry a, GearEntry b) => b.priceRef.compareTo(a.priceRef));
          case '名称':
            filtered.sort((GearEntry a, GearEntry b) =>
                a.displayName.compareTo(b.displayName));
          default:
            break;
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                for (final (String kind, String label) in <(String, String)>[
                  ('camera', '相机机身'),
                  ('lens', '镜头'),
                  ('light', '灯具'),
                  ('accessory', '附件'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: SsChip(
                      label:
                          '$label（${items.where((GearEntry g) => g.kind == kind).length}）',
                      selected: _kind == kind,
                      onTap: () => setState(() => _kind = kind),
                    ),
                  ),
                const Spacer(),
                SsButton(
                  label: _syncing ? '同步中…' : '同步器材图',
                  dense: true,
                  kind: SsButtonKind.ghost,
                  icon: Icons.sync_rounded,
                  onPressed: _syncing ? null : () => _syncPhotos(context, ref),
                ),
                const SizedBox(width: 6),
                SsButton(
                  label: '添加设备',
                  dense: true,
                  kind: SsButtonKind.ghost,
                  onPressed: () => _showAddDialog(context, ref),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 200,
                  child: TextField(
                    decoration: const InputDecoration(
                        hintText: '品牌/型号/焦段/F2.8/CRI', isDense: true),
                    onChanged: (String v) => setState(() => _keyword = v),
                  ),
                ),
                const SizedBox(width: 6),
                DropdownButton<String>(
                  value: _sort,
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  items: <DropdownMenuItem<String>>[
                    for (final String v in <String>['默认', '价格↑', '价格↓', '名称'])
                      DropdownMenuItem<String>(
                          value: v,
                          child: Text(v, style: const TextStyle(fontSize: 12))),
                  ],
                  onChanged: (String? v) => setState(() => _sort = v ?? '默认'),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.s8),
            Expanded(
              child: filtered.isEmpty
                  ? const SsEmpty(
                      icon: Icons.camera_alt_outlined, title: '没有匹配的设备')
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 240,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1.7,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (BuildContext context, int i) =>
                          _GearCard(entry: filtered[i]),
                    ),
            ),
            Text(
              '参数与参考价为参考值 · 灯具可一键放入布光预演 3D 场景（含真实光型参数）',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      },
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
      error: (Object e, _) =>
          SsEmpty(icon: Icons.error_outline_rounded, title: '加载失败', hint: '$e'),
    );
  }

  /// V4/D73：运行时同步未内置或氛围实拍条目（Dio + 设置页代理）。
  Future<void> _syncPhotos(BuildContext context, WidgetRef ref) async {
    setState(() => _syncing = true);
    final AppDatabase db = ref.read(databaseProvider);
    final ValueNotifier<(int, int)> progress =
        ValueNotifier<(int, int)>((0, 0));
    final Future<void> dialog = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('同步器材图', style: TextStyle(fontSize: 15)),
        content: ValueListenableBuilder<(int, int)>(
          valueListenable: progress,
          builder: (BuildContext c, (int, int) v, Widget? _) =>
              Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            LinearProgressIndicator(
              value: v.$2 == 0 ? null : v.$1 / v.$2,
              minHeight: 6,
            ),
            const SizedBox(height: 10),
            Text(
              '正在下载 ${v.$1}/${v.$2} · 已内置条目自动跳过',
              style: const TextStyle(fontSize: 12),
            ),
          ]),
        ),
      ),
    );
    int downloaded = 0;
    Object? error;
    try {
      downloaded = await GearPhotoSync.syncAll(
        db: db,
        onProgress: (int done, int total) => progress.value = (done, total),
      );
    } catch (e) {
      error = e;
    }
    if (context.mounted) Navigator.of(context).pop();
    await dialog;
    if (!context.mounted) return;
    setState(() => _syncing = false);
    if (error != null) {
      ssToast(context, '同步失败：$error');
    } else if (downloaded == 0) {
      ssToast(context, '器材图已就绪（内置或已缓存）');
    } else {
      ssToast(context, '同步完成：新增 $downloaded 张器材图');
    }
  }
}

Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
  final TextEditingController brand = TextEditingController();
  final TextEditingController model = TextEditingController();
  final TextEditingController mount = TextEditingController();
  final TextEditingController price = TextEditingController();
  String kind = 'camera';
  final bool? saved = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => StatefulBuilder(
      builder: (BuildContext ctx, StateSetter setLocal) => AlertDialog(
        title: const Text('添加自定义设备', style: TextStyle(fontSize: 16)),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DropdownButtonFormField<String>(
                initialValue: kind,
                decoration:
                    const InputDecoration(labelText: '类型', isDense: true),
                items: <DropdownMenuItem<String>>[
                  for (final (String k, String label) in <(String, String)>[
                    ('camera', '相机机身'),
                    ('lens', '镜头'),
                    ('light', '灯具'),
                    ('accessory', '附件'),
                  ])
                    DropdownMenuItem<String>(
                        value: k,
                        child:
                            Text(label, style: const TextStyle(fontSize: 13))),
                ],
                onChanged: (String? v) => setLocal(() => kind = v ?? kind),
              ),
              TextField(
                controller: brand,
                decoration:
                    const InputDecoration(labelText: '品牌', isDense: true),
              ),
              TextField(
                controller: model,
                decoration:
                    const InputDecoration(labelText: '型号', isDense: true),
              ),
              TextField(
                controller: mount,
                decoration:
                    const InputDecoration(labelText: '卡口（可空）', isDense: true),
              ),
              TextField(
                controller: price,
                decoration:
                    const InputDecoration(labelText: '参考价（可空）', isDense: true),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          SsButton(
            label: '保存',
            onPressed: () async {
              if (brand.text.trim().isEmpty || model.text.trim().isEmpty) {
                ssToast(ctx, '品牌与型号必填');
                return;
              }
              final AppDatabase db = ref.read(databaseProvider);
              final int now = DateTime.now().millisecondsSinceEpoch;
              await db.into(db.gearItems).insertOnConflictUpdate(
                    GearItemsCompanion.insert(
                      id: 'custom-$now',
                      kind: kind,
                      brand: brand.text.trim(),
                      model: model.text.trim(),
                      mount: Value(mount.text.trim()),
                      specsJson: const Value('{"type":"自定义"}'),
                      priceRef: Value(double.tryParse(price.text.trim()) ?? 0),
                      builtin: const Value(false),
                    ),
                  );
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
          ),
        ],
      ),
    ),
  );
  if (saved == true) {
    ref.invalidate(gearListProvider);
    if (context.mounted) ssToast(context, '已添加自定义设备');
  }
}

class _GearCard extends ConsumerWidget {
  const _GearCard({required this.entry});

  final GearEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Map<String, Object?>? photos =
        ref.watch(gearPhotosProvider).valueOrNull;
    final Map<String, Object?>? catalog =
        ref.watch(gearPhotos2Provider).valueOrNull;
    final Map<String, Object?>? photo2 = gearPhotoEntryOf(catalog, entry);
    final Map<String, Object?>? userPhoto = gearUserPhotoOf(photos, entry);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double t, Widget? child) => Opacity(
          opacity: t,
          child: Transform.translate(
              offset: Offset(0, 10 * (1 - t)), child: child)),
      child: SsCard(
        padding: const EdgeInsets.all(10),
        onTap: () => _showDetail(context, ref),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                _thumb(entry, photo2, userPhoto),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        entry.brand,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        entry.model,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              entry.specSummary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTokens.mono(context, size: 10),
            ),
            Text(
              '参考 ¥${entry.priceRef.toStringAsFixed(0)}'
              '${entry.imageSource == 'custom' ? ' · 自定义' : ''}',
              style: const TextStyle(fontSize: 11, color: AppTokens.accent),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示优先级（V4）：内置 photo2 → 用户目录 → 运行时缓存 → 插画。
  Widget _thumb(GearEntry entry, Map<String, Object?>? photo2,
      Map<String, Object?>? user) {
    final List<Widget Function(Widget Function())> chain =
        _photoChain(entry, photo2, user, fit: BoxFit.cover, width: 54);
    final String label = photo2 != null
        ? gearPhotoLabel(photo2)
        : (user != null
            ? '用户导入'
            : (GearPhotoSync.localPathFor(entry.id) != null
                ? '已同步'
                : (chain.isEmpty ? '缺图·插画' : '已同步')));
    if (chain.isEmpty) {
      return Column(
        children: <Widget>[
          Expanded(child: _illustration(entry)),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 8.5),
          ),
        ],
      );
    }
    return Column(
      children: <Widget>[
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _firstAvailable(chain, fallback: _illustration(entry)),
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 8.5),
        ),
      ],
    );
  }

  List<Widget Function(Widget Function())> _photoChain(
    GearEntry entry,
    Map<String, Object?>? photo2,
    Map<String, Object?>? user, {
    required BoxFit fit,
    double? width,
    double? height,
  }) {
    final List<Widget Function(Widget Function())> chain =
        <Widget Function(Widget Function())>[];
    if (photo2 != null && photo2['bundled'] != false) {
      final String? asset = GearPhotoSync.assetPath(photo2);
      if (asset != null) {
        chain.add((Widget Function() onError) => Image.asset(asset,
            fit: fit,
            width: width,
            height: height,
            errorBuilder: (_, __, ___) => onError()));
      }
    }
    final String userFile =
        user?['absolute'] == true ? '${user?['file'] ?? ''}' : '';
    if (userFile.isNotEmpty) {
      chain.add((Widget Function() onError) => Image.file(File(userFile),
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (_, __, ___) => onError()));
    }
    final String? local = GearPhotoSync.localPathFor(entry.id);
    if (local != null) {
      chain.add((Widget Function() onError) => Image.file(File(local),
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (_, __, ___) => onError()));
    }
    return chain;
  }

  Widget _firstAvailable(List<Widget Function(Widget Function())> chain,
      {Widget? fallback}) {
    Widget build(int i) {
      if (i >= chain.length) return fallback ?? _fallbackBox();
      return chain[i](() => build(i + 1));
    }

    return build(0);
  }

  Widget _illustration(GearEntry entry) {
    if (entry.imageSource == 'custom' || entry.image.isEmpty) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppTokens.accentSoft,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.camera_alt_outlined,
            size: 20, color: AppTokens.accent),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        'assets/content/gear/img/${entry.image}',
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        errorBuilder: (BuildContext c, Object e, StackTrace? s) =>
            _fallbackBox(),
      ),
    );
  }

  void _showDetail(BuildContext context, WidgetRef ref) {
    final Map<String, Object?>? photos =
        ref.read(gearPhotosProvider).valueOrNull;
    final Map<String, Object?>? catalog =
        ref.read(gearPhotos2Provider).valueOrNull;
    final Map<String, Object?>? photo2 = gearPhotoEntryOf(catalog, entry);
    final Map<String, Object?>? userPhoto = gearUserPhotoOf(photos, entry);
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(entry.displayName, style: const TextStyle(fontSize: 15)),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (_photoChain(entry, photo2, userPhoto,
                      fit: BoxFit.contain, height: 150)
                  .isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        width: 400,
                        height: 150,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: _firstAvailable(_photoChain(
                              entry, photo2, userPhoto,
                              fit: BoxFit.contain, height: 150)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        photo2 != null
                            ? gearPhotoLabel(photo2)
                            : (userPhoto != null
                                ? '用户导入（设置页「器材图目录」）'
                                : '运行时同步缓存（工作区 images/gear）'),
                        style: const TextStyle(fontSize: 10.5),
                      ),
                      if (photo2 != null && gearPhotoCredit(photo2).isNotEmpty)
                        Text(
                          gearPhotoCredit(photo2),
                          style: TextStyle(
                            fontSize: 10,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      if (photo2 != null &&
                          '${photo2['note'] ?? ''}'.isNotEmpty)
                        Text(
                          '${photo2['note']}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTokens.accent,
                          ),
                        ),
                    ],
                  ),
                ),
              if (photo2 == null &&
                  userPhoto == null &&
                  entry.image.isNotEmpty &&
                  entry.imageSource != 'custom')
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/content/gear/img/${entry.image}',
                      height: 120,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              if (entry.tags.isNotEmpty) ...<Widget>[
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: <Widget>[
                    for (final String tag in entry.tags)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTokens.accentSoft,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(tag,
                            style: const TextStyle(
                                fontSize: 11, color: AppTokens.accent)),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              for (final MapEntry<String, Object?> spec in entry.specs.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: <Widget>[
                      SizedBox(
                        width: 110,
                        child: Text(
                          _specLabel(spec.key),
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Text('${spec.value}',
                          style: const TextStyle(fontSize: 12.5)),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                '参考价：¥${entry.priceRef.toStringAsFixed(0)}（内容包参考值，可自定义修正）',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          if (entry.kind == 'light')
            SsButton(
              label: '放入布光场景',
              icon: Icons.wb_incandescent_outlined,
              onPressed: () {
                ref.read(lightingControllerProvider.notifier).addLightFromGear(
                      name: entry.displayName,
                      powerW:
                          (entry.specs['power_w'] as num?)?.toDouble() ?? 100,
                      cct: '${entry.specs['cct'] ?? ''}',
                      cri: (entry.specs['cri'] as num?)?.toInt() ?? 95,
                      mount: entry.mount,
                      type: '${entry.specs['type'] ?? ''}',
                    );
                ssToast(context, '已放入布光场景：${entry.displayName}（到布光预演页查看）');
              },
            ),
          if (entry.imageSource == 'custom')
            TextButton(
              onPressed: () async {
                final AppDatabase db = ref.read(databaseProvider);
                await (db.delete(db.gearItems)
                      ..where((t) => t.id.equals(entry.id)))
                    .go();
                ref.invalidate(gearListProvider);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) ssToast(context, '已删除自定义设备');
              },
              child: const Text('删除'),
            ),
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
        ],
      ),
    );
  }

  Widget _fallbackBox() => Container(
        width: 54,
        color: AppTokens.accentSoft,
        child: const Icon(Icons.camera_alt_outlined, size: 20),
      );

  String _specLabel(String key) => switch (key) {
        'sensor' => '画幅',
        'megapixel' => '像素',
        'weight_g' => '重量',
        'series' => '系列',
        'focal' => '焦段',
        'aperture' => '光圈',
        'type' => '类型',
        'power_w' => '功率',
        'cct' => '色温',
        'cri' => '显色指数',
        _ => key,
      };
}

/// 服装目录（D21）：分类卡片 + 本地程序化示意图。
class ClothingCatalog extends ConsumerWidget {
  const ClothingCatalog({super.key, required this.onFilterLibrary});

  final void Function(String keyword) onFilterLibrary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(clothingCatalogProvider);
    final Map<String, Object?>? clothingPhotos =
        ref.watch(clothingPhotosProvider).valueOrNull;
    final Map<String, Object?> byCategory =
        ((clothingPhotos?['byCategory'] as Map?) ?? <String, Object?>{})
            .cast<String, Object?>();
    return catalog.when(
      data: (List<ClothingCategoryEntry> categories) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 260,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.3,
              ),
              itemCount: categories.length,
              itemBuilder: (BuildContext context, int i) {
                final ClothingCategoryEntry c = categories[i];
                return SsCard(
                  padding: EdgeInsets.zero,
                  onTap: () => onFilterLibrary(c.category),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            if ((byCategory[c.id] as List<Object?>? ??
                                    <Object?>[])
                                .isNotEmpty)
                              Image.asset(
                                'assets/content/clothing/photo/${c.id}/${((byCategory[c.id] as List)[0] as Map)['file']}',
                                fit: BoxFit.cover,
                                errorBuilder: (BuildContext ctx, Object e,
                                        StackTrace? st) =>
                                    const SizedBox.shrink(),
                              ),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: <Color>[
                                    _color(c.gradient.isNotEmpty
                                        ? c.gradient[0]
                                        : '#888888'),
                                    _color(c.gradient.length > 1
                                        ? c.gradient[1]
                                        : '#444444'),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                c.category,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  shadows: <Shadow>[
                                    Shadow(blurRadius: 8, color: Colors.black45)
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              c.examples.join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11.5),
                            ),
                            Text(
                              '点击在服装库中筛选',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Text(
            '示意图为本地程序化图案（免版权）；可在服装库中自定义上传实拍图',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
      error: (Object e, _) =>
          SsEmpty(icon: Icons.error_outline_rounded, title: '加载失败', hint: '$e'),
    );
  }

  Color _color(String hex) => Color(0xFF000000 |
      (int.tryParse(hex.replaceFirst('#', ''), radix: 16) ?? 0x888888));
}

/// 道具预设（D22）：含采购与分工字段，一键加入道具库。
class PropsPresetBrowser extends ConsumerWidget {
  const PropsPresetBrowser({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets = ref.watch(propPresetsProvider);
    return presets.when(
      data: (List<PropPresetEntry> items) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 240,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.6,
              ),
              itemCount: items.length,
              itemBuilder: (BuildContext context, int i) {
                final PropPresetEntry p = items[i];
                return SsCard(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(p.name,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        p.note,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '¥${p.price} · ${p.owner}',
                        style: const TextStyle(
                            fontSize: 11, color: AppTokens.accent),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Text(
            '道具预设已自动播种到道具库（含采购与分工字段），可直接在策划案「道具清单」模块中绑定',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
      error: (Object e, _) =>
          SsEmpty(icon: Icons.error_outline_rounded, title: '加载失败', hint: '$e'),
    );
  }
}
