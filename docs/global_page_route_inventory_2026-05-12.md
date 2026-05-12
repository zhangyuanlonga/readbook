# 全局页面与路由清单

更新时间：2026-05-12  
用途：从 `GoRouter` 和各 feature `routes.dart` 出发，建立全局页面索引，明确每个页面的入口、能力边界、首屏优先级和懒加载策略。  
关联文档：

- `docs/page_function_multiplatform_methods_2026-05-12.md`
- `docs/page_ui_multiplatform_display_plan_2026-05-12.md`
- `docs/startup_init_cleanup_execution_plan_2026-05-12.md`
- `docs/books_core_performance_plan.md`
- `docs/global_page_lazy_loading_execution_plan_2026-05-12.md`

## 0. 总体结论

当前项目页面可以按四层管理：

| 层级 | 页面范围 | 加载策略 | 说明 |
| --- | --- | --- | --- |
| Core Shell | `/home`、`/bookshelf`、`/stats`、`/mine` | 高频入口，优先保证本地快照和基础数据 | 不应在首屏初始化书源、同步、图库扫描、复杂管理页数据 |
| Core On-demand | 书籍详情、阅读器、本地书库、书签、基础外观 | 用户进入时加载 | 允许页面级数据加载，但要可取消、可降级 |
| Management On-demand | 主题、图集、缓存、错误、反馈、会员、字体 | 低频页面，进入后加载 | 不参与启动和主 Tab 初始化 |
| Feature-gated | 发现、在线搜索、书源、WebDAV 同步 | capability 开启后可用，否则 disabled | 不支持时只展示统一占位，不创建重依赖 |

一句话原则：

**全局路由可以保留，但页面初始化必须核心优先；低频功能和能力受限功能只在用户明确进入后加载。**

## 1. 路由入口结构

全局路由入口在 `lib/app/router.dart`：

| 入口 | 说明 |
| --- | --- |
| `/` | 启动重定向，默认由 `resolveMinePageStartupLocation()` 返回 `/home` 或 `/bookshelf` |
| `StatefulShellRoute.indexedStack` | 主导航容器，包含首页、书架、发现、统计、我的 |
| standalone routes | 由 `mineRoutes`、`sourceRoutes`、`syncRoutes`、`searchRoutes`、`bookshelfRoutes`、`bookRoutes`、`readerRoutes` 等补充 |

主导航由 `lib/app/shell_navigation_provider.dart` 定义：

| Tab | 路由 | 默认状态 | 页面 | 优先级 |
| --- | --- | --- | --- | --- |
| 首页 | `/home` | 显示 | `HomePage` | Core Shell |
| 书架 | `/bookshelf` | 显示 | `BookshelfPage` | Core Shell |
| 发现 | `/discover` | 默认隐藏，依赖 `supportsSourceRuntime` | `DiscoverPage` 或 `FeatureDisabledPage` | Feature-gated |
| 统计 | `/stats` | 显示 | `ReadingRecordsPage` | Core Shell |
| 我的 | `/mine` | 固定显示 | `MinePage` | Core Shell |

## 2. 全局路由清单

### 2.1 Shell 页面

| 路由 | name | 页面/结果 | 来源 | 加载策略 | 能力边界 |
| --- | --- | --- | --- | --- | --- |
| `/home` | `home` | `HomePage` | `features/home/routes.dart` | Core Shell | 本地阅读记录、继续阅读、统计快照优先 |
| `/bookshelf` | `bookshelf` | `BookshelfPage` | `features/bookshelf/routes.dart` | Core Shell | 本地书架优先；在线刷新、书源能力后置 |
| `/discover` | `discover` | `DiscoverPage` / `FeatureDisabledPage` | `features/discover/routes.dart` | Feature-gated | 依赖 `supportsSourceRuntime` |
| `/stats` | `stats` | `ReadingRecordsPage` | `features/reader/routes.dart` | Core Shell | 阅读记录和统计查询，首版本地优先 |
| `/mine` | `mine` | `MinePage` | `features/mine/routes.dart` | Core Shell | 只展示入口和缓存快照，不初始化所有管理功能 |

### 2.2 书架与书籍

| 路由 | name | 页面/结果 | 来源 | 加载策略 | 能力边界 |
| --- | --- | --- | --- | --- | --- |
| `/local-library` | `local-library` | `LocalLibraryPage` | `features/bookshelf/routes.dart` | Core On-demand | 依赖本地文件导入、托管存储能力 |
| `/local/book/:bookId` | `local-book` | 重定向到 `/book/:bookId` 并补本地 query | `features/bookshelf/routes.dart` | Redirect | 本地图书详情别名 |
| `/book/:bookId` | `book` | `BookDetailPage` / `FeatureDisabledPage` | `features/book/routes.dart` | Core On-demand | 在线 sourceId 且书源关闭时禁用 |

