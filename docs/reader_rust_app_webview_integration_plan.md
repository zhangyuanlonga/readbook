# reader-rust 与 App WebView Worker 联动落地计划

更新时间：2026-05-09  
用途：作为 `reader-rust` 服务器化与当前 Flutter App WebView 兜底能力联调、改造、部署的阶段执行清单。  
总计划状态：`方案冻结前`

关联代码与文档：

- `docs/development_architecture_guardrails.md`
- `docs/source_login_execution_plan.md`
- `lib/core/webview/webview_executor.dart`
- `lib/runtime/host/appread_browser_runtime.dart`
- `/Users/zhangyuanlong/Downloads/reader-rust-master`

---

## 1. 结论

建议先 **本地运行联调**，不要一开始部署到服务器。

原因：

- 本方案涉及 `reader-rust`、Flutter App、WebSocket、WebView、cookie、超时、用户授权等多个变量，本地联调能最快定位问题。
- 你的 ECS 当前配置偏低，不适合早期把 Chromium、WebView fallback、代理、日志都堆到服务器上排障。
- 当前 Flutter App 已经具备 `HeadlessInAppWebView`、交互式 WebView、cookie 同步、HTML 抓取、JS 执行能力，优先接成远程 worker 比先部署更有价值。
- 本地闭环跑通后，服务器部署只剩网络、域名、TLS、守护进程、持久化这些工程问题。

本方案目标不是让 App 替代服务器，而是：

```text
reader-rust 处理绝大多数普通书源
App 仅在 WebView 书源、登录验证、复杂 JS 渲染场景下作为兜底执行器
```

---

## 2. 架构目标

目标链路：

```text
外部请求
  ↓
reader-rust API
  ↓
普通书源：reqwest 抓取 + rule_engine 解析
  ↓
WebView 书源：创建 WebViewRenderJob
  ↓
Flutter App WebView Worker 接收任务
  ↓
HeadlessInAppWebView / 交互 WebView 渲染
  ↓
App 回传 html / finalUrl / cookies / scriptResult
  ↓
reader-rust 继续用规则解析结果
```

边界原则：

- 规则解析尽量留在 `reader-rust`，App 不负责解析书源规则。
- App 只负责“像真实用户设备一样打开页面并返回浏览器结果”。
- WebView fallback 必须是可选能力，普通源不能因为 App 不在线而失败。
- 用户 App 执行远程 WebView 任务前必须有授权机制。

---

## 3. 技术可行性

当前 Flutter 项目已有基础：

- `WebViewExecutor` 支持 headless WebView、GET/POST、headers、body、timeout、`webViewDelay`、`webJs`、`sourceRegex`、`overrideUrlRegex`。
- `WebViewExecutor` 已能抓取 `document.documentElement.outerHTML`。
- `AppReadBrowserRuntime` 已经有 session cookie 到 WebView、WebView cookie 回 session 的同步能力。
- `InteractiveVerificationBrowserExecutor` 可承接需要用户手动完成的验证。

reader-rust 侧已有基础：

- 已有 `/reader3/searchBook`、`/reader3/getBookInfo`、`/reader3/getChapterList`、`/reader3/getBookContent` 等接口。
- `book_service.rs` 已经集中承载抓取、解析、缓存主流程。
- `rule_engine.rs` 已经支持 CSS / JSONPath / XPath / Regex / JS 等常规规则。

缺口：

- reader-rust 还没有 WebView Broker。
- reader-rust 还不能将抓取任务下发给 App。
- App 还没有常驻 WebSocket worker 与任务授权 UI。
- 双方还没有统一的 job 协议、cookie 协议、超时/取消协议。

---

## 4. 本地联调拓扑

本地优先使用以下拓扑：

```text
Mac 本机
  ├─ reader-rust: http://127.0.0.1:8080
  ├─ Flutter App: macOS/Android/iOS 任一可运行端
  └─ App WebSocket 连接 reader-rust
```

推荐顺序：

1. 先在 Mac 上 `cargo run` 启动 reader-rust。
2. Flutter App 使用本机或局域网地址连接 reader-rust。
3. Android 模拟器访问 Mac 时使用 `10.0.2.2:8080`。
4. 真机访问 Mac 时使用 Mac 局域网 IP，例如 `http://192.168.x.x:8080`。
5. 本地联调通过后，再考虑 Docker 化 reader-rust。

