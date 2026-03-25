# 统一书源调度方案

更新时间：2026-03-25

这份文档用于说明 `flutterreadbook` 当前“旧规则源 + 脚本源”并存状态下，为什么需要引入统一调度抽象，以及建议如何落地。

目标不是立刻统一所有模型，而是先把“执行入口”和“书源识别逻辑”从各个业务服务中收口。

---

## 1. 背景

当前仓库已经进入“双轨并存”状态：

- 旧规则链：
  - 书源描述使用 [SourceDefinition](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/domain/entities/source_definition.dart)
  - 搜索 / 详情 / 正文分别由旧业务 service 直接驱动
- 新脚本源链：
  - 书源描述使用 [ScriptSource](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/domain/entities/script_source.dart) + runtime 的 [SourceManifest](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/runtime/sources/source_manifest.dart)
  - 执行依赖 [SourceRuntimeFacade](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/source/application/source_runtime_facade.dart)

同时，当前项目里已经存在两套结果模型：

- 产品层旧模型：
  - [Book](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/domain/entities/book.dart)
  - [BookDetail](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/domain/entities/book_detail.dart)
  - [Chapter](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/domain/entities/chapter.dart)
- runtime 新模型：
  - [runtime Book](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/runtime/sources/source_result_models.dart)
  - [runtime Chapter](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/runtime/sources/source_result_models.dart)
  - [runtime Content](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/runtime/sources/source_result_models.dart)

当前接线方式是：

- [SearchService](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/search/application/search_service.dart)
- [BookDetailService](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/book/application/book_detail_service.dart)
- [ChapterContentService](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/chapter_content_service.dart)

这三个服务分别自己判断：

- 当前 `sourceId` 属于旧规则源还是脚本源
- 该走旧链还是新 runtime
- 如何做结果适配

这是一种可工作的过渡方案，但不适合作为长期结构。

---

## 2. 当前问题

## 2.1 执行路由分散

现在“走旧引擎还是新引擎”的判断分散在多个业务服务里：

- 搜索自己判断
- 详情自己判断
- 正文自己判断

直接后果：

- 每接一条新业务链，都要再写一套判断逻辑
- source 类型识别逻辑容易漂移
- 出错时难以定位到底是调度问题还是执行问题

## 2.2 书源描述不统一

旧规则源和脚本源并不是同一种概念对象：

- [SourceDefinition](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/domain/entities/source_definition.dart)
  是“声明式规则源”
- [SourceManifest](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/runtime/sources/source_manifest.dart)
  是“脚本源的轻量元信息”

如果后面继续让产品层直接面对两套对象，问题会变成：

- 书源列表如何统一排序/筛选
- 搜索页如何统一统计源数量
- 页面如何明确展示书源类型

## 2.3 结果模型双轨

当前的 `as runtime_models` 适配是合理的过渡方案，但它意味着：

- 适配代码正在逐步扩散
- 新旧模型字段语义可能逐渐不一致

这不是当前必须马上解决的问题，但必须被明确记录为技术债。

## 2.4 未来扩展点会越来越多

只要后面继续做这些功能，复杂度都会继续上升：

- 书源筛选
- 书源测试
- 书源分组
- 搜索聚合
- 详情页换源
- 阅读页自动换源

如果没有统一调度层，复杂度会继续向业务 service 蔓延。

---

## 3. 方案目标

这次方案的目标不是“一步统一所有模型”，而是先做三件事：

1. 统一书源识别
2. 统一执行路由
3. 统一业务层依赖入口

换句话说：

- 产品层不再直接关心“这是旧规则源还是脚本源”
- 产品层只关心“这是一个可搜索 / 可加载详情 / 可加载正文的书源”

---

## 4. 非目标

当前阶段暂不做这些事：

1. 不立刻废弃旧 `Book / BookDetail / Chapter` 产品层模型
2. 不立刻把旧规则转译进新 runtime
3. 不立刻把所有旧 service 删除
4. 不立刻重做书源市场 / 书源管理全套 UI

这些都可以后续做，但不是当前最优先的工作。

---

## 5. 推荐的新分层

建议把书源相关结构明确成四层。

## 5.1 宿主持久化层

职责：

- 保存旧规则源
- 保存脚本源源码
- 保存宿主状态

当前对应：

- [SourceRepository](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/domain/repositories/source_repository.dart)
- [ScriptSourceRepository](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/domain/repositories/script_source_repository.dart)

## 5.2 统一书源描述层

职责：

- 给产品层一个统一的“书源条目”视图
- 不暴露旧规则内部细节，也不暴露脚本源源码细节

建议新增对象：

`UnifiedSourceDescriptor`

建议字段：

```dart
class UnifiedSourceDescriptor {
  final String id;
  final String name;
  final String? group;
  final bool enabled;
  final UnifiedSourceKind kind; // legacy | script
  final bool isMangaSource;
  final bool supportsSearch;
  final bool supportsDetail;
  final bool supportsChapters;
  final bool supportsContent;
  final String? author;
  final String? description;
}
```

说明：

- 这是产品层对象，不是执行层对象
- 它的目的不是承载规则细节，而是给 UI 和调度层统一识别

## 5.3 统一调度层

职责：

