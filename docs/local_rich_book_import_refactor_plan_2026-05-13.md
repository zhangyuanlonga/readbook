# 本地图文导入与解析改造计划 - 2026-05-13

## 1. 背景

当前本地图文导入链路已经形成了稳定的主干：

- 导入层：`LocalBookImportService` 负责文件校验、复制入库、写入书架。
- 索引层：`LocalBookIndexService` 按格式分发到 TXT / EPUB / Markdown / HTML / PDF / Kindle parser。
- 内容模型：`ReaderDocument -> ReaderBlock` 统一表达标题、正文、图片、引用、脚注、列表、图注。
- 阅读层：滚动模式和分页模式消费同一份结构化内容。
- EPUB：已实现目录优先，章节正文按需解析。

新的改造目标不是推翻架构，而是补齐几个高杠杆短板：

1. HTML / Markdown 对齐 EPUB 的按需解析。
2. 图片真实尺寸成为分页布局输入，降低图文分页跳动。
3. EPUB fragment、图片 materialize、非标准编码进一步加固。
4. Kindle 图文能力专项排查。
5. 编码检测和防乱码测试体系补全。

## 2. 当前实现摘要

### 2.1 导入与入库

入口：

- `lib/features/bookshelf/application/local_book_import_service.dart`

现状：

- 支持 `txt / epub / md / html / pdf / mobi / azw / azw3`。
- 导入时复制到应用支持目录 `local_books`。
- 按源路径或导入指纹复用已有本地书。
- 写入 `LocalBook` 和书架 `BookshelfBook`。
- 根据格式和策略决定立即索引或后台 warm up 索引。

### 2.2 索引分发

入口：

- `lib/features/reader/application/local/local_book_index_service.dart`

现状：

- parser 注册：TXT、EPUB、Markdown、HTML、PDF、Kindle。
- parser 输出统一为 `LocalParsedBook / LocalParsedChapter`。
- 落库为 `LocalChapter`，保存：
  - `content`
  - `imageUrls`
  - `document`
  - `sourceRef`
  - `startOffset / endOffset`

### 2.3 图文模型

入口：

- `lib/domain/entities/reader_document.dart`

现状：

- `ReaderTextBlock`
- `ReaderTitleBlock`
- `ReaderImageBlock`
- `ReaderListItemBlock`
- `ReaderQuoteBlock`
- `ReaderCaptionBlock`
- `ReaderFootnoteBlock`

阅读器渲染前会转成：

- `ReaderRenderTextItem`
- `ReaderRenderImageItem`

入口：

- `lib/features/reader/application/reader_document_render_model.dart`

### 2.4 EPUB

入口：

- `lib/features/reader/application/local/epub_local_book_parser.dart`
- `lib/features/reader/application/local/local_chapter_content_service.dart`

现状：

- 索引阶段只读取 archive、package、toc/nav/spine、metadata、cover。
- 每章只保存标题和 `sourceRef`。
- 第一次打开章节时才 `parseChapter`，解析正文 HTML、图片、标题、引用、脚注等。
- 解析后的正文和 `ReaderDocument` 回写到 `LocalChapter`。

### 2.5 HTML / Markdown

入口：

- `lib/features/reader/application/local/html_local_book_parser.dart`
- `lib/features/reader/application/local/markdown_local_book_parser.dart`
- `lib/features/reader/application/local/local_markup_book_parser_support.dart`

现状：

- Markdown 先转 HTML，再复用 HTML 解析。
- HTML/Markdown 索引阶段会整本解析成 `ReaderDocument`，再按标题切章。
- 图片会复制到本地 assets 目录。

## 3. 关键问题

### 3.1 HTML / Markdown 仍是整本解析

影响：

- 大 HTML / Markdown 导入阶段可能耗时明显。
- 用户只读前几章时，后续章节解析属于浪费。
- 与 EPUB 的按需策略不一致。

### 3.2 图片尺寸不是布局一等输入

影响：

- 图文分页目前主要依赖占位比例。
- 横图、竖图、长图差异会导致页面空白或二次布局跳动。
- 图片尺寸变化尚未作为稳定缓存版本的一部分。

### 3.3 EPUB fragment 语义需要更健壮

影响：

- `href#id` 可能只是跳转锚点，不一定代表章节正文范围。
- 如果误把锚点附近内容当章节，可能漏正文。

