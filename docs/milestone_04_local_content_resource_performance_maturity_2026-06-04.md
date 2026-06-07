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
- [x] M4-02-05 为暂不替换的解析逻辑写中文维护注释和退出条件。
- [x] M4-02-06 输出解析库平台支持矩阵。

## 3. M4-03 长任务与性能

- [x] M4-03-01 盘点导入、解析、分页、索引、缓存清理等长任务。
- [x] M4-03-02 选择一个解析任务接入 isolate / compute / task queue，不改变业务结果。
- [x] M4-03-03 为任务取消、进度、失败重试和 UI 反馈补测试。
- [x] M4-03-04 记录低端移动设备、Web、Desktop 的性能影响。
- [x] M4-03-05 建立阅读器启动、章节切换、列表滚动、解析耗时的基线记录。

## 4. M4-04 用户资产与资源管理

- [x] M4-04-01 盘点主题资源、字体、封面、启动图、底栏图标、用户上传文件的存储落点。
- [x] M4-04-02 将一个直接 managed dir 使用点迁入 `ManagedAssetStore` 或统一 resource service。
- [x] M4-04-03 为用户资产删除、复用、迁移、回滚补中文维护注释。
- [x] M4-04-04 补用户资产不会被缓存清理误删的测试。
- [x] M4-04-05 更新 storage baseline 矩阵。

## 5. M4-05 缓存与诊断

- [x] M4-05-01 盘点封面缓存、分页缓存、网络缓存、临时目录和诊断导出。
- [x] M4-05-02 选择一个缓存清理路径改为统一 cache governance service。
- [x] M4-05-03 确认 Web 下载 / 复制、Desktop 保存 / 打开目录、移动端分享路径。
- [x] M4-05-04 为缓存预算、过期、失败兜底补测试。
- [x] M4-05-05 输出缓存和诊断六平台验收记录。

## 6. M4-06 本地阅读专项稳定化阶段任务

以下任务由 `本地阅读代码审计（2026-06-04）` 和 `本地导入任务队列审计与阶段计划（2026-06-04）` 拆分而来。执行规则仍然保持每次只领取一个最小任务编号。

- [x] M4-06-01 将本地阅读代码审计、成熟库替代判断和任务队列重复反馈整理为 M4 阶段计划。
- [x] M4-06-02 做 PDF 路线统一 spike：确认 `pdfrx` / `pdfrx_engine` / PDFium 是否能承担页元数据和文本抽取，给出是否替代 `pdf_text_extract` 的结论。
- [x] M4-06-03 将 MOBI / AZW / AZW3 标记为实验能力：补验收说明、失败路径、DRM / 编码 / 图片资源限制和样例测试缺口。
- [x] M4-06-04 收敛本地书库页导入 / 重索引任务反馈：`LocalLibraryPage` 不再把前台导入和单本重索引发布到全局任务队列，保留页面状态、bottom sheet、snackbar 和立即阅读入口。
- [x] M4-06-05 收敛外部本地图书导入 handoff：`ExternalImportPayloadType.localBook` 只保留 transient overlay 和目标 sheet 进度，不遗留全局任务队列记录；资源类外部导入仍可进入队列。
- [x] M4-06-06 收口 TXT 编码入口：让 storage、preview、parser 共用 `LocalTextEncodingDetector` 的导入采样 / charset 决策，避免多处重复评分。
- [x] M4-06-07 做 EPUB 成熟库 adapter spike：用 `epubx` 试替 metadata / OPF / TOC 层，不改变现有 `ReaderDocument`、fixed-layout、inline image 输出。
- [x] M4-06-08 让至少一个本地 parser 真正落地 `LocalBookParserInputAware`，避免 input adapter 长期空置。
- [x] M4-06-09 补本地图书导入体验 smoke：确认导入完成后不遗留全局任务队列按钮，导入 sheet、立即阅读、失败提示仍可用。
- [x] M4-06-10 建立 Windows 本地阅读性能基线：记录大 TXT、流式 EPUB、PDF 导入、索引、首次打开和章节切换耗时。
- [x] M4-06-11 复查本地书库页 presentation 体量：等 M3 书架链稳定后，再决定是否拆 `LocalLibraryTaskPresenter` / import controller。

## 7. M4 验收

- [x] M4-07-01 每种本地内容格式都有平台支持、成熟库评估和暂不替换原因。
- [x] M4-07-02 用户资产不写入 cache/tmp，不被启动清理误删。
- [x] M4-07-03 长任务不会明显阻塞 UI，至少一个高风险任务有队列或 isolate 试点。
- [x] M4-07-04 storage guard、storage baseline guard、相关 parser / cache tests 通过。
- [x] M4-07-05 Web build 和可用桌面构建或未验证原因记录完整。

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

#### M4-02-05 暂不替换 parser 的维护注释

