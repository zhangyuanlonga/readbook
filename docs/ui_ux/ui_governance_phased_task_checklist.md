# UI 治理阶段任务清单

**创建日期**: 2026-06-13  
**适用范围**: Flutter 全平台 UI/UX 治理、Design System 收敛、跨端适配一致性  
**文档用途**: 把 UI 治理拆成可执行、可验收、可打勾的阶段任务  
**执行原则**: 以组件统一、动效补齐、性能治理和能力库产品化为核心；收敛现有体系，不推倒重来。

---

## 0. 总原则

- [x] 不新建一套与 `lib/app/theme/`、`lib/app/layout/`、`lib/app/motion/` 并行的 Token 体系。
- [x] 不机械替换所有 Material 组件；只在跨端行为、重复模式、业务语义明确时封装。
- [x] 新增 UI 和大改页面必须遵守治理规则；旧页面按高频路径和风险分批迁移。
- [x] Reader 核心重构期不强行迁移阅读器核心页面，避免 UI 治理打断阅读链路稳定性。
- [x] 自动化检查先做报告和 baseline，再逐步升级为 CI 拦截新增问题。
- [x] 每个阶段必须有可复查产物：文档、组件、测试、脚本或页面验收记录。
- [x] 成熟库能稳定解决的问题，优先引用成熟库或 Flutter 原生能力，不自行手搓底层能力。
- [x] Flutter 原生能力优先：`RefreshIndicator`、`ReorderableListView`、`HapticFeedback`、`Shortcuts/Actions`、`MenuAnchor` 等无需额外依赖。
- [x] 每个新增依赖必须说明：Flutter 原生不支持、现有库不覆盖、自研成本和维护成本不可接受。
- [x] 不引入大而全 UI Kit；第三方库只作为能力层，必须经过项目组件封装后使用。
- [x] 体验目标不只是一致，还要有明确反馈、状态过渡、加载质感和大列表性能边界。

### 0.1 核心问题主线

| 主线 | 当前问题 | 治理目标 |
|---|---|---|
| 组件统一 | 高频 UI 模式各写各的，Button/Input/状态/弹层/卡片语义不稳定 | 建立语义组件和页面级模式，不机械替换所有 Material 控件 |
| 动效补齐 | `AppMotion` 已有，但页面进入、状态切换、列表变化和反馈动效覆盖不足 | 统一 4-6 类基础动效，全部尊重 `disableAnimations` |
| 组件性能 | 统一组件可能引入额外 rebuild、深层树、列表卡顿和图片解码压力 | 为基础组件和高频页面建立 const、key、rebuild、列表和图片性能规则 |
| 能力库产品化 | 已有 `flutter_animate`、`shimmer`、`flutter_slidable` 等库，但使用方式没有产品化沉淀 | 小而专地封装成熟库，第三方库负责能力，项目组件负责风格和边界 |

---

## 1. 规范入口

### 1.1 当前硬规范入口

- [x] UI 与自适应规则以 `docs/standards/ui_adaptive_design_rules.md` 为准。
- [x] 架构与 UI 基线组件规则以 `docs/standards/development_architecture_guardrails.md` 为准。
- [x] 当前真实设计系统参考 `docs/ui_ux/ui_ux_design_system_actual.md`。
- [x] 本文档只负责阶段拆解和任务追踪，不替代上述规范。

### 1.2 代码侧标准来源

- [x] 颜色: `Theme.of(context).colorScheme`、高级主题 palette/backdrop。
- [x] 组件形态: `AppComponentThemeTokens`、`ThemeExtension`。
- [x] 响应式尺寸: `AppAdaptiveMetrics`、`AppLayout`。
- [x] 通用尺寸: `AppSpacing`、`AppSizeTokens`。
- [x] 动效: `AppMotion`、`AppMotionScope`。
- [x] 弹层和操作面: `showAdaptiveActionSurface`、`AdaptiveActionSurface`、`AdaptiveBottomSheet`、`AdaptiveDialogSurface`。
- [x] 状态组件: `AppEmptyStateCard`、`AppStatusStateCard`、`FeatureDisabledPage`。

---

## 2. Phase 0: 基线盘点与决策

**目标**: 先确认标准入口、现有组件能力、迁移边界和试点范围。  
**建议周期**: 0.5-1 天。  
**输出物**: 盘点记录、试点页面列表、例外规则初稿。

### 2.1 任务

- [ ] 确认 UI 治理负责人和 Review 负责人。
- [x] 确认本轮不新建 `AppDesignTokens` 这类并行总 Token 文件。
- [x] 盘点现有 Token 文件和职责边界。
- [x] 盘点现有基础组件和 Adaptive 组件。
- [x] 列出允许保留裸 Material 组件的场景。
- [x] 列出必须使用 Adaptive 组件的场景。
- [x] 选择 1-2 个低风险试点页面。
- [x] 明确暂缓迁移的高风险区域，尤其是 Reader 核心链路。

### 2.2 验收

- [x] 有一份 Token 和组件来源表。
- [x] 有一份合法例外清单。
- [x] 有一份试点页面清单。
- [x] 团队明确本轮治理不是全量替换。

---

## 3. Phase 1: 标准收敛

**目标**: 把散落的规范收成一个可执行口径，让开发知道该引用哪个文件、哪个组件、哪个规则。  
**建议周期**: 2-4 天。  
**输出物**: 规范入口更新、Token 使用说明、Review checklist。

### 3.1 Token 使用说明

- [x] 补充或更新 `docs/ui_ux/ui_ux_design_system_actual.md`，说明现有 Token 来源。
- [x] 明确 `AppComponentThemeTokens` 负责卡片、按钮、输入、弹层、导航、选择控件形态。
- [x] 明确 `AppAdaptiveMetrics` 负责随屏幕和密度变化的页面 padding、gap、card radius、control height。
- [x] 明确 `AppSpacing` 和 `AppSizeTokens` 负责通用空间和触摸目标。
- [x] 明确 `AppMotion` 负责动画时长、曲线和无障碍禁用动画。
- [x] 记录允许硬编码的例外，例如真实资源色、封面占位、阅读器用户主题、警示语义色。

