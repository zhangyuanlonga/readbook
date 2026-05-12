# 逐页面 UI 多端兼容展示计划

更新时间：2026-05-12  
用途：补齐功能兼容计划之外的 UI 展示计划，逐页面定义 Android、iOS、平板、macOS、Windows、Linux、Web 的展示模型、布局差异和验收标准。  
关系：本文件关注“看起来像对应平台的应用”；`docs/all_platform_compatibility_plan_2026-05-11.md` 关注“功能能不能用”。

组件治理：跨页面通用 UI 组件、弹层、空状态、加载态、列表和桌面交互的迁移任务见 `docs/page_ui_component_governance_plan_2026-05-12.md`。本文继续负责逐页面展示模型。

## 0. 结论先行

后续 UI 兼容按两套体验模型推进：

1. **Mobile Touch**
   Android / iOS 手机优先，使用底部导航、底部弹层、触控大按钮、纵向信息流。
2. **Desktop Like**
   Web、macOS、Windows、Linux 和宽窗口平板优先，使用侧边导航、顶部工具条、双栏/多栏、表格/列表密度、鼠标键盘路径。

不要再把 Web 和桌面端当作“手机 UI 放大版”。Web/桌面端可以和大屏平板共享部分结构，但默认交互心智应更接近桌面应用。

## 1. 平台展示分层

### 1.1 展示类

| 展示类 | 平台/窗口 | 导航 | 页面结构 | 操作模型 |
| --- | --- | --- | --- | --- |
| Mobile Touch | Android、iOS，宽度 `< 600dp` | 底部导航 | 单列、底部 Sheet | 触控、手势、长按 |
| Tablet Hybrid | 宽度 `600dp - 839dp` | NavigationRail | 双栏起步、内容适度居中 | 触控 + 指针 |
| Desktop Like | Web、macOS、Windows、Linux，宽度 `>= 600dp` | NavigationRail / 侧边栏 | 顶部工具条、双栏/三栏、列表/网格 | 鼠标、滚轮、键盘 |
| Wide Desktop | 宽度 `>= 1280dp` | 侧边栏 + 内容区 | 最大宽度、多栏、细分面板 | 扫描、批量、右键/快捷操作 |

### 1.2 判断原则

- 页面布局优先看 `AppAdaptiveMetrics.windowClass` 和窗口宽度。
- Web/桌面端即使窗口为 `600dp - 839dp`，也应优先走 Desktop Like 的导航和工具条心智。
- 手机横屏只是高度受限的 Mobile Touch，不等同桌面。
- 功能是否可用仍走 `AppPlatformCapabilities`，不要在页面里散落平台判断。

### 1.3 各端展示口径

Android / iPhone 手机：

- 底部导航、单列纵向页面、触控大按钮。
- 设置、筛选、更多操作优先使用底部 Sheet。
- 公告、轻提示使用顶部横幅，自动收起，不阻断启动和阅读。
- 大图、长详情可全屏打开；少用表格，多用列表和紧凑卡片。

iPad / Android 平板：

- `600dp+` 默认使用 NavigationRail。
- 常用页面从单列升级为双栏：左列表/导航，右详情/内容。
- 阅读器保持沉浸，但目录、书签、设置可侧栏化。
- 弹层优先 Dialog 或侧边面板，卡片尺寸和间距比手机收紧。

Web：

- 默认走 Desktop Like，不使用手机放大版。
- 侧边导航 + 顶部工具条 + 列表/表格/网格。
- 受限能力显示统一 disabled 面板，说明原因和替代路径。
- 弹窗使用 Dialog 或右侧面板；提示使用顶部横幅或右上状态浮层。
- 正文和详情限制最大宽度，不铺满浏览器。

macOS / Windows / Linux 桌面：

- 侧边导航 + 内容区，主要操作支持鼠标 hover、滚轮、键盘焦点。
- 文件、缓存、错误、同步、书签等管理页使用双栏/三栏。
- 资源管理使用顶部工具条 + 网格/列表 + 预览。
- 详情、确认、编辑使用 Dialog 或侧栏。
- 阅读器支持键盘翻页、滚轮、窗口缩放分页恢复。

宽屏桌面 / 大屏 Web：

- `1280dp+` 优先使用三栏或主内容 + 侧栏。
- 左侧导航，中间主列表/内容，右侧详情/预览/状态。
- 不出现超宽单列卡片；管理类页面优先表格化、批量化。
- 阅读正文限制最大行宽并居中。

