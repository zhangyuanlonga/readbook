# 页面 UI 组件治理任务计划

更新时间：2026-05-12  
来源：基于 `lib` 下页面、presentation、app widgets 的静态扫描和人工归纳。  
用途：在逐页面多端 UI 展示计划之外，建立组件层面的治理任务，避免每个页面重复手写移动端风格布局、弹层、空状态和加载态。

## 0. 当前统计基线

本次统计只代表源码静态出现次数，不等同运行时实例数；它用于发现治理方向，不作为机械替换依据。

| 类型 | 指标 | 数量/次数 | 结论 |
| --- | --- | ---: | --- |
| 代码规模 | `lib/**/*.dart` | 552 | UI 分散在 app widgets 和各 feature presentation 中 |
| Widget 类 | `extends *Widget` | 218 | 自定义组件数量已经较多，需要收口规则 |
| 页面类 | `*Page` | 47 | 页面级多端治理需要可复用骨架 |
| 全局路由 | `GoRoute path` | 46 | 路由文档已由 `tool/check_route_inventory.dart` 守住 |
| Sheet 类 | `*Sheet` | 15 | 移动端 bottom sheet 心智较强，需要桌面适配 |
| Card 类 | `*Card` | 28 | 卡片体系较多，需要统一交互反馈 |
| `Scaffold` | 源码出现 | 56 | 新页面应默认走 adaptive scaffold |
| `ListView` | 源码出现 | 78 | 复杂列表页优先 Sliver 化，简单列表保留 builder |
| `showModalBottomSheet` | 源码出现 | 48 | 桌面/Web 需要统一 adaptive surface |
| `CircularProgressIndicator` | 源码出现 | 81 | 加载态需要收口，避免散落裸 spinner |
| `LayoutBuilder` | 源码出现 | 73 | 需要审计是否存在重计算或状态副作用 |

已有可复用基础件：

- `AdaptivePageScaffold`
- `AdaptiveContentContainer`
- `AdaptiveSearchBar`
- `AdaptiveFilterBar`
- `AdaptiveGridSliver`
- `AdaptiveBottomSheet` / `AdaptiveActionSurface` / `AdaptiveDialogSurface`
- `AdaptiveListTile`
- `AdaptiveSettingTile`
- `AdaptiveCard`
- `AppEmptyStateCard`
- `AppStatusStateCard`
- `FeatureDisabledPage`
- `ResolvedBookCoverView`

## 1. 治理原则

- 不按组件出现次数机械替换；只迁移有体验收益或维护收益的页面。
- 新页面默认使用 adaptive 基础件；旧页面按风险和页面访问频率逐步迁移。
- 简单列表可以保留 `ListView.builder`；复杂列表、吸顶搜索、分页加载、网格/列表切换优先使用 `CustomScrollView + Sliver*`。
- `itemExtent` 只用于固定高度列表；内容高度可变的书籍、搜索、书签、反馈列表不能强行固定高度。
- `SafeArea` 做遮挡风险审计，不要求每个 `Scaffold` 都机械包一层。
- `LayoutBuilder` 允许用于纯布局分支；禁止在 builder 中做重 IO、请求、状态写入或复杂重计算。
- Web/桌面端的弹层默认使用 dialog、popover、side panel；移动端继续优先 bottom sheet。

## 2. 阶段总览

| 阶段 | 名称 | 目标 | 范围 | 状态 |
| --- | --- | --- | --- | --- |
| UI-G0 | 组件基线与约束 | 建立组件治理规则和统计口径 | 文档、检查项 | 待执行 |
| UI-G1 | 页面骨架统一 | 新页面默认 adaptive scaffold，旧页面识别迁移对象 | Scaffold、SafeArea、内容宽度 | 待执行 |
| UI-G2 | 状态组件统一 | 空状态、加载态、错误态收口 | Empty、Loading、Error、Disabled | 待执行 |
| UI-G3 | 弹层自适应 | 移动 bottom sheet 与桌面 dialog/side panel 统一入口 | Sheet、Dialog、SnackBar | 待执行 |
| UI-G4 | 列表与卡片治理 | 高频列表、卡片、tile 统一交互反馈 | 书架、搜索、书签、反馈、资源管理 | 待执行 |
| UI-G5 | 桌面交互增强 | hover、focus、keyboard、scrollbar、快捷键 | Web、macOS、Windows、Linux | 待执行 |
| UI-G6 | 自动检查与回归 | 把 UI 组件规则纳入持续检查 | tool、测试、截图验收 | 待执行 |

