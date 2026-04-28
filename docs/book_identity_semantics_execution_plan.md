# 书籍身份语义收口执行计划

更新时间：2026-04-27  
目标：先收口应用内部的书籍身份语义，明确 `logicalBookId` 与 `sourceBookKey` 的概念边界。  
执行边界：**本轮不改书源编写规范，不改书源标准 `Book` contract，不改 `detailUrl` 语义，不改书源 custom state 的存储键策略。**
总计划状态：`进行中专题`

关联文档：

- `docs/book_model_and_cover_business_inventory.md`
- `docs/cover_image_business_inventory.md`
- `docs/development_architecture_guardrails.md`
- `docs/script_sources/official-source-author-guide.md`

---

## 1. 本轮不做什么

以下内容本轮明确不动：

- [ ] 不要求书源新增 `id`
- [ ] 不改书源标准 `Book` 对象结构
- [ ] 不改 `title / detailUrl / cover / tocUrl / extra` 的脚本约定
- [ ] 不改 `SourceBookStateContext` 的 `bookId + sourceId + detailUrl` 调用方式
- [ ] 不改 `BookCustomState.storageKey` 的现有兼容逻辑
- [ ] 不直接重命名全项目已有 `bookId` 字段

说明：

- 这些边界是为了保证书源脚本、运行时编译器、自定义状态存储、现有数据都不被破坏。

---

## 2. 本轮要解决什么

当前问题：

- `bookId` 同时承担“来源内作品标识”“逻辑作品标识”“本地实体标识”三种语义
- `sourceId + detailUrl` 的拼接逻辑散落在搜索、发现、书架、阅读器等多个入口
- 本地书 identity 规则和远程书 identity 规则没有统一抽象层

本轮目标：

- [ ] 明确并固化“应用内部身份语义”
- [ ] 新增统一身份模型/工具，避免继续手写拼接
- [ ] 保持现有外部行为和书源兼容性

---

## 3. 目标语义

### 3.1 `sourceBookKey`

定义：

- 来源内作品键
- 用于表达“当前书源/当前详情地址下的这本书”

建议构成：

- 远程书：`sourceId + detailUrl`
- 本地书：`local sourceId + local detailUrl`

用途：

- 远程检索结果映射
- 书源内 custom state
- 同源唯一定位
- 详情/换源/流程容器中的来源态定位

### 3.2 `logicalBookId`

定义：

- 应用内部逻辑作品主键
- 用于表达“应用认为这是同一本书”

当前兼容策略：

- 远程书暂时仍兼容使用现有 `bookId`
- 本地图书继续使用 `LocalBook.id`
- 书架换源仍保留旧 `bookId` 作为逻辑主键

用途：

- 书架收藏
- 阅读记录
- 阅读进度归属
- 本地索引结果同步

---

## 4. 分阶段计划

### Phase 1: 边界确认

- [x] 确认本轮不改书源 contract
- [x] 确认 `detailUrl` 仍是书源侧关键字段
- [x] 确认书源 custom state 兼容边界
- [x] 输出执行计划文档供人工检查

验收标准：

- 能明确回答“是否会影响书源编写”
- 能明确说明哪些地方本轮不会改

### Phase 2: 新增统一身份语义层

- [x] 新增内部身份模型或工具
- [x] 显式表达 `sourceBookKey`
- [x] 显式表达 `logicalBookId`
- [x] 补充注释，说明远程/本地两类身份规则

建议落点：

- `lib/domain/` 下的纯 Dart 模型或工具
- 不依赖 Flutter UI

本次实际落点：

- `lib/domain/entities/book_identity.dart`

本次新增内容：

- `BookIdentityScheme`
- `SourceBookKey`
- `BookIdentity`
- 本地书 identity helper：
  - `buildLocalBookDetailUrl()`
  - `buildLocalChapterUrl()`
  - `parseLocalBookIdFromDetailUrl()`
  - `parseLocalChapterIdFromChapterUrl()`

验收标准：

- 新代码不再需要各处手写 `sourceId + detailUrl` 拼接

### Phase 3: 替换关键入口

优先替换以下入口：

- [x] 搜索结果 `Book.id` / 来源键构造
- [x] 发现页结果 `Book.id` / 来源键构造
- [x] 本地书 detailUrl / source 规则构造
- [x] 书架换源时的身份保留逻辑
- [x] 与书籍展示态强相关的 identity 分支判断

说明：

