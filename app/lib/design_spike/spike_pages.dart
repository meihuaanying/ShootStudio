/// V8/D146 · S1 设计 spike：样板页（App 首页 / 布光页）
///
/// 全部颜色/字号/间距/圆角/动效只引用 `spike_tokens.dart`（R71）；
/// 布局按 §3.3 栅格（最大宽 1280、12 列、列间距 24、页边距 32/24）与
/// §4.1 布光信息架构（左清单 / 中视口 / 右属性检查器）。
library;

import 'package:flutter/material.dart';

import 'spike_tokens.dart';

/// 页面尺寸档（R72 视觉门禁）
enum SpikeViewport {
  md(1280, 800),
  lg(1920, 1080);

  const SpikeViewport(this.width, this.height);

  final double width;
  final double height;
}

Widget spikeHomePage(
  SpikeThemeMode mode, {
  SpikeViewport viewport = SpikeViewport.md,
}) {
  return _SpikeScaffold(
    mode: mode,
    viewport: viewport,
    title: '首页 · 杂志式大图流',
    child: _HomeContent(mode: mode, viewport: viewport),
  );
}

Widget spikeLightingPage(
  SpikeThemeMode mode, {
  SpikeViewport viewport = SpikeViewport.md,
}) {
  return _SpikeScaffold(
    mode: mode,
    viewport: viewport,
    title: '布光预演 · 左清单 / 中视口 / 右检查器',
    child: _LightingContent(mode: mode, viewport: viewport),
  );
}

// ---------------------------------------------------------------------------
// 基础构件（spike 版，S3 迁入 lib/core/design/）
// ---------------------------------------------------------------------------

class _SpikeScaffold extends StatelessWidget {
  const _SpikeScaffold({
    required this.mode,
    required this.viewport,
    required this.title,
    required this.child,
  });

  final SpikeThemeMode mode;
  final SpikeViewport viewport;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final SpikePalette p = spikePaletteOf(mode);
    return Theme(
      data: spikeTheme(mode),
      child: Material(
        color: p.bg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _TopBar(palette: p, title: title),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: SpikeGrid.maxContentWidth,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: SpikeGrid.pageMargin(viewport.width),
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required SpikePalette palette, required this.title})
    : p = palette;

  final SpikePalette p;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: SpikeSpace.s7,
      padding: const EdgeInsets.symmetric(horizontal: SpikeSpace.s5),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.rule)),
        color: p.surface,
      ),
      child: Row(
        children: <Widget>[
          Text(
            'SHOOTSTUDIO',
            style: spikeEyebrow(p.accent).copyWith(letterSpacing: 2.4),
          ),
          const SizedBox(width: SpikeSpace.s5),
          Container(width: 1, height: SpikeSpace.s4, color: p.rule),
          const SizedBox(width: SpikeSpace.s5),
          Text(
            title,
            style: SpikeType.caption.style(p.inkSoft, font: SpikeFonts.body),
          ),
          const Spacer(),
          _GhostButton(palette: p, label: '组件预览'),
          const SizedBox(width: SpikeSpace.s2),
          _PrimaryButton(palette: p, label: '开始策划'),
        ],
      ),
    );
  }
}

/// Eyebrow + hairline 区块眉题（§3.5）
class _SectionEyebrow extends StatelessWidget {
  const _SectionEyebrow({required SpikePalette palette, required this.text})
    : p = palette;

  final SpikePalette p;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Text(text.toUpperCase(), style: spikeEyebrow(p.muted)),
        const SizedBox(width: SpikeSpace.s3),
        Expanded(child: Container(height: 1, color: p.rule)),
      ],
    );
  }
}

/// 图片帧（§3.5/§3.6：surfaceSunken 底 + hairline + 比例锁；无图用衬线首字占位）
class _ImageFrame extends StatelessWidget {
  const _ImageFrame({
    required SpikePalette palette,
    required this.ratio,
    this.placeholder = '样',
    this.caption,
    this.height,
  }) : p = palette;

  final SpikePalette p;
  final double ratio;
  final String placeholder;
  final String? caption;
  final double? height;

