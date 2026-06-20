# 阅读器核心 Code Review：与 Legado 阅读内核差距审查

**日期**: 2026-06-20  
**范围**: `lib/features/reader/`、`lib/domain/entities/reader_*`  
**对照源码**:

- `/Users/zhangyuanlong/Downloads/legado-own`
- `/Users/zhangyuanlong/Downloads/legado-with-MD3-main`

**审查目标**: 判断当前阅读器和主流阅读器能力的差距，筛出做得不对、做得不够好、缺失的核心能力，并为后续改造提供依据。

---

## 1. 总体结论

当前阅读器已经完成了多轮拆分，具备较多用户侧功能：字体、行距、背景、翻页模式、纸页动画、自动阅读、音频、漫画、点击分区、分页缓存、设置持久化、基础选择/标注等。这些不是问题。

真正的问题在于：当前实现还没有形成“阅读内核”。它更像是一个大型 Flutter 页面，通过多个 controller/helper 维持运行；而 Legado 的成熟度来自独立的排版实体、页/行/列坐标、后台分页、页面工厂、动画委托和数据源边界。

所以后续不建议继续只做 UI 微调或继续拆小文件。优先级应从“让页面看起来更整洁”切到“补阅读器内核”：

- [ ] 建立页、行、列、块、内联资源的布局实体。
- [ ] 把分页/排版从 UI 状态中移出，并支持增量、后台、可取消。
- [ ] 让选择、标注、朗读、搜索都基于布局坐标，而不是 display offset 反推。
- [ ] 将翻页动画和跨章节切换从 `_ReaderPageState` 中解耦成独立委托。
- [ ] 补齐中文排版、混排、HTML/EPUB 语义和成熟设置项。

### 1.1 V 节点落地追踪

本审查的目标不是只做文档结论，而是持续约束后续 V 节点。当前映射如下：

- [x] V1 已覆盖布局实体、旧分页 adapter、hit-test/range service 的底座。
- [x] V2 已覆盖 layout request/spec、stream controller、cache、中文策略 alpha。
- [x] V3 已覆盖新 layout renderer preview/ready/fallback alpha。
- [x] V4 已覆盖 selection、annotation、bookmark、search、read-aloud anchor alpha。
- [x] V5 已覆盖漫画、PDF、音频、EPUB 混排 surface 语义 alpha。
- [x] V6 已覆盖正式入口、release policy、diagnostics 和 fallback alpha。
- [ ] V7 新增为旧能力承接与功能等价节点，专门处理“新 renderer 已有，但旧阅读器能力未接全”的问题。
- [ ] V7 前，不应把新 renderer 视为旧阅读器的完整替代。

---

## 2. 当前代码基线

- `lib/features/reader` 当前约 241 个 Dart 文件，总行数约 73,935 行。
- 最大文件仍集中在阅读器 presentation/application 核心：
  - `reader_page.dart`: 5433 行。
  - `reader_page_runtime.dart`: 2158 行。
  - `epub_local_book_parser.dart`: 2139 行。
  - `reader_catalog_sheet.dart`: 1903 行。
  - `reader_page_content_loading.dart`: 1359 行。
  - `reader_preferences_service.dart`: 1173 行。
  - `reader_pagination_cache_service.dart`: 1075 行。
  - `reader_page_selection.dart`: 1027 行。
  - `reader_page_source_switch.dart`: 1026 行。

这说明前几轮拆分已经降低了一些局部风险，但核心复杂度仍集中在 reader 主链路。

---

## 3. 对照 Legado 后的关键发现

### 3.1 P0：阅读器仍是 God State，拆文件没有真正形成内核边界

**本项目证据**:

- `lib/features/reader/presentation/reader_page.dart:724-872` 同时持有章节、书源、内容、文档、段落、图片、音频、选择、书签、漫画、进度、多个 timer、订阅、设备信息、亮度、自动阅读、分页、动画 controller、连续阅读章节 key 等状态。
- `lib/features/reader/presentation/reader_page_runtime.dart:1605-1893` 执行翻页计划、跨章节快照、等待 frame、截图、动画提交，仍依赖 `_ReaderPageState` 的 UI 状态和 render tree。
- `reader_page.dart` 的 part 文件减少了主文件直接行数，但很多 part 仍是 `part of 'reader_page.dart'`，实际共享同一个私有状态池。

**Legado 对照**:

- `ReadView.kt` 实现 `DataSource` 和 `LayoutProgressListener`，协调 `TextPageFactory`、`PageDelegate`、`PageView`。
- `PageFactory.kt` 负责上一页、下一页、当前页、跨章页。
- `PageDelegate.kt` 负责动画生命周期、触摸、绘制、上一页/下一页判断。
- `TextChapterLayout.kt` 负责章节排版和 page completed 回调。

