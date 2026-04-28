# Reader Page 拆解执行清单

更新时间：2026-04-26  
用途：作为 `lib/features/reader/presentation/reader_page.dart` 继续拆解的唯一执行文档，按阶段推进、按任务打勾、按验收标准关闭，避免后续再回到“边改边猜”的状态。
总计划状态：`进行中专题`

## 0. 当前状态

当前阅读器已经完成以下拆解：

- [x] `presentation -> data` 直接硬依赖已切掉
- [x] Reader 依赖图已收口到 provider factory
- [x] `content loading` 主链已迁到独立文件
- [x] `viewport + paged/curl` 主体已迁到独立文件
- [x] `selection / bookmark / toolbar` 主体已迁到独立文件
- [x] `settings / background` 主体已迁到独立文件
- [x] `overlay / chrome` 主体已迁到独立文件

当前主文件仍然约 `1.2w+` 行，说明还剩下几组 glue code 没有拆完。

一句话判断：

- **大块渲染和交互已开始分层**
- **但页面壳、bootstrap、source switch、runtime session glue 仍然偏重**

---

## 1. 目标口径

最终目标不是“把文件继续切碎”，而是让 `reader_page.dart` 只保留：

- 页面 State 字段
- 生命周期入口
- provider 绑定
- 顶层 build 组织
- 少量 callback 分发

下面这些内容都不应长期留在主文件：

- source switch 完整链路
- bootstrap / restore / snapshot 编排
- runtime / reading record / auto-read / progress save 编排
- 导航执行 glue
- shell / system UI / volume key / overlay 可见性编排

---

## 2. 已拆文件清单

- `lib/features/reader/presentation/reader_page_content_loading.dart`
- `lib/features/reader/presentation/reader_page_viewport.dart`
- `lib/features/reader/presentation/reader_page_selection.dart`
- `lib/features/reader/presentation/reader_page_settings.dart`
- `lib/features/reader/presentation/reader_page_overlay.dart`
- `lib/features/reader/presentation/reader_page_source_switch.dart`
- `lib/features/reader/presentation/reader_page_bootstrap.dart`
- `lib/features/reader/presentation/reader_page_runtime.dart`
- `lib/features/reader/presentation/reader_page_navigation.dart`
- `lib/features/reader/presentation/reader_page_shell.dart`
- `lib/features/reader/application/reader_dependencies_provider.dart`
- `lib/features/reader/application/reader_cached_chapter_store.dart`

这些文件已经是后续继续收口的基础，不再回滚进主文件。

---

## 3. 阶段一：Source Switch Flow

目标：把换源完整链路从主文件抽成独立模块，主页面只保留触发入口和结果绑定。

建议落点：

- `lib/features/reader/presentation/reader_page_source_switch.dart`
- 如 application 逻辑继续膨胀，可增加
  `lib/features/reader/application/reader_source_switch_flow_service.dart`

可打勾任务：

- [x] 抽出 `_showSwitchSourceSheet`
- [x] 抽出 `_buildSwitchSourceScope`
- [x] 抽出 `_loadSwitchSourceCandidatesProgressively`
- [x] 抽出 `_loadSwitchSourceScoreStoreSafely`
- [x] 抽出 `_buildSwitchSourceCandidates`
- [x] 抽出 `_resolveSwitchSourceSearchKeyword`
- [x] 抽出 `_showSwitchSourceCandidateSheet`
- [x] 抽出 `_applySwitchSourceScoreAction`
- [x] 抽出 `_canAutoSwitchSourceOnFailure`
- [x] 抽出 `_tryAutoSwitchSourceOnFailure`
- [x] 抽出 `_applySwitchSourceCandidate`
- [x] 抽出 `_syncBookshelfAfterSourceSwitch`
- [x] 抽出 `_syncReadingStateAfterSourceSwitch`
- [x] 抽出 `_confirmSwitchSourceCoverage`
- [x] 抽出 `_restoreSourceSnapshot`

完成标准：

- `reader_page.dart` 不再包含完整换源业务流
- 主页面仅保留 `onTap -> flow.start(...)` 或等价薄入口
- 换源失败、恢复、自动换源的行为不变

验收方式：

