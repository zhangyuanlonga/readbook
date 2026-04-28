# 项目架构统一化总计划

更新时间：2026-04-28  
用途：作为当前项目“整体收口”的唯一总编排文档，统一阶段目标、任务范围、已完成项、剩余项、完成标准与文档回填口径。  
后续所有跨专题结构治理，一律以本文件为总看板，再下钻到对应专题文档。

关联基线：

- `docs/product_guide.md`
- `docs/engineering_guide.md`
- `docs/development_architecture_guardrails.md`

关联专题：

- `docs/non_reader_architecture_remediation_plan.md`
- `docs/reader_page_execution_checklist.md`
- `docs/cover_image_execution_plan.md`
- `docs/book_identity_semantics_execution_plan.md`
- `docs/cross_platform_boundary_refactor_plan.md`
- `docs/reader_mode_rearchitecture_plan.md`
- `docs/local_text_epub_execution_plan.md`

---

## 0. 使用规则

这份文档解决两个问题：

1. 当前项目整体还剩哪些结构任务
2. 某轮执行完成后，应该在总计划里勾掉什么

后续执行规则固定为：

1. 先在本文件确认任务归属和完成标准
2. 再做代码改动
3. 跑最小验证
4. 回填专题文档
5. 最后回填本文件

硬约束：

- 不允许“先做代码，后面再说总计划怎么记”
- 不允许“专题文档已更新，但总计划看不出阶段剩余任务”
- 不允许“总计划只写阶段名，不写当前剩余项”

---

## 1. 当前项目判断

当前项目已经不是“缺功能”的阶段，而是“功能齐全、结构仍分散”的阶段。

一句话结论：

- 功能主链已基本完整
- 多个专题已经开始收口
- 但缺少一份能直接指导执行顺序和收尾标准的总任务板

当前最需要统一的不是继续补单点功能，而是这 6 条主线：

1. 依赖入口统一
2. 超大页面与 glue code 下沉
3. 共享业务语义统一
4. 资源系统统一
5. runtime / bridge 边界统一
6. 测试与守卫自动化

---

## 2. 当前功能版图

### 2.1 App 级能力

- App shell
- 底部主导航
- 启动编排
- 全局主题与外观
- 启动图、公告、更新提示

### 2.2 内容获取与阅读闭环

- 书源管理
- 脚本源导入、编辑、登录、调试
- 搜索、发现、详情、目录、正文
- 在线阅读与本地阅读共用主阅读链

### 2.3 本地阅读能力

- `txt / epub / md / html / pdf / mobi / azw / azw3`
- 本地导入、索引、封面抽取、正文结构化、重建索引

### 2.4 阅读体验能力

- 分页 / 滚动 / 漫画阅读模式
- 阅读设置、字体、背景、亮度、翻页动画、自动阅读
- 章节缓存、书签、阅读记录、阅读统计、热力图

### 2.5 Mine 侧能力

- 高级主题
- 应用背景、阅读背景
- 启动图集、封面图集、底栏图集
- 字体管理、缓存管理、反馈、会员、系统设置

结论：

- 这是一个完整阅读产品，不是 demo
- 因此后续结构治理必须按“长期平台维护”思路推进

---

## 3. 当前结构热点

截至 `2026-04-28`，当前最重的页面文件包括：

- `lib/features/reader/presentation/reader_page.dart`：`12276` 行
- `lib/features/bookshelf/presentation/bookshelf_page.dart`：`5790` 行
- `lib/features/mine/presentation/advanced_theme_editor_page.dart`：`3897` 行
- `lib/features/book/presentation/book_detail_page.dart`：`3496` 行
- `lib/features/reader/presentation/reading_records_page.dart`：`2889` 行
- `lib/features/source/presentation/source_page.dart`：`2623` 行
- `lib/features/source/presentation/script_source_debug_page.dart`：`2111` 行

当前最重的 application 文件包括：

- `lib/features/mine/application/advanced_theme_service.dart`
- `lib/features/reader/application/local/epub_local_book_parser.dart`
- `lib/features/reader/application/local/txt_local_book_parser.dart`
- `lib/features/bookshelf/application/bookshelf_service.dart`
- `lib/features/reader/application/reading_record_service.dart`
- `lib/features/reader/application/reader_preferences_service.dart`

