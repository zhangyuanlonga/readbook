# 源阅 — Legado 书源规则全兼容最优方案

> 编制日期：2026-02-27
> 基线：Legado 3.0 官方规则规范（`docs/reference/legado_source_rule_2024-02-27.html`）
> 目标：从当前 ~65% 兼容率逐步推进至 90%+

---

## 当前执行快照（2026-02-27）

> 口径：仅统计引擎/数据兼容主线，不把 UI 改造纳入里程碑。

| Phase | 状态快照 | 说明 |
|------|------|------|
| Phase 0（规则补齐） | 已完成 | `0-1 ~ 0-14` 已收口，规则语义补齐闭环 |
| Phase 1（QuickJS） | 已完成（主线） | QuickJS 主链路已稳定运行，`book/chapter/source/cookie/cache` 上下文与 `jsLib` 注入已打通 |
| Phase 1 Bridge | 已完成（主线） | Tier-1~Tier-4 主线已闭环，`jsCapability` 分级与 `js_fallback_legacy`/超时守卫诊断已接入回归 |
| Phase 2（XPath） | 已完成（主线） | 原生 `XPathExecutor` 已接入 `RuleParser/RuleEngine`，并保留 `LegacyXPathCompat` 失败/空结果降级 |
| Phase 3（WebView） | 已完成（主线） | `flutter_inappwebview`、Headless WebView 执行器、`webView:true` 路由与 `sourceRegex` 采集+消费链路已闭环 |

**已通过的主线回归（本轮）**：
- `flutter analyze` 通过。
- 搜索→详情→目录→正文链路相关测试通过（含 `legacy_source_compatibility_test`）。
- 核心规则与网络链路回归通过（`core/rule_engine`、`core/webview`、`core/network`）。
- `manga_inline_js_source_test`、`legado_source_adapter_test` 已恢复通过（fixture 与 server-proxy 降级映射已收口）。
- `webView:true` 稳定性回归已补齐：主链路新增 “WebView 异常 -> HTTP 回退” 用例，批量诊断进度统计一致性已加回归。
- 高频 Bridge 兼容补齐已落地：`connect/getElement/getCookie/toNumChapter/timeFormatUTC/t2s/s2t/strToBytes/bytesToString/createSymmetricCrypto` + `toast/longToast/startBrowser/startBrowserAwait/webView` no-op 桥接。

---

## 一、Legado 规则体系全貌

### 1.1 规则类型（6 种）

| 前缀 | 引擎 | 说明 |
|------|------|------|
| 无前缀 | JSoup 自有语法 | `class.odd.0@tag.a@text`，`@` 分段，末段为提取器 |
| `@css:` | JSoup CSS 选择器 | 标准 CSS 选择器 + JSoup 扩展伪类 |
| `@XPath:` / `//` | JsoupXpath | W3C XPath 1.0 子集 |
| `@json:` / `$.` | Jayway JsonPath | goessner JSONPath 规范 |
| `@js:` | Rhino JS 引擎 | 只能放在规则末尾，`result` 为前段结果 |
| `<js>...</js>` | Rhino JS 引擎 | 可放在规则任意位置，可做中间分隔 |

### 1.2 操作符（6 种）

| 操作符 | 语义 | 说明 |
|--------|------|------|
| `&&` | 合并 | 多规则结果拼接 |
| `\|\|` | 回退 | 第一个有结果的规则胜出 |
| `%%` | 交错 | 多列表轮询取值 |
| `##regex##replacement` | 正则替换 | 规则后缀，全局替换 |
| `@put:{key:"rule"}` | 存变量 | 执行 rule 并存入上下文 |
| `@get:{key}` | 取变量 | 从上下文读取 |

### 1.3 URL 格式规范

```
URL,{ "method":"POST", "charset":"gbk", "body":"key=xxx",
      "headers":{...}, "webView":true, "js":"...", "retry":3 }
```

完整 UrlOption 字段：`method` / `charset` / `webView` / `headers` / `body` / `type` / `js` / `retry`

### 1.4 java.* Bridge 完整 API（40+ 函数）

**网络（5）**：`ajax(url)` / `ajaxAll(urlList)` / `connect(url)` / `get(url,headers)` / `post(url,body,headers)`

**编解码（12）**：`base64Decode` / `base64Encode` / `base64DecodeToByteArray` / `md5Encode` / `md5Encode16` / `encodeURI` / `utf8ToGbk` / `htmlFormat` 等

