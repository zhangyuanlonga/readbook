# 官方书源编写手册

更新时间：2026-04-23  
适用范围：`flutterreadbook`

## 1. 文档说明

这份手册面向“书源作者”。

当前约定：

- `flutterreadbook` 当前只支持脚本源
- App 不再导入或执行旧规则 JSON
- 一个书源就是一个 `export default { ... }` 的 JavaScript 文件

这份手册是唯一保留的书源编写文档，主要解决这些问题：

- 书源文件整体应该怎么写
- `meta` 怎么写
- `search / detail / chapters / content` 每个方法分别怎么写
- `ctx.*` 都能做什么
- 标准对象应该返回什么结构
- 写完后怎么调试和检查

相关模板：

- 官方模板：[source_template_v1.js](../templates/source_template_v1.js)

## 2. 快速开始

一个最小可运行书源至少需要：

- `meta`
- `search(ctx, keyword)`
- `detail(ctx, book)`
- `chapters(ctx, book)`
- `content(ctx, book, chapter)`

最小示例：

```js
export default {
  meta: {
    name: '示例书源',
    author: 'your-name',
    description: '一个最小可运行示例',
    group: '小说',
    checkKeyword: '斗罗大陆',
  },

  async search(ctx, keyword) {
    return [];
  },

  async detail(ctx, book) {
    return book;
  },

  async chapters(ctx, book) {
    return [];
  },

  async content(ctx, book, chapter) {
    return {
      title: chapter.title,
      content: '',
    };
  },
};
```

如果你是第一次写，建议按这个顺序完成：

1. 先把 `meta` 写完整
2. 先让 `search` 能返回正确的 `Book[]`
3. 再写 `detail`
4. 再写 `chapters`
5. 最后写 `content`

不要一开始就在 `search()` 里顺手做详情、目录、正文。

## 3. 书源文件整体结构

推荐把一个书源文件写成这样：

```js
const SOURCE_HOST = 'https://www.example.com';

export default {
  meta: {
    name: '示例书源',
    author: 'your-name',
    description: '一个示例站点',
    group: '小说',
    homepage: SOURCE_HOST,
    checkKeyword: '斗罗大陆',
  },

  async init(ctx, task) {
    // 可选
  },

  async search(ctx, keyword) {
    // 必需
  },

  async detail(ctx, book) {
    // 必需
  },

  async chapters(ctx, book) {
    // 必需
  },

  async content(ctx, book, chapter) {
    // 必需
  },

  // async discoverCategories(ctx) {},
  // async discoverBooks(ctx, category, page, pageSize) {},
};
```

推荐组织方式：

- 顶部放站点常量
- `meta` 放最前
- 核心方法按执行顺序写
- 可选能力放后面

## 4. `meta` 怎么写

## 方法：`meta`

### 功能

描述这个书源是谁、做什么、默认检测词是什么、需要哪些宿主能力。

### 签名

```js
meta: {
  name: '...',
  author: '...',
  description: '...',
  group: '...',
  homepage: 'https://...',
  checkKeyword: '...',
  domains: ['example.com'],
  capabilities: ['discover'],
}
```

### 参数

`meta` 不是函数，没有运行时参数。  
它是脚本源导出的静态元信息对象。

### 返回值

无返回值。  
宿主会在编译和保存书源时读取这个对象。

### 示例

```js
meta: {
  name: '示例书源',
  author: 'your-name',
  description: '一个演示 HTML + API 混合流程的书源',
  group: '小说',
  homepage: 'https://www.example.com',
  checkKeyword: '凡人修仙传',
  domains: ['www.example.com'],
}
```

### 注意事项

- `name` 基本上应视为必填
- `checkKeyword` 很重要，影响单源检测和调试默认关键词
- `homepage` 与 `domains` 建议尽量填写，方便站点识别与归类
- 如果实现了 `discoverCategories / discoverBooks`，再声明 `discover` 能力
- 不要把运行时状态写进 `meta`

## 5. 核心方法

这四个方法是最重要的部分。  
后续所有“作者怎么写”的核心，都围绕这四个方法展开。

### 5.1 方法：`search(ctx, keyword)`

#### 功能

根据关键词返回候选书籍列表。

#### 参数

- `ctx`：宿主上下文
- `keyword`：搜索关键词

#### 返回值

- 返回 `Book[]`
- 每一项至少应能让后续 `detail(ctx, book)` 继续工作
- 最少建议保证：
  - `title`
  - `detailUrl`
  - `author`（推荐）

#### 示例

