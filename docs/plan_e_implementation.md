# 方案 E 执行计划 — Legado 书源规则全兼容（混合三层架构）

> 本文档为 Codex 可执行的逐任务拆解，每个任务包含：目标、输入/输出文件、精确插入点、代码规范约束、验收标准。
> 依赖关系用 `depends: [任务编号]` 标注，无依赖的任务可并行。

---

## 全局约束

1. **状态管理**：全项目 Riverpod，Widget 中禁止直接写网络 / 解析逻辑。
2. **命名**：文件 `snake_case.dart`，类 `UpperCamelCase`，方法/变量 `lowerCamelCase`。
3. **错误处理**：禁止吞异常；catch 必须至少记录一条含 `sourceId`/`stage`/`url`/`briefMessage` 的日志。
4. **测试**：每个任务完成后必须 `flutter analyze` + `flutter test` 全量通过。
5. **Schema 迁移**：Phase 0 所有字段变更合并为一次迁移（version 3 → 4）。
6. **文档**：跨模块改动同步更新 `docs/architecture.md` 和 `docs/implementation_steps.md`。

---

## 执行进度梳理（2026-02-27，已复跑）

> 口径已统一：**核心目标是适配 Legado 兼容引擎/数据链路，不以 UI 改造为主线**。
> - 主线验收：规则映射、执行结果、领域模型、持久化、回归稳定性。
> - UI 展示：作为可选增强，不阻塞兼容主线推进（除非影响核心功能可用性）。

### 主线原则（本次确认）

1. 以 Legado 规则兼容为第一优先级，不做“为兼容而改现有 UI 设计”。
2. 任务完成标准以“解析正确 + 数据正确 + 回归通过”为准。
3. UI 断言/文案波动默认不阻塞 Phase 里程碑。
4. 既有书源测试资产必须保留并持续复用，新增能力先补 fixture 再改逻辑。
5. 涉及提示文案/徽标/页面展示的改动统一归入可选增强，不纳入兼容主线任务验收。

### 兼容验证资产（必须保留）

| 资产 | 作用 |
|------|------|
| `test/compatibility/legacy_source_compatibility_test.dart` | 端到端兼容回归（搜索→详情→目录→正文） |
| `test/fixtures/compatibility/legacy_sources_manifest.json` | 兼容样本清单与期望基线 |
| `test/regression/source_baseline_regression_test.dart` | 大样本导入后的核心规则链路基线 |
| `test/data/adapters/legado_source_adapter_test.dart` | 规则字段映射与兼容降级逻辑 |
| `test/features/search/application/search_service_test.dart` | 搜索链路规则执行与网络选项解析 |

### 状态判定标准

- `已完成`：兼容引擎/数据目标已达成，回归路径覆盖到位。
- `部分完成`：主流程已落地，但核心语义或回归样本仍有缺口。
- `未开始`：仓库中未发现对应实现。

### 分阶段汇总（兼容主线口径）

| Phase | 已完成 | 部分完成 | 未开始 | 备注 |
|------|------:|--------:|------:|------|
| Phase 0（14） | 14 | 0 | 0 | `0-1 ~ 0-14` 已收口，核心语义补齐完成 |
| Phase 1（12） | 12 | 0 | 0 | QuickJS + Bridge + 变量持久化主链路已闭环 |
| Phase 2（4） | 4 | 0 | 0 | XPath / `%%` / `{{}}` 全链路已完成并保留兼容降级 |
| Phase 3（4） | 4 | 0 | 0 | WebView 执行器 + `webView:true` 路由 + `sourceRegex` 回填已完成 |

### Phase 0 逐任务状态

| Task | 状态 | 进展与差距 |
|------|------|-----------|
| 0-1 `replaceRegex` | 已完成 | 字段/映射/正文接入 + 单条规则 200ms 超时保护 + v4 迁移均已落地 |
| 0-2 `nextTocUrl` | 已完成 | 目录翻页循环、`visited` 去重、`emptyRounds` 兜底与 `maxPages=50` 已接入 |
| 0-3 `nextContentUrl` | 已完成 | 正文翻页、下一章 URL 截断、重复内容去重与 `maxPages=30` 已接入 |
| 0-4 `&&` 合并 | 已完成 | `rule1&&rule2||rule3` 优先级与回退语义已补齐并回归通过 |
| 0-5 URL `,{options}` | 已完成 | `UrlOption` 抽象与 `method/charset/body/headers/retry` 全链路接入完成 |
| 0-6 `concurrentRate` | 已完成 | 字段映射 + `SourceRateLimiter` + `AppHttpClient.acquire` 已全链路生效 |
| 0-7 `:` AllInOne | 已完成 | `:` / `+` 前缀 AllInOne 与 `$n` 分组引用执行链路已闭环 |
| 0-8 `###` OnlyOne | 已完成 | `json_executor` 与 `legacy_link_post_processor` 均支持首命中提取 |
| 0-9 `[n:m:step]` 切片 | 已完成 | 选择器索引提取与 `HtmlExecutor` 切片执行（含负索引/排除）已落地 |
| 0-10 `<...>` 条件 URL | 已完成 | `UrlTemplateResolver` 已支持 page=1 省略、page>1 保留语义 |
| 0-11 JSONPath 高级特性 | 已完成 | `$..`、`$[?()]`、`$[n:m(:step)]` 已实现 |
| 0-12 列表 `-` 反转 | 已完成 | `SearchService` + `SearchResultParser` + `BookDetailService` 已支持 `-` 前缀；`ExploreService` 通过映射到搜索链路自动对齐 |
| 0-13 `@textNodes/@ownText` | 已完成 | Parser/Executor/Compat 三层语义已打通 |
| 0-14 元数据字段补齐 | 已完成 | `canReName` 语义已在服务层闭环，入口字段仅在规则允许时被详情覆盖（仅引擎/数据层） |

### Phase 1 逐任务状态（仅引擎/数据）

| Task | 状态 | 进展与差距 |
|------|------|-----------|
| 1-1 `flutter_js` 依赖接入 | 已完成 | 多平台工程已接入，`JsExecutor` 可正常初始化并执行 |
| 1-2 `JsExecutor` 核心封装 | 已完成 | 已具备执行、基础超时保护与失败日志，关键单测已覆盖 |
| 1-3 RuleParser/RuleEngine JS 接入 | 已完成 | `@js:` 与 `<js>...</js>` 链路已接入执行器 |
| 1-4 Bridge Tier-1 | 已完成 | `put/get/log/base64/md5/encodeURI/htmlFormat/timeFormat` 已可用 |
| 1-5 Bridge Tier-2（网络） | 已完成 | 已补齐“静态提取 + 运行时探测 + 多轮预取 + `__ajax_cache` 注入 + 动态变量 URL/Body/Headers 归一化 + 深链路多轮探测” |
| 1-6 Bridge Tier-3（AES） | 已完成 | 已补齐 transformation 兼容（`PKCS5/PKCS7/NoPadding/ZeroPadding`、`CBC/ECB`）与 hex key/iv 输入兼容，并补向量回归 |
| 1-7 Bridge Tier-4（规则回调） | 已完成 | 已补齐 `java.setContent/getString/getElements/getStringList` 深层嵌套解析与递归深度保护（含诊断日志） |
| 1-8 JS 上下文变量注入 | 已完成 | `book/chapter/source` 与 `cookie/cache` 对象均已注入 QuickJS 全局作用域（内存态） |
| 1-9 `executeAll` 异步化 | 已完成 | `RuleEngine.executeAll/executeFirst` 已异步化并完成主链路迁移 |
| 1-10 JS 能力诊断与降级 | 已完成 | `jsCapability` 分级、`js_bridge_unsupported/js_timeout_guard/js_fallback_legacy` 诊断与降级链路断言均已落地并回归通过 |
| 1-11 `jsLib` 全量注入 | 已完成 | 导入层已透传 `jsLib`，执行器在用户脚本前完成注入（失败仅记诊断，不阻塞主流程） |
| 1-12 variable 持久化 | 已完成 | 已实现 source/book 双作用域变量持久化（`_appread_js_variables` / `_appread_js_book_variables`），并在搜索→详情→正文主链路接入；chapter 级保持单次加载内存态 |

### Phase 2 逐任务状态（仅引擎/数据）

