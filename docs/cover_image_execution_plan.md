# 封面图整改执行计划

更新时间：2026-04-27  
目标：将当前项目中的封面图能力从“分散实现”收口为统一业务线，明确唯一优先级、统一展示态、下沉页面编排，并对齐开发约束。  
总计划状态：`已完成专题`
关联文档：

- `docs/cover_image_business_inventory.md`
- `docs/book_model_and_cover_business_inventory.md`
- `docs/development_architecture_guardrails.md`

---

## Phase 0 当前已完成

- [x] 梳理封面图业务线文档
- [x] 梳理书模型与封面模型关系文档
- [x] 统一最终渲染入口的封面优先级
- [x] `resolveBookCover()` 已改为 `自定义封面 > 真实封面 > 图库 > 占位图`
- [x] 封面优先级单测已更新并通过

当前产物：

- `docs/cover_image_business_inventory.md`
- `docs/book_model_and_cover_business_inventory.md`
- `lib/app/widgets/resolved_book_cover.dart`
- `test/app/widgets/resolved_book_cover_test.dart`

---

## Phase 1 展示口径统一

目标：

- 所有页面对标题、作者、简介、封面使用同一套展示态口径

任务：

- [x] 明确唯一展示模型：标题、作者、简介、封面统一从同一 presentation 对象输出
- [x] 盘点所有仍直接传 `realCoverUrl + customCoverPath` 的页面
- [x] 搜索页统一改为消费同一种封面展示态
- [x] 发现页统一改为消费同一种封面展示态
- [x] 书架页统一改为消费同一种封面展示态
- [x] 阅读记录页统一改为消费同一种封面展示态
- [x] 书签页、缓存管理页、首页继续阅读入口统一改为消费同一种封面展示态
- [x] 补页面级回归测试，验证自定义封面在各页面显示一致

当前说明：

- 当前统一展示模型沿用 `BookMetadataPresentation`
- 最终渲染入口统一读取 `presentation.displayCover`
- `resolveBookCover()` 只负责“图片来源最终落点 + 主题兜底”，不再承担页面层优先级分歧

验收标准：

- 同一本书在搜索、发现、书架、阅读记录、详情页中展示的封面一致
- 自定义封面不会被真实封面覆盖

---

## Phase 2 展示态查询收口

目标：

- 页面不再自己拼 `title/author/intro/cover` 规则

任务：

- [x] 提炼统一 `BookPresentation` / `BookDisplayState` 模型
- [x] 收口远程书展示态查询入口
- [x] 收口本地图书展示态查询入口
- [x] 收口书架快照展示态查询入口
- [x] 收口阅读记录展示态查询入口
- [x] 页面不再自己拼 `title/author/cover` 优先级
- [x] 补 application/service 层测试

当前说明：

- 当前统一模型使用现有 `BookMetadataPresentation`
- `BookMetadataPresentationResolver` 已新增：
  - `resolveRemoteBook()`
  - `resolveBookshelfBook()`
  - `resolveReadingRecord()`
- `BookPresentationQueryService` 继续负责远程书的 override 查询
- 书架/阅读记录/快照类页面已统一按 presentation 消费封面展示态

验收标准：

- 页面层只消费稳定展示模型
- 不再出现多个页面各自维护一套解析逻辑

---

## Phase 3 封面来源分层

目标：

- 把“书籍事实封面”和“UI 兜底封面”分层表达

任务：

- [x] 明确区分 4 类封面来源
- [x] 远程真实封面
- [x] 本地索引封面
- [x] 用户自定义封面
- [x] 主题图库兜底封面
- [x] 展示态里显式保留“当前命中的封面来源类型”
- [x] 避免把主题图库继续当作书籍事实封面
- [x] 补来源优先级测试

当前说明：

- `BookMetadataPresentation` 已新增 `displayCoverSource`
- 当前来源类型：
  - `overrideCustom`
  - `localManaged`
  - `remote`
  - `none`
- 主题图库仍只在 `resolveBookCover()` 中作为 UI fallback，不回写到展示态事实层

验收标准：

- 能明确回答某个页面当前显示的是哪一类封面
- 主题图库只作为 UI fallback，不回写为书籍事实数据

---

## Phase 4 编辑与写回编排下沉

目标：

- 详情页不再直接承担封面选择、持久化、快照同步等完整编排

任务：

