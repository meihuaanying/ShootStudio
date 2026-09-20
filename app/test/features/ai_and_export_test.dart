import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:shoot_studio/core/db/database.dart';
import 'package:shoot_studio/core/workspace/workspace.dart';
import 'package:shoot_studio/features/ai/ai_client.dart';
import 'package:shoot_studio/features/ai/ai_controller.dart';
import 'package:shoot_studio/features/ai/key_vault.dart';
import 'package:shoot_studio/features/export/exporter.dart';
import 'package:shoot_studio/features/planner/planner_models.dart';
import 'package:shoot_studio/services/content_packs.dart';
import 'package:shoot_studio/services/image_store.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoot_studio/core/providers.dart';

/// 模拟 OpenAI 兼容端点。
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options);

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KeyVault AES-256-GCM（D9）', () {
    test('加密解密往返 + 掩码', () async {
      final vault = KeyVault.forTesting();
      final encrypted = await vault.encrypt('sk-test-1234567890');
      expect(encrypted, startsWith('v1:'));
      expect(encrypted.contains('sk-test'), isFalse);
      expect(await vault.decrypt(encrypted), 'sk-test-1234567890');
      expect(KeyVault.mask('sk-test-1234567890'), contains('••'));
      expect(KeyVault.mask(''), contains('未配置'));
    });

    test('错误密文返回空串（不抛异常）', () async {
      final vault = KeyVault.forTesting();
      expect(await vault.decrypt('v1:abc:def:ghi'), '');
      expect(await vault.decrypt('broken'), '');
    });
  });

  group('AI 全链路（Mock API）', () {
    test('OpenAI 兼容流式 → 模块 JSON 提取 → Schema 校验', () async {
      final modulesJson = jsonEncode(<String, Object?>{
        'modules': <Object?>[
          <String, Object?>{
            'id': 'm1',
            'type': 'theme',
            'title': '拍摄主题',
            'data': <String, Object?>{'text': '雨夜赛博朋克'},
          },
          <String, Object?>{
            'id': 'm2',
            'type': 'budget',
            'title': '预算表',
            'data': <String, Object?>{
              'rows': <Object?>[
                <String, Object?>{'item': '场地', 'price': 300, 'note': ''},
              ],
            },
          },
        ],
      });
      final sse =
          'data: ${jsonEncode(<String, Object?>{
            'choices': <Object?>[
              <String, Object?>{
                'delta': <String, Object?>{'content': modulesJson},
              },
            ],
          })}\n\ndata: [DONE]\n\n';
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter((RequestOptions options) async {
        expect(options.uri.path, endsWith('/chat/completions'));
        return ResponseBody.fromString(
          sse,
          200,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        );
      });
      final client = AiClient(dio: dio);
      final buffer = StringBuffer();
      final result = await client.chat(
        provider: const RuntimeProvider(
          id: 'deepseek',
          name: 'DeepSeek',
          protocol: 'openai',
          baseUrl: 'https://api.deepseek.com/v1',
          apiKey: 'sk-x',
          model: 'deepseek-chat',
        ),
        systemPrompt: 'test',
        userPrompt: 'test',
        onDelta: buffer.write,
      );
      expect(result.success, isTrue);
      expect(buffer.toString(), contains('雨夜赛博朋克'));

      final modules = extractModules(result.content);
      expect(modules, isNotNull);
      final errors = ModuleSchemaValidator.validate(modules!);
      expect(errors, isEmpty);
    });

    test('Anthropic 协议适配', () async {
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter((RequestOptions options) async {
        expect(options.uri.path, contains('/v1/messages'));
        expect(options.headers['x-api-key'], 'sk-ant');
        return ResponseBody.fromString(
          jsonEncode(<String, Object?>{
            'content': <Object?>[
              <String, Object?>{'type': 'text', 'text': '好'},
            ],
            'usage': <String, Object?>{'input_tokens': 10, 'output_tokens': 2},
          }),
          200,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        );
      });
      final client = AiClient(dio: dio);
      final result = await client.chat(
        provider: const RuntimeProvider(
          id: 'anthropic',
          name: 'Claude',
          protocol: 'anthropic',
          baseUrl: 'https://api.anthropic.com',
          apiKey: 'sk-ant',
          model: 'claude-3-5-sonnet-latest',
        ),
        systemPrompt: 's',
        userPrompt: 'u',
      );
      expect(result.success, isTrue);
      expect(result.content, '好');
      expect(result.promptTokens, 10);
    });

    test('鉴权失败给出可读错误（智能路由切换依据）', () async {
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter(
        (RequestOptions options) async => ResponseBody.fromString('{}', 401),
      );
      final client = AiClient(dio: dio);
      final result = await client.chat(
        provider: const RuntimeProvider(
          id: 'x',
          name: 'X',
          protocol: 'openai',
          baseUrl: 'https://x.example/v1',
          apiKey: 'bad',
          model: 'm',
        ),
        systemPrompt: 's',
        userPrompt: 'u',
        stream: false,
      );
      expect(result.success, isFalse);
      expect(result.error, contains('鉴权失败'));
    });
  });

  group('导出三格式 + .sspak 往返', () {
    late Directory temp;
    late Workspace workspace;
    late AppDatabase db;
    late ExportService service;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('ss_export_');
      workspace = await Workspace.initAt(p.join(temp.path, 'ws'));
      db = AppDatabase.forTesting(NativeDatabase.memory());
      service = ExportService(workspace: workspace, db: db);
    });

    tearDown(() async {
      await db.close();
      await temp.delete(recursive: true);
    });

    Future<List<PlanModuleData>> buildPlanModules() async {
      final templates = await ContentPacks.templates();
      final cos = templates.firstWhere((t) => t.category == 'Cos 正片');
      var seq = 0;
      final modules = modulesFromTemplate(cos, () => 'm${seq++}');
      // 写入一张资源封面与一条资源，绑定到模特模块。
      final store = ImageStore(workspace.root.path);
      final png = img.Image(width: 300, height: 300);
      for (final pixel in png) {
        pixel.r = 77;
        pixel.g = 107;
        pixel.b = 254;
      }
      final (String fileName, _) = await store.importBytes(
        pngBytes(png),
        category: 'models',
        title: '测试模特',
      );
      const String resourceId = 'res-1';
      final now = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.resources)
          .insert(
            ResourcesCompanion.insert(
              id: resourceId,
              type: 'models',
              name: '测试模特',
              coverImage: Value(fileName),
              createdAt: now,
              updatedAt: now,
            ),
          );
      final modelModule = modules.firstWhere(
        (m) => m.type == PlanModuleType.model,
      );
      modelModule.data['ids'] = <String>[resourceId];
      // 画板参考帧。
      final board = modules.firstWhere((m) => m.type == PlanModuleType.refs);
      board.data['refs'] = <Object?>[
        <String, Object?>{
          'name': '雨夜霓虹参考帧',
          'palette': <String>[
            '#c24e2a',
            '#2f5d50',
            '#e3dbcf',
            '#28231f',
            '#f6f3ee',
          ],
          'gradient': <String>['#c24e2a', '#2f5d50'],
          'sourceUrl': 'https://film-grab.com/?s=test',
        },
      ];
      // 布光方案。
      await db
          .into(db.lightingScenes)
          .insert(
            LightingScenesCompanion.insert(
              id: 'scene-1',
              name: '三点布光方案',
              sceneJson: jsonEncode(<String, Object?>{'devices': <Object?>[]}),
              linkedPoseId: const Value(null),
              updatedAt: now,
            ),
          );
      final lighting = modules.firstWhere(
        (m) => m.type == PlanModuleType.lighting,
      );
      lighting.data['sceneId'] = 'scene-1';
      lighting.data['sceneName'] = '三点布光方案';
      // 姿势清单。
      final poses = modules.firstWhere((m) => m.type == PlanModuleType.poses);
      poses.data['poses'] = <Object?>[
        <String, Object?>{
          'name': '侧身回眸',
          'lens': '35mm 全身',
          'joints': <String, Object?>{
            'spine': <double>[0, 20, 0],
            'shoulder_l': <double>[0, 0, 8],
          },
        },
      ];
      return modules;
    }

    test('长图 PNG 落盘且为合法 PNG', () async {
      final modules = await buildPlanModules();
      final result = await service.run(
        planTitle: '导出测试',
        status: PlanDocStatus.draft,
        modules: modules,
        format: ExportFormat.longPng,
        onProgress: (_) {},
        isCancelled: () => false,
      );
      expect(result.files, hasLength(1));
      final file = File(result.files.first);
      expect(await file.exists(), isTrue);
      final bytes = await file.readAsBytes();
      expect(bytes.length, greaterThan(20 * 1024));
      // PNG 魔数。
      expect(bytes.sublist(0, 4), <int>[0x89, 0x50, 0x4E, 0x47]);
      expect(result.sha256s[result.files.first], hasLength(64));
    });

    test('PDF 落盘且为合法 PDF', () async {
      final modules = await buildPlanModules();
      final result = await service.run(
        planTitle: '导出测试',
        status: PlanDocStatus.final_,
        modules: modules,
        format: ExportFormat.pdf,
        onProgress: (_) {},
        isCancelled: () => false,
      );
      final file = File(result.files.first);
      expect(await file.exists(), isTrue);
      final bytes = await file.readAsBytes();
      expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
    });

    test('.sspak 导出并在新库还原（引用重映射）', () async {
      final modules = await buildPlanModules();
      final result = await service.run(
        planTitle: '导出测试',
        status: PlanDocStatus.draft,
        modules: modules,
        format: ExportFormat.sspak,
        onProgress: (_) {},
        isCancelled: () => false,
      );
      final sspak = result.files.first;
      expect(await File(sspak).exists(), isTrue);

      // 新库导入。
      final db2 = AppDatabase.forTesting(NativeDatabase.memory());
      final ws2 = await Workspace.initAt(p.join(temp.path, 'ws2'));
      final importer = SspakImporter(workspace: ws2, db: db2);
      final imported = await importer.import(sspak);
      expect(imported.title, contains('导出测试'));
      expect(imported.moduleCount, modules.length);

      final plans = await db2.select(db2.plans).get();
      expect(plans, hasLength(1));
      final restored = PlanModuleData.fromJson(
        (jsonDecode(plans.first.modulesJson) as List)
            .whereType<Map>()
            .map((Map m) => m.cast<String, Object?>())
            .first,
      );
      expect(restored.type, PlanModuleType.theme);
      // 资源重映射：导入后绑定 id 指向 imported- 前缀。
      final restoredModules = (jsonDecode(plans.first.modulesJson) as List)
          .whereType<Map>()
          .map((Map m) => PlanModuleData.fromJson(m.cast<String, Object?>()))
          .toList();
      final modelModule = restoredModules.firstWhere(
        (m) => m.type == PlanModuleType.model,
      );
      expect((modelModule.data['ids'] as List).first, startsWith('imported-'));
      await db2.close();
    });

    test('完整性检查发现失效引用', () async {
      final modules = await buildPlanModules();
      final modelModule = modules.firstWhere(
        (m) => m.type == PlanModuleType.model,
      );
      modelModule.data['ids'] = <String>['missing-id'];
      final issues = await service.checkIntegrity(modules);
      expect(issues, isNotEmpty);
      expect(issues.first.detail, contains('引用失效'));
    });
  });

  group('AI 控制器（Mock 全链路 + 本地降级）', () {
    test('无 Key 时本地引擎 100% 产出（D11）', () async {
      final temp = await Directory.systemTemp.createTemp('ss_ai_');
      final workspace = await Workspace.initAt(p.join(temp.path, 'ws'));
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      await ContentPacks.syncToDatabase(db);
      final container = ProviderContainer(
        overrides: <Override>[
          databaseProvider.overrideWithValue(db),
          workspaceProvider.overrideWithValue(workspace),
        ],
      );
      final controller = container.read(aiControllerProvider.notifier);
      await controller.init();
      final draft = await controller.generatePlan(
        '汉服园林晨雾，柔光衣料质感',
        forceLocal: true,
      );
      expect(draft.viaLocal, isTrue);
      expect(draft.modules, isNotEmpty);
      expect(draft.modules.map((m) => m.type), contains(PlanModuleType.theme));
      final theme = draft.modules.firstWhere(
        (m) => m.type == PlanModuleType.theme,
      );
      expect(theme.data['text'], contains('汉服'));
      container.dispose();
      await db.close();
      await temp.delete(recursive: true);
    });
  });
}

/// 把 image 包图像转 Uint8List（PNG 编码）。
Uint8List pngBytes(img.Image image) => Uint8List.fromList(img.encodePng(image));
