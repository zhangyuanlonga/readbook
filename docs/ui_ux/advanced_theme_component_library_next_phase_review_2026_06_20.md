# 高级主题与组件库下一阶段审查

日期: 2026-06-20
分支: `codex/color-system-phase0-3`
范围: 高级主题、组件库、主题资源层、硬编码样式、组件性能、过渡动画、缺省页与状态页
关联文档:

- `docs/code_review_v1.3.0_refactor_roadmap.md`
- `docs/ui_ux/app_component_library_and_advanced_theme_review_2026_06_19.md`

## 1. 总结

这次复查后的判断是: 高级主题方向是正确的，组件库也已经有基础，但还没有进入“稳定 UI Kit + 统一治理”的状态。当前不是缺少组件，而是组件语义、使用边界、截图回归和资源生效规则还没有完全收束。

最需要优先处理的不是继续新增很多视觉能力，而是把现有能力变成可验证、可迁移、可防回归的系统:

1. 修复高级主题外部导入链路的会员 gate 漏洞。
2. 把组件样板页从用户功能入口调整为内部 QA/视觉回归入口。
3. 定义高级主题资源绑定生效矩阵，覆盖启动图、底栏图集、阅读背景、应用背景、封面图集。
4. 建立 `AppStateView`、`AppSurface`、`AppProgress` 和 motion spec，让 loading、empty、error、locked、offline、progress 不再由每个页面自己拼。
5. 先迁移高风险页面的本地 `Container + BoxDecoration`、硬编码圆角、硬编码颜色和页面级 spinner，再逐步提高审计脚本阈值。

## 2. 审查方式

本次复查结合了文档阅读、代码抽样、脚本审计和已有测试结果。

执行过的审计命令:

```bash
dart run tool/check_theme_coverage_audit.dart
dart run tool/check_ui_component_governance.dart
dart run tool/run_phase6_guardrail_audit.dart
```

已复核的核心代码区域:

- 组件基础层: `lib/app/widgets/foundation/`
- 状态组件: `lib/app/widgets/app_empty_state_card.dart`、`lib/app/widgets/app_status_state_card.dart`
- 动效层: `lib/app/motion/app_motion.dart`、`lib/app/motion/app_motion_widgets.dart`
- 自适应组件: `lib/app/widgets/adaptive_*.dart`
- 高级主题列表/编辑/样板页: `lib/features/mine/presentation/advanced_theme_*`、`component_demo_page.dart`
- 资源层: 启动图、底栏图集、阅读背景、应用背景、封面图集相关 service/provider/widget
- 高频页面抽样: Mine、Bookshelf、Reader、Appearance

## 3. 多角色 Review

### 3.1 开发经理视角

当前代码已经把很多“可复用能力”沉到 app 层，例如 `AppButton`、`AppTextField`、`AppDropdownField`、`AppSelectionIndicator`、`AppSkeletonList`、`AdaptiveCard`、`AdaptiveBottomSheet`、`AppMotion`。这说明方向不是散乱开发，而是在向 UI Kit 靠拢。

主要风险在治理闭环:

- 组件可用，但没有组件索引和迁移规则，新页面仍容易继续写本地样式。
- 审计脚本已经能发现问题，但目前仍是 report 模式，没有作为新增代码的硬门禁。
- 高级主题列表页、编辑页、Bookshelf、Reader 仍是超大文件，组件化迁移的成本偏高。
- 部分组件已经抽出，但 API 粒度还偏业务化，例如高级主题资源选择、图库卡片、状态卡片之间仍有重复造型。

建议开发侧下一步用“先收口规则，再迁移页面”的节奏，不要一口气重构 Reader/Bookshelf/Mine。

### 3.2 项目经理视角

这个阶段适合拆成 3 个小里程碑:

- M1: 主题资源与会员边界修正，属于发版前风险控制。
- M2: UI Kit 基座补齐，属于后续页面迁移的前置能力。
- M3: 高频页面分批迁移和截图回归，属于体验一致性提升。

不建议把“全部硬编码清零”作为一个短期目标。当前审计结果里有一部分是合理的固定视觉，例如封面占位图的生成色板、全屏预览遮罩、阅读器翻页动画透明色。更合理的目标是把审计项分成: 必须迁移、允许豁免、需要产品确认。

### 3.3 UI 设计视角

高级主题已经能影响颜色、背景、组件形态、导航、阅读背景、封面资源，但 UI 语言还没有完全统一:

- 卡片、浮层、状态块、资源选择 tile 的圆角和边框存在多个局部版本。
- 空态、错误态、会员锁定态、离线态、进度态没有统一视觉语义。
- 组件样板页覆盖了控件，但还缺“真实页面模式”的样板，例如主题卡、书籍卡、书源卡、阅读设置行、图库 tile。
- 主题资源绑定缺少一张产品可读的生效说明，尤其启动图和底栏图集需要明确“只通过高级主题绑定生效”，不再支持单独设置。

UI 设计侧建议先出一版“App UI Kit v0.1 组件索引”，重点不是画新稿，而是明确哪些组件是标准件，哪些页面局部写法必须替换。

### 3.4 产品经理视角

当前高级主题的产品价值已经比较完整: 官方主题免费、自定义高级主题会员、主题可以绑定字体/背景/导航/启动图/封面资源。这是一个可以包装成会员权益的体系。

产品风险主要有两个:

- 权益边界: 普通用户应该能使用官方主题，但不能通过外部分享导入绕过自定义主题会员限制。
- 预期边界: 启动图、底栏图集、阅读背景、应用背景、封面图集的生效入口需要在产品逻辑里固定，否则后续客服和测试都会反复遇到“为什么没生效”的问题。

产品侧下一步建议补一张“资源绑定生效入口 + 用户可见文案”表，先进入需求说明，再进入代码。

## 4. 当前组件库盘点

### 4.1 已有基础组件

