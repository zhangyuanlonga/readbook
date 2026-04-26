# `reader_page.dart` 拆解执行文档

更新时间：2026-04-26  
用途：基于当前代码现状，给出 `lib/features/reader/presentation/reader_page.dart` 的完整拆解总账、剩余任务清单、优先级和落地顺序。  
结论先行：当前 `reader_page.dart` 仍有约 `16723` 行，虽然已经拆出多层 helper / resolver，但仍然明显不合理，必须继续拆。

---

## 1. 当前判断

### 1.1 现状结论

当前阅读器已经从“完全单文件堆叠”前进到“主页面 + 多个 presentation helper / resolver”的阶段，但还没有进入真正稳定的容器页结构。

`reader_page.dart` 依然同时承担：

- 生命周期与页面壳层
- 阅读正文视口总装
- 分页动画与 curl 状态机
- 章节加载与连续正文流
- 选择、标注、书签交互
- 目录跳转、漫画定位、导航请求
- 自动阅读、进度保存、阅读记录
- 顶部/底部 overlay
- 换源完整链路
- 设置面板、背景、主题、排版编辑

这意味着：

- 已经拆出去的 helper 还没有把主页面真正“削薄”
- 当前结构仍然会拖慢后续并行开发
- `reader_page.dart` 还是实质性的单点风险文件

### 1.2 为什么说当前状态仍然不合理

一个阅读页容器文件承担 `1.6w+` 行代码，说明至少还有两类问题没有解决：

1. 纯编排逻辑没有完全下沉
2. 大量 UI presenter / flow controller 还留在页面文件中

目标不应该是“继续在 `reader_page.dart` 里优化”，而应该是：

- `reader_page.dart` 只保留页面 state、顶层组装、生命周期和 callback 绑定
- 复杂编排迁入 controller / presenter / support 文件
- 复杂 UI 迁入独立 presenter / widget 文件

---

## 2. 已完成拆分

以下模块已经新增并落库，且已经开始接入主页面：

### 2.1 已拆出的模块

- `lib/features/reader/presentation/reader_shell.dart`
- `lib/features/reader/presentation/reader_chrome_widgets.dart`
- `lib/features/reader/presentation/reader_chrome_resolver.dart`
- `lib/features/reader/presentation/reader_presentation_resolver.dart`
- `lib/features/reader/presentation/reader_image_pipeline.dart`
- `lib/features/reader/presentation/reader_annotation_controller.dart`
- `lib/features/reader/presentation/reader_paged_viewport_support.dart`
- `lib/features/reader/presentation/reader_content_loading_controller.dart`
- `lib/features/reader/presentation/reader_navigation_presenter.dart`

### 2.2 已补测试

- `test/features/reader/presentation/reader_chrome_widgets_test.dart`
- `test/features/reader/presentation/reader_chrome_resolver_test.dart`
- `test/features/reader/presentation/reader_presentation_resolver_test.dart`
- `test/features/reader/presentation/reader_image_pipeline_test.dart`
- `test/features/reader/presentation/reader_annotation_controller_test.dart`
- `test/features/reader/presentation/reader_paged_viewport_support_test.dart`
- `test/features/reader/presentation/reader_content_loading_controller_test.dart`
- `test/features/reader/presentation/reader_navigation_presenter_test.dart`

### 2.3 当前已完成的主页面接入

- 页眉页脚规则改走 `reader_chrome_resolver.dart`
- shell/session/view model 组装改走 `reader_presentation_resolver.dart`
- 图片加载改走 `reader_image_pipeline.dart`
- 书签范围、tap 命中、selection overlap 部分改走 `reader_annotation_controller.dart`
- 导航请求、目录结果、漫画定位部分改走 `reader_navigation_presenter.dart`
- 分页 transition stack / page frame 改走 `reader_paged_viewport_support.dart`
- bootstrap ratio / restore ratio / `_setContent` / continuous flow 部分纯逻辑改走 `reader_content_loading_controller.dart`

结论：

- 当前不是“没拆”，而是“拆出来的层已经够多，但 `reader_page.dart` 里还残留太多总装与流程代码”

---

## 3. 当前剩余的大块职责

下面按模块而不是按零散函数列出剩余问题。

### 3.1 生命周期与页面入口层

仍在 `reader_page.dart` 中：

- `initState`
- `dispose`
- `didChangeAppLifecycleState`
- `didChangePlatformBrightness`
- `build`
- back navigation / PopScope 行为

判断：

- 这一层应该是最终留在 `reader_page.dart` 的少数职责之一
- 但仍可抽出一个 `ReaderPageLifecycleDelegate`

建议文件：

- `lib/features/reader/presentation/reader_page_lifecycle_delegate.dart`

---

### 3.2 阅读正文视口总装

仍在 `reader_page.dart` 中：

- `_buildBody`
- `_buildReaderList`
- `_buildStandardReaderList`
- `_buildContinuousTextReader`
- `_buildMangaReader`
- `_buildPagedReader`

判断：

- 这是当前主页面里最不该继续保留的总装块
- 虽然内部依赖的 model/helper 已经拆出，但总装本身仍在页面里

