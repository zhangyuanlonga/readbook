# 书源登录专项审查与改造计划

日期：2026-06-22

状态：专项审查完成，待评审与排期

参考范围：

- 当前 Flutter 项目：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook`
- Rust 书源网关：`/Users/zhangyuanlong/storage/FlutterProject/reader-rust-master`
- MD3 参考项目：`/Users/zhangyuanlong/Downloads/legado-with-MD3-main-xin`
- own 参考项目：`/Users/zhangyuanlong/Downloads/legado-own`

## 1. 结论

当前项目已经有书源登录的底层骨架，但还没有形成面向用户可用的完整闭环。

已具备的能力：

- Flutter 有 WebView 登录页，可以打开书源登录地址并提交 Cookie/localStorage。
- Flutter 有 `SourceRuntimeSessionService`，已经能调用网关的登录任务、会话提交、会话读取、会话清除接口。
- 阅读器内容加载失败时，已经能识别 `LOGIN_REQUIRED` 和 `WEBVIEW_REQUIRED`，并跳转到网页登录或 WebView 协作页。
- Rust 网关已经有 session 存储、Cookie 存储、登录任务、WebView 任务、登录结果提交接口。
- Rust 请求链路已经会把 runtime session 的 header/cookie 注入书源请求。
- Rust 搜索、发现、详情、目录、正文等链路已经有 `loginCheckJs` 执行点。

主要缺口：

- 用户在书源管理、发现、搜索、详情页缺少主动登录入口。
- Flutter 只实现了 WebView 登录，没有实现 MD3 的 `loginUi` 表单登录。
- Flutter 看不到当前书源会话状态，也不能在界面里清除/重登/手动补会话。
- Rust JS bridge 里的 `source.getLoginInfo()`、`source.getLoginHeaderMap()` 仍是空实现或近似空实现。
- Rust JS bridge 里的 `source.putLoginHeader()` 没有闭环写入 runtime session，请求不会稳定继承 JS 登录后写入的 header。
- Rust 尚未把已保存的 `loginInfoJson/sourceVariableJson/loginHeaderJson` 注入 JS 执行上下文。
- MD3 支持 `source.login()` 触发登录规则、按钮 JS 动态刷新登录 UI，我们目前还没有完整等价能力。

上线可用角度判断：

- 只依赖普通 WebView Cookie 的书源：现在已有基础能力，但入口不足，用户很难发现。
- 依赖 `loginUi`、`loginInfo`、`loginHeader`、`source.login()` 的书源：当前能力不足，不能按 MD3 兼容口径承诺可用。
- 依赖 `loginCheckJs` 自动判断登录并重取响应的书源：当前有检测点，但 JS bridge 和会话写回不完整，复杂场景会失败。

## 2. 当前 Flutter 能力

### 2.1 已有服务

`lib/features/source/application/source_runtime_session_service.dart`

已有接口封装：

- `GET /api/v1/sources/{id}/session`
- `GET /api/v1/sources/{id}/login-task`
- `PUT /api/v1/sources/{id}/session`
- `POST /api/v1/sources/{id}/login-result`
- `DELETE /api/v1/sources/{id}/session`

服务模型已有：

- `SourceLoginTask`
- `SourceLoginRequestSnapshot`
- `SourceRuntimeSessionSnapshot`

可见状态包括：

- `hasCookie`
- `hasHeaders`
- `hasLoginInfo`
- `hasSourceVariable`
- `headerNames`
- `cookieScope`
- `sessionPolicy`
- `ttlSeconds`
- `updatedAt`

问题：

- 这些能力目前没有成为书源管理页的常规 UI。
- `SourceLoginTask` 只解析了 `taskId/sourceId/sourceName/mode/loginUrl/request`，没有解析网关已返回的 `loginUi/loginUiRaw/loginUiKind/loginCheckJs/requiredReturns/sessionPolicy/enabledCookieJar`。
- 业务层还没有统一的“书源登录状态模型”，已有 `SourceLoginState` 目前基本停留在实体和测试层。

### 2.2 WebView 登录页

`lib/features/source/presentation/source_webview_login_page.dart`

当前流程：

- 如果路由传入 `loginUrl`，直接打开。
- 如果没有传入 `loginUrl`，调用 `createLoginTask()` 获取任务。
- 使用 `webview_flutter` 打开登录页。
- 用户登录后点击“提交会话”。
- 页面读取 `document.cookie` 和 `localStorage`。
- 调用 `submitLoginResult()` 提交给 Rust 网关。

问题：

- 只支持 WebView 登录，不支持 `loginUi` 表单。
- Cookie 只能读 `document.cookie` 可见部分，HttpOnly Cookie 依赖平台 WebView CookieManager 时会弱一些。
- 没有执行 `loginCheckJs` 来即时校验登录是否成功。
- 没有显示会话提交后的具体状态，例如是否有 Cookie、Header、loginInfo、sourceVariable。
- 没有“重新登录/清除登录态/查看登录头”的完整操作。

### 2.3 阅读器失败恢复

`lib/features/reader/application/reader_failure_presentation_service.dart`

`lib/features/reader/presentation/reader_page.dart`

当前流程：

- `LOGIN_REQUIRED` 展示“网页登录”。
- `WEBVIEW_REQUIRED` 展示“WebView 渲染”。
- 用户点击后跳转 `/source/webview-login` 或 `/source/webview-task`。
- 登录或 WebView 协作完成后重新 bootstrap 阅读器。

问题：

- 只覆盖阅读器正文失败。
- 搜索、发现、详情、目录失败时没有同样的恢复动作。
- 阅读器传给登录页的 `sourceName` 目前偏书名，不一定是书源名，用户识别会弱。

### 2.4 书源管理入口

`lib/features/mine/presentation/widgets/private_book_source_more_menu_button.dart`

当前菜单：

- 详情
- 检测
- 提交共享
- 编辑
- 删除

问题：

- 没有“登录书源”。
- 没有“会话状态”。
- 没有“清除登录态”。
- `PrivateBookSourceItem` 没有直接暴露 `loginUrl/loginUi/loginCheckJs/enabledCookieJar/hasLogin` 等摘要字段，菜单无法判断是否展示登录项。
- 只能通过阅读器失败被动进入，无法在书源配置或测试阶段主动完成登录。

### 2.5 搜索/发现/详情入口

当前情况：

- 搜索失败 banner 只展示失败明细和 action hint，没有登录按钮。
- 发现页能展示网关 failure 文案，但没有登录当前书源的动作。
- 详情页目录/详情失败有诊断与换源，但没有登录恢复入口。

问题：

- 用户在“找书”和“看详情”阶段遇到登录失败，只能猜测原因，无法原地恢复。
- 这会让需要登录的书源看起来像“不可用书源”，影响可用感。

## 3. 当前 Rust 网关能力

### 3.1 已有接口

`/Users/zhangyuanlong/storage/FlutterProject/reader-rust-master/src/api/v1.rs`

已确认接口：

- `GET /api/v1/sources/:id/login-task`
- `POST /api/v1/sources/:id/login-result`
- `POST /api/v1/sources/:id/webview-task`
- `POST /api/v1/webview/resolve`
- `GET /api/v1/sources/:id/session`
- `PUT /api/v1/sources/:id/session`
- `DELETE /api/v1/sources/:id/session`

`build_login_task()` 已返回：

- `loginUrl`
- `loginUi`
- `loginUiRaw`
- `loginUiKind`
- `loginCheckJs`
- `requiredReturns`
- `sessionPolicy`
- `enabledCookieJar`
- `request`

问题：

- Flutter 当前没有消费这些完整字段。
- `loginUiKind = js/json/raw` 的后续执行协议还没有在客户端落地。

### 3.2 session 存储和请求注入

`/Users/zhangyuanlong/storage/FlutterProject/reader-rust-master/src/service/book_service.rs`

已具备：

- `SourceRuntimeSession`
- `SourceRuntimeSessionSummary`
- `upsert_source_session()`
- `clear_source_session()`
- `source_session_summary()`
- `apply_source_session_headers()`
- `apply_source_cookie()`

请求准备流程：

1. 应用请求策略。
2. 应用书源 header 规则。
3. 应用 runtime session headers。
4. 应用 runtime cookie。

这是正确方向，说明后续主要不是重建网关，而是补齐 JS bridge 和前端入口。

### 3.3 loginCheckJs

Rust 已在搜索、发现、详情、目录、正文等多处调用 `apply_login_check()` 或 `apply_search_login_check()`。

当前行为：

- `true/loggedIn/logged_in` 保持原响应。
- `false/login_required/need_login/未登录/需要登录` 转为登录失败。
- 其他非空字符串按替换后的响应 body 使用。
- JSON 中 `loginRequired/requiresLogin/needLogin/unauthenticated/isGuest` 为 true 时判定需要登录。

问题：

- MD3 的 `loginCheckJs` 执行时，`result` 是 `StrResponse`，JS 可以拿响应、调用 `source.login()`、改 header、再 `java.getResponse()` 或 `getStrResponseAwait()`。
- Rust 目前给 `eval_js()` 的 `result` 主要是响应 body 字符串，不是完整 `StrResponse` 等价对象。
- Rust 的 `source.getLoginInfo/getLoginHeaderMap` 当前没有读已保存 session。
- Rust 的 `source.putLoginHeader` 目前只写入 JS 内存 KV，没有可靠持久化到 runtime session。
- 因此复杂登录检测只能做“判断失败/替换 body”，不能完整模拟 MD3 的“检测、登录、更新 header、重试”。

### 3.4 JS bridge

`/Users/zhangyuanlong/storage/FlutterProject/reader-rust-master/src/parser/js.rs`

已具备：

- `source.key/bookSourceUrl/bookSourceName/header/loginUrl`
- `source.getKey()`
- `source.getVariable()/source.setVariable()`
- `cookie.getCookie/setCookie/replaceCookie/removeCookie`
- `cache.get/put/delete`
- `java.ajax/java.get/java.post/java.put/java.connect`
- 若干加解密、编码、HTML 提取辅助函数

缺口：

- `source.getLoginInfo()` 当前返回 `{}`。
- `source.getLoginInfoMap()` 当前返回 `None`。
- `source.getLoginHeaderMap()` 当前返回 `None`。
- `source.putLoginHeader()` 没有写入 `SourceRuntimeSession`。
- 缺少 `source.putLoginInfo()/removeLoginInfo()` 等价能力。
- 缺少 `source.login()` 等价能力。
- `source.getVariable()` 使用内存 JS 变量，不等价于 Rust 持久 session 中的 `sourceVariableJson`。
- 缺少 MD3 常见的 `java.getResponse/getStrResponse/initUrl/getHeaderMap` 同名兼容入口。

## 4. MD3/Legado 登录模型

### 4.1 登录入口

MD3 主要入口：

- 书源列表更多菜单：有 `loginUrl` 时显示“登录”。
- 书源编辑页：可编辑并测试 `loginUrl/loginUi/loginCheckJs`。
- 阅读器顶部书源菜单：当前书源有登录地址时可直接登录。
- RSS/TTS 等源也复用同一套登录模型。

关键参考文件：

- `SourceLoginActivity.kt`
- `BookSourceAdapter.kt`
- `ReadBookMenuBar.kt`

### 4.2 登录模式

MD3 的 `SourceLoginActivity` 根据 `loginUi` 分流：

- 没有 `loginUi`：打开 `WebViewLoginFragment`。
- 有 `loginUi`：打开 `SourceLoginDialog` 表单。

这点是目前 Flutter 与 MD3 最大的用户体验差距。

### 4.3 loginUi 表单能力

MD3 支持：

- `text`
- `password`
- `select`
- `button`
- `toggle`
- `@js:` 或 `<js>` 动态生成 UI。
- 按钮 action 可执行 JS 或打开 URL。
- JS 可调用 `upLoginData()` 更新表单数据。
- JS 可调用 `reLoginView()` 重新渲染登录 UI。

当前 Flutter 没有这些。

### 4.4 登录数据存储

MD3 的 `BaseSource` 提供：

- `getLoginHeader()`
- `getLoginHeaderMap()`
- `putLoginHeader()`
- `removeLoginHeader()`
- `getLoginInfo()`
- `getLoginInfoMap()`
- `putLoginInfo()`
- `removeLoginInfo()`
- `putVariable()/getVariable()`

行为特点：

- `putLoginHeader()` 如果发现 Cookie，会同步写入 `CookieStore`。
- 请求时 `getHeaderMap(true)` 自动合并 loginHeader。
- `loginInfo` 加密存储。
- `sourceVariable` 是持久源变量，可被 JS 读取。

当前 Rust 有字段和存储，但 JS bridge 没打通到这些字段。

### 4.5 请求与 Cookie

MD3 的 `AnalyzeUrl`：

- 初始化时通过 `source.getHeaderMap(true)` 合并登录头。
- 请求前 `setCookie()` 从 `CookieStore` 合并 Cookie。
- `enabledCookieJar` 会让请求保存并复用 Cookie。
- 请求后 `saveCookie()` 将 CookieJar 中 Cookie 落回 CookieStore。

当前 Rust：

- 已经能按 source 或 host 保存 Cookie。
- 已经能向请求注入 Cookie/header。
- 但 Flutter WebView Cookie 与 Rust CookieStore 的双向同步能力还不完整。

### 4.6 loginCheckJs

MD3 的 `WebBook` 在搜索、发现、详情、目录、正文后执行 `loginCheckJs`：

- `result` 是 `StrResponse`。
- JS 可以返回新的 `StrResponse`。
- JS 可以调用源对象方法读取/写入登录信息。
- JS 可以通过 `AnalyzeUrl`/`java` 发起请求。

当前 Rust：

- 有 `loginCheckJs` 执行点。
- 但执行上下文和会话 API 不完整。
- 适合先补“兼容常用书源”的最小闭环，再扩展到完整 MD3 兼容层。

## 5. 用户场景差距

### 5.1 用户导入一个需要登录的书源

期望：

- 书源列表直接看到“登录”。
- 登录完成后能看到“已登录/有 Cookie/有 Header”。
- 搜索、发现、阅读都自动使用登录态。

当前：

- 书源列表没有登录入口。
- 只有阅读器失败后才可能被动出现网页登录。
- 登录后用户看不到状态。

### 5.2 书源使用 loginUi 表单登录

期望：

- 弹出账号密码/选项/按钮表单。
- 保存 loginInfo。
- 点击登录后执行 source.login 或按钮 JS。
- 写入 loginHeader/cookie。

当前：

- Flutter 不渲染 `loginUi`。
- Rust 不支持完整 `source.login()` 和 session 写回。

### 5.3 搜索或发现遇到登录失败

期望：

- 异常项直接给“登录该书源”按钮。
- 登录后返回并重试当前搜索/发现。

当前：

- 只显示异常说明。
- 用户需要离开当前场景，且不知道应该做什么。

### 5.4 登录态失效

期望：

- 识别 `LOGIN_REQUIRED`。
- 提示“重新登录”。
- 可清除旧登录态。

当前：

- 阅读器可进入 WebView。
- 其他页面缺少一致处理。
- 没有会话状态页和清除入口。

## 6. 改造原则

- 先补用户可见闭环，再补完整兼容。
- Flutter 只负责登录交互和结果提交，书源规则执行仍放 Rust。
- Rust 负责 session 注入、JS bridge 兼容、loginCheckJs 结果归因。
- 以 MD3 的源 API 为兼容目标，但不照搬 Android UI。
- 每个入口都要能回到原业务场景并触发重试。
- 不把登录态长期明文散落在 Flutter 本地，优先交给 Rust session 管理。

## 7. 分阶段任务

### 阶段 0：能力口径与数据模型

- [ ] 定义统一的书源登录能力模型：`hasLoginUrl`、`hasLoginUi`、`hasLoginCheckJs`、`enabledCookieJar`、`sessionSummary`。
- [ ] 扩展 Flutter `SourceLoginTask`，解析 `loginUi/loginUiRaw/loginUiKind/loginCheckJs/requiredReturns/sessionPolicy/enabledCookieJar`。
- [ ] 将 `SourceRuntimeSessionSnapshot` 与 `SourceLoginState` 关系梳理清楚，避免两个模型各走各的。
- [ ] 给私有书源列表返回值补充登录能力摘要，至少要能判断是否显示“登录”。
- [ ] 给发现书源摘要补充登录能力摘要，支持发现页源卡片展示登录动作。
- [ ] 给搜索失败、发现失败、详情失败统一标记 `LOGIN_REQUIRED/WEBVIEW_REQUIRED` 的恢复动作。

完成进度：0/6

### 阶段 1：书源管理主动登录入口

- [ ] 在书源更多菜单增加“登录书源”。
- [ ] 在书源更多菜单增加“登录状态”。
- [ ] 在书源更多菜单增加“清除登录态”。
- [ ] 登录入口优先调用 `GET /login-task`，由任务决定打开 WebView 还是 loginUi 表单。
- [ ] 登录完成后刷新该书源 session 摘要。
- [ ] 书源检测失败为登录态问题时，检测结果页提供“登录后重测”。

完成进度：0/6

### 阶段 2：统一登录恢复入口

- [ ] 搜索失败明细中对 `LOGIN_REQUIRED` 增加“登录”按钮。
- [ ] 搜索失败明细中对 `WEBVIEW_REQUIRED` 增加“WebView 协作”按钮。
- [ ] 发现页分类加载失败时增加“登录/协作/重试”动作。
- [ ] 详情页详情失败时增加“登录/协作/重试”动作。
- [ ] 详情页目录失败时增加“登录/协作/重试”动作。
- [ ] 阅读器登录入口传入书源名，而不是书名。
- [ ] 登录返回后自动重试当前业务动作。

完成进度：0/7

### 阶段 3：会话状态与清理 UI

- [ ] 增加书源会话状态弹窗或页面。
- [ ] 展示 Cookie 状态。
- [ ] 展示 Header 状态和 header name 列表，不展示敏感值。
- [ ] 展示 loginInfo 状态。
- [ ] 展示 sourceVariable 状态。
- [ ] 展示 cookieScope/sessionPolicy/ttlSeconds/updatedAt。
- [ ] 支持清除登录态。
- [ ] 支持重新登录。
- [ ] 清除后立即刷新状态和源健康状态。

完成进度：0/9

### 阶段 4：loginUi 表单登录

- [ ] Flutter 新增 `SourceLoginPage`，作为 WebView 和表单登录的统一入口。
- [ ] 支持 `loginUiKind=json` 的字段解析。
- [ ] 支持 `text` 字段。
- [ ] 支持 `password` 字段。
- [ ] 支持 `select` 字段。
- [ ] 支持 `toggle` 字段。
- [ ] 支持 `button` 字段的基础展示。
- [ ] 保存表单数据为 `loginInfoJson` 并提交 Rust。
- [ ] 提交后调用 Rust 登录执行接口或 session 提交接口。
- [ ] 登录成功后展示 session 摘要。

完成进度：0/10

### 阶段 5：loginUi 动态 JS 能力

- [ ] Rust 提供 `loginUi` JS 预执行接口，将 `@js:`/`<js>` 转为表单 JSON。
- [ ] Flutter 对 `loginUiKind=js` 先调用 Rust 执行，拿到表单 JSON。
- [ ] 支持按钮 action 执行 JS。
- [ ] 支持 JS 更新登录数据，等价 `upLoginData()`。
- [ ] 支持 JS 触发重新渲染，等价 `reLoginView()`。
- [ ] 支持按钮 action 打开 URL。
- [ ] 支持按钮长按参数 `isLongClick`。
- [ ] 表单 JS 执行错误展示可复制诊断。

完成进度：0/8

### 阶段 6：Rust source 登录 API 补齐

- [ ] `JsSourceContext` 增加 `loginInfoJson/loginHeaderJson/sourceVariableJson/runtimeHeaders/runtimeCookie`。
- [ ] `source.getLoginInfo()` 读取 session 中的 `loginInfoJson`。
- [ ] `source.getLoginInfoMap()` 返回 loginInfo map。
- [ ] `source.putLoginInfo()` 写入 runtime session。
- [ ] `source.removeLoginInfo()` 清除 loginInfo。
- [ ] `source.getLoginHeader()` 读取 session headers JSON。
- [ ] `source.getLoginHeaderMap()` 返回 header map。
- [ ] `source.putLoginHeader()` 写入 runtime session headers，并同步 Cookie。
- [ ] `source.removeLoginHeader()` 清除 runtime session headers 和对应 Cookie。
- [ ] `source.getVariable()` 读取持久 `sourceVariableJson`。
- [ ] `source.putVariable()` 写入持久 `sourceVariableJson`。
- [ ] 补齐 `source.login()`，执行 `loginUrl` 中的 JS 登录逻辑或登录请求。

完成进度：0/12

### 阶段 7：Rust loginCheckJs 兼容增强

- [ ] 给 `loginCheckJs` 的 `result` 提供 StrResponse 等价对象。
- [ ] 支持 JS 返回 StrResponse 等价对象并替换响应。
- [ ] 支持 `loginCheckJs` 中读取 loginInfo/loginHeader/sourceVariable。
- [ ] 支持 `loginCheckJs` 中写入 loginHeader 后立刻重试请求。
- [ ] 补齐常用 `java.getResponse()` 兼容入口。
- [ ] 补齐常用 `java.getStrResponse()` 兼容入口。
- [ ] 补齐常用 `java.initUrl()` 兼容入口。
- [ ] 补齐常用 `java.getHeaderMap()` 兼容入口。
- [ ] 将 loginCheck 的失败归因稳定映射为 `LOGIN_REQUIRED`。
- [ ] 为搜索、发现、详情、目录、正文分别补 loginCheck 回归测试。

完成进度：0/10

### 阶段 8：WebView Cookie 与 HttpOnly Cookie

- [ ] 调研 `webview_flutter` 当前平台是否能读取 CookieManager 全量 Cookie。
- [ ] Android/iOS/macOS 分别确认 HttpOnly Cookie 获取能力。
- [ ] 如果 WebView JS 读不到 HttpOnly Cookie，增加平台 CookieManager 读取桥。
- [ ] 登录页提交时合并 `document.cookie` 和平台 CookieManager Cookie。
- [ ] WebView 登录完成后用 `loginCheckJs` 或 session summary 做成功校验。
- [ ] WebView task 的 localStorage/sourceVariable 映射策略文档化。

完成进度：0/6

### 阶段 9：样本与验收

- [ ] 准备普通 WebView Cookie 登录样本。
- [ ] 准备 HttpOnly Cookie 登录样本。
- [ ] 准备 loginUi text/password 样本。
- [ ] 准备 loginUi select/toggle/button 样本。
- [ ] 准备 loginUi `@js:` 动态 UI 样本。
- [ ] 准备 `source.putLoginHeader()` 样本。
- [ ] 准备 `source.login()` 样本。
- [ ] 准备 `loginCheckJs` 自动判断登录失效样本。
- [ ] 验收搜索登录恢复。
- [ ] 验收发现登录恢复。
- [ ] 验收详情登录恢复。
- [ ] 验收目录登录恢复。
- [ ] 验收阅读器登录恢复。
- [ ] 验收清除登录态后重新登录。

完成进度：0/14

## 8. 推荐实施顺序

建议顺序：

1. 先做阶段 0-3，让用户能找到入口、看到状态、能清理和重登。
2. 再做阶段 6-7，让 Rust 真正兼容 MD3 登录 API。
3. 再做阶段 4-5，让 Flutter 支持 loginUi 表单和动态 JS。
4. 最后做阶段 8-9，把 WebView Cookie 和样本验收补齐。

原因：

- 阶段 0-3 能快速解决“用户不知道怎么登录”的可用性问题。
- 阶段 6-7 是复杂书源能否真正可用的关键。
- 阶段 4-5 依赖 Rust 的登录 API，否则表单只能提交数据，不能完成登录闭环。
- 阶段 8-9 决定上线稳定性和回归信心。

## 9. 可上线口径

如果只完成阶段 0-3：

- 可宣称支持基础 WebView 书源登录。
- 不应宣称完整兼容 Legado/MD3 登录书源。
- 遇到 `loginUi/source.login/loginHeader` 类书源仍可能不可用。

如果完成阶段 0-7：

- 可宣称支持主流 Legado 登录模型的主要能力。
- 仍需通过样本验收确认 WebView Cookie 与平台差异。

如果完成阶段 0-9：

- 可作为“书源登录功能可上线”的标准。
- 后续只需要针对个别书源补兼容点和样本。
