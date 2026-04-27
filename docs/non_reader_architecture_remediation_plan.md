# 非阅读器功能架构整改文档

更新时间：2026-04-27  
用途：基于 `docs/development_architecture_guardrails.md`，对阅读器之外的页面和功能进行当前状态盘点，并输出可执行的整改方案与统一封装方向。

## 0. 结论先行

阅读器之外的模块，当前主要问题不是“没有分层”，而是**分层入口已经存在，但依赖图仍大量散落在页面和默认构造器里**。

共性表现：

- 页面直接 `new Service()`、`new Store()`、使用 `xxx.instance`
- application 默认构造器里直接绑定 `AppDatabase.instance` 或 `RepositoryImpl`
- feature 已有 `providers.dart`，但覆盖面不完整，页面仍在自行组装依赖
- 多个 feature 已出现重复查询逻辑，适合提炼为统一 query service
- `App` 根 widget 仍承担启动编排，而不只是壳层

一句话总结：

- **先统一依赖入口**
- **再清页面组装职责**
- **最后合并重复查询能力**

---

## 1. 本轮范围

纳入本轮：

- `app`
- `bookshelf`
- `book`
- `mine`
- `search`
- `discover`
- `source`
- `auth`
- `announcement`

不纳入本轮：

- `reader`

---

## 2. 盘点口径

本文件关注以下问题：

- 页面是否直接构造 service / store / facade
- 页面是否直接依赖 runtime 单例或事件总线
- application 是否通过默认构造器偷偷绑定 `AppDatabase.instance`
- feature 是否已具备稳定的 `providers.dart`
- 是否存在跨 feature 的重复逻辑，适合统一封装

优先级定义：

- `P1`：违反 guardrails 主约束，优先整改
- `P2`：当前可运行，但维护成本高，建议近期收口
- `P3`：结构可优化项，排在后续

---

## 3. 当前状态总览

### 3.1 已相对符合的部分

- `lib/app/router.dart` 已基本收敛为 feature route 聚合器
- `lib/features/source/providers.dart`、`lib/features/book/providers.dart`、`lib/features/bookshelf/providers.dart`、`lib/features/mine/providers.dart`、`lib/features/search/providers.dart`、`lib/features/discover/providers.dart` 已存在 provider 落点
- `source` 主页面已开始使用 provider 读取部分依赖，方向正确

### 3.2 当前主要问题

- `App` 根部仍自行 new coordinator 并直接编排启动流程
- `bookshelf`、`book`、`mine`、`search`、`auth`、`announcement` 等页面仍在 `State` 中直接组装依赖
- `search`、`discover`、`bookshelf` 存在重复的书籍展示态查询逻辑
- 多个 application service 仍保留“默认构造器自动绑数据库/仓库实现”的旧模式
- `source` feature 只有主页面部分 provider 化，子页面未统一

---

## 4. 阶段任务清单

当前进度：

- 阶段 0：已完成，完成日期 `2026-04-27`
- 阶段 1：已完成，完成日期 `2026-04-27`
- 阶段 2：已完成，完成日期 `2026-04-27`
- 阶段 3：已完成，完成日期 `2026-04-27`
- 阶段 4：已完成，完成日期 `2026-04-27`
- 阶段 5：未开始
- 阶段 6：未开始

回填规则：

- 状态：`未开始 / 进行中 / 已完成 / 已阻塞`
- 完成日期：`YYYY-MM-DD`
- 备注：只写阻塞原因或关键决策

### 阶段 0：建立整改基线

目标：

- 先统一命名、范围和共享依赖入口，避免边改边散

任务：

- [x] 确认本文件作为非阅读器整改唯一跟踪文档
- [x] 新增或补齐 app-level composition 文件
- [x] 明确共享 provider 命名口径
- [x] 明确 feature-level `DependenciesProvider` / `ControllerProvider` 命名口径
- [x] 明确本轮测试与验收口径

建议产出：

