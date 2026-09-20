import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 密钥保管库（D9）：AES-256-GCM 加密存 Key，主密钥托管系统钥匙串
/// （Windows DPAPI / Android Keystore，由 flutter_secure_storage 提供）。
///
/// 加密格式：`v1:<nonce_b64>:<cipher_b64>:<mac_b64>`。
/// 任何情况下不写入日志、不进入导出文件。
class KeyVault {
  KeyVault({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String _masterKeyEntry = 'shootstudio.master_key.v1';
  static const String _prefix = 'v1';
  static final AesGcm _algorithm = AesGcm.with256bits();
  final FlutterSecureStorage _storage;

  Uint8List? _cachedMaster;
  bool _storageAvailable = true;

  /// 测试/降级：内存主密钥（不落钥匙串）。
  KeyVault.forTesting() : _storage = const FlutterSecureStorage() {
    _storageAvailable = false;
    _cachedMaster = _randomBytes(32);
  }

  Future<Uint8List> _masterKey() async {
    if (_cachedMaster != null) return _cachedMaster!;
    try {
      final existing = await _storage.read(key: _masterKeyEntry);
      if (existing != null && existing.isNotEmpty) {
        _cachedMaster = base64Decode(existing);
        return _cachedMaster!;
      }
      final generated = _randomBytes(32);
      await _storage.write(
        key: _masterKeyEntry,
        value: base64Encode(generated),
      );
      _cachedMaster = generated;
      return generated;
    } catch (_) {
      // 钥匙串不可用：进程内临时密钥（本次会话可用，重启后密文不可解，提示重填）。
      _storageAvailable = false;
      _cachedMaster ??= _randomBytes(32);
      return _cachedMaster!;
    }
  }

  bool get storageAvailable => _storageAvailable;

  static Uint8List _randomBytes(int length) {
    final rnd = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => rnd.nextInt(256)),
    );
  }

  /// 加密 API Key（返回可存库的字符串）。
  Future<String> encrypt(String plainText) async {
    if (plainText.isEmpty) return '';
    final key = await _masterKey();
    final secretKey = SecretKey(key);
    final nonce = _randomBytes(12);
    final box = await _algorithm.encrypt(
      utf8.encode(plainText),
      secretKey: secretKey,
      nonce: nonce,
    );
    return '$_prefix:${base64Encode(box.nonce)}:'
        '${base64Encode(box.cipherText)}:${base64Encode(box.mac.bytes)}';
  }

  /// 解密（失败返回空串并提示重填）。
  Future<String> decrypt(String encoded) async {
    if (encoded.isEmpty) return '';
    final parts = encoded.split(':');
    if (parts.length != 4 || parts[0] != _prefix) return '';
    try {
      final key = await _masterKey();
      final secretBox = SecretBox(
        base64Decode(parts[2]),
        nonce: base64Decode(parts[1]),
        mac: Mac(base64Decode(parts[3])),
      );
      final clear = await _algorithm.decrypt(
        secretBox,
        secretKey: SecretKey(key),
      );
      return utf8.decode(clear);
    } catch (_) {
      return '';
    }
  }

  /// 掩码显示（D9：默认掩码，按需解密查看）。
  static String mask(String plainOrEmpty) {
    if (plainOrEmpty.isEmpty) return '（未配置）';
    if (plainOrEmpty.length <= 8) return '••••••••';
    return '${plainOrEmpty.substring(0, 4)}••••••${plainOrEmpty.substring(plainOrEmpty.length - 4)}';
  }
}
