# 书源登录兼容计划

日期：2026-06-22

状态：阶段 0-10 Flutter 可执行部分已完成，Rust 兼容接口待执行

本轮执行范围：阶段 0-10 已完成 Flutter 侧能力模型、主动入口、统一登录入口页、会话状态弹窗、WebView 登录补强、静态 loginUi 表单、动态 loginUi 诊断与 URL button、登录失败恢复入口、验收样本清单。Rust 网关摘要字段、平台 CookieManager、`loginCheckJs` 校验、动态 loginUi JS 执行、`source.login()` 与 `source.getLoginInfo()` 等兼容仍留在后续阶段，因为当前工程只改 Flutter 主仓，`reader-rust-master` 不在本轮可写范围内。

关联审查文档：

- `docs/features/source/source-login-gap-review-2026-06-22.md`
- `docs/features/source/source-login-rust-compatibility-contract-2026-06-22.md`
- `docs/features/source/source-login-acceptance-samples-2026-06-22.md`

## 1. 目标

把当前“已有 WebView 登录骨架”升级成“主流 Legado/MD3 书源登录可用”的闭环能力。

目标不是到处增加登录按钮，而是让用户在需要登录书源时，能用最短路径完成登录，并且登录态能被搜索、发现、详情、目录、阅读器正文等链路稳定复用。

## 2. 入口结论

第一版主动入口只保留两个：

- 发现页：当前书源或书源卡片提供“登录”。
- 我的书源：列表中该书源右侧“更多”菜单提供“登录”。

这个入口设计是够的。

原因：

- 用户主动探索书源时，最自然的位置是发现页。
- 用户管理、检测、编辑书源时，最自然的位置是我的书源列表。
- 不建议在搜索结果、详情页、阅读器顶部都放常驻登录按钮，否则入口会变散，用户也难判断应该在哪里管理登录态。

但需要保留被动恢复：

- 阅读器正文遇到 `LOGIN_REQUIRED` 时，继续展示“网页登录/去登录”恢复动作。
- 发现页当前源加载失败遇到 `LOGIN_REQUIRED` 时，展示“登录后重试”。
- 搜索、详情、目录遇到 `LOGIN_REQUIRED` 时，不做常驻入口，只在错误态提供一次性恢复动作或跳转到对应书源登录页。

换句话说：

- 主动入口：发现页 + 我的书源更多菜单。
- 错误恢复：谁失败谁提供一次性“去登录/重试”。
- 登录状态管理：回到我的书源更多菜单统一处理。

## 3. 范围边界

本计划包含：

- Flutter 入口、状态、登录页、表单 UI。
- Rust 网关 session、Cookie、loginInfo、loginHeader、sourceVariable 兼容。
- Legado/MD3 常见登录 API 兼容。
- WebView Cookie 和 HttpOnly Cookie 补强。
- 后续云端/本地双模式的最小架构边界。
- 样本验收。

本计划不包含：

- 新增全局账号系统。
- 把书源登录态长期明文存 Flutter 本地。
- 在所有页面都放常驻登录按钮。
- 重新设计书源编辑器。
- 做书源规则调试器完整替代 MD3。
- 当前阶段直接把 Rust 网关整体重构成 Flutter 本地库。

## 4. 用户路径

### 4.1 在发现页登录

1. 用户进入发现页。
2. 用户选择一个需要登录的书源。
3. 页面展示“登录”入口。
4. 用户完成 WebView 或 loginUi 表单登录。
5. 返回发现页。
6. 当前分类自动刷新。

验收标准：

- 登录前能看出该源需要登录或可登录。
- 登录后能回到原来的发现位置。
- 登录成功后不需要用户手动重新选源。

### 4.2 在我的书源登录

1. 用户进入我的书源。
2. 点击某个书源右侧更多。
3. 点击“登录”。
4. 登录完成后返回列表。
5. 更多菜单或状态弹窗能看到已保存的会话摘要。

验收标准：

- 支持登录。
- 支持重新登录。
- 支持查看会话状态。
- 支持清除登录态。

### 4.3 失败态恢复

1. 搜索、发现、详情、目录、阅读器正文请求返回 `LOGIN_REQUIRED`。
2. 当前页面只展示一次性“去登录”或“登录后重试”。
3. 用户登录完成后，自动重试刚刚失败的动作。

