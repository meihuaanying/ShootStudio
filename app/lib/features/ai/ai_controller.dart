import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../core/utils/json_utils.dart';
import '../../services/content_packs.dart';
import '../planner/planner_diff.dart';
import '../planner/planner_models.dart';
import '../refs/refs_controller.dart';
import 'ai_client.dart';
import 'key_vault.dart';
import 'local_engine.dart';
import 'plan_scorer.dart';
import 'provider_presets.dart';

/// 提供方配置视图模型。
class AiProviderView {
  const AiProviderView({
    required this.preset,
    required this.enabled,
    required this.priority,
    required this.hasKey,
    required this.maskedKey,
    required this.model,
    required this.models,
    required this.lastError,
    required this.encryptedKey,
  });

  final AiProviderPreset preset;
  final bool enabled;
  final int priority;
  final bool hasKey;
  final String maskedKey;
  final String model;
  final List<String> models;
  final String lastError;
  final String encryptedKey;
}

/// AI 生成结果。
class AiDraftResult {
  const AiDraftResult({
    required this.modules,
    required this.viaLocal,
    required this.providerName,
    required this.rawText,
    this.reasoning = '',
    this.schemaErrors = const <String>[],
    this.shortcomings = const <String>[],
    this.totalScore = 0,
    this.detailScore = 0,
    this.consistencyScore = 0,
    this.tokensIn = 0,
    this.tokensOut = 0,
    this.latencyMs = 0,
    this.attempts = const <String>[],
  });

  final List<PlanModuleData> modules;
  final bool viaLocal;
  final String providerName;
  final String rawText;

  /// 第一段推理文本（策划思路）。
  final String reasoning;
  final List<String> schemaErrors;
  final List<String> shortcomings;
  final double totalScore;
  final double detailScore;
  final double consistencyScore;
  final int tokensIn;
  final int tokensOut;
  final int latencyMs;

  /// 生成尝试链（提供方/模型/结果），供阅读模式展示。
  final List<String> attempts;
}

/// 对话式修订草稿（F3）：携带合并后的模块与 diff，需用户确认后应用。
class AiRevisionDraft {
  const AiRevisionDraft({
    required this.modules,
    required this.diff,
    required this.instruction,
    required this.providerName,
    this.rawText = '',
    this.changedModuleIds = const <String>{},
  });

  final List<PlanModuleData> modules;
  final Object diff; // PlanDiff（避免与 planner 相互导入的类型擦除）
  final String instruction;
  final String providerName;
  final String rawText;
  final Set<String> changedModuleIds;
}

class AiState {
  const AiState({
    this.providers = const <AiProviderView>[],
    this.logs = const <CallLog>[],
    this.loaded = false,
    this.generating = false,
    this.streamText = '',
    this.reasoningText = '',
    this.draft,
    this.revision,
    this.status = '',
    this.monthlyFreeUsed = 0,
    this.attempts = const <String>[],
  });

  final List<AiProviderView> providers;
  final List<CallLog> logs;
  final bool loaded;
  final bool generating;
  final String streamText;

  /// 第一段（推理）流式文本。
  final String reasoningText;
  final AiDraftResult? draft;
  final AiRevisionDraft? revision;
  final String status;
  final int monthlyFreeUsed;

  /// 生成尝试链（提供方/模型/结果），供阅读模式与设置页展示（D40）。
  final List<String> attempts;

  List<AiProviderView> get routed =>
      providers
          .where(
            (AiProviderView p) => p.enabled && (p.hasKey || p.preset.isCustom),
          )
          .toList()
        ..sort(
          (AiProviderView a, AiProviderView b) =>
              a.priority.compareTo(b.priority),
        );

  AiState copyWith({
    List<AiProviderView>? providers,
    List<CallLog>? logs,
    bool? loaded,
    bool? generating,
    String? streamText,
    String? reasoningText,
    Object? draft = _sentinel,
    Object? revision = _sentinel,
    String? status,
    int? monthlyFreeUsed,
    List<String>? attempts,
  }) {
    return AiState(
      providers: providers ?? this.providers,
      logs: logs ?? this.logs,
      loaded: loaded ?? this.loaded,
      generating: generating ?? this.generating,
      streamText: streamText ?? this.streamText,
      reasoningText: reasoningText ?? this.reasoningText,
      draft: draft == _sentinel ? this.draft : draft as AiDraftResult?,
      revision: revision == _sentinel
          ? this.revision
          : revision as AiRevisionDraft?,
      status: status ?? this.status,
      monthlyFreeUsed: monthlyFreeUsed ?? this.monthlyFreeUsed,
      attempts: attempts ?? this.attempts,
    );
  }

  static const Object _sentinel = Object();
}

