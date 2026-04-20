# 官方书源编写手册

更新时间：2026-04-01

当前产品说明：

- `flutterreadbook` 当前只支持脚本源。
- App 不再导入或执行旧规则 JSON。
- 如果你在迁移历史书源，请把旧规则字段映射为脚本源的 `search / detail / chapters / content` 方法；如果旧源有发现页能力，再额外映射为 `discoverCategories / discoverBooks`，而不是继续维护旧 JSON。

本手册面向“书源作者”。目标不是解释内部实现，而是帮助你从用户视角快速理解：

- 书源文件应该怎么写
- 哪些字段是必须返回的
- 每个方法分别负责什么
- `ctx` 提供了哪些可直接使用的能力
- 出现验证码、登录、动态页面时应该怎么处理

如果你只想尽快写出一个可运行的书源，先看“快速开始”和“完整流程示例”两节即可。

需要先强调一个原则：

- 固定的是导出结构、方法签名，以及返回结果要符合标准对象语义
- 不固定的是你内部怎么实现：HTML、JSON API、浏览器驱动、正则、DOM 解析、helper 拆分方式都可以
- 官方模板和手册示例只是固定示例，不是唯一写法，也不是强制实现路径
- 作者只需要按约定方法返回标准格式内容，宿主就能继续跑后续链路

相关文档：

- 规范定义：[source-spec-v1.md](./source-spec-v1.md)
- 运行时边界：[runtime-ctx-api.md](./runtime-ctx-api.md)
- 总体架构：[architecture.md](./architecture.md)
- 官方模板：[source_template_v1.js](../templates/source_template_v1.js)

---

## 1. 先理解一件事

一个书源，本质上是一个导出默认对象的 JavaScript 文件。这个对象描述了两类内容：

- `meta`：这个书源是谁、来自哪里、支持什么能力
- 方法：搜索、详情、目录、正文这几个步骤具体怎么跑

平台当前正式支持的主流程是：

1. `init`
2. `search`
3. `detail`
4. `chapters`
5. `content`

可选发现流程是：

1. `discoverCategories`
2. `discoverBooks`

其中：

- `init` 是可选的
- `search / detail / chapters / content` 是书源的核心方法
- `discoverCategories / discoverBooks` 是发现页可选方法，两个方法建议成对实现
- `ctx` 是书源运行时的顶层上下文对象

推荐理解方式：

- `search` 负责“找到书”
- `detail` 负责“补全这本书的信息”
- `chapters` 负责“拿到章节列表”
- `content` 负责“拿到章节正文”

这里需要额外强调一条当前宿主约束：

- `search` 应当只负责“返回搜索结果”
- 不应在搜索阶段主动补抓 `detail / chapters / content`
- 如果站点搜索接口本身已经返回了完整卡片信息，可以直接放进 `Book`
- 但不要因为想补字段而在 `search()` 里顺手追加详情页、目录页或正文页请求

原因很直接：

- 搜索阶段会被大量源并发执行
- 额外请求会把运行成本按源数放大
- 这会明显放大 JS 执行、browser/challenge 和宿主稳定性压力

推荐实践：

- 搜索阶段只返回最小可用 `Book[]`
- 用户进入详情页后再执行 `detail()`
- 用户进入阅读页后再执行 `chapters()` 和 `content()`

`ctx` 本质上是所有宿主能力的总入口：

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

官方示例写法之一：

- 方法和 helper 显式接收 `ctx`

当前宿主实践建议：

- 不要依赖 helper 中的隐式全局 `ctx`
- helper 请显式接收 `ctx`
- 尤其是 `absoluteUrl / cleanText / textOf / attrOf / request...` 这类公共函数，推荐统一写成 `function helper(ctx, ...)`

原因：

- 显式 `ctx` 的作用域最稳定
- 更容易调试和迁移
- 也能避免某些 JS 运行时对隐式全局变量解析不一致带来的问题

兼容说明：

- 运行时当前会尽量兜底隐式全局 `ctx/source`
- 但这属于兼容能力，不是推荐写法

---

## 2. 快速开始

### 2.1 最小模板

```js
export default {
 meta: {
    name: '示例书源',
    group: '默认分组',
    author: 'your_name',
    description: '一个最小可用的示例书源',
    checkKeyword: '凡人修仙传',
    domains: ['www.example.com'],
    homepage: 'https://www.example.com',
    capabilities: ['search', 'detail', 'chapters', 'content'],
    // 如果实现 discoverCategories / discoverBooks，再加上 'discover'
    // capabilities: ['search', 'detail', 'chapters', 'content', 'discover'],
  },

  async init(ctx, task) {},

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

  // async discoverCategories(ctx) {
  //   return [];
  // },

  // async discoverBooks(ctx, category, page, pageSize) {
  //   return [];
  // },
};
```

模板参考：

- [source_template_v1.js](../templates/source_template_v1.js)

补充说明：

- 书源是否启用由 App 内部状态管理
- 作者不要在 `meta` 中填写 `enabled`
- 导入后参与搜索、发现、阅读链，取决于宿主里的书源启停状态，而不是脚本里的 `meta.enabled`

### 2.2 helper 怎么写

官方推荐写法：

```js
function requestJson(ctx, url, options = {}) {
  return ctx.http.request({
    url,
    method: 'GET',
    responseType: 'json',
    ...options,
  });
}
```

简化版写法：

```js
function requestJsonLite(url, options = {}) {
  return ctx.http.request({
    url,
    method: 'GET',
    responseType: 'json',
    ...options,
  });
}
```

说明：

- 官方主推荐仍然是显式传 `ctx`
- 简化版依赖运行时注入的全局 `ctx`
- 两种都支持，但建议在正式模板和长期维护的书源里优先使用显式写法

### 2.3 一个书源最少要做什么

最少需要保证下面四件事：

1. `search` 能返回 `Book[]`
2. `detail` 能返回单个 `Book`
3. `chapters` 能返回 `Chapter[]`
4. `content` 能返回 `Content`

如果你要接入发现页，再额外保证：

5. `discoverCategories` 能返回 `DiscoverCategory[]`
6. `discoverBooks` 能根据当前分类返回 `Book[]`

如果某一步暂时不支持，也建议显式返回空数组、原对象，或直接抛出明确错误，而不是静默失败。

补充说明：

- `ctx.source.id` 是源被用户添加到 App 后，由宿主自动生成并注入的源 ID
- `sourceId` 是运行时字段，脚本通常不必手动填写
- 不要把站点内部主键当成标准对象必填字段
- 大多数 HTML 源直接依赖 `detailUrl / url + extra` 就足够
- 如果后续步骤需要站点私有参数，把它们放进 `extra`

### 2.4 推荐开发顺序

建议按这个顺序写：

1. 先写 `search`
2. 再写 `detail`
3. 再写 `chapters`
4. 最后写 `content`
5. 如果有登录、验证码或公共 token，再补 `init`

原因很简单：这是用户实际使用时最容易定位问题的顺序。

如果这个源同时支持发现页，建议在正文链路稳定之后再补：

6. `discoverCategories`
7. `discoverBooks`

---

## 3. 完整流程示例

下面是一份更接近真实站点的示例：

