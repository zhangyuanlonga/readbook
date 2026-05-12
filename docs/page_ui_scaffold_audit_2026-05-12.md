# 页面 Scaffold 骨架审计

更新时间：2026-05-12  
关联计划：`docs/page_ui_component_governance_plan_2026-05-12.md` UI-G1

## 0. 审计口径

扫描命令：

```bash
rg "\\bScaffold\\(" lib -n
```

结果：

- 裸 `Scaffold(`：55 处。
- `AdaptivePageScaffold` 内部实现：1 处，属于封装本身，不计入迁移债务。
- `ShellScaffold` 内部：3 处，属于主导航外壳，不迁移为页面级 adaptive scaffold。

分类说明：

| 分类 | 含义 |
| --- | --- |
| 保留-shell | 应用主壳，负责 bottom navigation / navigation rail |
| 保留-adaptive | adaptive 封装内部实现 |
| 已完成大屏结构 | 页面已在现阶段具备宽屏结构，后续只做细节治理 |
| 可迁移优先 | 后续适合迁移到 `AdaptivePageScaffold` 或拆出 adaptive scaffold 包装 |
| 专用保留 | 阅读器、内嵌页、沉浸式、特殊编辑器等保留专用 scaffold |
| 低优先级能力页 | 书源/同步等能力关闭时不进首版核心，后续开启能力再治理 |

## 1. 保留-shell

| 文件 | 行 | 说明 |
| --- | ---: | --- |
| `lib/app/shell_scaffold.dart` | 199 | 无可用导航时的主壳兜底 |
| `lib/app/shell_scaffold.dart` | 203 | Desktop Like `NavigationRail` 主壳 |
| `lib/app/shell_scaffold.dart` | 229 | Mobile Touch bottom navigation 主壳 |

处理结论：

- 保留，不迁移到 `AdaptivePageScaffold`。
- 后续只在主壳层继续维护 SafeArea、NavigationRail、底部导航和桌面焦点态。

## 2. 保留-adaptive

| 文件 | 行 | 说明 |
| --- | ---: | --- |
| `lib/app/widgets/adaptive_page_scaffold.dart` | 38 | adaptive 页面骨架封装内部 |

处理结论：

- 保留，这是后续新页面默认使用的封装。

## 3. 已完成大屏结构

这些页面已经在此前 UI 阶段完成或具备桌面结构，不作为 G1 立即迁移对象；后续进入 G2/G3/G4 时继续治理状态、弹层、列表和卡片。

| 页面/文件 | 行 | 现状 |
| --- | ---: | --- |
| `HomePage` / `lib/features/home/presentation/home_page.dart` | 105 | 600dp+ 已 dashboard 化 |
| `BookshelfPage` / `lib/features/bookshelf/presentation/bookshelf_page.dart` | 622 | 600dp+ 已桌面工具条和网格重排 |
| `LocalLibraryPage` / `lib/features/bookshelf/presentation/local_library_page.dart` | 869 | 600dp+ 已文件管理/列布局基础 |
| `BookDetailPage` / `lib/features/book/presentation/book_detail_page_view.dart` | 30 | 600dp+ 已宽屏封面/信息/目录分区 |
| `ReadingRecordsPage` / `lib/features/reader/presentation/reading_records_page.dart` | 278 | 已纳入 UI 计划，后续做双栏细化 |
| `MinePage` / `lib/features/mine/presentation/mine_page_view.dart` | 65 | 600dp+ 已工作台式分组 |
| `AppearancePage` / `lib/features/mine/presentation/appearance_page_view.dart` | 50 | 840dp+ 已两列工作台 |
| `AdvancedThemeListPage` / `lib/features/mine/presentation/advanced_theme_list_page.dart` | 2137 | 840dp+ 已列表/预览分栏 |
| `CacheManagementPage` / `lib/features/mine/presentation/cache_management_page.dart` | 131 | 已进入管理页桌面化 |
| `BookmarksPage` / `lib/features/mine/presentation/bookmarks_page.dart` | 110 | 600dp+ 已书籍分组/详情分栏 |
| `ErrorCenterPage` / `lib/features/error/presentation/error_center_page.dart` | 40 | 600dp+ 已列表/详情分栏 |
| `CoverGalleryPage` / `lib/features/mine/presentation/cover_gallery_page.dart` | 256 | 600dp+ 已工具条 + 网格 |
| `LaunchImageGalleryPage` / `lib/features/mine/presentation/launch_image_gallery_page.dart` | 313 | 600dp+ 已工具条 + 网格 |
| `BottomNavIconGalleryPage` / `lib/features/mine/presentation/bottom_nav_icon_gallery_page.dart` | 298 | 600dp+ 已资源管理布局 |
| `ReaderBackgroundPage` / `lib/features/mine/presentation/reader_background_page.dart` | 241 | 600dp+ 已桌面网格基础 |

处理结论：

- G1 不批量替换；这些页面后续优先进入状态组件、弹层和列表卡片治理。

## 4. 可迁移优先

这些页面仍以独立 `Scaffold` 为主，适合在后续阶段迁移到 `AdaptivePageScaffold` 或抽出统一骨架。