- app-level composition provider 文件
- feature provider 命名约定
- 测试清单基线

---

### 阶段 1：统一共享依赖与 composition

目标：

- 收口共享数据库、仓库、runtime facade 的创建入口

任务：

- [x] 新增 `appDatabaseProvider`
- [x] 新增 `bookmarkRepositoryProvider`
- [x] 新增 `bookMetadataOverrideRepositoryProvider`
- [x] 新增 `localBookRepositoryProvider`
- [x] 新增 `scriptSourceRepositoryProvider`
- [x] 将 `book/providers.dart` 中重复的数据库/仓库创建改为复用 app-level provider
- [x] 将 `bookshelf/providers.dart` 中重复的数据库/仓库创建改为复用 app-level provider
- [x] 将 `mine/providers.dart` 中重复的数据库/仓库创建改为复用 app-level provider
- [x] 将 `SourceRuntimeFacade.instance` 的创建迁移到 provider/composition
- [x] 清理 feature 内直接暴露 `AppDatabase.instance` 的 provider

影响模块：

- `app`
- `book`
- `bookshelf`
- `mine`
- `source`

阶段完成标准：

- feature 不再各自包一层 `AppDatabase.instance`
- `SourceRuntimeFacade` 有唯一的 provider 创建入口

---

### 阶段 2：清理 P1 页面组装层

目标：

- 优先解决页面直接 `new Service()`、直接读单例、直接监听事件总线的问题

任务：`app`

- [x] 为 `AppLifecycleCoordinator` 建立 app-level provider factory
- [x] 为 `AppStartupCoordinator` 建立 app-level provider factory
- [x] 为 `AppAnnouncementCoordinator` 建立 app-level provider factory
- [x] 将 `lib/app/app.dart` 中 coordinator 的直接构造迁出根 widget
- [x] 让 `App` 根 widget 只保留壳层和生命周期绑定

任务：`bookshelf`

- [x] 新增 `bookshelfPageDependenciesProvider`
- [x] 新增 `localBookImportServiceProvider`
- [x] 将 `bookshelf_page.dart` 中直接构造的 service 全部迁出页面
- [x] 将 `local_library_page.dart` 中直接构造的 `LocalBookImportService` 迁出页面

任务：`book`

- [x] 新增 `bookDetailDependenciesProvider`
- [x] 将 `book_detail_page.dart` 中直接构造的 service 全部迁出页面
- [x] 将切源辅助和本地元数据流程收口到 provider 或 application service

任务：`mine`

- [x] 新增 `mineAuthSessionProvider`
- [x] 新增 `mineUpdateServiceProvider`
- [x] 新增 `mineMobileFeatureServiceProvider`
- [x] 新增 `mineImageSelectionServiceProvider`
- [x] 新增 `minePageFlowCoordinatorProvider`
- [x] 将 `mine_page.dart` 中的 `AuthEventBus.instance` 监听迁出页面
- [x] 将 `mine_page.dart` 中直接构造的 service 全部迁出页面

任务：`search`

- [x] 新增 `searchServiceProvider`
- [x] 新增 `searchHistoryServiceProvider`
- [x] 新增 `searchSystemSettingsServiceProvider`
- [x] 评估后暂不新增 `searchPageControllerProvider`，当前先以 service provider 收口
- [x] 将 `search_page.dart` 中 `SourceRuntimeFacade.instance` 和 service 直接构造迁出页面

任务：`auth`

- [x] 新增 `lib/features/auth/providers.dart`
- [x] 新增 `authServiceProvider`
- [x] 新增 `authSessionStoreProvider`
- [x] 新增 `userProfileServiceProvider`
- [x] 将 `auth_page.dart` 中直接构造的 `AuthService` 迁出页面
- [x] 将 `user_profile_page.dart` 中直接构造的 store/service 迁出页面

任务：`announcement`

