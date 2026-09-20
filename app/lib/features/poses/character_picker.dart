import 'package:flutter/material.dart';

import '../../core/design/widgets.dart';
import '../../core/theme/tokens.dart';
import '../../services/content_packs.dart';
import '../../services/engine/engine_bridge.dart';

/// V3 人物选择（GLB 人物/发型/肤色）——布光预演与动作摆姿共用。
class CharacterSelection {
  const CharacterSelection({
    required this.characterId,
    required this.characterName,
    this.hairId,
    this.skinTone,
  });

  final String characterId;
  final String characterName;
  final String? hairId;
  final String? skinTone;

  CharacterSelection copyWith({
    String? characterId,
    String? characterName,
    Object? hairId = _sentinel,
    Object? skinTone = _sentinel,
  }) => CharacterSelection(
    characterId: characterId ?? this.characterId,
    characterName: characterName ?? this.characterName,
    hairId: hairId == _sentinel ? this.hairId : hairId as String?,
    skinTone: skinTone == _sentinel ? this.skinTone : skinTone as String?,
  );

  static const Object _sentinel = Object();
}

/// 弹出人物选择器；返回新选择或 null。
Future<CharacterSelection?> showCharacterPicker(
  BuildContext context, {
  required CharacterSelection current,
}) => showModalBottomSheet<CharacterSelection>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _CharacterPickerSheet(current: current),
);

/// 应用选择到 3D 引擎（含失败提示由引擎 error 事件负责）。
Future<void> applyCharacterSelection(
  EngineBridge? bridge,
  CharacterSelection selection,
) async {
  if (bridge == null) return;
  await bridge.setCharacter(selection.characterId);
  await bridge.setHair(selection.hairId);
  await bridge.setSkinTone(selection.skinTone);
}

class _CharacterPickerSheet extends StatefulWidget {
  const _CharacterPickerSheet({required this.current});
  final CharacterSelection current;

  @override
  State<_CharacterPickerSheet> createState() => _CharacterPickerSheetState();
}

class _CharacterPickerSheetState extends State<_CharacterPickerSheet> {
  List<Map<String, Object?>> _realistic = <Map<String, Object?>>[];
  List<Map<String, Object?>> _characters = <Map<String, Object?>>[];
  List<Map<String, Object?>> _hair = <Map<String, Object?>>[];
  late CharacterSelection _selection = widget.current;
  bool _loaded = false;

  static const List<String> _skinTones = <String>[
    '#f2d6c0',
    '#e8bd9a',
    '#c98f68',
    '#8d5a3b',
    '#5b3a28',
  ];

  @override
  void initState() {
    super.initState();
    ContentPacks.charactersManifest().then((Map<String, Object?> data) {
      if (!mounted) return;
      setState(() {
        // V4/Q1.5：写实角色（MakeHuman CC0 / CC-BY），面数 74k–85k。
        final Map<String, Object?> realisticInfo = data['realistic'] is Map
            ? (data['realistic'] as Map).cast<String, Object?>()
            : <String, Object?>{};
        _realistic = (realisticInfo['items'] as List<Object?>? ?? <Object?>[])
            .whereType<Map>()
            .map((Map m) => m.cast<String, Object?>())
            .toList();
        _characters = (data['characters'] as List<Object?>? ?? <Object?>[])
            .whereType<Map>()
            .map((Map m) => m.cast<String, Object?>())
            .toList();
        _hair = (data['hair'] as List<Object?>? ?? <Object?>[])
            .whereType<Map>()
            .map((Map m) => m.cast<String, Object?>())
            .toList();
        _loaded = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SsSectionTitle(
              '人物与服装',
              subtitle: '写实人物（MakeHuman CC0，74k–85k 面）· 高面数 Quaternius 模型（CC0）',
            ),
            const SizedBox(height: AppTokens.s12),
            if (!_loaded)
              const Center(child: CircularProgressIndicator(strokeWidth: 2))
            else ...<Widget>[
              SizedBox(
                height: 150,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _realistic.length + _characters.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (BuildContext context, int i) {
                    if (i < _realistic.length) {
                      final Map<String, Object?> c = _realistic[i];
                      final String id = '${c['id']}';
                      return _tile(
                        title: '${c['name']}',
                        subtitle: '写实 · ${c['triCount']} 面',
                        badge: '写实',
                        selected: _selection.characterId == id,
                        theme: theme,
                        onTap: () => setState(
                          () => _selection = _selection.copyWith(
                            characterId: id,
                            characterName: '${c['name']}',
                          ),
                        ),
                      );
                    }
                    final int ci = i - _realistic.length;
                    if (ci == _characters.length) {
                      final bool legacy = _selection.characterId == 'legacy';
                      return _tile(
                        title: '轻量假人',
                        subtitle: '程序几何',
                        selected: legacy,
                        theme: theme,
                        onTap: () => setState(
                          () => _selection = _selection.copyWith(
                            characterId: 'legacy',
                            characterName: '轻量假人',
                          ),
                        ),
                      );
                    }
                    final Map<String, Object?> c = _characters[ci];
                    final String id = '${c['id']}';
                    return _tile(
                      title: '${c['name']}',
                      subtitle: '${c['tag']} · ${c['triCount']} 面',
                      selected: _selection.characterId == id,
                      theme: theme,
                      onTap: () => setState(
                        () => _selection = _selection.copyWith(
                          characterId: id,
                          characterName: '${c['name']}',
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  const Text('发型', style: TextStyle(fontSize: 12)),
                  SsChip(
                    label: '默认',
                    selected: _selection.hairId == null,
                    onTap: () => setState(
                      () => _selection = _selection.copyWith(hairId: null),
                    ),
                  ),
                  for (final Map<String, Object?> h in _hair)
                    SsChip(
                      label: '${h['name']}',
                      selected: _selection.hairId == '${h['id']}',
                      onTap: () => setState(
                        () => _selection = _selection.copyWith(
                          hairId: '${h['id']}',
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  const Text('肤色', style: TextStyle(fontSize: 12)),
                  for (final String hex in _skinTones)
                    InkWell(
                      onTap: () => setState(
                        () => _selection = _selection.copyWith(skinTone: hex),
                      ),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: _hex(hex),
                          shape: BoxShape.circle,
                          border: Border.all(
                            width: _selection.skinTone == hex ? 2.5 : 1,
                            color: _selection.skinTone == hex
                                ? AppTokens.accent
                                : theme.colorScheme.outline,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                const Spacer(),
                SsButton(
                  label: '应用',
                  onPressed: _loaded
                      ? () => Navigator.pop(context, _selection)
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile({
    required String title,
    required String subtitle,
    required bool selected,
    required ThemeData theme,
    required VoidCallback onTap,
    String? badge,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(AppTokens.rMd),
    child: Container(
      width: 118,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: selected
            ? AppTokens.accentSoft
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTokens.rMd),
        border: Border.all(
          color: selected ? AppTokens.accent : theme.colorScheme.outline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.person_rounded,
                size: 30,
                color: selected
                    ? AppTokens.accent
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const Spacer(),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppTokens.accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppTokens.accent,
                    ),
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );

  Color _hex(String hex) => Color(
    0xFF000000 |
        (int.tryParse(hex.replaceFirst('#', ''), radix: 16) ?? 0x888888),
  );
}
