# 自适应体系优化计划

更新时间：2026-05-13  
定位：承接页面自适应、页面组件、内容尺寸、阅读器特化、capability、任务态和资源懒加载的后续治理，把讨论结论拆成可排期执行的阶段任务。

关联文档：

- `docs/development_architecture_guardrails.md`
- `docs/page_ui_multiplatform_display_plan_2026-05-12.md`
- `docs/page_ui_component_governance_plan_2026-05-12.md`
- `docs/app_task_status_unification_plan_2026-05-12.md`
- `docs/resource_page_lazy_loading_audit_2026-05-12.md`
- `docs/flutter_adaptive_baseline_matrix.md`
- `docs/adaptive_visual_regression_checklist.md`

## 0. 总目标

当前多端 UI 已有基本骨架：业务一套、自适应组件承接展示、capability 隔离平台能力、任务态开始统一。后续优化目标不是重做，而是补齐“最后一公里”：

- 明确基线组件覆盖度，减少页面手写分叉。
- 给阅读器建立专属布局上下文，避免普通页面规则硬套沉浸阅读。
- 把 capability 从布尔开关升级为可表达“需要配置/授权”的能力状态。
- 将导入、重索引、缓存扫描等耗时任务从 UI 状态推进到可队列化、可恢复的任务体系。
- 建立统一尺寸 token，解决字号、按钮、间距、内容宽度等绝对值不一致问题。
- 扩展验收矩阵，覆盖输入方式、窗口动态变化和高 DPI。
- 建立反模式清单和例外机制，让治理可以长期执行。

## 1. 阶段总览

| 阶段 | 名称 | 优先级 | 目标 | 主要产物 | 状态 |
| --- | --- | --- | --- | --- | --- |
| A0 | 基线盘点与冻结 | P0 | 明确现状和禁止继续扩散的点 | 覆盖矩阵、反模式清单 | 已完成 |
| A1 | 尺寸与 typography token | P0 | 统一字号、触控目标、内容宽度阶梯 | `AppTypography` / size token 方案 | 已完成 |
| A2 | 基线组件覆盖矩阵 | P0 | 定义必须用、推荐用、可例外的组件范围 | 组件覆盖度矩阵、例外规则 | 已完成 |
| A3 | 阅读器布局上下文 | P1 | 阅读器拥有独立内容宽度和弹层策略 | `ReaderLayoutContext` 方案与落地 | 已完成 |
| A4 | capability 三态化 | P1 | 区分支持、需配置、不支持 | 能力状态模型与页面迁移 | 已完成 |
| A5 | 任务态到任务管理层 | P1 | 统一导入/重索引/扫描的队列、取消、恢复 | Task manager 设计与核心链路接入 | 已完成 |
| A6 | 资源页懒加载深化 | P1 | 图库、字体、缓存按需 metadata 和扫描 | 资源 index、分页/展开加载 | 已完成 |
| A7 | 验收矩阵扩展 | P2 | 增加输入方式、动态窗口、高 DPI | 回归 checklist 与自动化补点 | 已完成 |
| A8 | 老页面分批迁移 | P2 | 高频页面逐步收口到基线体系 | 迁移清单、阶段执行记录 | 持续执行（B3 首批完成） |

## 2. A0：基线盘点与冻结

目标：先把“哪些做法不能继续新增”定下来，避免一边优化一边产生新的散点实现。

任务：

- [x] 汇总现有裸 `Scaffold`、直接 `showModalBottomSheet`、直接 `showDialog`、页面内 `Platform.isXxx / kIsWeb`、长列表 `ListView(children)` 的位置。
- [x] 区分“必须整改”“历史保留”“允许例外”的页面。
- [x] 在 review checklist 中增加反模式条目。
- [x] 更新 `tool/check_ui_component_governance.dart`，把新增反模式纳入 warning。

交付物：

- `docs/adaptive_component_coverage_matrix_2026-05-13.md`
- `docs/adaptive_ui_antipatterns_2026-05-13.md`
- `docs/adaptive_legacy_page_migration_inventory_2026-05-13.md`
- 静态检查 warning 项扩展

验收：

- 新增页面不得绕过基线组件而无说明。
- 例外必须写明原因、影响平台和后续回收条件。

## 3. A1：尺寸与 Typography Token

目标：把字号、图标、按钮高度、内容宽度、卡片宽度从散落常量收敛为统一 token。

任务：