| Task | 状态 | 进展与差距 |
|------|------|-----------|
| 2-1 引入 XPath 库 | 已完成 | 已确定并接入 `xml`（direct dependency），支持 XPath 1.0 求值能力 |
| 2-2 `XPathExecutor` | 已完成 | 新增原生执行器并接入 `RuleParser/RuleEngine`，支持轴/谓词/函数，异常与空结果均保留 Legacy 降级 |
| 2-3 `%%` 交错操作符 | 已完成 | `RuleEngine` 已支持 `%%` 分段执行与 round-robin 交错输出，`LegacyRuleCompat` 已保持 `%%` 归一化语义 |
| 2-4 `{{}}` 内嵌规则完整求值 | 已完成 | `RuleEngine` 已支持 `{{@@...}}`/`{{@css:...}}`/`{{@json:...}}`/`{{@xpath:...}}` 嵌套规则求值与模板替换 |

### Phase 3 逐任务状态（仅引擎/数据）

| Task | 状态 | 进展与差距 |
|------|------|-----------|
| 3-1 引入 `flutter_inappwebview` | 已完成 | 依赖与平台插件已接入工程 |
| 3-2 `WebViewExecutor` 封装 | 已完成 | 已落地 2-worker 池化复用、串行队列、超时/异常后会话重建与可测试会话抽象 |
| 3-3 `webView:true` 路由 | 已完成 | `SearchService` / `BookDetailService` / `ChapterContentService` 均支持在请求选项标记后走 WebView 执行器 |
| 3-4 `sourceRegex` 资源嗅探 | 已完成 | `WebViewExecutor` 已采集命中资源 URL，且搜索/详情消费链路已回填 `matchedResourceUrl` 并补齐回归断言 |

### 当前测试状态（按主线阻塞级别）

| 分组 | 用例 | 失败数 | 阻塞级别 |
|------|------|------:|---------|
| 兼容主线 | `test/core/rule_engine/rule_engine_test.dart` + `test/core/rule_engine/executors/js_executor_test.dart` + `test/features/search/application/search_result_parser_test.dart` + `test/features/search/application/search_service_test.dart` + `test/features/book/application/book_detail_service_test.dart` + `test/features/reader/application/chapter_content_service_test.dart` + `test/compatibility/legacy_source_compatibility_test.dart` + `test/data/adapters/legado_source_adapter_test.dart` + `test/features/manga/application/manga_inline_js_source_test.dart` | 0 | 已通过（主线可回归） |
| 兼容主线 | `test/features/manga/application/manga_inline_js_source_test.dart` | 0 | 已通过（fixture 已补齐） |
| 兼容主线 | `test/data/adapters/legado_source_adapter_test.dart` | 0 | 已通过（含 server-proxy 降级映射） |
| UI 回归 | `test/features/discover/presentation/discover_page_test.dart` | 2 | 非阻塞（文案断言与当前界面差异） |
| UI 回归 | `test/features/book/presentation/book_detail_primary_actions_test.dart` | 2 | 非阻塞（按钮文案/图标断言差异） |

### 下一轮优先收敛项（兼容主线）

1. 继续扩充高频复杂源 fixture，覆盖更多真实书源组合语法（不改 UI）。
2. 固化并扩展兼容基线回归：`legacy_source_compatibility_test` + `source_baseline_regression_test` 常态化执行。
3. `已完成（2026-02-28）`：针对 `webView:true` 源补充跨平台稳定性回归（超时、重建、资源嗅探一致性、WebView 失败后 HTTP 回退）。
4. `已完成（2026-02-28）`：补齐高频 `java.*` 兼容别名（`connect/getElement/getCookie/toNumChapter/timeFormatUTC/t2s/s2t/strToBytes/bytesToString/createSymmetricCrypto`）并新增 no-op UI 桥接（`toast/longToast/startBrowser/startBrowserAwait/webView`），诊断能力判定与回归测试同步收敛。
5. `已完成（2026-02-28）`：补齐第二批高频桥接（`deviceID/HMacBase64/aesDecodeArgsBase64Str/initUrl/getStrResponse/toURL/toUrl/reGetBook/cacheFile/importScript/removeCookie/getVerificationCode`），并将预取识别扩展到 `cacheFile/importScript`；`3000 书源` 矩阵 `non_full` 从 `82` 降到 `75`（相对首轮 `122` 已降到 `75`）。

本轮 `webView:true` 稳定性回归补充：
- 主链路（搜索 / 详情 / 正文）均新增 “WebView 抛错 -> HTTP 回退成功” 回归用例。
- `WebViewExecutor` 增加活跃请求安全完成封装，避免重复 `complete`/`completeError` 触发 `Future already completed`。
- 诊断链路新增批量回归：`diagnoseBatch` 在 WebView 失败回退场景下保持进度统计一致且不丢主线结果。

端侧回归执行入口（Android / iOS / Desktop）：
- `scripts/run_webview_platform_regression.sh`
- `dart run tool/run_webview_platform_regression.dart`
- 集成用例：`integration_test/webview_true_platform_regression_test.dart`
- 日志与汇总输出：`build/webview_platform_regression/<timestamp>/summary.json`

常用命令：
- `./scripts/run_webview_platform_regression.sh`
- `./scripts/run_webview_platform_regression.sh --platforms=android,ios`
- `dart run tool/run_webview_platform_regression.dart --allow-missing-platforms=false`

---

## Phase 0：不依赖 JS 引擎的规则补齐（65% → 78%）

---

### Task 0-1：`replaceRegex` 正文替换规则

**depends: []**

**目标**：执行 Legado `ruleContent.replaceRegex` 字段定义的正文清洗规则（去广告、去重复标题等）。

**步骤**：

1. **SourceRuleSet 新增字段**
   - 文件：`lib/domain/entities/source_definition.dart`
   - 在 `contentDecryptRule`（第 29 行）之后新增：
     ```dart
     final String? contentReplaceRegex;
     final String? tocNextUrlRule;      // 为 Task 0-2 预留
     final String? contentNextUrlRule;  // 为 Task 0-3 预留
     ```
   - 同步更新 `copyWith()`（~第 82 行起）、`toJson()`（~第 161 行起）、`fromJson()`（~第 201 行起）。

2. **LegadoSourceAdapter 映射**
   - 文件：`lib/data/adapters/legado_source_adapter.dart`
   - 在 `contentRuleMap`（~第 30 行从 `raw.rawData['ruleContent']` 获取）的处理块中，新增：
     ```dart
     contentReplaceRegex: _pickRule(contentRuleMap, ['replaceRegex']),
     ```

