# 阅读器多模态架构改造执行计划

更新时间：2026-05-25

状态：待执行

适用范围：

- 阅读器内容模式识别
- 文本、图文混排、漫画、听书阅读器分发
- PDF、固定版式 EPUB、绘本/杂志等固定页内容
- 阅读进度、目录跳转、点击分区、长按、缩放、自动阅读等跨模式能力

关联文档：

- [PROJECT_FEATURE_MAP.md](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/PROJECT_FEATURE_MAP.md)
- [reader_auto_read_execution_plan_2026-05-24.md](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/docs/reader_auto_read_execution_plan_2026-05-24.md)
- [reader_local_content_refactor_execution_plan_2026-05-21.md](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/docs/reader_local_content_refactor_execution_plan_2026-05-21.md)

## 1. 使用说明

- 所有任务默认以 `[ ]` 表示未完成。
- 单项任务完成后，改成 `[x]`。
- 阶段完成项必须在该阶段任务、测试和验收都满足后才能勾选。
- 如果代码真实现状与本文冲突，以代码为准，并同步更新本文。
- 本文用于后续执行追踪：执行某个阶段时，必须同步更新对应勾选状态和完成记录。

## 2. 改造结论

- [x] 改造方向已确认：阅读器需要从“文本/漫画/音频三类”升级到“文本/图文混排/漫画/音频”多模态架构。
- [x] 图文混排需要补齐，但不能把所有带图片的内容都归为 Hybrid。
- [x] 流式 EPUB 图文混排继续走文本阅读器，只增强图片查看、图片长按、预加载等能力。
- [x] 固定页内容归为 Hybrid：PDF、EPUB 固定版式、绘本、杂志、扫描版文档。
- [x] PDF 优先级高于 AudioReader 增强，因为当前 PDF 只做文本抽取，扫描版或无文本层页面会无法阅读。
- [x] 不建议第一步大改 `ReaderPage`，应先扩展内容模式、能力协议和进度模型。

目标架构：

```text
ReaderPage / ReaderShell
    |
    +-- ReaderContentMode.text
    |       +-- TextPagedViewport
    |       +-- TextScrollViewport
    |
    +-- ReaderContentMode.hybrid
    |       +-- PdfFixedPageViewport
    |       +-- EpubFixedViewport
    |       +-- PictureBookViewport
    |
    +-- ReaderContentMode.comic
    |       +-- MangaContinuousViewport
    |       +-- MangaPagedViewport
    |
    +-- ReaderContentMode.audio
            +-- AudioReaderViewport
```

## 3. 当前代码现状

- [x] 已确认当前内容模式位于 `lib/features/reader/application/reader_content_session.dart`，现有枚举为 `text`、`comic`、`audio`。
- [x] 已确认当前视口模型位于 `lib/features/reader/application/reader_mode_model.dart`，现有 `ReaderContentKind` 为 `text`、`image`、`audio`。
- [x] 已确认当前渲染分发主要位于 `lib/features/reader/presentation/reader_page_viewport.dart`。
- [x] 已确认当前 `ReaderContentModeResolver` 只将纯图片文档判为漫画，文本+图片仍进入文本模式。
- [x] 已确认 `ReaderDocument` 已支持文本块和图片块，具备流式图文混排的基础结构。
- [x] 已确认当前 PDF 本地解析器主要按页抽取文本，不具备固定页渲染能力。
- [x] 已确认当前 `ReaderAudioView` 已有基础播放能力，不是从零开始。
- [x] 已确认当前漫画视图已经有连续滚动和分页阅读的基础能力。

## 4. 内容类型边界

- [x] 内容类型边界已完成落地

| 内容类型 | 典型格式 | 内容特征 | 推荐模式 | 核心能力 |
|---|---|---|---|---|
| 纯文本 | TXT、纯文本章节、流式 EPUB 纯文本 | 文本可重排 | `text` | 字体、排版、高亮、自动阅读 |
| 流式图文 | EPUB 流式、HTML、Markdown 图文 | 文本可重排，图片内嵌 | `text` | 文本能力 + 图片查看 |
| 固定图文 | PDF、EPUB 固定版式、绘本、杂志 | 页是主要单位，版式不可重排 | `hybrid` | 分页、缩放、平移、白边裁剪 |
| 漫画 | CBZ、ZIP 图片章节、图片列表章节 | 图片序列为主 | `comic` | 图片预加载、连续滚动、横屏双页 |
| 听书 | MP3、M4A、音频章节 | 音频为主 | `audio` | 播放、倍速、后台、定时 |

