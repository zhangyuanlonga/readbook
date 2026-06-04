# 里程碑 04：本地内容、资源与性能成熟化

创建日期：2026-06-04

状态：部分执行。

适用平台：Android、iOS、Web JS、macOS、Windows、Linux。

核心目标：治理本地导入、TXT / EPUB / PDF / MOBI 解析、主题资源、字体、封面、缓存、诊断和性能。重点仍然是手搓换成熟、不稳定换成熟，但这一阶段聚焦重资产和长任务能力。

后续执行规则：每次只领取一个最小任务编号，例如 `M4-03-02`。

## 1. M4-01 本地内容入口盘点

- [x] M4-01-01 列出 TXT、EPUB、PDF、MOBI、音频、图片资源的导入入口。
- [x] M4-01-02 记录每种资源在 Android、iOS、Web JS、macOS、Windows、Linux 的文件选择和路径语义。
- [x] M4-01-03 标记哪些入口依赖本地 override、native engine、Web stub 或 `dart:io`。
- [x] M4-01-04 记录每种资源的现有测试入口和缺口。

## 2. M4-02 解析库与任务队列评估

- [x] M4-02-01 评估 TXT 编码检测是否继续使用当前方案、替换库或补 adapter。
- [x] M4-02-02 评估 EPUB 解析是否可替换成熟库或保留定制 parser。
- [x] M4-02-03 评估 PDF 解析、pdfium override、pdfrx 路径和平台支持。
- [x] M4-02-04 评估 MOBI 解析是否继续保留、替换或标记为实验能力。
- [ ] M4-02-05 为暂不替换的解析逻辑写中文维护注释和退出条件。
- [x] M4-02-06 输出解析库平台支持矩阵。

## 3. M4-03 长任务与性能

- [x] M4-03-01 盘点导入、解析、分页、索引、缓存清理等长任务。
- [ ] M4-03-02 选择一个解析任务接入 isolate / compute / task queue，不改变业务结果。
- [ ] M4-03-03 为任务取消、进度、失败重试和 UI 反馈补测试。
- [ ] M4-03-04 记录低端移动设备、Web、Desktop 的性能影响。
- [ ] M4-03-05 建立阅读器启动、章节切换、列表滚动、解析耗时的基线记录。

## 4. M4-04 用户资产与资源管理

- [x] M4-04-01 盘点主题资源、字体、封面、启动图、底栏图标、用户上传文件的存储落点。
- [ ] M4-04-02 将一个直接 managed dir 使用点迁入 `ManagedAssetStore` 或统一 resource service。
- [ ] M4-04-03 为用户资产删除、复用、迁移、回滚补中文维护注释。
- [ ] M4-04-04 补用户资产不会被缓存清理误删的测试。
- [ ] M4-04-05 更新 storage baseline 矩阵。

## 5. M4-05 缓存与诊断

- [x] M4-05-01 盘点封面缓存、分页缓存、网络缓存、临时目录和诊断导出。
- [ ] M4-05-02 选择一个缓存清理路径改为统一 cache governance service。
- [ ] M4-05-03 确认 Web 下载 / 复制、Desktop 保存 / 打开目录、移动端分享路径。
- [ ] M4-05-04 为缓存预算、过期、失败兜底补测试。
- [ ] M4-05-05 输出缓存和诊断六平台验收记录。

## 6. M4 验收

- [ ] M4-06-01 每种本地内容格式都有平台支持、成熟库评估和暂不替换原因。
- [ ] M4-06-02 用户资产不写入 cache/tmp，不被启动清理误删。
- [ ] M4-06-03 长任务不会明显阻塞 UI，至少一个高风险任务有队列或 isolate 试点。
- [ ] M4-06-04 storage guard、storage baseline guard、相关 parser / cache tests 通过。
- [ ] M4-06-05 Web build 和可用桌面构建或未验证原因记录完整。

## M4 执行记录（2026-06-04，Windows 侧代码阅读）

