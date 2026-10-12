# V8.5 / P2-3 引擎性能门禁修订：拆掉随机红，保留真回归判据

> 起因：tag `v8.4.0` 触发的 CI run [`38109551427`](https://github.com/meihuaanying/ShootStudio/actions/runs/38109551427)
> 在 `Engine perf gate` job 上 **failure**。本阶段定位、修订并验证该门禁。

## 1. 先排除「是不是 v8.4.0 把引擎改坏了」

v8.4.0 的全部改动是 `app/test/features/p2_a11y_test.dart` + 一份 QA 报告，
**没有任何 lib/ 或 assets/engine/ 改动**；同一条门禁在 v8.3.0 上是绿的。
→ 判定为门禁自身问题，不是产品回归。这一步必须做在前面，否则会去改无辜的代码。

## 2. 失败现场的读数

```
FAIL idle  引擎有出帧          :: engineFrames=0
FAIL dolly 引擎有出帧          :: engineFrames=0
FAIL idle/dolly 帧数未灾难回退 (>= 1)
FAIL idle/dolly 的 mean / fpsMean 为数值
[perf-gate] FAIL (8)
```
同时：`PASS orbit engineFrames=1`、`PASS lightDrag engineFrames=1`
—— **渲染循环明明是活的**。

## 3. 根因一：判据本身在 GPU-less 上测不准

引擎是**连续 rAF 循环**（`assets/engine/js/engine.js:1483`：

```js
if (!paused) { ... renderer.render(scene, camera); ... }
requestAnimationFrame(frame);
```

即 idle 段也该持续出帧），但在 headless 下 rAF 的触发取决于页面是否被浏览器
当作可见/前台，而 SwiftShader 下 fps 只有 0.6–1.8（V8-s2 入库基线
`v8-s2-engine-perf-swiftshader-dpr1.json`：idle 2 帧 / orbit 3 帧 /
lightDrag 3 帧 / dolly 1 帧，p95 > 1.4s）。

于是「某一段 2 秒窗口里一帧都没采到」是**二值噪音**，与性能回归无关，
而基线本身只有 1~3 帧、与噪音底噪同量级 —— 拿它当硬阈值等于抛硬币。

**本机实测证据**（`node tool/engine_perf_gate.mjs`，PERF_GATE_ATTEMPTS=5）：

```
[尝试 1/5] exit=0 逐相位帧数=?/?/?/?  总帧数=4
[尝试 2/5] exit=0 逐相位帧数=2/1/1/1  总帧数=5   ← 被选为代表运行
```

同机连续两次尝试总帧数 4 → 5，差出整整一个相位。初版门禁（单次测量 +
逐相位硬判）在这一步的红/绿概率接近抛硬币。

## 4. 根因二：一个**真空**的数值判据

```js
check(`${ph}.${k} 为数值`, Number.isFinite(Number(v[k])), ...)  // 原版
```

`Number(null) === 0`，而 `0` 是有限数 → 该检查对 `null` **永久通过**。
CI 日志里 `PASS idle.p50 为数值 :: null` 正是这个洞：p50 明明是空的，
却报 PASS。单独用例验证：

| value | 旧写法 | 新写法 |
|---|---|---|
| `null` | **true（假通过）** | false |
| `undefined` | false | false |
| `0` / `2584` / `3093.6` / `-1` | true | true |
| `'12'`（字符串） | true | **false** |
| `NaN` / `Infinity` | false | false |

改为 `typeof v === 'number' && Number.isFinite(v)` 后，`null` 与 `'12'` 这类
都会被正确判为「不是数值」。

## 5. 修订后的门禁

**硬判**（CI 真能稳定抓到）：

1. 测量进程 `exit === 0`、输出 JSON 存在且可解析；
2. 无 `error` 字段；
3. `warmup.settled === true`；
4. `lightPoint.ok === true`（拖拽采到的确实是灯，不是冷启动抖动）；
5. **整次测量总帧数 > 0** —— 渲染循环是否活着（真回归会让四相位同时归零）；
6. 出了帧的相位，统计字段齐全且为数值。

**只登记不判红**（打印 `NOTE` 并写进入库证据）：逐相位 `engineFrames` 与
SwiftShader 基线的差距、总帧数对照。

**多次尝试**：默认最多 5 次（`PERF_GATE_ATTEMPTS` 可覆盖），
取第一个「四相位全出帧且统计齐全」的健康运行；没有则取总帧数最多的一次作代表。
每次尝试各写一份 `docs/qa/v8-s2-engine-perf-ci-gate-<n>.json`，全部进 CI artifact。

### 为什么把判据从「逐相位」换成「总帧数」

真回归（渲染循环被打断）→ 四个相位同时归零 → 总帧数判据照样红。
噪音 → 只有个别相位归零 → 总帧数判据不误伤。
区别是确定的：**死循环不存在「有时活有时死」**。

## 6. 反向验证（证明门禁不是装饰）

把 `tool/engine_perf_qa.mjs` 临时换成只写「四相位全 0 帧」JSON 的替身
（跑完即恢复，`git diff app/tool/engine_perf_qa.mjs` 为空 = 已还原）：

```
[stub] wrote dead-loop json for ci-gate-1
[stub] wrote dead-loop json for ci-gate-2
  NOTE 未出现四相位全出帧的健康运行 :: 最好一次总帧数=0（尝试 2 次）
  FAIL 渲染循环有出帧（总帧数 > 0）:: 代表运行总帧数=0，全部尝试总帧数=0/0
[perf-gate] FAIL (1)      EXITCODE=1
```

对照正常测量：`[perf-gate] PASS`、`EXITCODE=0`。一红一绿区分明确。

## 7. 顺带修的工程细节

- `ci.yml` 的 `engine-gate`：step 改名反映真实口径
  （`Engine perf gate (link + render loop alive + stats)`）、加
  `PERF_GATE_ATTEMPTS: '5'`、artifact 路径改为
  `docs/qa/v8-s2-engine-perf-ci-gate.json` + `docs/qa/v8-s2-engine-perf-ci-gate-*.json`
  两个通配（否则只上传到旧的单份文件名，多次尝试的实测会丢）。
- `.gitignore`：`docs/qa/v8-s2-engine-perf-ci-gate.json` →
  `docs/qa/v8-s2-engine-perf-ci-gate*.json`；不加通配的话每次 CI 都会把
  `ci-gate-1.json` 之类拱成未跟踪文件。

## 8. 门禁实测（本轮全部重跑）

| 门禁 | 结果 |
|---|---|
| `dart format lib test` | 255 files **0 changed** |
| `flutter analyze --no-pub --fatal-infos` | No issues found (18.8s) |
| `flutter test --no-pub` | **535 passed + 34 skipped**，`EXITCODE=0` |
| `node tool/check_file_size.mjs` | PASS（门禁脚本 212 行，仍在限额内） |
| `node tool/check_tokens.mjs` | PASS（自造色值 / 内置色板 / 字号字重 / 间距圆角全 0） |
| `node --check tool/engine_perf_gate.mjs` | 语法通过 |
| 引擎门禁（本机实测 ×2 次尝试） | **PASS / EXITCODE=0** |
| 反向验证（死循环替身） | **FAIL (1) / EXITCODE=1** |

本轮无 Dart 改动，`535 passed + 34 skipped` 与 v8.4.0 完全一致 ——
用例数没降、没有删断言（R79）。

## 9. 明说的代价

门禁比初版松。松在「逐相位帧数」这种在 GPU-less 下**测不准**的量上，
换来的是不再随机红、不再无谓阻挡合入。绝对帧耗时与逐相位帧数**仍是人工判据**：
改渲染路径后按 `app/tool/engine_perf_gate.mjs` 文件头口径，在独显机上手动跑
`node tool/engine_perf_qa.mjs --label <说明>` 并把 JSON 入库对照。
已作为**偏差 9** 登记进 `docs/qa/v8-r71-deviations.md`（含「拿到 GPU runner
后恢复硬判并重录基线」的修复条件）。