### 3.2 组件使用说明

- [x] 更新 `docs/ui_ux/README.md`，加入本任务清单入口。
- [x] 明确新增页面默认使用 `AdaptivePageScaffold` 或说明例外。
- [x] 明确弹层默认使用 `showAdaptiveActionSurface`。
- [x] 明确空、加载、错误、禁用状态优先使用现有状态组件。
- [x] 明确搜索、筛选、列表、卡片优先复用现有 Adaptive 组件。
- [x] 明确 Button/TextField 不做机械替换，优先依赖全局 Theme；只有重复业务语义明确时再封装。

### 3.3 Review checklist

- [x] 新增 UI PR 是否使用现有 Token 或说明例外。
- [x] 新增 UI PR 是否覆盖小屏、平板、桌面至少三个断点。
- [x] 新增弹层是否使用 Adaptive surface 或说明例外。
- [x] 新增状态展示是否复用统一状态组件。
- [x] 新增页面是否避免裸大面积 `Scaffold`、无限宽内容和移动端 bottom sheet 桌面放大。

### 3.4 验收

- [x] 文档里不再出现“项目没有 Design Token”这类不准确说法。
- [x] 开发能从一个入口找到 UI 治理规则。
- [x] 代码侧 Token 和文档侧 Token 名称一致。

---

## 4. Phase 2: 组件统一与基础能力补缺

**目标**: 统一高频 UI 模式，只补真正缺失且能跨模块复用的基础组件，不为了组件库完整度而抽象。  
**建议周期**: 1-2 周。  
**输出物**: 最小基础组件、语义组件分层、Widget smoke test、使用示例。

### 4.1 语义组件优先级

- [x] 统一 Button 语义模型: primary、secondary、danger、ghost、text、icon。
- [x] 统一 Input/TextField 语义模型: 搜索、表单、只读、错误态。
- [x] 统一 Operation Surface frame: `showAdaptiveActionSurface` / `AppTaskBottomSheet` 覆盖标题、内容、操作区、安全区、最大宽度。
- [x] 统一 Loading/Empty/Error state: 列表页、详情页、局部卡片。
- [x] 统一 Card/ListTile 扩展: 普通、可点击、选中、危险操作、禁用。
- [x] 统一 Selection/BatchAction 模式: `AdaptiveListTile.selected` + `AppBatchActionBar` 覆盖选择态、批量操作栏、危险批量操作确认。
- [x] 统一 Search/Filter 模式: `AdaptiveSearchBar`、`AdaptiveFilterBar`、`AdaptiveOverflowToolbar` 覆盖搜索输入、筛选 chip、排序入口、清空入口。
- [x] 统一 Menu/Dropdown 模式: `AppMenuButton` 基于 `MenuAnchor` 覆盖更多菜单、筛选菜单和危险项；`AppDropdownField` 基于 `DropdownMenu` 覆盖表单下拉和设置选择器。
- [x] 统一 Image/Cover 模式: `DiskCachedCoverImage` 覆盖占位、失败、淡入、圆角、缓存和解码尺寸。
- [x] 统一 Toast/Snack/Inline feedback 模式: `AppFeedback`、成功、失败、警告、后台任务反馈。
- [x] 统一 Refresh 模式: 下拉刷新、上拉加载、刷新指示器和错误重试。
- [x] 统一 HapticFeedback 模式: 成功操作、危险操作、选择反馈和禁用场景。
- [x] 统一 ImageViewer 模式: 大图预览、缩放、手势、保存或分享入口，按需评估 `photo_view`。
- [x] 统一 ContextMenu 模式: 桌面右键菜单、移动端长按菜单、键盘可访问菜单。
- [x] 统一 Reorderable 模式: 拖拽排序、拖拽提示、拖拽动画和稳定 key。
- [x] 统一 Search Highlight 模式: 搜索命中高亮、空 query、大小写和跨端文本选择。

### 4.2 组件分层边界

- [x] `app/widgets/foundation/`: 只放跨 feature、高频、低业务耦合的基础组件。
- [x] `app/widgets/adaptive_*`: 只放跨端结构或交互差异明显的组件。
- [x] `features/*/presentation/widgets/`: 业务语义强、单 feature 内复用的组件先留在 feature。
- [x] 第三方库不得直接成为业务页面默认写法，必须先经过 app 或 feature 组件封装。
- [x] 新组件必须说明替代的重复模式，不以“组件库完整度”为目标。

### 4.3 设计约束

- [x] 组件优先读取 `ThemeData` 和 `AppComponentThemeTokens`。
- [x] 组件需要支持 `const` 构造，能 const 的 child 示例必须 const。
- [x] 列表类组件必须支持 key 或由调用侧提供稳定 key。
- [x] 组件不能绕过 `MediaQuery.disableAnimations`。
- [x] 组件不能把移动端交互强行带到桌面端。
- [x] 组件不能在 build 中做异步请求、状态写入或重计算重任务。
- [x] 新增基础组件不得默认使用 `shrinkWrap` 承载长列表。
- [x] 新增列表 item 组件不得创建不必要的 controller、focusNode、animation controller。
- [x] 新增图片组件不得把图片原图无约束解码到列表或网格中。

### 4.4 测试

- [x] Button 组件有 enabled、disabled、loading、danger smoke test。
- [x] Input 组件有 normal、focused、error、readOnly smoke test。
- [x] Surface 组件有 mobile sheet 和 desktop dialog smoke test。
- [x] State 组件有 loading、empty、error、permission/platform unavailable smoke test。
- [x] 组件测试覆盖 `390x844`、`600x960`、`1280x800` 中至少两个断点。
- [x] 列表 item 组件有稳定 key / selected / disabled / hover 或 focus smoke test。
- [x] Selection/BatchAction 组件有 selected count、select all、clear、danger confirm smoke test。
- [x] Menu/Dropdown 组件有打开、选择、禁用或原生 `DropdownMenu` 委托 smoke test。
- [x] 图片组件有 loading、error、cache manager、decode size 和圆角 smoke test。

### 4.5 验收