本轮只执行低冲突盘点和评估任务，未改 reader / bookshelf / mine 的业务运行逻辑，避免与 macOS 正在执行的 M3 业务链验收冲突。验证范围以 Windows 机器代码阅读、`rg` 盘点和静态分析为主；Web、Android、iOS、macOS、Linux 未在本机真实构建。

### M4-01 本地内容入口盘点

#### 本地内容导入入口

| 资源 | 入口 | 代码落点 | 当前处理 |
| --- | --- | --- | --- |
| TXT | 本地书库页“导入本地书”文件选择 | `lib/features/bookshelf/presentation/local_library_page.dart`、`lib/features/bookshelf/application/local_book_import_service.dart` | `file_selector.openFiles` 选文件，导入后复制到应用受管本地书目录，交给 `TxtLocalBookParser` 建索引。 |
| EPUB | 同 TXT | 同上，解析落点为 `EpubLocalBookParser` | ZIP / OPF / spine / HTML 解析，资源提取到本地图书相邻 asset 目录。 |
| PDF | 同 TXT | 同上，解析落点为 `PdfLocalBookParser` | 导入时建立轻量页索引，正文阅读时按页懒解析。 |
| MOBI / AZW / AZW3 | 同 TXT | 同上，解析落点为 `KindleLocalBookParser` | 基于 `dart_mobi` 读取 rawml、元数据、资源，DRM 文件抛明确错误。 |
| Markdown / HTML | 同 TXT | `MarkdownLocalBookParser`、`HtmlLocalBookParser` | 当前也在 `LocalBookFormat` 内，M4 主目标未列但属于本地内容入口，需要保留矩阵记录。 |
| 音频 | 阅读器音频模式 / 音频能力开关 | `lib/features/reader/application/audio_reading_mode.dart`、`lib/app/platform/app_platform_capabilities.dart` | 当前未发现与本地书库相同的文件导入入口；平台能力层有音频播放支持标记。 |
| 图片资源 | 封面、主题、阅读背景、启动图、底栏图标、头像等选择 / 导入 | `custom_cover_storage_service.dart`、`advanced_theme_service.dart`、`reader_background_service.dart`、`launch_image_gallery_service.dart`、`bottom_nav_icon_gallery_service.dart`、`mine_page_session_service.dart` | 多数已走 `ManagedAssetStore`，少量历史目录仍直接使用 documents 目录。 |

#### 平台路径语义

| 平台 | 文件选择 / 路径语义 | 已知限制 |
| --- | --- | --- |
| Android / iOS | 代码层通过 `file_selector` / 图片选择抽象进入，导入后应复制到应用受管目录，长期使用 `LocalBook.storagePath`。 | 真实系统选择器、权限和沙盒语义本轮未在移动端验证。 |
| Web JS | `AppPlatformCapabilities` 明确 Web 暂不支持 Native 文件系统导入和原生受管文件目录，需 Web 上传策略。 | 本轮不跑 Web；M4 后续如果要验 Web，应单独补上传 / IndexedDB / blob 路径记录。 |
| macOS | 与 Windows / Linux 同属桌面原生平台，使用系统文件选择器，长期文件应复制到应用支持目录。 | macOS 正在执行 M3，本轮不占用 macOS 构建。 |
| Windows | 本机目标平台；桌面文件选择器选源文件，`LocalBookStorageService` 将副本放入应用支持目录 `local_books`，解析使用 `dart:io` 路径。 | 本轮仅代码阅读和静态分析，未重新跑导入 UI 手工流。 |
| Linux | 设计上同桌面原生平台，使用系统文件选择器和 `dart:io`。 | Linux 未在本机验证，需后续补构建和文件选择行为。 |

#### 本地依赖标记

- `local_library_page.dart` 使用 `file_selector`，属于原生 / Web 平台抽象入口；当前 Web 能力层仍标记 Native 文件系统导入不支持。
- `LocalBookImportService`、`LocalBookStorageService`、各本地 parser 大量依赖 `dart:io`，因此长期解析链主要面向原生平台。
- `LocalBookFormat` 当前支持 `txt`、`epub`、`md`、`html`、`pdf`、`mobi`、`azw`、`azw3`。
- PDF 解析依赖 `pdf_text_extract`，项目还有 `pdfrx` 和本地 `pdfium_dart` override；PDF 阅读 / 提取路径需要继续拆清楚。
- 图片类资源多走 `ManagedAssetStore`，但 advanced theme / launch image / profile avatar 仍有直接 documents 目录路径，需要 M4-04 后续治理。

