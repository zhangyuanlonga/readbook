# 项目架构统一化总计划

更新时间：2026-04-28  
用途：作为当前项目“整体收口”的总编排文档，统一功能版图、架构目标、阶段任务和专题文档分工。后续如果继续推进“整体统一化”，一律以本文件排期和回填。

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

## 0. 结论先行

当前项目已经不是“缺少 feature”阶段，而是“功能已成体系、结构仍分散”的阶段。

一句话判断：

- **功能闭环基本齐全**
- **专题收口已经开始**
- **但还缺一个跨专题的总任务编排**

当前最需要统一的，不是继续补单点功能，而是把下面六条主线接成一个总计划：

1. 依赖入口统一
2. 超大页面和 glue code 继续下沉
3. 共享业务语义统一
4. 资源系统统一
5. runtime / bridge 边界统一
6. 测试、验收、文档回填统一

---

## 1. 当前项目功能版图

### 1.1 应用级能力

- App shell、底部主导航、启动编排、主题和外观切换
- 全局字体、导航样式、启动图、公告和更新提示

### 1.2 内容获取与阅读闭环

- 书源管理、脚本源导入、脚本编辑、登录、调试
- 搜索、发现、详情、目录、正文
- 在线阅读与本地阅读共用主阅读链路

### 1.3 本地阅读能力

- 本地图书导入
- `txt / epub / md / html / pdf / mobi / azw / azw3`
- 本地索引、封面抽取、正文结构化、重建索引

### 1.4 阅读体验能力

- 分页 / 滚动 / 漫画相关阅读模式
- 阅读设置、字体、背景、亮度、翻页动画、自动阅读
- 章节缓存、书签、阅读记录、阅读统计、热力图

### 1.5 “我的”侧能力

- 高级主题
- 应用背景、阅读背景
- 启动图集、封面图集、底栏图集
- 字体管理、书签页、缓存管理、反馈、会员、系统设置

### 1.6 其他 feature

- 首页
- 公告
- 认证与个人资料
- 错误中心

结论：

- 这已经是一个完整阅读产品，而不是单纯的阅读器 demo。
- 因此后续结构治理必须按“产品平台化维护”来做，而不是继续按单页面救火。

---

## 2. 当前状态盘点

### 2.1 已经完成或已开始收口的部分

- 顶层路由已经基本按 feature 聚合
- `app / core / runtime / data / domain / features` 的目录主框架已成型
- 非阅读器模块已有一轮依赖图整改
- 阅读器已完成第一轮拆文件和依赖图 provider 化
- 封面展示态和优先级已经收口
- 本地阅读已经完成统一主路径的大部分工作
- 原生与 Flutter 职责边界已有专项文档

### 2.2 当前最大的结构热点

以 `2026-04-28` 仓库状态为基线，当前最重的文件包括：

- `lib/features/reader/presentation/reader_page.dart` 约 `12455` 行
- `lib/features/bookshelf/presentation/bookshelf_page.dart` 约 `5855` 行
- `lib/features/mine/presentation/advanced_theme_editor_page.dart` 约 `3897` 行
- `lib/features/book/presentation/book_detail_page.dart` 约 `3499` 行
- `lib/features/reader/presentation/reading_records_page.dart` 约 `2889` 行
- `lib/features/source/presentation/source_page.dart` 约 `2623` 行
- `lib/features/discover/presentation/discover_page.dart` 约 `2258` 行
- `lib/features/mine/presentation/mine_page.dart` 约 `2146` 行
- `lib/features/source/presentation/script_source_debug_page.dart` 约 `2111` 行
- `lib/features/mine/presentation/appearance_page.dart` 约 `2016` 行

对应的 application 热点包括：

- `lib/features/mine/application/advanced_theme_service.dart` 约 `2287` 行
- `lib/features/reader/application/local/epub_local_book_parser.dart` 约 `2147` 行
- `lib/features/reader/application/local/txt_local_book_parser.dart` 约 `1606` 行
- `lib/features/bookshelf/application/bookshelf_service.dart` 约 `1038` 行
- `lib/features/reader/application/reading_record_service.dart` 约 `941` 行
- `lib/features/reader/application/reader_preferences_service.dart` 约 `921` 行

### 2.3 相对 guardrails 的主要偏差

当前最主要的偏差不是“完全没分层”，而是以下四类残留：

1. 大量页面仍过重  
   页面同时承担 UI、状态、业务编排、资源选择、持久化回写和流程控制。

2. 依赖入口未完全统一  
   虽然 provider 已大量建立，但仍存在：
   - `AppDatabase.instance`
   - `SharedPreferences.getInstance()`
   - `xxx.instance`
   - `legacy()` factory

