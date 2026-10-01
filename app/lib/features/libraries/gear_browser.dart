import 'dart:convert';
import 'package:path/path.dart' as path;
import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/design/widgets.dart';
import '../../core/providers.dart';
import '../../core/utils/json_utils.dart';
import '../../services/content_packs.dart';
import '../../services/gear_photo_sync.dart';
import '../lighting/lighting_controller.dart';

part 'gear_browser_add.dart';
part 'gear_browser_card.dart';
part 'gear_browser_catalogs.dart';

/// 产品图免责声明（D130/R47）：资源库底部固定展示。
const String kGearPhotoDisclaimer = '产品图版权归原品牌/平台，仅供选型参考，禁止商用分发；许可与来源以标注为准。';

/// 设备数据库浏览（D19/D20）：相机 / 镜头 / 灯具；灯具可一键放入布光场景。
final gearListProvider = FutureProvider.autoDispose<List<GearEntry>>((
  ref,
) async {
  final List<GearEntry> builtin = await ContentPacks.gear();
  final AppDatabase db = ref.watch(databaseProvider);
  final List<GearItem> rows = await db.select(db.gearItems).get();
  final List<GearEntry> custom = rows
      .where((GearItem r) => !r.builtin)
      .map(
        (GearItem r) => GearEntry(
          id: r.id,
          kind: r.kind,
          brand: r.brand,
          model: r.model,
          mount: r.mount,
          specs: asMap(jsonDecode(r.specsJson)),
          priceRef: r.priceRef ?? 0,
          imageSource: 'custom',
        ),
      )
      .toList();
  return <GearEntry>[...builtin, ...custom];
});

final clothingCatalogProvider =
    FutureProvider.autoDispose<List<ClothingCategoryEntry>>(
      (ref) => ContentPacks.clothingCategories(),
    );

final propPresetsProvider = FutureProvider.autoDispose<List<PropPresetEntry>>(
  (ref) => ContentPacks.propPresets(),
);

