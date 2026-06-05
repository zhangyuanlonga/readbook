# 里程碑 06：阅读器全平台可用与架构收敛

创建日期：2026-06-05

状态：规划完成，待按最小任务执行。

适用平台：Android、iOS、Web JS、macOS、Windows、Linux。

核心目标：让阅读器从“移动端体验稳定、桌面和 Web 逐步能跑”进入“全平台可用、能力边界清楚、架构可继续维护”的阶段。M6 不替代 M3 在线阅读链、M4 本地内容资源治理、M5 长期门禁，而是在它们之上把阅读器单独收束成可执行专项。

后续执行规则：每次只领取一个最小任务编号，例如 `M6-03-02`。如果执行中发现任务仍然过大，先拆本文档，再改代码。

## 1. 当前实现梳理

### 1.1 路由与入口

| 能力 | 当前落点 | 现状 |
| --- | --- | --- |
| 标准阅读入口 | `lib/features/reader/routes.dart`、`lib/features/reader/presentation/reader_route.dart` | 标准 route 为 `/reader/:bookId/:chapterId`，query 携带 `chapterUrl`、`sourceId`、`detailUrl`、`chapterIndex`、`bookmarkId`、`openRouteKind` 等身份。 |
| 本地旧入口兼容 | `lib/features/reader/routes.dart` | `/local/reader/:bookId/:chapterId` 会重定向到标准 reader route，并补齐 local source/detail/chapter URL。 |
| 详情开始阅读 | `lib/features/book/application/book_detail_read_route_service.dart`、`ReaderEntryRouteResolver` | 通过 route helper 构造阅读入口，避免页面裸拼复杂 route。 |
| 书架继续阅读 | `ReadingProgress`、`ReaderPreferencesService`、书架 route service | 继续阅读依赖持久化进度补齐 route 缺失字段，Web 刷新和桌面重启也依赖这条路径。 |

### 1.2 内容源与内容模式

| 层级 | 当前落点 | 现状 |
| --- | --- | --- |
| 内容源抽象 | `ContentProvider`、`ContentProviderRegistry` | 统一 `loadDetail` 和 `loadChapterContent`，页面不直接区分网络 / 本地解析实现。 |
| 在线内容 | `ServerGatewayContentProvider` | 当前 registry 默认接入服务器网关，支持详情、完整目录和正文加载；可换源，当前不启用章节缓存入口。 |
| 本地内容 | `LocalContentProvider` | 支持本地图书详情、目录和章节正文，能力上禁换源、禁远程章节缓存，支持重建本地索引。 |
| 内容模式 | `ReaderContentModeResolver` | 当前按 `text`、`hybrid`、`comic`、`audio` 四类分发。 |
| Hybrid 子模式 | `ReaderHybridSubMode` | PDF、固定版式 EPUB、绘本 / 杂志、扫描型文档归入固定页 / 图文混合路径。 |

### 1.3 阅读器状态与运行时

| 能力 | 当前落点 | 现状 |
| --- | --- | --- |
| 会话身份 | `ReaderContentSession` | 汇总书籍、章节、内容类型、音频、PDF 源文件、页数、目录和进度等运行态信息。 |
| 进度快照 | `ReadingProgress`、`ReaderPositionSnapshot`、`ReaderLogicalPosition` | 已支持旧比例进度、文本逻辑位置、分页页码、图片 index、hybrid 页码、audio 位置等字段。 |
| 设置持久化 | `ReaderPreferencesService` | 保存字体、排版、背景、翻页、自动阅读、信息栏、阅读进度和目录快照。 |
| 阅读记录 | `ReadingRecordService`、`ReaderReadingRecordCoordinator` | 负责阅读时长、记录 session 和统计链。 |
| 章节加载与预取 | `ReaderContentLoadingController`、`ReaderPreloadController`、`ReaderChapterWindowController` | 已有章节加载、相邻章节窗口、低优先级预取和取消 token 语义。 |
| 分页与缓存 | `ReaderPaginationEngine`、`ReaderPaginationCacheService` | 支持文本分页、持久化分页缓存、内存 LRU 和预计算布局。 |

### 1.4 表现层与输入

