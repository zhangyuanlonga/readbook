# 书籍与封面业务梳理

更新时间：2026-04-27  
用途：统一梳理当前项目中“书籍模型”和“封面模型”的职责、流转关系、主键语义、展示快照与架构边界问题，作为后续收口基线。  
补充说明：封面专题详版见 `docs/cover_image_business_inventory.md`。

---

## 1. 结论先行

当前项目里，“书籍”并不是一个单一模型，而是由多种不同语义的实体共同承载：

1. `Book`：搜索/发现列表中的轻量书籍结果
2. `BookDetail`：详情阶段的书籍事实
3. `BookshelfBook`：书架收藏快照
4. `LocalBook`：本地图书索引与存储实体
5. `ReadingRecord`：阅读进度快照

而“封面”既是书模型的一部分，又不是同一层意义上的字段：

1. 有的封面是作品事实数据
2. 有的封面是本地索引结果
3. 有的封面是用户覆盖结果
4. 有的封面只是主题层视觉兜底

当前真正的问题不是模型少，而是：

- **书籍实体很多，但角色边界没有被显式讲清楚**
- **`bookId / sourceId / detailUrl` 三元组语义并不稳定**
- **多个实体都在保存标题、作者、封面，形成大量展示快照**
- **封面优先级和书籍展示态规则分散在多个页面**
- **部分 application / presentation 已越过 guardrails 边界**

一句话总结：

- **现在的实现更像“多阶段书籍快照系统”，而不是单一统一书模型。**

---

## 2. 当前书籍模型角色表

### 2.1 `Book`

位置：

- `lib/domain/entities/book.dart`

字段特点：

- `id`
- `sourceId`
- `title`
- `detailUrl`
- `author`
- `intro`
- `coverUrl`
- `latestChapter`

语义判断：

- 这是列表态模型，不是完整事实模型
- 主要用于搜索结果、发现结果、部分跳转入参
- 其 `id` 当前更多是“来源内检索结果标识”

当前来源：

- 搜索：`lib/features/search/application/script_source_search_runner.dart`
- 发现：`lib/features/discover/application/explore_service.dart`

### 2.2 `BookDetail`

位置：

- `lib/domain/entities/book_detail.dart`

字段特点：

- 与 `Book` 高度重叠
- 增加 `tocUrl`
- 不包含 `latestChapter`

语义判断：

- 这是详情阶段事实模型
- 表示“当前来源下这本书的详情信息”
- 仍然是远程态/阅读入口态，不是收藏快照

当前来源：

- 远程：`lib/features/book/application/book_detail_service.dart`
- 本地：`lib/features/reader/application/local_content_provider.dart`

### 2.3 `BookshelfBook`

位置：

- `lib/domain/entities/bookshelf_book.dart`

字段特点：

- `bookId`
- `sourceId`
- `title`
- `detailUrl`
- `addedAt`
- `author`
- `category`
- `coverUrl`
- `latestChapter`

语义判断：

- 这是书架收藏快照
- 它不是详情事实，也不是纯展示模型
- 它保存的是“当前书架入口需要的最小快照”

特点：

- 由 `SharedPreferences` 持久化
- 会被后续详情刷新、本地索引、换源等操作二次更新

### 2.4 `LocalBook`

位置：

- `lib/domain/entities/local_book.dart`

字段特点：

- 除标题/作者/封面外，还包含：
  - `format`
  - `storagePath`
  - `sourcePath`
  - `charset`
  - `description`
  - `coverPath`
  - `indexStatus`
  - `chapterCount`
  - `lastError`
  - `splitLongChapter`

语义判断：

- 这是本地图书索引与存储主实体
- 它不是书架快照，也不是远程书详情
- 它同时承载“文件身份 + 索引状态 + 阅读准备状态 + 元数据”

### 2.5 `ReadingRecord`

位置：

- `lib/domain/entities/reading_record.dart`

字段特点：

- `bookId`
- `sourceId`
- `detailUrl`
- `bookTitle`
- `bookAuthor`
- `coverUrl`
- `lastChapterId`
- `lastChapterTitle`
- `lastPositionRatio`
- `totalReadMillis`

语义判断：

- 这是阅读快照，不是书籍事实模型
- 用于最近阅读、统计、继续阅读等场景
- 保存的是“阅读视角下当前这本书的最新展示状态”

---

## 3. 当前主键与身份语义

当前书模型实际依赖的是三元组：

1. `bookId`
2. `sourceId`
3. `detailUrl`

