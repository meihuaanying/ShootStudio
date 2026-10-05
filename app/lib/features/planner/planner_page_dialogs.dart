// V8/S8 · D158：策划案页的输入类与对话框（富文本输入 / 城市搜索 / 取色器 /
// 姿势信息 / 姿势替换 / 预算估算）。part 顶层放类，私有互访关系不变。
part of 'planner_page.dart';

/// 富文本输入（F4）：加粗 / 无序列表轻量标记。
class _RichTextInput extends StatefulWidget {
  const _RichTextInput({
    super.key,
    required this.initial,
    required this.onChanged,
    required this.hint,
  });

  final String initial;
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  State<_RichTextInput> createState() => _RichTextInputState();
}

class _RichTextInputState extends State<_RichTextInput> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _apply(({String text, int selection}) result) {
    _controller.value = TextEditingValue(
      text: result.text,
      selection: TextSelection.collapsed(offset: result.selection),
    );
    widget.onChanged(result.text);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final TextSelection selection = _controller.selection;
    final int start = selection.isValid ? selection.start : 0;
    final int end = selection.isValid ? selection.end : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: '加粗',
              icon: const Icon(Icons.format_bold_rounded, size: 18),
              onPressed: () =>
                  _apply(RichTextLite.toggleBold(_controller.text, start, end)),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: '无序列表',
              icon: const Icon(Icons.format_list_bulleted_rounded, size: 18),
              onPressed: () => _apply(
                RichTextLite.toggleBullet(_controller.text, start, end),
              ),
            ),
          ],
        ),
        TextField(
          controller: _controller,
          focusNode: _focus,
          maxLines: 8,
          decoration: InputDecoration(hintText: widget.hint),
          onChanged: widget.onChanged,
        ),
      ],
    );
  }
}

/// 城市搜索（F10）：内置 73 城即时过滤 + Nominatim 在线兜底。
class _CitySearchField extends StatefulWidget {
  const _CitySearchField({required this.initial, required this.onPick});

  final String initial;
  final void Function(String name, double lat, double lon) onPick;

  @override
  State<_CitySearchField> createState() => _CitySearchFieldState();
}

class _CitySearchFieldState extends State<_CitySearchField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );
  List<CityEntry> _all = <CityEntry>[];
  List<CityEntry> _matches = <CityEntry>[];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    ContentPacks.cities().then((List<CityEntry> cities) {
      if (mounted) setState(() => _all = cities);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _filter(String query) {
    final String q = query.trim();
    setState(() {
      _matches = q.isEmpty
          ? <CityEntry>[]
          : _all.where((CityEntry c) => c.name.contains(q)).take(6).toList();
    });
  }

  Future<void> _onlineSearch() async {
    setState(() => _searching = true);
    final ({String name, double lat, double lon})? result =
        await GeocodingService().search(_controller.text);
    if (!mounted) return;
    setState(() => _searching = false);
    if (result == null) {
      ssToast(context, '在线搜索无结果或断网：可手输经纬度，或从内置城市选择');
      return;
    }
    _controller.text = result.name;
    widget.onPick(result.name, result.lat, result.lon);
    ssToast(context, '已定位：${result.name}');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: '城市（内置城市库，输入即筛选）',
                  isDense: true,
                ),
                onChanged: _filter,
              ),
            ),
            const SizedBox(width: 6),
            SsButton(
              label: _searching ? '搜索中…' : '在线搜索',
              kind: SsButtonKind.text,
              dense: true,
              onPressed: _searching ? null : _onlineSearch,
            ),
          ],
        ),
        for (final CityEntry city in _matches)
          Material(
            type: MaterialType.transparency,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${city.name} · ${city.tier}',
                style: const TextStyle(fontSize: AppFontSize.small),
              ),
              onTap: () {
                _controller.text = city.name;
                setState(() => _matches = <CityEntry>[]);
                widget.onPick(city.name, city.lat, city.lon);
              },
            ),
          ),
      ],
    );
  }
}

/// HSV 取色器（F4）。
class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog();

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  double _h = 210, _s = 0.7, _v = 0.8;
  late final TextEditingController _hex = TextEditingController(
    text: _hexOf(HSVColor.fromAHSV(1, _h, _s, _v)),
  );

  static String _hexOf(HSVColor c) {
    final int v = c.toColor().toARGB32() & 0xFFFFFF;
    return '#${v.toRadixString(16).padLeft(6, '0')}';
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _syncHex() {
    _hex.text = _hexOf(HSVColor.fromAHSV(1, _h, _s, _v));
  }

  @override
  Widget build(BuildContext context) {
    final Color preview = HSVColor.fromAHSV(1, _h, _s, _v).toColor();
    return AlertDialog(
      title: const Text('添加颜色', style: TextStyle(fontSize: AppFontSize.bodyXl)),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: preview,
                borderRadius: BorderRadius.circular(AppRadius.frame),
              ),
            ),
            const SizedBox(height: 8),
            _slider('色相', _h, 360, (double v) {
              setState(() {
                _h = v;
                _syncHex();
              });
            }),
            _slider('饱和', _s, 1, (double v) {
              setState(() {
                _s = v;
                _syncHex();
              });
            }),
            _slider('明度', _v, 1, (double v) {
              setState(() {
                _v = v;
                _syncHex();
              });
            }),
            TextField(
              controller: _hex,
              decoration: const InputDecoration(
                labelText: '色值 #RRGGBB',
                isDense: true,
              ),
              onChanged: (String v) {
                final int? parsed = int.tryParse(
                  v.replaceFirst('#', ''),
                  radix: 16,
                );
                if (parsed == null || v.replaceFirst('#', '').length != 6) {
                  return;
                }
                // `0xFF000000 | parsed` 只是把用户输入的 24 位 RGB 强制补上不透明 alpha，
                // 并非「纯黑」——所以按 alpha 合成写，别再用 Color(0xFF000000 | …)，
                // 否则既被 §3.1 的禁纯黑规则误伤，也读不出真实意图。
                final HSVColor hsv = HSVColor.fromColor(
                  Color.from(
                    alpha: 1,
                    red: ((parsed >> 16) & 0xFF).toDouble(),
                    green: ((parsed >> 8) & 0xFF).toDouble(),
                    blue: (parsed & 0xFF).toDouble(),
                  ),
                );
                setState(() {
                  _h = hsv.hue;
                  _s = hsv.saturation;
                  _v = hsv.value;
                });
              },
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
          label: '添加',
          onPressed: () =>
              Navigator.pop(context, _hexOf(HSVColor.fromAHSV(1, _h, _s, _v))),
        ),
      ],
    );
  }

  Widget _slider(
    String label,
    double value,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 32,
          child: Text(
            label,
            style: const TextStyle(fontSize: AppFontSize.smallSm),
          ),
        ),
        Expanded(
          child: Slider(value: value, max: max, onChanged: onChanged),
        ),
      ],
    );
  }
}
