# 五层架构全面诊断报告

诊断日期：2026-06-20

诊断范围：`lib/`、`pubspec.yaml`、架构护栏脚本与既有治理文档。

结论先行：

- 项目已经具备比较清晰的 `app / core / domain / data / features` 分层，也已经使用 Riverpod、GoRouter、Drift、Dio、Sentry、Freezed/Json Serializable 等成熟方案。
- 当前主要问题不是“完全没分层”，而是历史复杂功能把分层边界压扁了：页面层过厚、application 层直接拿数据库、`AppDatabase` 巨型化、`core` 与 `data/domain` 出现方向反转。
- 阅读器、书架、书籍详情、个人中心高级主题是复杂度中心。`tool/check_architecture_guardrails.dart --check=imports,large-files` 当前报告了一个硬性违规：`lib/features/bookshelf/presentation/bookshelf_page.dart` 超过 6000 行。

## 各层现状与问题

| 层级 | 当前方案 | 痛点 | 推荐库/方案 |
|---|---|---|---|
| UI 层 | Flutter Material/Cupertino + GoRouter；大量 `ConsumerStatefulWidget`；`app/widgets` 自研 Adaptive 组件、主题 token、动画封装；使用 `flutter_animate`、`shimmer`、`flutter_slidable`、`responsive_framework`、`cached_network_image`、`pdfrx`、`webview_flutter` 等 | 页面文件过大：`bookshelf_page.dart` 6273 行、`reader_page.dart` 5547 行、`book_detail_page.dart` 3727 行；UI 持有大量 service/repository/controller；`part of` 拆文件只是物理拆分，仍共享同一个巨型 State；`private_book_source_form.dart` 在 UI 中直接 `Dio()` 拉取 URL；多个 presentation 文件直接 `dart:io` | P0：把页面改成“渲染 + 交互分发”，业务编排下沉到 feature application facade/controller；P0：移除 UI 里的直接 Dio；P1：使用 `riverpod_lint/custom_lint` 约束 UI 依赖；P1：在现有 `responsive_framework` 和 `app/layout` 上统一适配入口；P2：复杂表单可评估 `flutter_form_builder`，但不应替代现有设计系统 |
| 状态管理层 | 主方案是 `flutter_riverpod`：`Provider`、`StateProvider`、`FutureProvider`、`NotifierProvider`、`AsyncNotifierProvider`；同时存在页面内 `setState`、`ValueNotifier`、`ChangeNotifier`、手写 Timer/cancellation token | Riverpod 与本地 State 混用严重。`SearchPage` 用 Provider 存状态，但页面里又写大量 getter/setter 转发；`ReaderPage` 用多个 Timer 保存进度、自动阅读、加载占位；`ShellScaffold`、`BookDetailPage`、`BookshelfPage` 仍承担状态编排；Provider 命名和作用域多，但缺少自动化约束 | P0：统一“页面状态进 Notifier/AsyncNotifier，瞬时控件状态留本地”的边界；P1：引入 `riverpod_lint` + `custom_lint`，逐步启用 provider 依赖规则；P1：对搜索、阅读器运行态使用明确的 state machine/facade；P2：可评估 `riverpod_generator` 降低 provider 样板代码 |
| 业务逻辑层 | 全局 `domain/entities` + 少量 repository/usecase；主要业务在 `features/*/application` 的 service、controller、resolver、coordinator 中；阅读器有大量自研布局、分页、缓存、来源切换、自动阅读逻辑 | `domain/usecases` 目前很薄，真实业务散在 feature application 与页面；多个 application service 直接依赖 `AppDatabase` 或 `SharedPreferences`；Reader/Bookshelf/Book 之间存在相似流程：元数据展示、阅读入口、阅读状态、缓存刷新；部分页面仍直接写业务判断和流程编排 | P0：每个复杂 feature 增加一个 facade/controller 作为 UI 唯一业务入口；P0：把跨 feature 共享业务抽成 domain repository/usecase 或 core service；P1：继续使用 `freezed` 定义业务状态与事件结果；P1：本地书解析继续优先使用已有 `epub_pro`、`pdfrx`、`markdown`、`html`、`xml`，自研只保留业务差异 |
| 数据层 | Drift + SQLite 是主存储；`AppDatabase` 管理表、迁移、查询、缓存、维护；`SharedPreferences` 保存轻量配置、主题、书架历史数据；少量 repository 实现：Bookmark、LocalBook、BookMetadataOverride | `app_database.dart` 4357 行，表定义、迁移、查询、维护、缓存混在一起；很多 application service 绕过 repository 直接拿 `AppDatabase.instance`；SharedPreferences JSON 存储分散，缺少统一 typed preferences store；缓存既有 SQLite 表，也有自研 `AppCacheStore`、`CoverImageDiskCache`、`ReaderPaginationCacheService` 等 | P0：按 Drift DAO/accessor 拆分 `AppDatabase`，保留一个数据库入口但把查询移到 `*_dao.dart`；P0：为阅读记录、章节缓存、书源健康、书架快照补 repository/DAO 边界；P1：将手写 JSON 模型继续迁移到 `freezed/json_serializable`；P1：统一 typed preferences facade；P2：高频临时缓存可评估 `stash` 或专门 cache box，但不要替换主 Drift |
| 基础设施层 | `core/network/ApiClient` 基于 Dio，自研 envelope、重试、缓存、日志、token 刷新；`core/logging` + Sentry；`core/cache` 自研缓存治理；平台能力通过 conditional import、capability、bridge；使用 Shorebird、window_manager、secure_storage、path_provider、device_info_plus 等 | `ApiClient` 手写了 retry/cache/envelope，和 `core/cache` 形成复杂耦合；`core/cache/app_cache_governance_service.dart`、`core/storage/storage_health_service.dart` 直接依赖 `data/datasources/local/AppDatabase`，基础设施反向依赖数据层；`ApiClient.default*` 静态全局状态会增加测试和多账号隔离难度；平台能力有收口，但 presentation 仍有 `dart:io` 散点 | P0：把 `core -> data` 依赖移到 app composition 或 data/service adapter；P1：用 `retry` 或 Dio interceptor 明确化重试策略，减少手写分支；P1：用 `custom_lint` 固化禁用依赖；P2：如果 API 面继续扩大，可评估 `retrofit.dart` 生成 typed API service，但保留统一 `ApiClient` envelope |