关键口径：

- [x] `ReaderContentMode.text` 保留纯文本和流式图文能力。
- [x] `ReaderContentMode.hybrid` 只处理固定页、固定版式或扫描型内容。
- [x] `ReaderContentMode.comic` 只处理漫画图片序列，不承接普通 PDF/绘本。
- [x] `ReaderContentMode.audio` 保持音频独立模式。
- [x] 新增 `ReaderHybridSubMode`：`pdf`、`epubFixed`、`pictureBook`、`documentImage`。

## 5. Phase 0：方案冻结与边界校准

- [x] Phase 0 阶段完成

### 5.1 任务

- [x] 阅读 `PROJECT_FEATURE_MAP.md` 并确认阅读器相关入口。
- [x] 梳理当前阅读器内容模式、视口模型、分发入口。
- [x] 梳理当前 PDF、EPUB、本地图文能力现状。
- [x] 确认“流式图文继续走 Text，固定页内容走 Hybrid”的边界。
- [x] 确认 PDF 固定页渲染优先级高于 AudioReader 增强。
- [x] 确认不做一次性大爆炸重构，采用分阶段兼容演进。

### 5.2 验收标准

- [x] 改造目标、内容边界、实施优先级已写入本文。
- [x] 每个阶段都有明确任务和验收项。
- [x] 后续执行可以按阶段勾选推进。

## 6. Phase 1：内容模式与能力模型扩展

- [x] Phase 1 阶段完成

### 6.1 任务

- [x] 将 `ReaderContentMode` 从 `text/comic/audio` 扩展为 `text/hybrid/comic/audio`。
- [x] 新增 `ReaderHybridSubMode`：`pdf`、`epubFixed`、`pictureBook`、`documentImage`。
- [x] 扩展 `ReaderContentSession`，支持保存 hybrid 子类型、源文件路径、页码信息、可选渲染元数据。
- [x] 扩展 `ReaderContentModeResolver`，根据 `contentType`、本地格式、文档结构判断 hybrid。
- [x] 保持旧 `comic` 判断逻辑兼容，避免现有漫画阅读回退。
- [x] 扩展 `ReaderModeCapabilitiesResolver`，为 hybrid 定义能力：目录、缩放、截图页、自动阅读禁用或后置支持。
- [x] 扩展 `ReaderModeModel`，新增 hybrid 对应 viewport kind。
- [x] 增加非法 content type 的降级策略。

### 6.2 涉及文件

- `lib/features/reader/application/reader_content_session.dart`
- `lib/features/reader/application/reader_content_mode_resolver.dart`
- `lib/features/reader/application/reader_content_session_resolver.dart`
- `lib/features/reader/application/reader_mode_model.dart`
- `lib/features/reader/application/reader_mode_resolver.dart`
- `lib/features/reader/application/reader_mode_capabilities.dart`
- `lib/features/reader/presentation/reader_presentation_resolver.dart`

### 6.3 验收标准

- [x] 现有文本章节仍进入文本模式。
- [x] 现有漫画章节仍进入漫画模式。
- [x] 现有音频章节仍进入音频模式。
- [x] PDF、本地固定页内容能够被识别为 hybrid。
- [x] 模式能力不会导致底部导航、自动阅读、目录入口崩溃。

### 6.4 测试

- [x] 更新 `test/features/reader/application/reader_content_mode_resolver_test.dart` 或新增对应测试。
- [x] 更新 `test/features/reader/application/reader_mode_resolver_test.dart`。
- [x] 更新 `test/features/reader/application/reader_mode_capabilities_test.dart`。

## 7. Phase 2：统一 Reader Viewport 协议

- [x] Phase 2 阶段完成

### 7.1 任务

- [x] 定义统一的阅读器视口协议或模型，例如 `ReaderViewportContract` / `ReaderViewportAdapter`。
- [x] 协议至少覆盖：当前位置、跳转、上一页、下一页、是否支持缩放、是否支持文本选择、是否支持自动阅读。
- [x] 将文本分页/滚动的进度输出适配到协议。
- [x] 将漫画连续/分页的进度输出适配到协议。
- [x] 将音频进度输出适配到协议。
- [x] 为 hybrid 预留页码、缩放、平移、裁剪白边状态。
- [x] 收口点击分区、长按、目录跳转、音量键翻页对不同 viewport 的调用方式。

