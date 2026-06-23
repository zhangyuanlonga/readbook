# 书源登录 Rust 兼容接口契约

日期：2026-06-22

状态：Flutter 侧已预留，Rust 网关待实现

## 1. 目标

阶段 7-8 的核心不是继续堆 Flutter UI，而是让 Rust 网关真正兼容 Legado/MD3 登录运行时。

Flutter 现在已经能完成：

- 打开统一登录入口。
- WebView 提交 Cookie/localStorage。
- 静态 loginUi 提交 `loginInfoJson`。
- 查看和清除 session 摘要。
- 登录失败后回到发现、搜索、详情、目录、阅读器链路重试。

Rust 仍需要负责：

- 保存和读取 `loginInfoJson`、`loginHeaderJson`、`sourceVariableJson`。
- 在书源 JS 中暴露 `source.*` 登录 API。
- 执行 `source.login()`。
- 在请求失败或登录失效时执行 `loginCheckJs` 并重试原请求。

## 2. Session 数据模型

Rust session 至少需要维护：

- `cookie`：当前源可用 Cookie header。
- `headers` / `loginHeaderJson`：登录后附加请求头。
- `loginInfoJson`：loginUi 表单保存结果。
- `sourceVariableJson`：书源变量。
- `cookieScope`：`source` / `domain` / `global`。
- `sessionPolicy`：短期内存、持久、或运行期 header only。
- `updatedAt`、`ttlSeconds`。

Flutter 已提交的字段：

- WebView：`cookies`、`localStorage`、`finalUrl`。
- loginUi：`loginInfoJson`。
- 清除：`DELETE /v1/sources/{sourceId}/session`。

## 3. source API

- [ ] `source.getLoginInfo()` 返回 `loginInfoJson` 字符串。
- [ ] `source.getLoginInfoMap()` 返回 loginInfo map。
- [ ] `source.putLoginInfo(json)` 写入 `loginInfoJson`。
- [ ] `source.removeLoginInfo()` 清除 `loginInfoJson`。
- [ ] `source.getLoginHeader()` 返回 `loginHeaderJson` 字符串。
- [ ] `source.getLoginHeaderMap()` 返回 header map。
- [ ] `source.putLoginHeader(json)` 写入 headers。
- [ ] `source.putLoginHeader(json)` 同步 Cookie 到 runtime cookie jar。
- [ ] `source.removeLoginHeader()` 清除 headers。
- [ ] `source.removeLoginHeader()` 清除对应 Cookie。
- [ ] `source.getVariable(key?)` 读取 sourceVariable。
- [ ] `source.putVariable(keyOrJson, value?)` 写入 sourceVariable。
- [ ] `source.login()` 执行当前书源 `loginUrl` 脚本。
- [ ] 所有写入动作返回更新后的 session summary 或 trace id。

## 4. loginCheckJs

- [ ] 在搜索、发现、详情、目录、正文请求完成后，如果配置 `loginCheckJs`，把原响应包装成 `result`。
- [ ] `result.body()` 或 `result.body` 能读原 body。
- [ ] `result.url()` 或 `result.url` 能读最终 URL。
- [ ] `result.headers()` 或 `result.headers` 能读响应头。
- [ ] `result.code()` 或 `result.status` 能读状态码。
- [ ] JS 返回字符串时作为新 body。
- [ ] JS 返回 StrResponse 等价对象时作为新响应。
- [ ] JS 调用 `source.login()` 后能更新 session。
- [ ] JS 调用 `source.putLoginHeader()` 后能更新 header/cookie。
- [ ] JS 调用 `java.getResponse()` 时能使用更新后的 session 重试原请求。
- [ ] JS 调用 `java.getStrResponse()` 时能使用更新后的 session 重试原请求。
- [ ] JS 调用 `java.initUrl()` 时能重新初始化当前 URL 请求。
- [ ] JS 调用 `java.getHeaderMap()` 时能拿到可写 header map。
- [ ] 登录失效统一映射为 `LOGIN_REQUIRED`。

## 5. 动态 loginUi JS

- [ ] Rust 提供 `POST /v1/sources/{sourceId}/login-ui/evaluate`。
- [ ] 请求参数包含 `isLongClick`、当前 `loginInfoJson`、可选 button action。
- [ ] 返回值包含 `loginUiJson`、`loginInfoJson`、`toast`、`diagnostics`。
- [ ] 支持 `@js:` 生成 loginUi JSON。
- [ ] 支持 `<js>...</js>` 生成 loginUi JSON。
- [ ] 支持 button action 执行 JS。
- [ ] 支持 JS 更新表单数据。
- [ ] 支持 JS 请求重新渲染表单。
- [ ] JS 失败时返回结构化诊断，不吞异常。

## 6. 验收口径

阶段 7-8 完成前，只能说：

- 支持基础 WebView 登录。
- 支持静态 loginUi 保存登录信息。
- 支持登录态查看、清除和错误恢复入口。

阶段 7-8 完成后，才能说：

- 支持主流 Legado/MD3 登录 API。
- 支持 loginCheckJs 自动修复登录态并重试。
- 支持复杂 loginUi JS 书源。
