# App 组件库与高级主题业务审查

日期: 2026-06-19  
范围: 基础组件、组件样板页、高级主题增删改查会员边界、主题对全局 UI 的控制度  
结论: 现在已经有一批可复用基础组件和高级主题 token，但还没有形成一套稳定的 App UI Kit。下一阶段应先把组件目录、状态、动效、截图回归和主题控制边界固化，再逐步迁移业务页面。

## 1. 产品视角结论

当前主题和组件能力已经能支撑日常阅读 App 的基础观感，但用户能感知到的体验还不够统一:

- 官方主题预设已经适合作为免费默认外观能力，不能让用户感觉“不开会员就只能用旧蓝色默认 UI”。
- 自定义高级主题适合承载深度定制、资源绑定、导入导出和主题资产管理，是会员权益。
- 组件库现在更像“分散的可复用组件”，还不是“可被快速查阅、可验证、可回归”的标准组件库。
- 组件样板页应成为内部视觉 QA 入口，用于快速检查不同主题、明暗模式、状态和动效是否被全局 token 控住。

## 2. 已有组件盘点

### 2.1 基础与自适应组件

主要位置:

- `lib/app/widgets/foundation/`
- `lib/app/widgets/`
- `lib/app/motion/`
- `lib/app/theme/app_component_theme_tokens.dart`

当前可作为 App UI Kit 基线的组件:

- 操作: `AppButton`、`AppMenuButton`、`AppContextMenu`、`AppBatchActionBar`
- 表单: `AppTextField`、`AppDropdownField`
- 选择: `AppSelectionIndicator`
- 反馈: `AppFeedback`、`RuntimeFeedbackCard`
- 状态: `AppEmptyStateCard`、`AppStatusStateCard`、`AppSkeletonList`、`AppSkeletonBlock`
- 列表: `AdaptiveListTile`、`AdaptiveSettingTile`、`AppReorderableList`、`AppSlidableActionTile`
- 容器: `AdaptiveCard`、`AdaptiveContentContainer`、`AdaptivePageScaffold`
- 导航与工具条: `AdaptiveRouteTopBar`、`AdaptiveOverflowToolbar`、`AdaptiveSearchBar`、`AdaptiveFilterBar`
- 弹层: `AdaptiveBottomSheet`、`AppTaskBottomSheet`、`ImportExportTaskSheet`
- 图片: `DiskCachedCoverImage`、`ResolvedBookCover`、`TextCoverPlaceholder`、`AppImageViewer`
- 动效: `AppFadeSlideTransition`、`AppMotion`、主题切换 reveal

### 2.2 当前组件样板入口

页面:

- `lib/features/mine/presentation/component_demo_page.dart`

路由:

- `/appearance/component-demo`: 跟随当前主题，作为关于页默认入口
- `/appearance/component-demo`: 固定 Lumina 视觉基线，作为唯一内部组件样板入口；由于默认官方主题已经是 Lumina，普通用户侧不再单独暴露额外对照入口

入口:

- 关于页面新增“组件样板”卡片，方便从“我的/关于”快速进入。

当前样板覆盖:

- 搜索框、按钮、下拉框、单选、多选、标签、开关、滑条
- 列表、设置项
- 加载骨架、空状态、警告状态、错误状态
- 当前主题真实效果；当用户切换到非 Lumina 主题后，可与内部 Lumina 基线路由对照

## 3. 高级主题业务边界

### 3.1 免费能力

- 所有用户都能进入高级主题列表。
- 官方主题预设免费可见、可搜索、可直接启用。
- 官方主题只作为内置主题包存在，不写入用户自定义主题列表。
- 当前默认回落为 `official:lumina`，避免旧 seed 蓝色继续主导默认外观。

### 3.2 会员能力

自定义高级主题相关操作需要会员:

- 创建自定义主题
- 编辑自定义主题
- 启用自定义主题
- 复制自定义主题
- 删除自定义主题
- 批量管理、批量分类、批量导出
- 导入主题包、导出主题包
- 自定义资源绑定与资产管理

实现上，列表页通过 `AdvancedThemeAccessController` 读取会员权益，核心判断字段是 `hasThemeCustom`。如果会员权益失效，并且当前启用的是自定义主题，会恢复默认官方主题。

### 3.3 业务风险

