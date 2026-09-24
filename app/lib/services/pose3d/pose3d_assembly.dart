/// V7/D141：模型分片拼装（R64 随包；GitHub 100MiB 单文件限制绕过）。
///
/// fp16 RTMW3D（184,789,026 B）以两片入库（各 92,394,513 B），首次使用时拼装到
/// 工作区缓存文件；已存在且大小/摘要一致则跳过（拼装 0.23s 实测）。
/// 拼装失败（分片缺失/大小不符/摘要不符）→ 抛出 [Pose3dAssemblyException]，
/// 调用方按 R69 回退旧识别后端。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// 单个分片规格。
class Pose3dPartSpec {
  const Pose3dPartSpec({required this.assetKey, required this.bytes});

  final String assetKey;
  final int bytes;
}

/// 拼装规格（分片列表 + 总字节 + SHA256）。
class Pose3dAssemblySpec {
  const Pose3dAssemblySpec({
    required this.parts,
    required this.totalBytes,
    required this.sha256,
  });

  final List<Pose3dPartSpec> parts;
  final int totalBytes;
  final String sha256;

  /// RTMW3D-x fp16（2 片，见 `assets/models/pose3d/NOTICE.md`）。
  static const Pose3dAssemblySpec rtmw3dFp16 = Pose3dAssemblySpec(
    parts: <Pose3dPartSpec>[
      Pose3dPartSpec(
        assetKey: 'assets/models/pose3d/rtmw3d-x-fp16.onnx.part0',
        bytes: 92394513,
      ),
      Pose3dPartSpec(
        assetKey: 'assets/models/pose3d/rtmw3d-x-fp16.onnx.part1',
        bytes: 92394513,
      ),
    ],
    totalBytes: 184789026,
    sha256: '2ca95a4ab47b9711c4900ec7f746122aa9e741b5b6caf8b487940856b1187bec',
  );
}

/// 拼装结果。
class Pose3dAssembledModel {
  const Pose3dAssembledModel({
    required this.file,
    required this.bytes,
    required this.reused,
  });

  final File file;
  final int bytes;

  /// true = 复用已有文件（未重新拼装）。
  final bool reused;
}

/// 拼装失败（调用方回退旧后端，R69）。
class Pose3dAssemblyException implements Exception {
  const Pose3dAssemblyException(this.message);

  final String message;

  @override
  String toString() => 'Pose3dAssemblyException: $message';
}

/// 资源读取器（生产用 rootBundle.load；测试注入内存实现，R62）。
typedef Pose3dAssetReader = Future<Uint8List> Function(String assetKey);

/// 确保 [target] 存在且与 [spec] 一致（大小 + SHA256），否则从分片拼装。
///
/// 流式写入（不整包驻留内存）：分片 → `.tmp` → 校验 → rename。
Future<Pose3dAssembledModel> ensurePose3dModel({
  required Pose3dAssemblySpec spec,
  required File target,
  required Pose3dAssetReader readAsset,
  bool verifySha256 = true,
}) async {
  if (await target.exists()) {
    final int length = await target.length();
    if (length == spec.totalBytes) {
      if (!verifySha256) {
        return Pose3dAssembledModel(file: target, bytes: length, reused: true);
      }
      if (await sha256OfFile(target) == spec.sha256) {
        return Pose3dAssembledModel(file: target, bytes: length, reused: true);
      }
    }
  }
  final File tmp = File('${target.path}.tmp');
  await target.parent.create(recursive: true);
  final IOSink sink = tmp.openWrite();
  final _DigestSink acc = _DigestSink();
  final ByteConversionSink hasher = sha256.startChunkedConversion(acc);
  int written = 0;
  try {
    for (final Pose3dPartSpec part in spec.parts) {
      final Uint8List data = await readAsset(part.assetKey);
      if (data.length != part.bytes) {
        throw Pose3dAssemblyException(
          '分片大小不符：${part.assetKey} 期望 ${part.bytes} 实际 ${data.length}',
        );
      }
      hasher.add(data);
      sink.add(data);
      written += data.length;
    }
  } catch (e) {
    await sink.close();
    if (await tmp.exists()) {
      await tmp.delete();
    }
    rethrow;
  }
  await sink.close();
  hasher.close();
  if (written != spec.totalBytes) {
    if (await tmp.exists()) {
      await tmp.delete();
    }
    throw Pose3dAssemblyException('拼装大小不符：期望 ${spec.totalBytes} 实际 $written');
  }
  final String digest = acc.value?.toString() ?? '';
  if (verifySha256 && digest != spec.sha256) {
    if (await tmp.exists()) {
      await tmp.delete();
    }
    throw Pose3dAssemblyException('拼装摘要不符：期望 ${spec.sha256} 实际 $digest');
  }
  await tmp.rename(target.path);
  return Pose3dAssembledModel(file: target, bytes: written, reused: false);
}

/// 计算文件 SHA256（小写十六进制）。
Future<String> sha256OfFile(File file) async {
  final _DigestSink acc = _DigestSink();
  final ByteConversionSink hasher = sha256.startChunkedConversion(acc);
  await for (final List<int> chunk in file.openRead()) {
    hasher.add(chunk);
  }
  hasher.close();
  return acc.value?.toString() ?? '';
}

/// 收集 chunked 转换的最终摘要（避免依赖 package:convert）。
class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) {
    value = data;
  }

  @override
  void close() {}
}
