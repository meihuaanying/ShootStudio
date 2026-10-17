/// V8/D147 · S3：输入框 / 搜索框 / 表单行（§3.5）。
/// 令牌唯一来源：core/design/tokens.dart（R71）。
library;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// 单行输入框（hairline 边框 + 4 圆角 + 标签）。
///
/// V8.14/C2：为「裸 `TextField(` → sanctioned 输入件」的迁移补齐透传能力。
/// 新增参数（`onSubmitted` / `maxLines` / `minLines` / `maxLength` /
/// `keyboardType` / `textInputAction` / `focusNode` / `dense`）的默认值与
/// `TextField` / `InputDecoration` 的默认值一致，故对既有调用方行为零变更；
/// `label` 由 `required` 放宽为可选，同样是源兼容（原来传 label 的照常工作）。
///
/// V8.20/C2：再补 `prefix` / `enabled` / `style` 三个透传（C2 收口批）。
/// 默认值同样对齐原生默认（`prefix = null`、`enabled = true`（等于
/// `InputDecoration.enabled` 的原生默认）、`style = null` → 沿用 `mono`/正文
/// 逻辑），故对既有调用方仍是行为零变更。
class SsTextInput extends StatefulWidget {
  const SsTextInput({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.initialValue,
    this.onChanged,
    this.onSubmitted,
    this.obscure = false,
    this.mono = false,
    this.prefix,
    this.suffix,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.keyboardType,
    this.textInputAction,
    this.focusNode,
    this.dense = false,
    this.enabled = true,
    this.style,
  });

  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool obscure;
  final bool mono;
  final Widget? prefix;
  final Widget? suffix;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final bool dense;

  /// 透传 `InputDecoration.enabled`（原生默认即 `true`）。
  final bool enabled;

  /// 覆盖默认正文样式；`null` → 沿用 `mono`/正文逻辑。
  final TextStyle? style;

  @override
  State<SsTextInput> createState() => _SsTextInputState();
}

class _SsTextInputState extends State<SsTextInput> {
  /// `initialValue` 的兜底 controller。
  ///
  /// 修掉一个真缺陷：该参数此前被声明但 `build()` 里**完全没用到**，于是
  /// `SsTextInput(label: '项目名', initialValue: 'CITY-NIGHT')` 会渲染出一个空框
  /// （静默失效，`TextField` 本身没有 `initialValue`）。要让它生效就必须有个
  /// controller，所以本组件由 `StatelessWidget` 改为 `StatefulWidget`：
  /// 仅在调用方**未提供** `controller` 时自建一个，并在 `dispose()` 释放。
  TextEditingController? _own;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null && widget.initialValue != null) {
      _own = TextEditingController(text: widget.initialValue);
    }
  }

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return TextField(
      controller: widget.controller ?? _own,
      focusNode: widget.focusNode,
      obscureText: widget.obscure,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      maxLength: widget.maxLength,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      style:
          widget.style ??
          (widget.mono
              ? appMono(p.ink, size: 12.5)
              : AppType.body.style(p.ink)),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        prefixIcon: widget.prefix,
        suffixIcon: widget.suffix,
        isDense: widget.dense,
        enabled: widget.enabled,
        hintStyle: widget.mono
            ? appMono(p.muted, size: 12.5)
            : AppType.body.style(p.muted),
      ),
    );
  }
}

/// 搜索框（前置放大镜 + 可清空）。
class SsSearchField extends StatelessWidget {
  const SsSearchField({
    super.key,
    required this.hint,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
  });

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: AppType.body.style(p.ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppType.body.style(p.muted),
        prefixIcon: Icon(Icons.search_rounded, size: 18, color: p.muted),
        suffixIcon: controller == null
            ? null
            : IconButton(
                tooltip: '清空',
                icon: Icon(Icons.close_rounded, size: 16, color: p.muted),
                onPressed: onClear,
              ),
      ),
    );
  }
}

/// 表单行：等宽标签列 + 控件列 + 可选复制/提示。
class SsFieldRow extends StatelessWidget {
  const SsFieldRow({
    super.key,
    required this.label,
    required this.child,
    this.hint,
    this.copy,
  });

  final String label;
  final Widget child;
  final String? hint;
  final VoidCallback? copy;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 84,
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpace.s3),
              child: Row(
                children: <Widget>[
                  Text(label, style: AppType.small.style(p.inkSoft)),
                  if (copy != null)
                    InkWell(
                      onTap: copy,
                      child: Padding(
                        padding: const EdgeInsets.only(left: AppSpace.s1),
                        child: Icon(
                          Icons.copy_rounded,
                          size: 12,
                          color: p.muted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(child: child),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpace.s2,
                top: AppSpace.s3,
              ),
              child: Text(hint!, style: AppType.caption.style(p.muted)),
            ),
        ],
      ),
    );
  }
}

/// 设置开关行。
class SsToggleRow extends StatelessWidget {
  const SsToggleRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: AppType.body.style(p.ink)),
                if (subtitle != null)
                  Text(subtitle!, style: AppType.caption.style(p.muted)),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