验收标准：

- 不需要用户自己去找入口。
- 不新增常驻按钮。
- 登录后能回到原业务上下文。

## 5. 阶段任务

### 阶段 0：统一能力模型

- [ ] 扩展 Rust 书源摘要，返回 `hasLoginUrl`。
- [ ] 扩展 Rust 书源摘要，返回 `hasLoginUi`。
- [ ] 扩展 Rust 书源摘要，返回 `hasLoginCheckJs`。
- [ ] 扩展 Rust 书源摘要，返回 `enabledCookieJar`。
- [x] Flutter 私有书源模型补齐登录能力字段。
- [x] Flutter 发现书源模型补齐登录能力字段。
- [x] Flutter `SourceLoginTask` 解析 `loginUi`。
- [x] Flutter `SourceLoginTask` 解析 `loginUiRaw`。
- [x] Flutter `SourceLoginTask` 解析 `loginUiKind`。
- [x] Flutter `SourceLoginTask` 解析 `loginCheckJs`。
- [x] Flutter `SourceLoginTask` 解析 `requiredReturns`。
- [x] Flutter `SourceLoginTask` 解析 `enabledCookieJar`。
- [x] Flutter `SourceLoginTask` 解析 `sessionPolicy`。
- [x] 定义统一的 `SourceLoginCapability` 或等价领域模型。
- [x] 定义统一的 `SourceSessionSummary` UI 展示模型。

完成进度：11/15

说明：Flutter 侧已经兼容解析 Rust 未来可能返回的能力字段；Rust 侧摘要字段补齐留到后续在 `reader-rust-master` 中执行。

### 阶段 1：主动入口

- [x] 我的书源更多菜单增加“登录”。
- [x] 我的书源更多菜单增加“登录状态”。
- [x] 我的书源更多菜单增加“清除登录态”。
- [x] 我的书源列表登录完成后刷新该书源状态。
- [x] 我的书源列表清除登录态后刷新该书源状态。
- [x] 发现页当前书源操作区增加“登录”。
- [x] 发现页当前书源操作区增加“登录状态”。
- [x] 发现页登录完成后刷新当前分类。
- [x] 发现页清除登录态后刷新当前源状态。
- [x] 登录入口统一调用 `/login-task`，不由 UI 自己判断 WebView 还是表单。

完成进度：10/10

### 阶段 2：登录页面路由收敛

- [x] 新建统一登录入口页或协调器，例如 `SourceLoginEntryPage`。
- [x] 保留现有 WebView 登录页作为 WebView 子流程。
- [x] 新增 loginUi 表单子流程占位。
- [x] 根据 `loginTask.mode` 分流到 WebView 或表单。
- [x] 支持登录完成后 `pop(true)`。
- [x] 支持登录取消后 `pop(false/null)`。
- [ ] 支持登录失败展示可复制诊断。
- [x] 登录页标题使用书源名，不使用书名。
- [x] 登录页提交后展示 session 摘要。

完成进度：8/9

说明：WebView 子流程沿用现有完成/取消返回值；统一入口页负责取 `/login-task` 并分流。可复制诊断还需要结合后续 Rust 错误结构补齐。

### 阶段 3：会话状态与清除

- [x] 新增会话状态弹窗。
- [x] 展示是否有 Cookie。
- [x] 展示是否有 Header。
- [x] 展示 Header 名称列表，不展示敏感值。
- [x] 展示是否有 loginInfo。
- [x] 展示是否有 sourceVariable。
- [x] 展示 Cookie scope。
- [x] 展示 session policy。
- [x] 展示 TTL。
- [x] 展示最后更新时间。
- [x] 支持“重新登录”。
- [x] 支持“清除登录态”。
- [x] 清除登录态后提示成功。
- [x] 清除登录态后触发当前来源刷新。

完成进度：14/14

### 阶段 4：WebView 登录补强

- [x] 登录页加载 loginTask 中的 prepared request。
- [x] 支持 GET 登录请求。
- [x] 支持 POST 登录请求。
- [x] 支持 request headers。
- [x] 支持 request body。
- [x] 登录提交时读取 `document.cookie`。
- [x] 登录提交时读取 localStorage。
- [ ] 调研并接入平台 CookieManager 读取能力。
- [ ] 合并 JS Cookie 与平台 Cookie。
- [x] 提交登录结果后读取 session summary。
- [ ] 若有 `loginCheckJs`，登录后触发一次校验。
- [ ] 校验失败时提示继续登录或重新提交。

