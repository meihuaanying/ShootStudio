/// V8/D147 · S3：设计组件库统一出口（R74 组件收口：全部在 `lib/core/design/`）。
///
/// 组件清单（§3.5，≥15）：按钮四态 / 输入框 / 搜索框 / 卡片（文卡·图卡·数据卡）/
/// 对话框 / 底部抽屉 / Chip·标签 / Tabs / 空态 / 骨架屏 / Toast / Tooltip /
/// 分割线与眉题 / 图片帧 / KV 读数行 / 消息条 / 切换动效 / 列表阶梯入场。
///
/// 单文件 ≤300 行（R73）：实现分散在 ss_*.dart，本文件只做导出。
/// 令牌唯一来源：`tokens.dart`（AppTokensV2 / AppType / AppSpace / AppRadius…）。
library;

export 'ss_button.dart';
export 'ss_card.dart';
export 'ss_chip.dart';
export 'ss_dialog.dart';
export 'ss_empty.dart';
export 'ss_feedback.dart';
export 'ss_image_frame.dart';
export 'ss_input.dart';
export 'ss_text.dart';
export 'ss_transitions.dart';
export 'theme.dart';
export 'tokens.dart';
