# A8 老页面分批迁移清单

更新时间：2026-05-13  
来源：`docs/global_page_route_inventory_2026-05-12.md`、`docs/page_ui_multiplatform_display_plan_2026-05-12.md`、`tool/check_ui_component_governance.dart`

## 0. 口径

“老页面”不是指一定代码质量差，而是指尚未完全按当前自适应体系收口的页面。判断维度：

- 页面骨架是否使用 `AdaptivePageScaffold` 或有明确例外。
- 内容宽度是否有 compact / medium / expanded 策略。
- 空、加载、错误、禁用、任务态是否复用基线组件。
- 弹层是否走 adaptive surface，而不是移动端 bottom sheet 原样套到桌面/Web。
- 是否在页面层散落平台判断、同步文件读取、大列表 `children` 或自定义重复列表项。

## 1. 迁移批次

| 批次 | 范围 | 迁移策略 |
| --- | --- | --- |
| A8-B1 | 书架、阅读器、首页、我的、搜索/发现入口 | 先做样板，优先处理骨架、宽屏布局、弹层、任务态 |
| A8-B2 | 书籍详情、本地书库、统计、书签、外观基础页 | 保持业务不动，迁 UI 基线和状态组件 |
| A8-B3 | 资源管理页：缓存、图集、字体、主题、启动图、底栏图标 | 结合 A6 懒加载和 A5 任务态迁移 |
| A8-B4 | 反馈、公告、账号、会员、错误中心、关于 | 低频页面按改动机会迁移 |
| A8-B5 | 书源、同步、WebView 登录等 capability-gated 页面 | 等 A4 三态 capability 后迁移 |

## 2. Shell 与核心页面

| 路由/入口 | 页面 | 批次 | 风险 | 首个迁移动作 | 验收重点 |
| --- | --- | --- | --- | --- | --- |
| `/home` | `HomePage` | A8-B1 | 中 | 检查骨架、空/加载态、卡片宽度 | 360、390、600、1280；大字体 |
| `/bookshelf` | `BookshelfPage` | A8-B1 | 高 | 书架工具栏、排序/导入弹层、任务态样板 | 桌面/Web 不用移动端置灰控件；导入可用 |
| `/discover` | `DiscoverPage` / `FeatureDisabledPage` | A8-B5 | 中 | A4 后接三态 capability | 关闭时轻量占位，不加载书源重依赖 |
| `/stats` | `ReadingRecordsPage` | A8-B2 | 中 | 统计卡片宽度、列表/图表状态组件 | 横屏、大字体、桌面宽屏 |
| `/mine` | `MinePage` | A8-B1 | 高 | 入口分组、系统入口删减后审计、宽屏分栏 | 管理入口不预加载；桌面密度合理 |

## 3. 书架与书籍链路

| 路由/入口 | 页面 | 批次 | 风险 | 首个迁移动作 | 验收重点 |
| --- | --- | --- | --- | --- | --- |
| `/local-library` | `LocalLibraryPage` | A8-B2 | 高 | 本地导入任务态、列表 builder、空状态 | 大批量本地书、导入失败/取消 |
| `/local/book/:bookId` | redirect | A8-B2 | 低 | 保持 redirect，确认无重页面创建 | 本地详情别名 |
| `/book/:bookId` | `BookDetailPage` | A8-B2 | 高 | 详情宽屏布局、封面/操作栏、禁用态 | 本地/在线 capability 分支 |
| 书架内部导入 | bottom sheet / task surface | A8-B1 | 高 | 接 A5 统一任务态 | 移动底部面板，桌面居中/侧面板 |
| 书架排序/筛选 | sheet / toolbar | A8-B1 | 中 | 替换移动端原样控件 | 桌面工具栏可点、非置灰 |

## 4. 阅读器与记录

