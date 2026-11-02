import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../projects/project_controller.dart';

/// 待插入策划案的姿势（摆姿库 →「加入策划案」暂存区）。
class PendingPose {
  const PendingPose({
    required this.name,
    required this.joints,
    this.lens = '',
    this.cameraPosition = '',
    this.photo = '',
    this.author = '',
    this.license = '',
    this.source = '',
  });

  final String name;
  final Map<String, Object?> joints;
  final String lens;
  final String cameraPosition;

  /// V4/R25：实拍照片与署名（导出默认照片渲染，可切换骨架示意）。
  final String photo;
  final String author;
  final String license;
  final String source;

  Map<String, Object?> toModuleEntry() => <String, Object?>{
    'name': name,
    'joints': joints,
    'lens': lens,
    'cameraPosition': cameraPosition,
    'photo': photo,
    'author': author,
    'license': license,
    'source': source,
  };
}

final pendingPosesProvider =
    NotifierProvider<PendingPosesNotifier, List<PendingPose>>(
      PendingPosesNotifier.new,
    );

class PendingPosesNotifier extends Notifier<List<PendingPose>> {
  static const Uuid _uuid = Uuid();
  late final AppDatabase _db = ref.read(databaseProvider);
  late String _projectId;
  int _revision = 0;
  bool _disposed = false;

  @override
  List<PendingPose> build() {
    _projectId = ref.watch(currentProjectIdProvider);
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return const <PendingPose>[];
  }

  Future<void> init() async {
    if (_disposed) return;
    final int revision = _revision;
    final String projectId = _projectId;
    final rows =
        await (_db.select(_db.projectPoses)
              ..where((p) => p.projectId.equals(projectId))
              ..orderBy(<OrderClauseGenerator<$ProjectPosesTable>>[
                (p) => OrderingTerm(expression: p.sort),
              ]))
            .get();
    if (_disposed || revision != _revision || projectId != _projectId) return;
    state = rows.map((ProjectPose row) {
      final Map<String, Object?> json = (jsonDecode(row.payloadJson) as Map)
          .cast<String, Object?>();
      return PendingPose(
        name: '${json['name'] ?? ''}',
        joints: ((json['joints'] as Map?) ?? const <String, Object?>{})
            .cast<String, Object?>(),
        lens: '${json['lens'] ?? ''}',
        cameraPosition: '${json['cameraPosition'] ?? ''}',
        photo: '${json['photo'] ?? ''}',
        author: '${json['author'] ?? ''}',
        license: '${json['license'] ?? ''}',
        source: '${json['source'] ?? ''}',
      );
    }).toList();
  }

  Future<void> add(PendingPose pose) async {
    if (state.any((PendingPose p) => p.name == pose.name)) return;
    _revision++;
    state = <PendingPose>[...state, pose];
    await _persist();
  }

  Future<void> removeAt(int index) async {
    if (index < 0 || index >= state.length) return;
    _revision++;
    state = <PendingPose>[...state]..removeAt(index);
    await _persist();
  }

  Future<void> clear() async {
    _revision++;
    state = const <PendingPose>[];
    await _persist();
  }

  Future<void> _persist() async {
    final String projectId = _projectId;
    final List<PendingPose> poses = List<PendingPose>.of(state);
    final int now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      await (_db.delete(
        _db.projectPoses,
      )..where((p) => p.projectId.equals(projectId))).go();
      for (var i = 0; i < poses.length; i++) {
        await _db
            .into(_db.projectPoses)
            .insert(
              ProjectPosesCompanion.insert(
                id: _uuid.v4(),
                projectId: projectId,
                payloadJson: jsonEncode(poses[i].toModuleEntry()),
                sort: Value(i),
                createdAt: now,
              ),
            );
      }
    });
  }
}