  @override
  Widget build(BuildContext context) {
    // height 给定时按限高铺满（首页 hero 需在 800px 首屏内收口），
    // 否则按比例锁推导高度。
    final Widget box = Container(
      height: height,
      decoration: BoxDecoration(
        color: p.surfaceSunken,
        border: Border.all(color: p.rule),
        borderRadius: BorderRadius.circular(SpikeRadius.frame),
      ),
      alignment: Alignment.center,
      child: Text(
        placeholder,
        style: SpikeType.h1.style(p.muted, font: SpikeFonts.display),
      ),
    );
    final Widget frame = height == null
        ? AspectRatio(aspectRatio: ratio, child: box)
        : box;
    if (caption == null) {
      return frame;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        frame,
        const SizedBox(height: SpikeSpace.s2),
        Text(caption!, style: SpikeType.caption.style(p.muted)),
      ],
    );
  }
}

/// KV 读数行（§3.5：mono 数据 + muted 标签）
class _KvRow extends StatelessWidget {
  const _KvRow({
    required SpikePalette palette,
    required this.label,
    required this.value,
  }) : p = palette;

  final SpikePalette p;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SpikeSpace.s1),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 96,
            child: Text(label, style: SpikeType.caption.style(p.muted)),
          ),
          Text(
            value,
            style: SpikeType.small.style(
              p.ink,
              font: SpikeFonts.mono,
              weight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required SpikePalette palette,
    required this.label,
    this.selected = false,
  }) : p = palette;

  final SpikePalette p;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpikeSpace.s2,
        vertical: SpikeSpace.s1,
      ),
      decoration: BoxDecoration(
        color: selected ? p.accentSoft : Colors.transparent,
        border: Border.all(color: selected ? p.accent : p.rule),
        borderRadius: BorderRadius.circular(SpikeRadius.chip),
      ),
      child: Text(
        label,
        style: SpikeType.caption.style(selected ? p.accent : p.inkSoft),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required SpikePalette palette,
    required this.label,
    this.icon,
  }) : p = palette;

  final SpikePalette p;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: SpikeSpace.s4),
      decoration: BoxDecoration(
        color: p.accent,
        borderRadius: BorderRadius.circular(SpikeRadius.control),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 16, color: p.surface),
            const SizedBox(width: SpikeSpace.s2),
          ],
          Text(
            label,
            style: SpikeType.small.style(p.surface, weight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({required SpikePalette palette, required this.label})
    : p = palette;

  final SpikePalette p;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: SpikeSpace.s4),
      decoration: BoxDecoration(
        border: Border.all(color: p.rule),
        borderRadius: BorderRadius.circular(SpikeRadius.control),
      ),
      alignment: Alignment.center,
      child: Text(label, style: SpikeType.small.style(p.inkSoft)),
    );
  }
}