### 7.2 涉及文件

- `lib/features/reader/presentation/reader_page_viewport.dart`
- `lib/features/reader/presentation/reader_viewport_builder.dart`
- `lib/features/reader/presentation/reader_text_paged_view.dart`
- `lib/features/reader/presentation/reader_text_scroll_view.dart`
- `lib/features/reader/presentation/reader_manga_view.dart`
- `lib/features/reader/presentation/reader_audio_view.dart`
- `lib/features/reader/presentation/reader_page_shell.dart`
- `lib/features/reader/presentation/reader_page_navigation.dart`

### 7.3 验收标准

- [x] `ReaderPage` 不再直接关心每种内容的细碎行为差异。
- [x] 文本、漫画、音频现有行为保持一致。
- [x] 后续接入 PDF 时不需要复制大量点击、跳转、进度保存逻辑。

### 7.4 测试

- [x] 新增或更新 viewport adapter 单元测试。
- [x] 回归 `reader_annotation_interaction_test.dart`。
- [x] 回归 `reader_viewport_builder_test.dart`。

## 8. Phase 3：阅读进度模型升级

- [x] Phase 3 阶段完成

### 8.1 任务

- [x] 设计 `ReaderPositionSnapshot` 或等价模型。
- [x] 支持文本位置：章节、段落、字符偏移、分页页码、滚动比例。
- [x] 支持图片/漫画位置：图片 index、页内滚动比例。
- [x] 支持 hybrid 位置：page index、page count、zoom、pan offset、裁剪状态。
- [x] 支持 audio 位置：duration position、speed、章节队列位置。
- [x] 保留 `ReadingProgress.chapterPositionRatio` 的旧数据兼容。
- [x] 将进度保存、恢复、阅读记录统计改为读取新快照并兼容旧字段。
- [x] 明确哪些字段进入数据库，哪些字段只作为运行时状态。

### 8.2 涉及文件

- `lib/domain/entities/reading_progress.dart`
- `lib/domain/entities/reader_logical_position.dart`
- `lib/features/reader/application/reader_session_state.dart`
- `lib/features/reader/application/reader_reading_record_coordinator.dart`
- `lib/features/reader/application/reading_record_service.dart`
- `lib/features/reader/presentation/reader_page_runtime.dart`

### 8.3 验收标准

- [x] 旧阅读进度可以正常恢复。
- [x] 文本分页、文本滚动、漫画、音频进度不回退。
- [x] Hybrid 可以保存页码并恢复到正确页。
- [x] 数据库升级或 JSON 解析具备降级路径。

### 8.4 测试

- [x] 更新 `test/domain/entities/reading_progress_test.dart` 或新增对应测试。
- [x] 更新 `test/domain/entities/reader_logical_position_test.dart`。
- [x] 更新阅读记录相关测试。

## 9. Phase 4：PDF 固定页阅读器

- [x] Phase 4 阶段完成

### 9.1 任务

- [x] 选型并冻结 PDF 渲染方案，优先评估 `pdfrx`、`pdfx`、`syncfusion_flutter_pdfviewer`。
- [x] 新增 `ReaderPdfView` 或 `PdfFixedPageViewport`。
- [x] 接入本地 PDF 文件路径和页码。
- [x] 支持左右分页切换。
- [x] 支持双指缩放。
- [x] 支持单指拖拽平移。
- [x] 支持页码进度保存与恢复。
- [ ] 支持目录页跳转，目录缺失时使用页码目录。
- [x] 支持扫描版/无文本层 PDF 正常以页面形式阅读。
- [x] 保留 PDF 文本抽取能力作为搜索、辅助目录、可选文本预览，不作为主阅读路径。
- [x] 明确加密 PDF、损坏 PDF、大文件 PDF 的错误提示。

### 9.2 涉及文件

- `lib/features/reader/presentation/reader_pdf_view.dart`
- `lib/features/reader/presentation/reader_page_viewport.dart`
- `lib/features/reader/presentation/reader_viewport_builder.dart`
- `lib/features/reader/application/local/pdf_local_book_parser.dart`
- `lib/features/reader/application/local/local_chapter_content_service.dart`
- `lib/features/reader/application/reader_content_mode_resolver.dart`