- `flutter analyze`
- 手工验证：
  - 普通换源
  - 自动换源
  - 换源失败回滚
  - 书架状态同步

---

## 4. 阶段二：Bootstrap / Restore / Snapshot

目标：把阅读页启动、目录快照恢复、元数据恢复、本地书籍元数据拼接从页面移出。

建议落点：

- `lib/features/reader/presentation/reader_page_bootstrap.dart`
- 如需要跨页面复用，迁入
  `lib/features/reader/application/reader_bootstrap_service.dart`

可打勾任务：

- [x] 抽出 `_bootstrap`
- [x] 抽出 `_tryHydrateTocSnapshot`
- [x] 抽出 `_persistTocSnapshot`
- [x] 抽出 `_applyPresentedBookMetadata`
- [x] 抽出 `_resolveCurrentBookCustomCoverPath`
- [x] 抽出 `_copyLocalReaderDiagnostics`
- [x] 抽出 `_loadIsIosSimulator`
- [x] 抽出 `_shouldSkipBatteryRead`
- [x] 抽出 `_refreshReaderInfoSnapshot`

完成标准：

- `reader_page.dart` 不再包含完整初始化/恢复流程
- 主页面只负责触发 bootstrap 和接收结果 state
- 本地/远程书籍的元数据回填行为保持一致

验收方式：

- `flutter analyze`
- 手工验证：
  - 首次进入阅读页
  - 从进度恢复
  - 从本地图书进入
  - 目录快照恢复

---

## 5. 阶段三：Runtime / Session Glue

目标：把阅读运行时、自动阅读、阅读记录、进度保存、章节预加载等 session glue 迁出主文件。

建议落点：

- `lib/features/reader/presentation/reader_page_runtime.dart`
- 必要时补
  `lib/features/reader/application/reader_runtime_service.dart`

可打勾任务：

- [x] 抽出 `_scheduleReadingRecordSessionStart`
- [x] 抽出 `_setContent`
- [x] 抽出 `_loadContinuousTextChapter`
- [x] 抽出 `_loadAdjacentContinuousTextChapter`
- [x] 抽出 `_isContinuousTextChapterActive`
- [x] 抽出 `_continuousTextChapterScrollRatioFor`
- [x] 抽出 `_activateContinuousTextChapter`
- [x] 抽出 `_syncActiveContinuousTextChapterFromScroll`
- [x] 抽出 `_syncContinuousTextFlowAfterSettingsApplied`
- [x] 抽出 `_resetCatalogSearchCache`
- [x] 抽出 `_storePrecomputedChapterLayout`
- [x] 抽出 `_loadPrecomputedChapterLayout`
- [x] 抽出 `_disposeMangaTransformControllers`
- [x] 抽出 `_restoreScrollPosition`
- [x] 抽出 `_canRunAutoReadNow`
- [x] 抽出 `_autoReadProgressRatio`
- [x] 抽出 `_refreshChapterBookmarks`
- [x] 抽出 `_consumePendingBookmarkJump`
- [x] 抽出 `_jumpToBookmark`
- [x] 抽出 `_isAutoReadAtChapterEnd`
- [x] 抽出 `_scheduleAutoReadResume`
- [x] 抽出 `_reconcileAutoRead`
- [x] 抽出 `_startAutoReadIfNeeded`
- [x] 抽出 `_runAutoReadLoop`
- [x] 抽出 `_tryAutoReadAdvanceChapter`
- [x] 抽出 `_stopAutoRead`
- [x] 抽出 `_onScrollChanged`
- [x] 抽出 `_maybePrefetchContinuousTextNeighbors`
- [x] 抽出 `_scheduleProgressSave`
- [x] 抽出 `_maybeStartReadingRecordSession`
- [x] 抽出 `_syncActiveReadingRecordSessionProgress`
- [x] 抽出 `_scheduleReadingRecordAutoCommit`
- [x] 抽出 `_commitReadingRecordSession`
- [x] 抽出 `_saveProgress`
- [x] 抽出 `_showChapterSwitchFailedSnackbar`
- [x] 抽出 `_scheduleBlockingLoadingCard`
- [x] 抽出 `_clearDelayedLoadingUi`
- [x] 抽出 `_scheduleChapterLoadingIndicator`
- [x] 抽出 `_turnPagedTextPage`
- [x] 抽出 `_startPagedPageTransition`
- [x] 抽出 `_onPagedTransitionStatus`