- 会员判断散落在页面动作前置 guard，用户操作链路清晰，但未来新增入口时容易漏 guard。
- 官方主题和自定义主题混排展示是对的，但必须持续保证官方主题没有“编辑/复制/导出/删除”入口。
- 导入入口要继续确认外部分享、批量导入、文件选择三条路径都经过会员 gate。
- 权益失效后自动恢复默认主题是正确策略，但需要保留提示和测试，避免用户误以为主题丢失。

## 4. 高级主题对全局的掌控度

### 4.1 已掌控

高级主题和官方主题目前已经能影响:

- `ColorScheme`: primary、secondary、tertiary、surface、error 等语义色
- 明暗模式: 同一主题内的 lightConfig / darkConfig
- 背景: App 背景、surface 背景、可选壁纸和 backdrop
- 组件形态: card、button、input、overlay、navigation、selection token
- 阴影和边框: card / overlay / navigation 的边框、阴影强度
- 字体绑定: App 界面字体、阅读器字体
- 阅读器视觉: 阅读背景、阅读排版关联能力
- 资源绑定: 封面图库、启动图图库、底部导航图标图库

### 4.2 尚未完全掌控

- 仍有业务页面可能直接使用 `Colors.*`、硬编码圆角、硬编码阴影或局部 `Container` 样式。
- 状态组件虽然存在，但 loading / empty / error / locked / no-permission / offline / progress 的视觉语义还未完全标准化。
- 动效没有形成完整 motion spec，页面进入、列表更新、弹层、主题切换、状态切换仍有各自实现。
- 组件样板还缺少截图基线和跨端验收记录。
- 组件 API 分层还不够稳定，哪些场景用 Material 原生、哪些必须用 App 组件，需要更明确。

## 5. 组件库下一阶段目标

### 5.1 分层

- Token 层: color、spacing、radius、elevation、border、motion、typography
- Primitive 层: button、input、icon button、surface、text、skeleton
- Composite 层: card、list tile、section、toolbar、state view、sheet、dialog
- Domain Pattern 层: book card、source card、theme card、import task card、reader setting row

### 5.2 状态标准

需要补齐并在样板页展示:

- loading: skeleton、inline loading、button loading、task loading
- empty: 首次空、筛选空、数据清空后空
- error: 可重试错误、不可恢复错误、导入失败
- locked: 会员锁定、平台不可用、未登录
- offline: 网络不可用、同步暂停
- progress: 导入导出、下载、解析、批处理
- disabled: 权限不足、依赖未满足、处理中

### 5.3 动效标准

优先沉淀:

- 页面进入: 轻量 fade + slide
- 卡片出现: 分组节制动画，不能长列表全量重动画
- 弹层: 移动端 bottom sheet、桌面 dialog 过渡统一
- 状态切换: loading -> content、content -> empty、error -> retry
- 主题切换: 保留 reveal，但样板页要能检查切换后组件 token 是否同步
- 禁用动画: 遵守 `MediaQuery.disableAnimations` 和 `AppMotion`

## 6. 验收清单

- [x] 关于页提供组件样板入口。
- [x] 关于页只暴露当前主题样板，避免默认 Lumina 与固定 Lumina 重复。
- [x] 样板页覆盖基础控件、列表、设置项、加载、空态、警告和错误态。
- [ ] 为组件样板页补 light / dark / desktop / mobile 截图基线。
- [ ] 为 App UI Kit 建立组件索引表: 组件名、使用场景、替代旧写法、主题 token 依赖。
- [ ] 抽一个业务页做完整迁移复盘，记录哪些组件 API 过重或缺口明显。
- [ ] 增加自动扫描: 新增 `Colors.*`、硬编码圆角、硬编码阴影时提示审查。
- [ ] 补齐会员 gate 测试: 创建、编辑、复制、导入、导出、删除、启用自定义主题。

## 7. 建议优先级

P0:

- 补齐组件样板截图基线。
- 固化 App UI Kit 组件索引。
- 把高级主题会员 gate 覆盖到测试。

P1:

- 做统一 `AppStateView`，承接 loading / empty / error / locked / offline / progress。
- 做统一 motion spec，并让新组件默认读取 `AppMotion`。
- 清扫 Mine、Appearance、Bookshelf 高频页面里的硬编码样式。

P2:

- 为主题矩阵增加视觉回归: Lumina、Mono Blue、Ink Green、Selune Warm，light / dark。
- 将业务模式组件标准化: book card、theme card、source card、reader setting row。