手机横屏：

- 仍按 Mobile Touch 处理，不因为横屏切桌面导航。
- 优先解决高度不足：工具条收紧、Sheet 可滚动、避免 overflow。

## 2. 全局 UI 壳

### 2.1 App Shell / 主导航

目标：

- Mobile Touch：保留底部导航，适配安全区和键盘。
- Desktop Like：默认侧边导航，不展示 Cupertino Dock 或手机底栏。
- Wide Desktop：侧边导航可扩展为带分组、状态和快捷入口的应用栏。

待办：

- [x] 建立 `DesktopLike` 统一判断：Web 或桌面平台且宽度 `>= 600dp`。
- [x] `ShellScaffold` 在 Desktop Like 下强制使用 NavigationRail / 侧边栏。
- [x] 移除 Web/桌面页面内容对 `mobileBottomNavigationBodyPadding` 的依赖。
- [ ] 侧边导航增加 hover、焦点态和可扫描的选中态。

验收：

- `390x844` 使用底部导航。
- `600x960` 使用 NavigationRail。
- `1280x800`、`1440x900`、Web 默认窗口使用桌面导航，不出现手机底栏。

### 2.2 全局弹窗 / Sheet / SnackBar

目标：

- Mobile Touch：底部 Sheet 优先。
- Desktop Like：Dialog、Popover、侧栏面板优先。
- 所有弹窗高度不足时内部滚动，不允许 RenderFlex overflow。

待办：

- [x] 建立通用 `AdaptiveActionSurface`：移动端 bottom sheet，桌面端 dialog/popover。
- [ ] 公告、更新、导入导出进度、错误提示接入统一最大宽度和滚动约束。
  - [x] 启动公告改为全平台应用内顶部横幅，自动收起，保留查看公告详情入口。
- [ ] 所有弹窗覆盖 `1.3x` 文字缩放。

## 3. P0 页面展示计划

### 3.1 首页 `HomePage`

Mobile Touch：

- 打卡、继续阅读、阅读目标纵向排列。
- 横向列表可滑动，底部导航不遮挡主操作。

Desktop Like：

- 顶部为阅读概览工具条。
- 左侧继续阅读/最近记录，右侧统计、目标、快捷入口。
- 排行、推荐、目标卡片采用多栏，不要单列拉宽。

待办：

- [x] Desktop Like 改为概览 dashboard。
- [ ] 继续阅读区域支持鼠标滚轮、hover 操作。
- [ ] 空状态在宽屏居中但不大卡片化。

### 3.2 书架页 `BookshelfPage`

Mobile Touch：

- 搜索、筛选、视图切换保持顶部紧凑。
- 网格/列表适配触控点按。

Desktop Like：

- 顶部固定工具条：搜索、筛选、排序、视图、选择、导入。
- 左侧可选筛选栏或状态摘要，右侧主内容网格/列表。
- 网格列数按内容区重排，列表模式信息密度高于移动端。

待办：

- [x] 已有 expanded 工具条和网格重排基础。
- [x] Web/桌面强制默认展示桌面工具条，避免仍像手机顶栏。
- [ ] 列表模式补 hover、键盘焦点、批量选择可见状态。
- [x] 去掉桌面端底部导航舒适 inset。

### 3.3 本地书库页 `LocalLibraryPage`

Mobile Touch：

- 导入入口突出，导入状态清晰。
- 文件列表单列。

Desktop Like：

- 文件管理器心智：顶部导入工具条 + 状态汇总 + 可排序列表。
- 右侧/顶部展示索引状态、格式、更新时间、操作按钮。
- Web 受限时展示说明面板，不留空白。

待办：

- [x] 已有桌面文件管理视图基础。
- [x] 桌面列表改为更接近表格的列布局。
- [ ] 受限平台导入面板使用统一 disabled 状态。

### 3.4 书籍详情页 `BookDetailPage`

Mobile Touch：

- 封面、标题、主操作、简介、目录纵向排列。
- 主按钮固定可见，不被底部导航遮挡。

Desktop Like：

- 左侧封面/元信息，右侧简介、目录、阅读操作。
- 宽屏可三栏：封面信息、简介/元数据、目录/本地索引。
- 本地图书编辑、封面、重索引用侧栏或 Dialog。

待办：

