import 'dart:convert';

import '../core/db/database.dart';
import '../features/ai/ai_client.dart';
import '../features/ai/key_vault.dart';
import '../features/ai/provider_presets.dart';

/// AI 检索词翻译（D81/R33）：用已配置的默认 AI 提供方把中文查询译为
/// 英文检索词；结果缓存到 settings（LRU 200）；未配置/失败时返回空串，
/// 由调用方回退词表（不得把中文原样发往英文源）。
class QueryTranslator {
  QueryTranslator(this._db, {this.timeout = const Duration(seconds: 6)});

  final AppDatabase _db;
  final Duration timeout;

  static const String cacheKey = 'query_translation_cache';
  static const int cacheLimit = 200;

  /// 翻译（命中缓存直接返回）。
  Future<String> translate(String chinese) async {
    final String input = chinese.trim();
    if (input.isEmpty) return '';
    final Map<String, Object?> cache = await _loadCache();
    final Object? cached = cache[input];
    if (cached is String && cached.isNotEmpty) return cached;

    final RuntimeProvider? provider = await defaultProvider();
    if (provider == null) return '';
    try {
      final AiCallResult result = await AiClient()
          .chat(
            provider: provider,
            systemPrompt:
                '你是摄影图片检索助手。把用户的中文画面描述翻译成 3-8 个'
                '英文检索关键词（空格分隔，不要标点、不要解释、不要引号）。',
            userPrompt: input,
            maxTokens: 60,
            stream: false,
          )
          .timeout(timeout);
      if (!result.success) return '';
      final String cleaned = _clean(result.content);
      if (cleaned.isEmpty) return '';
      cache[input] = cleaned;
      while (cache.length > cacheLimit) {
        cache.remove(cache.keys.first);
      }
      await _db.setSetting(cacheKey, jsonEncode(cache));
      return cleaned;
    } catch (_) {
      return '';
    }
  }

  Future<Map<String, Object?>> _loadCache() async {
    try {
      final String raw = await _db.getSetting(cacheKey) ?? '{}';
      return (jsonDecode(raw) as Map).cast<String, Object?>();
    } catch (_) {
      return <String, Object?>{};
    }
  }

  /// 仅保留 ASCII 检索词（去掉模型输出中的标点/解释/中文）。
  static String _clean(String raw) => raw
      .replaceAll(RegExp(r'[^\x00-\x7F]+'), ' ')
      .replaceAll(RegExp(r'''[^\w\s-]+'''), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// 默认 AI 提供方（按 priority；未配置/无 Key 返回 null）。
  Future<RuntimeProvider?> defaultProvider() async {
    final List<ProviderConfig> rows = await _db
        .select(_db.providerConfigs)
        .get();
    rows.sort(
      (ProviderConfig a, ProviderConfig b) => a.priority.compareTo(b.priority),
    );
    final KeyVault vault = KeyVault();
    for (final ProviderConfig row in rows) {
      if (!row.enabled || row.encryptedKey.isEmpty) continue;
      AiProviderPreset? preset;
      for (final AiProviderPreset p in aiProviderPresets) {
        if (p.id == row.id) {
          preset = p;
          break;
        }
      }
      if (preset == null) continue;
      final String key = await vault.decrypt(row.encryptedKey);
      if (key.isEmpty) continue;
      return RuntimeProvider(
        id: preset.id,
        name: preset.name,
        protocol: preset.protocol,
        baseUrl: preset.baseUrl,
        apiKey: key,
        model: row.defaultModel.isNotEmpty
            ? row.defaultModel
            : preset.defaultModel,
      );
    }
    return null;
  }
}