#### 现有测试入口

- 本地导入 / 工作流：`test/features/bookshelf/application/bookshelf_flow_coordinator_test.dart`、`test/features/reader/application/local/local_book_storage_service_test.dart`、`test/features/reader/application/local/local_book_index_service_test.dart`。
- TXT：`txt_local_book_parser_test.dart`、`local_text_encoding_detector_test.dart`、`txt_chapter_rule_service_test.dart`、`local_chapter_content_service_test.dart`。
- EPUB / HTML / Markdown：`epub_local_book_parser_test.dart`、`html_local_book_parser_test.dart`、`markdown_local_book_parser_test.dart`。
- PDF：`pdf_local_book_parser_test.dart`、`local_chapter_content_service_test.dart`。
- MOBI / AZW / AZW3：`kindle_local_book_parser_test.dart`。
- 用户资产 / storage：`managed_asset_store_test.dart`、`managed_file_path_resolver_test.dart`、`managed_asset_directory_policy_test.dart`、`managed_asset_path_migration_service_test.dart`。
- 缓存治理：`app_cache_governance_service_test.dart`、`reader_pagination_cache_service_test.dart`、`chapter_cache` 相关测试。

测试缺口：真实文件选择器 UI、Windows 大文件导入耗时、移动端权限 / 沙盒、Web 上传策略、Linux 桌面选择器、用户图片资产不被缓存清理误删仍需要后续任务补验。

### M4-02 解析库评估

| 格式 | 当前方案 | 成熟度判断 | 建议 |
| --- | --- | --- | --- |
| TXT | `LocalTextEncodingDetector` + `charset` / `charset_converter` / `flutter_charset_detector`，`TxtLocalBookParser` 自定义章节切分和流式索引。 | 测试覆盖较多，已覆盖 UTF-8、UTF-16、GBK、Big5、大文件流式路径；移动端检测和桌面 `dart:io` 路径仍需真机补验。 | 暂保留当前方案，后续优先补 adapter 边界和性能基线，不建议立即替换。 |
| EPUB | `archive` 解包 + `html` DOM 解析 + 自定义 OPF / spine / nav / inline image 处理，索引阶段已有 `Isolate.run` 试点。 | 覆盖 fixed layout、metadata、cover、spine、nav、inline image、复杂 mixed-media 等测试；自定义代码体量大。 | 暂保留定制 parser，但 M4-02-05 需要补退出条件：当出现维护成本高于成熟库集成、或 EPUB3 特性覆盖不足时再替换。 |
| PDF | `pdf_text_extract` 抽象为 `LocalPdfTextExtractor`，项目同时声明 `pdfrx` 和本地 `pdfium_dart` override。 | 已有轻量页索引、懒解析、加密 / 无文本层 / 不支持运行时错误测试；PDF 渲染和正文提取路径存在多库并存。 | 短期保留抽象层，后续 M4-02-03 应继续明确 `pdf_text_extract`、`pdfrx`、`pdfium_dart` 各自职责，避免重复依赖。 |
| MOBI / AZW / AZW3 | `dart_mobi` 读取 rawml、metadata、resources，自定义转为本地章节和资源。 | 有 DRM、AZW、AZW3 基础测试，但 MOBI 生态复杂，库活跃度和格式覆盖需要谨慎。 | 标记为“可用但偏实验能力”，发布前应把 DRM、编码、图片资源、超大文件失败路径写进验收记录。 |
| Markdown / HTML | `markdown` / `html` 包 + `LocalMarkupBookParserSupport`。 | 测试覆盖基本结构和封面判定，是 EPUB / MOBI markup 处理的共用支撑。 | 作为本地内容附属格式保留，纳入后续 storage / asset 测试。 |

#### 解析库平台支持矩阵

