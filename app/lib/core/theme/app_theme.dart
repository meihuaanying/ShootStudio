/// V8/D147 · S3：旧主题入口已迁移到 `lib/core/design/theme.dart`。
///
/// R71/R76：`AppTheme` 实现迁到 `core/design/theme.dart`（由 §3 令牌构建），
/// 本文件仅保留转发壳以兼容既有 import，一个迭代后删除。
@Deprecated('V8/D147：已迁移到 core/design/theme.dart（AppTheme）；请更新 import。')
library;

export '../design/theme.dart';