- [x] 已有宽屏封面/信息/目录分区基础。
- [x] Desktop Like 下主操作改为顶部/右栏按钮组，不像手机四宫格。
- [ ] 目录区域在宽屏保持独立滚动。
- [ ] 书源关闭时“书源”操作禁用态文案更明确。

### 3.5 阅读器 `ReaderPage`

Mobile Touch：

- 手势翻页/滚动优先。
- 设置使用底部 Sheet。
- 目录和书签用全屏或底部面板。

Desktop Like：

- 键盘、鼠标滚轮、点击区域并存。
- 设置使用右侧面板，目录/书签可用侧栏。
- 内容宽度、行长、背景留白按阅读舒适度限制，不铺满宽屏。

待办：

- [x] 阅读设置已具备桌面侧栏基础。
- [x] 桌面目录/书签侧栏化。
- [x] 键盘翻页、滚轮阅读、窗口缩放分页恢复进入 UI 验收。
- [x] 宽屏下阅读正文最大行宽和页边距统一。

### 3.6 阅读记录页 `ReadingRecordsPage`

Mobile Touch：

- 日历/热力图、统计卡片、记录列表纵向排列。

Desktop Like：

- 左侧日历/热力图，右侧统计和最近记录。
- 宽屏统计卡片三列，记录列表可扫描。

待办：

- [ ] Desktop Like 双栏化。
- [ ] 长书名/章节名 hover tooltip 或次行展示。

### 3.7 我的页 `MinePage`

Mobile Touch：

- 用户卡片 + 设置入口列表。

Desktop Like：

- 左侧账号/快捷入口，右侧设置分组。
- 设置项密度降低大卡片感，更多使用分组列表。

待办：

- [x] 已有 expanded 双栏基础。
- [x] Web/桌面默认进入双栏，即使高度较低也不退回手机感大卡片。
- [x] 管理入口改为桌面工作台式分组。

### 3.8 系统设置页 `SystemSettingsPage`

Mobile Touch：

- 设置项单列，说明文字可换行。

Desktop Like：

- 双栏设置组，右侧可放预览/说明。
- 数字输入、开关、选择器对齐成表单行。

待办：

- [x] 已有桌面双栏基础。
- [x] 所有 trailing 控件桌面对齐。
- [ ] 长说明文字桌面端不撑高整页。

## 4. P1 页面展示计划

### 4.1 外观设置 `AppearancePage`

Desktop Like 目标：

- 左侧分类导航：主题、背景、启动图、封面、底栏图标、字体。
- 右侧资源列表/预览区。
- 图片资源管理使用网格 + 详情侧栏，不用手机大卡片流。

待办：

- [ ] 外观首页桌面分栏。
- [x] 资源图库统一桌面网格密度和批量操作条。
- [ ] Web 受限资源导入展示统一 disabled 面板。

### 4.2 高级主题列表/编辑 `AdvancedThemeListPage` / `AdvancedThemeEditorPage`

Desktop Like 目标：

- 列表页：左侧主题列表，右侧预览。
- 编辑页：左侧 token/分组导航，中间表单，右侧实时预览。

待办：

- [ ] 编辑页从长表单改为三栏工作台。
- [ ] 颜色、背景、字体等控件桌面端紧凑对齐。

### 4.3 缓存管理 `CacheManagementPage`

Desktop Like 目标：

- 顶部总览，下面分组列表。
- 清理操作按钮对齐右侧，危险操作二次确认。
- Web 受限路径显示说明，不展示不可点击失败入口。

待办：

- [x] 已接入受限存储提示。
- [x] 桌面分组列表密度优化。
- [x] 明细弹层桌面改 Dialog。

### 4.4 错误中心 `ErrorCenterPage`

Desktop Like 目标：

- 左侧日志列表，右侧详情/复制/导出操作。
- 筛选、等级、时间范围在顶部工具条。

待办：

- [x] 已接入受限诊断提示。
- [x] 桌面双栏日志查看器。
- [x] 长日志详情独立滚动。

### 4.5 书签页 `BookmarksPage`

Desktop Like 目标：

- 顶部按书籍/时间/章节筛选。
- 左侧书籍分组，右侧书签列表。
- 跳转阅读位置操作清晰。

待办：

- [x] 双栏书签管理。
- [x] 长文本摘要和章节名桌面密度优化。

### 4.6 字体/背景/封面/启动图/底栏图标资源页

覆盖页面：

