# Flutter 页面细腻感与动效改造计划

更新时间：2026-05-09  
用途：把当前 Flutter 项目的页面细节、反馈、动效和高级感改造拆成可执行、可验收、可打勾的阶段任务。  
范围：只处理 motion、页面过渡、状态切换、微交互、加载体验、弹层体验和视觉层次；不处理主题配色、品牌视觉和业务流程。

## 1. 改造目标

这轮改造不是“加很多动画”，而是让页面在操作、加载、切换和反馈时更连续、更稳定、更有质感。

核心目标：

- 页面进入不突兀，有轻微层次和连续感
- 加载、空状态、错误状态、成功状态之间切换自然
- 按钮、卡片、列表项有清晰但克制的触摸反馈
- 表单聚焦、错误提示、提交中状态不跳动、不遮挡
- 底部弹窗、Dialog、Toast/Snackbar 的出现和消失统一
- 动效不会影响可读性、不会拖慢低端设备、不会造成测试不稳定
- 尊重系统“减少动态效果”倾向，必要时降级为无位移淡入

## 2. 基本原则

- [ ] 不做全局浮夸动画，不为了动而动
- [ ] 先建立统一 Motion Token，再逐页接入
- [ ] 页面级动画只做首屏和关键结构，不对无限列表滚动项滥用动画
- [ ] 状态切换优先用 `AnimatedSwitcher`
- [ ] 尺寸变化优先用 `AnimatedSize` 或稳定容器，避免布局突然跳动
- [ ] 触摸反馈优先使用 Material 自带 `InkWell` / `InkResponse` / `ButtonStyle`
- [ ] 页面转场统一从 GoRouter / PageRoute 层处理，不在业务页面里各写一套
- [ ] 长列表、书架、阅读器等高性能场景只做低成本反馈
- [ ] 所有动效必须有测试或人工检查项

## 3. 推荐技术组合

继续使用 Flutter 原生能力，先不引入重量动画库。

- [ ] `AnimatedSwitcher`：加载、空状态、错误状态、内容状态切换
- [ ] `AnimatedSize`：筛选栏、展开区、提示区高度变化
- [ ] `TweenAnimationBuilder`：轻量数值变化、统计卡片变化
- [ ] `ImplicitlyAnimatedWidget` / `AnimatedContainer`：卡片背景、边框、阴影、选择态
- [ ] `FadeTransition` + `SlideTransition`：页面进入和分区进入
- [ ] `Hero`：书籍封面、图片预览等明确对象转场
- [ ] `PageRouteBuilder` / GoRouter `CustomTransitionPage`：页面级转场统一入口
- [ ] `RepaintBoundary`：复杂动画区域隔离重绘
- [ ] `TickerMode`：不可见 tab 或后台区域暂停动画

## 4. 统一 Motion 模型

### 4.1 AppMotion Tokens

任务：

- [x] 新增 `lib/app/motion/app_motion.dart`
- [x] 定义统一时长：`instant`、`fast`、`medium`、`slow`、`page`
- [x] 定义统一曲线：`standard`、`emphasized`、`decelerate`、`accelerate`
- [x] 定义位移距离：`pageEnterOffset`、`sectionEnterOffset`、`microOffset`
- [x] 定义开关：根据系统设置或测试环境关闭/降低动效
- [x] 为 token 写单元测试，确保默认值稳定

建议初始值：

- `fast`: `120ms`
- `medium`: `180ms`
- `slow`: `260ms`
- `page`: `300ms`
- `standard`: `Curves.easeOutCubic`
- `emphasized`: `Curves.easeInOutCubic`

### 4.2 Motion 组件封装

任务：

- [x] 新增 `AppAnimatedSwitcher`
- [x] 新增 `AppFadeSlideTransition`
- [x] 新增 `AppStaggeredEntrance`
- [x] 新增 `AppPressable`
- [x] 新增 `AppLoadingStateSwitcher`
- [x] 新增 `AppAnimatedStatusCard`
- [x] 新增 `AppMotionScope` 或 helper，用于测试和减少动态效果

验收：

- [x] 组件支持 `enabled: false`
- [x] 组件不会改变子组件语义结构
- [x] widget test 覆盖开启/关闭动效
- [x] 动效中途更新状态不会抛异常