| 能力 | 当前落点 | 现状 |
| --- | --- | --- |
| 页面总控 | `ReaderPage` | 仍是主汇总态页面，约 6000 行，直接持有大量控制器、计时器、状态和平台服务。 |
| Shell / Chrome | `ReaderShell`、`ReaderChromeResolver`、`ReaderChromeWidgets` | 已有 shell 和信息栏拆分，顶部 / 底部 overlay 仍主要由 `ReaderPage` part 文件驱动。 |
| 视口分发 | `reader_page_viewport.dart`、`ReaderViewportBuilder` | 按 text scroll、text paged、hybrid paged、comic scroll/paged、audio 分发。 |
| 文本视图 | `ReaderTextScrollView`、`ReaderTextPagedView` | 支持滚动 / 分页、选中文本、注释 / 书签、高亮、图文块渲染。 |
| 图片 / 漫画 | `ReaderMangaView` | 支持连续滚动和分页模式。 |
| PDF | `ReaderPdfView` + `pdfrx` | 本地 PDF 当前在 hybrid 模式中用 `pdfrx` 按文件路径渲染。 |
| 音频 | `ReaderAudioView`、`ReaderAudioController` | 已有基础播放、倍速、章节前后跳转入口，后台 / 定时等仍是后续项。 |
| 桌面输入 | `_handleReaderKeyEvent`、`_handleReaderPointerSignal`、`ReaderDesktopInputResolver` | 支持 Esc、方向键、PageUp/PageDown、Home/End、滚轮翻页；resolver 已有单测，但页面仍有重复逻辑可收口。 |
| 移动端桥 | `ReaderScreenBrightnessBridge`、`ReaderVolumeKeyPageBridge` | 亮度和音量键翻页只在 Android / iOS 原生端启用，Web / Desktop 降级。 |

### 1.5 本地内容与格式

| 格式 | 当前实现 | 当前策略 |
| --- | --- | --- |
| TXT | `TxtLocalBookParser`、`LocalTextEncodingDetector` | 保留定制流式解析，覆盖中文网文章节规则、多编码检测、大文件 offset 和长章节拆分。 |
| EPUB | `EpubLocalBookParser`、`LocalMarkupBookParserSupport` | 保留定制 parser，索引阶段已有 isolate 试点；成熟库先从 metadata / OPF / TOC adapter 试点。 |
| PDF | `PdfLocalBookParser`、`PackagePdfTextExtractor`、`ReaderPdfView` | 文本抽取仍经 `pdf_text_extract` adapter，固定页渲染用 `pdfrx`；后续目标是统一 PDF 路线并退出旧插件。 |
| MOBI / AZW / AZW3 | `KindleLocalBookParser` | 当前标记为实验能力，只承诺无 DRM 基础样例，复杂变体优先清晰失败。 |
| HTML / Markdown | `HtmlLocalBookParser`、`MarkdownLocalBookParser` | 作为本地内容附属格式，复用 markup 支撑和 `ReaderDocument`。 |

## 2. 当前全平台结论

| 平台 | 当前结论 | M6 重点 |
| --- | --- | --- |
| Android | 移动端稳定基线，阅读器手势、亮度、音量键、Safe Area、系统返回必须保护。 | 任何共享层改动都要补移动端阅读回归。 |
| iOS | 移动端稳定基线，需额外关注 iOS 模拟器电量读取、Safe Area、返回手势和 Files 沙盒。 | 亮度 / 音量键桥、PDF、本地导入要真机或模拟器 smoke。 |
| Web JS | `flutter build web --no-pub` 已于 2026-06-05 通过；WASM dry-run 提醒 `sqlite3/ffi` 不兼容，WASM 仍为独立专项。 | 在线阅读先做到刷新恢复、键盘 / 滚轮、能力降级；本地文件路径不能假装可用。 |
| macOS | macOS debug 构建曾验证通过，属于桌面优先适配目标。 | 窗口、键盘、鼠标、PDF 文件路径、目录 / 设置弹层要真实 smoke。 |
| Windows | 需要 Windows 机器或 CI 补验，不能用 macOS 结果替代。 | 重点是构建、文件路径、字体渲染、滚轮、PDF、本地导入和性能基线。 |
| Linux | 需要 Linux 机器或 CI 补验，不能用 macOS / Windows 结果替代。 | 重点是发行版依赖、文件选择器、字体渲染、窗口和 PDF / 本地导入。 |

## 3. 主要风险与优化方向

