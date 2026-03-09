# Legado 兼容现状总览（2026-02-28）

## 1. 统计基线

- 输入样本：`/Users/zhangyuanlong/storage/FlutterProject/3000 书源.json`
- 统计输出：`/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/build/source_pack_compat_matrix/20260228_180318/summary.json`
- 判定口径：
  - `full`：语义基本对齐 Legado
  - `partial`：可执行但语义存在差距（不再算 full）
  - `unsupported`：明确不支持

## 2. 当前兼容度（真实口径）

- `total=3733`
- `full=3557`（95.3%）
- `partial=109`（2.9%）
- `unsupported=67`（1.8%）
- `non_full=176`（4.7%）

说明：之前看到的 `non_full=75` 是旧口径（把部分 `stub/no-op` 记为 full）。  
现在是源码对齐后的真实口径。

## 3. 已完成能力（为什么说主链路已打通）

- QuickJS 执行链路已接入：`@js:`、`<js>...</js>`
- `webView:true` 请求链路已接入 `flutter_inappwebview`
- 规则主链路（搜索→详情→目录→正文）回归可跑
- 高频基础桥接已可用（如 `setContent/getString/base64/md5/aes/toUrl`）

对应文档：
- `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/docs/plan_e_implementation.md`
- `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/docs/legado_native_bridge_mapping.md`

## 4. 为什么引入 JS + WebView 后仍有缺口

1. 引擎“能执行 JS”不等于“所有 `java.*` 语义与 Legado 完全一致”。
2. `java.webView/webViewGetSource/webViewGetOverrideUrl/startBrowserAwait` 已接入 `WebViewExecutor`，但仍是无人工交互的后台语义，与 Legado 端侧验证流程存在差距。
3. 一批桥接仍是 `partial`：`initUrl/getStrResponse/getResponse/importScript/reGetBook/refreshTocUrl/getVerificationCode`。
4. `Packages.*` 和 DOM 依赖源仍是结构性差距（Rhino/平台差异）。

## 5. 当前差距 Top（按出现次数）

- `packages_bridge`：68
- `partial_bridge.toast`：52
- `partial_bridge.webview`：35
- `partial_bridge.startbrowserawait`：30
- `dom_runtime_dependency`：20
- `partial_bridge.longtoast`：19
- `partial_bridge.startbrowser`：12
- `partial_bridge.refreshtocurl`：10

## 6. 下一步优先级（按收益排序）

### P0（已完成，2026-02-28）

1. `get/head/post/connect/ajaxAll` 已对齐为 Legado 风格 response 对象语义（含字符串拼接兼容）。
2. `cacheFile` 已对齐缓存 key/TTL/失效控制；`importScript` 已对齐网络缓存语义（本地文件读取仍为 partial）。
3. `initUrl/getStrResponse/getResponse` 已补上下文约束与可诊断行为。
4. `reGetBook/refreshTocUrl` 已补 `preUpdateJs` 上下文诊断与可回退降级。

### P1（进行中）

1. `createAsymmetricCrypto/createSign` 最小可用实现（先覆盖常见 RSA/签名算法）。
2. `已完成（2026-02-28）`：`webView` 系列 JS bridge 已与业务层 `WebViewExecutor` 一致化（`webView/webViewGetSource/webViewGetOverrideUrl/startBrowserAwait`）。

## 7. 你现在可以直接看的 md

- 总览（这份）：`/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/docs/archive/legado_compatibility_status_2026-02-28.md`
- 桥接映射：`/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/docs/legado_native_bridge_mapping.md`
- 执行计划与阶段进度：`/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/docs/plan_e_implementation.md`