| 路由/入口 | 页面 | 批次 | 风险 | 首个迁移动作 | 验收重点 |
| --- | --- | --- | --- | --- | --- |
| `/reader/:bookId/:chapterId` | `ReaderPage` | A8-B1 + A3 | 高 | 引入 `ReaderLayoutContext`，独立弹层策略 | 文字/漫画宽度不同；键盘鼠标；横屏 |
| `/local/reader/:bookId/:chapterId` | redirect | A8-B1 | 低 | 保持 redirect | 本地阅读别名 |
| `/read-records` | redirect `/stats` | A8-B2 | 低 | 保持 redirect | 历史入口 |
| 阅读器目录 | 内嵌面板/sheet | A8-B1 + A3 | 高 | 移动半屏，桌面侧面板 | 不阻断阅读，不遮挡正文 |
| 阅读器设置 | 内嵌面板/sheet | A8-B1 + A3 | 高 | 接尺寸 token 和 reader sizes | 字号、行高、分页一致 |

## 5. 搜索、发现、书源

| 路由/入口 | 页面 | 批次 | 风险 | 首个迁移动作 | 验收重点 |
| --- | --- | --- | --- | --- | --- |
| `/search` | `SearchPage` / `FeatureDisabledPage` | A8-B1/A8-B5 | 高 | source runtime 关闭时轻量占位；开启后审计列表/弹层 | Web/桌面 capability |
| `/source` | `SourcePage` / `FeatureDisabledPage` | A8-B5 | 高 | 等 A4 三态 capability | 首版关闭不创建 source 运行时 |
| `/source/login` | `SourceLoginPage` | A8-B5 | 高 | capability 三态后迁移 | WebView/登录能力不足降级 |
| `/source/web-login` | `SourceWebLoginPage` | A8-B5 | 高 | capability 三态后迁移 | 交互式 WebView |
| `/source/script-editor` | `ScriptSourceEditorPage` | A8-B5 | 高 | 书源专题恢复时再迁 | 低频重依赖 |
| `/source/paste-import` | `ScriptSourcePasteImportPage` | A8-B5 | 高 | 书源导入接任务态 | 首版排除在线书源 |

## 6. 同步

| 路由/入口 | 页面 | 批次 | 风险 | 首个迁移动作 | 验收重点 |
| --- | --- | --- | --- | --- | --- |
| `/sync` | `SyncSettingsPage` / `FeatureDisabledPage` | A8-B5 | 高 | A4 后三态 capability，设置项基线化 | WebDAV 不可用/需配置 |
| `/sync/history` | `SyncHistoryPage` / `FeatureDisabledPage` | A8-B5 | 中 | 历史列表状态组件 | 空、错误、加载 |

## 7. 我的与设置/资源管理

| 路由/入口 | 页面 | 批次 | 风险 | 首个迁移动作 | 验收重点 |
| --- | --- | --- | --- | --- | --- |
| `/appearance` | `AppearancePage` | A8-B2 | 高 | 设置项、字体/背景按需加载 | section 切换不预加载全部资源 |
| `/appearance/reader-background` | `ReaderBackgroundPage` | A8-B3 | 中 | 资源列表懒加载 | 大图库 |
| `/appearance/launch-image` | `LaunchImageGalleryPage` | A8-B3 | 中 | 轻量图库 index | 启动图预览可见项加载 |
| `/appearance/launch-image/editor` | `LaunchImageGalleryEditorPage` | A8-B3 | 高 | 编辑器详情加载完整图集 | 大量图片不阻塞 |
| `/appearance/advanced-themes` | `AdvancedThemeListPage` | A8-B3 | 中 | 导入/导出任务态 | 主题资源懒加载 |
| `/appearance/advanced-themes/editor` | `AdvancedThemeEditorPage` | A8-B3 | 高 | 设置项和资源 picker 基线化 | 桌面弹层 |
| `/bottom-nav-icon-galleries` | `BottomNavIconGalleryPage` | A8-B3 | 中 | 轻量 index + 任务态 | 图标包很多 |
| `/bottom-nav-icon-galleries/editor` | `BottomNavIconGalleryEditorPage` | A8-B3 | 高 | 编辑器详情加载 | 图片 metadata 延迟 |
| `/cover-galleries` | `CoverGalleryPage` | A8-B3 | 中 | 轻量 index + 可见项图片 | 大图库 |
| `/cover-galleries/editor` | `CoverGalleryEditorPage` | A8-B3 | 高 | 编辑器完整资源延迟 | 大量封面 |
| `/cache` | `CacheManagementPage` | A8-B3 | 高 | 分类刷新，扫描进任务管理 | 不进入页面即全量扫描 |
| `/mine/tags` | `MineManagementPage(tagManagement)` | A8-B2 | 中 | 设置/列表基线化 | 大量标签 |
| `/mine/categories` | `MineManagementPage(categoryManagement)` | A8-B2 | 中 | 设置/列表基线化 | 大量分类 |
| `/font-management` | `FontManagementPage` | A8-B3 | 高 | 字体 metadata 展开加载 | 大字体库 |
| `/bookmarks` | `BookmarksPage` | A8-B2 | 中 | 列表/空状态/详情路由审计 | 大量书签 |

