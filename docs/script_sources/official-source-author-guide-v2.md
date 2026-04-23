# 官方书源编写手册 v2

更新时间：2026-04-23
适用范围：`flutterreadbook`

## 1. 文档说明

这份文档面向“要在 `flutterreadbook` 里写一个可运行脚本源”的作者。

当前约定：

- App 运行时只支持脚本源
- 旧规则 JSON 不再是当前运行态能力
- 一个脚本源本质上就是一个 `export default { ... }` 的 JS 文件

本手册重点讲：

- 书源文件整体怎么组织
- `meta` 怎么写
- `search / detail / chapters / content` 每个方法如何编写
- 返回对象应该长什么样
- 写完后怎么调试和检查

本手册不负责：

- 全量 `ctx.*` API 查表
- 所有浏览器能力边界解释
- 所有排错案例

这些内容请分别查看：

- [宿主运行时 API v2](./runtime-ctx-api-v2.md)
- [书源规范 v1](./source-spec-v1.md)
- [总体架构](./architecture.md)

## 2. 5 分钟上手

一个最小可运行的书源至少需要：

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

如果你是第一次写，建议按下面顺序完成：

1. 先把 `meta` 写完整
2. 先让 `search` 能返回正确 `Book[]`
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

## 5. `search(ctx, keyword)` 怎么写

## 方法：`search(ctx, keyword)`

### 功能

根据关键词返回候选书籍列表。

### 参数

- `ctx`：宿主上下文
- `keyword`：搜索关键词

### 返回值

- 返回 `Book[]`
- 每一项至少应能让后续 `detail(ctx, book)` 继续工作
- 最少建议保证：
  - `title`
  - `detailUrl`
  - `author`（推荐）

### 示例

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

### 注意事项

- `search` 的职责是“找书”，不是补齐详情
- 搜索结果里不要顺手追加详情页、目录页、正文页请求
- 如果返回的 `detailUrl` 为空，后续 `detail` 往往无法继续
- 如果接口是 JSON，直接映射为标准 `Book[]`
- 如果接口是 HTML，优先：
  - `ctx.http.request(...)`
  - `ctx.html.parse(...)`
  - `ctx.html.collect(...)`

## 6. `detail(ctx, book)` 怎么写

## 方法：`detail(ctx, book)`

### 功能

根据搜索阶段返回的书对象，补齐详情字段。

### 参数

- `ctx`：宿主上下文
- `book`：上一步 `search()` 返回的单本书

### 返回值

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

### 示例

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

### 注意事项

- 推荐写法是：`return { ...book, ...补充字段 }`
- 不要把 `search` 阶段的关键字段丢掉
- `tocUrl` 很重要，目录通常依赖它
- 如果详情页里没有单独目录地址，`tocUrl` 可以回退到 `detailUrl`
- 如果详情字段本来就来自 API，可以直接映射，不一定要解析 HTML

## 7. `chapters(ctx, book)` 怎么写

## 方法：`chapters(ctx, book)`

### 功能

返回某本书的完整目录列表。

### 参数

- `ctx`：宿主上下文
- `book`：一般应使用 `detail()` 补充后的书对象

### 返回值

- 返回 `Chapter[]`
- 最少建议保证：
  - `title`
  - `url`
  - `index`

### 示例

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

### 注意事项

- `chapters` 的职责是“返回完整目录”
- 如果目录分页，必须自己翻页拼全，不要只抓第一页
- `index` 应该稳定，最好按最终顺序重新编号
- 分卷标题节点如果不是正文页，不要误当作普通章节
- 如果你现在看到目录常常只有两百左右，第一怀疑点通常是“目录分页没处理”

## 8. `content(ctx, book, chapter)` 怎么写

## 方法：`content(ctx, book, chapter)`

### 功能

返回单章正文。

### 参数

- `ctx`：宿主上下文
- `book`：书籍对象
- `chapter`：章节对象

### 返回值

- 返回 `Content`
- 最少建议保证：
  - `title`
  - `content`

### 示例

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

### 注意事项

- `content` 返回的是对象，不是纯字符串
- 如果正文分页，必须在这里自行合并
- 如果正文是图片型内容，可以返回 `images`
- 如果正文为空，优先检查：
  - 章节 URL 是否正确
  - 页面是否被挑战页替换
  - 选择器是否选到了广告容器或空节点

## 9. 可选方法

除了四个主方法，还可以按需实现：

- `init(ctx, task)`
- `discoverCategories(ctx)`
- `discoverBooks(ctx, category, page, pageSize)`

### 方法：`init(ctx, task)`

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

### 方法：`discoverCategories(ctx)`

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

### 方法：`discoverBooks(ctx, category, page, pageSize)`

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

## 10. 标准对象

主手册里先记住最重要的几点：

- `search` 返回 `Book[]`
- `detail` 返回 `Book`
- `chapters` 返回 `Chapter[]`
- `content` 返回 `Content`

对象的完整字段说明请后续查看对象参考手册。

## 11. 调试与发布前检查

写完一个书源后，至少做这几步：

1. 搜索能返回结果
2. 详情能补齐主要字段
3. 目录能尽量返回全量章节
4. 正文能正确读取
5. `checkKeyword` 能稳定命中

推荐在网页调试台中分别验证：

- 搜索
- 详情
- 目录
- 正文
- 完整链路

## 12. 下一步建议

这份 v2 先把主链写法定清楚。

后续建议继续补：

- `ctx.http / ctx.html / ctx.browser / ctx.utils` 全量 API 说明
- 对象参考手册
- 场景 cookbook
- 排错手册
