import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import '../../core/design/tokens.dart';

/// AI 调用结果（含观测台所需的延迟与 token）。
class AiCallResult {
  const AiCallResult({
    required this.success,
    required this.providerId,
    required this.model,
    required this.latencyMs,
    this.content = '',
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.error = '',
  });

  final bool success;
  final String providerId;
  final String model;
  final int latencyMs;
  final String content;
  final int promptTokens;
  final int completionTokens;
  final String error;
}

/// 提供方运行时配置（Key 已解密）。
class RuntimeProvider {
  const RuntimeProvider({
    required this.id,
    required this.name,
    required this.protocol,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
  });

  final String id;
  final String name;
  final String protocol;
  final String baseUrl;
  final String apiKey;
  final String model;
}

/// 三协议适配（OpenAI 兼容 / Anthropic Messages / Responses 经 OpenAI 兼容兜底）。
class AiClient {
  AiClient({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: AppWait.network,
              receiveTimeout: AppWait.aiLong,
            ),
          );

  final Dio _dio;

  /// 连通性测试：拉取模型列表（失败则退回最小对话探测）。
  Future<AiCallResult> testConnectivity(RuntimeProvider provider) async {
    final started = DateTime.now();
    try {
      final models = await discoverModels(provider);
      if (models.isNotEmpty) {
        return AiCallResult(
          success: true,
          providerId: provider.id,
          model: models.first,
          latencyMs: DateTime.now().difference(started).inMilliseconds,
          content: '模型列表 ${models.length} 个 · 首个：${models.first}',
        );
      }
    } catch (_) {
      // 继续用对话探测。
    }
    final result = await chat(
      provider: provider,
      systemPrompt: '你是连通性测试助手，只回复一个字。',
      userPrompt: '回复：好',
      maxTokens: 8,
    );
    return result;
  }

  /// 模型发现（D9）。
  Future<List<String>> discoverModels(RuntimeProvider provider) async {
    final base = _normalize(provider);
    final headers = _headers(provider);
    final Response<dynamic> response;
    if (provider.protocol == 'anthropic') {
      response = await _dio.get<dynamic>(
        '${provider.baseUrl}/v1/models',
        options: Options(headers: headers),
      );
    } else {
      response = await _dio.get<dynamic>(
        '$base/models',
        options: Options(headers: headers),
      );
    }
    final data = response.data;
    final list = data is Map ? (data['data'] ?? data['models']) : null;
    if (list is List) {
      return list
          .whereType<Map>()
          .map((Map m) => (m['id'] ?? m['name'] ?? '').toString())
          .where((String id) => id.isNotEmpty)
          .toList();
    }
    return const <String>[];
  }

  /// 对话调用（支持 SSE 流式；失败自动回退非流式）。
  /// [schema] 非空时走原生结构化输出（OpenAI json_schema → json_object → 纯提示；
  /// Anthropic tool_use），不使用流式。
  Future<AiCallResult> chat({
    required RuntimeProvider provider,
    required String systemPrompt,
    required String userPrompt,
    int maxTokens = 4096,
    bool stream = true,
    Map<String, Object?>? schema,
    String schemaName = 'plan_modules',
    void Function(String delta)? onDelta,
  }) async {
    final started = DateTime.now();
    int latency() => DateTime.now().difference(started).inMilliseconds;
    try {
      if (provider.protocol == 'anthropic') {
        return await _anthropicChat(
          provider: provider,
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          maxTokens: maxTokens,
          latency: latency,
          schema: schema,
          schemaName: schemaName,
        );
      }
      if (schema != null) {
        return await _openAiStructured(
          provider: provider,
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          maxTokens: maxTokens,
          latency: latency,
          schema: schema,
          schemaName: schemaName,
        );
      }
      if (stream) {
        try {
          return await _openAiStream(
            provider: provider,
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            maxTokens: maxTokens,
            onDelta: onDelta,
            latency: latency,
          );
        } catch (_) {
          // 流式失败 → 非流式回退。
        }
      }
      return await _openAiPlain(
        provider: provider,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        maxTokens: maxTokens,
        latency: latency,
      );
    } on DioException catch (e) {
      return AiCallResult(
        success: false,
        providerId: provider.id,
        model: provider.model,
        latencyMs: latency(),
        error: _describeDioError(e),
      );
    } catch (e) {
      return AiCallResult(
        success: false,
        providerId: provider.id,
        model: provider.model,
        latencyMs: latency(),
        error: '$e',
      );
    }
  }

