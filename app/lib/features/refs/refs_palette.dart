import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/design/widgets.dart';
import '../../core/providers.dart';
import '../../services/palette_extractor.dart';
import '../../services/search/search_cache.dart';
import '../../services/search/search_models.dart';

/// S5/D154 五色色卡：详情抽屉里的调色依据（R70：只显示真实提取结果，不臆造）。
class RefsPaletteStrip extends StatelessWidget {
  const RefsPaletteStrip({super.key, required this.colors, this.height = 44});

  final List<String> colors;
  final double height;

  static List<String> fallbackOf(List<String> colors) {
    if (colors.isEmpty) return PaletteExtractor.fallback;
    if (colors.length >= 5) return colors.take(5).toList();
    return <String>[...colors, ...PaletteExtractor.fallback].take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> list = fallbackOf(colors);
    return Semantics(
      label: '五色色卡',
      child: SizedBox(
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int i = 0; i < list.length; i++)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(color: colorFromHex(list[i])),
                  alignment: Alignment.bottomRight,
                  padding: const EdgeInsets.only(
                    right: AppSpaceFine.n2,
                    bottom: AppSpaceFine.n2,
                  ),
                  child: Text(
                    list[i].replaceFirst('#', ''),
                    style: appMono(
                      _readableOn(list[i]),
                      size: 8,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static Color colorFromHex(String hex) {
    final String raw = hex.replaceFirst('#', '');
    final int? v = int.tryParse(raw.length == 6 ? 'FF$raw' : raw, radix: 16);
    return Color(v ?? 0xFF888888);
  }

  /// 依据亮度选前景色（避免色值上白字看不清）。
  static Color _readableOn(String hex) {
    final Color c = colorFromHex(hex);
    return (c.computeLuminance() > 0.45) ? Colors.black54 : Colors.white70;
  }
}

/// 色卡提取服务：下载（走 SearchCache 缓存）缩略图 → PaletteExtractor 提 5 色。
/// 记忆化在内存，避免抽屉反复打开重复解码。
class RefsPaletteService {
  RefsPaletteService({
    required this.db,
    required this.workspaceRoot,
    Future<List<String>> Function(SearchHit hit)? extract,
  }) : _extractOverride = extract;

  final AppDatabase db;
  final String workspaceRoot;
  final Future<List<String>> Function(SearchHit hit)? _extractOverride;
  final Map<String, List<String>> _memo = <String, List<String>>{};

  /// 从 provider 读取依赖构造（WidgetRef 与 Ref 不兼容，故显式传依赖）。
  static RefsPaletteService ofDeps({
    required AppDatabase db,
    required String workspaceRoot,
  }) => RefsPaletteService(db: db, workspaceRoot: workspaceRoot);

  List<String>? peek(String id) => _memo[id];

  Future<List<String>> of(SearchHit hit) async {
    final List<String>? cached = _memo[hit.id];
    if (cached != null) return cached;
    final List<String> colors = _extractOverride == null
        ? await _downloadExtract(hit)
        : await _extractOverride(hit);
    _memo[hit.id] = colors;
    return colors;
  }

  Future<List<String>> _downloadExtract(SearchHit hit) async {
    final String url = hit.thumbUrl.isNotEmpty ? hit.thumbUrl : hit.fullUrl;
    if (url.isEmpty) return PaletteExtractor.fallback;
    try {
      final SearchCache cache = await SearchCache.from(db, workspaceRoot);
      final Uint8List bytes = await cache.getOrFetch(url);
      return PaletteExtractor.extract(bytes).colors;
    } catch (_) {
      return PaletteExtractor.fallback;
    }
  }
}

/// 抽屉内异步色卡：加载中显示骨架条，完成后换真实色卡。
class RefsPaletteSlot extends ConsumerStatefulWidget {
  const RefsPaletteSlot({super.key, required this.hit});

  final SearchHit hit;

  @override
  ConsumerState<RefsPaletteSlot> createState() => _RefsPaletteSlotState();
}

/// 色卡服务的注入点：测试/截图可覆盖为不触网的固定提取器（R62）。
final Provider<RefsPaletteService> refsPaletteServiceProvider =
    Provider<RefsPaletteService>(
      (Ref ref) => RefsPaletteService.ofDeps(
        db: ref.watch(databaseProvider),
        workspaceRoot: ref.watch(workspaceProvider).root.path,
      ),
    );

class _RefsPaletteSlotState extends ConsumerState<RefsPaletteSlot> {
  List<String>? _colors;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant RefsPaletteSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hit.id != widget.hit.id) _load();
  }

  Future<void> _load() async {
    final List<String> colors = await ref
        .read(refsPaletteServiceProvider)
        .of(widget.hit);
    if (!mounted) return;
    setState(() => _colors = colors);
  }

  @override
  Widget build(BuildContext context) {
    final List<String>? colors = _colors;
    if (colors == null) {
      return const SizedBox(height: 44, child: SsSkeleton(height: 44));
    }
    return RefsPaletteStrip(colors: colors);
  }
}