当前主要偏差：

1. 页面仍然过重
2. 依赖入口还没完全统一
3. 共享语义尚未完全统一
4. 资源系统仍是平行实现

---

## 4. 总看板

### 4.1 阶段状态

- 阶段 0：已完成
- 阶段 1：已完成
- 阶段 2：进行中
- 阶段 3：进行中
- 阶段 4：未开始
- 阶段 5：未开始
- 阶段 6：未开始

### 4.2 阶段完成定义

- `未开始`：没有明确任务切片，或未开始执行
- `进行中`：至少有一条子任务开始落代码，但总完成标准未满足
- `已完成`：该阶段当前定义的剩余任务全部关闭，并已回填文档
- `已阻塞`：存在明确阻塞项，且本轮无法继续推进

### 4.3 回填规则

- 每个阶段必须写：
  - 目标
  - 范围
  - 已完成项
  - 当前剩余项
  - 完成标准
- 如果阶段状态是 `进行中`，必须有“当前剩余项”
- 如果阶段状态是 `已完成`，必须有“完成日期”

---

## 5. 阶段 0：总基线

状态：`已完成`  
完成日期：`2026-04-28`

目标：

- 建立本总计划文档作为唯一总编排文档
- 把专题文档与总计划绑定

已完成：

- [x] 建立总计划文档
- [x] 明确专题文档入口
- [x] 给关键专题文档补总计划状态
- [x] 明确后续文档维护规则
- [x] 明确统一化完成定义

完成标准：

- 后续不再新增平行总计划文档
- 所有专题都能在本文件里找到入口和当前归属

---

## 6. 阶段 1：依赖入口和单例治理

状态：`已完成`  
完成日期：`2026-04-28`

目标：

- 把 `instance / legacy / SharedPreferences.getInstance()` 收到可控边界

范围：

- `app`
- `reader` local reading 主链
- 部分 app-level notifier / persistence 入口

已完成：

- [x] 建立 app 级偏好 persistence service
- [x] 主题、导航、字体、壳层导航改为统一走 provider/service
- [x] local reading 主链去掉默认 `AppDatabase.instance` 兜底
- [x] 清理 `LocalBookDetailService.legacy()`
- [x] 明确基础设施单例与业务默认入口的分类口径

阶段结果：

- 新增：`lib/app/preferences/app_preferences_service.dart`
- app 级 notifier 已统一走 persistence service
- local reading 主链默认绑库入口已清理
- runtime/source 单例问题已明确归到阶段 5，不再挂在阶段 1 下

完成标准：

- 页面和主业务链不再依赖 `instance / legacy` 作为默认入口
- 持久化入口具备统一 provider 或 persistence service

---

## 7. 阶段 2：超大页面和 Glue Code 下沉

状态：`进行中`

目标：

- 把页面里仍然过重的 route glue、展示态 glue、交互编排 glue、壳层副作用 glue 继续下沉

阶段总完成标准：

- 主要大页面不再承担完整业务流
- 页面层主要只负责渲染、订阅状态、分发交互
- 各 feature 能形成稳定的 `presentation / application / providers / routes`

### 7.1 Reader

关联专题：

- `docs/reader_page_execution_checklist.md`

已完成：

- [x] `Source Switch Flow` 大块方法级拆分已完成
- [x] `Bootstrap / Restore / Snapshot` 方法级拆分已完成
- [x] `Runtime / Session Glue` 方法级拆分已完成
- [x] `Navigation / Catalog Glue` 方法级拆分已完成
- [x] `Shell / System UI / Input Glue` 未勾项已清完
- [x] 新增 `ReaderFeedbackService`
- [x] 新增 `ReaderThemeModeService`
- [x] 昼夜切换、提示、错误记录、缺源换源提示已迁到 shell part + application service
- [x] 生命周期与依赖绑定已压薄到独立 lifecycle part
- [x] 顶层 build / reader viewport 分支已迁到独立 viewport part
- [x] 背景资源状态已迁到独立 background part
- [x] settings sheet 展示与交互 glue 已迁到独立 settings-sheet part
- [x] 阅读内容 render helper 已迁到独立 content-rendering part
- [x] `reader_page.dart` 已压到约 `5k` 行，并通过本轮 analyze / test

