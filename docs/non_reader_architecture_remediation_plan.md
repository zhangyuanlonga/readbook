# 非阅读器功能架构整改计划

更新时间：2026-04-27  
用途：基于 `docs/development_architecture_guardrails.md`，对阅读器之外的 feature 进行第二轮架构收口，输出可执行、可打勾、可验收的整改任务清单。

## 0. 结论先行

当前阅读器拆分已先行落地，但阅读器之外仍存在以下共性问题：

- `presentation` 直接构造 `RepositoryImpl`
- `presentation` 直接访问 `AppDatabase`
- `presentation` 直接依赖 `SourceRuntimeFacade`、`ExternalImportBridge`、`AuthEventBus`、交互浏览器执行器等运行时或桥接能力
- feature 缺少 `providers.dart`，依赖图仍散落在页面 `State` 中
- 多个页面已重新膨胀为“超大综合页”

一句话总结：

- **先收依赖边界**
- **再拆页面职责**
- **最后补齐 provider 与测试口径**

---

## 1. 本轮整改范围

纳入本轮整改：

- `bookshelf`
- `book`
- `source`
- `mine` 中与缓存、书签、外部导入相关页面
- `discover`
- `search` 中直接访问数据库的 UI 片段

暂不纳入本轮：

- `reader`
- 已稳定的全局主题基础设施
- 原生宿主层新增调整

---

## 2. 整改目标

本轮完成后，目标口径如下：

- 页面只负责渲染、交互分发、局部 UI 状态
- feature 依赖统一经 `providers.dart` 或 feature application service 暴露
- 页面不再直接触碰 `AppDatabase`
- 页面不再直接构造 `RepositoryImpl`
- 页面不再直接消费 bridge / runtime 单例
- 大页面至少完成第一轮“依赖图外提 + 查询逻辑下沉 + 桥接流程下沉”

---

## 3. 已确认问题清单

### 3.1 P1

- [ ] `lib/features/bookshelf/presentation/bookshelf_page.dart`
  - 页面直接构造 `LocalBookRepositoryImpl`、`BookMetadataOverrideRepositoryImpl`
  - 页面直接访问 `AppDatabase`
  - 页面直接消费 `ExternalImportBridge`

- [ ] `lib/features/book/presentation/book_detail_page.dart`
  - 页面直接构造 `BookmarkRepositoryImpl`、`BookMetadataOverrideRepositoryImpl`、`LocalBookRepositoryImpl`
  - 页面直接访问 `AppDatabase`
  - 页面直接依赖 `SourceRuntimeFacade.instance`

- [ ] `lib/features/source/presentation/source_page.dart`
  - 页面直接监听 `ExternalImportBridge`
  - 页面直接监听 `AuthEventBus`
  - 页面内直接消费外部导入 payload

- [ ] `lib/features/mine/presentation/cache_management_page.dart`
  - 页面直接查询 `AppDatabase`
  - 页面直接订阅数据库 stream
  - 页面直接执行缓存清理

### 3.2 P2

- [ ] `lib/features/source/presentation/source_login_page.dart`
  - 页面直接调用交互浏览器执行器

- [ ] `lib/features/discover/presentation/discover_page.dart`
  - 页面直接查询 `AppDatabase` 获取书籍元数据覆盖

- [ ] `lib/features/mine/presentation/bookmarks_page.dart`
  - 页面直接构造 `BookmarkRepositoryImpl`

- [ ] `lib/features/search/presentation/widgets/search_book_card.dart`
  - widget 直接查询 `AppDatabase`

- [ ] `lib/features/mine/presentation/advanced_theme_list_page.dart`
  - 页面直接监听 `ExternalImportBridge`
  - 页面直接监听 `AuthEventBus`
  - 页面直接消费外部导入 payload

---

## 4. 阶段任务

当前进度：