3. 共享语义未完全统一  
   书籍身份、展示态、资源引用、快照字段、主题资源绑定已经部分收口，但仍未形成一套完整的统一模型。

4. 资源系统仍按功能块各自维护  
   高级主题、封面图集、启动图集、底栏图集、背景、字体、自定义封面，本质都是“受管资源 + 引用关系”，但当前仍以多个平行实现存在。

---

## 3. 这次总计划要解决什么

本计划不是替代已有专题文档，而是做三件事：

1. 给已有专题文档排总顺序  
   哪些先做，哪些依赖哪些，哪些已经完成但仍有残尾。

2. 把还没有单独立文档的“跨专题能力”补出来  
   重点是资源系统统一、共享语义统一、验收自动化统一。

3. 避免再次出现“专题内部收口了，但专题之间仍不统一”的情况。

---

## 4. 目标架构口径

后续统一化以 `docs/development_architecture_guardrails.md` 为唯一强约束，并进一步落实为以下目标：

### 4.1 页面层

- 页面只负责渲染、交互分发、状态订阅
- 超大页面继续拆为：
  - page shell
  - controller / coordinator glue
  - feature widgets
  - application flow service

### 4.2 application 层

- 承担用例编排和跨依赖整合
- 不再保留默认数据库兜底和 `legacy` 创建链作为长期常态
- 跨页面流程必须进入 application，不再散落在页面 State

### 4.3 data / runtime / core 层

- `data` 只承接数据访问和 repository 实现
- `runtime` 只承接脚本源运行时与宿主桥
- `core` 只承接跨 feature 基础设施

### 4.4 共享模型

至少要完成以下统一：

- 书籍身份模型
- 书籍展示态模型
- 受管资源引用模型
- 快照字段模型
- 平台桥接入口模型

---

## 5. 分阶段执行计划

当前进度：

- 阶段 0：已完成
- 阶段 1：已完成
- 阶段 2：未开始
- 阶段 3：未开始
- 阶段 4：未开始
- 阶段 5：未开始
- 阶段 6：未开始

回填规则：

- 状态：`未开始 / 进行中 / 已完成 / 已阻塞`
- 完成日期：`YYYY-MM-DD`
- 备注：只记录关键决策、依赖和阻塞原因

---

## 阶段 0：建立总基线

目标：

- 把“已有专题文档”和“总计划”绑定起来
- 锁定当前统一化范围、顺序、验收口径

任务：

- [x] 确认本文件作为总体统一化唯一总编排文档
- [x] 将已存在专题文档标记为：
  - 已完成专题
  - 进行中专题
  - 仍需续做专题
- [x] 给各专题补统一状态字段和最后回填日期
- [x] 统一后续文档命名口径：业务专题继续保留，跨专题总排期只维护本文件
- [x] 补一份“统一化完成定义”

完成标准：

- 后续不再新增平行总计划文档
- 所有专题文档都能在本文件里找到入口和当前状态

完成日期：

- `2026-04-28`

---

## 阶段 1：依赖入口和单例治理

目标：

- 把当前剩余的 `instance / legacy / SharedPreferences.getInstance()` 收到可控边界

范围：

- `app`
- `core`
- `source`
- `reader`
- `mine`
- `search`
- `bookshelf`
- `book`

任务：

- [x] 盘点仍在业务层长期保留的 `static instance` 和 `legacy()` factory
- [x] 区分“允许保留的基础设施单例”和“必须迁出的业务单例”
- [x] 为主题、导航、字体、壳层导航等 app 级状态补稳定 provider / persistence service
- [x] 收口 app-level notifier / 页面状态里的 `SharedPreferences.getInstance()` 直接散落调用
- [x] 清理 local reading 主链中仍直接绑定 `AppDatabase.instance` 的默认兜底
- [x] 为 runtime 调度、source health、外部导入、debug service 明确阶段归属与 provider 边界口径

当前进展：

- 已新增 `lib/app/preferences/app_preferences_service.dart`
- 已将以下 app 级 notifier 改为统一走 persistence service：
  - `AppThemeModeNotifier`
  - `AppSeedColorNotifier`
  - `AppInterfaceFontSettingsNotifier`
  - `AppInterfaceTextScaleNotifier`
  - `AppInterfaceFontWeightNotifier`
  - `AppNavigationStylePreferenceNotifier`
  - `AppNavigationLabelVisibilityNotifier`
  - `AppStandardNavigationBarAppearanceNotifier`
  - `AppCupertinoDockAppearanceNotifier`
  - `AppShellNavigationNotifier`