- `txt_local_book_parser.dart`：补充 TXT parser 保留原因，明确中文网文章节规则、超大文件流式 offset、多编码兜底和长章节拆分是当前不可直接替换的业务约束；退出条件是成熟 parser 能覆盖章节识别、编码检测、offset 懒加载和大文件性能基线。
- `local_text_encoding_detector.dart`：补充编码检测统一入口说明，要求 storage、preview、parser 不再复制新的 charset 评分逻辑；如替换成熟库，应先替换该类并回归 TXT / HTML / EPUB 测试。
- `epub_local_book_parser.dart`：补充 EPUB 定制 parser 保留原因，明确 `ReaderDocument`、inline image、fixed-layout 信号和资源物化是替换边界；成熟库先从 metadata / OPF / TOC adapter 试点。
- `pdf_local_book_parser.dart`：补充 PDF 文本抽取 adapter 说明，明确 `PackagePdfTextExtractor` 是替换点；如果 `pdfrx` / PDFium 能承担多端页元数据和文本抽取，再替换 adapter。
- `kindle_local_book_parser.dart`：补充 MOBI / AZW / AZW3 实验能力说明，明确仅承诺无 DRM 基础样例，复杂 Kindle 变体优先给清晰失败提示，不把格式细节扩散到 UI。

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

#### M4-03-02 EPUB isolate 解析试点确认

本次选择 EPUB 索引作为 M4-03-02 的 isolate / task queue 试点，因为 `EpubLocalBookParser` 已在索引阶段使用 `Isolate.run<Map<String, Object?>>` 执行 `_parseIndexInBackground`，业务输出仍通过原有 `LocalParsedBook`、`LocalParsedChapter`、`ReaderDocument` 和资源物化路径返回。

- 选择原因：EPUB 解包、OPF / spine / nav 解析和章节候选计算属于纯 Dart 重活，比 PDF MethodChannel 抽取更适合 isolate。
- 行为边界：本次不新增第二个并发模型，不改变 EPUB 章节顺序、fixed-layout 信号、cover 物化、inline image 输出。
- 当前限制：EPUB 资源物化和章节内容懒加载仍有主 isolate I/O；TXT 目前靠 streaming + cooperative yield；PDF 当前移动端文本插件不适合直接搬入 Dart isolate；MOBI 依赖 `dart_mobi`，需先补实验能力验收。

#### M4-03-03 任务取消、进度、失败重试和 UI 反馈测试

- `test/app/tasks/app_task_manager_test.dart`：补充长任务失败后仍保留 `progress`、`progressLabel`、`detail`、`recoveryKey`，并将 `canCancel` 关闭、`canRetry` 打开的测试，覆盖失败重试所需状态。
- `test/app/widgets/app_task_status_test.dart`：补充 `ImportExportInlineStatus` widget 测试，确认进度文案、阶段详情、进度条数值和失败反馈能被 UI 展示。
- 本轮不新增真实 retry 回调，因为当前 `AppTaskManager` 只保存 `canRetry` / `recoveryKey`，队列面板尚未提供统一 retry action；后续如果要做全局重试按钮，应单独领取任务并补交互测试。

#### M4-03-04 性能影响记录

| 平台 / 设备 | 当前影响判断 | 后续补验 |
| --- | --- | --- |
| 低端 Android / iOS | TXT 大文件编码评分和章节切分仍可能占用主 isolate；EPUB 索引已有 isolate 试点；PDF 文本抽取走插件，不应强迁 isolate。 | 需要真机导入大 TXT、流式 EPUB、PDF 样例，记录导入、索引、首次打开耗时。 |
| Web JS | 当前能力层标记 Native 文件系统导入和 managed file storage 不支持；`LocalBookParserInput` 预留了 webUploadedBytes，但 parser 尚未真实落地 input-aware。 | 后续如启用 Web 上传，必须先做 M4-06-08 input-aware，再补 Web bytes parser 测试。 |
| Windows Desktop | 本机主要风险是大文件 I/O、TXT 编码评分和 PDF 文本抽取平台不支持；EPUB isolate 可降低索引阶段阻塞。 | 先以 Windows 作为 M4-03-05 基线平台，记录大 TXT / EPUB / PDF 导入与打开时间。 |
| macOS / Linux Desktop | 设计上同桌面路径，但本轮未构建；`dart:io` 与插件支持需要分别验证。 | macOS 正在 M3，Linux 待后续机器补验。 |

#### M4-03-05 Windows 自动化性能基线

本轮建立的是 Windows 侧自动化测试基线，不等价于真机用户导入 / 首开手动验收；真实大样本仍放到 `M4-06-10`。

| 场景 | Windows 命令 | 结果 |
| --- | --- | --- |
| 阅读器启动 / 章节切换逻辑基线 | `flutter test test/features/reader/application/reader_experience_baseline_test.dart test/features/reader/application/reader_pagination_engine_test.dart` | 7 tests passed，墙钟约 97.1s。 |
| 列表滚动 / 视口渲染 smoke | `flutter test test/features/reader/presentation/reader_rendering_memory_smoke_test.dart test/features/reader/presentation/reader_paged_viewport_controller_test.dart test/features/reader/presentation/reader_runtime_controller_test.dart test/features/reader/presentation/reader_content_loading_controller_test.dart` | 29 tests passed，墙钟约 74.2s。 |
| TXT / EPUB / PDF / MOBI 解析耗时基线 | `flutter test --concurrency=1 --timeout=3x test/features/reader/application/local/txt_local_book_parser_test.dart test/features/reader/application/local/local_text_encoding_detector_test.dart test/features/reader/application/local/epub_local_book_parser_test.dart test/features/reader/application/local/pdf_local_book_parser_test.dart test/features/reader/application/local/kindle_local_book_parser_test.dart` | 46 tests passed，墙钟约 212.3s。 |