- [x] 从 `book_detail_page.dart` 抽离封面变更编排
- [x] 抽离“选择图片并持久化”能力
- [x] 抽离“远程书 override 保存”能力
- [x] 抽离“本地图书 metadata 保存”能力
- [x] 抽离“书架快照同步”能力
- [x] 抽离“阅读记录展示态同步”能力
- [x] 页面只保留交互分发和状态订阅
- [x] 补详情页交互回归测试

当前说明：

- 已新增：
  - `lib/features/book/application/book_metadata_edit_service.dart`
  - `lib/features/book/application/book_presentation_sync_service.dart`
- `book_detail_page.dart` 已改为通过 application service 执行：
  - 选图并持久化
  - 远程 metadata 保存/重置
  - 本地 metadata 保存/重置
  - toc snapshot / 阅读记录 / 书架快照同步

验收标准：

- 页面层不再直接编排 repository + storage + bookshelf + reading record
- 对齐 `docs/development_architecture_guardrails.md`

---

## Phase 5 数据与依赖边界整改

目标：

- 封面对齐 application / repository / data 分层约束

任务：

- [x] `BookPresentationQueryService` 不再直接依赖 `AppDatabase`
- [x] `CacheManagementService` 不再直接依赖 `AppDatabase`
- [x] 封面展示态相关查询改走 repository / stable service
- [x] 本地书 sourceId 常量不再跨 feature 直接引用实现类
- [x] 对齐 `docs/development_architecture_guardrails.md` 约束
- [x] 补 provider / repository 层测试

当前说明：

- `BookPresentationQueryService` 已改为依赖 `BookMetadataOverrideRepository`
- `CacheManagementService` 已改为依赖：
  - `ReadingRecordService`
  - `LocalBookRepository`
  - `BookMetadataOverrideRepository`
  - `ChapterCacheService`
- 已补测试：
  - `test/features/book/application/book_presentation_query_service_test.dart`
  - `test/features/mine/application/cache_management_service_test.dart`
  - `test/features/book/application/book_provider_smoke_test.dart`

验收标准：

- presentation 不直接碰数据库实现
- feature application 尽量不再直接绑定底层 datasource 细节

---

## Phase 6 快照一致性治理

目标：

- 统一封面变更后的快照同步机制

任务：

- [x] 明确哪些字段属于事实数据
- [x] 明确哪些字段属于书架快照
- [x] 明确哪些字段属于阅读记录快照
- [x] 统一封面变更后的快照同步时机
- [x] 验证详情页改封面后书架同步
- [x] 验证详情页改封面后阅读记录同步
- [x] 验证本地图书重新索引后封面同步
- [x] 补同步链路测试

当前说明：

- 快照同步已收口到 `BookPresentationSyncService`
- 详情页 metadata 保存/重置后，不再由页面分别写：
  - `ReaderTocSnapshot`
  - `ReadingRecord`
  - `BookshelfBook`
- 本地图书重新索引后的封面同步继续由 `LocalBookIndexService` 负责，与新的展示态口径兼容
- 已补测试：
  - `test/features/book/application/book_presentation_sync_service_test.dart`

验收标准：

- 详情修改、本地重索引、来源切换后，各入口展示结果一致

---

## Phase 7 文档与验收

目标：

- 让后续开发可以按统一文档执行，不再重复讨论口径

任务：

- [x] 更新封面业务梳理文档为最终状态
- [x] 更新书模型与封面模型文档为最终状态
- [x] 补充“封面优先级唯一口径”
- [x] 补充“页面不得自行拼装封面规则”
- [x] 输出验收清单
- [x] 搜索/发现/书架/阅读记录/详情页抽样验收

当前验收结果：

- 最终渲染入口统一：`自定义 > 真实 > 图库 > 占位`
- 页面展示入口统一消费 `BookMetadataPresentation`
- 详情页编辑/写回编排已下沉到 application service
- `BookPresentationQueryService` / `CacheManagementService` 已去除 `AppDatabase` 直连

验收标准：

- 文档能直接指导后续封面相关开发和 review

---

## 当前建议执行顺序

建议顺序：

1. `Phase 1`
2. `Phase 2`
3. `Phase 4`
4. `Phase 5`
5. `Phase 6`
6. `Phase 7`
7. `Phase 3`

说明：

- `Phase 3` 的来源分层可以稍后做，因为当前最紧急的问题是页面展示结果不一致和页面编排过重。
- 如果希望先快速稳定用户可见行为，应优先完成 `Phase 1` 和 `Phase 2`。