- 已去除本地阅读主链中的默认绑库入口：
  - `LocalBookDetailService.legacy()`
  - `LocalContentProvider` 默认本地 service 兜底
  - `LocalBookIndexService` 默认 `LocalBookRepositoryImpl(AppDatabase.instance)`
  - `LocalChapterContentService` 默认 `LocalBookRepositoryImpl(AppDatabase.instance)`
  - `LocalBookPreviewService` 默认 `LocalBookRepositoryImpl(AppDatabase.instance)`
  - `LocalBookImportService` 默认本地索引 service 兜底
- 已补本地阅读主链 targeted test，验证显式注入后行为不变

单例分类口径：

- 允许暂时保留的基础设施单例：
  - `AppLogger.instance`
  - `SourceHealthService.instance`
  - `SourceRuntimeSchedulerService.instance`
  - `SourceRuntimeTaskConflictService.instance`
  - `SourceRuntimeWarmStateService.instance`
  - `ReaderErrorCenterService.instance`
  - `CoverImageDiskCache.instance`
- 必须迁出的业务默认入口：
  - `SourceRuntimeFacade.instance`
  - `legacy()` factory
  - 页面 / notifier 直接 `SharedPreferences.getInstance()`
  - 业务 service 默认 `AppDatabase.instance`

阶段归属调整：

- `SourceRuntimeFacade.instance` 和 source/runtime 相关单例，不再归阶段 1 清理。
- 它们统一收口到阶段 5：`runtime / bridge / 平台边界统一`。

重点文件：

- `lib/app/theme/*.dart`
- `lib/app/navigation/*.dart`
- `lib/features/source/application/*.dart`
- `lib/features/reader/application/*.dart`
- `lib/features/mine/presentation/mine_page.dart`

完成标准：

- 页面和业务主链不再依赖 `instance / legacy` 作为默认入口
- 持久化入口具备统一 provider 或 persistence service

完成日期：

- `2026-04-28`

---

## 阶段 2：超大页面和 glue code 继续下沉

目标：

- 把“功能已完成但页面过重”的模块继续拆到 guardrails 允许的层次

优先级：

- `P0`：`reader`
- `P0`：`bookshelf`
- `P1`：`mine appearance / advanced theme`
- `P1`：`book detail`
- `P1`：`source`
- `P2`：`discover / search / home / stats`

任务：`reader`

- [ ] 继续推进 `docs/reader_page_execution_checklist.md`
- [ ] 把 `reader_page.dart` 收到“页面壳 + 顶层 build + 回调分发”
- [ ] 将 runtime glue、source switch glue、overlay glue 继续 application 化

任务：`bookshelf`

- [ ] 拆 `bookshelf_page.dart` 的搜索、筛选、选中态、打开阅读、外部导入、批量操作 glue
- [ ] 建立 `bookshelf flow coordinator` 或等价入口

任务：`mine / appearance`

- [ ] 拆 `advanced_theme_editor_page.dart`
- [ ] 拆 `appearance_page.dart`
- [ ] 拆 `mine_page.dart`
- [ ] 让 appearance 模块只保留页面交互，资源编辑和导入编排进入 application

任务：`book`

- [ ] 继续下沉 `book_detail_page.dart` 中非展示类流程
- [ ] 统一详情页的 action flow、metadata flow、toc/reading sync flow

任务：`source`

- [ ] 拆 `source_page.dart`
- [ ] 拆 `script_source_debug_page.dart`
- [ ] 把调试运行、批量检测、登录状态处理收口到 service / coordinator

完成标准：

- 主要大页面不再承担完整业务流
- 页面行数和职责明显下降
- 可按 feature 形成稳定的 `presentation / application / providers / routes`

---

## 阶段 3：共享业务语义统一

目标：

- 解决“看起来都是一个业务对象，实际上各 feature 各存一套口径”的问题

优先统一的语义：

1. 书籍身份
2. 书籍展示态
3. 快照语义
4. 规则作用域
5. 受管资源引用

任务：

- [ ] 续做 `docs/book_identity_semantics_execution_plan.md`
- [ ] 复查 `BookMetadataPresentation` 的边界，明确它是否升级为更通用的 `BookDisplayState`
- [ ] 明确 `BookshelfBook / ReadingRecord / LocalBook / BookDetail` 各自的事实字段与快照字段
- [ ] 统一“资源绑定字段”与“事实资源字段”的语义边界
- [ ] 为规则、封面、主题、快照相关共享模型补跨 feature 使用约束

重点收益：

- 页面不再自己拼业务语义
- 后续资源系统和主题系统统一时，不会再次回到“字段名相似但语义不同”

完成标准：

- 共享模型文档齐备
- 关键 feature 只消费统一展示态和统一身份语义

---

## 阶段 4：资源系统统一

目标：

- 将高级主题、背景、图集、字体、自定义封面等能力统一成“受管资源系统”

当前判断：

- 这是本轮最缺失的跨专题能力，也是近期故障最集中的区域。