**AES 加解密（8）**：`aesDecodeToString(str,key,transformation,iv)` / `aesEncodeToString` / `aesBase64DecodeToString` / `aesBase64DecodeToByteArray` 等（4 解密 + 4 加密）

**文件（8）**：`getFile` / `readFile` / `readTxtFile` / `deleteFile` / `downloadFile` / `unzipFile` / `getTxtInFolder` / `getZipStringContent` 等

**字体反爬（3）**：`queryTTF(str)` / `queryBase64TTF(base64)` / `replaceFont(text,font1,font2)`

**Cookie（1）**：`getCookie(tag,key)`

**时间（2）**：`timeFormat(timestamp)` / `timeFormat(timeStr)`

**规则解析（4）**：`setContent(content,baseUrl)` / `getString(rule)` / `getStringList(rule)` / `getElements(rule)`

**变量（2）**：`put(key,value)` / `get(key)`

**日志（1）**：`log(msg)`

### 1.5 JS 上下文变量

| 变量 | 类型 | 说明 |
|------|------|------|
| `result` | String/Object | 前段规则结果 |
| `baseUrl` | String | 当前页面 URL |
| `book` | Book 实体 | 书籍所有属性（name/author/bookUrl/variable 等 30+ 字段） |
| `chapter` | Chapter 实体 | 章节属性（url/title/index/variable 等） |
| `source` | BookSource 实体 | 书源定义 |
| `cookie` | CookieStore | Cookie 操作 |
| `cache` | CacheManager | 缓存操作 |

---

## 二、逐项兼容现状（142 项 Checklist，基线清单）

> 说明：本节用于展示“初始差距基线”，并非实时执行进度。实时进展以“当前执行快照”与 `docs/plan_e_implementation.md` 为准。

### 2.1 规则前缀

| 特性 | 状态 | 说明 |
|------|------|------|
| 无前缀 JSoup 语法 | ⚠️ | 基本可用，但 `[n:m:step]` 切片索引被 strip 丢弃，未真正执行过滤 |
| `@css:` | ⚠️ | 在 LegacyRuleCompat 中 strip 前缀后走 HTML 管线，但 JSoup 伪类（`:has`, `:contains`）未测试 |
| `@XPath:` / `//` | ⚠️ | 转 CSS 后执行，简单路径可用，`ancestor::`/`following-sibling::`/`contains()` 等轴不支持 |
| `@json:` / `$.` | ✅ | 完整 |
| `regex:` | ✅ | 完整 |
| `@js:` 末尾 | ⚠️ | 模式匹配 ~30 种 pattern，无真实引擎 |
| `<js>...</js>` 任意位置 | ⚠️ | 同上，且不支持作为规则中间分隔器 |
| `:` AllInOne 正则 | ❌ | 未实装 |
| `##regex##replacement###` OnlyOne | ❌ | 三重 `###` 终止符未识别 |

### 2.2 操作符

| 特性 | 状态 | 说明 |
|------|------|------|
| `\|\|` 回退 | ✅ | 已实装 |
| `##regex##replacement` 后缀替换 | ✅ | HTML/JSON 均支持 |
| `@put/@get` 变量 | ✅ | LegacyRuleVariableProcessor 已实装 |
| `&&` 合并 | ❌ | **完全未实装**，当前被当作分隔符 strip 掉 |
| `%%` 交错 | ✅ | RuleEngine 已支持多列表 round-robin 交错取值 |
| `{{}}` 内嵌规则求值 | ✅ | 已支持 `{{@@...}}`/`{{@css:...}}`/`{{@json:...}}`/`{{@xpath:...}}` |

### 2.3 URL 格式

| 特性 | 状态 | 说明 |
|------|------|------|
| `{{key}}` / `{{page}}` 占位符 | ✅ | 完整 |
| `{{page+1}}` 算术 | ✅ | 完整 |
| POST body（form/json/raw） | ✅ | 三种格式已支持 |
| 请求 headers | ✅ | JSON/字符串/`&&` 分隔/`@js:` 四种格式 |
| URL 尾部 `,{options}` 完整解析 | ⚠️ | `LegacyLinkPostProcessor` 可拆分 JSON，但 **`method`/`charset`/`webView`/`js`/`retry` 字段未解析** |
| `<,{{page}}>` 条件分段 | ❌ | 未实装 |
| `charset` 指定响应编码 | ❌ | 未实装 |
| `webView` 加载模式 | ❌ | 未实装 |
| URL 内 `js` 字段 | ❌ | 未实装 |
| `retry` 重试次数 | ❌ | 未实装 |

