# Flutter 自适应改造阶段计划

更新时间：2026-05-09  
用途：把当前 Flutter 项目的自适应改造拆成可执行、可验收、可打勾的阶段任务。  
范围：先处理布局、密度、组件和页面结构，不处理主题、品牌色、阴影和高级视觉效果。

## 1. 改造目标

本计划解决的问题不是“适配某几台手机”，而是建立一套在手机、横屏、折叠屏、平板和桌面窗口下都稳定工作的 Flutter 自适应体系。

核心目标：

- 小屏不溢出，不遮挡，不因为固定尺寸导致内容被挤掉
- 常规手机首屏信息量合理，不因为过大留白显得空
- 大手机和横屏能提升内容密度，而不是只放大手机布局
- `600dp+` 能进入中屏结构，适合 `NavigationRail`、双栏或更高列数
- `840dp+` 能进入扩展结构，避免内容区过宽、过散
- 字体放大、系统导航栏、键盘、横竖屏切换都不会破坏布局

## 2. 基本原则

- [x] 不再按机型名做适配，例如 `iPhone SE`、`iPhone 16`、某个 Android 型号
- [x] 页面结构优先看当前可用约束：`LayoutBuilder` / `SliverLayoutBuilder`
- [x] 全局壳层和导航结构可以看窗口宽度：`MediaQuery.sizeOf(context)`
- [x] 文字缩放必须纳入密度判断：`MediaQuery.textScalerOf(context)`
- [x] 组件尺寸不散落写死，统一从 adaptive tokens 获取
- [x] 网格列数优先按最小 item 宽度计算，而不是按固定机型或固定宽度表
- [x] 信息流页面以重排为主，不采用全页面等比缩放
- [x] 控制面板可以做小范围密度缩放，但不能替代结构重排

## 3. 推荐技术组合

继续使用当前项目已有技术，不引入以设计稿比例缩放为主的依赖。

- [x] 保留 `responsive_framework`，用于应用级断点和外层响应
- [x] 使用 `MediaQuery` 获取窗口尺寸、方向、文字缩放和安全区
- [x] 使用 `LayoutBuilder` 处理页面主体、卡片区、表单区、列表区
- [x] 使用 `SliverLayoutBuilder` 处理书架、搜索结果、瀑布/网格等 sliver 内容
- [x] 使用 Riverpod 保存用户选择的布局偏好，例如书架列表/网格、固定列数/自动列数
- [x] 暂不引入 `flutter_screenutil` 作为主方案

## 4. 统一模型

### 4.1 Window Class

窗口分级只表达页面结构，不表达具体控件密度。

- `compact`
  宽度 `< 600dp`，主要是手机和窄窗口
- `medium`
  宽度 `600dp - 839dp`，主要是折叠屏、小平板、横屏大手机
- `expanded`
  宽度 `>= 840dp`，主要是平板、桌面和宽窗口

任务：

- [x] 新增 `AppWindowClass`
- [x] 将现有 `AppWidthBucket` 与新模型做兼容映射
- [x] 明确 `390dp`、`480dp` 只作为手机内部密度辅助，不作为主结构断点
- [x] 保留 `600dp` 和 `840dp` 作为主结构断点

### 4.2 Density

密度表达同一结构下的尺寸、间距和信息量。

- `compact`
  小屏、横屏、字体放大、可用高度不足
- `regular`
  常规手机默认状态
- `comfortable`
  中大屏或内容空间充足

任务：

- [x] 新增 `AppDensity`
- [x] 密度计算同时参考宽度、高度、短边、方向和文字缩放
- [x] 当文字缩放较大时，优先降低密度而不是硬压文本
- [x] 当横屏高度不足时，优先降低垂直留白

### 4.3 Adaptive Metrics

页面和组件只读取 metrics，不直接散落判断逻辑。

建议字段：

- `windowClass`
- `density`
- `pagePadding`
- `contentGap`
- `sectionGap`
- `cardPadding`
- `cardRadius`
- `listTileMinHeight`
- `controlHeight`
- `iconButtonSize`
- `chipHeight`
- `bottomSheetMaxWidth`
- `dialogMaxWidth`
- `gridMinItemWidth`