当前剩余项：

- 无，`7.1 Reader` 本轮已完成关闭，后续如再出现 Reader 结构任务，另行回挂到本节

本轮关闭条件：

- `docs/reader_page_execution_checklist.md` 第 8 节剩余项全部打勾
- `reader_page.dart` 接近“页面壳 + 顶层 build + callback bind”

### 7.2 Bookshelf

已完成：

- [x] 新增 `BookshelfPageRouteService`
- [x] 最近阅读 / 进度阅读 / fallback / 详情路由决策已从页面移出
- [x] 搜索与筛选 glue 已迁到独立 flow part
- [x] 选中态与批量操作 glue 已迁到独立 selection part
- [x] 外部导入与本地导入交互 glue 已迁到独立 flow part
- [x] 新增 `BookshelfFlowCoordinator`

当前剩余项：

- 无，`7.2 Bookshelf` 本轮已完成；后续若继续压薄设置面板或卡片渲染，再单独回挂

### 7.3 Book Detail

已完成：

- [x] 新增 `BookDetailReadRouteService`
- [x] 可读章节过滤、最新章节解析、从详情页进入阅读的 route 构造已下沉
- [x] 本地内容 provider 装配残留继续清理了一轮
- [x] 新增 `BookDetailActionService`
- [x] 新增 `BookDetailCatalogService`
- [x] 新增 `BookDetailMetadataFlowService`
- [x] metadata flow 已迁到独立 metadata part + application service
- [x] action flow 已迁到独立 actions part + application service
- [x] toc / reading sync glue 已迁到独立 catalog part + application service
- [x] `book_detail_page.dart` 已压到约 `2.3k` 行，并通过本轮 analyze / test

当前剩余项：

- 无，`7.3 Book Detail` 本轮已完成；后续若继续下沉卡片细粒度 render helper，再单独回挂

### 7.4 Reading Records / Bookmarks / Home

已完成：

- [x] `BookmarksPage` 分组与展示态兜底下沉到 `BookmarksQueryService`
- [x] `ReadingRecordsPage` 新增 dependencies / open-route / presentation service
- [x] `ReadingRecordsPage` 不再直接订阅 `AppDatabase.instance.watchBookMetadataOverrides()`
- [x] `HomePage` 继续阅读卡片改为消费统一展示态标题/作者

当前剩余项：

- [ ] 继续减少 `ReadingRecordsPage` 页面内的 query/view assembly
- [ ] 把剩余 stats 相关 glue 继续往 service / presenter 下沉

### 7.5 Mine Appearance / Advanced Theme

当前剩余项：

- [ ] 拆 `advanced_theme_editor_page.dart`
- [ ] 拆 `appearance_page.dart`
- [ ] 拆 `mine_page.dart`
- [ ] 让资源编辑和导入编排进入 application

### 7.6 Source

当前剩余项：

- [ ] 拆 `source_page.dart`
- [ ] 拆 `script_source_debug_page.dart`
- [ ] 调试运行、批量检测、登录状态处理继续 service / coordinator 化

---

## 8. 阶段 3：共享业务语义统一

状态：`进行中`

目标：

- 解决“不同 feature 看起来在用同一个业务对象，实际上语义并不统一”的问题

阶段总完成标准：

- 关键 feature 只消费统一身份语义和统一展示态语义
- 快照字段、事实字段、资源绑定字段的边界清楚

### 8.1 书籍身份语义

关联专题：

- `docs/book_identity_semantics_execution_plan.md`

已完成：

- [x] 已建立 `BookIdentity / SourceBookKey`
- [x] 已替换关键入口的 identity 构造

当前剩余项：

- [ ] 完成剩余场景回查
- [ ] 补充新口径使用约束

### 8.2 书籍展示态语义

已完成：

- [x] 已新增 `BookDisplayState`
- [x] `BookMetadataPresentation` 已退化为兼容别名
- [x] `BookmarksQueryService` 已开始直接输出展示态就绪数据
- [x] `ReadingRecordsPresentationService` 已开始统一统计页展示态消费

当前剩余项：

- [ ] 继续替换仍直接依赖旧命名的调用点
- [ ] 明确展示态与事实字段的边界说明

### 8.3 快照语义

当前剩余项：