```js
const SOURCE_HOST = 'https://www.example.com';

export default {
  meta: {
    name: '示例书源',
    group: '默认分组',
    author: 'your_name',
    description: '一个演示 HTML + Challenge 流程的模板书源',
    checkKeyword: '凡人修仙传',
    domains: ['www.example.com'],
    homepage: SOURCE_HOST,
    capabilities: ['search', 'detail', 'chapters', 'content'],
  },

  async init(ctx, task) {
    if (task.step !== 'search') {
      return;
    }

    if (!ctx.session.get('bootstrapToken')) {
      const bootstrap = await ctx.http.request({
        url: `${SOURCE_HOST}/api/bootstrap`,
        method: 'GET',
        timeoutMs: 5000,
      });

      if (bootstrap.json?.token) {
        ctx.session.set('bootstrapToken', bootstrap.json.token);
      }
    }
  },

  async search(ctx, keyword) {
    const response = await ctx.http.request({
      url: `${SOURCE_HOST}/search`,
      method: 'GET',
      query: { q: keyword },
      timeoutMs: 6000,
    });

    if (ctx.http.isChallenge(response)) {
      await ctx.browser.challenge({
        url: response.url,
        reason: 'search_challenge',
        timeoutMs: 120000,
      });
    }

    const retryResponse = ctx.http.isChallenge(response)
      ? await ctx.http.request({
          url: `${SOURCE_HOST}/search`,
          method: 'GET',
          query: { q: keyword },
          timeoutMs: 6000,
        })
      : response;

    const doc = ctx.html.parse(retryResponse.text);
    const items = doc.querySelectorAll('.book-item');

    return ctx.html.collect(items, (item, index) => ({
      title: ctx.html.text(item.querySelector('.title')),
      author: ctx.html.text(item.querySelector('.author')),
      detailUrl: ctx.utils.absoluteUrl(
        SOURCE_HOST,
        item.querySelector('a')?.getAttribute('href') || '',
      ),
      extra: {
        searchIndex: index,
      },
    }));
  },

  async detail(ctx, book) {
    const response = await ctx.http.request({
      url: book.detailUrl,
      method: 'GET',
      timeoutMs: 6000,
    });

    const doc = ctx.html.parse(response.text);

    return {
      ...book,
      intro: ctx.html.text(doc.querySelector('.intro')),
      status: ctx.html.text(doc.querySelector('.status')),
      latestChapter: ctx.html.text(doc.querySelector('.latest')),
      tocUrl: ctx.utils.absoluteUrl(
        book.detailUrl,
        doc.querySelector('.catalog-link')?.getAttribute('href') || '',
      ),
      extra: {
        ...book.extra,
      },
    };
  },

  async chapters(ctx, book) {
    const response = await ctx.http.request({
      url: book.tocUrl || book.detailUrl,
      method: 'GET',
      timeoutMs: 6000,
    });

    const doc = ctx.html.parse(response.text);
    const nodes = doc.querySelectorAll('.chapter-list a');

    return ctx.html.collect(nodes, (node) => ({
      title: ctx.html.text(node),
      url: ctx.utils.absoluteUrl(book.detailUrl, node.getAttribute('href') || ''),
    }));
  },

  async content(ctx, book, chapter) {
    const response = await ctx.http.request({
      url: chapter.url,
      method: 'GET',
      timeoutMs: 6000,
    });

    const doc = ctx.html.parse(response.text);

    return {
      title: chapter.title,
      content: ctx.html.text(doc.querySelector('.content')),
    };
  },
};
```

这份示例展示了三个关键点：

- 优先用 `ctx.http` 处理普通请求
- 遇到挑战页时再升级到 `ctx.browser.challenge(...)`
- 上一步需要带给下一步的数据，统一放到 `extra`

---

## 4. `meta` 怎么写

`meta` 是书源的展示信息，不承载具体业务逻辑。

推荐写法：

```js
meta: {
  name: '示例书源',
  group: '默认分组',
  author: 'your_name',
  description: '一个示例源',
  checkKeyword: '凡人修仙传',
  domains: ['www.example.com'],
  homepage: 'https://www.example.com',
  capabilities: ['search', 'detail', 'chapters', 'content'],
  rateLimits: {
    'www.example.com': {
      minIntervalMs: 800,
    },
  },
}
```

字段说明：

- `name`：规则名称，建议对用户清晰可识别
- `group`：来源分组，例如“自带”“社区”“自定义”
- `author`：书源作者名称
- `description`：简要说明这个源的特点或适用范围
- `checkKeyword`：书源检测默认关键词，建议填写一个稳定能搜到结果的书名或作者词
- `domains`：相关域名列表
- `homepage`：站点首页
- `capabilities`：当前源支持的能力列表
- `rateLimits`：按域名声明最小请求间隔

补充说明：

- 不需要手动填写内部 `sourceId`
- 运行时会自动生成 `ctx.source.id`
- `meta` 里不要求作者维护内部版本号或 revision
- 不要在 `meta` 中声明 `enabled`
- 书源启用/停用由 App 内部状态管理
- `checkKeyword` 会在单源检测/批量检测时被宿主优先使用
- `rateLimits` 由宿主在 `ctx.http.request(...)` 时自动执行

`rateLimits` 推荐写法：

```js
rateLimits: {
  'www.example.com': {
    minIntervalMs: 800,
  },
  'api.example.com': {
    minIntervalMs: 300,
  },
}
```

含义：

- `minIntervalMs`：同一书源对同一域名连续发请求时的最小间隔，单位毫秒

适用场景：

- 某些站点请求太快会触发风控
- 某些接口要求明显放慢访问频率

---

## 5. 标准对象

平台当前统一的标准对象有四类：

- `DiscoverCategory`
- `Book`
- `Chapter`
- `Content`

建议所有方法只围绕这四类对象进行数据传递。

这里的对象示例展示的是“运行时支持的标准字段集合”。
不是要求每个源、每一步都把所有字段都填满。

### 5.1 DiscoverCategory

```js
{
  title: '男生 · 玄幻',
  url: 'https://...',
  style: {
    layoutFlexGrow: 1,
    layoutFlexBasisPercent: 50,
  },
  extra: {},
  debug: {}
}
```

字段建议：

- `title`：分类标题
- `url`：分类请求入口，或后续 `discoverBooks` 能继续解析的分类标识
- `style`：可选展示样式提示
- `extra`：discover 链路继续透传的私有参数
- `debug`：仅用于调试

### 5.2 Book

```js
{
  title: '书名',
  type: 'novel',
  detailUrl: 'https://...',
  tocUrl: 'https://.../catalog',
  author: '作者',
  cover: 'https://...',
  intro: '简介',
  status: '连载中',
  wordCount: '235000',
  updateTime: '2026-03-25 09:30:00',
  latestChapter: '第100章',
  extra: {},
  debug: {}
}
```

字段建议：

- `title`：书名
- `type`：作品类型，推荐 `novel / comic / audio`
- `author`：作者
- `cover`：封面 URL
- `intro`：简介
- `status`：连载状态
- `category`：分类
- `wordCount`：字数
- `updateTime`：最近更新时间
- `latestChapter`：最新章节名
- `detailUrl`：详情页 URL
- `tocUrl`：目录入口 URL（建议在 `detail` 阶段补齐）
- `sourceId`：运行时源 ID（脚本通常不必手动填写）
- `extra`：跨步骤透传数据
- `debug`：仅用于调试

实现原则：

- 只返回当前步骤已经稳定拿到的字段
- 不要为了贴合示例对象，去伪造站点本来没有的字段
- 后续步骤真正依赖的私有参数，优先放进 `extra`

### 5.3 Chapter

```js
{
  title: '第一章',
  url: 'https://...',
  isVolume: false,
  isVip: false,
  isPay: false,
  updateTime: '2026-03-25 09:30:00',
  extra: {},
  debug: {}
}
```

字段建议：

- `url`：章节页 URL 或正文接口地址
- `章节顺序`：按返回数组顺序确定，不再要求单独 `index` 字段
- `isVolume`：是否为分卷标题节点；为 `true` 时表示目录分组，不是可直接阅读的正文
- `isVip`：是否 VIP 章节（身份限制）
- `isPay`：是否已购买（支付状态）
- `extra`：继续透传章节请求真正需要的参数，例如 `chapterId`

### 5.4 Content

```js
{
  title: '第一章',
  content: '正文内容...',
  nextUrl: null,
  extra: {},
  debug: {}
}
```

正文约定：

- 文本正文和正文插图都应按原始顺序保留在 `content`
- `images` 只用于纯图片章节，例如漫画页
- 不要把正文插图拆成单独图片数组，否则位置语义会丢失

### 5.5 `extra` 应该放什么

`extra` 用于跨步骤传递站点内部上下文。
它的原则是：只放后续步骤确实需要的关键参数。

适合放：

- `bookId`
- `rawId`
- `ajaxUrl`
- `token`
- `csrf`
- `referer`
- 上一步解析出来、下一步还要继续使用的参数

不建议放：

- 整份 HTML
- 整份 JSON
- 大块二进制数据
- 明显只用于临时调试的垃圾数据

### 5.6 `debug` 应该怎么用

`debug` 只用于调试，不应被业务流程依赖。

适合放：

- 选择器命中信息
- 原始响应片段
- 诊断提示
- 调试阶段希望在 Debug 页观察的数据

---

## 6. 每个方法该负责什么

这一节是整份手册最重要的部分。
你可以把它理解成“书源作者的职责边界”。

### 6.1 `init(ctx, task)`：初始化，可选

作用：

- 在正式步骤执行前做准备工作

适合做：

- 获取公共 token
- 初始化公共请求头
- 初始化 session 状态
- 做一次预热请求
- 在需要时引导用户完成登录或挑战验证

不适合做：

- 把整个搜索逻辑塞进 `init`
- 在这里提前跑完整个业务链路
- 把只服务单一步骤的复杂解析都放进来

`task` 推荐理解为：

```js
{
  step: 'discoverCategories' | 'discoverBooks' | 'search' | 'detail' | 'chapters' | 'content',
  keyword: '关键词',
  book: null,
  chapter: null,
  category: null,
}
```