- `FontManagementPage`
- `ReaderBackgroundPage`
- `CoverGalleryPage` / `CoverGalleryEditorPage`
- `LaunchImageGalleryPage` / `LaunchImageGalleryEditorPage`
- `BottomNavIconGalleryPage` / `BottomNavIconGalleryEditorPage`

Desktop Like 目标：

- 统一资源管理模型：左侧资源集，右侧网格/预览/编辑。
- 顶部工具条：导入、筛选、排序、批量操作。
- 编辑页保留实时预览。

待办：

- [x] 统一资源页桌面布局模板。
- [ ] Web 受限导入统一禁用。
- [ ] 大图预览桌面 Dialog，移动端全屏/底部。

### 4.7 搜索页 `SearchPage`

首版功能口径：

- 在线搜索属于书源延期能力。
- 首版可改为本地搜索，或显示统一占位。

Desktop Like 目标：

- 如果启用本地搜索：左侧筛选，右侧结果列表/网格。
- 如果禁用：展示非空白占位，说明当前首版聚焦本地阅读。

待办：

- [ ] 明确搜索页首版是本地搜索还是占位。
- [ ] Desktop Like 下不要显示手机大输入卡片居中拉宽。

### 4.8 发现页 `DiscoverPage`

首版功能口径：

- 在线发现属于书源延期能力。

Desktop Like 目标：

- 首版若禁用，展示统一占位。
- 后续若恢复，使用左侧分类/来源栏 + 右侧内容网格。

待办：

- [ ] 首版占位状态统一。
- [ ] 取消在线发现未启用时的空白或半可用状态。

## 5. P2/P3 页面展示计划

### 5.1 同步设置/历史

页面：

- `SyncSettingsPage`
- `SyncHistoryPage`

Desktop Like 目标：

- 设置页：左侧 profile 列表，右侧连接/范围/冲突策略。
- 历史页：任务列表 + 详情面板。
- 首版默认 WebDAV 关闭时展示统一占位。

待办：

- [x] 默认关闭时已有占位页。
- [ ] 启用后补桌面双栏。

### 5.2 公告列表/详情

Desktop Like 目标：

- 列表页：左侧列表，右侧详情预览。
- 详情页正文最大宽度，不无限拉宽。

待办：

- [ ] 公告列表桌面双栏。
- [ ] 公告详情正文宽度限制和长文滚动。

### 5.3 登录/用户资料/会员/反馈

页面：

- `AuthPage`
- `UserProfilePage`
- `MembershipCenterPage`
- `FeedbackPage`

Desktop Like 目标：

- 表单宽度受限，居中或双栏。
- 反馈列表/详情用列表 + 详情面板。
- 会员中心权益和操作区多栏展示。

待办：

- [ ] 登录表单桌面宽度和键盘路径。
- [ ] 反馈桌面列表/详情分栏。
- [ ] 会员中心多栏重排。

### 5.4 关于页

Desktop Like 目标：

- 品牌区、版本信息、技术栈、链接按钮分栏展示。
- 不使用超大移动端卡片。

待办：

- [x] 已有 expanded 宽屏基础。
- [ ] 桌面端信息密度复核。

## 6. 延期书源页面 UI 口径

页面：

- `SourcePage`
- `SourceLoginPage`
- `SourceWebLoginPage`
- `ScriptSourceEditorPage`
- `ScriptSourcePasteImportPage`
- `ScriptSourceDebugPage`

首版：

- 默认不进入主验收。
- 所有入口必须通过 capability 进入统一占位。
- 如果开发者开启书源能力，再按桌面工作台验收。

后续 Desktop Like 目标：

- 书源列表：左侧分组/筛选，右侧列表/详情。
- 脚本编辑：工具栏 + 代码区 + 调试/日志面板。
- Web 登录：桌面端窗口化 WebView，移动端全屏。

## 7. 执行阶段

### UI 阶段 A：壳与判定统一

- [x] 新增 Desktop Like 统一判断。
- [x] 主导航 Web/Desktop 强制侧边导航。
- [x] 移除核心页面 Web/Desktop 的底部导航 inset。
- [x] 建立通用 adaptive surface：mobile sheet / desktop dialog。

验收：

- Web、macOS、Windows、Linux 默认窗口不出现手机底栏。
- `600x960` 与 `1280x800` 下主壳结构稳定。

### UI 阶段 B：核心 P0 页面桌面化

