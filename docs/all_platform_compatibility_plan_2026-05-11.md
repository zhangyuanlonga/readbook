# 全平台兼容总计划（书源延期版）

更新时间：2026-05-11  
用途：把项目从“Android / iOS 优先”推进到“Android、iOS、macOS、Windows、Linux、Web 全平台可用”的执行计划。  
当前口径：先兼容 UI、常用业务和本地阅读；在线书源、脚本源运行时、书源登录/调试/迁移能力整体移出首版范围。

关联功能方法计划：`docs/page_function_multiplatform_methods_2026-05-12.md`。本文件负责阶段闭环，逐页面功能多端方法以该文档为准。

关联 UI 展示计划：`docs/page_ui_multiplatform_display_plan_2026-05-12.md`。逐页面 UI 多端展示细则以该文档为准。

## 0. 结论先行

首版全平台不再以“在线书源闭环”为验收目标，而以以下闭环为目标：

1. 应用能在所有目标平台启动、导航、设置和展示核心页面。
2. 书架、本地书库、书籍详情、阅读器、书签、阅读记录、主题外观、资源管理等常用业务可用。
3. 阅读能力优先支持本地图书，移动端和桌面端先做完整能力，Web 先做受限能力。
4. 在线搜索、发现、书源管理、脚本源运行时、WebView 登录、源调试服务不进入首版验收。

一句话定位：

**首版全平台先做“本地阅读器 + 跨端 UI 壳 + 常用个人业务”，书源系统作为第二阶段独立专题回归。**

## 1. 当前项目状态

### 1.1 已具备的基础

- 项目已经存在 `android/`、`ios/`、`macos/`、`windows/`、`linux/`、`web/` 平台目录。
- `scripts/build_unified_artifacts.sh` 已覆盖 Android、iOS、macOS、Windows、Linux、Web 的统一产物收集；Web 产物默认使用本地 CanvasKit 资源，不依赖 `gstatic`。
- UI 层已经有自适应基础：
  - `ShellScaffold` 已在中大屏切换 `NavigationRail`。
  - `docs/flutter_adaptive_baseline_matrix.md` 已定义手机、横屏、中屏、平板视口和文字缩放矩阵。
  - `app/layout` 与 `app/widgets/adaptive_*` 已经有通用自适应组件。
- 本地阅读已经有独立链路：
  - 本地图书导入：`features/bookshelf/application/local_book_import_service.dart`
  - 本地解析：`features/reader/application/local/*`
  - 本地阅读入口：`/local/book/:bookId`、`/local/reader/:bookId/:chapterId`
- 书源运行时已经相对完整，但与本次首版目标冲突：
  - `features/source/*`
  - `runtime/sources/*`
  - `runtime/browser/*`
  - `runtime/session/*`
  - `src/js_runtime_*`

### 1.2 当前主要阻塞

- Web 编译会被大量 `dart:io` 直接导入阻塞，范围覆盖 app、core、reader、mine、book、bookshelf、source、sync。
- `app_database.dart` 当前使用原生 SQLite / 文件路径模型，移动端和桌面端可继续使用，Web 需要单独的 Drift Web 存储方案或受限模式。
- `flutter_inappwebview`、`flutter_js`、`pdf_text_extract`、`flutter_charset_detector`、`charset_converter` 等插件在 Web 或桌面端支持面不一致。
- 启动阶段会恢复书源日志、上报书源诊断、hydrate 书源健康状态；首版排除书源后，这些 deferred task 需要被能力开关隔离。
- 搜索、发现、切换书源、书源页、源登录、源调试仍通过路由和 UI 可达，需要首版隐藏或降级。

## 2. 首版范围

### 2.1 平台范围

首版目标平台分两层：

- P0：Android、iOS、macOS、Windows、Linux
- P1：Web

P0 要求完整本地阅读闭环。P1 Web 先要求可启动、可浏览 UI、可使用不依赖本机文件系统的常用设置；本地图书导入和数据库能力按 Web 受限方案推进，不与 P0 同步卡死。

### 2.2 功能保留

首版保留：

- 首页 / 书架 / 本地书库
- 本地图书导入、索引、详情、阅读
- 阅读器基础能力：翻页/滚动、目录、进度、书签、阅读记录、阅读设置、主题外观
- 我的 / 设置 / 关于 / 反馈入口
- 主题、启动图、背景图、封面等本地资源管理
- 缓存管理、诊断导出、基础设备标识
- WebDAV 同步可作为 P1+，不阻塞 P0 全平台本地阅读

### 2.3 功能延期

首版延期：

- 书源管理、书源导入、脚本源编辑器
- 在线搜索、发现页在线内容、批量校验
- 书源登录、WebView 验证、源调试服务
- 书源切换、在线章节缓存、在线正文拉取
- MD3 / 阅读书源迁移工具和兼容说明

延期方式不是删除代码，而是通过能力开关、路由守卫和 UI 入口隐藏隔离。

## 3. 总体架构策略

### 3.1 建立平台能力层

新增统一能力判断，不让页面直接判断平台或插件可用性。

建议能力项：