  /// 视觉调用（D96/D116 以图搜图）：OpenAI 兼容 content 数组 / Anthropic image block。
  /// 不支持图片输入的提供方会返回失败（由调用方提示切换或降级文本，不静默失败）。
  Future<AiCallResult> chatWithImage({
    required RuntimeProvider provider,
    required String systemPrompt,
    required String userPrompt,
    required String imageBase64,
    String imageMime = 'image/jpeg',
    int maxTokens = 512,
  }) async {
    final started = DateTime.now();
    int latency() => DateTime.now().difference(started).inMilliseconds;
    try {
      final Response<Map<String, dynamic>> response;
      if (provider.protocol == 'anthropic') {
        response = await _dio.post<Map<String, dynamic>>(
          '${_normalize(provider)}/v1/messages',
          options: Options(headers: _headers(provider)),
          data: <String, Object?>{
            'model': provider.model,
            'max_tokens': maxTokens,
            'system': systemPrompt,
            'messages': <Object?>[
              <String, Object?>{
                'role': 'user',
                'content': <Object?>[
                  <String, Object?>{
                    'type': 'image',
                    'source': <String, Object?>{
                      'type': 'base64',
                      'media_type': imageMime,
                      'data': imageBase64,
                    },
                  },
                  <String, Object?>{'type': 'text', 'text': userPrompt},
                ],
              },
            ],
          },
        );
      } else {
        response = await _dio.post<Map<String, dynamic>>(
          '${_normalize(provider)}/chat/completions',
          options: Options(headers: _headers(provider)),
          data: <String, Object?>{
            'model': provider.model,
            'max_tokens': maxTokens,
            'messages': <Object?>[
              <String, Object?>{'role': 'system', 'content': systemPrompt},
              <String, Object?>{
                'role': 'user',
                'content': <Object?>[
                  <String, Object?>{'type': 'text', 'text': userPrompt},
                  <String, Object?>{
                    'type': 'image_url',
                    'image_url': <String, Object?>{
                      'url': 'data:$imageMime;base64,$imageBase64',
                    },
                  },
                ],
              },
            ],
          },
        );
      }
      final data = response.data ?? <String, dynamic>{};
      final usage = data['usage'] is Map
          ? (data['usage'] as Map).cast<String, Object?>()
          : <String, Object?>{};
      final buffer = StringBuffer();
      if (provider.protocol == 'anthropic') {
        final contentField = data['content'];
        if (contentField is List) {
          for (final Object? block in contentField) {
            if (block is Map && block['type'] == 'text') {
              buffer.write(block['text']);
            }
          }
        }
      } else {
        final choices = data['choices'];
        if (choices is List && choices.isNotEmpty && choices.first is Map) {
          final message = (choices.first as Map)['message'];
          if (message is Map) {
            final content = message['content'];
            if (content is String) {
              buffer.write(content);
            } else if (content is List) {
              for (final Object? part in content) {
                if (part is Map && part['text'] != null) {
                  buffer.write(part['text']);
                }
              }
            }
          }
        }
      }
      final content = buffer.toString().trim();
      final Object? promptUsage =
          usage['prompt_tokens'] ?? usage['input_tokens'];
      final Object? completionUsage =
          usage['completion_tokens'] ?? usage['output_tokens'];
      return AiCallResult(
        success: content.isNotEmpty,
        providerId: provider.id,
        model: provider.model,
        latencyMs: latency(),
        content: content,
        promptTokens: promptUsage is num ? promptUsage.toInt() : 0,
        completionTokens: completionUsage is num ? completionUsage.toInt() : 0,
        error: content.isEmpty ? '视觉返回为空（提供方可能不支持图片输入）' : '',
      );
    } on DioException catch (e) {
      return AiCallResult(
        success: false,
        providerId: provider.id,
        model: provider.model,
        latencyMs: latency(),
        error: _describeDioError(e),
      );
    } catch (e) {
      return AiCallResult(
        success: false,
        providerId: provider.id,
        model: provider.model,
        latencyMs: latency(),
        error: '$e',
      );
    }
  }

