# UI 与自适应设计规则

更新时间：2026-06-06

本文定义 UI、响应式布局、自适应交互和视觉 token 的编写规则。目标是让每个平台都像原生使用场景，而不是把同一张移动端页面强行拉伸。

本项目布局术语统一如下：**响应式布局** 是实现手段，负责通过断点、弹性布局和可用空间计算，让 UI 随窗口或屏幕尺寸变化；**自适应应用** 是最终目标，负责让手机、平板、折叠屏、Web 大屏和桌面端都呈现符合自身设备习惯的结构和交互。移动端同样需要响应式布局，但验收时更关注是否保留成熟触控体验；桌面端和 Web 大屏则额外强调窗口拖拽后的实时布局变化。

## 1. UI 最高原则

- 移动端保持成熟体验。
- 桌面端提高信息密度、键鼠效率和宽屏利用率。
- Web 端优先保证可访问、可刷新、可降级。
- 同一业务可以多套外观，但状态、业务规则和数据语义必须共享。
- 页面不直接硬编码大量尺寸、圆角、颜色和阴影。

## 2. 断点规则

项目统一使用逻辑宽度，不按设备型号写适配。

| 范围 | 语义 | 推荐布局 |
| --- | --- | --- |
| `< 390` | compact phone | 紧凑移动布局 |
| `390 - 479` | large phone | 常规移动布局 |
| `480 - 599` | phone xl / 横屏小屏 | 移动增强布局 |
| `600 - 839` | medium | 可使用 rail、双列或更宽内容 |
| `>= 840` | expanded | 桌面/大屏布局 |
| `>= 1200` | desktop | 侧栏、多栏、宽内容 |
| `>= 1600` | wide desktop | 更高信息密度，但内容仍有最大宽度 |

新代码优先使用：

- `AppLayout`
- `AppAdaptiveMetrics`
- `AdaptivePageScaffold`
- `AdaptiveContentContainer`
- `AdaptiveSplitBody`
- `AdaptiveGridSliver`
- `AdaptiveOverflowToolbar`
- `AdaptiveBottomSheet`

## 3. 禁止的适配方式

禁止：

- 按 `iPhone 15`、`Pixel 8`、`Galaxy S24` 等设备型号写布局。
- 页面里到处写 `SizedBox(height: 120)` 这类不解释的固定尺寸。
- 桌面端继续使用移动端 bottom sheet 作为主要操作面。
- 宽屏内容无限拉宽。
- 小屏文字、按钮、卡片互相遮挡。
- 新增 UI 不接入主题 token。

## 4. 移动端 UI 规则

Android / iOS 默认保持成熟移动端体验：

- 一级导航、系统返回、iOS 返回手势、Android 返回键、阅读器手势和 bottom nav 不因 Web / Desktop 适配改变。
- 页面需要处理 Safe Area、状态栏、底部手势区、软键盘、横竖屏、文字缩放和触控命中区域。
- 移动端主要操作优先使用触控友好的 AppBar、bottom sheet、菜单、显式按钮和系统能力入口。
- 移动端专属能力如相册 / 文件选择、系统分享、支付、WebView、亮度、音量键、触感，需要按 capability 展示并有失败文案。
- 共享 adaptive 组件改动必须检查 390dp 以下、390 - 479、480 - 599 的移动端表现，不能只验证 840dp 以上宽屏。
- 桌面端 UI 任务不得为了复用工具栏、菜单、搜索框或排序逻辑，改写移动端 AppBar、bottom sheet、更多菜单、搜索入口、选择模式和触控路径。
- 如果桌面端需要使用共用页面里的业务动作，应通过桌面顶栏、popover、desktop provider 或 adapter 注册动作；移动端原有 widget 树和交互入口保持等价。

## 5. 桌面 UI 规则

桌面端优先使用：

- 左侧导航或 topbar。
- 主从分栏。
- 列表 + 详情面板。
- 表格、网格、筛选栏、工具栏。
- dialog、popover、side panel、command surface。
- hover、focus、selected、disabled 状态。
- 键盘快捷键、右键菜单、滚轮。