- [x] 首页 dashboard 化。
- [x] 书架桌面工具条默认化。
- [x] 本地书库表格/文件管理化。
- [x] 书籍详情右栏/目录滚动优化。
- [x] 我的/设置桌面分组密度优化。

验收：

- `1280x800` 下核心页面不像手机单列放大。
- 鼠标滚轮和 hover 不破坏操作。

### UI 阶段 C：阅读器桌面体验

- [x] 阅读正文最大行宽和页边距统一。
- [x] 目录/书签桌面侧栏。
- [x] 设置面板桌面右侧常驻/浮层。
- [x] 键盘翻页、滚轮、窗口缩放恢复。

验收：

- 桌面端能不用触屏完成阅读、目录、设置、书签。

### UI 阶段 D：资源与管理页桌面化

- [x] 外观、背景、封面、启动图、底栏图标统一资源管理模板。
- [x] 缓存、错误中心、书签、同步历史双栏化。
- [x] Web 受限导入/导出统一 disabled 状态。

验收：

- 资源管理页面使用工具条 + 网格/列表 + 预览，不是移动端卡片流。

### UI 阶段 E：真实端截图验收

- [ ] Web Chrome
- [ ] macOS
- [ ] Windows
- [ ] Linux
- [ ] Android
- [ ] iOS

截图矩阵：

- `390x844 @1.0`
- `390x844 @1.3`
- `600x960 @1.0`
- `840x1180 @1.0`
- `1280x800 @1.0`
- `1440x900 @1.0`
- `1920x1080 @1.0`

保存路径：

```text
artifacts/adaptive_baseline/page_ui_multiplatform/<page>/<viewport>_text-<scale>.png
```

## 8. 验收底线

- Web/Desktop 默认窗口不得展示手机底部导航。
- `600dp+` 不得只是手机单列拉宽。
- `840dp+` 核心页面必须有宽屏结构或明确最大宽度。
- 桌面端所有主要操作必须支持鼠标点击、滚轮、键盘焦点。
- Web 受限能力不得空白，不得显示可点击但必失败入口。
- 弹窗、卡片、工具条在 `1.3x` 文字下不得 overflow。
- 真实端 run 日志中出现 RenderFlex overflow 视为失败。

## 9. 与现有文档联动

- 功能范围：`docs/all_platform_compatibility_plan_2026-05-11.md`
- 架构约束：`docs/development_architecture_guardrails.md`
- 组件治理：`docs/page_ui_component_governance_plan_2026-05-12.md`
- Scaffold 审计：`docs/page_ui_scaffold_audit_2026-05-12.md`
- 状态组件审计：`docs/page_ui_state_component_audit_2026-05-12.md`
- 弹层审计：`docs/page_ui_modal_surface_audit_2026-05-12.md`
- 视口矩阵：`docs/flutter_adaptive_baseline_matrix.md`
- 人工回归清单：`docs/adaptive_visual_regression_checklist.md`

后续每执行完一个 UI 阶段，需要同时更新本文件的勾选状态和执行记录；如果涉及通用组件、弹层、状态组件、列表/卡片或桌面交互，还需要同步更新组件治理计划。

## 10. 执行记录

### 2026-05-12 UI 阶段 A/B

- 阶段 A：新增 `AppAdaptiveMetrics` / `AppLayout` 的 Desktop Like 判断，主壳 600dp+ 使用 `NavigationRail`，移动底栏 inset 在 600dp+ 清零，并新增 `AdaptiveActionSurface` 与桌面化 `AppTaskBottomSheet` 约束。
- 阶段 B：首页改为 600dp+ dashboard；书架 600dp+ 默认桌面工具条；本地书库 600dp+ 使用导入/状态双栏和列式文件信息；书籍详情 600dp+ 使用左封面、中简介、右操作分栏；我的和系统设置 600dp+ 默认分组双栏。
- 验证：`flutter analyze` 通过；`flutter test test/app/layout/app_adaptive_metrics_test.dart test/features/book/presentation/book_detail_sections_test.dart test/features/presentation/page_adaptive_smoke_test.dart` 通过。

### 2026-05-12 UI 阶段 C

