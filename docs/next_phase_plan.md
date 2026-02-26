# 源阅 — 下一阶段开发计划（规则兼容 & 体验进阶）

> 编制日期：2026-02-26
> 基线版本：`1.0.6+1`（main 分支，阶段 0–4 完成，阶段 5 收尾）
> 目标：从 MVP 走向"主流 Legado 书源 80 %+ 可用率"

---

## 一、当前状态快照

| 维度 | 现状 |
|------|------|
| 核心阅读链路 | 搜索 → 详情 → 目录 → 正文 完整闭环 |
| 规则兼容 | HTML/CSS + JSONPath + Regex + `\|\|` 回退 + `init` 预请求 + POST 三形态 + AES/LZ-Base64 解密 |
| JS 规则 | 模式匹配降级（~30 种常见 pattern），无真实 JS 引擎 |
| 漫画 | M0 + M1 已落地（图流阅读、懒加载、三种阅读模式） |
| 发现页 | 完整实装，含分类 / 分页 / 源切换 / 兼容探活 |
| UI | Material Design 3 全面落地，手机端自适应基本完成 |
| 测试 | 全链路端到端 + 加密源 + 漫画源回归样本 |

### 关键缺口（按用户可感知影响排序）

| # | 缺口 | 受影响源数（测试集内） | 用户感知 |
|---|------|----------------------|----------|
| 1 | `replaceRegex` 未执行 | 14+ | 正文夹杂广告、重复标题 |
| 2 | `nextTocUrl` 未实装 | 8+ | 章节列表不全（仅取第一页） |
| 3 | `nextContentUrl` 未实装 | 13+ | 章节内容截断（仅取第一页） |
| 4 | JS 规则前置拦截缺失 | — | 不支持的源搜索失败仅显示"解析为空"，用户无法理解原因 |
| 5 | `concurrentRate` 未遵守 | — | 存在被源站封 IP 风险 |

---

## 二、任务清单与优先级

### P0 — 规则兼容补齐（影响最大、改动可控）

#### P0-01：实装 `replaceRegex` 正文替换规则

- **背景**：Legado `ruleContent.replaceRegex` 字段定义了源作者编写的正文清洗规则（去广告、去重复标题、去 emoji），当前完全被忽略。
- **改动范围**：
  1. `SourceRuleSet` 新增 `contentReplaceRegex` 字段（`String?`）。
  2. `LegadoSourceAdapter` 从 `raw.rawData['ruleContent']['replaceRegex']` 读取并映射。
  3. `ChapterContentService` 在 `ContentTextCleaner.clean()` 之后、缓存写入之前，执行替换链。
  4. 替换链解析：支持 `##` 分隔的多条规则，每条格式为 `regex##replacement`（replacement 为空则删除匹配）。
  5. Drift schema 迁移（与 P0-02/03 合并为一次 migration）。
- **安全兜底**：每条正则执行设 200 ms 超时，超时跳过并记录日志（防 ReDoS）。
- **验收标准**：
  - 含 `replaceRegex` 的测试源正文无广告残留。
  - 不含该字段的源行为不变。
  - 恶意正则不导致卡顿。

#### P0-02：实装 `nextTocUrl` 目录翻页

- **背景**：许多源将目录拆分为多页（`<select>` 导航 / "下一页"链接），`ruleToc.nextTocUrl` 用于提取下一页 URL。当前只取第一页。
- **改动范围**：
  1. `SourceRuleSet` 新增 `tocNextPageRule` 字段。
  2. `LegadoSourceAdapter` 从 `raw.rawData['ruleToc']['nextTocUrl']` 读取并映射。
  3. `BookDetailService._parseChapters()` 外层加 while 翻页循环：
     - 对当前页 HTML 执行 `tocNextPageRule` 提取下一页 URL。
     - URL 非空 && 不在已访问集合中 → 发起请求 → 追加章节。
     - 循环退出条件：URL 为空 / URL 已访问 / 达到硬上限 50 页 / 连续 2 次新增章节数为 0。
  4. Drift schema 迁移（合并）。
- **验收标准**：
  - 分页目录源拿到完整章节列表。
  - 单页目录源行为不变。
  - 死循环 URL 不导致无限请求。

#### P0-03：实装 `nextContentUrl` 正文翻页

- **背景**：部分源将单章正文拆分为多页，`ruleContent.nextContentUrl` 用于提取下一页 URL。当前只取第一页。
- **改动范围**：
  1. `SourceRuleSet` 新增 `contentNextPageRule` 字段。
  2. `LegadoSourceAdapter` 从 `raw.rawData['ruleContent']['nextContentUrl']` 读取并映射。
  3. `ChapterContentService.load()` 内容提取后加 while 翻页循环：
     - 对当前页 HTML 执行 `contentNextPageRule` 提取下一页 URL。
     - URL 非空 && 不在已访问集合 && 不等于下一章 URL → 发起请求 → 追加正文。
     - 退出条件：URL 为空 / URL 已访问 / 达到硬上限 30 页 / URL 匹配下一章。
  4. 追加的正文通过内容 hash 去重（防尾部重复）。
  5. Drift schema 迁移（合并）。