## 3. UI-G0：组件基线与约束

目标：

- 把“哪些组件该统一、哪些不能机械替换”写清楚。
- 为后续迁移建立可复查的统计基线。

任务：

- [ ] 在架构约束中补充“UI 基线组件优先级”。
- [ ] 记录本次静态统计结果，后续每轮迁移后更新趋势。
- [ ] 明确新页面必须优先使用 adaptive 基础件。
- [ ] 明确旧页面迁移顺序：高频核心页、管理页、低频页。

验收：

- [ ] 新增页面 review 时有明确 UI 基线 checklist。
- [ ] 页面改造不会因为统计数字而盲目大改。

## 4. UI-G1：页面骨架统一

目标：

- 页面结构从散落 `Scaffold` 逐步收敛到 `AdaptivePageScaffold + AdaptiveContentContainer`。
- 手机、平板、Web、桌面默认拥有一致的安全区、内容宽度和导航行为。

任务：

- [ ] 新页面默认使用 `AdaptivePageScaffold`。
- [ ] 审计 56 处 `Scaffold`，标记为 `保留`、`迁移`、`由 shell 兜底` 三类。
- [ ] 对未使用 `AdaptivePageScaffold` 的核心页面补 SafeArea / padding / max width 风险说明。
- [ ] 页面宽度 `840dp+` 时避免移动端单列无限拉宽。
- [ ] 阅读器、启动页、沉浸式页面允许保留专用 scaffold，但必须说明原因。

优先页面：

- `BookshelfPage`
- `MinePage`
- `SearchPage`
- `BookmarksPage`
- `CacheManagementPage`
- `FeedbackPage`

验收：

- [ ] `390x844`、`600x960`、`1280x800` 下页面没有状态栏、底栏、侧边栏遮挡。
- [ ] Web/桌面默认窗口不出现手机底栏。

## 5. UI-G2：状态组件统一

目标：

- 空状态、加载态、错误态、能力禁用态统一。
- 避免裸 `Text('暂无数据')`、裸 `CircularProgressIndicator`、散落错误卡片。

任务：

- [ ] 搜索散落的 `暂无`、`没有`、`empty`、`CircularProgressIndicator`，按页面归档。
- [ ] 页面级空状态优先使用 `AppEmptyStateCard`。
- [ ] 页面级加载/错误/成功状态优先使用 `AppStatusStateCard`。
- [ ] 能力关闭页面统一使用 `FeatureDisabledPage` / `FeatureDisabledPages`。
- [ ] 列表底部加载更多封装为 Sliver 或列表 footer 组件。

优先页面：

- `BookshelfPage`
- `LocalLibraryPage`
- `SearchPage`
- `SourcePage`
- `SyncSettingsPage`
- `ErrorCenterPage`
- `FeedbackPage`

验收：

- [ ] 同一类空状态图标、标题、说明、主按钮风格一致。
- [ ] Web/桌面空状态不会变成超宽大卡片。
- [ ] 加载态不会阻塞已经可见的核心内容。

## 6. UI-G3：弹层自适应

目标：

- 移动端保留 bottom sheet。
- Web/桌面端统一转为 dialog、popover 或 side panel。
- 避免大屏底部弹出小面板和文字缩放 overflow。

任务：

- [ ] 审计 48 处 `showModalBottomSheet`，标记是否可迁移到 `AdaptiveActionSurface`。
- [ ] 审计 59 处 `showDialog` 和 50 处 `AlertDialog`，统一最大宽度、内边距和滚动约束。
- [ ] 导入导出、筛选排序、目录书签、设置、资源选择优先走 adaptive surface。
- [ ] `1.3x` 文字缩放下弹层内部必须可滚动，不允许 RenderFlex overflow。
- [ ] SnackBar 在桌面端不遮挡主操作，必要时改顶部横幅或右上状态浮层。

优先页面：

- `BookshelfPage`
- `ReaderPage`
- `SearchPage`
- `AppearancePage`
- `AdvancedThemeListPage`
- `CacheManagementPage`

验收：