- [x] 至少有两处不同 feature 真实复用新基础组件。
- [x] 每个新增基础组件都有最小 Widget test。
- [x] 没有为了抽象而迁移低频、单点、强业务定制 UI。
- [x] 每类新增组件都能指向一个被消除的重复 UI 模式。
- [x] 业务页面直接引用第三方 UI/动效库的新增用法为 0，合法例外需记录。

---

## 5. Phase 3: 动效与能力库产品化

**目标**: 补齐“使用起来流畅、反馈丰富”的体验空白；优先复用现有成熟库，但必须通过项目组件封装。  
**建议周期**: 1-2 周。  
**输出物**: 动效组件、骨架屏组件、列表交互组件、图片体验组件、动效覆盖试点。

### 5.1 成熟库优先策略

- [x] 能用成熟库稳定解决的能力，不手搓核心实现；项目只做主题、跨端、无障碍和性能边界封装。
- [x] 优先级顺序: Flutter 原生能力 > 项目已有成熟依赖 > 新增成熟第三方库 > 小范围自研补缺。
- [x] 不引入大而全 UI 组件库，避免和 Material 3、`AppTheme`、高级主题、Adaptive 体系冲突。
- [x] 继续优先复用现有能力库: `flutter_animate`、`shimmer`、`flutter_slidable`、`flutter_staggered_grid_view`、`cached_network_image`。
- [x] 引入任何新 UI/动效/图片库前，必须说明 Flutter 原生能力和现有依赖不能覆盖的缺口。
- [x] 自研 UI 能力前必须先记录成熟库评估结论；没有评估结论不得进入实现。
- [x] 第三方库只能作为能力层，不能直接决定产品视觉风格。
- [x] 本轮新增封装按职责读取 `AppMotion`、`ThemeData`、`AppComponentThemeTokens` 和 Adaptive metrics；无视觉职责的能力封装保持轻量。

### 5.1.1 当前已有能力库评估

| 库 | 用途 | 评价 | 是否保留 |
|---|---|---|---|
| `flutter_animate` ^4.5.0 | 基础动画、进入动效、状态过渡 | 功能足够、API 简洁，适合沉淀到 `AppMotion` 封装 | 保留 |
| `shimmer` ^3.0.0 | 骨架屏、加载占位 | 轻量成熟，适合封装 `AppSkeletonBlock` / `AppSkeletonList` | 保留 |
| `flutter_slidable` ^3.0.1 | 移动端滑动操作 | 移动端成熟，桌面端需要补显式操作入口 | 保留 |
| `cached_network_image` ^3.4.1 | 网络图片缓存 | 稳定，需通过项目图片组件约束尺寸、占位和失败态 | 保留 |
| `flutter_staggered_grid_view` ^0.7.0 | 交错网格、资源图库 | 适合图库和主题预览等特定场景，不作为普通列表默认方案 | 保留 |

### 5.1.2 潜在补充库与原生能力

| 能力 | 优先方案 | 优先级 | 评估结论 |
|---|---|---|---|
| 图片预览缩放 | `photo_view` | P2 | 如需要大图查看、双击缩放、手势平移，可在项目 `AppImageViewer` 中评估引入 |
| 桌面右键菜单 | `MenuAnchor` 优先，必要时评估 `context_menus` | P2 | Flutter 原生能覆盖时不新增依赖；原生能力不足再补库 |
| 拖拽排序 | `ReorderableListView` | 原生 | Flutter 原生能力，先封装统一拖拽态和排序反馈 |
| 下拉刷新 | `RefreshIndicator` | 原生 | Flutter 原生能力，封装 `AppRefreshIndicator` 统一样式和空/错态协作 |
| 触觉反馈 | `HapticFeedback` | 原生 | Flutter 原生能力，封装成功、危险、选择三类反馈规则 |
| 键盘快捷键 | `Shortcuts` / `Actions` | 原生 | Flutter 原生能力，优先用于桌面端和效率型页面 |
| 菜单锚点 | `MenuAnchor` | 原生 | Flutter 原生能力，适合作为桌面菜单和 overflow menu 基线 |
| 选择下拉 | `DropdownMenu` | 原生 | Flutter 原生 MD3 选择器，封装 `AppDropdownField` 后替代旧 `DropdownButton*` |

### 5.1.3 暂不引入 / 特定需求再评估

| 库或方案 | 当前结论 | 理由 |
|---|---|---|
| `rive` / `lottie` | 暂不引入 | 当前优先补基础交互动效，`flutter_animate` 已覆盖大多数状态过渡；有品牌级矢量动效需求时再评估 |
| 大而全 UI Kit | 不引入 | 容易与 Material 3、`AppTheme`、高级主题和 Adaptive 体系冲突 |
| `sprung` | 暂不引入 | 现阶段优先使用 Flutter 原生曲线和 `flutter_animate`，弹簧曲线不足时再评估 |
| 手搓图片缩放/手势库 | 不作为默认方案 | 大图缩放、边界回弹、双击缩放等细节复杂，优先评估成熟库 |

### 5.2 基础动效模式

- [x] 页面或 section 进入: 封装统一 fade + slight slide，避免每页自己写 `FadeTransition`。
- [x] 列表项出现: 封装轻量 stagger/entrance，限制只用于短列表或首屏可见项。
- [x] 状态切换: 封装 loading/empty/error/content 的 `AnimatedSwitcher` 规则。
- [x] 弹层出现: 收敛到 `AdaptiveActionSurface` / `AppFadeSlideTransition`。
- [x] 按压反馈: 封装轻量 press/hover/focus feedback，不改变移动端成熟触控路径。
- [x] 图片加载: `DiskCachedCoverImage` 统一淡入、占位、失败态和圆角裁剪入口。
- [x] 所有动效必须尊重 `MediaQuery.disableAnimations` 和 `AppMotionScope`。

### 5.2.1 优先使用 Flutter 原生能力

不需要额外依赖的能力先做项目封装，统一样式、主题读取、跨端行为、可访问性和性能边界。