```js
async search(ctx, keyword) {
  const response = await ctx.http.request({
    url: 'https://example.com/search',
    method: 'GET',
    query: { q: keyword },
    responseType: 'text',
  });

  const doc = ctx.html.parse(response.text);
  const items = doc.querySelectorAll('.book-item');

  return ctx.html.collect(items, (item) => ({
    title: ctx.html.text(item.querySelector('.title')),
    author: ctx.html.text(item.querySelector('.author')),
    detailUrl: ctx.utils.absoluteUrl(
      'https://example.com/search',
      ctx.html.attr(item.querySelector('a'), 'href'),
    ),
  }));
}
```

#### 注意事项

- `search` 的职责是“找书”，不是补齐详情
- 搜索结果里不要顺手追加详情页、目录页、正文页请求
- 如果返回的 `detailUrl` 为空，后续 `detail` 往往无法继续
- 如果接口是 JSON，直接映射为标准 `Book[]`
- 如果接口是 HTML，优先：
  - `ctx.http.request(...)`
  - `ctx.html.parse(...)`
  - `ctx.html.collect(...)`

### 5.2 方法：`detail(ctx, book)`

#### 功能

根据搜索阶段返回的书对象，补齐详情字段。

#### 参数

- `ctx`：宿主上下文
- `book`：上一步 `search()` 返回的单本书

#### 返回值

- 返回一个 `Book`
- 推荐保留原有字段，再补：
  - `intro`
  - `cover`
  - `status`
  - `category`
  - `wordCount`
  - `updateTime`
  - `latestChapter`
  - `tocUrl`

#### 示例

```js
async detail(ctx, book) {
  const response = await ctx.http.request({
    url: book.detailUrl,
    method: 'GET',
    responseType: 'text',
  });

  const doc = ctx.html.parse(response.text);

  return {
    ...book,
    intro: ctx.html.text(doc.querySelector('.book-intro')),
    cover: ctx.utils.absoluteUrl(
      book.detailUrl,
      ctx.html.attr(doc.querySelector('.book-cover img'), 'src'),
    ),
    status: ctx.html.text(doc.querySelector('.book-status')),
    latestChapter: ctx.html.text(doc.querySelector('.book-latest')),
    tocUrl: ctx.utils.absoluteUrl(
      book.detailUrl,
      ctx.html.attr(doc.querySelector('.catalog-link'), 'href'),
    ),
  };
}
```

#### 注意事项

- 推荐写法是：`return { ...book, ...补充字段 }`
- 不要把 `search` 阶段的关键字段丢掉
- `tocUrl` 很重要，目录通常依赖它
- 如果详情页里没有单独目录地址，`tocUrl` 可以回退到 `detailUrl`
- 如果详情字段本来就来自 API，可以直接映射，不一定要解析 HTML

### 5.3 方法：`chapters(ctx, book)`

#### 功能

返回某本书的完整目录列表。

#### 参数

- `ctx`：宿主上下文
- `book`：一般应使用 `detail()` 补充后的书对象

#### 返回值

- 返回 `Chapter[]`
- 最少建议保证：
  - `title`
  - `url`
  - `index`

#### 示例

```js
async chapters(ctx, book) {
  const response = await ctx.http.request({
    url: book.tocUrl || book.detailUrl,
    method: 'GET',
    responseType: 'text',
  });

  const doc = ctx.html.parse(response.text);
  const nodes = doc.querySelectorAll('.chapter-list a');

  return ctx.html.collect(nodes, (node, index) => ({
    title: ctx.html.text(node),
    url: ctx.utils.absoluteUrl(
      book.tocUrl || book.detailUrl,
      ctx.html.attr(node, 'href'),
    ),
    index,
  }));
}
```

#### 注意事项

- `chapters` 的职责是“返回完整目录”
- 如果目录分页，必须自己翻页拼全，不要只抓第一页
- `index` 应该稳定，最好按最终顺序重新编号
- 分卷标题节点如果不是正文页，不要误当作普通章节
- 如果目录总是只有一部分，第一怀疑点通常就是“目录分页没处理”

### 5.4 方法：`content(ctx, book, chapter)`

#### 功能

返回单章正文。

#### 参数

- `ctx`：宿主上下文
- `book`：书籍对象
- `chapter`：章节对象

#### 返回值

- 返回 `Content`
- 最少建议保证：
  - `title`
  - `content`

#### 示例

```js
async content(ctx, book, chapter) {
  const response = await ctx.http.request({
    url: chapter.url,
    method: 'GET',
    responseType: 'text',
  });

  const doc = ctx.html.parse(response.text);

  return {
    title: ctx.html.text(doc.querySelector('.chapter-title')) || chapter.title,
    content: ctx.html.text(doc.querySelector('.chapter-content')),
  };
}
```

#### 注意事项

- `content` 返回的是对象，不是纯字符串
- 如果正文分页，必须在这里自行合并
- 如果正文是图片型内容，可以返回 `images`
- 如果正文为空，优先检查：
  - 章节 URL 是否正确
  - 页面是否被挑战页替换
  - 选择器是否选到了广告容器或空节点

## 6. 可选方法

