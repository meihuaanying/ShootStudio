import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/core/db/database.dart';
import 'package:shoot_studio/core/providers.dart';
import 'package:shoot_studio/features/ai/ai_client.dart';
import 'package:shoot_studio/features/ai/ai_controller.dart';
import 'package:shoot_studio/features/ai/provider_presets.dart';
import 'package:shoot_studio/features/planner/planner_models.dart';
import 'package:shoot_studio/services/content_packs.dart';

class RecordingAdapter implements HttpClientAdapter {
  RecordingAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options, String body)
      handler;
  final List<String> bodies = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final List<int> bytes = await (requestStream ??
            const Stream<List<int>>.empty())
        .fold<List<int>>(<int>[], (List<int> a, List<int> c) => a..addAll(c));
    final String body = bytes.isEmpty ? '{}' : utf8.decode(bytes);
    bodies.add(body);
    return handler(options, body);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object data, {int code = 200}) => ResponseBody.fromString(
      jsonEncode(data),
      code,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );

ResponseBody _sse(String text) => ResponseBody.fromString(
      'data: ${jsonEncode(<String, Object?>{
            'choices': <Object?>[
              <String, Object?>{
                'delta': <String, Object?>{'content': text},
              },
            ],
          })}\n\ndata: [DONE]\n\n',
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );

Map<String, Object?> _module(
        String id, String type, String title, Map<String, Object?> data) =>
    <String, Object?>{
      'id': id,
      'type': type,
      'title': title,
      'data': jsonEncode(data),
    };