### 2.4 java.* Bridge API

| API | 状态 | 说明 |
|-----|------|------|
| `java.ajax(url)` | ❌ | |
| `java.ajaxAll(urlList)` | ❌ | |
| `java.connect(url)` | ❌ | |
| `java.get(url, headers)` | ❌ | |
| `java.post(url, body, headers)` | ❌ | |
| `java.getCookie(tag, key)` | ❌ | |
| `java.base64Decode(str)` | ❌ | 仅在 SourceResponseProcessor 硬编码解密，非运行时 API |
| `java.base64Encode(str)` | ❌ | |
| `java.md5Encode(str)` | ❌ | |
| `java.md5Encode16(str)` | ❌ | |
| `java.encodeURI(str)` | ❌ | |
| `java.utf8ToGbk(str)` | ❌ | |
| `java.htmlFormat(str)` | ❌ | |
| `java.timeFormat(ts)` | ❌ | |
| `java.aesDecodeToString(...)` | ❌ | 仅模式匹配提取 key，非运行时执行 |
| `java.aesEncodeToString(...)` | ❌ | |
| `java.aes*` 系列（8个） | ❌ | |
| `java.queryTTF(str)` | ❌ | |
| `java.replaceFont(...)` | ❌ | |
| `java.readFile(path)` / 文件系列 | ❌ | **可不实装**（安全风险，且在野使用率极低） |
| `java.setContent(content)` | ❌ | |
| `java.getString(rule)` | ❌ | |
| `java.getElements(rule)` | ❌ | |
| `java.getStringList(rule)` | ❌ | |
| `java.put(key, val)` | ❌ | `@put/@get` 语法已有，但 JS 内的 `java.put/get` 不可用 |
| `java.get(key)` | ❌ | 同上 |
| `java.log(msg)` | ❌ | |

### 2.5 内容处理 & 源字段

| 特性 | 状态 | 说明 |
|------|------|------|
| `replaceRegex`（正文替换） | ❌ | 14+ 源定义，完全未执行 |
| `nextTocUrl`（目录翻页） | ❌ | 8+ 源定义，完全未实装 |
| `nextContentUrl`（正文翻页） | ❌ | 13+ 源定义，完全未实装 |
| `concurrentRate`（频率限制） | ❌ | 未读取 |
| `loginUrl` / `loginUi` | ❌ | 未实装（MVP 可暂缓） |
| `bookUrlPattern` | ❌ | 未读取 |
| `webJs`（WebView JS） | ❌ | 未实装 |
| `sourceRegex`（资源嗅探） | ⚠️ | 已支持在 Headless WebView 中匹配采集资源 URL，后续补齐完整回填链路 |
| `book` / `chapter` / `source` JS 变量 | ❌ | JS 上下文中不可用 |

---

## 三、技术路线对比与最优解

### 3.1 核心问题：JS 引擎选型

这是最关键的技术决策——**选对 JS 引擎决定了兼容率天花板**。

#### 方案 A：继续模式匹配降级（不引入 JS 引擎）

```
投入：低（持续扩展 pattern）
兼容天花板：~75%
维护成本：高（每种新 JS 写法都要加 case）
```

**优势**：零依赖、零包体积增量、零安全风险。
**劣势**：永远无法兼容控制流（if/for）、`java.ajax`、`java.aesDecodeToString` 等动态调用。每次遇到新 pattern 都要改代码——这是一场追不完的长跑。

**结论：只适合作为 JS 引擎的降级兜底，不适合作为主路线。**

#### 方案 B：`flutter_js`（QuickJS 封装）

```
投入：中（~7-10 天核心 + bridge 实装）
兼容天花板：~88%
包体积：+2 MB
平台：Android / iOS / macOS / Linux / Windows
```

**优势**：跨平台一致、轻量、QuickJS 性能优秀（ES2023 完整支持）、社区有维护。
**劣势**：
- Dart ↔ JS 通信是同步阻塞（需要 Isolate 隔离）。
- Bridge 注入需要手写所有 `java.*` 函数的 Dart 桥接。
- 无 DOM——`document.querySelector` 等浏览器 API 不可用（但 Legado 源规则极少用到 DOM）。

