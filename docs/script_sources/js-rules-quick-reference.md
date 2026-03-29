# JS 规则速查

更新时间：2026-03-27

这份文档只做一件事：

- 把 `flutterreadbook` 当前的两套 JS 写法放到一起讲清楚
- 说明哪些是主线，哪些只是兼容层
- 给出可直接复制的模板入口

如果你不想在多份文档之间来回切换，先读这份速查，再按需展开到手册和 API 文档。

相关文档：

- [官方书源编写手册](./official-source-author-guide.md)
- [书源规范 v1](./source-spec-v1.md)
- [宿主运行时 API](./runtime-ctx-api.md)
- [标准完整模板](../templates/source_template_v1.js)

## 1. 先分清两套 JS

### 1.1 旧规则 JS

旧规则 JS 指的是写在旧规则 JSON 里的内联脚本，常见形态有：

- `@js:...`
- `js:...`
- `<js>...</js>`

它的特点是：

- 通常嵌在 `html:` / `json:` / `regex:` / `xpath:` 规则链里
- 更像“表达式补丁”或“兼容脚本”
- 当前仓库仍支持，但整体定位是兼容层

### 1.2 新 JS 规则

当前仓库真正的“新 JS 规则”主线，不再是给旧规则字段里塞一段脚本，而是直接写一个脚本源文件：

```js
export default {
  meta: {},
  async init(ctx, task) {},
  async search(ctx, keyword) {},
  async detail(ctx, book) {},
  async chapters(ctx, book) {},
  async content(ctx, book, chapter) {},
};
```

它的特点是：

- 直接以 `.js` 文件表达书源
- 逻辑、元信息、上下文都在一个文件里
- 新功能、新能力、新模板都应该优先写这套

一句话判断：

- 新写书源，用脚本源
- 兼容旧 JSON 规则，才继续看 `js:` / `<js>`

## 2. 什么时候用哪一套

- 新建书源：用脚本源
- 重写复杂旧源：用脚本源
- 涉及验证码、登录、浏览器页面、动态接口：用脚本源
- 只是修一个旧规则源的小问题：可以先保留旧规则 JS
- 导入的源里出现 `Reload(...)`、`Packages.*`、文件解压/字体桥接：不要继续堆补丁，直接评估迁移到脚本源

## 3. 旧规则 JS 速查

### 3.1 常见写法

直接脚本：

```js
@js:result.replace('a', 'b')
```

或：

```js
js:result.trim()
```

或：

```js
<js>
result.replace(/foo/g, 'bar')
</js>
```

前置规则后接 JS：

```js
html:.name@text@js:result.trim()
```

流水线中间插入 `<js>`：

```js
json:$.bid
<js>1100000000 + parseInt(result)</js>
https://example.com/book?bookid={{result}}
```

### 3.2 旧规则链里还能配合什么

当前规则引擎仍支持这些组合能力：

- `html:` 提取
- `json:` 提取
- `regex:` 提取
- `xpath:` 提取
- `&&` 合并
- `||` 回退
- `%%` 多列表交错输出
- `{{...}}` 模板嵌套
- `$1` 这类正则分组引用

示例：

```js
html:.a@text&&html:.b@text||html:.c@text
```

```js
html:.a li@text%%html:.b li@text
```

```js
书名:{{@@.title@text}} 作者:{{@@.author@text}}
```

### 3.3 旧规则 JS 里可直接用的上下文

当前规则执行时，常见上下文包括：

- `result`
- `baseUrl`
- `book`
- `chapter`
- `source`

常见例子：

```js
@js:[book.name, chapter.url, source.bookSourceUrl].join('|')
```

### 3.4 旧规则 JS 的兼容边界

当前仓库对旧规则 JS 的态度是“尽量兼容，但不再把它当主线扩展点”。

明确边界如下：

- 规则中出现 `<js>` / `js:`，兼容分析会标记为“部分兼容”
- `Reload(...)` 当前不支持
- `Packages.*` 当前不支持
- 明显死循环，如 `while(true){}` / `for(;;)`，会被保护性跳过
- `java.*` 仍保留了大量桥接，但语义分成“较完整兼容 / 部分兼容 / 不支持”

建议按下面方式判断风险：

- 低风险：
  只做 `result` 字符串加工，或用 `java.put/get`、`java.getString`、`java.base64Decode`、`java.md5Encode`、`java.aesBase64DecodeToString` 这类基础桥接
- 中风险：
  使用 `java.ajax`、`java.get/post/head/connect`、`java.cacheFile`、`java.webViewGetSource`
- 高风险：
  使用 `java.startBrowser`、`java.startBrowserAwait`、`java.webView`、`java.importScript`、`java.createAsymmetricCrypto`
- 直接重写：
  使用 `Reload(...)`、`Packages.*`、文件读写、压缩包解压、字体查询替换

### 3.5 旧规则 JS 到脚本源的迁移建议

不要把旧规则 JS 原样整段搬进新模板里继续堆 `java.*`。

优先替换成脚本源上下文能力：