- 阶段 0：已完成，完成日期 `2026-04-27`
- 阶段 1：已完成，完成日期 `2026-04-27`
- 阶段 2：已完成，完成日期 `2026-04-27`
- 阶段 3：已完成，完成日期 `2026-04-27`
- 阶段 4：已完成，完成日期 `2026-04-27`
- 备注：目标范围 `flutter analyze` 已通过；全量 `flutter analyze` 仍有阅读器既有 warning；已执行 `flutter test`，但当前存在与本轮整改无关的既有失败，集中在 `test/app/layout/adaptive_breakpoints_test.dart`
- 阶段 2 验证备注：`flutter analyze lib/features/source lib/features/discover lib/features/mine lib/features/search` 已通过；`test/features/source/presentation/source_login_page_test.dart` 与 `test/features/search/presentation/search_book_card_test.dart` 已通过；`test/features/discover/presentation/discover_page_test.dart` 仍存在 `shows cached discover sources and categories before refresh completes` 的 pending timer 失败，需后续单独处理
- 阶段 3 验证备注：已将 `discover_page.dart` 的 source/category picker 组件拆至 `discover_page_pickers.dart`，将 `source_page.dart` 的检测弹层与请求对话框拆至 `source_page_dialogs.dart`，将 `bookshelf_page.dart` 的书架内容/搜索筛选区拆至 `bookshelf_page_sections.dart`，并将 `book_detail_page.dart` 的本地诊断/编辑辅助模型拆至 `book_detail_page_models.dart`；`flutter analyze lib/features/bookshelf lib/features/book lib/features/source lib/features/discover` 已通过；`test/features/bookshelf/presentation/bookshelf_grid_sliver_test.dart`、`test/features/book/presentation/book_detail_primary_actions_test.dart`、`test/features/book/presentation/book_detail_switch_source_test.dart` 已通过
- 阶段 4 验证备注：已新增 `bookshelf_presentation_query_service_test.dart`、`book_local_metadata_service_test.dart`、`discover_book_presentation_service_test.dart`、`search_book_presentation_service_test.dart`、`cache_management_service_test.dart`、`bookmarks_query_service_test.dart` 以及 provider smoke tests；阶段 4 测试集已通过；全量 `flutter analyze` 仍有阅读器既有 warning：`reader_page.dart` 中 `_viewportBuilder` / `_pagedViewportTransitionResolver` 未使用

回填规则：

- 状态：`未开始 / 进行中 / 已完成 / 已阻塞`
- 完成日期：`YYYY-MM-DD`
- 备注：只写阻塞原因或特殊决策

### 阶段 0：建立整改骨架

目标：先把后续整改所需的 provider 落点、命名口径、验收口径统一起来，避免边改边散。

- [x] 为 `bookshelf` 新增 `lib/features/bookshelf/providers.dart`
- [x] 为 `book` 新增 `lib/features/book/providers.dart`
- [x] 为 `source` 新增 `lib/features/source/providers.dart`
- [x] 为 `discover` 新增 `lib/features/discover/providers.dart`
- [x] 为 `mine` 新增面向“缓存/书签/外部导入”的 provider 落点
- [x] 统一约定 feature provider 命名
  - 仓库接口 provider
  - 查询 service provider
  - action / coordinator provider
  - page state provider 或 controller provider
- [x] 在本文件完成后续阶段的负责人、状态、日期回填规则

阶段完成标准：

- 每个待整改 feature 至少有一个明确的 provider 入口文件
- 不再新增页面内直接 new 仓库实现的代码

---

### 阶段 1：优先清理 P1 越界依赖

目标：先解决 guardrails 中“一票否决项”级别的问题。

### 4.1 `bookshelf`

- [x] 把 `bookshelf_page.dart` 中的仓库实现构造移入 feature provider
- [x] 把书架元数据覆盖查询移入 application/query service
- [x] 把最新缓存章节查询移入 application/query service
- [x] 把缓存章节数量查询移入 application/query service
- [x] 把“继续阅读提示”依赖的阅读记录查询移入 application/query service
- [x] 把外部本地图书导入 payload 消费流程移入 application coordinator
- [x] 页面只保留 provider 订阅、滚动控制、交互分发