书架页面内部还有导入、排序、筛选、选择、封面编辑等流程，属于页面内功能，不应继续新增全局路由，除非需要深链。

### 2.3 阅读器与记录

| 路由 | name | 页面/结果 | 来源 | 加载策略 | 能力边界 |
| --- | --- | --- | --- | --- | --- |
| `/read-records` | `read-records` | 重定向到 `/stats` | `features/reader/routes.dart` | Redirect | 历史兼容入口 |
| `/local/reader/:bookId/:chapterId` | `local-reader` | 重定向到 `/reader/:bookId/:chapterId` 并补本地 query | `features/reader/routes.dart` | Redirect | 本地阅读别名 |
| `/reader/:bookId/:chapterId` | `reader` | `ReaderPage` / `FeatureDisabledPage` | `features/reader/routes.dart` | Core On-demand | 在线章节依赖 `supportsSourceRuntime`；本地章节优先 |

阅读器是高价值页面，但不应在 App 启动或主 Tab 初始化时创建。只在明确打开章节时初始化阅读内容、分页、图片和设置。

### 2.4 搜索、发现、书源

| 路由 | name | 页面/结果 | 来源 | 加载策略 | 能力边界 |
| --- | --- | --- | --- | --- | --- |
| `/search` | `search` | `SearchPage` / `FeatureDisabledPage` | `features/search/routes.dart` | Feature-gated | 依赖 `supportsSourceRuntime` |
| `/source` | `source` | `SourcePage` / `FeatureDisabledPage` | `features/source/routes.dart` | Feature-gated | 依赖 `supportsSourceRuntime` |
| `/source/login` | `script-source-login` | `SourceLoginPage` / `FeatureDisabledPage` | `features/source/routes.dart` | Feature-gated | 依赖书源运行时和登录能力 |
| `/source/web-login` | `script-source-web-login` | `SourceWebLoginPage` / `FeatureDisabledPage` | `features/source/routes.dart` | Feature-gated | 依赖交互式 WebView |
| `/source/script-editor` | `script-source-editor` | `ScriptSourceEditorPage` / `FeatureDisabledPage` | `features/source/routes.dart` | Feature-gated | 首版延期 |
| `/source/paste-import` | `script-source-paste-import` | `ScriptSourcePasteImportPage` / `FeatureDisabledPage` | `features/source/routes.dart` | Feature-gated | 首版延期 |

这组页面首版应保持路由可达但能力关闭时轻量占位。不要在 router import 之外再让 shell、首页、书架主动初始化书源数据。

### 2.5 同步

| 路由 | name | 页面/结果 | 来源 | 加载策略 | 能力边界 |
| --- | --- | --- | --- | --- | --- |
| `/sync` | `sync` | `SyncSettingsPage` / `FeatureDisabledPage` | `features/sync/routes.dart` | Feature-gated | 依赖 `supportsWebDavSync` |
| `/sync/history` | `sync-history` | `SyncHistoryPage` / `FeatureDisabledPage` | `features/sync/routes.dart` | Feature-gated | 依赖 `supportsWebDavSync` |

同步属于 P1+ 独立能力，默认不参与首版验收。入口可以保留，但只在用户进入同步页面时加载同步配置和历史。

### 2.6 公告与账号

| 路由 | name | 页面/结果 | 来源 | 加载策略 | 能力边界 |
| --- | --- | --- | --- | --- | --- |
| `/announcements` | `announcements` | `AnnouncementListPage` | `features/announcement/routes.dart` | Management On-demand | 进入公告页后加载 |
| `/announcements/:id` | `announcement-detail` | `AnnouncementDetailPage` | `features/announcement/routes.dart` | Management On-demand | 按 id 加载详情 |
| `/auth` | `auth` | `AuthPage` | `features/auth/routes.dart` | Core On-demand | 登录页按需打开 |
| `/profile` | `profile` | `UserProfilePage` | `features/auth/routes.dart` | Core On-demand | 个人资料按需加载 |

公告、登录、资料不应阻塞首屏。启动公告已经走 deferred 策略，列表页仍应用户进入后加载。

### 2.7 我的与设置

