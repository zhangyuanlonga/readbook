# 项目功能地图

本文档基于代码结构自动梳理，用于帮助开发者或 AI 快速理解 Flutter 阅读 App 的业务模块。重点分析 `/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/`，并补充 `/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/core/` 与 `/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/` 的基础设施。

## 快速索引

| 关键词 | 功能模块 | 代码路径 |
|--------|----------|----------|
| 打卡 | 首页 | `/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/home/presentation/home_page.dart` → `_buildCheckInCard()` / `_handleCheckInToday()` |
| 每日目标 | 首页 | `/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/home/presentation/home_page.dart` → `_showGoalSettingsSheet()` |
| 继续阅读 | 首页 | `/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/home/presentation/home_page.dart` → `_buildContinueReadingSectionBlock()` / `_openRecord()` |
| 在线搜索 | 首页/搜索 | `/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/search/presentation/search_page.dart` → `_runSearch()` |
| 书架网格/列表 | 书架 | `/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/bookshelf/presentation/bookshelf_page.dart` → `_setBookshelfViewMode()` |
| 本地书导入 | 书架 | `/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/bookshelf/application/local_book_import_service.dart` → `importFromFile()` |
| 批量管理 | 书架 | `/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/bookshelf/presentation/bookshelf_page_selection.dart` → `_deleteSelectedBooks()` / `_applyCustomCoverToBook()` |
| 书籍详情 | 书架 | `/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/book/presentation/book_detail_page.dart` → `_load()` / `_handleStartReading()` |
| 主题编辑 | 高级主题 | `/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/advanced_theme_editor_page.dart` → `AdvancedThemeEditorPage` |
| 主题导入导出 | 高级主题 | `/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/application/advanced_theme_service.dart` → `encodeThemeBundleZip()` / `importThemeBundleZipFile()` |
| 阅读器入口 | 阅读器 | `/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/presentation/reader_page.dart` → `ReaderPage` |
| 阅读器翻页 | 阅读器 | `/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/presentation/reader_text_paged_view.dart` / `/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/presentation/paged_animation/` |
| 阅读设置 | 阅读器 | `/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/presentation/reader_page_settings_sheet.dart` → `_showSettingsSheet()` |
| 书签笔记 | 阅读器 | `/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/presentation/reader_page_selection.dart` → `_saveSelectionBookmark()` |
| WebDAV 同步 | 基础设施 | `/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/sync/application/sync_stage4_service.dart` → `run()` |
| 本地数据库 | 基础设施 | `/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/data/datasources/local/app_database.dart` → `AppDatabase` |

## 常用修改场景

### 我要改首页打卡样式
- UI：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/home/presentation/home_page.dart` 中的 `_buildCheckInCard()`、`_buildReadingSummarySection()`
- 逻辑：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/home/application/home_engagement_service.dart`
- 存储：SharedPreferences 键 `home.engagement.check_in_dates.v1`、`home.engagement.goal_minutes.v1`

### 我要改首页继续阅读卡片
- UI：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/home/presentation/home_page.dart` 中的 `_buildContinueReadingSectionBlock()`、`_buildContinueReadingCard()`
- 跳转：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/reader_entry_route_resolver.dart`
- 数据：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/reading_record_service.dart`

### 我要改书架网格/列表切换动画
- UI：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/bookshelf/presentation/bookshelf_page.dart` 中的 `_setBookshelfViewMode()`、`_buildBooksContentSliver()`
- 动画：`AppAnimatedSwitcher`、`AppFadeSlideTransition`、`_BookshelfAnimatedProgressSection`
- 存储：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/bookshelf/application/bookshelf_service.dart` 中的 `loadUseGridView()`、`saveUseGridView()`

### 我要改本地书导入流程
- UI：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/bookshelf/presentation/bookshelf_page_flow.dart` 中的 `_showImportLocalBooksSheet()`
- 逻辑：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/bookshelf/application/local_book_import_service.dart` 中的 `importFromFile()`
- 索引：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/local/local_book_index_service.dart`

### 我要改书籍详情页或开始阅读按钮
- UI：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/book/presentation/book_detail_page.dart`、`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/book/presentation/widgets/book_detail_primary_actions.dart`
- 详情加载：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/book/application/book_detail_service.dart`
- 阅读路由：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/book/application/book_detail_read_route_service.dart`

### 我要改高级主题编辑器的颜色或资源绑定
- UI：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/advanced_theme_editor_page.dart`
- 草稿/资源：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/application/advanced_theme_editor_state_service.dart`
- 持久化：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/application/advanced_theme_service.dart`

