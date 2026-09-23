# three.js r169 → r186 升级渲染对比（V7/S3.1）

> 目的：纯迁移验证（不加特性）。方法：`light_preset_qa.mjs` 用同一 `qa.html` 分别以 r169 旧包与 r186 新包渲染全部 27 套预设，逐图计算像素差。
> 结论：**27/27 渲染成功、0 失败（前后一致）**；平均像素差 6.69/255（≈2.6%），最大 clamshell 11.84（软光/间接光占比高的预设）。
> 差异来源（预期内）：r181「PBR 能量守恒（roughness>0.5 更亮）」+ PMREM 反射改进 + r183 材质光照重构；几何/灯位/光型无变化。
> 处理：接受（物理更正确，无失败/崩溃）；观感微调在 S3.2 真实感阶段统一进行。
> 复现：`node tool/light_preset_qa.mjs --bundle <旧包> --suffix r169` + `node tool/light_preset_qa.mjs --suffix r186`；本机内存/缓存门禁 `engine_mem_qa.mjs` 亦通过（LRU PASS，堆增长 PASS，first=54.8 peak=82.9 last=43.3 MB）。

| preset | meanAbsDiff | pctPixels>8 |
| --- | --- | --- |
| clamshell | 11.84 | 56.04% |
| low-key | 9.27 | 24.86% |
| top-drama | 9.12 | 24.81% |
| hard-contrast | 9.04 | 24.02% |
| split | 8.57 | 22.50% |
| dual-color | 8.30 | 23.13% |
| stage-spot | 8.16 | 22.61% |
| prop-reflector | 8.12 | 20.57% |
| gel-party | 7.90 | 21.32% |
| rim-double | 7.86 | 24.78% |
| neon-night | 6.86 | 22.24% |
| side-rim | 6.35 | 21.20% |
| rembrandt | 6.35 | 19.95% |
| hanfu-window | 6.29 | 22.84% |
| butterfly | 6.14 | 19.04% |
| couple | 6.10 | 21.74% |
| beauty-top | 6.05 | 16.75% |
| loop | 5.67 | 16.49% |
| hair-light | 5.41 | 16.93% |
| split-rim | 5.36 | 16.50% |
| window-light | 5.30 | 20.52% |
| documentary | 5.07 | 16.78% |
| cos-rim | 4.94 | 15.67% |
| overcast | 4.79 | 17.68% |
| three-point | 4.75 | 15.29% |
| high-key | 3.47 | 12.55% |
| dual-soft | 3.46 | 11.75% |

- 证据图：`docs/screenshots/lighting-v6/<preset>-r186.png`（新基线 27 张）；r169 对照图与 `qa-r169.json` 保留于工作区历史。
- 引擎包：984KB（r169）→ 约 1.0MB（r186，含自包含 minified ESM 构建）。