final aiControllerProvider = NotifierProvider<AiController, AiState>(
  AiController.new,
);

/// 官方免费额度上限（D11：每月 30 次，未部署官方通道时自动走本地引擎）。
const int kOfficialMonthlyQuota = 30;

class AiController extends Notifier<AiState> {
  static const LocalPlanEngine _localEngine = LocalPlanEngine();
  late final AppDatabase _db = ref.read(databaseProvider);
  final KeyVault _vault = KeyVault();
  AiClient? _client;

  /// 测试注入（F13）：Mock 端到端管线。
  void useClient(AiClient client) => _client = client;

  @override
  AiState build() => const AiState();

  Future<void> init() async {
    if (state.loaded) return;
    await _ensurePresetRows();
    await refresh();
    // D40：后台自动拉取模型列表（静默失败，不阻塞首屏）。
    unawaited(autoFetchMissingModels());
  }

  /// 首次进入：为 13 个预设写入配置行（未启用、无 Key）。
  Future<void> _ensurePresetRows() async {
    final existing = await _db.select(_db.providerConfigs).get();
    final existingIds = existing.map((ProviderConfig row) => row.id).toSet();
    for (var i = 0; i < aiProviderPresets.length; i++) {
      final AiProviderPreset preset = aiProviderPresets[i];
      if (existingIds.contains(preset.id)) continue;
      await _db
          .into(_db.providerConfigs)
          .insert(
            ProviderConfigsCompanion.insert(
              id: preset.id,
              name: preset.name,
              baseUrl: preset.baseUrl,
              protocol: Value(preset.protocol),
              defaultModel: Value(preset.defaultModel),
              enabled: const Value(false),
              priority: Value(i),
            ),
          );
    }
  }