### 我要改阅读器翻页效果
- UI：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/presentation/reader_text_paged_view.dart`
- 动画：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/presentation/paged_animation/` 下的 `curl`、`cover`、`fade`、`translate`、`vertical` renderer
- 设置：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/presentation/reader_page_settings_sheet.dart` 中的 `ReaderPageAnimationStyle` 选项

### 我要改阅读器字体、背景或排版设置
- UI：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/presentation/reader_page_settings_sheet.dart`
- 存储：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/reader_preferences_service.dart`
- 渲染解析：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/reader_typography_resolver.dart`、`reader_layout_resolver.dart`

### 我要改书签/划线/笔记能力
- UI：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/presentation/reader_page_selection.dart`
- 仓储：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/data/repositories/bookmark_repository_impl.dart`
- 数据表：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/data/datasources/local/app_database.dart` 中的 `StoredBookmarks`

### 我要改 WebDAV 同步范围或同步策略
- UI：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/sync/presentation/pages/sync_settings_page.dart`
- 配置：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/sync/application/sync_profile_service.dart`
- 执行：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/sync/application/sync_stage4_service.dart`

## 1. 首页

### 阅读概览与打卡目标
- **业务描述**：用户进入首页后查看阅读概览、连续打卡和近期开启情况；可打开目标设置面板调整每日阅读目标分钟数，并执行今日打卡。
- **UI 位置**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/home/presentation/home_page.dart` + `HomePage`、`_buildReadingSummarySection()`、`_showGoalSettingsSheet()`
- **核心逻辑**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/home/application/home_engagement_service.dart` + `HomeEngagementService`、`HomeEngagementState`
- **关键方法**：`loadState()`、`checkInToday()`、`saveDailyGoalMinutes()`
- **数据存储**：SharedPreferences，键包括 `home.engagement.check_in_dates.v1`、`home.engagement.goal_minutes.v1`
- **交互细节**：首页使用 `AppFadeSlideTransition` 做分区渐入滑动；目标设置使用 `showAdaptiveActionSurface` 和 `Slider`。

### 继续阅读
- **业务描述**：用户在首页看到最近阅读记录，点击卡片继续打开对应书籍章节。
- **UI 位置**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/home/presentation/home_page.dart` + `_buildContinueReadingSectionBlock()`、`_buildContinueReadingCard()`、`_openRecord()`
- **核心逻辑**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/reading_record_service.dart` + `ReadingRecordService`；`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/reader_entry_route_resolver.dart` + `ReaderEntryRouteResolver`
- **关键方法**：`watchLatestRecords()`、`listLatestRecords()`、`_openRecord()`
- **数据存储**：SQLite/Drift，表 `reading_records`、`reading_record_days`、`reading_record_sessions`
- **交互细节**：继续阅读卡片使用封面组件 `ResolvedBookCover`；点击后通过 GoRouter 跳转阅读器。

