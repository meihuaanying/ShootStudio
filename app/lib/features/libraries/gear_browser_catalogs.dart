// V8/S9 · D158：服装目录与道具预设浏览器。
// 从 gear_browser.dart 拆出（R73 行数门禁）；part 同库，私有成员无需公开化。
part of 'gear_browser.dart';

class ClothingCatalog extends ConsumerWidget {
  const ClothingCatalog({super.key, required this.onFilterLibrary});

  final void Function(String keyword) onFilterLibrary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(clothingCatalogProvider);
    final Map<String, Object?>? clothingPhotos = ref
        .watch(clothingPhotosProvider)
        .valueOrNull;
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
                                errorBuilder:
                                    (
                                      BuildContext ctx,
                                      Object e,
                                      StackTrace? st,
                                    ) => const SizedBox.shrink(),
                              ),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: <Color>[
                                    _color(
                                      c.gradient.isNotEmpty
                                          ? c.gradient[0]
                                          : '#888888',
                                    ),
                                    _color(
                                      c.gradient.length > 1
                                          ? c.gradient[1]
                                          : '#444444',
                                    ),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                c.category,
                                style: const TextStyle(
                                  fontSize: AppFontSize.subhead,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  shadows: <Shadow>[
                                    Shadow(
                                      blurRadius: 8,
                                      color: Colors.black45,
                                    ),
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
                              style: const TextStyle(
                                fontSize: AppFontSize.captionLg,
                              ),
                            ),
                            Text(
                              '点击在服装库中筛选',
                              style: TextStyle(
                                fontSize: AppFontSize.tinyLg,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
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
              fontSize: AppFontSize.caption,
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

  Color _color(String hex) => Color(
    0xFF000000 |
        (int.tryParse(hex.replaceFirst('#', ''), radix: 16) ?? 0x888888),
  );
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
                final AppPalette p = context.palette;

                final PropPresetEntry prop = items[i];
                return SsCard(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        prop.name,
                        style: const TextStyle(
                          fontSize: AppFontSize.smallLg,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        prop.note,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppFontSize.caption,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '¥${prop.price} · ${prop.owner}',
                        style: TextStyle(
                          fontSize: AppFontSize.caption,
                          color: p.accent,
                        ),
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
              fontSize: AppFontSize.caption,
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
