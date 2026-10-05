part of 'planner_page.dart';

class _PoseInfoDialog extends StatelessWidget {
  const _PoseInfoDialog({required this.pose});

  final Map<String, Object?> pose;

  @override
  Widget build(BuildContext context) {
    final String lens = pose['lens'] as String? ?? '';
    final String camera = pose['cameraPosition'] as String? ?? '';
    final String photo = pose['photo'] as String? ?? '';
    final String skeleton = pose['skeleton'] as String? ?? '';
    final String author = pose['author'] as String? ?? '';
    final String license = pose['license'] as String? ?? '';
    final int jointCount =
        (pose['joints'] as Map? ?? <String, Object?>{}).length;
    final String attribution = <String>[
      if (author.isNotEmpty) author,
      if (license.isNotEmpty) license,
    ].join(' · ');
    return AlertDialog(
      title: Text(
        pose['name'] as String? ?? '姿势',
        style: const TextStyle(fontSize: AppFontSize.bodyXl),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (photo.isNotEmpty) ...<Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.frame),
                child: SizedBox(
                  width: 220,
                  height: 280,
                  child: PosePhotoView(
                    photo: photo,
                    skeleton: skeleton,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (lens.isNotEmpty)
              Text(
                '镜头建议：$lens',
                style: const TextStyle(fontSize: AppFontSize.smallLg),
              ),
            if (camera.isNotEmpty)
              Text(
                '机位建议：$camera',
                style: const TextStyle(fontSize: AppFontSize.smallLg),
              ),
            if (jointCount > 0)
              Text(
                '关节数：$jointCount（导出可选「照片 / 骨架示意」）',
                style: const TextStyle(fontSize: AppFontSize.smallSm),
              ),
            if (attribution.isNotEmpty)
              Text(
                '照片：$attribution',
                style: const TextStyle(
                  fontSize: AppFontSize.caption,
                  color: AppFeatureColor.panelInk,
                ),
              ),
            const SizedBox(height: 4),
            if (photo.isEmpty)
              const Text(
                '在「动作摆姿库」可查看照片、骨架与动作要领。',
                style: TextStyle(fontSize: AppFontSize.smallSm),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

/// 从内置姿势库替换（F4）。
class _PoseReplaceDialog extends StatefulWidget {
  const _PoseReplaceDialog();

  @override
  State<_PoseReplaceDialog> createState() => _PoseReplaceDialogState();
}

class _PoseReplaceDialogState extends State<_PoseReplaceDialog> {
  List<PoseEntry> _all = <PoseEntry>[];
  String _query = '';

  @override
  void initState() {
    super.initState();
    ContentPacks.poses().then((List<PoseEntry> poses) {
      if (mounted) setState(() => _all = poses);
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<PoseEntry> matches = _query.trim().isEmpty
        ? _all.take(30).toList()
        : _all
              .where((PoseEntry pose) => pose.name.contains(_query.trim()))
              .take(30)
              .toList();
    return AlertDialog(
      title: const Text('替换姿势', style: TextStyle(fontSize: AppFontSize.bodyXl)),
      content: SizedBox(
        width: 360,
        height: 380,
        child: Column(
          children: <Widget>[
            TextField(
              decoration: const InputDecoration(
                hintText: '搜索姿势名，例如：回眸 / 蹲',
                isDense: true,
              ),
              onChanged: (String v) => setState(() => _query = v),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: ListView.builder(
                itemCount: matches.length,
                itemBuilder: (BuildContext context, int i) {
                  final PoseEntry pose = matches[i];
                  return ListTile(
                    dense: true,
                    title: Text(
                      pose.name,
                      style: const TextStyle(fontSize: AppFontSize.small),
                    ),
                    subtitle: Text(
                      <String>[
                        pose.lens,
                        pose.cameraPosition,
                      ].where((String s) => s.isNotEmpty).join(' · '),
                      style: const TextStyle(fontSize: AppFontSize.caption),
                    ),
                    onTap: () => Navigator.pop(context, <String, Object?>{
                      'name': pose.name,
                      'joints': pose.joints,
                      'lens': pose.lens,
                      'cameraPosition': pose.cameraPosition,
                      'photo': pose.photo,
                      'author': pose.author,
                      'license': pose.license,
                      'source': pose.source,
                    }),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ],
    );
  }
}

/// 预算估算参数（F9）：城市档位系数 + 人数。
class _BudgetEstimateDialog extends StatefulWidget {
  const _BudgetEstimateDialog();

  @override
  State<_BudgetEstimateDialog> createState() => _BudgetEstimateDialogState();
}

class _BudgetEstimateDialogState extends State<_BudgetEstimateDialog> {
  List<CityEntry> _cities = <CityEntry>[];
  Map<String, double> _multipliers = <String, double>{};
  CityEntry? _city;
  final TextEditingController _people = TextEditingController(text: '4');

  @override
  void initState() {
    super.initState();
    ContentPacks.cities().then((List<CityEntry> cities) {
      if (!mounted) return;
      setState(() {
        _cities = cities;
        _city = cities.firstWhere(
          (CityEntry c) => c.name == '上海',
          orElse: () => cities.first,
        );
      });
    });
    ContentPacks.cityMultipliers().then((Map<String, double> m) {
      if (mounted) setState(() => _multipliers = m);
    });
  }

  @override
  void dispose() {
    _people.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'AI 预算估算',
        style: TextStyle(fontSize: AppFontSize.bodyXl),
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              '按内置价格区间 × 城市档位系数生成，结果标注「估算值」，可手动微调。',
              style: TextStyle(fontSize: AppFontSize.smallSm),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<CityEntry>(
              initialValue: _city,
              decoration: const InputDecoration(labelText: '城市', isDense: true),
              items: <DropdownMenuItem<CityEntry>>[
                for (final CityEntry c in _cities)
                  DropdownMenuItem<CityEntry>(
                    value: c,
                    child: Text('${c.name} · ${c.tier}'),
                  ),
              ],
              onChanged: (CityEntry? v) => setState(() => _city = v),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _people,
              decoration: const InputDecoration(
                labelText: '人数（餐饮按人数估算）',
                isDense: true,
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        SsButton(
          label: '生成估算',
          onPressed: _city == null
              ? null
              : () {
                  final String tier = _city!.tier;
                  Navigator.pop(context, (
                    city: _city!.name,
                    tier: tier,
                    multiplier: _multipliers[tier] ?? 1.0,
                    people: int.tryParse(_people.text) ?? 1,
                  ));
                },
        ),
      ],
    );
  }
}