| 层级 | 已有组件 | 现状 |
|---|---|---|
| 操作 | `AppButton`、`AppMenuButton`、`AppContextMenu`、`AppBatchActionBar` | 已有 loading、danger、tonal 等基础形态，但页面里仍有不少原生按钮 |
| 表单 | `AppTextField`、`AppDropdownField` | 主题 token 已接入，资源页仍有局部 `TextField` |
| 选择 | `AppSelectionIndicator` | 已用于主题选择，chip/segmented/toggle 还需要统一 |
| 状态 | `AppEmptyStateCard`、`AppStatusStateCard` | 已存在，但 loading/locked/offline/progress 没有统一入口 |
| 骨架 | `AppSkeletonBlock`、`AppSkeletonList` | 接入 `AppMotion.enabledOf`，能随系统禁用动画 |
| 容器 | `AdaptiveCard`、`AdaptiveContentContainer`、`AdaptivePageScaffold` | 有基础，但 Mine/Reader/Bookshelf 仍大量本地容器 |
| 列表 | `AdaptiveListTile`、`AdaptiveSettingTile`、`AppReorderableList` | 设置页较好，业务列表仍有大量专用实现 |
| 弹层 | `AdaptiveBottomSheet`、`showAdaptiveActionSurface` | 方向正确，个别资源选择 sheet 仍有局部布局和按钮 |
| 动效 | `AppMotion`、`AppAnimatedSwitcher`、`AppFadeSlideTransition`、`AppPressable` | 具备基础 motion token，但使用面还不完整 |
| 图片资源 | `ResolvedBookCover`、`TextCoverPlaceholder`、`BottomNavIconView` | 能支撑主题资源，但占位封面色板需要豁免规则 |

### 4.2 组件库缺口

现在最缺的不是按钮和输入框，而是更上层的复合组件:

| 缺口 | 建议新增/收敛 | 用途 |
|---|---|---|
| 页面状态 | `AppStateView` | 统一 loading、empty、error、locked、offline、progress、content |
| 表面容器 | `AppSurface` / `AppPanel` / `AppSection` | 替换散落的 `Container + BoxDecoration` |
| 进度反馈 | `AppProgressIndicator` / `AppInlineProgress` / `AppBlockingProgressCard` | 替换页面级裸 `CircularProgressIndicator` |
| 资源 tile | `AppImageResourceTile` / `AppResourcePickerGrid` | 统一启动图、封面图、阅读背景、底栏图集选择 |
| 业务卡片 | `BookCard`、`ThemeCard`、`SourceCard`、`ReaderSettingRow` | 让业务页面共享主题和状态语义 |
| 视觉 QA | `ComponentGalleryPage` 内部化 | 按 light/dark、主题 preset、状态、动效做截图基线 |

## 5. 硬编码与未统一组件审计

### 5.1 脚本结果

`tool/check_theme_coverage_audit.dart` 结果:

| 指标 | 数量 |
|---|---:|
| 扫描文件 | 175 |
| 高风险文件 | 8 |
| `border-radius` | 592 |
| `local-alpha` | 586 |
| `box-decoration` | 408 |
| `hardcoded-color` | 146 |
| `material-color` | 111 |
| `shape-property` | 86 |
| `rounded-shape` | 40 |
| `box-shadow` | 32 |

`tool/check_ui_component_governance.dart` 结果:

| 类型 | 数量 |
|---|---:|
| 总 findings | 1144 |
| `hardcoded-style` | 923 |
| `loading-state` | 57 |
| `platform-branch` | 51 |
| `list-children` | 46 |
| `scaffold` | 40 |
| `list-performance` | 8 |
| `missing-doc` | 8 |
| `capability-wrapper` | 5 |
| `layout-builder` | 5 |
| `modal-surface` | 1 |

这说明“硬编码未统一”确实存在，而且不是少量。好消息是脚本已经能定位问题，下一步可以从 report 模式进入分级治理。

### 5.2 高风险文件解读

| 文件 | 审计结论 | 建议 |
|---|---|---|
| `lib/features/mine/presentation/component_demo_page.dart` | score 263，硬编码最多。主要来自 Lumina 固定基线和样板布局 | 内部 QA 页可以保留固定基线，但不要作为普通用户功能入口；将 Lumina 配置改为官方 preset 复用 |
| `lib/app/widgets/text_cover_placeholder.dart` | score 190，封面生成色板大量 `Color(0x...)` | 这是“生成封面艺术色板”，不应简单改成主题色；建议加审计豁免和可选主题色策略 |
| `lib/features/mine/presentation/mine_page_view.dart` | score 109，Mine 首页局部卡片、阴影、alpha 较多 | 优先迁移到 `AppSurface/AppSection`，减少首页视觉漂移 |
| `lib/features/bookshelf/presentation/bookshelf_page.dart` | score 78，高频页面且文件巨大 | 暂不大改业务逻辑，先抽可复用表面、空态、进度态 |
| `lib/features/reader/presentation/reader_page.dart` | score 76，阅读器有固定色和本地 chrome | 阅读器需要保留部分专用视觉，但 chrome/overlay 可接入 motion 和 surface token |
| `lib/features/bookshelf/presentation/widgets/bookshelf_taxonomy_picker_surface.dart` | score 67，分类选择面板局部样式多 | 迁移到统一 picker/sheet surface |
| `lib/features/reader/presentation/widgets/chrome/reader_overlay_bars.dart` | score 67，阅读器浮层本地 alpha/阴影多 | 建议引入 `ReaderChromeTokens` 或复用 overlay tokens |
| `lib/features/mine/presentation/advanced_theme_list_page.dart` | score 65，列表页仍有本地容器与进度 | 继续拆分导入导出 surface，复用 `AppProgress`、`AppStateView` |

### 5.3 可以豁免的硬编码

不是所有 `Color(0x...)` 都应该清掉。建议建立豁免清单:

| 类型 | 示例 | 原因 |
|---|---|---|
| 生成封面色板 | `TextCoverPlaceholder` | 封面占位图本质是内容资产，不完全跟随 App 主题 |
| 全屏预览遮罩 | `AdaptiveFullscreenPreview` 黑色遮罩 | 预览图片时需要固定阅读性和沉浸感 |
| 翻页动画透明色 | reader paged animation | 渲染管线需要透明层，不是界面主题色 |
| 官方主题基线 | Lumina/官方 preset | 应保留，但最好来自 preset 数据，而不是散在样板页 |

### 5.4 需要迁移的硬编码

这些应进入下一阶段治理:

- 页面卡片、设置卡、资源 tile 的 `BorderRadius.circular(...)`
- `BoxDecoration` 里的 surface、border、shadow 组合
- blocking loading 的裸 `CircularProgressIndicator`
- 会员锁定、离线、错误、筛选空的局部状态块
- 资源选择页里的本地空态、选中态、角标、搜索框样式

## 6. 组件性能审查

### 6.1 已有正向实践

- 资源选择网格使用 `GridView.builder`，不是一次性 children。
- Reader 文本渲染、背景层、书架关键渲染区已有 `RepaintBoundary`。
- `AppSkeletonBlock` 会在 `MediaQuery.disableAnimations` 或 `AppMotionScope` 禁用时停止 shimmer。
- `ResolvedBookCoverView` 对图片使用 `cacheWidth/cacheHeight` 参数，有利于减少内存。
- 底栏图集、启动图、封面图集都有 service/provider 层，并有部分单测覆盖。

### 6.2 性能风险

| 风险 | 位置/模式 | 说明 | 建议 |
|---|---|---|---|
| 大文件导致重建边界不清 | Bookshelf、Reader、AdvancedThemeList、AdvancedThemeEditor | 超大页面里状态、布局、任务流混在一起，局部 setState 容易扩大 rebuild | 继续按 surface/widget/controller 拆分，新增组件用 `const` 和明确 key |
| `ListView(children)` 治理项较多 | 审计为 46 条 | 短设置列表可接受，长列表/资源列表不应使用 | 给每条 finding 标注“短列表豁免/必须 builder” |
| 页面级 spinner 过多 | 审计为 57 条 | 裸 spinner 缺少错误、重试、空态、权限语义 | 用 `AppStateView` 替换 blocking loading |
| 背景图 blur 成本 | `AdvancedThemeBackdropDecoration`、Reader background | 全屏图片 blur 会触发 saveLayer，低端机可能掉帧 | 给 blur 加档位限制，默认关闭或低强度；截图和 profile 验证 |
| 空态图标循环动画 | `AppEmptyStateCard` | 适合单个空态，不适合列表中大量重复 | 增加 `animateIcon` 或由 `AppStateView` 控制 |
| 主题预览图片缓存 | `AdvancedThemePreviewImageCache`、backdrop cache | 有缓存，但需要确认删除资源后是否清理 | 删除/替换资源时统一 evict 和 cache clear |

### 6.3 性能优先级

短期不建议直接追求“所有列表 builder 化”。建议优先处理:

1. 高频页面 blocking 状态统一，减少重复布局和 rebuild。
2. 资源图集页面确认缩略图尺寸、cacheWidth/cacheHeight 和文件失效清理。
3. Reader/Bookshelf 的动画与背景 blur 做 profile 验证。
4. 为长列表和可增长列表加 key、builder、RepaintBoundary。

## 7. 过渡动画与 Motion 审查

### 7.1 已有能力

`AppMotion` 已经定义:

- `fast`: 120ms
- `medium`: 180ms
- `slow`: 260ms
- `page`: 300ms
- `standard`、`emphasized`、`decelerate`、`accelerate`
- `AppMotion.enabledOf(context)` 会读取 `MediaQuery.disableAnimations`

已有动效组件:

- `AppAnimatedSwitcher`
- `AppFadeSlideTransition`
- `AppStaggeredEntrance`
- `AppPressable`
- `AppLoadingStateSwitcher`
- `AppAnimatedStatusCard`

这块的基础是好的。

### 7.2 当前缺口

| 缺口 | 说明 |
|---|---|
| motion spec 没有文档化 | 不知道页面进入、弹层、卡片、状态切换分别用哪个 duration/curve |
| 本地 `AnimatedContainer` 仍较多 | app/widgets 和业务页面都有自己的动画参数 |
| 长列表入场动画需要约束 | `AppFadeSlideTransition` 用在列表时要限制数量，避免每项都做重动画 |
| 主题切换 reveal 缺少截图/录屏基线 | 主题变更后的 token 是否完整同步，需要自动化或半自动验收 |
| 减少动画策略没有组件级验收 | `disableAnimations` 已接入，但需要 widget test 覆盖关键组件 |

### 7.3 建议 motion 标准

| 场景 | 建议 |
|---|---|
| 页面进入 | `AppMotion.page` + fade/slide，统一 route transition |
| 内容状态切换 | `AppAnimatedSwitcher`，loading/empty/error/content 用 key 区分 |
| 卡片入场 | 仅首屏或短列表允许 stagger，长列表只做轻量 fade 或无动画 |
| 按压反馈 | 统一 `AppPressable` 或组件内读取 `AppMotion.fast` |
| 弹层 | `AdaptiveBottomSheet` 内统一过渡，不在业务页面重复写 |
| 主题切换 | 保留 reveal，但需要验证所有组件 token 切换完整 |
| 减少动画 | 所有 App 组件读取 `AppMotion.enabledOf` |

## 8. 缺省页与状态页审查

### 8.1 当前状态

已有:

- `AppEmptyStateCard`
- `AppStatusStateCard`
- `AppSkeletonBlock`
- `AppSkeletonList`
- `AppLoadingStateSwitcher`
- 业务状态组件，例如 private book source、advanced theme list 的状态块

缺口:

- 没有统一 `AppStateView`。
- loading/empty/error/locked/offline/progress 没有枚举语义。
- 页面级 spinner 仍较多。
- 会员锁定页、离线页、权限不足页还没有统一语义。
- 缺省页没有和截图基线绑定。

### 8.2 建议统一状态模型

建议新增:

```dart
enum AppViewStateKind {
  loading,
  refreshing,
  empty,
  filteredEmpty,
  error,
  locked,
  offline,
  progress,
  content,
}
```

并提供:

- `AppStateView`
- `AppStateScaffold`
- `AppBlockingProgressCard`
- `AppInlineProgress`
- `AppRetryAction`

状态页必须支持:

- 标题、说明、图标
- 主操作、次操作
- 错误诊断复制入口
- 紧凑/完整模式
- 是否显示 skeleton
- 是否允许刷新

## 9. 高级主题资源绑定矩阵

### 9.1 当前资源能力

