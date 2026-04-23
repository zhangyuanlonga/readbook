# 宿主运行时 API v2

更新时间：2026-04-23
适用范围：`flutterreadbook`

## 1. 文档说明

这份文档是查表用的，不是入门教程。

用途：

- 当你已经知道自己要用 `ctx.http`、`ctx.html`、`ctx.browser` 或 `ctx.utils`
- 但你想确认：
  - 方法功能
  - 参数
  - 返回值
  - 最小示例
  - 注意事项

当前这版先优先整理最常用的四组能力：

- `ctx.http`
- `ctx.html`
- `ctx.browser`
- `ctx.utils`

## 2. `ctx.source`

### 方法：`ctx.source.id`

#### 功能

获取当前书源的运行时 ID。

#### 签名

```js
ctx.source.id
```

#### 参数

- 无

#### 返回值

- 返回字符串

#### 示例

```js
const sourceId = ctx.source.id;
```

#### 注意事项

- 这是宿主生成的运行时 ID，不要求作者手写

### 方法：`ctx.source.name`

#### 功能

获取当前书源名称。

#### 签名

```js
ctx.source.name
```

#### 参数

- 无

#### 返回值

- 返回字符串

#### 示例

```js
ctx.log(`当前源: ${ctx.source.name}`);
```

#### 注意事项

- 适合调试与日志

### 方法：`ctx.source.group`

#### 功能

获取当前书源分组。

#### 签名

```js
ctx.source.group
```

#### 参数

- 无

#### 返回值

- 返回字符串或空值

#### 示例

```js
const group = ctx.source.group;
```

#### 注意事项

- 更适合调试和展示，不建议强依赖分组写业务流程

### 方法：`ctx.source.revision`

#### 功能

获取当前运行中的修订标识。

#### 签名

```js
ctx.source.revision
```

#### 参数

- 无

#### 返回值

- 返回字符串

#### 示例

```js
ctx.log(`revision=${ctx.source.revision}`);
```

#### 注意事项

- 主要用于调试

## 3. `ctx.http`

### 方法：`ctx.http.request(options)`

#### 功能

发起一次宿主 HTTP 请求。

#### 签名

```js
await ctx.http.request(options)
```

#### 参数

- `options.url`：请求地址
- `options.method`：请求方法，可选 `GET / POST / PUT / PATCH / DELETE / HEAD`
- `options.headers`：请求头
- `options.query`：查询参数
- `options.body`：请求体
- `options.bodyType`：请求体编码方式，支持 `auto / json / form / text / bytes`
- `options.timeoutMs`：超时时间，单位毫秒
- `options.responseType`：响应类型，支持 `text / json / bytes`
- `options.charset`：文本解码字符集
- `options.referer`：快捷指定来源页
- `options.execution`：执行方式，支持 `http / browser`
- `options.webView`：`execution: 'browser'` 的轻量别名

#### 返回值

返回宿主统一响应对象：

```js
{
  ok: boolean,
  status: number,
  url: string,
  headers: Record<string, string>,
  text: string | null,
  json: any,
  bytesLength: number | null,
  redirected: boolean,
}
```

#### 示例

```js
const response = await ctx.http.request({
  url: 'https://example.com/search',
  method: 'GET',
  query: { q: keyword },
  responseType: 'text',
});
```

提交表单：

```js
const response = await ctx.http.request({
  url: 'https://example.com/login',
  method: 'POST',
  bodyType: 'form',
  body: {
    username: 'demo',
    password: '123456',
  },
});
```

#### 注意事项

- 普通站点优先用 `ctx.http.request(...)`
- 不要一开始就上 `ctx.browser.*`
- 如果命中挑战页，再决定是否升级到浏览器流程
- 字符集不对时，优先检查 `charset`

### 方法：`ctx.http.isHtml(response)`

#### 功能

判断响应是否适合按 HTML 处理。

#### 签名

```js
ctx.http.isHtml(response)
```

#### 参数

- `response`：`ctx.http.request(...)` 返回的响应对象

#### 返回值

- `boolean`

#### 示例

```js
if (ctx.http.isHtml(response)) {
  const doc = ctx.html.parse(response.text);
}
```

#### 注意事项

- 响应类型不固定时再用它判断
- 不是所有文本响应都应直接当 HTML 解析

### 方法：`ctx.http.isJson(response)`

#### 功能

判断响应是否适合按 JSON 处理。

#### 签名

```js
ctx.http.isJson(response)
```