3. **新增 ReplaceRegexExecutor 工具类**
   - 新建文件：`lib/core/rule_engine/processors/replace_regex_executor.dart`
   - 类签名：
     ```dart
     class ReplaceRegexExecutor {
       const ReplaceRegexExecutor();
       /// 解析并执行 replaceRegex 规则链。
       /// 格式：多条规则用 `&&` 分隔（Legado 3.0 约定），每条格式为 `regex##replacement`。
       /// replacement 为空时删除匹配。
       String execute(String content, String replaceRegex);
     }
     ```
   - 每条正则执行设 **200ms 超时**（用 `Isolate.run` + `timeout` 或 `Future.any`），超时则跳过该条并记录警告日志。

4. **ChapterContentService 接入**
   - 文件：`lib/features/reader/application/chapter_content_service.dart`
   - 在 `_cleaner.clean(extracted)` 之后（第 325 行），缓存写入之前，插入：
     ```dart
     // 执行书源定义的 replaceRegex 清洗
     if (source.rules.contentReplaceRegex != null &&
         source.rules.contentReplaceRegex!.isNotEmpty) {
       cleaned = const ReplaceRegexExecutor()
           .execute(cleaned, source.rules.contentReplaceRegex!);
     }
     ```

5. **Drift Schema 迁移**（与 0-2/0-3 合并）
   - 文件：`lib/data/datasources/local/app_database.dart`
   - `schemaVersion` 从 `3` → `4`（第 161 行）。
   - `onUpgrade` 中新增 `if (from < 4) { ... }` —— 注意：`rulesJson` 列存储的是 JSON 字符串，新字段不需要改表结构，只需要 Adapter 映射即可。如果 `contentReplaceRegex` 需要独立列（用于搜索/索引），则需 `ALTER TABLE sources ADD COLUMN content_replace_regex TEXT`。

**验收标准**：
- 导入含 `replaceRegex` 的测试源（`test_read.json` 中至少 3 条），正文无广告残留。
- 不含 `replaceRegex` 的源行为不变。
- 恶意正则（`(a+)+$` 类 ReDoS）不导致卡顿（200ms 超时兜底）。
- `flutter analyze` + `flutter test` 通过。

---

### Task 0-2：`nextTocUrl` 目录翻页

**depends: [0-1（共享 schema 迁移）]**

**目标**：支持 Legado `ruleToc.nextTocUrl` 字段，实现目录多页拼接。

**步骤**：

1. **SourceRuleSet 字段**（已在 0-1 预留 `tocNextUrlRule`）。

2. **LegadoSourceAdapter 映射**
   - 文件：`lib/data/adapters/legado_source_adapter.dart`
   - 在 `tocRuleMap` 处理块（~第 135–147 行）新增：
     ```dart
     tocNextUrlRule: _pickRule(tocRuleMap, ['nextTocUrl']),
     ```

3. **BookDetailService 加翻页循环**
   - 文件：`lib/features/book/application/book_detail_service.dart`
   - 在 `_parseChapters()` 第二次调用之后（~第 329 行），`chapters.isEmpty` 检查之前，插入翻页循环：
     ```dart
     // nextTocUrl 翻页
     if (tocRules.nextUrlRule != null && chapters.isNotEmpty) {
       var currentHtml = tocPageHtml ?? normalizedDetailHtml;
       var currentUrl = tocUrl ?? normalizedDetailUrl;
       final visitedUrls = <String>{currentUrl};
       var emptyRounds = 0;
       const maxPages = 50;

       for (var page = 0; page < maxPages; page++) {
         final nextUrl = _extractNextTocUrl(
           html: currentHtml,
           rule: tocRules.nextUrlRule!,
           baseUrl: currentUrl,
           context: context,
           variables: seedVariables,
         );
         if (nextUrl == null || nextUrl.isEmpty || visitedUrls.contains(nextUrl)) break;
         visitedUrls.add(nextUrl);

         final nextHtml = await _fetchAndNormalize(nextUrl, ...);
         final nextChapters = _parseChapters(html: nextHtml, pageUrl: nextUrl, ...);
         if (nextChapters.isEmpty) {
           emptyRounds++;
           if (emptyRounds >= 2) break;
         } else {
           emptyRounds = 0;
           chapters.addAll(nextChapters);
         }
         currentHtml = nextHtml;
         currentUrl = nextUrl;
       }
     }
     ```
   - 新增私有方法 `_extractNextTocUrl()`：对当前页 HTML 执行 `tocNextUrlRule` 规则提取 URL，然后做 `_resolveMaybeUrl()` 归一化。

4. **_TocParseRules 新增字段**
   - 在 `_TocParseRules` 类（~第 2186 行）新增 `final String? nextUrlRule;`，以及对应的 raw 字段。

**验收标准**：
- 分页目录源（测试集中含 `nextTocUrl` 的源）拿到完整章节列表（对比 Legado 客户端章节数）。
- 单页目录源行为不变。
- 死循环 URL（A→B→A）在 2 轮内退出。
- 超过 50 页硬上限自动停止。

---

### Task 0-3：`nextContentUrl` 正文翻页

**depends: [0-1（共享 schema 迁移）]**

**目标**：支持 Legado `ruleContent.nextContentUrl` 字段，实现正文多页拼接。

**步骤**：

1. **SourceRuleSet 字段**（已在 0-1 预留 `contentNextUrlRule`）。

2. **LegadoSourceAdapter 映射**
   - 在 `contentRuleMap` 处理块（~第 148–152 行）新增：
     ```dart
     contentNextUrlRule: _pickRule(contentRuleMap, ['nextContentUrl']),
     ```

3. **ChapterContentService 加翻页循环**
   - 文件：`lib/features/reader/application/chapter_content_service.dart`
   - 在内容提取 + `_cleaner.clean()` + `replaceRegex` 之后，缓存写入之前，插入：
     ```dart
     // nextContentUrl 翻页拼接
     if (source.rules.contentNextUrlRule != null) {
       var currentHtml = responseBody;
       var currentUrl = resolvedChapterUrl;
       final visitedUrls = <String>{currentUrl};
       final contentParts = <String>[cleaned];
       const maxPages = 30;

       for (var page = 0; page < maxPages; page++) {
         final nextUrl = _extractNextContentUrl(
           html: currentHtml,
           rule: source.rules.contentNextUrlRule!,
           baseUrl: currentUrl,
           ...
         );
         if (nextUrl == null || nextUrl.isEmpty || visitedUrls.contains(nextUrl)) break;
         // 检查 nextUrl 是否等于下一章 URL（防止跨章）
         if (_isNextChapterUrl(nextUrl, chapterIndex, chapters)) break;
         visitedUrls.add(nextUrl);

         final nextResponse = await _fetchPage(nextUrl, ...);
         final nextContent = _extractAndClean(nextResponse, ...);
         if (nextContent.isEmpty) break;
         // 内容 hash 去重（防尾部重复）
         if (_isDuplicateContent(contentParts.last, nextContent)) break;
         contentParts.add(nextContent);
         currentHtml = nextResponse;
         currentUrl = nextUrl;
       }
       cleaned = contentParts.join('\n\n');
     }
     ```
   - 新增 `_extractNextContentUrl()` / `_isDuplicateContent()` / `_isNextChapterUrl()` 私有方法。

**验收标准**：
- 分页正文源显示完整章节内容。
- 尾部无重复段落。
- 翻页 URL 等于下一章 URL 时自动停止。
- 30 页硬上限。

---

### Task 0-4：`&&` 合并操作符

**depends: []**

**目标**：支持 Legado `&&` 操作符，将多条同类型规则结果合并。

**步骤**：

1. **RuleEngine.executeAll() 增加 `&&` 分割逻辑**
   - 文件：`lib/core/rule_engine/rule_engine.dart`
   - 在 `executeAll()` 方法（第 23 行）的 `_parser.parse(expression)` 调用之前，新增：
     ```dart
     // 处理 && 合并操作符
     if (expression.contains('&&')) {
       final parts = _splitByOperator(expression, '&&');
       if (parts.length > 1) {
         final results = <String>[];
         for (final part in parts) {
           results.addAll(executeAll(content: content, expression: part.trim(), stage: stage));
         }
         return results;
       }
     }
     ```
   - 新增 `_splitByOperator()` 私有方法（注意不能在引号内/`<js>` 块内切割）。

2. **确保 `||` 回退逻辑不受影响**
   - 检查现有 `||` 分割逻辑是否在 `&&` 之前执行（`||` 优先级低于 `&&`）。
   - 正确的处理顺序：先按 `||` 分割为候选组 → 每组内按 `&&` 分割为子规则 → 子规则结果合并 → 第一个非空候选组胜出。

**验收标准**：
- `class.a@text&&class.b@text` 返回两条规则的合并结果。
- `rule1&&rule2||rule3` 先尝试 `rule1&&rule2`，为空时回退 `rule3`。
- 现有 `||` 测试用例不回归。

---

### Task 0-5：URL `,{options}` 完整解析

**depends: []**

**目标**：完整解析 Legado URL 尾部的 `method`/`charset`/`body`/`headers`/`retry` 字段。

**步骤**：

1. **新增 UrlOption 数据类**
   - 新建文件：`lib/core/network/url_option.dart`
   - 字段：`method` / `charset` / `headers` / `body` / `type` / `retry` / `webView`（暂存不执行）。

2. **扩展 LegacyLinkPostProcessor**
   - 文件：`lib/core/rule_engine/processors/legacy_link_post_processor.dart`
   - 在 `_splitRequestOptions()`（~第 257 行）中，将拆分出的 JSON 对象解析为 `UrlOption`，而不是仅提取 body。

3. **RequestContext 接入**
   - 文件：`lib/core/network/request_context.dart`
   - `RequestContext` 新增 `responseCharset`（已有）确认可从 `UrlOption.charset` 赋值。
   - `retry` 字段映射到 `RequestContext.maxRetries`。

4. **调用方适配**
   - 所有构建 `RequestContext` 的调用点（`BookDetailService._fetchHtml()`、`ChapterContentService` 等），传入从 URL 解析出的 `UrlOption` 字段。

**验收标准**：
- URL `https://xxx.com,{"method":"POST","body":"key=val","charset":"gbk"}` 正确发送 POST + GBK 解码。
- 无 `,{options}` 的 URL 行为不变。