| 资源 | 当前实现 | 审查结论 |
|---|---|---|
| 启动图 | `LaunchImageGalleryService`，有启动快照、默认内置图和独立 active gallery 逻辑 | 需要精简为“资源库 + 高级主题绑定生效”，移除独立启用/设为当前路径 |
| 底栏图集 | `effectiveBottomNavIconGalleryProvider` 当前会读取显式 active gallery | 需要精简为“资源库 + 高级主题绑定生效”，不再支持用户单独设置底栏图集 |
| 阅读背景 | `ReaderSettingsResolutionService` + Reader visual overrides | 主题可绑定，但用户视觉 override 优先级已经存在，需要文案说明 |
| 应用背景 | `AppBackgroundService` + `AdvancedThemeBackdropDecoration` | 主题控制 App 背景，页面接入不完全一致 |
| 封面图集 | `ResolvedBookCover` | 当前优先级是自定义封面 > 真实封面 > 主题封面图集 > 文字占位 |

### 9.2 建议产品生效规则

| 资源 | 建议规则 | 用户可理解文案 |
|---|---|---|
| 启动图 | 只由当前高级主题绑定的启动图集生效；未绑定则不展示自定义启动图，保留系统/默认启动体验 | “启动图跟随当前高级主题” |
| 底栏图集 | 只由当前高级主题绑定的底栏图集生效；未绑定则使用默认/系统底栏图标 | “底栏图标跟随当前高级主题” |
| 阅读背景 | 阅读器内单书/全局覆盖 > 主题绑定阅读背景 > 默认阅读背景 | “阅读器里单独设置的背景优先生效” |
| 应用背景 | 当前高级主题背景 > 默认主题背景；不提供独立全局 app background 覆盖主题 | “主题会控制 App 背景” |
| 封面图集 | 单书自定义封面 > 书源真实封面 > 主题封面图集 > 文字封面 | “主题封面只在书籍没有封面时补位” |

### 9.3 资源层风险

- 启动图、底栏图集、封面图集已有测试，但需要按“启动图/底栏仅主题绑定生效”的新规则重写相关断言。
- App 背景在多个页面自行 resolve backdrop，接入面需要清点。
- 阅读背景同时存在主题绑定和 reader visual override，产品文案必须解释优先级。
- 资源删除时，需要统一处理引用清理、缓存清理、预览图失效。
- 旧的启动图 active gallery、启动图开关、底栏 active gallery 需要迁移或忽略，避免和高级主题绑定并存。
- 高级主题导入/导出包含资源包，会员 gate 必须在所有入口一致。

## 10. 具体问题清单

### P1: 外部主题导入可能绕过会员 gate

位置:

- `lib/features/mine/presentation/advanced_theme_list_page.dart`
- `_importFromExternalPayload(...)`

现状:

- UI 上的批量导入、导出等入口会调用 `_guardCustomThemeAction(...)`。
- 外部分享/系统打开进入 `_consumePendingExternalImportPayloads()` 后，会直接调用 `_importFromExternalPayload(...)`。
- 该路径没有在方法入口处再次校验会员权益。

风险:

- 非会员可能通过外部文件分享触发自定义主题导入。

建议:

- 在 `_importFromExternalPayload` 方法开头调用统一 guard。
- 更好的做法是在 `AdvancedThemeImportController` 或 service/use case 层做能力校验，避免 UI 新入口再次遗漏。
- 补测试覆盖外部导入路径。

### P1: 组件样板页暴露给普通用户不合适

位置:

- `lib/features/mine/presentation/about_page.dart`
- `lib/features/mine/routes.dart`
- `lib/features/mine/presentation/component_demo_page.dart`

现状:

- 关于页有“组件样板”入口。
- 路由包含内部组件样板入口；当前实现已收敛为 `/appearance/component-demo`，固定 Lumina 视觉基线。
- 页面内有大量 QA 说明、示例数据和 Lumina 固定视觉。

风险:

- 用户会把内部组件 QA 页理解成正式功能。
- 审计脚本会把 Lumina 基线页识别成生产硬编码。

建议:

- 关于页移除入口，或仅 debug/internal build 暴露。
- 保留路由给内部 QA，但加 feature flag。
- 样板页的 Lumina 配置改为复用 `app_official_theme_presets.dart`，减少复制色值。

### P1: 资源绑定生效规则需要落文档和测试

现状:

- 当前底栏图集和启动图仍存在独立 active/开关路径，和高级主题绑定并存后逻辑复杂。
- 封面图集、应用背景更接近“资源库 + 主题绑定生效”的模式。
- 需要把启动图、底栏图集也收敛为同样模式，并补测试覆盖旧配置迁移、主题绑定、未绑定 fallback、删除资源。

建议:

- 先把本审查文档里的矩阵转成产品/测试用例。
- 再补 service/provider 层单测。
- 最后补组件样板/截图验证。

### P2: 状态组件没有统一入口

现状:

- 有 `AppEmptyStateCard`、`AppStatusStateCard`、`AppSkeletonList`。
- 但页面级 spinner 和局部状态块仍多。

建议:

- 新增 `AppStateView`。
- 先迁移 AdvancedThemeList、图库页、Appearance 页、Mine 页。
- Reader/Bookshelf 等高风险页面只迁移外围状态，不动核心阅读逻辑。

### P2: 高风险硬编码页面需要迁移计划

优先顺序:

1. `advanced_theme_list_page.dart`
2. `mine_page_view.dart`
3. `advanced_theme_resource_picker_widgets.dart`
4. `bookshelf_taxonomy_picker_surface.dart`
5. `reader_overlay_bars.dart`
6. `bookshelf_page.dart` 外围卡片和空态
7. `reader_page.dart` 外围 chrome 和状态

迁移目标:

- 用 `AppSurface/AppSection` 替换本地卡片。
- 用 `AppStateView` 替换页面级状态。
- 用 `AppProgress` 替换 blocking spinner。
- 用 component tokens 替换硬编码 radius/shadow/border。

### P2: 审计脚本需要进入分级门禁

建议:

- 先保留 report 模式作为趋势数据。
- 对新增文件启用严格规则。
- 对历史高风险文件建立 baseline，不要求一次清零。
- 对豁免项必须写理由，例如封面生成色板、全屏预览遮罩。

## 11. 阶段性改造任务

本节把前面的 review 结论拆成可勾选、可排期、可验收的任务。建议按阶段顺序推进，除非线上缺陷要求插队。

### Phase 0: 基线冻结与任务建档

