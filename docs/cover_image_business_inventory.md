# 封面图业务梳理

更新时间：2026-04-27  
用途：梳理当前项目内“书籍封面图”相关能力的业务线、数据来源、展示优先级、消费入口与架构问题，作为后续收口基线。  
约束基线：如与 `docs/development_architecture_guardrails.md` 冲突，以 guardrails 为准。

---

## 1. 结论先行

当前项目里的“封面图”不是一个单一概念，而是至少混合了 5 类能力：

1. 远程书源返回的真实封面 URL
2. 本地图书索引阶段提取出的本地封面文件
3. 用户为单本书设置的自定义封面
4. 主题层提供的封面图库兜底
5. 无图时生成的文本占位封面

现在的问题不是“没有封面能力”，而是：

- **封面来源很多，但没有统一业务模型**
- **不同页面对封面优先级的理解不一致**
- **展示逻辑、元数据覆盖逻辑、存储逻辑分散在多个 feature 和页面里**
- **部分实现已越过 guardrails 规定的层级边界**

一句话总结：

- **当前封面图能力可用，但没有被收口成一条清晰业务线。**

---

## 2. 当前封面图的业务对象

### 2.1 远程真实封面

语义：

- 来自书源搜索 / 发现 / 详情返回的 `cover` 或 `coverUrl`
- 本质是“源站提供的作品封面”

主要落点：

- `lib/runtime/sources/source_result_models.dart`
- `lib/domain/entities/book.dart`
- `lib/domain/entities/book_detail.dart`
- `lib/domain/entities/bookshelf_book.dart`
- `lib/domain/entities/reading_record.dart`

特点：

- 通常是 `http/https` URL
- 可能在搜索结果、发现页结果、详情结果之间不一致
- 目前也被当作书架/阅读记录的展示快照持久化

### 2.2 本地图书解析封面

语义：

- 来自 EPUB / MOBI / AZW / Markdown / HTML 等本地图书索引阶段抽取出的封面资源
- 本质是“本地图书内容解析后的托管封面文件”

主要落点：

- `lib/domain/entities/local_book.dart`
- `lib/features/reader/application/local/local_book_parser.dart`
- `lib/features/reader/application/local/local_book_index_service.dart`
- `lib/features/reader/application/local/epub_local_book_parser.dart`
- `lib/features/reader/application/local/kindle_local_book_parser.dart`
- `lib/features/reader/application/local/local_markup_book_parser_support.dart`

特点：

- 使用 `coverPath`
- 本质是受托管的本地文件路径
- 索引完成后会同步给书架和阅读记录，转成 `file://` 形式的 `coverUrl`

### 2.3 用户自定义封面

语义：

- 用户手动给某本书替换的封面
- 本质是“用户覆盖默认封面的个体化设置”

远程书籍存储位置：

- `book_metadata_overrides.coverPath`

本地图书存储位置：

- `local_books.coverPath`

主要落点：

- `lib/domain/entities/book_metadata_override.dart`
- `lib/features/book/application/custom_cover_storage_service.dart`
- `lib/features/book/presentation/book_detail_page.dart`
- `lib/data/datasources/local/app_database.dart`

特点：

- 图片文件会被复制到应用托管目录
- 远程书和本地图书目前走了两套持久化路径
- 这类封面按业务语义应该优先级最高

### 2.4 主题封面图库

语义：

- 并不是真正的“书籍元数据封面”
- 而是当书籍没有可用封面时，由主题系统给出的视觉兜底图

主要落点：

- `lib/domain/entities/cover_gallery.dart`
- `lib/features/mine/application/cover_gallery_service.dart`
- `lib/app/widgets/resolved_book_cover.dart`
- `lib/domain/entities/app_advanced_theme.dart`

特点：

- 与单本书籍元数据无关
- 属于外观主题层，不属于书籍事实数据
- 当前在封面解析函数中与真实封面、自定义封面混在一起做选择