建议理解：

- `task.step` 一定存在
- `task.keyword / task.book / task.chapter / task.category` 按步骤出现
- 不要假设这几个字段会在所有步骤里同时有值

示例：

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

### 6.2 `discoverCategories(ctx)`：获取发现分类

作用：

- 返回发现页分类列表

输出：

- `Promise<DiscoverCategory[]>`

最低要求：

- 返回数组
- 每项至少能让后续 `discoverBooks` 识别当前分类

最少字段建议：

- `title`
- `url`

推荐补齐：

- `style`
- `extra`
- `debug`

最小示例：

```js
return [
  {
    title: '男生 · 玄幻',
    url: 'https://example.com/discover/xuanhuan',
  },
];
```

### 6.3 `discoverBooks(ctx, category, page, pageSize)`：按分类取书

作用：

- 根据当前发现分类返回该分类下的书籍列表

输入：

- `DiscoverCategory`
- `page`
- `pageSize`

输出：

- `Promise<Book[]>`

最低要求：

- 返回数组
- 每项至少能让后续 `detail` 找到这本书

最少字段建议：

- `title`
- `detailUrl`

推荐补齐：

- `author`
- `cover`
- `intro`
- `status`
- `category`
- `wordCount`
- `latestChapter`
- `extra`
- `debug`

最小示例：

```js
return [
  {
    title: '凡人修仙传',
    detailUrl: 'https://example.com/book/1',
  },
];
```

### 6.4 `search(ctx, keyword)`：搜索书籍

作用：

- 根据关键词返回候选书籍列表

输入：

- `keyword`

输出：

- `Promise<Book[]>`

最低要求：

- 返回数组
- 每项至少能让后续 `detail` 找到这本书

最少字段建议：

- `title`
- `type`（建议：`novel/comic/audio`）
- `detailUrl`
- `author`（建议）

推荐补齐：

- `cover`
- `intro`
- `status`
- `category`
- `wordCount`
- `updateTime`
- `latestChapter`
- `extra`
- `debug`

最小示例：

```js
return [
  {
    title: '凡人修仙传',
    type: 'novel',
    author: '忘语',
    detailUrl: 'https://example.com/book/1',
  },
];
```

### 6.5 `detail(ctx, book)`：补齐详情

作用：

- 根据已找到的书，补齐详情信息

输入：

- `Book`

输出：

- `Promise<Book>`

最低要求：

- 返回一个单独的 `Book`
- 保留已有关键字段
- 尽量补齐 `intro / status / category / wordCount / updateTime / latestChapter`

最少字段建议：

- `title`
- `type`（建议沿用 `search` 产物）
- `detailUrl`
- `author`（建议）

最小示例：

```js
return {
  ...book,
  intro: '一个普通山村小子的修仙故事。',
  status: '已完结',
  category: '仙侠',
};
```

### 6.6 `chapters(ctx, book)`：获取目录

作用：

- 返回某本书的章节列表

输入：

- `Book`

输出：

- `Promise<Chapter[]>`

最少字段建议：

- `title`
- `url`

推荐补齐：

- `isVip`
- `isPay`
- `extra`
- `debug`

最小示例：

```js
return [
  {
    title: '第一章 山边小村',
    url: 'https://example.com/book/1/chapter/1',
  },
];
```

### 6.7 `content(ctx, book, chapter)`：获取正文

作用：

- 返回单章正文内容

输入：

- `Book`
- `Chapter`

输出：

- `Promise<Content>`

最少字段建议：

- `title`
- `content`

推荐补齐：

- `nextUrl`
- `content` 中内联 `<img src="...">`（用于正文插图定位）
- `extra`
- `debug`

最小示例：

```js
return {
  title: chapter.title,
  content: '这里是正文内容……',
};
```

---

## 7. 推荐的链式写法

书源流程不是孤立的，而是链式的。

推荐模式：

1. `discoverCategories` 返回 `DiscoverCategory[]`
2. `discoverBooks` 根据分类返回 `Book[]`
3. `search` 返回基础 `Book`
4. `detail` 在原有 `Book` 上补字段
5. `chapters` 使用 `detail` 阶段传下来的 `extra`
6. `content` 同时消费 `book + chapter`

正文主链最常见的模式：

1. `search` 返回基础 `Book`
2. `detail` 在原有 `Book` 上补字段
3. `chapters` 使用 `detail` 阶段传下来的 `extra`
4. `content` 同时消费 `book + chapter`

一个很常见的正确写法是：

```js
async detail(ctx, book) {
  return {
    ...book,
    tocUrl: 'https://example.com/catalog/123',
    extra: {
      ...book.extra,
    },
  };
}
```

重点是：

- 标准字段逐步补齐
- 源特有字段统一放到 `extra`
- 不要把站点私有字段直接污染到 `Book / Chapter / Content` 顶层

---

## 8. `ctx` 能做什么

当前运行时提供的 `ctx` 结构如下：

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

你可以把这些能力分成三类来理解：

- 基础执行：`source`、`http`、`html`、`utils`、`log`
- 状态管理：`cookie`、`cache`、`session`
- 浏览器兜底：`browser`
- 加解密与签名：`crypto`

### 8.1 `ctx.source`

用途：

- 获取当前运行中的书源信息

当前可用字段：

- `ctx.source.id`
- `ctx.source.name`
- `ctx.source.group`
- `ctx.source.revision`

示例：

```js
ctx.log(`当前源: ${ctx.source.name}`);
const sourceId = ctx.source.id;
```

#### 8.1.1 `ctx.source.id`

作用：

- 获取当前书源的运行时唯一标识

参数：

- 无

返回值：

```js
string
```

适用场景：

- 在适配层或调试日志中标识当前正在执行哪个源

示例：

```js
const sourceId = ctx.source.id;
```

注意：

- 这是运行时生成的值，不需要作者手动在 `meta` 中填写

#### 8.1.2 `ctx.source.name`

作用：

- 获取当前规则名称

参数：

- 无

返回值：

```js
string
```

适用场景：

- 日志输出
- 调试界面展示

示例：

```js
ctx.log(`当前源名称: ${ctx.source.name}`);
```

#### 8.1.3 `ctx.source.group`

作用：

- 获取当前书源所属分组

参数：

- 无

返回值：

```js
string
```

适用场景：

- 调试时确认来源分组
- 日志输出

示例：

```js
const group = ctx.source.group;
```

#### 8.1.4 `ctx.source.revision`

作用：

- 获取当前书源运行时 revision

参数：

- 无

返回值：

```js
number
```

适用场景：

- 调试时确认当前加载的是哪一版源
- 记录诊断信息

示例：

```js
ctx.log(`revision=${ctx.source.revision}`);
```

### 8.2 `ctx.http`

用途：

- 发起普通 HTTP 请求
- 判断响应类型或是否出现挑战页

当前可用方法：

- `ctx.http.request(options)`
- `ctx.http.isHtml(response)`
- `ctx.http.isJson(response)`
- `ctx.http.isRedirect(response)`
- `ctx.http.isChallenge(response)`

`request` 示例：

```js
const response = await ctx.http.request({
  url: 'https://example.com/search',
  method: 'GET',
  query: { q: keyword },
  headers: {
    Referer: 'https://example.com',
  },
  timeoutMs: 10000,
  responseType: 'text',
});
```

返回结构：

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

推荐使用习惯：

- 普通页面优先走 `ctx.http.request(...)`
- 如果命中挑战页，再用 `ctx.browser.challenge(...)`
- 先判断 `isJson` / `isHtml`，再决定如何解析
- 需要控速时优先写 `meta.rateLimits`，不要在规则里到处手写 `sleep`

#### 8.2.1 `ctx.http.request(options)`

作用：

- 发起普通 HTTP 请求

参数：

```js
{
  url: 'https://example.com/api',
  method: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE' | 'HEAD',
  headers: {
    Referer: 'https://example.com',
  },
  query: {
    q: '凡人',
    page: '1',
  },
  body: '...',
  bodyType: 'auto' | 'json' | 'form' | 'text' | 'bytes',
  timeoutMs: 10000,
  responseType: 'text' | 'json' | 'bytes',
  charset: 'utf8' | 'gbk' | 'gb2312' | 'big5',
  referer: 'https://example.com',
  execution: 'http' | 'browser',
  webView: true | false,
}
```

参数说明：