桌面端响应式规则：

- 不能只按“桌面端”写一套固定宽度 UI，必须覆盖窄窗口、常规桌面和宽屏桌面的变化。
- 原生桌面窗口最小宽度必须小于 `600dp`；否则 macOS / Windows / Linux 调试时拖不到关键断点，Web 可验证但原生桌面不可验证。
- 侧边栏负责全局导航和当前模块的一级筛选；顶栏负责当前页面工具和账号、主题、设置等轻操作；内容区负责列表、详情和结果区域的列数变化。
- 窄窗口下优先收窄侧边栏、折叠顶栏工具、降级为单列内容；宽屏下可以提升信息密度，但内容仍必须受最大宽度约束。
- 书架、在线搜索、详情、阅读器等桌面页面需要按实际内容宽度判断单列、双列、三列，而不是只看平台。

移动端响应式与自适应规则：

- Android / iOS 页面同样使用响应式布局处理小屏、大屏、横屏、平板和折叠屏变化。
- 移动端自适应目标不是复制桌面端结构，而是在不同移动设备上继续保持触控、手势、底部弹层、系统返回、安全区和软键盘体验自然。
- 手机、平板或折叠屏需要结构切换时，优先使用断点、capability 和 adaptive 组件，而不是按具体机型硬编码。

移动交互转换：

| 移动端 | 桌面端 |
| --- | --- |
| 长按 | 右键菜单 / 更多按钮 |
| 下拉刷新 | 刷新按钮 / 快捷键 |
| 左滑删除 | 显式按钮 / 菜单 |
| 底部弹层 | dialog / side panel / popover |
| 手势翻页 | 方向键 / 空格 / 滚轮 |

桌面 UI 任务边界：

- 桌面端新增顶栏、侧栏、popover、键鼠入口时，优先放在桌面壳层或桌面分支，不替换移动端成熟控件。
- 修改共用页面时，必须保证 `< 600` 宽度仍走原移动端结构；不能让桌面专用 provider、菜单状态或顶栏动作成为移动端依赖。
- 收尾验证至少覆盖一个移动端断点 smoke，确认桌面 UI 改动没有让移动端布局、入口和操作顺序发生变化。

## 6. 视觉 token 规则

颜色、圆角、边框、阴影、按钮高度优先从以下位置取得：

- `Theme.of(context).colorScheme`
- `AppComponentThemeTokens`
- `AppBorderTokens`
- `AppSpacing`
- `AppSizeTokens`
- `AppTypography`
- 高级主题解析后的 palette / backdrop

新页面不得大量使用：

- `Color(0x...)`
- `Colors.*`
- 随手 `withValues(alpha: ...)`
- 局部 `BoxShadow`
- 局部大圆角

允许例外：真实资源颜色、警示色、封面占位、阅读器正文主题等有明确业务语义的固定颜色。

## 7. 状态组件规则

页面级状态优先使用统一组件：

- 空态：`AppEmptyStateCard`
- 阻断状态：`AppStatusStateCard`
- 任务状态：`AppTaskStatus` / task queue surface
- 禁用能力页：`FeatureDisabledPage`
- 运行时反馈：`RuntimeFeedbackCard`

不要每个页面重新手写一套 loading、error、empty。

## 8. UI 验收矩阵

涉及 UI 的改动至少检查：

- 390dp 以下不溢出。
- Android / iOS Safe Area、软键盘、返回和触控命中区域不回退。
- 600dp 附近布局切换自然。
- 840dp 以上不是移动端拉宽。
- 1280dp 桌面布局可用。
- 1600dp 宽屏内容不过度拉伸。
- 文字缩放到项目上限后仍可读。
- hover/focus/disabled/loading/empty/error 状态完整。

推荐测试：

```bash
dart tool/check_adaptive_layout_guard.dart --fail
dart tool/check_ui_component_governance.dart
flutter test test/app/layout/adaptive_breakpoints_test.dart test/app/widgets/adaptive_components_test.dart
```
