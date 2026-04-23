# 新版书源作者手册骨架

更新时间：2026-04-23
适用范围：`flutterreadbook`

## 1. 目的

本文不是正式手册正文，而是新版作者手册的骨架，用于先确认结构是否合理。

目标：

- 把作者真正关心的内容放在最前面
- 把“这个方法怎么写”讲清楚
- 把 `ctx.*` 方法查表从主手册里拆出去

## 2. 新版主手册建议目录

## 1. 文档说明

- 当前运行时只支持脚本源
- 本手册适合谁
- 本手册不覆盖什么

## 2. 5 分钟上手

- 一个最小可运行书源
- 四个必需方法是什么
- 第一次调试怎么跑通

## 3. 书源文件整体结构

- `export default`
- `meta`
- `init`
- `search`
- `detail`
- `chapters`
- `content`
- 可选发现方法

## 4. `meta` 怎么写

- 必填与推荐字段
- `name`
- `author`
- `description`
- `group`
- `checkKeyword`
- `homepage`
- `domains`
- `capabilities`

## 5. `search(ctx, keyword)` 怎么写

每个核心方法都按统一模板写：

- 方法功能
- 参数
- 返回值
- 示例
- 注意事项

本章重点：

- 搜索只负责找书
- 返回 `Book[]`
- `detailUrl` 为什么重要
- 搜索里不要顺手做详情/目录/正文

## 6. `detail(ctx, book)` 怎么写

重点：

- 补齐详情字段
- 推荐 `return { ...book, ...补充字段 }`
- `tocUrl` 为什么重要

## 7. `chapters(ctx, book)` 怎么写

重点：

- 返回完整目录
- 目录分页怎么处理
- 为什么不能只抓第一页
- `index` 如何保持稳定

## 8. `content(ctx, book, chapter)` 怎么写

重点：

- 返回 `Content`
- 正文分页怎么合并
- 图片正文怎么返回
- 正文为空时怎么排查

## 9. 可选方法怎么写

- `init(ctx, task)`
- `discoverCategories(ctx)`
- `discoverBooks(ctx, category, page, pageSize)`

## 10. 标准对象怎么返回

- `DiscoverCategory`
- `Book`
- `Chapter`
- `Content`
- `extra`
- `debug`

说明：

- 本章只放作者最关心的返回规则
- 字段明细可链接到对象手册

## 11. 调试怎么做

- 网页调试台怎么用
- 单步调试怎么看
- 完整链路怎么看
- 日志/轨迹怎么读

## 12. 发布前检查

- 能编译
- 搜索可用
- 详情完整
- 目录全量
- 正文可读
- `checkKeyword` 合理
- 浏览器挑战场景可继续

## 3. 主手册中每个核心方法的写法模板

后续 `search / detail / chapters / content` 每章都统一写成：

### 方法：`search(ctx, keyword)`

#### 功能

说明这个方法负责什么。

#### 参数

- `ctx`
- `keyword`

#### 返回值

- 返回 `Book[]`
- 必须满足什么要求

#### 示例

```js
async search(ctx, keyword) {
  // ...
}
```

#### 注意事项

- 建议怎么写
- 不建议怎么写
- 常见坑

## 4. 主手册不再承担的内容

下面这些内容不建议继续塞在主手册里：

- `ctx.*` 全方法详解
- 所有加解密 API 详细签名
- 所有浏览器能力边界解释
- 所有排错案例

这些应拆到：

- API 手册
- 对象手册
- 排错手册
- cookbook

## 5. 与现有文档的关系

当前建议：

- 先保留现有 [official-source-author-guide.md](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/docs/script_sources/official-source-author-guide.md)
- 新增本文作为 v2 骨架
- 确认结构满意后，再按章节迁移重写

## 6. 第一批优先重写章节

如果要真正开始重写，建议优先写这 5 章：

1. `meta`
2. `search(ctx, keyword)`
3. `detail(ctx, book)`
4. `chapters(ctx, book)`
5. `content(ctx, book, chapter)`

原因：

- 这是所有书源作者最常用的部分
- 也是你提到“每个方法都要说明如何编写”的核心区域