- [x] 下拉刷新: 基于 `RefreshIndicator` 封装 `AppRefreshIndicator`。
- [x] 触觉反馈: 基于 `HapticFeedback.lightImpact`、`heavyImpact`、`selectionClick` 封装 `AppHaptics`。
- [x] 拖拽排序: 基于 `ReorderableListView` 封装统一拖拽句柄、排序反馈和空态。
- [x] 键盘快捷键: 基于 `Shortcuts` / `Actions` 封装 `AppShortcuts`，用于桌面端常用操作。
- [x] 右键或溢出菜单: 优先基于 `MenuAnchor`，不足时再评估 `context_menus`。
- [x] 下拉选择器: 基于 `DropdownMenu` 封装 `AppDropdownField`，替代旧 `DropdownButton` / `DropdownButtonFormField`。
- [x] 原生组件不足时才进入第三方库评估，评估结论必须写入 PR 或任务记录。

### 5.3 加载与骨架屏

- [x] 基于 `shimmer` 封装 `AppSkeletonBlock`。
- [x] 封装 `AppSkeletonList`，支持列表、卡片、封面三类骨架。
- [x] 封装 `AppLoadingState` / `AppLoadingStateSwitcher`，用于局部加载，减少散落的裸 `CircularProgressIndicator`。
- [x] 骨架屏必须有固定尺寸，避免加载态到内容态发生明显 layout shift。
- [x] 骨架屏只用于真实等待；瞬时操作不加无意义动效。

### 5.4 列表交互能力

- [x] `flutter_slidable` 只通过项目封装使用，例如 `AppSlidableActionTile` / `AppSlidableActionGroup`。
- [x] 左滑操作基础 API 已统一危险色和禁用态；确认方式、撤销反馈和桌面替代入口进入页面接入任务。
- [x] 桌面端替代能力已有 `AppContextMenu` / `AdaptiveOverflowToolbar` 基础件，页面接入按模块推进。
- [x] 滑动操作不得破坏列表 item 的稳定 key 和选择态。

### 5.5 图片与资源体验

- [x] 基于现有图片缓存能力统一封面占位、失败态、淡入和圆角。
- [x] 基础封面组件必须声明目标尺寸或解码约束。
- [x] 资源图库、主题预览、封面图库保留 `flutter_staggered_grid_view` 能力，书架主列表优先稳定 grid/list。
- [x] 基础图片组件需要避免重复裁剪、重复阴影和无界原图解码。

### 5.6 动效验收

- [x] 动效组件有启用和禁用动画两套 smoke test。
- [x] 试点页面至少覆盖 loading -> content、error -> retry、操作成功/失败反馈。
- [x] 动效不引入明显首帧延迟、滚动卡顿或布局跳动。
- [x] 低端移动设备或小屏断点下不使用过重的列表 stagger。

---

## 6. Phase 4: 试点页面迁移

**目标**: 用 1-2 个页面验证标准和组件是否可用，先拿到真实反馈，再扩到全项目。  
**建议周期**: 1-2 周。  
**输出物**: 试点页面 PR、验收记录、问题回流清单。

### 6.1 试点选择

- [x] 优先选择 Mine、Bookshelf、Search、Book detail 中低风险页面或页面局部。
- [x] 暂不选择 Reader 核心翻页、章节定位、阅读进度、设置持久化链路。
- [x] 试点页面必须有明确的重复 UI 模式或跨端体验问题。
- [x] 试点页面必须能补 smoke test 或明确手测矩阵。

### 6.2 迁移任务

- [x] 本轮修复非 Adaptive bottom sheet 使用点: Reader 点击分区编辑器和动作选择器已收口到 `showAdaptiveActionSurface`；Reader 目录 sheet 因透明背景、禁拖拽和专用转场暂列 Reader 周边例外。
- [x] 把页面弹层收口到 `showAdaptiveActionSurface` 或记录例外。
- [x] 把页面空、错、加载状态收口到统一状态组件。
- [x] 把重复卡片、列表项或操作按钮提取为 feature 组件或 app 基础组件。
- [x] 把明显随手写的颜色、圆角、间距改为现有 Token。
- [x] 保留已由全局 Theme 统一且无业务重复问题的 Material Button/TextField。
- [x] 为试点页面补齐 loading/error/content 状态切换动效。
- [x] 为试点页面补齐操作反馈: 成功、失败、重试、撤销或后台任务状态。
- [x] 本轮试点页面无图片资源链路；基础图片组件已补齐占位、失败态、缓存和解码约束。

### 6.3 验收矩阵

- [x] `360x800`
- [x] `390x844`
- [x] `600x960`
- [x] `840x1180`
- [x] `1280x800`
- [x] 文字缩放 `1.0x`
- [x] 文字缩放 `1.3x`
- [ ] Android 或 iOS 移动端 smoke。
- [x] 桌面或 Web 宽屏 smoke。

### 6.4 试点复盘

- [x] 记录哪些 Token 好用。
- [x] 记录哪些 Token 缺失。
- [x] 记录哪些组件 API 过重或过轻。
- [x] 记录哪些规则误杀或执行成本过高。
- [x] 记录哪些动效明显提升体验，哪些动效会打扰用户。
- [x] 记录哪些第三方能力值得沉淀为项目组件。
- [x] 根据试点结果调整 Phase 6 自动化规则。

---

## 7. Phase 5: 组件性能治理

**目标**: 确保统一组件、动效和能力库封装不会牺牲滚动、首屏、图片和交互性能。  
**建议周期**: 1 周起，随试点页面持续执行。  
**输出物**: 组件性能 checklist、关键组件 smoke、页面性能审查记录。

### 7.1 组件级性能规则

- [x] 静态 widget 和配置对象尽量使用 `const`。
- [x] 列表 item、网格 item、可删除/可排序项必须有稳定 key 或由调用方提供 key。
- [x] 大列表不得使用 `ListView(children: [...])` 或 `shrinkWrap: true` 承载长内容。
- [x] 本轮新增基础组件 build 内不得创建 `TextEditingController`、`FocusNode`、`AnimationController` 等长期对象。
- [x] 组件 build 内不得触发异步请求、provider 写入、数据库读取或重计算重任务。
- [x] 昂贵绘制区域按需使用 `RepaintBoundary`，不能把整个页面无脑包起来。
- [x] 动画组件不得对长列表所有 item 同时启动重动画。

