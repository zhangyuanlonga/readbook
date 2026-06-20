# 阅读器剩余 Surface 专项审查

**日期**: 2026-06-20  
**范围**: 漫画/图片、PDF/Hybrid、音频/听书、本地解析、换源与缓存  
**关联文档**:

- `docs/features/reader/reader-core-code-review-legado-gap-2026-06-20.md`
- `docs/features/reader/reader-core-modernization-roadmap-2026-06-20.md`

**审查目标**: 补齐核心文本阅读 review 之外的盲区，确认剩余 surface 是否会影响后续 `ReaderLayoutPage / Line / Column` 内核改造。

---

## 1. 总体判断

当前项目不是多个完全独立的阅读器入口，而是一个 `ReaderPage` 主壳下挂多套 surface：

- 文本分页：`ReaderModeViewportKind.textPaged`
- 文本滚动：`ReaderModeViewportKind.textScroll`
- 图片/漫画分页：`ReaderModeViewportKind.imagePaged`
- 图片/漫画滚动：`ReaderModeViewportKind.imageScroll`
- PDF/Hybrid：`ReaderModeViewportKind.hybridPaged`
- 音频/听书：`ReaderModeViewportKind.audio`

入口和模式映射已经比较清楚：

- `reader_mode_model.dart` 定义 viewport kind。
- `reader_content_mode_resolver.dart` 根据章节结果判断 text/comic/hybrid/audio。
- `reader_page_viewport.dart` 根据 `_currentViewportKind` 选择具体 surface。

结论：

- [ ] 后续不要把这些 surface 当成 5 个阅读器分别重写。
- [ ] 保留“一个主 ReaderPage 壳 + 多个 surface”的方向。
- [ ] 优先统一 session/progress/page intent/cache/layout anchor。
- [ ] 文本 layout 内核可以先启动，不需要等漫画、PDF、音频全部重构完。
- [ ] 漫画/PDF/音频需要定义和新内核的边界：它们可以不共享文本排版，但要共享阅读进度、章节窗口、缓存、输入 intent 和状态治理。

---

## 2. Surface Inventory

| Surface | 当前入口 | 主要文件 | 当前状态 | 是否阻塞文本 layout 内核 |
|---|---|---|---|---|
| 文本分页/滚动 | `textPaged` / `textScroll` | `reader_text_paged_view.dart`、`reader_text_scroll_view.dart` | 已深审，核心改造对象 | 是 |
| 漫画/图片 | `imagePaged` / `imageScroll` | `reader_manga_view.dart`、`reader_page_content_rendering.dart` | surface 较独立，但进度/重试仍在主页面 | 否 |
| PDF/Hybrid | `hybridPaged` | `reader_pdf_view.dart`、`pdf_local_book_parser.dart` | viewer 很薄，PDF 索引和展示链路割裂 | 否，但要补边界 |
| 音频/听书 | `audio` | `reader_audio_view.dart`、`reader_audio_controller.dart` | 可播放章节音频，不是完整 TTS/read-aloud | 否 |
| 本地解析 | local parsers | `txt/epub/pdf/html/markdown/kindle` parser | 覆盖格式多，但输出仍被 `ReaderDocument` v1 限制 | 会影响 Phase 6 |
| 换源/缓存 | source switch/cache | `reader_page_source_switch.dart`、`reader_source_switch_*`、`chapter_cache_service.dart` | 服务层已有，UI part 仍重 | 不阻塞 Phase 1，但影响发版稳定 |

---

## 3. 漫画/图片 Surface 审查

### 3.1 当前实现

**主要链路**:

- `ReaderContentModeResolver` 在章节有 `imageUrls` 或 explicit type 为 `manga` 时进入 `ReaderContentMode.comic`。
- `ReaderModeResolver` 根据 `ReaderMangaReadMode.continuous/paged/horizontal` 进入 `imageScroll` 或 `imagePaged`。
- `reader_page_viewport.dart` 调用 `_buildMangaReader` / `_buildMangaViewport`。
- `ReaderMangaView` 内部承接连续滚动、分页、横向分页、缩放、双击放大、重状态保留。

**代码证据**:

- `lib/features/reader/application/reader_content_mode_resolver.dart:16`
- `lib/features/reader/application/reader_mode_model.dart:7`
- `lib/features/reader/presentation/reader_page_viewport.dart:260`
- `lib/features/reader/presentation/reader_manga_view.dart:194`