| 能力 | Android | iOS | Web JS | macOS | Windows | Linux |
| --- | --- | --- | --- | --- | --- | --- |
| TXT 文件解析 | 代码应支持，需权限 / 沙盒真机验收 | 代码应支持，需沙盒真机验收 | 当前 Native 文件系统导入不支持 | 代码应支持，未本轮验证 | 代码应支持，本轮代码阅读 | 代码应支持，未本轮验证 |
| EPUB 解析 | 代码应支持 | 代码应支持 | 受文件导入限制 | 代码应支持 | 代码应支持 | 代码应支持 |
| PDF 文本提取 | 取决于 `pdf_text_extract` / pdfium 目标支持 | 取决于插件目标支持 | 不应默认支持 native 提取 | 需构建验证 | 需 Windows 构建 / 样例文件验证 | 需 Linux 构建验证 |
| MOBI / AZW / AZW3 | 纯 Dart 库理论可用，需大文件性能验收 | 同 Android | 受文件导入限制 | 理论可用 | 理论可用 | 理论可用 |

`M4-02-05` 本轮未执行，因为它需要改 parser 源码注释，属于代码变更；为降低与 M3 阅读链冲突，留到后续单独领取。

### M4-03-01 长任务盘点

| 长任务 | 落点 | 当前机制 | 风险 |
| --- | --- | --- | --- |
| 本地文件导入复制 / 持久化 | `LocalBookImportService`、`LocalBookStorageService` | 有导入进度阶段，TXT 会做编码预判和复制。 | 大文件复制、编码检测可能影响 UI，需要 Windows 大文件基线。 |
| 本地图书索引 | `LocalBookIndexService` | 有 `TimelineTask`，调用各 parser。 | TXT / MOBI / PDF 仍可能长时间占用主 isolate；EPUB 已有 isolate 试点。 |
| EPUB 解包 / 章节解析 | `EpubLocalBookParser` | 索引阶段使用 `Isolate.run` 返回结构化 payload。 | 资源提取和懒加载仍需基线；自定义 parser 复杂。 |
| TXT 章节切分 / 编码检测 | `TxtLocalBookParser`、`LocalTextEncodingDetector` | 有流式路径和协作 yield gate。 | 超大文件、多编码评分仍需实测耗时。 |
| PDF 懒解析 | `PdfLocalBookParser`、`LocalChapterContentService` | 页索引轻量化，正文按页读取并缓存。 | 加密、无文本层、插件运行时支持差异。 |
| 阅读器分页 | `ReaderPaginationEngine`、`ReaderPaginationCacheService` | 有 `TimelineTask`、yield、内存 / 持久化缓存。 | 首次分页和复杂图文内容可能阻塞，需要 M4-03-05 基线。 |
| 章节缓存预取 | `ChapterCacheService` | Stream 进度、取消 token、并发度解析。 | 失败重试和 UI 反馈可继续补测。 |
| 缓存治理 | `AppCacheGovernanceService` | 已能按预算清理章节、分页、封面缓存。 | 用户资产和 cache/tmp 边界需要 M4-04-04 / M4-05-04 补测。 |

### M4-04-01 用户资产与资源落点盘点

| 资产 | 主要落点 | 当前风险 |
| --- | --- | --- |
| 自定义封面 | `CustomCoverStorageService` + `ManagedAssetStore` | 已受管，删除后会 evict 文件图片缓存。 |
| 阅读背景 / 应用背景 | `ReaderBackgroundService`、`AppBackgroundService` + `ManagedAssetStore` | 已受管，需确认迁移和回滚测试。 |
| 字体 | `ReaderFontRegistryService` + `ManagedAssetStore` | 已受管，需补字体文件删除 / 复用行为。 |
| 启动图 | `LaunchImageGalleryService`，部分路径使用 `ManagedAssetStore`，同时存在 legacy documents 根目录 | 需后续统一 storage baseline。 |
| 底栏图标 | `BottomNavIconGalleryService` + `ManagedAssetStore` | 已受管，已有 gallery 测试。 |
| 高级主题包 | `AdvancedThemeService`，混合 `ManagedAssetStore`、documents 目录、temporary 工作目录 | 是 M4-04 后续高优先级治理对象，但改动面大，本轮只盘点。 |
| 头像 / 资料图片 | `MinePageSessionService` 使用 documents 下 `profile_avatars` | 直接 documents 路径，后续可迁入统一 resource service。 |
| 本地图书资源 | `LocalBookStorageService` 的 `local_books`，EPUB / MOBI / HTML / MD 资源在图书副本相邻 asset 目录 | 属于本地内容资产，不应被 cache 清理。 |