目标: 先把审计结果、豁免项和验收口径固定下来，避免后续迁移时范围漂移。

预计周期: 0.5-1 天

- [x] T0.1 固化当前审计基线。
  范围: 保存 `check_theme_coverage_audit`、`check_ui_component_governance`、`run_phase6_guardrail_audit` 的当前结果。
  输出: 在本目录新增或更新一份 baseline 记录，包含高风险文件、finding 总数、豁免策略。
  验收: 后续任务能以这份 baseline 判断“新增问题”和“历史债务下降”。

- [x] T0.2 给硬编码审计建立分类规则。
  范围: 将 findings 分为 `必须迁移`、`允许豁免`、`需要产品确认` 三类。
  重点: `TextCoverPlaceholder`、全屏图片预览遮罩、Reader 翻页透明色、官方主题基线色值先进入豁免候选。
  验收: 每个高风险文件都有处理策略，不再只看 finding 数字。

- [x] T0.3 形成阶段任务看板。
  范围: 将本节 T1-T7 任务同步到项目任务系统或维护为 Markdown checklist。
  验收: 每个任务都有负责人、预估周期、验收命令、回滚方式。

- [x] T0.4 确认不改动高风险核心链路的原则。
  范围: Reader 正文渲染、Bookshelf 核心书籍数据流、主题导入导出文件格式。
  验收: 后续 UI 迁移优先从外围组件和状态层开始，不在同一阶段重写核心业务。

### Phase 1: 权益边界与入口治理

目标: 先修正可能影响会员权益、用户预期和 QA 入口定位的问题。

预计周期: 1-2 天

- [x] T1.1 修复外部主题导入会员 gate。
  范围: `AdvancedThemeListPage._importFromExternalPayload`、`AdvancedThemeImportController` 或更靠近 use case 的导入入口。
  实现要求: 外部分享、系统打开、待消费 payload 三条路径都必须经过 `hasThemeCustom` 权益判断。
  验收: 非会员触发外部主题导入时不会写入自定义主题，并展示明确提示。
  测试: 补外部 payload 导入的会员/非会员单测或 widget test。

- [x] T1.2 收敛组件样板页入口。
  范围: `about_page.dart`、`routes.dart`、`component_demo_page.dart`。
  实现要求: 普通用户侧不再从关于页看到“组件样板”；保留 debug/internal QA 入口或通过 feature flag 暴露。
  验收: release 普通入口不可见，内部仍能访问当前主题样板和 Lumina 基线样板。

- [x] T1.3 将 Lumina 样板配置改成复用官方 preset。
  范围: `component_demo_page.dart` 与 `app_official_theme_presets.dart`。
  实现要求: 减少样板页内重复 `Color(0x...)`，让固定基线来自官方主题数据。
  验收: 组件样板页在 Lumina 模式下视觉不回归，审计中样板页硬编码数量下降或有明确豁免。

- [x] T1.4 补会员边界回归测试。
  范围: 创建、编辑、复制、导入、批量导入、导出、批量导出、删除、启用自定义主题。
  实现要求: 页面 guard 和 service/use case gate 至少覆盖一层，优先补容易绕过 UI 的入口。
  验收: 非会员不能通过隐藏入口、外部文件或批处理路径完成会员专属操作。

- [x] T1.5 整理用户提示文案。
  范围: 自定义主题会员提示、外部导入失败、组件样板入口隐藏后的替代说明。
  实现要求: 文案区分“官方主题可免费使用”和“自定义主题需要会员”。
  验收: 用户不会误以为高级主题功能整体被锁。

### Phase 2: 高级主题资源绑定矩阵

目标: 把启动图、底栏图集、阅读背景、应用背景、封面图集的生效入口写成产品规则、测试规则和代码规则；其中启动图和底栏图集改为仅通过高级主题绑定生效。

预计周期: 2-3 天

- [x] T2.1 精简启动图生效规则。
  建议规则: 启动图只由当前高级主题绑定的 `launchImageGalleryId` 生效；未绑定则不展示自定义启动图，保留系统/默认启动体验。
  范围: `LaunchImageGalleryService`、启动快照更新、主题启用/切换后同步、启动图集页面入口。
  改造要求: 移除或废弃独立启动图开关、独立 active gallery、设为当前等入口；资源页只负责图库管理和主题引用提示。
  验收: 切换主题时启动图跟随主题绑定；用户不能在启动图集页单独设置当前启动图。
  测试: 增加“主题绑定生效”“未绑定 fallback”“旧 active gallery 被忽略或迁移清理”“删除被绑定图集后 fallback”的单测。

- [x] T2.2 精简底栏图集生效规则。
  建议规则: 底栏图集只由当前高级主题绑定的 `bottomNavGalleryId` 生效；未绑定则使用默认/系统底栏图标。
  范围: `effectiveBottomNavIconGalleryProvider`、底栏图集 service、底栏图集页面入口。
  改造要求: 移除或废弃独立 active gallery、设为当前等入口；资源页只负责图库管理和主题引用提示。
  验收: 用户不能在底栏图集页单独设置当前底栏图标；底栏图标只随当前高级主题变化。
  测试: 重写旧的 active gallery 优先级测试，改为验证旧 active gallery 被忽略或迁移清理。

- [x] T2.3 固化阅读背景优先级。
  建议规则: 阅读器内 visual override > 主题绑定阅读背景 > 阅读器默认背景。
  范围: `ReaderSettingsResolutionService`、`reader_page_content_rendering.dart`、`reader_page_background.dart`。
  验收: 用户在阅读器内手动设置背景后，切换主题不会意外覆盖用户覆盖项。
  测试: 补 visual override 与 theme reader wallpaper 冲突测试。

- [x] T2.4 固化应用背景优先级。
  建议规则: 当前高级主题 app wallpaper > 主题默认背景；如果未来增加全局手动 app background，需要单独确认是否覆盖主题。
  范围: `AppBackgroundService`、`AdvancedThemeBackdropDecoration`、Mine/Appearance/Book/Reader 外围页面 backdrop 接入。
  验收: 已接入高级主题背景的页面列表明确，未接入页面有后续任务。

