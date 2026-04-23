# 书源方法说明模板

更新时间：2026-04-23
适用范围：`flutterreadbook`

## 1. 目的

统一书源文档中所有方法的说明格式。

后续不管是：

- `ctx.utils.absoluteUrl(...)`
- `ctx.http.request(...)`
- `ctx.html.parse(...)`
- `ctx.browser.challenge(...)`
- `ctx.cookie.get(...)`
- `ctx.session.set(...)`
- `ctx.crypto.sha256(...)`
- `ctx.log(...)`

都应按同一套格式写，避免风格混乱。

## 2. 标准模板

## 方法：`方法名`

### 功能

说明这个方法是干什么的。

### 签名

```js
方法调用写法
```

### 参数

- `参数名`：说明
- `参数名`：说明

### 返回值

- 返回什么类型
- 特殊情况下返回什么

### 示例

```js
示例代码
```

### 注意事项

- 使用时要注意什么
- 常见边界是什么
- 不会帮你做什么

## 3. 示例一：`ctx.utils.absoluteUrl(base, path)`

### 功能

将相对地址基于当前页面地址补成完整绝对地址。

### 签名

```js
ctx.utils.absoluteUrl(base, path)
```

### 参数

- `base`：当前页面的基准地址
- `path`：目标地址，可以是相对路径、站内路径或完整地址

### 返回值

- 返回补全后的绝对地址字符串

### 示例

```js
const url = ctx.utils.absoluteUrl(
  'https://example.com/book/123.html',
  '/chapter/1.html',
);
```

### 注意事项

- 如果 `path` 已经是完整地址，应直接返回完整地址
- 目录链接、正文链接、图片链接都建议统一走这个方法补全
- 不要在书源里手写大量字符串拼接来补 URL

## 4. 示例二：`ctx.http.request(options)`

### 功能

发起一次宿主 HTTP 请求。

### 签名

```js
await ctx.http.request(options)
```

### 参数

- `options`：请求配置对象，例如 `url`、`method`、`headers`、`body`

### 返回值

- 返回宿主统一响应对象
- 可再配合 `ctx.http.isHtml(...)`、`ctx.http.isJson(...)` 等工具判断响应类型

### 示例

```js
const response = await ctx.http.request({
  url: 'https://example.com/search?q=' + encodeURIComponent(keyword),
  method: 'GET',
});
```

### 注意事项

- 普通请求优先走 `ctx.http.request(...)`
- 只有需要浏览器验证或页面脚本执行时，再升级到 `ctx.browser.*`
- 不要把它当成浏览器环境替代品

## 5. 示例三：`ctx.browser.challenge(options)`

### 功能

进入浏览器挑战流程，让规则在验证码、登录或页面风控通过后继续执行。

### 签名

```js
await ctx.browser.challenge(options)
```

### 参数

- `options`：浏览器挑战配置，例如 `url`、`reason`、等待条件等

### 返回值

- 一般不依赖直接返回值
- 核心效果是让浏览器流程完成后，Cookie/状态回流到当前源上下文

### 示例

```js
await ctx.browser.challenge({
  url: 'https://example.com/protected',
  reason: '需要通过站点验证后继续请求',
});
```

### 注意事项

- 这是浏览器兜底能力，不应作为默认主链
- 目标是“让流程继续”，不是单纯打开一个页面给用户看
- 挑战成功后，后续普通 `ctx.http.request(...)` 仍应优先作为继续请求手段

## 6. 适用范围

本模板适用于：

- `ctx.source.*`
- `ctx.http.*`
- `ctx.html.*`
- `ctx.browser.*`
- `ctx.cookie.*`
- `ctx.cache.*`
- `ctx.session.*`
- `ctx.utils.*`
- `ctx.crypto.*`
- `ctx.log(...)`

## 7. 使用要求

后续新增方法说明时，统一要求：

- 只写当前 JS / 书源运行时口径
- 不引入 Java、Dart、Python 风格的方法签名描述
- 示例必须使用书源脚本写法
- 注意事项必须明确边界