| 优先级 | 风险 | 影响 | 默认方向 |
| --- | --- | --- | --- |
| P0 | 阅读器入口、进度恢复或 route 身份丢失 | Web 刷新、桌面重启、书架继续阅读会错位。 | 所有入口继续使用 route helper，进度 fallback 保持兼容并补测试。 |
| P0 | 本地用户资产 / 阅读进度被缓存治理误删 | 影响用户书籍、字体、背景、进度和书签。 | 继续走 `ManagedAssetStore`、本地图书受管目录和 cache governance 边界。 |
| P0 | Web / Desktop 引入 native-only import 或文件路径假设 | Web JS 编译或运行失败。 | 原生能力通过 capability、adapter、conditional import 或明确禁用态。 |
| P1 | `ReaderPage` 和设置 / 目录 sheet 过大 | 后续改动容易互相踩踏，移动端和桌面路径难隔离。 | 等价拆 facade、controller、presenter、platform adapter 和 desktop shell，不一次性重写。 |
| P1 | PDF 路线多库并存 | 依赖维护、SPM、平台支持和文本抽取职责不清。 | 以 `pdfrx` / PDFium 能力为主线做 adapter spike，保留旧 adapter 直到替换可证明。 |
| P1 | 本地解析仍以 `dart:io` 和原生路径为核心 | Web 本地阅读无法直接复用。 | Web 先禁用 native local reading，再做上传 bytes / IndexedDB 独立策略。 |
| P2 | 桌面输入逻辑散在页面方法里 | 快捷键、滚轮、focus 行为难测。 | 将页面实现收口到 `ReaderDesktopInputResolver` 或等价 controller。 |
| P2 | 设置弹层移动端 / 桌面端形态混杂 | 宽屏体验和触控体验容易互相影响。 | 保留移动端 bottom sheet，桌面改为 dialog / side panel / popover 形态。 |
| P2 | AudioReader 能力仍偏基础 | 听书全平台体验不完整。 | 后置为 M6 中后段，先保证基础播放、进度、章节跳转和降级。 |

## 4. M6-01 阅读器全平台基线盘点

- [ ] M6-01-01 复核阅读器入口清单：详情开始阅读、目录章节、书架继续阅读、阅读记录、书签、本地旧路由、Web 直接 URL。
- [ ] M6-01-02 输出阅读器代码结构图：route、content provider、session、progress、viewport、platform bridge、local parser、cache。
- [ ] M6-01-03 输出六平台能力矩阵：在线阅读、本地阅读、PDF、音频、亮度、音量键、键盘、滚轮、文件导入、缓存和诊断。
- [ ] M6-01-04 建立阅读器 smoke 模板，覆盖打开、加载、翻页 / 滚动、目录、设置、进度保存、返回、失败重试。
- [ ] M6-01-05 记录当前 Web JS 构建结果和 Web WASM dry-run 风险，不把 WASM 纳入 M6 默认交付。
- [ ] M6-01-06 确认 M3-04 在线阅读链、M4 本地内容治理、M5 guard 中与阅读器重叠的任务编号，避免重复领取。

## 5. M6-02 Web JS 在线阅读可用

- [ ] M6-02-01 检查 `/reader/:bookId/:chapterId` 在 Web 刷新、新标签打开、浏览器后退 / 前进后的恢复路径。
- [ ] M6-02-02 检查在线章节加载、正文为空、网络失败、源不可用、换源失败在 Web 的可理解错误态。
- [ ] M6-02-03 收口 Web 键盘和滚轮阅读：方向键、PageUp/PageDown、Space、Home/End、Esc 和滚轮节流都要有目标测试。
- [ ] M6-02-04 明确 Web 不支持的移动端能力：亮度、音量键、native 文件路径、本地受管文件目录，入口必须禁用、隐藏或显示降级说明。
- [ ] M6-02-05 检查 Web 文本选择、复制、注释 / 书签工具栏和 overlay 层级，不得被浏览器选择行为或滚轮抢焦点破坏。
- [ ] M6-02-06 补 Web 阅读器 widget smoke 或 browser smoke，至少覆盖 390、840、1280 宽度。
- [ ] M6-02-07 将 `flutter build web --no-pub` 纳入 M6 任务收尾记录；如失败，记录具体 import / 插件 / 路由阻塞。

## 6. M6-03 Desktop 阅读器可用