### 3.4 EPUB 图片 materialize 时机偏早

影响：

- 图片密集章节第一次打开可能慢。
- 当前章节解析时倾向一次性落地本章图片。

### 3.5 Kindle 图文能力不确定

需要确认：

- 是否产出 `ReaderDocument`。
- 是否提取图片到本地 assets。
- 是否保留脚注、引用、图注。

### 3.6 防乱码仍缺专项测试包

现有基础：

- `LocalTextEncodingDetector` 已支持 BOM、UTF-8 严格尝试、UTF-16 零字节检测、GBK/GB18030/Big5/Shift-JIS/EUC-JP/EUC-KR 等候选。
- TXT 已持久化 `charset`，并支持字节 offset 按需读取章节。

待补：

- 错声明 HTML。
- 非标准 EPUB 编码。
- Big5、Shift-JIS、混合编码样本。
- 编码变化后分页缓存失效策略。

## 4. 改造阶段

### 阶段 0：基线与测试样本

目标：先准备可复测样本，防止改造后只凭感觉判断。

任务：

- [ ] 建立本地图文导入测试样本目录或说明文档。
- [ ] 准备大 HTML：单文件整本书，包含 `h1/h2`、图片、脚注。
- [ ] 准备大 Markdown：包含 front matter、标题层级、图片、引用、列表。
- [ ] 准备图文 EPUB：普通章节图文混排。
- [ ] 准备图片密集 EPUB：单章 30 张以上图片。
- [ ] 准备 Kindle/MOBI/AZW3 样本：至少一本图文混排。
- [ ] 准备编码样本：UTF-8 BOM、GBK、Big5、Shift-JIS、声明错误 HTML、非标准 EPUB。
- [ ] 记录导入耗时、索引耗时、首章打开耗时、首次图片显示耗时、分页耗时。

验收：

- 每个样本都有格式、编码、内容特征和期望结果说明。
- 可以复测导入和首次阅读耗时。

### 阶段 1：HTML 按需解析

目标：HTML 索引阶段只建目录，正文打开章节时再解析。

任务：

- [ ] 新增 HTML index-only 模式。
- [ ] 索引阶段只扫描标题结构，生成章节标题和 `sourceRef`。
- [ ] `sourceRef` 支持 `elementId`、DOM path、或字符/字节区间。
- [ ] 保留当前整本解析作为 fallback。
- [ ] 在 `LocalChapterContentService` 中支持 HTML `sourceRef` 按需解析。
- [ ] 打开章节后回写 `content / imageUrls / document`。
- [ ] 邻章预加载走低优先级按需解析。

建议实现：

- 对有 `id` 的标题优先用 `elementId`。
- 无 `id` 时记录稳定 DOM path。
- 如果 DOM path 不稳定，退回章节 block index 范围。
- 不建议依赖解码后字符串位置反推字节 offset。

涉及文件：

- `lib/features/reader/application/local/html_local_book_parser.dart`
- `lib/features/reader/application/local/local_markup_book_parser_support.dart`
- `lib/features/reader/application/local/local_chapter_content_service.dart`
- `lib/features/reader/application/local/local_book_index_service.dart`

验收：

- 大 HTML 导入后可以快速看到目录。
- 首次打开某章才解析该章正文。
- 已解析章节二次打开直接命中本地章节内容。

### 阶段 2：Markdown 按需解析

目标：Markdown 对齐 HTML / EPUB，索引只建目录，正文按需转换和解析。

任务：

- [ ] 新增 Markdown index-only 模式。
- [ ] 标题扫描直接基于 Markdown 源文件，不先整本转 HTML。
- [ ] 保存章节 `sourceRef`，优先使用原始字节范围。
- [ ] 按需读取章节 Markdown 源片段，转 HTML，再走现有 HTML block 解析。
- [ ] front matter 中的 title / author / description / cover 仍在索引阶段读取。
- [ ] 编码检测结果持久化到 `LocalBook.charset`。

注意：

- Markdown 的 byte offset 必须在原始字节层扫描。
- 如果先解码成 String 再计算 offset，多字节编码会产生偏移风险。

涉及文件：

- `lib/features/reader/application/local/markdown_local_book_parser.dart`
- `lib/features/reader/application/local/local_markup_book_parser_support.dart`
- `lib/features/reader/application/local/local_chapter_content_service.dart`

