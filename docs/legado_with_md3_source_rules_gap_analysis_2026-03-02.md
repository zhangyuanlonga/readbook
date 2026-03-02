# legado-with-MD3-main 书源规则与架构对比分析（vs flutter_appread）

更新时间：2026-03-02

## 1. 结论先看

- `legado-with-MD3-main` 的核心规则内核仍然是 Legado 成熟链路（`AnalyzeRule + AnalyzeUrl + Rhino`），UI 虽在做 MD3/Compose 迁移，但规则能力并未“重写”，而是沿用并增强。
- 该分支在“书源实战能力”上最强的三块是：规则语法完备度、搜索聚合与换源数据链、替换净化规则系统。
- 我们 `flutter_appread` 在架构可维护性、跨平台、兼容诊断与降级策略上更现代（适配器、兼容提示、诊断页、桥接能力矩阵），但在“规则生态完整复刻”上还有关键差距。
- 最值得复用的方向：  
  1) 全局替换净化规则系统  
  2) 搜索命中缓存与换源直连查询  
  3) 书源健康度与响应时间闭环  
  4) URL 选项与 JS bridge 语义继续补齐

---

## 2. legado-with-MD3-main 的书源规则体系

## 2.1 规则数据模型（结构化）

- `BookSource` 直接持有强类型规则对象：`ruleSearch / ruleExplore / ruleBookInfo / ruleToc / ruleContent`。
- 通过 Room `TypeConverters` 序列化反序列化规则对象，不是散字段拼装。
- 规则对象拆分明确：`SearchRule`、`BookInfoRule`、`TocRule`、`ContentRule` 等。

这使得规则字段语义更稳定，后续演进（新增字段、迁移、兼容）成本较低。

## 2.2 规则执行核心（AnalyzeRule）

`AnalyzeRule` 支持并统一处理：

- HTML / JSON / XPath / Regex / JS 多模式规则。
- `@put` / `@get` 变量注入读取。
- `{{...}}` 模板求值。
- `##` 替换语法（replaceRegex）。
- JS 执行深度与调用次数防护（避免失控）。

本质上是“规则解释器 + 变量系统 + 后处理系统”一体化引擎。

## 2.3 请求构建与网络行为（AnalyzeUrl）

`AnalyzeUrl` 除了解析 URL 模板，还内建了请求行为控制：

- 方法/头/体/重试解析。
- `webView` 与延迟参数。
- `enabledCookieJar` 控制。
- 并发限流（`ConcurrentRateLimiter`）。
- 代理请求分支能力。

这点很关键：Legado 把“规则解析”和“请求语义”紧耦合成完整 DSL 运行时，不是单纯 URL 替换器。

## 2.4 搜索排序与同书聚合

`SearchModel.mergeItems` 的主逻辑：

- 先按“精确命中（书名/作者 == 关键词）/包含命中/其他”分层。
- 同书判定是 `name == && author ==`。
- 同书命中会合并 `origins`（命中源集合）。
- 列表按 `origins.size` 降序，把多源命中书前置。

这就是你提到的“同一本书命中多个源时聚合成一条并带命中数”的核心来源。

## 2.5 书源体检与失效标记

`CheckSourceService` 提供了搜索/发现/详情/目录/正文的链路校验，并将失败原因写回书源分组与备注：

- 例如 `搜索失效`、`发现失效`、`搜索目录失效`、`搜索正文失效`、`校验超时`、`js失效`。
- 每次校验更新 `respondTime`。

这形成了“可运营”的书源健康管理，而不仅是一次性诊断。

## 2.6 替换净化规则（独立系统）

该分支有完整 `ReplaceRule` 体系：

- 独立表 `replace_rules`。
- 规则维度：名称、分组、pattern、replacement、scope、excludeScope、是否正则、超时、排序。
- 支持标题与正文分域应用，支持按书名/书源排除。
- 运行期捕获 regex 超时并自动禁用异常规则。
- 有完整 UI（列表、编辑、排序、导入导出）。

---

## 3. legado-with-MD3-main 的架构状态

## 3.1 总体形态

- 仍是 Android 原生主工程（Kotlin + Room + Koin）。
- 模块化：`app` + `modules:book` + `modules:rhino`（另有 `modules/web` 目录，但未在当前 `settings.gradle` 纳入构建）。
- 数据库中心化：`AppDatabase version = 80`，实体和迁移体系成熟。

