# UI 与自适应设计规则

更新时间：2026-06-03

本文定义 UI、响应式布局、自适应交互和视觉 token 的编写规则。目标是让每个平台都像原生使用场景，而不是把同一张移动端页面强行拉伸。

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

## 5. 桌面 UI 规则

桌面端优先使用：

- 左侧导航或 topbar。
- 主从分栏。
- 列表 + 详情面板。
- 表格、网格、筛选栏、工具栏。
- dialog、popover、side panel、command surface。
- hover、focus、selected、disabled 状态。
- 键盘快捷键、右键菜单、滚轮。

移动交互转换：

| 移动端 | 桌面端 |
| --- | --- |
| 长按 | 右键菜单 / 更多按钮 |
| 下拉刷新 | 刷新按钮 / 快捷键 |
| 左滑删除 | 显式按钮 / 菜单 |
| 底部弹层 | dialog / side panel / popover |
| 手势翻页 | 方向键 / 空格 / 滚轮 |

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
dart run tool/check_adaptive_layout_guard.dart --fail
dart run tool/check_ui_component_governance.dart
flutter test test/app/layout/adaptive_breakpoints_test.dart test/app/widgets/adaptive_components_test.dart
```
