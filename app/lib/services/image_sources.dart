import 'dart:async';

import 'package:dio/dio.dart';

import 'net_router.dart';

/// 画面参考聚合搜图（V5 / D80–D83）：
/// Pexels（主）→ TMDB（影片）→ Openverse（实验性，当前网络常不可用）。
/// 统一走 [NetRouter]（用户代理 / DoH 隧道 / 直连），逐源上报状态与耗时。
class ImageHit {
  const ImageHit({
    required this.title,
    required this.thumbUrl,
    required this.fullUrl,
    required this.source,
    required this.license,
    required this.attribution,
    this.width = 0,
    this.height = 0,
  });

  final String title;
  final String thumbUrl;
  final String fullUrl;
  final String source;
  final String license;
  final String attribution;
  final int width;
  final int height;
}

/// 中文画面词 → 英文检索词（确定性内置词表，覆盖常见摄影题材；V5 扩至 200+）。
const Map<String, String> kSceneKeywordMap = <String, String>{
  // ---- 场景 / 环境 ----
  '雨夜': 'rainy night neon',
  '霓虹': 'neon lights',
  '赛博': 'cyberpunk',
  '夜景': 'night city',
  '城市': 'city',
  '街道': 'street',
  '巷子': 'alley',
  '天台': 'rooftop',
  '地铁': 'subway station',
  '车站': 'train station',
  '便利店': 'convenience store',
  '咖啡馆': 'cafe',
  '酒吧': 'bar',
  '餐厅': 'restaurant',
  '教室': 'classroom',
  '图书馆': 'library',
  '校园': 'school campus',
  '办公室': 'office',
  '工厂': 'factory industrial',
  '废墟': 'ruins abandoned',
  '废弃': 'abandoned building',
  '隧道': 'tunnel',
  '桥': 'bridge',
  '江边': 'riverside',
  '海边': 'seaside beach',
  '沙滩': 'sandy beach',
  '码头': 'pier dock',
  '森林': 'forest',
  '竹林': 'bamboo forest',
  '草原': 'grassland prairie',
  '沙漠': 'desert',
  '雪山': 'snow mountain',
  '山谷': 'mountain valley',
  '湖泊': 'lake',
  '瀑布': 'waterfall',
  '花园': 'garden',
  '园林': 'chinese garden',
  '古镇': 'ancient town',
  '寺庙': 'temple',
  '教堂': 'church',
  '博物馆': 'museum',
  '美术馆': 'art gallery',
  '剧院': 'theater stage',
  '泳池': 'swimming pool',
  '浴室': 'bathroom',
  '卧室': 'bedroom',
  '厨房': 'kitchen',
  '客厅': 'living room',
  '楼梯': 'staircase',
  '走廊': 'corridor hallway',
  '停车场': 'parking garage',
  '机场': 'airport',
  '港口': 'harbor',
  '市场': 'market',
  '夜市': 'night market',
  '厨房烟火': 'kitchen steam cooking',
  '雨林': 'rainforest',
  '荒野': 'wilderness',
  '戈壁': 'gobi desert',
  '稻田': 'rice field',
  '麦田': 'wheat field',
  '花海': 'flower field',
  '油菜花': 'rapeseed flower field',
  '薰衣草': 'lavender field',
  '樱花': 'cherry blossom',
  '枫叶': 'autumn maple leaves',
  '芦苇': 'reed grass',
  '天台夜景': 'rooftop night skyline',
  '天文台': 'observatory',
  '太空': 'outer space stars',
  '星空': 'starry night sky',
  '银河': 'milky way',
  '日落': 'sunset',
  '日出': 'sunrise',
  '黄昏': 'dusk golden hour',
  '黎明': 'dawn',
  '沙漠星空': 'desert night stars',
  // ---- 光线 / 氛围 ----
  '逆光': 'backlight portrait',
  '侧光': 'side light portrait',
  '顺光': 'front light portrait',
  '顶光': 'top light portrait',
  '底光': 'bottom light horror',
  '剪影': 'silhouette',
  '轮廓光': 'rim light portrait',
  '伦勃朗光': 'rembrandt lighting portrait',
  '蝴蝶光': 'butterfly lighting portrait',
  '硬光': 'hard light shadow',
  '柔光': 'soft light',
  '高调': 'high key photography',
  '低调': 'low key photography',
  '暗调': 'dark moody',
  '明暗对比': 'chiaroscuro contrast',
  '投影': 'shadow projection',
  '光斑': 'bokeh light spots',
  '漏光': 'light leak film',
  '丁达尔': 'god rays sunbeam',
  '烟雾': 'smoke fog',
  '雾气': 'mist fog',
  '晨雾': 'morning mist',
  '水汽': 'steam vapor',
  '雨滴': 'raindrops',
  '水花': 'water splash',
  '火焰': 'fire flame',
  '烛光': 'candlelight',
  '灯笼': 'lantern',
  '霓虹灯牌': 'neon sign',
  '烟花': 'fireworks',
  '雪景': 'snow winter',
  '雨伞': 'umbrella rain',
  '镜子': 'mirror reflection',
  '玻璃反射': 'glass reflection',
  '水面反射': 'water reflection',
  '投影仪': 'projector light',
  '频闪': 'strobe light motion',
  '长曝光': 'long exposure light trails',
  // ---- 情绪 / 风格 ----
  '高级感': 'high fashion editorial',
  '电影感': 'cinematic film still',
  '胶片': 'film photography grain',
  '复古': 'vintage retro',
  '黑白': 'black and white',
  '怀旧': 'nostalgic faded film',
  '忧郁': 'melancholy mood',
  '孤独': 'lonely solitude',
  '温柔': 'soft gentle mood',
  '甜酷': 'edgy fashion portrait',
  '暗黑': 'dark gothic',
  '甜美': 'sweet cute portrait',
  '元气': 'energetic vibrant',
  '文艺': 'artsy mood',
  '梦幻': 'dreamy fantasy',
  '未来感': 'futuristic sci-fi',
  '蒸汽波': 'vaporwave aesthetic',
  '国风': 'chinese traditional style',
  '和风': 'japanese traditional style',
  '港风': 'hong kong retro style',
  '民国风': 'republic of china vintage',
  '昭和': 'showa retro japan',
  '千禧': 'y2k aesthetic',
  '极简': 'minimalist',
  '巴洛克': 'baroque ornate',
  '哥特': 'gothic',
  '浪漫': 'romantic mood',
  '神秘': 'mysterious mood',
  '惊悚': 'thriller dark mood',
  '科幻': 'science fiction',
  '奇幻': 'fantasy magical',
  // ---- 人物 / 服装 ----
  '单人': 'single portrait',
  '双人': 'couple portrait',
  '情侣': 'couple',
  '闺蜜': 'friends portrait',
  '亲子': 'parent child',
  '老人': 'elderly portrait',
  '儿童': 'child portrait',
  '男生': 'male portrait',
  '女生': 'female portrait',
  '汉服': 'hanfu chinese traditional',
  '旗袍': 'qipao cheongsam',
  '和服': 'kimono',
  'JK': 'school uniform japanese',
  '洛丽塔': 'lolita fashion',
  '婚纱': 'wedding dress',
  '西服': 'suit fashion',
  '运动风': 'sportswear fashion',
  '街头风': 'streetwear fashion',
  '礼服': 'evening gown',
  '制服': 'uniform',
  '古装': 'ancient costume',
  '蒸汽朋克': 'steampunk costume',
  '机甲': 'mecha robot armor',
  '兽耳': 'animal ears cosplay',
  '面具': 'mask',
  '头纱': 'veil',
  '珠宝': 'jewelry',
  '帽子': 'hat fashion',
  '墨镜': 'sunglasses portrait',
  '婚礼': 'wedding',
  '毕业': 'graduation',
  '孕期': 'maternity',
  '健身': 'fitness body',
  '舞蹈': 'dancer',
  '芭蕾': 'ballet dancer',
  '武术': 'martial arts',
  '乐器': 'musician instrument',
  '吉他': 'guitar player',
  '钢琴': 'piano player',
  '绘画': 'painter artist',
  '阅读': 'reading book',
  '咖啡': 'coffee cup',
  '美食': 'food photography',
  '宠物': 'pet animal',
  '猫': 'cat',
  '狗': 'dog',
  '骑马': 'horse riding',
  // ---- 器材 / 技法 ----
  '棚拍': 'studio portrait',
  '棚拍布光': 'studio lighting setup',
  '外拍': 'outdoor photoshoot',
  '街拍': 'street photography',
  '抓拍': 'candid shot',
  '特写': 'close up shot',
  '微距': 'macro photography',
  '人像': 'portrait',
  '半身': 'half body portrait',
  '全身': 'full body portrait',
  '俯拍': 'top down shot',
  '仰拍': 'low angle shot',
  '平视': 'eye level shot',
  '广角': 'wide angle',
  '长焦': 'telephoto compression',
  '鱼眼': 'fisheye lens',
  '景深': 'shallow depth of field',
  '虚化': 'bokeh blur background',
  '动态模糊': 'motion blur',
  '双重曝光': 'double exposure',
  '倒影': 'reflection shot',
  '俯视构图': 'overhead composition',
  '对称构图': 'symmetrical composition',
  '留白': 'negative space composition',
  '三分法': 'rule of thirds',
  '前景': 'foreground framing',
  '框架构图': 'frame within frame',
  '低角度': 'low angle',
  '高角度': 'high angle',
  '航拍': 'aerial drone shot',
  '水下': 'underwater',
  '慢门': 'slow shutter',
  '高速摄影': 'high speed photography',
  '定格': 'freeze motion',
  '画中画': 'picture in picture reflection',
  // ---- 色彩 ----
  '暖色': 'warm tones',
  '冷色': 'cool tones',
  '莫兰迪': 'morandi muted colors',
  '马卡龙': 'pastel colors',
  '撞色': 'contrasting colors',
  '单色': 'monochrome',
  '青橙': 'teal and orange grade',
  '赛璐璐': 'cel shading colors',
  '红黑': 'red and black',
  '蓝调': 'blue hour',
  '绿意': 'green nature tones',
  '金黄': 'golden tones',
};

