/// V8/R72 · S8 策划案 + AI + 导出重构（D155）专项测试。
///
/// 覆盖四条合同要求：
///  1) AI 面板三态收敛（输入 → 生成中 → 阅读成案），生成中可取消、失败自动换商明示；
///  2) 成案阅读视图按杂志内页排版（Display 衬线大标题 / 眉题分节 / KV 读数预算表 / 桌面双栏）；
///  3) 导出三格式校验不回归（PNG 魔数 / PDF 头 / .sspak 往返）；
///  4) D150：.sspak 升版到 v2，v1 迁移明示、更高版本明示拒绝。
library;

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:shoot_studio/core/db/database.dart';
import 'package:shoot_studio/core/design/widgets.dart';
import 'package:shoot_studio/core/workspace/workspace.dart';
import 'package:shoot_studio/features/ai/ai_controller.dart';
import 'package:shoot_studio/features/ai/ai_stage.dart';
import 'package:shoot_studio/features/ai/plan_read_view.dart';
import 'package:shoot_studio/features/export/exporter.dart';
import 'package:shoot_studio/features/planner/planner_models.dart';
import 'package:shoot_studio/services/content_packs.dart';
import 'package:shoot_studio/services/image_store.dart';

// ---------------------------------------------------------------------------
// 夹具
// ---------------------------------------------------------------------------

const String _idea = '雨夜赛博朋克风初音正片，霓虹雨夜，未来感';

PlanModuleData _module(
  String id,
  PlanModuleType type,
  String title,
  Map<String, Object?> data,
) => PlanModuleData(id: id, type: type, title: title, data: data);

List<PlanModuleData> _draftModules() => <PlanModuleData>[
  _module('d-theme', PlanModuleType.theme, '主题基调', <String, Object?>{
    'text': '雨夜 / 霓虹 / 冷蓝打底，单点洋红做视觉锚。',
  }),
  _module('d-sun', PlanModuleType.sun, '太阳方位', <String, Object?>{
    'place': '上海 · 徐汇滨江',
    'date': '2026-10-02 19:40',
  }),
  _module('d-refs', PlanModuleType.refs, '样片方向', <String, Object?>{
    'refs': <Object?>[
      <String, Object?>{
        'name': '雨夜霓虹参考帧',
        'palette': <Object?>[
          '#1B2A4A',
          '#3C6DF0',
          '#E94F8A',
          '#FFC46B',
          '#F2F5FA',
        ],
        'gradient': <Object?>['#1B2A4A', '#E94F8A'],
        'sourceUrl': 'https://film-grab.com/?s=test',
      },
    ],
  }),
  _module('d-poses', PlanModuleType.poses, '摆姿要点', <String, Object?>{
    'poses': <Object?>[
      <String, Object?>{
        'name': '站姿·举手伸展',
        'author': 'K.',
        'license': 'CC BY 4.0',
      },
    ],
  }),
];

AiDraftResult _draft({
  bool cancelled = false,
  List<String> attempts = const <String>[],
}) => AiDraftResult(
  modules: _draftModules(),
  viaLocal: true,
  providerName: cancelled ? '已取消' : '本地规则引擎',
  rawText: '{"theme":"雨夜赛博朋克"}',
  reasoning: '先定基调，再排太阳方位，最后补摆姿与色板。',
  totalScore: 86,
  detailScore: 84,
  consistencyScore: 88,
  tokensIn: 412,
  tokensOut: 933,
  latencyMs: 1280,
  attempts: attempts,
  cancelled: cancelled,
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(1600, 1000),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.of(AppThemeVariant.paper),
        // 阅读视图等控件原本跑在 Dialog.fullscreen 里（自带 Material），
        // 测试里直接 pump 也要有 Material 祖先，否则 SsButton 的 InkWell 会抛
        // "No Material widget found"。
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  expect(tester.takeException(), isNull);
}