## 5. 阶段计划

## 阶段 0：体验审查与页面分级

目标：先确定哪些页面值得优先做细腻感，哪些页面只需要基础统一。

任务：

- [x] 建立页面动效分级：P0 / P1 / P2 / P3
- [x] 标记高频路径：首页、书架、搜索、详情、阅读器、我的页
- [x] 标记表单路径：登录、反馈、书源编辑、同步设置、主题编辑
- [x] 标记管理路径：字体、背景、封面、启动图、图标图库、缓存
- [x] 标记低频路径：关于、公告、错误中心、会员中心
- [x] 记录当前问题：突兀切换、加载单薄、按钮跳动、弹层割裂、状态无反馈
- [x] 输出人工验收矩阵：小屏、横屏、平板、文字 `1.3x`

验收：

- [x] 每个页面都归到一个动效批次
- [x] 每个批次都有明确接入点和验收标准

阶段 0 输出：

- [x] P0：我的页、书籍详情页、书架页、搜索页、阅读器页面、阅读设置弹层
- [x] P1：首页、发现页、登录页、会员中心、反馈提交页、书源编辑/调试页、同步设置页
- [x] P2：外观、字体、背景、图库、缓存、阅读记录、本地书库、高级主题编辑
- [x] P3：关于、公告、错误中心、用户资料、反馈列表/详情、同步历史
- [x] 当前核心缺口：状态切换突兀、加载反馈偏单薄、弹层/按钮 loading 不统一、拖动/横滑/返回手势需专项治理
- [x] 人工验收矩阵：`360x640`、`390x844`、`412x915`、`600x960`、`840x1180`、`780x360`，文字缩放 `1.0x` / `1.3x`

## 阶段 1：Motion 基础设施

目标：先让全项目有统一动效语言。

任务：

- [x] 新增 `AppMotion`
- [x] 新增通用淡入/位移动效组件
- [x] 新增状态切换组件
- [x] 新增按压反馈组件
- [x] 新增测试环境关闭动效能力
- [x] 给基础组件写 widget test
- [x] 写 `docs/flutter_motion_refinement_plan.md` 勾选规则

验收：

- [x] `flutter analyze` 通过
- [x] motion 基础组件测试通过
- [x] 不改业务页面即可编译通过

## 阶段 2：试点页面

目标：先做 3 个代表页面，确定“高级感模板”。

- [x] 我的页
  文件：`lib/features/mine/presentation/mine_page.dart`、`mine_page_view.dart`
  接入点：用户卡片、入口分组、状态卡片、页面进入。
  验收：首屏分区轻微进入，点击入口反馈稳定。

- [x] 书籍详情页
  文件：`lib/features/book/presentation/book_detail_page.dart`、`book_detail_page_view.dart`
  接入点：封面/标题区、主操作按钮、简介展开、章节/书源状态。
  验收：详情加载和内容出现自然，按钮 loading 不跳动。

- [x] 会员中心
  文件：`lib/features/mine/presentation/membership_center_page.dart`
  接入点：权益卡片、底部操作栏、支付/激活/设备管理弹层。
  验收：弹层和按钮状态统一，权益列表不出现过度动画。

验收：

- [x] 三个页面在 `360`、`390`、`600`、`840` 下无异常
- [x] 文字 `1.3x` 下不遮挡关键按钮
- [x] 动效关闭后页面仍可正常使用

阶段 2 回填：

- [x] 我的页：将已有分区进入动画收敛到 `AppFadeSlideTransition`
- [x] 书籍详情页：加载完成后的主要内容分区接入轻量进入动效
- [x] 会员中心：权益/状态/功能区分段进入，保留列表静态滚动性能
- [x] 本阶段未改业务流程、未给长列表添加持续动画

## 阶段 3：高频内容页

目标：把最常用路径做出连续感。

- [x] 书架页
  文件：`lib/features/bookshelf/presentation/bookshelf_page_sections.dart`、`bookshelf_grid_sliver.dart`
  接入点：筛选切换、网格/列表切换、空状态、导入入口。
  验收：布局切换不突兀，滚动性能稳定。

