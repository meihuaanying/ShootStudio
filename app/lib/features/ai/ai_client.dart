import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

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
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 90),
            ));

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
      response = await _dio.get<dynamic>('${provider.baseUrl}/v1/models',
          options: Options(headers: headers));
    } else {
      response = await _dio.get<dynamic>('$base/models',
          options: Options(headers: headers));
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

/// OpenAI/Anthropic 通用：结构严格的策划模块 Schema（data 为 JSON 字符串以兼容 strict 模式）。
final Map<String, Object?> planJsonSchema = <String, Object?>{
  'type': 'object',
  'properties': <String, Object?>{
    'modules': <String, Object?>{
      'type': 'array',
      'items': <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'id': <String, Object?>{'type': 'string'},
          'type': <String, Object?>{
            'type': 'string',
            'enum': ModuleTypeNames.all,
          },
          'title': <String, Object?>{'type': 'string'},
          'data': <String, Object?>{
            'type': 'string',
            'description': '模块 data 的 JSON 字符串（如 {"text":"..."}）',
          },
        },
        'required': <String>['id', 'type', 'title', 'data'],
        'additionalProperties': false,
      },
    },
  },
  'required': <String>['modules'],
  'additionalProperties': false,
};

/// 模块类型名（避免 ai_client ↔ planner 循环依赖）。
abstract final class ModuleTypeNames {
  static const List<String> all = <String>[
    'theme',
    'model',
    'location',
    'sun',
    'refs',
    'palette',
    'lighting',
    'poses',
    'storyboard',
    'clothing',
    'props',
    'makeup',
    'crew',
    'budget',
    'richText',
  ];
}

/// 规范化模块 JSON：解包 data（字符串 → Map），过滤非法项。
List<Map<String, Object?>> normalizeModules(List<Object?> raw) {
  final out = <Map<String, Object?>>[];
  for (final Object? item in raw) {
    if (item is! Map) continue;
    final Map<String, Object?> map = item.cast<String, Object?>();
    Object? data = map['data'];
    if (data is String) {
      try {
        data = jsonDecode(data);
      } catch (_) {
        data = <String, Object?>{};
      }
    }
    if (data is! Map) data = <String, Object?>{};
    out.add(<String, Object?>{
      ...map,
      'data': (data).cast<String, Object?>(),
    });
  }
  return out;
}

/// 从模型输出中提取模块 JSON（容忍 ```json 围栏与前后杂文）。
List<Object?>? extractModules(String content) {
  var text = content.trim();
  final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(text);
  if (fence != null) text = fence.group(1)!.trim();
  Object? decoded;
  try {
    decoded = jsonDecode(text);
  } catch (_) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start >= 0 && end > start) {
      try {
        decoded = jsonDecode(text.substring(start, end + 1));
      } catch (_) {
        return null;
      }
    } else {
      return null;
    }
  }
  if (decoded is Map) {
    final modules = decoded['modules'];
    if (modules is List) return modules;
  }
  if (decoded is List) return decoded;
  return null;
}

/// 第一段：推理策划思路（自由文本，含可执行细节；F3）。
String buildReasoningSystemPrompt() => '''
你是资深摄影策划。针对用户主题与工作区上下文，先用中文写一份策划思路（不要输出 JSON），包含：
1) 画面基调：色调（给出 2-3 个 HEX）、构图、光影方向；
2) 布光方案：主光/辅光/轮廓光的方位角与距离量级、光比、色温；
3) 姿势编排：3-5 个动作，含镜头焦段与机位高度；
4) 服化道与场地要点、拍摄时间轴（含备选时段）、现场风险与预案；
5) 预算区间：参考给定价格区间，按城市档位修正。
要求具体、可执行、不空话；总量 300-600 字。''';

/// 第二段（修订）：只输出被修改/新增模块。
String buildRevisionSystemPrompt() => '''
你是摄影策划修订助手。根据用户指令，只输出需要变更或新增的策划模块 JSON：
{"modules":[{"id":"保持原 id（新增模块可自拟）","type":"<类型>","title":"<标题>","data":"<data 的 JSON 字符串>"}]}
规则：
- 修改已有模块时必须保持原 id；未修改的模块不要输出；
- data 必须是 JSON 字符串（把对象再编码一层为字符串），例如：{"text":"..."}；
- 变更要具体可执行（参数、数字、时间），不得改变用户未要求的模块；
- 输出仅含 JSON，不要解释文字。''';

/// 组装策划生成系统提示词（中文；内嵌 14 模块 Schema）。
String buildPlanSystemPrompt() => '''
你是专业摄影正片策划助手。请根据用户主题与工作区资源摘要，生成结构化策划案模块 JSON。
只输出 JSON，不要多余文字。输出格式：
{"modules":[{"id":"m1","type":"<类型>","title":"<中文标题>","data":{...}}]}

可用 type（必须从以下枚举选择）：
theme（拍摄主题）、model（模特绑定）、location（场地绑定）、sun（日照时间）、refs（参考样片）、
palette（色调色卡）、lighting（布光图）、poses（姿势清单）、storyboard（分镜表）、clothing（服装清单）、
props（道具清单）、makeup（妆面造型）、crew（人员分工）、budget（预算表）、richText（自定义富文本）

data 字段要求：
- theme/richText: {"text":"中文内容"}
- model/location/clothing/props/makeup: {"ids":[],"note":"中文建议"}
- sun: {"place":"城市","lat":30.2,"lon":120.1,"date":"2026-09-12"}
- refs: {"refs":[]}
- palette: {"colors":["#RRGGBB" ×5]}
- lighting: {"sceneId":"","sceneName":"","note":"布光建议","lights":[{"name":"主光","type":"soft","x":-1.2,"y":-1.6,"height":2.2,"intensity":70,"kelvin":5600,"modifier":"softbox-90"}]}
  lights 必须 ≥3 盏：按三点布光（主光/辅光/轮廓光）给出可执行数值；x/y 单位米（被摄体在原点，x 向右为正，y 朝相机方向为正），
  灯高 1.5–2.6，强度 20–100，色温 3200–6500，type 取 soft/hard/panel，modifier 取 softbox-90/umbrella-white/barn/bare 等。
- poses: {"poses":[]}
- storyboard: {"shots":[{"no":1,"shotSize":"全身","camera":"腰位","lens":"35mm","pose":"侧身回眸","lighting":"主光冷白 45°","key":true,"note":"开场建立环境"}]}
  shots 必须 8–12 个镜头，按拍摄顺序；shotSize 取 远景/全身/中景/近景/特写/空镜；
  camera 取 低机位/腰位/胸口/眼位/俯拍/过肩；lens 为焦段（如 24mm/35mm/50mm/85mm/135mm）；
  pose 用姿势名；lighting 写主光状态；第 1 镜与结尾镜 key=true。
- crew: {"rows":[{"role":"摄影师","who":"","time":"09:00"}]}
- budget: {"rows":[{"item":"场地","price":300,"note":""}]}

要求：中文内容；必须包含 theme、lighting、poses、storyboard、crew、budget 模块；
布光必须给出 lights 数值；姿势清单要给出与主题贴合的顺序化镜头姿势建议（可用空数组让应用自动补齐）；
建议不得与用户已选条件冲突。
''';
