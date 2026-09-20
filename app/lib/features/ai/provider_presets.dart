/// 13 个内置 AI 提供方预设（对齐 dsh-model-pro；D8）。
/// 选中即出配置卡：Base URL / 协议已预填，用户只需粘贴 Key。
class AiProviderPreset {
  const AiProviderPreset({
    required this.id,
    required this.name,
    required this.protocol,
    required this.baseUrl,
    this.defaultModel = '',
    this.keyHint = 'API Key',
    this.consoleUrl = '',
    this.note = '',
  });

  final String id;
  final String name;

  /// openai | anthropic | responses
  final String protocol;
  final String baseUrl;
  final String defaultModel;
  final String keyHint;
  final String consoleUrl;
  final String note;

  bool get isCustom => id == 'custom';
}

const List<AiProviderPreset> aiProviderPresets = <AiProviderPreset>[
  AiProviderPreset(
    id: 'deepseek',
    name: 'DeepSeek',
    protocol: 'openai',
    baseUrl: 'https://api.deepseek.com/v1',
    defaultModel: 'deepseek-chat',
    consoleUrl: 'https://platform.deepseek.com',
    note: '性价比高，中文文案稳定',
  ),
  AiProviderPreset(
    id: 'openai',
    name: 'OpenAI',
    protocol: 'openai',
    baseUrl: 'https://api.openai.com/v1',
    defaultModel: 'gpt-4o-mini',
    consoleUrl: 'https://platform.openai.com',
  ),
  AiProviderPreset(
    id: 'aliyun',
    name: '阿里百炼（通义）',
    protocol: 'openai',
    baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    defaultModel: 'qwen-plus',
    consoleUrl: 'https://bailian.console.aliyun.com',
  ),
  AiProviderPreset(
    id: 'zhipu',
    name: '智谱 GLM',
    protocol: 'openai',
    baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
    defaultModel: 'glm-4-flash',
    consoleUrl: 'https://open.bigmodel.cn',
  ),
  AiProviderPreset(
    id: 'moonshot',
    name: 'Moonshot Kimi',
    protocol: 'openai',
    baseUrl: 'https://api.moonshot.cn/v1',
    defaultModel: 'moonshot-v1-8k',
    consoleUrl: 'https://platform.moonshot.cn',
  ),
  AiProviderPreset(
    id: 'volcengine',
    name: '火山方舟（豆包）',
    protocol: 'openai',
    baseUrl: 'https://ark.cn-beijing.volces.com/api/v3',
    defaultModel: 'doubao-lite-32k',
    consoleUrl: 'https://console.volcengine.com/ark',
  ),
  AiProviderPreset(
    id: 'anthropic',
    name: 'Anthropic Claude',
    protocol: 'anthropic',
    baseUrl: 'https://api.anthropic.com',
    defaultModel: 'claude-3-5-sonnet-latest',
    consoleUrl: 'https://console.anthropic.com',
  ),
  AiProviderPreset(
    id: 'gemini',
    name: 'Google Gemini',
    protocol: 'openai',
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
    defaultModel: 'gemini-1.5-flash',
    consoleUrl: 'https://aistudio.google.com',
  ),
  AiProviderPreset(
    id: 'sensenova',
    name: '商汤 SenseNova',
    protocol: 'openai',
    baseUrl: 'https://api.sensenova.cn/v1',
    defaultModel: 'SenseChat-5',
    consoleUrl: 'https://platform.sensenova.cn',
  ),
  AiProviderPreset(
    id: 'opencode-go',
    name: 'OpenCode Go',
    protocol: 'openai',
    baseUrl: 'https://opencode.ai/zen/go/v1',
    consoleUrl: 'https://opencode.ai/docs/zen/',
    note: '订阅内置：OpenAI 兼容端点，粘贴 Zen 控制台的 API Key 即用',
  ),
  AiProviderPreset(
    id: 'opencode-zen',
    name: 'OpenCode Zen',
    protocol: 'openai',
    baseUrl: 'https://opencode.ai/zen/v1',
    consoleUrl: 'https://opencode.ai/docs/zh-cn/zen/',
    note: 'opencode 生态统一端点（按量付费）',
  ),
  AiProviderPreset(
    id: 'command-code',
    name: 'Command Code',
    protocol: 'openai',
    baseUrl: 'https://api.commandcode.ai/provider/v1',
    consoleUrl: 'https://commandcode.ai',
  ),
  AiProviderPreset(
    id: 'tokenrhythm',
    name: '基元律动 TokenRhythm',
    protocol: 'openai',
    baseUrl: 'https://tokenrhythm.studio/v1',
    consoleUrl: 'https://tokenrhythm.studio/docs',
    note: '同时支持 OpenAI 与 Anthropic 协议',
  ),
  AiProviderPreset(
    id: 'custom',
    name: '自定义端点',
    protocol: 'openai',
    baseUrl: '',
    keyHint: 'API Key（如中转站/本地 Ollama 可留空）',
    note: '兼容 OpenAI 协议；可填 Ollama（http://localhost:11434/v1）',
  ),
];

AiProviderPreset? findProviderPreset(String id) {
  for (final AiProviderPreset p in aiProviderPresets) {
    if (p.id == id) return p;
  }
  return null;
}

/// 质量优先的模型优选（D40）：按已知强模型片段打分，未知模型排后。
/// 过滤 embedding/rerank/tts/vision-only 等非对话模型。
const List<String> _qualityHints = <String>[
  'gpt-5.6-sol',
  'gpt-5.6',
  'gpt-5.5-pro',
  'gpt-5.5',
  'claude-opus',
  'claude-sonnet',
  'deepseek-v4-pro',
  'deepseek-reasoner',
  'glm-5.2',
  'glm-5.1',
  'kimi-k3',
  'kimi-k2.7',
  'kimi-k2.6',
  'qwen3.7-max',
  'qwen3.6-max',
  'gemini-3.1-pro',
  'gemini-3-pro',
  'minimax-m3',
  'grok-4',
  'gpt-5',
  'o3',
  'deepseek-v4',
  'deepseek-chat',
  'glm-5',
  'glm-4',
  'kimi',
  'qwen-max',
  'qwen-plus',
  'gemini-3',
  'gemini-2.5-pro',
  'claude',
  'gpt-4o',
];

const List<String> _excludeHints = <String>[
  'embedding',
  'embed',
  'rerank',
  'tts',
  'whisper',
  'audio',
  'image-',
  'dall-e',
  'vision-preview',
  'moderation',
];

/// 从模型列表里挑质量最高的可用模型；都未知时取第一个可对话模型。
String pickBestModel(List<String> models, {String preferred = ''}) {
  final List<String> chat = models
      .where(
        (String m) =>
            !_excludeHints.any((String e) => m.toLowerCase().contains(e)),
      )
      .toList();
  if (chat.isEmpty) return preferred;
  if (preferred.isNotEmpty) {
    for (final String m in chat) {
      if (m == preferred) return m;
    }
  }
  for (final String hint in _qualityHints) {
    for (final String m in chat) {
      if (m.toLowerCase().contains(hint)) return m;
    }
  }
  return chat.first;
}
