# A0 自适应 UI 反模式清单

更新时间：2026-05-13

## 0. 一票否决

以下做法新增时必须拦截：

- 页面直接依赖 `Platform.isAndroid / Platform.isIOS / Platform.isMacOS / kIsWeb` 决定能力入口。
- 不支持平台仍展示可点击但必失败的入口。
- 新普通页面裸写 `Scaffold` 且无例外说明。
- 新筛选、设置、资源选择、详情操作直接调用 `showModalBottomSheet`。
- 页面级加载只放一个居中 `CircularProgressIndicator`，没有统一状态组件或上下文。
- 长列表使用 `ListView(children: [...])` 或一次性构建大量卡片。
- 页面 build 中同步读文件字节、扫描目录、读取大量图片 metadata。

## 1. 需要 review 的反模式

| 反模式 | 风险 | 替代方案 |
| --- | --- | --- |
| 散落字号常量 | 多端不一致，大字体难验收 | `AppTypography` 或 theme textTheme |
| 散落内容最大宽度 | 桌面拉伸或平板过窄 | `AppSizeTokens` / `AdaptiveContentContainer` |
| 移动端 bottom sheet 硬套桌面 | 大屏体验奇怪 | adaptive surface |
| 业务页面手写 Row + Column 列表项 | hover/focus/语义缺失 | `AdaptiveListTile` 或 feature tile |
| 资源页进入即全量扫描目录 | 首屏卡顿 | 轻量 index + 展开/可见项加载 |
| 任务态只存在局部 setState | 跨页面不可见，不可恢复 | `AppTaskStatusData` + task manager |
| 阅读器使用普通页面宽度规则 | 正文行宽不舒适 | `ReaderLayoutContext` |

## 2. 例外流程

允许例外的页面必须在对应计划或页面注释中写清：

- 为什么不能使用基线组件。
- 影响哪些平台。
- 如何覆盖 SafeArea、键盘 inset、最大宽度和大字体。
- 回收条件是什么。

## 3. 自动检查目标

`tool/check_ui_component_governance.dart` 先以 warning 方式暴露以下问题：

- 裸 `Scaffold`
- 直接 `showModalBottomSheet`
- 直接 `showDialog`
- 页面内 `Platform.isXxx / kIsWeb`
- 长列表 `ListView(children)`
- 可疑页面级 `CircularProgressIndicator`
- `LayoutBuilder` 中疑似副作用

后续在新增页面模板稳定后，再考虑对部分反模式启用 `--fail-on-warning`。
