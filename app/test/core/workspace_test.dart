import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shoot_studio/core/workspace/workspace.dart';

void main() {
  group('Workspace', () {
    late Directory temp;
    setUp(() async {
      temp = await Directory.systemTemp.createTemp('ss_ws_');
    });
    tearDown(() async {
      if (await temp.exists()) {
        await temp.delete(recursive: true);
      }
    });

    test('initAt 创建完整目录结构（D2 本地优先）', () async {
      final root = p.join(temp.path, 'my_workspace');
      final ws = await Workspace.initAt(root);
      expect(await Directory(ws.exportsPath).exists(), isTrue);
      for (final dir in Workspace.imageDirs.values) {
        expect(
          await Directory(p.join(root, dir)).exists(),
          isTrue,
          reason: '缺少目录 $dir',
        );
      }
      expect(ws.dbPath, p.join(root, 'database.sqlite'));
    });

    test('isWritable 对可写目录返回 true', () async {
      expect(await Workspace.isWritable(p.join(temp.path, 'writable')), isTrue);
    });

    test('imagePathOf 映射五库与画板目录', () async {
      final ws = await Workspace.initAt(p.join(temp.path, 'ws2'));
      expect(
        ws.imagePathOf('models', 'a.jpg'),
        p.join(ws.root.path, 'images', 'models', 'a.jpg'),
      );
      expect(
        ws.imagePathOf('refs', 'b.jpg'),
        p.join(ws.root.path, 'images', 'refs', 'b.jpg'),
      );
      // 未知分类回退 misc。
      expect(ws.imagePathOf('unknown', 'c.jpg'), contains('misc'));
    });
  });
}