- [x] 搜索页
  文件：`lib/features/search/presentation/search_page.dart`
  接入点：搜索框聚焦、筛选栏展开、结果状态切换、结果卡片。
  验收：输入、加载、结果、空状态连续。

- [x] 首页
  文件：`lib/features/home/presentation/home_page.dart`
  接入点：打卡卡片、继续阅读、目标卡片、排行区块。
  验收：首屏区块进入有层次，但不影响快速浏览。

- [x] 发现页
  文件：`lib/features/discover/presentation/discover_page.dart`
  接入点：侧栏选择、分类切换、列表加载、空状态。
  验收：侧栏和内容区切换稳定。

阶段 3 回填：

- [x] 书架页：加载/空/错误状态接入 `AppAnimatedSwitcher`，网格/列表切换复用 `AppFadeSlideTransition` 并保留数量阈值
- [x] 搜索页：输入卡、进度卡、空状态、结果摘要接入轻量状态/进入动效
- [x] 首页：首屏核心区块接入分段进入，阅读记录流更新接入状态切换
- [x] 发现页：加载、错误、提示卡片接入统一状态切换
- [x] 长列表 item 未做持续动画，避免影响滚动性能

## 阶段 4：表单与编辑页

目标：提升输入、保存、错误反馈的质感。

- [x] 登录页
  文件：`lib/features/auth/presentation/auth_page.dart`
  接入点：登录/注册切换、输入框聚焦、提交中、错误提示。
  验收：键盘弹出后按钮可达，提交状态不跳动。

- [x] 反馈提交页
  文件：`lib/features/mine/presentation/feedback_page.dart`
  接入点：类型切换、相似反馈弹窗、提交中、成功返回。
  验收：表单状态清晰，错误提示自然出现。

- [x] 书源编辑/脚本调试页
  文件：`lib/features/source/presentation/script_source_editor_page.dart`、`script_source_debug_page.dart`
  接入点：工具栏、保存状态、调试结果、日志展开。
  验收：长内容滚动不掉帧，状态切换不遮挡编辑区。

- [x] 同步设置页
  文件：`lib/features/sync/presentation/pages/sync_settings_page.dart`
  接入点：分段控件、连接测试、保存状态、错误提示。
  验收：表单反馈统一。

- [x] 高级主题编辑页
  文件：`lib/features/mine/presentation/advanced_theme_editor_page.dart`
  接入点：颜色/资源选择、预览区、保存/导入状态。
  验收：预览更新不过度闪烁。

## 阶段 5：管理与资源页

目标：让大量卡片、网格、资源状态更精致。

- [x] 外观设置页
  文件：`lib/features/mine/presentation/appearance_page.dart`、`appearance_page_view.dart`
  接入点：设置分组、开关项、二级入口。
  验收：切换反馈清晰。

- [x] 字体管理页
  文件：`lib/features/mine/presentation/font_management_page.dart`
  接入点：导入状态、字体卡片、删除确认。
  验收：长字体名和 loading 状态稳定。

- [x] 阅读背景管理页
  文件：`lib/features/mine/presentation/reader_background_page.dart`
  接入点：背景网格、导入入口、预览弹层。
  验收：网格滚动不卡顿。

- [x] 封面图库/编辑页
  文件：`lib/features/mine/presentation/cover_gallery_page.dart`、`cover_gallery_editor_page.dart`
  接入点：图片选择、批量状态、编辑保存。
  验收：选择态清晰，图片加载不闪烁。

- [x] 启动图图库/编辑页
  文件：`lib/features/mine/presentation/launch_image_gallery_page.dart`、`launch_image_gallery_editor_page.dart`
  接入点：图片网格、预览、保存状态。
  验收：横屏编辑可用。

- [x] 底部导航图标图库/编辑页
  文件：`lib/features/mine/presentation/bottom_nav_icon_gallery_page.dart`、`bottom_nav_icon_gallery_editor_page.dart`
  接入点：图标配置、选择态、保存反馈。
  验收：批量配置不混乱。

- [x] 缓存管理页
  文件：`lib/features/mine/presentation/cache_management_page.dart`
  接入点：统计卡片、清理按钮、任务进度、结果反馈。
  验收：清理过程有明确状态。

