# A0 自适应基线组件覆盖矩阵

更新时间：2026-05-13

## 0. 使用口径

| 级别 | 含义 |
| --- | --- |
| 必须使用 | 新页面和大改页面默认使用；绕过需要写例外原因 |
| 推荐使用 | 优先使用；特殊交互可以保留 feature 专用组件 |
| 允许例外 | 低频、沉浸式、WebView、验证页等可保留专用实现 |

## 1. 覆盖矩阵

| 场景 | 基线组件/模型 | 级别 | 允许例外 |
| --- | --- | --- | --- |
| 普通页面骨架 | `AdaptivePageScaffold` | 必须使用 | 主壳、阅读器、启动页、WebView/验证页 |
| 内容最大宽度 | `AdaptiveContentContainer`、`AppSizeTokens` | 必须使用 | 全屏画布、阅读器正文 |
| 搜索输入 | `AdaptiveSearchBar` | 推荐使用 | 复杂富搜索编辑器 |
| 筛选/排序 | `AdaptiveFilterBar`、adaptive action surface | 推荐使用 | 阅读器内浮层 |
| 设置项 | `AdaptiveSettingTile` / `AdaptiveSettingSection` | 必须使用 | 特殊编辑器画布 |
| 普通列表项 | `AdaptiveListTile` 或 feature 专用 tile | 推荐使用 | 高度定制卡片 |
| 网格 | `AdaptiveGridSliver` 或 builder/sliver grid | 推荐使用 | 固定棋盘/编辑器 |
| 空状态 | `AppEmptyStateCard` | 必须使用 | 阅读器沉浸空态 |
| 错误/加载/禁用 | `AppStatusStateCard`、`FeatureDisabledPage` | 必须使用 | 内联轻提示 |
| 弹层 | `showAdaptiveActionSurface` / `AdaptiveBottomSheet` / `AdaptiveDialogSurface` | 必须使用 | 阅读器由 `ReaderLayoutContext` 决策 |
| 封面 | `ResolvedBookCoverView` | 推荐使用 | 纯文本占位生成器 |
| 任务态 | `AppTaskStatusData`，后续接 task manager | 必须使用 | 纯瞬时按钮 loading |
| 图像资源 | `LazyFileImage` / 带 cacheWidth/cacheHeight 的图片组件 | 必须使用 | 小型静态 asset |

## 2. 组件 API 补强清单

- [x] `AdaptiveListTile` 检查 leading / trailing / subtitle / selected / hover / focus 能力是否覆盖常见页面。
- [x] `AdaptiveSettingTile` 检查 switch、slider、dropdown、stepper、文本按钮组合。
- [x] `AdaptiveActionSurface` 检查桌面 side panel、popover 与居中 dialog 的选择策略。
- [x] `AdaptiveContentContainer` 接入 `AppSizeTokens` 的默认内容宽度阶梯。
- [ ] `AppTaskStatusData` 后续接任务队列、取消、重试和恢复。

本轮补强：

- `AdaptiveListTile` 增加 `enabled`、`selected`、`dense`、`onLongPress`、focus/autofocus/mouseCursor。
- `AdaptiveSettingTile` 增加 `onTap`、`onLongPress`、`enabled`、`dense`、`padding`。
- `AdaptiveContentContainer` 默认使用 `AppSizeTokens.defaultContentMaxWidthForWidth`。

## 3. Review 问题

- 这个页面是否可以用现有骨架组件？
- 内容在 1280x800 是否被无限拉宽？
- 弹层在桌面/Web 是否仍是移动端 bottom sheet？
- 空、加载、错误、禁用是否用了统一组件？
- 列表是否可能增长到需要 builder/sliver？
- 是否有页面内平台判断可以改成 capability？
- 是否有散落字号、触控尺寸或内容宽度常量可以改成 token？