但它们不是同一层稳定主键。

### 3.1 `Book.id` 语义

在搜索结果里，`Book.id` 是通过 `sourceId + detailUrl` 生成的：

- 见 `lib/features/search/application/script_source_search_runner.dart`

这说明：

- 它更像“来源内作品标识”
- 它依赖当前来源
- 换源后理论上应该变化

### 3.2 `BookshelfBook.bookId` 语义

在书架换源逻辑里，构建替换后的 `BookshelfBook` 时保留了旧 `bookId`，只替换 `sourceId/detailUrl`：

- 见 `lib/features/reader/application/reader_source_switch_coordinator.dart`

这说明：

- `BookshelfBook.bookId` 更像“逻辑作品主键”
- 它并不总是来源内标识

### 3.3 `LocalBook.id` 语义

本地图书导入时，`BookshelfBook.bookId` 直接等于 `LocalBook.id`：

- 见 `lib/features/bookshelf/application/local_book_import_service.dart`

这说明：

- 本地态里 `bookId` 又变成了“本地存储实体主键”

### 3.4 当前判断

因此当前项目里的 `bookId` 至少混合了 3 种含义：

1. 远程来源内标识
2. 逻辑作品标识
3. 本地实体标识

这是后续收口时必须明确的一点。

---

## 4. 当前书籍主链路

### 4.1 远程书籍链路

主链路：

1. 书源搜索/发现返回运行时 `Book`
2. 运行时映射到领域 `Book`
3. 路由把 `bookId/sourceId/detailUrl/title/author/coverUrl` 作为跳转入参带到详情页
4. 详情页再用 `BookDetailService` 拉取 `BookDetail`
5. 详情页刷新后，同步更新：
   - `ReaderTocSnapshot`
   - `ReadingRecord`
   - `BookshelfBook`

这说明：

- 列表态和详情态是分开的
- 详情页同时承担了“事实刷新 + 展示快照回写”的职责

### 4.2 本地图书链路

主链路：

1. 文件导入生成 `LocalBook`
2. 同时生成本地书架入口 `BookshelfBook`
3. 索引阶段解析标题、作者、简介、封面、章节
4. `LocalContentProvider` 再把 `LocalBook` 映射成 `BookDetail`
5. 索引结果回写书架和阅读记录快照

这说明：

- 本地阅读其实是另一条模型体系
- 只是为了和远程详情页、阅读器共用入口，才被投影成 `BookDetail`

### 4.3 阅读过程链路

主链路：

1. 进入阅读器时建立阅读 session
2. session 保存 `bookId/sourceId/detailUrl/title/author/coverUrl`
3. 提交时生成 `ReadingRecordCommitInput`
4. 持久化为 `ReadingRecord`
5. 统计、最近阅读、缓存管理等页面再基于该快照展示

这说明：

- 阅读记录不是书籍事实
- 它是“读到哪里时，这本书在当时长什么样”的快照

---

## 5. 封面在书模型中的位置

封面确实属于书模型的一部分，但不是所有书模型里的同一种字段。

### 5.1 作为远程事实字段

- `Book.coverUrl`
- `BookDetail.coverUrl`

语义：

- 当前来源返回的真实封面

### 5.2 作为本地索引字段

- `LocalBook.coverPath`

语义：

- 本地图书解析后的托管封面文件

### 5.3 作为用户覆盖字段

- `BookMetadataOverride.coverPath`
- 以及本地图书上被用户直接改写的 `LocalBook.coverPath`

语义：

- 用户意图覆盖默认封面

### 5.4 作为展示快照字段

- `BookshelfBook.coverUrl`
- `ReadingRecord.coverUrl`

语义：

- 当时写回给 UI 的展示封面快照
- 不一定等于真实封面

### 5.5 作为视觉兜底

- `CoverGallery`
- `TextCoverPlaceholder`

语义：

- 不属于书籍事实
- 属于 UI fallback

---

## 6. 书模型与封面模型的当前耦合点

### 6.1 详情页是最大的耦合中心

详情页当前同时处理：

- 书籍事实刷新
- 自定义封面选择与保存
- override / local metadata 保存
- 书架快照更新
- 阅读记录展示态同步

这导致：

- 书模型更新和封面模型更新都堆在同一页面
- 页面不只是 presentation，而是已经承担 application 编排

### 6.2 书架和阅读记录都在保存“书籍展示快照”

这意味着：

- 标题、作者、封面在多个地方重复存储
- 数据源并不唯一
- 同一本书在不同模块可能展示不同状态