缺口：没有真实 Windows 文件选择器导入、真实大 PDF / 大 EPUB / 大 TXT 首开、书库页真实滚动帧耗时；这些需要样本文件和手动 / integration 验收，后续归入 `M4-06-10`。

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

#### M4-04-02 / M4-04-03 头像资产迁入 ManagedAssetStore

- 新增 `ManagedAssetType.profileAvatar` / `ManagedAssetScope.userProfile`，并在 `ManagedAssetDirectoryPolicies` 中登记 `profile_avatars/`。
- `MinePageSessionService.saveLocalAvatar` 改为通过 `ManagedAssetStore.persistBytes` 保存头像，prefs 只保存 managed relative path；读取时由 `ManagedAssetStore.resolvePersistedPath` 解析为运行时绝对路径。
- 删除、替换和清用户作用域缓存时通过 `ManagedAssetStore.deletePath` 处理，兼容旧版本绝对路径和新版本相对路径，避免旧头像遗留。
- 维护注释已写在保存 / 删除头像路径附近，明确 prefs 不承载图片字节、替换先删旧 asset、旧路径只作为兼容输入。

#### M4-04-04 用户资产不被缓存清理误删测试

- `test/features/mine/application/mine_page_session_service_test.dart`：覆盖头像保存、读取、删除和旧路径清理。
- `test/core/cache/app_cache_governance_service_test.dart`：新增 `clearRebuildableCaches` 测试，确认章节缓存、分页缓存、封面缓存被清理时，`ManagedAssetStore` 下的 `profileAvatar` 文件仍存在。

#### M4-04-05 Storage baseline 矩阵更新

- `docs/storage_governance_baseline_matrix_2026-06-04.md`：将 `profile_avatars` 从 `MinePageSessionService` 业务层直连目录改为 `ManagedAssetDirectoryPolicy` baseline，状态更新为“已迁入 policy”。
- `tool/check_storage_governance_guard.dart`：Windows 路径归一化为 `/`，避免 baseline ID 在 Windows 下因反斜杠误报；`profile_avatars` 白名单同步到 policy 文件。

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

#### M4-05-02 统一缓存治理清理入口

- `AppCacheGovernanceService` 新增 `clearRebuildableCaches()`，统一清理章节正文缓存、阅读器分页缓存、封面磁盘缓存。
- `enforceBudgets()` 改为按 cache kind 逐项容错：某一路径清理失败时记录 `developer.log`，继续执行其他 cache 清理，避免单点失败阻断治理。
- `AppPaginationLayoutCacheStore` 补 `clearPersistedChapterLayouts()`，让分页缓存清理也进入统一 governance adapter。

#### M4-05-03 下载 / 保存 / 分享路径确认

| 平台 | 诊断 / 导出路径结论 | 本轮状态 |
| --- | --- | --- |
| Web JS | `DiagnosticLogExportService` Web 实现返回 `text`，`file == null`，适合复制 / 浏览器下载策略；Native 文件系统导入仍未启用。 | 代码确认，未跑 Web build。 |
| Android / iOS | 诊断和主题导出以临时文件作为分享中转，页面通过 `share_plus` 分发；长期用户资产不得落 temporary。 | 代码确认，未跑真机。 |
| Windows | 诊断导出写入 temp/diagnostics 文件，主题导出使用分享 / 剪贴板 fallback；本轮测试在 Windows 跑通 service 侧。 | 已跑 Windows 单测。 |
| macOS | 设计同桌面路径，M3 仍在 macOS 侧，本轮不占用。 | 未验证。 |
| Linux | 设计同桌面路径，需后续机器补构建和文件管理器行为。 | 未验证。 |

#### M4-05-04 缓存预算、过期、失败兜底测试

- `test/core/cache/app_cache_governance_service_test.dart` 覆盖：
  - snapshot 聚合章节缓存、分页缓存、封面缓存预算；
  - `enforceBudgets` 传递章节、分页、封面预算；
  - 过期分页缓存按 stale period 删除；
  - 分页缓存清理失败时封面 compact 仍继续；
  - `clearRebuildableCaches` 不误删 managed 用户头像资产。

#### M4-05-05 缓存和诊断六平台验收记录