void main() {
  // -------------------------------------------------------------------------
  group('D155 · AI 面板三态收敛', () {
    test('resolveAiStage：无草稿=输入，生成中=生成中，有草稿=阅读，取消回落输入', () {
      expect(resolveAiStage(const AiState()), AiStage.input);
      expect(
        resolveAiStage(const AiState(generating: true)),
        AiStage.generating,
      );
      expect(resolveAiStage(AiState(draft: _draft())), AiStage.reading);
      expect(
        resolveAiStage(AiState(generating: true, draft: _draft())),
        AiStage.generating,
        reason: '生成中优先于已有草稿',
      );
      expect(
        resolveAiStage(AiState(draft: _draft(cancelled: true))),
        AiStage.input,
      );
    });

    testWidgets('AiStageBar：三步编号齐全，当前步高亮', (WidgetTester tester) async {
      await _pump(
        tester,
        Scaffold(body: AiStageBar(stage: AiStage.generating)),
      );
      expect(find.text('01'), findsOneWidget);
      expect(find.text('02'), findsOneWidget);
      expect(find.text('03'), findsOneWidget);
      expect(find.text('描述'), findsOneWidget);
      expect(find.text('生成中'), findsOneWidget);
      expect(find.text('阅读成案'), findsOneWidget);
    });

    testWidgets('生成中：流式文本 + 尝试链 + 失败自动换商提示 + 可取消', (WidgetTester tester) async {
      bool cancelled = false;
      await _pump(
        tester,
        Scaffold(
          body: AiGeneratingPanel(
            state: AiState(
              generating: true,
              status: '正在调用云端模型…',
              streamText: '{"modules":[{"type":"theme"}]}',
              reasoningText: '正在推演叙事线。',
              attempts: <String>['云端 A · 402 额度不足', '云端 B · 连通'],
            ),
            onCancel: () => cancelled = true,
          ),
        ),
      );
      expect(find.text('正在调用云端模型…'), findsOneWidget);
      expect(find.textContaining('{"modules"'), findsOneWidget);
      expect(find.text('推理链'), findsOneWidget);
      expect(find.text('正在推演叙事线。'), findsOneWidget);
      // D40：同商换模型 → 换商，尝试链要明示。
      expect(find.textContaining('1 · 云端 A · 402 额度不足'), findsOneWidget);
      expect(find.textContaining('本次已自动换商'), findsOneWidget);

      await tester.tap(find.text('取消生成'));
      await tester.pump();
      expect(cancelled, isTrue, reason: '取消按钮必须能中断生成');
    });

    testWidgets('阅读态：摘要 chip + 阅读成案/写入画布/重新生成三个动作', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        Scaffold(
          body: AiReadingPanel(
            state: AiState(draft: _draft()),
            idea: _idea,
            onInsertAll: (List<PlanModuleData> _) {},
            onInsertModule: (PlanModuleData _) {},
          ),
        ),
      );
      expect(find.textContaining('本地规则引擎'), findsOneWidget);
      expect(find.text('阅读成案'), findsOneWidget);
      expect(find.text('写入画布'), findsOneWidget);
      expect(find.text('重新生成'), findsOneWidget);
      expect(find.textContaining('主题基调'), findsOneWidget);
    });

    testWidgets('被取消的草稿：写入画布按钮禁用（不可写入）', (WidgetTester tester) async {
      await _pump(
        tester,
        Scaffold(
          body: AiReadingPanel(
            state: AiState(draft: _draft(cancelled: true)),
            idea: _idea,
            onInsertAll: (List<PlanModuleData> _) {},
            onInsertModule: (PlanModuleData _) {},
          ),
        ),
      );
      expect(find.text('已取消'), findsWidgets);
      expect(find.textContaining('不可写入画布'), findsOneWidget);
      final Finder write = find.widgetWithText(SsButton, '已取消');
      expect(write, findsOneWidget);
      final SsButton button = tester.widget<SsButton>(write);
      expect(button.onPressed, isNull, reason: '取消后的草稿不得写入画布');
    });
  });

  // -------------------------------------------------------------------------
  group('D155 · 成案阅读视图（杂志内页排版）', () {
    testWidgets('桌面双栏：左目录 + 右正文，Display 衬线大标题与 KV 读数预算表', (
      WidgetTester tester,
    ) async {
      await _pump(tester, PlanReadView(draft: _draft(), idea: _idea));
      expect(find.text('成案阅读视图'), findsOneWidget);
      expect(find.text(_idea), findsOneWidget); // 衬线大标题
      expect(find.text('刊头'), findsOneWidget);
      expect(find.text('读数'), findsOneWidget); // 目录项 == 分节
      // 「推理链」在目录与正文眉题各出现一次。
      expect(find.text('推理链'), findsNWidgets(2));
      // 「附录 · 原始文本」与「推理链」同理：目录 + 正文眉题各一次。
      expect(find.text('附录 · 原始文本'), findsNWidgets(2));
      expect(find.text('AI 成案 · 阅读'), findsOneWidget); // 顶栏眉题
      // KV 读数预算表
      expect(find.text('总分'), findsOneWidget);
      expect(find.text('86.0'), findsOneWidget);
      expect(find.text('输入 tokens'), findsOneWidget);
      expect(find.text('412'), findsOneWidget);
      expect(find.text('输出 tokens'), findsOneWidget);
      // 图卡分镜：目录项 + 分镜标题 + 内容视图里的标题，共 3 处。
      expect(find.text('主题基调'), findsNWidgets(3));
      expect(find.text('写入画布并编辑'), findsOneWidget);
    });

    testWidgets('窄栏回落单列（无横向溢出）', (WidgetTester tester) async {
      await _pump(
        tester,
        PlanReadView(draft: _draft(), idea: _idea),
        size: const Size(900, 1000),
      );
      expect(tester.takeException(), isNull);
      // 窄栏不渲染左目录（折叠），但正文分节与 KV 预算表必须在。
      expect(find.text('读数'), findsNothing);
      expect(find.text('总分'), findsOneWidget);
    });

    testWidgets('风险清单：shortcomings 与 schemaErrors 明示', (
      WidgetTester tester,
    ) async {
      final AiDraftResult risky = AiDraftResult(
        modules: _draftModules(),
        viaLocal: false,
        providerName: '云端 A',
        rawText: '{}',
        shortcomings: <String>['摆姿模块缺少镜头建议'],
        schemaErrors: <String>['budget.rows 缺少 amount'],
      );
      await _pump(tester, PlanReadView(draft: risky, idea: _idea));
      expect(find.text('摆姿模块缺少镜头建议'), findsOneWidget);
      expect(find.text('budget.rows 缺少 amount'), findsOneWidget);
    });

    testWidgets('被取消的草稿：阅读视图明示且写入按钮禁用', (WidgetTester tester) async {
      await _pump(
        tester,
        PlanReadView(draft: _draft(cancelled: true), idea: _idea),
      );
      expect(find.text('本次生成已被取消，仅供复核，不可写入画布。'), findsOneWidget);
      final SsButton button = tester.widget<SsButton>(
        find.widgetWithText(SsButton, '已取消'),
      );
      expect(button.onPressed, isNull);
    });
  });

  // -------------------------------------------------------------------------
  group('D155/D150 · 导出三格式与 .sspak 往返', () {
    late Directory temp;
    late Workspace ws;
    late AppDatabase db;
    late ExportService service;
    late List<PlanModuleData> modules;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('ss_s8_export_');
      ws = await Workspace.initAt(p.join(temp.path, 'ws'));
      db = AppDatabase.forTesting(NativeDatabase.memory());
      service = ExportService(workspace: ws, db: db);

      final templates = await ContentPacks.templates();
      final cos = templates.firstWhere((dynamic t) => t.category == 'Cos 正片');
      var seq = 0;
      modules = modulesFromTemplate(cos, () => 'm${seq++}');
      final store = ImageStore(ws.root.path);
      final Uint8List png = img.encodePng(img.Image(width: 300, height: 300));
      final (String fileName, _) = await store.importBytes(
        png,
        category: 'models',
        title: '测试模特',
      );
      final int now = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.resources)
          .insert(
            ResourcesCompanion.insert(
              id: 'res-1',
              type: 'models',
              name: '测试模特',
              coverImage: Value(fileName),
              createdAt: now,
              updatedAt: now,
            ),
          );
      for (final PlanModuleData m in modules) {
        if (m.type == PlanModuleType.model) m.data['ids'] = <String>['res-1'];
        if (m.type == PlanModuleType.refs) {
          m.data['refs'] = <Object?>[
            <String, Object?>{
              'name': '雨夜霓虹参考帧',
              'palette': <Object?>[
                '#1B2A4A',
                '#3C6DF0',
                '#E94F8A',
                '#FFC46B',
                '#F2F5FA',
              ],
              'gradient': <Object?>['#1B2A4A', '#E94F8A'],
              'sourceUrl': 'https://film-grab.com/?s=test',
            },
          ];
        }
      }
    });

    tearDown(() async {
      await db.close();
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    test('PNG：魔数正确 + sha256 登记', () async {
      final ExportResult r = await service.run(
        planTitle: '导出测试',
        status: PlanDocStatus.final_,
        modules: modules,
        format: ExportFormat.longPng,
        onProgress: (ExportProgress _) {},
        isCancelled: () => false,
      );
      expect(r.files, hasLength(1));
      final Uint8List bytes = File(r.files.first).readAsBytesSync();
      expect(bytes.length, greaterThan(20 * 1024));
      expect(bytes.sublist(0, 4), <int>[0x89, 0x50, 0x4E, 0x47]);
      expect(r.sha256s[r.files.first], hasLength(64));
    });

    test('PDF：%PDF- 文件头 + 尾页 EOF', () async {
      final ExportResult r = await service.run(
        planTitle: '导出测试',
        status: PlanDocStatus.final_,
        modules: modules,
        format: ExportFormat.pdf,
        onProgress: (ExportProgress _) {},
        isCancelled: () => false,
      );
      expect(r.files, hasLength(1));
      final Uint8List bytes = File(r.files.first).readAsBytesSync();
      expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
      expect(
        String.fromCharCodes(
          bytes.sublist(bytes.length - 6, bytes.length - 1),
        ).trim(),
        '%%EOF',
      );
    });

    test('.sspak：v2 往返（migratedFrom == null）+ 清单带版本', () async {
      final ExportResult r = await service.run(
        planTitle: '导出测试',
        status: PlanDocStatus.final_,
        modules: modules,
        format: ExportFormat.sspak,
        onProgress: (ExportProgress _) {},
        isCancelled: () => false,
      );
      final File pkg = File(r.files.first);
      final Archive archive = ZipDecoder().decodeBytes(pkg.readAsBytesSync());
      final Map<String, Object?> meta = _readJson(archive, 'manifest.json');
      expect(meta['version'], kSspakFormatVersion);
      expect(meta['layout'], kSspakLayoutName);

      final AppDatabase db2 = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db2.close);
      final Workspace ws2 = await Workspace.initAt(p.join(temp.path, 'ws2'));
      final ({String planId, String title, int moduleCount, int? migratedFrom})
      imported = await SspakImporter(workspace: ws2, db: db2).import(pkg.path);
      expect(imported.migratedFrom, isNull, reason: 'v2 包应直接读取，不算迁移');
      expect(imported.title, contains('导出测试'));
      expect(imported.moduleCount, modules.length);
    });

    test('D150：v1 包导入明示迁移（migratedFrom == 1）', () async {
      final ExportResult r = await service.run(
        planTitle: '导出测试',
        status: PlanDocStatus.final_,
        modules: modules,
        format: ExportFormat.sspak,
        onProgress: (ExportProgress _) {},
        isCancelled: () => false,
      );
      final File pkg = File(r.files.first);
      final File legacy = _repack(pkg, version: 1, layout: null);

      final AppDatabase db2 = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db2.close);
      final Workspace ws2 = await Workspace.initAt(p.join(temp.path, 'ws1'));
      final ({String planId, String title, int moduleCount, int? migratedFrom})
      imported = await SspakImporter(
        workspace: ws2,
        db: db2,
      ).import(legacy.path);
      expect(imported.migratedFrom, 1);
      expect(imported.title, contains('导出测试'));
    });

    test('D150：无 version 的远古包按 v1 迁移', () async {
      final ExportResult r = await service.run(
        planTitle: '导出测试',
        status: PlanDocStatus.final_,
        modules: modules,
        format: ExportFormat.sspak,
        onProgress: (ExportProgress _) {},
        isCancelled: () => false,
      );
      final File pkg = File(r.files.first);
      final File legacy = _repack(pkg, version: null, layout: null);

      final AppDatabase db2 = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db2.close);
      final Workspace ws2 = await Workspace.initAt(p.join(temp.path, 'ws0'));
      final ({String planId, String title, int moduleCount, int? migratedFrom})
      imported = await SspakImporter(
        workspace: ws2,
        db: db2,
      ).import(legacy.path);
      expect(imported.migratedFrom, 1, reason: '缺版本按 v1 迁移并明示');
    });

    test('D150：更高版本明示拒绝并给出升级指引', () async {
      final ExportResult r = await service.run(
        planTitle: '导出测试',
        status: PlanDocStatus.final_,
        modules: modules,
        format: ExportFormat.sspak,
        onProgress: (ExportProgress _) {},
        isCancelled: () => false,
      );
      final File pkg = File(r.files.first);
      final File newer = _repack(pkg, version: 99, layout: 'sspak-v99');

      final AppDatabase db2 = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db2.close);
      final Workspace ws2 = await Workspace.initAt(p.join(temp.path, 'ws9'));
      await expectLater(
        SspakImporter(workspace: ws2, db: db2).import(newer.path),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            contains('请先升级'),
          ),
        ),
      );
    });

    test('D150：非 .sspak 包明示拒绝', () async {
      final File fake = File(p.join(temp.path, 'fake.sspak'))
        ..writeAsBytesSync(ZipEncoder().encode(Archive())!);
      final AppDatabase db2 = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db2.close);
      final Workspace ws2 = await Workspace.initAt(p.join(temp.path, 'wsx'));
      await expectLater(
        SspakImporter(workspace: ws2, db: db2).import(fake.path),
        throwsA(
          isA<StateError>().having(
            (StateError e) => e.message,
            'message',
            contains('manifest.json'),
          ),
        ),
      );
    });
  });
}