### 6.1 方法：`init(ctx, task)`

#### 功能

在正式步骤执行前做准备工作。

#### 参数

- `ctx`
- `task`

#### 返回值

- 一般无返回值

#### 示例

```js
async init(ctx, task) {
  if (task.step !== 'search') {
    return;
  }

  if (!ctx.session.get('initialized')) {
    ctx.session.set('initialized', true);
    ctx.log(`init for ${task.step}`);
  }
}
```

#### 注意事项

- 适合做 token 初始化、session 准备、预热请求
- 不要把整条搜索/详情逻辑塞进 `init`

### 6.2 方法：`discoverCategories(ctx)`

#### 功能

返回发现页分类列表。

#### 参数

- `ctx`

#### 返回值

- 返回 `DiscoverCategory[]`

#### 示例

```js
async discoverCategories(ctx) {
  return [
    {
      title: '玄幻',
      url: 'https://example.com/discover/xuanhuan',
    },
  ];
}
```

#### 注意事项

- 只负责“给分类”
- 每项至少要能让后续 `discoverBooks` 识别

### 6.3 方法：`discoverBooks(ctx, category, page, pageSize)`

#### 功能

根据分类返回书籍列表。

#### 参数

- `ctx`
- `category`
- `page`
- `pageSize`

#### 返回值

- 返回 `Book[]`

#### 示例

```js
async discoverBooks(ctx, category, page, pageSize) {
  const response = await ctx.http.request({
    url: category.url,
    method: 'GET',
    query: { page, pageSize },
    responseType: 'text',
  });

  const doc = ctx.html.parse(response.text);
  return ctx.html.collect(doc.querySelectorAll('.book-item'), (item) => ({
    title: ctx.html.text(item.querySelector('.title')),
    author: ctx.html.text(item.querySelector('.author')),
    detailUrl: ctx.utils.absoluteUrl(
      category.url,
      ctx.html.attr(item.querySelector('a'), 'href'),
    ),
  }));
}
```

#### 注意事项

- 和 `search` 很像，但输入是分类而不是关键词
- 如果声明了发现能力，建议 `discoverCategories` 和 `discoverBooks` 成对实现

## 7. `ctx` 能做什么

书源里常用的宿主能力主要是：

- `ctx.source`
- `ctx.http`
- `ctx.html`
- `ctx.browser`
- `ctx.cookie`
- `ctx.cache`
- `ctx.session`
- `ctx.utils`
- `ctx.crypto`
- `ctx.log`

下面按命名空间整理。

## 8. `ctx.source`

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

- 这是宿主生成的 ID，不要求作者手写

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

- 更适合调试和日志

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

- 不建议把分组当成强业务依赖

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

## 9. `ctx.http`

### 方法：`ctx.http.request(options)`

#### 功能

发起一次宿主 HTTP 请求。

#### 签名

```js
await ctx.http.request(options)
```

#### 参数

- `options.url`
- `options.method`
- `options.headers`
- `options.query`
- `options.body`
- `options.bodyType`
- `options.timeoutMs`
- `options.responseType`
- `options.charset`
- `options.referer`
- `options.execution`
- `options.webView`

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

#### 注意事项

- 普通请求优先走 `ctx.http.request(...)`
- 命中挑战页后再考虑浏览器流程

### 方法：`ctx.http.isHtml(response)`

#### 功能

判断响应是否适合按 HTML 处理。

#### 签名

```js
ctx.http.isHtml(response)
```

#### 参数

- `response`

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

### 方法：`ctx.http.isJson(response)`

#### 功能

判断响应是否适合按 JSON 处理。

#### 签名

```js
ctx.http.isJson(response)
```

#### 参数

- `response`

#### 返回值

- `boolean`

#### 示例

```js
if (ctx.http.isJson(response)) {
  return response.json?.rows || [];
}
```

#### 注意事项

- 适合 API / HTML 混合场景

### 方法：`ctx.http.isRedirect(response)`

#### 功能

判断响应是否发生了跳转。

#### 签名

```js
ctx.http.isRedirect(response)
```

#### 参数

- `response`

#### 返回值

- `boolean`

#### 示例

```js
if (ctx.http.isRedirect(response)) {
  ctx.log(`redirected to ${response.url}`);
}
```

#### 注意事项

- 适合排查登录页、风控页跳转

### 方法：`ctx.http.isChallenge(response)`

#### 功能

判断响应是否命中了挑战页。

#### 签名

```js
ctx.http.isChallenge(response)
```

#### 参数

- `response`

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

- 不要把浏览器流程当默认主路

## 10. `ctx.html`

### 方法：`ctx.html.parse(html)`

#### 功能

把 HTML 字符串解析成可查询文档对象。

#### 签名

```js
ctx.html.parse(html)
```

#### 参数

- `html`

#### 返回值

- 返回文档对象

