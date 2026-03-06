# 搜索页面优化实施方案

## 概述
对 `search_page.dart`（1253行）进行性能优化、组件拆分、体验增强。不包含结果去重/聚合（#8）。

---

## 第一步：新建搜索历史服务

**新建文件**: `lib/features/search/application/search_history_service.dart`

- 参照 `BookshelfService` 的 SharedPreferences 模式
- 存储最近 15 条搜索关键词（去重，最新在前）
- 提供 `getAll()`, `add(keyword)`, `remove(keyword)`, `clear()` 方法
- 存储 key: `search.history`

---

## 第二步：拆分子组件

在 `lib/features/search/presentation/widgets/` 下新建以下文件：

### 2a. `search_input_card.dart`
- 提取 `_buildSearchInputCard()`, `_buildSourceFilterRow()`, `_buildPreciseMatchRow()`
- 接收回调参数：`onSearch`, `onCancel`, `onClearResults`, `onContentModeChanged`, `onPreciseMatchChanged`, `onOpenSourceFilter`
- 接收状态参数：`isSearching`, `searchContentMode`, `isPreciseBookMatch`, `selectedSourceCount`, `availableSourceCount`, `isLoadingSourceCount`
- TextField 使用 `ValueListenableBuilder` 替代 `onChanged: (_) => setState(() {})`

### 2b. `search_progress_card.dart`
- 提取 `_buildProgressCard()`
- 接收参数：`report`, `isSearching`

### 2c. `search_report_summary.dart`
- 提取 `_buildReportSummary()`, `_buildSummaryChip()`
- 接收参数：`report`, `visibleBookCount`, `isPreciseBookMatch`, `searchContentMode`, `hasSelectedSources`

### 2d. `search_failure_banner.dart`
- 提取 `_buildFailureBanner()`, `_showFailureDetails()`
- 接收参数：`report`, `onShowDetails`

### 2e. `search_book_card.dart`
- 提取 `_buildBookCard()`, `_buildInfoPill()`, `_buildCoverPreview()`, `_buildCoverFallback()`
- 封面图添加 `cacheWidth: 112, cacheHeight: 160`
- 封面图添加 `loadingBuilder` 显示加载占位
- 接收预处理好的 snippet 数据（而非原始数据）

### 2f. `search_empty_state.dart`
- 提取空状态 UI，增强为：图标 + 标题 + 副标题 + 搜索历史列表
- 接收参数：`history`, `onHistoryTap`, `onClearHistory`

---

## 第三步：性能优化（在主文件中）

### 3a. snippet 预处理
- 在 `_setReport()` 中对所有 book 的 `intro` 和 `latestChapter` 做 `_normalizeSnippet` 预处理
- 用 `Map<String, String?>` 缓存结果，传给 `SearchBookCard`

### 3b. 结果列表改用 ListView.builder
- 将 `Column` + `map` 替换为 `ListView.builder`（懒加载渲染）
- 保留分页逻辑

### 3c. Theme 缓存
- 各子组件 build 方法开头缓存 `final theme = Theme.of(context)` 和 `final colorScheme = theme.colorScheme`

---

## 第四步：搜索历史 UI 集成

- 在 `search_page.dart` 中实例化 `SearchHistoryService`
- 搜索成功后调用 `_historyService.add(keyword)`
- 空状态改用 `SearchEmptyState` 组件，展示搜索历史
- 点击历史关键词自动填入并搜索

---

## 文件变动汇总

| 操作 | 文件 |
|------|------|
| 新建 | `lib/features/search/application/search_history_service.dart` |
| 新建 | `lib/features/search/presentation/widgets/search_input_card.dart` |
| 新建 | `lib/features/search/presentation/widgets/search_progress_card.dart` |
| 新建 | `lib/features/search/presentation/widgets/search_report_summary.dart` |
| 新建 | `lib/features/search/presentation/widgets/search_failure_banner.dart` |
| 新建 | `lib/features/search/presentation/widgets/search_book_card.dart` |
| 新建 | `lib/features/search/presentation/widgets/search_empty_state.dart` |
| 修改 | `lib/features/search/presentation/search_page.dart`（大幅简化） |