### 9.3 验收标准

- [x] 扫描版 PDF 可以打开并按页阅读。
- [x] 文本层 PDF 可以打开并按页阅读。
- [x] PDF 首开不会依赖全文抽取成功。
- [x] PDF 页码、目录跳转、返回继续阅读都能定位到正确页。
- [x] 大 PDF 不会在导入阶段全量渲染或全量抽正文。

### 9.4 测试

- [x] 更新 PDF 本地解析相关测试。
- [x] 新增 PDF content mode resolver 测试。
- [x] 增加 PDF 进度模型测试。

## 10. Phase 5：流式图文文本阅读增强

- [x] Phase 5 阶段完成

### 10.1 任务

- [x] 保持 EPUB 流式图文继续进入文本模式。
- [x] 增强 `ReaderImageBlock` 的展示能力。
- [x] 图片点击打开大图查看器。
- [x] 图片长按进入图片操作面板。
- [ ] 图片支持复制链接、保存、重新加载。
- [x] 图片预加载与解码预算复用现有 `ReaderImageDecodeBudget`。
- [x] 图片查看器与自动阅读、点击分区、工具栏状态正确协作。

### 10.2 涉及文件

- `lib/domain/entities/reader_document.dart`
- `lib/features/reader/presentation/reader_page_content_rendering.dart`
- `lib/features/reader/presentation/reader_text_scroll_view.dart`
- `lib/features/reader/presentation/reader_text_paged_view.dart`
- `lib/features/reader/application/reader_image_decode_budget.dart`
- `lib/features/reader/presentation/reader_image_pipeline.dart`

### 10.3 验收标准

- [x] 文字高亮、选择、笔记不受图片块影响。
- [x] 图片查看不误触正文九宫格点击。
- [x] 自动阅读中点击图片会暂停，而不是直接退出。
- [x] EPUB 流式图文不被误判为漫画或 hybrid。

### 10.4 测试

- [x] 更新 `reader_annotation_interaction_test.dart`。
- [ ] 新增图片块点击/长按交互测试。
- [x] 回归 EPUB 本地解析测试。

## 11. Phase 6：绘本/杂志 PictureBookReader

- [x] Phase 6 阶段完成

### 11.1 任务

- [x] 定义绘本/杂志的内容来源：图片列表、本地图片目录、固定版式导出页。
- [x] 新增 `PictureBookViewport`，以页为单位展示。
- [x] 复用漫画图片加载和预加载管线。
- [x] 进度采用 page index，而不是图片滚动比例。
- [x] 支持双指缩放和单指平移。
- [ ] 支持横屏双页预留，但首版可只做单页。
- [x] 与目录、书签、继续阅读联动。

### 11.2 涉及文件

- `lib/features/reader/presentation/reader_picture_book_view.dart`
- `lib/features/reader/presentation/reader_manga_view.dart`
- `lib/features/reader/presentation/reader_image_pipeline.dart`
- `lib/features/reader/application/reader_content_mode_resolver.dart`
- `lib/features/reader/application/reader_mode_resolver.dart`

### 11.3 验收标准

- [x] 绘本/杂志不会被当作漫画连续滚动模式打开。
- [x] 页码进度准确保存和恢复。
- [x] 图片预加载不会一次性压爆内存。

### 11.4 测试

- [x] 新增 PictureBook mode resolver 测试。
- [x] 新增图片页进度恢复测试。

## 12. Phase 7：漫画阅读器能力收口

- [x] Phase 7 阶段完成

### 12.1 任务

- [x] 保留现有 `ReaderMangaView` 连续滚动和分页能力。
- [x] 将漫画连续/分页行为挂到统一 viewport 协议。
- [x] 横屏双页作为 `MangaPagedViewport` 能力增强，而不是复制独立大逻辑。
- [x] 调整漫画点击、长按、缩放与九宫格点击分区的优先级。
- [x] 优化漫画图片预加载窗口和失败重试。
- [x] 校验漫画模式下底部导航主操作仍是位置面板。

### 12.2 涉及文件