- `supportsLocalFileImport`
- `supportsManagedFileStorage`
- `supportsNativeSqlite`
- `supportsDriftWebStorage`
- `supportsImagePicking`
- `supportsReaderBrightnessBridge`
- `supportsReaderVolumeKeyBridge`
- `supportsSourceRuntime`
- `supportsInteractiveWebView`
- `supportsWebDavSync`

所有功能入口根据能力项展示、隐藏或降级。

### 3.2 依赖边界收口

目标是让业务层不直接依赖平台插件：

- 文件系统：收口到 `core/storage` 和 `reader/application/local` 的平台适配。
- 图片选择：继续收口到 `core/media/image_selection_service.dart`。
- 数据库：原生端继续 SQLite；Web 单独建立 Drift Web 驱动或内存/IndexedDB 受限模式。
- 阅读器平台桥：继续保留 `ReaderPlatformBridgeService`，桌面/Web 默认 no-op。
- 书源运行时：首版统一挂在 `supportsSourceRuntime == false` 后面。

### 3.3 路由与启动隔离

首版需要在路由和启动阶段隔离书源：

- `/source`、`/source/login`、`/source/web-login`、`/source/script-editor`、`/source/paste-import` 首版隐藏入口，并可重定向到占位页或设置说明页。
- `/search` 首版改为本地搜索或隐藏入口，不触发脚本源运行时。
- `/discover` 首版改为本地/静态内容或隐藏入口，不触发在线书源。
- 启动 deferred task 中的 `SourceLogStore.restore`、`SourceRuntimeDiagnosticsService.reportRecoveredInvocations`、`SourceHealthService.hydrate` 挂到书源能力开关后。
- `AppStartupCoordinator` 不再把书源运行时作为首版启动必要依赖。

## 4. 阶段计划

执行补充：

- 阶段任务继续按整阶段推进，不按阶段内零散小项单独交付。
- 功能兼容改动按 `docs/page_function_multiplatform_methods_2026-05-12.md` 逐页面回填能力边界、降级方式和验证结果。
- UI 展示改动按 `docs/page_ui_multiplatform_display_plan_2026-05-12.md` 回填展示模型和截图/运行验收。
- 每完成一个阶段，必须同步更新本文阶段记录和对应的页面级方法文档。

### 阶段 0：范围冻结与基线确认

目标：确认首版到底验收什么，避免边做边把书源又带回来。

- [x] 写入 `AppCapability` / `PlatformCapability` 设计草案。
- [x] 明确 P0 平台：Android、iOS、macOS、Windows、Linux。
- [x] 明确 P1 Web：先启动和 UI 可用，再逐步补齐本地存储。
- [x] 确认首版导航：书架、阅读记录、我的为主；发现/搜索/书源按能力隐藏。
- [x] 确认首版阅读格式：`txt`、`epub` 为 P0；`md`、`html` 为 P1；`pdf`、`mobi`、`azw/azw3` 为 P2。

验收：

- 一份范围清单进入 docs。
- 每个延期功能都有入口处理方式，不出现点进去才报错的路径。

### 阶段 1：全平台编译边界清理

目标：先让目标平台能编译，再谈体验。

- [x] 扫描并分类所有 `dart:io` 导入：UI 展示、文件读写、数据库、日志、资源、书源、同步。
- [x] 对 UI 中的 `File` / `FileImage` 使用平台安全包装，Web 下提供占位或网络/内存图片路径。
- [x] `app/app.dart`、`reader_page.dart` 等直接使用 `Platform.isIOS/isAndroid` 的位置改为平台能力或 `defaultTargetPlatform + kIsWeb`。
- [x] `app_database.dart` 拆分原生和 Web 初始化入口。
- [x] 书源相关 `dart:io` 和 JS runtime 不参与 Web 首版编译路径。
- [ ] 在统一构建脚本中加入 Web build 目标。

验收：

- `flutter analyze` 通过。
- P0 平台至少完成 debug 构建。
- Web 至少能执行 `flutter build web` 或明确记录剩余 Web-only 阻塞。

### 阶段 2：导航与 UI 自适应收口

目标：移动端、平板、桌面、Web 的主 UI 都不像“拉大的手机应用”。

- [x] 基于现有 `flutter_adaptive_baseline_matrix.md` 扩展桌面视口：`1024x768`、`1280x800`、`1440x900`、`1920x1080`。
- [x] 书架页支持桌面密度：搜索/筛选/导入操作固定在可扫描区域，内容网格按容器宽度重排。
- [x] 本地书库页支持桌面文件管理心智：列表、排序、导入状态、重索引状态清晰可见。
- [x] 书籍详情页在宽屏使用封面/元信息/目录分区布局，不简单放大手机纵向布局。
- [x] 我的/设置页降低大卡片和大留白，桌面端使用内容最大宽度和双栏分组。
- [x] 阅读设置弹层在桌面端改为侧栏/浮层，在移动端保留底部弹层。
- [x] 所有核心页面覆盖文字缩放 `1.0x` 和 `1.3x`。

验收：

