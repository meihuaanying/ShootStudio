/// 富文本轻量格式（F12）：**加粗** 与 - 无序列表，长图/PDF 双端一致渲染。
class RichTextLite {
  RichTextLite._();

  /// 解析为行；行内再拆分为粗体/常规片段。
  static List<RichLine> parse(String text) {
    final List<RichLine> lines = <RichLine>[];
    for (final String raw in text.split('\n')) {
      final String trimmed = raw.trimRight();
      final bool bullet = trimmed.startsWith('- ');
      final String body = bullet ? trimmed.substring(2) : trimmed;
      lines.add(RichLine(bullet: bullet, spans: _inline(body)));
    }
    return lines;
  }

  static List<RichSpan> _inline(String line) {
    final List<RichSpan> spans = <RichSpan>[];
    var rest = line;
    while (rest.isNotEmpty) {
      final int start = rest.indexOf('**');
      if (start < 0) {
        spans.add(RichSpan(rest, bold: false));
        break;
      }
      final int end = rest.indexOf('**', start + 2);
      if (end < 0) {
        spans.add(RichSpan(rest, bold: false));
        break;
      }
      if (start > 0) spans.add(RichSpan(rest.substring(0, start), bold: false));
      final String bold = rest.substring(start + 2, end);
      if (bold.isNotEmpty) spans.add(RichSpan(bold, bold: true));
      rest = rest.substring(end + 2);
    }
    if (spans.isEmpty) spans.add(const RichSpan('', bold: false));
    return spans;
  }

  /// 编辑器工具栏：对选区施加加粗。
  static ({String text, int selection}) toggleBold(
      String text, int selectionStart, int selectionEnd) {
    if (selectionStart == selectionEnd) {
      final String next = '$text**加粗文字**';
      return (
        text: next,
        selection: selectionStart + 2 + '加粗文字'.length,
      );
    }
    final String before = text.substring(0, selectionStart);
    final String selected = text.substring(selectionStart, selectionEnd);
    final String after = text.substring(selectionEnd);
    if (selected.startsWith('**') &&
        selected.endsWith('**') &&
        selected.length > 4) {
      final String plain = selected.substring(2, selected.length - 2);
      return (text: '$before$plain$after', selection: selectionEnd - 4);
    }
    return (
      text: '$before**$selected**$after',
      selection: selectionEnd + 4,
    );
  }

  /// 编辑器工具栏：把选中行转为无序列表（前缀 `- `）。
  static ({String text, int selection}) toggleBullet(
      String text, int selectionStart, int selectionEnd) {
    final int lineStart =
        text.lastIndexOf('\n', selectionStart > 0 ? selectionStart - 1 : 0) + 1;
    final int lineEnd = text.indexOf('\n', selectionEnd);
    final int end = lineEnd < 0 ? text.length : lineEnd;
    final String block = text.substring(lineStart, end);
    final bool allBullets = block
        .split('\n')
        .where((String l) => l.trim().isNotEmpty)
        .every((String l) => l.startsWith('- '));
    final String next = block
        .split('\n')
        .map((String l) => l.trim().isEmpty
            ? l
            : allBullets
                ? l.startsWith('- ')
                    ? l.substring(2)
                    : l
                : '- $l')
        .join('\n');
    final String updated =
        text.substring(0, lineStart) + next + text.substring(end);
    return (text: updated, selection: lineStart + next.length);
  }

  /// 去除标记的纯文本（用于测试与校字）。
  static String plain(String text) => parse(text)
      .map((RichLine l) => l.spans.map((RichSpan s) => s.text).join())
      .join('\n');
}

class RichLine {
  const RichLine({required this.bullet, required this.spans});
  final bool bullet;
  final List<RichSpan> spans;
}

class RichSpan {
  const RichSpan(this.text, {required this.bold});
  final String text;
  final bool bold;
}