- 本阶段只替换关键构造入口，不做全量字段重命名。

本次实际替换入口：

- 搜索：
  - `lib/features/search/application/script_source_search_runner.dart`
- 发现：
  - `lib/features/discover/application/explore_service.dart`
- 来源阅读流来源键：
  - `lib/features/source/application/source_runtime_reading_flow_container_service.dart`
- 本地书 source / detailUrl 统一构造：
  - `lib/features/bookshelf/application/local_book_import_service.dart`
  - `lib/features/bookshelf/routes.dart`
  - `lib/features/reader/routes.dart`
  - `lib/features/reader/application/local/local_reader_identity.dart`
- 书架换源时保留逻辑作品主键、替换来源键：
  - `lib/features/reader/application/reader_source_switch_coordinator.dart`

验收标准：

- 关键入口都通过统一 identity 工具构造键值

### Phase 4: 验证

- [x] 增加或更新 identity 相关测试
- [x] 验证搜索/发现映射行为不变
- [x] 验证本地图书 detailUrl 与 sourceId 规则不变
- [x] 验证书架换源行为不变

建议最少覆盖：

- `domain` 层 identity 单元测试
- 搜索/发现 service 测试
- 本地阅读 identity 测试
- 书架换源相关测试

本次已验证：

- `test/domain/entities/book_identity_test.dart`
- `test/features/search/application/search_service_test.dart`
- `test/features/discover/application/explore_service_test.dart`
- `test/features/source/application/source_runtime_reading_flow_container_service_test.dart`
- `test/features/reader/application/reader_source_switch_coordinator_test.dart`
- `test/features/bookshelf/application/local_book_import_service_test.dart`
- `test/features/reader/presentation/reader_route_test.dart`

### Phase 5: 文档回写

- [x] 更新 `docs/book_model_and_cover_business_inventory.md`
- [x] 如有必要，更新 `docs/cover_image_business_inventory.md`
- [x] 补充“新身份语义口径”和“迁移边界”

### Phase 6: 使用约束补充

- [x] 页面 / presenter / service 不再手写 `sourceId + detailUrl` 拼接
- [x] 与书源交互的“来源内作品键”统一优先走 `SourceBookKey`
- [x] 应用内逻辑作品主键统一优先走 `logicalBookId`
- [x] 本地书来源判断统一优先走 `isLocalBookSourceId()`

约束说明：

- `logicalBookId` 只表达“应用认为这是同一本书”，不回流到书源 contract。
- `SourceBookKey` 只表达“当前书源下这本书的唯一定位”，不承担跨源作品合并语义。
- 需要构造书源范围键时，优先使用：
  - `BookIdentity.remote(...)`
  - `BookIdentity.local(...)`
  - `SourceBookKey.forRemoteBook(...)`
  - `SourceBookKey.forReadingFlow(...)`
- 新增业务若仍直接操作 `bookId + sourceId + detailUrl` 三元组，必须先说明它到底属于：
  - 逻辑作品主键
  - 来源内作品键
  - 本地实体主键

验收标准：

- 后续开发能直接按文档判断 `bookId`、`sourceBookKey`、`detailUrl` 应该如何使用

---

## 5. 实施策略

推荐策略：

1. 先新增 identity 语义层
2. 再把关键入口切过去
3. 最后通过测试确认行为不变

明确不推荐：

- 直接全局搜索替换 `bookId`
- 直接修改书源模板或书源文档标准对象
- 修改 `BookCustomState` 的存储键生成方式

---

## 6. 风险点

主要风险：

- 把“来源内键”误当成“逻辑作品主键”
- 把“逻辑作品主键”误回写进书源交互层
- 改动书源 custom state 读写键，导致已有脚本状态丢失
- 本地书和远程书走了不同 identity 规则却被强行合并

控制方式：

- identity 语义层只做新增，不先破坏现有字段
- 与书源交互的接口继续保留现有输入字段
- 新逻辑优先以 adapter 方式接入关键入口

---

## 7. 检查项

在进入代码执行前，请先人工确认下面问题：

- [ ] 可以接受本轮先新增 identity 语义层，而不是全量重命名字段
- [ ] 可以接受先替换关键入口，再逐步推进全局迁移
- [ ] 可以接受书源 contract 与运行时标准对象本轮保持不变
- [ ] 可以接受 `bookId` 在存量代码里暂时继续存在，但新增逻辑不再扩大其语义混用