- P0 页面在手机、小平板、桌面视口无横向溢出、遮挡和底部导航误挡。
- 鼠标悬停、右键/长按、键盘焦点不破坏基础操作。

### 阶段 3：常用业务全平台化

目标：非书源业务在 P0 平台上闭环。

- [x] 书架：本地书籍展示、继续阅读、最近阅读、筛选排序。
- [x] 本地导入：桌面使用文件选择器，移动端保留系统分享/打开方式和选择器；不支持文件选择器的平台显示受限状态。
- [x] 详情：本地图书元数据编辑、封面编辑、目录入口、删除/重索引。
- [x] 书签：添加、删除、列表、从书签跳转阅读位置。
- [x] 阅读记录：日历/统计/最近记录，宽屏适配。
- [x] 外观：主题、阅读背景、启动图、底部导航图标、本地资源引用。
- [x] 缓存/日志：缓存清理、诊断导出在桌面端路径可控，Web 下隐藏或降级。
- [x] 同步：WebDAV 放入 P1+，默认关闭，不阻塞本地首版。

验收：

- 不登录、不配置书源，也能完整使用核心本地阅读业务。
- 常用业务没有隐性触发 `SourceRuntimeFacade`、`SearchService` 在线执行或 WebView。

### 阶段 4：UI 可见性与多端首屏验收

目标：补齐“功能可用”之外的 UI 首屏、弹窗、资产、导航和端差异验收，避免 Web 空白、桌面 overflow、移动端误挡这类问题漏出。

- [x] Web 首屏不依赖外网 Flutter Web 资源，构建和运行默认使用本地 CanvasKit。
- [x] Web 首屏不因 `dart:io` / `FileImage` 出现在 app 壳、启动图或共享 UI import 链而空白。
- [x] Web 插件注册链不因 native/mobile 优先插件的 Web 实现异常而阻断首屏。
- [x] macOS 桌面首屏和启动公告弹窗无 RenderFlex overflow。
- [ ] Android / iOS / macOS / Windows / Linux / Web 均建立首屏截图或日志验收记录。
- [ ] 主导航在手机、平板、桌面、Web 下分别验证：可见、可点击、选中态正确、受限入口有占位。
- [ ] 全局弹窗、公告、更新、导入导出进度、错误提示覆盖小窗口、桌面默认窗口和大字体。
- [ ] 主题背景、启动图、封面、底部导航图标等 UI 资产在 Web/桌面受限路径下不崩溃并有占位。
- [ ] 桌面端 hover、滚轮、窗口缩放、键盘焦点不破坏书架/本地书库/详情/设置。
- [ ] Web 受限能力页面不能是空白页；必须是统一占位、禁用态或可浏览内容。

验收：

- `flutter run -d chrome --no-web-resources-cdn` 不出现 CanvasKit / Roboto 外网加载失败导致的白屏。
- `flutter run -d macos` 首屏与启动弹窗无 overflow/error 级 UI 日志。
- 自适应 smoke 只算基础门槛，真实端 run/screenshot/log 至少覆盖 Web 与一个桌面端。

### 阶段 5：本地阅读优先闭环

目标：本地阅读是首版全平台的主价值。

- [ ] `txt`：统一字符集检测和解码策略，减少原生编码插件依赖；移动端、桌面端行为一致。
- [ ] `epub`：索引阶段产出完整章节正文和 `ReaderDocument`，阅读阶段不再做主解析。
- [ ] `md/html`：作为 P1 格式接入，统一落到 `LocalParsedBook -> LocalChapter -> ReaderDocument`。
- [ ] `pdf`：标注为 P2，优先支持文本型 PDF；图片型 PDF 后续独立方案。
- [ ] `mobi/azw/azw3`：标注为 P2，先验证 `dart_mobi` 在桌面端和移动端的稳定性。
- [ ] 阅读器输入：移动端手势优先，桌面端补齐键盘翻页、鼠标滚轮、窗口尺寸变化后的分页恢复。
- [ ] 阅读器性能：沿用低资源计划，三章窗口、流式分页、图片预算和缓存字节预算进入首版验收。

验收：

- P0 平台可导入并阅读 `txt`、`epub`。
- `ready` 状态表示目录和正文都可读。
- 断网状态下本地图书可完整阅读。

### 阶段 6：书源功能延期隔离

目标：不是删书源，而是让首版不被书源拖住。

- [x] 新增“书源功能未启用/后续版本开放”的统一占位状态。
- [x] 隐藏或降级书源页、脚本编辑器、登录页、调试页入口。
- [x] 搜索页首版只搜索本地书库，或从主导航移除。
- [x] 发现页首版只保留本地推荐/空状态，或从主导航移除。
- [x] 书籍详情隐藏切换书源相关操作。
- [x] 阅读器禁用在线章节缓存和源切换。
- [x] 启动任务不恢复书源健康状态、不上报书源运行时诊断。

验收：

- 首版用户路径中不会出现“书源执行失败”类错误。
- 书源代码仍可在后续通过能力开关重新接入。

### 阶段 7：构建、测试与发布矩阵

目标：用固定矩阵保护全平台。