List<Object?> _goodModules() => <Object?>[
      _module('m1', 'theme', '拍摄主题', <String, Object?>{
        'text': '雨夜赛博朋克正片：霓虹与湿地反光为主基调，冷主光塑造轮廓，'
            '品红与青色点缀，重点抓住雨夜反光与霓虹光斑的氛围感。',
      }),
      _module('m2', 'lighting', '布光图', <String, Object?>{
        'sceneId': '',
        'sceneName': '雨夜双灯',
        'note': '主光冷白 + 霓虹轮廓',
        'lights': <Object?>[
          <String, Object?>{
            'name': '主光',
            'type': 'soft',
            'x': -1.2,
            'y': -1.6,
            'height': 2.2,
            'intensity': 70,
            'kelvin': 4300,
          },
          <String, Object?>{
            'name': '品红点缀',
            'type': 'hard',
            'x': 1.8,
            'y': 0.6,
            'height': 1.6,
            'intensity': 50,
            'kelvin': 6000,
          },
          <String, Object?>{
            'name': '青边光',
            'type': 'hard',
            'x': 1.0,
            'y': 2.0,
            'height': 2.4,
            'intensity': 45,
            'kelvin': 6500,
          },
        ],
      }),
      _module('m3', 'poses', '姿势清单', <String, Object?>{
        'poses': <Object?>[
          <String, Object?>{
            'name': '侧身回眸',
            'lens': '35mm',
            'cameraPosition': '腰位',
            'joints': <String, Object?>{
              'spine': <double>[0, 20, 0],
            },
          },
        ],
      }),
      _module('m4', 'budget', '预算表', <String, Object?>{
        'rows': <Object?>[
          <String, Object?>{'item': '场地', 'price': 400, 'note': '估算值'},
          <String, Object?>{'item': '妆造', 'price': 500, 'note': '估算值'},
        ],
      }),
      _module('m5', 'crew', '人员分工', <String, Object?>{
        'rows': <Object?>[
          <String, Object?>{'role': '摄影师', 'who': 'A', 'time': '10:00'},
          <String, Object?>{'role': '妆造', 'who': 'B', 'time': '08:30'},
        ],
      }),
      _module('m6', 'sun', '日照时间', <String, Object?>{
        'place': '上海',
        'date': '2026-09-12',
        'lat': 31.23,
        'lon': 121.47,
      }),
      _module('m7', 'palette', '色调色卡', <String, Object?>{
        'colors': <String>['#c24e2a', '#2f3a4a', '#e3dbcf'],
      }),
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;
  late AiController controller;

  Future<void> setup(RecordingAdapter adapter) async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await ContentPacks.syncToDatabase(db);
    container = ProviderContainer(
      overrides: <Override>[databaseProvider.overrideWithValue(db)],
    );
    controller = container.read(aiControllerProvider.notifier);
    await controller.init();
    controller.useClient(AiClient(dio: Dio()..httpClientAdapter = adapter));
  }

  tearDown(() async {
    try {
      container.dispose();
      await db.close();
    } catch (_) {
      // 纯函数用例未初始化容器。
    }
  });

  test('D40：pickBestModel 质量优先并过滤非对话模型', () {
    expect(
      pickBestModel(<String>['text-embedding-3', 'deepseek-chat', 'gpt-4o']),
      'deepseek-chat',
    );
    expect(
      pickBestModel(<String>['foo-mini', 'glm-5.2', 'kimi-k2.6']),
      'glm-5.2',
    );
    expect(pickBestModel(<String>['unknown-a', 'unknown-b']), 'unknown-a');
    expect(pickBestModel(<String>['a'], preferred: 'a'), 'a');
    expect(pickBestModel(<String>['embed-1', 'rerank-2']), '');
  });

  test('J1：生成后阅读数据完整（推理/评分/尝试链/流式文本）', () async {
    final RecordingAdapter adapter = RecordingAdapter(
      (RequestOptions options, String body) async {
        if (body.contains('"stream":true')) {
          return _sse('策划思路：霓虹雨夜，冷主光 + 品红与青边光。');
        }
        return _json(<String, Object?>{
          'choices': <Object?>[
            <String, Object?>{
              'message': <String, Object?>{
                'content':
                    jsonEncode(<String, Object?>{'modules': _goodModules()}),
              },
            },
          ],
        });
      },
    );
    await setup(adapter);
    await controller.saveProvider(
      findProviderPreset('deepseek')!,
      apiKey: 'sk-test',
      model: 'deepseek-chat',
      baseUrl: 'https://api.deepseek.com/v1',
      enabled: true,
    );

    final AiDraftResult draft = await controller.generatePlan('雨夜霓虹');
    expect(draft.reasoning, contains('霓虹'));
    expect(draft.totalScore, greaterThanOrEqualTo(90));
    expect(draft.attempts, isNotEmpty);
    expect(draft.attempts.last, contains('成功'));
    final AiState state = container.read(aiControllerProvider);
    expect(state.streamText, contains('霓虹'));
    expect(state.reasoningText, contains('霓虹'));
  });

  test('J1/J2：AI 灯位自动物化为可打开布光场景并回绑 sceneId', () async {
    final RecordingAdapter adapter = RecordingAdapter(
      (RequestOptions options, String body) async {
        if (body.contains('"stream":true')) {
          return _sse('策划思路：三点布光。');
        }
        return _json(<String, Object?>{
          'choices': <Object?>[
            <String, Object?>{
              'message': <String, Object?>{
                'content':
                    jsonEncode(<String, Object?>{'modules': _goodModules()}),
              },
            },
          ],
        });
      },
    );
    await setup(adapter);
    await controller.saveProvider(
      findProviderPreset('deepseek')!,
      apiKey: 'sk-test',
      model: 'deepseek-chat',
      baseUrl: 'https://api.deepseek.com/v1',
      enabled: true,
    );

    final AiDraftResult draft = await controller.generatePlan('雨夜霓虹');
    final PlanModuleData lighting = draft.modules
        .firstWhere((PlanModuleData m) => m.type == PlanModuleType.lighting);
    final String sceneId = lighting.data['sceneId'] as String? ?? '';
    expect(sceneId, isNotEmpty, reason: '应自动物化并绑定布光场景');
    final List<LightingScene> rows = await db.select(db.lightingScenes).get();
    expect(rows, hasLength(1));
    expect(rows.first.id, sceneId);
    expect(rows.first.sceneJson, contains('"主光"'));
    // 物化后不再有"场景不存在"的短板。
    expect(
      draft.shortcomings.any((String s) => s.contains('布光')),
      isFalse,
    );
  });

  test('D40：主商失败自动换模型/换商，尝试链可追溯', () async {
    final RecordingAdapter adapter = RecordingAdapter(
      (RequestOptions options, String body) async {
        final Object? auth = options.headers['Authorization'];
        if ('$auth'.contains('sk-first')) {
          return _json(<String, Object?>{
            'error': <String, Object?>{'message': 'invalid api key'},
          }, code: 401);
        }
        if (body.contains('"stream":true')) {
          return _sse('备用商策划思路。');
        }
        return _json(<String, Object?>{
          'choices': <Object?>[
            <String, Object?>{
              'message': <String, Object?>{
                'content':
                    jsonEncode(<String, Object?>{'modules': _goodModules()}),
              },
            },
          ],
        });
      },
    );
    await setup(adapter);
    await controller.saveProvider(
      findProviderPreset('deepseek')!,
      apiKey: 'sk-first',
      model: 'deepseek-chat',
      baseUrl: 'https://api.deepseek.com/v1',
      enabled: true,
    );
    await controller.saveProvider(
      findProviderPreset('zhipu')!,
      apiKey: 'sk-second',
      model: 'glm-4-flash',
      baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
      enabled: true,
    );

    final AiDraftResult draft = await controller.generatePlan('汉服园林');
    expect(draft.viaLocal, isFalse);
    expect(draft.providerName, '智谱 GLM');
    expect(draft.attempts.any((String a) => a.contains('失败')), isTrue);
    expect(draft.attempts.any((String a) => a.contains('成功')), isTrue);
  });
}
