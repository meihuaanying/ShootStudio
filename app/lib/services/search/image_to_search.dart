import 'dart:convert';
import 'dart:typed_data';

import '../../core/db/database.dart';
import '../../features/ai/ai_client.dart';
import '../image_store.dart';
import '../net_router.dart';
import '../query_translator.dart';
import 'keywords.dart';
import 'search_models.dart';

/// 视觉描述结果。
class VisionResult {
  const VisionResult({
    required this.success,
    this.description = '',
    this.keywords = '',
    this.providerName = '',
    this.error = '',
  });

  final bool success;
  final String description;
  final String keywords;
  final String providerName;
  final String error;

  /// 是否因未配置 AI / 提供方不支持图片而失败（UI 给降级建议）。
  bool get needsConfiguration => error.isNotEmpty;
}

/// V6 以图搜图（D116）：上传参考图 → AI 视觉描述（风格/光线/色彩/构图）
/// → 多源文本搜；无视觉能力时提示配置并降级为文本关键词（D96）。
class ImageToSearch {
  ImageToSearch(this._db, {AiClient? client})
    : _client =
          client ??
          AiClient(
            dio: NetRouter.I.dio(receiveTimeout: const Duration(seconds: 60)),
          );

  final AppDatabase _db;
  final AiClient _client;

  static const String systemPrompt =
      '你是摄影参考图分析助手。'
      '分析用户上传的图片，用中文描述其风格、光线（方向/软硬/色温）、'
      '色彩（给出 2-3 个主色）、构图与题材；'
      '最后另起一行输出 3-8 个英文检索关键词，格式：KEYWORDS: word1 word2 …';

  /// 视觉描述（压缩图片 → 默认提供方；不支持图片时返回失败原因）。
  Future<VisionResult> describe(Uint8List bytes) async {
    if (bytes.isEmpty) {
      return const VisionResult(success: false, error: '图片为空');
    }
    final RuntimeProvider? provider = await QueryTranslator(
      _db,
    ).defaultProvider();
    if (provider == null) {
      return const VisionResult(
        success: false,
        error: '未配置 AI 提供方：以图搜图需要视觉模型，可在设置页配置后再试，或直接输入关键词搜索',
      );
    }
    final Uint8List compressed = ImageStore.compress(bytes, maxKb: 900);
    final AiCallResult result = await _client.chatWithImage(
      provider: provider,
      systemPrompt: systemPrompt,
      userPrompt: '分析这张参考图，并给出英文检索关键词。',
      imageBase64: base64Encode(compressed),
      imageMime: 'image/jpeg',
      maxTokens: 600,
    );
    if (!result.success) {
      return VisionResult(
        success: false,
        providerName: provider.name,
        error:
            '视觉调用失败（${provider.name}）：${result.error}；'
            '可切换到支持图片输入的提供方，或改用关键词搜索',
      );
    }
    final (String description, String keywords) = _split(result.content);
    return VisionResult(
      success: true,
      description: description,
      keywords: keywords,
      providerName: provider.name,
    );
  }

  /// 视觉描述 → 可执行的多源查询。
  Future<({VisionResult vision, SearchQuery? query})> planFromImage(
    Uint8List bytes, {
    ImageDomain domain = ImageDomain.photo,
  }) async {
    final VisionResult vision = await describe(bytes);
    if (!vision.success || !hasAsciiQuery(vision.keywords)) {
      return (vision: vision, query: null);
    }
    return (
      vision: vision,
      query: SearchQuery(
        raw: vision.description.isEmpty ? '以图搜图' : vision.description,
        intent: SearchIntent.keyword,
        text: vision.keywords,
        domain: domain,
        sourceNote: 'AI 视觉描述（${vision.providerName}）',
      ),
    );
  }

  /// 拆分描述与 KEYWORDS 行。
  static (String, String) _split(String content) {
    final String text = content.trim();
    final RegExp re = RegExp(r'KEYWORDS\s*[:：]\s*(.+)', caseSensitive: false);
    final RegExpMatch? match = re.firstMatch(text);
    String keywords = '';
    String description = text;
    if (match != null) {
      keywords = _cleanKeywords(match.group(1) ?? '');
      description = text.substring(0, match.start).trim();
    }
    if (keywords.isEmpty) {
      // 模型没按格式输出：取最后一行英文词。
      for (final String line in text.split('\n').reversed) {
        final String cleaned = _cleanKeywords(line);
        if (cleaned.split(' ').length >= 2) {
          keywords = cleaned;
          break;
        }
      }
    }
    return (description, keywords);
  }

  /// 测试入口：解析视觉模型输出（描述 + KEYWORDS）。
  static (String, String) debugSplit(String content) => _split(content);

  /// 仅保留 ASCII 检索词。
  static String _cleanKeywords(String raw) => raw
      .replaceAll(RegExp(r'[^\x00-\x7F]+'), ' ')
      .replaceAll(RegExp(r'''[^\w\s-]+'''), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