- [x] `flutter analyze`
- [x] `flutter test`
- [x] 自适应 smoke：手机、横屏、平板、桌面视口。
- [x] 阅读器 smoke：打开本地图书、翻页、目录跳转、书签、恢复进度。
- [ ] 构建矩阵：
  - macOS 主机：Android、iOS、macOS、Web
  - Linux 主机：Android、Linux、Web
  - Windows 主机：Android、Windows、Web
- [x] 统一构建脚本补齐 Web 产物收集。
- [x] 发布说明明确首版不包含在线书源能力。

验收：

- P0 平台有可交付产物。
- Web 有明确的受限能力说明和单独验收记录。

## 5. 平台能力矩阵

| 功能 | Android | iOS | macOS | Windows | Linux | Web |
| --- | --- | --- | --- | --- | --- | --- |
| 启动与主导航 | P0 | P0 | P0 | P0 | P0 | P1 |
| 自适应 UI | P0 | P0 | P0 | P0 | P0 | P1 |
| 本地文件导入 | P0 | P0 | P0 | P0 | P0 | P1 受限 |
| 本地 SQLite | P0 | P0 | P0 | P0 | P0 | 需替代 |
| TXT 阅读 | P0 | P0 | P0 | P0 | P0 | P1 |
| EPUB 阅读 | P0 | P0 | P0 | P0 | P0 | P1 |
| MD/HTML 阅读 | P1 | P1 | P1 | P1 | P1 | P1 |
| PDF 阅读 | P2 | P2 | P2 | P2 | P2 | 暂缓 |
| MOBI/AZW 阅读 | P2 | P2 | P2 | P2 | P2 | 暂缓 |
| 书签/阅读记录 | P0 | P0 | P0 | P0 | P0 | P1 |
| 主题/外观 | P0 | P0 | P0 | P0 | P0 | P1 |
| WebDAV 同步 | P1+ | P1+ | P1+ | P1+ | P1+ | 暂缓 |
| 在线书源 | 延期 | 延期 | 延期 | 延期 | 延期 | 延期 |
| 书源调试/WebView 登录 | 延期 | 延期 | 延期 | 延期 | 延期 | 延期 |

## 6. 首批代码改造清单

建议按以下顺序开工：

1. 增加 `AppCapability` 能力层和 provider。
2. 把启动阶段书源 deferred task 挂到能力开关后。
3. 把路由和主导航里的书源/在线搜索/发现入口隐藏或降级。
4. 清理 Web 编译路径上的 `dart:io` 直接导入。
5. 拆分数据库初始化，明确 Web 存储策略。
6. 书架、本地书库、书籍详情、阅读器设置做桌面视口适配。
7. 本地 `txt/epub` 导入和阅读在 macOS、Windows、Linux 上做专项验收。
8. 统一构建脚本补 Web。

## 7. 风险与处理

- Web 不是简单加平台目录即可完成：当前 `dart:io`、SQLite、文件系统、插件支持都会影响编译，应作为 P1 独立推进。
- 书源延期必须做“入口隔离”，不能只在文档里说排除，否则启动任务和在线业务仍会拖累全平台。
- 桌面端不是手机 UI 放大版，书架、详情、设置、阅读器设置至少要有宽屏结构。
- 本地多格式不要一口气全上，先把 `txt/epub` 的 ready 语义和跨平台解析稳定下来。
- 同步功能依赖安全存储、文件系统和网络错误处理，建议放在本地阅读闭环之后。

## 8. 推荐里程碑

- M1：P0 平台可启动、主导航可用、书源入口隔离。
- M2：Android / iOS / macOS / Windows / Linux 本地 `txt/epub` 导入阅读闭环。
- M3：核心 UI 桌面/平板适配完成，常用业务 smoke 通过。
- M4：统一构建脚本产出 P0 平台安装包。
- M5：Web 首版受限模式可启动，并明确哪些本地能力可用。
- M6：回到书源专题，按独立计划恢复在线搜索、书源管理和运行时。

## 9. 阶段 0/1 执行记录（2026-05-11）

### 已完成

- [x] 新增 `AppPlatformCapabilities` 能力层，首版默认关闭 `supportsSourceRuntime`，可通过 `--dart-define=APP_ENABLE_SOURCE_RUNTIME=true` 回开。
- [x] 书源运行时启动 warmup 改为能力开关控制，默认不再在启动阶段读取脚本源列表。
- [x] 主导航发现页跟随能力开关隐藏；用户偏好中即使保存了发现页，也会在书源关闭时归一化为隐藏。
- [x] `/source`、书源登录、网页登录、脚本编辑、粘贴导入、`/search`、`/discover` 已接入首版占位页。
- [x] Cupertino dock 搜索入口在书源关闭时隐藏。
- [x] 书架顶部在线搜索入口在书源关闭时隐藏。
- [x] 数据库连接拆成条件导入：原生端继续 `NativeDatabase`，Web 端先接 `WebDatabase` 作为阶段 1 编译通道。
- [x] 修复 Web 编译暴露的 JS 整数精度问题，将阅读分页缓存 hash 改为 JS 安全整数范围内的稳定 hash。
- [x] 修复 Web 编译下 `flutter_svg` 与 `dart:io File` 类型冲突，本地 SVG 改为读取文本后用 `SvgPicture.string` 渲染。