---

### Task 0-6：`concurrentRate` 基础限流

**depends: []**

**目标**：遵守源定义的请求频率限制，避免被封 IP。

**步骤**：

1. **SourceDefinition 新增字段**
   - 文件：`lib/domain/entities/source_definition.dart`
   - `SourceDefinition` 类（~第 276 行）新增 `final String? concurrentRate;`
   - 同步更新 `copyWith` / `toJson` / `fromJson`。

2. **LegadoSourceAdapter 映射**
   - 从 `raw.rawData['concurrentRate']` 读取。

3. **新增 SourceRateLimiter**
   - 新建文件：`lib/core/network/source_rate_limiter.dart`
   - 解析格式 `"次数/毫秒数"`（如 `"1/1000"` = 每 1000ms 允许 1 次请求）。
   - 内部维护 `Map<String, _TokenBucket>` per-source 令牌桶。
   - 公开方法 `Future<void> acquire(String sourceId)` — 无 `concurrentRate` 的源立即返回。

4. **AppHttpClient 接入**
   - 文件：`lib/core/network/http_client.dart`
   - 在发起请求前 `await rateLimiter.acquire(context.sourceId)`。

**验收标准**：
- 设置 `concurrentRate: "1/2000"` 的源，连续 3 次请求间隔 ≥ 2 秒。
- 无 `concurrentRate` 的源无额外延迟。

---

### Task 0-7：`:` AllInOne 正则模式

**depends: []**

**目标**：支持 Legado 以 `:` 开头的 AllInOne 正则规则（用于搜索列表、目录列表等）。

**步骤**：

1. **RuleParser 识别 `:` 前缀**
   - 文件：`lib/core/rule_engine/rule_parser.dart`
   - 在 `parse()` 方法（第 62 行），`regex:` 判断之前，新增对以 `:` 开头（且非 `://`）的识别：
     ```dart
     if (expression.startsWith(':') && !expression.startsWith('://')) {
       return _parseAllInOneRegexRule(expression.substring(1));
     }
     ```
   - AllInOne 模式返回整个正则匹配的所有捕获组，供后续字段规则通过 `$1`/`$2` 引用。

2. **新增 ParsedAllInOneRegexRule**
   - 在 `rule_parser.dart` 的 sealed class 层级中新增子类。

3. **RuleEngine dispatch**
   - 在 `executeAll()` 中新增 `is ParsedAllInOneRegexRule` 分支。

**验收标准**：
- `:bookSourceUrl(.+?)\n` 类规则能正确提取捕获组。
- 后续字段规则中 `$1` 能引用到对应捕获组值。

---

### Task 0-8：`##regex##replacement###` OnlyOne 模式

**depends: []**

**目标**：支持三重 `###` 终止符的 OnlyOne 正则（只返回第一个匹配）。

**步骤**：

1. **在 `##` 替换逻辑中检测 `###` 终止符**
   - 涉及文件：`json_executor.dart`（~第 136 行）、`legacy_link_post_processor.dart`（~第 76 行）。
   - 当检测到 `###` 终止时，正则只取 `firstMatch` 而非全局替换。

**验收标准**：
- `##:author"[^"]+\"([^"]*)##$1###` 只返回第一个匹配的作者名。

---

### Task 0-9：JSoup `[n:m:step]` 索引切片执行

**depends: []**

**目标**：当前 `LegacyRuleCompat._stripLegacySelectorDecorations()` 直接 strip 了 `[n:m]` 语法，导致索引过滤失效。

**步骤**：

1. **修改 `_stripLegacySelectorDecorations()`**
   - 文件：`lib/core/rule_engine/processors/legacy_rule_compat.dart`（~第 290 行）
   - 不再 strip `[n:m:step]`，而是提取索引信息并传递给 `HtmlExecutor`。

2. **HtmlExecutor 在 querySelector 结果上应用索引过滤**
   - 文件：`lib/core/rule_engine/executors/html_executor.dart`
   - 在 `querySelectorAll()` 返回结果后，按 `[start:end:step]` 切片。
   - 支持负数索引（`[-1]` = 最后一个，`[-3:-1]` = 倒数第三到倒数第一）。
   - 支持步长（`[::2]` = 每隔一个取一个）。
   - 支持 `[!n:m]` 排除模式。

**验收标准**：
- `tag.div[0:3]` 只返回前 3 个 div。
- `tag.div[-1]` 返回最后一个 div。
- `tag.div[!0]` 排除第一个 div。

---

### Task 0-10：`<,{{page}}>` 条件分段 URL

**depends: []**

**目标**：Legado 中 `<...>` 语法表示"当 page=1 时省略该段"。

**步骤**：

1. **UrlTemplateResolver 扩展**
   - 文件：`lib/core/rule_engine/processors/url_template_resolver.dart`
   - 在变量替换之前，检测 `<...>` 分段。
   - 当 `page == 1` 时，移除 `<...>` 包裹的整段（含分隔符）。
   - 当 `page > 1` 时，保留内容但移除 `<` 和 `>`。

**验收标准**：
- `https://xxx.com/search<&page={{page}}>` 在 page=1 时变为 `https://xxx.com/search`。
- page=2 时变为 `https://xxx.com/search&page=2`。

---

## Phase 1：QuickJS 引擎接入（78% → 90%）

---

### Task 1-1：引入 `flutter_js` 依赖

**depends: [Phase 0 全部完成]**

**目标**：添加 QuickJS JS 引擎依赖，各平台验证可启动。

**步骤**：

1. `pubspec.yaml` 添加：
   ```yaml
   flutter_js: ^0.8.0  # 或最新稳定版
   ```
2. 运行 `flutter pub get`。
3. 在各平台（Android/iOS/macOS）运行 `flutter run`，确认无原生编译错误。
4. 编写最简单的冒烟测试：
   ```dart
   test('QuickJS smoke test', () {
     final runtime = getJavascriptRuntime();
     final result = runtime.evaluate('1 + 1');
     expect(result.stringResult, '2');
     runtime.dispose();
   });
   ```

**验收标准**：
- `flutter pub get` 成功。
- Android/iOS/macOS 均可启动。
- 冒烟测试通过。

---

### Task 1-2：JsExecutor 核心封装

**depends: [1-1]**

**目标**：封装 JS 执行器，支持 Isolate 隔离、超时熔断、结果类型转换。

**步骤**：

1. **新建文件：`lib/core/rule_engine/executors/js_executor.dart`**
2. **类签名**：
   ```dart
   class JsExecutor {
     JsExecutor();

     /// 在隔离环境中执行 JS 代码。
     /// [script] 为 JS 代码字符串。
     /// [context] 包含 result/baseUrl/book/chapter 等注入变量。
     /// 返回执行结果字符串，超时或异常返回 null。
     Future<String?> execute({
       required String script,
       required JsExecutionContext context,
       Duration timeout = const Duration(seconds: 3),
     });

     /// 释放资源。
     void dispose();
   }
   ```
3. **JsExecutionContext 数据类**：
   ```dart
   class JsExecutionContext {
     final String? result;       // 前段规则结果
     final String? baseUrl;      // 当前页面 URL
     final String? sourceId;     // 当前书源 ID
     final Map<String, String> variables;  // @put/@get 变量
     // book/chapter 后续 Task 扩展
   }
   ```
4. **Isolate 隔离执行**：
   - 使用 `Isolate.run()` 或 `compute()` 在独立 Isolate 中创建 QuickJS Runtime。
   - 注入 `result`/`baseUrl` 到 JS 全局变量。
   - 执行 script 并获取结果。
   - 用 `Future.any([执行Future, Future.delayed(timeout)])` 实现超时。
   - 超时时 kill Isolate 并返回 null。

5. **错误处理**：
   - JS 执行异常 → 记录日志 → 返回 null（不抛出）。
   - 调用方拿到 null 后可降级到 `LegacyScriptRuleFallback`。

**验收标准**：
- `execute(script: '1+1', context: ...)` 返回 `'2'`。
- `execute(script: 'result.replace("a","b")', context: JsExecutionContext(result: 'abc'))` 返回 `'bbc'`。
- `execute(script: 'while(true){}', ...)` 在 3 秒内返回 null，不卡主线程。
- 内存泄漏测试：连续执行 100 次后内存不持续增长。