### 排行预览
- **业务描述**：用户在首页查看热门/趋势等排行预览，用于发现可阅读内容或跳转详情。
- **UI 位置**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/home/presentation/home_page.dart` + `_buildRankingPreviewSection()`
- **核心逻辑**：当前主要在首页页面内组装展示；排行数据来源待分析。
- **关键方法**：`_buildRankingPreviewSection()`、`_buildSectionHeader()`、`_openRecord()`
- **数据存储**：待分析，代码中未看到独立排行持久化表。
- **交互细节**：使用 `AppAnimatedSwitcher`、`AppFadeSlideTransition` 切换排行维度和内容。

### 搜索入口与在线搜索
- **业务描述**：用户从底部 Dock、书架顶部或路由进入搜索页，输入关键词搜索小说/漫画，筛选服务器源，查看进度和结果，点击结果进入书籍详情。
- **UI 位置**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/search/presentation/search_page.dart` + `SearchPage`、`_buildSearchBar()`、`_runSearch()`；入口路由在 `/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/search/routes.dart`
- **核心逻辑**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/search/application/search_service.dart` + `SearchService`；`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/search/application/server_online_search_service.dart` + `ServerOnlineSearchService`；`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/search/application/search_report_assembler.dart`
- **关键方法**：`_runSearch()`、`search()`、`loadSourcePage()`
- **数据存储**：SharedPreferences 保存搜索历史和搜索设置；SQLite/Drift 表 `search_source_hits` 记录命中缓存；服务器接口用于在线搜索与源列表。
- **交互细节**：Dock 入口使用 `CircularThemeRevealOverlay`；搜索页对进度 UI 做 1500ms 节流，滚动时延迟刷新；返回动画按入口区分淡入缩放或零时长进入。

### 发现页占位
- **业务描述**：底部发现入口当前展示“服务器发现开发中”，客户端发现页暂不承载本地规则运行能力。
- **UI 位置**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/discover/routes.dart` + `discoverShellBranch`、`FeatureDisabledPage`
- **核心逻辑**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/widgets/feature_disabled_page.dart` + `FeatureDisabledPage`
- **关键方法**：待分析，当前为静态占位页面。
- **数据存储**：无。
- **交互细节**：无特殊动画。

## 2. 书架

### 书架列表/网格浏览
- **业务描述**：用户查看已加入的书籍，支持列表和网格视图、排序、筛选、分类/标签视图、搜索栏和进度显示。
- **UI 位置**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/bookshelf/presentation/bookshelf_page.dart` + `BookshelfPage`、`_buildBooksContent()`、`_setBookshelfViewMode()`；`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/bookshelf/presentation/widgets/bookshelf_grid_sliver.dart`
- **核心逻辑**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/bookshelf/application/bookshelf_service.dart` + `BookshelfService`
- **关键方法**：`getAll()`、`loadUseGridView()`、`saveSortMode()`
- **数据存储**：SQLite/Drift 表 `bookshelf_books`、`bookshelf_tag_assignments`、`bookshelf_tag_metadata`、`bookshelf_category_metadata`、`bookshelf_base_filter_orders`；部分视图偏好保存在 SharedPreferences。
- **交互细节**：列表/网格切换使用 `AppAnimatedSwitcher` 和前 24 个条目的 `AppFadeSlideTransition`；进度条使用 `_BookshelfAnimatedProgressSection`，完成时有 `HapticFeedback.mediumImpact()`。

### 加入/移除书架与书籍组织
- **业务描述**：用户在书籍详情或书架中添加/移除书籍，设置分类和标签，维护书架组织结构。
- **UI 位置**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/book/presentation/book_detail_page_actions.dart` + `_toggleBookshelf()`、`_openOrganizeSheet()`；`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/bookshelf/presentation/bookshelf_page_flow.dart`
- **核心逻辑**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/book/application/book_detail_action_service.dart` + `BookDetailActionService`；`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/bookshelf/application/bookshelf_service.dart` + `BookshelfService`
- **关键方法**：`toggleBookshelf()`、`saveOrganization()`、`setBookTags()`
- **数据存储**：SQLite/Drift 书架与标签/分类表；旧版 SharedPreferences 书架快照由 `BookshelfService` 迁移。
- **交互细节**：详情页主操作按钮按下有 `HapticFeedback.lightImpact()` 和 `AnimatedScale`；组织设置使用自适应底部面板。

### 本地书导入与索引
- **业务描述**：用户从本地选择 txt、epub、md、html、pdf、mobi、azw、azw3 等文件导入书架，系统保存文件、建立目录索引，并在可用时进入阅读。
- **UI 位置**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/bookshelf/presentation/bookshelf_page_flow.dart` + `_showImportLocalBooksSheet()`；`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/bookshelf/presentation/local_library_page.dart`
- **核心逻辑**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/bookshelf/application/local_book_import_service.dart` + `LocalBookImportService`；`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/local/local_book_index_service.dart` + `LocalBookIndexService`
- **关键方法**：`importFromFile()`、`ensureIndexed()`、`_warmUpLocalBookIndex()`
- **数据存储**：本地文件复制到应用托管目录；SQLite/Drift 表 `local_books`、`local_chapters` 和 `local_chapter_bodies`；书架表同步插入本地书条目。
- **交互细节**：导入进度通过 `LocalBookImportProgress` 回调和任务面板展示；大文件可异步预热索引。

### 书籍详情与目录
- **业务描述**：用户打开书籍详情查看封面、作者、简介、目录、最新章节、缓存状态，可刷新详情、打开目录、开始阅读、换源、分享。
- **UI 位置**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/book/presentation/book_detail_page.dart` + `BookDetailPage`、`_load()`、`_handleStartReading()`；`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/book/presentation/book_detail_page_catalog.dart` + `_openCatalogSheet()`
- **核心逻辑**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/book/application/book_detail_service.dart` + `BookDetailService`；`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/book/application/book_detail_catalog_service.dart`
- **关键方法**：`load()`、`_ensureCatalogLoaded()`、`_openChapter()`
- **数据存储**：详情和目录有内存 LRU/TTL 缓存；目录快照存入 SQLite/Drift 表 `toc_snapshots`；远程详情走服务器/接口，本地详情走本地库。
- **交互细节**：详情页路由使用 320ms fade-slide；封面/标题/作者支持 Hero；下拉刷新使用 `RefreshIndicator`；离场阅读有短延迟动画。

### 书籍元数据编辑与自定义封面
- **业务描述**：用户在书籍详情中编辑标题、作者、简介、封面；本地书还可调整字符集等本地高级信息。
- **UI 位置**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/book/presentation/book_detail_page_metadata.dart` + `_enterEditingMode()`、`_handleSaveMetadataEditing()`、`_pickEditableCoverPath()`
- **核心逻辑**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/book/application/book_metadata_edit_service.dart` + `BookMetadataEditService`；`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/book/application/custom_cover_storage_service.dart` + `CustomCoverStorageService`
- **关键方法**：`_saveRemoteBookMetadata()`、`_saveLocalBookMetadata()`、`_handleResetMetadataEditing()`
- **数据存储**：SQLite/Drift 表 `book_metadata_overrides`；本地书元数据表 `local_books`；自定义封面保存为本地托管文件。
- **交互细节**：编辑模式修改 AppBar 操作区；封面选择使用图片选择服务和自适应面板。

### 批量选择、删除与批量封面更新
- **业务描述**：用户长按或通过更多菜单进入批量模式，选择多本书后批量删除或批量应用自定义封面。
- **UI 位置**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/bookshelf/presentation/bookshelf_page_selection.dart` + `_toggleBookSelection()`、`_deleteSelectedBooks()`、`_updateSelectedBookCovers()`
- **核心逻辑**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/bookshelf/application/bookshelf_service.dart` + `remove()`；`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/book/application/custom_cover_storage_service.dart`
- **关键方法**：`_setSelectionEnabled()`、`_deleteSelectedBooks()`、`_applyCustomCoverToBook()`
- **数据存储**：SQLite/Drift 书架表、标签表、元数据覆盖表；封面本地文件。
- **交互细节**：书籍卡片按压有 `AnimatedScale` 和 `HapticFeedback.lightImpact()`；选择状态叠层用 `AnimatedContainer`。

## 3. 高级主题编辑器

### 高级主题创建/编辑
- **业务描述**：用户新建或编辑高级主题，分别配置浅色/深色模式颜色、壁纸、阅读背景、字体、封面图集、启动图、底部导航图标等。
- **UI 位置**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/advanced_theme_editor_page.dart` + `AdvancedThemeEditorPage`、`_parseColorsForMode()`、`_saveTheme()`；路由在 `/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/routes.dart`
- **核心逻辑**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/application/advanced_theme_editor_state_service.dart` + `AdvancedThemeEditorStateService`；`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/application/advanced_theme_service.dart` + `AdvancedThemeService`
- **关键方法**：`createDraft()`、`loadDraft()`、`saveTheme()`
- **数据存储**：主题索引优先写入应用文档目录 `index.json`；主题摘要和激活 ID 使用 SharedPreferences；资源文件通过 `ManagedAssetStore` 托管。
- **交互细节**：编辑器页面使用 `NoTransitionPage`；浅/深色通过 `TabController` 切换；颜色输入实时刷新预览 `ValueNotifier`。

### 颜色语义与强度调节
- **业务描述**：用户编辑主色、背景、卡片、文字、阴影、壁纸遮罩等语义颜色，并调整壁纸透明度、模糊、阴影强度。
- **UI 位置**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/advanced_theme_editor_page.dart` + `_pickColorForSlot()`、`_showColorPickerDialog()`、`_buildStrengthSliderRow()`
- **核心逻辑**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/theme/app_advanced_theme_tokens.dart` + `resolveAdvancedThemePalette()`、`resolveAdvancedThemeBackdrop()`；`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/application/theme_semantic_spec.dart`
- **关键方法**：`_parseColorsForMode()`、`_setWallpaperOpacity()`、`_setShadowIntensity()`
- **数据存储**：随 `AppAdvancedTheme` 的 light/dark config 持久化到主题索引。
- **交互细节**：颜色选择弹窗使用 `flutter_colorpicker`；强度滑杆有自定义 `SliderTheme`；部分区域用 `AnimatedCrossFade` 展开/收起。

### 外观资源联动
- **业务描述**：用户从背景库、阅读背景库、底部导航图库、封面图库、启动图图库和字体库中选择资源绑定到主题。
- **UI 位置**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/advanced_theme_editor_page.dart` + `_pickWallpaperFromBackgroundLibrary()`、`_pickReaderWallpaperFromBackgroundLibrary()`、`_pickBottomNavGallery()`、`_pickCoverGallery()`、`_pickLaunchImageGallery()`、`_pickThemeFont()`
- **核心逻辑**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/application/advanced_theme_editor_state_service.dart` + `loadAppearanceLinks()`、`applyWallpaper()`、`applyReaderWallpaper()`
- **关键方法**：`loadAppearanceLinks()`、`applyWallpaper()`、`applyReaderWallpaper()`
- **数据存储**：背景/阅读背景/封面/启动图/字体均存为本地托管文件或图库配置；图库配置主要由 SharedPreferences 和 `ManagedAssetStore` 维护。
- **交互细节**：资源选择统一使用 `showAdaptiveActionSurface`；图片长按可全屏预览。

### 主题列表、激活、复制、删除、导入导出
- **业务描述**：用户在高级主题列表中管理主题，激活某个主题，复制主题，删除主题及可选关联资源，或导入/导出主题压缩包。
- **UI 位置**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/advanced_theme_list_page.dart` + `AdvancedThemeListPage`；编辑入口 `/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/routes.dart`
- **核心逻辑**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/application/advanced_theme_service.dart` + `AdvancedThemeService`
- **关键方法**：`saveActiveThemeId()`、`duplicateTheme()`、`encodeThemeBundleZip()`、`importThemeBundleZipFile()`
- **数据存储**：SharedPreferences 保存 active theme id 和外观快照；主题包是 zip，内含 `manifest.json` 与资源文件；文件指纹用于防止重复导入。
- **交互细节**：激活主题会同步启动图快照并触发 `advancedThemeRevisionProvider`；删除时会判断资源是否仍被其他主题引用。

## 4. 阅读器

### 阅读器入口与会话加载
- **业务描述**：用户从书架、详情、继续阅读或书签进入阅读器；阅读器加载章节内容、恢复进度、处理本地/服务器内容源。
- **UI 位置**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/presentation/reader_page.dart` + `ReaderPage`；路由在 `/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/routes.dart`
- **核心逻辑**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/reader_dependencies_provider.dart` + `ReaderFeatureDependencies`；`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/reader_session_controller.dart` + `ReaderSessionController`
- **关键方法**：`_loadCurrentChapter()`、`beginIntent()`、`cancelAll()`
- **数据存储**：章节缓存、阅读进度和目录快照在 SQLite/Drift；阅读设置在 SharedPreferences；本地书内容在本地文件和 SQLite。
- **交互细节**：阅读器路由使用 220ms fade；任务 token 避免旧加载/分页任务覆盖新会话。

### 文本、漫画、音频与分页渲染
- **业务描述**：阅读器根据章节内容类型渲染文本、图片漫画或音频相关视图；文本可分页或连续滚动，漫画支持图片预加载。
- **UI 位置**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/presentation/reader_page_content_rendering.dart`、`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/presentation/reader_text_paged_view.dart`、`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/presentation/reader_manga_view.dart`、`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/presentation/reader_audio_view.dart`
- **核心逻辑**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/reader_pagination_engine.dart` + `ReaderPaginationEngine`；`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/text_reader_renderer.dart`；`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/reader_content_mode_resolver.dart`
- **关键方法**：`paginate()`、`_setContentFlow()`、`_scheduleInlineImagePrecache()`
- **数据存储**：分页缓存使用 `ReaderPaginationCacheService` 内存缓存；章节内容缓存使用 SQLite/Drift 表 `chapter_caches`。
- **交互细节**：翻页动画注册在 `/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/presentation/paged_animation/`，包含 curl、cover、fade、translate、vertical。

### 章节导航、目录与跳转
- **业务描述**：用户打开目录、搜索目录、跳转章节、前后章切换、漫画位置跳转、书签位置跳转。
- **UI 位置**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/presentation/reader_page_navigation.dart` + `_showCatalogSheet()`、`_jumpTo()`、`_executeNavigationRequest()`；目录 UI `/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/presentation/reader_catalog_sheet.dart`
- **核心逻辑**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/reader_chapter_navigation.dart`、`reader_jump_planner.dart`、`reader_catalog_search_service.dart`
- **关键方法**：`_ensureCatalogLoadedForOverlay()`、`_jumpToAdjacentReadableChapter()`、`_openMangaPositionSheet()`
- **数据存储**：目录快照 SQLite/Drift 表 `toc_snapshots`；进度表 `reading_progresses`。
- **交互细节**：目录/位置跳转使用 `showAdaptiveActionSurface`；漫画位置使用 `Slider` 显示百分比。

### 阅读设置与视觉定制
- **业务描述**：用户调整字号、行高、段距、边距、字体、亮度、主题模式、背景图、正文颜色/装饰、页眉页脚、漫画阅读方式、音量键翻页、自动阅读等。
- **UI 位置**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/presentation/reader_page_settings_sheet.dart` + `_showSettingsSheet()`；设置面板分组在 `/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/presentation/reader_page_settings_panel.dart`
- **核心逻辑**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/reader_preferences_service.dart` + `ReaderPreferencesService`；`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/reader_settings_resolution_service.dart`
- **关键方法**：`loadSettings()`、`_persistResolvedReaderSettingsLayers()`、`saveCustomBackgroundImages()`
- **数据存储**：SharedPreferences 保存大量 `reader.settings.*` 键；自定义背景通过本地文件/托管资源保存。
- **交互细节**：设置弹层使用 `showGeneralDialog`、透明遮罩和 `AppFadeSlideTransition`；滑杆交互时面板会临时降低透明度，草稿设置 220ms 防抖持久化。

### 书签、划线与笔记
- **业务描述**：用户在阅读器内选择文本，保存“灵感”书签，添加笔记，切换高亮、加粗、下划线和波浪线，也可复制选中文本。
- **UI 位置**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/presentation/reader_page_selection.dart` + `_showBookmarkToolbar()`、`_onSaveBookmarkPressed()`、`_onEditBookmarkNotePressed()`
- **核心逻辑**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/domain/repositories/bookmark_repository.dart` + `BookmarkRepository`；实现 `/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/data/repositories/bookmark_repository_impl.dart`
- **关键方法**：`_saveSelectionBookmark()`、`_toggleSelectionHighlight()`、`_refreshChapterBookmarks()`
- **数据存储**：SQLite/Drift 表 `bookmarks`
- **交互细节**：文本选择后显示浮动工具条；笔记编辑使用自适应面板；书签样式实时映射到段落范围。

### 章节缓存与预加载
- **业务描述**：阅读器根据当前章节预加载邻近章节，可手动缓存章节范围，并对当前章节是否来自缓存进行反馈。
- **UI 位置**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/presentation/chapter_cache_sheets.dart`；阅读器更多菜单在 `/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/presentation/reader_page.dart` + `_ReaderTopMoreAction.cacheChapter`
- **核心逻辑**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/reader_cached_chapter_store.dart` + `ReaderCachedChapterStore`；`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/reader_preload_controller.dart`
- **关键方法**：`_fetchChapterContentSnapshotFlow()`、`_loadAdjacentContinuousTextChapterFlow()`、`ReaderCachedChapterStore` 的缓存读写方法
- **数据存储**：SQLite/Drift 表 `chapter_caches`
- **交互细节**：缓存范围选择使用 `RangeSlider` 和自适应底部面板。

### 换源与阅读状态迁移
- **业务描述**：用户在阅读器或详情页手动搜索同名书籍的其他源，选择候选后迁移书架、进度、记录和目录位置。
- **UI 位置**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/presentation/reader_page_source_switch.dart` + `_showSwitchSourceSheet()`；详情页换源在 `/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/book/presentation/book_detail_page.dart` + `_handleSwitchSource()`
- **核心逻辑**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/reader_source_switch_coordinator.dart`；`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/source_switch_score_service.dart`；`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/search/application/search_service.dart`
- **关键方法**：`_loadSwitchSourceCandidatesProgressively()`、`_applySwitchSourceCandidate()`、`_syncReadingStateAfterSwitch()`
- **数据存储**：SQLite/Drift 书架、阅读进度、阅读记录、搜索命中表；SharedPreferences 保存部分换源评分设置（具体键待分析）。
- **交互细节**：候选列表渐进式更新；搜索可取消；候选排序结合命中数和评分。

### 阅读记录与统计
- **业务描述**：系统记录每次有效阅读会话，用户在统计页查看总时长、每日记录、分布、排行，并可删除、恢复、合并记录。
- **UI 位置**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/presentation/reading_records_page.dart` + `ReadingRecordsPage`
- **核心逻辑**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/reading_record_service.dart` + `ReadingRecordService`；统计聚合器在 `/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/reading_stats_*`
- **关键方法**：`commitSession()`、`getMergeCandidates()`、`mergeRecords()`
- **数据存储**：SQLite/Drift 表 `reading_records`、`reading_record_days`、`reading_record_sessions`
- **交互细节**：统计页使用 `AppFadeSlideTransition`；记录删除有快照恢复能力。

## 5. 基础设施

### 应用启动、主题与全局壳
- **业务描述**：应用启动时预热 SharedPreferences 中的主题、导航、字体、启动图和我的页面配置；构建 MaterialApp、响应式断点、全局主题和底部/侧边导航壳。
- **UI 位置**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/app.dart` + `App`；`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/shell_scaffold.dart` + `ShellScaffold`
- **核心逻辑**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/bootstrap.dart` + `bootstrap()`；`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/router.dart` + `appRouter`
- **关键方法**：`bootstrap()`、`_runDeferredBootstrapTasks()`、`resolveMinePageStartupLocation()`
- **数据存储**：SharedPreferences；托管文件路径迁移；启动图缓存。
- **交互细节**：底部 Tab 切换有 240ms slide/fade/scale；搜索入口使用 circular reveal；移动端键盘 inset 有稳定处理。

### 路由与导航
- **业务描述**：GoRouter 统一管理首页、书架、发现、统计、我的，以及搜索、详情、阅读器、同步、认证等独立路由。
- **UI 位置**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/router.dart` + `appRouter`
- **核心逻辑**：各模块 `routes.dart`：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/home/routes.dart`、`bookshelf/routes.dart`、`book/routes.dart`、`reader/routes.dart`、`mine/routes.dart`、`search/routes.dart`、`sync/routes.dart`、`auth/routes.dart`
- **关键方法**：`buildFadeTransitionPage()`、`buildFadeSlideTransitionPage()`、`buildReaderRoute()`
- **数据存储**：无直接存储；启动目的地由 Mine 偏好决定。
- **交互细节**：不同路由定义自定义过渡，详情页 fade-slide，阅读器 fade，搜索入口按来源调整 reverse 动画。

### Riverpod 依赖注入
- **业务描述**：通过 Provider 组合数据库、仓储、服务、运行时门面、认证事件流、阅读器依赖等。
- **UI 位置**：无直接 UI。
- **核心逻辑**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/composition/app_providers.dart`；`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/reader_dependencies_provider.dart`；`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/providers.dart`
- **关键方法**：`appDatabaseProvider`、`readerFeatureDependenciesFactoryProvider`、`advancedThemeEditorStateServiceProvider`
- **数据存储**：依赖注入本身不存储；服务内部连接 SQLite、SharedPreferences、本地文件、接口。
- **交互细节**：无。