## 跨层架构问题

1. 依赖方向是否正确：

   目标方向应是 UI -> 业务逻辑 -> 数据 -> 基础设施。当前只能算“总体趋势正确，局部方向不纯”。

   - UI/presentation 没有发现直接 `AppDatabase.instance` 的主路径，架构护栏也能检查这一点。
   - 业务层大量直接依赖数据实现，例如 `ReaderPreferencesService`、`ChapterCacheService`、`ReadingRecordService`、`BookshelfService`、`SearchHitCacheService` 直接持有 `AppDatabase`。
   - `core/cache/app_cache_governance_service.dart` 和 `core/storage/storage_health_service.dart` 直接导入 `data/datasources/local/app_database.dart`，属于 `core -> data` 反向依赖。
   - `domain/entities/app_advanced_theme.dart` 导入 `core/storage/managed_asset_directory_policy.dart`，domain 不再是纯模型层。

2. UI 层是否直接调用数据库或网络 API：

   - 没有发现 presentation 直接调用 Drift/SQLite 的情况。
   - 有 UI 直接网络调用：`lib/features/mine/presentation/widgets/private_book_source_form.dart` 中 `_loadRawImportFromUrl` 直接创建 `Dio` 并请求 URL。
   - 多个 presentation 文件导入 `core/network/api_client.dart`，主要是为了捕获 `ApiException`，这不是直接 API 请求，但让 UI 依赖网络基础设施异常类型。

3. 业务逻辑是否散落在 UI 层：

   是，且集中在复杂页面。

   - `BookshelfPage` 页面 State 中持有书架服务、阅读设置、导入服务、封面存储、公告、任务冲突、阅读状态等大量业务依赖，并维护大量 Map/List 派生状态。
   - `BookDetailPage` 在 `initState` 里组装 `ContentProviderRegistry`、来源切换 helper、缓存恢复、远程/本地加载分支。
   - `ReaderPage` 通过多个 `part` 文件承载自动阅读、进度保存、章节加载、分页、平台输入、音频、书签、来源切换等流程，拆分后仍共享一个 `_ReaderPageState`。
   - `SearchPage` 同时处理会员权限、搜索历史、进度节流、分页、搜索模式、来源过滤和 UI 渲染。

## 推荐引入的库/方案（按优先级排序）