---

### Task 1-3：RuleParser + RuleEngine 接入 JsExecutor

**depends: [1-2]**

**目标**：`@js:` 和 `<js>` 规则走 JsExecutor 执行，失败降级到模式匹配。

**步骤**：

1. **新增 ParsedJsRule**
   - 文件：`lib/core/rule_engine/rule_parser.dart`
   - 在 sealed class 层级新增：
     ```dart
     class ParsedJsRule extends ParsedRule {
       const ParsedJsRule({required this.script, this.precedingRule});
       final String script;
       final String? precedingRule;  // @js: 前的规则（如 css@text@js:xxx）
     }
     ```

2. **RuleParser.parse() 识别**
   - 在 `parse()` 中新增 `@js:` / `js:` 前缀识别。
   - 对于 `rule@js:script` 格式，拆分为 `precedingRule=rule` + `script=script`。

3. **RuleEngine 接入**
   - 文件：`lib/core/rule_engine/rule_engine.dart`
   - 构造函数新增 `JsExecutor? jsExecutor` 参数。
   - `executeAll()` 中新增 `is ParsedJsRule` 分支：
     ```dart
     if (parsed is ParsedJsRule) {
       // 如果有 precedingRule，先执行前段规则
       String? precedingResult;
       if (parsed.precedingRule != null) {
         final preceding = executeAll(content: content, expression: parsed.precedingRule!, stage: stage);
         precedingResult = preceding.isNotEmpty ? preceding.first : null;
       }
       // 执行 JS
       final jsResult = await _jsExecutor?.execute(
         script: parsed.script,
         context: JsExecutionContext(result: precedingResult ?? content, baseUrl: ...),
       );
       if (jsResult != null) return [jsResult];
       // 降级到模式匹配
       final fallback = LegacyScriptRuleFallback.evaluateFieldValue(
         content: precedingResult ?? content, rawRule: '@js:${parsed.script}');
       return fallback != null ? [fallback] : const [];
     }
     ```
   - **注意**：`executeAll()` 目前是同步方法（返回 `List<String>`），接入 JS 后需要改为 `Future<List<String>>`。这是一个**破坏性变更**，需要同时更新所有调用方。

4. **`<js>` 中间分隔支持**
   - 对于 `cssRule<js>code</js>xpathRule` 格式：
     - 按 `<js>...</js>` 切割为 3 段。
     - 第 1 段走原规则引擎 → result。
     - 第 2 段（JS）以 result 为输入执行 → newResult。
     - 第 3 段以 newResult 为输入走原规则引擎 → 最终结果。

**验收标准**：
- `@js:result.replace(/广告/g, '')` 正确执行。
- `class.content@text@js:result.trim()` 先提取文本再 trim。
- `@js:while(true){}` 超时后降级到模式匹配（返回 null 不崩溃）。
- **所有现有测试不回归**（调用方异步化后）。

---

### Task 1-4：Bridge Tier-1 — 变量与编解码

**depends: [1-2]**

**目标**：在 QuickJS 中注入纯计算类 `java.*` 函数。

**步骤**：

1. **新建 Bridge 注入模块**
   - 新建文件：`lib/core/rule_engine/js_bridge/bridge_tier1.dart`
   - 在 QuickJS Runtime 中注入以下函数（通过 `runtime.evaluate()` 注册全局对象）：

   ```javascript
   var java = {
     put: function(key, value) { /* 桥接到 Dart RuleExecutionContext.variables */ },
     get: function(key) { /* 桥接到 Dart RuleExecutionContext.variables */ },
     log: function(msg) { /* 桥接到 Dart Logger */ },
     base64Decode: function(str) { /* Dart: utf8.decode(base64.decode(str)) */ },
     base64Encode: function(str) { /* Dart: base64.encode(utf8.encode(str)) */ },
     md5Encode: function(str) { /* Dart: md5.convert(utf8.encode(str)).toString() */ },
     md5Encode16: function(str) { /* Dart: md5Encode(str).substring(8, 24) */ },
     encodeURI: function(str, enc) { /* Dart: Uri.encodeComponent(str) */ },
     htmlFormat: function(str) { /* Dart: 去 HTML 标签 + 实体解码 */ },
     timeFormat: function(ts) { /* Dart: DateTime → format */ },
   };
   ```

2. **Dart ↔ JS 通信机制**
   - `flutter_js` 的 `sendMessage()` / `onMessage()` 或直接在 evaluate 前注入 Dart 计算结果。
   - 对于纯计算函数，可以在 JS 侧用 Dart 预计算结果注入：
     ```dart
     // 在执行用户脚本之前，注入预计算的桥接实现
     runtime.evaluate('''
       var __bridge_vars = ${jsonEncode(context.variables)};
       var java = {
         put: function(k, v) { __bridge_vars[k] = v; },
         get: function(k) { return __bridge_vars[k] || ''; },
         base64Decode: function(s) { return __dart_base64Decode(s); },
         ...
       };
     ''');
     ```
   - 纯计算函数（base64/md5/encodeURI）需要注册为 Dart callback。`flutter_js` 支持 `runtime.onMessage('channelName', callback)` 模式。

3. **pubspec.yaml 新增依赖**（如需要）：
   - `crypto: ^3.0.0`（用于 md5，检查是否已间接依赖）。

**验收标准**：
- `java.base64Decode('aGVsbG8=')` 返回 `'hello'`。
- `java.md5Encode('test')` 返回正确的 32 位 MD5。
- `java.put('key', 'val'); java.get('key')` 返回 `'val'`。
- `java.encodeURI('中文')` 返回正确编码。

---

### Task 1-5：Bridge Tier-2 — 网络请求

**depends: [1-2, 1-4]**

**目标**：在 QuickJS 中注入 `java.ajax` / `java.get` / `java.post` 网络请求函数。

**关键难点**：QuickJS 是同步执行的，但 Dart Dio 请求是异步的。

**步骤**：

1. **设计同步桥接方案**
   - 方案 A（推荐）：**预执行 + 二次注入**
     - 第一遍扫描 JS 脚本，提取所有 `java.ajax(url)` 调用的 URL。
     - 在 Dart 侧批量异步请求所有 URL。
     - 将结果注入 JS 上下文为缓存 Map：`__ajax_cache[url] = responseBody`。
     - 第二遍执行 JS，`java.ajax(url)` 从缓存读取。
   - 方案 B：使用 `flutter_js` 的 `dartToJsChannel` 实现同步回调（需要验证 `flutter_js` 是否支持同步阻塞回调）。

2. **实现**
   - 新建文件：`lib/core/rule_engine/js_bridge/bridge_tier2_network.dart`
   - 注入函数：
     ```javascript
     java.ajax = function(url) { return __ajax_cache[url] || ''; };
     java.ajaxAll = function(urls) { return urls.map(u => __ajax_cache[u] || ''); };
     ```
   - Dart 侧预请求：
     ```dart
     final urls = _extractAjaxUrls(script);
     final cache = <String, String>{};
     await Future.wait(urls.map((url) async {
       try {
         final resp = await _httpClient.get(RequestContext(url: url, timeout: 15s, ...));
         cache[url] = resp.body;
       } catch (_) { cache[url] = ''; }
     }));
     runtime.evaluate('var __ajax_cache = ${jsonEncode(cache)};');
     ```

3. **安全约束**
   - 单次 JS 执行最多允许 5 个 `java.ajax` 调用。
   - 每次请求 15s 超时。
   - 可选：域名白名单（仅允许同源 + 常见 CDN）。

**验收标准**：
- `java.ajax('https://httpbin.org/get')` 返回有效 JSON 字符串。
- 超过 5 个 ajax 调用时，第 6 个返回空字符串。
- 请求超时 15s 后返回空字符串，不阻塞 JS 执行。

---

### Task 1-6：Bridge Tier-3 — AES 加解密

**depends: [1-2, 1-4]**

**目标**：注入 8 个 AES 加解密函数。

**步骤**：

1. **新建文件：`lib/core/rule_engine/js_bridge/bridge_tier3_crypto.dart`**

2. **桥接到 pointycastle**
   - 项目已依赖 `pointycastle: ^3.9.1`。
   - 已有 `SourceResponseProcessor._decryptAesCbcPkcs7Body()` 可复用逻辑。
   - 将现有解密逻辑抽取为通用工具函数，JS Bridge 和 SourceResponseProcessor 共用。