本地联调必须先验证：

- App 能成功注册为 WebView worker。
- reader-rust 能下发一个固定 URL 渲染任务。
- App 能返回 HTML。
- reader-rust 能拿 HTML 继续走规则解析。
- App 断线、超时、用户拒绝时 reader-rust 能优雅失败。

---

## 5. 协议草案

### 5.1 Worker 注册

App 建立 WebSocket：

```text
GET /reader3/webview/ws?deviceId=xxx&token=xxx
```

App 首包：

```json
{
  "type": "worker.hello",
  "deviceId": "macbook-or-phone-001",
  "appVersion": "1.1.0",
  "platform": "android",
  "capabilities": {
    "headless": true,
    "interactive": true,
    "cookies": true,
    "sourceRegex": true,
    "overrideUrlRegex": true
  }
}
```

服务端响应：

```json
{
  "type": "worker.accepted",
  "workerId": "worker-xxx",
  "heartbeatSeconds": 20
}
```

### 5.2 渲染任务

reader-rust 下发：

```json
{
  "type": "webview.render",
  "jobId": "job-xxx",
  "sourceUrl": "https://example.com",
  "stage": "search",
  "mode": "headless",
  "url": "https://example.com/search?q=test",
  "method": "GET",
  "headers": {},
  "body": null,
  "html": null,
  "webJs": "document.documentElement.outerHTML",
  "sourceRegex": null,
  "overrideUrlRegex": null,
  "waitMs": 1200,
  "timeoutMs": 30000
}
```

App 回传：

```json
{
  "type": "webview.result",
  "jobId": "job-xxx",
  "success": true,
  "statusCode": 200,
  "finalUrl": "https://example.com/search?q=test",
  "html": "<html>...</html>",
  "scriptResult": null,
  "matchedResourceUrl": null,
  "matchedOverrideUrl": null,
  "cookies": [
    {
      "name": "session",
      "value": "xxx",
      "domain": "example.com",
      "path": "/",
      "secure": true,
      "httpOnly": true,
      "expiresAt": 1790000000000
    }
  ]
}
```

失败回传：

```json
{
  "type": "webview.result",
  "jobId": "job-xxx",
  "success": false,
  "errorCode": "user_rejected",
  "errorMessage": "User rejected WebView task."
}
```

### 5.3 取消任务

```json
{
  "type": "webview.cancel",
  "jobId": "job-xxx",
  "reason": "request_timeout"
}
```

---

## 6. reader-rust 改造计划

### 阶段 R0：本地运行基线

目标：

- 不改业务逻辑，先把 reader-rust 本地跑通。

执行清单：

- [ ] 在 `/Users/zhangyuanlong/Downloads/reader-rust-master` 启动 reader-rust
- [ ] 导入至少 5 个普通书源
- [ ] 验证 `/reader3/searchBook`
- [ ] 验证 `/reader3/getBookInfo`
- [ ] 验证 `/reader3/getChapterList`
- [ ] 验证 `/reader3/getBookContent`
- [ ] 记录失败源和失败阶段

阶段完成定义：

- [ ] 常规书源不依赖 App 即可跑通完整链路
- [ ] 形成第一批 WebView 候选书源列表

### 阶段 R1：WebView Broker 骨架

目标：

- reader-rust 能管理 App worker，并能下发测试任务。

建议新增：

```text
src/webview/
  mod.rs
  broker.rs
  protocol.rs
  worker.rs
```

建议新增接口：

```text
GET  /reader3/webview/ws
GET  /reader3/webview/workers
POST /reader3/webview/testRender
```

执行清单：

- [ ] 定义 `WebViewRenderRequest`
- [ ] 定义 `WebViewRenderResponse`
- [ ] 定义 worker 在线状态
- [ ] 实现 WebSocket worker 注册
- [ ] 实现 heartbeat
- [ ] 实现任务分发和 result 回收
- [ ] 实现任务超时
- [ ] 实现 `/reader3/webview/testRender`

阶段完成定义：

- [ ] 不进入书源主流程时，服务端也能独立下发 URL 并拿回 HTML

### 阶段 R2：接入抓取 fallback

目标：

- `book_service.rs` 在指定场景下使用 App WebView 结果替代 reqwest 结果。