验收：

- 大 Markdown 导入不整本转 HTML。
- 打开章节后能正确解析标题、图片、引用、列表。
- GBK/Big5/Shift-JIS Markdown 不乱码。

### 阶段 3：图片 promised size

目标：图片尺寸成为分页布局的稳定输入，减少图文分页跳动。

任务：

- [ ] 扩展 `ReaderImageBlock`，增加图片尺寸元数据。
- [ ] 定义图片尺寸状态：`known / estimated / corrected`。
- [ ] HTML 图片优先读取 `width / height` 属性。
- [ ] EPUB 图片优先读取 manifest 属性或图片头信息。
- [ ] 无尺寸时使用默认 promised ratio。
- [ ] 分页布局使用 promised size，而不是固定占位比例。
- [ ] 图片真实解码完成后，如果偏差超过阈值，标记相关页脏。
- [ ] 偏差较小时不触发重分页。

建议数据结构：

```dart
class ReaderImageBlock extends ReaderBlock {
  const ReaderImageBlock({
    required this.imageUrl,
    this.width,
    this.height,
    this.sizeStatus = ReaderImageSizeStatus.estimated,
    this.sizeVersion = 0,
  });
}
```

涉及文件：

- `lib/domain/entities/reader_document.dart`
- `lib/features/reader/application/reader_pagination_models.dart`
- `lib/features/reader/application/reader_pagination_spec.dart`
- `lib/features/reader/application/reader_pagination_engine.dart`
- `lib/features/reader/presentation/reader_text_paged_view.dart`

验收：

- 横图、竖图、长图在分页模式下高度更稳定。
- 图片尺寸修正不会导致整章频繁重分页。

### 阶段 4：分页缓存接入图片尺寸版本

目标：确保图文分页缓存不会因为图片尺寸变化复用错误布局。

任务：

- [ ] 缓存 key 纳入图片 promised size version。
- [ ] `ReaderPagedBlock.image` 保存布局使用的尺寸版本。
- [ ] 缓存命中时做开发期一致性校验。
- [ ] 图片尺寸版本变化时只失效受影响章节/页面缓存。
- [ ] 增加图文分页缓存确定性测试。

涉及文件：

- `lib/features/reader/application/reader_pagination_cache_service.dart`
- `lib/features/reader/application/reader_pagination_models.dart`
- `test/features/reader/application/reader_pagination_cache_service_test.dart`

验收：

- 相同输入重复分页结果一致。
- 图片尺寸版本变化后不会复用旧 layout。

### 阶段 5：EPUB fragment 与图片懒 materialize

目标：提升非标准 EPUB 健壮性和图片密集章节打开速度。

任务：

- [ ] 区分无 fragment、普通 `#id`、异常 fragment。
- [ ] 普通锚点只作为定位信息，默认仍解析整个 spine item。
- [ ] 如果 sourceRef 表示明确范围，才做范围截取。
- [ ] 对图片密集章节引入懒 materialize 方案。
- [ ] 评估虚拟 URL：`epub-asset://bookId/chapterId/path`。
- [ ] 图片真正进入视口时再落地到本地 assets。
- [ ] 当前屏幕和邻近 1-2 张图片高优先级，其余低优先级。

涉及文件：

- `lib/features/reader/application/local/epub_local_book_parser.dart`
- `lib/features/reader/application/local/local_chapter_content_service.dart`
- `lib/features/reader/presentation/reader_text_scroll_view.dart`
- `lib/features/reader/presentation/reader_text_paged_view.dart`

验收：

- fragment EPUB 不漏正文。
- 图片密集 EPUB 首章打开时间下降。
- 图片可见时能稳定显示，不出现永久占位。

### 阶段 6：Kindle 图文能力排查与补齐

目标：确认 MOBI/AZW/AZW3 是否真正走结构化图文链路。

任务：

- [ ] 审查 `KindleLocalBookParser` 当前输出。
- [ ] 确认是否生成 `ReaderDocument`。
- [ ] 确认图片是否 materialize 到本地 assets。
- [ ] 确认脚注、引用、图注是否映射到对应 `ReaderBlock`。
- [ ] 如果只产出纯文本，评估复用 HTML/EPUB 的 block 解析支持。
- [ ] 增加 Kindle 图文样本回归测试。

涉及文件：