### 3.2 做得好的地方

- [x] `ReaderMangaView` 已经是独立 widget，不是完全混在 `ReaderPage` build 里。
- [x] 支持连续滚动、分页、横向分页。
- [x] 支持 `InteractiveViewer` 缩放和双击放大。
- [x] 对重状态有保留策略，只保留当前页前后和 zoomed 页面。
- [x] 连续滚动模式使用 `ListView.separated` 和 `scrollCacheExtent`。
- [x] 图片 decode budget 已从主页面传入。

### 3.3 主要风险

#### M1：漫画进度、重试、page controller 仍挂在主 ReaderPage

`_mangaPageIndex`、`_mangaImageRetryNonce`、`_mangaPageController` 仍由 `_ReaderPageState` 持有，`ReaderMangaView` 只负责局部缩放状态。这样漫画 surface 看似独立，但章节切换、阅读进度、图片重试仍是主页面状态的一部分。

影响：

- [ ] 漫画和 PDF 共用 `_mangaPageIndex`，语义不清。
- [ ] PDF page index、漫画 image index、hybrid page index 后续容易互相污染。
- [ ] 图片重试 nonce 和图片缓存策略难以独立测试。

建议：

- [ ] 新建 `ReaderImageSurfaceRuntime`，持有 image index、retry nonce、zoom policy、decode budget。
- [ ] 将 PDF 的 page index 从 `_mangaPageIndex` 中拆出，命名为 `documentPageIndex` 或统一 `ReaderSurfacePosition`。
- [ ] 将漫画/图片 progress 转为 `ReaderVisiblePosition`，由主页面只接收结果，不持有细节字段。

#### M2：图片阅读不共享 page-turn intent

当前漫画分页使用 `PageView` 自己翻页，文本分页使用 page-turn coordinator。漫画被设定为不支持 tap/swipe turn，但用户仍然会期待一致的点击分区、键盘、音量键、鼠标滚轮策略。

建议：

- [ ] 为 image surface 定义 `ReaderSurfacePageIntent`。
- [ ] 键盘/鼠标/音量键先转成 intent，再由 surface 决定是否支持。
- [ ] 漫画连续模式支持滚动 step，分页模式支持 page step。
- [ ] 漫画和文本点击分区可以配置不同 action，但走同一个 interaction resolver。

#### M3：图片真实尺寸和错误恢复还偏显示层

图片由 `ReaderCachedNetworkImage` 渲染，错误时展示固定 3:4 占位。当前不保存图片真实宽高、加载耗时、失败类型，也没有 surface 级 retry policy。

建议：

- [ ] 图片加载结果写入 `ReaderImageSurfaceRuntime`。
- [ ] 保存真实 image width/height/aspect ratio。
- [ ] retry nonce 改成带失败原因和最近失败时间的结构。
- [ ] 对连续长图章节记录内存峰值和 decode budget 命中情况。

### 3.4 测试缺口

- [ ] 漫画连续模式滚动进度恢复。
- [ ] 漫画分页模式 page index 恢复。
- [ ] 横向模式切换后 page controller 重建。
- [ ] 双击缩放后 PageView 禁止滑动，再缩回恢复滑动。
- [ ] 图片失败后 retry nonce 生效。
- [ ] 大量图片章节内存 smoke。

### 3.5 是否阻塞 ReaderLayout Phase 1

不阻塞。漫画可以先保留独立 surface，但需要在 Phase 1 旁边定义 `ReaderSurfacePosition`，避免继续用 `_mangaPageIndex` 表达所有非文本 page index。

---

## 4. PDF / Hybrid Surface 审查

### 4.1 当前实现

**主要链路**:

- `ReaderContentModeResolver` 将 `pdf`、`epub-fixed`、`picture-book`、`document-image` 等识别为 hybrid。
- `reader_page_viewport.dart` 中 `_buildHybridReader` 判断 `ReaderHybridSubMode.pdf` 后使用 `ReaderPdfView`。
- 非 PDF hybrid 当前回退到 `_buildMangaReader`。
- `ReaderPdfView` 使用 `pdfrx` 的 `PdfViewer.file`。
- `PdfLocalBookParser` 建立按页章节索引，文本抽取通过 `pdf_text_extract`，仅 Android/iOS 支持。

**代码证据**:

- `lib/features/reader/application/reader_content_mode_resolver.dart:28`
- `lib/features/reader/presentation/reader_page_viewport.dart:229`
- `lib/features/reader/presentation/reader_pdf_view.dart:6`
- `lib/features/reader/application/local/pdf_local_book_parser.dart:17`

### 4.2 做得好的地方

- [x] PDF visual viewer 被隔离在 `ReaderPdfView`，没有把 `pdfrx` API 扩散到主页面。
- [x] PDF parser 采用轻索引：每页一个 chapter，按需 `parsePage` 抽取文本。
- [x] 对加密、无文本层、页码缺失等错误有业务化异常。
- [x] Hybrid sub mode 已为 fixed EPUB、picture book、document image 预留。

### 4.3 主要风险

#### P1：PDF viewer 状态太薄，和阅读 session 没形成完整契约

`ReaderPdfView` 只接收 `filePath/initialPage/onPageChanged/onViewerReady`。主页面只传 `onPageChanged`，没有使用 `onViewerReady` 同步真实页数，也没有保存 zoom/scroll position。

影响：

- [ ] PDF 总页数依赖 session/index，不一定等于 viewer 实际页数。
- [ ] 只保存 page index，不保存 page 内位置和 zoom。
- [ ] PDF 旋转、缩放、横竖屏切换后恢复能力弱。

建议：

- [ ] 新建 `ReaderDocumentSurfaceRuntime`，字段包含 `pageIndex`、`pageCount`、`zoomScale`、`scrollOffsetInPage`。
- [ ] `_buildHybridReader` 使用 `onViewerReady` 回写实际 pageCount。
- [ ] 阅读记录区分 `textPageIndex`、`imageIndex`、`documentPageIndex`，不要共用 `_mangaPageIndex`。

#### P2：`ReaderPdfView` 在 build 中同步查文件

`ReaderPdfView.build` 中使用 `File(filePath).existsSync()`。这类同步 IO 不一定会造成大问题，但 build 阶段做文件系统访问不是理想路径。

建议：

- [ ] 文件存在性检查前移到 content loading/session resolver。
- [ ] `ReaderPdfView` 只渲染已验证的 file 或错误状态。
- [ ] 给 PDF 缺文件增加 reader-level recovery action。

#### P3：PDF viewer controller 未显式释放

`ReaderPdfView` 创建了 `PdfViewerController`，但 `dispose` 只调用 `super.dispose()`。需要确认 `PdfViewerController` 是否有 dispose 语义；如果有，当前可能有资源泄漏风险。

建议：

- [ ] 查 `pdfrx` controller 生命周期。
- [ ] 如支持 dispose，则在 `ReaderPdfView.dispose` 释放。
- [ ] 增加 widget smoke：打开/关闭 PDF 不残留 controller。

#### P4：Hybrid 非 PDF 基本回退到漫画 surface

fixed EPUB、picture book、document image 目前都走 `_buildMangaReader`。这对纯图片绘本可用，但对 fixed EPUB 的页面尺寸、链接、文字层、脚注、区域点击不够。

建议：

- [ ] 定义 `ReaderHybridSurfaceKind`: pdfViewer、fixedLayoutPages、imageDocument。
- [ ] fixed EPUB 输出 page model，而不是只输出 imageUrls。
- [ ] document image 保存 OCR/text layer 预留字段。
- [ ] picture book 允许图片 surface，但用 document page index 表达进度。

### 4.4 测试缺口

- [ ] `ReaderPdfView` 缺文件错误 widget test。
- [ ] PDF viewer ready 后 pageCount 同步测试。
- [ ] PDF page index 恢复测试。
- [ ] PDF 打开/关闭 controller 生命周期测试。
- [ ] fixed EPUB / picture book / scanned document 的 hybrid 分流测试。
- [ ] PDF 文本抽取和视觉 viewer 页码一致性测试。

### 4.5 是否阻塞 ReaderLayout Phase 1

不阻塞。PDF 和 hybrid 可以继续独立，但必须尽早拆出 `documentPageIndex`，不要继续复用漫画字段。Phase 6 做 `ReaderDocument v2` 时再处理 fixed EPUB 和 document image。

---

## 5. 音频 / 听书 Surface 审查

### 5.1 当前实现

**主要链路**:

- `ReaderContentModeResolver` 在 `hasAudioContent` 或 explicit type 为 `audio` 时进入 audio mode。
- `reader_page_viewport.dart` 的 `_buildAudioReader` 构造 `ReaderAudioViewModel`，注入 `ReaderAudioController`。
- `ReaderAudioView` 使用 `AnimatedBuilder` 监听 controller，展示播放进度、快进快退、上一章/下一章、倍速、错误详情、外部打开、复制地址。
- `ReaderAudioController` 封装 `just_audio`。

**代码证据**:

- `lib/features/reader/application/reader_content_mode_resolver.dart:10`
- `lib/features/reader/presentation/reader_page_viewport.dart:186`
- `lib/features/reader/presentation/reader_audio_view.dart:36`
- `lib/features/reader/application/reader_audio_controller.dart:92`

### 5.2 做得好的地方

- [x] 音频播放控制器已独立，不直接把 `AudioPlayer` 放在 view 内。
- [x] 支持章节音频 URL、manifest URL、headers。
- [x] 支持播放/暂停、seek、倍速、重试、生命周期暂停恢复。
- [x] 错误信息保留原始详情，便于反馈。
- [x] 阅读记录已有 audio position/duration/speed 字段。

### 5.3 主要风险

#### A1：当前是“章节音频播放器”，不是完整 TTS/read-aloud

`AudioReadingMode` 里预留了 sleep timer、background playback、lock screen controls，但 controller 中 `setSleepTimer`、`skipNext`、`skipPrevious` 仍是空实现或后置 milestone。

影响：

- [ ] 不能把当前 audio surface 视为主流阅读器的朗读功能。
- [ ] 文本 read-aloud 高亮、句子定位、自动翻页尚未和音频打通。
- [ ] 后台播放、锁屏控制、媒体按键需要平台层补齐。

建议：

- [ ] 区分 `ChapterAudioSurface` 和 `TextToSpeechReadAloud`。
- [ ] TTS/read-aloud 后续基于 `ReaderLayoutRange` 做高亮和翻页。
- [ ] 章节音频保留当前 controller，但补 sleep timer、skip next/previous、media session。

#### A2：Audio view 每次 position tick 会重建整块面板

`ReaderAudioView` 用单个 `AnimatedBuilder` 包住整个音频面板，`positionStream` 更新时可能导致 header、更多操作、按钮等整块 rebuild。

建议：

- [ ] 将 progress slider 抽为独立 `AnimatedBuilder` 或 selector。
- [ ] Header、more actions、chapter info 只在 session/status 变化时 rebuild。
- [ ] 对长音频播放做 frame/rebuild profile。

#### A3：configure 由 view post-frame 触发，语义偏 UI

`ReaderAudioView` 在 `initState/didUpdateWidget` 中 post-frame 调用 `_controller.configure`。controller 有 configurationKey 防重复，但初始化仍由 UI 生命周期驱动。

建议：

- [ ] 将音频 configure 移到 `ReaderMediaRuntime` 或 session activation 阶段。
- [ ] View 只展示 controller state 和派发用户 action。
- [ ] 生命周期暂停/恢复由 reader runtime 统一调用，不散在 view。

### 5.4 测试缺口

- [ ] `ReaderAudioView` widget test：播放态、错误态、无 URL、紧凑宽度。
- [ ] position tick rebuild profile。
- [ ] lifecycle pause/resume 集成测试。
- [ ] 章节切换后保留/重置速度和位置测试。
- [ ] sleep timer、skip next/previous、媒体按键后续测试。
- [ ] TTS/read-aloud 与 layout range 的测试，等 Phase 4 后补。

### 5.5 是否阻塞 ReaderLayout Phase 1

不阻塞。章节音频可以继续独立。真正需要 layout 的是文本 TTS/read-aloud，应等 `ReaderLayoutRange` 建好后再做。

---

## 6. 本地解析链路专项审查

### 6.1 当前实现

**主要链路**:

- `LocalBookIndexService` 注册 TXT、EPUB、Markdown、HTML、PDF、Kindle parser。
- `LocalBookIndexService` 使用 `Pool(2)` 限制索引并发，并有 active task 去重。
- `TxtLocalBookParser` 支持大 TXT 和编码检测。
- `EpubLocalBookParser` 使用定制实现，保留 fixed-layout、inline image、本地资源物化。
- `PdfLocalBookParser` 建立 page chapter，并按需抽取 page text。
- `LocalChapterReadableDocumentNormalizer` 在本地章节出口统一补 `ReaderDocument`。