#### 方案 C：Dart FFI → 系统 JS 引擎

```
投入：高（~15-20 天，平台分裂）
兼容天花板：~90%
包体积：0（使用系统自带引擎）
平台：iOS/macOS (JavaScriptCore) + Android (需手动绑定 V8/QuickJS)
```

**优势**：零额外包体积（Apple 平台）、性能最好。
**劣势**：Android 没有系统级 JS 引擎暴露给 NDK，需要自行编译 QuickJS/V8 为 .so（约 5-10 MB），**平台分裂严重**，维护成本高。

#### 方案 D：`flutter_inappwebview`（WebView 沙箱）

```
投入：中（~5-7 天核心）
兼容天花板：~92%（含 webView 源）
包体积：0（系统 WebView）
平台：Android / iOS / macOS
```

**优势**：完整浏览器环境（DOM + JS + 网络），天然支持 `"webView": true` 源和 `webJs` 执行。
**劣势**：
- **需要 Flutter 宿主上下文**——即使隐藏 WebView，也要附着在 Widget 树上（属于引擎内部运行约束，不代表需要改业务 UI 页面）。
- **性能差**——每次规则执行要创建/复用 WebView 实例，延迟显著。
- **不适合高频调用**——搜索一次可能需要执行几十次 JS 规则，WebView 开销不可接受。
- 桌面端（Windows/Linux）支持差。

#### 方案 E：混合方案（推荐最优解）

```
核心 JS 执行：flutter_js（QuickJS）
WebView 加载：flutter_inappwebview（仅用于 webView:true 的源）
模式匹配：保留作为 QuickJS 不可用时的降级兜底
```

**投入**：中高（~12-15 天核心 + bridge 逐步实装）
**兼容天花板**：**~92-95%**
**包体积**：+2 MB（QuickJS）
**平台**：全平台

### 3.2 为什么方案 E 是最优解

```
               兼容率
  100% ┤                              ┌─ Legado (Rhino + WebView)
       │                         ┌────┘
   95% ┤                    ┌────┘ ← 方案 E (QuickJS + WebView + 降级)
       │               ┌────┘
   90% ┤          ┌────┘ ← 方案 B (仅 QuickJS)
       │     ┌────┘
   85% ┤┌────┘
       ││
   80% ┤│
       ││← 方案 A (仅模式匹配)
   75% ┤│
       │└── 当前
   65% ┤
       └────────────────────────────────→ 工程投入
```

**方案 E 的分层策略**：

1. **第一层（覆盖 90% 场景）**：QuickJS 执行所有 `@js:` / `<js>` 规则 + 注入高频 java.* Bridge（`ajax`/`base64`/`md5`/`aes`/`put`/`get`/`encodeURI`/`timeFormat`/`getString`/`getElements`）。
2. **第二层（覆盖 5% 场景）**：`flutter_inappwebview` 隐藏 WebView 处理标注了 `"webView": true` 的源——这些源需要真实浏览器环境渲染。
3. **第三层（兜底）**：保留现有模式匹配作为 QuickJS 初始化失败 / 不可用平台的降级路径。

**不实装的部分**（投入产出比极低）：
- `java.readFile` / `java.deleteFile` 等文件操作 — 安全风险高，在野使用率 <1%
- `java.queryTTF` / `java.replaceFont` 字体反爬 — 极少源使用，实装成本高
- `java.downloadFile` / `java.unzipFile` — 在野使用率极低
- `Packages.java.xxx` Java 类导入 — Rhino 特有能力，其他引擎无法复制

---

## 四、分阶段执行计划

### Phase 0：不依赖 JS 引擎的高收益补齐

> 这些改动完全不需要 JS 引擎，但能显著提升兼容率（65% → 78%）。

| # | 任务 | 兼容率提升 | 改动量 |
|---|------|-----------|--------|
| 0-1 | `replaceRegex` 正文替换 | +3% | 小 |
| 0-2 | `nextTocUrl` 目录翻页 | +3% | 中 |
| 0-3 | `nextContentUrl` 正文翻页 | +2% | 中 |
| 0-4 | `&&` 合并操作符 | +2% | 中 |
| 0-5 | URL `method`/`charset`/`body` 完整解析 | +1% | 小 |
| 0-6 | `concurrentRate` 限流 | +0%（稳定性） | 小 |
| 0-7 | `:` AllInOne 正则 | +1% | 小 |
| 0-8 | `##regex##replacement###` OnlyOne | +1% | 小 |
| 0-9 | JSoup `[n:m:step]` 索引切片真正执行 | +1% | 小 |
| 0-10 | `<,{{page}}>` 条件分段 URL | +1% | 小 |