任务：

- [x] 新增 `lib/app/layout/app_adaptive.dart`
- [x] 实现 `AppAdaptiveMetrics.resolve(BuildContext context)`
- [x] 实现 `AppAdaptiveMetrics.resolveForConstraints(...)`
- [x] 提供常用 helper：`AppAdaptiveMetrics.of(context)`
- [x] 为 sliver 场景提供基于 `constraints.crossAxisExtent` 的 resolve 方法
- [x] 写单元测试覆盖 360、390、412、600、840、1200 宽度

## 5. 阶段计划

## 阶段 0：基线审查与截图矩阵

目标：先知道“改造前长什么样”，后续每一步都有对照。

范围：

- 书架页
- 搜索页
- 书籍详情页
- 我的/设置页
- 阅读设置弹层

任务：

- [x] 整理当前已有自适应文档，不删除历史审计
- [x] 确认 5 个标准宽度：`360`、`390`、`412`、`600`、`840`
- [x] 增加横屏检查宽度：`780x360` 或等效窗口
- [x] 增加文字缩放检查：`1.0x`、`1.3x`
- [ ] 为 P0 页面保存改造前截图
- [x] 记录当前主要问题：溢出、遮挡、空、过挤、留白过大、信息量不足

验收：

- [ ] 每个 P0 页面至少有手机、小屏、大手机、中屏截图
- [x] 问题列表能对应到具体页面和组件

## 阶段 1：自适应基础设施

目标：建立统一判断模型，避免后续继续按机型或页面各写一套。

涉及文件：

- `lib/app/layout/app_layout.dart`
- `lib/app/layout/app_spacing.dart`
- `lib/app/layout/app_adaptive.dart`

任务：

- [x] 新增 `AppWindowClass`
- [x] 新增 `AppDensity`
- [x] 新增 `AppAdaptiveMetrics`
- [x] 将现有 `pageHorizontalForWidth`、`cardHorizontalForWidth` 逐步接入 metrics
- [x] 保留现有 `AppLayout` API，避免一次性大面积破坏调用方
- [x] 标注旧 helper 的推荐替代路径
- [x] 为 metrics 增加测试
- [x] 在文档中明确：页面结构看 window class，组件尺寸看 density

验收：

- [x] 项目能通过 `flutter analyze`
- [x] 新增测试覆盖主要宽度和文字缩放
- [x] 至少一个页面能读取 metrics，但页面视觉可暂不大改

## 阶段 2：书架页试点

目标：用最能感知信息量的书架页验证新体系。

涉及文件：

- `lib/features/bookshelf/presentation/bookshelf_page.dart`
- `lib/features/bookshelf/presentation/widgets/bookshelf_grid_sliver.dart`
- `lib/features/bookshelf/presentation/widgets/bookshelf_page_sections.dart`

任务：

- [x] 书架网格列数改为按容器宽度和最小 item 宽度计算
- [x] 将 `crossSpacing`、`mainSpacing`、`itemHeightExtra` 接入 adaptive metrics
- [x] 搜索栏高度、chip 高度、筛选区间距接入 adaptive metrics
- [x] 小屏降低垂直留白，避免首屏只看到很少内容
- [x] 大手机允许提升信息密度，而不是保持小屏布局
- [x] `600dp+` 检查是否需要更高列数或内容限宽
- [x] 保留用户手动固定列数能力，自动列数只在 adaptive 模式下生效
- [x] 处理文字缩放 `1.3x` 下标题和摘要溢出

验收：

- [x] 360 宽度至少 2 列且无横向溢出
- [x] 390/412 宽度信息量比当前更稳定，不出现大面积空白
- [x] 600 宽度能自然提升列数或改善内容分布
- [x] 840 宽度内容不无节制拉宽
- [x] 字体放大到 `1.3x` 时标题、筛选、搜索不炸布局

## 阶段 3：通用组件抽取

目标：把书架试点中有效的尺寸策略沉淀成组件，避免每个页面重复写。

建议新增或改造组件：

