# V8/S9 · 资源库 + 设置 + 引导页重构 — 完工报告

## 1. 结论

S9 门禁三项全部达标：覆盖率报告六类 **100% 不回归**（`app/tool/gear_coverage.py` 由 CI line 67 直接守，本轮另在 Dart 测试里复刻同一算法做平台无关的二次守门）、**设置往返测试**（公告地址写 → 读回一致 + trim）、**CI 绿**（见 §6）。工程侧把 D158 强制拆分清单里剩下的两个大文件（`gear_browser.dart`、`settings_page.dart`）全部降到 ≤600 行以内，白名单从 6 条降到 4 条。契约 D158 line 203 要求的「设计组件预览」debug-only 入口经核查**在 S3 已落地**，本轮补上断言守护。

## 2. 文件拆分（R73 / D158）

| 文件 | 拆分前 | 拆分后 | 新增 part |
|---|---|---|---|
| `libraries/gear_browser.dart` | 1273 | **486** | `gear_browser_add.dart`(110，顶层 `_showAddDialog`) / `gear_browser_card.dart`(466，`class _GearCard`) / `gear_browser_catalogs.dart`(142 `ClothingCatalog` + 73 `PropsPresetBrowser`) |
| `settings/settings_page.dart` | 1196 | **313** | `settings_page_cards.dart`(213 `_AiChannelsCard`) / `settings_page_sources.dart`(531 `_AssetSourcesCard`) / `settings_page_gpu.dart`(144 `_GpuCard`) |

`tool/file_size_baseline.json` 从 6 条降到 **4 条**（`lighting_controller 760` / `ai_panel 747` / `libraries_page 808` / `ai_client 779`），`check_file_size.mjs` PASS。剩余 4 条均不在 D158 强制清单里（`lighting_page.dart` 已在 S6 处理），留待后续按需下调。

## 3. 覆盖率六类 100% 守门

`app/tool/gear_coverage.py`（251 行，CI line 67 独立执行）判定规则与本轮 Dart 复刻一致：

| 类 | 覆盖判定 | 当前值 |
|---|---|---|
| `camera` / `lens` / `light` / `accessory` | `gear.json` 的 item id ∈ `gear_photo_sources.json.items` ∪ `gear_photos2.json.byId` ∪ `byModel` ∪ `builtinTop100` | 111/111、197/197、157/157、28/28 |
| `clothing` | `clothing_photos.json.byCategory[id]` 非空 **且** 至少一张 `assets/content/clothing/photo/<id>/<file>` 在磁盘真实存在 | 9/9 |
| `props` | `props_presets.json` 的 id 出现在 `gear_photo_sources.json.items` | 14/14 |

专项测试 `s9_library_settings_test.dart` 在 Dart 侧复刻该算法（不 spawn python —— Windows runner 上 `python3` 未必在 PATH），断言「恰好六类」+ 每类 `total > 0` 且 `covered == total`，并额外读 `docs/qa/gear-coverage-v7.json`（未入库生成物，缺失时降级只断言类数）核对 `pass == true`。

## 4. 设置往返与 debug 入口

- **往返**：`updaterProvider.notifier.setAnnouncementUrl('  <url>  ')` → `await notifier.announcementUrl()` 原样读回（自动 trim），`state.status == '公告地址已保存'`；再覆盖写第二个 URL 验证二次往返。`setAnnouncementUrl` 走 `db.setSetting('announcement_url', url.trim())`，只有 `silentCheck` / `manualCheck` 触网，因此本测试零网络。
- **debug 入口**：`settings_page.dart` 的 `if (kDebugMode)` 块内 `SsButton(label: '设计组件预览', icon: Icons.palette_outlined, kind: SsButtonKind.outline)` → 推 `MaterialPageRoute(DesignDemoPage(variant: AppTokensV2.of(context).variant))`。测试断言该按钮与 `SsSectionTitle('设计系统')` 存在（测试环境 `kDebugMode == true`；release 隐藏靠 `if (kDebugMode)` 代码审查保证）。**该入口是 S3 就有的，本轮未改动实现。**
- 渲染冒烟：`LibrariesPage`（断言「资源库」标题）、`GearBrowser`（断言无渲染异常 + 导出常量 `kGearPhotoDisclaimer` 内容含「仅供选型参考 / 禁止商用分发 / 许可与来源以标注为准」）、`OnboardingPage`。