- [x] 新增 `lib/features/announcement/providers.dart`
- [x] 新增 `announcementServiceProvider`
- [x] 新增 `announcementReadStateServiceProvider`
- [x] 评估后暂不新增 `announcementListControllerProvider`，当前先以 service provider 收口
- [x] 将 `announcement_list_page.dart` 中直接构造的 service 迁出页面
- [x] 将 `announcement_detail_page.dart` 中直接构造的 service 迁出页面

阶段完成标准：

- 上述页面不再直接 `new Service()`、`new Store()`、`xxx.instance`
- `App` 根 widget 不再直接承担启动业务编排

---

### 阶段 3：清理 application 默认兜底依赖

目标：

- 去掉 application 默认构造器里对 `AppDatabase.instance` 和 `RepositoryImpl` 的隐藏绑定

任务：`bookshelf`

- [x] 将 `LocalBookImportService` 改为显式注入式
- [x] 将 `BookshelfPresentationQueryService` 改为显式注入式

任务：`book`

- [x] 将 `LocalBookDetailService` 改为显式注入式
- [x] 为兼容旧调用点保留 `legacy` factory，后续阶段继续清理剩余调用

任务：`search`

- [x] 将 `SearchBookPresentationService` 改为显式注入式

任务：`discover`

- [x] 将 `DiscoverBookPresentationService` 改为显式注入式

任务：`source`

- [x] 清理 `SourceRuntimeFacade` 中直接绑定 `ScriptSourceRepositoryImpl(AppDatabase.instance)` 的默认入口
- [x] 统一 `SourceLoginRuntimeService` 的 provider 注入方式
- [x] 为兼容旧调用点保留 `legacy` factory，后续阶段继续清理子页面默认构造

阶段完成标准：

- application 层默认构造器不再偷偷绑定数据库或仓库实现
- 页面和 application 只依赖显式注入的 provider/service

---

### 阶段 4：统一 source 子页面和 mine 子页面风格

目标：

- 让已经半收口的 feature 完成统一 provider 化，避免主页面和子页面口径不一致

任务：`source`

- [x] 将 `script_source_editor_page.dart` 中直接构造的 `AuthSessionStore`、`MobileFeatureService` 迁出页面
- [x] 将 `script_source_paste_import_page.dart` 中直接构造的 `AuthSessionStore`、`MobileFeatureService` 迁出页面
- [x] 将 `source_login_page.dart` 默认 `SourceLoginRuntimeService()` 改为 provider 注入
- [x] 统一 `source` 全部页面只通过 `source/providers.dart` 取依赖
- [x] 新增 `sourceLoginBrowserServiceProvider`，补齐登录页默认依赖入口

任务：`mine`

- [x] 将 `appearance_page.dart` 直连的图片选择能力迁出页面
- [x] 将 `reader_background_page.dart` 直连的 service 迁出页面
- [x] 将 `advanced_theme_editor_page.dart` 直连的 service 迁出页面
- [x] 将 `membership_center_page.dart` 直连的 store/service 迁出页面
- [x] 新增 `readerBackgroundServiceProvider`，统一阅读背景能力入口

阶段完成标准：

- `source` 与 `mine` 的子页面依赖获取方式统一
- 不再存在“主页面 provider 化、子页面继续手动 new”的混合风格

---

### 阶段 5：合并重复查询能力

目标：

- 清理 `search / discover / bookshelf` 的重复展示查询逻辑

任务：

- [ ] 新建共享 `BookPresentationQueryService`
- [ ] 收口 remote/local target key 规则
- [ ] 收口 metadata override 查询逻辑
- [ ] 收口标题、作者、简介、封面展示态解析逻辑
- [ ] 将 `SearchBookPresentationService` 迁移到共享 query service
- [ ] 将 `DiscoverBookPresentationService` 迁移到共享 query service
- [ ] 将 `BookshelfPresentationQueryService` 中重复的 metadata 展示逻辑迁移到共享 query service

阶段完成标准：

- `search`、`discover`、`bookshelf` 不再各自维护一套展示态查询