- `AdaptivePageScaffold`
- `AdaptiveContentContainer`
- `AdaptiveCard`
- `AdaptiveListTile`
- `AdaptiveSearchBar`
- `AdaptiveFilterBar`
- `AdaptiveGridSliver`
- `AdaptiveBottomSheet`

任务：

- [x] 抽取通用内容容器，统一 page padding 和 max width
- [x] 抽取紧凑列表项，支持 leading、title、subtitle、trailing、badge
- [x] 抽取紧凑搜索栏，支持 summary、clear、filter action
- [x] 抽取筛选 chip bar，统一 chip 高度和横向间距
- [x] 抽取 grid sliver，统一按 min item width 算列数
- [x] 抽取 bottom sheet 尺寸 helper，统一高度比例和最大宽度
- [x] 为通用组件写最小 widget test

验收：

- [x] 书架页不再直接维护大量固定搜索栏和筛选栏尺寸
- [x] 新增组件能被搜索页或设置页复用
- [x] 不引入主题视觉改动，只改变布局和密度

## 阶段 4：搜索页与书源页

目标：把信息流页面从“单列大卡片”逐步改成按空间重排。

涉及页面：

- `lib/features/search/presentation/search_page.dart`
- `lib/features/search/presentation/widgets/search_book_card.dart`
- `lib/features/search/presentation/widgets/search_input_card.dart`
- `lib/features/source/presentation/source_page.dart`

任务：

- [x] 搜索输入区接入 `AdaptiveSearchBar`
- [x] 搜索结果卡片接入 `AdaptiveCard` / `AdaptiveListTile`
- [x] 小屏压缩卡片 padding 和按钮高度
- [x] 大手机显示更多副信息，但不增加过多装饰
- [x] `600dp+` 评估搜索条件和结果是否可分栏
- [x] 书源列表使用紧凑 list tile，统一状态 badge 尺寸
- [x] 复核批量操作栏和底部导航遮挡

验收：

- [x] 搜索结果在 360/390 宽度不横向溢出
- [x] 412 宽度首屏信息量明显优于改造前
- [x] 600+ 不只是单列居中放大
- [x] 书源状态、按钮和名称在字体放大下仍可读

## 阶段 5：设置类页面

目标：用统一的紧凑设置项替代页面里分散的大卡片、大留白。

涉及页面：

- `lib/features/mine/presentation/system_settings_page.dart`
- `lib/features/mine/presentation/appearance_page.dart`
- `lib/features/mine/presentation/cache_management_page.dart`
- `lib/features/mine/presentation/mine_page.dart`

任务：

- [x] 定义 `AdaptiveSettingTile`
- [x] 定义 `AdaptiveSettingSection`
- [x] 开关、步进器、下拉值、说明文字统一行高
- [x] 小屏说明文字最多 2 行，超出进入详情或弹层
- [x] 大屏设置页内容限制最大宽度，不铺满
- [x] 统一二级设置页面的顶部安全区和底部 inset
- [ ] 清理重复的 `EdgeInsets.all(24)`、`BorderRadius.circular(24)`

验收：

- [x] 设置页同屏可见项数增加，但不显拥挤
- [x] 文字缩放 `1.3x` 下不遮挡 trailing 控件
- [ ] 二级设置页视觉密度一致

## 阶段 6：书籍详情页

目标：让详情页在手机和大屏上采用不同结构，而不是单列放大。

涉及文件：

- `lib/features/book/presentation/book_detail_page.dart`
- `lib/features/book/presentation/book_detail_page_view.dart`
- `lib/features/book/presentation/widgets/book_detail_sections.dart`

任务：

- [x] 手机维持单列，但压缩非核心区域留白
- [x] 大手机优化封面、标题、按钮区比例
- [x] `600dp+` 评估封面信息区与简介/目录双栏
- [x] `840dp+` 采用稳定内容最大宽度，避免正文过宽
- [x] 操作按钮在窄屏自动换行或转为 icon/text 混合
- [x] 简介、目录、来源信息的展开状态不导致布局跳动过大

验收：