#### 参数

- `response`：响应对象

#### 返回值

- `boolean`

#### 示例

```js
if (ctx.http.isJson(response)) {
  return response.json?.rows || [];
}
```

#### 注意事项

- 适合 API / HTML 混合站点
- 不要假设所有接口永远只返回 JSON

### 方法：`ctx.http.isRedirect(response)`

#### 功能

判断响应是否发生了跳转。

#### 签名

```js
ctx.http.isRedirect(response)
```

#### 参数

- `response`：响应对象

#### 返回值

- `boolean`

#### 示例

```js
if (ctx.http.isRedirect(response)) {
  ctx.log(`redirected to ${response.url}`);
}
```

#### 注意事项

- 适合排查是否被重定向到登录页或风控页

### 方法：`ctx.http.isChallenge(response)`

#### 功能

判断响应是否命中了验证码、风控页或其他挑战页。

#### 签名

```js
ctx.http.isChallenge(response)
```

#### 参数

- `response`：响应对象

#### 返回值

- `boolean`

#### 示例

```js
if (ctx.http.isChallenge(response)) {
  await ctx.browser.challenge({
    url: response.url,
    reason: 'challenge_detected',
  });
}
```

#### 注意事项

- 普通请求被挑战页替换时，再升级到浏览器流程
- 不要把 `browser` 当成默认主路

## 4. `ctx.html`

### 方法：`ctx.html.parse(html)`

#### 功能

把 HTML 字符串解析成可查询文档对象。

#### 签名

```js
ctx.html.parse(html)
```

#### 参数

- `html`：HTML 字符串

#### 返回值

- 返回文档对象，可继续 `querySelector / querySelectorAll`

#### 示例

```js
const doc = ctx.html.parse(response.text);
const titleNode = doc.querySelector('.book-title');
```

#### 注意事项

- 输入必须是 HTML 字符串
- 如果上游拿到的是 JSON，不要先 `parse(html)`

### 方法：`ctx.html.text(node)`

#### 功能

获取节点文本内容。

#### 签名

```js
ctx.html.text(node)
```

#### 参数

- `node`：节点对象

#### 返回值

- 返回字符串

#### 示例

```js
const title = ctx.html.text(doc.querySelector('.book-title'));
```

#### 注意事项

- 节点为空时通常返回空字符串
- 适合书名、作者、简介、章节名等文本提取

### 方法：`ctx.html.innerHtml(node)`

#### 功能

获取元素内部 HTML 片段。

#### 签名

```js
ctx.html.innerHtml(node)
```

#### 参数

- `node`：节点对象

#### 返回值

- 返回 HTML 字符串

#### 示例

```js
const html = ctx.html.innerHtml(doc.querySelector('.content'));
```

#### 注意事项

- 与 `ctx.html.text(...)` 的区别是：这里保留子标签
- 如果正文有图片或复杂内联元素，优先考虑 `innerHtml(...)`

### 方法：`ctx.html.attr(node, name)`

#### 功能

读取节点属性值。

#### 签名

```js
ctx.html.attr(node, name)
```

#### 参数

- `node`：节点对象
- `name`：属性名，例如 `href`、`src`

#### 返回值

- 返回属性值字符串

#### 示例

```js
const href = ctx.html.attr(doc.querySelector('a'), 'href');
```

#### 注意事项

- 目录链接、封面链接、详情链接经常靠它读取
- 相对地址通常要再配合 `ctx.utils.absoluteUrl(...)`

### 方法：`ctx.html.collect(nodes, mapper)`

#### 功能

遍历节点集合并映射成结构化数组。

#### 签名

```js
ctx.html.collect(nodes, mapper)
```

#### 参数

- `nodes`：节点集合
- `mapper`：映射函数

#### 返回值

- 返回数组

#### 示例

```js
const books = ctx.html.collect(
  doc.querySelectorAll('.book-item'),
  (node, index) => ({
    title: ctx.html.text(node.querySelector('.title')),
    author: ctx.html.text(node.querySelector('.author')),
  }),
);
```

#### 注意事项

- 搜索结果、目录列表最适合用它统一收集
- 最好在 mapper 中直接返回标准对象

## 5. `ctx.browser`

### 方法：`ctx.browser.open(options)`

#### 功能

打开一个真实浏览器页面。

#### 签名

```js
await ctx.browser.open(options)
```

#### 参数

- `options.url`：要打开的页面地址
- `options.timeoutMs`：等待时间

#### 返回值

