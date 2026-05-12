# 页面列表与卡片交互审计

更新时间：2026-05-12  
关联计划：`docs/page_ui_component_governance_plan_2026-05-12.md` UI-G4

## 0. 审计结论

当前列表/卡片治理重点不是“所有 `ListView` 都换 Sliver”，而是：

- 高频长列表继续确保使用 builder 或 Sliver。
- 复杂页面优先使用 `CustomScrollView + Sliver*`。
- 卡片点击反馈需要统一 hover、focus、selected、disabled。
- 资源卡片、封面卡片、书籍卡片后续应抽共同交互规范。

## 1. 高频文件

| 文件 | 现状 | 迁移优先级 | 建议 |
| --- | --- | --- | --- |
| `advanced_theme_editor_page.dart` | 资源选择/预览处 `InkWell` 多，`GridView.builder` 已使用 | P1 | 资源选择卡片统一 hover/focus/selected |
| `appearance_page_view.dart` | 外观面板使用多处 `InkWell/GestureDetector` | P1 | 设置卡片逐步统一到 `AdaptiveSettingTile` 或 feature tile |
| `bookmarks_page.dart` | 多处 `ListView` + `Card` | P1 | 书籍分组和详情列表补 builder/sliver 与键盘焦点 |
| `discover_page.dart` | 已使用 `CustomScrollView`、`SliverList` | P2 | 能力开启后统一书籍卡片交互 |
| `bookshelf_page.dart` | 已使用 `CustomScrollView`，书籍卡片交互复杂 | P0 | 书籍卡片 hover/focus/selected/批量选择继续作为样板 |
| `error_center_page.dart` | `ListView` + `Card` | P2 | 日志列表后续可 builder 化 |
| `cover_gallery_page.dart` / `launch_image_gallery_page.dart` / `bottom_nav_icon_gallery_page.dart` | 移动列表 + 桌面 `CustomScrollView/SliverGrid` | P1 | 图集卡片交互状态统一 |
| `feedback_page.dart` | 多处 `ListView` | P1 | 反馈列表/详情分栏后续补 builder/focus |
| `search_page.dart` | 已有 `CustomScrollView` 和 `AdaptiveGridSliver` | P1 | 搜索结果卡片 hover/focus/键盘选择 |

## 2. 迁移规则

- 长列表禁止新增 `ListView(children: [...])`；简单长列表使用 `ListView.builder`。
- 固定高度列表才允许 `itemExtent` / `prototypeItem`。
- 复杂列表、吸顶搜索、分页 footer、网格/列表切换优先 Sliver。
- 手写 `Row + Column + InkWell` 的列表项，优先迁移到 `AdaptiveListTile` 或 feature 专用 tile。
- 卡片必须有明确点击反馈；桌面端补 hover/focus，移动端保持触控面积。
- 封面叠层统一：来源、进度、未读、选中态不要散落到各页面重复实现。

## 3. G4 验收结论

- 已完成列表/卡片静态审计和页面优先级归档。
- 书架、搜索、书签、反馈、资源管理进入后续样板页面序列。
- G4 不做批量替换，迁移将跟随后续具体页面优化推进。
