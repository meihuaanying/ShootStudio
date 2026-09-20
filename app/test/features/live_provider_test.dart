import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/features/ai/ai_client.dart';
import 'package:shoot_studio/features/ai/provider_presets.dart';

/// 真实供应商联调（默认跳过；由环境变量触发）：
/// ZHIPU_API_KEY / DEEPSEEK_API_KEY / OPENCODE_GO_API_KEY 任一存在即执行。
void main() {
  final String zhipu = Platform.environment['ZHIPU_API_KEY'] ?? '';
  final String deepseek = Platform.environment['DEEPSEEK_API_KEY'] ?? '';
  final String go = Platform.environment['OPENCODE_GO_API_KEY'] ?? '';
  final String id = zhipu.isNotEmpty
      ? 'zhipu'
      : deepseek.isNotEmpty
      ? 'deepseek'
      : go.isNotEmpty
      ? 'opencode-go'
      : '';
  final String key = id == 'zhipu'
      ? zhipu
      : id == 'deepseek'
      ? deepseek
      : go;
  final String baseUrl = id == 'zhipu'
      ? 'https://open.bigmodel.cn/api/paas/v4'
      : id == 'deepseek'
      ? 'https://api.deepseek.com/v1'
      : 'https://opencode.ai/zen/go/v1';

  test('live：真实供应商 拉模型 + 最小对话', () async {
    final AiClient client = AiClient();
    final RuntimeProvider probe = RuntimeProvider(
      id: id,
      name: id,
      protocol: 'openai',
      baseUrl: baseUrl,
      apiKey: key,
      model: '',
    );
    late List<String> models;
    try {
      models = await client.discoverModels(probe);
    } catch (e) {
      models = <String>[];
      // ignore: avoid_print
      print('discoverModels failed (tolerated): $e');
    }
    final String picked = pickBestModel(models).isEmpty
        ? 'glm-4-flash'
        : pickBestModel(models);
    final AiCallResult chat = await client.chat(
      provider: RuntimeProvider(
        id: id,
        name: id,
        protocol: 'openai',
        baseUrl: baseUrl,
        apiKey: key,
        model: picked,
      ),
      systemPrompt: '你是摄影策划助手，只回复四个字。',
      userPrompt: '回复：布光就绪',
      maxTokens: 16,
    );
    // ignore: avoid_print
    print(
      'LIVE id=$id models=${models.length} model=$picked '
      'success=${chat.success} content=${chat.content} error=${chat.error}',
    );
    expect(chat.success, isTrue, reason: chat.error);
  }, skip: id.isEmpty ? '未提供 LIVE provider key（跳过）' : false);
}
