/// V8/D147 · S3：设计系统组件库 demo（§3.5 全量 16 项；R71/R72 证据载体）。
///
/// - 令牌唯一来源：`core/design/tokens.dart`（本文件不写任何硬编码色值/字号/间距）；
/// - 视觉门禁：`test/visual/s3_design_demo_capture_test.dart`（明暗 × 1280×800 / 1920×1080）；
/// - 入口：设置页「设计组件预览」（仅 debug 构建可见，合同 §6 L203）。
library;

import 'package:flutter/material.dart';

import '../core/design/widgets.dart';

void _demoNoop() {}

/// 组件预览板（无 Scaffold 包裹，供 demo 页与视觉门禁测试共用）。
class DesignDemoBoard extends StatelessWidget {
  const DesignDemoBoard({super.key, required this.variant});

  final AppThemeVariant variant;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final double margin = AppGrid.pageMargin(c.maxWidth);
        final double gap = AppSpace.s4;
        final int columns = c.maxWidth >= AppGrid.maxContentWidth * 2 ? 5 : 4;
        final double cellWidth =
            (c.maxWidth - margin * 2 - gap * (columns - 1)) / columns;
        return ColoredBox(
          color: p.bg,
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: margin,
              vertical: AppSpace.s5,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _header(p),
                const SizedBox(height: AppSpace.s5),
                Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: <Widget>[
                    for (final (String, Widget) cell in _cells(context))
                      SizedBox(
                        width: cellWidth,
                        child: _DemoCell(label: cell.$1, child: cell.$2),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _header(AppPalette p) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: <Widget>[
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SsEyebrow('V8/D147 · 设计系统 · S3'),
            const SizedBox(height: AppSpace.s1),
            Text('组件预览', style: AppType.h1.style(p.ink)),
          ],
        ),
      ),
      SsTag(label: variant.name, tone: SsTagTone.accent),
      const SizedBox(width: AppSpace.s2),
      const SsMonoBadge('§3.5 · 16'),
    ],
  );

  List<(String, Widget)> _cells(BuildContext context) => <(String, Widget)>[
    ('BUTTON · 四态', _buttons()),
    ('INPUT · 输入 / 搜索', const _InputCell()),
    ('CHIP · 标签', _chips()),
    ('CARD · 卡片', _cards()),
    ('TABS · 切页', _tabs()),
    ('EMPTY · 空态', _empty()),
    ('SKELETON · 骨架屏', _skeleton()),
    ('BANNER · 提示条', _banners()),
    ('TOAST · 轻提示', _toast(context)),
    ('TEXT · 眉题 / 分割', _texts(context.palette)),
    ('FRAME · 图片帧', _frames()),
    ('KV · 读数行', _kv(context.palette)),
    ('DIALOG · 对话框 / 抽屉', _dialog()),
    ('MOTION · 动效', _motion(context.palette)),
    ('FIELD · 表单行', _fields()),
    ('RULE · 圆角与阴影', _rules(context.palette)),
  ];

  Widget _buttons() => Wrap(
    spacing: AppSpace.s2,
    runSpacing: AppSpace.s2,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: <Widget>[
      SsButton(label: '主要', onPressed: _demoNoop, dense: true),
      SsButton(
        label: '描边',
        onPressed: _demoNoop,
        kind: SsButtonKind.outline,
        dense: true,
      ),
      SsButton(
        label: '文字',
        onPressed: _demoNoop,
        kind: SsButtonKind.text,
        dense: true,
      ),
      const SsIconButton(
        icon: Icons.photo_camera_outlined,
        onPressed: _demoNoop,
        tooltip: '图标按钮',
      ),
    ],
  );

  Widget _cards() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      const Expanded(
        child: SsDataCard(
          label: 'APERTURE',
          value: '1.4',
          unit: 'f',
          hint: '浅景深',
        ),
      ),
      const SizedBox(width: AppSpace.s2),
      SizedBox(
        width: 128,
        child: SsImageCard(
          title: '主光板',
          subtitle: 'KEY · 45°',
          ratio: SsFrameRatio.fourFive,
          onTap: _demoNoop,
        ),
      ),
    ],
  );

  Widget _chips() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Wrap(
        spacing: AppSpace.s2,
        children: <Widget>[
          SsChip(label: '全部', selected: true, onTap: _demoNoop),
          SsChip(label: '夜景', selected: false, onTap: _demoNoop),
          SsChip(label: '人像', selected: false, onTap: _demoNoop),
        ],
      ),
      const SizedBox(height: AppSpace.s2),
      const Wrap(
        spacing: AppSpace.s2,
        children: <Widget>[
          SsTag(label: 'NEUTRAL'),
          SsTag(label: 'ACCENT', tone: SsTagTone.accent),
          SsTag(label: 'POSITIVE', tone: SsTagTone.positive),
          SsTag(label: 'WARNING', tone: SsTagTone.warning),
          SsTag(label: 'DANGER', tone: SsTagTone.danger),
        ],
      ),
    ],
  );

  Widget _tabs() => SsTabs(
    labels: const <String>['画面', '灯光', '成案'],
    index: 1,
    onChanged: (int _) {},
  );

  Widget _empty() => SsEmpty(
    icon: Icons.photo_library_outlined,
    title: '还没有参考图',
    hint: '从素材库挑一张，或按需抓取影视静帧',
    action: SsButton(label: '导入图片', onPressed: _demoNoop, dense: true),
  );

  Widget _skeleton() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      const SsShimmer(height: 4, label: 'LOADING'),
      const SizedBox(height: AppSpace.s3),
      const SsSkeleton(height: 12),
      const SizedBox(height: AppSpace.s2),
      const Row(
        children: <Widget>[
          SsSkeleton(height: 10, width: 148),
          SizedBox(width: AppSpace.s2),
          SsSkeleton(height: 10, width: 96),
        ],
      ),
    ],
  );

  Widget _banners() => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      SsBanner(text: '已保存到工作区 images/plans', kind: SsBannerKind.success),
      SizedBox(height: AppSpace.s2),
      SsBanner(text: '模型未随包：将回退 MediaPipe 识别', kind: SsBannerKind.warning),
      SizedBox(height: AppSpace.s2),
      SsBannerLite(text: '离线可用 · 数据留在本机'),
    ],
  );

  Widget _toast(BuildContext context) => Row(
    children: <Widget>[
      SsButton(
        label: '触发 Toast',
        kind: SsButtonKind.outline,
        dense: true,
        onPressed: () =>
            ssToast(context, '已复制到剪贴板', kind: SsBannerKind.success),
      ),
      const SizedBox(width: AppSpace.s2),
      const SsTooltip(
        message: 'Ctrl+Z 撤销',
        child: SsIconButton(icon: Icons.undo, onPressed: _demoNoop),
      ),
    ],
  );

  Widget _texts(AppPalette p) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      const SsEyebrow('SECTION · 眉题'),
      const SizedBox(height: AppSpace.s2),
      Text('衬线区块标题', style: AppType.h3.style(p.ink)),
      Text('副标题 caption/muted', style: AppType.caption.style(p.muted)),
      const SizedBox(height: AppSpace.s2),
      const SsDivider(),
    ],
  );

  Widget _frames() => const Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: <Widget>[
      Expanded(child: SsImageFrame(ratio: SsFrameRatio.threeTwo, height: 74)),
      SizedBox(width: AppSpace.s2),
      Expanded(child: SsImageFrame(ratio: SsFrameRatio.fourFive, height: 74)),
      SizedBox(width: AppSpace.s2),
      Expanded(
        child: SsImageFrame(ratio: SsFrameRatio.sixteenNine, height: 74),
      ),
    ],
  );

  Widget _kv(AppPalette p) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      const SsKvRow(label: 'LIGHT', value: 'KEY 01 · 3 盏'),
      const SsKvRow(label: 'CAMERA', value: '35MM · F2 · 1/125'),
      const SizedBox(height: AppSpace.s2),
      Row(
        children: <Widget>[
          const SsMonoBadge('p95 17.8ms'),
          const SizedBox(width: AppSpace.s2),
          const SsTag(label: 'GPU', tone: SsTagTone.positive),
        ],
      ),
    ],
  );

  Widget _dialog() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      const _MiniPane(label: 'DIALOG', title: '导出策划案', hint: '含布光图、姿势清单与预算表。'),
      const SizedBox(height: AppSpace.s2),
      const _MiniPane(label: 'SHEET', title: '底部抽屉', hint: '上滑展开，不遮挡画布。'),
    ],
  );

  Widget _motion(AppPalette p) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      const SsFadeSwitch(index: 0, child: _MotionLabel()),
      const SizedBox(height: AppSpace.s3),
      SizedBox(
        height: 76,
        child: SsStaggeredList(
          itemCount: 3,
          itemBuilder: (BuildContext context, int i) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.s1),
            child: Text(
              '阶梯列表 ${i + 1} · 40ms',
              style: AppType.caption.style(p.inkSoft),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _fields() => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      SsFieldRow(label: '快门', child: Text('1/125')),
      SizedBox(height: AppSpace.s2),
      SsToggleRow(
        title: '软阴影',
        subtitle: 'VSM 高质量阴影（低配自动回退 PCF）',
        value: true,
        onChanged: _demoBool,
      ),
    ],
  );

  Widget _rules(AppPalette p) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      const Row(
        children: <Widget>[
          _RadiusSwatch(radius: 2, label: '2'),
          SizedBox(width: AppSpace.s1),
          _RadiusSwatch(radius: 4, label: '4'),
          SizedBox(width: AppSpace.s1),
          _RadiusSwatch(radius: 8, label: '8'),
          SizedBox(width: AppSpace.s3),
          _HairlineSwatch(),
          SizedBox(width: AppSpace.s2),
          _ShadowSwatch(paper: true),
          SizedBox(width: AppSpace.s2),
          _ShadowSwatch(paper: false),
        ],
      ),
      const SizedBox(height: AppSpace.s3),
      Row(
        children: <Widget>[
          _ColorDot(p.accent),
          _ColorDot(p.film),
          _ColorDot(p.gold),
          _ColorDot(p.danger),
          _ColorDot(p.ink),
          _ColorDot(p.muted),
        ],
      ),
    ],
  );
}

