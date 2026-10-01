// V8/S8 · D155：AI 开案生成主流程（generatePlan：资源装配 → 上下文 → 路由 →
// 同商换模型 → 换商 → 本地引擎兜底，含 D155 的取消检查点）。
// 从 ai_controller.dart 拆出（R73 行数门禁）；part 同库，私有成员无需公开化。
part of 'ai_controller.dart';

extension AiControllerGenerate on AiController {
  Future<AiDraftResult> generatePlan(
    String theme, {
    bool forceLocal = false,
  }) async {
    _state = _state.copyWith(
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
    if (_checkCancelled()) return _cancelledDraft();
    // D155：资源装配是 IO 密集段，取消在这里最先生效。

    var localSeq = 0;
    Future<AiDraftResult> viaLocal(
      String reason, {
      String reasoning = '',
    }) async {
      if (_cancelRequested) return _cancelledDraft();
      final modules = await AiController._localEngine.generate(
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
        attempts: _state.attempts,
      );
      _state = _state.copyWith(
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

    final routed = _state.routed;
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
      if (_cancelRequested) break stage1;
      for (final String model in _candidatesFor(view)) {
        final RuntimeProvider provider = await _runtimeOf(view, model: model);
        _state = _state.copyWith(
          status: '正在构思策划思路 · ${view.preset.name}/${provider.model}…',
        );
        final AiCallResult result = await client.chat(
          provider: provider,
          systemPrompt: buildReasoningSystemPrompt(),
          userPrompt: context,
          maxTokens: 2048,
          onDelta: (String delta) {
            _state = _state.copyWith(
              reasoningText: _state.reasoningText + delta,
              streamText: _state.reasoningText + delta,
            );
          },
        );
        await _log(result);
        _state = _state.copyWith(
          attempts: <String>[
            ..._state.attempts,
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
        if (_cancelRequested) return _abortIfCancelled();
        for (final String model in _candidatesFor(view)) {
          final RuntimeProvider provider =
              (working != null &&
                  working.id == view.preset.id &&
                  working.model == model)
              ? working
              : await _runtimeOf(view, model: model);
          _state = _state.copyWith(
            status: attempt == 1
                ? '正在结构化输出 · ${view.preset.name}/${provider.model}…'
                : '质量分不足，正在按反馈重试 · ${view.preset.name}/${provider.model}…',
          );
          final String feedback =
              attempt == 2 && (_state.draft?.shortcomings.isNotEmpty ?? false)
              ? '\n\n上一次输出的不足（必须逐条修正）：\n'
                    '${_state.draft!.shortcomings.take(6).join('\n')}'
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
            _state = _state.copyWith(
              attempts: <String>[
                ..._state.attempts,
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
            _state = _state.copyWith(
              attempts: <String>[
                ..._state.attempts,
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
              ..._state.attempts,
              '${view.preset.name}/${provider.model} · 成功（质量分 '
                  '${score.total.toStringAsFixed(0)}，${result.latencyMs}ms）',
            ],
          );
          _state = _state.copyWith(draft: draft);
          if (score.needsRetry && attempt == 1) {
            failures.add('质量分 ${score.total.toStringAsFixed(0)} < 80，自动重试');
            _state = _state.copyWith(
              attempts: <String>[
                ..._state.attempts,
                '${view.preset.name}/${provider.model} · 质量分 '
                    '${score.total.toStringAsFixed(0)} < 80，自动重试',
              ],
            );
            break stage2;
          }
          _state = _state.copyWith(
            generating: false,
            attempts: <String>[
              ..._state.attempts,
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

    if (_cancelRequested) return _abortIfCancelled();
    // D155：收尾前再确认一次取消状态。
    return viaLocal(
      '云端全部失败（${failures.take(3).join('；')}）→ 已降级本地引擎',
      reasoning: reasoning,
    );
  }
}
