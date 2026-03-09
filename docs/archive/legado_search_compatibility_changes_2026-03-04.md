# 开源阅读搜索兼容改造变更说明（2026-03-04）

## 1. 目的与范围
- 目标：对齐开源阅读（Legado）搜索链路的兼容性与实时体验，同时降低大数据量下的卡顿与掉帧。
- 范围：搜索请求构造、解析与聚合、UI 渲染更新节奏、WebView 执行稳定性、调试日志治理。

## 2. Git 基线与记录

### 2.1 上一版已提交记录（主干）

1. `5adff179c57eaf123a90aa4c9a203fca9de3bf16`（2026-03-02 22:37:06 +0800）  
   提交信息：`Feat: 1.新增“搜索命中缓存表” 2.换源候选排序加入“命中次数/源评分/最新章节完整度”综合分 3.书源健康指标增加响应时长与阶段失败计数持久化 4.URL 选项补齐 webViewDelay、enabledCookieJar`  
   重点：引入搜索命中缓存、换源排序增强、书源健康指标持久化、URL/WebView 选项补齐。

2. `34585e3411d7bb001ed0cac381ca5ebc2337df5b`（2026-03-02 19:26:46 +0800）  
   提交信息：`Feat: 搜索复原-开源阅读逻辑-换源也重新修改逻辑`  
   重点：搜索流程回归开源阅读逻辑、搜索系统设置接入、搜索页与换源流程联动调整。

### 2.2 本次本地未提交改动（截至 2026-03-04）

- `lib/features/search/application/search_service.dart`
- `lib/features/search/presentation/search_page.dart`
- `lib/features/search/application/search_system_settings_service.dart`
- `lib/features/mine/presentation/system_settings_page.dart`
- `lib/core/webview/webview_executor.dart`
- `lib/core/webview/interactive_verification_browser_executor.dart`
- `lib/app/bootstrap.dart`
- `test/features/search/application/search_system_settings_service_test.dart`

本次上述 8 个文件合计：`1661` 行新增，`346` 行删除。

## 3. 本次改动内容（按链路）

### 3.1 搜索服务层（SearchService）

1. 进度回调节流提升  
   - 服务层进度聚合窗口改为 `900ms`。  
   - 在“全部源完成”时会立即推送最终进度。

2. 聚合策略从“每次都重算”改为“分阶段重算”  
   - 保持实时体验，不改为“仅最终聚合”。  
   - 维护聚合缓存，按窗口重算，减少高频重复计算。

3. 同书聚合排序支持后台 Isolate  
   - 数据量较大（阈值：160）时在 Isolate 执行聚合与排序。  
   - 失败时自动回退主 Isolate，保证功能可用。

4. 请求与解析缓存  
   - 增加每源 `searchRequestSpec` 缓存。  
   - 增加每源 `searchParseRules` 缓存。  
   - 降低同轮搜索内重复解析开销。

5. `searchInitRule` 快速路径  
   - 按规则内容和模板变量依赖判断是否真的需要 `init` 请求。  
   - 避免不必要的初始化请求。

6. 搜索日志开关接入  
   - 搜索 INFO 日志改为受开关控制。  
   - 每次搜索/单源测试前同步设置，默认关闭 INFO 调试日志。

### 3.2 搜索 UI 层（SearchPage）

1. 进度与渲染状态拆分  
   - 从整页 `setState` 迁移为 `ValueNotifier` 分离更新。  
   - 进度卡与结果列表可独立更新，减少无效重建。

2. 列表渲染改为 `CustomScrollView + SliverList`  
   - 避免大列表一次性重建。  
   - 保留分页追加渲染（`_searchResultPageSize`）策略。

3. 渲染预处理下沉到 Isolate  
   - 精准匹配过滤、简介/最新章节文本归一化移至后台预处理。  
   - 使用可发送消息结构（Map/List/String/bool）规避 isolate unsendable 问题。  
   - isolate 失败自动回退 UI Isolate。

4. UI 进度刷新节流  
   - UI 层进度窗口调整为 `1500ms`。

5. 新增“滚动中暂缓 UI 应用更新”  
   - 用户滚动期间只缓存最新进度，不立即刷新列表。  
   - 滚动结束后延迟 `180ms` 一次性应用，降低滚动中插帧导致的肉眼卡顿。