### 7.2 状态管理与 rebuild

- [x] 高频页面使用 `Consumer` / `ConsumerWidget` / `select` 限制 rebuild 范围。
- [x] 统一组件接收稳定 value model，避免每帧创建大量临时对象。
- [x] 列表 item 的 selected、loading、disabled 状态变化只刷新必要区域。
- [x] 弹层打开、关闭和状态切换不触发主页面大范围 rebuild。
- [x] 动效状态和业务状态分离，避免动画 controller 污染业务 provider。

### 7.3 图片与资源性能

- [x] 封面、头像、主题预览图必须有尺寸约束。
- [x] 图片列表优先使用缓存、占位和失败态，不重复发起网络/磁盘读取。
- [x] 大图预览和缩略图使用不同尺寸策略，避免缩略图解码原图。
- [x] 圆角、裁剪、阴影只保留一层，避免重复 `ClipRRect` + shadow。
- [x] 图片淡入动画只作用于图片本身，不触发布局重排。

### 7.4 性能验收

- [x] 新增基础组件至少有 widget smoke，确认禁用/加载/错误状态不抛异常。
- [x] 高频列表组件至少覆盖 100+ item 的 smoke 或局部 benchmark。
- [x] 图片组件至少覆盖 loading、error、缓存管理和解码尺寸约束。
- [x] 动效组件在 `disableAnimations=true` 下应退化为静态展示。
- [x] 页面试点需要记录是否存在明显首帧延迟、滚动卡顿、布局跳动。
- [x] 性能问题不得用“统一组件”作为理由延期处理。

---

## 8. Phase 6: 自动化检查与准入

**目标**: 用轻量脚本守住新增问题，不追求一次性清空历史债务。  
**建议周期**: 3-5 天。  
**输出物**: 检查脚本、baseline、豁免清单、CI 策略。

### 8.1 检查脚本

- [x] 新增 UI 合规扫描脚本，优先检查 git diff 新增行。
- [x] 检查裸 `showDialog`、`showModalBottomSheet`，允许 Adaptive 内部实现。
- [x] 检查新增 `Color(0x...)`、`Colors.*`，允许主题、资源、阅读器主题、警示色豁免。
- [x] 检查新增局部 `BoxShadow`、局部大圆角、随手 `fontSize`，先作为 warning。
- [x] 检查新增页面是否出现裸 `Scaffold`，要求备注例外。
- [x] 检查业务页面直接新增第三方 UI/动效库调用，要求走项目封装或说明例外。
- [x] 检查新增长列表中的 `shrinkWrap: true`、`ListView(children: ...)` 和无 key item。

### 8.2 豁免机制

- [x] 建立文件级 allowlist。
- [x] 建立业务语义 allowlist。
- [ ] 建立 inline ignore 规则和必须填写原因的格式。
- [x] 豁免清单需要定期复查，不能无限增长。

### 8.3 CI 策略

- [x] 第 1 周只生成报告，不阻断 CI。
- [ ] 第 2 周开始阻断新增裸弹层和无说明的大面积硬编码。
- [ ] 第 3 周开始阻断无测试的新增基础组件。
- [ ] 第 4 周开始阻断业务页面直接新增未封装第三方 UI/动效库调用。
- [x] 历史问题不进入阻断条件，只进入 backlog。

### 8.4 验收

- [x] 脚本能区分新增问题和历史问题。
- [x] 脚本不会误杀 Adaptive 组件内部实现。
- [x] CI 输出能定位到文件和行号。
- [x] 规则说明能被开发直接看懂。

---

## 9. Phase 7: 分模块推广

**目标**: 在试点稳定后，按模块和页面风险推广 UI 治理。  
**建议周期**: 持续执行，每轮 1-2 个页面。  
**输出物**: 模块迁移记录、重复模式消除清单、页面验收报告。

### 9.1 推广覆盖清单

> 表格第一列表示该页面族的 UI 治理迁移是否完成；覆盖归属已确认但页面尚未完成迁移时，仍保持未勾选。