/// V3：器材实拍（Pexels 缓存 + 用户按型号导入目录）。
final gearPhotosProvider = FutureProvider.autoDispose<Map<String, Object?>>((
  ref,
) async {
  final Map<String, Object?> bundled = await ContentPacks.gearPhotos();
  final Map<String, Object?> out = <String, Object?>{
    'byKind': bundled['byKind'] ?? <String, Object?>{},
    'byModel': <String, Object?>{
      ...(bundled['byModel'] as Map? ?? <String, Object?>{}),
    },
  };
  try {
    final AppDatabase db = ref.watch(databaseProvider);
    final String dir = await db.getSetting('gear_image_dir') ?? '';
    if (dir.isNotEmpty) {
      final Directory directory = Directory(dir);
      if (await directory.exists()) {
        final Map<String, Object?> byModel = (out['byModel'] as Map)
            .cast<String, Object?>();
        await for (final FileSystemEntity entity in directory.list(
          recursive: true,
        )) {
          if (entity is! File) continue;
          final String name = path.basenameWithoutExtension(entity.path);
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
});

/// V4：规范化产品图目录（assets/content/gear/gear_photos2.json，D71–D73）。
final gearPhotos2Provider = FutureProvider.autoDispose<Map<String, Object?>>(
  (ref) => GearPhotoSync.catalog(),
);

/// 从 gear_photos2.json 目录中取该设备的产品图条目（byId 优先，byModel 兜底）。
Map<String, Object?>? gearPhotoEntryOf(
  Map<String, Object?>? catalog,
  GearEntry entry,
) {
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
  Map<String, Object?>? photos,
  GearEntry entry,
) {
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
            .where(
              (GearEntry g) =>
                  tokens.isEmpty ||
                  tokens.every((String t) => g.searchText.contains(t)),
            )
            .toList();
        switch (_sort) {
          case '价格↑':
            filtered.sort(
              (GearEntry a, GearEntry b) => a.priceRef.compareTo(b.priceRef),
            );
          case '价格↓':
            filtered.sort(
              (GearEntry a, GearEntry b) => b.priceRef.compareTo(a.priceRef),
            );
          case '名称':
            filtered.sort(
              (GearEntry a, GearEntry b) =>
                  a.displayName.compareTo(b.displayName),
            );
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
                  kind: SsButtonKind.text,
                  icon: Icons.sync_rounded,
                  onPressed: _syncing ? null : () => _syncPhotos(context, ref),
                ),
                const SizedBox(width: 6),
                SsButton(
                  label: '添加设备',
                  dense: true,
                  kind: SsButtonKind.text,
                  onPressed: () => _showAddDialog(context, ref),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 200,
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: '品牌/型号/焦段/F2.8/CRI',
                      isDense: true,
                    ),
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
                        child: Text(v, style: const TextStyle(fontSize: 12)),
                      ),
                  ],
                  onChanged: (String? v) => setState(() => _sort = v ?? '默认'),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s2),
            Expanded(
              child: filtered.isEmpty
                  ? const SsEmpty(
                      icon: Icons.camera_alt_outlined,
                      title: '没有匹配的设备',
                    )
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 240,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 1.7,
                          ),
                      itemCount: filtered.length,
                      itemBuilder: (BuildContext context, int i) => _GearCard(
                        entry: filtered[i],
                        onRephoto: (GearEntry e) =>
                            _showRephotoDialog(context, ref, e),
                      ),
                    ),
            ),
            Text(
              '参数与参考价为参考值 · 灯具可一键放入布光预演 3D 场景（含真实光型参数）',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              kGearPhotoDisclaimer,
              style: TextStyle(
                fontSize: 10.5,
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
    final ValueNotifier<(int, int)> progress = ValueNotifier<(int, int)>((
      0,
      0,
    ));
    final Future<void> dialog = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('同步器材图', style: TextStyle(fontSize: 15)),
        content: ValueListenableBuilder<(int, int)>(
          valueListenable: progress,
          builder: (BuildContext c, (int, int) v, Widget? _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              LinearProgressIndicator(
                value: v.$2 == 0 ? null : v.$1 / v.$2,
                minHeight: 6,
              ),
              const SizedBox(height: 10),
              Text(
                '正在下载 ${v.$1}/${v.$2} · 已内置条目自动跳过',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
    int downloaded = 0;
    Object? error;
    GearSyncReport? report;
    try {
      report = await GearPhotoSync.syncAll(
        db: db,
        onProgress: (int done, int total) => progress.value = (done, total),
      );
      downloaded = report.downloaded;
    } catch (e) {
      error = e;
    }
    if (context.mounted) Navigator.of(context).pop();
    await dialog;
    if (!context.mounted) return;
    setState(() => _syncing = false);
    if (error != null) {
      ssToast(context, '同步失败：$error');
    } else if (downloaded == 0 && (report?.gap ?? 0) == 0) {
      ssToast(context, '器材图已就绪（内置或已缓存）');
    } else if ((report?.gap ?? 0) == 0) {
      ssToast(
        context,
        '同步完成：新增 $downloaded 张'
        '（跳过内置 ${report?.skippedBuiltin ?? 0} / 本地 ${report?.skippedLocal ?? 0}）',
      );
    } else {
      ssToast(context, '同步完成：新增 $downloaded 张；仍缺 ${report?.gap} 条，可在条目详情「补图」');
    }
  }

  /// D130 补图：本地图片或链接 → 工作区 images/gear + 来源登记。
  Future<void> _showRephotoDialog(
    BuildContext context,
    WidgetRef ref,
    GearEntry entry,
  ) async {
    final String? mode = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(
          '补图 · ${entry.displayName}',
          style: const TextStyle(fontSize: 15),
        ),
        content: const Text(
          '选择本地图片，或粘贴图片链接（自动保存到工作区并登记来源）。',
          style: TextStyle(fontSize: 12),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'file'),
            child: const Text('选择本地图片'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'url'),
            child: const Text('粘贴图片链接'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
        ],
      ),
    );
    if (mode == null || !context.mounted) return;
    String? error;
    if (mode == 'file') {
      try {
        final FilePickerResult? picked = await FilePicker.platform.pickFiles(
          type: FileType.image,
        );
        final String? path = picked?.files.single.path;
        if (path == null) return;
        await GearPhotoSync.importLocalFile(entry.id, File(path));
      } catch (e) {
        error = '$e';
      }
    } else {
      final TextEditingController controller = TextEditingController();
      final bool? ok = await showDialog<bool>(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          title: const Text('粘贴图片链接', style: TextStyle(fontSize: 15)),
          content: SizedBox(
            width: 380,
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'https://…（jpg/png/webp）',
                isDense: true,
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('下载并登记'),
            ),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
      final String url = controller.text.trim();
      if (url.isEmpty) return;
      try {
        await GearPhotoSync.importFromUrl(
          entry.id,
          url,
          db: ref.read(databaseProvider),
        );
      } catch (e) {
        error = '$e';
      }
    }
    if (!context.mounted) return;
    if (error != null) {
      ssToast(context, '补图失败：$error');
      return;
    }
    ref.invalidate(gearPhotos2Provider);
    ssToast(context, '已补图：${entry.displayName}（工作区 images/gear，来源已登记）');
  }
}