阶段 4 回填：

- [x] 登录页：登录/注册入口、表单区和提交 loading 接入统一进入/切换动效
- [x] 反馈提交页：说明卡、类型/输入区和提交按钮状态接入轻量 Motion
- [x] 书源编辑/脚本调试页：问题提示、编辑器加载态、调试输入和结果摘要接入状态切换
- [x] 同步设置页：主配置面板、资料列表和加载占位接入 `AppAnimatedSwitcher`
- [x] 高级主题编辑页：编辑内容区接入进入动效，加载/缺失状态保留明确反馈

阶段 5 回填：

- [x] 外观设置页：设置分组按顺序进入，覆盖外观、底栏、封面、背景分区
- [x] 字体管理页：头部、字体库状态、错误/加载反馈接入 Motion，字体长列表保持静态滚动
- [x] 阅读背景管理页：加载/内容/空态切换、搜索入口接入 Motion，背景网格保持 builder 渲染
- [x] 封面、启动图、底栏图集：图库列表搜索/空态/说明区接入 Motion，编辑页内容状态统一切换
- [x] 缓存管理页：初始加载进度、列表进入和清理按钮状态接入 Motion
- [x] 资源网格 item 未做持续动画，避免图片列表滚动掉帧

## 阶段 6：阅读器与阅读相关页面

目标：阅读器动效必须克制，优先保证性能和阅读稳定。

- [ ] 阅读器页面
  文件：`lib/features/reader/presentation/reader_page.dart`
  接入点：工具栏显示/隐藏、设置面板、加载/错误状态。
  验收：翻页和滚动不受额外动画影响。

- [x] 阅读设置弹层
  文件：`lib/features/reader/presentation/reader_page_settings_sheet.dart`
  接入点：Tab 切换、设置项变化、底部安全区。
  验收：面板切换顺滑，控件不跳动。

- [x] 阅读记录页
  文件：`lib/features/reader/presentation/reading_records_page.dart`
  接入点：周期筛选、统计卡片、列表项。
  验收：统计变化自然，长文本可读。

- [x] 本地书库页
  文件：`lib/features/bookshelf/presentation/local_library_page.dart`
  接入点：导入入口、状态卡片、导入结果。
  验收：导入反馈明确。

## 阶段 7：低频信息页与账户页

目标：低频页面统一基础细节，不做复杂动效。

- [x] 关于页
  文件：`lib/features/mine/presentation/about_page.dart`
  接入点：分栏进入、按钮反馈、标签出现。
  验收：大屏和小屏都克制稳定。

- [x] 公告列表/详情页
  文件：`lib/features/announcement/presentation/announcement_list_page.dart`、`announcement_detail_page.dart`
  接入点：列表状态、最新公告卡片、详情正文。
  验收：加载和刷新状态自然。

- [x] 错误中心
  文件：`lib/features/error/presentation/error_center_page.dart`
  接入点：日志筛选、复制/导出/清空反馈。
  验收：长日志不受动画影响。

- [x] 用户资料页
  文件：`lib/features/auth/presentation/user_profile_page.dart`
  接入点：资料同步、刷新、退出登录确认。
  验收：按钮状态稳定。

- [x] 反馈列表/详情页
  文件：`lib/features/mine/presentation/feedback_page.dart`
  接入点：搜索筛选、列表状态、详情卡片。
  验收：状态切换统一。

- [x] 同步历史页
  文件：`lib/features/sync/presentation/pages/sync_history_page.dart`
  接入点：任务列表、冲突列表、详情弹层。
  验收：低频页面切换稳定，详情弹层不过度抢眼。

## 阶段 8：全局弹层、Dialog 与通知反馈

目标：让所有临时层体验一致。

任务：

- [x] 统一底部弹窗进入动效、最大宽度、圆角、拖拽柄
- [x] 统一 Dialog 内容切换和按钮 loading
- [ ] 统一 Snackbar 行为：替换当前提示、持续时间、错误/成功文案
- [x] 统一 Import/Export 任务浮层动效
- [ ] 统一确认删除、清理、释放席位等危险操作反馈

涉及文件：