- **验收标准**：
  - 分页正文源显示完整章节内容。
  - 单页正文源行为不变。
  - 尾部无重复段落。

#### P0-04：JS 规则前置拦截与用户提示

- **背景**：`SourceCapabilityAnalyzer` 已标注源的 JS 依赖级别（`none` / `partial` / `unsupported`），但该结果未在搜索 / 阅读入口使用，用户看到的是模糊的"解析为空"。
- **改动范围**：
  1. 搜索执行前：检查目标源 `jsCapability`，`unsupported` 源弹出 Snackbar："此书源依赖 JS 规则，当前不支持，搜索可能无结果"。
  2. `partial` 源弹出轻提示："此书源部分功能依赖 JS 规则，可能影响使用"。
  3. 书源卡片增加兼容度徽标（绿 = full / 黄 = partial / 红 = unsupported）。
  4. 搜索失败时，若源为 `partial` / `unsupported`，错误文案补充"可能因 JS 规则不兼容导致"。
- **验收标准**：
  - 用户在搜索失败前即可知道源的兼容限制。
  - `none` 级别源不显示任何额外提示。

#### P0-05：`concurrentRate` 基础限流

- **背景**：Legado 源可通过 `concurrentRate` 字段定义请求频率（如 `"1/1000"` = 每秒 1 次）。当前完全忽略，存在触发源站反爬的风险。
- **改动范围**：
  1. `SourceDefinition` 新增 `concurrentRate` 字段（`String?`）。
  2. `LegadoSourceAdapter` 从 `raw.rawData['concurrentRate']` 读取。
  3. 解析格式：`"次数/毫秒数"`（如 `"1/1000"`）→ 换算为最小请求间隔。
  4. `core/network/` 层新增 per-source 令牌桶（`Map<String, _RateLimiter>`），在 `_fetchHtml()` 前 await 令牌。
  5. 无 `concurrentRate` 的源不受限。
- **验收标准**：
  - 有 `concurrentRate` 的源请求间隔符合定义。
  - 无该字段的源无任何额外延迟。

---

### P1 — 规则能力扩展（兼容率提升第二梯队）

#### P1-01：`@put` / `@get` 变量链完整实装

- **背景**：Legado 支持 `@put{key:rule}` 在规则执行中将中间结果存入变量，后续阶段通过 `@get{key}` 读取。当前已有基础上下文透传，但 `@put/@get` 语法未完整解析。
- **改动范围**：
  1. 规则引擎新增 `RuleExecutionContext.variables: Map<String, String>`。
  2. `RuleParser` 识别 `@put{key:rule}` → 执行内嵌 rule → 将结果存入 context。
  3. `@get{key}` → 从 context 读取 → 替换到当前规则表达式中。
  4. context 在搜索 → 详情 → 目录 → 正文四阶段间传递。
- **验收标准**：依赖 `@put/@get` 的源链路可走通。

#### P1-02：XPath 规则原生支持

- **背景**：`LegacyXPathCompat` 当前将 XPath 转 CSS 选择器，但只覆盖简单路径。复杂 XPath（`following-sibling`、`contains()`、`position()`）转换失败。
- **改动范围**：
  1. 技术选型：优先评估 `xpath_selector_html_parser`；不满足则用 `xml` 包 + 手写适配。
  2. `RuleParser` 识别 `@xpath:` 前缀 / `//` 开头规则 → 分发到 `XPathExecutor`。
  3. 新增 `lib/core/rule_engine/executors/xpath_executor.dart`。
  4. 保留 `LegacyXPathCompat` 作为回退（XPath 库解析失败时降级到 CSS 转换）。
- **验收标准**：含复杂 XPath 规则的源可正常解析。

#### P1-03：正文内容健康度校验

- **背景**：部分源返回模板残留（`{{`）、过短内容（<50 字）或纯广告。当前静默展示。
- **改动范围**：
  1. `ChapterContentService` 返回前增加校验层。
  2. 检测项：模板残留 / 过短内容 / 纯 HTML 标签 / 纯广告关键词。
  3. 校验失败 → 返回结构化 `ContentQualityWarning`，UI 层展示提示而非空白页。
- **验收标准**：问题内容给出明确提示而非静默展示。

#### P1-04：搜索结果书架状态标记

- **背景**：搜索结果不显示书籍是否已入架，用户需要记忆。
- **改动范围**：
  1. `SearchResultCard` 读取本地书架状态。
  2. 已收藏 → 显示"已在书架"角标；正在阅读 → 显示"阅读中"角标。