### 3.3 系统设置与开关

1. 搜索系统设置新增键  
   - `search.system.debugLogEnabled`（默认 `false`）。

2. 设置页新增调试区  
   - 路径：系统设置 -> 其他（调试）。  
   - 新增“搜索调试日志（INFO）”开关，并含读写失败提示。

3. 设置服务测试补充  
   - 新增 debug log 开关读写持久化测试用例。

### 3.4 WebView 稳定性（重点针对 macOS 卡顿/事件风暴）

1. 关闭插件调试日志  
   - `bootstrap` 中关闭 `flutter_inappwebview` debug logging，减少控制台事件洪泛。

2. 桌面默认 WebView 并发降为 1  
   - `macOS/windows/linux` 默认 `poolSize=1`，减轻主线程压力。

3. 减少无效导航噪音  
   - 移除 headless 初始化阶段的 `about:blank` 初始请求。

4. 错误分级处理  
   - 忽略 `CANCELLED/-999`、`about:blank`、子资源错误。  
   - 仅对真正主框架失败上抛错误。

5. 证书回调策略  
   - 增加 `onReceivedServerTrustAuthRequest` 处理。  
   - `UNSPECIFIED` 场景默认 `PROCEED`，其余异常走 `CANCEL`。

6. 交互验证页同样忽略取消类错误  
   - 避免用户侧误报和不必要的失败提示。

## 4. 与开源阅读对齐点（本次）

1. 保留“实时反馈”，但用窗口化节流与阶段聚合控制 CPU/主线程压力。  
2. 大计算下沉后台（Isolate），避免直接压 UI 线程。  
3. 请求链路缩短：不必要 `init` 请求不再触发。  
4. 兼容性优先：保持旧规则兼容前提下增加缓存和降噪。

## 5. 验证记录（本地）

1. `flutter analyze`（本次涉及核心文件）通过。  
2. `flutter test test/core/webview/webview_executor_test.dart` 通过。  
3. `flutter test test/features/search/application/search_system_settings_service_test.dart` 通过。  
4. 二次修正后 `flutter analyze lib/features/search/presentation/search_page.dart lib/features/search/application/search_service.dart` 通过。  
5. `flutter test test/features/search/application/search_service_test.dart` 在当前环境存在既有 `Binding has not yet been initialized` 用例问题（非本次逻辑回归结论）。

## 6. 备注

- 本文档用于“上一版已提交 + 当前本地修改”的统一归档，便于后续回归与发布前核对。  
- 若后续继续优化滚动中体验，可进一步将停滚延迟从 `180ms` 调整到 `250~300ms` 做 A/B 体感验证。

## 7. 代码复盘（无用代码/逻辑顺滑性）

### 7.1 复盘结论（本轮）

- `flutter analyze` 维度：未发现“编译级无用代码/未使用成员”。
- 逻辑复盘维度：原发现 **5 项** 风险，已按本轮修正处理为：
  - 已修复：4 项（P2/P3）
  - 保留：1 项（P1，按当前决策暂不改）
- 明确可判定为“完全死代码”的条目：0 项。  
  当前剩余主要问题是“`searchInitRule` 快速路径的兼容性边界”。

### 7.2 问题清单（状态）

1. **[P1 | 保留] `searchInitRule` 快速路径可能跳过必要的会话预热请求**  
   - 文件：`lib/features/search/application/search_service.dart:1194`, `lib/features/search/application/search_service.dart:2236`  
   - 现象：当前仅在 `parseRule` 存在或请求模板依赖额外变量时才执行 init。  
   - 风险：部分书源的 init 主要用于拿 cookie/会话，不依赖变量也无 `@put`，被跳过后可能出现 403、空结果、偶发失效。  
   - 处理状态：按当前决策保留，不在本轮改动。

2. **[P2 | 已修复] 搜索结束阶段重复重计算（冗余）**  
   - 修复点：`_runSearch` 最终结果改为走 `_applyFinalProgressReport`，并在非滚动态下直接等待一次最终渲染；去掉无条件 `forceRenderState: true`。  
   - 文件：`lib/features/search/presentation/search_page.dart:998`