执行清单：

- [ ] 增加 source 扩展字段读取，例如 `serverExt.webViewPolicy`
- [ ] 支持 `webViewPolicy = never | app | auto`
- [ ] 支持 `webViewStages = search | bookInfo | toc | content`
- [ ] 在 search 阶段优先接入 fallback
- [ ] 再扩展到 bookInfo / toc / content
- [ ] 保持原 `rule_engine` 解析入口不变
- [ ] 记录 fallback 日志和耗时

阶段完成定义：

- [ ] 同一书源可以选择普通抓取或 WebView 抓取
- [ ] WebView 返回 HTML 后，reader-rust 能继续解析搜索结果

### 阶段 R3：cookie 与登录态

目标：

- WebView 产生的 cookie 能被 reader-rust 后续请求消费。

执行清单：

- [ ] 定义服务端 cookie 存储模型
- [ ] 接收 App 回传 cookies
- [ ] 按 `user + source + domain` 保存 cookies
- [ ] reqwest 请求前注入相关 cookies
- [ ] 支持 App 接收服务端已有 cookies 并写入 WebView
- [ ] 登录类源单独打通一次

阶段完成定义：

- [ ] App WebView 登录或验证后，reader-rust 后续普通请求能复用登录态

---

## 7. Flutter App 改造计划

### 阶段 A0：Worker 配置入口

目标：

- 用户能配置并启用“服务器 WebView 协助”。

执行清单：

- [ ] 新增服务器地址配置
- [ ] 新增设备名称配置
- [ ] 新增访问 token 配置
- [ ] 新增启用开关
- [ ] 新增连接状态展示
- [ ] 新增最近任务列表

建议落点：

```text
lib/features/server_webview/
  application/
  domain/
  presentation/
  data/
  providers.dart
```

阶段完成定义：

- [ ] 用户能看到当前 App 是否已连接 reader-rust

### 阶段 A1：WebSocket worker

目标：

- App 能保持与 reader-rust 的 worker 通道。

执行清单：

- [ ] 建立 WebSocket client
- [ ] 发送 `worker.hello`
- [ ] 处理 heartbeat
- [ ] 接收 `webview.render`
- [ ] 支持 `webview.cancel`
- [ ] 断线自动重连
- [ ] App 进入后台时明确策略：继续、暂停或断开

阶段完成定义：

- [ ] reader-rust 能在 worker 列表看到 App 在线

### 阶段 A2：接入现有 WebViewExecutor

目标：

- 把远程任务映射到现有 `WebViewRequestPayload`。

执行清单：

- [ ] 解析 render task
- [ ] 映射 method / headers / body / html / webJs
- [ ] 映射 sourceRegex / overrideUrlRegex
- [ ] 映射 timeout / waitMs
- [ ] 调用 `WebViewExecutor.load`
- [ ] 把 `WebViewResponsePayload` 转成 result
- [ ] 回传 html / finalUrl / scriptResult / matched url

阶段完成定义：

- [ ] App 能完成 headless WebView 任务并回传 HTML

### 阶段 A3：用户授权与交互验证

目标：

- 避免服务器静默驱动用户设备访问未知页面。

执行清单：

- [ ] 首次绑定服务器时要求用户确认
- [ ] 每个新书源首次使用 App WebView 时要求确认
- [ ] 支持“信任该书源后自动执行”
- [ ] 遇到交互验证时切到交互式 WebView
- [ ] 明确显示任务来源、书源名、目标域名
- [ ] 支持用户拒绝任务

阶段完成定义：

- [ ] 用户能理解当前 App 为什么打开 WebView
- [ ] 用户拒绝后 reader-rust 能收到结构化错误

---

## 8. 本地联调阶段计划

### 阶段 L0：常规服务闭环

```text
reader-rust local
  ↓
普通书源搜索
  ↓
详情 / 目录 / 正文
```

验收：

- [ ] 3 个普通 HTML 源跑通
- [ ] 1 个 JSON API 源跑通
- [ ] 1 个 JS 简单源跑通

### 阶段 L1：固定 URL WebView 任务

```text
reader-rust /testRender
  ↓
App WebView Worker
  ↓
返回 HTML
```

验收：