| 迁移完成 | 模块 / 页面族 | 覆盖范围 | 完成记录 |
|---|---|---|---|
| [x] | App Shell / 全局导航 | `ShellScaffold`、桌面工具栏、底部导航、全局任务面板 | 已完成全局反馈、Adaptive 账号弹层、任务面板反馈、导航结构确认和 RepaintBoundary 边界审查 |
| [x] | Bookshelf | 书架卡片、筛选、排序、布局切换、更多操作、本地书库、导入反馈 | 已完成刷新、筛选/排序弹层、批量操作栏、危险确认、卡片图片尺寸、长列表 key 和 RepaintBoundary 收口 |
| [x] | Search | 搜索输入、结果卡片、分组空态、失败报告、书源筛选、书架入口搜索 | 已完成菜单、书源筛选 sheet、失败报告弹层、结果卡片、空态、反馈和 P3 Search 边界记录 |
| [x] | Book detail | 元数据、主操作、目录、来源切换、封面编辑 | 已完成详情刷新、提示反馈、编码下拉、封面/元数据弹层、主操作和来源切换弹层统一 |
| [x] | Reader core | 翻页、章节定位、阅读进度、阅读设置持久化 | 已完成 Reader UI surface 的刷新、反馈、设置弹层和绘制边界收口；不在 UI 治理中改阅读算法和持久化语义 |
| [x] | Reader surrounding / Stats | 设置 sheet、目录 sheet、统计页、阅读记录、缓存反馈、来源切换、注释工具栏 | 已完成阅读记录反馈、热力图菜单、Reader audio 反馈、缓存/来源切换弹层和设置 sheet 基础组件收口 |
| [x] | Mine / StorageManagement | 存储管理页低风险试点 | 已完成弹层、状态、骨架、反馈、smoke 和复盘 |
| [x] | Mine / Appearance | 外观设置、阅读背景、底部导航图标、封面图库、启动图图库 | 已完成图库菜单、资源反馈、背景/图集编辑提示和 Mine 入口刷新反馈收口 |
| [x] | Mine / AdvancedTheme | 高级主题列表、编辑器、导入导出、主题预览 | 已完成菜单/筛选、导入导出反馈、编辑器保存反馈和任务状态收口 |
| [x] | Mine / Source & Assets | 私有书源、标签/分类、字体管理、书签、反馈、会员、系统设置 | 已完成私有书源、字体、反馈、会员、书签、标签分类、系统设置的刷新与反馈收口 |
| [x] | Auth / Profile | 登录注册、账号资料、密码、头像和启动鉴权入口 | 已完成登录/注册反馈、资料页刷新、编辑保存和退出失败反馈收口 |
| [x] | Announcement | 公告列表、公告详情 | 已完成统一刷新、加载骨架、状态卡片、反馈和宽屏约束 |
| [x] | Discover | 发现页、发现分类页、服务端发现结果、错误/空态 | 已完成统一刷新、加载骨架、状态卡片、结果卡片、失败反馈和图片尺寸约束 |
| [x] | Source / WebView | 书源登录 WebView、导入外部源、source workflow | 已完成 WebView 平台分支、错误/会话提示、导入任务提示和安全区页面收口 |
| [x] | Sync / Task status | 后台同步任务、`AppTaskChannel.sync`、全局任务队列状态 | 当前无独立同步页面路由；已按全局任务面板、取消/清理反馈和 `AppTaskChannel.sync` 状态治理 |
| [x] | Error Center | 错误列表、日志详情、清理操作 | 已完成统一反馈、危险确认、桌面分栏、空态和导出任务状态 |
| [x] | Onboarding / 预留入口 | 当前目录无页面文件和运行时路由 | 当前无运行时改造对象；恢复首次启动、权限引导或功能介绍入口时重新纳入迁移 |
| [x] | App update / Core surfaces | 更新提示、媒体/文件选择、WebView 共享 surface | 已完成热更新 Adaptive surface、更新链接失败反馈和全局核心提示收口；媒体/文件选择已有 Adaptive surface |
| [x] | About / 低频静态页 | 关于、帮助、低频说明页 | 已完成版本检查、外链失败和更新入口反馈统一 |

> 注: 当前底部导航和 `AppShellNavigationState` 已无独立 `Home`，旧首页偏好 key 只用于清理历史数据；`lib/features/home` 当前为空目录且无运行时路由，“首页入口、推荐区、跨模块卡片”不再作为独立 Phase 7 模块，后续推荐/发现类能力归入 Discover 或 Bookshelf 对应页面族。

### 9.1.1 模块迁移完成标准

**App Shell / 全局导航**

- [x] 退出登录成功、失败提示统一使用 `AppFeedback.showSnackBar`。
- [x] 当前导航结构确认: `appShellDestinations` 为 Bookshelf、Discover、Stats、Mine，无独立 Home。
- [x] 全局任务面板、账号菜单和桌面工具栏反馈统一到项目反馈组件。
- [x] 桌面/移动导航入口的动效、禁用动画和文字缩放完成 smoke。
- [x] 桌面工具栏和主要全局绘制区完成 RepaintBoundary 边界审查。

**Bookshelf**

- [x] 书架页和本地书库导入提示统一使用 `AppFeedback.showSnackBar`。
- [x] 书架页下拉刷新从裸 `RefreshIndicator` 迁移到 `AppRefreshIndicator`。
- [x] 排序和筛选弹层移除不必要的 `shrinkWrap` 写法。
- [x] 书架选择态、批量操作和危险确认统一接入 `AppBatchActionBar`。
- [x] 书架卡片、列表项、封面图片尺寸和占位/失败态完成页面级审查。
- [x] 书架长列表 key、滚动性能和图片解码尺寸完成 smoke 或记录。

**Search**

- [x] 搜索取消等页面提示统一使用 `AppFeedback.showSnackBar`。
- [x] 搜索更多菜单已接入 `AppMenuButton`。
- [x] 来源选择和失败报告弹层移除不必要的 `shrinkWrap` 写法。
- [x] Search P3 关键链路改动边界已确认: 本轮只做基础组件、反馈和性能模式收口，不抢搜索核心业务改动。
- [x] 搜索输入和书源筛选 sheet 统一状态反馈、禁用态和加载态。
- [x] 搜索结果卡片、空态、失败报告和导出反馈完成组件替换审查。
- [x] Search P3 关键链路稳定后，如需调整业务搜索算法另立任务；本轮 UI 治理不抢核心业务改动。

**Book / Reader / Source / Sync**

- [x] Book detail 详情页从裸 `RefreshIndicator` 迁移到 `AppRefreshIndicator`。
- [x] Book detail 主提示统一使用 `AppFeedback`，元数据、封面、编码、来源切换弹层继续走项目 Adaptive surface。
- [x] Reader core 的页面级提示统一使用 `AppFeedback`，可刷新状态统一使用 `AppRefreshIndicator`。
- [x] Reader core 的翻页、章节定位、阅读进度和设置持久化未被 UI 治理改写；本轮只收口 UI surface。
- [x] Reader surrounding / Stats 阅读记录、音频地址复制/外部打开提示统一使用 `AppFeedback`。
- [x] Reader surrounding / Stats 阅读记录热力图菜单、缓存和来源切换弹层继续使用项目组件。
- [x] Source / WebView 登录页和任务页错误、会话、提交反馈统一使用 `AppFeedback`。
- [x] Source / WebView 平台不支持分支保留 `FeatureDisabledPage`，不增加手搓替代 WebView。
- [x] Sync / Task status 当前无独立同步页面路由，统一归入全局任务面板和 `AppTaskChannel.sync`。
- [x] 全局任务面板取消任务、清理已完成任务统一使用 `AppFeedback`。

**Auth / Mine management pages**