| 路由 | name | 页面/结果 | 来源 | 加载策略 | 能力边界 |
| --- | --- | --- | --- | --- | --- |
| `/appearance` | `appearance` | `AppearancePage` | `features/mine/routes.dart` | Core On-demand | query `section=appearance/tab-bar/cover/background` |
| `/appearance/reader-background` | `reader-background` | `ReaderBackgroundPage` | `features/mine/routes.dart` | Management On-demand | 阅读背景资源按需加载 |
| `/appearance/launch-image` | `launch-image` | `LaunchImageGalleryPage` | `features/mine/routes.dart` | Management On-demand | 启动图集按需加载 |
| `/appearance/launch-image/editor` | `launch-image-editor` | `LaunchImageGalleryEditorPage` | `features/mine/routes.dart` | Management On-demand | query `id`，编辑器按需加载 |
| `/appearance/advanced-themes` | `advanced-themes` | `AdvancedThemeListPage` | `features/mine/routes.dart` | Management On-demand | 高级主题列表按需加载 |
| `/appearance/advanced-themes/editor` | `advanced-theme-editor` | `AdvancedThemeEditorPage` | `features/mine/routes.dart` | Management On-demand | query `id`，编辑器按需加载 |
| `/bottom-nav-icon-galleries` | `bottom-nav-icon-galleries` | `BottomNavIconGalleryPage` | `features/mine/routes.dart` | Management On-demand | 底栏图标库按需加载 |
| `/bottom-nav-icon-galleries/editor` | `bottom-nav-icon-gallery-editor` | `BottomNavIconGalleryEditorPage` | `features/mine/routes.dart` | Management On-demand | query `id`，编辑器按需加载 |
| `/cover-galleries` | `cover-galleries` | `CoverGalleryPage` | `features/mine/routes.dart` | Management On-demand | 封面图库按需加载 |
| `/cover-galleries/editor` | `cover-gallery-editor` | `CoverGalleryEditorPage` | `features/mine/routes.dart` | Management On-demand | query `id`，编辑器按需加载 |
| `/cache` | `cache` | `CacheManagementPage` | `features/mine/routes.dart` | Management On-demand | 只在进入页面后扫描/统计缓存 |
| `/mine/tags` | `mine-tags` | `MineManagementPage(tagManagement)` | `features/mine/routes.dart` | Core On-demand | 书架数据标题下的标签管理 |
| `/mine/categories` | `mine-categories` | `MineManagementPage(categoryManagement)` | `features/mine/routes.dart` | Core On-demand | 书架数据标题下的分类管理 |
| `/membership` | `membership` | `MembershipCenterPage` | `features/mine/routes.dart` | Management On-demand | 进入后刷新权益 |
| `/about` | `about` | `AboutPage` | `features/mine/routes.dart` | Management On-demand | 静态信息优先 |
| `/system-settings` | `system-settings` | `SystemSettingsPage` | `features/mine/routes.dart` | Management On-demand | 系统设置入口已不在我的页展示时仍保留路由 |
| `/font-management` | `font-management` | `FontManagementPage` | `features/mine/routes.dart` | Core On-demand | 字体资源按需加载 |
| `/bookmarks` | `bookmarks` | `BookmarksPage` | `features/mine/routes.dart` | Core On-demand | 书签查询按需加载 |
| `/error-center` | `error-center` | `ErrorCenterPage` | `features/mine/routes.dart` | Management On-demand | 进入后加载错误记录 |
| `/feedback` | `feedback` | `FeedbackPage` | `features/mine/routes.dart` | Management On-demand | 反馈列表按需加载 |
| `/feedback/:id` | `feedback-detail` | `FeedbackDetailPage` | `features/mine/routes.dart` | Management On-demand | 按 id 加载反馈详情 |
| `/feedback/compose` | `feedback-compose` | `FeedbackComposePage` | `features/mine/routes.dart` | Management On-demand | 编辑态按需加载 |

我的页是入口聚合页，不应在自身初始化时创建上述管理页的服务链。进入具体页面后再加载对应资源。

## 3. 非 GoRouter 页面与嵌入页面

以下页面通过 `MaterialPageRoute`、嵌入式 sheet 或私有页面打开，不属于全局深链路由，但需要在全局文档中记录：

| 页面 | 触发位置 | 当前形态 | 建议 |
| --- | --- | --- | --- |
| `SourceLoginPage(embedded: true)` | `SourcePage` 登录入口 | bottom sheet 内嵌 | 继续保持嵌入，不进首屏 |
| `SourceWebLoginPage` | `SourcePage` 非 router 导航分支 | `MaterialPageRoute` | 如需深链统一走 `/source/web-login` |
| `ScriptSourceDebugPage` | `SourcePage`、`ScriptSourceEditorPage` | `MaterialPageRoute` | 书源专题内保留，首版能力关闭时不可触发 |
| `_BookmarkBookDetailPage` | `BookmarksPage` 内部书籍分组详情 | 私有 `MaterialPageRoute` | 属于书签页内部详情，不需要全局路由 |

这类页面的共同规则：不参与启动，不参与主导航初始化，只有用户明确操作后创建。

## 4. 页面懒加载策略

执行状态：

- 2026-05-12：Phase 0、Phase 1 已完成，页面加载分级进入架构约束，Core Shell 首屏只加载基础快照。
- 2026-05-12：Phase 2、Phase 3 已完成，书架链路分成基础列表、首屏后补齐、低优先级后台刷新；阅读器重资源 warmup 改为正文可见后触发。

