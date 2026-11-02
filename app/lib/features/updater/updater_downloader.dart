import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';

/// 应用内下载的校验结论（偏差 2 闭环）。
///
/// 只有 [verified] 允许启动安装器；其余三态都必须拒绝安装。
enum UpdateVerifyState {
  /// 下载完成且流式 SHA-256 与公告一致。
  verified,

  /// 下载完成但摘要不一致（文件已删除）。
  mismatch,

  /// 公告没有公布可校验的 64 位十六进制摘要（文件已删除）。
  digestMissing,

  /// 网络/磁盘错误（无文件留下）。
  downloadFailed,
}

/// 一次「下载 + 校验」的结果。
class UpdateDownloadResult {
  const UpdateDownloadResult({
    required this.state,
    required this.message,
    this.filePath = '',
    this.expectedDigest = '',
    this.actualDigest = '',
  });

  final UpdateVerifyState state;
  final String message;
  final String filePath;
  final String expectedDigest;
  final String actualDigest;

  /// 唯一允许安装的条件。
  bool get canInstall => state == UpdateVerifyState.verified;
}

/// 规范化公告里的 sha256：必须正好 64 位十六进制，否则视为「未公布」。
///
/// 线上公告在发布前可能是占位串（例如「发布时由 CI 写入」），
/// 这种情况必须走 [UpdateVerifyState.digestMissing] 而不是当成校验通过。
String? normalizeSha256(String raw) {
  final String s = raw.trim().toLowerCase();
  if (s.length != 64) return null;
  return RegExp(r'^[0-9a-f]{64}$').hasMatch(s) ? s : null;
}

/// 流式计算文件 SHA-256（不把整包读进内存）。
Future<String> sha256OfFile(File file) async {
  final _DigestSink sink = _DigestSink();
  final ByteConversionSink hasher = sha256.startChunkedConversion(sink);
  await for (final List<int> chunk in file.openRead()) {
    hasher.add(chunk);
  }
  hasher.close();
  return sink.value.toString();
}

class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}

/// 启动本地安装器（Windows 交给系统默认处理器，Android 交给外部应用）。
typedef InstallerLauncher = Future<bool> Function(String filePath);

/// 默认安装器：用系统默认程序打开已校验的文件。
Future<bool> launchLocalInstaller(String filePath) async {
  try {
    return await launchUrl(
      Uri.file(filePath),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    return false;
  }
}

/// 应用内下载 + 流式校验 + 校验通过才安装（偏差 2 的闭环实现）。
///
/// 铁律：**校验失败一律拒绝安装**，并把半成品文件删掉，
/// 绝不留一个「看起来下载好了」的包给用户手动双击。
class UpdaterDownloader {
  UpdaterDownloader({required this.dio, this.launcher = launchLocalInstaller});

  final Dio dio;
  final InstallerLauncher launcher;

  Future<UpdateDownloadResult> download({
    required String url,
    required String sha256,
    required String savePath,
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final File file = File(savePath);
    try {
      await file.parent.create(recursive: true);
      await dio.download(
        url,
        savePath,
        onReceiveProgress: onProgress,
        cancelToken: cancelToken,
      );
    } catch (error) {
      await _tryDelete(file);
      return UpdateDownloadResult(
        state: UpdateVerifyState.downloadFailed,
        message: '下载失败：$error',
        expectedDigest: sha256,
      );
    }

    final String? expected = normalizeSha256(sha256);
    if (expected == null) {
      await _tryDelete(file);
      return UpdateDownloadResult(
        state: UpdateVerifyState.digestMissing,
        message: '公告未公布可校验的 SHA-256，已拒绝应用内安装。',
        expectedDigest: sha256,
      );
    }

    String actual = '';
    try {
      actual = await sha256OfFile(file);
    } catch (error) {
      await _tryDelete(file);
      return UpdateDownloadResult(
        state: UpdateVerifyState.downloadFailed,
        message: '读取下载文件失败：$error',
        expectedDigest: expected,
      );
    }

    if (actual != expected) {
      await _tryDelete(file);
      return UpdateDownloadResult(
        state: UpdateVerifyState.mismatch,
        message: 'SHA-256 校验失败，已删除下载文件并拒绝安装。',
        expectedDigest: expected,
        actualDigest: actual,
      );
    }

    return UpdateDownloadResult(
      state: UpdateVerifyState.verified,
      message: 'SHA-256 校验通过。',
      filePath: savePath,
      expectedDigest: expected,
      actualDigest: actual,
    );
  }

  /// 下载 → 校验 → 仅在 [UpdateVerifyState.verified] 时启动安装器。
  Future<bool> downloadAndInstall({
    required String url,
    required String sha256,
    required String savePath,
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final UpdateDownloadResult result = await download(
      url: url,
      sha256: sha256,
      savePath: savePath,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    if (!result.canInstall) return false;
    return launcher(result.filePath);
  }

  static Future<void> _tryDelete(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // 删不掉也不影响「拒绝安装」的结论。
    }
  }
}