- **验收标准**：搜索结果一眼区分已入架 / 未入架书籍。

#### P1-05：书源规则调试台

- **背景**：当前排查规则问题需要看日志，效率低。
- **改动范围**：
  1. 新增调试页面（从书源卡片三点菜单 → "调试规则"进入）。
  2. 输入关键词 / URL → 分阶段展示：请求 URL、HTTP 状态码、响应摘要（前 500 字符）、规则命中结果、失败原因。
  3. 阶段切换：搜索 / 详情 / 目录 / 正文。
- **验收标准**：可在 App 内定位任意源任意阶段的规则匹配问题。

---

### P2 — JS 引擎与高级兼容（兼容天花板突破）

#### P2-01：受限 JS Runtime 集成

- **背景**：~30–40% 的在野 Legado 源在至少一个阶段使用 JS。当前模式匹配降级无法处理控制流、DOM 操作、异步调用。
- **技术选型**：
  | 方案 | 包体积 | 性能 | 安全性 | 备注 |
  |------|--------|------|--------|------|
  | `flutter_js` (QuickJS) | ~2 MB | 快 | 中（需手动沙箱） | 社区成熟度一般 |
  | Dart FFI → JavaScriptCore (iOS) / V8 (Android) | 0（系统自带） | 最快 | 高 | 平台分裂，维护成本高 |
  | WebView 沙箱 | 0 | 慢 | 高 | 延迟高，不适合高频调用 |
- **建议方案**：`flutter_js`（QuickJS），统一跨平台，包体积可接受。
- **改动范围**：
  1. 沙箱封装：禁止网络 / 文件 / 无限循环（设 3s 执行超时）。
  2. 新增 `lib/core/rule_engine/executors/js_executor.dart`。
  3. `RuleParser` 识别 `@js:` / `<js>...</js>` → 分发到 `JsExecutor`。
  4. 超时 / 异常不影响主线程，降级为静态规则结果。
- **验收标准**：`@js:` 规则可在沙箱中执行；超时 / 异常不崩溃。

#### P2-02：`java.*` Bridge API 实装

- **背景**：Legado JS 规则通过 `java.*` API 调用宿主能力（网络请求、加解密、变量存储）。
- **改动范围**：
  1. 在 JS 沙箱中注入以下 bridge 函数：
     - `java.ajax(urlStr)` → 桥接到 Dart Dio 请求
     - `java.get(key)` / `java.put(key, val)` → 桥接到 `RuleExecutionContext.variables`
     - `java.md5Encode(str)` → 桥接到 `crypto` 包
     - `java.aesDecrypt(data, key, iv, ...)` / `java.aesEncrypt(...)` → 桥接到加密工具
     - `java.base64Decode(str)` / `java.base64Encode(str)`
  2. 每个 bridge 调用设独立超时（网络 15s，其余 1s）。
- **前置依赖**：P2-01 完成。
- **验收标准**：依赖 `java.*` API 的源可正常执行。

#### P2-03：`Reload(url)` 规则支持

- **背景**：部分漫画源在目录 / 正文规则中使用 `Reload(url, headers)` 发起中间请求获取真实数据。
- **改动范围**：
  1. `RuleParser` 识别 `Reload(url)` / `Reload(url, headers)` 语法。
  2. 在规则执行链路中执行中间 HTTP 请求，将响应作为新的解析输入。
  3. 递归深度上限 3 层。
- **前置依赖**：P2-01 完成（部分 `Reload` URL 由 JS 计算）。
- **验收标准**：含 `Reload` 的漫画源可正常加载。

---

### P3 — 体验打磨与工程质量

#### P3-01：批量导入兼容率验收报告

- 自动化导入 `read.json` + `test_read.json` → 统计成功率 / 去重率 / 失败明细 → 生成 JSON 报告。
- 每次发版前可自动生成，作为质量门禁依据。

#### P3-02：多源搜索健康度调度

- 按源健康度（连续失败数 / 最近成功率）分层调度。
- 健康源优先并发，亚健康源降级延后，死源跳过。
- 大量源场景下搜索体验更稳定。

#### P3-03：阅读主题独立于全局

- 新增开关：阅读页配色可独立于 App 全局 ThemeMode。
- 用户可在全局夜间模式下使用护眼 / 羊皮纸阅读主题。

#### P3-04：书架长按多选管理

- 网格 / 列表视图支持长按进入多选模式。
- 支持批量移出书架 / 批量清缓存。

#### P3-05：关键页面 Golden 测试

- 覆盖书架 / 搜索 / 详情 / 阅读 4 页 × 2 尺寸（375×812 / 390×844）× textScale 1.0 + 1.3。
- UI 回归有自动化兜底。

---

## 三、关键文件改动索引