// ---------------------------------------------------------------------------
// 首页样板：7+5 不对称跨页
// ---------------------------------------------------------------------------

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.mode, required this.viewport});

  final SpikeThemeMode mode;
  final SpikeViewport viewport;

  @override
  Widget build(BuildContext context) {
    final SpikePalette p = spikePaletteOf(mode);
    final double content =
        SpikeGrid.maxContentWidth - SpikeGrid.pageMargin(viewport.width) * 2;
    final double left = SpikeGrid.span(content, 7);
    final double right = SpikeGrid.span(content, 5);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: SpikeSpace.s5, bottom: SpikeSpace.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('ISSUE 01 · FW26', style: spikeEyebrow(p.accent)),
                    const SizedBox(height: SpikeSpace.s3),
                    Text('把光放对，\n再把人说活', style: SpikeType.display.style(p.ink)),
                    const SizedBox(height: SpikeSpace.s3),
                    SizedBox(
                      width: SpikeGrid.span(content, 5),
                      child: Text(
                        '摄影正片工作台：布光预演、动作摆姿、画面参考与成案导出，'
                        '一套设计令牌贯穿桌面端与官网。',
                        style: SpikeType.body.style(
                          p.inkSoft,
                          font: SpikeFonts.body,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: SpikeGrid.gutter),
              SizedBox(
                width: right,
                child: _ImageFrame(
                  palette: p,
                  ratio: SpikeFrameRatio.fourFive,
                  placeholder: '光',
                  height: 420,
                ),
              ),
            ],
          ),
          const SizedBox(height: SpikeSpace.s6),
          _SectionEyebrow(palette: p, text: 'FEATURE · EDITORIAL'),
          const SizedBox(height: SpikeSpace.s4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: left,
                child: _ImageFrame(
                  palette: p,
                  ratio: SpikeFrameRatio.threeTwo,
                  placeholder: '势',
                  caption: '图卡 · 3:2 比例锁 · surfaceSunken 底 + hairline',
                ),
              ),
              SizedBox(width: SpikeGrid.gutter),
              SizedBox(
                width: right,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _KvRow(palette: p, label: '引擎', value: 'three.js r186'),
                    _KvRow(
                      palette: p,
                      label: '静帧',
                      value: 'path tracing 480×360×48',
                    ),
                    _KvRow(
                      palette: p,
                      label: '识别',
                      value: 'RTMW3D-x fp16 · CPU',
                    ),
                    _KvRow(palette: p, label: '体积', value: 'APK 412.0MB'),
                    const SizedBox(height: SpikeSpace.s4),
                    Wrap(
                      spacing: SpikeSpace.s2,
                      runSpacing: SpikeSpace.s2,
                      children: <Widget>[
                        _Chip(
                          palette: p,
                          label: '纸面亮',
                          selected: mode == SpikeThemeMode.paper,
                        ),
                        _Chip(
                          palette: p,
                          label: '暗房暗',
                          selected: mode == SpikeThemeMode.darkroom,
                        ),
                        _TokenDot(palette: p, color: p.accent, label: '印相红'),
                        _TokenDot(palette: p, color: p.film, label: '胶片绿'),
                        _TokenDot(palette: p, color: p.gold, label: '暖金'),
                        _TokenDot(palette: p, color: p.danger, label: '错误'),
                      ],
                    ),
                    const SizedBox(height: SpikeSpace.s5),
                    _PrimaryButton(palette: p, label: '新建正片', icon: Icons.add),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: SpikeSpace.s6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: right,
                child: _ImageFrame(
                  palette: p,
                  ratio: SpikeFrameRatio.sixteenNine,
                  placeholder: '参',
                ),
              ),
              SizedBox(width: SpikeGrid.gutter),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _SectionEyebrow(palette: p, text: 'RECENT'),
                    const SizedBox(height: SpikeSpace.s3),
                    Text(
                      '空白态用衬线大字 + 一行指引 + 主行动',
                      style: SpikeType.h3.style(p.ink),
                    ),
                    const SizedBox(height: SpikeSpace.s2),
                    Text(
                      '无图时用 surfaceSunken + 衬线首字占位，禁止 emoji 与灰块。',
                      style: SpikeType.body.style(
                        p.inkSoft,
                        font: SpikeFonts.body,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 色板读数（spike 评审用：色块 + 令牌名）
class _TokenDot extends StatelessWidget {
  const _TokenDot({
    required SpikePalette palette,
    required this.color,
    required this.label,
  }) : p = palette;

  final SpikePalette p;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpikeSpace.s2,
        vertical: SpikeSpace.s1,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: p.rule),
        borderRadius: BorderRadius.circular(SpikeRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: SpikeSpace.s1),
          Text(label, style: SpikeType.caption.style(p.inkSoft)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 布光页样板：左清单 / 中视口 / 右属性检查器（§4.1）
// ---------------------------------------------------------------------------

class _LightingContent extends StatelessWidget {
  const _LightingContent({required this.mode, required this.viewport});

  final SpikeThemeMode mode;
  final SpikeViewport viewport;

  @override
  Widget build(BuildContext context) {
    final SpikePalette p = spikePaletteOf(mode);
    final double content =
        SpikeGrid.maxContentWidth - SpikeGrid.pageMargin(viewport.width) * 2;
    final double list = SpikeGrid.span(content, 2);
    final double inspector = SpikeGrid.span(content, 3);
    final double viewportWidth =
        content - list - inspector - SpikeGrid.gutter * 2;

    return Padding(
      padding: const EdgeInsets.only(top: SpikeSpace.s4, bottom: SpikeSpace.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _DeviceList(palette: p, width: list),
          const SizedBox(width: SpikeGrid.gutter),
          _ViewportPanel(palette: p, width: viewportWidth, viewport: viewport),
          const SizedBox(width: SpikeGrid.gutter),
          _Inspector(palette: p, width: inspector),
        ],
      ),
    );
  }
}

class _DeviceList extends StatelessWidget {
  const _DeviceList({required SpikePalette palette, required this.width})
    : p = palette;

  final SpikePalette p;
  final double width;

  static const List<(String, String)> _devices = <(String, String)>[
    ('主光', 'Aputure 600d'),
    ('辅光', '南冠 RX60'),
    ('轮廓光', '神牛 ML60Bi'),
    ('道具', '柔光伞 1'),
    ('背景', '灰卡 2m'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.rule),
        borderRadius: BorderRadius.circular(SpikeRadius.control),
      ),
      padding: const EdgeInsets.all(SpikeSpace.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _SectionEyebrow(palette: p, text: 'GEAR'),
          const SizedBox(height: SpikeSpace.s3),
          for (final (String role, String model) in _devices)
            Padding(
              padding: const EdgeInsets.only(bottom: SpikeSpace.s2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(role, style: SpikeType.caption.style(p.muted)),
                  Text(
                    model,
                    style: SpikeType.small.style(p.ink, font: SpikeFonts.body),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ViewportPanel extends StatelessWidget {
  const _ViewportPanel({
    required SpikePalette palette,
    required this.width,
    required this.viewport,
  }) : p = palette;

  final SpikePalette p;
  final double width;
  final SpikeViewport viewport;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: SpikeSpace.s3),
            decoration: BoxDecoration(
              color: p.surface,
              border: Border.all(color: p.rule),
              borderRadius: BorderRadius.circular(SpikeRadius.control),
            ),
            child: Row(
              children: <Widget>[
                Text('看构图', style: SpikeType.caption.style(p.ink)),
                const SizedBox(width: SpikeSpace.s4),
                Text(
                  '85mm',
                  style: SpikeType.caption.style(
                    p.inkSoft,
                    font: SpikeFonts.mono,
                  ),
                ),
                const SizedBox(width: SpikeSpace.s4),
                Text(
                  'f/2.8',
                  style: SpikeType.caption.style(
                    p.inkSoft,
                    font: SpikeFonts.mono,
                  ),
                ),
                const Spacer(),
                _Chip(palette: p, label: '构图辅助', selected: true),
                const SizedBox(width: SpikeSpace.s2),
                _Chip(palette: p, label: 'VSM'),
                const SizedBox(width: SpikeSpace.s2),
                _Chip(palette: p, label: '路径追踪'),
              ],
            ),
          ),
          const SizedBox(height: SpikeSpace.s2),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: p.surfaceSunken,
                border: Border.all(color: p.rule),
                borderRadius: BorderRadius.circular(SpikeRadius.frame),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text('3D 视口', style: SpikeType.h2.style(p.muted)),
                  const SizedBox(height: SpikeSpace.s2),
                  Text(
                    '≥60% 宽 · 灯位拖拽实时预览 · 俯视灯位图为画中画',
                    style: SpikeType.caption.style(p.muted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: SpikeSpace.s2),
          Row(
            children: <Widget>[
              _PrimaryButton(
                palette: p,
                label: '出片（1/3）',
                icon: Icons.camera_alt_outlined,
              ),
              const SizedBox(width: SpikeSpace.s2),
              _GhostButton(palette: p, label: 'A/B 对比'),
              const Spacer(),
              Text(
                'P95 12.4MS',
                style: SpikeType.caption.style(
                  p.inkSoft,
                  font: SpikeFonts.mono,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Inspector extends StatelessWidget {
  const _Inspector({required SpikePalette palette, required this.width})
    : p = palette;

  final SpikePalette p;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.rule),
        borderRadius: BorderRadius.circular(SpikeRadius.control),
      ),
      padding: const EdgeInsets.all(SpikeSpace.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _SectionEyebrow(palette: p, text: 'KEY · KEY LIGHT'),
          const SizedBox(height: SpikeSpace.s3),
          _KvRow(palette: p, label: '灯具', value: 'cob-600d'),
          _KvRow(palette: p, label: '控光件', value: 'softbox-medium'),
          _KvRow(palette: p, label: '强度', value: '82'),
          _KvRow(palette: p, label: '色温', value: '5600K'),
          _KvRow(palette: p, label: '光束角', value: '55°'),
          const SizedBox(height: SpikeSpace.s3),
          Container(height: 1, color: p.rule),
          const SizedBox(height: SpikeSpace.s3),
          _KvRow(palette: p, label: 'EV', value: '+1.3'),
          _KvRow(palette: p, label: '距离', value: '2.40m'),
          const Spacer(),
          Row(
            children: <Widget>[
              _GhostButton(palette: p, label: '重置'),
              const SizedBox(width: SpikeSpace.s2),
              _GhostButton(palette: p, label: '复制'),
              const Spacer(),
              Text(
                'Ctrl+Z · Ctrl+Shift+Z',
                style: SpikeType.caption.style(p.muted, font: SpikeFonts.mono),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
