# 页面弹层与反馈审计

更新时间：2026-05-12  
关联计划：`docs/page_ui_component_governance_plan_2026-05-12.md` UI-G3

## 0. 审计口径

扫描范围：

- `lib/app`
- `lib/features/**/presentation`
- `lib/core/app_update`
- `lib/core/media`
- `lib/core/webview`

统计结果：

| 组件/模式 | 次数 | 结论 |
| --- | ---: | --- |
| `showModalBottomSheet` | 48 | 移动端心智较强，桌面/Web 需要逐步迁移到 adaptive surface |
| `showDialog` | 59 | 数量高，需要统一最大宽度、滚动约束和 1.3x 文字表现 |
| `AlertDialog` | 50 | 确认/输入弹窗很多，优先做约束，不机械替换 |
| `SnackBar` | 66 | 轻提示多，桌面端需避免遮挡主操作 |
| `AdaptiveActionSurface` | 2 | 已有基础件，但调用覆盖不足 |
| `AdaptiveBottomSheet` | 3 | 封装内部使用为主 |
| `AdaptiveDialogSurface` | 3 | 封装内部使用为主 |

## 1. 新增统一入口

本阶段新增 `showAdaptiveActionSurface<T>`：

- 移动端：`showModalBottomSheet` + `AdaptiveActionSurface.mobileSheet`
- Web/桌面：`showDialog` + `AdaptiveActionSurface.desktopDialog`
- 默认 `isScrollControlled=true`，桌面端使用透明 `Dialog` 包裹 adaptive surface
- 支持 `maxWidth`、`maxHeightFactor`、`padding`、`barrierDismissible`、`useRootNavigator`

样板迁移：

- `SearchFailureBanner` 的失败明细从裸 `showModalBottomSheet` 改为 `showAdaptiveActionSurface`。

## 2. 高频弹层文件

| 文件 | BottomSheet | Dialog | SnackBar | 优先级 | 迁移判断 |
| --- | ---: | ---: | ---: | --- | --- |
| `lib/features/mine/presentation/advanced_theme_list_page.dart` | 3 | 6 | 2 | P1 | 排序、导入、删除、批量任务优先 adaptive surface |
| `lib/features/source/presentation/source_login_page.dart` | 0 | 5 | 6 | P2 | 书源能力开启后治理 |
| `lib/features/mine/presentation/font_management_page.dart` | 1 | 2 | 7 | P1 | 导入来源、重命名、删除确认统一 |
| `lib/features/source/presentation/source_page_flow.dart` | 3 | 4 | 0 | P2 | 书源工作台后续统一 |
| `lib/features/sync/presentation/pages/sync_settings_page.dart` | 0 | 1 | 9 | P2 | 同步能力开启后治理 |
| `lib/features/mine/presentation/advanced_theme_editor_page.dart` | 6 | 2 | 1 | P1 | 资源选择 bottom sheet 优先迁移 |
| `lib/features/mine/presentation/cache_management_page.dart` | 1 | 3 | 2 | P1 | 缓存明细、清理确认统一约束 |
| `lib/features/mine/presentation/membership_center_page.dart` | 3 | 2 | 1 | P2 | 低频权益/支持弹层后续迁移 |
| `lib/features/source/presentation/source_page_batch_check.dart` | 2 | 3 | 0 | P2 | 书源能力开启后治理 |
| `lib/features/reader/presentation/reader_page.dart` | 0 | 3 | 0 | 保留 | 阅读器已具备专用面板，确认类 dialog 继续保留 |
| `lib/features/mine/presentation/appearance_page_view.dart` | 3 | 0 | 0 | P1 | 外观设置选择面板优先 adaptive |
| `lib/features/search/presentation/search_page.dart` | 2 | 0 | 2 | P1 | 筛选、分组选书弹层优先 adaptive |
| `lib/features/book/presentation/book_detail_page_actions.dart` | 2 | 1 | 0 | P1 | 详情动作菜单和确认弹层统一 |
| `lib/features/reader/presentation/reader_catalog_sheet.dart` | 2 | 0 | 0 | 保留 | 阅读器目录/书签已有桌面侧栏方向，底部 sheet 保留移动路径 |

## 3. 迁移规则

- 新增筛选、排序、设置、资源选择、信息明细类弹层，必须优先使用 `showAdaptiveActionSurface`。
- 删除确认、危险操作、短输入可以继续用 `showDialog/AlertDialog`，但需要最大宽度和滚动约束。
- 阅读器目录、设置、章节缓存等已有移动/桌面双路径的页面，不强制统一到通用 surface。
- `SnackBar` 保留轻提示语义；桌面端如果会遮挡主操作，改为页面内 banner 或右上状态浮层。

## 4. G3 验收结论

- 已完成弹层/反馈静态审计和页面优先级归档。
- 已新增统一 adaptive 弹层入口。
- 已完成一个低风险样板迁移：搜索失败明细。
- G3 不批量替换 48 处 bottom sheet，后续按页面迁移，避免一次性改变移动端手感。