完成进度：8/12

说明：当前 `webview_flutter` 可稳定读取 JS 可见 Cookie 与 localStorage；HttpOnly Cookie 需要平台 CookieManager 读取能力，后续需补插件/平台通道或 Rust 网关配套方案。`loginCheckJs` 也需要 Rust 提供 Legado 兼容执行上下文后才能真正校验。

### 阶段 5：loginUi 基础表单

- [x] 解析 `loginUiKind=json`。
- [x] 支持 `text` 控件。
- [x] 支持 `password` 控件。
- [x] 支持 `select` 控件。
- [x] 支持 `toggle` 控件。
- [x] 支持 `button` 控件展示。
- [x] 支持默认值。
- [x] 支持必填校验。
- [x] 支持保存 `loginInfoJson`。
- [x] 支持提交 `loginInfoJson` 到 Rust session。
- [x] 支持提交后刷新 session summary。
- [ ] 支持表单取消时保留已输入草稿。

完成进度：11/12

说明：静态 JSON loginUi 已经可以填写并提交为 `loginInfoJson`。真正执行 `source.login()`、消费 `source.getLoginInfo()` 仍属于阶段 7 的 Rust source API 兼容。

### 阶段 6：loginUi 动态 JS

- [ ] Rust 增加 loginUi JS 执行接口。
- [ ] 支持 `@js:` 生成 loginUi JSON。
- [ ] 支持 `<js>` 生成 loginUi JSON。
- [ ] Flutter 对 `loginUiKind=js` 调用 Rust 执行接口。
- [ ] 支持 button action 执行 JS。
- [x] 支持 button action 打开 URL。
- [ ] 支持 JS 更新表单数据。
- [ ] 支持 JS 请求重新渲染表单。
- [ ] 支持 `isLongClick` 参数。
- [x] JS 执行失败时展示诊断。
- [x] JS 执行失败时不丢失表单输入。

完成进度：3/11

说明：Flutter 已识别 `@js:` 和 `<js>` 动态 loginUi，并给出明确诊断；button action 若是 URL 可外部打开。动态 UI 生成、button JS、数据更新、重新渲染必须等 Rust 网关提供 Legado `source/java/result` 执行上下文，不能只在 Flutter 内执行普通 JavaScript。

### 阶段 7：Rust source API 兼容

- [ ] `source.getLoginInfo()` 读取 Rust session 的 `loginInfoJson`。
- [ ] `source.getLoginInfoMap()` 返回 loginInfo map。
- [ ] `source.putLoginInfo()` 写入 Rust session。
- [ ] `source.removeLoginInfo()` 清除 loginInfo。
- [ ] `source.getLoginHeader()` 读取 Rust session header JSON。
- [ ] `source.getLoginHeaderMap()` 返回 header map。
- [ ] `source.putLoginHeader()` 写入 Rust session headers。
- [ ] `source.putLoginHeader()` 同步 Cookie 到 runtime cookie。
- [ ] `source.removeLoginHeader()` 清除 session headers。
- [ ] `source.removeLoginHeader()` 清除对应 Cookie。
- [ ] `source.getVariable()` 读取持久 sourceVariable。
- [ ] `source.putVariable()` 写入持久 sourceVariable。
- [ ] `source.login()` 执行 loginUrl 登录逻辑。
- [ ] 所有写入动作返回更新后的 session summary 或可追踪结果。

完成进度：0/14

说明：本阶段为 Rust 网关执行项，当前 Flutter 主仓无法直接实现。已补充接口契约：`docs/features/source/source-login-rust-compatibility-contract-2026-06-22.md`。

### 阶段 8：loginCheckJs 兼容