### 本地数据库与仓储
- **业务描述**：统一持久化书架、本地书、章节缓存、书签、元数据覆盖、阅读进度、阅读统计、同步状态、搜索命中等数据。
- **UI 位置**：无直接 UI。
- **核心逻辑**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/data/datasources/local/app_database.dart` + `AppDatabase`；仓储在 `/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/data/repositories/`
- **关键方法**：`migration`、`listBookshelfBooks()`、`upsertReadingRecord()`、`insertReadingRecordSession()`
- **数据存储**：SQLite/Drift，当前 `schemaVersion = 32`
- **交互细节**：无；部分批量解析使用 `Isolate.run` 降低 UI 阻塞。

### SharedPreferences 偏好系统
- **业务描述**：保存主题、字体、导航、书架视图、首页打卡、阅读设置、搜索设置、Mine 页面可见性等轻量状态。
- **UI 位置**：无直接 UI。
- **核心逻辑**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/preferences/app_preferences_service.dart`；各业务服务如 `ReaderPreferencesService`、`BookshelfService`、`HomeEngagementService`
- **关键方法**：`loadThemeModeRaw()`、`saveFontSettings()`、`loadSettings()`
- **数据存储**：SharedPreferences
- **交互细节**：启动时通过各 Notifier 的 `prime()` 减少首帧异步闪动。

