# A3 阅读器布局上下文

更新时间：2026-05-13

## 0. 当前代码入口

- `lib/features/reader/presentation/reader_layout_context.dart`
- `lib/features/reader/application/reader_layout_resolver.dart`
- `lib/features/reader/presentation/reader_catalog_sheet.dart`
- `lib/features/reader/presentation/reader_page_settings_panel.dart`

## 1. 设计口径

阅读器不直接复用普通页面的内容宽度和弹层规则，而是在全局 `AppAdaptiveMetrics` 之上派生 `ReaderLayoutContext`。

`ReaderLayoutContext` 当前负责：

- 判断当前阅读 viewport 是文字还是图片/漫画。
- 文字阅读在 expanded 窗口下收敛到 720dp 正文宽度。
- 图片/漫画阅读不套文字最大宽度，优先利用可用视口。
- 目录和设置面板在 desktop-like 场景使用 side panel，在移动端使用 bottom sheet。
- 暴露 side panel 最大宽度，供阅读器弹层复用。

## 2. ReaderSizes

`ReaderSizes` 用正文字号推导阅读排版比例：

- lineHeight = fontSize * 1.8
- paragraphSpacing = fontSize * 0.8
- pagePaddingH = fontSize * 1.2
- pagePaddingV = fontSize
- indentSize = fontSize * 2
- blockQuoteIndent = fontSize * 1.5
- imageCaptionSize = fontSize * 0.85

后续阅读器分页、滚动正文和设置预览应逐步从同一套尺寸链取值，避免视觉参数和分页参数不一致。

## 3. 已接入

- [x] `ReaderLayoutResolver.desktopReadableContentMaxWidth` 从 760 收敛到 720。
- [x] `_resolveReaderSurfaceMetrics` 使用 `ReaderLayoutContext.contentMaxWidth` 决定文字/图片宽度策略。
- [x] 目录面板使用 `ReaderLayoutContext.catalogPanelPresentation`。
- [x] 设置面板使用 `ReaderLayoutContext.settingsPanelPresentation` 和 `sidePanelMaxWidth`。
- [x] 新增 `reader_layout_context_test` 覆盖文字/图片宽度、side panel 决策和 `ReaderSizes`。

## 4. 后续

- [ ] 阅读器设置项中具体字号、行高、段距控件接入 `ReaderSizes`。
- [ ] 阅读器目录、书签、标注面板继续减少全屏 dialog，统一走 reader panel 策略。
- [ ] 漫画模式按图片 viewport 单独补充双页/适宽策略。
- [ ] A7 阶段补鼠标键盘、窗口缩放和横屏大字体回归。