#### 示例

```js
const doc = ctx.html.parse(response.text);
```

#### 注意事项

- 输入应是 HTML 字符串

### 方法：`ctx.html.text(node)`

#### 功能

获取节点文本内容。

#### 签名

```js
ctx.html.text(node)
```

#### 参数

- `node`

#### 返回值

- 返回字符串

#### 示例

```js
const title = ctx.html.text(doc.querySelector('.book-title'));
```

#### 注意事项

- 适合书名、作者、简介、章节名

### 方法：`ctx.html.innerHtml(node)`

#### 功能

获取元素内部 HTML 片段。

#### 签名

```js
ctx.html.innerHtml(node)
```

#### 参数

- `node`

#### 返回值

- 返回 HTML 字符串

#### 示例

```js
const html = ctx.html.innerHtml(doc.querySelector('.content'));
```

#### 注意事项

- 如果你要保留正文中的图片或标签，用它比 `text(...)` 更合适

### 方法：`ctx.html.attr(node, name)`

#### 功能

读取节点属性值。

#### 签名

```js
ctx.html.attr(node, name)
```

#### 参数

- `node`
- `name`

#### 返回值

- 返回字符串

#### 示例

```js
const href = ctx.html.attr(doc.querySelector('a'), 'href');
```

#### 注意事项

- 常用于 `href / src`
- 相对地址通常还要配合 `ctx.utils.absoluteUrl(...)`

### 方法：`ctx.html.collect(nodes, mapper)`

#### 功能

遍历节点集合并映射成结构化数组。

#### 签名

```js
ctx.html.collect(nodes, mapper)
```

#### 参数

- `nodes`
- `mapper`

#### 返回值

- 返回数组

#### 示例

```js
const books = ctx.html.collect(
  doc.querySelectorAll('.book-item'),
  (node) => ({
    title: ctx.html.text(node.querySelector('.title')),
    author: ctx.html.text(node.querySelector('.author')),
  }),
);
```

#### 注意事项

- 搜索结果、目录列表最适合用它统一收集

## 11. `ctx.browser`

### 方法：`ctx.browser.open(options)`

#### 功能

打开一个真实浏览器页面。

#### 签名

```js
await ctx.browser.open(options)
```

#### 参数

- `options.url`
- `options.timeoutMs`

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

- `open(...)` 只是打开页面，不代表完成登录或验证

### 方法：`ctx.browser.challenge(options)`

#### 功能

进入浏览器挑战流程，让验证码、登录或风控通过后继续执行。

#### 签名

```js
await ctx.browser.challenge(options)
```

#### 参数

