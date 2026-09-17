# ShootStudio · Flutter 应用

Windows + Android 单代码库。仓库级说明、环境配置、管线与工具速查见根目录
[`HANDOFF.md`](../HANDOFF.md)；版本约束与决策见根目录的 `FIX_CONTRACT_*.md` / `BUILD_CONTRACT.md`。

## 常用命令（在本目录执行）

```powershell
# 依赖与链接（每次改 pubspec：脚本 → pub get → 脚本）
powershell -NoProfile -ExecutionPolicy Bypass -File tool/setup_symlinks.ps1
"C:/dev/flutter/bin/cache/dart-sdk/bin/dart.exe" "C:/dev/flutter/bin/cache/flutter_tools.snapshot" pub get
powershell -NoProfile -ExecutionPolicy Bypass -File tool/setup_symlinks.ps1

# 质量门禁（与 CI 一致）
"C:/dev/flutter/bin/cache/dart-sdk/bin/dart.exe" format --output=none --set-exit-if-changed lib test
"C:/dev/flutter/bin/cache/dart-sdk/bin/dart.exe" "C:/dev/flutter/bin/cache/flutter_tools.snapshot" analyze --fatal-infos
"C:/dev/flutter/bin/cache/dart-sdk/bin/dart.exe" "C:/dev/flutter/bin/cache/flutter_tools.snapshot" test

# 构建
powershell -NoProfile -ExecutionPolicy Bypass -File tool/setup_windows_build.ps1
"C:/dev/flutter/bin/cache/dart-sdk/bin/dart.exe" "C:/dev/flutter/bin/cache/flutter_tools.snapshot" build windows --release
powershell -NoProfile -ExecutionPolicy Bypass -File tool/smoke_launch.ps1

# 引擎打包（改动 assets/engine/js/** 后必须重跑）
node tool/engine_build/bundle.mjs
```

## 结构

| 目录 | 说明 |
| --- | --- |
| `lib/` | 应用代码（features 按模块：ai / lighting / poses / planner / refs / export / libraries / settings / shell / onboarding / updater） |
| `assets/content/` | 内置内容包（`poses3` 照片姿势库、`gear` 设备与产品图、`stills` 静帧、`clothing`、模板/预设/城市/预算等） |
| `assets/engine/` | 3D 引擎（`js/engine.bundle.js` 为打包产物，`qa.html` 为 QA 渲染页） |
| `assets/models/` | 人形 GLB（Quaternius CC0 ×21 + MakeHuman 写实；细分在运行时执行，原模型为轻量模式） |
| `test/` | 单元/Widget/黄金测试（156 项 + 1 skipped） |
| `tool/` | 构建期管线与 QA 脚本（见 HANDOFF §3） |
| `third_party/` | 两个工具链兼容加固的插件副本（`dependency_overrides` 指向，见根 README） |
| `windows/` `android/` | 平台工程（含 WebView2 本地访问开关与 compileSdk 对齐） |