### M4-05-01 缓存与诊断盘点

| 类型 | 落点 | 当前治理 |
| --- | --- | --- |
| 封面网络缓存 | `CoverImageDiskCache`、`DiskCachedCoverImage` | 接入 `flutter_cache_manager`，纳入 `AppCacheGovernanceService` snapshot / budget。 |
| 章节正文缓存 | `ChapterContentService`、`ChapterCacheService`、数据库 chapter cache | 支持单书清理、全清理、预取进度、取消 token、预算统计。 |
| 阅读分页缓存 | `ReaderPaginationCacheService` | 内存 LRU + 应用 cache 目录持久化，老 support 目录有 legacy 读取路径。 |
| EPUB archive 内存缓存 | `EpubLocalBookParser._archiveCache` | 小型内存 LRU，未纳入统一 cache governance。 |
| 搜索 / 详情内存缓存 | `SearchHitCacheService`、`BookDetailService`、`ReaderCatalogSearchService` | 主要是内存或业务缓存，不属于磁盘清理核心。 |
| 临时目录 | `AdvancedThemeService` 使用 `getTemporaryDirectory()` 处理主题导入 / 导出工作目录 | 应确保失败时清理，不影响用户资产。 |
| 诊断导出 | `SearchFailureExportService`、`ExternalImportDiagnostics`、`AppPlatformCapabilities.diagnosticLogExport` | 桌面 / 下载目录 / support exports 路径存在，平台支持需后续验收。 |

后续低风险建议：先单独领取 `M4-02-05` 只补 parser 维护注释；再领取 `M4-04-05` 写 storage baseline 矩阵。代码改造类 `M4-03-02`、`M4-04-02`、`M4-05-02` 建议等 M3 阅读链和书架链稳定后再做。

### 本地阅读代码审计（2026-06-04）

本节按“本地化阅读链”补充代码审计，目标是识别过度设计、手搓实现和可替换成熟库的方向。本轮只读代码和公开包资料，未改业务逻辑。

#### 代码落点和体量

| 模块 | 文件 | 体量 | 角色 | 审计结论 |
| --- | --- | ---: | --- | --- |
| EPUB parser | `lib/features/reader/application/local/epub_local_book_parser.dart` | 2077 行 | 解包、OPF / spine / nav、章节 HTML、图片资源、fixed-layout 信号、archive cache | 最大手搓点，功能覆盖多但维护成本最高。 |
| TXT parser | `lib/features/reader/application/local/txt_local_book_parser.dart` | 1588 行 | 编码识别、流式采样、章节规则、offset、长章节拆分、协作 yield | 手搓复杂度高，但很多逻辑是中文网文 / 大文件特化，不适合直接整体替换。 |
| 编码检测 | `lib/features/reader/application/local/local_text_encoding_detector.dart` | 896 行 | charset 候选评分、BOM、平台 converter / detector 调度 | 已接成熟包，但评分策略手搓，适合收口 adapter 而非继续扩散。 |
| 本地存储 | `lib/features/reader/application/local/local_book_storage_service.dart` | 759 行 | 应用副本、TXT 转码、asset 目录、路径恢复 | 属于必要复杂度，但路径语义需要继续统一到 managed file / storage baseline。 |
| 本地索引 | `lib/features/reader/application/local/local_book_index_service.dart` | 677 行 | parser 分发、索引状态、stale 判断、书架 / 阅读记录同步 | 责任偏多，但有必要的任务去重和状态保护。 |
| 本地导入 | `lib/features/bookshelf/application/local_book_import_service.dart` | 551 行 | 文件导入、去重、持久化、预热索引、书架同步 | 当前可接受，后续应避免继续加 UI 状态。 |
| 本地书库页 | `lib/features/bookshelf/presentation/local_library_page.dart` | 1080 行 | 文件选择、导入任务 UI、重索引、打开本地书 | presentation 偏重，后续若继续加功能应拆 controller / presenter。 |
| MOBI parser | `lib/features/reader/application/local/kindle_local_book_parser.dart` | 300 行 | `dart_mobi` 读取 rawml / 资源 / metadata 后转本地章节 | 代码量可控，但底层库成熟度不足。 |
| PDF parser | `lib/features/reader/application/local/pdf_local_book_parser.dart` | 279 行 | 页索引、移动端文本抽取、按页懒解析 | 抽象层设计合理，但与 `pdfrx` / `pdfium_dart` 多库并存，需要统一路线。 |