/// 把 .sspak 里的 manifest/plan 版本改成指定值（用于构造 v1 / v99 包）。
/// D150：迁移与拒绝都必须有可复现的证据，不能靠口头声明。
File _repack(File src, {required int? version, required String? layout}) {
  // Archive 没有 updateFile（会留下同名重复条目），所以重建一份新包。
  final Archive source = ZipDecoder().decodeBytes(src.readAsBytesSync());
  final Archive rebuilt = Archive();

  void patch(String name) {
    final Map<String, Object?> json = _readJson(source, name);
    if (version == null) {
      json.remove('version');
      json.remove('layout');
    } else {
      json['version'] = version;
      if (layout == null) {
        json.remove('layout');
      } else {
        json['layout'] = layout;
      }
    }
    final List<int> bytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(json),
    );
    rebuilt.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  for (final ArchiveFile file in source.files) {
    if (file.name == 'manifest.json' || file.name == 'plan.json') {
      patch(file.name);
    } else {
      rebuilt.addFile(ArchiveFile(file.name, file.size, file.content!));
    }
  }

  final File out = File('${src.path}.${version ?? 'nover'}');
  out.writeAsBytesSync(ZipEncoder().encode(rebuilt)!);
  return out;
}

/// 从 zip 读一份 JSON 清单（`ArchiveFile.content` 是可空的，直接强转会编译失败）。
Map<String, Object?> _readJson(Archive archive, String name) {
  final ArchiveFile file = archive.findFile(name)!;
  final List<int>? content = file.content;
  if (content == null) {
    throw StateError('.sspak 缺少 $name');
  }
  return jsonDecode(utf8.decode(content)) as Map<String, Object?>;
}