- [ ] 明确 `BookshelfBook / ReadingRecord / LocalBook / BookDetail` 的事实字段与快照字段
- [ ] 补充快照迁移和同步口径

### 8.4 资源绑定语义

当前剩余项：

- [ ] 明确主题绑定字段和事实资源字段边界
- [ ] 为阶段 4 的资源系统统一提供语义基线

---

## 9. 阶段 4：资源系统统一

状态：`未开始`

目标：

- 将高级主题、背景、图集、字体、自定义封面统一成“受管资源系统”

范围：

- 高级主题壁纸
- 应用背景 / 阅读背景
- 封面图集
- 启动图集
- 底栏图集
- 字体文件
- 自定义封面

当前已有基础：

- `lib/core/storage/managed_file_path_resolver.dart`
- `lib/app/startup/managed_asset_path_migration_service.dart`

剩余任务：

- [ ] 新建资源系统专题文档
- [ ] 定义 `ManagedAssetRef / ManagedAssetCollection / ManagedAssetType / ManagedAssetScope`
- [ ] 统一目录、命名、相对引用、迁移规则
- [ ] 让主题层只持有绑定关系，不直接管理文件路径
- [ ] 统一导入、删除、迁移、导出、预览、引用校验生命周期

完成标准：

- 资源不再各 feature 各存绝对路径
- 覆盖安装、目录迁移、导入导出有统一恢复能力

---

## 10. 阶段 5：Runtime / Bridge / 平台边界统一

状态：`未开始`

目标：

- 把 runtime 和 bridge 留在清晰边界内，避免再次回流到页面和普通业务 service

范围：

- source runtime
- 外部导入
- 登录桥
- 阅读器亮度与音量键桥
- webview 交互验证

剩余任务：

- [ ] 复查 `docs/cross_platform_boundary_refactor_plan.md` 当前完成度
- [ ] 明确哪些 bridge 保留单例，哪些 provider 化
- [ ] 明确 `runtime -> application -> presentation` 唯一路径
- [ ] 统一 source 调试、登录、导入、健康状态、调度入口
- [ ] reader 平台桥只保留能力适配，不再夹带页面决策

完成标准：

- 平台桥不再散落回业务页面
- runtime 调度和宿主桥职责稳定

---

## 11. 阶段 6：测试、验收与守卫自动化

状态：`未开始`

目标：

- 让统一化不依赖人工记忆，而是有自动化守卫

剩余任务：

- [ ] 建立关键阶段的 analyze/test 绿色集合
- [ ] 增加 dependency violation 检查脚本
- [ ] 增加超大文件预警
- [ ] 增加关键共享模型回归测试
- [ ] 建立文档回填检查口径

完成标准：

- 新增越界代码更容易被提前发现
- 结构回退能被脚本或测试尽早发现

---

## 12. 当前执行顺序

后续执行顺序固定为：

1. Reader 阶段 2 剩余项
2. Bookshelf / Book Detail 阶段 2 剩余项
3. Mine Appearance / Source 阶段 2
4. 阶段 3 剩余语义统一
5. 阶段 4 资源系统统一
6. 阶段 5 runtime / bridge
7. 阶段 6 测试与守卫

原因：

- 阶段 2 不收完，阶段 3、4 的统一模型会持续被页面层反向污染
- 阶段 3 不收完，阶段 4 的资源系统会继续语义混乱
- 阶段 5、6 更适合建立在前四阶段明确之后再统一处理

---

## 13. 统一化完成定义

只有同时满足下面条件，才能认定“项目整体统一化”完成：

- 主要页面不再承担完整业务流
- 主业务链不再依赖 `instance / legacy / AppDatabase.instance` 默认入口
- 身份、展示态、快照、资源绑定语义统一
- 资源系统具备统一引用与迁移能力
- runtime / bridge 边界稳定
- 有对应 analyze / test / smoke 守卫
- 代码与文档都已回填

---

## 14. 文档维护规则

- 本文件只负责总编排，不替代专题细任务文档
- 每次执行完成后，必须先回填专题文档，再回填本文件
- 如果某阶段还在 `进行中`，必须明确“当前剩余项”
- 若阶段边界变化，先改本文件，再继续执行代码
- 如与 `docs/development_architecture_guardrails.md` 冲突，以 guardrails 为准