- [x] Auth 登录/注册成功、失败提示统一使用 `AppFeedback`。
- [x] Profile 页面从裸 `RefreshIndicator` 迁移到 `AppRefreshIndicator`。
- [x] Profile 退出失败、资料保存成功/失败提示统一使用 `AppFeedback`。
- [x] Mine 主入口刷新从裸 `RefreshIndicator` 迁移到 `AppRefreshIndicator`，入口提示统一到 `AppFeedback`。
- [x] Mine / Appearance 外观页、阅读背景页、封面图库、启动图图库、底部导航图标图库提示统一使用 `AppFeedback`。
- [x] Mine / AdvancedTheme 列表页和编辑器提示统一使用 `AppFeedback`，导入导出任务继续走项目任务状态组件。
- [x] Mine / Source & Assets 中私有书源、反馈、书签、会员、字体管理页面从裸 `RefreshIndicator` 迁移到 `AppRefreshIndicator`。
- [x] Mine / Source & Assets 中私有书源、标签分类、字体、书签、反馈、会员、系统设置提示统一使用 `AppFeedback`。
- [x] 剩余 `shrinkWrap` 已审查：当前位于受限高度选择器、内嵌短列表、拖拽排序列表和资源网格中，不作为长列表违规；后续大改时再做结构化 Sliver 拆分。

**Low-risk pages / Core surfaces**

- [x] Announcement 列表和详情页从裸 `RefreshIndicator` 迁移到 `AppRefreshIndicator`。
- [x] Announcement 列表和详情页加载态补齐 `AppSkeletonList` / `AppSkeletonBlock`。
- [x] Announcement 页面提示统一使用 `AppFeedback.showSnackBar`。
- [x] Discover 主列表接入 `AppRefreshIndicator`，加载态和远程搜索加载态接入骨架屏。
- [x] Discover 分类页和分类书籍页接入骨架屏，分类书籍列表接入统一下拉刷新。
- [x] Discover 状态组件、空态、错误态和书籍封面尺寸约束完成页面级审查。
- [x] Error Center 日志复制、导出、清空提示统一使用 `AppFeedback`。
- [x] Error Center 清空日志接入 `showAppBatchActionConfirmation` 危险确认。
- [x] App update / Hot update 从裸 `AlertDialog` 收口到 `showAdaptiveActionSurface`。
- [x] App update 链接失败、热更新失败和全局鉴权提示统一到 `AppFeedback`。
- [x] About 页外链失败、版本检查和更新入口提示统一到 `AppFeedback`。
- [x] Onboarding 当前无页面文件和运行时路由，本轮按“无改造对象”收尾记录。

### 9.1.2 覆盖范围审查

- [x] 一级导航覆盖已核对: `appShellDestinations` 为 Bookshelf、Discover、Stats、Mine。
- [x] 路由入口覆盖已核对: `appRouter` 挂载 Mine、Announcement、Auth、Search、Source、Bookshelf、Book、Reader 路由。
- [x] `lib/features/home` 当前为空目录且无运行时路由，不作为独立 Phase 7 模块。
- [x] `local-library`、本地图书导入和本地书籍详情入口归入 Bookshelf / Book detail。
- [x] `/stats` 和 `/read-records` 重定向归入 Reader surrounding / Stats。
- [x] `/error-center` 由 Mine routes 挂载，归入 Error Center。
- [x] `/source/webview-login` 和 `/source/webview-task` 归入 Source / WebView。
- [x] `lib/features/sync` 当前无页面文件和独立路由，按后台同步任务、全局任务状态和错误恢复治理。
- [x] `lib/features/onboarding` 当前无页面文件和运行时路由，作为预留入口记录，恢复时重新开启迁移任务。
- [x] Mine 子路由覆盖已核对: 外观、高级主题、图库、标签/分类、私有书源、会员、关于、系统设置、存储、字体、书签、错误中心、反馈均有归属。

### 9.2 每页迁移 checklist

- [x] 页面是否有最大宽度、分栏或桌面展示策略。
- [x] 页面是否保留移动端成熟路径。
- [x] 页面是否有空、错、加载、禁用态。
- [x] 页面是否处理 Safe Area、键盘、底部导航遮挡。
- [x] 页面是否处理文字缩放和小屏溢出。
- [x] 页面是否复用现有 Token。
- [x] 页面是否有 smoke test 或手测记录。
- [x] 页面是否有必要的状态切换、加载、图片和操作反馈动效。
- [x] 页面是否避免长列表 shrinkWrap、无 key item、无尺寸图片。

### 9.3 每轮复盘

- [x] 记录新增或调整的基础组件。
- [x] 记录移除的重复 UI 模式。
- [x] 记录仍需豁免的历史代码。
- [x] 记录自动化误报和漏报。
- [x] 更新下一轮页面优先级。

---

## 10. 可量化指标

### 10.1 不使用的指标

- [x] 不使用“品牌一致性提升 200%”。
- [x] 不使用“开发效率提升 50%”。
- [x] 不使用“维护成本降低 60%”。
- [x] 不使用“所有硬编码数量归零”。
- [x] 不使用“所有 Button/TextField 全量替换”。
- [x] 不使用“动画数量越多越好”。
- [x] 不使用“引入更多 UI 库等于体验更好”。

### 10.2 使用的指标

- [x] 新增 UI PR 裸弹层数量为 0，合法例外除外。
- [x] 新增基础组件 Widget smoke test 覆盖率为 100%。
- [x] 每轮至少消除 1 个重复 UI 模式。
- [x] 每个试点页面完成断点验收矩阵。
- [x] 每个大改页面说明移动端、平板、桌面影响。
- [x] 自动化报告中的新增 P0 UI 问题为 0。
- [x] 试点页面至少覆盖 loading/empty/error/content 中 3 类状态。
- [x] 试点页面至少补齐 2 类用户可感知反馈: 动效、骨架、图片淡入、操作成功/失败、撤销。
- [x] 高频列表组件有稳定 key 和长列表性能说明。
- [x] 新增第三方 UI/动效库直接调用数量为 0，合法例外除外。
- [x] 新增图片组件必须有尺寸约束、占位和失败态。
- [x] 旧 MD2 风险入口 `PopupMenu*`、`DropdownButton*`、`DropdownMenuItem` 在 `lib` / `test` 扫描结果为 0。

---

## 11. 任务看板模板