## 8. 账号、公告、反馈和低频页面

| 路由/入口 | 页面 | 批次 | 风险 | 首个迁移动作 | 验收重点 |
| --- | --- | --- | --- | --- | --- |
| `/announcements` | `AnnouncementListPage` | A8-B4 | 中 | 列表状态和宽屏内容宽度 | 空、错误、加载 |
| `/announcements/:id` | `AnnouncementDetailPage` | A8-B4 | 中 | 正文最大宽度 | 长文、大字体 |
| `/auth` | `AuthPage` | A8-B4 | 中 | 表单宽度和键盘 inset | 桌面/Web |
| `/profile` | `UserProfilePage` | A8-B4 | 中 | 设置项基线化 | 账号状态 |
| `/membership` | `MembershipCenterPage` | A8-B4 | 中 | 卡片宽度和状态组件 | 大屏密度 |
| `/about` | `AboutPage` | A8-B4 | 低 | 内容宽度 token | 静态内容 |
| `/system-settings` | `SystemSettingsPage` | A8-B4 | 中 | 入口已隐藏，保留路由审计 | 可达但低频 |
| `/error-center` | `ErrorCenterPage` | A8-B4 | 中 | 导出任务态、列表状态 | 日志导出 |
| `/feedback` | `FeedbackPage` | A8-B4 | 中 | 列表状态和弹层 | 空、错误、加载 |
| `/feedback/:id` | `FeedbackDetailPage` | A8-B4 | 中 | 详情内容宽度 | 长内容 |
| `/feedback/compose` | `FeedbackComposePage` | A8-B4 | 中 | 表单、附件、键盘 inset | 移动/桌面输入 |

## 9. 非 GoRouter 内嵌页面

| 页面 | 触发位置 | 批次 | 首个迁移动作 |
| --- | --- | --- | --- |
| `SourceLoginPage(embedded: true)` | `SourcePage` 登录入口 | A8-B5 | A4 后确认 embedded 与全局路由共用三态 capability |
| `SourceWebLoginPage` | `SourcePage` 非 router 分支 | A8-B5 | 统一 deep link 或保持内部导航但写例外 |
| `ScriptSourceDebugPage` | `SourcePage`、`ScriptSourceEditorPage` | A8-B5 | 书源专题恢复时审计 |
| `_BookmarkBookDetailPage` | `BookmarksPage` 内部书籍分组详情 | A8-B2 | 保留内部详情，补宽屏和状态组件 |

## 10. 执行规则

- 每次迁移前先从本清单挑一个批次或一组同类页面。
- 高频页面一次只迁一个页面；低频静态页可以一组迁移。
- 首个动作优先 UI 骨架、状态组件、弹层和内容宽度，不先动深层业务。
- 完成页面迁移后更新本清单状态，并同步对应 UI 展示计划。
- 无法迁移的页面必须写例外原因、影响平台和回收条件。

## 11. 执行记录

### 2026-05-13：A8-B3 资源图集列表页首批迁移

选择范围：

| 路由/入口 | 页面 | 本批动作 | 回归重点 | 状态 |
| --- | --- | --- | --- | --- |
| `/cover-galleries` | `CoverGalleryPage` | 重命名/删除弹层迁到 `showAdaptiveActionSurface`；保留轻量 index、移动单列、桌面多列网格 | 新增、重命名、复制、删除；360/600/1280；大字体 | 已完成 |
| `/appearance/launch-image` | `LaunchImageGalleryPage` | 重命名/删除弹层迁到 `showAdaptiveActionSurface`；保留启动图开关和轻量 index | 启动图开关、新增、重命名、复制、删除；移动/桌面 | 已完成 |
| `/bottom-nav-icon-galleries` | `BottomNavIconGalleryPage` | 收口到 `ConsumerStatefulWidget` 和 provider；重命名/删除弹层迁到 adaptive surface；空搜索结果保留搜索框 | 默认图集切换、搜索空态、编辑入口、删除确认 | 已完成 |

