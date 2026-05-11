# 全平台兼容总计划（书源延期版）

更新时间：2026-05-11  
用途：把项目从“Android / iOS 优先”推进到“Android、iOS、macOS、Windows、Linux、Web 全平台可用”的执行计划。  
当前口径：先兼容 UI、常用业务和本地阅读；在线书源、脚本源运行时、书源登录/调试/迁移能力整体移出首版范围。

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
- `scripts/build_unified_artifacts.sh` 已覆盖 Android、iOS、macOS、Windows、Linux 的统一产物收集；Web 尚未纳入统一打包脚本。
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
- `supportsSourceDebugServer`
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

### 阶段 0：范围冻结与基线确认

目标：确认首版到底验收什么，避免边做边把书源又带回来。

- [ ] 写入 `AppCapability` / `PlatformCapability` 设计草案。
- [ ] 明确 P0 平台：Android、iOS、macOS、Windows、Linux。
- [ ] 明确 P1 Web：先启动和 UI 可用，再逐步补齐本地存储。
- [ ] 确认首版导航：书架、阅读记录、我的为主；发现/搜索/书源按能力隐藏。
- [ ] 确认首版阅读格式：`txt`、`epub` 为 P0；`md`、`html` 为 P1；`pdf`、`mobi`、`azw/azw3` 为 P2。

验收：

- 一份范围清单进入 docs。
- 每个延期功能都有入口处理方式，不出现点进去才报错的路径。

### 阶段 1：全平台编译边界清理

目标：先让目标平台能编译，再谈体验。

- [ ] 扫描并分类所有 `dart:io` 导入：UI 展示、文件读写、数据库、日志、资源、书源、同步。
- [ ] 对 UI 中的 `File` / `FileImage` 使用平台安全包装，Web 下提供占位或网络/内存图片路径。
- [ ] `app/app.dart`、`reader_page.dart` 等直接使用 `Platform.isIOS/isAndroid` 的位置改为平台能力或 `defaultTargetPlatform + kIsWeb`。
- [ ] `app_database.dart` 拆分原生和 Web 初始化入口。
- [ ] 书源相关 `dart:io` 和 JS runtime 不参与 Web 首版编译路径。
- [ ] 在统一构建脚本中加入 Web build 目标。

验收：

- `flutter analyze` 通过。
- P0 平台至少完成 debug 构建。
- Web 至少能执行 `flutter build web` 或明确记录剩余 Web-only 阻塞。

### 阶段 2：导航与 UI 自适应收口

目标：移动端、平板、桌面、Web 的主 UI 都不像“拉大的手机应用”。

- [ ] 基于现有 `flutter_adaptive_baseline_matrix.md` 扩展桌面视口：`1024x768`、`1280x800`、`1440x900`、`1920x1080`。
- [ ] 书架页支持桌面密度：搜索/筛选/导入操作固定在可扫描区域，内容网格按容器宽度重排。
- [ ] 本地书库页支持桌面文件管理心智：列表、排序、导入状态、重索引状态清晰可见。
- [ ] 书籍详情页在宽屏使用封面/元信息/目录分区布局，不简单放大手机纵向布局。
- [ ] 我的/设置页降低大卡片和大留白，桌面端使用内容最大宽度和双栏分组。
- [ ] 阅读设置弹层在桌面端改为侧栏/浮层，在移动端保留底部弹层。
- [ ] 所有核心页面覆盖文字缩放 `1.0x` 和 `1.3x`。

验收：

- P0 页面在手机、小平板、桌面视口无横向溢出、遮挡和底部导航误挡。
- 鼠标悬停、右键/长按、键盘焦点不破坏基础操作。

### 阶段 3：常用业务全平台化

目标：非书源业务在 P0 平台上闭环。

- [ ] 书架：本地书籍展示、继续阅读、最近阅读、筛选排序。
- [ ] 本地导入：桌面使用文件选择器，移动端保留系统分享/打开方式和选择器。
- [ ] 详情：本地图书元数据编辑、封面编辑、目录入口、删除/重索引。
- [ ] 书签：添加、删除、列表、从书签跳转阅读位置。
- [ ] 阅读记录：日历/统计/最近记录，宽屏适配。
- [ ] 外观：主题、阅读背景、启动图、底部导航图标、本地资源引用。
- [ ] 缓存/日志：缓存清理、诊断导出在桌面端路径可控，Web 下隐藏或降级。
- [ ] 同步：WebDAV 放入 P1+，不阻塞本地首版。

验收：

- 不登录、不配置书源，也能完整使用核心本地阅读业务。
- 常用业务没有隐性触发 `SourceRuntimeFacade`、`SearchService` 在线执行或 WebView。

### 阶段 4：本地阅读优先闭环

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

### 阶段 5：书源功能延期隔离

目标：不是删书源，而是让首版不被书源拖住。

- [ ] 新增“书源功能未启用/后续版本开放”的统一占位状态。
- [ ] 隐藏或降级书源页、脚本编辑器、登录页、调试页入口。
- [ ] 搜索页首版只搜索本地书库，或从主导航移除。
- [ ] 发现页首版只保留本地推荐/空状态，或从主导航移除。
- [ ] 书籍详情隐藏切换书源相关操作。
- [ ] 阅读器禁用在线章节缓存和源切换。
- [ ] 启动任务不恢复书源健康状态、不上报书源运行时诊断。

验收：

- 首版用户路径中不会出现“书源执行失败”类错误。
- 书源代码仍可在后续通过能力开关重新接入。

### 阶段 6：构建、测试与发布矩阵

目标：用固定矩阵保护全平台。

- [ ] `flutter analyze`
- [ ] `flutter test`
- [ ] 自适应 smoke：手机、横屏、平板、桌面视口。
- [ ] 阅读器 smoke：打开本地图书、翻页、目录跳转、书签、恢复进度。
- [ ] 构建矩阵：
  - macOS 主机：Android、iOS、macOS、Web
  - Linux 主机：Android、Linux、Web
  - Windows 主机：Android、Windows、Web
- [ ] 统一构建脚本补齐 Web 产物收集。
- [ ] 发布说明明确首版不包含在线书源能力。

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