- [x] 定义 App UI 字号层级：caption、footnote、subhead、body、bodyLarge、titleSmall、title、titleLarge、headline。
- [x] 定义全局交互尺寸：最小触控目标 44dp，常规按钮高度、图标按钮命中区、列表项最小高度。
- [x] 定义内容宽度阶梯：compact 满宽、medium 约 680dp、expanded 约 820dp，允许设置页、表单页、书架页覆盖。
- [x] 定义书架卡片列宽范围：移动端、平板、桌面分别控制在合理区间，避免桌面拉伸成移动端大卡片。
- [x] 明确系统字体缩放策略：App UI 跟随系统；阅读正文独立；阅读器内 UI 跟随系统但设上限。

交付物：

- `lib/app/theme/app_typography.dart`
- `lib/app/layout/app_size_tokens.dart`
- `docs/adaptive_size_typography_tokens_2026-05-13.md`

验收：

- 新增 UI 不直接写散落字号，除非有组件级注释说明。
- 可点击控件命中区不低于 44dp。
- 设置页、管理页在 1280x800 不无限拉宽。
- 字体缩放 1.3x 下无按钮文字溢出；专项验收覆盖 1.5x。

## 4. A2：基线组件覆盖矩阵

目标：让开发者知道“该用哪个组件”，也允许合理例外。

任务：

- [x] 为页面骨架、内容容器、搜索、筛选、设置项、列表项、空状态、错误态、禁用态、弹层、封面、任务态建立覆盖矩阵。
- [x] 给每类组件标注：必须使用、推荐使用、允许例外。
- [x] 检查组件 API 灵活性，补齐常见自定义能力，如 leading、trailing、actions、dense、desktopHover、keyboardFocus。
- [x] 输出旧页面迁移优先级：书架、阅读器、首页、我的、搜索优先；管理页其次；低频静态页按机会迁移。

交付物：

- 组件覆盖矩阵文档
- 基线组件 API 补强 PR
- UI 反模式文档

验收：

- 新页面 review 能直接对照矩阵判断是否合规。
- 业务页面不再因为基线组件不够灵活而被迫手写整套列表项或弹层。

## 5. A3：阅读器布局上下文

目标：阅读器继续复用全局自适应能力，但拥有阅读场景自己的布局策略。

任务：

- [x] 设计 `ReaderLayoutContext`，从 `AppAdaptiveMetrics` 派生窗口等级、输入方式、正文区域、面板形态。
- [x] 定义文字阅读正文宽度策略：按字符行宽控制，桌面端正文最大宽度默认不超过约 720dp。
- [x] 定义漫画/图像阅读宽度策略：优先利用可用宽度，与文字阅读分离。
- [x] 定义阅读器弹层策略：目录、书签、设置、标注优先使用非阻断式 side panel、popover、半透明浮层，减少桌面全屏 dialog。
- [x] 阅读器分页计算使用同一套字号、行高、边距参数，避免视觉与分页不一致。

交付物：

- `ReaderLayoutContext` / `ReaderSizes` 设计与实现
- 阅读器目录、设置面板接入样板
- 阅读器验收 checklist 更新
- `docs/reader_layout_context_2026-05-13.md`

验收：

- 文字阅读、漫画阅读不共用同一最大宽度策略。
- 桌面/Web 阅读器目录和设置不以移动端 bottom sheet 原样放大。
- 横屏、大字体、窗口缩放后阅读器不遮挡关键操作。

## 6. A4：Capability 三态化

目标：从“能/不能”升级到“可用/需要设置/不可用”，让入口展示更准确。

建议模型：

```text
supported：当前环境可直接使用
needsSetup：平台支持，但需要权限、配置、依赖或登录
unsupported：当前平台或构建配置不支持
```

任务：

- [x] 新增能力状态模型，例如 `AppCapabilityState`。
- [x] 将文件导入、受管文件存储、WebDAV、书源运行时、WebView、图片选择等高风险能力先迁移。
- [x] 明确页面根据状态决定：正常显示、置灰并给引导、隐藏或进入 `FeatureDisabledPage`。
- [x] 旧页面入口按三态 capability 逐步迁移。
- [x] 为 Web、桌面 Linux、移动端权限缺失等场景补降级文案。

交付物：

- capability 三态模型
- 高频入口接入样板
- capability 文档更新
- `docs/app_capability_state_plan_2026-05-13.md`

验收：

- 不再出现“入口可点击但必失败”的体验。
- 需要授权/配置的能力不被误判为 unsupported。
- capability 关闭时不得创建真实重依赖页面。

## 7. A5：任务态到任务管理层

目标：明确 `AppTaskStatusData` 是 UI 状态模型；真正的导入、重索引、扫描需要任务管理层。

任务：