| 文件 | 涉及任务 |
|------|----------|
| `lib/domain/entities/source_definition.dart` | P0-01, P0-02, P0-03, P0-05, P1-01 |
| `lib/data/adapters/legado_source_adapter.dart` | P0-01, P0-02, P0-03, P0-05, P1-01 |
| `lib/data/datasources/drift/tables.dart` | P0-01 ~ 03, P0-05（合并一次 schema 迁移） |
| `lib/features/reader/application/chapter_content_service.dart` | P0-01, P0-03, P1-03 |
| `lib/features/book/application/book_detail_service.dart` | P0-02 |
| `lib/core/rule_engine/processors/legacy_script_rule_fallback.dart` | P1-01, P2-01 |
| `lib/core/rule_engine/rule_parser.dart` | P1-02, P2-01 |
| `lib/core/rule_engine/executors/`（新增） | P1-02 `xpath_executor.dart`, P2-01 `js_executor.dart` |
| `lib/features/source/application/source_capability_analyzer.dart` | P0-04 |
| `lib/features/search/presentation/search_page.dart` | P0-04, P1-04 |
| `lib/core/network/` | P0-05（令牌桶限流） |

---

## 四、执行节奏

```
P0（规则兼容补齐）
  ├─ P0-01 replaceRegex        ← 最小改动、最大收益，首先做
  ├─ P0-02 nextTocUrl           ← 紧接，与 P0-01 共享 schema 迁移
  ├─ P0-03 nextContentUrl       ← 同批
  ├─ P0-04 JS 前置拦截          ← 轻量 UI 改动，可并行
  └─ P0-05 concurrentRate       ← 可稍后，独立模块

P1（规则能力扩展）
  ├─ P1-01 @put/@get            ← 优先，多源依赖
  ├─ P1-02 XPath                ← 其次，需引入依赖
  ├─ P1-03 内容健康度           ← 轻量，可并行
  ├─ P1-04 书架状态标记         ← 轻量 UI
  └─ P1-05 规则调试台           ← 可独立迭代

P2（JS 引擎）
  ├─ P2-01 JS Runtime           ← 前置技术选型评审
  ├─ P2-02 java.* Bridge        ← 依赖 P2-01
  └─ P2-03 Reload               ← 依赖 P2-01

P3（体验打磨）
  └─ 可穿插在 P0 ~ P2 间隙执行
```

---

## 五、风险与应对

| 风险 | 应对措施 |
|------|----------|
| `nextTocUrl` 翻页死循环 | 硬上限 50 页 + URL 去重集合 + 连续 2 次新增章节数为 0 退出 |
| `nextContentUrl` 正文重复 | 内容 hash 去重 + 翻页 URL ≠ 当前 URL + 翻页 URL ≠ 下一章 URL |
| `replaceRegex` 恶意正则 ReDoS | 每条替换规则 200 ms 超时，超时跳过并记录日志 |
| JS 引擎包体积增大 | `flutter_js` ~2 MB；备选：仅桌面端启用 JS，移动端保持降级 |
| Drift schema 迁移链条 | P0-01 ~ 03 + P0-05 合并为一次迁移（schema version +1） |
| XPath 库兼容性 | 优先评估 `xpath_selector_html_parser`；不满足则用 `xml` 包 + 手写适配 |

---

## 六、验证方案

| 阶段 | 验证方式 |
|------|----------|
| P0-01 ~ 03 完成后 | 使用 `test_read.json` 中含对应字段的源执行全链路回归，对比修复前后的章节数量、正文完整度、广告残留量 |
| P0-04 完成后 | 导入含 JS 规则的源，验证搜索前是否出现兼容提示 |
| P0-05 完成后 | Mock 高频请求场景，验证令牌桶是否正确限流 |
| 每个 P 阶段完成后 | `flutter analyze` + `flutter test` 全量通过 |
| P2 完成后 | 选取 10 条 JS 源做端到端验收，统计通过率 |

---

## 七、与现有文档的关系

| 现有文档 | 本计划对应 | 关系说明 |
|----------|-----------|----------|
| `legado_full_compatibility_plan.md` | P1-01, P1-02, P2-01 ~ 03 | 本计划细化了执行顺序并补充了 P0 层（原文档未覆盖 replaceRegex / nextTocUrl / nextContentUrl） |
| `manga_source_compat_plan.md` M2 | P2-01 ~ 03 | JS 引擎是漫画 M2 的前置依赖，合并推进 |
| `reader_content_quality_next_stage.md` R04 ~ R09 | P0-01, P1-03 | replaceRegex 直接解决 R05；内容健康度校验解决 R04 |
| `ui_component_next_plan.md` P0-4 | P1-04 | 搜索结果书架状态标记 |
| `implementation_steps.md` 下一阶段 | P0-04, P1-05, P3-01 ~ 02 | 规则调试台、多源搜索治理、批量导入验收 |