**风险**:

- 新增一个能力通常要碰主页面状态，回归面过大。
- 动画、分页、选择、内容加载、设置变更之间互相牵连。
- 修 bug 容易依赖局部状态顺序，缺少可测试内核。

**建议**:

- [ ] 将 reader 运行时拆成 `ReaderSessionRuntime`、`ReaderLayoutRuntime`、`ReaderPageTurnRuntime`、`ReaderSelectionRuntime`、`ReaderMediaRuntime`。
- [ ] `_ReaderPageState` 只保留 widget 生命周期、controller 注入、UI 事件转发。
- [ ] 禁止新增业务状态直接挂到 `_ReaderPageState`。

---

### 3.2 P0：分页模型过薄，无法支撑主流阅读器级排版能力

**本项目证据**:

- `lib/features/reader/application/reader_pagination_models.dart:5-24` 的 `ReaderPagedSlice` 只有 `paragraphIndex/start/end/height`。
- `lib/features/reader/application/reader_pagination_models.dart:26-94` 的 `ReaderPagedBlock` 只有 text/image 两类，缺少行、列、span、链接、图片尺寸、命中区域、章节位置。
- `lib/domain/entities/reader_document.dart:5-167` 只定义 text/list/quote/caption/footnote/image/title 等粗粒度 block。
- `lib/domain/entities/reader_document.dart:198-238` 从纯文本拆段落，图片通过 marker 识别，混排语义较弱。

**Legado 对照**:

- `TextPage.kt` 保存页索引、章节位置、行集合、渲染高度、朗读 span、搜索结果、双页状态。
- `TextLine.kt` 保存行文本、列集合、lineTop/lineBase/lineBottom、paragraphNum、chapterPosition、pagePosition、isTitle/isImage/isHtml 等。
- `TextColumn.kt`、`ImageColumn.kt` 保存字符列或图片列位置，用于绘制、命中、选择、搜索、朗读高亮。

**风险**:

- 当前分页只能回答“这一页有哪些段落切片”，不能稳定回答“某个坐标对应哪个字符/图片/链接”。
- 选择、标注、朗读、搜索、高亮、点击图片/链接都只能额外反推，越补越脆。
- EPUB/HTML 混排和中文排版能力上限被模型限制。

**建议**:

- [ ] 新增 `ReaderLayoutPage`，至少包含 `pageIndex`、`chapterId`、`chapterIndex`、`startOffset`、`endOffset`、`height`、`lines`、`blocks`。
- [ ] 新增 `ReaderLayoutLine`，至少包含 `text`、`chapterOffset`、`pageOffset`、`paragraphIndex`、`lineTop`、`lineBase`、`lineBottom`、`columns`、`flags`。
- [ ] 新增 `ReaderLayoutColumn`，支持 text/image/link/inlineWidget，并包含 start/end、rect、style、semantic payload。
- [ ] 让旧 `ReaderPagedSlice` 作为兼容 adapter，而不是长期核心模型。

---

### 3.3 P0：分页仍在 UI 侧用 TextPainter 反复测量，长章节和复杂排版有明显性能风险

**本项目证据**:

- `lib/features/reader/application/reader_pagination_engine.dart:294-313` 在 engine 内直接创建并复用 `TextPainter`。
- `reader_pagination_engine.dart:316-370` 通过 `computeLineMetrics` 和 `getPositionForOffset` 计算 fit length。
- `reader_pagination_engine.dart:406-505` 对段落和切片循环反复 measure。
- `reader_pagination_engine.dart:391-404` 只通过 `Future.delayed(Duration.zero)` 让出事件循环，不是真正离开主 isolate。
- `reader_pagination_cache_service.dart` 读写 JSON 时保存完整 paragraphs 和 pages，缓存实体也偏 UI 侧 slice。

**Legado 对照**:

- `TextChapterLayout.kt:130-149` 使用后台 coroutine，在 IO 上进行章节布局。
- `TextChapterLayout.kt:172-188` 每完成一页就通过 channel/listener 回传。
- `TextMeasure.kt` 有字符宽度缓存和中文测量优化。
- `ZhLayout.kt` 实现中文标点、分词和断行规则。

**风险**:

- 超长章节、超长段落、EPUB 混排、字体/边距频繁变化时可能造成 jank。
- `Future.delayed(Duration.zero)` 可以降低连续阻塞，但无法避免 UI isolate 被大量布局计算占用。
- 缓存粒度不够，设置变化后重排成本高。

