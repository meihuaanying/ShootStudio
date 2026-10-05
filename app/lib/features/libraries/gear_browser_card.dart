// V8/S9 · D158：器材图卡（缩略图链 / 示意图 / 详情弹窗 / 规格标签）。
// 从 gear_browser.dart 拆出（R73 行数门禁）；part 同库，私有成员无需公开化。
part of 'gear_browser.dart';

class _GearCard extends ConsumerWidget {
  const _GearCard({required this.entry, this.onRephoto});

  final GearEntry entry;

  /// D130 补图回调（由资源库页注入，写入工作区并登记来源）。
  final Future<void> Function(GearEntry entry)? onRephoto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette p = context.palette;

    final Map<String, Object?>? photos = ref
        .watch(gearPhotosProvider)
        .valueOrNull;
    final Map<String, Object?>? catalog = ref
        .watch(gearPhotos2Provider)
        .valueOrNull;
    final Map<String, Object?>? photo2 = gearPhotoEntryOf(catalog, entry);
    final Map<String, Object?>? userPhoto = gearUserPhotoOf(photos, entry);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: AppWait.cardHover,
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double t, Widget? child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - t)),
          child: child,
        ),
      ),
      child: SsCard(
        padding: const EdgeInsets.all(10),
        onTap: () => _showDetail(context, ref),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                _thumb(context, entry, photo2, userPhoto),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        entry.brand,
                        style: TextStyle(
                          fontSize: AppFontSize.tinyLg,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        entry.model,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: AppFontSize.small,
                          fontWeight: AppFontWeight.bold,
                        ),
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
              style: appMono(p.inkSoft),
            ),
            Text(
              '参考 ¥${entry.priceRef.toStringAsFixed(0)}'
              '${entry.imageSource == 'custom' ? ' · 自定义' : ''}',
              style: TextStyle(fontSize: AppFontSize.caption, color: p.accent),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示优先级（V4）：内置 photo2 → 用户目录 → 运行时缓存 → 插画。
  Widget _thumb(
    BuildContext context,
    GearEntry entry,
    Map<String, Object?>? photo2,
    Map<String, Object?>? user,
  ) {
    final List<Widget Function(Widget Function())> chain = _photoChain(
      entry,
      photo2,
      user,
      fit: BoxFit.cover,
      width: 54,
    );
    final String label = photo2 != null
        ? gearPhotoLabel(photo2)
        : (user != null
              ? '用户导入'
              : (GearPhotoSync.localPathFor(entry.id) != null
                    ? '已同步'
                    : (chain.isEmpty ? '缺图·插画' : '已同步')));
    if (chain.isEmpty) {
      return SizedBox(
        width: 54,
        height: 54,
        child: Column(
          children: <Widget>[
            Expanded(child: _illustration(context, entry)),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: AppFontSize.micro2),
            ),
          ],
        ),
      );
    }
    return SizedBox(
      width: 54,
      height: 54,
      child: Column(
        children: <Widget>[
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _firstAvailable(
                context,
                chain,
                fallback: _illustration(context, entry),
              ),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: AppFontSize.micro2),
          ),
        ],
      ),
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
        chain.add(
          (Widget Function() onError) => Image.asset(
            asset,
            fit: fit,
            width: width,
            height: height,
            errorBuilder: (_, __, ___) => onError(),
          ),
        );
      }
    }
    final String userFile = user?['absolute'] == true
        ? '${user?['file'] ?? ''}'
        : '';
    if (userFile.isNotEmpty) {
      chain.add(
        (Widget Function() onError) => Image.file(
          File(userFile),
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (_, __, ___) => onError(),
        ),
      );
    }
    final String? local = GearPhotoSync.localPathFor(entry.id);
    if (local != null) {
      chain.add(
        (Widget Function() onError) => Image.file(
          File(local),
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (_, __, ___) => onError(),
        ),
      );
    }
    return chain;
  }

  Widget _firstAvailable(
    BuildContext context,
    List<Widget Function(Widget Function())> chain, {
    Widget? fallback,
  }) {
    Widget build(int i) {
      if (i >= chain.length) return fallback ?? _fallbackBox(context);
      return chain[i](() => build(i + 1));
    }

    return build(0);
  }

  Widget _illustration(BuildContext context, GearEntry entry) {
    if (entry.imageSource == 'custom' || entry.image.isEmpty) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: context.palette.accentSoft,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.camera_alt_outlined,
          size: 20,
          color: context.palette.accent,
        ),
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
            _fallbackBox(context),
      ),
    );
  }

  void _showDetail(BuildContext context, WidgetRef ref) {
    final AppPalette p = context.palette;

    final Map<String, Object?>? photos = ref
        .read(gearPhotosProvider)
        .valueOrNull;
    final Map<String, Object?>? catalog = ref
        .read(gearPhotos2Provider)
        .valueOrNull;
    final Map<String, Object?>? photo2 = gearPhotoEntryOf(catalog, entry);
    final Map<String, Object?>? userPhoto = gearUserPhotoOf(photos, entry);
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(
          entry.displayName,
          style: const TextStyle(fontSize: AppFontSize.bodyLg),
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (_photoChain(
                entry,
                photo2,
                userPhoto,
                fit: BoxFit.contain,
                height: 150,
              ).isNotEmpty)
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
                          child: _firstAvailable(
                            context,
                            _photoChain(
                              entry,
                              photo2,
                              userPhoto,
                              fit: BoxFit.contain,
                              height: 150,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        photo2 != null
                            ? gearPhotoLabel(photo2)
                            : (userPhoto != null
                                  ? '用户导入（设置页「器材图目录」）'
                                  : '运行时同步缓存（工作区 images/gear）'),
                        style: const TextStyle(fontSize: AppFontSize.tinyLg),
                      ),
                      if (photo2 != null && gearPhotoCredit(photo2).isNotEmpty)
                        Text(
                          gearPhotoCredit(photo2),
                          style: TextStyle(
                            fontSize: AppFontSize.tiny,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      if (photo2 != null &&
                          '${photo2['note'] ?? ''}'.isNotEmpty)
                        Text(
                          '${photo2['note']}',
                          style: TextStyle(
                            fontSize: AppFontSize.tiny,
                            color: p.accent,
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
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: context.palette.accentSoft,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: AppFontSize.caption,
                            color: p.accent,
                          ),
                        ),
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
                            fontSize: AppFontSize.smallSm,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Text(
                        '${spec.value}',
                        style: const TextStyle(fontSize: AppFontSize.small),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                '参考价：¥${entry.priceRef.toStringAsFixed(0)}（内容包参考值，可自定义修正）',
                style: const TextStyle(fontSize: AppFontSize.smallSm),
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
                ref
                    .read(lightingControllerProvider.notifier)
                    .addLightFromGear(
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
                await (db.delete(
                  db.gearItems,
                )..where((t) => t.id.equals(entry.id))).go();
                ref.invalidate(gearListProvider);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) ssToast(context, '已删除自定义设备');
              },
              child: const Text('删除'),
            ),
          if (photo2 == null &&
              userPhoto == null &&
              entry.imageSource != 'custom')
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                onRephoto?.call(entry);
              },
              child: const Text('补图'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _fallbackBox(BuildContext context) => Container(
    width: 54,
    color: context.palette.accentSoft,
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