- `options.url`
- `options.reason`
- `options.waitFor`
- `options.timeoutMs`

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
});
```

#### 注意事项

- 目标是“让流程继续”，不是单纯打开页面给用户看

### 方法：`ctx.browser.eval(options)`

#### 功能

在当前浏览器页面环境执行脚本并返回结果。

#### 签名

```js
await ctx.browser.eval(options)
```

#### 参数

- `options.script`

#### 返回值

- `Promise<any>`

#### 示例

```js
const token = await ctx.browser.eval({
  script: "localStorage.getItem('token')",
});
```

#### 注意事项

- 如果只取一个明确值，优先用 `eval(...)`

### 方法：`ctx.browser.waitForUrl(options)`

#### 功能

等待 URL 满足条件。

#### 签名

```js
await ctx.browser.waitForUrl(options)
```

#### 参数

- `options.includes`
- `options.timeoutMs`

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

- 更适合监听跳转

### 方法：`ctx.browser.waitForText(options)`

#### 功能

等待页面出现文本。

#### 签名

```js
await ctx.browser.waitForText(options)
```

#### 参数

- `options.text`
- `options.timeoutMs`

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

### 方法：`ctx.browser.getCookies()`

#### 功能

读取当前浏览器上下文的 cookie 集合。

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

- 更适合 challenge / 登录后的浏览器调试

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

- 适合调试跳转后页面位置

### 方法：`ctx.browser.getHtml()`

#### 功能

读取当前浏览器页面 HTML 快照。

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

- 如果只取单值，优先用 `eval(...)`

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

## 12. `ctx.cookie`

### 方法：`ctx.cookie.get(name)`

#### 功能

读取当前源上下文中的指定 cookie。

#### 签名

```js
ctx.cookie.get(name)
```

#### 参数

- `name`

#### 返回值

- 返回 cookie 值

#### 示例

```js
const sessionId = ctx.cookie.get('SESSIONID');
```

#### 注意事项

- 这是当前源上下文视角

### 方法：`ctx.cookie.getAll()`

#### 功能

读取当前源上下文里的全部 cookie。

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

### 方法：`ctx.cookie.getForUrl(url, name?)`

#### 功能

以目标 URL 视角读取可匹配 cookie。

#### 签名

```js
ctx.cookie.getForUrl(url, name?)
```

#### 参数

- `url`
- `name`

#### 返回值

- 返回单个 cookie 值或 cookie 集合

#### 示例

```js
const sessionId = ctx.cookie.getForUrl('https://example.com', 'SESSIONID');
```

#### 注意事项

- 这个视角更贴近真实请求携带结果

### 方法：`ctx.cookie.set(name, value)`

#### 功能

写入或更新 cookie。

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

### 方法：`ctx.cookie.remove(name)`

#### 功能

删除指定 cookie。

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

- 当前是当前源 session 视角，不是浏览器级完整删除器

## 13. `ctx.cache`

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

### 方法：`ctx.cache.remove(key)`

#### 功能

删除缓存项。

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

## 14. `ctx.session`

### 方法：`ctx.session.get(key)`

#### 功能

读取当前源 session 值。

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

查看当前 session 的 cookie 视图。

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

- `session` 更适合放“当前源是否还能继续执行”的状态
- 减少重复请求的数据优先放 `cache`

## 15. `ctx.utils`

### 方法：`ctx.utils.absoluteUrl(base, relative)`

#### 功能

把相对路径补成绝对地址。

#### 签名

```js
ctx.utils.absoluteUrl(base, relative)
```

#### 参数

- `base`
- `relative`

#### 返回值

- 返回绝对地址字符串

#### 示例

```js
const detailUrl = ctx.utils.absoluteUrl('https://example.com/search', '/book/123');
```

### 方法：`ctx.utils.sleep(duration)`

#### 功能

等待一段时间。

#### 签名

```js
await ctx.utils.sleep(duration)
```

#### 参数

- `duration`

#### 返回值

- `Promise<void>`

#### 示例

```js
await ctx.utils.sleep(500);
```

### 方法：`ctx.utils.pick(value, fallback)`

#### 功能

主值不可用时回退到备用值。

#### 签名

```js
ctx.utils.pick(value, fallback)
```

#### 参数

- `value`
- `fallback`

#### 返回值

- 返回最终值

#### 示例

```js
const title = ctx.utils.pick(ctx.html.text(doc.querySelector('.title')), '未知书名');
```

### 方法：`ctx.utils.normalizeText(text)`

#### 功能

对文本做基础规范化处理。

#### 签名

```js
ctx.utils.normalizeText(text)
```

#### 参数

- `text`

#### 返回值

- 返回规范化后的字符串

#### 示例

```js
const intro = ctx.utils.normalizeText(ctx.html.text(doc.querySelector('.intro')));
```

### 方法：`ctx.utils.timeFormat(value, pattern?)`

#### 功能

把时间值格式化成指定字符串。

#### 签名

```js
ctx.utils.timeFormat(value, pattern?)
```

#### 参数

- `value`
- `pattern`

#### 返回值

- 返回格式化后的字符串

#### 示例

```js
const text = ctx.utils.timeFormat('2026-03-25T08:09:10Z', 'yyyy-MM-dd HH:mm:ss');
```

### 方法：`ctx.utils.htmlFormat(value)`

#### 功能

把常见 HTML 片段清洗成纯文本。

#### 签名

```js
ctx.utils.htmlFormat(value)
```

#### 参数

- `value`

#### 返回值

- 返回文本

#### 示例

```js
const text = ctx.utils.htmlFormat('<p>hello<br>world</p>');
```

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

## 16. `ctx.crypto`

`ctx.crypto` 用于摘要、HMAC、加解密、签名验签、随机数、时间戳，以及签名常用的字节编码转换。

### 16.1 编码与字节工具

支持：

- `ctx.crypto.hexEncode(value, options?)`
- `ctx.crypto.hexDecode(value, options?)`
- `ctx.crypto.hexToBytes(value)`
- `ctx.crypto.bytesToHex(value)`
- `ctx.crypto.base64Encode(value, options?)`
- `ctx.crypto.base64Decode(value, options?)`
- `ctx.crypto.base64ToBytes(value)`
- `ctx.crypto.bytesToBase64(value)`

#### 方法：`ctx.crypto.hexDecode(value, options?)`

把十六进制字符串解码为字节数组或 UTF-8 字符串。

```js
const hmacHex = ctx.crypto.hmacSha256('hello', 'secret');
const hmacBytes = ctx.crypto.hexDecode(hmacHex);
const text = ctx.crypto.hexDecode('616263', { output: 'string' });
```

参数：

- `value`：十六进制字符串
- `options.output`：默认 `bytes`；可选 `string / utf8 / utf-8 / array`
- `options.outputEncoding`：`options.output` 的兼容别名

返回值：

- 默认返回 `Uint8Array`
- `output: 'string'` 时返回 UTF-8 字符串
- `output: 'array'` 时返回普通数字数组

注意事项：

- 签名、异或、二进制拼接等场景优先使用 `ctx.crypto.hexDecode(...)`
- `ctx.utils.hexDecode(...)` 保持旧行为：返回 UTF-8 字符串，不适合当字节数组使用

#### 方法：`ctx.crypto.hexEncode(value, options?)`

把字符串、普通数组或 `Uint8Array` 编码成十六进制字符串。

```js
const hex = ctx.crypto.hexEncode(new Uint8Array([0x61, 0x62, 0x63]));
```

参数：

- `value`：字符串、普通数字数组或 `Uint8Array`
- `options.inputEncoding`：可选，支持 `hex / base64`

#### 方法：`ctx.crypto.base64Decode(value, options?)`

把 Base64 字符串解码为字节数组或 UTF-8 字符串。

```js
const bytes = ctx.crypto.base64Decode('YWJj');
const text = ctx.crypto.base64Decode('YWJj', { output: 'string' });
```

#### 方法：`ctx.crypto.base64Encode(value, options?)`

把字符串、普通数组或 `Uint8Array` 编码成 Base64 字符串。

```js
const b64 = ctx.crypto.base64Encode(new Uint8Array([0x61, 0x62, 0x63]));
```

### 16.2 摘要方法

支持：

- `ctx.crypto.md5(value, options?)`
- `ctx.crypto.sha1(value, options?)`
- `ctx.crypto.sha256(value, options?)`
- `ctx.crypto.sha512(value, options?)`
- `ctx.crypto.sm3(value, options?)`

示例：

```js
const digest = ctx.crypto.sha256('hello');
const digestBase64 = ctx.crypto.sha256('hello', { outputEncoding: 'base64' });
```

常用参数：

- `options.inputEncoding`：默认 `utf8`，也支持 `base64 / hex`
- `options.outputEncoding`：默认 `hex`，也支持 `base64 / utf8`

### 16.3 HMAC 方法

支持：

- `ctx.crypto.hmacSha1(value, key, options?)`
- `ctx.crypto.hmacSha256(value, key, options?)`
- `ctx.crypto.hmacSha512(value, key, options?)`

示例：

```js
const sign = ctx.crypto.hmacSha256('hello', 'secret');
const signBytes = ctx.crypto.hexDecode(sign);
```

常用参数：

- `options.inputEncoding`
- `options.keyEncoding`
- `options.outputEncoding`

### 16.4 对称加解密

支持：

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
- `ctx.crypto.symmetricCrypto(key, iv, algorithm, data)`

AES 示例：

```js
const encrypted = ctx.crypto.aesEncrypt({
  data: 'hello',
  key: '1234567890123456',
  iv: '1234567890123456',
  mode: 'cbc',
  outputEncoding: 'base64',
});