**建议**:

- [ ] 将纯布局输入抽成 isolate-safe DTO，避免携带 Flutter widget/context。
- [ ] 用 isolate/worker 执行可序列化的布局计划，UI isolate 只做最终绘制。
- [ ] 支持 incremental page stream：优先产出当前页和前后页，再继续后台排全章。
- [ ] 缓存 `ReaderLayoutPage` 或 layout binary/json，而不是只缓存 paragraph slice。
- [ ] 建立性能预算：首屏分页、跳页、字体变化、超长段落、混排图片都要有耗时上限。

---

### 3.4 P1：选择、标注、朗读锚点依赖 display offset，混排/跨页时不可靠

**本项目证据**:

- `lib/features/reader/presentation/reader_page_selection.dart:4-13` 使用 Flutter `SelectionArea` 和 `SelectionListener`。
- `reader_page_selection.dart:321-417` 从 `SelectedContentRange` 读取 display offset，再转成章节 offset。
- `lib/features/reader/presentation/reader_text_offset_mapper.dart:3-122` 按 paragraph/slice offset 反算章节 offset，并假设段落之间 `+2`。
- `reader_page_selection.dart:105-200` bookmark tap 在 slice 内再次使用 TextPainter 做局部命中。

**Legado 对照**:

- `ReadView.kt` 长按后按 line/column 定位文字。
- `TextPage.getPosByLineColumn` 能从页、行、列直接得到阅读位置。
- `TextLine.chapterPosition`、`TextLine.pagePosition` 是选择、朗读、搜索、高亮的共同坐标。

**风险**:

- 分页模式和滚动模式的 offset 体系不一致。
- 选择跨页、段首缩进、图片、HTML span、标题、脚注、注音/emoji 等场景可能出现错位。
- 朗读高亮和标注恢复可能跟实际可见文字不同步。

**建议**:

- [ ] 所有 selection/bookmark/read-aloud/search anchor 统一存 `chapterOffset + layout position`。
- [ ] 提供 `hitTest(Offset) -> ReaderLayoutPosition`。
- [ ] 提供 `rangeToRects(startOffset, endOffset) -> List<Rect>`。
- [ ] 只有系统复制仍使用 Flutter selection，业务语义不要依赖 display offset。

---

### 3.5 P1：翻页动画抽象已开始，但仍和 UI 快照、主状态强耦合

**本项目证据**:

- `lib/features/reader/presentation/paged_animation/paged_animation_renderer_registry.dart:17-28` 中 `curl`、`paperCurl`、`none` 在轻量 renderer 内都回退到 fade。
- `lib/features/reader/presentation/reader_page_runtime.dart:1684-1850` 跨章节翻页直接等待跳章、等待 frame、截图、启动动画。
- `reader_page_runtime.dart:1872-1893` 通过 `RenderRepaintBoundary.toImage` 捕获当前内容快照。

**Legado 对照**:

- `PageDelegate.kt` 抽象 `abortAnim`、`onAnimStart`、`onDraw`、`onAnimStop`、`nextPageByAnim`、`prevPageByAnim`、`onTouch`。
- `HorizontalPageDelegate.kt`、`SimulationPageDelegate.kt`、`CoverPageDelegate.kt`、`ScrollPageDelegate.kt` 分别承接动画实现。
- 页面源由 `TextPageFactory` 提供，动画委托不需要知道章节加载细节。

**风险**:

- 新增动画样式会继续碰运行时状态和快照逻辑。
- 跨章节时截图失败、frame 等待、内容尚未 ready 等边界多，行为难推理。
- 动画实现无法独立测试。

**建议**:

- [ ] 新增 `ReaderPageTurnDelegate` 抽象，明确输入 `fromPage/toPage/direction/style/source`，输出 `started/committed/cancelled/rejected`。
- [ ] 跨章节先由 page factory 产出目标 page snapshot，再交给 delegate。
- [ ] 保留截图作为过渡兼容，但不再让它成为唯一跨章节动画基础。

---

### 3.6 P1：EPUB/HTML/混排语义不够，内容模型被过早拍平

**本项目证据**:

- `ReaderDocument` 的 block 类型有限，缺少 inline span、link、style run、真实图片尺寸、footnote link、anchor、HTML node metadata。
- `reader_pagination_engine.dart` 对图片主要按 placeholder aspect ratio 估高。
- `reader_document_render_model.dart` 将 document 转为 text/image render item，表达力仍偏简单。

**Legado 对照**:

- `TextChapterLayout.kt` 支持 HTML span、图片、颜色、尺寸、链接、特殊样式。
- 图片列支持 width/style/click，混在行列模型里。
- `TitleStyleParser.kt` 支持标题分段和缩放。
- `ReadBookConfig.kt` 中标题、下划线、边距、中文布局等配置直接影响排版。

**风险**:

- EPUB 复杂章节和 HTML 章节展示会和主流阅读器差距明显。
- 图片、链接、脚注、标题样式难以稳定点击和恢复。
- 后续想补功能会被现有简化模型卡住。

**建议**:

- [ ] 将 `ReaderDocument` 升级为 block + inline span 模型。
- [ ] 图片 block/inline image 保存真实尺寸、alt、href/click action、caption、loading state。
- [ ] HTML/EPUB parser 输出语义节点，而不是直接输出纯段落。
- [ ] 排版层处理语义节点到 layout columns 的映射。

---

### 3.7 P2：设置面广但成熟阅读器关键项缺失，且部分设置没有深入排版内核

**本项目已覆盖**:

- 字号、行高、边距、段距、首行缩进、两端对齐、底部对齐。
- 亮度、主题、背景、字体来源、字体粗细、字体阴影。
- 翻页模式、动画样式、音量键、自动阅读、音频速度。
- 漫画连续/分页/横向、图片间距、加载策略。
- 信息栏、章节标题、点击分区。

**Legado 对照缺口**:

- `useZhLayout`: 中文断行/标点避头尾/词宽缓存。
- 标题分段、标题缩放、标题段距、标题特殊样式。
- 双页/横向阅读。
- 文本和漫画独立九宫格点击配置。
- 硬件按键、长按翻页、鼠标滚轮、播放中音量键策略。
- 渲染缓存/优化开关。
- TTS 引擎、朗读定时、媒体按键等完整朗读链路。

**建议**:

- [ ] 先补能驱动排版内核的设置，不急于补纯 UI 设置。
- [ ] 新设置必须进入 pagination/layout signature，否则设置变化后无法保证重排正确。
- [ ] 点击分区、硬件键、鼠标滚轮等输入策略应统一到 interaction intent 层。

---

## 4. 当前已有亮点

- [x] 已有较多 reader application/presentation 单测，不是无保护状态。
- [x] `ReaderNavigationCommandDispatcher`、`ReaderPageTurnGate`、`ReaderPageTurnCoordinator` 已经开始建立翻页边界。
- [x] `ReaderPaginationCacheService`、`ReaderStreamingPaginationController` 已经意识到分页缓存和首屏优先问题。
- [x] 设置项覆盖范围较大，后续可基于现有 `ReaderSettings` 继续扩展。
- [x] 多媒体、漫画、本地书解析已经有基础链路，适合后续纳入统一 layout model。

这些基础值得保留。后续改造不应推翻重写，而应建立兼容适配层，逐步把旧 slice/render item 迁入新 layout model。

---

## 5. 测试缺口

当前测试覆盖了分页引擎、offset mapper、翻页 gate、controller/presenter、TXT 大文件解析、本地导入等，但还缺少阅读器内核级验证。

建议补齐：

- [ ] 中文标点断行 golden/data test。
- [ ] 超长段落分页性能测试。
- [ ] EPUB/HTML mixed content layout test。
- [ ] 图片真实尺寸、图片跨页、图片点击命中测试。
- [ ] 跨页选择、跨段标注、标注恢复位置测试。
- [ ] read-aloud 当前句/当前行高亮测试。
- [ ] 跨章节翻页动画状态机测试。
- [ ] iOS/Android 真机 smoke checklist。
- [ ] profile mode 下的首屏分页和字体切换耗时记录。

---

## 6. 建议优先级

### 立即处理

- [ ] 不再继续向 `_ReaderPageState` 添加业务状态。
- [ ] 定义 `ReaderLayoutPage/Line/Column` 第一版。
- [ ] 为旧分页结果写 adapter，先做到行为不变。
- [ ] 给 layout model 补纯 Dart 单测。

### 下一阶段处理

- [ ] 将分页改为增量布局流。
- [ ] 将 selection/bookmark/read-aloud anchor 切到 layout position。
- [ ] 将 page-turn animation delegate 化。
- [ ] 扩展 `ReaderDocument` 到 block + inline span。

### 后置处理

- [ ] 补齐中文排版开关、标题分段、双页、硬件输入、TTS 等成熟阅读器设置。
- [ ] 针对 EPUB/HTML 复杂书籍做兼容矩阵。
- [ ] 建立真机性能基线和发版前 smoke。