  /// OpenAI 兼容的结构化输出链：json_schema(strict) → json_object → 纯提示。
  Future<AiCallResult> _openAiStructured({
    required RuntimeProvider provider,
    required String systemPrompt,
    required String userPrompt,
    required int maxTokens,
    required int Function() latency,
    required Map<String, Object?> schema,
    required String schemaName,
  }) async {
    final List<Map<String, Object?>?> formats = <Map<String, Object?>?>[
      <String, Object?>{
        'type': 'json_schema',
        'json_schema': <String, Object?>{
          'name': schemaName,
          'strict': true,
          'schema': schema,
        },
      },
      <String, Object?>{'type': 'json_object'},
      null,
    ];
    AiCallResult last = AiCallResult(
      success: false,
      providerId: provider.id,
      model: provider.model,
      latencyMs: 0,
      error: '未发起请求',
    );
    for (final Map<String, Object?>? format in formats) {
      try {
        final AiCallResult result = await _openAiPlain(
          provider: provider,
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          maxTokens: maxTokens,
          latency: latency,
          responseFormat: format,
        );
        if (result.success) {
          // 结构化模式下 data 可能是 JSON 字符串，规范化交给调用方处理。
          return result;
        }
        last = result;
      } catch (e) {
        last = AiCallResult(
          success: false,
          providerId: provider.id,
          model: provider.model,
          latencyMs: latency(),
          error: '$e',
        );
      }
    }
    return last;
  }

  String _normalize(RuntimeProvider provider) => provider.baseUrl.endsWith('/')
      ? provider.baseUrl.substring(0, provider.baseUrl.length - 1)
      : provider.baseUrl;

  Map<String, String> _headers(RuntimeProvider provider) {
    if (provider.protocol == 'anthropic') {
      return <String, String>{
        'x-api-key': provider.apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      };
    }
    return <String, String>{
      if (provider.apiKey.isNotEmpty)
        'Authorization': 'Bearer ${provider.apiKey}',
      'content-type': 'application/json',
    };
  }

  String _describeDioError(DioException e) {
    final status = e.response?.statusCode;
    if (status == 401 || status == 403) return '鉴权失败（$status）：请检查 API Key';
    if (status == 404) return '端点不存在（404）：请检查 Base URL';
    if (status == 429) return '请求过于频繁或被限流（429）';
    return '网络错误：${e.type.name}${status != null ? ' · HTTP $status' : ''}';
  }

  Future<AiCallResult> _openAiPlain({
    required RuntimeProvider provider,
    required String systemPrompt,
    required String userPrompt,
    required int maxTokens,
    required int Function() latency,
    Map<String, Object?>? responseFormat,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '${_normalize(provider)}/chat/completions',
      options: Options(headers: _headers(provider)),
      data: <String, Object?>{
        'model': provider.model,
        'max_tokens': maxTokens,
        if (responseFormat != null) 'response_format': responseFormat,
        'messages': <Object?>[
          <String, Object?>{'role': 'system', 'content': systemPrompt},
          <String, Object?>{'role': 'user', 'content': userPrompt},
        ],
      },
    );
    final data = response.data ?? <String, dynamic>{};
    final usage = data['usage'] is Map
        ? (data['usage'] as Map).cast<String, Object?>()
        : <String, Object?>{};
    final choices = data['choices'];
    String content = '';
    if (choices is List && choices.isNotEmpty && choices.first is Map) {
      final message = (choices.first as Map)['message'];
      if (message is Map) content = (message['content'] ?? '').toString();
    }
    return AiCallResult(
      success: content.isNotEmpty,
      providerId: provider.id,
      model: provider.model,
      latencyMs: latency(),
      content: content,
      promptTokens: (usage['prompt_tokens'] as num?)?.toInt() ?? 0,
      completionTokens: (usage['completion_tokens'] as num?)?.toInt() ?? 0,
      error: content.isEmpty ? '返回内容为空' : '',
    );
  }

