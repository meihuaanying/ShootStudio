import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../services/richtext_lite.dart';
import 'planner_models.dart';

/// 模块正文只读渲染（D28）：阅读模式 / 画布展开 / 草稿预览共用。
/// 与导出渲染保持语义一致（同一份 data）。
class ModuleContentView extends StatelessWidget {
  const ModuleContentView(
      {super.key, required this.module, this.compact = false});

  final PlanModuleData module;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Widget body = switch (module.type) {
      PlanModuleType.theme ||
      PlanModuleType.richText =>
        _richText(context, module.data['text'] as String? ?? ''),
      PlanModuleType.palette => _palette(context),
      PlanModuleType.lighting => _lighting(context),
      PlanModuleType.poses => _poses(context),
      PlanModuleType.refs => _refs(context),
      PlanModuleType.storyboard => _storyboard(context),
      PlanModuleType.sun => _sun(context),
      PlanModuleType.crew => _rows(context,
          fields: <String>['role', 'who', 'time'],
          labels: <String>['角色', '成员', '时间']),
      PlanModuleType.budget => _rows(context,
          fields: <String>['item', 'price', 'note'],
          labels: <String>['项目', '金额', '备注'],
          isBudget: true),
      _ => _binding(context),
    };
    return DefaultTextStyle.merge(
      style: TextStyle(fontSize: compact ? 12 : 13, height: 1.55),
      child: body,
    );
  }

  Widget _richText(BuildContext context, String text) {
    if (text.trim().isEmpty) {
      return const Text('（空）', style: TextStyle(color: AppTokens.lightMuted));
    }
    final List<RichLine> lines = RichTextLite.parse(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final RichLine line in lines)
          Padding(
            padding: EdgeInsets.only(left: line.bullet ? 10 : 0, bottom: 2),
            child: Text.rich(
              TextSpan(children: <InlineSpan>[
                if (line.bullet)
                  const TextSpan(
                      text: '• ', style: TextStyle(color: AppTokens.accent)),
                for (final RichSpan span in line.spans)
                  TextSpan(
                    text: span.text,
                    style: TextStyle(
                        fontWeight:
                            span.bold ? FontWeight.w700 : FontWeight.w400),
                  ),
              ]),
            ),
          ),
      ],
    );
  }

  Widget _palette(BuildContext context) {
    final List<String> colors =
        (module.data['colors'] as List? ?? <Object?>[]).cast<String>();
    if (colors.isEmpty) return const Text('（暂无色卡）');
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        for (final String hex in colors)
          Column(
            children: <Widget>[
              Container(
                width: 56,
                height: 40,
                decoration: BoxDecoration(
                  color: _hex(hex),
                  borderRadius: BorderRadius.circular(AppTokens.rSm),
                  border:
                      Border.all(color: Theme.of(context).colorScheme.outline),
                ),
              ),
              const SizedBox(height: 2),
              Text(hex,
                  style: const TextStyle(fontSize: 10, fontFamily: 'Consolas')),
            ],
          ),
      ],
    );
  }

  Widget _lighting(BuildContext context) {
    final String name = module.data['sceneName'] as String? ?? '';
    final String note = module.data['note'] as String? ?? '';
    final List<Object?> lights = module.data['lights'] as List? ?? <Object?>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (name.isNotEmpty)
          Text('布光方案：$name',
              style: const TextStyle(fontWeight: FontWeight.w600)),
        if (note.isNotEmpty) Text(note),
        if (lights.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          for (var i = 0; i < lights.length; i++)
            if (lights[i] is Map)
              Builder(builder: (_) {
                final Map<Object?, Object?> m =
                    lights[i] as Map<Object?, Object?>;
                final double x = (m['x'] as num?)?.toDouble() ?? 0;
                final double y = (m['y'] as num?)?.toDouble() ?? 0;
                final double h = (m['height'] as num?)?.toDouble() ?? 2;
                final int k = (m['kelvin'] as num?)?.toInt() ?? 5600;
                final int p = (m['intensity'] as num?)?.toInt() ?? 60;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '${i + 1}. ${m['name'] ?? '灯'} · '
                    '位置(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)})m · '
                    '高 ${h.toStringAsFixed(1)}m · $p% · ${k}K',
                  ),
                );
              }),
        ],
      ],
    );
  }

  Widget _poses(BuildContext context) {
    final List<Object?> poses = module.data['poses'] as List? ?? <Object?>[];
    if (poses.isEmpty) return const Text('（姿势清单为空：可从姿势库加入）');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (var i = 0; i < poses.length; i++)
          if (poses[i] is Map)
            Builder(builder: (_) {
              final Map<Object?, Object?> p = poses[i] as Map<Object?, Object?>;
              final String lens = p['lens'] as String? ?? '';
              final String camera = p['cameraPosition'] as String? ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text('${i + 1}. ${p['name'] ?? '姿势'}'
                    '${lens.isEmpty ? '' : ' · $lens'}'
                    '${camera.isEmpty ? '' : ' · $camera'}'),
              );
            }),
      ],
    );
  }

  Widget _storyboard(BuildContext context) {
    final List<Object?> shots = module.data['shots'] as List? ?? <Object?>[];
    if (shots.isEmpty) return const Text('（分镜为空：可让 AI 生成或手动添加）');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final Object? shot in shots)
          if (shot is Map)
            Builder(builder: (_) {
              final Map<Object?, Object?> s = shot;
              final bool key = s['key'] == true;
              final String note = s['note'] as String? ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '${s['no'] ?? ''}. ${s['shotSize'] ?? ''} · ${s['lens'] ?? ''} · '
                  '${s['camera'] ?? ''} · 姿势：${s['pose'] ?? ''}'
                  '${(s['lighting'] as String? ?? '').isEmpty ? '' : ' · ${s['lighting']}'}'
                  '${key ? ' · ★重点' : ''}'
                  '${note.isEmpty ? '' : '\n     $note'}',
                  style: TextStyle(
                    fontWeight: key ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              );
            }),
      ],
    );
  }

  Widget _refs(BuildContext context) {
    final List<Object?> refs = module.data['refs'] as List? ?? <Object?>[];
    if (refs.isEmpty) return const Text('（参考样片为空）');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (var i = 0; i < refs.length; i++)
          if (refs[i] is Map)
            Builder(builder: (_) {
              final Map<Object?, Object?> f = refs[i] as Map<Object?, Object?>;
              final String src = f['sourceUrl'] as String? ?? '';
              final bool hasImage = (f['imageRef'] as String? ?? '').isNotEmpty;
              return Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text('${i + 1}. ${f['name'] ?? '样片'}'
                    '${hasImage ? ' · 本地图片' : ''}'
                    '${src.isEmpty ? '' : ' · 出处：$src'}'),
              );
            }),
      ],
    );
  }

  Widget _sun(BuildContext context) {
    final String place = module.data['place'] as String? ?? '';
    final String date = module.data['date'] as String? ?? '';
    final double? lat = (module.data['lat'] as num?)?.toDouble();
    final double? lon = (module.data['lon'] as num?)?.toDouble();
    return Text('$place · $date'
        '${lat == null || lon == null ? '' : ' · (${lat.toStringAsFixed(2)}, ${lon.toStringAsFixed(2)})'}');
  }

  Widget _rows(BuildContext context,
      {required List<String> fields,
      required List<String> labels,
      bool isBudget = false}) {
    final List<Object?> rows = module.data['rows'] as List? ?? <Object?>[];
    if (rows.isEmpty) return const Text('（暂无明细）');
    var total = 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final Object? row in rows)
          if (row is Map)
            Builder(builder: (_) {
              final Map<Object?, Object?> r = row;
              if (isBudget) {
                total += ((r['price'] as num?)?.toDouble() ?? 0);
              }
              final String note = r['note'] as String? ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(isBudget
                    ? '· ${r['item'] ?? ''}  ¥${r['price'] ?? 0}${note.isEmpty ? '' : '  （$note）'}'
                    : '· ${r['role'] ?? ''}  ${r['who'] ?? ''}  ${r['time'] ?? ''}'),
              );
            }),
        if (isBudget && total > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('合计 ¥${total.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }

  Widget _binding(BuildContext context) {
    final List<String> ids =
        (module.data['ids'] as List? ?? <Object?>[]).cast<String>();
    final String note = module.data['note'] as String? ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(ids.isEmpty ? '（未绑定资源）' : '已绑定 ${ids.length} 项资源'),
        if (note.isNotEmpty) Text(note),
      ],
    );
  }

  Color _hex(String hex) => Color(0xFF000000 |
      (int.tryParse(hex.replaceFirst('#', ''), radix: 16) ?? 0x888888));
}