### 4.1 Core Shell

目标：

- Shell 只创建当前可见 branch 的必要 UI。
- 首页、书架、统计、我的只加载基础本地快照。
- 不在 shell 初始化书源、同步、主题图库、缓存统计、反馈、公告列表。

重点页面：

- `HomePage`：继续阅读、阅读统计、目标数据优先本地 service。
- `BookshelfPage`：基础书架列表优先；标签、分类、最新章节、封面补充和后台刷新后置。
- `ReadingRecordsPage`：统计查询按页面可见时进行，避免启动阶段主动查询重数据。
- `MinePage`：只读会员/模块快照和入口配置，不预加载管理页面。

### 4.2 Core On-demand

目标：

- 页面打开后再加载业务数据。
- 文件、图片、数据库查询必须经 service/provider，不在页面散落平台判断。
- 能力不支持时显示统一 disabled 或禁用按钮。

重点页面：

- `BookDetailPage`：本地图书详情可用；在线详情走书源 capability。
- `ReaderPage`：本地章节优先；在线章节能力关闭时不创建 source 读取链。
- `LocalLibraryPage`：导入、重索引、删除资源均走本地书库 service。
- `BookmarksPage`：进入后查询书签，不在我的页预查询。

### 4.3 Management On-demand

目标：

- 所有低频管理页面只在进入页面后加载。
- 大图、图集、缓存统计、错误记录、反馈列表禁止出现在启动链。
- 编辑器页面不应该被列表页提前创建。

重点页面：

- 高级主题、启动图集、封面图库、底栏图标库。
- 缓存管理、错误中心、反馈、会员中心。
- 字体管理和阅读背景管理。

### 4.4 Feature-gated

目标：

- 保留路由，能力关闭时只展示轻量 `FeatureDisabledPage`。
- 不支持平台不得创建真实业务页面和重依赖。
- 书源和同步通过 `AppPlatformCapabilities` 控制，不在页面散点判断。

重点页面：

- `DiscoverPage`、`SearchPage`、`SourcePage`、书源登录/编辑/导入。
- `SyncSettingsPage`、`SyncHistoryPage`。

## 5. 后续拆分建议

阶段任务已拆到 `docs/global_page_lazy_loading_execution_plan_2026-05-12.md`。本文只保留页面清单和维护规则。

| 优先级 | 任务 | 说明 |
| --- | --- | --- |
| P0 | 建立页面路由登记规则 | 新增 `GoRoute` 必须补本文档 |
| P0 | 书架首屏拆成基础加载和后台补充加载 | 对齐“核心功能优先，其他功能懒加载” |
| P0 | MinePage 只保留入口和快照 | 管理页服务进入页面后再初始化 |
| P1 | Router import 分层评估 | 先按业务懒初始化，不急于全平台 deferred import |
| P1 | FeatureDisabled 文案与能力映射统一 | search/source/sync/discover 使用同一降级模型 |
| P1 | 非 GoRouter 页面是否需要深链 | 仅对需要外部进入或恢复状态的页面补路由 |

## 6. 维护规则

新增或调整页面时必须同步更新：

1. 本文的路由表。
2. `docs/page_function_multiplatform_methods_2026-05-12.md` 的功能兼容状态。
3. `docs/page_ui_multiplatform_display_plan_2026-05-12.md` 的多端展示状态。
4. 如果页面进入启动链或主 Tab 初始化链，需要同步更新 `docs/startup_init_cleanup_execution_plan_2026-05-12.md`。

页面新增 checklist：

- [ ] 是否属于 Core Shell、Core On-demand、Management On-demand 或 Feature-gated。
- [ ] 是否需要 capability 控制。
- [ ] 不支持平台是否有 disabled/隐藏/降级策略。
- [ ] 页面是否在用户进入前创建了重服务、网络请求、图片扫描或数据库全量查询。
- [ ] 是否需要 Web、桌面和移动端不同 UI 展示。
- [ ] 是否需要深链；不需要则优先使用页面内部 sheet/dialog。

## 7. 本次盘点来源

- `lib/app/router.dart`
- `lib/app/shell_navigation_provider.dart`
- `lib/features/home/routes.dart`
- `lib/features/bookshelf/routes.dart`
- `lib/features/book/routes.dart`
- `lib/features/reader/routes.dart`
- `lib/features/search/routes.dart`
- `lib/features/discover/routes.dart`
- `lib/features/source/routes.dart`
- `lib/features/sync/routes.dart`
- `lib/features/announcement/routes.dart`
- `lib/features/auth/routes.dart`
- `lib/features/mine/routes.dart`
- `rg "MaterialPageRoute|context.push|context.go"` 对非全局页面入口的补充扫描
