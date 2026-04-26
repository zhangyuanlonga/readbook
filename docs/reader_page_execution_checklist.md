# Reader Page 拆解执行清单

更新时间：2026-04-26  
用途：作为 `lib/features/reader/presentation/reader_page.dart` 继续拆解的唯一执行文档，按阶段推进、按任务打勾、按验收标准关闭，避免后续再回到“边改边猜”的状态。

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

- [ ] 抽出 `_scheduleReadingRecordSessionStart`
- [ ] 抽出 `_setContent`
- [ ] 抽出 `_loadContinuousTextChapter`
- [ ] 抽出 `_loadAdjacentContinuousTextChapter`
- [ ] 抽出 `_isContinuousTextChapterActive`
- [ ] 抽出 `_continuousTextChapterScrollRatioFor`
- [ ] 抽出 `_activateContinuousTextChapter`
- [ ] 抽出 `_syncActiveContinuousTextChapterFromScroll`
- [ ] 抽出 `_syncContinuousTextFlowAfterSettingsApplied`
- [ ] 抽出 `_resetCatalogSearchCache`
- [ ] 抽出 `_storePrecomputedChapterLayout`
- [ ] 抽出 `_loadPrecomputedChapterLayout`
- [ ] 抽出 `_disposeMangaTransformControllers`
- [ ] 抽出 `_restoreScrollPosition`
- [ ] 抽出 `_canRunAutoReadNow`
- [ ] 抽出 `_autoReadProgressRatio`
- [ ] 抽出 `_refreshChapterBookmarks`
- [ ] 抽出 `_consumePendingBookmarkJump`
- [ ] 抽出 `_jumpToBookmark`
- [ ] 抽出 `_isAutoReadAtChapterEnd`
- [ ] 抽出 `_scheduleAutoReadResume`
- [ ] 抽出 `_reconcileAutoRead`
- [ ] 抽出 `_startAutoReadIfNeeded`
- [ ] 抽出 `_runAutoReadLoop`
- [ ] 抽出 `_tryAutoReadAdvanceChapter`
- [ ] 抽出 `_stopAutoRead`
- [ ] 抽出 `_onScrollChanged`
- [ ] 抽出 `_maybePrefetchContinuousTextNeighbors`
- [ ] 抽出 `_scheduleProgressSave`
- [ ] 抽出 `_maybeStartReadingRecordSession`
- [ ] 抽出 `_syncActiveReadingRecordSessionProgress`
- [ ] 抽出 `_scheduleReadingRecordAutoCommit`
- [ ] 抽出 `_commitReadingRecordSession`
- [ ] 抽出 `_saveProgress`
- [ ] 抽出 `_showChapterSwitchFailedSnackbar`
- [ ] 抽出 `_scheduleBlockingLoadingCard`
- [ ] 抽出 `_clearDelayedLoadingUi`
- [ ] 抽出 `_scheduleChapterLoadingIndicator`
- [ ] 抽出 `_turnPagedTextPage`
- [ ] 抽出 `_startPagedPageTransition`
- [ ] 抽出 `_onPagedTransitionStatus`

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

- [ ] 抽出 `_jumpToAdjacentReadableChapter`
- [ ] 抽出 `_jumpTo`
- [ ] 抽出 `_openCatalogSheetFromOverlay`
- [ ] 抽出 `_executeNavigationRequest`
- [ ] 抽出 `_openMangaPositionSheet`
- [ ] 抽出 `_showCatalogSheet`
- [ ] 抽出 `_lookupCatalogSearchEntries`

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

- [ ] 抽出 `_syncVolumeKeyPageInterception`
- [ ] 抽出 `_setVolumeKeyPageInterceptionEnabled`
- [ ] 抽出 `_handleVolumeKeyEvent`
- [ ] 抽出 `_turnReaderByDirection`
- [ ] 抽出 `_advanceScrollReaderByStep`
- [ ] 抽出 `_turnMangaPage`
- [ ] 抽出 `_handleBackNavigation`
- [ ] 抽出 `_markBackNavigationTriggered`
- [ ] 抽出 `_buildOverlayScrim`
- [ ] 抽出 `_buildBackgroundLayer`
- [ ] 抽出 `_buildChapterLoadingIndicator`
- [ ] 抽出 `_hideOverlayControls`
- [ ] 抽出 `_setOverlayControlsVisibility`
- [ ] 抽出 `_syncSystemUiVisibility`
- [ ] 抽出 `_onReaderTap`
- [ ] 抽出 `_toggleAutoReadSession`
- [ ] 抽出 `_startAutoReadSession`
- [ ] 抽出 `_stopAutoReadSession`
- [ ] 抽出 `_toggleDayNightMode`
- [ ] 抽出 `_showMessage`
- [ ] 抽出 `_showChapterBoundaryHint`
- [ ] 抽出 `_showReaderSnackBar`
- [ ] 抽出 `_recordReaderFailure`
- [ ] 抽出 `_maybePromptSwitchSourceForMissingSource`

完成标准：

- 页面壳层、副作用和用户提示不再散落在主文件
- 主页面只保留 UI bind 与 event dispatch

验收方式：

- `flutter analyze`
- 手工验证：
  - 返回手势
  - 音量键翻页
  - overlay 显隐
  - 自动阅读暂停/恢复
  - 错误提示

---

## 8. 最终收尾标准

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

## 9. 每阶段验收模板

每个阶段完成后都应补下面记录：

- 变更目标：
- 拆出的文件：
- 主文件减少的行数：
- `flutter analyze` 结果：
- `flutter test` 范围与结果：
- 手工验证项：
- 剩余风险：

---

## 10. 当前建议执行顺序

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

## 11. 文档维护规则

- 本文档是 Reader 拆解的唯一执行清单
- 新增 Reader 拆解任务，优先补到本文档而不是散落在聊天里
- 某阶段完成后，应立刻更新打勾状态和剩余范围
- 若执行策略变化，更新本文档，而不是新开平行计划文档
