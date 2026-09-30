/// V8/D147 · S3：页签切换动效（§3.4「200ms 淡入 + 8px 上浮」，保持子页状态）。
/// 令牌唯一来源：core/design/tokens.dart（R71）。
library;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// 页签切换淡入 + 上浮：只重放透明度/位移，不重建子页（保状态）。
class SsFadeSwitch extends StatefulWidget {
  const SsFadeSwitch({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<SsFadeSwitch> createState() => _SsFadeSwitchState();
}

class _SsFadeSwitchState extends State<SsFadeSwitch>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.page,
    value: 1,
  );

  @override
  void didUpdateWidget(covariant SsFadeSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> curved = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.curve,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: AppMotion.pageRise,
          end: Offset.zero,
        ).animate(curved),
        child: widget.child,
      ),
    );
  }
}

/// 列表入场阶梯延迟（§3.4：逐项 40ms，≤12 项）。
class SsStaggeredList extends StatelessWidget {
  const SsStaggeredList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.step = 40,
    this.maxStaggered = 12,
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final int step;
  final int maxStaggered;

  @override
  Widget build(BuildContext context) => ListView.builder(
    padding: EdgeInsets.zero,
    itemCount: itemCount,
    itemBuilder: (BuildContext context, int index) => _SsStaggeredItem(
      delayMs: step * (index < maxStaggered ? index : maxStaggered),
      child: itemBuilder(context, index),
    ),
  );
}

class _SsStaggeredItem extends StatefulWidget {
  const _SsStaggeredItem({required this.delayMs, required this.child});

  final int delayMs;
  final Widget child;

  @override
  State<_SsStaggeredItem> createState() => _SsStaggeredItemState();
}

class _SsStaggeredItemState extends State<_SsStaggeredItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.page,
  );

  @override
  void initState() {
    super.initState();
    if (widget.delayMs <= 0) {
      _controller.value = 1;
    } else {
      Future<void>.delayed(Duration(milliseconds: widget.delayMs), () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> curved = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.curve,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: AppMotion.pageRise,
          end: Offset.zero,
        ).animate(curved),
        child: widget.child,
      ),
    );
  }
}
