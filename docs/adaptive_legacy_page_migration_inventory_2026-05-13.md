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