- [x] T2.5 固化封面图集优先级。
  当前规则: 单书自定义封面 > 书源真实封面 > 主题封面图集 > 文字封面。
  范围: `ResolvedBookCover`、书架卡片、详情页封面展示。
  验收: 主题封面只在书籍没有封面时补位，不覆盖用户自定义封面和真实封面。

- [x] T2.6 建立资源删除与失效回收规则。
  范围: app background、reader background、launch gallery、bottom nav gallery、cover gallery。
  实现要求: 删除资源时处理引用清理、fallback、图片缓存 evict、主题引用提示。
  验收: 删除被主题引用的资源不会造成空白图、异常路径或无限 loading。

- [x] T2.7 输出资源绑定产品说明。
  范围: 外观页、资源页、主题编辑页的说明文案和测试用例。
  验收: QA 能按一张矩阵覆盖全部资源生效路径，并明确启动图/底栏没有独立设置入口。

### Phase 3: UI Kit 基座补齐

目标: 先补标准件，再迁移页面，避免每个页面继续各写各的状态、表面、进度和动效。

预计周期: 3-5 天

- [x] T3.1 新增 `AppStateView`。
  范围: `lib/app/widgets/` 或 `lib/app/widgets/foundation/`。
  支持状态: loading、refreshing、empty、filteredEmpty、error、locked、offline、progress、content。
  实现要求: 支持 icon、title、description、primary action、secondary action、retry、diagnostics footer、compact 模式。
  验收: 可替代 `AppEmptyStateCard`、`AppStatusStateCard` 和 blocking spinner 的组合场景。

- [x] T3.2 新增 `AppSurface`、`AppPanel`、`AppSection`。
  范围: app widgets 基础层。
  实现要求: 统一 radius、border、shadow、padding、background，并读取 `AppComponentThemeTokens`。
  验收: 能覆盖高级主题卡片、资源 tile、Mine 首页卡片、设置分组。

- [x] T3.3 新增进度组件族。
  组件建议: `AppProgressIndicator`、`AppInlineProgress`、`AppBlockingProgressCard`、`AppTaskProgressRow`。
  实现要求: 替代裸 `CircularProgressIndicator`，支持语义 label、进度文本、取消/重试动作。
  验收: 新组件可用于导入、导出、同步、下载、解析、批处理。

- [x] T3.4 补齐 motion spec。
  范围: 新增 `docs/ui_ux/app_motion_spec_*.md` 或纳入组件库文档。
  内容: 页面进入、弹层、卡片入场、状态切换、按压反馈、主题 reveal、禁用动画。
  验收: 新组件默认读取 `AppMotion`，明确长列表不做全量重动画。

- [x] T3.5 增加组件 widget tests。
  范围: `AppStateView`、`AppSurface`、`AppProgress`、`AppMotion` 相关组件。
  测试要求: light/dark、disableAnimations、长文案、紧凑模式、按钮 loading。
  验收: 基础组件变更有测试保护。

- [x] T3.6 建立组件索引表。
  范围: 组件名、使用场景、替代旧写法、主题 token 依赖、是否允许业务自定义。
  验收: 开发新增页面时能查到应该使用哪个组件。

阶段 0-3 执行记录:

- 新增 `docs/ui_ux/advanced_theme_component_library_baseline_2026_06_20.md`，记录 theme coverage、Phase 6 guardrail、UI governance 参考基线和豁免分类。
- 新增 `docs/ui_ux/app_motion_spec_2026_06_20.md`，明确状态切换、页面进入、长列表动画和 reduced motion 规则。
- 新增 `docs/ui_ux/app_ui_kit_v0_1_component_index_2026_06_20.md`，列出新增/已有基础组件和迁移优先级。
- 外部高级主题导入已补会员 gate；组件样板入口仅 debug 可见；Lumina 样板改为复用官方 preset。
- 启动图和底栏图集已改为“资源库 + 高级主题绑定生效”：页面移除开关/设为默认，底栏 provider 忽略旧 active gallery，启动快照只由当前自定义高级主题绑定生成。
- 已新增 `AppStateView`、`AppSurface/AppPanel/AppSection`、`AppProgressIndicator/AppInlineProgress/AppBlockingProgressCard/AppTaskProgressRow`，并补 foundation widget tests。
- 新增 `docs/ui_ux/advanced_theme_membership_and_resource_binding_matrix_2026_06_20.md`，把会员 gate 文案、资源绑定生效规则、删除回收规则和测试映射收敛成 QA 矩阵。
- 会员 gate 文案已集中到 `AdvancedThemeMembershipGateCopy`，并补测试覆盖创建、编辑、复制、导入、导出、删除、启用和批处理动作。
- 阅读背景、应用背景、封面图集和资源删除回收规则已补对应 service/token/widget tests；Phase 0-3 已闭环，后续从 Phase 4 开始推进视觉回归。

### Phase 4: 组件样板与视觉回归

目标: 把组件样板页从“能看”升级为“能验收、能截图、能防回归”的内部工具。

预计周期: 3-5 天

- [x] T4.1 内部化组件样板页。
  范围: 路由、入口、debug/internal flag。
  验收: release 用户不可见，内部 QA 可直接访问。

- [x] T4.2 扩展样板状态覆盖。
  范围: `component_demo_page.dart`。
  新增覆盖: locked、offline、progress、filtered empty、retry error、destructive action、disabled dependency。
  验收: `AppStateView` 的所有状态都能在样板页看到。

- [x] T4.3 增加业务模式组件样板。
  范围: book card、theme card、source card、reader setting row、image resource tile、task card。
  验收: 高级主题切换后，业务组件视觉跟随 token。

- [x] T4.4 建立截图矩阵。
  主题: Lumina、Mono Blue、Ink Green、Selune Warm。
  模式: light/dark。
  视口: mobile/desktop。
  验收: 每个截图页面都有固定路由、固定测试数据、固定 viewport。

- [x] T4.5 增加截图回归脚本。
  范围: 可使用 Flutter integration test、golden test 或后续 Playwright/浏览器截图方案。
  验收: 至少覆盖组件样板页、我的页、外观页、高级主题列表页、资源页、阅读器设置浮层。

- [x] T4.6 记录视觉验收差异。
  范围: 主题色、边框、圆角、阴影、状态、动效、长文本换行。
  验收: 每次视觉差异都有“接受/修复/豁免”结论。

### Phase 5: Mine 与高级主题资源页迁移