- `Promise<void>`

#### 示例

```js
await ctx.browser.open({
  url: 'https://example.com/login',
  timeoutMs: 120000,
});
```

#### 注意事项

- `open(...)` 只是打开页面
- 不等于已经完成登录或验证

### 方法：`ctx.browser.challenge(options)`

#### 功能

进入浏览器挑战流程，让验证码、登录或页面风控通过后继续执行。

#### 签名

```js
await ctx.browser.challenge(options)
```

#### 参数

- `options.url`：挑战页地址
- `options.reason`：触发原因
- `options.waitFor`：等待条件
- `options.timeoutMs`：超时时间

#### 返回值

- `Promise<void>`

#### 示例

```js
await ctx.browser.challenge({
  url: 'https://example.com/login',
  reason: 'manual_login',
  waitFor: {
    urlIncludes: '/home',
    textIncludes: '登录成功',
    cookie: 'SESSIONID',
  },
  timeoutMs: 120000,
});
```

#### 注意事项

- 这是浏览器兜底能力，不应作为默认主链
- 目标是“让流程继续”
- 挑战后如果还要取 token / HTML / storage，请显式再调用对应方法

### 方法：`ctx.browser.eval(options)`

#### 功能

在当前浏览器页面环境执行脚本并返回结果。

#### 签名

```js
await ctx.browser.eval(options)
```

#### 参数

- `options.script`：要执行的脚本字符串

#### 返回值

- `Promise<any>`

#### 示例

```js
const token = await ctx.browser.eval({
  script: "localStorage.getItem('token')",
});
```

#### 注意事项

- 如果你只想取一个明确值，优先用 `eval(...)`
- 比 `getStorage()` 整包拿数据更直接

### 方法：`ctx.browser.waitForUrl(options)`

#### 功能

等待浏览器当前 URL 满足指定条件。

#### 签名

```js
await ctx.browser.waitForUrl(options)
```

#### 参数

- `options.includes`：URL 应包含的关键片段
- `options.timeoutMs`：等待时间

#### 返回值

- `Promise<void>`

#### 示例

```js
await ctx.browser.waitForUrl({
  includes: '/bookshelf',
  timeoutMs: 120000,
});
```

#### 注意事项

- 适合等待跳转完成
- 如果地址不变、只是页面内容变化，优先用 `waitForText(...)`

### 方法：`ctx.browser.waitForText(options)`

#### 功能

等待页面出现某段文本。

#### 签名

```js
await ctx.browser.waitForText(options)
```

#### 参数

- `options.text`：目标文本
- `options.timeoutMs`：等待时间

#### 返回值

- `Promise<void>`

#### 示例

```js
await ctx.browser.waitForText({
  text: '欢迎回来',
  timeoutMs: 120000,
});
```

#### 注意事项

- 适合监听用户可见提示
- 不是拿结构化值的首选方法

### 方法：`ctx.browser.getCookies()`

#### 功能

读取当前浏览器上下文中的 cookie 集合。

#### 签名

```js
await ctx.browser.getCookies()
```

#### 参数

- 无

#### 返回值

- 返回 cookie 集合

#### 示例

```js
const cookies = await ctx.browser.getCookies();
```

#### 注意事项

- 更适合 challenge / 登录后的浏览器侧状态调试

### 方法：`ctx.browser.getCurrentUrl()`

#### 功能

读取当前浏览器页面的实际 URL。

#### 签名

```js
await ctx.browser.getCurrentUrl()
```

#### 参数

- 无

#### 返回值

- 返回字符串

#### 示例

```js
const url = await ctx.browser.getCurrentUrl();
```

#### 注意事项

- 适合调试跳转位置

### 方法：`ctx.browser.getHtml()`

#### 功能

读取当前浏览器页面的 HTML 快照。

#### 签名

```js
await ctx.browser.getHtml()
```

#### 参数

- 无

#### 返回值

- 返回 HTML 字符串

#### 示例

```js
const html = await ctx.browser.getHtml();
const doc = ctx.html.parse(html);
```

#### 注意事项

- 如果只取一个明确值，优先考虑 `ctx.browser.eval(...)`

### 方法：`ctx.browser.getStorage()`

#### 功能

读取当前浏览器页面可见的存储快照。

#### 签名

```js
await ctx.browser.getStorage()
```

#### 参数

- 无

#### 返回值

- 返回 `localStorage / sessionStorage` 快照

#### 示例

```js
const storage = await ctx.browser.getStorage();
const token = storage.localStorage?.token;
```

