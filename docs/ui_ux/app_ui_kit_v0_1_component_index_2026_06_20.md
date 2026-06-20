# App UI Kit v0.1 组件索引

日期: 2026-06-20
目标: 让新增页面先查标准组件，减少本地硬编码样式继续扩散。

## 基础组件

| 组件 | 用途 | 替代旧写法 |
|---|---|---|
| `AppButton` | 标准按钮、危险按钮、loading 按钮 | 裸 `FilledButton/OutlinedButton/TextButton` 拼样式 |
| `AppTextField` | 输入框、搜索输入、错误输入 | 本地 `TextField + InputDecoration` |
| `AppDropdownField` | 下拉选择 | 本地 `DropdownMenu` 样式 |
| `AppMenuButton` | 更多菜单、资源操作菜单 | 本地 Popup/Menu 组合 |
| `AppSelectionIndicator` | 选中态标识 | 本地 check icon/chip |

## 状态与进度

| 组件 | 用途 | 备注 |
|---|---|---|
| `AppStateView` | loading、refreshing、empty、filteredEmpty、error、locked、offline、progress、content | 新页面状态入口默认用它 |
| `AppEmptyStateCard` | 单独空态卡片 | 可继续用于已有页面 |
| `AppStatusStateCard` | 错误、警告、中性状态 | 可继续用于已有页面 |
| `AppProgressIndicator` | 语义化圆形/线性进度 | 替代裸 progress indicator |
| `AppInlineProgress` | 行内同步/解析/导入进度 | 适合列表项、任务行 |
| `AppBlockingProgressCard` | 页面级 blocking 任务 | 适合导入、导出、批处理 |
| `AppTaskProgressRow` | 可取消任务行 | 适合任务队列 |

## 表面与布局

| 组件 | 用途 | 替代旧写法 |
|---|---|---|
| `AppSurface` | token 化表面容器 | `Container + BoxDecoration` |
| `AppPanel` | 带标题/说明/操作的面板 | 页面局部卡片 |
| `AppSection` | 设置分组、资源分组 | 本地分组容器 |
| `AdaptiveCard` | 已有自适应卡片 | 保留用于已迁移页面 |
| `AdaptivePageScaffold` | 自适应页面骨架 | 新页面优先使用 |
| `AdaptiveBottomSheet` | 自适应弹层 | 本地 bottom sheet 样式 |

## 迁移优先级

1. 新增代码必须优先使用本索引组件。
2. 高级主题、启动图集、底栏图集、封面图集、背景资源页优先迁移 `AppSurface` 和 `AppStateView`。
3. Mine 首页、Bookshelf 外围、Reader chrome 后续分批迁移，避免一次触碰核心业务链路。

## 允许业务自定义

- 封面生成色板、阅读器翻页透明层、全屏图片预览遮罩可以保留固定视觉。
- 业务组件可以传入 icon、title、description、actions，但不应重写 radius、shadow、border token。
- 需要自定义表面视觉时，优先扩展 App 组件参数，再考虑页面局部实现。