复制下面模板到具体任务或 PR 描述中使用。

```markdown
## UI 治理任务

### 范围
- 页面/模块:
- 本次改动类型: 标准收敛 / 组件统一 / 动效补齐 / 能力库封装 / 性能治理 / 试点迁移 / 自动化 / 模块推广
- 不改范围:

### Checklist
- [ ] 使用现有 Token 或说明例外
- [ ] 复用语义组件或说明为何保留原生 Material 组件
- [ ] 弹层使用 Adaptive surface 或说明例外
- [ ] 状态组件复用统一组件
- [ ] loading/empty/error/content 状态有明确反馈
- [ ] 动效使用 `AppMotion` 并尊重禁用动画
- [ ] 未在业务页面直接新增第三方 UI/动效库调用
- [ ] 长列表、图片、动画有性能边界
- [ ] 移动端路径未被桌面适配破坏
- [ ] 覆盖至少 3 个断点
- [ ] 补 Widget test 或手测记录

### 验收记录
- [ ] 360x800:
- [ ] 390x844:
- [ ] 600x960:
- [ ] 840x1180:
- [ ] 1280x800:
- [ ] 1.3x text scale:
```

---

## 12. 当前推荐下一步

- [x] 完成 Phase 0 基线盘点。
- [x] 更新 `docs/ui_ux/README.md`，加入本文档入口。
- [x] 把 `cross_platform_product_strategy_and_ui_governance.md` 的定位改为战略草案。
- [x] 选择一个 Mine 或 Bookshelf 局部做试点。
- [x] 围绕组件统一、动效补齐、组件性能和能力库封装重新排下一轮试点。
- [x] 优先选择一个高频页面做完整闭环，而不是继续只补文档。
- [x] 先写检查脚本报告模式，不急于阻断 CI。

---

## 13. 立即执行建议（优先级排序）

### 13.1 Week 1: 必须完成

- [x] 完成 Phase 2 基础组件测试补全: Surface mobile sheet / desktop dialog smoke test。
- [x] 完成 Phase 2 列表 item 测试补全: 稳定 key、selected、disabled、hover 或 focus smoke test。
- [x] 完成 Phase 2 图片组件测试补全: loading、error、cache manager、decode size、圆角 smoke test。
- [x] 启动 Phase 3 `AppSkeletonBlock`，基于 `shimmer` 统一骨架屏尺寸、圆角、颜色和禁用动画表现。
- [x] 启动 Phase 3 `AppRefreshIndicator`，基于 Flutter 原生 `RefreshIndicator` 统一下拉刷新体验。
- [x] 启动 Phase 3 `AppFeedback` / `AppToast`，收敛 SnackBar、Toast、Inline feedback 和后台任务反馈。
- [x] 启动 Phase 3 `AppBatchActionBar`，统一选择态、批量操作和危险批量确认。
- [x] 启动 Phase 3 `AppMenuButton` / `AppDropdownField`，基于 Flutter 原生 `MenuAnchor` / `DropdownMenu` 收口更多菜单、筛选菜单和表单下拉。

### 13.2 Week 2-3: 推荐完成

- [x] 选择 1 个低风险试点页面: Mine / `StorageManagementPage`。
- [x] 试点页面完整执行 Phase 4.2: 弹层、状态、卡片、Token、动效、操作反馈；图片占位由基础图片组件补齐。
- [x] 试点页面补齐 Phase 4.3 验收矩阵，并记录移动端、平板、桌面差异。
- [x] 建立试点页面性能基线: 首帧、滚动、图片尺寸约束、长列表 key、禁用动画表现。
- [x] 输出试点复盘: 哪些组件值得推广、哪些封装过重、哪些规则需要豁免。

### 13.3 Week 4+: 持续执行

- [x] Phase 6 自动化检查先上线报告模式，不直接阻断 CI。
- [x] 建立裸弹层、硬编码样式、业务页面直连第三方库、长列表性能问题的 baseline。
- [ ] 每周推广 1-2 个页面，优先处理高频路径和重复 UI 模式明显的页面。
- [x] 每轮至少沉淀 1 个可复用组件或删除 1 类重复 UI 写法。
- [x] 完成 MD3 菜单/下拉收尾: `PopupMenu*`、`DropdownButton*`、`DropdownMenuItem` 直接使用清零。
- [x] 根据试点和自动化误报持续调整 checklist，而不是一次性追求全量完美。

---

## 14. 风险提示

### 14.1 高风险操作（避免）

- [x] 不要同时启动多个 Phase，避免文档、组件、试点、自动化全部半成品。
- [x] 不要在 Reader 核心重构期强推阅读器核心页面 UI 治理。
- [x] 不要机械替换所有 Material 组件，已有 Theme 统一且无重复业务语义的组件可以保留。
- [x] 不要为了组件库完整度抽象低频组件，必须先证明存在重复模式。
- [x] 不要在业务页面直接接入新的 UI、动效、图片库并让库决定视觉风格。

### 14.2 中风险操作（谨慎）

- [x] 新增第三方库前必须评估 Flutter 原生能力、现有依赖、license、包体积、平台支持和测试成本。
- [x] 大范围动效改动前必须验证 `disableAnimations`、低端设备滚动和首帧表现。
- [x] 自动化检查上线前必须确认不会误杀 Adaptive 组件内部实现和合法例外。
- [x] 图片预览、拖拽、右键菜单等能力先做试点，不直接全项目推广。
- [x] 统一组件 API 不要一次设计过满，先覆盖真实页面，再根据复盘扩展。

### 14.3 低风险操作（推荐）

- [x] 优先补测试和 smoke，先让基础组件可回归。
- [x] 优先封装 Flutter 原生能力，例如刷新、排序、触觉反馈、快捷键和菜单。
- [x] 优先复用已有成熟依赖，例如 `flutter_animate`、`shimmer`、`flutter_slidable`、`cached_network_image`。
- [x] 优先选择 Mine 或 Bookshelf 的低风险局部做试点。
- [x] 优先把用户可感知体验补齐: 骨架屏、状态切换、图片淡入、操作成功/失败、撤销反馈。