完成标准：

- `reader_page.dart` 不再负责阅读运行时总装
- progress / auto-read / reading record 状态更新链路有稳定入口
- 预加载、缓存布局、分页状态不再散落在页面里

验收方式：

- `flutter analyze`
- 建议补 targeted test：
  - auto-read
  - progress save
  - reading record session
  - continuous text activation

---

## 6. 阶段四：Navigation / Catalog Glue

目标：把目录跳转、搜索定位、书签跳转、漫画定位等导航胶水从主文件收走。

建议落点：

- `lib/features/reader/presentation/reader_page_navigation.dart`

可打勾任务：

- [x] 抽出 `_jumpToAdjacentReadableChapter`
- [x] 抽出 `_jumpTo`
- [x] 抽出 `_openCatalogSheetFromOverlay`
- [x] 抽出 `_executeNavigationRequest`
- [x] 抽出 `_openMangaPositionSheet`
- [x] 抽出 `_showCatalogSheet`
- [x] 抽出 `_lookupCatalogSearchEntries`

完成标准：

- 主页面不再持有目录/定位完整执行逻辑
- 导航请求的执行入口统一

验收方式：

- `flutter analyze`
- 手工验证：
  - 目录跳转
  - 搜索命中跳转
  - 书签跳转
  - 漫画定位

---

## 7. 阶段五：Shell / System UI / Input Glue

目标：把页面壳层、系统 UI 同步、输入拦截、overlay 显隐控制继续收口。

建议落点：

- `lib/features/reader/presentation/reader_page_shell.dart`

可打勾任务：

- [x] 抽出 `_syncVolumeKeyPageInterception`
- [x] 抽出 `_setVolumeKeyPageInterceptionEnabled`
- [x] 抽出 `_handleVolumeKeyEvent`
- [x] 抽出 `_turnReaderByDirection`
- [x] 抽出 `_advanceScrollReaderByStep`
- [x] 抽出 `_turnMangaPage`
- [x] 抽出 `_handleBackNavigation`
- [x] 抽出 `_markBackNavigationTriggered`
- [x] 抽出 `_buildOverlayScrim`
- [x] 抽出 `_buildBackgroundLayer`
- [x] 抽出 `_buildChapterLoadingIndicator`
- [x] 抽出 `_hideOverlayControls`
- [x] 抽出 `_setOverlayControlsVisibility`
- [x] 抽出 `_syncSystemUiVisibility`
- [x] 抽出 `_onReaderTap`
- [x] 抽出 `_toggleAutoReadSession`
- [x] 抽出 `_startAutoReadSession`
- [x] 抽出 `_stopAutoReadSession`
- [x] 抽出 `_toggleDayNightMode`
- [x] 抽出 `_showMessage`
- [x] 抽出 `_showChapterBoundaryHint`
- [x] 抽出 `_showReaderSnackBar`
- [x] 抽出 `_recordReaderFailure`
- [x] 抽出 `_maybePromptSwitchSourceForMissingSource`

完成标准：

- 页面壳层、副作用和用户提示不再散落在主文件
- 主页面只保留 UI bind 与 event dispatch

本次新增 application 支撑：

- `lib/features/reader/application/reader_feedback_service.dart`
- `lib/features/reader/application/reader_theme_mode_service.dart`

本次说明：

- 页面主文件中的昼夜切换、提示去重、错误记录、缺源换源提示已迁到 `reader_page_shell.dart`
- 其中提示与错误决策已下沉到 application service，不再由主文件直接维护

验收方式：

- `flutter analyze`
- 手工验证：
  - 返回手势
  - 音量键翻页
  - overlay 显隐
  - 自动阅读暂停/恢复
  - 错误提示

---

## 8. 当前剩余结构任务

下面这些任务是当前 `reader` 线在阶段 2 内的显式剩余项。  
后续执行时，先更新本清单，再同步回 `docs/project_architecture_unification_plan.md` 的阶段 2 `reader` 项。

