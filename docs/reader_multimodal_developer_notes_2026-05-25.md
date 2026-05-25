# 阅读器多模态开发说明

更新时间：2026-05-25

## 1. 当前架构口径

阅读器当前统一按四类内容模式运行：

- `text`：纯文本、流式 EPUB、Markdown/HTML 图文
- `hybrid`：PDF、固定版式 EPUB、绘本、杂志、扫描型页内容
- `comic`：漫画图片序列
- `audio`：音频章节

模式识别入口：

- `lib/features/reader/application/reader_content_mode_resolver.dart`

模式能力入口：

- `lib/features/reader/application/reader_mode_resolver.dart`
- `lib/features/reader/application/reader_mode_capabilities.dart`

统一 viewport 状态：

- `lib/features/reader/application/reader_viewport_state.dart`
- `lib/features/reader/application/reader_viewport_state_resolver.dart`

统一进度快照：

- `lib/domain/entities/reading_progress.dart`
- `lib/domain/entities/reader_logical_position.dart`

## 2. 内容接入规则

### `text`

适用于：

- TXT
- 流式 EPUB
- Markdown / HTML 正文
- 文本主导、图片内嵌的章节

要求：

- 正文可重排
- 支持字体、排版、高亮、自动阅读

### `hybrid`

适用于：

- PDF
- 固定版式 EPUB
- 绘本 / 杂志
- 扫描型页内容

要求：

- 页是主要单位
- 默认关闭自动阅读
- 进度优先保存 page index

### `comic`

适用于：

- 漫画图片序列
- CBZ / ZIP 图片章节

要求：

- 图片序列为正文主体
- 连续滚动与分页共存
- 缩放优先级高于正文点击分区

### `audio`

适用于：

- 音频章节
- 听书模式

要求：

- 不参与正文自动阅读
- 进度保存播放位置、时长、倍速

## 3. 本地内容接入约定

### PDF

- `LocalContentProvider` 会把本地 PDF 章节标记为 `contentType = pdf`
- Reader 进入 `hybrid`
- 渲染器当前为 `ReaderPdfView` + `pdfrx`

### 固定版式 EPUB

- `EpubLocalBookParser` 会在以下信号命中时标记为 fixed-layout：
  - OPF `rendition:layout`
  - item/itemref properties 中的 fixed/pre-paginated 信号
  - 章节文档中的 viewport meta / SVG 信号
- fixed-layout 章节会输出 `contentType = epub-fixed`
- 流式 EPUB 仍保持文本模式

### 绘本 / 杂志

- 本地单页纯图片章节会优先标记为 `picture-book`
- 目前复用页码型图片渲染路径

## 4. ReaderPage 扩展建议

新增阅读器类型时，优先按这个顺序接：

1. 在 `ReaderContentModeResolver` 决定模式与 subtype
2. 在 `ReaderModeResolver` 和 `ReaderModeCapabilitiesResolver` 决定能力口径
3. 在 `ReaderViewportStateResolver` 决定 progress/state 口径
4. 在 `reader_page_viewport.dart` 挂接具体 view
5. 在 `ReadingProgress.positionSnapshot` 中补足恢复所需字段

不要直接在 `ReaderPage` 里再开一套完全独立的保存、点击、翻页和恢复逻辑。

## 5. 当前已知尾项

- 固定版式 EPUB 仍是“识别 + hybrid 路径接入”，还不是高保真 HTML/CSS 版式渲染
- PDF / fixed-layout EPUB 目录页级跳转尚未补足
- AudioReader 还未做上一段 / 下一段、后台播放、定时停止
- 跨模式交互的 widget 测试还不完整