/// 输出英文检索词；未命中词表的中文不会再被原样发往英文源（R33）。
/// [allowTail]：有词表命中时是否保留英文尾巴。
String translateSceneToKeywords(String input, {bool allowTail = true}) {
  final String trimmed = input.trim();
  if (trimmed.isEmpty) return '';
  final List<String> parts = <String>[];
  var rest = trimmed;
  for (final MapEntry<String, String> entry in kSceneKeywordMap.entries) {
    if (rest.contains(entry.key)) {
      parts.add(entry.value);
      rest = rest.replaceAll(entry.key, ' ');
    }
  }
  if (parts.isEmpty) return '';
  if (allowTail) {
    final String tail = rest
        .split(RegExp(r'[\s，,。.；;、]+'))
        .where(
          (String s) => s.isNotEmpty && !RegExp(r'[\u4e00-\u9fff]').hasMatch(s),
        )
        .join(' ');
    if (tail.isNotEmpty) parts.add(tail);
  }
  return parts.toSet().join(' ');
}

/// 是否含可用 ASCII 检索词（>=2 个字母的英文/数字 token）。
bool hasAsciiQuery(String text) => RegExp(r'[A-Za-z0-9]{2,}').hasMatch(text);

/// 是否需要 AI 翻译（输入含中文且词表翻译无英文）。
bool needsAiTranslate(String input) {
  final bool hasCjk = RegExp(r'[\u4e00-\u9fff]').hasMatch(input);
  if (!hasCjk) return false;
  final String mapped = translateSceneToKeywords(input, allowTail: false);
  return !hasAsciiQuery(mapped);
}