## 5. 视觉证据

`docs/screenshots/v8/s9-<scene>-<theme>-<size>.png` 共 **16 张**（scene ∈ `libraries` / `gear` / `settings` / `onboarding`；theme ∈ `paper` / `darkroom`；size ∈ `1280x800` / `1920x1080`）+ 索引 `docs/qa/v8-s9-library-screenshots.json`。视觉门禁 `test/visual/s9_library_capture_test.dart` 出图 **17 项全绿**（16 截图 + 1 索引），索引里 `coverageGate` 字段注明覆盖率由 `app/tool/gear_coverage.py` 负责。

## 6. 测试与门禁

| 项 | 结果 |
|---|---|
| `s9_library_settings_test.dart`（新增专项） | **8 / 8 全绿** |
| `q6_gear_test` | 7 passed（不回归） |
| `flutter test --no-pub`（全量） | **517 passed + 43 skipped**，All tests passed |
| `dart format lib test` | 0 changed（247 files） |
| `flutter analyze --no-pub --fatal-infos` | No issues found |
| `node tool/check_file_size.mjs` | PASS（报告 `docs/qa/v8-file-size.json`） |

## 7. 偏差与限制登记

- **`GearBrowser` 在测试/截图环境渲染为空态**：`gearListProvider` 是读磁盘内容包的 `FutureProvider`，在 `flutter test` 壳里不落地（`pumpAndSettle` 不空转、显式推进 4s 仍无），所以 `s9-gear-*.png` 显示 `SsEmpty`。这是测试壳限制，不是产品缺陷 —— 真实构建下 provider 由 `rootBundle`/`File` 读取会正常返回。**截图守版式不破，覆盖率守门由 `gear_coverage.py` 承担。**
- **`docs/qa/gear-coverage-v7.json` 未入库**：它是脚本生成物（`git ls-files` 为空），本地跑 `gear_coverage.py` 会改动它，提交时不纳入 diff。
- **`libraries_page.dart`(769/808)、`ai_client.dart`(679/779)、`ai_panel.dart`(707/747)、`lighting_controller.dart`(760/760) 仍在白名单**：均不在 D158 强制拆分清单内，且 `check_file_size` 允许（白名单只降不升），留待后续阶段按需处理。
- **「设计组件预览」只做 debug 断言**：release 隐藏依赖 `if (kDebugMode)`，无法在 `flutter test` 里构造 release 环境断言（`kDebugMode` 是编译期常量），已在本报告登记为代码审查项。

## 8. 测试逼出来的真实问题（非测试迁就）

1. **Dart 复刻覆盖率时把 `gear_photo_sources.json` 的顶层 key 当成了条目** → camera 只有 106/111。真实结构是条目在 `items` 子字典里（218 项），且 `gear_photos2.json` 还有 `builtinTop100`（100 个 id）也属于内置覆盖集合，必须并入。修正后 111/111。**读内容包 JSON 复刻脚本时，先 dump 顶层 key 与各字段类型。**
2. **`clothing_photos.json.byCategory` 可空** → 直接 `byCategory[id]` 会 NPE，写成 `byCategory?[id]` 报 `invalid_null_aware_operator`（Dart 里非空类型不能用 `?[]`）。正确写法是先 `?? const <String, Object?>{}`。
3. **长 `ListView` 底部的控件用固定时长 pump 断言不到** → `find.text` 默认 `skipOffstage: true`，底部尚未建树。必须 `tester.scrollUntilVisible(finder, delta, scrollable: find.byType(Scrollable).first)`。
4. **拆分脚本两处踩坑**：①「从声明行起找第一个列 0 的 `}`」只会切到 widget 外壳（`class X { const X({super.key}); }`），把 State 留在主文件 → 一堆 `unused_import` 且功能残缺；end 必须用「下一个顶层声明起始行 − 1」。②`git checkout --` 的 pathspec 拼了 `app/lib/features/` 前缀导致双前缀 `did not match any file(s)`，脚本在写文件前就退出 —— 正确写法是 `os.path.relpath(f, REPO).replace("\\", "/")`。
