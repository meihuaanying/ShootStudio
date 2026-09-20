import 'dart:async';

/// V6 搜索重做（D113–D121）：统一模型与源接口。
///
/// 与 V5 的 [image_sources.dart] 并存：旧接口继续为既有测试/兼容保留，
/// 新搜索页与聚合引擎一律使用本文件类型。

/// 结果域：影视静帧 / 画作与平面艺术 / 摄影参考。
enum ImageDomain {
  film('影视静帧'),
  art('画作与平面艺术'),
  photo('摄影参考');

  const ImageDomain(this.label);
  final String label;
}

/// 查询意图（D114）。
enum SearchIntent {
  title('作品'),
  person('人名'),
  keyword('主题');

  const SearchIntent(this.label);
  final String label;

  static SearchIntent fromName(String name) =>
      SearchIntent.values.firstWhere((SearchIntent t) => t.name == name,
          orElse: () => SearchIntent.keyword);
}

/// 源能力声明（合同 §3.C.1）。
class SourceCapability {
  const SourceCapability({
    this.byTitle = true,
    this.byPerson = false,
    this.byKeyword = true,
    this.hasLicenseFilter = false,
    this.domains = const <ImageDomain>{ImageDomain.photo},
    this.requiresKey = false,
    this.keySettingId = '',
  });

  final bool byTitle;
  final bool byPerson;
  final bool byKeyword;
  final bool hasLicenseFilter;
  final Set<ImageDomain> domains;
  final bool requiresKey;
  final String keySettingId;

  bool supportsDomain(ImageDomain domain) => domains.contains(domain);
}

/// 统一结果条目（含来源与许可，R47）。
class SearchHit {
  const SearchHit({
    required this.id,
    required this.title,
    required this.thumbUrl,
    required this.fullUrl,
    required this.sourceId,
    required this.sourceLabel,
    required this.license,
    this.licenseUrl = '',
    this.commercialOk = false,
    this.attribution = '',
    this.sourcePageUrl = '',
    this.width = 0,
    this.height = 0,
    this.group = '',
    this.domain = ImageDomain.photo,
    this.imageType = 'photo',
    this.description = '',
    this.score = 0,
    this.extra = const <String, Object?>{},
  });

  final String id;
  final String title;
  final String thumbUrl;
  final String fullUrl;
  final String sourceId;
  final String sourceLabel;
  final String license;
  final String licenseUrl;

  /// 是否可商用（CC0/PD/明确可商用许可）。
  final bool commercialOk;
  final String attribution;
  final String sourcePageUrl;
  final int width;
  final int height;

  /// 作品分组名（人名搜索按作品分组，D114）。
  final String group;
  final ImageDomain domain;
  final String imageType; // still / artwork / photo
  final String description;
  final double score;
  final Map<String, Object?> extra;

  SearchHit copyWith({
    double? score,
    String? group,
    String? description,
  }) =>
      SearchHit(
        id: id,
        title: title,
        thumbUrl: thumbUrl,
        fullUrl: fullUrl,
        sourceId: sourceId,
        sourceLabel: sourceLabel,
        license: license,
        licenseUrl: licenseUrl,
        commercialOk: commercialOk,
        attribution: attribution,
        sourcePageUrl: sourcePageUrl,
        width: width,
        height: height,
        group: group ?? this.group,
        domain: domain,
        imageType: imageType,
        description: description ?? this.description,
        score: score ?? this.score,
        extra: extra,
      );

  /// 展示用副标题：来源 · 许可（可商用加 ✓）。
  String get creditLine {
    final String lic = license.isEmpty ? '许可未标注' : license;
    return '$sourceLabel · $lic${commercialOk ? ' · 可商用' : ''}';
  }
}

/// 规划后的检索查询（QueryPlanner 输出）。
class SearchQuery {
  const SearchQuery({
    required this.raw,
    required this.intent,
    required this.text,
    this.title = '',
    this.person = '',
    this.domain = ImageDomain.photo,
    this.perSource = const <String, String>{},
    this.sourceNote = '',
  });

  final String raw;
  final SearchIntent intent;

  /// 主英文检索词（保证不含中文，R46）。
  final String text;
  final String title;
  final String person;
  final ImageDomain domain;

  /// 每源覆盖词（如 TMDB 用片名、Met 用关键词）。
  final Map<String, String> perSource;

  /// 规划来源说明（词表/AI/拼音），用于 UI 状态展示（R45）。
  final String sourceNote;

  String forSource(String sourceId) {
    final String override = perSource[sourceId] ?? '';
    if (override.isNotEmpty) return override;
    return text;
  }

  SearchQuery copyWith({
    SearchIntent? intent,
    String? text,
    String? title,
    String? person,
    ImageDomain? domain,
    Map<String, String>? perSource,
    String? sourceNote,
  }) =>
      SearchQuery(
        raw: raw,
        intent: intent ?? this.intent,
        text: text ?? this.text,
        title: title ?? this.title,
        person: person ?? this.person,
        domain: domain ?? this.domain,
        perSource: perSource ?? this.perSource,
        sourceNote: sourceNote ?? this.sourceNote,
      );
}

/// 单源一页结果。
class SourceSearchPage {
  const SourceSearchPage({required this.hits, required this.hasMore});
  final List<SearchHit> hits;
  final bool hasMore;
}

/// 图源统一接口（合同 §3.C.1）。
abstract class SearchSource {
  String get id;
  String get label;
  SourceCapability get capability;

  bool get enabled;
  String get disabledHint;

  Future<SourceSearchPage> search(
    SearchQuery query, {
    int page = 1,
    int perPage = 24,
  });
}

/// 每源状态（UI chips：结果数/耗时/失败原因/重试，R45）。
class SourceStatus {
  const SourceStatus({
    required this.id,
    required this.label,
    required this.ok,
    required this.count,
    required this.elapsedMs,
    this.error = '',
    this.enabled = true,
    this.hint = '',
    this.skipped = false,
    this.domain,
  });

  final String id;
  final String label;
  final bool ok;
  final int count;
  final int elapsedMs;
  final String error;
  final bool enabled;
  final String hint;

  /// 与当前 Tab 域不匹配而跳过。
  final bool skipped;
  final ImageDomain? domain;

  String get summary {
    if (!enabled) return hint.isEmpty ? '未启用' : hint;
    if (skipped) return '不适用当前分类';
    if (ok) return '$count 条 · ${elapsedMs}ms';
    return '失败：$error';
  }
}

/// 聚合结果。
class AggregatedResult {
  const AggregatedResult({
    required this.hits,
    required this.statuses,
    required this.page,
    required this.hasMore,
    required this.query,
    this.rankNote = '',
  });

  final List<SearchHit> hits;
  final List<SourceStatus> statuses;
  final int page;
  final bool hasMore;
  final SearchQuery query;
  final String rankNote;

  int get okSources => statuses.where((SourceStatus s) => s.ok).length;
  int get failedSources => statuses
      .where((SourceStatus s) => !s.ok && s.enabled && !s.skipped)
      .length;

  /// 人名结果按作品分组（D114）。
  Map<String, List<SearchHit>> get groupedByWork {
    final Map<String, List<SearchHit>> map = <String, List<SearchHit>>{};
    for (final SearchHit hit in hits) {
      final String key = hit.group.isEmpty ? '未分组' : hit.group;
      map.putIfAbsent(key, () => <SearchHit>[]).add(hit);
    }
    return map;
  }
}
