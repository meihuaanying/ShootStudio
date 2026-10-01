import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart' as pdfx;
import 'package:pdf/widgets.dart' as pw;
import 'package:path/path.dart' as path;

import '../../core/db/database.dart';
import '../../core/utils/json_utils.dart';
import '../../core/workspace/workspace.dart';
import '../../services/richtext_lite.dart';
import '../lighting/lighting_models.dart';
import '../planner/planner_models.dart';

/// 导出格式（PRD 6.7）。
part 'exporter_render.dart';
part 'exporter_draw.dart';
part 'exporter_pdf.dart';
part 'exporter_pdf_press.dart';
part 'exporter_sspak.dart';

/// D150：.sspak 包格式版本。v1 = 旧包（无 `layout`、无 plan.version）；
/// v2 = manifest/plan 均显式带版本，导入端按档位迁移或明示拒绝。
const int kSspakFormatVersion = 2;

/// D150：v2 包内各清单的版式名（读方可据此判断是否需要迁移）。
const String kSspakLayoutName = 'sspak-v2';

enum ExportFormat {
  longPng('long', '长图 PNG', '发微信 / 小红书'),
  pdf('pdf', '打印版 PDF', '正式确认件'),
  sspak('sspak', '.sspak 数据包', '整案交接 / 备份');

  const ExportFormat(this.id, this.label, this.usage);
  final String id;
  final String label;
  final String usage;
}

class ExportProgress {
  const ExportProgress(this.stage, [this.percent = 0]);
  final String stage;
  final double percent;
}

class ExportResult {
  const ExportResult({required this.files, required this.sha256s});
  final List<String> files;
  final Map<String, String> sha256s;
}

class ExportCancelled implements Exception {
  const ExportCancelled();
}

class IntegrityIssue {
  const IntegrityIssue(this.moduleTitle, this.detail);
  final String moduleTitle;
  final String detail;
}

/// 导出服务。
class ExportService {
  ExportService({
    required this.workspace,
    required this.db,
    this.refBytesLoader,
  });

  final Workspace workspace;
  final AppDatabase db;

  /// 参考图字节读取钩子（测试注入；默认从工作区 images/refs 读取）。
  final Future<Uint8List?> Function(String ref)? refBytesLoader;

  Future<Uint8List?> _loadRefBytes(String ref) async {
    if (ref.isEmpty) return null;
    final Future<Uint8List?> Function(String)? hook = refBytesLoader;
    if (hook != null) return hook(ref);
    final file = File(path.join(workspace.root.path, 'images', 'refs', ref));
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  /// V4/R25：姿势照片字节（assets 内路径走 rootBundle；非 assets 走参考图钩子）。
  Future<Uint8List?> _loadPosePhotoBytes(String path) async {
    if (path.isEmpty) return null;
    if (!path.startsWith('assets/')) return _loadRefBytes(path);
    try {
      final ByteData data = await rootBundle.load(path);
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<List<IntegrityIssue>> checkIntegrity(
    List<PlanModuleData> modules,
  ) async {
    final issues = <IntegrityIssue>[];
    final resources = await db.select(db.resources).get();
    final resourceIds = resources.map((Resource r) => r.id).toSet();
    final scenes = await db.select(db.lightingScenes).get();
    final sceneIds = scenes.map((LightingScene s) => s.id).toSet();
    for (final PlanModuleData module in modules) {
      switch (module.type) {
        case PlanModuleType.model:
        case PlanModuleType.location:
        case PlanModuleType.clothing:
        case PlanModuleType.props:
        case PlanModuleType.makeup:
          for (final String id
              in (module.data['ids'] as List? ?? <Object?>[]).cast<String>()) {
            if (!resourceIds.contains(id)) {
              issues.add(IntegrityIssue(module.title, '资源引用失效（$id）'));
            }
          }
        case PlanModuleType.lighting:
          final sceneId = module.data['sceneId'] as String? ?? '';
          if (sceneId.isNotEmpty && !sceneIds.contains(sceneId)) {
            issues.add(IntegrityIssue(module.title, '布光方案已被删除'));
          }
        default:
          break;
      }
    }
    return issues;
  }

  Future<ExportResult> run({
    required String planTitle,
    required PlanDocStatus status,
    required List<PlanModuleData> modules,
    required ExportFormat format,
    required void Function(ExportProgress) onProgress,
    required bool Function() isCancelled,
  }) async {
    final safeTitle = planTitle.replaceAll(RegExp(r'[\\/:*?"<>|\s]'), '_');
    final date = DateTime.now()
        .toIso8601String()
        .substring(0, 10)
        .replaceAll('-', '');
    final base = '$safeTitle-$date';
    final files = <String>[];
    final hashes = <String, String>{};

    switch (format) {
      case ExportFormat.longPng:
        onProgress(const ExportProgress('正在渲染长图…', 0.1));
        final images = await renderLongImage(
          modules: modules,
          title: planTitle,
          status: status,
          dark: false,
        );
        var index = 0;
        for (final Uint8List png in images) {
          if (isCancelled()) throw const ExportCancelled();
          final name = images.length > 1
              ? '${base}_long_${++index}.png'
              : '${base}_long.png';
          final file = File(path.join(workspace.exportsPath, name));
          await file.writeAsBytes(png);
          files.add(file.path);
          hashes[file.path] = sha256.convert(png).toString();
          onProgress(
            ExportProgress(
              '已导出 $index/${images.length}',
              0.1 + 0.85 * index / images.length,
            ),
          );
        }
      case ExportFormat.pdf:
        onProgress(const ExportProgress('正在生成 PDF…', 0.2));
        final file = File(path.join(workspace.exportsPath, '$base.pdf'));
        await _exportPdf(file, planTitle, status, modules, onProgress);
        files.add(file.path);
        hashes[file.path] = sha256.convert(await file.readAsBytes()).toString();
      case ExportFormat.sspak:
        onProgress(const ExportProgress('正在打包 .sspak…', 0.1));
        final file = File(path.join(workspace.exportsPath, '$base.sspak'));
        await _exportSspak(
          file,
          planTitle,
          status,
          modules,
          onProgress,
          isCancelled,
        );
        files.add(file.path);
        hashes[file.path] = sha256.convert(await file.readAsBytes()).toString();
    }
    return ExportResult(files: files, sha256s: hashes);
  }

  // ---------------- 长图渲染（纯 dart:ui 离屏拼接；高度超限自动分页） ----------------

  static const double _width = 1080;
  static const double _maxPartHeight = 28000;

  /// V4/R25：姿势照片署名（作者 · 许可）。
  static String _poseAttribution(Map<String, Object?> pose) => <String>[
    if ((pose['author'] as String? ?? '').isNotEmpty) pose['author'] as String,
    if ((pose['license'] as String? ?? '').isNotEmpty)
      pose['license'] as String,
  ].join(' · ');
}