### 2.5 文本占位封面

语义：

- 当没有任何图片封面时，根据标题/作者生成的视觉占位

主要落点：

- `lib/app/widgets/text_cover_placeholder.dart`

特点：

- 纯 UI 能力
- 不参与持久化
- 应该是最终兜底，而不是业务数据的一部分

---

## 3. 当前业务链路

### 3.1 远程书籍链路

当前主链路：

1. 书源脚本返回 `cover`
2. 运行时模型 `runtime_models.Book.cover`
3. 映射到领域模型 `Book.coverUrl`
4. 搜索 / 发现 / 详情页读取该字段
5. 若存在用户覆盖，则再叠加 `BookMetadataOverride.coverPath`
6. 进入书架或阅读记录后，再把当前展示封面快照写入 `BookshelfBook.coverUrl` / `ReadingRecord.coverUrl`
7. 页面最终通过 `resolveBookCover()` 渲染

涉及入口：

- 搜索：`lib/features/search/application/script_source_search_runner.dart`
- 发现：`lib/features/discover/application/explore_service.dart`
- 详情：`lib/features/book/application/book_detail_service.dart`
- 展示态解析：`lib/features/book/application/book_presentation_query_service.dart`

### 3.2 本地图书链路

当前主链路：

1. 导入文件生成 `LocalBook`
2. 索引阶段解析标题、作者、简介、`coverPath`
3. `LocalBookIndexService` 持久化本地图书元数据
4. 索引完成后同步书架与阅读记录展示快照
5. 页面读取本地 `coverPath` 或同步后的 `file:// coverUrl`
6. 最终通过 `resolveBookCover()` 渲染

涉及入口：

- 导入：`lib/features/bookshelf/application/local_book_import_service.dart`
- 索引：`lib/features/reader/application/local/local_book_index_service.dart`
- 解析：`lib/features/reader/application/local/*_local_book_parser.dart`

### 3.3 用户自定义封面链路

当前主链路：

1. 用户在书籍详情页选择图片
2. `CustomCoverStorageService` 将图片复制到应用托管目录
3. 远程书写入 `BookMetadataOverride.coverPath`
4. 本地图书写入 `LocalBook.coverPath`
5. 页面刷新展示态
6. 部分页面使用 `displayCover`，部分页面使用 `realCoverUrl + customCoverPath` 再二次判断

这条链路现在已经存在，但收口不完整，主要问题是各页面读取口径不一致。

### 3.4 主题兜底链路

当前主链路：

1. 主题可绑定 `coverGalleryId`
2. `resolveBookCover()` 在没有可用图片时，从图集中按稳定 hash 选一张
3. 若图集也没有可用图片，则回退到文本占位封面

这条链路本质上是“外观兜底链路”，不应与书籍真实封面或用户覆盖封面混为一类业务数据。

---

## 4. 当前封面图消费入口

当前主要消费页面包括：

- 书架页
- 搜索结果页
- 发现页
- 书籍详情页
- 阅读记录页
- 首页继续阅读/最近阅读
- 书签页
- 缓存管理页
- 阅读器目录弹层
- 外观设置页中的封面预览

统一渲染组件：

- `lib/app/widgets/resolved_book_cover.dart`
- `lib/app/widgets/disk_cached_cover_image.dart`
- `lib/app/widgets/text_cover_placeholder.dart`

说明：

- 视觉层“看起来统一”，因为多数页面最终都走了 `ResolvedBookCoverView`
- 但**进入这个组件之前的封面解析口径并不统一**

---

## 5. 当前实际优先级

从业务语义看，合理优先级应该是：

1. 用户自定义封面
2. 本地图书解析出的托管封面
3. 远程真实封面
4. 主题封面图库
5. 文本占位封面

但当前代码里至少存在两种不同口径：

### 5.1 `BookMetadataPresentationResolver` 的口径