- `url`：请求地址
- `method`：请求方法
- `headers`：自定义请求头
- `query`：查询参数
- `body`：请求体，可为字符串、对象或其他宿主支持的格式
- `bodyType`：请求体编码方式，默认 `auto`
- `timeoutMs`：超时时间，单位毫秒
- `responseType`：期望的响应类型
- `charset`：响应文本解码字符集，默认 `utf8`
- `referer`：快捷传入的来源页地址
- `execution`：请求执行方式，默认 `http`
- `webView`：`execution: 'browser'` 的轻量别名

返回值：

```js
Promise<{
  ok: boolean,
  status: number,
  url: string,
  headers: Record<string, string>,
  text: string | null,
  json: any,
  bytesLength: number | null,
  redirected: boolean,
}>
```

适用场景：

- 搜索接口请求
- 详情页、目录页、正文页抓取
- API 接口调用

示例：

```js
const response = await ctx.http.request({
  url: 'https://example.com/search',
  method: 'GET',
  query: { q: keyword },
  headers: {
    Referer: 'https://example.com',
  },
  timeoutMs: 10000,
  responseType: 'text',
});
```

指定字符集：

```js
const response = await ctx.http.request({
  url: 'https://example.com/search',
  method: 'GET',
  charset: 'gbk',
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

按浏览器环境请求页面：

```js
const response = await ctx.http.request({
  url: 'https://example.com/protected',
  execution: 'browser',
});
```

注意：

- 普通站点优先使用 `request(...)`
- 命中挑战页后，再决定是否升级到 `ctx.browser.challenge(...)`
- 如果 `meta.rateLimits` 为当前域名声明了 `minIntervalMs`，宿主会在请求前自动等待
- `execution: 'browser'` 当前更适合 HTML 页面抓取，不应理解为完整浏览器网络栈替代

#### 8.2.2 `ctx.http.isHtml(response)`

作用：

- 判断响应是否适合按 HTML 处理

参数：

```js
response
```

返回值：

```js
boolean
```

适用场景：

- 响应类型不固定时做分支判断
- 解析前先确认是不是 HTML 页面

示例：

```js
if (ctx.http.isHtml(response)) {
  const doc = ctx.html.parse(response.text);
}
```

#### 8.2.3 `ctx.http.isJson(response)`

作用：

- 判断响应是否适合按 JSON 处理

参数：

```js
response
```

返回值：

```js
boolean
```

适用场景：

- 搜索接口可能返回 JSON 时
- 同一站点既有 HTML 页也有 JSON API 时

示例：

```js
if (ctx.http.isJson(response)) {
  return response.json?.rows || [];
}
```

#### 8.2.4 `ctx.http.isRedirect(response)`

作用：

- 判断响应是否发生了跳转

参数：

```js
response
```

返回值：

```js
boolean
```

适用场景：

- 判断是否被站点重定向到登录页
- 调试请求链路

示例：

```js
if (ctx.http.isRedirect(response)) {
  ctx.log(`redirected to ${response.url}`);
}
```

#### 8.2.5 `ctx.http.isChallenge(response)`

作用：

- 判断响应是否命中了验证码、风控页或其他挑战页

参数：

```js
response
```

返回值：

```js
boolean
```

适用场景：

- 普通请求被拦截后切换到浏览器流程
- 登录或验证前置判断

示例：

```js
if (ctx.http.isChallenge(response)) {
  await ctx.browser.challenge({
    url: response.url,
    reason: 'challenge_detected',
  });
}
```

### 8.3 `ctx.html`

用途：

- 解析 HTML 并提取内容

当前可用方法：

- `ctx.html.parse(html)`
- `ctx.html.text(node)`
- `ctx.html.innerHtml(node)`
- `ctx.html.attr(node, name)`
- `ctx.html.collect(nodes, mapper)`

示例：

```js
const doc = ctx.html.parse(response.text);
const items = doc.querySelectorAll('.book-item');