**代码证据**:

- `lib/features/reader/application/local/local_book_index_service.dart:41`
- `lib/features/reader/application/local/local_book_index_service.dart:66`
- `lib/features/reader/application/local/epub_local_book_parser.dart:21`
- `lib/features/reader/application/local/epub_local_book_parser.dart:137`
- `lib/features/reader/application/local/pdf_local_book_parser.dart:58`
- `lib/features/reader/application/local/local_chapter_content_service.dart:30`

### 6.2 做得好的地方

- [x] 本地解析格式覆盖广：TXT、EPUB、Markdown、HTML、PDF、MOBI/AZW/AZW3。
- [x] 索引有并发池和 active task 去重。
- [x] EPUB 解析已把部分重活放到 `Isolate.run`。
- [x] PDF 采用轻索引，避免导入时抽取所有文本。
- [x] 本地章节出口有 normalizer，降低不同 parser 输出不一致。
- [x] 测试覆盖较多，尤其 TXT 大文件、EPUB、PDF parser、encoding detector。

### 6.3 主要风险

#### L1：解析输出最终仍受 `ReaderDocument v1` 限制

本地 parser 即使识别了 HTML/EPUB 结构，最终也会落到粗粒度 `ReaderDocument`：text/list/quote/caption/footnote/image/title。inline span、link、style run、footnote target、图片真实尺寸等信息丢失。

影响：

- [ ] 后续 layout engine 无法恢复已丢失的 EPUB/HTML 语义。
- [ ] fixed EPUB、图文混排、脚注、链接点击会继续不稳定。

建议：

- [ ] Phase 6 前先定义 `ReaderDocument v2`。
- [ ] Parser 输出 block + inline node，不再只输出 compatibility content。
- [ ] LocalParsedChapter 保留 v1 compatibility 字段，同时新增 v2 semantic payload。

#### L2：LocalChapter normalizer 会把缺失 image marker 的图片补到正文末尾

这能避免图片丢失，但会破坏原始图文顺序。对“旧数据只有 imageUrls”是合理兜底，但不能作为长期混排策略。

建议：

- [ ] 给 normalizer 输出标记：`imageOrderRecovered = fallbackAppend`。
- [ ] 对 fallback append 的章节在布局层显示诊断或降级。
- [ ] 新 parser 必须提供图片所在 block/inline 位置。

#### L3：EPUB parser 仍是大文件高复杂度模块

`epub_local_book_parser.dart` 约 2139 行，虽然有注释说明替换条件，也接入了 `epub_pro` adapter，但它仍是后续 document v2 的高风险入口。

建议：

- [ ] 不在 Phase 1/2 重写 EPUB parser。
- [ ] 先给 EPUB parser 输出加 contract test：标题、图片、链接、fixed-layout、章节定位。
- [ ] Phase 6 时只加 v2 输出 adapter，不直接删旧逻辑。

#### L4：索引 timeout 不是硬取消

`LocalBookIndexService` 对 parser 调用 `.timeout(_indexTimeout)`，但 timeout 不一定能取消底层解析工作，尤其是文件 IO、第三方库解析或 isolate 任务。

建议：

- [ ] 为 parser 增加可选 cancellation token。
- [ ] 对 isolate parser 建立可取消 worker 方案。
- [ ] 对超大 EPUB/MOBI 做解析中断和资源释放测试。

### 6.4 测试缺口

- [ ] Parser 输出 `ReaderDocument v2` 的 contract test。
- [ ] EPUB fixed-layout 到 hybrid surface 的端到端测试。
- [ ] EPUB link/footnote/image order 测试。
- [ ] Normalizer fallback append 的显式测试。
- [ ] 本地索引 timeout 后资源释放测试。
- [ ] MOBI/AZW 大文件解析性能测试。
- [ ] PDF visual page 和 parser page text 一致性测试。

### 6.5 是否阻塞 ReaderLayout Phase 1

不阻塞 Phase 1，因为 Phase 1 可以从旧 `ReaderDocument` 适配。但会影响 Phase 6。建议先在 Phase 1 中预留 document v2 adapter，不要把 v1 写死进 layout model。

---

## 7. 换源与缓存链路专项审查

### 7.1 当前实现

**主要链路**:

- `reader_page_source_switch.dart` 是 `ReaderPage` 的 part extension，串起会员校验、候选搜索、候选 sheet、取消 token、应用候选。
- `ReaderSourceSwitchCoordinator` 负责可切换判断、关键词、自动换源、书架迁移策略。
- `ReaderSourceSwitchService` 负责目标章节匹配和阅读进度迁移计划。
- `ChapterCacheService` 支持章节范围缓存、并发限制、取消 token、source health 降并发。
- `ReaderChapterContentCacheStore` 把章节正文存入 Drift chapter caches。
- `ReaderPreloadController` 产出 content/pagination/image 预加载任务。

**代码证据**:

- `lib/features/reader/presentation/reader_page_source_switch.dart:5`
- `lib/features/reader/application/reader_source_switch_coordinator.dart:72`
- `lib/features/reader/application/reader_source_switch_service.dart:59`
- `lib/features/reader/application/chapter_cache_service.dart:45`
- `lib/features/reader/application/reader_chapter_content_cache_store.dart:45`
- `lib/features/reader/application/reader_preload_controller.dart:86`

### 7.2 做得好的地方

- [x] 换源已经有 coordinator/service/target resolver 单测。
- [x] 手动换源有 cancellation token，候选加载可取消。
- [x] 章节缓存有 per-chapter timeout 和并发控制。
- [x] Source health 会影响缓存并发，降低浏览器风险源的压力。
- [x] 预加载有 resource budget、失败冷却、nearby/far priority。
- [x] 章节缓存 store 已接入通用 cache key/policy/result 体系。

### 7.3 主要风险

#### S1：换源 UI part 仍承担过多流程编排

`reader_page_source_switch.dart` 仍在 `_ReaderPageState` extension 里串联会员校验、scope 构建、score store、候选搜索、sheet、取消、应用候选。虽然服务层已经抽了不少纯逻辑，但流程编排仍与 UI 状态强绑定。

建议：

- [ ] 新建 `ReaderSourceSwitchRuntimeController`。
- [ ] 将 membership decision、lookup state、cancellation token、candidate selection 迁出 part。
- [ ] `ReaderPage` 只负责打开 sheet 和执行 runtime result。
- [ ] 保留 membership UI 入口，但把会员策略作为 injectable guard。

#### S2：换源进度迁移仍基于 logical position，不是未来 layout position

`ReaderSourceSwitchService` 使用 `ReaderLogicalPosition` 和 chapter ratio 做迁移。文本 layout 内核完成后，换源应优先使用 `ReaderLayoutPosition` 或 `chapterOffset + semantic anchor`，再 fallback 到 ratio。

建议：

- [ ] Phase 4 后升级换源迁移输入：`ReaderLayoutAnchor`。
- [ ] 匹配目标章节后，用标题、段落片段、offset、ratio 多信号定位。
- [ ] 对漫画/PDF/audio 使用 `ReaderSurfacePosition`，不要用文本 ratio。

#### S3：章节缓存仍是正文字符串缓存，不是 layout/document cache

`ReaderChapterContentCacheStore` 的 payload 是 cached.content。它可以缓存正文，但无法缓存 `ReaderDocument v2`、layout pages、图片 metadata、音频 manifest 解析结果。

建议：

- [ ] 保留 chapter content cache 作为原始内容缓存。
- [ ] 新增 `ReaderDocumentCacheStore`，缓存 parser/document 输出。
- [ ] 新增 `ReaderLayoutCacheStore`，缓存 layout pages。
- [ ] 缓存 key 加入 document version、layout signature、parser version。

#### S4：预加载任务类型有 image，但默认未打开

`ReaderPreloadController` 支持 content/pagination/image 三类任务，但 `includeImageWarmup` 默认 false。漫画/图文章节实际体验可能依赖图片预热。

建议：

- [ ] 对 comic/hybrid picture book 打开 image warmup。
- [ ] image warmup 受 image decode budget 和网络策略控制。
- [ ] 记录 image preload 成功率和内存影响。

### 7.4 测试缺口

- [ ] 换源 runtime 流程测试：会员通过/拒绝、取消、候选为空、应用候选。
- [ ] 换源后漫画/PDF/audio 进度迁移测试。
- [ ] 缓存 key 版本升级和旧缓存失效测试。
- [ ] document cache/layout cache 命中测试。
- [ ] image preload 在 comic/hybrid 下的预算测试。
- [ ] source health 降并发的端到端缓存测试。