这里的口径是：

- `customCoverPath` 存在且文件可读时，`displayCover = file://custom`
- 否则回退到 `realCoverUrl`

这说明该 resolver 认为：

- **自定义封面优先于真实封面**

### 5.2 `resolveBookCover()` 的口径

当前已收口为：

- 先尝试 `customCoverPath`
- 再尝试 `realCoverUrl`
- 再尝试主题图库
- 最后回退占位图

说明：

- 这已经与 `BookMetadataPresentationResolver` 的展示态优先级对齐
- 至少在最终渲染入口上，**自定义封面优先于真实封面** 已经成为唯一规则

当前剩余问题：

- 不同页面传参方式仍有差异
- 但最终渲染口径已经统一，不再出现“同一页面链路里真实封面压过自定义封面”的问题
- 当前展示态还新增了显式封面来源类型，可区分：
  - `overrideCustom`
  - `localManaged`
  - `remote`
  - `none`

---

## 6. 已确认的主要问题

### 6.1 问题一：封面优先级不一致

这是当前最直接的业务问题。

表现：

- `BookMetadataPresentationResolver` 认为自定义封面优先
- `resolveBookCover()` 认为真实封面优先
- 搜索 / 书架 / 阅读记录等页面经常传 `realCoverUrl + customCoverPath`
- 发现页更多使用 `displayCover`

结果：

- 用户设置自定义封面后，不同页面展示结果可能不一致

### 6.2 问题二：封面展示态解析被散落在多个页面里

当前很多页面自己拼：

- 标题使用哪个字段
- 作者使用哪个字段
- 封面用 `displayCover` 还是 `realCoverUrl`
- 是否叠加 `customCoverPath`
- 是否再套主题图库兜底

结果：

- 同一条业务规则在多个页面重复实现
- 后续改优先级时需要逐页修
- 很容易出现一个页面改了，另一个页面漏改

### 6.3 问题三：封面业务边界和主题视觉边界混在一起

当前 `resolveBookCover()` 同时做了：

- 真实封面解析
- 自定义封面解析
- 主题图库兜底
- 占位图兜底

这会导致：

- “封面事实数据” 与 “外观主题兜底” 混在一个函数里
- 后面如果要扩展漫画封面、作者头像、系列封面或按阅读模式切换封面策略，会越来越难拆

### 6.4 问题四：部分实现越过了 guardrails 规定的边界

#### A. feature application 直接依赖 `AppDatabase`

历史位置：

- `lib/features/book/application/book_presentation_query_service.dart`
- `lib/features/mine/application/cache_management_service.dart`

当前进度：

- [x] 已完成整改

当前口径：

- `BookPresentationQueryService` 改为依赖 `BookMetadataOverrideRepository`
- `CacheManagementService` 改为依赖 repository / stable service 组合

#### B. feature application 跨 feature 依赖业务常量

典型位置：

- `BookPresentationQueryService` 直接依赖 `LocalBookImportService.localBookSourceId`

问题：

- 这是把“本地书 sourceId 语义”绑在了另一个 feature 的实现类上
- 这类稳定语义更适合放到共享 identity / policy 层

#### C. 页面直接做封面存储与元数据写入

典型位置：

- `lib/features/book/presentation/book_detail_page.dart`

历史问题：

- 拉起图片选择
- 调用封面文件持久化
- 决定远程书写 override 还是本地图书写 localBook
- 直接写 repository

当前进度：

- [x] 已完成第一轮下沉

当前口径：

- `BookMetadataEditService` 负责封面/metadata 保存与重置
- `BookPresentationSyncService` 负责快照同步
- 页面保留消息提示、弹窗确认与交互分发

---

## 7. 按 guardrails 应如何定义职责

建议把封面相关能力明确拆成 3 层。

### 7.1 元数据事实层

职责：

- 定义一本书当前有哪些候选封面来源
- 不负责主题兜底
- 不负责最终 UI 组件渲染