建议文件：

- `lib/features/reader/presentation/reader_viewport_builder.dart`

完成标准：

- `reader_page.dart` 不再直接决定 paged/scroll/manga 三种正文视口如何组装
- 页面只传入当前 state 和 callback

---

### 3.3 章节加载与连续正文流

虽然 `reader_content_loading_controller.dart` 已经落地，但以下流程仍残留在页面里：

- `_loadCurrentChapter`
- `_fetchChapterContentSnapshot`
- `_applyLoadedChapterSnapshot`
- `_loadContinuousTextChapter`
- `_loadAdjacentContinuousTextChapter`
- `_syncActiveContinuousTextChapterFromScroll`
- continuous chapter layout 测量与适配类型转换

判断：

- 当前 controller 只吸走了纯逻辑，还没有吸走 orchestration 层
- 这一块仍然是页面里最大的业务流之一

建议文件：

- `lib/features/reader/presentation/reader_content_loading_presenter.dart`

完成标准：

- `reader_page.dart` 不再直接写“拉取章节 -> 判定正文类型 -> 应用内容 -> 连续正文预取”的整条流程
- 页面只接收 presenter 输出的状态更新和副作用回调

---

### 3.4 选择、标注、书签完整链路

虽然 `reader_annotation_controller.dart` 已经接入部分逻辑，但以下内容还在页面里：

- `_handleSelectionNotifierChanged`
- `_syncSelectionState`
- `_clearSelectionState`
- `_showBookmarkToolbar`
- `_buildSelectionContextMenu`
- `_toggleSelectionBold`
- `_toggleSelectionHighlight`
- `_toggleSelectionUnderline`
- `_toggleSelectionWavy`
- `_saveSelectionBookmark`
- `_showBookmarkNoteEditor`

判断：

- 当前 controller 只接了“命中与计算”
- toolbar / action / save flow 仍是页面内大块业务

建议文件：

- `lib/features/reader/presentation/reader_annotation_presenter.dart`

完成标准：

- 页面不再直接拼 selection toolbar 状态
- 页面不再直接组装 bookmark 保存请求
- 页面只处理 UI 回调和 presenter 输出

---

### 3.5 分页动画与 curl 状态机

虽然 `reader_paged_viewport_support.dart` 已经接入 transition stack 和 page frame，但以下状态机与交互还在页面里：

- `_updateCurlPreviewProgress`
- `_finishCurlPreview`
- `_onCurlAutoTurnStatus`
- `_autoTurnCurlPage`
- `_ensurePagination`
- `_paginateCurrentChapter`
- `_buildPaginationParagraphModels`

判断：

- 当前 support 已经解决“展示装配”
- 但“交互驱动 + 分页任务调度 + curl 状态迁移”还没下沉

建议文件：

- `lib/features/reader/presentation/reader_paged_viewport_controller.dart`

完成标准：

- 页面不再自己维护 curl preview / auto turn 状态机
- 页面不再直接驱动分页任务调度

---

### 3.6 导航与目录跳转完整链路

虽然 `reader_navigation_presenter.dart` 已经接入，但以下部分仍在页面里：

- `_jumpTo`
- `_jumpToAdjacentReadableChapter`
- `_showChapterBoundaryHint`
- `_consumePendingBookmarkJump`
- `_jumpToBookmark`
- overlay 进度条拖动后的即时定位逻辑

判断：

- 当前 presenter 已经接住“目录结果解释”和“request 执行”
- 但具体 jump orchestration 还是页面自己掌控

建议文件：

- `lib/features/reader/presentation/reader_navigation_controller.dart`

完成标准：

- 页面不再直接维护多种 jump 分支
- 所有目录 / 书签 / 进度定位 / 临近章节跳转共用统一 controller

---

### 3.7 阅读运行时

仍在页面里：

- 自动阅读 session 开关
- `_reconcileAutoRead`
- `_runAutoReadLoop`
- `_tryAutoReadAdvanceChapter`
- `_saveProgress`
- `_scheduleProgressSave`
- 阅读记录 session 与 auto commit
- `_currentScrollRatio`

判断：

- 这是第二个大业务块
- 也最容易继续让 `reader_page.dart` 回胖

建议文件：

- `lib/features/reader/presentation/reader_runtime_controller.dart`

完成标准：

- 页面不再直接写 auto read loop
- 页面不再直接管理 reading record session 生命周期

---

### 3.8 顶部/底部 overlay 与 snackbar 展示

仍在页面里：

- `_buildTopOverlay`
- `_buildBottomOverlay`
- `_buildBottomProgressStrip`
- `_buildShellOverlayTransition`
- `_showReaderSnackBar`
- `_showMessage`

判断：

- 这是典型 presenter 层内容
- 应该和正文视口、章节加载、导航逻辑脱开

建议文件：

- `lib/features/reader/presentation/reader_overlay_presenter.dart`

完成标准：

- 页面不再直接拼顶部/底部 overlay 细节
- snackbar/dedupe 逻辑下沉

---

### 3.9 换源完整链路

仍在页面里：