return ctx.html.collect(items, (node, index) => ({
  title: ctx.html.text(node.querySelector('.title')),
  author: ctx.html.text(node.querySelector('.author')),
}));
```

#### 8.3.1 `ctx.html.parse(html)`

作用：

- 把 HTML 字符串解析成可查询的文档对象

参数：

```js
html
```

返回值：

```js
DocumentLike
```

适用场景：

- 解析搜索结果页
- 解析详情页、目录页、正文页

示例：

```js
const doc = ctx.html.parse(response.text);
const titleNode = doc.querySelector('.book-title');
```

#### 8.3.2 `ctx.html.text(node)`

作用：

- 获取节点的文本内容，并做基础文本提取

参数：

```js
node
```

返回值：

```js
string
```

适用场景：

- 提取书名、作者、简介、章节名

示例：

```js
const title = ctx.html.text(doc.querySelector('.book-title'));
```

注意：

- 节点为空时，建议结合上游判空逻辑一起使用

#### 8.3.3 `ctx.html.innerHtml(node)`

作用：

- 获取元素的内部 HTML 内容（不包含元素本身的标签）

参数：

```js
node
```

返回值：

```js
string
```

适用场景：

- 提取正文容器的原始 HTML
- 需要保留子元素标签的场景（如正文中的图片、段落格式）
- 配合其他规则进一步处理 HTML 片段

示例：

```js
const html = ctx.html.innerHtml(doc.querySelector('.content'));
// 返回类似：<p>第一段文字</p><p>第二段<img src="..."/></p>
```

注意：

- 元素为空时返回空字符串
- 与 `ctx.html.text()` 的区别：`text()` 只返回纯文本，`innerHtml()` 保留子元素标签
- 正文提取时，如果正文包含图片等内联元素，使用 `innerHtml()` 可以保留这些元素

#### 8.3.4 `ctx.html.attr(node, name)`

作用：

- 获取节点指定属性值

参数：

```js
node, name
```

返回值：

```js
string
```

适用场景：

- 读取链接 `href`
- 读取图片 `src`
- 读取元素自定义属性

示例：

```js
const href = ctx.html.attr(doc.querySelector('a'), 'href');
```

#### 8.3.5 `ctx.html.collect(nodes, mapper)`

作用：

- 遍历节点集合并映射成结构化数组

参数：

```js
nodes, mapper
```

返回值：

```js
Array<any>
```

适用场景：

- 搜索结果列表提取
- 章节列表提取

示例：

```js
const books = ctx.html.collect(
  doc.querySelectorAll('.book-item'),
  (node, index) => ({
    title: ctx.html.text(node.querySelector('.title')),
    author: ctx.html.text(node.querySelector('.author')),
  }),
);
```

### 8.4 `ctx.browser`

用途：

- 当普通请求不够时，进入真实浏览器上下文

当前可用方法：

- `ctx.browser.open(...)`
- `ctx.browser.challenge(...)`
- `ctx.browser.eval(...)`
- `ctx.browser.waitForUrl(...)`
- `ctx.browser.waitForText(...)`
- `ctx.browser.getCookies()`
- `ctx.browser.getCurrentUrl()`
- `ctx.browser.getHtml()`
- `ctx.browser.getStorage()`

推荐理解：

- `browser` 不是“登录模块”
- `challenge` 的核心目标是“让流程继续”
- 如果你需要某个明确值，优先用 `eval(...)` 去拿

#### 8.4.1 `ctx.browser.open(options)`

作用：

- 打开一个真实浏览器页面
- 适合需要先进入某个页面、再执行后续交互的场景

参数：

```js
{
  url: 'https://example.com/login',
  timeoutMs: 120000,
}
```

参数说明：

- `url`：要打开的页面地址
- `timeoutMs`：等待打开完成的超时时间，单位毫秒

返回值：

```js
Promise<void>
```

适用场景：

- 先打开登录页
- 先进入详情页，再配合 `eval(...)` 读取页面数据
- 明确知道接下来要在同一页面继续等待或执行脚本

示例：

```js
await ctx.browser.open({
  url: 'https://example.com/login',
  timeoutMs: 120000,
});
```

注意：

- `open(...)` 只是打开页面，不等于已经完成登录或验证
- 如果你需要等待某个结果出现，继续配合 `waitForUrl(...)`、`waitForText(...)` 或 `eval(...)`

#### 8.4.2 `ctx.browser.challenge(options)`

作用：

- 在浏览器中承接验证码、人工登录或其他需要页面继续完成的流程

参数：

```js
{
  url: 'https://example.com/login',
  reason: 'manual_login',
  waitFor: {
    urlIncludes: '/home',
    textIncludes: '登录成功',
    cookie: 'SESSIONID',
  },
  timeoutMs: 120000,
}
```

参数说明：

- `url`：需要进入的挑战页或登录页
- `reason`：触发原因，建议写清楚，例如 `captcha`、`manual_login`
- `waitFor`：等待条件，可按需指定
- `waitFor.urlIncludes`：当 URL 包含某段文本时视为成功
- `waitFor.textIncludes`：当页面出现某段文本时视为成功
- `waitFor.cookie`：当出现某个 cookie 时视为成功
- `timeoutMs`：最大等待时间，单位毫秒

返回值：

```js
Promise<void>
```

适用场景：

- 普通 HTTP 请求被验证码拦截
- 站点要求用户先登录
- 某一步必须通过页面交互后才能继续

示例：

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

注意：

- `challenge(...)` 的目标是“让规则继续”，不是自动帮你完成所有状态同步
- 如果后续还需要 token、HTML、storage，请显式调用对应方法获取

#### 8.4.3 `ctx.browser.eval(options)`

作用：

- 在当前浏览器页面上下文中执行脚本，并返回结果

参数：

```js
{
  script: "localStorage.getItem('token')",
}
```

参数说明：

- `script`：要在页面环境执行的脚本字符串

返回值：

```js
Promise<any>
```

适用场景：

- 读取 `localStorage` / `sessionStorage`
- 获取页面里的某个全局变量
- 读取页面已经渲染出的动态数据

示例：

```js
const token = await ctx.browser.eval({
  script: "localStorage.getItem('token')",
});
```

注意：

- 如果你只需要一个明确值，优先用 `eval(...)`
- 比起先 `getStorage()` 再自己翻字段，`eval(...)` 通常更直接

#### 8.4.4 `ctx.browser.waitForUrl(options)`

作用：

- 等待浏览器当前 URL 满足指定条件

参数：

```js
{
  includes: '/home',
  timeoutMs: 120000,
}
```

参数说明：

- `includes`：URL 中应包含的关键片段
- `timeoutMs`：最大等待时间，单位毫秒

返回值：

```js
Promise<void>
```

适用场景：

- 登录完成后页面跳转
- 验证码通过后进入目标页
- 单页应用发生路由变化

示例：

```js
await ctx.browser.waitForUrl({
  includes: '/bookshelf',
  timeoutMs: 120000,
});
```

注意：

- 适合监听“地址变化”
- 如果页面地址不变、只是 DOM 变化，优先用 `waitForText(...)`

#### 8.4.5 `ctx.browser.waitForText(options)`

作用：

- 等待页面中出现指定文本

参数：

```js
{
  text: '登录成功',
  timeoutMs: 120000,
}
```

参数说明：

- `text`：页面中应出现的文本
- `timeoutMs`：最大等待时间，单位毫秒

返回值：

```js
Promise<void>
```

适用场景：

- 等待“登录成功”“验证通过”这类页面提示
- 页面没有跳转，但内容已经变化
- 等待 SPA 页面渲染出目标区域

示例：

```js
await ctx.browser.waitForText({
  text: '欢迎回来',
  timeoutMs: 120000,
});
```

注意：

- 文本判断适合用户可见提示
- 如果你要拿的不是文本而是结构化值，后续仍建议配合 `eval(...)`

#### 8.4.6 `ctx.browser.getCookies()`

作用：

- 获取当前浏览器上下文中的 cookie 集合

参数：

- 无

返回值：

```js
Promise<Record<string, string>>
```

适用场景：

- 登录完成后读取浏览器侧 cookie
- 调试 challenge 后站点到底写入了哪些 cookie

示例：

```js
const cookies = await ctx.browser.getCookies();
```

注意：

- 这适合在你明确需要查看浏览器侧 cookie 时使用
- 如果只是规则内部读取 cookie，也可以优先尝试 `ctx.cookie.*`
- 当前 `browser.open(...)` / `browser.challenge(...)` / `browser.eval(...)` 完成后，浏览器侧可见 cookie 会同步回当前源 session
- 如果后续只是普通 `ctx.http.request(...)`，通常优先读取 `ctx.cookie.getForUrl(...)` 会更贴近实际发请求时的携带结果

#### 8.4.7 `ctx.browser.getCurrentUrl()`

作用：

- 获取当前浏览器页面的实际 URL

参数：

- 无

返回值：

```js
Promise<string>
```

适用场景：

- 判断 challenge 完成后跳到了哪里
- 记录调试信息
- 验证当前页面是否已经进入目标路径

示例：

```js
const currentUrl = await ctx.browser.getCurrentUrl();
ctx.log(`browser url=${currentUrl}`);
```

#### 8.4.8 `ctx.browser.getHtml()`

作用：

- 获取当前浏览器页面的 HTML 快照

参数：

- 无

返回值：

```js
Promise<string>
```

适用场景：

- 页面依赖前端渲染，HTTP 拿不到最终 DOM
- 调试浏览器页当前到底渲染成了什么

示例：

```js
const html = await ctx.browser.getHtml();
const doc = ctx.html.parse(html);
```

注意：

- 如果你只想拿某个明确字段，优先用 `eval(...)`
- `getHtml()` 更适合你确实需要整页 DOM 快照时使用

#### 8.4.9 `ctx.browser.getStorage()`

作用：

- 获取当前浏览器页面可访问的存储快照

参数：

- 无

返回值：

```js
Promise<{
  localStorage?: Record<string, string>,
  sessionStorage?: Record<string, string>,
}>
```

适用场景：

- 调试登录后页面写入了哪些存储项
- 需要一次性查看多个 storage 字段

示例：

```js
const storage = await ctx.browser.getStorage();
const token = storage.localStorage?.token;
```

注意：

- 当前更推荐“按需使用”
- 如果只是拿一个 token，通常 `eval(...)` 比 `getStorage()` 更直接

### 8.5 `ctx.cookie`

用途：

- 管理当前书源上下文里的 cookie

当前可用方法：

- `ctx.cookie.get(name)`
- `ctx.cookie.getAll()`
- `ctx.cookie.getForUrl(url, name?)`
- `ctx.cookie.set(name, value)`
- `ctx.cookie.remove(name)`
- `ctx.cookie.clearDomain(domain)`

示例：

```js
const sessionId = ctx.cookie.get('SESSIONID');
ctx.cookie.set('custom_token', 'abc');
```

说明：

- `ctx.cookie.*` 操作的是“当前源 session 里的 cookie 视图”，不是浏览器全局 cookie 仓库
- 浏览器流程成功写入的 cookie 会回灌到当前源 session，所以后续 `ctx.http.request(...)` 会按目标 URL 自动带上匹配的 cookie
- `clearDomain(domain)` 现在会按域名清理当前源 session 中匹配的 cookie，但仍不等于浏览器级精细删除器

#### 8.5.1 `ctx.cookie.get(name)`

作用：

- 获取指定名称的 cookie 值

参数：

```js
name
```

返回值：

```js
string | null
```

适用场景：

- 读取登录态 cookie
- 拼接后续请求头

示例：

```js
const sessionId = ctx.cookie.get('SESSIONID');
```

#### 8.5.2 `ctx.cookie.getAll()`

作用：

- 获取当前规则上下文中的全部 cookie

参数：

- 无

返回值：

```js
Record<string, string>
```

适用场景：

- 调试 cookie 状态
- 一次性检查当前 cookie 集合

示例：

```js
const cookies = ctx.cookie.getAll();
```

#### 8.5.3 `ctx.cookie.getForUrl(url, name?)`

作用：

- 以 URL 视角读取当前源上下文里的 cookie

参数：

```js
url, name?
```

返回值：

```js
string | Record<string, string> | null
```

适用场景：

- 从旧规则迁移 `getCookie(url, key)` 这类写法
- 调试某个站点请求前可用的 cookie

示例：

```js
const sessionId = ctx.cookie.getForUrl('https://example.com', 'SESSIONID');
const allCookies = ctx.cookie.getForUrl('https://example.com');
```

注意：

- 当前会按目标 URL 过滤当前源 session 中可匹配的 cookie
- 它仍然不是浏览器全局 cookie 容器，也不会替代浏览器开发者工具级别的完整观察视角

#### 8.5.4 `ctx.cookie.set(name, value)`

作用：

- 写入或更新一个 cookie

参数：

```js
name, value
```

返回值：

```js
void
```

适用场景：

- 写入站点要求的临时 cookie
- 在规则内同步某些已知 cookie 值

示例：

```js
ctx.cookie.set('custom_token', 'abc');
```

#### 8.5.5 `ctx.cookie.remove(name)`

作用：

- 删除指定名称的 cookie

参数：

```js
name
```

返回值：

```js
void
```

适用场景：

- 清理失效登录态
- 重新发起登录前清理旧 cookie

示例：

```js
ctx.cookie.remove('SESSIONID');
```

#### 8.5.6 `ctx.cookie.clearDomain(domain)`

作用：

- 清理当前源上下文里与某个域名相关的 cookie 集合

参数：

```js
domain
```

返回值：

```js
void
```

适用场景：

- 某站点 cookie 污染导致规则异常
- 重新初始化站点状态前做清理

示例：

```js
ctx.cookie.clearDomain('example.com');
```

注意：

- 当前会按域名清理当前源 session 中匹配的 cookie
- 不要把它理解成完整浏览器级精细删除器

### 8.6 `ctx.cache`

用途：

- 存储可重复利用、但不一定必须跨整个流程存在的数据

当前可用方法：

- `ctx.cache.get(key)`
- `ctx.cache.set(key, value)`
- `ctx.cache.remove(key)`
- `ctx.cache.clearPrefix(prefix)`

示例：

```js
const cached = ctx.cache.get(`search:${keyword}`);
if (cached) {
  return cached;
}
```

#### 8.6.1 `ctx.cache.get(key)`

作用：

- 读取缓存值

参数：

```js
key
```

返回值：

```js
any
```

适用场景：

- 读取搜索缓存
- 读取预热阶段写入的公共数据

示例：

```js
const cached = ctx.cache.get(`search:${keyword}`);
```

#### 8.6.2 `ctx.cache.set(key, value)`

作用：

- 写入缓存值

参数：

```js
key, value
```

返回值：

```js
void
```

适用场景：

- 缓存搜索结果
- 缓存短期复用的 token 或接口结果

示例：

```js
ctx.cache.set(`search:${keyword}`, books);
```

#### 8.6.3 `ctx.cache.remove(key)`

作用：

- 删除指定缓存项

参数：

```js
key
```

返回值：

```js
void
```

适用场景：

- 某条缓存失效时主动清除

示例：

```js
ctx.cache.remove(`search:${keyword}`);
```

#### 8.6.4 `ctx.cache.clearPrefix(prefix)`

作用：

- 清理指定前缀下的缓存项

参数：

```js
prefix
```

返回值：

```js
void
```

适用场景：

- 批量清理某类缓存
- 站点规则升级后清空旧缓存

示例：

```js
ctx.cache.clearPrefix('search:');
```

### 8.7 `ctx.session`

用途：

- 保存源内临时状态
- 适合跨步骤共享信息

当前可用方法：

- `ctx.session.get(key)`
- `ctx.session.set(key, value)`
- `ctx.session.clear(key?)`
- `ctx.session.cookies()`

示例：

```js
if (!ctx.session.get('initialized')) {
  ctx.session.set('initialized', true);
}
```

推荐场景：

- 初始化标记
- 登录状态
- 预热 token
- 当前流程确实需要跨步骤透传的上下文

#### 8.7.1 `ctx.session.get(key)`

作用：

- 获取 session 中的值

参数：

```js
key
```

返回值：

```js
any
```

适用场景：

- 读取初始化标记
- 读取登录态或 token

示例：

```js
const initialized = ctx.session.get('initialized');
```

#### 8.7.2 `ctx.session.set(key, value)`

作用：

- 写入 session 值

参数：

```js
key, value
```

返回值：

```js
void
```

适用场景：

- 存初始化标记
- 存跨步骤复用的 token 或状态

示例：

```js
ctx.session.set('initialized', true);
```

#### 8.7.3 `ctx.session.clear(key?)`

作用：

- 清空某个 session 键，或清空整个 session

参数：

```js
key?
```

返回值：

```js
void
```

适用场景：

- 某个状态失效后删除
- 重置整个源内流程状态

示例：

```js
ctx.session.clear('initialized');
ctx.session.clear();
```

#### 8.7.4 `ctx.session.cookies()`

作用：

- 获取与当前 session 关联的 cookie 视图

参数：

- 无

返回值：

```js
any
```

适用场景：

- 调试当前 session 里的 cookie 状态
- 在 session 视角检查 cookie 是否同步

示例：

```js
const cookies = ctx.session.cookies();
```

#### 8.7.5 `ctx.session` 与 `ctx.cache` 怎么选

这是书源作者最容易混淆的一组能力。

推荐理解：

- `ctx.session`

  - 偏“当前源的运行时会话状态”
  - 更适合放：
    - 初始化标记
    - 登录态
    - token
    - 浏览器 challenge 后继承的状态
- `ctx.cache`

  - 偏“可重复利用的业务结果”
  - 更适合放：
    - 搜索结果
    - 详情结果
    - 目录结果
    - 某些短期可复用的接口结果

简单判断：

- 如果这个值丢了会影响“当前源是否还能继续执行”，优先放 `session`
- 如果这个值主要是为了减少重复请求，优先放 `cache`

### 8.8 `ctx.utils`

用途：

- 提供一些通用工具函数

当前可用方法：

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
- `ctx.utils.getDeviceInfo()`
- `ctx.utils.getUserId()`

示例：

```js
const detailUrl = ctx.utils.absoluteUrl(
  'https://example.com',
  '/book/123',
);
```

#### 8.8.1 `ctx.utils.absoluteUrl(base, relative)`

作用：

- 把相对路径转换成绝对 URL

参数：

```js
base, relative
```

返回值：

```js
string
```

适用场景：

- 把详情链接、章节链接、封面链接补成完整地址

示例：

```js
const detailUrl = ctx.utils.absoluteUrl(
  'https://example.com',
  '/book/123',
);
```

#### 8.8.2 `ctx.utils.sleep(duration)`

作用：

- 暂停指定时长

参数：

```js
duration
```

返回值：

```js
Promise<void>
```

适用场景：

- 某些站点需要短暂等待
- 调试或兼容节流场景

示例：

```js
await ctx.utils.sleep(500);
```

#### 8.8.3 `ctx.utils.pick(value, fallback)`

作用：

- 当主值为空或不可用时，回退到备用值

参数：

```js
value, fallback
```

返回值：

```js
any
```

适用场景：

- 同一字段有多个备选来源
- 某些站点字段并不稳定时做回退

示例：

```js
const title = ctx.utils.pick(
  ctx.html.text(doc.querySelector('.title')),
  '未知书名',
);
```

#### 8.8.4 `ctx.utils.normalizeText(text)`

作用：

- 对文本做基础规范化处理

参数：

```js
text
```

返回值：

```js
string
```

适用场景：

- 清理多余空白
- 统一正文、简介、标题文本

示例：

```js
const intro = ctx.utils.normalizeText(
  ctx.html.text(doc.querySelector('.intro')),
);
```

#### 8.8.5 `ctx.utils.timeFormat(value, pattern?)`

作用：

- 把时间值格式化成指定字符串

参数：

```js
value, pattern?
```

返回值：

```js
string
```

示例：

```js
const text = ctx.utils.timeFormat(
  '2026-03-25T08:09:10Z',
  'yyyy-MM-dd HH:mm:ss',
);
```

#### 8.8.6 `ctx.utils.htmlFormat(value)`

作用：

- 把常见 HTML 片段清洗成更适合阅读的纯文本

参数：

```js
value
```

返回值：

```js
string
```

示例：

```js
const text = ctx.utils.htmlFormat('<p>hello<br>world</p>');
```

#### 8.8.7 `ctx.utils.base64Encode(value)`

作用：

- 把字符串编码成 Base64

参数：

```js
value
```

返回值：

```js
string
```

示例：

```js
const encoded = ctx.utils.base64Encode('hello');
```

#### 8.8.8 `ctx.utils.base64Decode(value)`

作用：

- 把 Base64 字符串解码成普通文本

参数：

```js
value
```

返回值：

```js
string
```

示例：

```js
const decoded = ctx.utils.base64Decode('aGVsbG8=');
```

#### 8.8.9 `ctx.utils.hexEncode(value)`

作用：

- 把字符串编码成十六进制文本

参数：

```js
value
```

返回值：

```js
string
```

示例：

```js
const encoded = ctx.utils.hexEncode('abc');
```

#### 8.8.10 `ctx.utils.hexDecode(value)`

作用：

- 把十六进制文本解码成普通文本

参数：

```js
value
```

返回值：

```js
string
```

示例：

```js
const decoded = ctx.utils.hexDecode('616263');
```

#### 8.8.11 `ctx.utils.encodeUri(value)`

作用：

- 对整段 URI / URL 字符串做编码

参数：

```js
value
```

返回值：

```js
string
```

示例：

```js
const encoded = ctx.utils.encodeUri('https://example.com/书?q=hello world');
```

#### 8.8.12 `ctx.utils.decodeUri(value)`

作用：

- 对整段 URI / URL 字符串做解码

参数：

```js
value
```

返回值：

```js
string
```

示例：

```js
const decoded = ctx.utils.decodeUri(
  'https://example.com/%E4%B9%A6?q=hello%20world',
);
```

#### 8.8.13 `ctx.utils.encodeUriComponent(value)`

作用：

- 对 URL 参数值做编码

参数：

```js
value
```

返回值：

```js
string
```

示例：

```js
const q = ctx.utils.encodeUriComponent('凡人修仙传 & 忘语');
```

#### 8.8.14 `ctx.utils.decodeUriComponent(value)`

作用：

- 对 URL 参数值做解码

参数：

```js
value
```

返回值：

```js
string
```

示例：

```js
const q = ctx.utils.decodeUriComponent(
  '%E5%87%A1%E4%BA%BA%E4%BF%AE%E4%BB%99%E4%BC%A0%20%26%20%E5%BF%98%E8%AF%AD',
);
```

#### 8.8.15 `ctx.utils.getDeviceInfo()`

作用：

- 获取当前设备与安装实例的运行时标识信息

返回值：

```js
Promise<{
  installId: string,
  deviceUid: string,
  deviceFingerprint: string,
  platform: string,
  deviceBrand: string,
  deviceModel: string,
  osVersion: string,
  appVersion: string,
}>
```

说明：

- `installId`：当前 App 安装实例 ID，适合做设备级缓存键或调试标识
- `deviceUid`：基于设备信息生成的稳定哈希标识
- `deviceFingerprint`：更细粒度的设备指纹哈希
- `platform / deviceBrand / deviceModel / osVersion / appVersion`：当前宿主和设备信息

推荐场景：

- 某些接口需要设备标识时
- 需要按安装实例隔离缓存时
- 调试“为什么同一源在不同设备表现不一致”时

示例：

```js
const device = await ctx.utils.getDeviceInfo();