- 阅读器目录/书签在 Desktop Like 下改为右侧抽屉式面板，移动端继续保留底部 Sheet。
- 宽屏阅读正文通过 `ReaderLayoutResolver` 统一限制最大行宽并居中，滚动和分页共用同一套 surface metrics，窗口缩放后分页签名随内容区域变化自然恢复。
- 阅读器根节点新增焦点和键盘路径，支持方向键、PageUp/PageDown、Space、Home/End、Escape；分页阅读支持鼠标滚轮翻页，滚动阅读保留原生滚轮滚动。
- 验证：`flutter analyze` 通过；`flutter test test/features/reader/application/reader_layout_resolver_test.dart test/features/reader/application/reader_pagination_spec_resolver_test.dart test/features/reader/application/reader_experience_baseline_test.dart test/features/reader/presentation/reader_navigation_presenter_test.dart test/features/reader/presentation/reader_paged_viewport_controller_test.dart` 通过。

### 2026-05-12 UI 阶段 D

- 封面图集、启动图集、底栏图集在 600dp+ 改为工具条 + 多列网格，阅读背景已有桌面网格；移动端继续保留原单列/触控路径。
- 错误中心在桌面端改为左日志列表、右独立滚动详情；书签页改为左书籍分组、右章节灵感详情；同步历史 600dp+ 任务/冲突并排。
- 缓存管理明细在桌面端改为 Dialog，移动端继续使用 bottom sheet；受限存储/诊断提示保持可见且不可误触失败入口。
- 验证：`flutter analyze` 通过；`flutter test test/features/mine/presentation/mine_management_page_test.dart test/features/mine/presentation/advanced_theme_pages_smoke_test.dart test/features/mine/application/cache_management_service_test.dart test/features/mine/application/bookmarks_query_service_test.dart test/features/mine/application/launch_image_gallery_service_test.dart test/app/navigation/bottom_nav_icon_gallery_service_test.dart` 通过。

### 2026-05-12 我的页多端展示优化

- `MinePage` 在没有用户偏好时，600dp+ 默认使用网格入口，手机继续默认列表；宽屏下左侧账号/快捷区固定宽度，右侧管理入口进一步拆成工作台式分组。
- 用户卡片在桌面端去掉手机列表式尾部占位和箭头，登录状态 chip 只在未登录时展示，减少横向空洞。
- 列表模式从过度紧凑改为舒适设置列表，网格模式从宽松卡片改为桌面快捷入口，两种模式共享更接近的标题、图标、间距节奏。
- 移动端列表分组与顶部用户卡保持同宽；桌面端取消左侧独立账号栏，改为顶部账号/快捷入口横排、下方统一管理区，避免左侧大面积留白。
- 验证：`flutter analyze` 通过；`flutter test test/features/mine/application/mine_page_preferences_service_test.dart test/features/mine/application/mine_page_session_service_test.dart test/features/mine/presentation/mine_management_page_test.dart` 通过。

### 2026-05-12 外观/高级主题桌面展示优化

- 外观页在 840dp+ 改为两列工作台：左侧基础外观（模式、颜色、高级主题状态），右侧导航、底部菜单、字体和其他设置；移动端继续单列。
- 高级主题列表在 840dp+ 改为左侧搜索/主题列表、右侧主题预览与操作面板；移动端继续保留单列主题卡。
- 验证：`flutter analyze` 通过；`flutter test test/features/mine/presentation/advanced_theme_pages_smoke_test.dart` 通过。

### 2026-05-12 UI-G0/G1 组件治理

- 新增 `docs/page_ui_component_governance_plan_2026-05-12.md` 的 G0/G1 执行状态，明确新页面默认使用 adaptive 基线组件，旧页面按高频核心页、管理页、能力页、低频静态页顺序迁移。
- 新增 `docs/page_ui_scaffold_audit_2026-05-12.md`，将 55 处裸 `Scaffold(` 分为 shell、adaptive 内部、已完成大屏结构、可迁移优先、专用保留、低优先级能力页。
- G1 不做批量替换页面代码，后续跟随状态组件、弹层、列表卡片和桌面交互阶段逐步迁移。

### 2026-05-12 UI-G2/G3 组件治理

- 新增 `docs/page_ui_state_component_audit_2026-05-12.md`，完成状态组件静态审计和页面优先级归档。
- 新增 `docs/page_ui_modal_surface_audit_2026-05-12.md`，完成弹层/反馈静态审计和页面优先级归档。
- 新增 `showAdaptiveActionSurface<T>` 作为统一弹层入口，并将搜索失败明细迁移为样板；移动端继续 bottom sheet，Web/桌面端使用 dialog surface。