- [ ] `loginCheckJs` 的 `result` 提供 StrResponse 等价对象。
- [ ] StrResponse 等价对象支持 `body`。
- [ ] StrResponse 等价对象支持 `url`。
- [ ] StrResponse 等价对象支持 `headers`。
- [ ] StrResponse 等价对象支持 `status`。
- [ ] 支持 JS 返回新 body。
- [ ] 支持 JS 返回 StrResponse 等价对象。
- [ ] 支持 `loginCheckJs` 调用 `source.login()`。
- [ ] 支持 `loginCheckJs` 调用 `source.putLoginHeader()`。
- [ ] 支持 `loginCheckJs` 写入登录态后重试原请求。
- [ ] 补齐 `java.getResponse()` 常用兼容。
- [ ] 补齐 `java.getStrResponse()` 常用兼容。
- [ ] 补齐 `java.initUrl()` 常用兼容。
- [ ] 补齐 `java.getHeaderMap()` 常用兼容。
- [ ] 登录失效统一映射为 `LOGIN_REQUIRED`。

完成进度：0/15

说明：本阶段依赖 Rust JS bridge 和 StrResponse 等价对象，当前 Flutter 主仓无法直接实现。已补充 `loginCheckJs` 入参、返回值、重试和 `java.*` 兼容契约。

### 阶段 9：错误恢复闭环

- [x] 发现页源分类失败为 `LOGIN_REQUIRED` 时展示“登录后重试”。
- [x] 发现页书籍列表失败为 `LOGIN_REQUIRED` 时展示“登录后重试”。
- [x] 搜索失败明细为 `LOGIN_REQUIRED` 时提供一次性“去登录”。
- [x] 详情失败为 `LOGIN_REQUIRED` 时提供一次性“去登录”。
- [x] 目录失败为 `LOGIN_REQUIRED` 时提供一次性“去登录”。
- [x] 阅读器正文失败为 `LOGIN_REQUIRED` 时沿用恢复入口。
- [x] 登录返回后重试原动作。
- [x] 用户取消登录后保持原错误态。
- [ ] 登录失败后保留诊断信息。

完成进度：8/9

说明：错误恢复入口已统一走 `/source/login`，因此 WebView 和静态 loginUi 都能恢复。登录失败可读诊断已有基础提示，复制式结构化诊断留到 Rust 错误结构补齐后完善。

### 阶段 10：验收样本

- [x] 准备普通 Cookie WebView 登录样本。
- [x] 准备 HttpOnly Cookie WebView 登录样本。
- [x] 准备 localStorage 登录样本。
- [x] 准备 loginUi text/password 样本。
- [x] 准备 loginUi select 样本。
- [x] 准备 loginUi toggle 样本。
- [x] 准备 loginUi button action 样本。
- [x] 准备 loginUi `@js:` 样本。
- [x] 准备 `source.putLoginHeader()` 样本。
- [x] 准备 `source.login()` 样本。
- [x] 准备 `loginCheckJs` 自动重试样本。
- [x] 准备 enabledCookieJar 样本。
- [ ] 验收发现页入口。
- [ ] 验收我的书源入口。
- [ ] 验收搜索失败恢复。
- [ ] 验收详情失败恢复。
- [ ] 验收目录失败恢复。
- [ ] 验收阅读器失败恢复。
- [ ] 验收清除登录态。
- [ ] 验收重新登录。

完成进度：12/20

说明：样本清单已落地：`docs/features/source/source-login-acceptance-samples-2026-06-22.md`。真实站点登录凭据、HttpOnly Cookie 和 Rust source API/loginCheckJs 验收仍需后续联调。

## 6. 推荐执行顺序

建议按以下顺序执行：

1. 阶段 0：先统一能力模型。
2. 阶段 1：先把两个主动入口做出来。
3. 阶段 2：收敛登录路由。
4. 阶段 3：补会话状态和清除。
5. 阶段 4：把 WebView 登录做稳。
6. 阶段 7：补 Rust source API。
7. 阶段 8：补 loginCheckJs。
8. 阶段 5：补基础 loginUi 表单。
9. 阶段 6：补动态 loginUi JS。
10. 阶段 9：补错误恢复闭环。
11. 阶段 10：样本验收。

说明：

- 阶段 0-4 完成后，基础 WebView 登录可以进入可用状态。
- 阶段 7-8 完成后，复杂 MD3/Legado 登录书源才算真正进入兼容状态。
- 阶段 5-6 完成后，`loginUi` 书源体验才接近 MD3。
- 阶段 9-10 完成后，才建议对外宣称“书源登录兼容能力可上线”。

## 7. 第一版上线口径

如果只做阶段 0-4：

- 可以说支持基础 WebView 书源登录。
- 可以从发现页和我的书源主动登录。
- 可以查看和清除登录态。
- 不能说完整兼容 MD3/Legado 登录。