- `lib/app/widgets/adaptive_bottom_sheet.dart`
- `lib/app/widgets/app_task_bottom_sheet.dart`
- `lib/app/widgets/import_export_task_sheet.dart`
- `lib/app/widgets/import_export_task_overlay.dart`
- `lib/features/source/presentation/source_page_dialogs.dart`

验收：

- [x] 弹层在手机/平板/桌面宽度一致
- [x] 键盘弹出不遮挡底部主按钮
- [ ] 重复点击不会叠多个 loading

## 阶段 9：性能与验收收尾

目标：确保细腻感不会变成卡顿来源。

任务：

- [x] 增加 motion smoke test
- [x] 增加关键页面 golden/screenshot 人工清单
- [x] 检查 `TickerMode` 和不可见页面动画暂停
- [ ] 对书架、搜索、阅读器跑滚动性能检查
- [ ] 检查 `RepaintBoundary` 是否需要补在高频动画区域
- [x] 更新 `docs/adaptive_visual_regression_checklist.md`，加入 motion 检查项
- [x] 更新本计划勾选状态

验收：

- [x] `flutter analyze`
- [x] 相关 widget/smoke test
- [ ] 低端宽度和横屏无明显掉帧
- [x] 减少动态效果模式可降级
- [x] 页面不出现动画后布局错位

## 6. 建议执行批次

- [x] 第一批：阶段 0 + 阶段 1，建立 Motion 基建和页面分级
- [x] 第二批：阶段 2，完成我的页、书籍详情页、会员中心试点
- [x] 第三批：阶段 3，高频内容页
- [x] 第四批：阶段 4，表单与编辑页
- [x] 第五批：阶段 5，管理与资源页
- [x] 第六批：阶段 6，阅读器与阅读相关页面
- [x] 第七批：阶段 7 + 阶段 8，低频页和全局弹层
- [ ] 第八批：阶段 9，性能、测试和文档收尾

## 7. 页面优先级清单

P0：

- [x] 我的页
- [x] 书籍详情页
- [x] 书架页
- [x] 搜索页
- [x] 阅读器页面
- [x] 阅读设置弹层

P1：

- [x] 首页
- [x] 发现页
- [x] 登录页
- [x] 会员中心
- [x] 反馈提交页
- [x] 书源编辑/调试页
- [x] 同步设置页

P2：

- [x] 外观设置页
- [x] 字体管理页
- [x] 阅读背景管理页
- [x] 封面图库/编辑页
- [x] 启动图图库/编辑页
- [x] 底部导航图标图库/编辑页
- [x] 缓存管理页
- [x] 阅读记录页
- [x] 本地书库页
- [x] 高级主题编辑页

P3：

- [x] 关于页
- [x] 公告列表/详情页
- [x] 错误中心
- [x] 用户资料页
- [x] 反馈列表/详情页
- [x] 同步历史页

## 8. 不做事项

- [x] 不重做主题配色
- [x] 不重做品牌视觉
- [x] 不引入复杂 Lottie/Rive 作为基础方案
- [x] 不给长列表每个滚动项持续动画
- [x] 不改变业务流程
- [x] 不为了动画增加网络等待
- [x] 不让动画影响阅读器翻页和滚动性能

## 9. 每阶段交付格式

每个阶段完成后都需要回填：

- [x] 改动文件列表
- [x] 覆盖页面
- [x] 已接入的 motion 组件
- [x] 已关闭或降级的动效场景
- [x] 性能风险
- [x] 测试命令
- [x] 是否更新本文档勾选状态

阶段 0/1 回填：

- 改动文件：`lib/app/motion/app_motion.dart`、`lib/app/motion/app_motion_widgets.dart`、`test/app/motion/app_motion_test.dart`、`test/app/motion/app_motion_widgets_test.dart`
- 覆盖页面：本阶段只做页面分级和基建，不接入业务页面
- 已接入组件：`AppAnimatedSwitcher`、`AppFadeSlideTransition`、`AppStaggeredEntrance`、`AppPressable`、`AppLoadingStateSwitcher`、`AppAnimatedStatusCard`、`AppMotionScope`
- 降级场景：`MediaQuery.disableAnimations == true` 或 `AppMotionScope(enabled: false)` 时，位移/淡入/缩放降级为即时显示
- 性能风险：后续长列表、阅读器、漫画滚动不得滥用 stagger 或持续动画
- 测试命令：`flutter test test/app/motion/app_motion_test.dart test/app/motion/app_motion_widgets_test.dart`

