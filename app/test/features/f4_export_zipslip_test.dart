// V8/R84 · P0 安全：.sspak 导入器的 Zip Slip 防护回归测试。
//
// 归档条目名是不可信输入：`images/../../evil.png` 之类的条目名经 path.join
// 后会写到 workspace 之外。这里逐个构造恶意条目名，断言导入器抛
// FormatException 且**没有任何文件被写到 workspace 外**。
//
// 关键：不仅要断言抛异常，还要断言「没写盘」—— 只抛异常但已经把文件落盘
// 的实现仍然是有洞的。
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shoot_studio/core/db/database.dart';
import 'package:shoot_studio/core/workspace/workspace.dart';
import 'package:shoot_studio/features/export/exporter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  late Workspace workspace;
  late AppDatabase db;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('ss_zipslip_');
    workspace = await Workspace.initAt(p.join(temp.path, 'ws'));
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
    if (temp.existsSync()) {
      await temp.delete(recursive: true);
    }
  });

  /// 造一个只含 manifest.json + 若干图片条目的 .sspak。
  ///
  /// manifest 先通过格式/版本闸门，图片条目随后才轮到落盘逻辑 —— 这样断言
  /// 的失败点确实来自 Zip Slip 校验，而不是更早的 manifest 校验。
  File buildSspak(String name, List<String> imageEntries) {
    final archive = Archive();
    void add(String entryName, List<int> bytes) =>
        archive.addFile(ArchiveFile(entryName, bytes.length, bytes));

    add(
      'manifest.json',
      utf8.encode(
        const JsonEncoder.withIndent('  ').convert(<String, Object?>{
          'format': 'sspak',
          'version': kSspakFormatVersion,
          'layout': kSspakLayoutName,
          'app': 'ShootStudio',
          'title': 'zip slip probe',
        }),
      ),
    );
    for (final entry in imageEntries) {
      add(entry, utf8.encode('PWNED'));
    }

    final out = File(p.join(temp.path, name));
    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) {
      throw StateError('ZipEncoder 未产出字节（测试夹具异常）');
    }
    out.writeAsBytesSync(encoded);
    return out;
  }

  /// workspace 之外的可写探针位置 —— 恶意条目若真的落盘，这里会出现文件。
  File outsideProbe(String relative) => File(p.join(temp.path, relative));

  List<String> everythingUnder(Directory dir) {
    if (!dir.existsSync()) return <String>[];
    return dir
        .listSync(recursive: true)
        .whereType<File>()
        .map((File f) => p.relative(f.path, from: dir.path))
        .toList();
  }

  group('R84 Zip Slip：条目名校验', () {
    const attacks = <String, String>{
      '上跳两级': 'images/../../evil.png',
      '上跳一级': 'images/../evil.png',
      '深层回跳': 'images/a/b/../../../evil.png',
      '回跳后看起来正常': 'images/a/../ok.png',
      '反斜杠上跳': r'images\..\..\evil.png',
      '反斜杠盘符': r'images/C:/Windows/evil.dll',
      'UNC 前缀': r'images\\host\share\evil.dll',
      '前导斜杠': '/images/evil.png',
    };

    attacks.forEach((String label, String entry) {
      test('拒绝「$label」：$entry', () async {
        final sspak = buildSspak('$label.sspak', <String>[entry]);
        final before = everythingUnder(temp);

        await expectLater(
          () => SspakImporter(workspace: workspace, db: db).import(sspak.path),
          throwsA(isA<FormatException>()),
        );

        // 没写盘：临时目录内容与导入前逐字一致。
        expect(everythingUnder(temp), before, reason: '导入被拒绝后不得有任何文件落盘');
        // 显式确认经典 Zip Slip 目标不存在。
        expect(outsideProbe('evil.png').existsSync(), isFalse);
      });
    });
  });

  test('拒绝 `..`：合法图片也不应被顺带写入（中止而非跳过）', () async {
    final sspak = buildSspak('mixed.sspak', <String>[
      'images/good.png',
      'images/../../evil.png',
    ]);

    await expectLater(
      () => SspakImporter(workspace: workspace, db: db).import(sspak.path),
      throwsA(isA<FormatException>()),
    );

    // 中止语义：两段式校验保证恶意条目后面的正常条目也**不落盘**，
    // 工作区不会停在"写了一半"的状态。
    expect(outsideProbe('evil.png').existsSync(), isFalse);
    expect(
      File(p.join(workspace.root.path, 'images', 'good.png')).existsSync(),
      isFalse,
      reason: '校验未全量通过前不得写出任何图片',
    );
  });

  test('放行正常图片：安全路径不受影响（防「过修」回归）', () async {
    final sspak = buildSspak('good.sspak', <String>[
      'images/cover.png',
      'images/nested/deep.png',
    ]);

    // resources/lighting 等后续清单缺失会抛 StateError，说明已安全通过
    // 图片落盘阶段 —— 断言落盘成功即可，不必造完整数据包。
    await expectLater(
      () => SspakImporter(workspace: workspace, db: db).import(sspak.path),
      throwsA(isA<StateError>()),
    );

    expect(
      File(p.join(workspace.root.path, 'images', 'cover.png')).existsSync(),
      isTrue,
      reason: '正常条目必须仍然能落盘',
    );
    expect(
      File(
        p.join(workspace.root.path, 'images', 'nested', 'deep.png'),
      ).existsSync(),
      isTrue,
    );
  });

  test('规范化后仍在 images 内的相对路径被放行（`..` 未越界即拒绝是硬规则）', () async {
    // `images/a/../ok.png` 规范化后其实仍在 images 内，但按硬规则拒绝：
    // 放行它会让「条目名可含 .. 」这条不变量失效，后续再加规则时容易漏网。
    final sspak = buildSspak('inner-dotdot.sspak', <String>[
      'images/a/../ok.png',
    ]);

    await expectLater(
      () => SspakImporter(workspace: workspace, db: db).import(sspak.path),
      throwsA(isA<FormatException>()),
    );
  });
}