- [ ] M6-03-01 检查 macOS 从详情、书架、阅读记录、书签进入 reader 的打开和返回路径。
- [ ] M6-03-02 检查 Windows 从详情、书架、阅读记录、书签进入 reader 的打开和返回路径，不能用 macOS 结果替代。
- [ ] M6-03-03 检查 Linux 从详情、书架、阅读记录、书签进入 reader 的打开和返回路径，不能用 macOS / Windows 结果替代。
- [ ] M6-03-04 将桌面键盘 / 滚轮动作从页面散点收口到 resolver / controller，并补单测。
- [ ] M6-03-05 检查桌面窗口缩放、最小窗口、可读最大宽度、左右留白、信息栏、目录和设置弹层不溢出。
- [ ] M6-03-06 为桌面设置面板定义 dialog / side panel / popover 策略，不反向改移动端 bottom sheet 体验。
- [ ] M6-03-07 检查桌面 PDF 阅读：文件存在、页码恢复、窗口缩放、滚轮、缩放、失败态和进度保存。
- [ ] M6-03-08 输出 macOS、Windows、Linux 三端独立验收记录，未验证平台写清机器和阻塞原因。

## 7. M6-04 Android / iOS 移动端保护回归

- [ ] M6-04-01 检查移动端从详情开始阅读、目录进章节、书架继续阅读、书签跳转的旧体验不回退。
- [ ] M6-04-02 检查触控翻页、滑动、点击分区、长按选择、系统返回、沉浸式和 Safe Area。
- [ ] M6-04-03 检查阅读设置、目录、换源、章节缓存、自动阅读、书签 / 注释弹层仍按移动端交互展示。
- [ ] M6-04-04 检查亮度桥和音量键翻页：只在 Android / iOS 原生端启用，弹层 / 选中 / 加载态不拦截。
- [ ] M6-04-05 检查移动端本地 TXT / EPUB / PDF / MOBI 打开、失败提示和重建索引路径。
- [ ] M6-04-06 运行 Android / iOS 构建或记录真实阻塞；涉及原生桥、Info.plist、AndroidManifest 时必须补真机 / 模拟器 smoke。

## 8. M6-05 阅读器表现层架构收敛

- [ ] M6-05-01 拆出 `ReaderRuntimeFacade` 或等价 controller，先承接章节加载、进度保存、预取、阅读记录和错误态，不改变 UI。
- [ ] M6-05-02 将 `ReaderPage` 中的桌面输入、移动端桥接、系统 UI、亮度、电量读取收口到 platform facade / capability。
- [ ] M6-05-03 将 `ReaderPage` 中的 content session 构造、mode/capability 解析、viewport state 解析迁到 application 层可测试服务。
- [ ] M6-05-04 拆分 `reader_page_settings_sheet.dart`：按界面、阅读、自动阅读、信息栏、字体 / 背景、实验能力分 section presenter。
- [ ] M6-05-05 拆分 `reader_catalog_sheet.dart`：目录数据、搜索、跳转、桌面 / 移动展示策略分离。
- [ ] M6-05-06 审计 `ReaderPage` 体量，目标从 6000 行警戒降到可维护区间；每次拆分必须等价迁移并补测试。
- [ ] M6-05-07 为新增 public class、provider、facade、adapter、storage key 和复杂进度逻辑补中文维护注释。

## 9. M6-06 本地阅读全平台策略

- [ ] M6-06-01 明确 Web 本地阅读首版策略：禁用 native local reading，或以浏览器上传 bytes + 可重建缓存作为独立入口。
- [ ] M6-06-02 让本地 parser 输入统一走 `LocalBookParserInputAware` 或等价 adapter，避免 native path 和 Web bytes 分叉扩散到 parser 外。
- [ ] M6-06-03 复查 TXT 编码检测：storage、preview、parser 继续共用 `LocalTextEncodingDetector`，移动端插件失败要有 fallback。
- [ ] M6-06-04 继续 EPUB 成熟库 adapter spike：先替 metadata / OPF / TOC 层，保留 `ReaderDocument` 和 inline image 输出。
- [ ] M6-06-05 做 PDF 路线统一：明确 `pdfrx`、PDFium、`pdf_text_extract` 的职责、平台支持和退出条件。
- [ ] M6-06-06 将 MOBI / AZW / AZW3 保持实验能力，补 DRM、编码、图片资源、超大文件和失败样例验收。
- [ ] M6-06-07 检查本地图书、字体、背景、封面和 PDF 源文件都在受管目录，不被 cache/tmp 清理误删。
- [ ] M6-06-08 为 Android、iOS、macOS、Windows、Linux 本地导入分别记录文件选择器、沙盒、路径和重建索引结果。

## 10. M6-07 阅读交互、可访问性与自适应