- [x] 设计 `AppTaskController` / `AppTaskManager`，支持任务 id、kind、priority、status stream、cancel、retry。
- [x] 区分任务通道：阅读即时任务、本地导入任务、资源扫描任务、后台维护任务。
- [x] 本地图书导入、重建索引先接入统一任务管理。
- [x] 外部导入接入统一任务管理。
- [x] 图集、主题、字体、缓存扫描第二批接入。
- [x] 设计中断恢复策略：哪些任务可恢复、哪些只提示中断、哪些必须重新开始。

交付物：

- 任务管理层设计文档
- 书籍导入/重索引接入
- 任务队列 UI 样板
- `docs/app_task_manager_plan_2026-05-13.md`

验收：

- 用户导入大量书籍时，打开阅读不被低优先级导入队列阻塞。
- 任务失败、取消、重试有统一展示。
- App 重启后可恢复或解释上次中断任务。

执行记录：

- 2026-05-13：外部文件接收入口、本地图书外部导入、封面/启动/底栏图集导入、字体导入、外部主题导入、缓存扫描和缓存清理已接入 `AppTaskManager`。
- 2026-05-13：任务通道按本地图书导入、资源导入、资源扫描和维护清理拆分，缓存扫描使用后台优先级，导入与清理使用用户触发优先级。
- 2026-05-13：A5 收尾完成，全局任务队列入口和自适应任务面板已接入 Shell；恢复策略落入 `AppTaskRecoveryPolicy`，队列项可显示可恢复/中断提示/需重新开始。

## 8. A6：资源页懒加载深化

目标：资源页继续从“进入页面加载列表”优化到“轻量 index + 可见项/展开项加载 metadata”。

任务：

- [x] 图库服务增加轻量 index，只读 id、名称、数量、首图。
- [x] 图集详情或编辑页再加载完整图片列表和尺寸 metadata。
- [x] 字体管理页首屏只读注册字段，预览、文件大小、校验结果按展开或选中加载。
- [x] 缓存页默认不扫全目录，每个缓存分类单独刷新。
- [x] 大目录扫描接入任务管理层，允许取消、降级和后台完成。

交付物：

- 图库轻量 index API
- 字体 metadata 懒加载样板
- 缓存分类刷新入口

验收：

- App 启动阶段不扫描图库、字体、缓存大目录。
- 资源页面首屏进入不因大图库或大字体库明显卡顿。
- 图片文件不在 build 中同步读取字节。

执行记录：

- 2026-05-13：封面图集、启动图集、底栏图集新增轻量 index；列表页只读 id、名称、数量/预览项，编辑页再加载完整图片/图标列表。
- 2026-05-13：字体管理页首屏不再批量 stat 字体文件；文件可用性和预览字体按用户点击检查后更新。
- 2026-05-13：缓存管理页进入页面不再自动扫描所有存储目录；每个缓存分类提供独立刷新入口，扫描任务写入 `AppTaskManager`。

## 9. A7：验收矩阵扩展

目标：静态尺寸矩阵继续保留，同时增加真实跨端容易出问题的输入方式和动态窗口变化。

任务：

- [x] 输入方式加入：纯触控、触控+键盘、鼠标+键盘、触控笔。
- [x] 动态窗口加入：Android 分屏、iPad Slide Over / Stage Manager、桌面窗口拖拽缩放、折叠屏展开/折叠。
- [x] 桌面加入：hover、右键、Tab 顺序、快捷键、Esc 关闭面板。
- [x] 显示加入：Windows 高 DPI 150%、字体缩放 1.5x、横屏 + 大字体组合。
- [x] 关键页面补 smoke：书架、阅读器、我的、搜索、资源管理页。

交付物：

- `docs/adaptive_visual_regression_checklist.md` 更新
- 关键页面 smoke 测试补点
- 手工验收表

验收：

- `docs/adaptive_visual_regression_checklist.md` 已补输入方式、动态窗口、高 DPI/字体缩放和关键页面 smoke 表。

- 页面布局改动必须说明覆盖了哪些输入方式和窗口变化。
- 阅读器和书架至少覆盖鼠标键盘路径。

## 10. A8：老页面分批迁移

目标：不做一次性大重构，按风险和收益迁移。

优先级：

1. 高频核心页：书架、阅读器、首页、我的、搜索。
2. 管理页：缓存、书签、反馈、图集、字体、标签/分类。
3. 能力页：书源、同步、发现等 capability-gated 页面。
4. 低频静态页：关于、公告、资料。

任务：

- [x] 每批迁移前先写页面清单、影响平台和回归矩阵。
- [x] 优先替换页面骨架、弹层、空状态、长列表，不先动深层业务逻辑。
- [x] 每个页面迁移后更新对应页面计划和执行记录。
- [x] 对无法迁移的页面写例外说明和回收条件。

