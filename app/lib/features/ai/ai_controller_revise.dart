// V8/S8 · D155：AI 修订与上下文装配（revise / 资源摘要 / 收藏姿势 / 布光场景 /
// 分镜帧 / 已知资源 ID / _buildContext）。从 ai_controller.dart 拆出。
part of 'ai_controller.dart';

extension AiControllerRevise on AiController {
  Future<AiRevisionDraft?> revise({
    required List<PlanModuleData> modules,
    required String instruction,
    String? targetModuleId,
  }) async {
    final List<AiProviderView> configured = _state.routed
        .where(
          (AiProviderView p) =>
              p.preset.id != 'custom' || p.preset.baseUrl.isNotEmpty,
        )
        .toList();
    if (configured.isEmpty) {
      _state = _state.copyWith(status: '对话式修订需要配置 AI 提供方；离线时可手动编辑模块');
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

    _state = _state.copyWith(status: '正在生成修订预览…');
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
      _state = _state.copyWith(
        revision: draft,
        status: '修订预览已生成：${diff.totalChanges} 处变更，确认后应用',
      );
      return draft;
    }
    _state = _state.copyWith(status: '修订失败：所有提供方均未返回可用结果');
    return null;
  }

  void clearRevision() => _state = _state.copyWith(revision: null);

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
    final AiProviderView? view = _state.providers
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
    final List<AiProviderView> need = _state.providers
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
    final logs = _state.logs;
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