3. **注入 8 个函数**
   - 同 Tier-1，通过 `dartToJsChannel` 或预计算注入。
   - 参数映射：`transformation` 字符串（如 `"AES/CBC/PKCS7Padding"`）→ pointycastle 参数。

**验收标准**：
- `java.aesDecodeToString(encrypted, key, 'AES/CBC/PKCS7Padding', iv)` 返回正确明文。
- `java.aesEncodeToBase64String(plain, key, 'AES/CBC/PKCS7Padding', iv)` 返回正确密文。

---

### Task 1-7：Bridge Tier-4 — 规则解析回调

**depends: [1-3, 1-4]**

**目标**：注入 `java.setContent` / `java.getString` / `java.getElements` / `java.getStringList`。

**关键难点**：JS → Dart → RuleEngine → 可能再触发 JS，存在递归风险。

**步骤**：

1. **新建文件：`lib/core/rule_engine/js_bridge/bridge_tier4_rule.dart`**

2. **实现**
   - `java.setContent(content, baseUrl)` → 在 Dart 侧缓存当前解析内容和 baseUrl。
   - `java.getString(rule)` → 桥接到 `RuleEngine.executeFirst(content, rule)`。
   - `java.getStringList(rule)` → 桥接到 `RuleEngine.executeAll(content, rule)`。
   - `java.getElements(rule)` → 桥接到 `RuleEngine.executeAll(content, rule)` 返回 HTML 片段列表。

3. **递归深度限制**
   - 维护 `_recursionDepth` 计数器。
   - 每次 JS → Dart 回调时 depth++，返回时 depth--。
   - depth > 3 时直接返回空结果。

**验收标准**：
- `java.getString('@css:div.title@text')` 返回对应元素文本。
- 递归深度 > 3 时安全返回空值不崩溃。

---

### Task 1-8：JS 上下文变量注入（book / chapter / source）

**depends: [1-2]**

**目标**：在 JS 全局作用域注入 `book`/`chapter`/`source` 对象。

**步骤**：

1. **扩展 JsExecutionContext**
   - 新增 `Map<String, dynamic>? bookJson`、`Map<String, dynamic>? chapterJson`、`Map<String, dynamic>? sourceJson`。

2. **注入到 QuickJS**
   ```dart
   if (context.bookJson != null) {
     runtime.evaluate('var book = ${jsonEncode(context.bookJson)};');
   }
   if (context.chapterJson != null) {
     runtime.evaluate('var chapter = ${jsonEncode(context.chapterJson)};');
   }
   if (context.sourceJson != null) {
     runtime.evaluate('var source = ${jsonEncode(context.sourceJson)};');
   }
   ```

3. **调用方传入**
   - `BookDetailService` / `ChapterContentService` / `SearchService` 在构建 `JsExecutionContext` 时填充 book/chapter/source 数据。

**验收标准**：
- `@js:book.name` 返回当前书名。
- `@js:chapter.url` 返回当前章节 URL。
- `@js:source.bookSourceUrl` 返回源 URL。

---

### Task 1-9：executeAll 异步化改造

**depends: [1-3]**

**目标**：将 `RuleEngine.executeAll()` 从同步改为异步，因为 JS 执行需要 async。

**关键注意**：这是一个**影响面最大的变更**，所有调用 `executeAll()` / `executeFirst()` 的地方都需要改为 `await`。

**步骤**：

1. **RuleEngine 方法签名变更**
   ```dart
   // Before
   List<String> executeAll({...})
   String executeFirst({...})
   // After
   Future<List<String>> executeAll({...})
   Future<String> executeFirst({...})
   ```

2. **逐文件更新调用方**（用 `grep -r 'executeAll\|executeFirst' lib/` 找到所有调用点）：
   - `BookDetailService`
   - `ChapterContentService`
   - `SearchService` / `ExploreService`
   - 所有测试文件

3. **非 JS 路径保持高效**
   - 对于 HTML/JSON/Regex 规则，虽然方法签名是 async，但内部仍是同步计算，用 `Future.value()` 包装即可，不引入额外开销。

**验收标准**：
- 所有现有测试通过（异步化后行为不变）。
- `flutter analyze` 无异步相关 warning。

---

### Task 1-10：JS 兼容能力探测与诊断标记（非 UI）

**depends: [1-1]**

**目标**：对 JS 依赖等级与执行失败原因形成结构化诊断，供引擎侧决策与回归定位使用。

**当前进展（2026-02-27）**：
- [x] 导入层 `jsCapability` 分级覆盖已实装/未知/不支持桥接能力。
- [x] 执行链路诊断码已补齐：`js_bridge_unsupported`、`js_timeout_guard`、`js_fallback_legacy`。
- [x] 兼容回归已补断言并通过：失败路径可定位、降级路径可验证。

**步骤**：

1. **源级能力探测**
   - 文件：`lib/data/adapters/legado_source_adapter.dart`
   - 导入书源时基于规则内容标记 `jsCapability`：
     - `full`：仅依赖已实装 Bridge 能力。
     - `partial`：包含可降级能力或高风险能力。
     - `unsupported`：依赖明确未实装能力（如 `Packages.java.xxx`、文件操作）。

2. **执行链路诊断码落盘**
   - 文件：`lib/core/rule_engine/rule_engine.dart`、`lib/core/rule_engine/executors/js_executor.dart`
   - JS 执行失败/超时/降级时记录标准诊断码（如 `js_timeout`、`js_bridge_unsupported`、`js_fallback_legacy`）。
   - 诊断信息写入日志与调试态状态对象，禁止直接耦合 UI 展示逻辑。

3. **兼容回归断言补充**
   - 文件：`test/compatibility/legacy_source_compatibility_test.dart`
   - 对典型 JS 源增加断言：触发降级时必须有对应诊断码，且结果满足预期兜底行为。

**验收标准**：
- 导入后每个源都有稳定 `jsCapability` 分级结果。
- JS 失败路径能稳定产出诊断码，回归测试可断言。
- 兼容主线不依赖任何 UI 提示实现。

---

## Phase 2：XPath 原生支持 + 操作符补全（90% → 92%）

---

### Task 2-1：引入 XPath 库

**depends: [Phase 1]**

**当前进展（2026-02-27）**：
- [x] 已选定 `xml` 方案并升级为 direct dependency。
- [x] 已完成冒烟验证并接入主回归链路。

**步骤**：
1. 评估 `xpath_selector_html_parser` 或 `xml` 包。
2. pubspec.yaml 添加依赖。
3. 冒烟测试。

---

### Task 2-2：XPathExecutor

**depends: [2-1]**

**当前进展（2026-02-27）**：
- [x] 已新增 `lib/core/rule_engine/executors/xpath_executor.dart`。
- [x] 已接入 `RuleParser + RuleEngine`，支持 `xpath:` / `@xpath:` / 裸 XPath。
- [x] 已支持轴/谓词/函数，并保留 `LegacyXPathCompat` 作为失败与空结果降级。

**步骤**：
1. 新建 `lib/core/rule_engine/executors/xpath_executor.dart`。
2. 接口与 HtmlExecutor 对齐：`List<String> execute({content, rule, stage})`。
3. 支持完整 XPath 1.0 子集（轴、谓词、函数）。
4. RuleParser + RuleEngine 注册。
5. 保留 `LegacyXPathCompat` 作为降级。

---

### Task 2-3：`%%` 交错操作符

**depends: []**

**当前进展（2026-02-27）**：
- [x] `RuleEngine.executeAll()` 已支持按 `%%` 分段执行并 round-robin 交错合并结果。
- [x] 已补充 `RuleEngine` 回归测试覆盖不等长列表交错场景。
- [x] `LegacyRuleCompat.buildHtmlRuleExpression()` 已支持保留 `%%` 归一化语义。

**步骤**：
1. RuleEngine.executeAll() 中按 `%%` 分割。
2. 多列表轮询取值（round-robin）。

---

### Task 2-4：`{{}}` 内嵌规则完整求值

**depends: [1-3]**

**当前进展（2026-02-27）**：
- [x] `RuleEngine` 模板解析已识别 `{{@@...}}` / `{{@css:...}}` / `{{@json:...}}` / `{{@xpath:...}}`。
- [x] 已通过递归调用 RuleEngine 执行内嵌规则并替换回模板文本。
- [x] 已补充 `RuleEngine` 回归测试覆盖 `{{@@...}}` 与 `{{@json:...}}`。

