# A1 尺寸与 Typography Token

更新时间：2026-05-13

## 0. 当前代码入口

- `lib/app/theme/app_typography.dart`
- `lib/app/layout/app_size_tokens.dart`
- `lib/app/layout/app_adaptive.dart`

## 1. Typography 锚点

| Token | 数值 |
| --- | --- |
| caption | 11 |
| footnote | 12 |
| subhead | 13 |
| body / bodyBase | 15 |
| bodyLarge | 16 |
| titleSmall | 18 |
| title | 22 |
| titleLarge | 28 |
| headline | 34 |

规则：

- App UI 默认跟随系统字体缩放。
- App UI 和阅读器 chrome 的系统字体缩放建议上限为 1.5x。
- 阅读器正文使用独立字号滑块，分页计算不得再乘系统字体缩放。

## 2. 尺寸锚点

| Token | 数值 | 用途 |
| --- | --- | --- |
| minTouchTarget | 44 | 所有可点击区域命中底线 |
| compactControlHeight | 36 | 小屏视觉控件高度 |
| regularControlHeight | 40 | 常规视觉控件高度 |
| comfortableControlHeight | 44 | 舒适视觉控件高度 |
| mediumContentMaxWidth | 680 | 中宽设置/表单内容 |
| expandedContentMaxWidth | 820 | 大屏普通内容 |
| readerTextContentMaxWidth | 720 | 文字阅读正文宽度上限 |
| bookshelfCardMinWidth | 140 | 书架卡片最小宽 |
| bookshelfCardMaxWidth | 200 | 书架卡片最大宽 |

注意：视觉高度可以小于 44dp，但外层点击命中区必须不小于 44dp。

## 3. 后续迁移规则

- 新组件优先从 `AppTypography` 和 `AppSizeTokens` 取锚点。
- 老页面不做机械替换；只在迁移页面时替换散落字号、按钮高度和内容宽度。
- 阅读器正文尺寸链在 A3 中单独落地，避免和普通页面 token 混用。

## 4. 验收

- `flutter test test/app/theme/app_typography_size_tokens_test.dart`
- `flutter test test/app/layout/app_adaptive_metrics_test.dart`
- `flutter test test/app/layout/adaptive_breakpoints_test.dart`