### 验证结果

- [x] `flutter analyze`：通过。
- [x] `flutter build web --debug`：通过，产物位于 `build/web`。
- [x] `flutter test test/features/presentation/page_adaptive_smoke_test.dart`：通过。
- [ ] `flutter test test/app/layout/adaptive_breakpoints_test.dart test/app/layout/adaptive_ui_matrix_test.dart test/features/presentation/page_adaptive_smoke_test.dart`：未通过，失败集中在既有导航/文字缩放测试预期：
  - `AppLayout.clampedTextScaleFactor` 当前实现上限为 `1.5`，测试仍期望手机 `1.24`、平板 `1.3`。
  - `ShellScaffold` 相关测试仍期望首页默认隐藏、iOS followSystem 使用 Cupertino dock；当前实现与首版导航口径不一致，需要后续统一产品口径后更新测试或回调实现。

### 遗留说明

- Web 数据库当前使用 Drift 旧 `WebDatabase` 通道，只作为阶段 1 编译和受限运行基线；后续应迁移到 `WasmDatabase` 并补齐 `sqlite3.wasm` / worker 静态资源。
- Web 虽已能编译，但本地文件导入、托管文件存储、图片/字体资源管理仍按受限能力处理，不进入 P0 验收。
- 在线书源代码仍保留，默认入口隔离；恢复时应通过 `APP_ENABLE_SOURCE_RUNTIME=true` 和独立书源专题验证。

## 10. 阶段 2 执行记录（2026-05-11）

### 已完成：导航与 UI 自适应收口

- [x] `test/test_utils/adaptive_test_harness.dart` 默认自适应 smoke 矩阵加入桌面视口：`1024x768 @1.0`、`1280x800 @1.0`、`1440x900 @1.0`、`1920x1080 @1.0`。
- [x] `runAdaptivePageSmokeMatrix` 默认覆盖 `1.0x` 和 `1.3x` 文字缩放。
- [x] 书架页新增 expanded 桌面工具条，搜索、筛选摘要、排序、视图切换、选择和导入集中在顶部可扫描区域；内容区按 `bookshelfContentMaxWidth` 居中，网格继续使用容器宽度重排。
- [x] 本地书库页升级为文件管理视图，包含导入面板、书库状态汇总、本地文件列表、按索引状态和更新时间排序、单书重索引状态反馈。
- [x] 书籍详情页在 expanded 宽屏拆成封面元信息、简介/提示、操作/归类/本地索引状态三列；中屏继续保留双栏，手机保留纵向布局。
- [x] 我的页 expanded 桌面端拆成左侧账号快捷区和右侧设置分组区；系统设置页使用两列分组，降低单列大留白。
- [x] 阅读设置浮层在 expanded 桌面端切换为右侧浮层，移动端和中屏仍保留底部弹层心智。
- [x] `docs/flutter_adaptive_baseline_matrix.md` 与 `docs/adaptive_visual_regression_checklist.md` 已同步阶段 2 桌面矩阵和页面检查口径。

### 平台影响

- 影响平台：Android、iOS、macOS、Windows、Linux、Web 的 UI 自适应表现。
- 不影响平台能力边界：未新增平台插件，未改变数据库 schema，未重新打开在线书源运行时。
- 隔离策略：页面仍通过 `AppLayout`、`AppAdaptiveMetrics`、能力 provider 和既有服务完成适配，没有新增分散的端判断。

### 验证结果

- [x] `flutter analyze`：通过。
- [x] `flutter test test/app/layout/adaptive_ui_matrix_test.dart test/features/presentation/page_adaptive_smoke_test.dart test/app/layout/app_adaptive_metrics_test.dart`：通过，覆盖手机、横屏、中屏、平板、桌面视口和 `1.0x / 1.3x` 文字缩放。

### 遗留说明

- 真实截图仍未批量保存，后续阶段可接入自动截图或人工采样到 `artifacts/adaptive_baseline/phase_2_bookshelf/`。
- 阶段 2 仅收口 UI 与常用操作可达性；本地阅读业务闭环、桌面键盘/鼠标阅读输入和构建发布矩阵继续放到后续阶段。

## 11. 阶段 3 执行记录（2026-05-11）

### 已完成：常用业务全平台化

- [x] 本地书库导入入口接入 `supportsLocalFileImport`，不支持文件选择器的平台禁用导入按钮并展示受限说明；页面移除直接 `dart:io File` 依赖。
- [x] 书籍详情换源入口接入 `supportsSourceRuntime`，首版默认关闭书源运行时时不会触发 `SearchService` 换源搜索。
- [x] WebDAV 同步新增独立能力开关 `APP_ENABLE_WEBDAV_SYNC`，`/sync` 与 `/sync/history` 在未启用时展示统一占位页。
- [x] 缓存管理页接入 `supportsManagedFileStorage`，受限平台提示路径与批量清理会降级显示。
- [x] 错误中心接入 `supportsManagedFileStorage`，受限平台提示诊断日志优先复制文本，支持分享的平台继续导出文件。
- [x] 增加平台能力测试，确认书源运行时与 WebDAV 同步均为显式 opt-in 能力。
- [x] 增加详情换源回归测试，覆盖“默认关闭时按钮不可交互且不调用 `SearchService`”和“显式启用时可换源”两条路径。