  Future<AiCallResult> _openAiStream({
    required RuntimeProvider provider,
    required String systemPrompt,
    required String userPrompt,
    required int maxTokens,
    required int Function() latency,
    void Function(String delta)? onDelta,
  }) async {
    final response = await _dio.post<ResponseBody>(
      '${_normalize(provider)}/chat/completions',
      options: Options(
        headers: _headers(provider),
        responseType: ResponseType.stream,
      ),
      data: <String, Object?>{
        'model': provider.model,
        'max_tokens': maxTokens,
        'stream': true,
        'messages': <Object?>[
          <String, Object?>{'role': 'system', 'content': systemPrompt},
          <String, Object?>{'role': 'user', 'content': userPrompt},
        ],
      },
    );
    final body = response.data;
    if (body == null) throw StateError('空响应');
    final buffer = StringBuffer();
    var promptTokens = 0;
    var completionTokens = 0;
    final lines = body.stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    await for (final String line in lines) {
      if (!line.startsWith('data:')) continue;
      final payload = line.substring(5).trim();
      if (payload == '[DONE]') break;
      try {
        final event = jsonDecode(payload);
        if (event is! Map) continue;
        final usage = event['usage'];
        if (usage is Map) {
          promptTokens =
              (usage['prompt_tokens'] as num?)?.toInt() ?? promptTokens;
          completionTokens =
              (usage['completion_tokens'] as num?)?.toInt() ?? completionTokens;
        }
        final choices = event['choices'];
        if (choices is List && choices.isNotEmpty && choices.first is Map) {
          final delta = (choices.first as Map)['delta'];
          if (delta is Map) {
            final piece = delta['content'];
            if (piece is String && piece.isNotEmpty) {
              buffer.write(piece);
              onDelta?.call(piece);
            }
          }
        }
      } catch (_) {
        // 忽略单行解析失败。
      }
    }
    final content = buffer.toString();
    return AiCallResult(
      success: content.isNotEmpty,
      providerId: provider.id,
      model: provider.model,
      latencyMs: latency(),
      content: content,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      error: content.isEmpty ? '流式返回为空' : '',
    );
  }

  Future<AiCallResult> _anthropicChat({
    required RuntimeProvider provider,
    required String systemPrompt,
    required String userPrompt,
    required int maxTokens,
    required int Function() latency,
    Map<String, Object?>? schema,
    String schemaName = 'plan_modules',
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '${_normalize(provider)}/v1/messages',
      options: Options(headers: _headers(provider)),
      data: <String, Object?>{
        'model': provider.model,
        'max_tokens': maxTokens,
        'system': systemPrompt,
        if (schema != null) ...<String, Object?>{
          'tools': <Object?>[
            <String, Object?>{
              'name': schemaName,
              'description': '输出结构化策划模块 JSON',
              'input_schema': schema,
            },
          ],
          'tool_choice': <String, Object?>{'type': 'tool', 'name': schemaName},
        },
        'messages': <Object?>[
          <String, Object?>{'role': 'user', 'content': userPrompt},
        ],
      },
    );
    final data = response.data ?? <String, dynamic>{};
    final usage = data['usage'] is Map
        ? (data['usage'] as Map).cast<String, Object?>()
        : <String, Object?>{};
    final contentField = data['content'];
    final buffer = StringBuffer();
    if (contentField is List) {
      for (final Object? block in contentField) {
        if (block is Map && block['type'] == 'text') {
          buffer.write(block['text']);
        }
        // tool_use 结构化输出（F3）。
        if (block is Map && block['type'] == 'tool_use') {
          buffer.write(jsonEncode(block['input']));
        }
      }
    }
    final content = buffer.toString();
    return AiCallResult(
      success: content.isNotEmpty,
      providerId: provider.id,
      model: provider.model,
      latencyMs: latency(),
      content: content,
      promptTokens: (usage['input_tokens'] as num?)?.toInt() ?? 0,
      completionTokens: (usage['output_tokens'] as num?)?.toInt() ?? 0,
      error: content.isEmpty ? '返回内容为空' : '',
    );
  }
}

