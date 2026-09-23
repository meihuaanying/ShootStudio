import '../../core/db/database.dart';
import '../net.dart';
import 'search_models.dart';
import 'sources/anilist_source.dart';
import 'sources/artic_source.dart';
import 'sources/artvee_source.dart';
import 'sources/cleveland_source.dart';
import 'sources/europeana_source.dart';
import 'sources/harvard_source.dart';
import 'sources/met_source.dart';
import 'sources/open_index_source.dart';
import 'sources/openverse_source.dart';
import 'sources/pexels_source.dart';
import 'sources/rijks_source.dart';
import 'sources/smk_source.dart';
import 'sources/smithsonian_source.dart';
import 'sources/tmdb_source.dart';
import 'sources/vam_source.dart';
import 'sources/wellcome_source.dart';
import 'sources/wikiart_source.dart';
import 'sources/wikimedia_source.dart';
import 'sources/loc_source.dart';

/// 搜索相关凭据（内置默认 + 用户设置覆盖，D82/D98）。
class SearchKeys {
  const SearchKeys({
    this.pexelsKey = '',
    this.tmdbKey = '',
    this.tmdbToken = '',
    this.europeanaKey = '',
    this.smithsonianKey = '',
    this.harvardKey = '',
    this.rijksKey = '',
  });

  final String pexelsKey;
  final String tmdbKey;
  final String tmdbToken;
  final String europeanaKey;
  final String smithsonianKey;
  final String harvardKey;
  final String rijksKey;

  static Future<SearchKeys> load(AppDatabase db) async {
    final NetConfig builtin = await loadNetConfig();
    Future<String> pick(String setting, String fallback) async {
      final String value = (await db.getSetting(setting) ?? '').trim();
      return value.isNotEmpty ? value : fallback;
    }

    return SearchKeys(
      pexelsKey: await pick('image_pexels_key', builtin.pexelsKey),
      tmdbKey: await pick('image_tmdb_key', builtin.tmdbKey),
      tmdbToken: await pick('tmdb_token', builtin.tmdbToken),
      europeanaKey: await pick('search_key_europeana', ''),
      smithsonianKey: await pick('search_key_smithsonian', ''),
      harvardKey: await pick('search_key_harvard', ''),
      rijksKey: await pick('search_key_rijks', ''),
    );
  }

  /// 默认全源（含 Key 预留源；未填 Key 的源显示"未启用"并可点击去设置）。
  /// V7/D134：新增 7 个开放源（Openverse/Wikimedia/Wellcome/SMK/LoC + NGA/Walters 内置索引）。
  List<SearchSource> sources() => <SearchSource>[
    PexelsImageSource(pexelsKey),
    TmdbImageSource(apiKey: tmdbKey, readToken: tmdbToken),
    AniListSource(),
    MetSource(),
    ArticSource(),
    ClevelandSource(),
    VamSource(),
    WikiArtSource(),
    ArtveeSource(),
    EuropeanaSource(europeanaKey),
    SmithsonianSource(smithsonianKey),
    HarvardSource(harvardKey),
    RijksSource(rijksKey),
    OpenverseSource(),
    WikimediaSource(),
    WellcomeSource(),
    SmkSource(),
    LocSource(),
    OpenIndexSource(
      id: 'nga',
      label: '美国国家美术馆',
      asset: 'assets/content/search/open_index/nga.json',
      attributionBase: 'National Gallery of Art',
    ),
    OpenIndexSource(
      id: 'walters',
      label: '沃尔特斯艺术博物馆',
      asset: 'assets/content/search/open_index/walters.json',
      attributionBase: 'Walters Art Museum',
    ),
  ];
}