- `lib/features/reader/presentation/reader_manga_view.dart`
- `lib/features/reader/presentation/reader_page_viewport.dart`
- `lib/features/reader/presentation/reader_page_shell.dart`
- `lib/features/reader/application/reader_mode_capabilities.dart`
- `lib/features/reader/application/reader_image_decode_budget.dart`

### 12.3 验收标准

- [x] 现有漫画阅读行为不回退。
- [x] 连续滚动、分页、横向模式状态清晰。
- [x] 缩放时不会触发正文点击分区。

### 12.4 测试

- [x] 回归 `reader_image_pipeline_test.dart`。
- [ ] 新增漫画点击/缩放优先级测试。

## 13. Phase 8：固定版式 EPUB

- [x] Phase 8 阶段完成

### 13.1 任务

- [x] 在 EPUB 解析阶段识别 fixed-layout 信号。
- [x] 区分 EPUB 流式与 EPUB 固定版式。
- [x] 评估固定版式渲染方案：WebView、HTML/CSS 原样渲染、插件方案。
- [x] 新增 `EpubFixedViewport`。
- [x] 支持固定页翻页、缩放和平移。
- [ ] 支持资源路径解析、图片资源加载、CSS 样式保真。
- [ ] 支持目录跳转和页码进度。
- [x] 避免影响现有流式 EPUB 文本解析。

### 13.2 涉及文件

- `lib/features/reader/application/local/epub_local_book_parser.dart`
- `lib/features/reader/application/local/local_chapter_content_service.dart`
- `lib/features/reader/application/reader_content_mode_resolver.dart`
- `lib/features/reader/presentation/reader_epub_fixed_view.dart`

### 13.3 验收标准

- [x] 流式 EPUB 仍走文本模式。
- [x] 固定版式 EPUB 进入 hybrid 模式。
- [x] 固定版式页面资源能正确加载。
- [x] 目录和进度恢复可用。

### 13.4 测试

- [x] 新增 EPUB fixed-layout 识别测试。
- [x] 回归 EPUB 流式解析测试。

## 14. Phase 9：AudioReader 增强

- [x] Phase 9 阶段完成

### 14.1 任务

- [x] 将现有 `ReaderAudioView` 接入统一 viewport 协议。
- [x] 支持播放速度调节。
- [ ] 支持上一段/下一段音频章节。
- [ ] 支持后台播放能力评估与接入。
- [ ] 支持定时停止。
- [x] 支持音频进度保存与恢复到具体时间点。
- [x] 明确音频模式下自动阅读入口隐藏或禁用。

### 14.2 涉及文件

- `lib/features/reader/presentation/reader_audio_view.dart`
- `lib/features/reader/application/audio_reading_mode.dart`
- `lib/features/reader/application/reader_content_session.dart`
- `lib/features/reader/application/reader_session_state.dart`
- `lib/features/reader/application/reader_mode_capabilities.dart`

### 14.3 验收标准

- [x] 现有音频播放不回退。
- [x] 退出阅读器后可恢复音频进度。
- [ ] 音频章节切换和目录跳转可用。

### 14.4 测试

- [x] 更新 `audio_reading_mode_test.dart`。
- [x] 新增音频进度恢复测试。

## 15. Phase 10：跨模式交互治理

- [x] Phase 10 阶段完成

### 15.1 任务

- [x] 梳理九宫格点击分区在 text/hybrid/comic/audio 下的默认行为。
- [x] 梳理长按正文、长按图片、长按 PDF 页、长按漫画页的事件优先级。
- [x] 梳理自动阅读在不同内容模式下的能力开关。
- [x] 梳理目录、书签、笔记、划线在不同内容模式下的可用性。
- [x] 梳理音量键翻页在 text/hybrid/comic/audio 下的行为。
- [x] 梳理夜间模式、亮度、背景在固定页内容下的作用边界。
- [x] 在设置面板里按当前内容模式隐藏或禁用不适用的设置项。

### 15.2 涉及文件

- `lib/features/reader/presentation/reader_page_shell.dart`
- `lib/features/reader/presentation/reader_page_selection.dart`
- `lib/features/reader/presentation/reader_page_settings_sheet.dart`
- `lib/features/reader/presentation/reader_page_navigation.dart`
- `lib/features/reader/application/reader_mode_capabilities.dart`
- `lib/features/reader/application/reader_preferences_service.dart`

### 15.3 验收标准

