import 'dart:convert';

import '../../core/db/database.dart';
import '../image_sources.dart' as legacy;
import '../query_translator.dart';
import 'keywords.dart';
import 'search_models.dart';
import 'theme_packs.dart';

/// V6 查询规划（合同 §3.C.2）：意图分类 → 每源英文关键词 → 缓存 LRU。
///
/// 红线（R46）：任何路径都不得把中文原样发往英文源；
/// 词表/拼音/AI 全部失败时返回空文本，由 UI 给出可执行建议（R45）。
class QueryPlanner {
  QueryPlanner(this._db, {QueryTranslator? translator, bool allowAi = true})
    : _translator = translator ?? QueryTranslator(_db),
      _allowAi = allowAi;

  final AppDatabase _db;
  final QueryTranslator _translator;
  final bool _allowAi;

  static const String cacheKey = 'search_plan_cache_v6';
  static const int cacheLimit = 300;

  /// 人名标记（D114）。
  static const List<String> personMarkers = <String>[
    '导演',
    '演员',
    '主演',
    '出演',
    '代表作',
    '参演',
    '的作品',
    '拍的电影',
    '拍的剧',
  ];

  /// 作品标记。
  static const List<String> titleMarkers = <String>[
    '电影',
    '影片',
    '片名',
    '剧集',
    '电视剧',
    '动漫',
    '动画',
    '纪录片',
    '短片',
  ];

  /// 意图分类（确定性规则，AI 可覆盖）。
  static SearchIntent classifyIntent(
    String input, {
    ImageDomain domain = ImageDomain.photo,
  }) {
    final String text = input.trim();
    if (text.isEmpty) return SearchIntent.keyword;
    for (final String marker in personMarkers) {
      if (text.contains(marker)) return SearchIntent.person;
    }
    for (final String marker in titleMarkers) {
      if (text.contains(marker)) return SearchIntent.title;
    }
    return SearchIntent.keyword;
  }

  /// 从「导演 诺兰」类输入提取人名（去标记与修饰词）。
  static String extractPerson(String input) {
    var text = input.trim();
    for (final String marker in personMarkers) {
      text = text.replaceAll(marker, ' ');
    }
    text = text.replaceAll(RegExp(r'[的了吗呢啊]'), ' ');
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// 规划一次查询（带缓存）。
  Future<SearchQuery> plan(
    String input, {
    ImageDomain domain = ImageDomain.photo,
    bool useCache = true,
  }) async {
    final String raw = input.trim();
    if (raw.isEmpty) {
      return SearchQuery(
        raw: '',
        intent: SearchIntent.keyword,
        text: '',
        domain: domain,
        sourceNote: '空查询',
      );
    }
    final String key = '${domain.name}|$raw';
    if (useCache) {
      final Map<String, Object?> cache = await _loadCache();
      final Object? cached = cache[key];
      if (cached is Map) {
        return _fromCache(raw, domain, cached.cast<String, Object?>());
      }
    }

    SearchIntent intent = classifyIntent(raw, domain: domain);
    String keywords = '';
    String title = '';
    String person = '';
    String note = '';

    final bool asciiInput = hasAsciiQuery(raw) && !containsCjk(raw);
    if (asciiInput) {
      keywords = raw;
      note = '英文原文';
    } else {
      // D133：关键词自动匹配主题包（中文主题词优先于逐字翻译）。
      final ThemePack? matched = matchThemePack(raw);
      if (matched != null) {
        intent = SearchIntent.keyword;
        keywords = matched.enQuery;
        note = '主题匹配：${matched.name}';
      }
      if (!legacy.hasAsciiQuery(keywords)) {
        final String mapped = translateToEnglish(raw);
        if (legacy.hasAsciiQuery(mapped)) {
          keywords = mapped;
          note = '内置词表/人名表';
        }
      }
      if (_allowAi && !legacy.hasAsciiQuery(keywords)) {
        final String ai = await _translator.translate(raw);
        if (legacy.hasAsciiQuery(ai)) {
          keywords = ai;
          note = 'AI 翻译';
        }
      }
      if (!legacy.hasAsciiQuery(keywords)) {
        final String py = toPinyin(raw);
        if (legacy.hasAsciiQuery(py)) {
          keywords = py;
          note = '拼音兜底（未命中词表且 AI 不可用）';
        }
      }
    }
    if (intent == SearchIntent.person) {
      person = extractPerson(raw);
    }
    if (intent == SearchIntent.title) {
      title = raw;
    }
    if (keywords.isEmpty && person.isEmpty && title.isEmpty) {
      note = '未得到英文检索词：请换用可识别的画面词（词表）、配置 AI 提供方或改用英文关键词';
    }
    final SearchQuery query = SearchQuery(
      raw: raw,
      intent: intent,
      text: keywords,
      title: containsCjk(title) ? '' : title,
      person: person,
      domain: domain,
      perSource: _perSource(domain, raw, person),
      sourceNote: note,
    );
    if (note.isNotEmpty && !note.startsWith('未得到')) {
      await _saveCache(key, query);
    }
    return query;
  }

  /// 主题包 → 查询（D120）。
  SearchQuery fromThemePack(ThemePack pack, {ImageDomain? domain}) =>
      SearchQuery(
        raw: pack.name,
        intent: SearchIntent.keyword,
        text: pack.enQuery,
        domain: domain ?? pack.domains.first,
        perSource: <String, String>{},
        sourceNote: '主题包：${pack.name}',
      );

  Map<String, String> _perSource(
    ImageDomain domain,
    String raw,
    String person,
  ) {
    final Map<String, String> map = <String, String>{};
    if (person.isNotEmpty) {
      // TMDB 是多语源（language=zh-CN），中文人名可直接检索；
      // AniList 为英文源，中文人名必须转拼音（R46）。
      map['tmdb'] = person;
      final String latin = containsCjk(person) ? toPinyin(person) : person;
      if (legacy.hasAsciiQuery(latin)) map['anilist'] = latin;
    } else if (domain == ImageDomain.film && containsCjk(raw)) {
      // 影视域：TMDB 支持中文片名（language=zh-CN），中文原名优于拼音。
      map['tmdb'] = raw;
    }
    return map;
  }

  SearchQuery _fromCache(
    String raw,
    ImageDomain domain,
    Map<String, Object?> cached,
  ) {
    final String text = '${cached['keywords'] ?? ''}';
    final String person = '${cached['person'] ?? ''}';
    return SearchQuery(
      raw: raw,
      intent: SearchIntent.fromName('${cached['intent'] ?? 'keyword'}'),
      text: text,
      title: '${cached['title'] ?? ''}',
      person: person,
      domain: domain,
      perSource: _perSource(domain, raw, person),
      sourceNote: '缓存 · ${cached['note'] ?? ''}',
    );
  }

  Future<Map<String, Object?>> _loadCache() async {
    try {
      final String raw = await _db.getSetting(cacheKey) ?? '{}';
      return (jsonDecode(raw) as Map).cast<String, Object?>();
    } catch (_) {
      return <String, Object?>{};
    }
  }

  Future<void> _saveCache(String key, SearchQuery query) async {
    final Map<String, Object?> cache = await _loadCache();
    cache[key] = <String, Object?>{
      'intent': query.intent.name,
      'keywords': query.text,
      'title': query.title,
      'person': query.person,
      'note': query.sourceNote,
    };
    while (cache.length > cacheLimit) {
      cache.remove(cache.keys.first);
    }
    await _db.setSetting(cacheKey, jsonEncode(cache));
  }
}
