import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/core/db/database.dart';
import 'package:shoot_studio/core/providers.dart';
import 'package:shoot_studio/features/ai/ai_client.dart';
import 'package:shoot_studio/features/ai/ai_controller.dart';
import 'package:shoot_studio/features/ai/provider_presets.dart';
import 'package:shoot_studio/features/planner/planner_diff.dart';
import 'package:shoot_studio/features/planner/planner_models.dart';
import 'package:shoot_studio/services/content_packs.dart';

/// 记录请求体的假适配器：reasoning 走 SSE，结构化走 JSON。
class RecordingAdapter implements HttpClientAdapter {
  RecordingAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options, String body)
  handler;
  final List<String> requestBodies = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final List<int> bytes =
        await (requestStream ?? const Stream<List<int>>.empty())
            .fold<List<int>>(
              <int>[],
              (List<int> acc, List<int> chunk) => acc..addAll(chunk),
            );
    final String body = bytes.isEmpty ? '{}' : utf8.decode(bytes);
    requestBodies.add(body);
    return handler(options, body);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object data) => ResponseBody.fromString(
  jsonEncode(data),
  200,
  headers: <String, List<String>>{
    Headers.contentTypeHeader: <String>[Headers.jsonContentType],
  },
);

ResponseBody _sse(String delta) => ResponseBody.fromString(
  'data: ${jsonEncode(<String, Object?>{
    'choices': <Object?>[
      <String, Object?>{
        'delta': <String, Object?>{'content': delta},
      },
    ],
  })}\n\ndata: [DONE]\n\n',
  200,
  headers: <String, List<String>>{
    Headers.contentTypeHeader: <String>[Headers.jsonContentType],
  },
);

Map<String, Object?> _module(
  String id,
  String type,
  String title,
  Map<String, Object?> data,
) => <String, Object?>{
  'id': id,
  'type': type,
  'title': title,
  'data': jsonEncode(data),
};

List<Object?> _goodModules() => <Object?>[
  _module('m1', 'theme', '拍摄主题', <String, Object?>{
    'text':
        '雨夜赛博朋克正片，霓虹与湿地反光为主基调。冷主光塑造人物轮廓，'
        '品红与青色点缀环境；服化道对齐角色设定，突出神态与配色一致性，'
        '重点抓住雨夜反光与霓虹光斑的氛围感。',
  }),
  _module('m2', 'crew', '人员分工', <String, Object?>{
    'rows': <Object?>[
      <String, Object?>{'role': '摄影师', 'who': 'A', 'time': '10:00'},
      <String, Object?>{'role': '妆造', 'who': 'B', 'time': '08:30'},
    ],
  }),
  _module('m3', 'budget', '预算表', <String, Object?>{
    'rows': <Object?>[
      <String, Object?>{'item': '场地', 'price': 400, 'note': '估算值'},
      <String, Object?>{'item': '妆造', 'price': 500, 'note': '估算值'},
    ],
  }),
  _module('m4', 'poses', '姿势清单', <String, Object?>{
    'poses': <Object?>[
      <String, Object?>{'name': '侧身回眸', 'lens': '35mm', 'cameraPosition': '腰位'},
      <String, Object?>{'name': '撑墙', 'lens': '50mm', 'cameraPosition': '胸口'},
      <String, Object?>{'name': '蹲姿', 'lens': '85mm', 'cameraPosition': '低机位'},
    ],
  }),
  _module('m5', 'sun', '日照时间', <String, Object?>{
    'place': '上海',
    'date': '2026-09-12',
    'lat': 31.23,
    'lon': 121.47,
  }),
];