- [ ] GET URL 成功
- [ ] POST URL 成功
- [ ] headers 生效
- [ ] webJs 生效
- [ ] waitMs 生效
- [ ] timeout 生效

### 阶段 L2：search fallback

```text
/reader3/searchBook
  ↓
标记 source search 需要 WebView
  ↓
App 返回 search HTML
  ↓
reader-rust ruleSearch 解析
```

验收：

- [ ] 一个 WebView 搜索源跑通
- [ ] App 不在线时返回明确错误
- [ ] 用户拒绝时返回明确错误
- [ ] 任务超时时不会卡死搜索请求

### 阶段 L3：详情 / 目录 / 正文 fallback

验收：

- [ ] `getBookInfo` 支持 WebView fallback
- [ ] `getChapterList` 支持 WebView fallback
- [ ] `getBookContent` 支持 WebView fallback
- [ ] reader-rust 缓存仍然有效

### 阶段 L4：cookie 与登录源

验收：

- [ ] App WebView 获取 cookie
- [ ] reader-rust 保存 cookie
- [ ] reader-rust 后续请求带 cookie
- [ ] 登录态过期后能重新触发 App WebView

---

## 9. 部署阶段计划

只有完成本地 `L0-L4` 后再部署。

### 阶段 D0：Docker 化 reader-rust

执行清单：

- [ ] 使用 reader-rust 官方 Dockerfile 或本地构建
- [ ] 挂载 storage 目录
- [ ] 配置日志级别
- [ ] 配置管理员账号
- [ ] 配置反向代理前缀或域名

### 阶段 D1：公网接入

执行清单：

- [ ] 域名与 HTTPS
- [ ] WebSocket 反代
- [ ] 请求体大小限制
- [ ] 超时配置
- [ ] 访问 token
- [ ] CORS 策略收紧

### 阶段 D2：App 连接公网 reader-rust

执行清单：

- [ ] App 配置公网地址
- [ ] 绑定设备 token
- [ ] 验证后台保活策略
- [ ] 验证移动网络与 Wi-Fi 切换
- [ ] 验证断线重连

### 阶段 D3：灰度

执行清单：

- [ ] 只给少量书源开启 `webViewPolicy = app`
- [ ] 记录成功率、平均耗时、失败原因
- [ ] 确认不会影响普通源
- [ ] 再逐步扩大

---

## 10. 风险与处理

### App 不在线

处理：

- `webViewPolicy = auto` 时允许回退普通抓取。
- `webViewPolicy = app` 时返回明确错误：需要打开 App。

### WebView 任务耗时长

处理：

- 每个任务必须有 `timeoutMs`。
- 搜索阶段建议 30 秒以内。
- 交互验证任务可以放宽到 2 分钟。

### 用户隐私

处理：

- App 展示目标域名和书源名。
- 不允许服务器随意下发任意 URL，至少要绑定 source。
- cookie 回传需要用户授权，可提供“仅本源保存”模式。

### 服务器被滥用

处理：

- worker token 必须启用。
- 任务来源必须校验用户和 source。
- 限制每用户并发 WebView 任务数量。

### 规则分叉

处理：

- App 不解析规则。
- reader-rust 仍作为唯一规则解析方。
- WebView 只返回浏览器产物。

---

## 11. 最小可行版本

MVP 只做这些：

- [ ] reader-rust 本地启动
- [ ] App 配置本地 reader-rust 地址
- [ ] WebSocket worker 连接
- [ ] `/reader3/webview/testRender`
- [ ] App 使用 `WebViewExecutor.load` 返回 HTML
- [ ] search 阶段支持手动标记 WebView fallback

MVP 暂不做：

- [ ] 服务端 Playwright
- [ ] 复杂 cookie 持久化
- [ ] 全阶段 fallback
- [ ] 自动识别 WebView 源
- [ ] 多设备调度
- [ ] 公网部署

MVP 完成后，再决定是否进入完整部署。

---

## 12. 推荐下一步

下一步先做本地 PoC：

1. 在 reader-rust 增加最小 `webview/testRender` 与 WebSocket worker。
2. 在 Flutter App 增加最小 worker 连接服务。
3. 用固定 URL 验证 App 能返回 HTML。
4. 再把这个能力接入一个 `ruleSearch` 失败的真实书源。

通过这一步以后，再谈服务器部署就很稳了。
