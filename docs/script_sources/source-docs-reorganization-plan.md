# 书源文档重整方案

更新时间：2026-04-23
适用范围：`flutterreadbook`

## 1. 目标

把当前偏“大而全”的书源文档体系，重整成一套更适合书源作者阅读、查表和排错的结构。

重整后的目标是：

- 新手能快速找到“这个方法怎么写”
- 熟手能快速查某个 `ctx.*` 方法的签名和注意事项
- 排错时能按“现象”定位问题，而不是在大文档里全文搜索
- 方法说明统一使用 JS / 脚本源运行时口径，不再混入非本项目语言风格

## 2. 当前问题

当前文档中已经有大量有效内容，但组织方式不够聚焦，主要问题包括：

- 作者手册内容过大，第一次阅读成本高
- `ctx.*` 能力与“怎么写 `search/detail/chapters/content`”混在一起
- 方法说明风格不完全统一
- 工具能力、HTTP、HTML、Browser 等能力虽然已经列出，但缺少统一模板
- 排错内容散落在多份规划文档、手册和实现文档中

## 3. 新的目标结构

建议把书源作者侧文档重整为 6 类。

### 3.1 主手册

文件建议：

- `official-source-author-guide-v2.md`

职责：

- 面向第一次写书源的人
- 说明“书源整体怎么写”
- 重点解释：
  - 文件结构
  - `meta`
  - `search / detail / chapters / content`
  - 标准对象
  - 发布前检查

不承担：

- 完整 API 查表
- 所有 `ctx.*` 方法的细节解释
- 所有排错案例

### 3.2 运行时 API 手册

文件建议：

- `runtime-ctx-api-v2.md`

职责：

- 专门按方法查：
  - `ctx.http.*`
  - `ctx.html.*`
  - `ctx.browser.*`
  - `ctx.cookie.*`
  - `ctx.cache.*`
  - `ctx.session.*`
  - `ctx.utils.*`
  - `ctx.crypto.*`
  - `ctx.log(...)`

写法要求：

- 每个方法统一模板
- 只写当前实现
- 不写泛泛概念

### 3.3 标准对象手册

文件建议：

- `source-object-reference.md`

职责：

- 统一说明：
  - `DiscoverCategory`
  - `Book`
  - `Chapter`
  - `Content`
  - `extra`
  - `debug`

### 3.4 场景范例手册

文件建议：

- `source-cookbook.md`

职责：

- 提供实战场景写法
- 例如：
  - 纯 API 搜索源
  - HTML 解析源
  - 搜索 API + 详情 HTML 混合源
  - 目录分页源
  - 浏览器 challenge 源
  - 正文二次解密源

### 3.5 排错手册

文件建议：

- `source-troubleshooting.md`

职责：

- 按“现象”组织，而不是按 API 组织
- 例如：
  - 搜索无结果
  - 详情为空
  - 目录不全
  - 正文为空
  - Cookie 不生效
  - Challenge 过不去
  - 返回值被净化

### 3.6 统一写作模板

文件建议：

- `source-method-template.md`

职责：

- 给所有方法说明统一写法
- 以后不管是 `ctx.utils.absoluteUrl(...)` 还是 `ctx.http.request(...)`，都按同一格式写

## 4. 方法说明统一模板

后续所有方法说明统一使用下面这套格式：

### 方法：`ctx.utils.xxx(...)`

#### 功能

说明这个方法是干什么的。

#### 签名

```js
ctx.utils.xxx(arg1, arg2)
```

#### 参数

- `arg1`：说明
- `arg2`：说明

#### 返回值

- 返回什么类型
- 特殊情况下返回什么

#### 示例

```js
const result = ctx.utils.xxx(...)
```

#### 注意事项

- 使用时要注意什么
- 常见边界是什么
- 不会帮你做什么

这套格式适用于：

- `ctx.utils.*`
- `ctx.http.*`
- `ctx.html.*`
- `ctx.browser.*`
- `ctx.cookie.*`
- `ctx.cache.*`
- `ctx.session.*`
- `ctx.crypto.*`
- `ctx.log(...)`

## 5. 主手册章节建议

新版主手册建议只保留作者最需要的内容。

推荐目录：

1. 文档说明
2. 5 分钟上手
3. 最小可运行书源
4. 书源文件整体结构
5. `meta` 怎么写
6. `search(ctx, keyword)` 怎么写
7. `detail(ctx, book)` 怎么写
8. `chapters(ctx, book)` 怎么写
9. `content(ctx, book, chapter)` 怎么写
10. 标准对象怎么返回
11. `extra / debug` 怎么用
12. 调试与发布前检查

说明：

- 主手册不应把全部 `ctx.*` 能力展开成上百节
- 主手册重点应始终是“如何把一个源写出来”

## 6. API 手册章节建议

新版 API 手册建议按命名空间组织：

1. `ctx.source`
2. `ctx.http`
3. `ctx.html`
4. `ctx.browser`
5. `ctx.cookie`
6. `ctx.cache`
7. `ctx.session`
8. `ctx.utils`
9. `ctx.crypto`
10. `ctx.log`

每个命名空间下，再按方法展开。

## 7. 当前文档迁移映射

下面是建议的迁移方向。

### 7.1 现有主文档

- [official-source-author-guide.md](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/docs/script_sources/official-source-author-guide.md)
  - 保留为现行文档
  - 后续重写拆分到：
    - 主手册
    - API 手册
    - 对象手册
    - 排错手册

- [runtime-ctx-api.md](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/docs/script_sources/runtime-ctx-api.md)
  - 保留为 API 手册来源
  - 逐步重排成方法说明模板格式

- [source-spec-v1.md](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/docs/script_sources/source-spec-v1.md)
  - 保留为规范文档
  - 不建议写成教程

### 7.2 现有作者手册可拆内容

`official-source-author-guide.md` 中：

- `第 6 章 方法职责`
  - 迁入新版主手册
- `第 8 章 ctx 能做什么`
  - 迁入新版 API 手册
- `DiscoverCategory / Book / Chapter / Content`
  - 迁入标准对象手册
- 调试、trace、发布建议
  - 迁入排错手册或主手册末尾

### 7.3 现有开发规划文档

这类文档原则上不并入作者手册：

- `search-runtime-redesign.md`
- `runtime-result-sanitization-plan.md`
- `cross-scene-runtime-scheduler-plan.md`
- `search-first-run-instability-plan.md`

这些继续保留为开发文档，不作为作者主阅读路径。

## 8. 重整顺序建议

建议按下面顺序做，不要一次性硬重写所有文档。

### 阶段 A：先定格式

- 先定方法说明模板
- 先定主手册目录
- 先定迁移映射

### 阶段 B：先重写最常用部分

优先重写：

- `search`
- `detail`
- `chapters`
- `content`
- `ctx.http.request(...)`
- `ctx.html.parse(...)`
- `ctx.utils.absoluteUrl(...)`
- `ctx.browser.challenge(...)`

### 阶段 C：再补完整 API

- `ctx.cookie`
- `ctx.cache`
- `ctx.session`
- `ctx.crypto`
- 其余 `ctx.utils.*`

### 阶段 D：最后补范例与排错

- 场景 cookbook
- 故障排查手册

## 9. 本轮建议产物

本轮先落这 3 份：

- [书源方法说明模板](./source-method-template.md)
- [新版书源作者手册骨架](./source-author-guide-v2-outline.md)
- 本文：书源文档重整方案

这样可以先把结构定下来，再判断你是否满意。
