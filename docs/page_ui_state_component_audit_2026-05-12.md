# 页面状态组件审计

更新时间：2026-05-12  
关联计划：`docs/page_ui_component_governance_plan_2026-05-12.md` UI-G2

## 0. 审计口径

扫描范围：

- `lib/app/widgets`
- `lib/app/motion`
- `lib/features/**/presentation`
- `lib/core/app_update`
- `lib/core/media`
- `lib/core/webview`

统计结果：

| 组件/模式 | 次数 | 结论 |
| --- | ---: | --- |
| `CircularProgressIndicator` | 81 | 裸 loading 较多，需要区分页面级、局部按钮级、任务进度级 |
| `LinearProgressIndicator` | 14 | 主要集中在任务/进度展示，优先保留或封装为任务进度组件 |
| `AppEmptyStateCard` | 19 | 已有统一空状态，但覆盖还不够 |
| `AppStatusStateCard` | 14 | 已有状态卡，适合继续承接错误/警告/加载说明 |
| `FeatureDisabledPage` | 24 | 能力关闭占位已统一，继续保持 |

原则：

- 页面级空状态优先 `AppEmptyStateCard`。
- 页面级加载、错误、警告、成功说明优先 `AppStatusStateCard`。
- 能力关闭优先 `FeatureDisabledPage` / `FeatureDisabledPages`。
- 按钮内、列表行内、任务 overlay 内的小 spinner 可以保留，但需要确认不会阻塞首屏。

## 1. 高频状态组件文件

| 文件 | Loading | Empty | Status | Disabled | 迁移判断 |
| --- | ---: | ---: | ---: | ---: | --- |
| `lib/features/bookshelf/presentation/bookshelf_page.dart` | 6 | 0 | 0 | 0 | P1，书架加载/刷新状态后续收口为列表 footer 或状态卡 |
| `lib/features/mine/presentation/feedback_page.dart` | 4 | 1 | 1 | 0 | P1，反馈列表/详情空态和错误态统一 |
| `lib/features/source/presentation/source_page_flow.dart` | 4 | 2 | 0 | 0 | P2，书源能力开启后治理 |
| `lib/features/sync/presentation/pages/sync_settings_page.dart` | 2 | 2 | 2 | 0 | P2，WebDAV 开启后治理 |
| `lib/app/widgets/import_export_task_overlay.dart` | 5 | 0 | 0 | 0 | 保留任务进度语义，后续抽成 import/export status component |
| `lib/features/mine/presentation/advanced_theme_list_page.dart` | 4 | 1 | 0 | 0 | P1，主题导入/空状态统一 |
| `lib/features/error/presentation/error_center_page.dart` | 1 | 3 | 0 | 0 | 已较好使用 `AppEmptyStateCard` |
| `lib/features/announcement/presentation/announcement_list_page.dart` | 2 | 0 | 1 | 0 | P2，公告空/加载状态补统一 |
| `lib/features/discover/presentation/discover_page.dart` | 3 | 0 | 0 | 0 | P2，能力开启后治理 |
| `lib/features/mine/presentation/font_management_page.dart` | 1 | 1 | 1 | 0 | P1，字体列表/导入状态统一 |
| `lib/features/source/presentation/source_login_page.dart` | 3 | 0 | 0 | 0 | P2，书源能力开启后治理 |

## 2. 优先迁移页面

P1：

- `BookshelfPage`：加载更多、刷新、批量任务状态。
- `FeedbackPage`：列表空态、提交中、详情异常。
- `AdvancedThemeListPage`：主题列表空态、批量导入状态。
- `FontManagementPage`：字体列表空态、导入中和失败态。
- `SearchPage` / search widgets：搜索进度、失败摘要、分组空态。

P2：

- `SourcePage` / `SourceLoginPage` / `ScriptSourceEditorPage`：书源能力开启后统一。
- `SyncSettingsPage` / `SyncHistoryPage`：WebDAV 能力开启后统一。
- `AnnouncementListPage` / `AnnouncementDetailPage`：低频页面按机会迁移。

保留：

- 按钮内 spinner、图片加载占位、阅读器局部图片加载。
- 导入导出任务 overlay 的进度条，后续可以封装但不强制替换为状态卡。

## 3. G2 验收结论

- 已完成状态组件静态审计和页面优先级归档。
- 现有能力关闭页已经统一到 `FeatureDisabledPage` / `FeatureDisabledPages`。
- G2 不做批量替换，后续按页面进入 UI-G4/G5 或具体页面优化时迁移。