建议输入：

- `realCoverUrl`
- `localCoverPath`
- `overrideCoverPath`

建议输出：

- 一个稳定的 `BookCoverState` / `BookCoverDescriptor`

### 7.2 应用编排层

职责：

- 统一决定封面优先级
- 统一加载 override、本地图书元数据、快照数据
- 对外暴露“这本书当前应展示的封面状态”

建议能力：

- `resolveBookPresentation(...)`
- `setCustomCover(...)`
- `removeCustomCover(...)`
- `syncPresentationSnapshot(...)`

### 7.3 UI 渲染层

职责：

- 根据统一的封面状态做渲染
- 在没有业务封面时，决定是否使用主题图库或文本占位图

说明：

- 主题图库和文本占位图属于 **UI fallback**
- 不应反向污染书籍元数据层

---

## 8. 建议收口后的统一优先级

建议明确成唯一口径：

1. 用户自定义封面
2. 本地图书托管封面
3. 远程真实封面
4. 主题封面图库
5. 文本占位封面

并且要求：

- 所有页面只能消费统一的封面展示态
- 页面不能再自己决定封面优先级

---

## 9. 建议整改顺序

### 第一阶段：先统一规则，不急着大拆

目标：

- 先让所有页面展示结果一致

建议动作：

1. 明确唯一封面优先级
2. 收口为统一的“展示态解析入口”
3. 所有页面改为消费同一种封面展示模型

当前进度：

- [x] 最终渲染入口 `resolveBookCover()` 已统一为 `自定义 > 真实 > 图库 > 占位`
- [ ] 页面入参仍待进一步收口为更统一的展示模型

### 第二阶段：把页面里的封面业务编排搬走

目标：

- 让详情页不再直接做封面写入与元数据决策

建议动作：

1. 抽出 `BookCoverMutationService` 或 `BookMetadataEditCoordinator`
2. 页面只触发“设置封面 / 移除封面 / 保存编辑”
3. provider 负责注入依赖

当前进度：

- [x] 已抽出 `BookMetadataEditService`
- [x] 已抽出 `BookPresentationSyncService`
- [x] 详情页的封面保存、metadata 写回、快照同步已下沉到 application service

### 第三阶段：把 application 对 data 的直连改成 repository/service

目标：

- 对齐 guardrails

建议动作：

1. `BookPresentationQueryService` 不再直接依赖 `AppDatabase`
2. `CacheManagementService` 不再直接拼数据库细节
3. 本地书 identity 常量移出 `LocalBookImportService`

### 第四阶段：把主题兜底从业务封面语义中拆开

目标：

- 让“书籍封面”与“主题视觉替身”成为两个明确概念

建议动作：

1. 统一输出业务封面状态
2. UI 层再决定是否应用 `coverGallery`
3. 书架、搜索、详情、阅读记录都复用同一渲染入口

---

## 10. 这次梳理后的明确判断

当前项目中，封面图相关功能已经形成了下面这条实际业务线：

- **书源/本地解析产出封面**
- **用户可覆盖封面**
- **书架/阅读记录持久化封面快照**
- **页面消费封面展示态**
- **主题系统提供最终视觉兜底**

问题不在“有没有这条线”，而在：

- **这条线被拆散到了多个页面、多个 service、多个存储语义里**
- **还没有形成统一的封面领域口径**

后续如果继续开发封面相关能力，建议默认遵守下面三条：

1. 书籍真实封面、自定义封面、主题兜底封面必须分层建模
2. 页面不再直接拼装封面解析规则
3. 封面优先级只能有一套，不允许页面自定义

补充：

- 书籍身份语义已开始收口到 `lib/domain/entities/book_identity.dart`
- 后续封面展示态如果继续收口，应直接复用 `logicalBookId` / `sourceBookKey` 口径，不再各自拼接来源身份