## 3.2 UI 技术栈状态

- 混合栈：Compose 与传统 View 并存。
- 快速统计：`@Composable` 约 97 处；`res/layout` XML 约 212 个。
- 说明其处于“持续迁移态”，并非纯 Compose 应用。

## 3.3 依赖注入与运行时

- Koin 模块化注入（`appModule`、`appDatabaseModule`）。
- App 启动阶段初始化 Rhino 包装器，保证规则 JS bridge 的对象访问能力。

---

## 4. 我们 flutter_appread 的现状映射

## 4.1 已有优势（可继续放大）

- 架构更清晰：`core / data / domain / features`，跨平台路径明确。
- 已有 Legado 兼容适配层：`LegadoSourceAdapter` 做字段映射与兼容补丁。
- 已有能力评估与诊断：`SourceCapabilityAnalyzer`、`SourceValidator`、`SourceDiagnosticsService`。
- 已有搜索聚合与排序：支持按标题+作者聚合、相关性 tier、质量评分、源序加权。
- 已有自动换源开关与读中自动尝试（系统设置 + Reader 页逻辑）。

## 4.2 当前短板（影响“完整对齐”）

- 规则语法虽覆盖主干，但运行时语义分散在多个 processor/service，完整等价成本高。
- URL 选项能力与 AnalyzeUrl 仍有缺口（如 cookieJar/webView delay/更完整请求语义）。
- 缺少 Legado 那种“可运营”的书源健康状态闭环（分组打标、响应时延沉淀）。
- 缺少独立“替换净化规则中心”（当前主要是 `contentReplaceRegex`）。
- 缺少搜索命中持久化模型（Legado `searchBooks`）带来的换源快速路径。

---

## 5. 差距矩阵（能力级）

| 能力项 | legado-with-MD3-main | flutter_appread | 差距等级 | 建议 |
| --- | --- | --- | --- | --- |
| 规则模型结构化 | `BookSource + rule/*` 强类型 | `SourceRuleSet` 扁平规则集 | 中 | 保持现状可行，重点补运行时语义 |
| 规则执行一体化 | `AnalyzeRule` 一体化解析+变量+替换 | 引擎 + 多 processor 分层 | 中 | 用回归样本驱动语义对齐，不必硬搬同构实现 |
| URL 选项语义 | `AnalyzeUrl` 支持更完整请求行为 | `UrlOption` 覆盖核心但不全 | 中高 | 优先补 cookie/webView 延迟/特殊选项 |
| JS bridge 语义完备度 | Rhino 原生链路成熟 | 已有 full/partial/unsupported 矩阵 | 中 | 继续从 partial 列表中逐步转 full |
| 搜索同书聚合 | 严格 `name+author` + 命中源计数排序 | 已支持严格聚合与评分 | 低 | 保持并补回归测试 |
| 换源数据支撑 | `searchBooks` 持久化 + DAO 查询 | 主要靠运行时检索 | 中高 | 增加搜索命中缓存表与换源快速查询 |
| 书源健康闭环 | `CheckSourceService` 多阶段校验 + 失效标记 + respondTime | 诊断页 + healthStatus 持久化 | 中 | 增加后台/批处理校验与指标沉淀 |
| 替换净化系统 | 独立规则中心（scope/exclude/timeout/UI） | 仅源内 replaceRegex 为主 | 高 | 新增全局 ReplaceRule 子系统 |
| 书源管理能力 | `customOrder`、多分组、丰富 DAO | 目前更偏基础列表 | 中高 | 补自定义排序/分组查询能力 |
| 架构可维护性 | Android 单端、历史包袱较重 | 跨平台 + 分层清晰 | 我方优势 | 继续保持，避免复制其历史复杂度 |

---

## 6. 对方优势可否为我们所用（可复用建议）

## 6.1 可直接借鉴（高价值）

- 搜索聚合策略细节：  
  严格同书判定 + 命中数优先排序，已经与我们方向一致，可作为测试基线继续固化。
- 书源体检流程模板：  
  搜索 -> 详情 -> 目录 -> 正文 的分阶段失败分类，可直接迁移为我们的批诊断规则模板。
- 替换规则防护策略：  
  regex 超时自动降级/禁用，建议直接在我们 Replace 体系复用。

## 6.2 需要重构后复用（中高成本）

- `AnalyzeRule` / `AnalyzeUrl` 全量搬运不建议直接照搬。  
  建议“能力清单化 + 回归样本驱动对齐”，避免把 Android 特定实现耦合带入 Flutter。