/// 输入框 + 搜索框。
class _InputCell extends StatelessWidget {
  const _InputCell();

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      SsTextInput(label: '项目名', initialValue: 'CITY-NIGHT', mono: true),
      SizedBox(height: AppSpace.s2),
      SsSearchField(hint: '搜索素材 / 器材 / 模板'),
    ],
  );
}

/// 组件预览页（设置页「设计组件预览」入口，仅 debug 构建可见）。
class DesignDemoPage extends StatelessWidget {
  const DesignDemoPage({super.key, this.variant = AppThemeVariant.paper});

  final AppThemeVariant variant;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('设计组件预览')),
    body: DesignDemoBoard(variant: variant),
  );
}

class _MotionLabel extends StatelessWidget {
  const _MotionLabel();

  @override
  Widget build(BuildContext context) => Text(
    '页面切换 200ms + 8px 上浮',
    style: AppType.small.style(context.palette.inkSoft),
  );
}

void _demoBool(bool _) {}

/// demo 单元格：mono 眉题 + 内容。
class _DemoCell extends StatelessWidget {
  const _DemoCell({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpace.s3),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: AppRadius.controlBorder,
        border: Border.all(color: p.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(label, style: appMono(p.muted, size: 10.5)),
          const SizedBox(height: AppSpace.s2),
          child,
        ],
      ),
    );
  }
}