统一范围：

- 高级主题壁纸
- 阅读背景 / 应用背景
- 封面图集
- 启动图集
- 底栏图集
- 字体文件
- 自定义封面

任务：

- [ ] 新建资源系统专题文档，作为本阶段唯一执行文档
- [ ] 明确统一模型：
  - `ManagedAssetRef`
  - `ManagedAssetCollection`
  - `ManagedAssetType`
  - `ManagedAssetScope`
- [ ] 统一资源目录、命名、相对引用和迁移规则
- [ ] 让主题层只保存绑定关系，不直接承担文件路径管理
- [ ] 收口导入、删除、迁移、导出、预览、引用校验生命周期
- [ ] 将当前路径自愈逻辑从兼容补丁升级为长期资源引用体系

相关现有产物：

- `lib/core/storage/managed_file_path_resolver.dart`
- `lib/app/startup/managed_asset_path_migration_service.dart`

完成标准：

- 资源不再各 feature 各存绝对路径
- 主题系统只消费资源引用，不直接管理物理路径
- 覆盖安装、目录迁移、导入导出具备统一恢复能力

---

## 阶段 5：runtime / bridge / 平台边界统一

目标：

- 把运行时和平台桥接留在清晰边界内，避免再次回流到页面和普通业务 service

范围：

- source runtime
- 外部导入
- 登录桥
- 阅读器亮度和音量键桥
- webview 交互验证

任务：

- [ ] 复查 `docs/cross_platform_boundary_refactor_plan.md` 当前完成度
- [ ] 明确哪些 bridge 应保留单例，哪些应 provider 化
- [ ] 明确 `runtime -> application -> presentation` 的唯一调用路径
- [ ] source 调试、登录、导入、健康状态、调度能力统一入口
- [ ] reader 平台桥只保留能力适配，不再夹带页面决策

完成标准：

- 平台桥不再散落进入业务页面
- runtime 调度和宿主桥职责稳定

---

## 阶段 6：测试、验收与守卫自动化

目标：

- 让统一化不是“人工记忆”，而是有自动化守卫

任务：

- [ ] 为关键专题建立最小 analyze/test 绿色集合
- [ ] 补 dependency violation 检查脚本：
  - `presentation -> AppDatabase`
  - `presentation -> MethodChannel`
  - `presentation -> RepositoryImpl`
- [ ] 建立超大文件预警阈值
- [ ] 建立关键共享模型回归测试
- [ ] 将文档回填纳入每轮结构改造验收

建议守卫：

- 关键 feature smoke test
- 路由 smoke test
- provider wiring smoke test
- 资源迁移回归测试
- 书籍展示态回归测试

完成标准：

- 结构性回退能被脚本或测试尽早发现
- 新增代码更难再次越过 guardrails

---

## 6. 推荐执行顺序

为了避免多条线同时动导致回归面过大，建议顺序固定为：

1. 阶段 0：总基线
2. 阶段 1：依赖入口和单例治理
3. 阶段 2：页面和 glue code 下沉
4. 阶段 3：共享业务语义统一
5. 阶段 4：资源系统统一
6. 阶段 5：runtime / bridge 边界统一
7. 阶段 6：测试与守卫自动化

原因：

- 如果不先统一依赖入口，后续拆页面会继续复制旧注入方式。
- 如果不先拆页面，语义模型和资源系统会不断被页面层反向污染。
- 如果不先统一共享语义，资源系统会继续出现“字段多、口径乱、引用不一致”。

---

## 7. 当前建议优先级

如果只看未来两到三轮开发，建议优先做：

### P0

- 阶段 1：依赖入口和单例治理
- 阶段 2：`reader / bookshelf / mine appearance` 超大页面下沉
- 阶段 4：资源系统统一立项

### P1

- 阶段 3：共享业务语义统一
- 阶段 5：runtime / bridge 边界统一

### P2

- 阶段 6：守卫自动化补全

---

## 8. 完成定义

满足以下条件，才算本轮“整体统一化”完成：

- 页面层不再直接承担重业务编排
- 主要业务链不再依赖 `instance / legacy / AppDatabase.instance` 作为默认入口
- 共享业务语义和资源引用语义有统一模型
- 资源系统具备统一导入、持久化、迁移、绑定和删除口径
- runtime / bridge 边界稳定
- 对应 analyze / test / smoke 守卫已建立
- 相关专题文档和本文件都已回填

---

## 9. 文档维护规则

- 本文件只负责“总编排”和“阶段顺序”。
- 具体专题的细任务仍维护在各自执行文档中。
- 如果某个阶段新增了新的跨专题能力，先补到本文件，再决定是否拆专题文档。
- 若与 `docs/development_architecture_guardrails.md` 冲突，以 guardrails 为准。