**Schema 迁移**：0-1/0-2/0-3 合并为一次 Drift migration。

### Phase 1：QuickJS 引擎接入（核心突破）

> 兼容率从 78% → 88%。

| # | 任务 | 说明 |
|---|------|------|
| 1-1 | **引入 `flutter_js` 依赖** | pubspec.yaml 添加，各平台验证启动 |
| 1-2 | **JsExecutor 核心封装** | `lib/core/rule_engine/executors/js_executor.dart`：Isolate 隔离执行、3s 超时熔断、结果类型转换 |
| 1-3 | **RuleParser 接入 JS 执行器** | `@js:` / `<js>` 前缀识别 → 分发到 JsExecutor |
| 1-4 | **Bridge Tier-1：变量与编解码** | 注入 `java.put/get/log/base64Decode/base64Encode/md5Encode/md5Encode16/encodeURI/htmlFormat/timeFormat` — 纯 Dart 实现，无外部依赖 |
| 1-5 | **Bridge Tier-2：网络请求** | 注入 `java.ajax(url)` → 桥接 Dio；`java.get(url,headers)` / `java.post(url,body,headers)` → 桥接 Dio；每次请求 15s 超时 |
| 1-6 | **Bridge Tier-3：加解密** | 注入 `java.aesDecodeToString/aesEncodeToString/aesBase64DecodeToString` 等 8 个函数 → 桥接 pointycastle |
| 1-7 | **Bridge Tier-4：规则解析** | 注入 `java.setContent/getString/getElements/getStringList` → 桥接回 Dart 规则引擎（需注意递归） |
| 1-8 | **JS 上下文变量注入** | `result`/`baseUrl`/`book`/`chapter`/`source`/`cookie`/`cache` 注入到 JS 全局作用域 |
| 1-9 | **`<js>` 中间分隔支持** | 规则字符串 `cssRule<js>jsCode</js>xpathRule` → 按 `<js>` 切割 → 前段走原规则引擎 → JS 处理 result → 后段继续 |
| 1-10 | **JS 能力诊断 + 模式匹配降级** | 导入阶段产出 `jsCapability` 分级；QuickJS 执行失败 / 超时时自动 fallback 到 LegacyScriptRuleFallback 并记录诊断原因 |

**关键设计决策**：

```
┌─ RuleParser ─────────────────────────────────┐
│  识别规则前缀 → 分发到对应 Executor           │
│                                               │
│  @css: → HtmlExecutor                         │
│  @json: → JsonExecutor                        │
│  regex: → RegexExecutor                       │
│  @js:  → ┌─ JsExecutor (QuickJS) ──────────┐│
│          │  注入 java.* Bridge               ││
│          │  注入 result/baseUrl/book/...     ││
│          │  3s 超时 → fallback               ││
│          └─ ↓ 失败时 ─────────────────────── ││
│             LegacyScriptRuleFallback (模式匹配)│
└───────────────────────────────────────────────┘
```

### Phase 2：XPath 原生支持 + `%%` 操作符

> 兼容率从 88% → 90%。

| # | 任务 |
|---|------|
| 2-1 | 引入 `xpath_selector_html_parser` 或 `xml` 包 |
| 2-2 | 新增 `XPathExecutor`，支持完整 XPath 1.0 子集（含轴、谓词、函数） |
| 2-3 | 保留 `LegacyXPathCompat` 作为降级（新库失败时退回 CSS 转换） |
| 2-4 | 实装 `%%` 交错操作符 |
| 2-5 | 完善 `{{}}` 内嵌规则求值（支持 `{{@@rule}}`/`{{@css:rule}}`/`{{@json:rule}}`） |

### Phase 3：WebView 层（可选，按需）

> 兼容率从 90% → 92-95%。
> 约束：Phase 3 仅新增引擎侧 `WebViewExecutor` 后台能力，不以页面改版、交互改造、视觉展示作为交付目标。