| 能力 | Android | iOS | Web JS | macOS | Windows | Linux |
| --- | --- | --- | --- | --- | --- | --- |
| cache governance snapshot / budget | 代码应支持，需真机数据库和文件缓存验收。 | 同 Android。 | Web 不支持原生 managed file storage，需单独 Web storage 策略。 | 代码应支持，未本轮构建。 | 单测通过；Drift 测试需临时加入 `build/windows/x64/plugins/sqlite3_flutter_libs/Release` 到 PATH。 | 代码应支持，未本轮构建。 |
| 诊断导出 | 临时文件 + 系统分享。 | 临时文件 + 系统分享。 | 返回 text，不生成本地 file，适合复制 / 下载策略。 | 临时文件 / 桌面保存路径待验。 | 临时文件路径代码可用，本轮未打开文件管理器。 | 临时文件 / 桌面保存路径待验。 |
| 用户资产保护 | managed 头像、封面、字体、主题资产不应进 cache/tmp。 | 同 Android。 | 需 Web 上传策略后补验。 | 需构建验收。 | 头像 managed store 测试通过；cache 清理不误删头像测试通过。 | 需构建验收。 |

后续低风险建议：`M4-02-05`、`M4-03-02` 到 `M4-03-05`、`M4-04-02` 到 `M4-04-05`、`M4-05-02` 到 `M4-05-05`、`M4-06-02` 到 `M4-06-09` 已在 Windows 侧完成；下一步可从 `M4-06-10` Windows 本地阅读性能基线、`M4-06-11` 本地书库页 presentation 复查或 `M4-07` 总验收继续。

#### M4-06-02 PDF 路线统一 spike

本轮只做路线确认和本地依赖资料核验，未替换生产 parser。结论是：`pdfrx_engine` 具备承接 PDF 页元数据、页数和按页文本抽取的 API 条件，后续替换点应落在 `PdfLocalBookParser` 的 `LocalPdfTextExtractor` adapter，而不是继续扩展移动端限定的 `pdf_text_extract`。

| 依赖 | 本轮核验信息 | 结论 |
| --- | --- | --- |
| `pdfrx` | 当前项目已用于 `reader_pdf_view.dart`，包文档说明覆盖 Android、iOS、Windows、macOS、Linux、Web，并基于 PDFium / `pdfrx_engine`。 | 继续作为 PDF 阅读 / 渲染主路线。 |
| `pdfrx_engine` | 本地 pub cache 文档和源码暴露 `PdfDocument.openFile/openData/openUri/openAsset`、`PdfDocument.pages`、`PdfPage.render`、`PdfPage.loadText`、`PdfPage.loadLinks`，需要 `pdfrxInitialize()`。 | 可作为文本抽取 adapter 的优先 spike 目标，能覆盖页信息和按页文本层。 |
| `pdfium_dart` | 本地 override 文档定位为 PDFium 低层 FFI binding，并建议 Flutter app 优先使用 `pdfrx` / 上层封装。 | 不建议业务 parser 直接依赖低层 FFI，除非 `pdfrx_engine` 缺必要能力。 |
| `pdf_text_extract` | 本地 override README 说明主要面向 Android / iOS，提供 `PDFDoc.fromPath`、页数和懒加载 `PDFPage.text`。 | 暂保留为当前 adapter；等 `pdfrx_engine` adapter 有 Windows 样例 PDF 测试后再删除。 |

执行决策：短期不直接删除 `pdf_text_extract`，避免在没有 Windows 样例 PDF、Developer Mode / native asset、加密 PDF、无文本层 PDF 验证前引入回归。下一步如果继续做 PDF，应新增 `PdfrxEnginePdfTextExtractor`，保持当前轻量页索引 + 按页懒解析语义，并用样例 PDF 补 Windows 测试。

#### M4-06-04 本地书库页导入 / 重索引任务队列收敛

`LocalLibraryPage` 的前台“导入本地图书”和单本“重索引”不再调用 `AppTaskManager.startTask/updateTask`，也不再发布 `localBookImport` / `localBookIndex` 全局任务记录。保留的反馈仍包括页面内 `_taskStatus`、导入 bottom sheet、阶段文案、失败提示、完成 snackbar 和“立即阅读”入口。

本轮刻意没有改 `App._onIncomingExternalImportPayload`、`bookshelf_page_flow.dart` 或 `_BookshelfExternalImportSheet`，因为外部文件 handoff 属于 `M4-06-05`，需要单独验证“本地图书不进全局队列、资源类外部导入仍可进队列”的边界。

#### M4-06-03 MOBI / AZW / AZW3 实验能力标记

MOBI / AZW / AZW3 保留导入入口，但验收口径改为“实验支持”，不再按成熟稳定格式承诺。导入说明文案已标记 MOBI、AZW、AZW3 为实验支持；`KindleLocalBookParser` 继续复用 `dart_mobi` + markup 解析链，遇到 DRM / 加密文件保持清晰失败提示。

