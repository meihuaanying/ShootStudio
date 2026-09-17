# 第三方组件与许可声明（3D 引擎）

本目录下的 3D 预演引擎为自研实现，集成了以下 MIT 许可的第三方组件/语义参考：

| 组件 | 版本/来源 | 许可 | 使用方式 |
| --- | --- | --- | --- |
| three.js | r169（npm `three`，经 npmmirror 获取） | MIT | 运行时 3D 渲染（`js/vendor/three.module.min.js`） |
| OrbitControls / RectAreaLightUniformsLib / RoomEnvironment | three.js examples（r169） | MIT | 相机轨道控制、面光源、环境反射 |
| direct-light | https://github.com/oukeming64-tech/direct-light | MIT（Copyright (c) 2026 Keming Ou） | **领域语义改编**：灯具预设、控光件乘数、白棚沟通级渲染理念、姿势参数语义；代码由 React/R3F 重写为无框架 three.js 单页 |

- three.js 许可全文见 `js/vendor/THREE_LICENSE`。
- direct-light 许可全文见 `DIRECT_LIGHT_LICENSE`。
- 人像模型为自研关节假人（`js/person.js`），未使用任何第三方角色模型资产。