#### 注意事项

- 如果只取单个字段，通常 `eval(...)` 更直接

## 6. `ctx.utils`

### 方法：`ctx.utils.absoluteUrl(base, relative)`

#### 功能

把相对路径补成绝对地址。

#### 签名

```js
ctx.utils.absoluteUrl(base, relative)
```

#### 参数

- `base`：当前页面的基准地址
- `relative`：相对地址、站内路径或完整地址

#### 返回值

- 返回绝对地址字符串

#### 示例

```js
const detailUrl = ctx.utils.absoluteUrl(
  'https://example.com/search',
  '/book/123',
);
```

#### 注意事项

- 目录、正文、封面、图片链接都建议统一走它补全
- 不要在书源里大量手写 URL 拼接逻辑

### 方法：`ctx.utils.sleep(duration)`

#### 功能

等待一段时间。

#### 签名

```js
await ctx.utils.sleep(duration)
```

#### 参数

- `duration`：毫秒数

#### 返回值

- `Promise<void>`

#### 示例

```js
await ctx.utils.sleep(500);
```

#### 注意事项

- 只在必要时使用
- 不要把它当成“万能修复器”

### 方法：`ctx.utils.pick(value, fallback)`

#### 功能

当主值为空或不可用时，回退到备用值。

#### 签名

```js
ctx.utils.pick(value, fallback)
```

#### 参数

- `value`：主值
- `fallback`：备用值

#### 返回值

- 返回最终选中的值

#### 示例

```js
const title = ctx.utils.pick(
  ctx.html.text(doc.querySelector('.title')),
  '未知书名',
);
```

#### 注意事项

- 适合字段不稳定的站点
- 不要拿它掩盖解析逻辑本身写错的问题

### 方法：`ctx.utils.normalizeText(text)`

#### 功能

对文本做基础规范化处理。

#### 签名

```js
ctx.utils.normalizeText(text)
```

#### 参数

- `text`：原始文本

#### 返回值

- 返回规范化后的字符串

#### 示例

```js
const intro = ctx.utils.normalizeText(
  ctx.html.text(doc.querySelector('.intro')),
);
```

#### 注意事项

- 适合简介、标题、正文基础清洗
- 它不是复杂正文净化规则的替代品

### 方法：`ctx.utils.timeFormat(value, pattern?)`

#### 功能

把时间值格式化成指定字符串。

#### 签名

```js
ctx.utils.timeFormat(value, pattern?)
```

#### 参数

- `value`：时间值
- `pattern`：格式化模板，可选

#### 返回值

- 返回格式化后的字符串

#### 示例

```js
const text = ctx.utils.timeFormat(
  '2026-03-25T08:09:10Z',
  'yyyy-MM-dd HH:mm:ss',
);
```

#### 注意事项

- 适合站点时间格式统一化
- 如果原始值本身不可解析，结果取决于当前实现

### 方法：`ctx.utils.htmlFormat(value)`

#### 功能

把常见 HTML 片段清洗成更适合阅读的纯文本。

#### 签名

```js
ctx.utils.htmlFormat(value)
```

#### 参数

- `value`：HTML 片段

#### 返回值

- 返回清洗后的文本

#### 示例

```js
const text = ctx.utils.htmlFormat('<p>hello<br>world</p>');
```

#### 注意事项

- 适合简单 HTML 转文本
- 如果正文本身有复杂结构，不要指望它做完整排版修复

### 方法：`ctx.utils.base64Encode(value)`

#### 功能

把字符串编码成 Base64。

#### 签名

```js
ctx.utils.base64Encode(value)
```

#### 参数

- `value`

#### 返回值

- 返回编码后的字符串

#### 示例

```js
const encoded = ctx.utils.base64Encode('hello');
```

### 方法：`ctx.utils.base64Decode(value)`

#### 功能

把 Base64 字符串解码成普通文本。

#### 签名

```js
ctx.utils.base64Decode(value)
```

#### 参数

- `value`

#### 返回值

- 返回解码后的字符串

#### 示例

```js
const decoded = ctx.utils.base64Decode('aGVsbG8=');
```

### 方法：`ctx.utils.hexEncode(value)`

#### 功能

把字符串编码成十六进制文本。

#### 签名

```js
ctx.utils.hexEncode(value)
```

#### 参数

- `value`

#### 返回值

- 返回十六进制字符串

#### 示例

```js
const encoded = ctx.utils.hexEncode('abc');
```