| 项目 | 当前验收口径 | 后续缺口 |
| --- | --- | --- |
| 无 DRM 基础样例 | `kindle_local_book_parser_test.dart` 覆盖 MOBI、AZW、AZW3 基础 payload 和资源提取。 | 仍需真实样本库覆盖不同 Kindle 生成器版本。 |
| DRM / 加密 | 已有测试确认抛出“仅支持无 DRM 文件”的明确错误。 | 需要 Windows 手工导入真实 DRM 样本，确认 UI 提示不被吞掉。 |
| 编码 / rawml 变体 | 当前依赖 `dart_mobi` 输出 rawml，再由 markup 支撑层解析。 | 复杂编码、异常 HTML、非标准 metadata 仍属于实验风险。 |
| 图片资源 | 基础资源物化已有测试。 | 大量图片、损坏图片、嵌套资源命名冲突需要样例补测。 |
| 超大文件性能 | 代码路径理论可用。 | 尚未建立大 MOBI / AZW3 导入、索引和首次打开耗时基线。 |

#### M4-06-05 外部本地图书导入 handoff 队列收敛

`ExternalImportPayloadType.localBook` 的 app 级 handoff 不再创建 `external-import-handoff:*` 全局任务；仍保留顶部 transient overlay 和路由跳转。`_BookshelfExternalImportSheet` 不再接收 `AppTaskManager`，也不再发布 `external-book-import:*` / `localBookImport` 全局任务，进度只留在目标 sheet 内。

资源类外部导入仍保持原规则：advanced theme / font handoff 继续进入 `AppTaskManager` 的 `resourceImport` channel。本轮未删除 `AppTaskManager` 或资源导入队列基础设施。

#### M4-06-06 TXT 编码入口收口

`LocalTextEncodingDetector` 新增 `decodeBestEffortFromSamples`，统一承接多段采样、候选 charset 解码、样本位置加权、UTF-16 zero-byte 兜底和 fallback 惩罚。`LocalBookStorageService` 的 TXT 导入采样不再维护独立评分函数；`TxtLocalBookParser` 的流式样本解码改为调用统一 detector，并只额外叠加章节规则权重。

非流式 TXT 全量解码也改为直接委托 `LocalTextEncodingDetector.decodeBestEffortAsync`，保留已冻结 charset 的严格解码和错误提示。Preview / chapter content 之前已通过 `LocalTextEncodingDetector` 读取 `book.charset`，本轮不再增加新的 charset 评分入口。

#### M4-06-07 EPUB 成熟库 adapter spike

本轮尝试用 `epubx` 接入 metadata / OPF / TOC 只读 adapter，但 `flutter pub add epubx` 在当前依赖树下解算失败：项目当前使用 `image ^4.3.0` 和 `xml ^6.5.0`，而 `epubx` 全版本要求 `image ^3.0.8` 或旧版 `xml ^5.0.2` 路径，不能在不破坏现有依赖的情况下直接加入。

执行结论：暂不强行添加 dependency override，也不把 EPUB 生产 parser 切到 `epubx`。`EpubLocalBookParser` 继续保留定制实现，维护边界仍是 `ReaderDocument`、fixed-layout、inline image、资源物化和章节懒加载输出不变。后续如果要继续成熟库替换，应优先找支持 `image 4.x` / `xml 6.x` 的 EPUB 包，或单独评估 fork `epubx` 的依赖升级成本。

#### M4-06-08 LocalBookParserInputAware 落地

`TxtLocalBookParser` 已实现 `LocalBookParserInputAware`。路径输入仍走原有文件解析和大文件 streaming index；当 `LocalBookParserInput.bytes` 存在时，TXT parser 可直接从字节输入建立章节索引，复用同一套编码检测、章节规则和长章节拆分逻辑。

新增测试覆盖 Web 上传字节语义：没有真实本地文件时，`LocalBookParserInputSource.webUploadedBytes` + UTF-8 bytes 也能解析出章节并返回 charset。

#### M4-06-09 本地图书导入体验 smoke

新增本地图书导入反馈 smoke guard：确认 `LocalLibraryPage` 仍保留 `ImportExportTaskSheet`、立即阅读入口和失败提示，同时不再引用 `appTaskManagerProvider` / `AppTaskManager` / `local-book-import` / `local-book-reindex`。外部本地图书导入 sheet 也确认只保留 sheet 反馈，不再发布 `toAppTaskStatusData`、`localBookImport` 或 `external-book-import` 全局任务。

限制：文件选择器真实打开和 Windows 手工导入 TXT 样例仍属于后续人工验收；本轮自动化先固定“不遗留全局任务队列按钮”的代码边界。

#### M4-06-10 Windows 本地阅读性能基线

本轮建立 Windows 侧自动化基线，覆盖 TXT 大文件索引、EPUB 解析、PDF 轻量索引 / 懒解析、本地章节内容读取和书架页 smoke。它不是完整手工导入基线：真实文件选择器、大 PDF 首开、真实 EPUB 滚动帧率和章节切换体感仍需要人工样本验收。

