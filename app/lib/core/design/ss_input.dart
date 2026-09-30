/// V8/D147 · S3：输入框 / 搜索框 / 表单行（§3.5）。
/// 令牌唯一来源：core/design/tokens.dart（R71）。
library;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// 单行输入框（hairline 边框 + 4 圆角 + 标签）。
class SsTextInput extends StatelessWidget {
  const SsTextInput({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.initialValue,
    this.onChanged,
    this.obscure = false,
    this.mono = false,
    this.suffix,
  });

  final String label;
  final String? hint;
  final TextEditingController? controller;
  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final bool obscure;
  final bool mono;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return TextField(
      controller: controller,
      obscureText: obscure,
      onChanged: onChanged,
      style: mono ? appMono(p.ink, size: 12.5) : AppType.body.style(p.ink),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffix,
        hintStyle: mono
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