  Future<void> refresh() async {
    final rows = await _db.select(_db.providerConfigs).get();
    final byId = <String, ProviderConfig>{
      for (final ProviderConfig row in rows) row.id: row,
    };
    final providers = <AiProviderView>[];
    for (final AiProviderPreset preset in aiProviderPresets) {
      final ProviderConfig? row = byId[preset.id];
      final encryptedKey = row?.encryptedKey ?? '';
      final decrypted = encryptedKey.isEmpty
          ? ''
          : await _vault.decrypt(encryptedKey);
      providers.add(
        AiProviderView(
          preset: preset,
          enabled: row?.enabled ?? false,
          priority: row?.priority ?? 0,
          hasKey: decrypted.isNotEmpty,
          maskedKey: KeyVault.mask(decrypted),
          model: (row?.defaultModel.isNotEmpty ?? false)
              ? row!.defaultModel
              : preset.defaultModel,
          models: asStringList(jsonDecode(row?.modelsJson ?? '[]')),
          lastError: '',
          encryptedKey: encryptedKey,
        ),
      );
    }
    final logs =
        await (_db.select(_db.callLogs)
              ..orderBy(<OrderClauseGenerator<$CallLogsTable>>[
                (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
              ])
              ..limit(30))
            .get();
    final quota = await _loadQuota();
    state = state.copyWith(
      providers: providers,
      logs: logs,
      loaded: true,
      monthlyFreeUsed: quota,
    );
  }

  Future<int> _loadQuota() async {
    final monthKey =
        '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';
    final stored = await _db.getSetting('ai_quota_month');
    final count =
        int.tryParse(await _db.getSetting('ai_quota_count') ?? '0') ?? 0;
    return stored == monthKey ? count : 0;
  }

  Future<void> _bumpQuota() async {
    final monthKey =
        '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';
    final current = await _loadQuota();
    await _db.setSetting('ai_quota_month', monthKey);
    await _db.setSetting('ai_quota_count', '${current + 1}');
    state = state.copyWith(monthlyFreeUsed: current + 1);
  }

  /// 保存提供方配置（Key AES-256-GCM 加密入库；D9）。
  Future<void> saveProvider(
    AiProviderPreset preset, {
    required String apiKey,
    required String model,
    required String baseUrl,
    required bool enabled,
  }) async {
    final encrypted = apiKey.isEmpty ? '' : await _vault.encrypt(apiKey);
    final rows = await (_db.select(
      _db.providerConfigs,
    )..where((t) => t.id.equals(preset.id))).getSingleOrNull();
    await _db
        .into(_db.providerConfigs)
        .insertOnConflictUpdate(
          ProviderConfigsCompanion.insert(
            id: preset.id,
            name: preset.name,
            baseUrl: baseUrl,
            protocol: Value(preset.protocol),
            encryptedKey: Value(
              encrypted.isNotEmpty ? encrypted : (rows?.encryptedKey ?? ''),
            ),
            defaultModel: Value(model),
            modelsJson: Value(rows?.modelsJson ?? '[]'),
            enabled: Value(enabled),
            priority: Value(rows?.priority ?? 0),
          ),
        );
    await refresh();
    state = state.copyWith(status: '已保存 ${preset.name} 配置');
  }

  Future<void> setEnabled(String providerId, bool enabled) async {
    await (_db.update(_db.providerConfigs)
          ..where((t) => t.id.equals(providerId)))
        .write(ProviderConfigsCompanion(enabled: Value(enabled)));
    await refresh();
  }

  Future<void> movePriority(String providerId, int delta) async {
    final rows = await _db.select(_db.providerConfigs).get();
    final sorted = rows.toList()
      ..sort(
        (ProviderConfig a, ProviderConfig b) =>
            a.priority.compareTo(b.priority),
      );
    final index = sorted.indexWhere(
      (ProviderConfig row) => row.id == providerId,
    );
    if (index < 0) return;
    final target = (index + delta).clamp(0, sorted.length - 1);
    if (target == index) return;
    final moved = sorted.removeAt(index);
    sorted.insert(target, moved);
    for (var i = 0; i < sorted.length; i++) {
      await (_db.update(_db.providerConfigs)
            ..where((t) => t.id.equals(sorted[i].id)))
          .write(ProviderConfigsCompanion(priority: Value(i)));
    }
    await refresh();
  }

  Future<AiCallResult> testProvider(String providerId) async {
    final view = state.providers.firstWhere(
      (AiProviderView p) => p.preset.id == providerId,
    );
    final key = view.encryptedKey.isEmpty
        ? ''
        : await _vault.decrypt(view.encryptedKey);
    final provider = RuntimeProvider(
      id: view.preset.id,
      name: view.preset.name,
      protocol: view.preset.protocol,
      baseUrl: view.preset.baseUrl,
      apiKey: key,
      model: view.model,
    );
    final result = await AiClient().testConnectivity(provider);
    await _log(result);
    state = state.copyWith(
      status: result.success
          ? '${view.preset.name} 连通正常 · ${result.latencyMs}ms · ${result.content}'
          : '${view.preset.name} 测试失败：${result.error}',
    );
    return result;
  }

  Future<List<String>> discoverModels(String providerId) async {
    final view = state.providers.firstWhere(
      (AiProviderView p) => p.preset.id == providerId,
    );
    final key = view.encryptedKey.isEmpty
        ? ''
        : await _vault.decrypt(view.encryptedKey);
    final provider = RuntimeProvider(
      id: view.preset.id,
      name: view.preset.name,
      protocol: view.preset.protocol,
      baseUrl: view.preset.baseUrl,
      apiKey: key,
      model: view.model,
    );
    try {
      final models = await AiClient().discoverModels(provider);
      await (_db.update(
        _db.providerConfigs,
      )..where((t) => t.id.equals(providerId))).write(
        ProviderConfigsCompanion(modelsJson: Value(jsonEncode(models))),
      );
      await refresh();
      state = state.copyWith(status: '已发现 ${models.length} 个模型');
      return models;
    } catch (e) {
      state = state.copyWith(status: '模型发现失败：$e');
      return const <String>[];
    }
  }

  Future<void> _log(AiCallResult result) async {
    await _db
        .into(_db.callLogs)
        .insert(
          CallLogsCompanion.insert(
            providerId: result.providerId,
            model: result.model,
            success: result.success,
            latencyMs: result.latencyMs,
            promptTokens: Value(result.promptTokens),
            completionTokens: Value(result.completionTokens),
            error: Value(result.error.isEmpty ? null : result.error),
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
  }

  /// 生成策划案：智能路由（失败自动切换）→ Schema 校验 → 本地引擎兜底（D10/D11）。
  Future<AiDraftResult> generatePlan(
    String theme, {
    bool forceLocal = false,
  }) async {
    state = state.copyWith(
      generating: true,
      streamText: '',
      reasoningText: '',
      draft: null,
      revision: null,
      attempts: <String>[],
      status: '正在生成…',
    );
    final resources = await _resourceSummary();
    final boardFrames = _boardFrames();
    final scene = await _latestLightingScene();
    final favoritePoses = await _favoritePoses();
    final knownResources = await _knownResourceIds();
    final knownScenes = await _knownSceneIds();

    var localSeq = 0;
    Future<AiDraftResult> viaLocal(
      String reason, {
      String reasoning = '',
    }) async {
      final modules = await _localEngine.generate(
        theme: theme,
        nextId: () =>
            'ai_${DateTime.now().microsecondsSinceEpoch}_${localSeq++}',
        resourceNamesByType: resources,
        boardFrames: boardFrames,
        lightingScene: scene,
        favoritePoses: favoritePoses,
      );
      await _attachLightingScene(modules, theme, knownScenes);
      final PlanScore score = PlanScorer.score(
        modules,
        knownResourceIds: knownResources,
        knownSceneIds: knownScenes,
      );
      final draft = AiDraftResult(
        modules: modules,
        viaLocal: true,
        providerName: '本地引擎',
        rawText: reason.isEmpty ? '本地模板规则引擎生成' : reason,
        reasoning: reasoning,
        shortcomings: score.shortcomings,
        totalScore: score.total,
        detailScore: score.detailScore,
        consistencyScore: score.consistencyScore,
        attempts: state.attempts,
      );
      state = state.copyWith(
        generating: false,
        draft: draft,
        status:
            '本地引擎生成完成（${modules.length} 个模块 · 质量分 ${score.total.toStringAsFixed(0)}）'
            '· 配置 API Key 可获得更贴合的内容',
      );
      return draft;
    }

    if (forceLocal) {
      return viaLocal('用户选择离线降级模式');
    }

    final routed = state.routed;
    final configured = routed
        .where(
          (AiProviderView p) =>
              p.preset.id != 'custom' || p.preset.baseUrl.isNotEmpty,
        )
        .toList();
    if (configured.isEmpty) {
      await _bumpQuota(); // 记录一次“本应调用的免费额度”
      return viaLocal('未配置任何 API Key：已自动使用本地引擎');
    }

    final String context = await _buildContext(
      theme,
      resources,
      boardFrames,
      scene,
      favoritePoses,
    );
    final AiClient client = _client ?? AiClient();
    final failures = <String>[];

    // 阶段一：推理策划思路（流式；失败不阻断，直接进入结构化）。
    // D40：同一商内先自动换模型，全失败再换商。
    String reasoning = '';
    RuntimeProvider? working;
    stage1:
    for (final AiProviderView view in configured) {
      for (final String model in _candidatesFor(view)) {
        final RuntimeProvider provider = await _runtimeOf(view, model: model);
        state = state.copyWith(
          status: '正在构思策划思路 · ${view.preset.name}/${provider.model}…',
        );
        final AiCallResult result = await client.chat(
          provider: provider,
          systemPrompt: buildReasoningSystemPrompt(),
          userPrompt: context,
          maxTokens: 2048,
          onDelta: (String delta) {
            state = state.copyWith(
              reasoningText: state.reasoningText + delta,
              streamText: state.reasoningText + delta,
            );
          },
        );
        await _log(result);
        state = state.copyWith(
          attempts: <String>[
            ...state.attempts,
            '${view.preset.name}/${provider.model} · '
                '${result.success ? '构思成功' : '构思失败：${result.error}'}',
          ],
        );
        if (result.success) {
          reasoning = result.content;
          working = provider;
          break stage1;
        }
        failures.add(
          '${view.preset.name}/${provider.model}(构思): ${result.error}',
        );
      }
    }

    // 阶段二：结构化输出（原生 Schema → 校验 → 评分；<80 自动重试一次）。
    var attempt = 0;
    while (attempt < 2) {
      attempt++;
      stage2:
      for (final AiProviderView view in configured) {
        for (final String model in _candidatesFor(view)) {
          final RuntimeProvider provider =
              (working != null &&
                  working.id == view.preset.id &&
                  working.model == model)
              ? working
              : await _runtimeOf(view, model: model);
          state = state.copyWith(
            status: attempt == 1
                ? '正在结构化输出 · ${view.preset.name}/${provider.model}…'
                : '质量分不足，正在按反馈重试 · ${view.preset.name}/${provider.model}…',
          );
          final String feedback =
              attempt == 2 && (state.draft?.shortcomings.isNotEmpty ?? false)
              ? '\n\n上一次输出的不足（必须逐条修正）：\n'
                    '${state.draft!.shortcomings.take(6).join('\n')}'
              : '';
          final String userPrompt =
              '$context\n\n策划思路（供结构化参考）：\n'
              '${reasoning.isEmpty ? '（无，直接按主题生成）' : reasoning}'
              '$feedback';
          final AiCallResult result = await client.chat(
            provider: provider,
            systemPrompt: buildPlanSystemPrompt(),
            userPrompt: userPrompt,
            maxTokens: 6144,
            schema: planJsonSchema,
            schemaName: 'plan_modules',
          );
          await _log(result);
          if (!result.success) {
            state = state.copyWith(
              attempts: <String>[
                ...state.attempts,
                '${view.preset.name}/${provider.model} · 结构化失败：${result.error}',
              ],
            );
            failures.add(
              '${view.preset.name}/${provider.model}(结构化): ${result.error}',
            );
            continue;
          }
          final List<Object?>? raw = extractModules(result.content);
          if (raw == null) {
            state = state.copyWith(
              attempts: <String>[
                ...state.attempts,
                '${view.preset.name}/${provider.model} · 未包含模块 JSON',
              ],
            );
            failures.add(
              '${view.preset.name}/${provider.model}(结构化): 未包含模块 JSON',
            );
            continue;
          }
          final List<Map<String, Object?>> normalized = normalizeModules(raw);
          final List<String> errors = ModuleSchemaValidator.validate(
            normalized,
          );
          if (errors.isNotEmpty) {
            failures.add('${view.preset.name}(结构化): 结构校验失败（${errors.first}）');
            continue;
          }
          final List<PlanModuleData> modules = normalized
              .map((Map<String, Object?> m) => PlanModuleData.fromJson(m))
              .toList();
          await _attachLightingScene(modules, theme, knownScenes);
          final PlanScore score = PlanScorer.score(
            modules,
            knownResourceIds: knownResources,
            knownSceneIds: knownScenes,
          );
          final draft = AiDraftResult(
            modules: modules,
            viaLocal: false,
            providerName: view.preset.name,
            rawText: result.content,
            reasoning: reasoning,
            shortcomings: score.shortcomings,
            totalScore: score.total,
            detailScore: score.detailScore,
            consistencyScore: score.consistencyScore,
            tokensIn: result.promptTokens,
            tokensOut: result.completionTokens,
            latencyMs: result.latencyMs,
            attempts: <String>[
              ...state.attempts,
              '${view.preset.name}/${provider.model} · 成功（质量分 '
                  '${score.total.toStringAsFixed(0)}，${result.latencyMs}ms）',
            ],
          );
          state = state.copyWith(draft: draft);
          if (score.needsRetry && attempt == 1) {
            failures.add('质量分 ${score.total.toStringAsFixed(0)} < 80，自动重试');
            state = state.copyWith(
              attempts: <String>[
                ...state.attempts,
                '${view.preset.name}/${provider.model} · 质量分 '
                    '${score.total.toStringAsFixed(0)} < 80，自动重试',
              ],
            );
            break stage2;
          }
          state = state.copyWith(
            generating: false,
            attempts: <String>[
              ...state.attempts,
              '${view.preset.name}/${provider.model} · 成功（质量分 '
                  '${score.total.toStringAsFixed(0)}，${result.latencyMs}ms）',
            ],
            status:
                '${view.preset.name} 生成完成（${modules.length} 个模块 · '
                '质量分 ${score.total.toStringAsFixed(0)} · ${result.latencyMs}ms）',
          );
          return draft;
        }
      }
    }

    return viaLocal(
      '云端全部失败（${failures.take(3).join('；')}）→ 已降级本地引擎',
      reasoning: reasoning,
    );
  }

  /// 对话式修订（F3）：返回合并后的模块与 diff，需用户确认后应用。
  Future<AiRevisionDraft?> revise({
    required List<PlanModuleData> modules,
    required String instruction,
    String? targetModuleId,
  }) async {
    final List<AiProviderView> configured = state.routed
        .where(
          (AiProviderView p) =>
              p.preset.id != 'custom' || p.preset.baseUrl.isNotEmpty,
        )
        .toList();
    if (configured.isEmpty) {
      state = state.copyWith(status: '对话式修订需要配置 AI 提供方；离线时可手动编辑模块');
      return null;
    }
    final StringBuffer summary = StringBuffer('当前策划案模块概览：\n');
    for (var i = 0; i < modules.length; i++) {
      final PlanModuleData m = modules[i];
      summary.writeln(
        '${i + 1}. id=${m.id} type=${m.type.name} title=${m.title} 摘要=${m.summary}',
      );
    }
    PlanModuleData? target;
    for (final PlanModuleData m in modules) {
      if (m.id == targetModuleId) target = m;
    }
    final String userPrompt =
        '$summary\n'
        '${target == null ? '' : '目标模块完整 JSON：\n${jsonEncode(target.toJson())}\n'}\n'
        '修改指令：$instruction\n'
        '只输出需要变更或新增的模块（修改的模块必须保持原 id）；data 为 JSON 字符串。';

    state = state.copyWith(status: '正在生成修订预览…');
    final AiClient client = _client ?? AiClient();
    for (final AiProviderView view in configured) {
      final RuntimeProvider provider = await _runtimeOf(view);
      final AiCallResult result = await client.chat(
        provider: provider,
        systemPrompt: buildRevisionSystemPrompt(),
        userPrompt: userPrompt,
        maxTokens: 4096,
        schema: planJsonSchema,
        schemaName: 'plan_modules',
      );
      await _log(result);
      if (!result.success) continue;
      final List<Object?>? raw = extractModules(result.content);
      if (raw == null) continue;
      final List<Map<String, Object?>> normalized = normalizeModules(raw);
      if (ModuleSchemaValidator.validate(normalized).isNotEmpty) continue;

      final changedIds = <String>{};
      final merged = <PlanModuleData>[
        ...modules.map(
          (PlanModuleData m) => PlanModuleData.fromJson(m.toJson()),
        ),
      ];
      for (final Map<String, Object?> rawModule in normalized) {
        final PlanModuleData incoming = PlanModuleData.fromJson(rawModule);
        final int index = merged.indexWhere(
          (PlanModuleData m) => m.id == incoming.id,
        );
        if (index >= 0) {
          merged[index] = PlanModuleData(
            id: incoming.id,
            type: incoming.type,
            title: incoming.title,
            data: _preserveLocalAssets(
              incoming.type,
              merged[index].data,
              incoming.data,
            ),
            folded: merged[index].folded,
          );
        } else {
          merged.add(incoming);
        }
        changedIds.add(incoming.id);
      }
      final PlanDiff diff = diffPlans(modules, merged);
      final draft = AiRevisionDraft(
        modules: merged,
        diff: diff,
        instruction: instruction,
        providerName: view.preset.name,
        rawText: result.content,
        changedModuleIds: changedIds,
      );
      state = state.copyWith(
        revision: draft,
        status: '修订预览已生成：${diff.totalChanges} 处变更，确认后应用',
      );
      return draft;
    }
    state = state.copyWith(status: '修订失败：所有提供方均未返回可用结果');
    return null;
  }

  void clearRevision() => state = state.copyWith(revision: null);

  /// D29：把策划案里的灯位建议物化为可打开的布光场景并回绑 sceneId。
  Future<void> _attachLightingScene(
    List<PlanModuleData> modules,
    String theme,
    Set<String> knownScenes,
  ) async {
    final int now = DateTime.now().millisecondsSinceEpoch;
    for (final PlanModuleData module in modules) {
      if (module.type != PlanModuleType.lighting) continue;
      final String existing = module.data['sceneId'] as String? ?? '';
      if (existing.isNotEmpty && knownScenes.contains(existing)) continue;
      final List<Object?> rawLights =
          (module.data['lights'] as List? ?? <Object?>[]);
      final List<Map<String, Object?>> devices = <Map<String, Object?>>[];
      var i = 0;
      for (final Object? raw in rawLights) {
        if (raw is! Map) continue;
        i++;
        final Map<String, Object?> m = raw.cast<String, Object?>();
        devices.add(<String, Object?>{
          'id': 'ai-light-$i',
          'kind': 'light',
          'name': (m['name'] as String? ?? '').isEmpty ? '灯 $i' : m['name'],
          'type': m['type'] as String? ?? 'soft',
          'x': (m['x'] as num?)?.toDouble() ?? 0,
          'y': (m['y'] as num?)?.toDouble() ?? 0,
          'height': (m['height'] as num?)?.toDouble() ?? 2.0,
          'intensity': (m['intensity'] as num?)?.toInt() ?? 60,
          'kelvin': (m['kelvin'] as num?)?.toInt() ?? 5600,
          'beamAngle': (m['beamAngle'] as num?)?.toDouble() ?? 45,
          'softness': (m['softness'] as num?)?.toDouble() ?? 0.2,
          'color': m['color'] as String? ?? '#ffffff',
          'rotation': 0,
          'scale': 1,
        });
      }
      if (devices.isEmpty) continue;
      final String trimmed = theme.trim();
      final String title = trimmed.isEmpty
          ? 'AI 布光'
          : trimmed.substring(0, trimmed.length > 14 ? 14 : trimmed.length);
      final String name =
          (module.data['sceneName'] as String? ?? '').trim().isEmpty
          ? '$title · AI 布光'
          : module.data['sceneName'] as String;
      final String newId = 'ai-${DateTime.now().microsecondsSinceEpoch}';
      await _db
          .into(_db.lightingScenes)
          .insert(
            LightingScenesCompanion.insert(
              id: newId,
              name: name,
              sceneJson: jsonEncode(<String, Object?>{
                'id': newId,
                'name': name,
                'devices': devices,
              }),
              linkedPoseId: const Value(null),
              updatedAt: now,
            ),
          );
      module.data['sceneId'] = newId;
      module.data['sceneName'] = name;
      module.data['note'] = 'AI 已自动生成布光场景（${devices.length} 灯，可打开预演微调）';
      knownScenes.add(newId);
    }
  }

  Future<RuntimeProvider> _runtimeOf(
    AiProviderView view, {
    String? model,
  }) async {
    final String key = view.encryptedKey.isEmpty
        ? ''
        : await _vault.decrypt(view.encryptedKey);
    return RuntimeProvider(
      id: view.preset.id,
      name: view.preset.name,
      protocol: view.preset.protocol,
      baseUrl: view.preset.baseUrl,
      apiKey: key,
      model: (model ?? '').isNotEmpty ? model! : view.model,
    );
  }

  /// 候选模型（质量优先，最多 3 个，失败自动换模型再换商）。
  List<String> _candidatesFor(AiProviderView view) {
    final String picked = pickBestModel(view.models, preferred: view.model);
    final List<String> list = <String>[
      if (picked.isNotEmpty) picked,
      if (view.model.isNotEmpty) view.model,
      ...view.models,
    ];
    return list.toSet().take(3).toList();
  }

  /// 拉取模型列表并持久化 + 自动选模（D40）。
  Future<List<String>> fetchModels(String providerId) async {
    final AiProviderView? view = state.providers
        .where((AiProviderView p) => p.preset.id == providerId)
        .firstOrNull;
    if (view == null) return <String>[];
    final RuntimeProvider provider = await _runtimeOf(view);
    try {
      final List<String> models = await (_client ?? AiClient()).discoverModels(
        provider,
      );
      if (models.isEmpty) return <String>[];
      final String picked = pickBestModel(models, preferred: view.model);
      await (_db.update(
        _db.providerConfigs,
      )..where((t) => t.id.equals(providerId))).write(
        ProviderConfigsCompanion(
          modelsJson: Value(jsonEncode(models)),
          defaultModel: Value(picked),
        ),
      );
      await refresh();
      return models;
    } catch (_) {
      return <String>[];
    }
  }

  /// 启动后为已配置 Key 且尚无模型列表的提供方自动拉取（静默失败）。
  Future<void> autoFetchMissingModels() async {
    final List<AiProviderView> need = state.providers
        .where((AiProviderView p) => p.enabled && p.hasKey && p.models.isEmpty)
        .take(3)
        .toList();
    for (final AiProviderView view in need) {
      await fetchModels(view.preset.id);
    }
  }

  Future<Set<String>> _knownResourceIds() async {
    final rows = await _db.select(_db.resources).get();
    return rows.map((Resource r) => r.id).toSet();
  }

  Future<Set<String>> _knownSceneIds() async {
    final rows = await _db.select(_db.lightingScenes).get();
    return rows.map((LightingScene s) => s.id).toSet();
  }

  Future<Map<String, List<String>>> _resourceSummary() async {
    final rows = await _db.select(_db.resources).get();
    final map = <String, List<String>>{};
    for (final Resource row in rows) {
      map.putIfAbsent(row.type, () => <String>[]).add(row.name);
    }
    return map;
  }

  /// 修订合并时保护本地资产：同名的样片图片与姿势骨骼不被 AI 文本改写丢失。
  Map<String, Object?> _preserveLocalAssets(
    PlanModuleType type,
    Map<String, Object?> oldData,
    Map<String, Object?> newData,
  ) {
    if (type == PlanModuleType.refs) {
      final List<Object?> oldRefs = (oldData['refs'] as List? ?? <Object?>[])
          .cast<Object?>();
      final List<Object?> newRefs = (newData['refs'] as List? ?? <Object?>[])
          .cast<Object?>();
      for (final Object? entry in newRefs) {
        if (entry is! Map) continue;
        if ((entry['imageRef'] as String? ?? '').isNotEmpty) continue;
        for (final Object? old in oldRefs) {
          if (old is Map &&
              (old['name'] as String? ?? '') ==
                  (entry['name'] as String? ?? '')) {
            final String oldRef = old['imageRef'] as String? ?? '';
            if (oldRef.isNotEmpty) entry['imageRef'] = oldRef;
          }
        }
      }
      newData['refs'] = newRefs;
    }
    if (type == PlanModuleType.poses) {
      final List<Object?> oldPoses = (oldData['poses'] as List? ?? <Object?>[])
          .cast<Object?>();
      final List<Object?> newPoses = (newData['poses'] as List? ?? <Object?>[])
          .cast<Object?>();
      for (final Object? entry in newPoses) {
        if (entry is! Map) continue;
        if (asMap(entry['joints']).isNotEmpty) continue;
        for (final Object? old in oldPoses) {
          if (old is Map &&
              (old['name'] as String? ?? '') ==
                  (entry['name'] as String? ?? '')) {
            final Map<String, Object?> oldJoints = asMap(old['joints']);
            if (oldJoints.isNotEmpty) {
              entry['joints'] = oldJoints;
              entry['lens'] = entry['lens'] ?? old['lens'];
              entry['cameraPosition'] =
                  entry['cameraPosition'] ?? old['cameraPosition'];
            }
          }
        }
      }
      newData['poses'] = newPoses;
    }
    return newData;
  }

  List<Map<String, Object?>> _boardFrames() {
    final board = ref.read(refsControllerProvider).board;
    return board
        .map(
          (RefFrame frame) => <String, Object?>{
            'name': frame.name,
            'palette': frame.palette,
            'gradient': frame.gradient,
            'sourceUrl': frame.sourceUrl,
            'imageRef': frame.imagePath,
          },
        )
        .toList();
  }

  Future<({String id, String name})?> _latestLightingScene() async {
    final rows =
        await (_db.select(_db.lightingScenes)
              ..orderBy(<OrderClauseGenerator<$LightingScenesTable>>[
                (t) => OrderingTerm(
                  expression: t.updatedAt,
                  mode: OrderingMode.desc,
                ),
              ])
              ..limit(1))
            .get();
    if (rows.isEmpty) return null;
    return (id: rows.first.id, name: rows.first.name);
  }

  Future<List<Map<String, Object?>>> _favoritePoses() async {
    final rows = await (_db.select(
      _db.poses,
    )..where((t) => t.favorite.equals(true))).get();
    return rows
        .map(
          (Pose row) => <String, Object?>{
            'name': row.name,
            'lens': row.lensAdvice,
            'joints': asMap(jsonDecode(row.jointsJson)),
          },
        )
        .toList();
  }

  /// 深度上下文（F3）：资源条目、画板色卡、布光方案、收藏姿势（含镜头/机位）、
  /// 城市档位、预算价格区间。
  Future<String> _buildContext(
    String theme,
    Map<String, List<String>> resources,
    List<Map<String, Object?>> boardFrames,
    ({String id, String name})? scene,
    List<Map<String, Object?>> poses,
  ) async {
    final buffer = StringBuffer('主题：${theme.trim()}\n');
    if (resources.isNotEmpty) {
      buffer.writeln('工作区资源摘要：');
      for (final MapEntry<String, List<String>> entry in resources.entries) {
        buffer.writeln('- ${entry.key}: ${entry.value.take(8).join('、')}');
      }
    }
    if (boardFrames.isNotEmpty) {
      final palettes = boardFrames
          .take(3)
          .map(
            (Map<String, Object?> f) =>
                (f['palette'] as List?)?.join('/') ?? '',
          )
          .where((String s) => s.isNotEmpty)
          .join('；');
      if (palettes.isNotEmpty) buffer.writeln('画板色卡参考：$palettes');
    }
    if (scene != null) {
      buffer.writeln(
        '已有布光方案：${scene.name}（lighting 模块可引用 sceneId=${scene.id}）',
      );
    }
    if (poses.isNotEmpty) {
      buffer.writeln('收藏姿势（含镜头与机位建议）：');
      for (final Map<String, Object?> p in poses.take(6)) {
        buffer.writeln(
          '- ${p['name']}：${p['lens'] ?? ''}；${p['cameraPosition'] ?? ''}',
        );
      }
    }
    final List<CityEntry> cities = await ContentPacks.cities();
    final List<BudgetItemEntry> budget = await ContentPacks.budgetRefs();
    if (cities.isNotEmpty) {
      buffer.writeln(
        '可选城市（sun 模块用，含坐标）：'
        '${cities.take(12).map((CityEntry c) => '${c.name}(${c.lat},${c.lon})').join('、')} 等',
      );
    }
    if (budget.isNotEmpty) {
      buffer.writeln('预算参考区间（人民币，按城市档位乘系数）：');
      for (final BudgetItemEntry item in budget) {
        buffer.writeln(
          '- ${item.label}: ${item.min.round()}–${item.max.round()}（${item.note}）',
        );
      }
    }
    return buffer.toString();
  }

  /// 观测台汇总。
  ({int calls, int success, double avgLatency, int tokensIn, int tokensOut})
  logSummary() {
    final logs = state.logs;
    if (logs.isEmpty) {
      return (calls: 0, success: 0, avgLatency: 0, tokensIn: 0, tokensOut: 0);
    }
    final success = logs.where((CallLog l) => l.success).length;
    final avg =
        logs.map((CallLog l) => l.latencyMs).reduce((int a, int b) => a + b) /
        logs.length;
    return (
      calls: logs.length,
      success: success,
      avgLatency: avg,
      tokensIn: logs
          .map((CallLog l) => l.promptTokens)
          .fold(0, (int a, int b) => a + b),
      tokensOut: logs
          .map((CallLog l) => l.completionTokens)
          .fold(0, (int a, int b) => a + b),
    );
  }
}