| 场景 | 覆盖命令 / 用例 | Windows 自动化耗时 | 结果 |
| --- | --- | ---: | --- |
| 大 TXT / 流式 TXT | `txt_local_book_parser_test.dart`，包含大 UTF-8、UTF-16LE、GBK head-ascii streaming path | 归入组合耗时 | 通过 |
| 流式 EPUB / mixed media EPUB | `epub_local_book_parser_test.dart`，覆盖 metadata、spine、nav fragment、fixed-layout、inline image、SVG 资源 | 归入组合耗时 | 通过 |
| PDF 导入 / 页索引 / 懒解析 | `pdf_local_book_parser_test.dart` + `local_chapter_content_service_test.dart` | 归入组合耗时 | 通过 |
| 书架 / 本地书库打开链 smoke | `bookshelf_page_smoke_test.dart` | 归入组合耗时 | 通过 |
| 自动化基线总耗时 | `Measure-Command { flutter test --concurrency=1 --timeout=3x ... }` | 98.81 秒 | 通过 |

基线命令：

```powershell
flutter test --concurrency=1 --timeout=3x `
  test/features/reader/application/local/txt_local_book_parser_test.dart `
  test/features/reader/application/local/epub_local_book_parser_test.dart `
  test/features/reader/application/local/pdf_local_book_parser_test.dart `
  test/features/reader/application/local/local_chapter_content_service_test.dart `
  test/features/bookshelf/presentation/bookshelf_page_smoke_test.dart