/// 对话框 / 底部抽屉的静态缩略示意（真实弹层见 showSsConfirm / showSsSheet）。
class _MiniPane extends StatelessWidget {
  const _MiniPane({
    required this.label,
    required this.title,
    required this.hint,
  });

  final String label;
  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.s3),
      decoration: BoxDecoration(
        color: p.surfaceSunken,
        borderRadius: AppRadius.frameBorder,
        border: Border.all(color: p.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: appMono(p.accent, size: 10.5)),
          const SizedBox(height: AppSpace.s1),
          Text(title, style: AppType.h3.style(p.ink)),
          const SizedBox(height: AppSpace.s1),
          Text(hint, style: AppType.caption.style(p.inkSoft)),
          const SizedBox(height: AppSpace.s2),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: const <Widget>[
              SsButton(
                label: '取消',
                kind: SsButtonKind.text,
                dense: true,
                onPressed: _demoNoop,
              ),
              SizedBox(width: AppSpace.s2),
              SsButton(label: '确定', dense: true, onPressed: _demoNoop),
            ],
          ),
        ],
      ),
    );
  }
}

/// 圆角规范样块（§3.3 仅 2/4/8）。
class _RadiusSwatch extends StatelessWidget {
  const _RadiusSwatch({required this.radius, required this.label});

  final double radius;
  final String label;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: p.surfaceSunken,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: p.rule),
      ),
      child: Text(label, style: AppType.caption.style(p.muted)),
    );
  }
}

/// hairline 1px 样块。
class _HairlineSwatch extends StatelessWidget {
  const _HairlineSwatch();

  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    alignment: Alignment.centerLeft,
    child: Container(height: 1, color: context.palette.rule),
  );
}

/// 两级阴影样块。
class _ShadowSwatch extends StatelessWidget {
  const _ShadowSwatch({required this.paper});

  final bool paper;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return Container(
      width: 44,
      height: 30,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: AppRadius.controlBorder,
        border: Border.all(color: p.rule),
        boxShadow: paper ? appShadowPaper(p.ink) : appShadowOverlay(p.ink),
      ),
    );
  }
}

/// 语义色点。
class _ColorDot extends StatelessWidget {
  const _ColorDot(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: AppSpace.s2),
    child: Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppRadius.chipBorder,
        border: Border.all(color: context.palette.rule),
      ),
    ),
  );
}