### 托管资源与本地文件
- **业务描述**：管理封面、背景、主题壁纸、字体、本地书等应用内资源，解决绝对路径、相对路径、迁移和跨平台文件能力差异。
- **UI 位置**：无直接 UI；被高级主题、封面图库、阅读背景、本地导入等页面调用。
- **核心逻辑**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/core/storage/managed_asset_store.dart` + `ManagedAssetStore`；`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/core/storage/managed_file_path_resolver.dart`
- **关键方法**：`persistBytes()`、`importFile()`、`relativizePersistedPath()`、`resolvePersistedPath()`
- **数据存储**：应用 documents/support 目录下的本地文件；路径引用保存到 SharedPreferences 或 SQLite。
- **交互细节**：无直接交互；启动时 `ManagedAssetPathMigrationService` 执行迁移。

### 服务器书源、搜索与内容网关
- **业务描述**：搜索、详情、目录、正文和换源统一走服务器书源/内容网关；历史旧脚本源数据由兼容 guard 拦截并提示用户重新加入服务器书源版本。
- **UI 位置**：搜索页、详情页、阅读器间接调用。
- **核心逻辑**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/search/application/server_online_search_service.dart` + `ServerOnlineSearchService`；`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/search/application/server_book_gateway_service.dart` + `ServerBookGatewayService`；`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/server_gateway_content_provider.dart` + `ServerGatewayContentProvider`；`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/removed_script_source_guard.dart`
- **关键方法**：`search()`、`loadDetail()`、`loadChapterContent()`、`isRemovedScriptSourceId()`
- **数据存储**：接口/服务器；源健康快照存 SQLite/Drift 表 `source_health_snapshots`
- **交互细节**：远程内容任务冲突和调度由 `RemoteContentTaskConflictService`、`RemoteContentTaskSchedulerService` 管理；换源候选可展示健康状态 badge。

