/// V5/D86：手部预设表（与引擎 character.js HAND_PRESETS 对齐；双手组合含手臂叠加）。
///
/// 单手指令走引擎 `setHandPose`（curls 数值由引擎权威定义，此处镜像用于 UI 滑杆初值）；
/// 双手组合额外携带 `arms`（语义 12 关节角度），由控制器叠加进当前姿势后重新注入。
class HandPresetInfo {
  const HandPresetInfo({
    required this.id,
    required this.label,
    required this.emoji,
    this.dual = false,
    this.curls = const <String, double>{},
    this.spread = 0,
    this.wrist,
    this.arms,
  });

  final String id;
  final String label;
  final String emoji;
  final bool dual;
  final Map<String, double> curls;
  final double spread;
  final List<double>? wrist;

  /// 双手组合的手臂叠加：{'l': {shoulder:[...], elbow:[...]}, 'r': {...}}。
  final Map<String, Map<String, List<double>>>? arms;
}

const List<HandPresetInfo> kHandPresetList = <HandPresetInfo>[
  // 基础四式
  HandPresetInfo(
    id: 'relax',
    label: '自然放松',
    emoji: '🤚',
    curls: <String, double>{
      'thumb': 0.18,
      'index': 0.22,
      'middle': 0.26,
      'ring': 0.30,
      'pinky': 0.32,
    },
    spread: 0.15,
  ),
  HandPresetInfo(
    id: 'open',
    label: '五指张开',
    emoji: '🖐️',
    curls: <String, double>{
      'thumb': 0.05,
      'index': 0,
      'middle': 0,
      'ring': 0,
      'pinky': 0,
    },
    spread: 1,
  ),
  HandPresetInfo(
    id: 'fist',
    label: '握拳',
    emoji: '✊',
    curls: <String, double>{
      'thumb': 0.78,
      'index': 1,
      'middle': 1,
      'ring': 1,
      'pinky': 1,
    },
  ),
  HandPresetInfo(
    id: 'halfGrip',
    label: '半握',
    emoji: '🤏',
    curls: <String, double>{
      'thumb': 0.4,
      'index': 0.55,
      'middle': 0.6,
      'ring': 0.65,
      'pinky': 0.65,
    },
    spread: 0.15,
  ),
  // 标志手势
  HandPresetInfo(
    id: 'thumbsUp',
    label: '点赞',
    emoji: '👍',
    curls: <String, double>{
      'thumb': 0,
      'index': 1,
      'middle': 1,
      'ring': 1,
      'pinky': 1,
    },
    wrist: <double>[0, 0, -30],
  ),
  HandPresetInfo(
    id: 'peace',
    label: '比耶',
    emoji: '✌️',
    curls: <String, double>{
      'thumb': 0.45,
      'index': 0,
      'middle': 0,
      'ring': 1,
      'pinky': 1,
    },
    spread: 0.7,
  ),
  HandPresetInfo(
    id: 'ok',
    label: 'OK 手势',
    emoji: '👌',
    curls: <String, double>{
      'thumb': 0.55,
      'index': 0.62,
      'middle': 0.05,
      'ring': 0.05,
      'pinky': 0.05,
    },
    spread: 0.35,
  ),
  HandPresetInfo(
    id: 'point',
    label: '食指指向',
    emoji: '☝️',
    curls: <String, double>{
      'thumb': 0.7,
      'index': 0,
      'middle': 1,
      'ring': 1,
      'pinky': 1,
    },
    spread: 0.2,
  ),
  // 情绪与互动
  HandPresetInfo(
    id: 'heart',
    label: '比心',
    emoji: '🫶',
    curls: <String, double>{
      'thumb': 0.35,
      'index': 0.5,
      'middle': 0.85,
      'ring': 1,
      'pinky': 1,
    },
    spread: 0.45,
  ),
  HandPresetInfo(
    id: 'pinch',
    label: '捏合',
    emoji: '🤏',
    curls: <String, double>{
      'thumb': 0.72,
      'index': 0.72,
      'middle': 0.15,
      'ring': 0.15,
      'pinky': 0.15,
    },
    spread: 0.1,
  ),
  HandPresetInfo(
    id: 'wave',
    label: '挥手',
    emoji: '👋',
    curls: <String, double>{
      'thumb': 0.2,
      'index': 0,
      'middle': 0,
      'ring': 0,
      'pinky': 0,
    },
    spread: 0.9,
    wrist: <double>[0, 0, -22],
  ),
  HandPresetInfo(
    id: 'chinRest',
    label: '托腮',
    emoji: '🤔',
    curls: <String, double>{
      'thumb': 0.35,
      'index': 0.62,
      'middle': 0.7,
      'ring': 0.75,
      'pinky': 0.75,
    },
    spread: 0.1,
    wrist: <double>[52, -8, -14],
  ),
  // 双手组合（含手臂叠加）
  HandPresetInfo(
    id: 'gongshou',
    label: '抱拳（双手）',
    emoji: '🙏',
    dual: true,
    curls: <String, double>{
      'thumb': 0.55,
      'index': 0.95,
      'middle': 1,
      'ring': 1,
      'pinky': 1,
    },
    spread: 0.05,
    arms: <String, Map<String, List<double>>>{
      'l': <String, List<double>>{
        'shoulder': <double>[-18, 38, 26],
        'elbow': <double>[-108, 0, 0],
      },
      'r': <String, List<double>>{
        'shoulder': <double>[-18, -38, -26],
        'elbow': <double>[-108, 0, 0],
      },
    },
  ),
  HandPresetInfo(
    id: 'qigong',
    label: '拱手（双手）',
    emoji: '🙏',
    dual: true,
    curls: <String, double>{
      'thumb': 0.45,
      'index': 0.85,
      'middle': 0.95,
      'ring': 0.95,
      'pinky': 0.95,
    },
    spread: 0.3,
    arms: <String, Map<String, List<double>>>{
      'l': <String, List<double>>{
        'shoulder': <double>[-12, 42, 18],
        'elbow': <double>[-96, 0, 0],
      },
      'r': <String, List<double>>{
        'shoulder': <double>[-12, -42, -18],
        'elbow': <double>[-96, 0, 0],
      },
    },
  ),
  HandPresetInfo(
    id: 'prayer',
    label: '双手合十',
    emoji: '🙏',
    dual: true,
    curls: <String, double>{
      'thumb': 0.5,
      'index': 0.05,
      'middle': 0.05,
      'ring': 0.05,
      'pinky': 0.05,
    },
    spread: 0.02,
    wrist: <double>[42, 0, 0],
    arms: <String, Map<String, List<double>>>{
      'l': <String, List<double>>{
        'shoulder': <double>[-10, 46, 14],
        'elbow': <double>[-124, 0, 0],
      },
      'r': <String, List<double>>{
        'shoulder': <double>[-10, -46, -14],
        'elbow': <double>[-124, 0, 0],
      },
    },
  ),
];

HandPresetInfo? handPresetById(String id) {
  for (final HandPresetInfo p in kHandPresetList) {
    if (p.id == id) return p;
  }
  return null;
}