## 10. 最终漏项清单：滑动、拖动与手势细节

这部分作为执行前的最终补充检查。前面的阶段更多按页面拆分，本节按交互形态拆分，避免遗漏“页面看起来完成了，但手感还粗糙”的部分。

### 10.1 列表滑动体验

任务：

- [ ] 统一列表滚动物理：普通列表、长列表、弹层列表、横向列表分别明确 `ScrollPhysics`
- [ ] 检查下拉刷新触发距离、刷新指示器位置和顶部透明 AppBar 叠加效果
- [ ] 统一列表底部安全区和加载更多区域，不让最后一项被底栏/手势条遮挡
- [ ] 给加载更多状态提供稳定高度，避免尾部 loading 出现时列表跳动
- [ ] 检查空状态、错误状态、加载状态切换时滚动位置是否异常
- [ ] 长列表避免首屏所有 item 都做 stagger 动画，只允许首屏轻量进入
- [ ] 横向列表提供边缘渐隐或足够 padding，让用户知道可横滑

涉及页面：

- 书架页、搜索页、首页继续阅读、发现页、公告列表、反馈列表、阅读记录、本地书库、字体/图库/背景管理页。

验收：

- [ ] 快速滑动不卡顿
- [ ] 下拉刷新不会和透明 AppBar、状态栏重叠
- [ ] 加载更多不造成布局跳动
- [ ] 横向列表可感知、可停靠、无误触

### 10.2 拖动、排序与重排

任务：

- [ ] 梳理所有需要拖动排序的入口：书架分组、标签/分类、底部导航图标、图片图库、主题资源排序
- [ ] 对排序态提供明确视觉：拖拽手柄、浮起阴影、占位空隙、释放反馈
- [ ] 拖动过程中禁止复杂动画叠加，优先保证跟手
- [ ] 拖动结束后使用短动效归位，不让 item 突然跳回
- [ ] 长按进入排序时提供轻微触觉反馈
- [ ] 拖动跨容器或跨分组时明确边界，不允许误删或误移
- [ ] 桌面端补鼠标悬停、拖拽光标和右键/辅助入口

涉及页面：

- 书架分组、Mine 管理页、封面图库、启动图图库、底栏图标图库、高级主题资源编辑页。

验收：

- [ ] 拖动跟手，无明显延迟
- [ ] 排序前后数据一致
- [ ] 横屏和 `600dp+` 双栏下拖动边界清晰
- [ ] 没有拖动时误触排序

### 10.3 横滑操作与可撤销反馈

任务：

- [ ] 梳理可横滑操作：书架书籍、阅读记录、缓存项、书签、反馈项、公告项
- [ ] 删除/移除类操作优先提供确认或撤销，不做直接消失
- [ ] 横滑按钮宽度、颜色、图标和文案统一
- [ ] 横滑后列表项回弹和删除动画统一
- [ ] 防止横滑与页面返回手势、横向列表滚动冲突
- [ ] 桌面端为横滑操作提供显式更多菜单，避免鼠标不可发现

验收：

- [ ] 横滑阈值自然，不容易误触
- [ ] 删除/移除有撤销或确认
- [ ] 手势冲突可控
- [ ] 桌面端也能发现同等操作

### 10.4 卡片按压、长按与上下文菜单

任务：

- [ ] 统一卡片按压反馈：水波纹、背景层、轻微缩放三者只选择一种主方案
- [ ] 长按菜单统一样式和出现位置
- [ ] 长按与拖动排序有明确区分：普通长按菜单、排序长按、图片预览长按不能混淆
- [ ] 对危险操作增加二次确认或撤销
- [ ] 桌面端补 hover、focus、secondary click

涉及页面：

- 书架、搜索结果、书籍详情操作区、我的入口、资源图库、阅读记录、反馈/公告列表。

验收：

