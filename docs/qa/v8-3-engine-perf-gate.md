# V8.3 引擎性能门禁入 CI（P2-1）

> 阶段目标：把「引擎性能只有本机手动跑、不入 CI、无回归阈值」这个测试类型缺口补上。
> 交付 `app/tool/engine_perf_gate.mjs` + `.github/workflows/ci.yml` 的新 `engine-gate` job。

---

## 1. 先弄清一件事：CI 上能门禁什么、不能门禁什么

合同 D152 写「拖动灯具 p95 帧耗时 ≤16ms，记录实测；达不到则在 spike 报告说明并给降档策略」。
该口径是**有独显的真实工作机**口径，S2 spike 已实测登记：

| 基线文件 | 环境 | lightDrag p95 |
|---|---|---|
| `v8-s2-engine-perf-gtx4060-dpr1.json` | RTX 4060 Laptop / D3D11 headed | 17.5ms |
| `v8-s2-engine-perf-swiftshader-dpr1.json` | SwiftShader 软渲染 headless | **1554.8ms** |

看软渲染那一行的完整数据：

```
idle      engineFrames=2  p50=1500.2 p95=1500.2
orbit     engineFrames=3  p50=1528.6 p95=1574.1
lightDrag engineFrames=3  p50=1536.7 p95=1554.8
dolly     engineFrames=1  p50=1469.4 p95=1469.4   fps=0.7
```

**每段只有 1~3 个采样点、p95 超过 1.4 秒。** 这个数字既不是「引擎慢」也不是「GPU 不行」，
而是**统计上无意义** —— 样本量 3 的时候谈 p95 没有意义。

所以在 GPU-less 的 runner 上设「p95 ≤ N ms」阈值，无论 N 取多少都是**假门禁**：
- N 定得宽（比如 2000ms）→ 永远绿，纯装饰，还会让人误以为性能被守护了；
- N 定得严（比如 100ms）→ 永远红，挡住所有合入。

**因此本门禁刻意不设绝对帧耗时阈值。** 这是有实测依据的取舍，不是「放宽标准」。
合同 D152 的 16ms 口径继续由「独显机手动跑 + JSON 入库 + 偏差登记」承担，
本门禁不去假装自己能做到这件事。

## 2. 本门禁真正守什么

换成「CI 真能抓到的那些回归」：

| 断言 | 抓什么 |
|---|---|
| 测量进程 exit 0 | Edge 起不来 / CDP 连不上 / 引擎页加载失败 |
| `error` 字段为 null | 测量脚本自身抛错 |
| `warmup.settled === true` | 采的是冷启动抖动而非稳态 |
| `lightPoint.ok === true` | 灯体拖拽没命中灯，交互采样失真 |
| 每 phase `engineFrames > 0` | **渲染循环真的被打断**（这条是核心） |
| 每 phase p50/p95/p99/max/mean/fpsMean/cpuMsPerFrame 均为数值 | 有人把 `stats()` 改坏 |
| 帧数 ≥ 入库基线的 50% | 相对回退（见下） |

**帧数地板为什么有意义**：软渲染基线本身只有 1~3 帧，所以「基线的 50%」实义是
「从 3 帧掉到 0~1 帧」。如果哪天渲染循环真被打断（比如 `requestAnimationFrame` 挂了），
`engineFrames` 会归零，这条立刻红。

## 3. 反向验证（证明它不是装饰）

把输出的 `phases.idle.engineFrames` 与 `phases.orbit.engineFrames` 改成 0：

```
FAIL dolly 引擎有出帧 :: engineFrames=0
FAIL dolly.mean 为数值 :: undefined
FAIL dolly.fpsMean 为数值 :: undefined
FAIL dolly 帧数未灾难回退 (>= 1) :: baseline=1 now=0
[perf-gate] FAIL (4)
Exited with code 1
```

注入故障后四条断言同时抓到并 `exit 1` —— 门禁真的能失败。

## 4. 顺手修掉 `engine_perf_qa.mjs` 的两个可移植性缺陷

要让它在 Linux CI 上跑，必须先修（这两个坑与 `shot_s10.mjs` 在 V8.1 踩的是同一类）：

1. **Edge 路径只列 Windows**（原 :50-53）→ 改为按平台解析
   （win32 / darwin / linux 三组候选 + `SS_EDGE` 环境变量覆盖）。
2. **直接用全局 `WebSocket`**（原 :150）→ 改为运行时依次解析
   （`node:http` 导出 → 全局 → 都没有则报可读错误并 exit 2）。
   本机是 Node v24，两种来源都在，所以本地跑得过；CI 用 Node 22 也走 `SS_EDGE`
   + 22 的全局，但**不依赖这个巧合**。
3. Linux 下追加 `--no-sandbox`（容器内无授权进程组，headless Edge 起不来）。

## 5. CI job 设计

`engine-gate`（runs-on: ubuntu-latest，`needs: []` 与 analyze-test 并行）：

- `node-version: 22`（与 website-gate 同因：CDP 需要 WebSocket，Node 20 拿不到 ——
  这条已在 V8.1.1/V8.1.2 用三次失败换来过）
- 装 `microsoft-edge-stable`
- `node tool/engine_perf_gate.mjs`（内部以 `--headless=1 --swiftshader=1`
  + 短时段 `--idle=2 --drag=2 --wheel=1 --warmup=4` 跑，控制在 CI 预算内）
- `if: always()` 上传 `docs/qa/v8-s2-engine-perf-ci-gate.json` 作为产物留档
  （retention 14 天），便于人工复核软渲染环境下的绝对数字

产物文件已加入 `.gitignore`：每次 run 重算、数值随机器抖，进 git 只会制造噪音。
**入库的 swiftshader 基线仍是提交的**，它是「帧数地板」的参照点。

## 6. 不做什么

- **不加 App 侧任何测试**：本 job 是 Node 侧的门禁，与 Flutter 测试无关，
  `flutter test` 数量不变（仍 532 passed + 34 skipped）。
- **不给绝对帧耗时设阈值**：理由见 §1，这是结论不是省略。