### 方法：`ctx.utils.hexDecode(value)`

#### 功能

把十六进制文本解码成普通字符串。

#### 签名

```js
ctx.utils.hexDecode(value)
```

#### 参数

- `value`

#### 返回值

- 返回解码后的字符串

#### 示例

```js
const decoded = ctx.utils.hexDecode('616263');
```

### 方法：`ctx.utils.encodeUri(value)`

#### 功能

对完整 URI / URL 做编码。

#### 签名

```js
ctx.utils.encodeUri(value)
```

#### 参数

- `value`

#### 返回值

- 返回编码后的字符串

#### 示例

```js
const encoded = ctx.utils.encodeUri('https://example.com/书?q=hello world');
```

### 方法：`ctx.utils.decodeUri(value)`

#### 功能

对完整 URI / URL 做解码。

#### 签名

```js
ctx.utils.decodeUri(value)
```

#### 参数

- `value`

#### 返回值

- 返回解码后的字符串

#### 示例

```js
const decoded = ctx.utils.decodeUri('https://example.com/%E4%B9%A6?q=hello%20world');
```

### 方法：`ctx.utils.encodeUriComponent(value)`

#### 功能

对 URL 参数值做编码。

#### 签名

```js
ctx.utils.encodeUriComponent(value)
```

#### 参数

- `value`

#### 返回值

- 返回编码后的字符串

#### 示例

```js
const q = ctx.utils.encodeUriComponent('凡人修仙传 & 忘语');
```

### 方法：`ctx.utils.decodeUriComponent(value)`

#### 功能

对 URL 参数值做解码。

#### 签名

```js
ctx.utils.decodeUriComponent(value)
```

#### 参数

- `value`

#### 返回值

- 返回解码后的字符串

#### 示例

```js
const q = ctx.utils.decodeUriComponent('%E5%87%A1%E4%BA%BA%E4%BF%AE%E4%BB%99%E4%BC%A0');
```

### 方法：`ctx.utils.getDeviceInfo()`

#### 功能

获取当前宿主设备与安装实例的运行时信息。

#### 签名

```js
await ctx.utils.getDeviceInfo()
```

#### 参数

- 无

#### 返回值

- 返回设备信息对象

#### 示例

```js
const device = await ctx.utils.getDeviceInfo();
ctx.log(`device=${device.platform}:${device.installId}`);
```

#### 注意事项

- 更适合调试、设备隔离缓存、设备标识场景

### 方法：`ctx.utils.getUserId()`

#### 功能

获取当前 App 登录用户 ID。

#### 签名

```js
await ctx.utils.getUserId()
```

#### 参数

- 无

#### 返回值

- 返回用户 ID 或 `null`

#### 示例

```js
const userId = await ctx.utils.getUserId();
const cacheKey = userId ? `feed:${userId}` : 'feed:guest';
```

#### 注意事项

- 这是宿主用户 ID，不是目标站点用户 ID

## 7. `ctx.cookie`

### 方法：`ctx.cookie.get(name)`

#### 功能

获取当前源上下文里的指定 cookie。

#### 签名

```js
ctx.cookie.get(name)
```

#### 参数

- `name`：cookie 名称

#### 返回值

- 返回 cookie 值，拿不到时通常为空

#### 示例

```js
const sessionId = ctx.cookie.get('SESSIONID');
```

#### 注意事项

- 这是当前源上下文视角，不是全浏览器开发者工具视角

### 方法：`ctx.cookie.getAll()`

#### 功能

获取当前源上下文中的全部 cookie。

#### 签名

```js
ctx.cookie.getAll()
```

#### 参数

- 无

#### 返回值

- 返回 cookie 集合

#### 示例

```js
const cookies = ctx.cookie.getAll();
```

#### 注意事项

- 适合调试 cookie 状态

### 方法：`ctx.cookie.getForUrl(url, name?)`

#### 功能

以目标 URL 视角读取当前上下文中可匹配的 cookie。

#### 签名

```js
ctx.cookie.getForUrl(url, name?)
```

#### 参数

- `url`：目标地址
- `name`：可选 cookie 名

#### 返回值

- 返回单个 cookie 值或可用于该 URL 的 cookie 集合

#### 示例

```js
const sessionId = ctx.cookie.getForUrl('https://example.com', 'SESSIONID');
```

#### 注意事项

- 这个视角比 `getAll()` 更贴近真实请求携带结果

### 方法：`ctx.cookie.set(name, value)`