/// 首页结果页（分页支持）。
class SourcePage {
  const SourcePage({required this.hits, required this.hasMore});
  final List<ImageHit> hits;
  final bool hasMore;
}

abstract class ImageSource {
  String get id;
  String get label;
  bool get experimental;

  /// 是否启用（缺 Key 的源禁用并给出提示）。
  bool get enabled;
  String get disabledHint;
  Future<SourcePage> search(String query, {int page = 1, int perPage = 18});
}

class OpenverseSource implements ImageSource {
  OpenverseSource({Dio? dio}) : _dio = dio ?? NetRouter.I.dio();

  final Dio _dio;

  @override
  String get id => 'openverse';
  @override
  String get label => 'Openverse（实验性）';
  @override
  bool get experimental => true;
  @override
  bool get enabled => true;
  @override
  String get disabledHint => '';

  @override
  Future<SourcePage> search(
    String query, {
    int page = 1,
    int perPage = 18,
  }) async {
    final Response<Object?> res = await _dio.get<Object?>(
      'https://api.openverse.org/v1/images/',
      queryParameters: <String, Object?>{
        'q': query,
        'page': page,
        'page_size': perPage,
      },
      options: Options(
        headers: <String, Object?>{'User-Agent': 'ShootStudio/1.0'},
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
    final Map<String, Object?> data = (res.data as Map? ?? <String, Object?>{})
        .cast<String, Object?>();
    final List<Object?> results =
        data['results'] as List<Object?>? ?? <Object?>[];
    final List<ImageHit> hits = results
        .whereType<Map>()
        .map((Map m) {
          final Map<String, Object?> item = m.cast<String, Object?>();
          final String thumb = '${item['thumbnail'] ?? item['url'] ?? ''}';
          return ImageHit(
            title: '${item['title'] ?? '参考图'}',
            thumbUrl: thumb.isEmpty ? '${item['url'] ?? ''}' : thumb,
            fullUrl: '${item['url'] ?? thumb}',
            source: 'Openverse',
            license: '${item['license'] ?? ''} ${item['license_version'] ?? ''}'
                .trim(),
            attribution: '${item['attribution'] ?? item['creator'] ?? ''}',
            width: (item['width'] as num?)?.toInt() ?? 0,
            height: (item['height'] as num?)?.toInt() ?? 0,
          );
        })
        .where((ImageHit h) => h.fullUrl.isNotEmpty)
        .toList();
    final int total = (data['result_count'] as num?)?.toInt() ?? hits.length;
    return SourcePage(
      hits: hits,
      hasMore: hits.isNotEmpty && page * perPage < total,
    );
  }
}

class PexelsSource implements ImageSource {
  PexelsSource(this.apiKey, {Dio? dio, this.locale = 'zh-CN'})
    : _dio = dio ?? NetRouter.I.dio();

  final String apiKey;
  final Dio _dio;
  final String locale;

  @override
  String get id => 'pexels';
  @override
  String get label => 'Pexels';
  @override
  bool get experimental => false;
  @override
  bool get enabled => apiKey.isNotEmpty;
  @override
  String get disabledHint => '缺 Pexels Key（设置 → 图片素材通道）';

  @override
  Future<SourcePage> search(
    String query, {
    int page = 1,
    int perPage = 18,
  }) async {
    final Response<Object?> res = await _dio.get<Object?>(
      'https://api.pexels.com/v1/search',
      queryParameters: <String, Object?>{
        'query': query,
        'page': page,
        'per_page': perPage,
        'locale': locale,
      },
      options: Options(
        headers: <String, Object?>{'Authorization': apiKey},
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    final Map<String, Object?> data = (res.data as Map? ?? <String, Object?>{})
        .cast<String, Object?>();
    final List<Object?> photos =
        data['photos'] as List<Object?>? ?? <Object?>[];
    final List<ImageHit> hits = photos
        .whereType<Map>()
        .map((Map m) {
          final Map<String, Object?> item = m.cast<String, Object?>();
          final Map<String, Object?> src =
              (item['src'] as Map? ?? <String, Object?>{})
                  .cast<String, Object?>();
          return ImageHit(
            title: '${item['alt'] ?? 'Pexels 参考图'}',
            thumbUrl: '${src['medium'] ?? src['small'] ?? ''}',
            fullUrl:
                '${src['large2x'] ?? src['original'] ?? src['large'] ?? ''}',
            source: 'Pexels',
            license: 'Pexels License',
            attribution: '${item['photographer'] ?? ''} · Pexels',
            width: (item['width'] as num?)?.toInt() ?? 0,
            height: (item['height'] as num?)?.toInt() ?? 0,
          );
        })
        .where((ImageHit h) => h.fullUrl.isNotEmpty)
        .toList();
    final int total = (data['total_results'] as num?)?.toInt() ?? hits.length;
    return SourcePage(
      hits: hits,
      hasMore: hits.isNotEmpty && page * perPage < total,
    );
  }
}

class TmdbSource implements ImageSource {
  TmdbSource(this.apiKey, {Dio? dio}) : _dio = dio ?? NetRouter.I.dio();

  final String apiKey;
  final Dio _dio;

  @override
  String get id => 'tmdb';
  @override
  String get label => 'TMDB 剧照';
  @override
  bool get experimental => false;
  @override
  bool get enabled => apiKey.isNotEmpty;
  @override
  String get disabledHint => '缺 TMDB Key（设置 → 图片素材通道）';

  @override
  Future<SourcePage> search(
    String query, {
    int page = 1,
    int perPage = 18,
  }) async {
    final Response<Object?> res = await _dio.get<Object?>(
      'https://api.themoviedb.org/3/search/movie',
      queryParameters: <String, Object?>{
        'api_key': apiKey,
        'query': query,
        'page': page,
        'include_adult': false,
      },
      options: Options(receiveTimeout: const Duration(seconds: 15)),
    );
    final Map<String, Object?> data = (res.data as Map? ?? <String, Object?>{})
        .cast<String, Object?>();
    final List<Object?> movies =
        data['results'] as List<Object?>? ?? <Object?>[];
    final int totalPages = (data['total_pages'] as num?)?.toInt() ?? 1;
    final List<ImageHit> hits = <ImageHit>[];
    for (final Object? raw in movies) {
      if (raw is! Map) continue;
      final Map<String, Object?> movie = raw.cast<String, Object?>();
      final String poster = '${movie['poster_path'] ?? ''}';
      if (poster.isEmpty) continue;
      hits.add(
        ImageHit(
          title:
              '${movie['title'] ?? movie['original_title'] ?? 'TMDB'}（${movie['release_date'] ?? ''}）',
          thumbUrl: 'https://image.tmdb.org/t/p/w500$poster',
          fullUrl: 'https://image.tmdb.org/t/p/w780$poster',
          source: 'TMDB',
          license: 'TMDB 剧照（个人参考）',
          attribution:
              'TMDB · ${movie['original_title'] ?? movie['title'] ?? ''}',
          width: 500,
          height: 750,
        ),
      );
    }
    return SourcePage(hits: hits, hasMore: page < totalPages);
  }
}

/// 单源状态（UI 展示 + 单源重试）。
class SourceStatus {
  const SourceStatus({
    required this.id,
    required this.label,
    required this.ok,
    required this.count,
    required this.elapsedMs,
    this.error = '',
    this.experimental = false,
    this.enabled = true,
    this.hint = '',
  });

  final String id;
  final String label;
  final bool ok;
  final int count;
  final int elapsedMs;
  final String error;
  final bool experimental;
  final bool enabled;
  final String hint;

  String get summary {
    if (!enabled) return hint.isEmpty ? '未启用' : hint;
    if (ok) return '$count 条 · ${elapsedMs}ms';
    return '失败：$error';
  }
}

class SmartSearchResult {
  const SmartSearchResult({
    required this.hits,
    required this.statuses,
    required this.page,
    required this.hasMore,
    required this.query,
  });

  final List<ImageHit> hits;
  final List<SourceStatus> statuses;
  final int page;
  final bool hasMore;
  final String query;

  int get okSources => statuses.where((SourceStatus s) => s.ok).length;
  int get failedSources =>
      statuses.where((SourceStatus s) => !s.ok && s.enabled).length;
}

class SmartImageSearch {
  SmartImageSearch({List<ImageSource>? sources})
    : _sources = sources ?? const <ImageSource>[];

  final List<ImageSource> _sources;

  /// 默认源组合：Pexels（主）→ TMDB → Openverse（实验性，最后）。
  static SmartImageSearch from({
    String pexelsKey = '',
    String tmdbKey = '',
    bool includeOpenverse = true,
    Dio? dio,
  }) => SmartImageSearch(
    sources: <ImageSource>[
      if (pexelsKey.isNotEmpty) PexelsSource(pexelsKey, dio: dio),
      if (tmdbKey.isNotEmpty) TmdbSource(tmdbKey, dio: dio),
      if (includeOpenverse) OpenverseSource(dio: dio),
    ],
  );

  List<ImageSource> get sources => _sources;

  Future<SmartSearchResult> search(
    String query, {
    int page = 1,
    int perPage = 18,
  }) async {
    final List<ImageHit> hits = <ImageHit>[];
    final List<SourceStatus> statuses = <SourceStatus>[];
    await Future.wait(
      _sources.map((ImageSource source) async {
        if (!source.enabled) {
          statuses.add(
            SourceStatus(
              id: source.id,
              label: source.label,
              ok: false,
              count: 0,
              elapsedMs: 0,
              experimental: source.experimental,
              enabled: false,
              hint: source.disabledHint,
            ),
          );
          return;
        }
        final Stopwatch sw = Stopwatch()..start();
        try {
          final SourcePage result = await source.search(
            query,
            page: page,
            perPage: perPage,
          );
          sw.stop();
          hits.addAll(result.hits);
          statuses.add(
            SourceStatus(
              id: source.id,
              label: source.label,
              ok: true,
              count: result.hits.length,
              elapsedMs: sw.elapsedMilliseconds,
              experimental: source.experimental,
            ),
          );
        } catch (e) {
          sw.stop();
          statuses.add(
            SourceStatus(
              id: source.id,
              label: source.label,
              ok: false,
              count: 0,
              elapsedMs: sw.elapsedMilliseconds,
              error: describeNetworkError(e),
              experimental: source.experimental,
            ),
          );
        }
      }),
    );
    statuses.sort((SourceStatus a, SourceStatus b) {
      if (a.experimental != b.experimental) return a.experimental ? 1 : -1;
      return a.id.compareTo(b.id);
    });
    final List<ImageHit> deduped = dedupeHits(hits);
    final bool hasMore = statuses.any(
      (SourceStatus s) => s.ok && s.count >= perPage,
    );
    return SmartSearchResult(
      hits: deduped,
      statuses: statuses,
      page: page,
      hasMore: hasMore,
      query: query,
    );
  }

  static List<ImageHit> dedupeHits(List<ImageHit> hits) {
    final Set<String> seen = <String>{};
    final List<ImageHit> out = <ImageHit>[];
    for (final ImageHit hit in hits) {
      final String key = hit.fullUrl.split('?').first;
      if (key.isEmpty) continue;
      if (seen.add(key)) out.add(hit);
    }
    return out;
  }
}

/// 可读的网络错误描述（含域名与建议）。
String describeNetworkError(Object e) {
  if (e is DioException) {
    final String host = e.requestOptions.uri.host;
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return '连接超时（$host 不可达，可在设置页配置代理）';
      case DioExceptionType.receiveTimeout:
        return '响应超时（$host）';
      case DioExceptionType.badResponse:
        final int? code = e.response?.statusCode;
        if (code == 401 || code == 403) return '鉴权失败（$host，检查 Key）';
        if (code == 429) return '请求过频（$host）';
        return 'HTTP $code（$host）';
      case DioExceptionType.connectionError:
        return '连接失败（$host 被阻断或网络不可达）';
      case DioExceptionType.cancel:
        return '已取消（$host）';
      default:
        final String raw = e.message ?? '';
        if (raw.contains('timed out') || raw.contains('超时')) {
          return '连接超时（$host 不可达，可在设置页配置代理）';
        }
        return '网络错误（$host）：${raw.isEmpty ? e.error ?? '未知' : raw}';
    }
  }
  return '$e';
}