- [x] 360 宽度主操作完整可见
- [x] 390/412 宽度首屏能看到封面、标题、主操作和部分详情
- [x] 600+ 能利用宽度展示更多核心信息
- [x] 横屏不出现封面过高挤压内容

## 阶段 7：阅读设置弹层

目标：控制面板以“局部重排 + 密度缩放”解决挤压和空白。

涉及文件：

- `lib/features/reader/presentation/reader_page.dart`
- `lib/features/reader/presentation/reader_page_settings_sheet.dart`
- `lib/features/reader/presentation/reader_page_source_switch.dart`

任务：

- [x] 将弹层最大宽度、高度比例接入 adaptive metrics
- [x] 将快捷入口列数改为按面板宽度计算
- [ ] 控件组在窄屏下 2 列，在宽面板下 3-4 列
- [ ] 滑块、步进器、开关统一紧凑高度
- [x] 小屏横屏减少顶部区域高度
- [x] 字体放大时优先换行和滚动，不硬压文本
- [x] 复核漫画、文字阅读两套设置分支的一致性

验收：

- [x] 360 宽度弹层内容可操作，不出现底部遮挡
- [x] 横屏高度不足时仍能进入核心设置
- [x] 600+ 弹层不显得过窄或过空
- [ ] 同类控件高度一致

## 阶段 8：全局收敛与守卫

目标：防止后续继续写出新的固定机型适配和散落尺寸。

任务：

- [x] 在 `docs/product_experience_guide.md` 回填最终规则
- [x] 在 `docs/adaptive_layout_playbook.md` 回填新模型
- [x] 增加代码搜索清单：固定 `EdgeInsets.all(24)`、大圆角、固定高度
- [x] 增加 lint 或脚本提示页面中新增机型判断
- [x] 建立截图回归目录或测试说明
- [x] 将 P0/P1 页面截图纳入发布前检查

验收：

- [x] 新增页面默认使用 adaptive metrics
- [x] 不再出现按具体机型名适配的新增代码
- [ ] 主要页面在标准宽度矩阵下通过人工视觉验收

## 阶段 9：剩余页面接入清单

目标：把已验证的 `AppAdaptiveMetrics` 和 `Adaptive*` 组件铺到未接入页面，避免核心页和二级页体验割裂。

原则：

- 优先处理路由可达页面和用户高频二级页
- 不按机型补丁修 UI，只按 `windowClass`、`density`、容器宽度和文字缩放处理
- 不重做主题视觉，不改业务流程，只做布局、密度、限宽、滚动、安全区和网格列数
- 每个页面完成后补最小 smoke/widget 测试或纳入视觉回归清单

### 9.1 P1：高优先级二级页

这些页面从主流程容易进入，建议下一轮第一批处理。

- [x] 外观设置页
  文件：`lib/features/mine/presentation/appearance_page.dart`
  接入点：页面限宽、顶部/底部 inset、设置项密度、分区间距、二级入口卡片。
  验收：`360/390/600/840` 下入口不挤压，`1.3x` 文字缩放不遮挡 trailing 控件。

- [x] 我的页
  文件：`lib/features/mine/presentation/mine_page.dart`
  接入点：入口卡片、功能网格、会员/账户区域、底部安全区。
  验收：手机首屏信息量稳定，`600dp+` 不只是放大单列。

- [x] 缓存管理页
  文件：`lib/features/mine/presentation/cache_management_page.dart`
  接入点：统计卡片、操作按钮、列表项、清理确认弹层。
  验收：小屏按钮自动换行，统计卡片不横向溢出。

- [x] 本地书库页
  文件：`lib/features/bookshelf/presentation/local_library_page.dart`
  接入点：导入入口、文件列表、状态卡片、空状态。
  验收：`360dp` 可完成导入操作，`600dp+` 列表/信息区能利用宽度。

- [x] 阅读记录页
  文件：`lib/features/reader/presentation/reading_records_page.dart`
  接入点：记录列表项、分组/筛选、空状态、底部安全区。
  验收：长书名和章节名在 `1.3x` 下可读且不遮挡操作。

### 9.2 P1.5：书源与编辑链路

这些页面属于书源管理闭环，入口较深但和书源主流程强相关。