**步骤**：
1. 在模板解析中识别 `{{@@rule}}`/`{{@css:rule}}`/`{{@json:rule}}`。
2. 调用 RuleEngine 执行内嵌规则。
3. 将结果替换回模板。

---

## Phase 3：WebView 层（92% → 95%，可选）

---

### Task 3-1：引入 flutter_inappwebview

**depends: [Phase 2]**

1. pubspec.yaml 添加 `flutter_inappwebview: ^6.x`。
2. Android/iOS 权限配置。

---

### Task 3-2：WebViewExecutor 封装

**depends: [3-1]**

1. 隐藏 WebView 池（2 个实例复用）。
2. 加载 URL → 等 `onLoadStop` → 提取 `document.body.innerHTML`。
3. 支持 `webJs` 字段执行。
4. 30s 超时。

---

### Task 3-3：URL webView 参数路由

**depends: [3-2, 0-5]**

1. UrlOption 中 `webView != null` 时路由到 WebViewExecutor。

---

### Task 3-4：sourceRegex 资源嗅探

**depends: [3-2]**

**当前进展（2026-02-27）**：
- [x] WebView 层已拦截 `sourceRegex` 命中资源 URL。
- [x] 搜索/详情请求消费链路已回填 `matchedResourceUrl`。
- [x] 回归测试已覆盖搜索与详情路径。

1. 在 WebView 加载过程中拦截匹配 `sourceRegex` 的资源 URL。
2. 将匹配的 URL 作为 content 规则的 `result`。

---

## 依赖关系总览

```
Phase 0 (可并行):
  0-1 ─┬─ 0-2
       └─ 0-3
  0-4 (独立)
  0-5 (独立)
  0-6 (独立)
  0-7 (独立)
  0-8 (独立)
  0-9 (独立)
  0-10 (独立)

Phase 1 (串行为主):
  1-1 → 1-2 → 1-3 → 1-7
              ↓
             1-4 → 1-5
              ↓
             1-6
  1-8 (依赖 1-2)
  1-9 (依赖 1-3，影响面最大)
  1-10 (依赖 1-1)

Phase 2:
  2-1 → 2-2
  2-3 (独立)
  2-4 (依赖 1-3)

Phase 3:
  3-1 → 3-2 → 3-3
              → 3-4
```

---

## 终版检查补遗（2026-02-27）

> 以下为逐项比对 Legado 官方规范后发现的遗漏，按影响分为"补入计划"与"明确排除"。

### 补入 Phase 0 的遗漏

| 编号 | 遗漏项 | 说明 | 归入任务 |
|------|--------|------|----------|
| GAP-1 | **JSONPath `$..` 递归下降** | 当前 JsonExecutor 仅支持单层 `$.field`，不支持 `$..books[*]` 递归搜索。在野源中有使用。 | **新增 Task 0-11** |
| GAP-2 | **JSONPath `$[?(@.field)]` 过滤表达式** | 条件过滤，如 `$[?(@.type==1)]`。当前完全不支持。 | **合并到 Task 0-11** |
| GAP-3 | **JSONPath `$[start:end]` 数组切片** | 如 `$[0:10]`。当前仅支持 `$[n]` 单索引。 | **合并到 Task 0-11** |
| GAP-4 | **`chapterList` / `bookList` 的 `-` 前缀反转** | Legado 规范：列表规则前加 `-` 反转结果。当前 `tocReversed` 仅从布尔字段读取，未解析规则本身的 `-` 前缀。 | **新增 Task 0-12** |
| GAP-5 | **`+` 前缀 AllInOne 模式** | 搜索列表/发现列表/目录列表规则前加 `+` 启用 AllInOne 正则模式（和 Task 0-7 的 `:` 前缀联动）。 | **合并到 Task 0-7** |
| GAP-6 | **`@textNodes` 提取器语义丢失** | 当前归一化为 `text`，但 Legado 中 `textNodes` 仅提取直接文本节点（不含子元素文本）。 | **新增 Task 0-13** |
| GAP-7 | **`@ownText` 提取器** | 与 `@textNodes` 类似，仅提取元素自身文本。当前未识别。 | **合并到 Task 0-13** |

### 补入 Phase 1 的遗漏

| 编号 | 遗漏项 | 说明 | 归入任务 |
|------|--------|------|----------|
| GAP-8 | **JS 上下文缺少 `cookie` / `cache` 变量** | Task 1-8 仅列了 `book`/`chapter`/`source`，遗漏了 `cookie`（CookieStore）和 `cache`（CacheManager）。 | **补入 Task 1-8** |
| GAP-9 | **`java.base64Decode(str, flags)` 带 flags 变体** | Task 1-4 仅列了无参版本。Legado 支持带 `flags: Int` 的重载（如 `NO_WRAP`/`URL_SAFE`）。 | **补入 Task 1-4** |
| GAP-10 | **`java.base64DecodeToByteArray` 系列** | 返回 ByteArray 的变体函数。部分加密源使用。 | **补入 Task 1-4** |
| GAP-11 | **`jsLib` 字段完整支持** | 当前仅从 `jsLib` 提取 API base URL 和 LZ helper 检测。Legado 中 `jsLib` 是全局 JS 库代码，应在 QuickJS 执行前注入。 | **新增 Task 1-11** |
| GAP-12 | **`source.variable` / `book.variable` / `chapter.variable` 持久化** | Legado 支持 per-source/book/chapter 的自定义变量，由 JS 通过 `java.put`/`java.get` 读写并持久化。当前 `@put/@get` 仅内存态。 | **新增 Task 1-12** |

### 补入 Phase 0 的源字段遗漏

| 编号 | 遗漏项 | 说明 | 归入任务 |
|------|--------|------|----------|
| GAP-13 | **`ruleBookInfo.kind` / `wordCount` / `lastChapter`** | 领域模型缺少分类、字数、最新章节元数据提取，导致合并/持久化信息不完整。 | **新增 Task 0-14** |
| GAP-14 | **`ruleBookInfo.canReName`** | 控制是否用详情链路拿到的书名/作者覆盖入口链路结果。 | **合并到 Task 0-14** |
| GAP-15 | **`ruleToc.isVip` / `updateTime`** | 章节元数据缺少 VIP 与更新时间语义，影响目录数据完整性与下游规则判断。 | **合并到 Task 0-14** |
| GAP-16 | **`ruleSearch.kind` / `wordCount`** | 搜索链路缺少分类与字数字段提取，影响结果合并与排序策略。 | **合并到 Task 0-14** |

### 明确排除（不纳入计划）

| 遗漏项 | 排除原因 |
|--------|----------|
| `loginUrl` / `loginUi` / `loginCheckJs` | 登录体系完整实装成本极高，在野需登录源占比 <5%，MVP 不覆盖 |
| `java.readFile` / `deleteFile` / 文件操作系列 | 安全风险高，在野使用率 <1% |
| `java.queryTTF` / `replaceFont` 字体反爬 | 实装成本极高（需 TTF 解析库），在野使用率 <2% |
| `java.downloadFile` / `unzipFile` / `getTxtInFolder` | 极低频，安全风险 |
| `Packages.java.xxx` Java 类导入 | Rhino 特有能力，QuickJS 无法复制 |
| `bookUrlPattern` | URL 匹配路由，影响极小 |
| `weight` / `customOrder` | UI 排序字段，不影响规则执行 |
| `headers` 中的 `proxy` 支持 | 代理功能需额外网络层改造，MVP 不覆盖 |
| `ruleContent.payAction` | 付费内容处理，需完整登录体系支撑 |
| `ruleContent.imageStyle` | 漫画已有独立图片处理，该字段影响极小 |
| `{}` 旧版 JSONPath 简写（Legado 2.0） | 已废弃语法，新源不使用 |

---

### 补充任务详情

#### Task 0-11：JSONPath 高级特性（`$..` 递归 / `$[?()]` 过滤 / `$[n:m]` 切片）

**depends: []**

**目标**：补齐 JSONPath 规范中的三个缺失特性。

**步骤**：

1. **`$..` 递归下降**
   - 文件：`lib/core/rule_engine/executors/json_executor.dart`
   - 在 `_queryPath()` 中识别 `..` 段 → 递归遍历所有层级匹配字段名。