### 7.5 是否阻塞 ReaderLayout Phase 1

不阻塞。换源和缓存可以并行收口。Phase 1 只需要确保新的 layout cache 不复用正文缓存 schema。

---

## 8. 已有测试保护总结

当前已有测试覆盖：

- [x] `ReaderMangaView` 有 rendering memory smoke。
- [x] `ReaderAudioController` 有 application 测试。
- [x] `AudioReadingMode` 有模型测试。
- [x] `PdfLocalBookParser` 有 parser 测试。
- [x] `EpubLocalBookParser`、`TxtLocalBookParser`、`KindleLocalBookParser`、Markdown/HTML parser 有测试。
- [x] `ReaderSourceSwitchCoordinator/Service/TargetResolver` 有测试。
- [x] `ChapterCacheService`、`ReaderChapterContentCacheStore`、`ReaderPreloadController` 有测试。

当前缺少：

- [ ] `ReaderPdfView` widget/lifecycle test。
- [ ] `ReaderAudioView` widget/rebuild profile。
- [ ] 漫画 page index/zoom/continuous progress 行为测试。
- [ ] hybrid fixed EPUB / picture book / scanned document 端到端测试。
- [ ] 本地 parser 到 surface 的端到端测试。
- [ ] 换源后不同 surface 的进度迁移测试。

---

## 9. 对后续路线图的修正建议

基于本次专项审查，建议对改造顺序做轻微补充：

### 9.1 Phase 0 增补

- [ ] 增加漫画样本：连续长图、分页漫画、横向漫画。
- [ ] 增加 PDF 样本：普通文本 PDF、扫描 PDF、加密 PDF、大页数 PDF。
- [ ] 增加 fixed EPUB/picture book 样本。
- [ ] 增加章节音频样本：直链音频、manifest 音频、带 headers 音频、失败音频。
- [ ] 增加换源样本：同名章节、章节偏移、漫画源、音频源。

### 9.2 Phase 1 增补

- [ ] 在 `ReaderLayoutPosition` 之外新增 `ReaderSurfacePosition`。
- [ ] `ReaderSurfacePosition` 支持 text layout position、image index、document page index、audio position。
- [ ] 阅读记录从“文本/page/manga/audio 混合字段”逐步迁移到 surface position snapshot。

### 9.3 Phase 2/3 增补

- [ ] Layout cache 与 chapter content cache 分离。
- [ ] 图片章节走 image warmup，不强行进入 text layout engine。
- [ ] Hybrid fixed EPUB 先按 document page model，不直接混入 text page model。

### 9.4 Phase 4 增补

- [ ] 换源迁移从 `ReaderLogicalPosition` 升级到 `ReaderSurfacePosition`。
- [ ] 文本使用 layout anchor，漫画/PDF 使用 page/image anchor，音频使用 audio position anchor。

### 9.5 Phase 7 增补

- [ ] 音频章节播放和 TTS/read-aloud 分开建模。
- [ ] TTS/read-aloud 使用 `ReaderLayoutRange`，章节音频使用 `AudioPlaybackState`。
- [ ] PDF/Hybrid 设置不要混入漫画设置，单独建 document surface 设置。

---

## 10. 推荐下一步执行

### 立即可做

- [ ] 新增 `ReaderSurfacePosition` 设计草案。
- [ ] 将 `_mangaPageIndex` 拆分设计为 `imageIndex/documentPageIndex`。
- [ ] 给 `ReaderPdfView` 补生命周期审查 issue。
- [ ] 给 `ReaderAudioView` 补 rebuild/profile 任务。
- [ ] 把本次专项样本加入 Phase 0 样本库清单。

### 不建议现在做

- [ ] 不建议先重写漫画 view。
- [ ] 不建议先重写 PDF viewer。
- [ ] 不建议把音频播放和 TTS 一次性混做。
- [ ] 不建议先改本地 parser 大结构。
- [ ] 不建议先重构换源全流程。

### 最稳路径

- [ ] 先做 Phase 0 样本和保护线。
- [ ] 再做 `ReaderLayoutPage/Line/Column`。
- [ ] 同时设计 `ReaderSurfacePosition`，给漫画/PDF/音频留位置。
- [ ] 文本 layout 稳定后，再逐步把 selection/annotation/read-aloud/source-switch migration 切到新 anchor。