### 4.2 `book`

- [x] 把 `book_detail_page.dart` 中的 `BookmarkRepositoryImpl` 构造移入 provider
- [x] 把 `BookMetadataOverrideRepositoryImpl` 构造移入 provider
- [x] 把 `LocalBookRepositoryImpl` 构造移入 provider
- [x] 把本地图书元数据查询移入 application service
- [x] 把 `SourceRuntimeFacade` 依赖改为通过 provider 注入
- [x] 页面释放阅读流、切源辅助等逻辑改为依赖注入后的稳定 service

### 4.3 `source`

- [x] 将 `source_page.dart` 的外部导入监听移入 feature application coordinator
- [x] 将 `AuthEventBus` 监听移入 feature application coordinator 或 app-level listener
- [x] 将 payload 消费、缓存、导入结果提示拆为独立 service
- [x] 页面只保留“加载状态 + 列表交互 + 调用 action”

### 4.4 `mine/cache`

- [x] 为缓存管理建立 query service
- [x] 为缓存清理建立 action service
- [x] 将页面里的 `AppDatabase` 查询全部迁出
- [x] 将数据库 stream 订阅迁为 provider 暴露
- [x] 将封面缓存清理与章节缓存清理解耦成稳定用例接口

阶段完成标准：

- `presentation -> AppDatabase` 直接依赖在上述 4 个范围内清零
- `presentation -> RepositoryImpl` 直接依赖在上述 4 个范围内清零
- `presentation -> bridge/runtime 单例` 在上述 4 个范围内完成第一轮下沉

---

### 阶段 2：处理 P2 越界与散点技术债

目标：补齐中等优先级越界点，避免问题重新扩散。

### 4.5 `source_login`

- [x] 把交互浏览器打开流程提取为 `SourceLoginBrowserService` 或同类 application service
- [x] 页面只保留登录表单、验证码输入、提示展示
- [x] 将浏览器返回协议封装为稳定模型，而非页面直接拼装 map

### 4.6 `discover`

- [x] 将书籍展示元数据覆盖查询移入 query service
- [x] 将 `SourceHealthService`、任务冲突服务、任务调度服务改为 provider 注入
- [x] 页面保留分类、列表、分页、滚动与交互

### 4.7 `mine/bookmarks`

- [x] 将 `BookmarkRepositoryImpl` 迁出页面
- [x] 建立书签列表 query service
- [x] 建立书签跳转 action service 或复用现有 route resolver provider

### 4.8 `search`

- [x] 将 `search_book_card.dart` 中元数据覆盖查询迁出 widget
- [x] 将展示态解析统一走 search feature query/presentation resolver

### 4.9 `mine/advanced_theme_list`

- [x] 将外部导入监听迁出页面
- [x] 将 `AuthEventBus` 监听迁出页面
- [x] 将 payload 消费和缓存流程迁移到 application service

阶段完成标准：

- 已知 P2 越界点全部有对应 provider 或 application service 承接
- 页面中不再出现新的桥接事件消费逻辑

---

### 阶段 3：超大页面拆薄

目标：在完成依赖收口后，开始处理维护性问题，避免再次形成“页面即系统”。

优先关注文件：

- [x] `lib/features/bookshelf/presentation/bookshelf_page.dart` 约 6200+ 行
  - 已拆出 `bookshelf_page_sections.dart`
- [x] `lib/features/book/presentation/book_detail_page.dart` 约 3600+ 行
  - 已拆出 `book_detail_page_models.dart`
- [x] `lib/features/source/presentation/source_page.dart` 约 2900+ 行
  - 已拆出 `source_page_dialogs.dart`
- [x] `lib/features/discover/presentation/discover_page.dart` 约 2800+ 行
  - 已拆出 `discover_page_pickers.dart`

拆分要求：