目标: 先迁移高级主题最相关、风险较低、收益明显的页面。

预计周期: 1 周

- [x] T5.1 迁移 `advanced_theme_list_page.dart` 外围状态。
  范围: loading、empty、error、saving progress、import/export progress。
  实现要求: 用 `AppStateView` 和 `AppProgress` 替代页面级 spinner 和本地状态卡。
  验收: 列表加载、筛选空、导入中、导入失败、导出中都有统一状态表现。

- [x] T5.2 迁移高级主题卡片 surface。
  范围: `AdvancedThemeSummaryCard`、官方主题卡片、状态 bubble。
  实现要求: 使用 `AppSurface/AppSection` 和 component tokens。
  验收: theme coverage 中 `advanced_theme_list_page.dart` 与相关 widget 的 radius/box-decoration findings 下降。

- [x] T5.3 迁移高级主题资源 picker。
  范围: `advanced_theme_resource_picker_widgets.dart`、启动图/封面/底栏/阅读背景选择 sheet。
  实现要求: 统一选择态、空态、角标、预览 tile、长按预览。
  验收: 所有资源 picker 视觉一致，且仍使用 `GridView.builder`；启动图和底栏 picker 只在高级主题编辑/绑定流程中出现。

- [x] T5.4 迁移启动图集页。
  范围: `launch_image_gallery_page.dart`、editor page、相关状态和搜索框。
  改造要求: 页面只保留图库管理能力，移除独立启用、关闭、设为当前、当前启动图等自配置入口。
  验收: 空图集、搜索空、导入中、导入失败、主题引用 badge 都使用统一组件；用户只能通过高级主题绑定使用启动图集。

- [x] T5.5 迁移底栏图集页。
  范围: `bottom_nav_icon_gallery_page.dart`、editor page。
  改造要求: 页面只保留图库管理能力，移除独立设为当前、当前底栏图集等自配置入口。
  验收: 图标缺省、主题引用、选中态、编辑态和导入进度统一；用户只能通过高级主题绑定使用底栏图集。

- [x] T5.6 迁移封面图集页。
  范围: `cover_gallery_page.dart`、editor page、封面资源 tile。
  验收: 删除/引用/空态/搜索态统一；不改变 `ResolvedBookCover` 优先级。

- [x] T5.7 迁移阅读背景页。
  范围: `reader_background_page.dart`、高级主题绑定入口。
  验收: 阅读背景素材、主题引用 badge、空态、预览、导入进度统一。

- [x] T5.8 迁移 Mine 首页卡片。
  范围: `mine_page_view.dart` 中 profile card、action section、appearance/data/other cards。
  实现要求: 用 `AppSurface/AppSection` 替换本地容器和阴影。
  验收: Mine 首页 theme coverage score 下降，布局不回归。

- [x] T5.9 复跑高级主题资源测试。
  范围: official theme activation、advanced theme list loading、bottom nav provider、launch gallery、resolved cover、reader wallpaper。
  验收: 资源绑定和高级主题启用不回归。

阶段 4-5 执行记录:

- 组件样板页已内部化到 debug/internal 路由: 关于页入口和路由层均避免 release 普通用户访问，并收敛为单一 Lumina 基线。
- `component_demo_page.dart` 已补齐 `AppStateView` 状态矩阵，覆盖 locked、offline、progress、filtered empty、retry error、destructive action、disabled dependency。
- 组件样板页已新增业务模式样板: 书籍卡、主题卡、书源卡、阅读设置行、资源 tile、任务卡。
- 新增 `docs/ui_ux/advanced_theme_visual_regression_matrix_2026_06_20.md`，固定截图页面、主题、模式、视口和差异记录规则。
- 新增 `test/features/mine/presentation/component_demo_visual_matrix_test.dart`，覆盖 Lumina 样板在 mobile/desktop 下的自动化渲染入口。
- `AdvancedThemeSummaryCard`、官方主题卡、会员提示、保存/批量导入进度已迁移到 `AppSurface/AppStateView/AppProgress`。
- `advanced_theme_resource_picker_widgets.dart` 已统一资源选择空态和 image tile surface，继续保留 `GridView.builder` 和长按预览能力。
- 启动图集、底栏图集、封面图集、阅读背景页已迁移 loading、empty、主题引用 badge、预览 tile 和管理卡片；启动图/底栏仍只通过高级主题绑定生效，不恢复独立配置入口。
- Mine 首页 action section、grid/list tile、profile card 外层已接入 `AppSurface`；不改动账号、会员、导航和刷新业务流。
- 本阶段保留合理固定视觉豁免: 封面占位生成色板、资源预览黑色角标、会员金色强调、阅读背景图片本身。
- 审计趋势: `check_theme_coverage_audit` 高风险文件降到 6，`hardcoded-color` 降到 98；`check_ui_component_governance` findings 降到 1033，`loading-state` 降到 49，`hardcoded-style` 降到 820。

### Phase 6: Bookshelf 与 Reader 外围迁移

目标: 只统一外围组件和视觉，不重写核心阅读和书架业务。

预计周期: 1-2 周

- [x] T6.1 迁移 Bookshelf 分类选择面板。
  范围: `bookshelf_taxonomy_picker_surface.dart`。
  实现要求: 接入 `AppSurface`、统一 chip/selection/empty/error。
  验收: 分类/标签增删改不回归，theme coverage score 下降。

- [x] T6.2 迁移 Bookshelf 外围状态。
  范围: 书架 loading、empty、filtered empty、批处理 progress、导入进度。
  实现要求: 优先迁移状态层，不触碰书籍数据计算。
  验收: 书架主要空态和进度态统一。

- [x] T6.3 迁移 Bookshelf 外围卡片。
  范围: toolbar、setting sheet、progress indicator、非核心卡片边框/阴影。
  验收: 书架布局不回归，长列表仍使用 builder/sliver。

- [x] T6.4 迁移 Reader overlay bars。
  范围: `reader_overlay_bars.dart`、reader chrome widgets。
  实现要求: 统一 overlay surface、alpha、shadow、motion duration。
  验收: 阅读器顶部/底部栏显示隐藏顺滑，减少动画关闭时可停用。

