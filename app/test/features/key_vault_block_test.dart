import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/core/db/database.dart';
import 'package:shoot_studio/core/providers.dart';
import 'package:shoot_studio/features/ai/ai_controller.dart';
import 'package:shoot_studio/features/ai/key_vault.dart';
import 'package:shoot_studio/features/ai/provider_presets.dart';
import 'package:shoot_studio/services/content_packs.dart';

/// 内存版钥匙串：真的能托管主密钥（模拟「系统钥匙串可用」）。
class _MemStorage extends FlutterSecureStorage {
  _MemStorage([Map<String, String>? seed]) : _data = <String, String>{...?seed};

  final Map<String, String> _data;

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _data.remove(key);
    } else {
      _data[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _data[key];

  @override
  Future<bool> containsKey({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _data.containsKey(key);

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.remove(key);
  }

  @override
  Future<Map<String, String>> readAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => Map<String, String>.of(_data);

  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.clear();
  }
}

/// 坏掉的钥匙串：每个操作都抛 [PlatformException]（模拟系统钥匙串不可用）。
class _BrokenStorage extends FlutterSecureStorage {
  const _BrokenStorage();

  Never _fail() =>
      throw PlatformException(code: 'unavailable', message: '钥匙串不可用');

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _fail();

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _fail();

  @override
  Future<bool> containsKey({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _fail();

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _fail();

  @override
  Future<Map<String, String>> readAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _fail();

  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _fail();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final AiProviderPreset deepseek = findProviderPreset('deepseek')!;

  group('偏差3：KeyVault 写入前拦截', () {
    test('probeStorage：钥匙串可用时返回 true 并把主密钥写进钥匙串', () async {
      final _MemStorage storage = _MemStorage();
      final KeyVault vault = KeyVault(storage: storage);

      expect(await vault.probeStorage(), isTrue);
      expect(vault.storageAvailable, isTrue);
      // 主密钥真的托管进了钥匙串，且是 32 字节的 base64。
      final Map<String, String> stored = await storage.readAll();
      expect(stored.keys, contains('shootstudio.master_key.v1'));
      // 加密 → 解密闭环仍然可用。
      final String enc = await vault.encrypt('sk-live');
      expect(enc, startsWith('v1:'));
      expect(await vault.decrypt(enc), 'sk-live');
    });

    test('probeStorage：钥匙串不可用时返回 false（不抛异常）', () async {
      final KeyVault vault = KeyVault(storage: const _BrokenStorage());

      expect(await vault.probeStorage(), isFalse);
      expect(vault.storageAvailable, isFalse);
      // 降级路径仍能加解密，只是密文重启后不可解。
      final String enc = await vault.encrypt('sk-ephemeral');
      expect(enc, isNotEmpty);
      expect(await vault.decrypt(enc), 'sk-ephemeral');
    });
  });

  group('偏差3：saveProvider 三分支', () {
    late AppDatabase db;
    late ProviderContainer container;
    late AiController controller;

    Future<void> setup() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await ContentPacks.syncToDatabase(db);
      container = ProviderContainer(
        overrides: <Override>[databaseProvider.overrideWithValue(db)],
      );
      controller = container.read(aiControllerProvider.notifier);
      await controller.init();
    }

    tearDown(() async {
      try {
        container.dispose();
        await db.close();
      } catch (_) {
        // 纯函数用例未初始化容器。
      }
    });

    Future<String> encryptedKeyOf(String id) async {
      final List<ProviderConfig> rows = await db
          .select(db.providerConfigs)
          .get();
      return rows.firstWhere((ProviderConfig r) => r.id == id).encryptedKey;
    }

    test('stored：钥匙串可用 → 密文入库且可解密', () async {
      await setup();
      final _MemStorage storage = _MemStorage();
      controller.useVault(KeyVault(storage: storage));

      final AiKeyPersist persist = await controller.saveProvider(
        deepseek,
        apiKey: 'sk-good',
        model: 'deepseek-chat',
        baseUrl: deepseek.baseUrl,
        enabled: true,
      );

      expect(persist, AiKeyPersist.stored);
      final String encrypted = await encryptedKeyOf('deepseek');
      expect(encrypted, startsWith('v1:'));
      expect(await KeyVault(storage: storage).decrypt(encrypted), 'sk-good');

      final AiState state = container.read(aiControllerProvider);
      final AiProviderView view = state.providers.firstWhere(
        (AiProviderView p) => p.preset.id == 'deepseek',
      );
      expect(view.hasKey, isTrue);
      expect(view.maskedKey, isNot(contains('sk-good')));
    });

    test('notProvided：不填 Key → 沿用原有密文，不覆盖', () async {
      await setup();
      final _MemStorage storage = _MemStorage();
      controller.useVault(KeyVault(storage: storage));
      await controller.saveProvider(
        deepseek,
        apiKey: 'sk-first',
        model: 'deepseek-chat',
        baseUrl: deepseek.baseUrl,
        enabled: true,
      );
      final String before = await encryptedKeyOf('deepseek');
      expect(before, isNotEmpty);

      final AiKeyPersist persist = await controller.saveProvider(
        deepseek,
        apiKey: '',
        model: 'deepseek-reasoner',
        baseUrl: deepseek.baseUrl,
        enabled: false,
      );

      expect(persist, AiKeyPersist.notProvided);
      expect(await encryptedKeyOf('deepseek'), before);
      final List<ProviderConfig> rows = await db
          .select(db.providerConfigs)
          .get();
      final ProviderConfig row = rows.firstWhere(
        (ProviderConfig r) => r.id == 'deepseek',
      );
      expect(row.defaultModel, 'deepseek-reasoner');
      expect(row.enabled, isFalse);
    });

    test('blockedNoStorage：钥匙串不可用 → 拒绝写 Key 且不抛异常', () async {
      await setup();
      controller.useVault(KeyVault(storage: const _BrokenStorage()));

      final AiKeyPersist persist = await controller.saveProvider(
        deepseek,
        apiKey: 'sk-would-be-lost',
        model: 'deepseek-chat',
        baseUrl: deepseek.baseUrl,
        enabled: true,
      );

      expect(persist, AiKeyPersist.blockedNoStorage);
      // 关键断言：库里没有写进任何密文（否则重启后就是解不开的垃圾）。
      expect(await encryptedKeyOf('deepseek'), '');
      // 其余字段照常保存。
      final List<ProviderConfig> rows = await db
          .select(db.providerConfigs)
          .get();
      final ProviderConfig row = rows.firstWhere(
        (ProviderConfig r) => r.id == 'deepseek',
      );
      expect(row.baseUrl, deepseek.baseUrl);
      expect(row.defaultModel, 'deepseek-chat');
      expect(row.enabled, isTrue);
      // 状态栏给出可读提示，且没有把 Key 当成功。
      expect(container.read(aiControllerProvider).status, contains('钥匙串不可用'));
      final AiProviderView view = container
          .read(aiControllerProvider)
          .providers
          .firstWhere((AiProviderView p) => p.preset.id == 'deepseek');
      expect(view.hasKey, isFalse);
    });

    test('blockedNoStorage：已有 Key 时保留原密文，不清空', () async {
      await setup();
      controller.useVault(KeyVault(storage: _MemStorage()));
      await controller.saveProvider(
        deepseek,
        apiKey: 'sk-existing',
        model: 'deepseek-chat',
        baseUrl: deepseek.baseUrl,
        enabled: true,
      );
      final String before = await encryptedKeyOf('deepseek');
      expect(before, isNotEmpty);

      // 换成坏掉的钥匙串后重试保存新 Key。
      controller.useVault(KeyVault(storage: const _BrokenStorage()));
      final AiKeyPersist persist = await controller.saveProvider(
        deepseek,
        apiKey: 'sk-new',
        model: 'deepseek-chat',
        baseUrl: deepseek.baseUrl,
        enabled: true,
      );

      expect(persist, AiKeyPersist.blockedNoStorage);
      expect(await encryptedKeyOf('deepseek'), before);
    });
  });
}