| # | 任务 |
|---|------|
| 3-1 | 引入 `flutter_inappwebview` |
| 3-2 | 封装 `WebViewExecutor`：隐藏 WebView 池（复用实例）→ 加载 URL → 等待完成 → 提取 DOM |
| 3-3 | URL 选项中 `"webView": true` 时自动路由到 WebViewExecutor |
| 3-4 | 支持 `webJs` 字段（在 WebView 中执行 JS 并获取返回值） |
| 3-5 | 支持 `sourceRegex` 资源嗅探（拦截 WebView 加载的媒体资源 URL） |
| 3-6 | Cookie 管理接入（`java.getCookie` 桥接 WebView CookieManager） |

**注意**：Phase 3 主要面向音频源（type=1）和极少数反爬站点，可根据实际需求决定是否实施；即使启用，也应保持现有 UI 结构不变。

---

## 五、Bridge 实装优先级排序

按在野源使用频率排序，分 4 批实装：

### Tier-1：纯计算函数（Day 1-2，最高 ROI）

```dart
// 这些函数只需要 Dart 标准库，零外部依赖
java.put(key, value)        // → RuleExecutionContext.variables[key] = value
java.get(key)               // → RuleExecutionContext.variables[key]
java.log(msg)               // → Logger.d(msg)
java.base64Decode(str)      // → base64.decode(str) → utf8.decode
java.base64Encode(str)      // → base64.encode(utf8.encode(str))
java.md5Encode(str)         // → md5.convert(utf8.encode(str)).toString()
java.md5Encode16(str)       // → md5Encode(str).substring(8, 24)
java.encodeURI(str)         // → Uri.encodeComponent(str)
java.encodeURI(str, enc)    // → 按指定编码 encode
java.htmlFormat(str)        // → 去 HTML 标签 + 实体解码
java.timeFormat(ts)         // → DateTime.fromMillisecondsSinceEpoch → format
```

### Tier-2：网络请求函数（Day 3-4）

```dart
java.ajax(url)              // → Dio.get/post(url) → response.body
java.ajaxAll(urlList)       // → Future.wait(urls.map(ajax)) → [body1, body2, ...]
java.get(url, headers)      // → Dio.get(url, headers: headers)
java.post(url, body, headers) // → Dio.post(url, data: body, headers: headers)
java.connect(url)           // → deprecated, alias for ajax
```

**安全约束**：
- 每次请求 15s 超时
- 域名白名单（仅允许请求 source.baseUrl 同域 + 常见 CDN）
- 单次 JS 执行最多 5 次网络请求

### Tier-3：加解密函数（Day 5-6）

```dart
java.aesDecodeToString(str, key, transformation, iv)
java.aesDecodeToByteArray(str, key, transformation, iv)
java.aesBase64DecodeToString(str, key, transformation, iv)
java.aesBase64DecodeToByteArray(str, key, transformation, iv)
java.aesEncodeToString(data, key, transformation, iv)
java.aesEncodeToByteArray(data, key, transformation, iv)
java.aesEncodeToBase64String(data, key, transformation, iv)
java.aesEncodeToBase64ByteArray(data, key, transformation, iv)
```

→ 全部桥接到 `pointycastle` 包（项目已有依赖）。

### Tier-4：规则解析函数（Day 7-8）

```dart
java.setContent(content, baseUrl) // → 创建新 RuleEngine 实例并设置内容
java.getString(rule, isUrl)       // → RuleEngine.execute(rule) → String
java.getStringList(rule, isUrl)   // → RuleEngine.executeAll(rule) → List<String>
java.getElements(rule)            // → RuleEngine.executeAll(rule) → List<Element>
```

**注意**：这些函数涉及 JS → Dart → 规则引擎 → 可能再触发 JS 的递归调用。需要设递归深度上限（3 层）。

### 不实装（明确排除）

| API | 原因 |
|-----|------|
| `java.readFile/readTxtFile/deleteFile` | 安全风险，在野使用率 <1% |
| `java.downloadFile/unzipFile/getTxtInFolder` | 安全风险，几乎无源使用 |
| `java.getZipStringContent/getZipByteArrayContent` | 极低频 |
| `java.queryTTF/queryBase64TTF/replaceFont` | 字体反爬实装成本极高，在野使用率 <2% |
| `java.getCookie` | 依赖登录系统，MVP 阶段不实装 |
| `java.utf8ToGbk` | 极低频，GBK 编码已在请求层处理 |
| `Packages.java.xxx` Java 类导入 | Rhino 特有，无法在 QuickJS 中复制 |

---

## 六、关键架构设计