- 按 sourceId 找到对应的执行引擎
- 统一对外暴露搜索 / 详情 / 目录 / 正文入口
- 统一做错误标准化和结果适配

建议新增对象：

- `UnifiedSourceDispatchFacade`
- 或 `UnifiedSourceExecutor`

这是当前阶段最关键的新层。

## 5.4 结果适配层

职责：

- 把 runtime 结果适配成当前产品层结果
- 把旧规则链结果也适配到统一返回结构

当前阶段建议保留。

---

## 6. 核心设计

## 6.1 统一书源类型

建议先引入：

```dart
enum UnifiedSourceKind { legacy, script }
```

用途：

- 书源管理页展示
- 搜索页筛选
- 调试日志标记

## 6.2 统一调度入口

建议抽象如下：

```dart
abstract class UnifiedSourceDispatchFacade {
  Future<List<UnifiedSourceDescriptor>> listSources();

  Future<List<Book>> search({
    required String keyword,
    List<String>? sourceIds,
    SearchContentMode contentMode = SearchContentMode.novel,
  });

  Future<BookDetailLoadResult> loadDetail({
    required String sourceId,
    required String bookId,
    required String detailUrl,
    String? fallbackTitle,
    String? fallbackAuthor,
    bool forceRefresh = false,
  });

  Future<ChapterContentResult> loadContent({
    required String sourceId,
    required String chapterUrl,
    String? bookId,
    String? bookTitle,
    int? chapterIndex,
    String? chapterTitle,
    String? nextChapterUrl,
  });
}
```

说明：

- 对外暴露的返回值先维持当前产品层类型
- 内部再决定调用旧规则服务还是脚本源 runtime

## 6.3 路由策略应被封装

不要让业务层到处写：

- “先查 SourceRepository，再查 SourceRuntimeFacade”
- “如果 source 不存在就走脚本源”

建议统一收口到一个地方：

```dart
Future<UnifiedSourceKind> resolveSourceKind(String sourceId);
```

或者直接：

```dart
Future<_ResolvedSourceHandle> resolve(String sourceId);
```

这样后续如果再增加第三种源类型，也不会继续散落。

## 6.4 统一错误边界

调度层应负责把“找不到 source”统一成标准错误，而不是每条链自己抛。

例如：

- `UnknownSourceException`
- `UnsupportedSourceOperationException`

这样页面层只需要按统一错误码处理。

---

## 7. 推荐落地步骤

## 阶段 1：先抽统一描述层

新增：

- `UnifiedSourceKind`
- `UnifiedSourceDescriptor`

并提供一个聚合查询 service，例如：

- `UnifiedSourceCatalogService`

它负责：

- 聚合旧规则源和脚本源
- 输出统一列表对象

这个阶段不改执行链，只先统一“看 source”的方式。

## 阶段 2：抽统一调度层

新增：

- `UnifiedSourceDispatchFacade`

它内部依赖：

- 旧规则链
- 脚本源 facade

这个阶段开始让产品层改依赖它。

## 阶段 3：搜索链改依赖统一调度层

当前 [SearchService](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/search/application/search_service.dart) 已经开始承担一部分调度职责。

建议：

- 把“脚本源并入搜索结果”的逻辑迁到统一调度层
- 搜索页只依赖统一入口

## 阶段 4：详情 / 正文链改依赖统一调度层

把当前：

- [BookDetailService](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/book/application/book_detail_service.dart)
- [ChapterContentService](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/chapter_content_service.dart)

里的 fallback 判断移走。

## 阶段 5：把双模型问题正式登记为技术债

在调度层稳定后，再推动模型统一。

这时可以明确：

- runtime 模型是否成为未来主线
- 旧产品层模型是否逐步废弃

---

## 8. 技术债记录

以下内容建议在文档和任务系统里明确登记。

## 8.1 双结果模型并存

当前状态：

- 产品层 `Book / BookDetail / Chapter`
- runtime 层 `runtime_models.Book / Chapter / Content`

判断：

- 这是过渡期补丁
- 不宜长期维持

建议：

- 当前先保留 adapter
- 后续以 runtime 模型为主线候选，评估统一迁移

## 8.2 双书源描述并存

当前状态：

- `SourceDefinition`
- `SourceManifest`

判断：

- 这是概念模型层面的双轨
- 比字段映射更需要调度层先收口

建议：

- 先加 `UnifiedSourceDescriptor`
- 不要让页面层直接同时理解两套书源对象

## 8.3 业务 service 承担了调度职责

当前状态：

- `SearchService`
- `BookDetailService`
- `ChapterContentService`

都已经在做部分 source 路由判断

判断：

- 这是当前最需要优先清理的结构问题

建议：

- 先抽统一调度层

---

## 9. 为什么先做调度，不先做模型统一

原因很简单：

- 调度层不统一，模型统一也会继续散落判断
- 调度层先统一后，模型统一才有落脚点

所以推荐顺序是：

1. 统一 source 识别
2. 统一执行调度
3. 统一错误边界
4. 最后再看模型统一

---

## 10. 一句话结论

你提到的问题是对的：

- 两套 `Book` 并存是技术债
- `SourceDefinition` 和 `SourceManifest` 是两种完全不同的书源概念
- 当前最应该优先做的不是立刻合并模型，而是加一层统一调度抽象

一句话总结：

- 先统一调度
- 再统一模型
