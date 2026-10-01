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

part 'ai_controller_generate.dart';
part 'ai_controller_revise.dart';

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
    this.cancelled = false,
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

  /// D155：本次生成被用户取消（已取消的草稿只作为占位，不可写入画布）。
  final bool cancelled;
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

  /// D155：取消标记。生成过程中每个 await 之后检查一次，命中即回填占位草稿。
  bool _cancelRequested = false;

  /// 测试注入（F13）：Mock 端到端管线。
  void useClient(AiClient client) => _client = client;

  /// D155：取消本次生成（AI 面板「生成中」态的取消按钮）。
  ///
  /// 协作式取消：不打断已在飞行的 HTTP 请求，而是在下一个检查点收敛，
  /// 因此不会留下「按钮已停但后台仍在跑」的状态。
  void cancelGenerate() {
    if (!state.generating) return;
    _cancelRequested = true;
    state = state.copyWith(generating: false, status: '已取消本次生成');
  }

  /// D155：被取消时的占位草稿（不可写入画布，只用于让面板切到「阅读」态展示提示）。
  AiDraftResult _cancelledDraft() => AiDraftResult(
    modules: const <PlanModuleData>[],
    viaLocal: true,
    providerName: '已取消',
    rawText: '用户在生成过程中取消',
    reasoning: state.reasoningText,
    attempts: state.attempts,
    cancelled: true,
  );

  /// D155：命中取消时收敛状态并回填占位草稿（供各分支提前返回）。
  AiDraftResult _abortIfCancelled() {
    _checkCancelled();
    return _cancelledDraft();
  }

  bool _checkCancelled() {
    if (!_cancelRequested) return false;
    state = state.copyWith(
      generating: false,
      draft: _cancelledDraft(),
      status: '已取消本次生成（可调整描述后重试）',
    );
    return true;
  }

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

  /// extension 里读不到 Notifier 的 protected `state`，统一走这层内部访问器。
  AiState get _state => state;

  set _state(AiState value) => state = value;
}
