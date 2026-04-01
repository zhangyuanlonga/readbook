# 书源规范 v1

更新时间：2026-04-01

当前产品说明：

- 本规范只适用于脚本源。
- `flutterreadbook` 运行时不再导入或执行旧规则 JSON。
- 与旧规则字段的迁移关系仅属于历史迁移话题，不属于现行规范的一部分。

这份文档只定义规范，不重复作者手册中的入门说明、详细示例和 API 参考。

如果你是第一次写书源，请先看：

- [官方书源编写手册](./official-source-author-guide.md)

---

## 1. 目标

`v1` 规范的目标是：

- 一个 `.js` 文件即可描述一个书源
- 书源同时包含元信息和执行逻辑
- 书源在步骤之间可以传递上下文
- 宿主能力通过 `ctx` 提供，而不是写死在源格式里
- 规范可以向后兼容地扩展

---

## 2. 文件结构

书源文件导出一个默认对象：

```js
export default {
  meta: {},
  async init(ctx, task) {},
  async search(ctx, keyword) {},
  async detail(ctx, book) {},
  async chapters(ctx, book) {},
  async content(ctx, book, chapter) {},
}
```

说明：

- `meta` 为元信息
- `init` 为可选方法
- `search / detail / chapters / content` 为核心方法

`init(ctx, task)` 中 `task` 推荐结构：

```js
{
  step: 'search' | 'detail' | 'chapters' | 'content',
  keyword: '关键词',
  book: null,
  chapter: null,
}
```

---

## 3. `meta` 规范

推荐字段：

```js
meta: {
  name: '示例书源',
  group: '默认分组',
  author: 'source_author',
  description: '示例书源描述',
  domains: ['www.example.com'],
  homepage: 'https://www.example.com',
  enabled: true,
  capabilities: ['search', 'detail', 'chapters', 'content'],
  rateLimits: {
    'www.example.com': {
      minIntervalMs: 800,
    },
  },
}
```

字段定义：

- `name`：展示名称
- `group`：分组
- `author`：作者
- `description`：描述
- `domains`：相关域名列表
- `homepage`：站点首页
- `enabled`：默认是否启用
- `capabilities`：支持的能力列表
- `rateLimits`：按域名声明最小请求间隔

约定：

- 作者不需要填写内部 `sourceId`
- 作者不需要在 `meta` 中维护 `revision`
- 宿主在运行时生成 `ctx.source.id`
- `rateLimits` 推荐保持对象结构，以便后续继续扩展更多请求控制字段

---

## 4. 方法规范

核心方法：

- `search(ctx, keyword)` -> `Promise<Book[]>`
- `detail(ctx, book)` -> `Promise<Book>`
- `chapters(ctx, book)` -> `Promise<Chapter[]>`
- `content(ctx, book, chapter)` -> `Promise<Content>`

可选方法：

- `init(ctx, task)`

说明：

- `search / detail / chapters / content` 建议都存在
- 某一步暂时不支持时，可以返回空结果或显式抛错
- 详细职责、示例和 `ctx` API 见主手册

---

## 5. 标准对象

### 5.1 `Book`

```js
{
  id: 'book-remote-id',
  title: '书名',
  type: 'novel',
  sourceId: 'runtime-generated-id',
  detailUrl: 'https://...',
  tocUrl: 'https://.../catalog',
  author: '作者',
  cover: 'https://...',
  intro: '简介',
  status: '连载',
  category: '玄幻',
  score: '9.2',
  wordCount: '235000',
  updateTime: '2026-03-25 09:30:00',
  tags: ['科幻', '群像'],
  latestChapter: '第100章',
  extra: {},
  debug: {}
}
```

### 5.2 `Chapter`

```js
{
  id: 'chapter-id',
  title: '第一章',
  url: 'https://...',
  index: 1,
  isVip: false,
  isPay: false,
  updateTime: '2026-03-25 09:30:00',
  sourceId: 'runtime-generated-id',
  extra: {},
  debug: {}
}
```

### 5.3 `Content`

```js
{
  title: '第一章',
  content: '正文内容...',
  nextUrl: null,
  images: [],
  sourceId: 'runtime-generated-id',
  extra: {},
  debug: {}
}
```

正文插图约定：

- 纯文本/HTML 正文直接放在 `content`
- 图片型正文可通过 `images` 返回图片 URL 数组
- 如果正文同时包含图文混排，优先把可读主内容放在 `content`

MVP 最小字段（建议先只保证这些）：

- `Book`：`title`、`detailUrl`（`tocUrl` 建议在 `detail` 阶段补齐）
- `Chapter`：`title`、`url`
- `Content`：`title`、`content`

可省略字段（脚本可不返回）：

- `Book.id`、`Chapter.id`：若站点无稳定主键可不填，宿主可按 URL 生成兜底标识
- `sourceId`：不要求脚本填写，宿主可按 `ctx.source.id` 在适配层补齐
- `Book.type`：建议有能力时填写，推荐枚举 `novel / comic / audio`
- `Chapter.isVip / Chapter.isPay`：建议有能力时填写，默认可为 `false`
- `Content.images`：图片型正文时建议填写；纯文本正文可留空
- 其他业务可选字段：按站点能力逐步补齐即可

---

## 6. `extra` 与 `debug`

`extra`：

- 用于跨步骤传递站点私有上下文
- 适合放 `token`、`rawId`、`csrf` 等关键参数
- 不建议放整页 HTML、整份 JSON 或大块二进制数据

`debug`：

- 仅用于调试
- 聚合层不应依赖它作为业务字段

---

## 7. 运行时选择规则

`v1` 不要求作者声明静态执行模式，例如 `execution: browser`。

原因：

- 站点流程可能在执行中动态变化
- 一开始能用 HTTP，过程中也可能升级到浏览器

因此规范约定为：

- 作者只写 `meta + 方法`
- 运行时路径由方法内部对 `ctx` 的调用决定

例如：

- `ctx.http.request(...)` 表示普通请求链路
- `ctx.http.request({ execution: 'browser' })` 表示本次请求借用浏览器环境
- `ctx.browser.challenge(...)` 表示进入浏览器挑战流程
- `ctx.browser.eval(...)` 表示在浏览器页面执行脚本
- `ctx.crypto.sha256(...)` 表示在宿主侧执行摘要或加解密能力

补充约定：

- 如果 `meta.rateLimits` 为某个域名声明了 `minIntervalMs`
- 宿主应在该书源对该域名发请求时自动保证最小间隔

---

## 8. 链式上下文规则

书源流程是链式的：

- `search` 产出的 `Book` 会进入 `detail`
- `detail` 产出的 `Book` 会进入 `chapters`
- `content` 同时消费 `book + chapter`

推荐约定：

- 标准字段逐步补齐
- 源专属字段统一放入 `extra`

---

## 9. 错误与兼容

错误处理约定：

- 源内部可以直接抛错
- 宿主层负责统一捕获和标准化

向后兼容约定：

- 优先新增可选字段
- 不轻易修改已有字段含义
- 新能力优先加到 `ctx` 或 `extra`

---

## 10. 规范与模板联动

为了避免规范和示例漂移，约定如下：

- 修改 `Book / Chapter / Content` 字段定义时，必须同步更新模板示例
- 统一同步到官方模板 `docs/templates/source_template_v1.js`