### 认证、会员与用户资料
- **业务描述**：用户登录、保存会话、读取用户资料、同步会员权益和远程访问能力。
- **UI 位置**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/auth/presentation/auth_page.dart`、`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/auth/presentation/user_profile_page.dart`、`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/membership_center_page.dart`
- **核心逻辑**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/core/auth/auth_service.dart`、`auth_session_store.dart`、`auth_session_secret_store.dart`；`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/core/membership/membership_service.dart`
- **关键方法**：`getSession()`、`saveSession()`、`clear()`
- **数据存储**：访问/刷新 Token 存安全存储 `FlutterSecureAuthSessionSecretStore`；用户展示信息存 SharedPreferences；远程访问快照存 SQLite/Drift 表 `remote_access_snapshots`
- **交互细节**：登录事件通过 `AuthEventBus` 广播，启动/页面协调器监听。

### WebDAV 同步
- **业务描述**：用户配置 WebDAV 同步档案，选择同步范围，手动或自动同步阅读进度、书签、阅读状态、元数据、主题、阅读历史、书架集合和分类标签。
- **UI 位置**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/sync/presentation/pages/sync_settings_page.dart`、`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/sync/presentation/pages/sync_history_page.dart`
- **核心逻辑**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/sync/application/sync_profile_service.dart` + `SyncProfileService`；`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/sync/application/sync_stage4_service.dart` + `SyncStage4Service`
- **关键方法**：`saveProfile()`、`run()`、`_syncReadingProgress()`
- **数据存储**：SQLite/Drift 表 `sync_profiles`、`sync_scope_states`、`sync_jobs`、`sync_conflicts`；WebDAV 远端文件；密码存 `SyncSecretStore`
- **交互细节**：同步任务写入 job 状态，历史页可读取成功/失败记录；冲突模型已定义。

