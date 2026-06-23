# 书源登录验收样本

日期：2026-06-22

状态：样本清单已建立，真实站点凭据需人工补充

## 1. WebView Cookie 登录

- [ ] 准备普通 Cookie 登录书源。
- [ ] 从“我的书源 > 更多 > 登录”打开。
- [ ] 登录完成后点击“提交会话”。
- [ ] session 摘要显示 Cookie 已保存。
- [ ] 返回原页面后能刷新成功。

样本结构：

```json
{
  "bookSourceName": "验收-WebView-Cookie",
  "bookSourceUrl": "https://example-cookie.test",
  "loginUrl": "https://example-cookie.test/login",
  "enabledCookieJar": true
}
```

## 2. WebView localStorage 登录

- [ ] 准备登录态写入 localStorage 的书源。
- [ ] 登录后提交会话。
- [ ] session 摘要显示 loginInfo/sourceVariable 或 Cookie 之外的登录材料已保存。
- [ ] 发现页分类能刷新成功。

样本结构：

```json
{
  "bookSourceName": "验收-WebView-localStorage",
  "bookSourceUrl": "https://example-localstorage.test",
  "loginUrl": "https://example-localstorage.test/login"
}
```

## 3. HttpOnly Cookie 登录

- [ ] 准备 HttpOnly Cookie 登录书源。
- [ ] WebView 登录完成后提交。
- [ ] 当前版本预期：JS 可能读不到 Cookie。
- [ ] 后续平台 CookieManager 接入后，session 摘要应显示 Cookie 已保存。

样本结构：

```json
{
  "bookSourceName": "验收-HttpOnly-Cookie",
  "bookSourceUrl": "https://example-httponly.test",
  "loginUrl": "https://example-httponly.test/login",
  "enabledCookieJar": true
}
```

## 4. 静态 loginUi

- [ ] text/password 能输入。
- [ ] select 能选择。
- [ ] toggle 能切换。
- [ ] button URL 能打开外部页面。
- [ ] 提交后 session 摘要显示 loginInfo 已保存。

样本结构：

```json
{
  "bookSourceName": "验收-loginUi-static",
  "bookSourceUrl": "https://example-login-ui.test",
  "loginUi": [
    {"name": "telephone", "type": "text", "required": true},
    {"name": "password", "type": "password", "required": true},
    {"name": "region", "type": "select", "chars": ["cn", "hk", "tw"], "default": "cn"},
    {"name": "remember", "type": "toggle", "chars": ["yes", "no"], "default": "yes"},
    {"name": "注册", "type": "button", "action": "https://example-login-ui.test/register"}
  ],
  "loginUrl": "var loginInfo = source.getLoginInfoMap(); source.putLoginHeader(JSON.stringify({Authorization: 'Bearer ' + loginInfo.token}));"
}
```

## 5. 动态 loginUi JS

- [ ] `@js:` 样本能被识别为动态 JS。
- [ ] 当前版本预期：展示 Rust JS 上下文待接入诊断。
- [ ] Rust 接口完成后，动态 JSON 能渲染为表单。

样本结构：

```json
{
  "bookSourceName": "验收-loginUi-js",
  "bookSourceUrl": "https://example-login-ui-js.test",
  "loginUi": "@js:`[{\"name\":\"token\",\"type\":\"text\",\"required\":true}]`",
  "loginUrl": "source.putLoginHeader(JSON.stringify({Authorization: 'Bearer ' + source.getLoginInfoMap().token}))"
}
```

## 6. source.putLoginHeader

- [ ] loginUi 提交 `loginInfoJson`。
- [ ] Rust `source.login()` 读取 loginInfo。
- [ ] Rust `source.putLoginHeader()` 写入 header。
- [ ] session 摘要显示 Header 已保存。
- [ ] 后续搜索/详情/目录请求带上 Header。

## 7. source.login

- [ ] `loginCheckJs` 可调用 `source.login()`。
- [ ] `source.login()` 可执行 `loginUrl`。
- [ ] 登录成功后更新 session。
- [ ] 原请求自动重试。

## 8. loginCheckJs 自动重试

- [ ] 准备首次请求返回登录失效的书源。
- [ ] Rust 包装 `result`。
- [ ] `loginCheckJs` 判断失效。
- [ ] JS 写入新登录态。
- [ ] `java.getResponse()` 使用新登录态重试。
- [ ] Flutter 不展示错误，用户只看到最终内容。

## 9. Flutter 入口验收

- [ ] 发现页书源更多菜单能登录。
- [ ] 发现页书源更多菜单能查看登录状态。
- [ ] 发现页书源更多菜单能清除登录态。
- [ ] 我的书源更多菜单能登录。
- [ ] 我的书源更多菜单能查看登录状态。
- [ ] 我的书源更多菜单能清除登录态。
- [ ] 搜索失败明细 LOGIN_REQUIRED 能“登录后重试”。
- [ ] 发现页分类 LOGIN_REQUIRED 能“登录后重试”。
- [ ] 发现页分类书籍 LOGIN_REQUIRED 能“登录后重试”。
- [ ] 详情页 LOGIN_REQUIRED 能“登录后重试”。
- [ ] 目录 LOGIN_REQUIRED 能“登录后重试”。
- [ ] 阅读器正文 LOGIN_REQUIRED 能打开统一登录入口并重试。

## 10. 上线前结论

- [ ] 阶段 0-6：Flutter 侧基础闭环可验收。
- [ ] 阶段 7-8：Rust 兼容 API 完成后，复杂 Legado/MD3 登录书源可验收。
- [ ] 阶段 9：错误恢复闭环完成后，用户不会被迫自己找登录入口。
- [ ] 阶段 10：真实样本通过后，才能对外宣称“书源登录兼容能力可上线”。