### 平台影响

- 影响平台：Android、iOS、macOS、Windows、Linux、Web 的常用业务入口可用性与受限提示。
- 不影响平台：未新增原生插件，未改变数据库 schema，未重新打开在线书源、WebView 登录或脚本源调试。
- 隔离策略：平台差异统一通过 `AppPlatformCapabilities` 暴露给页面；同步、导入、缓存、日志、换源均通过 capability 禁用、降级或占位，避免单端改动误伤另一端 UI。

### 验证结果

- [x] `flutter analyze`：通过。
- [x] `flutter test test/app/platform/app_platform_capabilities_test.dart test/features/book/presentation/book_detail_switch_source_test.dart test/features/book/presentation/book_detail_primary_actions_test.dart test/features/mine/application/cache_management_service_test.dart test/features/reader/application/reading_record_service_test.dart test/features/reader/application/reading_records_query_service_test.dart test/features/mine/application/bookmarks_query_service_test.dart`：通过。
- [x] `flutter test test/app/layout/adaptive_ui_matrix_test.dart test/features/presentation/page_adaptive_smoke_test.dart test/app/layout/app_adaptive_metrics_test.dart`：通过，确认阶段 3 没有破坏阶段 2 自适应 UI 基线。

### 遗留说明

- 阶段 3 只保证非书源常用业务闭环和受限平台降级；在线书源入口隐藏、发现/搜索本地化和启动书源健康恢复继续归入阶段 5。
- WebDAV 同步保留为 P1+ 能力，需要后续通过 `--dart-define=APP_ENABLE_WEBDAV_SYNC=true` 单独打开并补同步矩阵验证。
- 本地阅读格式、桌面键盘/鼠标阅读输入、`txt/epub` 解析一致性继续进入阶段 4。

## 12. 阶段 4 UI 首屏执行记录（2026-05-12）

### 已完成：Web 空白与 macOS UI 报错修复

- [x] 复现 Web 空白：默认 `flutter run -d chrome` 会从 `https://www.gstatic.com/flutter-canvaskit/...` 与 `fonts.gstatic.com` 拉取 Flutter Web 资源；网络失败时 Flutter 引擎未启动，页面白屏。
- [x] 验证 Web 解决路径：`flutter run -d chrome --no-web-resources-cdn` 不再触发 gstatic CanvasKit 加载失败；`flutter build web --debug --no-web-resources-cdn --no-wasm-dry-run` 通过。
- [x] `scripts/build_unified_artifacts.sh` 增加 `web` 平台，默认执行 `flutter build web --no-web-resources-cdn --no-wasm-dry-run` 并输出 `Selune-web-<mode>.tar.gz`。
- [x] `lib/app/app.dart` 首屏键盘 inset 分支移除直接 `Platform.isAndroid/isIOS`，改用 `kIsWeb + defaultTargetPlatform`。
- [x] 启动图文件渲染拆成条件导入：原生端使用 `FileImage`，Web 端回落到内置启动图，避免 app 壳共享 import 链带入 `dart:io`。
- [x] `flutter_charset_detector_web` 改为项目本地 stub override，避免 Web 插件注册阶段访问缺失的 JS `enableDebug` 导致首屏中断；Web TXT 编码检测按 P1 受限能力后续补齐。
- [x] Web deferred 启动任务按 capability 跳过原生文件/SQLite 维护，避免 `path_provider`、Drift Web sql.js 在首屏后输出受限平台错误。
- [x] 复现并修复 macOS UI 报错：启动公告弹窗在桌面窗口高度下 `RenderFlex overflowed by 3.4 pixels`，现改为高度受限时正文卡片整体可滚动。

### 验证结果

- [x] `flutter analyze`：通过。
- [x] `flutter build web --debug --no-web-resources-cdn --no-wasm-dry-run`：通过，产物包含本地 `build/web/canvaskit/*`。
- [x] `SKIP_CLEAN=1 SKIP_PUB_GET=1 VERSION_PROMPT=0 ./scripts/build_unified_artifacts.sh web debug`：通过，产物位于 `build/unified_artifacts/20260512-060906-debug/Selune-web-debug.tar.gz`。
- [x] `flutter run -d chrome --web-port=53117 --no-web-resources-cdn`：启动后未再出现 CanvasKit 外网加载失败、`flutter_charset_detector_web` 注册异常、`path_provider` 缺失或 Drift sql.js 启动维护错误。
- [x] `flutter run -d macos`：复现公告弹窗 overflow；修复后 hot reload 未再输出该 overflow。

### 遗留说明