- `lib/features/reader/application/local/kindle_local_book_parser.dart`
- `lib/features/reader/application/local/local_markup_book_parser_support.dart`

验收：

- Kindle 图文书能显示图片。
- 至少保留标题、正文、图片、引用或脚注中的主要结构。

### 阶段 7：防乱码加固

目标：把现有编码检测能力整理成稳定、可回归的防乱码体系。

现有基础：

- BOM 检测。
- UTF-8 严格尝试。
- UTF-16 零字节模式。
- GBK / GB18030 / Big5 / Shift-JIS / EUC-JP / EUC-KR 候选。
- 移动端 charset detector。
- TXT charset 持久化。
- TXT 字节 offset 按需读取章节。

任务：

- [ ] HTML 解码优先级统一为：BOM > 声明 > 探测 > UTF-8 fallback。
- [ ] 对声明错误 HTML 增加乱码特征检测和重解码。
- [ ] EPUB 章节 HTML 解码增加声明错误兜底。
- [ ] NCX / nav 标题增加乱码检测和重解码。
- [ ] 编码变化时主动失效对应分页缓存。
- [ ] 增加编码测试包。
- [ ] 增加用户手动修正编码后的重索引入口验证。

测试样本：

| 样本 | 期望 |
| --- | --- |
| TXT UTF-8 BOM | 正常显示，charset=utf-8 |
| TXT GBK | 正常显示，charset=gbk 或 gb18030 |
| TXT Big5 | 繁体正常显示 |
| TXT Shift-JIS | 日文正常显示 |
| TXT 混合编码 | 不崩溃，局部替换字符可接受 |
| HTML 声明 UTF-8 实际 GBK | 自动纠正或提示 |
| EPUB 章节 GBK 非标准 | 正文不乱码 |
| EPUB TOC 标题异常编码 | 目录不乱码或可恢复 |

涉及文件：

- `lib/features/reader/application/local/local_text_encoding_detector.dart`
- `lib/features/reader/application/local/txt_local_book_parser.dart`
- `lib/features/reader/application/local/local_markup_book_parser_support.dart`
- `lib/features/reader/application/local/epub_local_book_parser.dart`
- `test/features/reader/application/local/`

验收：

- 常见中文老 TXT、繁体、日文文本不乱码。
- 声明错误 HTML/EPUB 不直接信错声明。
- 解码失败不会导致整本导入崩溃。

## 5. 优先级

| 优先级 | 任务 | 原因 |
| --- | --- | --- |
| P0 | HTML 按需解析 | 大文件导入体验质变 |
| P0 | Markdown 按需解析 | 与 HTML 同源，收益明显 |
| P0 | 图片 promised size | 直接影响图文分页稳定 |
| P1 | EPUB fragment 加固 | 避免非标准 EPUB 漏正文 |
| P1 | 分页缓存接入图片尺寸版本 | 防止缓存布局漂移 |
| P1 | Kindle 图文排查 | 补格式覆盖盲区 |
| P2 | EPUB 图片懒 materialize | 图片密集书体验优化 |
| P2 | 原始 HTML 备份 | 为还原度模式预留 |
| P2 | 编码测试包 | 长期回归保障 |

## 6. 建议执行顺序

1. 阶段 0：先准备样本和指标。
2. 阶段 1：HTML index-only + 按需章节解析。
3. 阶段 2：Markdown index-only + 按需章节解析。
4. 阶段 3：图片 promised size。
5. 阶段 4：分页缓存接入图片尺寸版本。
6. 阶段 5：EPUB fragment 加固。
7. 阶段 6：Kindle 图文能力排查。
8. 阶段 7：防乱码测试包和错声明纠正。

## 7. 不做的事

- 不把阅读器重新改成 WebView 主渲染。
- 不恢复完整 CSS 排版作为当前阶段目标。
- 不为了图片真实尺寸阻塞首屏分页。
- 不让编码检测在每章反复猜测；一旦确认，应持久化并复用。

## 8. 验收总标准

- 大 HTML / Markdown 导入后能快速看到目录。
- EPUB / HTML / Markdown 图文章节都能通过 `ReaderDocument` 渲染。
- 图文分页不会因图片尺寸轻微修正频繁整章重排。
- 乱码样本不崩溃，常见编码能自动识别。
- Kindle 图文能力有明确结论：已支持、部分支持或待补齐。