| 优先级 | 所属层级 | 推荐方案 | 解决什么问题 | 替代我代码里的什么 |
|--------|---------|---------|-------------|------------------|
| P0 | UI/业务逻辑 | Feature facade/controller 边界 | 页面只负责渲染和交互分发，业务流程集中测试 | `BookshelfPage`、`BookDetailPage`、`ReaderPage`、`SearchPage` 内的 service 组装、加载分支、业务 if-else |
| P0 | 数据层 | Drift DAO/accessor 拆分 | 降低 `AppDatabase` 巨型类风险，按业务域隔离查询和迁移 | `lib/data/datasources/local/app_database.dart` 中大量 `get/upsert/watch/prune/maintenance` 方法 |
| P0 | 数据/业务逻辑 | 为阅读记录、章节缓存、书源健康、书架快照补 repository/DAO | 让 application 不直接依赖 `AppDatabase`，便于测试和替换存储 | `ReadingRecordService`、`ChapterCacheService`、`SourceHealthPersistenceService`、`BookshelfService` 直接持有数据库 |
| P0 | 基础设施 | 移除 `core -> data` 依赖，改为 app composition 注入 storage gateway | 修正依赖方向，避免基础设施知道具体数据库 | `AppCacheGovernanceService`、`StorageHealthService` 中的 `AppDatabase` 依赖 |
| P0 | UI/网络 | 书源 URL 导入移入 application service，并复用 `ApiClient`/受控 Dio | 消除 UI 直接网络调用，统一超时、日志、错误处理 | `private_book_source_form.dart` 中 `_loadRawImportFromUrl` 和 `Dio()` |
| P1 | 状态管理 | `riverpod_lint` + `custom_lint` | 自动发现 provider 滥用、UI 越界依赖、未监听/错误读取 | 目前只能靠人工和部分脚本发现的状态边界问题 |
| P1 | 状态管理 | `riverpod_generator` 或统一 Provider 命名模板 | 降低 provider 样板代码，强化作用域一致性 | 手写 provider/factory 的重复代码 |
| P1 | 业务/领域模型 | 更一致地使用 `freezed` + `json_serializable` | 减少手写 `copyWith/fromJson/toJson`、降低兼容分支错误 | `ReaderSettings`、`AppAdvancedTheme`、`ReaderDocument`、`BottomNavIconGallery` 等手写模型逻辑 |
| P1 | 基础设施 | `retry` 包或统一 Dio retry interceptor | 让网络重试策略声明化，减少 `ApiClient.request` 手写循环 | `ApiClient` 内的 attempts、delay、retryable 判断 |
| P1 | UI/路由 | `go_router_builder` typed routes | 减少字符串路由和参数解析错误 | 各 feature `routes.dart`、页面里 `context.go('/xxx')`、自研 route string guard |
| P2 | UI/表单 | 评估 `flutter_form_builder` | 高级主题、书源表单、设置页字段多，统一校验和字段状态 | 大量手写 `TextEditingController`、校验、错误文案、表单布局 |
| P2 | 基础设施/API | 评估 `retrofit.dart` | API 面继续扩大时生成 typed endpoint，减少手写 request spec | `ServerBookGatewayService`、`ServerOnlineSearchService`、`PrivateBookSourceService` 中重复 API 调用样板 |
| P2 | 缓存 | 评估 `stash` 或专门 cache adapter | 高频临时缓存与主业务表解耦，统一 TTL/LRU | `AppCacheStore`、部分搜索/分页/章节缓存的手写预算治理 |

## 不建议引入的库（及原因）

| 不建议引入 | 原因 |
|---|---|
| GetX | 项目已经以 Riverpod 为主，引入 GetX 会造成状态、路由、依赖注入三套心智模型并存，迁移收益低于治理成本 |
| Bloc/MobX 作为主状态框架 | 当前问题不是 Riverpod 不够，而是状态边界不统一。换框架会制造大迁移，不会自动拆掉巨型页面 |
| AutoRoute | 已经使用 GoRouter，并有路由治理脚本。更适合补 `go_router_builder`，不适合换路由栈 |
| Isar/ObjectBox 作为主数据库替代 | Drift + SQLite 已经有 34 个 schema version、大量迁移和测试。替换主库风险很高，收益不明确 |
| Hive 作为全量数据层替代 | 可作为小范围缓存评估，但不建议替换 Drift 主存储。项目需要关系查询、迁移、索引和跨端 SQLite 能力 |
| flutter_screenutil | 项目已有 `app/layout`、`AppSpacing`、`responsive_framework` 和自适应规范；再引入屏幕缩放库容易与现有 token 体系冲突 |
| 全量 UI 组件库替换现有设计系统 | 当前有大量自研主题 token、advanced theme、adaptive widgets。直接换组件库会破坏现有视觉和多端适配，应该先治理组件边界 |

## 建议的落地顺序

1. P0 先清跨层硬伤：移除 UI 直接 Dio、拆 `core -> data`、给高频数据库访问补 DAO/repository。
2. P0 同步拆最大页面：先从 `BookshelfPage` 开始，因为它已经超过架构护栏硬限制。
3. P1 固化自动化约束：把 import guard、large file guard、Riverpod lint 放入常规检查。
4. P1 再做模型与状态收口：优先 `AppAdvancedTheme`、`ReaderSettings`、搜索/阅读器页面状态。
5. P2 才评估新库：表单、typed route、typed API、专用缓存都应在边界清楚后引入。

## 本次产出的 MD 文档

- `docs/five_layer_architecture_diagnosis_2026-06-20.md`