- [ ] M6-07-01 建立阅读器宽度检查：390、600、840、1280、1600 视口下正文、overlay、目录、设置和错误态不重叠。
- [ ] M6-07-02 检查字体缩放：阅读正文使用 reader 设置，chrome / sheet 使用界面文字缩放上限，不出现按钮文字溢出。
- [ ] M6-07-03 检查 focus ring、Tab 顺序、Esc 关闭、Enter 激活、滚轮行为和 hover 状态。
- [ ] M6-07-04 检查文本选择、书签 / 注释工具栏、图片预览、PDF 缩放手势在移动端和桌面端的差异。
- [ ] M6-07-05 检查自动阅读在文本分页、文本滚动、低电量、后台、overlay、章节边界的状态机。
- [ ] M6-07-06 检查阅读背景、主题、亮度遮罩、深色模式和高对比文本颜色，不让装饰图影响可读性。

## 11. M6-08 性能、长任务与缓存

- [ ] M6-08-01 建立阅读器启动到首屏可见、首章加载、第一次翻页、章节切换、目录打开、设置打开的性能基线。
- [ ] M6-08-02 检查文本分页、图文分页、PDF 打开、大图解码、EPUB 解包、TXT 大文件切章的主 isolate 占用。
- [ ] M6-08-03 继续使用 `ReaderResourceBudgetResolver` 控制低端设备、低电量、图片解码和预取预算。
- [ ] M6-08-04 确认分页缓存、章节缓存、封面缓存和本地 parser 临时文件进入统一 cache governance，不碰用户资产。
- [ ] M6-08-05 为 Web JS 记录内存和大章节行为，避免大文本 / 大图在浏览器中一次性撑爆。
- [ ] M6-08-06 输出 Android、iOS、Web JS、macOS、Windows、Linux 的性能基线或未验证原因。

## 12. M6-09 测试、构建与 guard

- [ ] M6-09-01 运行阅读器目标单测：route、content mode、mode capabilities、session、progress、pagination、auto read、desktop input。
- [ ] M6-09-02 运行本地 parser 目标单测：TXT、encoding、EPUB、PDF、MOBI、local chapter content、local index。
- [ ] M6-09-03 运行 presentation widget / smoke：viewport builder、paged controller、runtime controller、chrome、settings presenter、annotation。
- [ ] M6-09-04 运行 `flutter analyze`、route guard、architecture guard、storage guard、dependency override guard。
- [ ] M6-09-05 运行 `flutter build web --no-pub`，记录 Web JS 与 Web WASM dry-run 结果。
- [ ] M6-09-06 运行 macOS / Windows / Linux 至少一个桌面构建时，按项目规则同步记录 Android / iOS 构建或真实阻塞。
- [ ] M6-09-07 为高确定性问题评估新增 guard：presentation 直接文件系统访问、ReaderPage 裸平台判断、复杂 reader route 裸字符串。

## 13. M6-10 验收与接力

- [ ] M6-10-01 输出阅读器六平台验收记录：每个平台必须写已验证、代码级不回退、未验证原因或发布前补验要求。
- [ ] M6-10-02 输出能力降级清单：Web、本地阅读、PDF、亮度、音量键、文件导入、诊断、音频。
- [ ] M6-10-03 更新 README、AI 执行序列、reader developer notes 和相关 regression checklist。
- [ ] M6-10-04 将暂不替换或暂不支持项登记到长期看板，包含影响平台、推荐方向、验证入口和退出条件。
- [ ] M6-10-05 明确下一轮最小任务编号，不能只写“继续优化阅读器”。

## 14. M6 收尾矩阵

每个 M6 任务完成时必须记录：

| 项目 | 必填结论 |
| --- | --- |
| 业务链 | 在线阅读、本地阅读、PDF、音频、设置、目录、进度、缓存、书架继续阅读中哪些被影响。 |
| 修改范围 | route、provider、service、facade、presentation、parser、storage、platform bridge、capability、theme 是否修改。 |
| Android | 已验证 / 代码级不回退 / 未验证原因 / 发布前补验要求。 |
| iOS | 已验证 / 代码级不回退 / 未验证原因 / 发布前补验要求。 |
| Web JS | 构建、刷新恢复、键盘 / 滚轮、路由、浏览器存储、不支持能力降级。 |
| macOS | 构建、启动、窗口、键鼠、PDF、本地文件、外部打开、凭证能力。 |
| Windows | 独立构建或 CI / 手动补验，不能用 macOS 结果替代。 |
| Linux | 独立构建或 CI / 手动补验，不能用 macOS / Windows 结果替代。 |
| 测试与构建 | 实际执行命令、通过 / 失败、未运行原因和后续补验方式。 |
| 注释与文档 | 新增复杂代码是否补中文维护注释，相关 docs / checklist 是否同步。 |