- `java.ajax/get/post/head/connect` -> `ctx.http.request(...)`
- `java.base64Decode/base64Encode` -> `ctx.utils.base64Decode / base64Encode`
- `java.md5Encode / digest / hmac / aes / des` -> `ctx.crypto.*`
- `java.startBrowserAwait / webView / webViewGetSource` -> `ctx.browser.*`
- `java.put/get` 的临时状态 -> `ctx.session.*` 或 `book.extra / chapter.extra`

## 4. 新脚本源规则速查

### 4.1 最小结构

脚本源至少要满足：

- 使用 `export default { ... }` 导出
- 带 `meta`
- 至少实现 `search`、`detail`、`chapters`、`content`
- `init` 可选

最小骨架：

```js
export default {
  meta: {
    name: '示例书源',
    group: '默认分组',
    author: 'your_name',
    description: '一个最小可用的示例书源',
    domains: ['www.example.com'],
    homepage: 'https://www.example.com',
    enabled: true,
    capabilities: ['search', 'detail', 'chapters', 'content'],
  },

  async init(ctx, task) {},
  async search(ctx, keyword) { return []; },
  async detail(ctx, book) { return book; },
  async chapters(ctx, book) { return []; },
  async content(ctx, book, chapter) {
    return {
      title: chapter.title,
      content: '',
      sourceId: ctx.source.id,
    };
  },
};
```

### 4.2 编辑器当前校验要求

当前脚本编辑器会直接检查这些条件：

- 不能是旧规则 JSON
- 必须使用 `export default { ... }` 或 `globalThis.__sourceDefinition = { ... }`
- 必须包含 `meta`
- 必须包含 `meta.name`

也就是说，新书源不要再从旧 JSON 开始改，直接从脚本模板起步更稳。

### 4.3 `ctx` 顶层能力

当前脚本源运行时开放的是：

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

推荐理解：

- `ctx.http` 负责请求
- `ctx.html` 负责 DOM 解析和提取
- `ctx.browser` 负责浏览器挑战和动态页面
- `ctx.session` 负责当前源会话状态
- `ctx.crypto` 负责摘要、加解密、签名
- `ctx.utils` 负责 URL、编码、文本、时间等通用处理

### 4.4 标准返回对象

新脚本源统一返回三类对象：

- `Book`
- `Chapter`
- `Content`

推荐做法：

- 标准字段尽量补齐
- 站点私有字段放 `extra`
- 调试字段放 `debug`

关于 `id`：

- `ctx.source.id` 是源被添加到 App 后，宿主自动生成并注入的源 ID
- `Book.id` / `Chapter.id` 是结果对象自己的字段，不是源 ID
- 站点有稳定主键时可以显式填写
- 没有稳定主键时，可以优先把真实请求参数放进 `extra`
- 当前 `flutterreadbook` 产品链会按 `detailUrl` / `chapterUrl` 做兜底标识

### 4.5 新脚本源推荐写法

- helper 显式接收 `ctx`
- 跨步骤传参统一放 `extra`
- 公共 token / session 值放 `ctx.session`
- 明确需要浏览器时，再调用 `ctx.browser`
- 新逻辑优先使用 `ctx.*`，不要再默认从 `java.*` 开始写

## 5. 模板入口

当前仓库模板分两类：

- [标准完整模板](../templates/source_template_v1.js)
  这是当前沿用 `flutter_testjs` 主线模板整理出的官方示例入口
- [最小骨架模板](../templates/source_template_minimal_v1.js)
  这是当前仓库补充的本地简化示例，适合快速起手
- [HTML 站点模板](../templates/source_template_html_v1.js)
  这是当前仓库补充的本地 HTML 示例
- [JSON API 模板](../templates/source_template_api_v1.js)
  这是当前仓库补充的本地 API 示例

怎么选：

- 完全没思路：先从“标准完整模板”开始
- 只想要最小空架子：用“最小骨架模板”
- 站点就是传统页面抓取：用“HTML 站点模板”
- 站点主要走接口：用“JSON API 模板”

## 6. 旧规则到新脚本源的职责映射

旧规则字段大致可以这样迁移：

- `ruleSearch` -> `search(ctx, keyword)`
- `ruleBookInfo` -> `detail(ctx, book)`
- `ruleToc` -> `chapters(ctx, book)`
- `ruleContent` -> `content(ctx, book, chapter)`
- `jsLib` -> 脚本文件内的 helper / 局部函数

迁移时不要一比一搬字段名，更应该按“职责”搬：

- 搜索阶段返回 `Book[]`
- 详情阶段补全单本 `Book`
- 目录阶段返回 `Chapter[]`
- 正文阶段返回 `Content`

## 7. 推荐阅读顺序

如果你现在要开始写新源，建议按这个顺序看：

1. 先看这份 [JS 规则速查](./js-rules-quick-reference.md)
2. 再看 [官方书源编写手册](./official-source-author-guide.md)
3. 需要确认结构时看 [书源规范 v1](./source-spec-v1.md)
4. 需要确认宿主边界时看 [运行时 API](./runtime-ctx-api.md)