### 公告、反馈、错误中心与日志
- **业务描述**：应用展示公告，用户提交反馈，开发者查看错误中心和诊断日志。
- **UI 位置**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/announcement/presentation/announcement_list_page.dart`、`announcement_detail_page.dart`；`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/feedback_page.dart`；`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/error/presentation/error_center_page.dart`
- **核心逻辑**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/announcement/application/announcement_service.dart`；`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/core/feedback/feedback_service.dart`；`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/core/logging/app_logger.dart`
- **关键方法**：公告读取状态和反馈提交方法待分析；`AppLogger.instance`、`SourceLogStore.instance.restore()`
- **数据存储**：公告已读状态大概率为 SharedPreferences（具体键待分析）；反馈走接口；日志保存在本地 SourceLogStore/诊断导出文件。
- **交互细节**：启动公告由 `AppAnnouncementCoordinator` 和 `AppStartupCoordinator` 协调弹出。

### 平台能力、更新与移动端特性
- **业务描述**：根据平台判断是否支持原生 SQLite、托管文件、移动特性；启动时检查更新、设备心跳、外部导入。
- **UI 位置**：更新弹窗 `/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/core/app_update/app_update_dialog.dart`；外部导入任务层 `/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/widgets/import_export_task_overlay.dart`
- **核心逻辑**：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/platform/app_platform_capabilities.dart`；`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/lifecycle/app_lifecycle_coordinator.dart`；`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/core/app_update/app_update_service.dart`
- **关键方法**：`AppPlatformCapabilities.current()`、`AppLifecycleCoordinator()`、`AppStartupCoordinator()`
- **数据存储**：SharedPreferences、本地文件、接口，视具体服务而定。
- **交互细节**：全局任务队列通过 `AppTaskQueueSurface`、`AppTaskStatus` 展示导入/导出状态。
