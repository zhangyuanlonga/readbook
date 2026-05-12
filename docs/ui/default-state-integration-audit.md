# 缺省态接入审计

更新时间：2026-05-07

## 范围

本次只统计这类页面：

- 明确以 `ListView` / `GridView` / `SliverList` / `CustomScrollView` 承载内容
- 存在“空列表 / 无结果 / 加载失败 / 状态提示”类缺省态
- 适合逐步接入当前统一组件
  - `AppEmptyStateCard`
  - `AppStatusStateCard`

不纳入本次统计的情况：

- 普通详情页里的单个提示文案
- Toast / SnackBar / 对话框文案
- 阅读器正文、图片重试、业务流中高度定制的内嵌状态

## 当前结论

- 已接入统一缺省态：21 处
- 未接入但可直接替换：0 处
- 未接入且建议先做轻包装再替换：0 处
- 合计候选：21 处

## 已接入

| 页面/组件 | 场景 | 现状 |
| --- | --- | --- |
| `lib/features/reader/presentation/reading_records_page.dart` | 统计页空数据 | 已接 `AppEmptyStateCard` |
| `lib/features/mine/presentation/feedback_page.dart` | 反馈列表空态/失败态 | 已接 `AppEmptyStateCard` / `AppStatusStateCard` |
| `lib/features/mine/presentation/bookmarks_page.dart` | 灵感页空态/失败态 | 已接 `AppStatusStateCard` |
| `lib/features/mine/presentation/mine_management_page.dart` | 标签/分类管理空态/失败态 | 已接 `AppEmptyStateCard` / `AppStatusStateCard` |
| `lib/features/mine/presentation/advanced_theme_list_page.dart` | 高级主题空态 | 已接 `AppEmptyStateCard` |
| `lib/features/mine/presentation/cover_gallery_page.dart` | 封面图集空态 | 通过 `ImageResourceEmptyStateCard` 间接接入 |
| `lib/features/mine/presentation/launch_image_gallery_page.dart` | 启动图集空态 | 通过 `ImageResourceEmptyStateCard` 间接接入 |
| `lib/features/mine/presentation/reader_background_page.dart` | 阅读背景空态 | 通过 `ImageResourceEmptyStateCard` 间接接入 |
| `lib/features/mine/presentation/appearance_page_view.dart` | 应用背景空态 | 通过 `ImageResourceEmptyStateCard` 间接接入 |
| `lib/features/mine/presentation/font_management_page.dart` | 字体库空态 / 加载失败 | 已接 `AppEmptyStateCard` / `AppStatusStateCard` |
| `lib/features/source/presentation/source_page_flow.dart` | 书源列表空态 / 搜索无结果 | 已接 `AppEmptyStateCard` |
| `lib/features/announcement/presentation/announcement_list_page.dart` | 公告列表空态 / 失败态 | 已接 `AppStatusStateCard` |
| `lib/features/announcement/presentation/announcement_detail_page.dart` | 公告详情无内容 / 失败态 | 已接 `AppStatusStateCard` |
| `lib/features/error/presentation/error_center_page.dart` | 错误日志为空 | 已接 `AppEmptyStateCard` |
| `lib/features/sync/presentation/pages/sync_settings_page.dart` | 已保存配置为空 / 任务记录为空 / 加载失败 | 已接 `AppEmptyStateCard` / `AppStatusStateCard` |
| `lib/features/bookshelf/presentation/widgets/bookshelf_page_sections.dart` | 书架空态 / 筛选空态 / 加载失败 | 已做书架业务包装并接入统一组件 |
| `lib/features/search/presentation/widgets/search_grouped_empty_fallback_card.dart` | 搜索无结果但带操作建议 | 已做搜索业务包装并接入统一组件 |
| `lib/features/search/presentation/widgets/search_empty_state.dart` | 搜索历史 + 引导空态 | 已保留复合布局并接入统一空态壳体 |
| `lib/features/source/presentation/script_source_debug_page.dart` | 调试结果为空但带“复制卡片”操作 | 已做调试业务包装并接入统一组件 |

## 暂不建议强行统一

这些页面有明显专题化 UI，短期不建议为了统一而损失信息密度或交互语义。

| 页面/组件 | 原因 |
| --- | --- |
| `lib/features/discover/presentation/discover_page.dart` | 分类流、书源流、结果流混合，当前空态和错误态与信息架构绑定较深 |
| `lib/features/mine/presentation/cache_management_page.dart` | 多为弹窗明细和分区说明，缺省态更像“内嵌说明文字”而不是页面级空态 |
| `lib/features/mine/presentation/membership_center_page.dart` | 会员态、许可证态、设备记录态差异很大，建议后续单独设计 `MembershipStateCard` |
| `lib/features/reader/presentation/reader_text_paged_view.dart` / `reader_viewport_builder.dart` | 阅读内容区状态属于阅读器专属语义，不应直接复用列表页缺省态卡片 |

## 推荐接入顺序

当前文档范围内的候选页面已经全部完成接入。后续建议转入两类工作：

1. 视觉微调：统一不同页面对 `compact`、图标尺寸、动作按钮密度的使用规则
2. 扩展体系：按专题抽 `MembershipStateCard`、`DiscoverStateCard`、阅读器专属状态组件

## 接入规则

后续接入时建议遵守这几个规则：

- 简单空列表：优先用 `AppEmptyStateCard`
- 错误 / 禁用 / 需要重试：优先用 `AppStatusStateCard`
- 如果页面有明显业务个性：
  - 不直接复制旧实现
  - 先做业务包装组件
  - 包装组件底层仍复用统一缺省态
- 不要把所有差异都塞进一个万能组件

## 备注

- `ImageResourceEmptyStateCard` 目前已退化成 `AppEmptyStateCard` 的资源页包装层，可以继续保留，作为资源类页面的专用入口。
- 后续如果要继续统一搜索框、过滤无结果、分页加载失败，建议单独再出一份 `list-shell` 审计文档，不和本缺省态文档混在一起。