3. **[P2 | 已修复] 滚动延迟提交缺少兜底强制落地**  
   - 修复点：新增 `_scrollUiMaxDeferredWindow=2s` 的强制 flush 定时器，滚动事件异常时也会落地最新更新。  
   - 文件：`lib/features/search/presentation/search_page.dart:917`

4. **[P2 | 已修复] 搜索完成态与最终渲染完成时序不一致**  
   - 修复点：引入“待完成会话”状态，若最终结果在滚动中被延迟，则保持 `_isSearching=true` 直到 deferred final report 真正渲染完成。  
   - 文件：`lib/features/search/presentation/search_page.dart:1027`, `lib/features/search/presentation/search_page.dart:1128`

5. **[P3 | 已修复] 调试日志开关重复读取偏好**  
   - 修复点：`SearchService` 增加 `_searchDebugLoggingSettingLoaded`，设置值后标记已加载；后续搜索不再重复读 SharedPreferences。  
   - 文件：`lib/features/search/application/search_service.dart:223`, `lib/features/search/application/search_service.dart:2159`

### 7.3 “这次改动造成多少”量化

- 原始风险项：**5**（P1=1, P2=3, P3=1）。  
- 本轮已修复：**4**。  
- 当前剩余风险：**1**（P1，书源兼容稳定性相关，优先级最高）。

## 8. 三项 Feat 实际落地核查（补充）

### 8.1 总览结论

| Feat | 是否真实使用 | 与开源阅读（Legado）关系 | 建议 |
|---|---|---|---|
| 1. 搜索命中缓存表 | 是（搜索写入 + 换源排序读取） | 原版没有同名“跨会话命中表”，更像本项目增强 | 保留，但建议降写入成本 |
| 2. 换源候选综合分（命中次数/源评分/章节完整度） | 是（换源候选构建与排序主链路） | “源评分/书评分”与原版接近；“命中次数/章节完整度”为增强项 | 保留（核心体验），权重可调 |
| 3. 健康指标持久化（响应时长+阶段失败计数） | 部分（高频写入已接入，但当前几乎无消费端） | 原版主要有 `respondTime` 与源管理排序，不含阶段失败计数体系 | 建议降级或改为低频采样 |

### 8.2 调用链证据

1. Feat 1：搜索命中缓存表
   - 写入：`search_service.dart` 在搜索结束后调用 `_persistSearchHitCache()`，再由 `SearchHitCacheService.recordBooks()` 入库 `search_source_hits`。
   - 读取：`reader_page.dart` 在换源流程调用 `loadSourceHitCounts()`，参与候选评分 `hitBonus`。
   - 相关表结构：`app_database.dart` 的 `SearchSourceHits`（`tableName = search_source_hits`）。

2. Feat 2：换源候选综合分
   - 评分来源：`reader_page.dart` 同时读取 `hitCount` + `sourceScore` + `bookScore`，并纳入 `_composeSwitchSourceCandidateScore(...)`。
   - 排序：先按综合分，再按最新章节号（完整度近似信号）等规则排序。
   - 评分持久化：`source_switch_score_service.dart`（SharedPreferences）维护源评分/书评分。

3. Feat 3：健康指标持久化
   - 写入入口：`search_service.dart`、`book_detail_service.dart`、`chapter_content_service.dart` 都会触发 `recordRequestSuccess/Failure`。
   - 持久化：`SourceHealthMetricsService` 更新 `lastResponseDurationMs`、`lastResponseStage`、`stageFailureCounts`，再 `upsert` 源数据。
   - 当前消费端：本仓库中尚未发现对应 UI/排序/策略读取上述三项指标（除实体映射/测试外）。

### 8.3 与开源阅读对齐判断

1. 真正“对齐原版核心”的是 Feat 2 里的“源评分/书评分”。
2. Feat 1 与 Feat 2 的“命中次数/章节完整度”属于增强，不是原版必需项。
3. Feat 3 的“阶段失败计数持久化”不属于原版核心能力，当前投入大于收益。

### 8.4 性能与复杂度观察（当前代码）

1. 命中缓存写入在搜索主流程中 `await` 执行，且发生在取消分支判断之前，会拉长尾部完成时间。
2. 健康指标每次写入会先拉全量书源再定位目标源（`getAll()` + `upsert`），在大书源量和高并发请求下成本较高。
3. 结合目前“消费端缺失”，Feat 3 的性价比偏低，建议优先治理。