- [ ] 点击反馈即时但不夸张
- [ ] 长按菜单不遮挡被操作对象
- [ ] 键盘/鼠标可达

### 10.5 图片预览、缩放与拖拽导入

任务：

- [ ] 图片预览统一支持双指缩放、双击复位、拖动查看
- [ ] 图片选择态、上传/导入中、失败重试状态统一
- [ ] 桌面端支持拖拽文件导入的页面需要明确 drop zone
- [ ] 图片加载过程避免白屏闪烁，使用占位和淡入
- [ ] 大图预览使用 `Hero` 时只在明确对象之间启用
- [ ] 图片网格滚动时避免每张图片持续动画

涉及页面：

- 封面图库、启动图图库、背景图库、底栏图标图库、高级主题资源、书籍封面、阅读器漫画/插图。

验收：

- [ ] 大图预览可缩放可退出
- [ ] 导入失败可重试
- [ ] 图片加载无明显闪烁
- [ ] 拖拽导入有清晰反馈

### 10.6 控件连续调节

任务：

- [ ] Slider、Stepper、SegmentedButton、Switch、Checkbox 的反馈统一
- [ ] 阅读器字体、行距、边距、亮度等连续调节要即时预览，但避免每次变化都触发重计算卡顿
- [ ] 对昂贵操作增加 debounce 或松手后提交
- [ ] 数值变化使用轻量动画或数字过渡，不让文本宽度跳动
- [ ] 开关项保存失败时能回滚并提示

涉及页面：

- 阅读设置弹层、系统设置、同步设置、外观设置、高级主题编辑、书架网格设置。

验收：

- [ ] 拖动控件顺滑
- [ ] 数值和预览同步
- [ ] 保存失败有回滚

### 10.7 导航与返回手势

任务：

- [ ] 统一页面转场：主路径、详情页、编辑页、弹层页分别有明确转场策略
- [ ] Android 返回键、iOS 边缘返回、桌面 ESC 行为一致
- [ ] 表单未保存时返回需要确认，确认弹窗动效统一
- [ ] 嵌套导航和透明 AppBar 页面检查返回手势冲突
- [ ] 阅读器全屏场景下返回优先关闭工具栏/弹层，再退出页面

验收：

- [ ] 返回行为可预测
- [ ] 未保存内容不丢失
- [ ] 边缘返回和横滑列表不冲突

### 10.8 可访问性与减少动态效果

任务：

- [ ] 检查 `MediaQuery.disableAnimations` 或平台减少动态效果倾向
- [ ] 动效关闭时保留状态变化，不依赖动画表达唯一信息
- [ ] 所有自定义可点击/可拖动组件补语义标签
- [ ] 拖动排序提供非拖动替代入口，例如上移/下移按钮或菜单
- [ ] 焦点态、键盘操作和屏幕阅读器路径可用

验收：

- [ ] 减少动态效果时页面不突兀、不丢信息
- [ ] 只用键盘也能完成核心操作
- [ ] 拖动类操作有替代方案

### 10.9 性能红线

任务：

- [ ] 列表滚动中不触发大范围 `setState`
- [ ] 列表 item 不使用昂贵阴影、模糊和持续动画
- [ ] 复杂卡片动效包 `RepaintBoundary`
- [ ] 不可见 tab、弹层背后的动画暂停
- [ ] 页面进入动画不阻塞首屏数据展示
- [ ] 阅读器翻页、漫画滚动、搜索结果滚动优先性能，不做复杂进入动画

验收：

- [ ] 关键列表快速滑动无明显掉帧
- [ ] 阅读器翻页/滚动不被 motion 基建影响
- [ ] 长列表内存和 rebuild 次数可控

## 11. 最终推荐执行补充顺序

如果后续开始动效改造，建议在原有阶段前插入这组专项：

- [ ] Motion-S0：滑动/拖动/横滑/长按交互盘点
- [ ] Motion-S1：统一 Scroll、Refresh、LoadMore、Swipe、Drag 的交互规范
- [ ] Motion-S2：先做 2 个复杂交互试点：书架列表/网格、图库拖动/选择
- [ ] Motion-S3：再回到页面批次执行阶段 2 到阶段 8
- [ ] Motion-S4：阅读器专项性能验收