### 6.1 JS 执行隔离

```
┌── Main Isolate ──────────────────────────────┐
│  RuleParser → 识别 @js: → 发起 JS 执行请求   │
│                                               │
│  ┌── JS Isolate (独立) ────────────────────┐  │
│  │  QuickJS Runtime                        │  │
│  │  ├── java.* Bridge (通过 SendPort 桥接) │  │
│  │  ├── 3s 执行超时                        │  │
│  │  ├── 递归深度上限 3                     │  │
│  │  └── 内存限制 32 MB                     │  │
│  └─────────────────────────────────────────┘  │
│                                               │
│  ← 结果返回 / 超时返回 null                   │
└───────────────────────────────────────────────┘
```

**为什么用 Isolate 隔离**：
- QuickJS 的 `evaluate()` 是同步阻塞调用
- 直接在 Main Isolate 执行会卡 UI
- Isolate 通信通过 SendPort/ReceivePort，天然线程安全
- 超时可通过 `Isolate.kill()` 强制终止

### 6.2 Bridge 通信协议

JS 中的 `java.ajax(url)` 需要调用 Dart 侧的 Dio——这是异步操作，但 QuickJS 是同步的。解决方案：

**方案（同步桥接）**：在 JS Isolate 中，`java.ajax` 通过 SendPort 发送请求到 Main Isolate，然后 JS Isolate 阻塞等待结果返回。

```dart
// JS Isolate 侧
String javaAjax(String url) {
  requestPort.send({'type': 'ajax', 'url': url, 'id': requestId});
  // 阻塞等待结果
  final result = responsePort.receive(); // 同步等待
  return result;
}
```

这需要使用 `Isolate` 的双向通信 + `ReceivePort` 阻塞读取模式。

### 6.3 安全边界

| 约束 | 值 | 原因 |
|------|-----|------|
| 单次执行超时 | 3s | 防死循环 |
| 网络请求超时 | 15s/次 | 防慢响应阻塞 |
| 单次执行最大网络请求 | 5 次 | 防滥用 |
| 递归深度 | 3 层 | 防 `getString` → JS → `getString` → ... |
| 内存限制 | 32 MB | 防内存泄漏 |
| 禁止 API | 文件读写、系统命令 | 安全 |

---

## 七、兼容率预期

| 阶段 | 完成后兼容率 | 累计投入 |
|------|-------------|----------|
| 当前 | ~65% | — |
| Phase 0 完成 | ~78% | 小 |
| Phase 1 完成（QuickJS + Bridge Tier1-2） | ~88% | 中 |
| Phase 1 + Bridge Tier3-4 | ~90% | 中高 |
| Phase 2 完成（XPath + %%） | ~91% | 中高 |
| Phase 3 完成（WebView） | ~93-95% | 高 |

**剩余 5-7% 不可兼容**：
- 依赖 Rhino 特有 Java 类导入的源（`Packages.java.security.MessageDigest` 等）
- 字体反爬源（`java.queryTTF`）
- 需要登录/Cookie 的源
- 极端复杂 JS（动态 `eval`、递归超限）

---

## 八、与现有文档的关系

| 文档 | 本方案对应 | 关系 |
|------|-----------|------|
| `next_phase_plan.md` P0 | Phase 0 | 完全对齐，本方案增加了 0-4/0-7/0-8/0-9/0-10 |
| `next_phase_plan.md` P2 | Phase 1 | 本方案细化了 Bridge 分层和隔离架构 |
| `legado_full_compatibility_plan.md` Phase 1-3 | Phase 0-2 | 本方案重新排序了优先级并补充了操作符缺口 |
| `legado_full_compatibility_plan.md` Phase 3 | Phase 1 | JS Runtime 方案从"待选型"变为"确定 QuickJS + 混合架构" |

---

## 九、决策建议

1. **立即启动 Phase 0**——不需要任何新依赖，全部是规则引擎逻辑补齐，风险最低、收益最高。
2. **Phase 1 先做 Tier-1/2 Bridge**——`java.put/get/base64/md5/ajax` 覆盖了 80% 的 JS 源需求，不必一次性实装全部 40+ API。
3. **Phase 3（WebView）可推迟**——在野标注 `webView:true` 的源占比极低（<3%），且主要是音频源，优先级低于文字/漫画。
4. **字体反爬和文件操作明确不做**——告知用户这类源"当前不兼容"即可，投入产出比极低。