2. **`$[?(@.field==value)]` 过滤表达式**
   - 在 `_expandByBracket()` 中识别 `?()` 语法 → 对数组元素逐个求值条件表达式。
   - 支持：`==`、`!=`、`>`、`<`、`=~`（正则匹配）。

3. **`$[start:end]` 数组切片**
   - 在 `_expandByBracket()` 中识别 `n:m` 格式 → 列表切片。
   - 支持负数索引和省略形式（`[:3]`、`[2:]`、`[::2]`）。

**验收标准**：
- `$..title` 递归提取所有层级的 title 字段。
- `$.books[?(@.type==1)]` 过滤 type==1 的元素。
- `$.list[0:5]` 返回前 5 个元素。

---

#### Task 0-12：列表规则 `-` 前缀反转

**depends: []**

**目标**：`chapterList` / `bookList` 规则前加 `-` 反转结果列表。

**当前进展（2026-02-27）**：
- [x] `SearchService` 已识别并剥离列表规则 `-` 前缀，透传 `listReversed` 到 `SearchResultParser`。
- [x] `SearchResultParser` 已在 chunk 级别执行反转，确保搜索/发现链路顺序一致。
- [x] `BookDetailService` 已识别目录列表 `-` 前缀并与 `tocReversed` 布尔语义合并。
- [x] 已补充 Search/Detail/Explore 对应回归测试（含 `ExploreService` 映射链路）。

**步骤**：

1. 在 `BookDetailService._parseChapters()` 解析 `listRule` 前检测并 strip `-` 前缀。
2. 如果检测到 `-`，在结果列表上做 `.reversed.toList()`。
3. 同理适配 `SearchService` 和 `ExploreService` 的 list 规则。

**验收标准**：
- `-class.chapter@tag.a` 返回反转后的章节列表。
- 无 `-` 前缀的规则行为不变。

---

#### Task 0-13：`@textNodes` / `@ownText` 提取器精确语义

**depends: []**

**目标**：`@textNodes` 仅提取直接文本节点（不含子元素文本），`@ownText` 仅提取元素自身文本。

**步骤**：

1. 文件：`lib/core/rule_engine/executors/html_executor.dart`
2. 在提取器分支中新增 `textNodes` 和 `ownText` case。
3. `textNodes` → 遍历 `element.nodes`，仅取 `Text` 类型节点的内容。
4. `ownText` → 使用 `element.text` 但排除子元素（遍历直接子 Text 节点）。
5. 更新 `LegacyRuleCompat` 中的归一化逻辑，不再将 `textNodes` 强制映射为 `text`。

**验收标准**：
- `<div>Hello<span>World</span>!</div>` 用 `@textNodes` 返回 `Hello!`（不含 `World`）。
- 用 `@text` 返回 `HelloWorld!`。

---

#### Task 0-14：元数据字段补齐（引擎 / 数据层）

**depends: []**

**目标**：补齐 Legado 元数据字段映射与覆盖语义，保证搜索/详情/目录链路的数据一致性，不要求 UI 改造。

**步骤**：

1. **SourceRuleSet 新增字段**：
   - `detailKindRule`、`detailWordCountRule`、`detailLastChapterRule`、`detailCanReNameRule`
   - `searchKindRule`、`searchWordCountRule`
   - `tocIsVipRule`、`tocUpdateTimeRule`

2. **LegadoSourceAdapter 映射**：
   - `ruleBookInfo` → `kind`/`wordCount`/`lastChapter`/`canReName`
   - `ruleSearch` → `kind`/`wordCount`
   - `ruleToc` → `isVip`/`updateTime`

3. **领域模型透传**（非 UI）：
   - `BookMeta` / `SearchItem` / `ChapterMeta` 增加 `kind`、`wordCount`、`lastChapter`、`isVip`、`updateTime` 字段透传。
   - 持久化层按需落盘，未使用字段可保留空值但不可丢失映射能力。

4. **canReName 逻辑**：
   - 在数据合并阶段处理：若 `canReName` 规则求值为真，且详情链路拿到有效书名/作者，则覆盖入口链路同字段。

**验收标准**：
- 含 `kind`/`wordCount`/`lastChapter`/`isVip`/`updateTime` 的源均能在领域模型中正确取值。
- `canReName` 为 true 时，入口数据会被详情数据按规则覆盖（通过服务层测试断言）。
- 全流程无需新增或修改 UI 才能通过兼容主线验收。

---

#### Task 1-11：`jsLib` 全局 JS 库注入

**depends: [1-2]**

**目标**：`jsLib` 字段包含源作者定义的全局 JS 函数库，应在每次 JS 执行前注入到 QuickJS 上下文。

**步骤**：

1. **SourceDefinition 新增字段**：`final String? jsLib;`
2. **LegadoSourceAdapter 映射**：从 `raw.rawData['jsLib']` 读取完整内容（不再仅做子串提取）。
3. **JsExecutor 注入**：在执行用户脚本之前，先 `runtime.evaluate(jsLib)` 注入库代码。
4. **安全兜底**：jsLib 执行同样受 3s 超时约束；注入失败不阻塞后续规则执行。

**验收标准**：
- 含 `jsLib` 定义了 `function decrypt(s) { ... }` 的源，在 `@js:decrypt(result)` 中可调用。

---

#### Task 1-12：`variable` 字段持久化（source / book / chapter 级）

**depends: [1-4, 1-8]**

**目标**：Legado 支持 per-source/book/chapter 的自定义变量持久化，JS 中通过 `java.put`/`java.get` 读写。

**当前进展（2026-02-27）**：
- [x] 已在 `JsExecutor` 增加 `java.put` 回调上报能力，并接入 `SearchService` / `BookDetailService` / `ChapterContentService`。
- [x] Source 级变量持久化：`SourceDefinition.originalSource['_appread_js_variables']`。
- [x] Book 级变量持久化：`SourceDefinition.originalSource['_appread_js_book_variables'][bookId]`。
- [x] Chapter 级变量：单次加载内存态（不持久化）。
- [x] 已覆盖回归：`search_service_test` / `book_detail_service_test` / `chapter_content_service_test` 新增 `java.put/java.get` 作用域持久化用例。

**步骤**：

1. **Sources 表新增 `variable` 列**（Drift migration version 5，独立于 Phase 0 的 version 4）。
2. **Book 本地模型新增 `variable` 字段**。
3. **`java.put(key, val)` 写入时**：同步更新内存 + 异步落盘（debounce 500ms 防高频写入）。
4. **`java.get(key)` 读取时**：优先从内存读取。
5. **作用域**：
   - Source 级变量：跨所有书籍共享。
   - Book 级变量：单本书范围。
   - Chapter 级变量：单章节范围（仅内存态，不持久化）。

**验收标准**：
- JS 中 `java.put('token', 'abc')` 后退出并重进 → `java.get('token')` 返回 `'abc'`。
- 不同书籍的 book 级变量互不干扰。

---

## 更新后的任务总表

| Phase | 任务数 | 编号范围 |
|-------|--------|----------|
| Phase 0 | **14** | 0-1 ~ 0-14 |
| Phase 1 | **12** | 1-1 ~ 1-12 |
| Phase 2 | **4** | 2-1 ~ 2-4 |
| Phase 3 | **4** | 3-1 ~ 3-4 |
| **总计** | **34** | |

---

## 风险清单

| 风险 | 影响 | 应对 |
|------|------|------|
| `flutter_js` 在某平台编译失败 | 阻塞 Phase 1 | 备选：Dart FFI + QuickJS native 编译 |
| `executeAll` 异步化影响面过大 | 大量文件需修改 | Task 1-9 必须在 1-3 之后立即做，用 `grep` 全量扫描 |
| QuickJS 同步阻塞 Dart Isolate | 3s 超时不够用 | 分析在野源 JS 执行耗时，按需调整 |
| Bridge 网络请求安全风险 | 恶意源发起内网请求 | 域名白名单 + 内网 IP 段拦截 |
| Drift schema 迁移冲突 | 用户升级时数据丢失 | Phase 0 合并一次迁移（v4）；Phase 1 变量持久化单独一次（v5） |
| `java.getString` 递归死循环 | 栈溢出崩溃 | 递归深度上限 3 层 |
| JSONPath `$..` 递归性能 | 深层 JSON 遍历慢 | 设递归深度上限 10 层 + 结果数上限 1000 |