- [x] 脚本书源编辑页
  文件：`lib/features/source/presentation/script_source_editor_page.dart`
  接入点：编辑表单、代码区域、保存按钮、底部键盘 inset。
  验收：键盘弹出后保存/调试入口不被遮挡。

- [x] 粘贴导入页
  文件：`lib/features/source/presentation/script_source_paste_import_page.dart`
  接入点：输入框高度、导入按钮、提示卡片。
  验收：小屏可粘贴并提交，大屏输入区不过宽。

- [x] 书源登录页
  文件：`lib/features/source/presentation/source_login_page.dart`
  接入点：登录状态、操作按钮、表单项。
  验收：按钮和状态文案在 `360dp` 下完整可见。

- [x] 书源 Web 登录页
  文件：`lib/features/source/presentation/source_web_login_page.dart`
  接入点：WebView 容器、顶部操作栏、说明/错误提示。
  验收：横屏和小屏下操作栏不遮挡网页。

- [x] 脚本调试页
  文件：`lib/features/source/presentation/script_source_debug_page.dart`
  接入点：调试输入、日志面板、操作按钮。
  验收：日志区可滚动，操作区在小屏不溢出。

### 9.3 P2：资源与管理页

这些页面多为设置/管理型，适合用 `AdaptiveSettingSection`、`AdaptiveContentContainer`、`AdaptiveGridSliver` 批量收敛。

- [x] 字体管理页
  文件：`lib/features/mine/presentation/font_management_page.dart`
  接入点：字体列表、导入按钮、状态 chip、空状态。
  验收：字体名长文本不挤压按钮。

- [x] 阅读背景管理页
  文件：`lib/features/mine/presentation/reader_background_page.dart`
  接入点：背景网格、导入入口、预览卡片。
  验收：网格按宽度算列数。

- [x] 封面图库页与编辑页
  文件：`lib/features/mine/presentation/cover_gallery_page.dart`、`lib/features/mine/presentation/cover_gallery_editor_page.dart`
  接入点：图库网格、编辑表单、预览区域。
  验收：`600dp+` 预览和表单可分区。

- [x] 启动图图库页与编辑页
  文件：`lib/features/mine/presentation/launch_image_gallery_page.dart`、`lib/features/mine/presentation/launch_image_gallery_editor_page.dart`
  接入点：图片网格、裁剪/预览、操作按钮。
  验收：横屏可完成选择和保存。

- [x] 底部导航图标图库页与编辑页
  文件：`lib/features/mine/presentation/bottom_nav_icon_gallery_page.dart`、`lib/features/mine/presentation/bottom_nav_icon_gallery_editor_page.dart`
  接入点：图标网格、编辑表单、预览。
  验收：小屏图标网格不溢出。

- [ ] 高级主题列表页与编辑页
  文件：`lib/features/mine/presentation/advanced_theme_list_page.dart`、`lib/features/mine/presentation/advanced_theme_editor_page.dart`
  接入点：主题卡片、编辑表单、颜色/资源选择器。
  验收：编辑页 `1.3x` 下表单可滚动，按钮不遮挡。

- [ ] 标签/分类管理页
  文件：`lib/features/mine/presentation/mine_management_page.dart`
  接入点：管理列表、编辑表单、批量操作栏。
  验收：批量操作不遮挡列表。

- [ ] 书签页
  文件：`lib/features/mine/presentation/bookmarks_page.dart`
  接入点：书签列表、筛选、空状态、长摘录。
  验收：长摘录可读且列表密度稳定。

### 9.4 P2：同步与发现/首页链路

- [x] 首页
  文件：`lib/features/home/presentation/home_page.dart`
  接入点：首页卡片、横向区块、入口网格。
  验收：`600dp+` 信息区不空、不拉宽。

- [x] 发现页
  文件：`lib/features/discover/presentation/discover_page.dart`
  接入点：侧栏/内容区已有基础，继续收敛筛选、卡片、状态 chip。
  验收：`600dp+` 双栏稳定，`360dp` 不挤压筛选。