### 6.3 本地书身份规则仍跨 feature 耦合

`LocalReaderIdentity` 仍依赖 `LocalBookImportService.localBookSourceId`。

这意味着：

- 本地书 identity 规则仍绑在书架导入 feature 上
- 共享语义没有完全提到稳定公共层

---

## 7. 当前主要问题

### 7.1 `Book` 与 `BookDetail` 过于接近，但职责没有被说清

问题：

- 两者字段高度重合
- 容易被误认为同一模型的不同阶段
- 但实际一个是列表态结果，一个是详情态事实

风险：

- 后续很容易继续把列表逻辑和详情逻辑混用

### 7.2 `BookshelfBook` 与 `ReadingRecord` 都在保存重复书籍信息

问题：

- 标题、作者、封面在两边重复存储
- 这些字段都可能被详情刷新、本地索引、用户编辑再次改写

风险：

- 快照不同步时，多个页面展示不一致

### 7.3 `bookId` 语义不统一

问题：

- 有时是来源标识
- 有时是逻辑作品标识
- 有时是本地实体标识

风险：

- 换源、合并记录、书架更新、阅读统计之间会持续出现隐性耦合

### 7.4 封面优先级仍不统一

问题：

- 封面既属于书模型，又存在单独的展示优先级
- 当前不同入口的优先级不一致

风险：

- 用户改封面后，不同页面不一致

### 7.5 页面承担了过多业务编排

问题：

- 详情页直接协调 repository、storage、record、bookshelf

风险：

- 继续开发会让页面更大
- 与 `docs/development_architecture_guardrails.md` 冲突

---

## 8. 建议收口方向

### 8.1 明确区分 5 类书籍模型

建议口径：

1. `Book`：检索结果模型
2. `BookDetail`：详情事实模型
3. `BookshelfBook`：书架快照模型
4. `LocalBook`：本地索引/存储模型
5. `ReadingRecord`：阅读快照模型

要求：

- 后续新增字段时，先问“这是事实字段，还是快照字段”

### 8.2 明确区分 2 类主键

建议显式拆分概念：

1. `workId` / `logicalBookId`：逻辑作品主键
2. `sourceBookKey`：来源内主键（由 `sourceId + detailUrl` 等构成）

至少先在文档和 service 语义层明确，不要继续默认 `bookId` 同时承担所有角色。

当前进度：

- 已新增内部 identity 语义层：`lib/domain/entities/book_identity.dart`
- 已在搜索、发现、本地 detailUrl 构造、来源阅读流键、书架换源主键保留等关键入口接入
- 现阶段仍保持外部字段名兼容，尚未进行全局字段迁移

当前口径：

- `logicalBookId`：应用内部逻辑作品主键，当前仍兼容落在既有 `bookId` 字段上
- `sourceBookKey`：来源内作品键，统一由 identity helper 构造，避免继续散落拼接
- 书架换源时保留 `logicalBookId`，只替换 `sourceId + detailUrl`

### 8.3 把封面统一看作“书籍展示态”的一个字段

建议：

- 封面不单独到处拼规则
- 由统一的书籍展示态服务一次性输出：
  - `displayTitle`
  - `displayAuthor`
  - `displayIntro`
  - `displayCover`
  - `realCoverUrl`
  - `customCoverPath`

### 8.4 把详情页里的编辑/封面变更编排下沉到 application

建议抽出：

- `BookPresentationService`
- `BookMetadataEditCoordinator`
- `BookCoverMutationService`

页面只负责：

- 发起编辑动作
- 订阅结果
- 呈现状态

### 8.5 把展示快照同步做成稳定能力

现在有多处代码在做：

- 详情刷新后同步书架
- 本地索引后同步书架
- 详情刷新后同步阅读记录
- 本地索引后同步阅读记录

建议收口成统一能力，例如：

- `BookPresentationSnapshotSyncService`

---

## 9. 这次合并梳理后的明确判断

当前项目里的“书籍”最好理解为：

- **一个逻辑作品**
- 在不同阶段被投影成多种模型
- 并在书架、阅读记录、主题展示中形成多个快照

而“封面”最好理解为：

- **书籍展示态中的一个字段**
- 但它的来源可以来自真实数据、本地索引、用户覆盖或 UI fallback

所以后续开发时，建议默认遵守下面三条：

1. 先区分“书籍事实模型”和“书籍展示快照模型”
2. 再区分“真实封面字段”和“展示封面字段”
3. 页面不再自己决定书籍展示态与封面优先级