const traceKey = `${device.platform}:${device.installId}`;
ctx.log(`device=${traceKey}`);
```

注意：

- 这是运行时设备信息，不是站点 cookie 或浏览器指纹容器
- `deviceUid / deviceFingerprint` 是宿主生成的稳定值，适合标识，不建议当作站点登录凭证替代品

#### 8.8.16 `ctx.utils.getUserId()`

作用：

- 获取当前 App 登录用户的用户 ID

返回值：

```js
Promise<string | null>
```

说明：

- 当前用户未登录时返回 `null`
- 返回的是宿主账户体系里的用户 ID，不是目标站点的用户 ID

推荐场景：

- 需要按当前登录用户隔离缓存或 session key 时
- 某些书源要把宿主用户和本地行为绑定时

示例：

```js
const userId = await ctx.utils.getUserId();
const cacheKey = userId ? `feed:${userId}` : 'feed:guest';
```

### 8.9 `ctx.crypto`

用途：

- 提供摘要、HMAC、对称加解密、RSA 和常用随机辅助能力

当前可用方法：

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

推荐理解：

- 编码转换优先放在 `ctx.utils`
- 真正的加解密、摘要、HMAC 放在 `ctx.crypto`
- `SM3` 属于摘要算法，不是对称或非对称加解密算法

链式写法示例：

```js
const encrypted = ctx.crypto
  .symmetricCrypto(
    '1234567890abcdef',
    'fedcba0987654321',
    'AES-CBC-PKCS5Padding',
    'hello world',
  )
  .encode()
  .base64();