- [ ] `showModalBottomSheet` 新增使用必须有桌面替代路径。
- [ ] Web/桌面端筛选、排序、设置不再默认使用手机底部 Sheet。

## 7. UI-G4：列表与卡片治理

目标：

- 高频列表和卡片拥有统一的点击、hover、focus、选中、长按/右键反馈。
- 复杂列表页获得更稳定的 Sliver 结构。

任务：

- [ ] 复杂列表页优先迁移为 `CustomScrollView + SliverList/SliverGrid/SliverToBoxAdapter`。
- [ ] 简单列表继续使用 `ListView.builder`，禁止使用 `ListView(children: [...])` 承载长列表。
- [ ] 固定高度列表可使用 `itemExtent` / `prototypeItem`；可变高度列表不得强行固定高度。
- [ ] 书籍卡片、封面卡片、资源卡片统一 hover、focus、selected、disabled 状态。
- [ ] 封面叠层统一组件化：来源、进度、未读、选中态使用明确的叠层规则。
- [ ] 重复手写 `Row + Column + InkWell` 的列表项优先迁移到 `AdaptiveListTile` 或 feature 专用 tile。

优先页面：

- `BookshelfPage`
- `SearchPage`
- `BookmarksPage`
- `FeedbackPage`
- `CoverGalleryPage`
- `LaunchImageGalleryPage`
- `BottomNavIconGalleryPage`
- `SyncHistoryPage`

验收：

- [ ] 1000 本书架滚动时不因一次性 children 构建卡顿。
- [ ] 桌面端卡片 hover 和键盘焦点可见。
- [ ] 移动端触控面积不低于当前体验。

## 8. UI-G5：桌面交互增强

目标：

- 桌面/Web 不只是布局变宽，还要有指针、键盘、滚轮和快捷路径。

任务：

- [ ] 高频列表补 hover 和 focus。
- [ ] 长列表补显式 `Scrollbar` 或平台默认可见滚动反馈。
- [ ] 支持常见快捷键：搜索 `Ctrl/Cmd+F`，保存 `Ctrl/Cmd+S`，关闭弹层 `Esc`，列表上下选择方向键。
- [ ] 可批量操作页面补桌面选择态、工具条和右键/更多菜单。
- [ ] 阅读器保持已有键盘翻页、滚轮和宽屏正文能力，并纳入回归。

优先页面：

- `BookshelfPage`
- `ReaderPage`
- `SearchPage`
- `BookmarksPage`
- `SourcePage`（能力开启后）
- `ScriptSourceEditorPage`（能力开启后）

验收：

- [ ] Web/桌面主要流程可以不用触屏完成。
- [ ] 键盘焦点不会丢失到不可见元素。

## 9. UI-G6：自动检查与回归

目标：

- 把 UI 组件治理从“记得做”变成“可检查”。

任务：

- [ ] 新增 UI 组件静态检查脚本，至少扫描：
  - 裸 `showModalBottomSheet`
  - 裸页面级 `CircularProgressIndicator`
  - 长列表 `ListView(children: [...])`
  - 新增页面未使用 adaptive scaffold 的风险项
  - `LayoutBuilder` 中疑似状态写入或异步调用
- [ ] 将检查脚本接入 `scripts/run_architecture_green_suite.sh` 或独立 UI 回归脚本。
- [ ] 在 `docs/global_page_lazy_loading_regression_checklist_2026-05-12.md` 增加 UI 组件治理检查项。
- [ ] UI 阶段完成后同步更新本文状态和执行记录。

验收：

- [ ] 新增 UI 反模式能在 review 前暴露。
- [ ] 不强制失败的风险项以 warning 形式输出，避免阻塞合理特例。

## 10. 执行建议

推荐顺序：

1. UI-G0 + UI-G2：先统一规则和状态组件，低风险且收益稳定。
2. UI-G3：弹层适配对桌面/Web 体验影响最大。
3. UI-G1：骨架迁移按页面逐步做，避免一次性改动太多。
4. UI-G4：挑书架、搜索、书签、反馈做样板，再扩展资源管理。
5. UI-G5：桌面交互增强跟随样板页面推进。
6. UI-G6：等规则稳定后再固化成检查脚本。

## 11. 执行记录

- 2026-05-12：建立组件治理任务文档，纳入逐页面 UI 多端计划和架构约束引用。当前仅完成任务拆分，尚未开始迁移。
