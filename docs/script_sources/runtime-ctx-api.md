# 宿主运行时 API

这份文档不再承担作者手册功能。  
它只负责两件事：

1. 说明当前运行时真实暴露了哪些能力
2. 说明这些能力的实现边界

如果你是写书源作者，优先看：

- [官方书源编写手册](./official-source-author-guide.md)

---

## 1. 当前 `ctx` 结构

当前运行时暴露的 `ctx` 为：

```js
ctx = {
  source,
  http,
  html,
  browser,
  cookie,
  cache,
  session,
  utils,
  crypto,
  log,
}
```

---

## 2. 当前已实现能力

### 2.1 `ctx.source`

- `ctx.source.id`
- `ctx.source.name`
- `ctx.source.group`
- `ctx.source.revision`

### 2.2 `ctx.http`

- `ctx.http.request(...)`
- `ctx.http.isHtml(response)`
- `ctx.http.isJson(response)`
- `ctx.http.isRedirect(response)`
- `ctx.http.isChallenge(response)`

### 2.3 `ctx.html`

- `ctx.html.parse(html)`
- `ctx.html.text(node)`
- `ctx.html.attr(node, name)`
- `ctx.html.collect(nodes, mapper)`

### 2.4 `ctx.browser`

- `ctx.browser.open(...)`
- `ctx.browser.challenge(...)`
- `ctx.browser.eval(...)`
- `ctx.browser.waitForUrl(...)`
- `ctx.browser.waitForText(...)`
- `ctx.browser.getCookies()`
- `ctx.browser.getCurrentUrl()`
- `ctx.browser.getHtml()`
- `ctx.browser.getStorage()`

### 2.5 `ctx.cookie`

- `ctx.cookie.get(name)`
- `ctx.cookie.getAll()`
- `ctx.cookie.getForUrl(url, name?)`
- `ctx.cookie.set(name, value)`
- `ctx.cookie.remove(name)`
- `ctx.cookie.clearDomain(domain)`

### 2.6 `ctx.cache`

- `ctx.cache.get(key)`
- `ctx.cache.set(key, value)`
- `ctx.cache.remove(key)`
- `ctx.cache.clearPrefix(prefix)`

### 2.7 `ctx.session`

- `ctx.session.get(key)`
- `ctx.session.set(key, value)`
- `ctx.session.clear(key?)`
- `ctx.session.cookies()`

### 2.8 `ctx.utils`

- `ctx.utils.absoluteUrl(base, relative)`
- `ctx.utils.sleep(duration)`
- `ctx.utils.pick(value, fallback)`
- `ctx.utils.normalizeText(text)`
- `ctx.utils.timeFormat(value, pattern?)`
- `ctx.utils.htmlFormat(value)`
- `ctx.utils.base64Encode(value)`
- `ctx.utils.base64Decode(value)`
- `ctx.utils.hexEncode(value)`
- `ctx.utils.hexDecode(value)`
- `ctx.utils.encodeUri(value)`
- `ctx.utils.decodeUri(value)`
- `ctx.utils.encodeUriComponent(value)`
- `ctx.utils.decodeUriComponent(value)`

### 2.9 `ctx.crypto`