影响平台：

- 移动端：命名和确认操作改为底部操作面板，保留原有单列触控列表。
- Web/桌面：命名和确认操作改为居中 dialog surface，避免手机弹层原样放大。
- 平板/大屏：列表继续使用已有 600dp+ 多列网格与内容最大宽度。

本批例外：

- `CoverGalleryPage`、`LaunchImageGalleryPage`、`BottomNavIconGalleryPage` 暂保留直接 `Scaffold`，因为页面依赖透明 AppBar、主题背景和 `extendBodyBehindAppBar`。回收条件：`AdaptivePageScaffold` 支持 backdrop、透明 AppBar 和沉浸式顶部 inset 后，再迁移页面骨架。
- 图集编辑器页本批不迁移。原因：编辑器包含完整资源列表、文件导入、排序和删除等深层业务路径；回收条件：下一批 A8-B3 先抽出编辑器通用 adaptive picker / confirm surface 后再迁移。

### 2026-05-13：A8-B3 资源编辑页第二批迁移

选择范围：

| 路由/入口 | 页面 | 本批动作 | 回归重点 | 状态 |
| --- | --- | --- | --- | --- |
| `/bottom-nav-icon-galleries/editor` | `BottomNavIconGalleryEditorPage` | 从 `StatefulWidget + 直接 new service + ProviderScope.containerOf` 收口为 `ConsumerStatefulWidget + provider` | 导入图标、清空 slot、复制日间到夜间、保存名称、任务态 | 已完成 |
| `/cover-galleries/editor` | `CoverGalleryEditorPage` | 删除图集确认迁到 `showAdaptiveActionSurface` | 删除确认、删除后返回、移动/桌面弹层形态 | 已完成 |
| `/appearance/launch-image/editor` | `LaunchImageGalleryEditorPage` | 删除图集确认迁到 `showAdaptiveActionSurface` | 内置图集不可删、自定义图集删除、返回结果 | 已完成 |
| `/appearance/reader-background` | `ReaderBackgroundPage` | 删除阅读背景确认迁到 `showAdaptiveActionSurface` | 删除确认、搜索/空态、移动/桌面弹层形态 | 已完成 |

本批例外：

- 封面、启动图和阅读背景的全屏图片预览仍保留 `showDialog`。原因：该弹层是沉浸式黑底预览，包含 `InteractiveViewer` 手势缩放和点按关闭，不是普通操作面板。回收条件：新增 `AdaptiveFullscreenPreviewSurface` 或同等全屏预览基线组件后再统一迁移。
- 底栏图集编辑器仍保留直接 `Scaffold`。原因：编辑器结构为专用 slot 矩阵，当前收益主要在状态来源和任务态收口；回收条件：资源编辑器统一骨架支持专用矩阵布局后迁移。

### 2026-05-13：A8-B4 公告页面两项迁移

选择范围：

| 路由/入口 | 页面 | 本批动作 | 回归重点 | 状态 |
| --- | --- | --- | --- | --- |
| `/announcements` | `AnnouncementListPage` | 公告列表从 `ListView(children)` 改为 `CustomScrollView + SliverList.builder`，保留最新公告置顶和加载更多 footer | 下拉刷新、滚动加载更多、空/错误状态、360/1280 宽度 | 已完成 |
| `/announcements/:id` | `AnnouncementDetailPage` | 正文最大宽度从 `mineContentMaxWidth` 收窄到 `settingsContentMaxWidth` | 长公告正文、大字体、桌面宽屏阅读 | 已完成 |

本批例外：

- 两个公告页暂保留直接 `Scaffold`。原因：页面和资源页一样依赖透明 AppBar、主题 backdrop 和 `extendBodyBehindAppBar`；回收条件同资源页，待 `AdaptivePageScaffold` 支持透明 AppBar/backdrop 后统一迁移。