const plain = ctx.crypto
  .symmetricCrypto(
    '1234567890abcdef',
    'fedcba0987654321',
    'AES-CBC-PKCS5Padding',
    encrypted,
  )
  .decode()
  .string();

const rsaEncrypted = ctx.crypto
  .AsymmetricCrypto('RSA/ECB/PKCS1Padding', 'hello world')
  .setPublicKey(publicKeyPem)
  .encode()
  .base64();
```

推荐理解：

- 函数式 API 适合明确参数和稳定调用
- 链式 API 适合兼容旧书源或更接近习惯写法

#### 8.9.1 `ctx.crypto.md5(value, options?)`

作用：

- 计算 MD5 摘要

示例：

```js
const sign = ctx.crypto.md5('hello');
```

#### 8.9.2 `ctx.crypto.sha256(value, options?)`

作用：

- 计算 SHA-256 摘要

示例：

```js
const digest = ctx.crypto.sha256('hello');
```

#### 8.9.3 `ctx.crypto.hmacSha256(value, key, options?)`

作用：

- 计算 HMAC-SHA256

示例：

```js
const sign = ctx.crypto.hmacSha256('hello', 'secret');
```

#### 8.9.4 `ctx.crypto.sm3(value, options?)`

作用：

- 计算 SM3 摘要

示例：

```js
const digest = ctx.crypto.sm3('abc');
```

#### 8.9.5 `ctx.crypto.aesEncrypt(options)`

作用：

- 使用 AES 对文本加密

参数示例：

```js
{
  data: 'hello world',
  key: '1234567890abcdef',
  iv: 'fedcba0987654321',
  mode: 'cbc',
  inputEncoding: 'utf8',
  keyEncoding: 'utf8',
  ivEncoding: 'utf8',
  outputEncoding: 'base64',
}
```

示例：

```js
const encrypted = ctx.crypto.aesEncrypt({
  data: 'hello world',
  key: '1234567890abcdef',
  iv: 'fedcba0987654321',
});
```

#### 8.9.6 `ctx.crypto.aesDecrypt(options)`

作用：

- 使用 AES 解密文本

示例：

```js
const plain = ctx.crypto.aesDecrypt({
  data: encrypted,
  key: '1234567890abcdef',
  iv: 'fedcba0987654321',
});
```

#### 8.9.7 `ctx.crypto.desEncrypt(options)`

作用：

- 使用 DES 加密文本

示例：

```js
const encrypted = ctx.crypto.desEncrypt({
  data: 'hello world',
  key: '12345678',
  iv: '87654321',
});
```

#### 8.9.8 `ctx.crypto.desDecrypt(options)`

作用：

- 使用 DES 解密文本

#### 8.9.9 `ctx.crypto.tripleDesEncrypt(options)`

作用：

- 使用 3DES 加密文本

示例：

```js
const encrypted = ctx.crypto.tripleDesEncrypt({
  data: 'hello world',
  key: '1234567890abcdef12345678',
  iv: '87654321',
});
```

#### 8.9.10 `ctx.crypto.tripleDesDecrypt(options)`

作用：

- 使用 3DES 解密文本

#### 8.9.11 `ctx.crypto.rc4Encrypt(options)`

作用：

- 使用 RC4 对文本加密

示例：

```js
const encrypted = ctx.crypto.rc4Encrypt({
  data: 'hello world',
  key: 'secret-key',
});
```

#### 8.9.12 `ctx.crypto.rc4Decrypt(options)`

作用：

- 使用 RC4 对文本解密

#### 8.9.13 `ctx.crypto.symmetricEncrypt(options)`

作用：

- 使用算法字符串执行对称加密

示例：

```js
const encrypted = ctx.crypto.symmetricEncrypt({
  algorithm: 'AES-CBC-PKCS5Padding',
  data: 'hello world',
  key: '1234567890abcdef',
  iv: 'fedcba0987654321',
});
```

#### 8.9.14 `ctx.crypto.symmetricDecrypt(options)`

作用：

- 使用算法字符串执行对称解密

常见算法字符串：

- `AES-CBC-PKCS5Padding`
- `AES-ECB-PKCS5Padding`
- `DES-CBC-PKCS5Padding`
- `DES-ECB-PKCS5Padding`
- `DESede-CBC-PKCS5Padding`
- `DESede-ECB-PKCS5Padding`
- `RC4`

#### 8.9.15 `ctx.crypto.rsaEncrypt(options)`

作用：

- 使用 RSA 公钥加密文本

参数示例：

```js
{
  data: 'hello world',
  publicKey: '-----BEGIN PUBLIC KEY-----...',
  inputEncoding: 'utf8',
  outputEncoding: 'base64',
  padding: 'pkcs1',
}
```

#### 8.9.16 `ctx.crypto.rsaDecrypt(options)`

作用：

- 使用 RSA 私钥解密文本

#### 8.9.17 `ctx.crypto.asymmetricEncrypt(options)`

作用：

- 使用算法字符串执行非对称加密

常见算法字符串：

- `RSA/ECB/PKCS1Padding`
- `RSA/ECB/OAEPWithSHA-1AndMGF1Padding`
- `RSA/ECB/OAEPWithSHA-256AndMGF1Padding`
- `RSA/ECB/OAEPWithSHA-512AndMGF1Padding`

#### 8.9.18 `ctx.crypto.asymmetricDecrypt(options)`

作用：

- 使用算法字符串执行非对称解密

#### 8.9.19 `ctx.crypto.rsaSign(options)`

作用：

- 使用 RSA 私钥对数据签名

示例：

```js
const signature = ctx.crypto.rsaSign({
  data: 'hello world',
  privateKey: privateKeyPem,
  algorithm: 'SHA256withRSA',
  outputEncoding: 'base64',
});
```

#### 8.9.20 `ctx.crypto.rsaVerify(options)`

作用：

- 使用 RSA 公钥验证签名

示例：

```js
const ok = ctx.crypto.rsaVerify({
  data: 'hello world',
  publicKey: publicKeyPem,
  signature,
  algorithm: 'SHA-256/RSA',
  signatureEncoding: 'base64',
});
```

#### 8.9.21 `ctx.crypto.symmetricCrypto(key, iv, algorithm, data)`

作用：

- 创建对称加解密的链式包装器

示例：

```js
const encrypted = ctx.crypto
  .symmetricCrypto(key, iv, 'DES-ECB-PKCS5Padding', data)
  .encode()
  .base64();
