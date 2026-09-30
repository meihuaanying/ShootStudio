import 'package:flutter/material.dart';

import '../../core/design/widgets.dart';
import '../../services/search/theme_packs.dart';

/// S5/D154 首屏（杂志画册风）：居中检索 + 8 个常用主题**画报**（图卡，不是文字 chip）。
///
/// 视觉纪律（R71/R82）：只用设计令牌；主题卡是「图」优先的版面块（surfaceSunken + 衬线首字占位），
/// 不使用 emoji / 彩色渐变方块（旧首屏的横向文字 chip 形态已废弃）。
class RefsHomeHeader extends StatelessWidget {
  const RefsHomeHeader({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.searching,
    required this.status,
    required this.vision,
    required this.onSearch,
    required this.onPickTheme,
    required this.onAllThemes,
    required this.onSearchByImage,
    required this.onPaste,
    required this.onImport,
    this.compact = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool searching;
  final String status;
  final String vision;
  final VoidCallback onSearch;
  final ValueChanged<ThemePack> onPickTheme;
  final VoidCallback onAllThemes;
  final VoidCallback onSearchByImage;
  final VoidCallback onPaste;
  final VoidCallback onImport;

  /// 有结果时收起首屏大标题与 132px 画报墙，改为检索条 + 单行画报 chip，
  /// 把纵向空间让给瀑布流（1280×800 下结果不再被挤出视口）。
  final bool compact;

  /// 首屏常用主题（D120 的 8 个常用包）。
  static List<ThemePack> featured() => commonThemePacks();

  Widget _searchRow(AppPalette p) {
    return Row(
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            textInputAction: TextInputAction.search,
            onSubmitted: (String _) => onSearch(),
            decoration: const InputDecoration(
              hintText: '搜影片 / 导演 / 演员 / 画作 / 摄影主题（中英文均可）',
              isDense: true,
              prefixIcon: Icon(Icons.search_rounded, size: 18),
            ),
          ),
        ),
        const SizedBox(width: AppSpace.s2),
        SsButton(
          label: searching ? '检索中…' : '搜索',
          onPressed: searching ? null : onSearch,
        ),
      ],
    );
  }

  Widget _toolRow(AppPalette p, {bool centered = true}) {
    return Row(
      mainAxisAlignment: centered
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: <Widget>[
        SsButton(
          label: '以图搜图',
          kind: SsButtonKind.text,
          dense: true,
          icon: Icons.image_search_rounded,
          onPressed: searching ? null : onSearchByImage,
        ),
        const SizedBox(width: AppSpace.s1),
        SsButton(
          label: '粘贴截图',
          kind: SsButtonKind.text,
          dense: true,
          icon: Icons.content_paste_rounded,
          onPressed: onPaste,
        ),
        const SizedBox(width: AppSpace.s1),
        SsButton(
          label: '本地导入',
          kind: SsButtonKind.text,
          dense: true,
          icon: Icons.add_photo_alternate_outlined,
          onPressed: onImport,
        ),
      ],
    );
  }

  Widget _statusLines(AppPalette p, {bool centered = false}) {
    final List<Widget> out = <Widget>[];
    if (vision.isNotEmpty) {
      out.add(
        Padding(
          padding: const EdgeInsets.only(top: AppSpace.s2),
          child: Text('AI 视觉关键词：$vision', style: appMono(p.accent, size: 10.5)),
        ),
      );
    }
    if (status.isNotEmpty) {
      out.add(
        Padding(
          padding: const EdgeInsets.only(top: AppSpace.s1),
          child: Text(
            status,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: appMono(p.muted, size: 10.5),
          ),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: out);
  }

  Widget _themeHeader(AppPalette p) {
    return Row(
      children: <Widget>[
        Text('常用画报', style: AppType.h3.style(p.ink)),
        const SizedBox(width: AppSpace.s2),
        const Expanded(child: SsDivider()),
        const SizedBox(width: AppSpace.s2),
        SsButton(
          label: '全部 48 个主题',
          kind: SsButtonKind.text,
          dense: true,
          onPressed: onAllThemes,
        ),
      ],
    );
  }

  /// 单行小 chip（紧凑模式）：衬线首字 + 名称，保留主题入口但不占版面。
  Widget _themeChip(AppPalette p, ThemePack pack) {
    return Semantics(
      button: true,
      label: '主题画报 ${pack.name}',
      child: InkWell(
        onTap: () => onPickTheme(pack),
        borderRadius: AppRadius.chipBorder,
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s2),
          decoration: BoxDecoration(
            color: p.surfaceSunken,
            border: Border.all(color: p.rule),
            borderRadius: AppRadius.chipBorder,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(pack.name.characters.first, style: AppType.h3.style(p.rule)),
              const SizedBox(width: AppSpace.s1),
              Text(pack.name, style: AppType.small.style(p.ink)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _compactBody(AppPalette p) {
    final List<ThemePack> packs = featured();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _searchRow(p),
        const SizedBox(height: AppSpace.s2),
        _toolRow(p, centered: false),
        _statusLines(p),
        const SizedBox(height: AppSpace.s3),
        _themeHeader(p),
        const SizedBox(height: AppSpace.s2),
        SizedBox(
          height: 30,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: packs.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpace.s2),
            itemBuilder: (BuildContext context, int i) =>
                _themeChip(p, packs[i]),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    if (compact) return _compactBody(p);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Text('REFERENCE · 画面参考', style: appEyebrow(p.accent)),
                const SizedBox(height: AppSpace.s2),
                Text(
                  '找一张对味的参考，再决定怎么拍。',
                  textAlign: TextAlign.center,
                  style: AppType.h1.style(p.ink),
                ),
                const SizedBox(height: AppSpace.s2),
                Text(
                  '13 个开放图源聚合影视静帧 / 画作 / 摄影；逐图标注来源与许可。',
                  textAlign: TextAlign.center,
                  style: AppType.small.style(p.muted),
                ),
                const SizedBox(height: AppSpace.s4),
                _searchRow(p),
                const SizedBox(height: AppSpace.s2),
                _toolRow(p),
                _statusLines(p, centered: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpace.s5),
        _themeHeader(p),
        const SizedBox(height: AppSpace.s3),
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: featured().length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpace.s3),
            itemBuilder: (BuildContext context, int i) {
              final ThemePack pack = featured()[i];
              return RefsThemeCard(pack: pack, onTap: () => onPickTheme(pack));
            },
          ),
        ),
      ],
    );
  }
}

/// 主题画报卡（D154：图卡而非文字 chip）：3:2 版面块 + 衬线首字占位 + mono id。
class RefsThemeCard extends StatelessWidget {
  const RefsThemeCard({super.key, required this.pack, required this.onTap});

  final ThemePack pack;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return Semantics(
      button: true,
      label: '主题画报 ${pack.name}',
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.frameBorder,
        child: SizedBox(
          width: 208,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                height: 84,
                width: 208,
                decoration: BoxDecoration(
                  color: p.surfaceSunken,
                  border: Border.all(color: p.rule),
                  borderRadius: AppRadius.frameBorder,
                ),
                alignment: Alignment.center,
                child: Text(
                  pack.name.characters.first,
                  style: AppType.h1.style(p.rule),
                ),
              ),
              const SizedBox(height: AppSpace.s1),
              Text(
                pack.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.small.style(p.ink),
              ),
              Text(
                pack.id,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: appMono(p.muted, size: 9.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