```

#### M4-06-11 本地书库页 presentation 体量复查

本轮队列收敛后，`local_library_page.dart` 从旧审计时的 1080 行降到 925 行，说明去掉全局任务队列发布后页面复杂度有所回落。当前仍然偏重，但功能边界清晰：文件选择、导入 sheet、单本重索引、立即阅读、错误反馈都仍在同一用户流程内。

| 文件 | 当前体量 | 复查结论 |
| --- | ---: | --- |
| `lib/features/bookshelf/presentation/local_library_page.dart` | 925 行 | 暂不拆 `LocalLibraryTaskPresenter` / import controller；如果继续加入批量导入策略、后台扫描或复杂取消重试，再拆。 |
| `lib/features/bookshelf/presentation/bookshelf_page_flow.dart` | 2560 行 | 体量更大，承担书架页多个 sheet / flow；后续如果要做 UI 拆分，应优先按 sheet / flow 分离，而不是只拆本地书库页。 |
| `lib/features/reader/application/local/txt_local_book_parser.dart` | 1449 行 | 已落地 input-aware，但章节拆分、offset、streaming 编码仍复杂；后续适合拆内部协作类，不建议立即换库。 |
| `lib/features/reader/application/local/epub_local_book_parser.dart` | 2082 行 | 仍是最大手搓点；`epubx` 依赖冲突后暂不替换，后续只做 adapter 或 fork 成本评估。 |

执行结论：M4 不继续拆 presentation 文件，避免扩大和 M3 书架 / 在线链冲突。当前更应该把“全局任务队列准入规则”固定下来，防止本地图书前台导入再次进入全局任务列表。

### M4-07 总验收（2026-06-04，Windows 侧）

#### M4-07-01 本地内容格式、平台支持和成熟库评估

| 格式 / 资源 | 当前支持口径 | 成熟库 / 路线结论 | 暂不替换原因 |
| --- | --- | --- | --- |
| TXT | Native 桌面 / 移动端代码路径可用，Windows 自动化通过；Web bytes 路径已有 input-aware 起点。 | 继续使用 `charset`、`charset_converter`、`flutter_charset_detector`，项目保留中文网文章节和 streaming 特化。 | 章节规则、offset、长章节拆分是业务特化，不适合整体换库。 |
| EPUB | Windows parser 自动化通过，覆盖 OPF、spine、nav、fixed-layout、inline image、资源物化。 | `epubx` adapter spike 因 `image` / `xml` 依赖冲突未落地。 | 不使用 dependency override，避免破坏现有依赖树；保留定制 parser。 |
| PDF | Windows 自动化覆盖轻量页索引和按页懒解析；阅读 / 渲染路线已有 `pdfrx`。 | 后续优先 spike `pdfrx_engine` 文本抽取 adapter。 | `pdf_text_extract` 暂保留，等 Windows 样例 PDF 和 `pdfrx_engine` adapter 测试再删。 |
| MOBI / AZW / AZW3 | 实验支持；基础 MOBI、AZW、AZW3 payload 和 DRM 错误路径测试通过。 | 继续使用 `dart_mobi`。 | 底层库成熟度不足且 Kindle 格式复杂，暂无更稳替换库。 |
| Markdown / HTML | 本地 parser 保留，属于本地内容入口补充项。 | 当前自有 parser 足够轻量。 | M4 主风险不在该路径，暂不替换。 |
| 用户图片 / 字体 / 主题资源 | 继续走 managed asset / resource service 方向。 | `ManagedAssetStore` 和 cache governance 继续收口。 | 用户资产不能放 cache/tmp，优先治理存储边界。 |

#### M4-07-02 用户资产和 cache / tmp 边界

`dart tool/check_storage_governance_guard.dart` 通过：JSON-backed SharedPreferences writes 6 处、temporary/cache directory usages 9 处、startup cleanup call sites 0 处、managed directory direct usages 3 处，未发现新增 storage governance violations。

`dart tool/check_storage_baseline_governance.dart` 通过，已批准 storage baseline 均有文档记录。本地图书存储路径已统一使用 POSIX 相对路径语义，避免 Windows `\` 进入长期存储字段。

#### M4-07-03 长任务和 UI 阻塞风险

TXT 大文件索引仍使用 streaming path 和 cooperative yield；PDF 导入保持轻量页索引，正文按页懒解析；本地图书前台导入不再发布全局队列，避免同一任务重复反馈。高风险任务的后续 isolate / queue 深化仍建议放在 PDF 文本抽取 adapter 或 EPUB 资源物化阶段，M4 本轮不强行扩大。

#### M4-07-04 守卫和测试结果

| 命令 | 结果 |
| --- | --- |
| `dart tool/check_storage_governance_guard.dart` | 通过 |
| `dart tool/check_storage_baseline_governance.dart` | 通过 |
| `flutter test --concurrency=1 --timeout=3x test/core/cache/app_cache_governance_service_test.dart test/features/reader/application/reader_pagination_cache_service_test.dart test/features/reader/application/local/txt_local_book_parser_test.dart test/features/reader/application/local/epub_local_book_parser_test.dart test/features/reader/application/local/pdf_local_book_parser_test.dart test/features/reader/application/local/kindle_local_book_parser_test.dart` | 通过，51 tests passed |
| `flutter analyze` | 通过，No issues found |

Windows 下 cache / Drift 相关测试需要当前命令进程 PATH 包含 `build/windows/x64/plugins/sqlite3_flutter_libs/Release`，否则会因找不到 `sqlite3.dll` 失败；这属于本机测试环境依赖，不是本轮业务改动失败。

#### M4-07-05 构建验收

本轮按用户要求只跑 Windows，不跑 Web、macOS、Linux、Android、iOS。

| 平台 | 命令 | 结果 |
| --- | --- | --- |
| Windows | `flutter build windows` | 通过，产物 `build\windows\x64\runner\Release\shuxiang_reading_next.exe`，构建耗时 257.7 秒 |
| Web | 未执行 | 用户要求本机只跑 Windows，Web 留给后续单独验收 |
| macOS / Linux / Android / iOS | 未执行 | 本轮 Windows 侧收尾，不占用其他平台验收 |

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

### 本地阅读导入到解析规范化（2026-06-07）

本轮按“用户导入 -> 受管存储 -> 索引 -> parser input -> 章节内容 -> 阅读器”重新固定本地阅读链路，新增专项文档 [本地阅读导入到解析规范化计划](local_reading_import_parse_standardization_plan_2026-06-07.md)。

- TXT 自定义章节规则旧设计已退役：`reader.local.txt.chapterRules` 不再读取、不再写入，也不再作为 storage guard baseline。
- TXT parser 仍保留项目内实现，原因是中文网文章节规则、多编码、超大文件 offset 懒加载和长章节拆分暂时没有成熟库能整体替代。
- EPUB 已引入 `epub_pro` 作为成熟库 adapter。生产 parser 只在 adapter 输出章节形态与现有 parser 等价、且不是 fixed-layout 时采用 `epub_pro` 索引；同一 xhtml 多 fragment、fixed-layout、inline image、ReaderDocument 复杂章节仍回退项目 parser。
- Web 本地图书后续必须以 `LocalBookParserInput.webUploadedBytes` 为核心补齐 bytes / IndexedDB / 刷新恢复语义，不能依赖 `dart:io File`。

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
| P0 | MOBI 实验能力标记 | `M4-02-04` / `M4-07-01` | 低 | 在验收记录中明确 MOBI 不是成熟能力，只承诺无 DRM / 基础样例。 |
| P1 | TXT 编码入口收口 | `M4-02-01` / `M4-03-02` | 中 | 先抽 `LocalTextEncodingDetector` 的“导入采样决策”API，让 storage、preview、parser 共用。 |
| P1 | EPUB 成熟库替代试点 | `M4-02-02` / `M4-03-02` | 中高 | 用 `epubx` 做只读 adapter spike，只替代 metadata / TOC，不碰 ReaderDocument 输出。 |
| P1 | 本地 parser input-aware 落地 | M2-D012 / `M4-01-03` | 中 | 选择 TXT 或 EPUB 先实现 `parseInput`，避免 adapter 空置。 |
| P2 | 本地书库页拆 presenter | M4 后续 UI 稳定性 | 中 | 等 M3 书架链结束后再拆，避免和 macOS 页面改动冲突。 |
| P2 | 性能基线 | `M4-03-05` | 低 | Windows 先记录大 TXT、EPUB、PDF 导入 / 打开耗时，作为后续 isolate 改造前基线。 |

当前最有价值的执行顺序：先做 `PDF 路线统一评估` 和 `MOBI 实验能力标记`，再做 `TXT 编码入口收口`。EPUB 替换成熟库要谨慎，因为现有代码虽然手搓，但承载了项目特有的 fixed-layout、inline image、ReaderDocument 结构。

### 本地导入任务队列审计与阶段计划（2026-06-04）

本节补充“导入本地图书会触发任务列表”的排查结论。当前问题不是 `AppTaskManager` 整体多余，而是本地图书导入路径把同一件事同时投递到页面状态、底部导入 sheet 和全局任务队列，造成用户看到额外“任务列表 / 任务队列”入口。

#### 排查结论

| 入口 | 当前反馈 | 是否重复 | 结论 |
| --- | --- | --- | --- |
| 本地书库页直接导入 | `LocalLibraryPage` 内部 `_currentStageText` / `_lastErrorText` 页面状态 + `ImportExportTaskSheet` bottom sheet + `AppTaskManager` 全局任务队列 | 是 | 全局队列多余；用户已留在当前页面且有底部 sheet，完成后还有 snackbar / 立即阅读按钮。 |
| 本地书库页重索引 | 页面内 `_reindexStatusText` / `_reindexErrorText` + `AppTaskManager` 全局任务队列 | 是 | 对单本书手动重索引，页面内状态足够；全局队列会留下已完成任务按钮。 |
| 书架页“导入本地图书”sheet | `_BookshelfImportLocalBooksSheet` 内部 steps + `ImportExportProgressCard` / `ImportExportTaskSheet` | 否 | 这是当前更合理的模式：前台操作只在当前 sheet 展示进度，不投全局队列。 |
| 外部文件 handoff | `App._onIncomingExternalImportPayload` 先发全局 handoff task + 顶层 transient overlay + 跳转后 `_BookshelfExternalImportSheet` 再发 localBookImport task | 是 | 对本地图书外部导入重复更明显；handoff 与目标 sheet 都会留下任务队列记录。 |
| 资源导入 / 字体 / 主题 / 封面 | 多处资源管理页使用 `AppTaskManager` | 不直接判定 | 这些任务可能跨页面、批量导入或需要中断提示，不能因为本地图书导入重复就删除全局队列基础设施。 |

#### 根因

- `AppTaskQueueButton` 位于 `lib/app/shell_scaffold.dart`，只要 `AppTaskManager.tasks` 非空就显示。
- `AppTaskManager` 的已完成任务不会自动清理，需要用户打开任务队列手动“清除已完成”。
- 本地图书导入和重索引是前台、同步、强上下文任务，当前页面已经完整承载进度和结果；再进入全局队列会把一次普通导入变成“系统后台任务”的感觉。
- `ImportExportTaskStatus` 同时被 bottom sheet、overlay、queue panel 转换复用，导致组件抽象看起来统一，但具体入口没有明确“谁有资格进入全局队列”。

#### 稳定化原则

1. 前台、不可取消、用户留在当前页面的任务，不进入全局任务队列。
2. 会跨页面、可中断、需要恢复提示、可取消或可重试的长任务，才进入 `AppTaskManager`。
3. 本地图书导入优先使用当前 sheet / 页面内状态 / snackbar；资源批量导入、后台扫描、缓存治理可以继续使用全局队列。
4. `AppTaskManager` 不删除，只收紧 `localBookImport` 的发布场景。

#### 分阶段计划

| 阶段 | 目标 | 任务 | 风险 | 验证 |
| --- | --- | --- | --- | --- |
| Phase A | 文档固化 | 将本次本地阅读代码审计、任务队列重复反馈结论写入 M4。 | 无代码风险 | `git diff` 确认仅文档变更。 |
| Phase B | 去掉本地书库页重复队列 | `LocalLibraryPage` 直接导入和重索引不再调用 `AppTaskManager.startTask/updateTask`；保留 `_taskStatus`、`ImportExportTaskSheet`、页面状态和 snackbar。 | 低；只影响本地书库页前台反馈。 | `flutter analyze`；补/跑本地书库页面 smoke，确认导入按钮、底部 sheet、立即阅读按钮仍可用。 |
| Phase C | 收敛外部本地图书导入 | `ExternalImportPayloadType.localBook` 的 app handoff 只保留 transient overlay 和路由跳转，不写全局任务队列；`_BookshelfExternalImportSheet` 使用自身 sheet 状态，不再二次发布 `localBookImport` task。 | 中；外部分享 / 打开方式需要手工验收。 | Windows 上模拟外部 payload 或走可控入口，确认能跳本地导入页并显示 sheet；资源类外部导入仍可进任务队列。 |
| Phase D | 明确队列准入规则 | 在 M4 或治理文档补一条规则：只有跨页面、后台、可中断 / 可恢复任务进入全局队列。 | 低 | 文档评审；后续资源导入按规则复查。 |
| Phase E | 后续体验补测 | 补一条针对本地图书导入“不遗留全局任务队列按钮”的 widget / integration smoke；如果测试成本高，先记录 Windows 手工验收。 | 中；文件选择器自动化可能需要 mock。 | `flutter analyze` + 可行的 widget/provider 测试；Windows 手工导入 TXT 样例。 |

#### 建议执行顺序

先做 `Phase B`，因为它只影响 `LocalLibraryPage`，不会碰 M3 在线阅读链；再做 `Phase C`，因为外部导入涉及 app 级 handoff 和书架 sheet，需要单独验收。`AppTaskManager`、`AppTaskQueueButton` 和资源导入任务队列先保留，避免扩大改动。