---

### 阶段 6：补测试与验收

目标：

- 为新边界建立回归保护，避免后续再次倒灌

任务：

- [ ] 为 app-level composition provider 补 smoke test
- [ ] 为 `auth/providers.dart` 补 provider smoke test
- [ ] 为 `announcement/providers.dart` 补 provider smoke test
- [ ] 为 `bookshelfPageDependenciesProvider` 补 provider smoke test
- [ ] 为 `bookDetailDependenciesProvider` 补 provider smoke test
- [ ] 为 `search` 新增 provider/controller 补 smoke test
- [ ] 为 `BookPresentationQueryService` 补 application service test
- [ ] 为 `LocalBookImportService`、`LocalBookDetailService` 的注入式重构补测试
- [ ] 为 `AuthPage`、`AnnouncementListPage`、`UserProfilePage` 补 widget smoke test
- [ ] 跑一次目标范围 `flutter analyze`
- [ ] 跑一次目标范围 `flutter test`

阶段完成标准：

- 新增 provider、service、页面有对应测试覆盖
- 本轮整改范围的 analyze / test 结果可复现

---

## 5. 模块映射表

### 5.1 `app`

功能：

- 应用根 widget
- 启动时序
- 生命周期
- 启动公告
- 更新弹窗
- 外部导入监听接线

重点任务归属：

- 阶段 1
- 阶段 2

### 5.2 `bookshelf`

功能：

- 书架列表
- 搜索和筛选
- 本地图书导入
- 封面与元数据展示
- 阅读记录与缓存章节展示

重点任务归属：

- 阶段 1
- 阶段 2
- 阶段 3
- 阶段 5

### 5.3 `book`

功能：

- 书籍详情展示
- 元数据编辑
- 本地图书章节索引状态管理
- 切换来源辅助

重点任务归属：

- 阶段 1
- 阶段 2
- 阶段 3

### 5.4 `mine`

功能：

- 我的首页
- 会员信息
- 更新检查
- 头像与图片选择
- 外观与主题编辑
- 阅读背景管理

重点任务归属：

- 阶段 1
- 阶段 2
- 阶段 4

### 5.5 `search`

功能：

- 搜索输入
- 搜索执行
- 来源筛选
- 搜索历史
- 结果展示

重点任务归属：

- 阶段 2
- 阶段 3
- 阶段 5

### 5.6 `discover`

功能：

- 发现页探索
- 来源与分类选择
- 列表渲染

重点任务归属：

- 阶段 3
- 阶段 5

### 5.7 `source`

功能：

- 书源列表管理
- 书源脚本编辑
- 粘贴导入
- 登录页
- 书源运行时访问

重点任务归属：

- 阶段 1
- 阶段 3
- 阶段 4

### 5.8 `auth`

功能：

- 登录与注册
- 用户信息
- 退出登录

重点任务归属：

- 阶段 2
- 阶段 6

### 5.9 `announcement`

功能：

- 公告列表
- 公告分页
- 公告详情
- 已读状态

重点任务归属：

- 阶段 2
- 阶段 6

---

## 6. 最终验收标准

完成本轮整改后，应满足：

- 页面不再直接 `new Service()`、`new RepositoryImpl()`、`new Store()`
- 页面不再直接依赖 `AppDatabase.instance`
- 页面不再直接读取 `SourceRuntimeFacade.instance`
- `auth`、`announcement` 具备自己的 `providers.dart`
- `search`、`discover`、`bookshelf` 的书籍展示态查询能力完成统一收口
- `App` 根 widget 不再直接承担启动业务编排
- 本轮整改范围有对应 provider / application / widget 级测试保护

---

## 7. 文档联动

相关文档：

- `docs/development_architecture_guardrails.md`
- `docs/engineering_guide.md`

若后续整改过程中实际目录、provider 命名或阶段顺序发生变化，应优先更新本文件，再进行代码迁移，避免文档与实现再次脱节。
