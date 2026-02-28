# Legado 原生 Bridge 映射（源码对齐版）

> 目标：只服务兼容引擎/数据链路，不涉及 UI 设计改造。
> 基准源码：
> - `/Users/zhangyuanlong/storage/FlutterProject/legado-master/app/src/main/java/io/legado/app/help/JsExtensions.kt`
> - `/Users/zhangyuanlong/storage/FlutterProject/legado-master/app/src/main/java/io/legado/app/help/JsEncodeUtils.kt`
> - `/Users/zhangyuanlong/storage/FlutterProject/legado-master/app/src/main/java/io/legado/app/model/analyzeRule/AnalyzeUrl.kt`
> - `/Users/zhangyuanlong/storage/FlutterProject/legado-master/app/src/main/java/io/legado/app/model/analyzeRule/AnalyzeRule.kt`
> - `/Users/zhangyuanlong/storage/FlutterProject/legado-master/app/src/main/assets/web/help/md/jsHelp.md`

## 状态定义

- `full`：语义与 Legado 基本一致，可作为主线能力。
- `partial`：已识别/可调用，但语义不完整、上下文受限或为降级实现。
- `unsupported`：当前明确不支持（安全或实现成本原因）。

## 高优先级映射

| bridge | Legado 归属 | Legado 语义 | appread 当前 | 优先级 |
|---|---|---|---|---|
| `java.ajax` | `JsExtensions.ajax` | 网络请求，返回 body 字符串 | `full` | P1 |
| `java.ajaxAll` | `JsExtensions.ajaxAll` | 并发请求，返回 `Array<StrResponse>` | `full`（返回 response 对象数组，保留 `toString()->body`） | P0（已完成） |
| `java.connect` | `JsExtensions.connect` | 返回 `StrResponse`（含 code/headers 等） | `full`（返回 response 对象，支持 `get/post/head/execute`） | P0（已完成） |
| `java.get` | `JsExtensions.get` | 返回 `Connection.Response` | `full`（网络分支返回 response 对象，变量读取分支保持兼容） | P0（已完成） |
| `java.head` | `JsExtensions.head` | HEAD 请求返回 `Connection.Response` | `full`（已对齐为 HEAD 请求 response 对象） | P0（已完成） |
| `java.post` | `JsExtensions.post` | POST 返回 `Connection.Response` | `full`（返回 response 对象，`toString()->body` 兼容） | P0（已完成） |
| `java.initUrl` | `AnalyzeUrl.initUrl` | 仅登录检查 JS 场景重解析 URL | `partial`（通用脚本可调，语义有偏差） | P0 |
| `java.getStrResponse` | `AnalyzeUrl.getStrResponse` | 登录检查场景返回 `StrResponse` | `partial`（本地状态模拟） | P0 |
| `java.getResponse` | `AnalyzeUrl.getResponse` | 返回原生 HTTP Response | `partial`（识别但未对齐实现） | P1 |
| `java.refreshTocUrl` | `AnalyzeRule.refreshTocUrl` | `preUpdateJs` 场景触发重取目录 URL | `partial`（已补上下文诊断 + 可回退别名语义） | P0（已完成） |
| `java.reGetBook` | `AnalyzeRule.reGetBook` | `preUpdateJs` 场景重搜书并刷新信息 | `partial`（已补上下文诊断 + bookUrl 回传降级） | P0（已完成） |
| `java.cacheFile` | `JsExtensions.cacheFile` | 下载并按时间缓存文本文件 | `full`（md5 key + TTL + `cache.delete` 失效已对齐） | P0（已完成） |
| `java.importScript` | `JsExtensions.importScript` | 网络缓存或本地文件读取脚本 | `partial`（网络缓存对齐；本地文件读取仍未支持） | P0（已完成） |
| `java.webView` | `JsExtensions.webView` | 后台 WebView 执行并返回结果 | `partial`（已接入 JS bridge -> `WebViewExecutor`，支持 `html/url/js` 与 `scriptResult` 回传） | P1（已完成） |
| `java.webViewGetSource` | `JsExtensions.webViewGetSource` | WebView 抓资源 URL | `partial`（已接入 `sourceRegex` 回填） | P1（已完成） |
| `java.webViewGetOverrideUrl` | `JsExtensions.webViewGetOverrideUrl` | WebView 抓跳转 URL | `partial`（已接入 `overrideUrlRegex` 回填） | P1（已完成） |
| `java.startBrowser` | `JsExtensions.startBrowser` | 打开验证浏览器 | `partial`（降级为后台 WebView 预执行，不拉起 UI） | P1（已完成） |
| `java.startBrowserAwait` | `JsExtensions.startBrowserAwait` | 等待浏览器验证结果 | `partial`（已返回 `StrResponse` 风格对象；无人工交互流程） | P1（已完成） |
| `java.getVerificationCode` | `JsExtensions.getVerificationCode` | 弹验证码输入并返回结果 | `partial`（返回空字符串） | P0 |
| `java.createSymmetricCrypto` | `JsEncodeUtils.createSymmetricCrypto` | 对称加解密对象 | `full` | P1 |
| `java.createAsymmetricCrypto` | `JsEncodeUtils.createAsymmetricCrypto` | 非对称加解密对象 | `partial`（识别，未实装） | P0 |
| `java.createSign` | `JsEncodeUtils.createSign` | 签名对象 | `partial`（识别，未实装） | P1 |

## 已归入 full 的稳定桥接（摘要）

- 规则解析桥：`setContent/getString/getStringList/getElements/getElement`
- 变量与日志：`put/log`（`get` 变量读取分支保持兼容）
- 网络响应桥：`get/head/post/connect/ajaxAll`（统一 response 对象语义，保留字符串拼接兼容）
- 编解码与哈希：`base64*`, `md5*`, `hex*`, `digestHex`, `hmac*`, `encodeURI`
- 时间与文本：`timeFormat/timeFormatUTC`, `toNumChapter`, `htmlFormat`, `t2s/s2t`
- 标识与 URL：`randomUUID`, `androidId/deviceID`, `toURL/toUrl`
- 缓存：`cacheFile`（远端缓存 + 失效控制）
- AES/legacy AES 兼容方法：`aes*`, `aesDecodeArgsBase64Str`, `desEncodeToBase64String`

## 明确 unsupported（保留安全边界）

- 文件/压缩包相关：`readFile/getFile/readTxtFile/deleteFile/downloadFile/unzipFile/unrarFile/un7zFile/unArchiveFile/getTxtInFolder/get*StringContent/get*ByteArrayContent`
- 字体反爬相关：`queryTTF/queryBase64TTF/replaceFont`

## 执行原则

1. `full` 才能计入“完全兼容”。
2. `partial` 一律计入“非 full”，并在矩阵中输出 `partial_bridge.*` 原因。
3. 后续每次 bridge 改造，先对齐本表，再改代码与回归。