const plain = ctx.crypto.aesDecrypt({
  data: encrypted,
  key: '1234567890123456',
  iv: '1234567890123456',
  mode: 'cbc',
  inputEncoding: 'base64',
  outputEncoding: 'utf8',
});
```

通用算法示例：

```js
const encrypted = ctx.crypto.symmetricEncrypt({
  algorithm: 'AES-CBC-PKCS5Padding',
  data: 'hello',
  key: '1234567890123456',
  iv: '1234567890123456',
  outputEncoding: 'base64',
});
```

链式写法示例：

```js
const encrypted = ctx.crypto
  .symmetricCrypto('1234567890123456', '1234567890123456', 'AES-CBC-PKCS5Padding', 'hello')
  .encrypt()
  .base64();
```

### 16.5 非对称加解密与签名

支持：

- `ctx.crypto.rsaEncrypt(options)`
- `ctx.crypto.rsaDecrypt(options)`
- `ctx.crypto.rsaSign(options)`
- `ctx.crypto.rsaVerify(options)`
- `ctx.crypto.asymmetricEncrypt(options)`
- `ctx.crypto.asymmetricDecrypt(options)`
- `ctx.crypto.asymmetricCrypto(algorithm, data)`

签名示例：

```js
const signature = ctx.crypto.rsaSign({
  data: 'hello',
  privateKey: '-----BEGIN PRIVATE KEY-----...',
  algorithm: 'SHA-256/RSA',
  outputEncoding: 'base64',
});
```

验签示例：

```js
const ok = ctx.crypto.rsaVerify({
  data: 'hello',
  publicKey: '-----BEGIN PUBLIC KEY-----...',
  signature,
  algorithm: 'SHA-256/RSA',
  signatureEncoding: 'base64',
});
```

### 16.6 随机数与时间

支持：

- `ctx.crypto.randomBytes(length, options?)`
- `ctx.crypto.randomString(length, options?)`
- `ctx.crypto.timestamp(options?)`

示例：

```js
const nonce = ctx.crypto.randomString(16);
const randomHex = ctx.crypto.randomBytes(16, { outputEncoding: 'hex' });
const timestampMs = ctx.crypto.timestamp();
const timestampSeconds = ctx.crypto.timestamp({ unit: 's' });
```

### 16.7 使用建议

- 字符串级编码转换可以用 `ctx.utils`
- 涉及签名、异或、字节数组时优先用 `ctx.crypto.hexDecode/base64Decode`
- 简单摘要和 HMAC 优先用直接方法
- 算法由站点动态下发时，再考虑 `symmetricEncrypt/asymmetricEncrypt` 或链式 API

## 17. `ctx.log`

### 方法：`ctx.log(message)`

#### 功能

向调试面板写入一条日志。

#### 签名

```js
ctx.log(message)
```

#### 参数

- `message`

#### 返回值

- 无

#### 示例

```js
ctx.log(`search keyword=${keyword}`);
```

#### 注意事项

- 适合记录关键阶段信息
- 不要在高频循环里无节制打印大量日志

## 18. 标准对象

书源方法返回值必须尽量靠近标准对象结构。宿主会做一定兼容和归一化，但不要依赖宿主猜测字段。

### 18.1 `DiscoverCategory`

用于发现页分类，由 `discoverCategories(ctx)` 返回。

最小示例：

```js
{
  title: '推荐',
  url: 'https://example.com/discover/recommend',
}
```

常用字段：

- `title`：分类标题
- `url`：分类请求地址或站点分类标识
- `style`：展示辅助信息
- `extra`：后续请求要用的扩展字段
- `debug`：调试辅助字段

注意事项：

- `title` 建议非空
- `url` 可以是 URL，也可以是你自己定义的分类 key
- 不要把大量列表数据塞进分类对象

### 18.2 `Book`

用于搜索、发现和详情阶段。

最小示例：

```js
{
  title: '示例小说',
  author: '作者名',
  detailUrl: 'https://example.com/book/1',
}
```

常用字段：

- `title`：书名
- `author`：作者
- `type`：内容类型，如 `novel / manga`
- `cover`：封面 URL
- `intro`：简介
- `status`：连载状态
- `category`：分类
- `score`：评分
- `wordCount`：字数
- `updateTime`：更新时间
- `tags`：标签数组
- `latestChapter`：最新章节
- `detailUrl`：详情页地址或详情标识
- `tocUrl`：目录页地址或目录标识
- `sourceId`：通常不用手写，宿主会补齐
- `extra`：跨阶段传递的自定义数据
- `debug`：调试辅助字段

注意事项：

- `title` 和 `detailUrl` 是最关键字段
- `tocUrl` 可以在 `detail` 阶段补齐
- 搜索阶段不要为了补全所有字段而做大量额外请求

### 18.3 `Chapter`

用于目录阶段，由 `chapters(ctx, book)` 返回。

最小示例：

```js
{
  title: '第 1 章',
  url: 'https://example.com/book/1/chapter/1',
}
```

常用字段：

- `title`：章节标题
- `url`：正文请求地址或章节标识
- `index`：章节序号；可不写，宿主按数组顺序归一化
- `isVolume`：是否为卷标题
- `vip` / `isVip`：是否会员章节
- `isPay`：是否付费章节
- `updateTime`：更新时间
- `extra`：正文阶段要用的扩展字段
- `debug`：调试辅助字段

注意事项：

- 可读章节必须有 `url`
- 卷标题可以 `isVolume: true` 且 `url` 为空
- 建议按站点目录顺序返回完整数组

### 18.4 `Content`

用于正文阶段，由 `content(ctx, book, chapter)` 返回。

最小示例：

```js
{
  title: chapter.title,
  content: '正文内容',
}
```

常用字段：

- `title`：章节标题
- `content`：正文文本
- `nextUrl`：下一章地址，通常可不写
- `images`：图片章节的图片 URL 数组
- `extra`：扩展字段
- `debug`：调试辅助字段

注意事项：

- 小说正文优先返回 `content`
- 漫画或图片章节可返回 `images`
- 不要把 HTML 原文直接当正文返回，建议清洗成可读文本

### 18.5 `extra`

`extra` 用于跨阶段传递业务字段，例如接口需要的 `bookId`、`chapterId`、签名参数、分页 key。

示例：

```js
return {
  title: item.name,
  detailUrl: item.id,
  extra: {
    bookId: item.id,
    sourceType: item.type,
  },
};
```

注意事项：

- `extra` 应保持可 JSON 序列化
- 不要放函数、DOM 节点、循环引用或过大的响应原文

### 18.6 `debug`

`debug` 用于调试辅助，不建议业务强依赖。

示例：

```js
return {
  title: item.name,
  detailUrl: item.id,
  debug: {
    rawTitle: item.title,
    matchedSelector: '.book-item',
  },
};
```

注意事项：

- `debug` 可以帮助网页调试台定位问题
- 发布前可以保留少量有价值信息
- 不要放敏感 Cookie、Token 或完整加密密钥

## 19. 网页调试服务

网页调试服务用于在浏览器中连接 App 本地服务，编辑书源并执行单步或完整链路调试。

### 19.1 连接方式

App 侧启动“书源网页调试服务”后，会提供类似这样的地址：

```text
http://192.168.1.23:15421
```

在网页调试台填入该地址后，会调用：

```text
GET /api/debug/ping
```

成功后即可加载书源列表、编辑代码、保存和运行调试。

### 19.2 调试接口

统一响应结构：

```js
{
  ok: true,
  data: {},
  error: null,
  meta: {
    requestId: 'req_...',
    timestamp: '...',
  },
}
```

失败响应：

```js
{
  ok: false,
  data: null,
  error: {
    code: 'unknown',
    message: '...',
    stage: 'content',
    detail: '...',
  },
}
```

主要接口：

- `GET /api/debug/ping`
- `GET /api/sources`
- `GET /api/sources/:id`
- `POST /api/sources`
- `PUT /api/sources/:id`
- `DELETE /api/sources/:id`
- `PATCH /api/sources/:id/enabled`
- `POST /api/debug/search`
- `POST /api/debug/detail`
- `POST /api/debug/chapters`
- `POST /api/debug/content`
- `POST /api/debug/full-run`

### 19.3 `logs`、`traces`、`stages`

调试接口会尽量返回结构化信息：

- `logs`：调试日志，包括脚本里的 `ctx.log(...)`
- `traces`：运行轨迹，包括 HTTP 请求、浏览器动作、执行摘要
- `stages`：完整链路中的阶段结果

单步接口成功时，`logs/traces` 位于 `data`：

```js
{
  ok: true,
  data: {
    step: 'content',
    result: {},
    logs: [],
    traces: [],
  },
}
```

失败时，结构化信息会放在 `error.detail` 的 JSON 字符串里：

```js
{
  error: {
    stage: 'content',
    detail: '{"durationMs":91,"logs":[],"traces":[]}',
  },
}
```

### 19.4 推荐调试顺序

推荐在网页调试台中分别验证：

1. 搜索
2. 详情
3. 目录
4. 正文
5. 完整链路

不要只跑 `full-run`。单步调试能更快定位是入参、网络、解析还是返回对象的问题。

### 19.5 常见错误

`SourceScriptCompileException: not a function` 通常表示脚本调用了不存在的方法，或导出对象里的对应步骤不是函数。

排查顺序：

1. 看错误里的 `stage`
2. 打开 `logs` 看 `ctx.log(...)` 输出
3. 打开 `traces` 看请求 URL、状态码和运行摘要
4. 检查当前阶段调用的 `ctx.*` API 是否存在
5. 检查返回对象是否是可序列化普通对象

## 20. 运行时边界与维护原则

### 20.1 当前只支持脚本源

当前 App 只执行 JavaScript 脚本源，不再导入或执行旧规则 JSON。旧规则可以作为迁移参考，但不能直接作为运行时格式。

### 20.2 执行链路

标准链路是：

```text
search -> detail -> chapters -> content
```

发现页链路是：

```text
discoverCategories -> discoverBooks -> detail -> chapters -> content
```

### 20.3 阶段职责

- `search`：只负责找书，返回候选 `Book[]`
- `detail`：补齐书籍详情、目录地址或跨阶段字段
- `chapters`：返回完整目录
- `content`：返回单章正文或图片
- `discoverCategories`：返回发现页分类
- `discoverBooks`：返回分类分页书籍

### 20.4 运行时隔离

宿主会根据场景选择普通容器或隔离容器执行脚本。书源作者不应该依赖全局变量长期保活；需要跨阶段传递的数据应放在 `book.extra`、`chapter.extra`、`ctx.cache` 或 `ctx.session`。

### 20.5 返回值序列化

返回值必须可 JSON 序列化。

不要返回：

- 函数
- DOM 节点
- `Map / Set`
- 循环引用对象
- 超大原始响应体

### 20.6 错误处理

脚本里可以抛出普通 `Error`，宿主会归一化为阶段错误。建议错误信息包含关键上下文，但不要包含敏感信息。

示例：

```js
if (!response.ok) {
  throw new Error(`章节请求失败 status=${response.status}`);
}
```

## 21. 发布前检查

发布前至少检查：

1. 能编译
2. 搜索有结果
3. 详情完整
4. 目录尽量全量
5. 正文可读
6. `checkKeyword` 合理
7. Challenge 场景可继续

## 22. 维护说明

本目录只保留这一份书源编写文档。需要新增书源规范、运行时 API、调试台行为、对象字段说明时，都直接更新本文档。

历史计划、阶段任务、API 草稿不再单独保留，避免作者阅读入口分散。
