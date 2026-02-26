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

### Task 1-10：JS 前置拦截与用户提示

**depends: [1-1]**

**目标**：对 JS 兼容度不同的源给出前置提示。

**步骤**：

1. **搜索入口增加提示**
   - 文件：`lib/features/search/presentation/search_page.dart`
   - 搜索执行前检查目标源 `jsCapability`：
     - `unsupported` → Snackbar "此书源依赖复杂 JS 规则，部分功能可能不可用"
     - `partial` → 轻提示 "此书源部分依赖 JS 规则"

2. **书源卡片兼容度徽标**
   - 在书源列表卡片上显示兼容度标记：🟢 full / 🟡 partial / 🔴 unsupported。

3. **搜索失败文案增强**
   - 失败时检查源的 JS 依赖级别，补充提示 "可能因 JS 规则不兼容导致"。

**验收标准**：
- 导入 JS 依赖源 → 搜索前看到提示。
- 非 JS 源无提示。

---

## Phase 2：XPath 原生支持 + 操作符补全（90% → 92%）

---

### Task 2-1：引入 XPath 库

**depends: [Phase 1]**

**步骤**：
1. 评估 `xpath_selector_html_parser` 或 `xml` 包。
2. pubspec.yaml 添加依赖。
3. 冒烟测试。

---

### Task 2-2：XPathExecutor

**depends: [2-1]**

**步骤**：
1. 新建 `lib/core/rule_engine/executors/xpath_executor.dart`。
2. 接口与 HtmlExecutor 对齐：`List<String> execute({content, rule, stage})`。
3. 支持完整 XPath 1.0 子集（轴、谓词、函数）。
4. RuleParser + RuleEngine 注册。
5. 保留 `LegacyXPathCompat` 作为降级。

---

### Task 2-3：`%%` 交错操作符

**depends: []**

**步骤**：
1. RuleEngine.executeAll() 中按 `%%` 分割。
2. 多列表轮询取值（round-robin）。

---

### Task 2-4：`{{}}` 内嵌规则完整求值

**depends: [1-3]**

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

## 风险清单

| 风险 | 影响 | 应对 |
|------|------|------|
| `flutter_js` 在某平台编译失败 | 阻塞 Phase 1 | 备选：Dart FFI + QuickJS native 编译 |
| `executeAll` 异步化影响面过大 | 大量文件需修改 | Task 1-9 必须在 1-3 之后立即做，用 `grep` 全量扫描 |
| QuickJS 同步阻塞 Dart Isolate | 3s 超时不够用 | 分析在野源 JS 执行耗时，按需调整 |
| Bridge 网络请求安全风险 | 恶意源发起内网请求 | 域名白名单 + 内网 IP 段拦截 |
| Drift schema 迁移冲突 | 用户升级时数据丢失 | Phase 0 合并一次迁移；Phase 1 不改表结构 |
| `java.getString` 递归死循环 | 栈溢出崩溃 | 递归深度上限 3 层 |