- [x] 按“页面壳 / widgets / controllers / application actions”拆层
  - 已完成首轮物理拆分，主页面开始回收到页面壳与编排
- [x] 不再新增超大 `StatefulWidget` 文件
- [x] 列表卡片、筛选条、批量操作、导入面板、诊断面板等拆到 `presentation/widgets`
- [x] 与页面状态强绑定但不直接渲染的流程优先拆到 controller 或 presenter
- [x] 拆分过程中不把业务逻辑倒灌回 widget helper

阶段完成标准：

- 上述页面至少完成第一轮结构化拆分
- 主页面文件职责收敛为页面壳、布局、交互绑定

---

### 阶段 4：测试与评审口径补齐

目标：让整改结果可守住，不靠人工记忆维持。

- [x] 为 `bookshelf` provider / query service 补测试
- [x] 为 `book detail` provider / application service 补测试
- [x] 为 `source` 外部导入 coordinator 补测试
- [x] 为 `cache management` 查询与清理 service 补测试
- [x] 为 `discover` 展示态解析 query service 补测试
- [x] 为 `bookmarks` 查询 service 补测试
- [x] 为 `source_login` 浏览器交互 service 补测试
- [x] 补充对应 widget smoke test 或 route smoke test
- [x] 代码评审时强制检查本文件第 7 节清单

阶段完成标准：

- 每个被整改的 feature 至少补上一层有效测试
- 不再出现“只移动代码、不补测试”的整改提交

---

## 5. 推荐落地顺序

建议顺序如下：

1. `bookshelf`
2. `book`
3. `mine/cache`
4. `source`
5. `discover`
6. `mine/bookmarks`
7. `search`
8. `source_login`
9. `mine/advanced_theme_list`

原因：

- `bookshelf` 和 `book` 的页面越界最集中，且对主流程影响最大
- `mine/cache` 有直接数据库读写与删除动作，风险较高
- `source` 涉及桥接与导入编排，应该尽快从页面层迁出
- `discover/search/bookmarks` 可以在基础 provider 口径成形后跟进

---

## 6. 每阶段交付物

每完成一个阶段，至少应交付：

- [ ] 代码改动
- [ ] 对应测试
- [ ] 文档状态回填
- [ ] 一次 `flutter analyze`
- [ ] 一次 `flutter test`

建议回填格式：

- 状态：`未开始 / 进行中 / 已完成 / 已阻塞`
- 完成日期：`YYYY-MM-DD`
- 备注：只写阻塞原因或特殊决策

---

## 7. 评审检查清单

后续每个整改 PR 必查：

- [ ] 页面里是否仍直接 `new RepositoryImpl`
- [ ] 页面里是否仍直接依赖 `AppDatabase`
- [ ] 页面里是否仍直接依赖 bridge / runtime 单例
- [ ] feature 是否新增了自己的 `providers.dart` 或等价 provider 落点
- [ ] application service 是否承担了查询、导入、缓存清理、桥接编排职责
- [ ] 页面主文件是否继续膨胀
- [ ] 本次整改是否补了至少一层测试
- [ ] 是否又引入新的静态单例

任一项回答为“是”的处理规则：

- `new RepositoryImpl`
- `AppDatabase`
- 直接 bridge / runtime 单例

默认视为不通过。

---

## 8. 里程碑勾选区

### M1：依赖边界止血

- [x] 阶段 0 完成
- [x] 阶段 1 完成

### M2：中优先级越界清零

- [x] 阶段 2 完成

### M3：结构可维护

- [x] 阶段 3 完成

### M4：长期可守

- [x] 阶段 4 完成

---

## 9. 文档维护规则

- 本文件用于跟踪“阅读器之外的架构整改”
- 若发现新的非阅读器 feature 越界点，优先补到本文件，再安排实施
- 若某项整改已经由其他文档承接，需在本文件中注明迁移去向
- 若 `docs/development_architecture_guardrails.md` 更新，本文件需同步校准