- [x] 每种内容模式下的点击、长按、滑动、缩放不会互相误触。
- [x] 不可用功能有明确禁用态或提示。
- [x] 新增 hybrid 后不会破坏自动阅读、九宫格和工具栏自动隐藏。

### 15.4 测试

- [ ] 新增跨模式点击分区测试。
- [ ] 新增长按事件路由测试。
- [ ] 回归自动阅读相关测试。

## 16. Phase 11：设置、文档与回归

- [x] Phase 11 阶段完成

### 16.1 任务

- [x] 更新 `PROJECT_FEATURE_MAP.md` 阅读器章节。
- [x] 更新本地书导入与 PDF 策略相关文档。
- [x] 为多模态阅读器补充开发说明。
- [x] 补齐各模式 smoke test 清单。
- [x] 补齐手动回归清单：文本、流式图文、PDF、漫画、听书。
- [x] 建立性能基线：大 PDF、大 EPUB、长漫画章节、长音频章节。
- [x] 明确回滚策略：content mode 扩展、PDF renderer、进度模型升级。

### 16.2 验收标准

- [x] 文档与代码现状一致。
- [x] 每个内容模式至少有一条可执行回归路径。
- [x] 性能和内存风险有记录。
- [x] 后续新增阅读器类型可以按本文协议接入。

## 17. 推荐执行顺序

- [x] Phase 1：内容模式与能力模型扩展
- [x] Phase 2：统一 Reader Viewport 协议
- [x] Phase 3：阅读进度模型升级
- [x] Phase 4：PDF 固定页阅读器
- [x] Phase 5：流式图文文本阅读增强
- [x] Phase 6：绘本/杂志 PictureBookReader
- [x] Phase 7：漫画阅读器能力收口
- [x] Phase 8：固定版式 EPUB
- [x] Phase 9：AudioReader 增强
- [x] Phase 10：跨模式交互治理
- [x] Phase 11：设置、文档与回归

建议优先级：

| 优先级 | 阶段 | 原因 |
|---|---|---|
| P0 | Phase 1-3 | 先补抽象和进度模型，避免后续每种阅读器重复接线 |
| P1 | Phase 4 | PDF 是当前最明显短板，能验证 hybrid 架构是否成立 |
| P1 | Phase 5 | 流式图文已有基础，增强收益高、风险相对低 |
| P2 | Phase 6-8 | 绘本、漫画增强、固定版式 EPUB 按资源投入推进 |
| P3 | Phase 9-11 | 音频增强和文档回归可在核心架构稳定后收口 |

## 18. 执行完成记录

- [x] 2026-05-25：完成多模态架构方向评估。
- [x] 2026-05-25：生成本文档并拆分阶段任务。
- [x] 2026-05-25：完成 Phase 1，扩展 `ReaderContentMode` / `ReaderHybridSubMode`，并接入本地 PDF hybrid 识别。
- [x] 2026-05-25：完成 Phase 2，新增 `ReaderViewportState` / `ReaderViewportStateResolver`，将现有 text/comic/audio 页面运行时接入统一 viewport 适配层。
- [x] 2026-05-25：完成 Phase 3，新增 `ReaderPositionSnapshot`，并将进度保存链路接入兼容快照存储。
- [x] 2026-05-25：完成 Phase 4，接入 `pdfrx` 并新增 `ReaderPdfView`，本地 PDF 进入 Hybrid 固定页阅读路径。
- [x] 2026-05-25：完成 Phase 5，流式图文正文图片支持点击/长按进入全屏预览，并与自动阅读协同。
- [x] 2026-05-25：完成 Phase 6，新增 PictureBook 识别和页码型图片内容路径，复用图片页渲染与进度保存。
- [x] 2026-05-25：完成 Phase 7，漫画与页码型图片内容统一挂入 viewport 进度/交互链路。
- [x] 2026-05-25：完成 Phase 8，固定版式 EPUB 已能识别并进入 Hybrid 路径，保持流式 EPUB 不回退。
- [x] 2026-05-25：完成 Phase 9，听书模式补齐倍速、进度恢复和音频快照持久化。
- [x] 2026-05-25：完成 Phase 10，跨模式自动阅读禁用提示、设置分组显隐和交互口径已收口。
- [x] 2026-05-25：完成 Phase 11，更新阅读器地图、开发说明、手动回归清单与性能/回滚基线。