- Codex 当前无 Chrome 屏幕读取权限，本次 Web 通过 Flutter run 日志和本地 CanvasKit build 验证首屏启动链路；后续仍需要补真实截图。
- 阶段 4 UI 双轨已经补进阶段计划，但 Android/iOS/Windows/Linux 的真实端截图和窗口缩放记录尚未完成。
- 阶段编号已从此处起后移：原“本地阅读优先闭环”为阶段 5，原“书源功能延期隔离”为阶段 6，原“构建、测试与发布矩阵”为阶段 7。

## 13. 页面功能阶段 A 执行记录（2026-05-12）

### 已完成：页面能力盘点与平台文件边界收口

- [x] 新增 `docs/page_function_multiplatform_methods_2026-05-12.md`，逐页面定义功能、端状态、capability / service / bridge 边界、降级方法和后续阶段。
- [x] 新增 `local_file_image` 条件导入 adapter：原生端支持本地文件图片，Web 端统一回落占位，页面不直接创建 `FileImage`。
- [x] 新增 `local_file_stat` 条件导入 adapter：原生端支持文件存在性、stat、bytes/text 读取，Web 端统一返回不可用结果。
- [x] `BookDetailPage` 本地封面背景和本地图书诊断文件状态改走 adapter。
- [x] `ReaderPage` presentation 链的本地正文图片、SVG 文件读取、阅读器背景、诊断文件状态改走 adapter。
- [x] `MinePage` 头像、`ResolvedBookCoverView`、高级主题背景装饰的本地文件图片显示改走 adapter。

### 平台影响

- 影响平台：Android、iOS、macOS、Windows、Linux、Web 的本地图片显示、阅读器背景、详情诊断和头像占位降级路径。
- 不影响平台：未新增原生插件，未改变数据库 schema，未重开书源运行时、WebDAV 或在线搜索。
- 隔离策略：presentation 层不再直接依赖 `dart:io` / `FileImage` / `FileStat`，Web 通过 adapter 返回空 provider、空 bytes 或不可用 stat。

### 验证结果

- [x] `flutter analyze`：通过。
- [x] `flutter test test/features/book/presentation/book_detail_switch_source_test.dart test/features/book/presentation/book_detail_primary_actions_test.dart test/features/presentation/page_adaptive_smoke_test.dart test/features/reader/application/reader_layout_resolver_test.dart`：通过。
- [x] `flutter build web --debug --no-web-resources-cdn --no-wasm-dry-run`：通过，产物位于 `build/web`。

### 遗留说明

- 资源管理、高级主题导入导出、字体管理仍有 service / application 层文件读写，本轮不迁移业务实现，归入功能阶段 C。
- 书架 flow、底部导航图标、阅读器底层图片 pipeline 仍有历史文件处理路径，后续按页面功能阶段继续收口，不能在页面层新增类似依赖。

## 14. 页面功能阶段 B 执行记录（2026-05-12）

### 已完成：本地阅读主链路入口守卫与桌面输入验收

- [x] 新增 `LocalReaderEntryGuardService`，统一判断本地图书是否存在、索引是否 ready、目标章节是否仍存在。
- [x] 书架继续阅读入口接入本地入口守卫：本地图书缺失时提示不可用，索引未 ready 或章节缺失时回到详情页提示重建索引。
- [x] 阅读记录跳转接入本地入口守卫：本地记录不会直接跳进空 reader。
- [x] 书签跳转接入本地入口守卫：本地书或章节缺失时提示，保留书签记录。
- [x] 新增 `ReaderDesktopInputResolver`，固定桌面键盘和滚轮阅读动作规则，覆盖方向键、PageUp/PageDown、Space、Home/End、滚轮阈值和节流。

### 平台影响

- 影响平台：Android、iOS、macOS、Windows、Linux、Web 的本地阅读入口、阅读记录和书签跳转行为。
- 不影响平台：未新增原生插件，未改变数据库 schema，未改变书源运行时默认关闭策略。
- 隔离策略：入口判断在 application service 内完成，页面只消费 route resolution 或 guard result，不直接读取本地章节表。

### 验证结果

- [x] `flutter analyze`：通过。
- [x] `flutter test test/features/bookshelf/application/bookshelf_page_route_service_test.dart test/features/reader/application/local/local_reader_entry_guard_service_test.dart test/features/reader/application/reader_desktop_input_resolver_test.dart test/features/reader/presentation/reading_records_page_test.dart test/features/mine/application/bookmarks_query_service_test.dart test/features/reader/application/reader_layout_resolver_test.dart`：通过。

### 遗留说明

- 详情页本地删除/重索引仍可继续拆成更明确的 application action result，归入后续本地资源管理阶段。
- Web 数据库初始化失败时的整页可恢复错误仍留给 Web 存储专项。

## 15. 页面功能阶段 C 执行记录（2026-05-12）

### 已完成：个人业务、资源显示和诊断导出降级

- [x] 字体管理页接入 `AppPlatformCapabilities`：受限平台禁用字体导入，保留已有字体状态展示和说明。
- [x] 字体文件存在性判断从页面和界面字体 provider 中移除，统一走 `localFileExists` 条件导入 adapter。
- [x] 外观资源集合缩略图、底部导航本地 SVG/PNG/GIF 图标改走 `local_file_image` / `local_file_stat` adapter，Web 回落为占位图标。
- [x] 诊断日志导出拆成 native/web 条件实现：native 继续生成可分享文件，Web 生成同样文本并由错误中心复制到剪贴板。
- [x] 新增 `diagnostic_log_export_service_test`，覆盖无可导出日志、native 文件写入和文本兜底内容。