#### 功能

写入或更新一个 cookie。

#### 签名

```js
ctx.cookie.set(name, value)
```

#### 参数

- `name`
- `value`

#### 返回值

- 无

#### 示例

```js
ctx.cookie.set('custom_token', 'abc');
```

#### 注意事项

- 适合规则内同步某些已知 cookie

### 方法：`ctx.cookie.remove(name)`

#### 功能

删除指定名称的 cookie。

#### 签名

```js
ctx.cookie.remove(name)
```

#### 参数

- `name`

#### 返回值

- 无

#### 示例

```js
ctx.cookie.remove('SESSIONID');
```

#### 注意事项

- 适合登录前清理旧状态

### 方法：`ctx.cookie.clearDomain(domain)`

#### 功能

清理当前源上下文里与某个域名相关的 cookie 集合。

#### 签名

```js
ctx.cookie.clearDomain(domain)
```

#### 参数

- `domain`

#### 返回值

- 无

#### 示例

```js
ctx.cookie.clearDomain('example.com');
```

#### 注意事项

- 当前是“当前源 session 视角”的域名清理，不是浏览器级完整删除器

## 8. `ctx.cache`

### 方法：`ctx.cache.get(key)`

#### 功能

读取缓存。

#### 签名

```js
ctx.cache.get(key)
```

#### 参数

- `key`

#### 返回值

- 返回缓存值

#### 示例

```js
const cached = ctx.cache.get(`search:${keyword}`);
```

#### 注意事项

- 适合减少重复请求

### 方法：`ctx.cache.set(key, value)`

#### 功能

写入缓存。

#### 签名

```js
ctx.cache.set(key, value)
```

#### 参数

- `key`
- `value`

#### 返回值

- 无

#### 示例

```js
ctx.cache.set(`search:${keyword}`, books);
```

#### 注意事项

- 只放可序列化、可复用的数据

### 方法：`ctx.cache.remove(key)`

#### 功能

删除指定缓存项。

#### 签名

```js
ctx.cache.remove(key)
```

#### 参数

- `key`

#### 返回值

- 无

#### 示例

```js
ctx.cache.remove(`search:${keyword}`);
```

### 方法：`ctx.cache.clearPrefix(prefix)`

#### 功能

按前缀清理缓存。

#### 签名

```js
ctx.cache.clearPrefix(prefix)
```

#### 参数

- `prefix`

#### 返回值

- 无

#### 示例

```js
ctx.cache.clearPrefix('search:');
```

## 9. `ctx.session`

### 方法：`ctx.session.get(key)`

#### 功能

读取当前源 session 中的值。

#### 签名

```js
ctx.session.get(key)
```

#### 参数

- `key`

#### 返回值

- 返回 session 值

#### 示例

```js
const initialized = ctx.session.get('initialized');
```

### 方法：`ctx.session.set(key, value)`

#### 功能

写入当前源 session 值。

#### 签名

```js
ctx.session.set(key, value)
```

#### 参数

- `key`
- `value`

#### 返回值

- 无

#### 示例

```js
ctx.session.set('initialized', true);
```

### 方法：`ctx.session.clear(key?)`

#### 功能

清空某个 session 键，或清空整个 session。

#### 签名

```js
ctx.session.clear(key?)
```

#### 参数

- `key`：可选

#### 返回值

- 无

#### 示例

```js
ctx.session.clear('initialized');
ctx.session.clear();
```

### 方法：`ctx.session.cookies()`

#### 功能

查看当前 session 里的 cookie 视图。

#### 签名

```js
ctx.session.cookies()
```

#### 参数

- 无

#### 返回值

- 返回 cookie 视图

#### 示例

```js
const cookies = ctx.session.cookies();
```

#### 注意事项

- `session` 适合放“当前源是否还能继续执行”的状态
- 减少重复请求的数据优先放 `cache`

## 10. `ctx.log`

### 方法：`ctx.log(message)`

#### 功能

向调试面板写入一条日志。

#### 签名

```js
ctx.log(message)
```

#### 参数

- `message`：日志文本

#### 返回值

- 无

#### 示例

```js
ctx.log(`search keyword=${keyword}`);
```

#### 注意事项

- 适合记录关键阶段信息
- 不要在高频循环里无节制打印大量日志

## 11. 下一步

后续继续查看：

- [宿主运行时加解密 API v2](./runtime-ctx-crypto-v2.md)
- [书源标准对象参考](./source-object-reference.md)