#### 过度设计 / 手搓风险

| 风险 | 证据 | 判断 | 建议 |
| --- | --- | --- | --- |
| EPUB 解析手搓过深 | 单文件 2077 行，自行处理 package document、spine、nav、NCX、HTML、资源、fixed-layout、archive cache。 | 高风险但不是无意义过度设计，因为项目有 fixed-layout / mixed-media / ReaderDocument 特化。 | 不建议整包删除；先引入 `EpubMetadataAdapter` / `EpubNavigationAdapter` spike，用成熟库替代 OPF / nav 层，保留项目特有 ReaderDocument 转换。 |
| TXT parser 聚合太多职责 | 单文件同时负责编码、采样、章节识别、offset 对齐、长章节拆分、yield。 | 这是“复杂度集中”，不是纯过度设计。 | 拆内部协作类：`TxtEncodingPlan`、`TxtChapterSplitter`、`TxtOffsetMapper`，先不改行为。 |
| 编码检测策略重复 | `TxtLocalBookParser` 和 `LocalBookStorageService` 都有采样 / charset 评分相关逻辑。 | 有重复风险，长期会出现导入时 charset 和阅读时 charset 判断不一致。 | 收口到 `LocalTextEncodingDetector` 的公开 API，导入、预览、章节读取共用同一决策结果。 |
| `LocalBookParserInputAware` 预留但未落地 | `parseLocalBookInput` 支持 input-aware，但现有 parser 仍以 `LocalBook.storagePath` 为主。 | 轻度过度设计，属于 M2-D007 后续未完成。 | 要么在 M4 内选 EPUB 或 TXT 真正实现 input-aware，要么把 Web bytes 入口继续明确登记为延期，避免空 adapter 长期漂着。 |
| PDF 多库并存 | `pubspec.yaml` 同时有 `pdf_text_extract`、`pdfrx`、本地 `pdfium_dart` override；`PdfLocalBookParser` 仍限制 Android / iOS。 | 这是当前最明显的路线不一致。 | PDF 阅读优先统一到 `pdfrx`；PDF 文本抽取单独 spike `pdfrx_engine` / PDFium API 能否替代 `pdf_text_extract`。 |
| 本地书库页面偏重 | `local_library_page.dart` 1080 行，包含文件选择、任务状态、重索引、打开逻辑。 | 后续继续加导入策略会过载。 | 暂不拆；等 M4-03 / M4-05 任务态改造时抽 `LocalLibraryTaskPresenter`。 |
| MOBI 能力标记过乐观 | `dart_mobi` 官方页说明是 libmobi 的 Dart port，且注明“not thoroughly tested”。 | 不能把 MOBI 视为成熟稳定能力。 | M4 验收中把 MOBI / AZW / AZW3 标为实验能力，保留导入但加强失败提示和样例测试。 |

#### 成熟库替代候选