- [x] 同步设置页
  文件：`lib/features/sync/presentation/pages/sync_settings_page.dart`
  接入点：账号/配置卡片、开关项、操作按钮。
  验收：小屏按钮换行，大屏限宽。

- [x] 同步历史页
  文件：`lib/features/sync/presentation/pages/sync_history_page.dart`
  接入点：历史列表、状态 chip、错误详情。
  验收：长错误文案可折行或展开。

### 9.5 P3：低频信息页与账户页

- [x] 关于页
  文件：`lib/features/mine/presentation/about_page.dart`
  接入点：品牌区、信息项、链接按钮。
  验收：大屏限宽，小屏链接按钮不溢出。

- [x] 公告列表页与详情页
  文件：`lib/features/announcement/presentation/announcement_list_page.dart`、`lib/features/announcement/presentation/announcement_detail_page.dart`
  接入点：列表项、详情正文宽度、时间/状态标签。
  验收：详情正文 `840dp+` 不过宽。

- [x] 错误中心
  文件：`lib/features/error/presentation/error_center_page.dart`
  接入点：错误卡片、筛选/清理按钮、详情文本。
  验收：错误栈可滚动复制，按钮不遮挡。

- [x] 登录页与用户资料页
  文件：`lib/features/auth/presentation/auth_page.dart`、`lib/features/auth/presentation/user_profile_page.dart`
  接入点：表单、账号卡片、操作按钮。
  验收：键盘弹出后登录/保存按钮可达。

- [x] 会员中心
  文件：`lib/features/mine/presentation/membership_center_page.dart`
  接入点：权益卡片、套餐/状态区、操作按钮。
  验收：小屏套餐区不溢出，大屏不铺满。

- [x] 反馈列表/详情/提交页
  文件：`lib/features/mine/presentation/feedback_page.dart`
  接入点：列表、详情、提交表单、图片/附件区。
  验收：键盘和附件区不遮挡提交按钮。

### 9.6 新一轮建议执行顺序

- [x] 第一批：外观设置页、我的页、缓存管理页、本地书库页、阅读记录页
- [x] 第二批：脚本编辑/导入/登录/调试链路
- [x] 第三批：字体、背景、封面、启动图、图标图库
- [x] 第四批：同步、首页、发现页剩余卡片
- [x] 第五批：关于、公告、错误中心、登录/资料、会员、反馈

每一批验收：

- [x] `flutter analyze`
- [x] 相关 widget/smoke test
- [x] `dart run tool/check_adaptive_layout_guard.dart lib`
- [x] 更新 `docs/adaptive_visual_regression_checklist.md`
- [x] 更新本阶段勾选状态

## 6. 优先级清单

P0：

- [x] 自适应基础设施
- [x] 书架页
- [x] 搜索页
- [x] 阅读设置弹层

P1：

- [x] 书源页
- [x] 书籍详情页
- [x] 系统设置页
- [x] 外观设置页

P2：

- [x] 我的页
- [x] 缓存管理页
- [x] 阅读记录页
- [x] 本地书库页

P3：

- [x] 关于页
- [x] 公告页
- [x] 错误中心
- [x] 登录/用户资料页
- [x] 会员中心
- [x] 反馈列表/详情/提交页

## 7. 不做事项

本轮暂不做：

- [x] 不重做主题配色
- [x] 不调整品牌视觉
- [x] 不引入全局设计稿比例缩放
- [x] 不按机型名建立适配表
- [x] 不一次性重构所有页面
- [x] 不改变业务流程和数据结构

## 8. 每阶段交付格式

每个阶段完成后都需要回填：

- [x] 改动文件列表
- [x] 覆盖的宽度矩阵
- [x] 已解决问题
- [x] 未解决风险
- [x] 是否需要继续抽象通用组件
- [x] 是否需要更新本文档勾选状态

## 9. 第一阶段建议执行顺序

建议从最小闭环开始：

- [x] 创建 `app_adaptive.dart`
- [x] 增加 metrics 测试
- [x] 书架网格接入自动列数
- [x] 书架搜索/筛选接入密度 token
- [ ] 360/390/412/600/840 截图验收
- [x] 根据试点结果再抽通用组件