验收：

- 迁移不改变原有业务路径。
- 每次只迁一个页面或一组同类低风险页面。
- 回归覆盖移动端、桌面/Web、大字体和横屏。

执行记录：

- 2026-05-13：A8-B3 首批选择封面图集、启动图集、底栏图集列表页，不改编辑器深层资源业务；三页保留既有轻量 index、移动单列和 600dp+ 多列网格。
- 2026-05-13：封面图集、启动图集、底栏图集的重命名/删除确认统一迁到 `showAdaptiveActionSurface`，移动端继续底部面板，桌面/Web 使用居中 dialog surface。
- 2026-05-13：`BottomNavIconGalleryPage` 从 `StatefulWidget + Consumer + ProviderScope.containerOf` 收口为 `ConsumerStatefulWidget + provider`，并修正空搜索结果仍展示搜索框，避免空态丢失筛选入口。
- 2026-05-13：资源图集列表页暂保留直接 `Scaffold`，原因是它们依赖透明 AppBar、主题背景和 `extendBodyBehindAppBar`；待 `AdaptivePageScaffold` 支持 backdrop / transparent app bar slot 后回收该例外。
- 2026-05-13：A8-B3 继续迁移资源编辑页；`BottomNavIconGalleryEditorPage` 收口为 `ConsumerStatefulWidget + provider`，封面图集编辑器、启动图集编辑器和阅读背景页的删除确认统一迁到 `showAdaptiveActionSurface`。
- 2026-05-13：图片预览全屏黑底 `showDialog` 本批保留为例外，原因是它承载 `InteractiveViewer` 缩放和沉浸预览，不属于普通操作弹层；后续如新增全屏预览基线组件再回收。
- 2026-05-13：A8-B4 按“两项一组”迁移公告列表和公告详情；公告列表从一次性拼装 `ListView(children)` 改为 `CustomScrollView + SliverList.builder`，公告详情正文最大宽度收窄到设置页内容宽度，避免桌面长文行宽过长。
- 2026-05-13：A8 继续按两项一组迁移关于页与同步历史；`AboutPage` 收口为 `ConsumerStatefulWidget`，`SyncHistoryPage` 任务详情从裸 `showModalBottomSheet` 迁到 `showAdaptiveActionSurface`。
- 2026-05-13：A8 按三个功能模块批量推进：标签/分类管理模块收口到 `ConsumerStatefulWidget` 且重命名/删除走 adaptive surface；书签模块内部详情页增加宽屏内容约束；缓存/字体资源模块将清理确认、明细弹层、字体导入说明和重命名统一迁到 `showAdaptiveActionSurface`。
- 2026-05-13：A8 下一组三模块继续推进：反馈模块将 `FeedbackPage` 收口为 `ConsumerStatefulWidget` 并将相似反馈确认迁到 adaptive surface；错误中心移动日志列表改为 Sliver builder，且低高度横屏降级为移动列表避免 640x360 + 1.3 字体溢出；系统设置恢复默认确认迁到 adaptive surface。会员中心复杂兑换/设备席位面板暂留后续单独迁移。

## 11. 排期建议

建议按 4 个执行批次推进：

| 批次 | 包含阶段 | 建议节奏 | 原因 |
| --- | --- | --- | --- |
| Batch 1 | A0、A1、A2 | 先做 | 先立规则和 token，后续页面迁移才有统一目标 |
| Batch 2 | A3、A4 | 第二批 | 阅读器和 capability 是多端体验的关键边界 |
| Batch 3 | A5、A6 | 第三批 | 任务管理和资源懒加载涉及业务流程，需要在规则稳定后推进 |
| Batch 4 | A7、A8 | 持续执行 | 验收和老页面迁移应贯穿后续迭代 |

不建议一开始就大规模改老页面。更稳妥的顺序是：先补 token、矩阵、反模式和能力状态，再挑书架/阅读器这类高频页面做样板，样板稳定后再扩展到管理页。

## 12. 总体验收口径

本计划完成后，应达到：

- 新页面可以通过覆盖矩阵直接选择组件。
- UI 尺寸来自 token，少量例外有记录。
- 阅读器有独立布局上下文，不被普通页面断点绑死。
- capability 能表达需要授权/配置的中间态。
- 导入、重索引、扫描等任务有统一状态和任务管理边界。
- 资源页不会在启动或首屏无差别扫描大目录。
- UI 回归覆盖尺寸、字体、输入方式、动态窗口和高 DPI。