### 平台影响

- 影响平台：Android、iOS、macOS、Windows、Linux、Web 的字体管理、外观资源预览、底部导航图标和诊断日志导出行为。
- 不影响平台：未重开书源运行时、WebDAV、在线搜索或 WebView；未改变数据库 schema。
- 隔离策略：页面层不直接读取本地文件图片、SVG 文本或字体文件状态；Web 由条件实现返回占位、不可用状态或文本兜底，避免一个端的文件路径能力影响另一端 UI。

### 验证结果

- [x] `flutter analyze`：通过。
- [x] `flutter test test/core/logging/diagnostic_log_export_service_test.dart test/features/mine/application/cache_management_service_test.dart test/features/mine/application/advanced_theme_resource_reference_service_test.dart test/features/mine/application/launch_image_gallery_service_test.dart test/features/mine/presentation/mine_management_page_test.dart test/features/presentation/page_adaptive_smoke_test.dart`：通过。
- [x] `flutter build web --debug --no-web-resources-cdn --no-wasm-dry-run`：通过。

### 遗留说明

- 高级主题编辑页和高级主题导入导出仍有较重的归档/文件读写流程，后续需要继续向 application/service 和条件 adapter 收口。
- 缓存管理目前完成 capability 降级说明和清理边界，独立“复制诊断摘要”按钮可作为后续体验增强。

## 16. 页面功能阶段 D/E 执行记录（2026-05-12）

### 已完成：延期入口隔离与页面级验证矩阵

- [x] 启动延迟任务中 `SourceRuntimeDiagnosticsService.reportRecoveredInvocations()` 和 `SourceHealthService.hydrate()` 已接入 `supportsSourceRuntime`；默认首版关闭书源运行时时不恢复书源健康状态、不上报书源运行时诊断。
- [x] `/book/:bookId` 在线详情路由新增 capability 守卫；默认关闭书源运行时时进入 `FeatureDisabledPage`，不创建在线详情加载链路。
- [x] `/reader/:bookId/:chapterId` 在线章节路由新增 capability 守卫；默认关闭书源运行时时进入 `FeatureDisabledPage`，不创建在线 reader。
- [x] `ReaderFeatureDependencies` 默认只注册本地内容 provider；只有 `supportsSourceRuntime=true` 时才注册 `SourceContentProvider`。
- [x] `ReaderModeCapabilitiesResolver` 新增 source runtime gate，换源和在线章节缓存能力必须叠加全局 capability。
- [x] 补 `deferred_entry_capability_test` 覆盖书源、搜索、发现、在线详情和在线章节禁用页；补 reader provider / mode capability 回归。
- [x] 在 E 阶段矩阵中发现并修复 `MinePage` 在 `initState` 读取 `MediaQuery` 的生命周期问题，改到 `didChangeDependencies` 后恢复布局模式。

### 平台影响

- 影响平台：Android、iOS、macOS、Windows、Linux、Web 的延期功能入口、在线详情/阅读路由、本地阅读 provider 注册和 Mine 页自适应初始化。
- 不影响平台：未新增原生插件，未改变数据库 schema，未重新打开在线书源运行时、WebDAV 或在线搜索。
- 隔离策略：首版本地阅读仍保留 `/local/reader`、本地详情和本地 provider；在线能力统一由 `supportsSourceRuntime` 拦截，避免书源运行时进入启动和阅读主链路。

### 验证结果

- [x] `flutter analyze`：通过。
- [x] `flutter test test/app/platform/app_platform_capabilities_test.dart test/features/book/presentation/book_detail_switch_source_test.dart test/features/book/presentation/book_detail_primary_actions_test.dart test/features/bookshelf/application/bookshelf_page_route_service_test.dart test/features/reader/application/local/local_reader_entry_guard_service_test.dart test/features/reader/application/reader_desktop_input_resolver_test.dart test/features/reader/presentation/reading_records_page_test.dart test/features/mine/application/bookmarks_query_service_test.dart test/features/presentation/page_adaptive_smoke_test.dart test/features/reader/application/reader_layout_resolver_test.dart test/features/reader/application/reader_mode_capabilities_test.dart test/features/reader/application/reader_dependencies_provider_test.dart test/features/routes/deferred_entry_capability_test.dart`：通过。
- [x] `flutter build web --debug --no-web-resources-cdn --no-wasm-dry-run`：通过，产物位于 `build/web`。

### 遗留说明

- macOS 真实 run、Windows/Linux 真实主机矩阵仍需在对应环境补充；本轮 E 阶段先以自动化测试和 Web build 关闭代码级风险。
- 书源、在线搜索、发现在线内容、WebView 登录和脚本调试仍保持延期；恢复时必须走独立书源专题和显式 `APP_ENABLE_SOURCE_RUNTIME=true` 验证。