```

#### 8.9.22 `ctx.crypto.asymmetricCrypto(algorithm, data)`

作用：

- 创建非对称加解密的链式包装器

兼容说明：

- `ctx.crypto.AsymmetricCrypto(...)` 当前仍可作为兼容别名使用
- 但正式文档和新模板建议统一使用 `asymmetricCrypto(...)`

#### 8.9.23 `ctx.crypto.randomBytes(length, options?)`

作用：

- 生成随机字节序列

示例：

```js
const nonce = ctx.crypto.randomBytes(16, { outputEncoding: 'hex' });
```

#### 8.9.24 `ctx.crypto.randomString(length, options?)`

作用：

- 生成随机字符串

示例：

```js
const nonce = ctx.crypto.randomString(12);
```

#### 8.9.25 `ctx.crypto.timestamp(options?)`

作用：

- 获取当前时间戳

示例：

```js
const ms = ctx.crypto.timestamp();
const s = ctx.crypto.timestamp({ unit: 's' });
```

补充说明：

- 摘要和 HMAC 默认返回 `hex`
- `aes / des / 3des` 默认输出 `base64`
- `rc4` 默认输出 `base64`
- 对称加密当前支持 `cbc / ecb`
- RSA 当前支持 `PKCS1Padding / OAEP-SHA1 / OAEP-SHA256 / OAEP-SHA512`
- RSA 签名当前支持常见 `MD5 / SHA1 / SHA256 / SHA512` 的 `RSA / PSS` 变体

#### 8.9.26 常见配方

AES-CBC 加密后转 Base64：

```js
const encrypted = ctx.crypto
  .symmetricCrypto(key, iv, 'AES-CBC-PKCS5Padding', data)
  .encode()
  .base64();
```

AES-CBC 解密后转字符串：

```js
const plain = ctx.crypto
  .symmetricCrypto(key, iv, 'AES-CBC-PKCS5Padding', encrypted)
  .decode()
  .string();
```

DES-ECB 加密后转 Base64：

```js
const encrypted = ctx.crypto
  .symmetricCrypto(key, null, 'DES-ECB-PKCS5Padding', data)
  .encode()
  .base64();
```

RSA 公钥加密后转 Base64：

```js
const encrypted = ctx.crypto
  .AsymmetricCrypto('RSA/ECB/PKCS1Padding', data)
  .setPublicKey(publicKeyPem)
  .encode()
  .base64();
```

RSA 私钥签名：

```js
const signature = ctx.crypto.rsaSign({
  data,
  privateKey: privateKeyPem,
  algorithm: 'SHA256withRSA',
  outputEncoding: 'base64',
});
```

HMAC-SHA256 签名：

```js
const sign = ctx.crypto.hmacSha256(data, secret);
```

### 8.10 `ctx.log`

用途：

- 输出调试日志

示例：

```js
ctx.log(`search keyword=${keyword}`);
```

#### 8.10.1 `ctx.log(message)`

作用：

- 输出调试日志，帮助定位当前规则执行状态

参数：

```js
message
```

返回值：

```js
void
```

适用场景：

- 记录当前执行步骤
- 输出关键参数和中间状态
- 调试解析失败或分支判断

示例：

```js
ctx.log(`search keyword=${keyword}`);
ctx.log(`detail url=${book.detailUrl}`);
```

注意：

- 建议输出对定位问题有帮助的关键信息
- 不建议无节制打印大量噪声日志

---

## 9. 什么时候用 HTTP，什么时候用 Browser

这是书源作者最容易写乱的一点。

建议遵循下面这条简单规则：

1. 能用 `ctx.http` 完成，就不要先上浏览器
2. 命中挑战页、依赖前端执行、必须人工登录时，再进入 `ctx.browser`
3. 浏览器完成关键动作后，优先回到普通请求链路

推荐流程：

```js
const response = await ctx.http.request({ ... });

if (ctx.http.isChallenge(response)) {
  await ctx.browser.challenge({
    url: response.url,
    reason: 'challenge_detected',
  });
}
```

不推荐一上来就把所有请求都放到浏览器里跑。原因是：

- 调试更慢
- 失败定位更难
- 书源维护成本更高

---

## 10. 错误处理建议

源内部遇到问题时，建议用下面几种方式处理：

- 请求失败：直接抛错
- 解析失败：直接抛错，并在 `debug` 或 `ctx.log` 里补充线索
- 验证码或登录要求：调用 `ctx.browser.challenge(...)`
- 需要等待页面变化：使用 `waitForUrl(...)` 或 `waitForText(...)`

推荐写法：

```js
if (!response.ok) {
  throw new Error(`request failed: ${response.status}`);
}
```

如果你要补调试信息，建议补“能帮助定位问题的最少信息”，例如：

- 当前 URL
- 命中的选择器
- 响应状态码
- 页面标题或关键片段

---

## 11. 调试建议

平台当前提供两类很有价值的调试视角：

- `Debug` 页：看原始数据、日志和链路问题
- `Preview` 页：看最终渲染效果

建议排查顺序：

1. 先确认请求是否真的成功
2. 再确认返回的是 HTML 还是 JSON
3. 再确认选择器是否命中
4. 再确认标准对象字段是否填对
5. 最后再看渲染问题是不是由空字段导致

常见定位手段：

- 用 `ctx.log(...)` 打出关键阶段信息
- 在 `debug` 里临时存选择器命中结果
- 把站点私有参数放入 `extra`，确认链路传递是否正确

当前 Debug 页已经更适合按步骤排查：

- `init / search / detail / chapters / content / aggregate` 每一步都会保留结果快照
- 每一步还会附带当前 `session / cookie / cache` 的运行时快照
- 关键 HTTP / browser 动作现在会附带 `trace`，便于看原始请求与响应材料
- 这更适合排查“为什么上一步有值、下一步没值”这类链路问题

调试页当前还支持自动保存：

- 关键词会自动保存
- 编辑中的书源源码会自动保存
- 切换页面后再次回来，通常可以继续上次的调试上下文

---

## 12. 常见误区

### 12.1 把 `meta` 当成业务配置中心

不建议。
`meta` 主要是展示信息，不应塞入一堆流程控制字段。

### 12.2 把站点私有字段直接挂在顶层

不建议。
站点私有字段统一放 `extra`，这样标准对象更稳定。

### 12.3 在 `init` 里做所有事情

不建议。
`init` 是初始化，不是把整个业务链路提前执行一遍。

### 12.4 所有站点都默认需要浏览器

不建议。
优先尝试 `ctx.http`，只有确实需要时再升级到 `ctx.browser`。

### 12.5 在 `extra` 里存整页 HTML

不建议。
这会让对象过重，也会增加调试和维护成本。

---

## 13. 书源作者的最简检查清单

在提交或交付一个书源前，建议至少确认下面这些项：

- `meta` 字段完整且对用户可读
- `search / detail / chapters / content` 均有返回值
- `Book / Chapter / Content` 满足最小字段（`title/detailUrl`、`title/url`、`title/content`）
- URL 已做绝对路径处理
- 站点私有参数已统一放入 `extra`
- 正文页能稳定拿到 `content`
- 需要验证码或登录时，流程能通过 `ctx.browser.challenge(...)` 继续
- 没有把大量调试垃圾数据混入正式字段

---

## 14. 一句话总结

写书源时，优先记住这套思路：

1. 用标准对象表达结果
2. 用 `extra` 传递站点私有上下文
3. 普通请求优先走 `ctx.http`
4. 遇到挑战、登录、动态执行，再升级到 `ctx.browser`
5. 让每个方法只负责自己那一步

如果你已经掌握这五点，就能写出结构稳定、对用户更友好、也更容易维护的书源。