- `searchBooks` 持久化模型可复用思路但需按 Drift 重建，和现有 `Book` / `Source` ID 体系对齐。
- ReplaceRule UI 可以复用交互设计与数据字段，但实现需走 Flutter 页面与状态体系。

---

## 7. 建议落地路线（可打勾执行）

## P0（先补最影响体验的闭环）

- [ ] 新增“搜索命中缓存表”（按 `title+author+sourceId` 存储最近命中），用于换源快速候选。
- [ ] 换源候选排序加入“命中次数/源评分/最新章节完整度”综合分。
- [ ] 书源健康指标增加响应时长与阶段失败计数持久化。
- [ ] URL 选项补齐 `webViewDelay`、`enabledCookieJar` 的解析与请求链透传。
- [ ] 补一组 Legado 对照回归样本（搜索、目录、正文、换源）。

## P1（能力对齐）

- [ ] 设计并落地全局 `ReplaceRule` 子系统（表结构、仓储、执行器）。
- [ ] 支持 `scopeTitle/scopeContent/excludeScope/group/order`。
- [ ] 正则超时治理：单规则超时自动禁用并记录错误。
- [ ] 增加替换规则管理页（列表、启停、排序、导入导出）。

## P2（长期演进）

- [ ] 统一规则执行上下文（变量、模板、replace、bridge）以减少语义分散。
- [ ] 建立“partial bridge -> full bridge”季度清单，持续抹平语义差异。
- [ ] 形成自动化书源巡检任务（周期跑批 + 结果入库 + UI 告警）。

---

## 8. 风险与取舍

- 全量追平 Legado 语义是高成本长期工程，不建议一次性重写引擎。
- 我们应保持 Flutter 分层优势，按“用户可感知价值”分批补齐。
- 建议优先级：换源效率 > 替换净化中心 > URL 选项补齐 > bridge 深水区。

---

## 9. 关键证据文件（本次审查）

### legado-with-MD3-main

- `settings.gradle`
- `app/build.gradle.kts`
- `app/src/main/java/io/legado/app/data/entities/BookSource.kt`
- `app/src/main/java/io/legado/app/data/entities/rule/*.kt`
- `app/src/main/java/io/legado/app/model/analyzeRule/AnalyzeRule.kt`
- `app/src/main/java/io/legado/app/model/analyzeRule/AnalyzeUrl.kt`
- `app/src/main/java/io/legado/app/model/webBook/SearchModel.kt`
- `app/src/main/java/io/legado/app/data/dao/SearchBookDao.kt`
- `app/src/main/java/io/legado/app/service/CheckSourceService.kt`
- `app/src/main/java/io/legado/app/data/entities/ReplaceRule.kt`
- `app/src/main/java/io/legado/app/help/book/ContentProcessor.kt`
- `app/src/main/java/io/legado/app/di/appModule.kt`
- `app/src/main/java/io/legado/app/di/appDatabaseModule.kt`
- `app/src/main/java/io/legado/app/data/AppDatabase.kt`
- `app/src/main/java/io/legado/app/App.kt`

### flutter_appread

- `lib/domain/entities/source_definition.dart`
- `lib/data/adapters/legado_source_adapter.dart`
- `lib/core/rule_engine/rule_engine.dart`
- `lib/core/rule_engine/rule_parser.dart`
- `lib/core/rule_engine/legado_bridge_capability.dart`
- `lib/core/rule_engine/processors/legacy_rule_variable_processor.dart`
- `lib/core/network/url_option.dart`
- `lib/core/network/source_rate_limiter.dart`
- `lib/features/source/application/source_validator.dart`
- `lib/features/source/application/source_capability_analyzer.dart`
- `lib/features/source/application/source_diagnostics_service.dart`
- `lib/features/search/application/search_service.dart`
- `lib/features/reader/application/reader_system_settings_service.dart`
- `lib/features/reader/presentation/reader_page.dart`

---

## 10. 用户当前在用书源样本集（已纳入）

- 样本目录：`/Users/zhangyuanlong/storage/FlutterProject/书源`
- 当前样本文件（3 个）：
  - `3000 书源.json`
  - `read.json`
  - `shareBookSource.json`
- 说明：后续“规则兼容回归 / 搜索聚合 / 换源策略 / 诊断覆盖率”建议优先基于这 3 份样本执行。