如果做到阶段 0-8：

- 可以说支持主流 Legado/MD3 登录模型。
- 仍需样本覆盖后再对外扩大口径。

如果做到阶段 0-10：

- 可以作为书源登录兼容能力的上线标准。

## 8. 入口最终约定

最终入口保持简洁：

- 发现页：用于用户探索书源时登录当前源。
- 我的书源更多菜单：用于用户管理某个源时登录、重登、查看状态、清除登录态。

不新增以下常驻入口：

- 搜索结果常驻登录按钮。
- 详情页常驻登录按钮。
- 阅读器顶部常驻登录按钮。
- 我的页面全局书源登录入口。

这些页面只在明确失败时提供一次性恢复动作。

## 9. 云端/本地双模式最优解

后续如果支持本地化，推荐采用“一套 Rust Core，两种运行形态”。

最优解：

- Rust 只保留一套核心书源解析代码。
- 云端模式：Rust Core 通过 HTTP server 部署到服务器，Flutter 走现有网关 API。
- 本地模式：Rust Core 编译成 App 内置库，Flutter 通过 `flutter_rust_bridge` 调用。
- Flutter 侧只切换统一的 gateway client，不让 UI 和业务流程感知云端/本地差异。

推荐结构：

```text
reader-rust-core
  书源解析、搜索、发现、详情、目录、正文、Cookie、session、loginCheckJs

reader-rust-http-server
  HTTP 路由和部署入口，只把请求转给 core

reader-rust-flutter-bridge
  flutter_rust_bridge 绑定，只把 Dart 调用转给 core

Flutter
  BookSourceGatewayClient
    RemoteGatewayClient: 走 HTTP
    LocalRustGatewayClient: 走 flutter_rust_bridge
```

为什么这样最稳：

- 书源解析、Cookie、编码、JS bridge、请求重试这些能力不适合放 Flutter 侧手搓。
- Flutter 的跨平台主要是 UI 跨平台，不代表 WebView、Cookie、TLS、编码、JS 执行在各平台表现一致。
- Rust Core 能让云端和本地使用同一套解析结果、同一套测试样本、同一套兼容修复。
- 远端和本地只差适配层，不会出现“服务器修好了，本地没修”的分叉。

第一版不建议做的事：

- 不在 App 内下载并执行 Rust 二进制。
- 不在 iOS 上启动本地可执行进程。
- 不为了本地化立刻重写所有网关 API。
- 不把 HTTP server 原样搬进 App。
- 不在登录兼容阶段强行引入复杂的本地/云端混合策略。

平台策略：

- iOS：Rust 必须随 App 编译成库，通过 FFI/`flutter_rust_bridge` 调用，不下载执行代码。
- Android：也建议走库调用，而不是 sidecar 进程，减少权限、进程保活和端口问题。
- Windows/macOS/Linux：可以支持库调用；如需调试可保留 HTTP server。

用户策略：

- 默认走云端，适合普通用户，升级快，设备负担低。
- 设置里提供“书源解析模式”：云端 / 本地。
- 本地模式初始化失败时允许一键回退云端。
- 云端共享、审核、账号、同步继续留服务器。
- 本地只负责阅读链路：搜索、发现、详情、目录、正文、书源规则执行、Cookie/session。

## 10. 本地化预留任务

这组任务不阻塞当前书源登录兼容，可以在登录稳定后单独开版本执行。

- [ ] 定义 Flutter 侧 `BookSourceGatewayClient` 抽象。
- [ ] 将现有 HTTP 调用收敛到 `RemoteGatewayClient`。
- [ ] 保持请求/响应 DTO 与 Rust HTTP API 对齐。
- [ ] 在设置中预留“书源解析模式”配置位，默认云端。
- [ ] Rust 网关拆出 `reader-rust-core`，让 HTTP server 只做薄适配。
- [ ] 新建 `reader-rust-flutter-bridge`，使用 `flutter_rust_bridge v2` 暴露 core API。
- [ ] 本地库初始化时指定 App 私有数据目录。
- [ ] 本地库复用 Rust 的 Cookie/session/cache 存储。
- [ ] 本地模式失败时自动提示回退云端。
- [ ] 建立同一套样本同时跑云端 HTTP 和本地 Rust 库。

完成进度：0/10