### 2026-05-13：A8 两项并行迁移：关于页 + 同步历史

选择范围：

| 路由/入口 | 页面 | 本批动作 | 回归重点 | 状态 |
| --- | --- | --- | --- | --- |
| `/about` | `AboutPage` | 从 `StatefulWidget + Consumer` 收口为 `ConsumerStatefulWidget` | 版本信息加载、主题 backdrop、桌面双列卡片 | 已完成 |
| `/sync/history` | `SyncHistoryPage` | 任务详情从裸 `showModalBottomSheet` 迁到 `showAdaptiveActionSurface` | 移动底部面板、桌面居中详情、任务/冲突双栏 | 已完成 |

本批例外：

- `AboutPage` 暂保留直接 `Scaffold`，原因同公告页，依赖透明 AppBar 与主题 backdrop。
- `SyncHistoryPage` 暂保留直接 `Scaffold`，原因是同步能力页后续还要和 A4 capability 三态入口一起做整页 gated 迁移；本批只处理明确的弹层反模式。

### 2026-05-13：A8 三个功能模块批量迁移

选择范围：

| 功能模块 | 页面 | 本批动作 | 回归重点 | 状态 |
| --- | --- | --- | --- | --- |
| 标签/分类管理 | `/mine/tags`、`/mine/categories` | `MineManagementPage` 内部管理页从 `StatefulWidget + Consumer` 收口为 `ConsumerStatefulWidget`；重命名和删除确认迁到 `showAdaptiveActionSurface` | 新增、重命名、删除、空状态、加载失败重试 | 已完成 |
| 书签/灵感 | `/bookmarks`、`_BookmarkBookDetailPage` | 内部详情页增加内容最大宽度与自适应间距，避免桌面详情横向拉满 | 书籍分组、章节分组、删除后返回、桌面宽屏 | 已完成 |
| 缓存/字体资源 | `/cache`、`/font-management` | 缓存清理确认、缓存明细、单书清理、字体导入说明、字体重命名统一迁到 `showAdaptiveActionSurface` | 移动底部面板、桌面居中面板、清理任务态、字体导入任务态 | 已完成 |

本批例外：

- `MineManagementPage`、`BookmarksPage`、`CacheManagementPage`、`FontManagementPage` 暂保留直接 `Scaffold`。原因：这些页面已有透明 AppBar、主题 backdrop 或专用任务 overlay；回收条件同前，待 `AdaptivePageScaffold` 支持透明 AppBar/backdrop/overlay slot 后统一迁移骨架。
- 缓存清理和字体导入的业务流程不在本批重写，只迁 UI surface 和状态来源，避免影响实际数据删除、导入和任务态。

### 2026-05-13：A8 三个功能模块第二组迁移

选择范围：

| 功能模块 | 页面 | 本批动作 | 回归重点 | 状态 |
| --- | --- | --- | --- | --- |
| 反馈 | `/feedback`、`/feedback/compose` | `FeedbackPage` 从 `StatefulWidget + Consumer` 收口为 `ConsumerStatefulWidget`；提交前相似反馈确认迁到 `showAdaptiveActionSurface` | 列表筛选、提交反馈、相似反馈确认、移动/桌面弹层 | 已完成 |
| 错误中心 | `/error-center` | 移动端日志列表从 `ListView(children)` 改为 `CustomScrollView + SliverList.builder`；低高度横屏降级为移动列表 | 日志很多时滚动、空状态、复制/导出入口、640x360 + 1.3 字体 | 已完成 |
| 系统设置 | `/system-settings` | 恢复界面/阅读设置默认确认迁到 `showAdaptiveActionSurface` | 入口可达、确认恢复、移动/桌面弹层 | 已完成 |

本批例外：

- `MembershipCenterPage` 中兑换码、设备席位、客服说明面板暂不纳入本组三模块。原因：该页包含登录态、会员权益、席位同步和底部表单，适合单独作为账号/会员模块做完整迁移。
- `FeedbackComposePage` 页面骨架暂保留直接 `Scaffold`，本批只迁提交前的普通确认弹层；回收条件：反馈模块统一表单骨架和附件/键盘 inset 后再迁移。