- `_showSwitchSourceSheet`
- progressive candidate loading
- score / hit count / coverage confirm
- `_applySwitchSourceCandidate`
- `_syncBookshelfAfterSourceSwitch`
- `_syncReadingStateAfterSourceSwitch`
- `_restoreSourceSnapshot`

判断：

- 这是当前仍然最重的一条业务流之一
- 耦合了搜索、评分、持久化、章节恢复、UI 交互

建议文件：

- `lib/features/reader/presentation/reader_source_switch_controller.dart`

完成标准：

- 页面不再自己驱动换源整条流程
- 页面只接“打开 sheet / 选中 candidate / 应用结果”

---

### 3.10 设置面板、背景、主题、排版配置

仍在页面里：

- `_showSettingsSheet`
- grouped preview / setting line / chips / slider / theme dots / background gallery
- 字号、字距、行距、段距、排版与背景色 UI
- 主题切换、图片背景、资源预览、背景图库

判断：

- 这是目前最大的纯 UI presenter 块
- 即使业务逻辑继续拆完，这一块不拆，文件仍然会很大

建议文件：

- `lib/features/reader/presentation/reader_settings_presenter.dart`
- 视情况再拆：
  - `reader_background_presenter.dart`
  - `reader_typography_presenter.dart`

完成标准：

- 页面不再直接承载巨型 bottom sheet 组装
- 设置 UI 和设置应用逻辑可以单测和独立迭代

---

## 4. 拆分优先级

### P0：必须立即继续拆

- [ ] 阅读正文视口总装
- [ ] 章节加载与连续正文流 orchestration
- [ ] 分页动画与 curl 状态机
- [ ] 阅读运行时

理由：

- 这四块决定 `reader_page.dart` 是否还能继续下降到合理体量

### P1：紧接着拆

- [ ] 选择、标注、书签完整链路
- [ ] 导航与目录跳转完整链路
- [ ] overlay presenter

理由：

- 这三块目前已经有 helper 基础，继续接完整成本相对低

### P2：最后拆

- [ ] 换源完整链路
- [ ] 设置面板与背景/排版 presenter
- [ ] 生命周期 delegate

理由：

- 体量大，但对阅读主路径结构风险略低于 P0

---

## 5. 建议执行顺序

建议按 4 轮连续执行，不要打散：

### 第一轮

- [x] `reader_viewport_builder.dart`
- [x] `reader_paged_viewport_controller.dart`

目标：

- 页面不再直接组装 paged/scroll/manga 视口
- 页面不再直接维护 curl / paged animation 主状态机

### 第二轮

- [x] `reader_content_loading_presenter.dart`
- [x] `reader_runtime_controller.dart`

目标：

- 页面不再写章节加载与 continuous flow 主流程
- 页面不再写自动阅读与阅读记录主流程

### 第三轮

- [ ] `reader_annotation_presenter.dart`
- [ ] `reader_navigation_controller.dart`
- [ ] `reader_overlay_presenter.dart`

目标：

- 页面不再写 selection/toolbar/bookmark flow
- 页面不再写目录/书签/进度定位的 jump orchestration
- 页面不再直接拼 overlay/snackbar

### 第四轮

- [ ] `reader_source_switch_controller.dart`
- [ ] `reader_settings_presenter.dart`
- [ ] `reader_page_lifecycle_delegate.dart`

目标：

- 页面只剩最终容器壳层职责

---

## 6. 每轮完成标准

### 结构标准

- `reader_page.dart` 不再新增新的复杂分支
- 被拆出的文件必须有独立测试或至少有定向 analyze 覆盖
- 不允许“helper 已新增，但页面没接入”

### 体量标准

建议分阶段把 `reader_page.dart` 压缩到以下量级：

- 第一轮后：降到 `12000` 行以内
- 第二轮后：降到 `9000` 行以内
- 第三轮后：降到 `6500` 行以内
- 第四轮后：降到 `4500` 行以内

最终目标：

- `reader_page.dart` 成为容器页，而不是功能全集

---

## 7. 交付定义

当本拆解计划完成时，`reader_page.dart` 应只保留：

- 页面 state 持有
- lifecycle hook
- 顶层 route 参数解析
- shell / scaffold 组装
- 极少量 callback 绑定

以下内容都不应再留在页面文件中：

- 超长 bottom sheet UI
- 换源完整流程
- auto read 主循环
- 分页任务调度
- selection/bookmark toolbar 编排
- 图片类型分发
- 目录/书签/进度定位的具体执行策略

---

## 8. 当前结论

结论很明确：

- 当前 `reader_page.dart` 仍然过大，不合理
- 当前已经不是“要不要拆”的问题，而是“按什么顺序继续拆”
- 现在最重要的不是再新增 helper，而是把已拆出的 helper 与剩余 orchestration 彻底接完

因此，后续执行必须遵循：

1. 不再新增临时逻辑回填 `reader_page.dart`
2. 所有新增阅读功能必须优先挂到已拆出的 presenter/controller/support 上
3. `reader_page.dart` 只允许继续变薄，不允许再次变胖
