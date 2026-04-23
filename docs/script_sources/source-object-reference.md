# 书源标准对象参考

更新时间：2026-04-23
适用范围：`flutterreadbook`

## 1. 说明

这份文档只负责回答一个问题：

“书源方法到底应该返回什么对象，字段应该怎么放？”

涉及对象：

- `DiscoverCategory`
- `Book`
- `Chapter`
- `Content`
- `extra`
- `debug`

## 2. `DiscoverCategory`

### 功能

描述发现页中的一个分类入口。

### 典型来源

- `discoverCategories(ctx)` 的返回值

### 最小示例

```js
{
  title: '玄幻',
  url: 'https://example.com/discover/xuanhuan',
}
```

### 常用字段

- `title`
  分类名称
- `url`
  后续 `discoverBooks` 使用的分类地址或分类标识
- `style`
  用于发现页展示布局的样式信息
- `extra`
  给后续步骤携带的业务数据
- `debug`
  调试辅助数据

### 注意事项

- `title` 应可直接展示给用户
- `url` 不一定必须是完整地址，但必须能让后续 `discoverBooks` 识别
- `extra` 里适合放分类 ID、分页信息、接口参数等

## 3. `Book`

### 功能

描述一本书。

### 典型来源

- `search(ctx, keyword)` 返回 `Book[]`
- `discoverBooks(ctx, category, page, pageSize)` 返回 `Book[]`
- `detail(ctx, book)` 返回单个增强后的 `Book`

### 最小示例

```js
{
  title: '凡人修仙传',
  author: '忘语',
  detailUrl: 'https://example.com/book/1',
}
```

### 常用字段

- `title`
- `author`
- `type`
- `cover`
- `intro`
- `status`
- `category`
- `score`
- `wordCount`
- `updateTime`
- `tags`
- `latestChapter`
- `detailUrl`
- `tocUrl`
- `sourceId`
- `extra`
- `debug`

### 注意事项

- `detailUrl` 很关键，后续 `detail()` 通常依赖它
- `tocUrl` 建议在 `detail()` 阶段补齐
- 推荐在 `detail()` 里 `return { ...book, ...补充字段 }`
- `sourceId` 不要求作者强制填写，宿主可能补齐

## 4. `Chapter`

### 功能

描述一本书中的一个章节。

### 典型来源

- `chapters(ctx, book)` 返回 `Chapter[]`

### 最小示例

```js
{
  title: '第一章 山边小村',
  url: 'https://example.com/book/1/chapter/1',
  index: 0,
}
```

### 常用字段

- `title`
- `url`
- `index`
- `isVolume`
- `vip`
- `isPay`
- `updateTime`
- `sourceId`
- `extra`
- `debug`

### 注意事项

- `index` 建议稳定且连续
- 目录分页时，最好在拼全后统一重新编号
- 分卷标题如果不是可阅读章节，应考虑 `isVolume`

## 5. `Content`

### 功能

描述单章正文。

### 典型来源

- `content(ctx, book, chapter)` 返回 `Content`

### 最小示例

```js
{
  title: '第一章 山边小村',
  content: '这里是正文内容……',
}
```

### 常用字段

- `title`
- `content`
- `nextUrl`
- `images`
- `sourceId`
- `extra`
- `debug`

### 注意事项

- `content` 返回的是对象，不是纯字符串
- 漫画或图片正文可以主要使用 `images`
- 正文分页时可以结合 `nextUrl` 或脚本内自行合并

## 6. `extra`

### 功能

放业务链路里后续步骤还会继续使用的数据。

### 适合放什么

- 站点返回的内部 ID
- 接口分页参数
- 章节列表定位参数
- 详情页里提取出的后续请求 token

### 示例

```js
{
  title: '凡人修仙传',
  detailUrl: 'https://example.com/book/1',
  extra: {
    bookId: '1',
    apiToken: 'abc',
  },
}
```

### 注意事项

- `extra` 是给后续步骤继续用的
- 尽量只放可序列化、可复用的数据
- 不要把 DOM、函数、循环引用对象塞进去

## 7. `debug`

### 功能

放调试辅助信息。

### 适合放什么

- 原始接口字段片段
- 当前步骤的中间解析线索
- 调试时方便观察的补充材料

### 示例

```js
{
  title: '凡人修仙传',
  detailUrl: 'https://example.com/book/1',
  debug: {
    rawCategory: '玄幻修真',
    rawStatus: '完结',
  },
}
```

### 注意事项

- `debug` 只用于调试
- 不要把必须依赖的业务字段只放在 `debug`
- 一样不要放不可序列化对象