- [x] T6.5 迁移 Reader settings sheet 外围组件。
  范围: reader settings sheet 中按钮、状态、progress、surface。
  验收: 阅读设置项视觉统一，设置持久化不回归。

- [x] T6.6 验证背景图 blur 性能。
  范围: app backdrop、reader background、主题 wallpaper blur。
  实现要求: 使用 profile 模式或 DevTools 观察低端设备/模拟器帧耗时。
  验收: 默认配置不产生明显 jank；高 blur 档位有上限和提示。

- [x] T6.7 为 Reader/Bookshelf 建立豁免记录。
  范围: 阅读器专用颜色、翻页透明层、书籍封面生成色板、内容渲染边界。
  验收: 审计 findings 中合理项不再反复被当成迁移任务。

### Phase 7: 治理门禁与收尾

目标: 把阶段成果变成后续开发规则，防止新页面继续回到旧写法。

预计周期: 2-3 天

- [x] T7.1 建立 UI 组件治理文档。
  范围: 补齐当前脚本提示缺失的治理文档或更新为新的统一文档。
  内容: 组件选择规则、页面 scaffold 规则、状态组件规则、modal surface 规则、adaptive 规则。
  验收: `missing-doc` finding 能下降或被新文档替代。

- [x] T7.2 将审计脚本改成分级门禁。
  范围: `check_theme_coverage_audit`、`check_ui_component_governance`。
  实现要求: 历史 baseline 允许存在；新增文件或新增高风险 finding 需要失败或警告。
  验收: CI 或本地 guard 能阻止新增明显硬编码样式。

- [x] T7.3 建立豁免注释格式。
  范围: 允许豁免的固定色、固定透明度、固定动画。
  实现要求: 豁免必须说明原因、所属视觉语义、复查日期。
  验收: 审计报告能区分“未治理”和“已豁免”。

- [x] T7.4 更新组件样板和组件索引。
  范围: 所有新增 App 组件、迁移后的业务模式组件。
  验收: 文档、样板页、代码导出入口一致。

- [x] T7.5 做最终回归审查。
  范围: 高级主题、Mine、Appearance、资源页、Bookshelf 外围、Reader 外围。
  验收: 关键测试通过，视觉截图通过，审计趋势下降，未完成项进入下一轮 backlog。

### Phase 6-7 执行记录

- Bookshelf 分类/标签 picker、初始 loading 已接入 foundation 组件；书籍数据计算、打开阅读、批量选择、导入流程未改动。
- Reader overlay、自动阅读浮动提示、settings sheet、章节缓存 sheet 已完成外围 surface/progress 迁移；Reader 核心渲染、翻页、目录和缓存服务未改动。
- Reader overlay blur 上限统一收敛到 `sigmaX/Y = 8`，不新增全屏 blur；性能和豁免记录见 `docs/ui_ux/reader_bookshelf_ui_exemptions_2026_06_20.md`。
- 新增 `docs/ui_ux/app_ui_component_governance_2026_06_20.md`，明确组件选择、分级门禁和豁免注释格式。
- `check_ui_component_governance.dart` 和 `check_theme_coverage_audit.dart` 已支持 `--strict-new`，用于只拦截新增/变更代码里的治理问题。
- 组件索引已补充 Bookshelf/Reader 外围模式；Lumina 仍是唯一组件样板基线。

## 12. 拆分后复核

- [x] 阶段顺序已按风险排序: 先权益边界和资源规则，再 UI Kit 基座，再页面迁移，最后治理门禁。
- [x] 每个阶段都有目标、预计周期、可勾选任务和验收口径。
- [x] 每个具体任务前都使用 `- [ ]` 或复核项 `- [x]`，可以直接作为 checklist 使用。
- [x] P1 风险已覆盖: 外部导入会员 gate、组件样板入口、资源生效规则。
- [x] 组件化缺口已覆盖: `AppStateView`、`AppSurface`、`AppProgress`、motion spec、组件索引。
- [x] 高级主题资源层已覆盖: 启动图、底栏图集、阅读背景、应用背景、封面图集、资源删除回收；启动图和底栏图集已明确为只通过高级主题绑定生效。
- [x] 性能和动效已覆盖: builder/sliver、RepaintBoundary、背景 blur、disableAnimations、长列表动画限制。
- [x] Reader 和 Bookshelf 已限定为外围迁移，避免一次性重构核心阅读和书架业务。

## 13. 建议验收命令

每轮迁移至少执行:

```bash
flutter analyze lib/app lib/features/mine lib/features/bookshelf lib/features/reader
dart run tool/check_theme_coverage_audit.dart
dart run tool/check_ui_component_governance.dart
dart run tool/run_phase6_guardrail_audit.dart
```

高级主题资源相关测试建议固定执行:

```bash
flutter test \
  test/features/mine/application/official_theme_activation_test.dart \
  test/features/mine/presentation/advanced_theme_list_page_loading_test.dart \
  test/app/navigation/bottom_nav_icon_gallery_provider_test.dart \
  test/features/mine/application/launch_image_gallery_service_test.dart \
  test/app/widgets/resolved_book_cover_test.dart \
  test/domain/entities/app_advanced_theme_reader_wallpaper_test.dart
```

视觉回归建议新增矩阵:

| 主题 | 模式 | 视口 |
|---|---|---|
| Lumina | light/dark | mobile/desktop |
| Mono Blue | light/dark | mobile/desktop |
| Ink Green | light/dark | mobile/desktop |
| Selune Warm | light/dark | mobile/desktop |

截图页面:

- 组件样板页
- 我的页
- 外观页
- 高级主题列表页
- 启动图集页
- 底栏图集页
- 阅读背景页
- 封面图集页
- 书架页
- 阅读器设置浮层

## 14. 最后结论

下一步最优先做的不是再扩很多高级主题功能，而是把现有主题能力“组件化、可验证、可解释”。只要先修好会员 gate、资源生效规则、内部组件样板定位，再补 `AppStateView/AppSurface/AppProgress/MotionSpec`，后续清理硬编码和统一高级主题外观就会顺很多。

建议从 Phase 0/1 开始排期，范围小、风险低、收益高；Phase 3 做完 UI Kit 基座后，再批量迁移 Mine 和高级主题资源页。Reader 和 Bookshelf 先只碰外围组件，避免把阅读体验和书架核心流程卷进一次大重构。