| 页面/文件 | 行 | 优先级 | 迁移方向 |
| --- | ---: | --- | --- |
| `AnnouncementListPage` / `lib/features/announcement/presentation/announcement_list_page.dart` | 185 | P1 | 桌面列表/详情双栏，正文宽度限制 |
| `AnnouncementDetailPage` / `lib/features/announcement/presentation/announcement_detail_page.dart` | 99 | P1 | 详情正文最大宽度和滚动约束 |
| `AuthPage` / `lib/features/auth/presentation/auth_page.dart` | 57 | P1 | 表单宽度受限，键盘路径 |
| `UserProfilePage` / `lib/features/auth/presentation/user_profile_page.dart` | 112 | P1 | 资料表单居中/双栏 |
| `MembershipCenterPage` / `lib/features/mine/presentation/membership_center_page.dart` | 172 | P1 | 权益和操作区多栏 |
| `FeedbackPage` / `lib/features/mine/presentation/feedback_page.dart` | 131 | P1 | 列表/详情分栏 |
| `FeedbackComposePage` / `lib/features/mine/presentation/feedback_page.dart` | 576 | P1 | 表单宽度受限 |
| `FeedbackDetailPage` / `lib/features/mine/presentation/feedback_page.dart` | 873 | P1 | 详情正文宽度限制 |
| `FontManagementPage` / `lib/features/mine/presentation/font_management_page.dart` | 260 | P1 | 字体列表/预览/操作区分栏 |
| `SystemSettingsPage` / `lib/features/mine/presentation/system_settings_page.dart` | 45 | P1 | 设置项统一 `AdaptiveSettingTile` |
| `MineManagementPage` / `lib/features/mine/presentation/mine_management_page.dart` | 444 | P1 | 标签/分类管理列表和编辑区分栏 |
| `AboutPage` / `lib/features/mine/presentation/about_page.dart` | 95 | P2 | 信息密度复核，最大宽度 |
| `ReaderBackgroundPage` editor branch / `lib/features/mine/presentation/reader_background_page.dart` | 155 | P2 | 编辑态与预览态统一 adaptive 容器 |
| `CoverGalleryEditorPage` / `lib/features/mine/presentation/cover_gallery_editor_page.dart` | 268, 329 | P2 | 编辑表单和预览分栏 |
| `LaunchImageGalleryEditorPage` / `lib/features/mine/presentation/launch_image_gallery_editor_page.dart` | 278, 339 | P2 | 编辑表单和预览分栏 |
| `BottomNavIconGalleryEditorPage` / `lib/features/mine/presentation/bottom_nav_icon_gallery_editor_page.dart` | 219 | P2 | 编辑表单和预览分栏 |

处理结论：

- 后续 UI-G2/G3/G4 按页面收益逐步迁移，避免一次性替换所有 scaffold。

## 5. 专用保留

| 页面/文件 | 行 | 保留原因 |
| --- | ---: | --- |
| `ReaderPage` / `lib/features/reader/presentation/reader_page_viewport.dart` | 54 | 阅读器是沉浸式内容容器，已有专用键盘、滚轮、目录侧栏和正文宽度规则 |
| `_BookmarkBookDetailPage` / `lib/features/mine/presentation/bookmarks_page.dart` | 807 | 书签内部私有详情页，非全局路由，后续可随书签页一起整理 |
| `BookDetailPage` action branch / `lib/features/book/presentation/book_detail_page_actions.dart` | 229 | 详情页内部动作流分支，后续随详情页动作弹层治理 |
| `InteractiveVerificationPage` / `lib/core/webview/interactive_verification_browser_executor.dart` | 248 | WebView/交互验证专用容器 |
| `FeatureDisabledPage` / `lib/app/widgets/feature_disabled_page.dart` | 32 | 轻量禁用页封装，保留独立 scaffold |

处理结论：

- 保留专用 scaffold，但后续仍要遵守安全区、最大宽度和桌面交互底线。

## 6. 低优先级能力页

书源和同步能力默认不属于首版核心。能力关闭时已通过 `FeatureDisabledPage` 降级；能力开启后再按桌面工作台治理。

| 页面/文件 | 行 | 后续方向 |
| --- | ---: | --- |
| `DiscoverPage` / `lib/features/discover/presentation/discover_page.dart` | 198 | 书源能力开启后再治理发现工作台 |
| `SearchPage` / `lib/features/search/presentation/search_page.dart` | 175 | 搜索属于高频候选，能力开启后优先做列表/筛选弹层治理 |
| `SourcePage` flow / `lib/features/source/presentation/source_page_flow.dart` | 96, 111, 194 | 书源工作台后续统一 |
| `SourceLoginPage` / `lib/features/source/presentation/source_login_page.dart` | 509 | 登录表单桌面化 |
| `SourceWebLoginPage` / `lib/features/source/presentation/source_web_login_page.dart` | 130 | WebView 窗口化 |
| `ScriptSourceDebugPage` / `lib/features/source/presentation/script_source_debug_page.dart` | 100 | 调试工作台 |
| `ScriptSourceEditorPage` / `lib/features/source/presentation/script_source_editor_page.dart` | 438 | 代码编辑器 + 调试/日志面板 |
| `ScriptSourcePasteImportPage` / `lib/features/source/presentation/script_source_paste_import_page.dart` | 210 | 导入表单桌面化 |
| `SyncSettingsPage` / `lib/features/sync/presentation/pages/sync_settings_page.dart` | 82 | WebDAV 开启后做 profile/设置双栏 |
| `SyncHistoryPage` / `lib/features/sync/presentation/pages/sync_history_page.dart` | 22 | 已有历史双栏方向，能力开启后细化 |

处理结论：

- 默认能力关闭时不创建真实业务页。
- 能力开启后作为 UI-G4/G5 的工作台式页面治理对象。

## 7. G1 验收结论

- 已建立 scaffold 审计台账。
- 已明确新页面默认使用 `AdaptivePageScaffold`。
- 已明确旧页面迁移不是批量替换，而是跟随后续状态组件、弹层、列表和桌面交互阶段推进。
- 当前核心页面的桌面底栏和单列放大问题已在 UI 阶段 A/B/C/D 中处理；G1 不再重复修改核心页面代码。