List<Object?> _poorModules() => <Object?>[
  _module('m1', 'theme', '拍摄主题', <String, Object?>{'text': '夜景'}),
  _module('m2', 'crew', '人员分工', <String, Object?>{
    'rows': <Object?>[
      <String, Object?>{'role': '摄影师', 'who': '', 'time': ''},
    ],
  }),
  _module('m3', 'budget', '预算表', <String, Object?>{
    'rows': <Object?>[
      <String, Object?>{'item': '场地', 'price': 0, 'note': ''},
    ],
  }),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;
  late AiController controller;

  Future<void> setup({required RecordingAdapter adapter}) async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await ContentPacks.syncToDatabase(db);
    container = ProviderContainer(
      overrides: <Override>[databaseProvider.overrideWithValue(db)],
    );
    controller = container.read(aiControllerProvider.notifier);
    await controller.init();
    await controller.saveProvider(
      findProviderPreset('deepseek')!,
      apiKey: 'sk-test',
      model: 'test-model',
      baseUrl: 'https://api.deepseek.com/v1',
      enabled: true,
    );
    controller.useClient(AiClient(dio: Dio()..httpClientAdapter = adapter));
  }

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('两段式生成：先推理（流式）→ 再原生结构化，质量分达标', () async {
    final RecordingAdapter adapter = RecordingAdapter((
      RequestOptions options,
      String body,
    ) async {
      if (body.contains('"stream":true')) {
        return _sse('策划思路：以霓虹雨夜为基调，主光 45° 侧前 2.2m…');
      }
      return _json(<String, Object?>{
        'choices': <Object?>[
          <String, Object?>{
            'message': <String, Object?>{
              'content': jsonEncode(<String, Object?>{
                'modules': _goodModules(),
              }),
            },
          },
        ],
        'usage': <String, Object?>{
          'prompt_tokens': 100,
          'completion_tokens': 200,
        },
      });
    });
    await setup(adapter: adapter);

    final AiDraftResult draft = await controller.generatePlan('雨夜霓虹 cos 正片');
    expect(draft.viaLocal, isFalse);
    expect(draft.reasoning, contains('霓虹雨夜'));
    expect(draft.modules, hasLength(5));
    expect(draft.totalScore, greaterThanOrEqualTo(80));
    expect(draft.shortcomings, isEmpty);

    // 请求序列：第一条为推理流式；第二条带 json_schema 结构化。
    expect(adapter.requestBodies.first, contains('"stream":true'));
    expect(adapter.requestBodies[1], contains('json_schema'));
    expect(adapter.requestBodies[1], contains('"strict":true'));
    // 第二段输入包含第一段推理内容（上下文衔接）。
    expect(adapter.requestBodies[1], contains('霓虹雨夜'));
  });

  test('自检评分 <80：自动重试一次并在重试请求中携带短板反馈', () async {
    var structuredCalls = 0;
    final RecordingAdapter adapter = RecordingAdapter((
      RequestOptions options,
      String body,
    ) async {
      if (body.contains('"stream":true')) {
        return _sse('策划思路：先给一版简单方案…');
      }
      structuredCalls++;
      final List<Object?> modules = structuredCalls == 1
          ? _poorModules()
          : _goodModules();
      return _json(<String, Object?>{
        'choices': <Object?>[
          <String, Object?>{
            'message': <String, Object?>{
              'content': jsonEncode(<String, Object?>{'modules': modules}),
            },
          },
        ],
      });
    });
    await setup(adapter: adapter);

    final AiDraftResult draft = await controller.generatePlan('夜拍妹子');
    expect(structuredCalls, 2, reason: '低分应自动重试一次');
    expect(draft.totalScore, greaterThanOrEqualTo(80));
    expect(adapter.requestBodies.last, contains('上一次输出的不足'));
  });

  test('对话式修订：只改目标模块，返回 diff 供确认', () async {
    final RecordingAdapter adapter = RecordingAdapter((
      RequestOptions options,
      String body,
    ) async {
      return _json(<String, Object?>{
        'choices': <Object?>[
          <String, Object?>{
            'message': <String, Object?>{
              'content': jsonEncode(<String, Object?>{
                'modules': <Object?>[
                  _module('m1', 'theme', '拍摄主题', <String, Object?>{
                    'text':
                        '改为夜景霓虹：主光 300° 冷白 2.0m，品红点缀 90°，青边光 190°；'
                        '机位与胸口齐平，留出霓虹光斑作为前景层次。',
                  }),
                ],
              }),
            },
          },
        ],
      });
    });
    await setup(adapter: adapter);

    final List<PlanModuleData> current = <PlanModuleData>[
      PlanModuleData(
        id: 'm1',
        type: PlanModuleType.theme,
        title: '拍摄主题',
        data: <String, Object?>{'text': '白天的清新风格'},
      ),
      PlanModuleData(
        id: 'm2',
        type: PlanModuleType.crew,
        title: '人员分工',
        data: <String, Object?>{
          'rows': <Object?>[
            <String, Object?>{'role': '摄影师', 'who': '', 'time': '10:00'},
          ],
        },
      ),
    ];
    final AiRevisionDraft? draft = await controller.revise(
      modules: current,
      instruction: '色调换成夜景霓虹',
      targetModuleId: 'm1',
    );
    expect(draft, isNotNull);
    expect(draft!.changedModuleIds, contains('m1'));
    final PlanDiff diff = draft.diff as PlanDiff;
    expect(diff.changed, hasLength(1));
    expect(diff.changed.single.changedKeys, contains('文本'));
    expect(diff.unchanged, 1);
    // 合并结果：m1 已更新、m2 原样保留。
    final PlanModuleData mergedTheme = draft.modules.firstWhere(
      (PlanModuleData m) => m.id == 'm1',
    );
    expect(mergedTheme.data['text'], contains('夜景霓虹'));
    expect(draft.modules, hasLength(2));
  });

  test('本地引擎兜底：每个模块含可执行细节且质量分 ≥80（F3）', () async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await ContentPacks.syncToDatabase(db);
    container = ProviderContainer(
      overrides: <Override>[databaseProvider.overrideWithValue(db)],
    );
    controller = container.read(aiControllerProvider.notifier);
    await controller.init();

    final AiDraftResult draft = await controller.generatePlan(
      '汉服园林晨雾',
      forceLocal: true,
    );
    expect(draft.viaLocal, isTrue);
    expect(
      draft.totalScore,
      greaterThanOrEqualTo(80),
      reason: '本地引擎必须 100% 兜底且细节达标；当前短板：${draft.shortcomings}',
    );

    final PlanModuleData theme = draft.modules.firstWhere(
      (PlanModuleData m) => m.type == PlanModuleType.theme,
    );
    expect((theme.data['text'] as String).length, greaterThanOrEqualTo(40));

    final PlanModuleData budget = draft.modules.firstWhere(
      (PlanModuleData m) => m.type == PlanModuleType.budget,
    );
    final List<Object?> budgetRows =
        (budget.data['rows'] as List?) ?? <Object?>[];
    expect(budgetRows.length, greaterThanOrEqualTo(2));
    expect(
      budgetRows.whereType<Map>().every(
        (Map m) => ((m['price'] as num?)?.toDouble() ?? 0) > 0,
      ),
      isTrue,
    );
    expect('${(budgetRows.first as Map)['note']}', contains('估算值'));

    final PlanModuleData sun = draft.modules.firstWhere(
      (PlanModuleData m) => m.type == PlanModuleType.sun,
    );
    expect(sun.data['place'], isNotEmpty);
    expect(sun.data['date'], isNotEmpty);

    final PlanModuleData poses = draft.modules.firstWhere(
      (PlanModuleData m) => m.type == PlanModuleType.poses,
    );
    expect((poses.data['poses'] as List).isNotEmpty, isTrue);
  });
}