### 8.1 生命周期与依赖绑定收口

- [ ] 继续压薄 `_bindDependencies()`
- [ ] 继续压薄 `initState()`
- [ ] 继续压薄 `dispose()`
- [ ] 明确哪些副作用应下沉到独立 flow / coordinator

完成标准：

- 主文件只保留最少量生命周期入口
- 依赖绑定不再继续膨胀

### 8.2 顶层 Build 收口

- [ ] 拆分 `_buildReaderContent()`
- [ ] 拆分 `_buildBody()`
- [ ] 拆分 `_buildReaderList()`
- [ ] 拆分 `_buildMangaReader()`
- [ ] 拆分 `_buildPagedReader()`
- [ ] 让主文件只负责选择渲染分支，不直接承载大块 UI 组装

完成标准：

- 主文件主要只保留“选择哪种阅读视图”的顶层编排
- 大块 build 逻辑转移到独立 widget / composer

### 8.3 背景与资源型 UI 状态下沉

- [ ] 下沉背景预设加载逻辑
- [ ] 下沉背景预览缓存逻辑
- [ ] 下沉自定义背景文件管理逻辑
- [ ] 下沉背景 preset bytes/base64 管理逻辑

完成标准：

- 主文件不再直接维护这组资源缓存细节
- 背景相关状态有独立管理入口

### 8.4 设置面板 Glue 下沉

- [ ] 拆分 `_buildFloatingReaderSettingsSheet()`
- [ ] 下沉设置项显示格式化辅助方法
- [ ] 下沉设置项分组、展示和交互 glue

完成标准：

- 设置 UI 由独立 builder / presenter 负责
- 主文件只传状态和 callback

### 8.5 阅读内容构建辅助收口

- [ ] 继续下沉分页阅读残余 render helper
- [ ] 继续下沉滚动阅读残余 render helper
- [ ] 继续下沉漫画阅读残余 render helper
- [ ] 继续下沉正文 block / paragraph 展示辅助

完成标准：

- 主文件不再夹杂大量 render helper
- 内容构建辅助逻辑集中到 presentation 子模块

### 8.6 最终收尾验证

- [ ] 对照“最终收尾标准”逐项关闭
- [ ] 回填本清单和总计划中的 reader 阶段状态
- [ ] 补齐本轮 analyze / test / 手工验证记录

完成标准：

- `reader_page.dart` 接近“页面壳 + 顶层 build + callback bind”
- 可以在总计划中将阶段 2 的 `reader` 项正式打勾

---

## 9. 最终收尾标准

当下面条件全部满足时，可认定 `reader_page.dart` 拆解完成：

- [ ] 主文件不再包含完整业务流
- [ ] 主文件不再包含完整渲染大块
- [ ] 主文件不再直接 new 基础设施
- [ ] 主文件主要只剩 state、lifecycle、build、callback bind
- [ ] 所有 reader 子模块都能单独 `flutter analyze`
- [ ] 核心 presentation/application 测试可独立执行

目标参考：

- `reader_page.dart` 行数压到明显低于当前水平
- 页面职责可以在 1 次代码审阅中快速解释清楚

---

## 10. 每阶段验收模板

每个阶段完成后都应补下面记录：

- 变更目标：
- 拆出的文件：
- 主文件减少的行数：
- `flutter analyze` 结果：
- `flutter test` 范围与结果：
- 手工验证项：
- 剩余风险：

---

## 11. 当前建议执行顺序

建议按下面顺序推进，不要来回切：

1. `Source Switch Flow`
2. `Bootstrap / Restore / Snapshot`
3. `Runtime / Session Glue`
4. `Navigation / Catalog Glue`
5. `Shell / System UI / Input Glue`

原因：

- 前三阶段是剩余最重的业务 glue
- 后两阶段更偏收尾和壳层整理

---

## 12. 文档维护规则

- 本文档是 Reader 拆解的唯一执行清单
- 新增 Reader 拆解任务，优先补到本文档而不是散落在聊天里
- 某阶段完成后，应立刻更新打勾状态和剩余范围
- 若执行策略变化，更新本文档，而不是新开平行计划文档