- `ctx.crypto.md5(value, options?)`
- `ctx.crypto.sha1(value, options?)`
- `ctx.crypto.sha256(value, options?)`
- `ctx.crypto.sha512(value, options?)`
- `ctx.crypto.sm3(value, options?)`
- `ctx.crypto.hmacSha1(value, key, options?)`
- `ctx.crypto.hmacSha256(value, key, options?)`
- `ctx.crypto.hmacSha512(value, key, options?)`
- `ctx.crypto.aesEncrypt(options)`
- `ctx.crypto.aesDecrypt(options)`
- `ctx.crypto.desEncrypt(options)`
- `ctx.crypto.desDecrypt(options)`
- `ctx.crypto.tripleDesEncrypt(options)`
- `ctx.crypto.tripleDesDecrypt(options)`
- `ctx.crypto.rc4Encrypt(options)`
- `ctx.crypto.rc4Decrypt(options)`
- `ctx.crypto.symmetricEncrypt(options)`
- `ctx.crypto.symmetricDecrypt(options)`
- `ctx.crypto.rsaEncrypt(options)`
- `ctx.crypto.rsaDecrypt(options)`
- `ctx.crypto.rsaSign(options)`
- `ctx.crypto.rsaVerify(options)`
- `ctx.crypto.asymmetricEncrypt(options)`
- `ctx.crypto.asymmetricDecrypt(options)`
- `ctx.crypto.symmetricCrypto(key, iv, algorithm, data)`
- `ctx.crypto.asymmetricCrypto(algorithm, data)`
- `ctx.crypto.randomBytes(length, options?)`
- `ctx.crypto.randomString(length, options?)`
- `ctx.crypto.timestamp(options?)`

### 2.10 `ctx.log`

- `ctx.log(message)`

说明：

- 详细参数、返回值、示例统一放在主手册中
- 这份文档不再重复 API 参考内容
- `ctx.crypto.AsymmetricCrypto(...)` 当前仍可作为兼容别名使用，但不再作为主推荐命名列出

---

## 3. 当前实现边界

### 3.1 `ctx.browser` 不等于登录能力

`browser` 是浏览器上下文能力，不是单独的登录模块。

这意味着：

- 你可以用它承接登录流程
- 但它不只服务登录
- 不应把它理解成“登录成功后自动提供全部状态”

### 3.2 `ctx.browser.challenge(...)` 的目标是“让流程继续”

`challenge` 负责：

- 打开浏览器
- 等待某个条件满足
- 让规则继续执行

它不应被理解成默认自动完成：

- token 全量同步
- 整页 HTML 同步
- 全部 storage 同步
- 登录态推断

如果规则需要这些数据，应显式调用：

- `ctx.browser.eval(...)`
- `ctx.browser.getCookies()`
- `ctx.browser.getCurrentUrl()`
- `ctx.browser.getHtml()`
- `ctx.browser.getStorage()`

补充说明：

- 当前浏览器流程完成后，浏览器侧 cookie 会同步回当前源 session
- 因此后续普通 `ctx.http.request(...)` 会按目标 URL 复用匹配的 cookie
- 但这仍不等于“浏览器全部状态自动推断完成”

### 3.3 `getHtml()` 和 `getStorage()` 当前是“按需能力”

这两个能力已经开放，但当前设计重点仍然是先保证 challenge 可继续执行。

当前建议：

- 只拿单个明确值时，优先 `ctx.browser.eval(...)`
- 只有确实需要页面快照时，再使用 `getHtml()` 或 `getStorage()`

### 3.4 `ctx.cookie.clearDomain(domain)` 不是完整浏览器级清理器

它当前更适合理解为：

- 清理当前源上下文里与该域名匹配的 cookie 集合

不建议把它理解成：

- 浏览器级、域名级的精细 cookie 删除能力

### 3.5 `ctx.http.request({ execution: 'browser' })` 当前是轻量包装

当前它更适合理解为：

- 用浏览器环境打开页面并返回当前 HTML 快照

不应把它理解成：

- 完整浏览器网络栈替代
- 自动支持所有浏览器拦截、请求头改写、XHR 代理等高级行为

### 3.6 `ctx.http.request({ bodyType })` 当前用于明确请求体编码

当前已支持：

- `auto`
- `json`
- `form`
- `text`
- `bytes`

适合的理解方式是：

- `bodyType` 只负责告诉宿主“这段 body 应该怎样编码”
- 它不负责自动推断业务语义

---

## 4. 文档分工

- [官方书源编写手册](./official-source-author-guide.md) 负责“怎么写”
- [书源规范 v1](./source-spec-v1.md) 负责“什么算合规”
- 这份文档负责“当前实现到哪里、边界在哪里”
