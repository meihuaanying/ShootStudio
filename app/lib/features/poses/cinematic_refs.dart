import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/widgets.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../services/search/search_cache.dart';
import '../../services/search/search_keys.dart';
import '../../services/search/search_models.dart';
import '../refs/refs_controller.dart';

/// V7/D140：「影视感参考」入口 —— 按需抓取 TMDB 剧照/海报/静帧，用于姿势与情绪参考。
/// 只存工作区 `images/refs/`（画板条目携带来源与许可标注），**不入包**（V3 版权结论继续有效，R63）。
Future<void> showCinematicRefsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext _) => const _CinematicRefsDialog(),
  );
}

class _CinematicRefsDialog extends ConsumerStatefulWidget {
  const _CinematicRefsDialog();

  @override
  ConsumerState<_CinematicRefsDialog> createState() =>
      _CinematicRefsDialogState();
}

class _CinematicRefsDialogState extends ConsumerState<_CinematicRefsDialog> {
  final TextEditingController _text = TextEditingController();
  List<SearchHit> _hits = <SearchHit>[];
  bool _searching = false;
  String _status = '输入片名/影人/氛围词（如：王家卫、霓虹夜景、cinematic portrait）';

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final String text = _text.text.trim();
    if (text.isEmpty || _searching) return;
    setState(() {
      _searching = true;
      _status = '检索中…';
    });
    try {
      final SearchKeys keys = await SearchKeys.load(ref.read(databaseProvider));
      final List<SearchSource> tmdb = keys
          .sources()
          .where((SearchSource s) => s.id == 'tmdb')
          .toList();
      if (tmdb.isEmpty) {
        setState(() {
          _searching = false;
          _status = '缺 TMDB Key/Token（设置 → 图片素材通道）';
        });
        return;
      }
      final SearchQuery query = SearchQuery(
        raw: text,
        intent: SearchIntent.keyword,
        text: text,
        domain: ImageDomain.film,
        perSource: <String, String>{'tmdb': text},
      );
      final SourceSearchPage page = await tmdb.first.search(
        query,
        page: 1,
        perPage: 24,
      );
      if (!mounted) return;
      setState(() {
        _searching = false;
        _hits = page.hits;
        _status = page.hits.isEmpty
            ? '没有结果 · 换个片名或关键词'
            : '共 ${page.hits.length} 条 · 点击图片加入参考画面（存工作区，不入包）';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _status = '检索失败：$e';
      });
    }
  }

  Future<void> _add(SearchHit hit) async {
    ssToast(context, '正在下载「${hit.title}」…');
    try {
      final SearchCache cache = await SearchCache.from(
        ref.read(databaseProvider),
        ref.read(workspaceProvider).root.path,
      );
      final Uint8List bytes = await cache.getOrFetch(
        hit.fullUrl,
        original: true,
      );
      await ref
          .read(refsControllerProvider.notifier)
          .addFetched(
            bytes: bytes,
            title: hit.title,
            sourceUrl: hit.sourcePageUrl.isEmpty
                ? hit.fullUrl
                : hit.sourcePageUrl,
            sourceLabel: '${hit.sourceLabel} · ${hit.license}',
          );
      if (mounted) {
        ssToast(context, '已加入参考画面（${hit.sourceLabel}）');
      }
    } catch (e) {
      if (mounted) ssToast(context, '下载失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.s16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SsSectionTitle(
                '影视感参考（TMDB）',
                subtitle:
                    '按需抓取剧照/海报/静帧 · 只存工作区 images/refs/ 并标注来源与许可 · 不入包（R63）',
              ),
              const SizedBox(height: AppTokens.s12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _text,
                      onSubmitted: (String _) => _search(),
                      decoration: const InputDecoration(
                        hintText: '片名 / 影人 / 氛围词',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SsButton(
                    label: _searching ? '检索中…' : '检索',
                    icon: Icons.search,
                    dense: true,
                    onPressed: _searching ? null : _search,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _status,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppTokens.s8),
              Flexible(
                child: _hits.isEmpty
                    ? const SizedBox(height: 80)
                    : GridView.builder(
                        shrinkWrap: true,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              childAspectRatio: 0.62,
                            ),
                        itemCount: _hits.length,
                        itemBuilder: (BuildContext context, int i) =>
                            _tile(_hits[i]),
                      ),
              ),
              const SizedBox(height: AppTokens.s8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  SsButton(
                    label: '关闭',
                    kind: SsButtonKind.ghost,
                    dense: true,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(SearchHit hit) {
    return InkWell(
      onTap: () => _add(hit),
      borderRadius: BorderRadius.circular(AppTokens.rSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTokens.rSm),
              child: Image.network(
                hit.thumbUrl.isEmpty ? hit.fullUrl : hit.thumbUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (_, _, _) => Container(
                  alignment: Alignment.center,
                  color: AppTokens.accentSoft,
                  child: const Icon(Icons.broken_image_outlined, size: 18),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hit.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5),
          ),
          Text(
            hit.creditLine.isEmpty ? hit.sourceLabel : hit.creditLine,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
