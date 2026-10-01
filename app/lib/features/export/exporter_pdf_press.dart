// V8/S8 · D155：PDF 印版部件（页眉 / 页脚 / 来源与许可附录 / 署名收集 / 省略号）。
// 从 exporter_pdf.dart 拆出，使两个文件都 ≤600 行（R73 行数门禁）。
// 注：这里的 static 方法通过 _ExporterPdfPress.<名> 限定调用。
part of 'exporter.dart';

extension _ExporterPdfPress on ExportService {
  pw.Widget _pdfRunningHead(
    pw.TextStyle base,
    String title, {
    required PlanDocStatus status,
  }) => pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 10),
    padding: const pw.EdgeInsets.only(bottom: 6),
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(color: pdfx.PdfColors.grey400, width: 0.6),
      ),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: <pw.Widget>[
        pw.Text(
          '正片工坊 SHOOTSTUDIO',
          style: base.copyWith(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            _ellipsis(title, 28),
            textAlign: pw.TextAlign.right,
            style: base.copyWith(fontSize: 9, color: pdfx.PdfColors.grey700),
          ),
        ),
      ],
    ),
  );

  /// D155：页脚——上方 hairline，左侧版本/状态说明，右侧「第 N / M 页」。
  pw.Widget _pdfRunningFoot(
    pw.TextStyle base,
    int page, {
    required int total,
  }) => pw.Container(
    margin: const pw.EdgeInsets.only(top: 10),
    padding: const pw.EdgeInsets.only(top: 6),
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        top: pw.BorderSide(color: pdfx.PdfColors.grey400, width: 0.6),
      ),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: <pw.Widget>[
        pw.Text(
          '状态：${PlanDocStatus.draft.label} · 导出自 ShootStudio',
          style: base.copyWith(fontSize: 8, color: pdfx.PdfColors.grey600),
        ),
        pw.Text(
          '第 $page / $total 页',
          style: base.copyWith(fontSize: 8, color: pdfx.PdfColors.grey600),
        ),
      ],
    ),
  );

  /// D155：附录——来源 / 许可清单（hairline 表格，字段不丢）。
  pw.Widget _pdfAttributionAppendix(
    pw.TextStyle base,
    List<(String, String)> rows,
  ) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: <pw.Widget>[
      pw.SizedBox(height: 18),
      pw.Text(
        '来源 / 许可',
        style: base.copyWith(fontSize: 13, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 6),
      pw.Container(height: 0.8, color: pdfx.PdfColors.grey700),
      for (final (String label, String value) in rows)
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 5),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: pdfx.PdfColors.grey400, width: 0.5),
            ),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              pw.SizedBox(
                width: 150,
                child: pw.Text(
                  _ellipsis(label, 26),
                  style: base.copyWith(
                    fontSize: 9,
                    color: pdfx.PdfColors.grey800,
                  ),
                ),
              ),
              pw.Expanded(
                child: pw.Text(
                  value.isEmpty ? '未标注来源' : value,
                  style: base.copyWith(
                    fontSize: 9,
                    color: value.isEmpty
                        ? pdfx.PdfColors.grey500
                        : pdfx.PdfColors.grey800,
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );

  /// D155：汇总参考图与姿势照片的「作者 · 许可」署名，供附录页逐条列出。
  static List<(String, String)> _collectAttributions(
    List<PlanModuleData> modules,
  ) {
    final List<(String, String)> rows = <(String, String)>[];
    for (final PlanModuleData module in modules) {
      if (module.type == PlanModuleType.refs) {
        for (final Object? entry
            in (module.data['refs'] as List? ?? <Object?>[])) {
          if (entry is! Map) continue;
          final String label = (entry['title'] as String? ?? '').trim();
          final String ref = (entry['imageRef'] as String? ?? '').trim();
          final String source = (entry['source'] as String? ?? '').trim();
          if (label.isEmpty && ref.isEmpty && source.isEmpty) continue;
          rows.add((
            label.isEmpty ? ref : label,
            <String>[
              if (source.isNotEmpty) '来源：$source',
              if (ref.isNotEmpty) ref,
            ].join(' · '),
          ));
        }
      }
      if (module.type == PlanModuleType.poses) {
        for (final Object? entry
            in (module.data['poses'] as List? ?? <Object?>[])) {
          if (entry is! Map) continue;
          final String label = (entry['name'] as String? ?? '').trim();
          final String attribution = ExportService._poseAttribution(
            asMap(entry),
          );
          if (label.isEmpty && attribution.isEmpty) continue;
          rows.add((
            label.isEmpty ? '未命名姿势' : label,
            attribution.isEmpty ? '' : '署名：$attribution',
          ));
        }
      }
    }
    return rows;
  }

  /// D155：小工具——按字符数截断（中文按字计即可，PDF 里不换行）。
  static String _ellipsis(String text, int max) =>
      text.length <= max ? text : '${text.substring(0, max)}…';
}