| 方向 | 当前依赖 / 候选 | 公开包信息 | 替代结论 |
| --- | --- | --- | --- |
| EPUB | 当前手搓 `archive` + `html`；候选 `epubx` | `epubx` 是 Dart EPUB parser，支持 Android / iOS / Linux / macOS / Web / Windows，不依赖 `dart:io`，能读 title、author、cover、chapters、content、OPF / NCX schema。来源：https://pub.dev/packages/epubx | 可作为 OPF / metadata / navigation 层替代候选；不建议一次性替换项目 ReaderDocument / fixed-layout / inline image 转换。 |
| PDF 阅读 / 渲染 | 当前已有 `pdfrx`、`pdfium_dart`，PDF 文本抽取用 `pdf_text_extract` | `pdfrx` 官方页标记支持 Android、iOS、Windows、macOS、Linux、Web，并基于 PDFium，提供 viewer 和底层 engine。来源：https://pub.dev/packages/pdfrx | 阅读 / 渲染应优先向 `pdfrx` 统一；文本抽取是否能替代 `pdf_text_extract` 需要 spike，不应凭假设删除。 |
| PDF 文本抽取 | 当前 `pdf_text_extract` 本地 override；外部类似 `flutter_pdf_text` / `read_pdf_text` 主要 Android / iOS | `flutter_pdf_text`、`read_pdf_text` 均主要覆盖 Android / iOS；不能解决桌面 / Web 多端闭环。来源：https://pub.dev/packages/flutter_pdf_text、https://pub.dev/packages/read_pdf_text | 不建议换另一个移动端 PDF 文本插件；应优先评估 `pdfrx_engine` / PDFium 文本能力，或保持“PDF 阅读可用、文本抽取移动端能力”。 |
| TXT 编码转换 | 当前 `charset`、`charset_converter`、`flutter_charset_detector` | `charset_converter` 使用平台内置 converter，支持 Android / iOS / Linux / Windows；官方页说明平台 charset 名称可能不同。来源：https://pub.dev/packages/charset_converter | 继续使用成熟包，手搓部分只保留评分和兜底；需要统一入口减少重复判断。 |
| MOBI / AZW / AZW3 | 当前 `dart_mobi` | `dart_mobi` 支持多平台、读取 mobi/azw/azw3/azw4，但官方 README 明确“not thoroughly tested”。来源：https://pub.dev/packages/dart_mobi | 不存在明显更成熟替代可以直接换；应标为实验能力并加强验收。 |

#### 本地化阅读优先任务建议

| 优先级 | 任务 | 对应 M4 | 改动风险 | 推荐动作 |
| --- | --- | --- | --- | --- |
| P0 | PDF 路线统一评估 | `M4-02-03` / `M4-02-06` 后续深化 | 中 | 建一个 spike 文档或小测试，确认 `pdfrx` / `pdfrx_engine` 是否能提供需要的文本抽取和页元数据；不要再扩展 `pdf_text_extract`。 |
| P0 | MOBI 实验能力标记 | `M4-02-04` / `M4-06-01` | 低 | 在验收记录中明确 MOBI 不是成熟能力，只承诺无 DRM / 基础样例。 |
| P1 | TXT 编码入口收口 | `M4-02-01` / `M4-03-02` | 中 | 先抽 `LocalTextEncodingDetector` 的“导入采样决策”API，让 storage、preview、parser 共用。 |
| P1 | EPUB 成熟库替代试点 | `M4-02-02` / `M4-03-02` | 中高 | 用 `epubx` 做只读 adapter spike，只替代 metadata / TOC，不碰 ReaderDocument 输出。 |
| P1 | 本地 parser input-aware 落地 | M2-D012 / `M4-01-03` | 中 | 选择 TXT 或 EPUB 先实现 `parseInput`，避免 adapter 空置。 |
| P2 | 本地书库页拆 presenter | M4 后续 UI 稳定性 | 中 | 等 M3 书架链结束后再拆，避免和 macOS 页面改动冲突。 |
| P2 | 性能基线 | `M4-03-05` | 低 | Windows 先记录大 TXT、EPUB、PDF 导入 / 打开耗时，作为后续 isolate 改造前基线。 |

当前最有价值的执行顺序：先做 `PDF 路线统一评估` 和 `MOBI 实验能力标记`，再做 `TXT 编码入口收口`。EPUB 替换成熟库要谨慎，因为现有代码虽然手搓，但承载了项目特有的 fixed-layout、inline image、ReaderDocument 结构。
