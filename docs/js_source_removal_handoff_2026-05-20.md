# JS 书源业务移除交接文档

日期：2026-05-20

目标：为后续 AI/开发者提供一份可直接执行的移除任务说明，将项目中的“本地 JS 书源规则 / 脚本书源 runtime”整块移除，收敛到“服务器书源 + 本地图书”双路线。

## 1. 结论先行

当前项目里的 JS 书源不是一个独立小模块，而是一整条业务链，至少覆盖：

- 书源存储
- JS runtime 编译与执行
- 搜索
- 发现
- 详情/目录/正文解析
- 登录态与 WebView 登录
- 调试器/编辑器/导入页
- 启动预热
- 多处测试、脚本、文档、示例资源

所以这件事不能理解成“删掉 `flutter_js` 依赖”或“删掉 `lib/features/source` 目录”。

必须先把以下能力改造或直接拆除，再删除代码：

- 搜索：切到服务器书源
- 阅读详情/正文：切到服务器网关
- 发现：改成服务器发现，或整块删除
- 换源：如果只保留服务器书源，需要重新定义交互；不能沿用本地脚本换源
- 书源管理：整个入口、路由、页面、服务直接删除

## 2. 当前架构事实

下面这些点是本次移除任务的核心依据。

### 2.1 JS runtime 与 WebView 依赖仍在主依赖中

- `pubspec.yaml:66-67`
  - `flutter_js`
  - `flutter_inappwebview`

### 2.2 脚本书源有独立本地存储

- `lib/data/datasources/local/app_database.dart:235-255`
  - `script_sources` 表仍然存在
- `lib/data/datasources/local/app_database.dart:779-859`
  - 提供 `get/upsert/delete/watch/clear script_sources`
- `lib/domain/entities/script_source.dart`
  - 脚本书源实体
- `lib/data/repositories/script_source_repository_impl.dart`
  - 脚本书源仓储实现

### 2.3 启动阶段仍会触发脚本书源预热

- `lib/app/startup/app_startup_coordinator.dart:170-185`
  - 启动时会调用 `sourceRuntimeFacade.listScriptSources()`

### 2.4 整个书源管理功能仍在

- 路由：`lib/features/source/routes.dart:13-107`
  - `/source`
  - `/source/login`
  - `/source/web-login`
  - `/source/script-editor`
  - `/source/paste-import`
- Provider 装配：`lib/features/source/providers.dart`
- 页面目录：`lib/features/source/presentation/*`
- 应用服务目录：`lib/features/source/application/*`

### 2.5 搜索仍直接依赖脚本书源 runtime

- `lib/features/search/application/script_source_search_runner.dart:10-42`
  - 搜索调用 `SourceRuntimeFacade.search(...)`
- `lib/features/search/presentation/search_page.dart:797-826`
  - UI 仍会加载可用脚本书源供用户筛选
- `lib/features/mine/presentation/membership_center_page.dart:807-809`
  - 文案明确说明“关闭后继续使用本机旧搜索逻辑”

### 2.6 阅读详情/正文仍保留脚本书源 provider

- `lib/features/reader/application/source_content_provider.dart:6-83`
  - 脚本书源内容提供器
- `lib/features/reader/application/server_gateway_content_provider.dart:16-80`
  - 服务器网关内容提供器已存在
- `lib/features/reader/application/reader_dependencies_provider.dart:153-170`
  - 当前 registry 同时注册：
  - `LocalContentProvider`
  - `ServerGatewayContentProvider`
  - `SourceContentProvider`
- `lib/features/book/presentation/book_detail_page.dart:293-311`
  - 详情页也仍然同时装配本地/服务器/脚本三类 provider

### 2.7 发现页仍完全依赖脚本书源 discover 能力

- `lib/features/discover/application/explore_service.dart:88-139`
  - `ExploreService` 依赖 `SourceRuntimeFacade`
- `lib/features/discover/application/explore_service.dart:107-126`
  - 发现源来自脚本书源 `discoverCategories + discoverBooks`
- `lib/features/discover/presentation/discover_page.dart`
  - 发现页 UI 仍以脚本书源为数据来源

### 2.8 JS runtime 不是薄包装，而是完整桥接层

- `lib/src/js_runtime.dart`
- `lib/src/js_runtime_native.dart`
- `lib/runtime/sources/source_script_compiler.dart`

尤其是 `lib/runtime/sources/source_script_compiler.dart` 内注册了大量 bridge：

- session
- source login
- book custom state
- cookie
- cache
- http
- html
- browser
- ui
- crypto

这说明“脚本书源业务”本质上是一套宿主运行时，不是几条规则解析函数。

### 2.9 WebView 基础设施目前主要服务脚本书源链路

- `lib/core/webview/webview_executor.dart`
- `lib/core/webview/interactive_verification_browser_executor.dart`
- `lib/runtime/host/appread_browser_runtime.dart`
- `lib/features/source/presentation/source_web_login_page.dart`

注意：`flutter_inappwebview` 很可能可以随脚本书源一起删除，但应在最终删除前再次全局确认没有其他业务复用。

## 3. 目标移除边界

本次建议移除的业务定义如下：

- 本地脚本书源存储
- JS 书源编译/执行 runtime
- 书源管理页
- 书源脚本编辑/导入/调试页
- 书源登录页与 WebView 登录页
- 基于脚本书源的搜索
- 基于脚本书源的发现
- 基于脚本书源的详情/目录/正文解析
- 基于脚本书源的换源
- 与脚本书源相关的健康检查、调度、诊断、冲突控制、预热逻辑

本次建议保留的能力：

- 本地图书导入与阅读
- 服务器书源网关搜索
- 服务器书源详情/目录/正文
- 与本地图书、服务器书源无关的通用 UI/主题/书架/阅读记录能力

## 4. 不要直接删除的点

下面这些地方如果直接删，很容易把项目删坏。

### 4.1 不要先删 `SourceRuntimeFacade`

它目前被以下主链路直接依赖：

- 搜索
- 阅读详情
- 正文加载
- 章节缓存
- 换源
- 发现
- 启动预热
- 多个 provider 装配点

正确顺序应该是：先替换调用方，再删 facade 与 runtime。

### 4.2 不要先删 `script_sources` 表

先删数据库表会连带炸掉：

- 仓储
- 启动预热
- 搜索/发现装配
- 同步设计里对 `script_sources` 的引用

应在业务调用全部移除后，再做 schema 清理。

### 4.3 不要默认把 `flutter_inappwebview` 第一时间删掉

虽然它大概率是脚本书源链路专用，但建议在执行末段再做一次全局搜索确认后删除。

### 4.4 不要假设“服务器书源已覆盖发现和换源”

当前代码只明确覆盖了：

- 服务器在线搜索
- 服务器详情/目录/正文

没有看到等价的“服务器发现页”与“服务器换源”完整替代链路。

## 5. 推荐执行顺序

建议分 6 个阶段执行，而不是一把梭删除。

### 阶段 A：先确定拆除口径

执行前先固定以下决策，否则后续 AI 会在实现时来回摇摆：

1. 发现页怎么处理
   - 方案 A：直接删除发现页
   - 方案 B：改造成服务器发现
2. 换源怎么处理
   - 方案 A：直接删除换源功能
   - 方案 B：做服务器侧换源能力
3. 会员页“服务器在线搜索”开关怎么处理
   - 方案 A：保留开关，但彻底移除“本机旧搜索逻辑”语义
   - 方案 B：如果以后全量走服务器，继续收口相关配置项
4. 历史本地脚本书源数据是否需要迁移/清空
   - 方案 A：保留数据库字段一版，业务不再读取
   - 方案 B：直接清表并删 schema

如果让我给建议：

- 发现页：本地版建议直接删除，除非你要同步补服务器发现
- 换源：本地版建议直接删除，除非你要同步补服务器换源
- 搜索：统一改成服务器
- 旧脚本书源数据：先停止读取，再在后续版本删表

### 阶段 B：先把主业务切到“无脚本书源也能跑”

先改调用方，再删底层。

#### B1. 阅读内容 provider 收口

目标状态：

- `ContentProviderRegistry` 只保留：
  - `LocalContentProvider`
  - `ServerGatewayContentProvider`

需要改动的关键位置：

- `lib/features/reader/application/reader_dependencies_provider.dart:153-170`
- `lib/features/book/presentation/book_detail_page.dart:293-311`

同时要检查以下能力开关是否仍合理：

- `canSwitchSource`
- `canCacheChapter`
- `canSearchInSource`

因为当前这些能力有一部分来自 `SourceContentProvider`。

#### B2. 详情/正文/缓存链路去脚本源分支

重点排查并改造：

- `lib/features/book/application/book_detail_service.dart`
- `lib/features/reader/application/chapter_content_service.dart`
- `lib/features/reader/application/chapter_cache_service.dart`
- `lib/features/reader/presentation/reader_page.dart`
- `lib/features/reader/presentation/reader_page_bootstrap.dart`
- `lib/features/reader/presentation/reader_page_source_switch.dart`
- `lib/features/book/presentation/book_detail_switch_source_helper.dart`

处理原则：

- 遇到服务器 sourceId，继续走服务器 provider
- 遇到本地图书 sourceId，继续走本地 provider
- 遇到旧脚本 sourceId，做兜底：
  - 显示“该本地脚本书源能力已移除，请重新搜索并加入服务器书源版本”
  - 不再尝试 runtime 执行

#### B3. 搜索改成纯服务器路径

需要处理：

- `lib/features/search/application/search_service.dart`
- `lib/features/search/application/script_source_search_runner.dart`
- `lib/features/search/presentation/search_page.dart:797-826`
- `lib/features/search/providers.dart`

建议做法：

- 删除脚本书源搜索 runner
- 搜索页不再加载本地脚本书源列表
- 只保留服务器书源筛选面板
- 如果会员/开关逻辑仍存在，明确“不开启时的行为”

还要同步改文案：

- `lib/features/mine/presentation/membership_center_page.dart:807-809`

把“关闭后继续使用本机旧搜索逻辑”改掉。

#### B4. 发现页处理

二选一：

- 如果短期不做服务器发现：
  - 直接删除 `discover` 页入口、路由、页面与 service
- 如果要做服务器发现：
  - 新建服务器发现 service
  - 彻底替换 `ExploreService` 对 `SourceRuntimeFacade` 的依赖

当前强依赖点：

- `lib/features/discover/application/explore_service.dart`
- `lib/features/discover/presentation/discover_page.dart`
- `lib/features/discover/providers.dart`
- `lib/features/discover/routes.dart`

### 阶段 C：直接删除书源管理功能

在主流程不再依赖脚本书源后，直接删除整块 `features/source`。

建议删除范围：

- `lib/features/source/presentation/*`
- `lib/features/source/application/*`
- `lib/features/source/providers.dart`
- `lib/features/source/routes.dart`

同时处理：

- `lib/app/router.dart` 中的 `sourceRoutes`
- `lib/app/shell_scaffold.dart`
- `lib/app/shell_navigation_provider.dart`
- `lib/features/mine/presentation/mine_page.dart`
- 所有“书源管理 / 脚本编辑 / 粘贴导入 / 登录”入口

### 阶段 D：删除脚本 runtime 与基础设施

当上层已经无人调用后，再删底层。

建议删除范围：

- `lib/src/js_runtime.dart`
- `lib/src/js_runtime_native.dart`
- `lib/src/js_runtime_stub.dart`
- `lib/runtime/sources/*`
- `lib/runtime/session/source_session.dart`
- `lib/runtime/aggregation/search_aggregator.dart`
- `lib/runtime/crypto/source_crypto.dart`
- `lib/runtime/host/appread_browser_runtime.dart`
- `lib/core/webview/webview_executor.dart`
- `lib/core/webview/interactive_verification_browser_executor.dart`

以及应用装配中的相关 provider：

- `lib/app/composition/app_providers.dart`
  - `scriptSourceRepositoryProvider`
  - `appSourceRuntimeFacadeProvider`
  - `appSourceHealthServiceProvider`
  - `appSourceRuntimeSchedulerServiceProvider`
  - `appSourceRuntimeTaskConflictServiceProvider`
  - `appInteractiveVerificationBrowserExecutorProvider`

### 阶段 E：清理数据库与 capability

建议处理：

- 删 `ScriptSource` 实体与 repository
- 删 `script_sources` 表与 DAO 方法
- 移除 `sourceRuntime` / `interactiveWebView` 能力定义与引用

重点位置：

- `lib/domain/entities/script_source.dart`
- `lib/domain/repositories/script_source_repository.dart`
- `lib/data/repositories/script_source_repository_impl.dart`
- `lib/data/datasources/local/app_database.dart`
- `lib/app/platform/app_platform_capabilities.dart`
- `lib/app/widgets/feature_disabled_page.dart`
- `lib/app/startup/app_startup_coordinator.dart`

注意：

- `SourceLoginStateService` 使用的是 `SharedPreferences` key，不是 Drift 表。
- 对应 key：
  - `source.login.states.v1`
  - `source.book.custom.states.v1`
- 位置：`lib/features/source/application/source_login_state_service.dart`

如果整个书源业务删掉，这个服务和这些 key 也应一并淘汰。

### 阶段 F：删依赖、测试、示例、文档

#### 依赖

评估并删除：

- `flutter_js`
- `flutter_inappwebview`

#### 资源/示例

检查并删除或移出 assets：

- `read.json`
- `test_read.json`
- `晴天聚合.js`
- `docs/js/test_read.js`

其中 `pubspec.yaml:120-121` 仍把 `read.json`、`test_read.json` 注册为资源。

#### 测试

需要删除或重写的大类测试包括：

- `test/features/source/**`
- `test/runtime/**`
- `test/data/repositories/script_source_repository_impl_test.dart`
- `test/data/datasources/local/app_database_script_source_migration_test.dart`
- `test/features/search/**` 中依赖脚本书源的 case
- `test/features/book/**` / `test/features/reader/**` 中依赖 `SourceRuntimeFacade` 的 case
- `test/features/discover/**` 中脚本发现链路的 case

#### 文档

建议至少标注过时或删除与脚本书源强绑定的文档：

- `docs/source_login_execution_plan.md`
- `docs/md3_login_feature_execution_plan.md`
- `docs/md3_source_manual_migration_strategy_2026-05-08.md`
- `docs/script_sources/*`
- 以及所有引用 `script_sources`、`source_runtime`、`JS 书源` 的设计文档

## 6. 建议的“先改后删”落地方案

如果希望降低一次性风险，推荐下面的实际执行路径。

### 第 1 步：先让主业务摆脱脚本书源依赖

- 搜索页面只展示服务器书源选择
- 阅读详情/正文只允许：
  - 本地图书
  - 服务器书源
- 发现页直接删除，或改为服务器发现
- 换源功能直接删除，或改为服务器换源
- 书源管理整块删除

### 第 2 步：给旧数据做兜底

对历史收藏/书架里仍挂着旧脚本 sourceId 的书，统一给出友好提示，例如：

- “该本地脚本书源能力已移除，请重新搜索后加入书架”

不要继续尝试兼容旧 runtime。

### 第 3 步：删 UI 和业务调用层

先删：

- source 页面
- source 路由
- discover 脚本链路
- search 脚本链路
- reader/book 脚本 provider 注入

### 第 4 步：删底层 runtime

上层无人引用后，再删：

- `SourceRuntimeFacade`
- `runtime/sources`
- `js_runtime`
- `webview executor`

### 第 5 步：删持久化和依赖

最后再删：

- `script_sources` 表
- repository/entity
- `flutter_js`
- `flutter_inappwebview`

## 7. 验收标准

后续执行完成后，至少应满足以下验收条件。

### 编译与静态检查

- `flutter analyze` 通过
- `flutter test` 通过，或已同步删除/改写失效测试
- `rg -n "SourceRuntimeFacade|ScriptSource|script_source|script_sources|flutter_js|js_runtime|source login|sourceRuntime|interactiveWebView"` 结果仅剩允许保留的历史文档，业务代码中不再出现

### 功能验收

- 搜索仅走服务器书源，且可正常出结果
- 服务器详情、目录、正文可正常打开
- 本地图书导入、打开、阅读不受影响
- 不再出现“书源管理 / 脚本调试 / 脚本导入 / WebView 登录”入口
- 若打开历史旧书，能得到明确提示，而不是崩溃

### 清理验收

- `pubspec.yaml` 不再包含废弃依赖
- 资源清单不再包含旧书源示例文件
- 相关测试与文档已同步处理

## 8. 建议给后续 AI 的执行约束

可以把下面这段作为后续 AI 的任务前置说明：

1. 不要直接暴力删除 `lib/features/source` 或 `flutter_js`。
2. 先让搜索、阅读、发现、换源在“没有本地脚本书源”的情况下仍然可运行。
3. 先替换调用方，再删除 `SourceRuntimeFacade`、`runtime/sources`、`js_runtime`、`webview` 基础设施。
4. 发现页如果没有服务器替代实现，则直接删除，不要半保留。
5. 对历史旧脚本 sourceId 的书籍提供友好错误提示，不要尝试兼容旧 runtime。
6. 所有删除都要同步清理测试、路由、provider、capability、数据库、资源和文档引用。

## 9. 我对最终目标结构的建议

移除完成后，项目最好收敛成下面这套模型：

- 内容来源 1：本地图书
- 内容来源 2：服务器书源

前端只保留两类 `ContentProvider`：

- `LocalContentProvider`
- `ServerGatewayContentProvider`

不再保留：

- `SourceContentProvider`
- `SourceRuntimeFacade`
- 脚本书源管理体系
- JS runtime / WebView 登录 / 书源脚本编辑器

这会让架构从“三套内容体系并存”收敛成“两套清晰来源”，后续维护成本会明显下降。

## 10. 拆除阶段执行计划

下面这部分可以直接当作执行 checklist 使用。

推荐执行节奏：

1. 先删除业务入口与路由
2. 再替换调用链
3. 再删除页面与服务
4. 最后清理 runtime、数据库、依赖、测试、文档

### 阶段 0：执行前确认

目标：先锁定产品口径，避免执行中反复改方向。

- [x] 确认发现页处理方案
- [x] 确认换源功能处理方案
- [x] 确认“服务器在线搜索”开关是否保留
- [ ] 确认历史脚本书源数据是保留一版还是直接清理
- [x] 确认历史旧书打开时的兜底提示文案

交付标准：

- 有一份明确结论，后续执行过程中不再临时摇摆

阶段 0 决策结论：

- 发现页：未来改为服务器实现；当前本地版先移除脚本书源 discover 实现，改成“服务器发现预留页”
- 换源：未来改为服务器实现；当前先移除现有本地脚本换源入口，不再暴露旧换源能力
- 服务器在线搜索：保留，但文案与行为都不再指向“本机旧搜索逻辑”
- 历史旧书兜底文案：使用“该本地脚本书源能力已移除，请重新搜索并加入服务器书源版本”

### 阶段 1：直接删除用户入口与路由

目标：直接删除用户可见入口和路由，不保留空壳。

- [x] 删除“书源管理”入口
- [x] 删除“脚本编辑/导入/调试”入口
- [x] 删除“书源登录 / WebView 登录”入口
- [x] 删除发现页入口，或同步改成服务器发现入口
- [x] 删除换源入口，或同步改成服务器换源入口
- [x] 修改会员页文案，去掉“关闭后继续使用本机旧搜索逻辑”

建议检查文件：

- `lib/app/shell_scaffold.dart`
- `lib/app/shell_navigation_provider.dart`
- `lib/features/mine/presentation/mine_page.dart`
- `lib/features/mine/presentation/membership_center_page.dart`
- `lib/features/discover/routes.dart`
- `lib/features/source/routes.dart`

交付标准：

- 用户在 UI 中已不再看到 JS 书源相关入口、路由、页面

### 阶段 2：搜索链路切换

目标：搜索只保留服务器书源路径。

- [x] 搜索页不再加载本地脚本书源列表
- [x] 删除脚本书源筛选 UI
- [x] 全局搜索页不再使用脚本书源搜索 runner
- [x] 全局搜索页不再依赖 `SourceRuntimeFacade.search(...)`
- [x] 搜索失败/空态文案改成服务器书源语义
- [x] 搜索页仅保留服务器书源筛选和结果展示

建议检查文件：

- `lib/features/search/presentation/search_page.dart`
- `lib/features/search/application/search_service.dart`
- `lib/features/search/application/script_source_search_runner.dart`
- `lib/features/search/providers.dart`

交付标准：

- [x] 搜索流程仅走服务器书源
- [x] 搜索页面不再出现“脚本书源”选择逻辑

### 阶段 3：阅读链路切换

目标：阅读详情/目录/正文只支持本地图书和服务器书源。

- [x] `ContentProviderRegistry` 移除 `SourceContentProvider`
- [x] 详情页 provider 装配移除脚本书源 provider
- [x] 正文加载流程移除脚本 runtime 分支
- [x] 章节缓存流程不再依赖脚本书源 runtime
- [x] 旧脚本 sourceId 打开时给出友好提示
- [ ] 本地图书阅读不受影响
- [ ] 服务器书源详情/目录/正文正常

建议检查文件：

- `lib/features/reader/application/reader_dependencies_provider.dart`
- `lib/features/book/presentation/book_detail_page.dart`
- `lib/features/book/application/book_detail_service.dart`
- `lib/features/reader/application/chapter_content_service.dart`
- `lib/features/reader/application/chapter_cache_service.dart`
- `lib/features/reader/presentation/reader_page.dart`
- `lib/features/reader/presentation/reader_page_bootstrap.dart`
- `lib/features/reader/presentation/reader_page_source_switch.dart`

交付标准：

- [ ] 本地图书可正常阅读
- [ ] 服务器书源可正常阅读
- [x] 历史脚本 sourceId 不会导致崩溃

### 阶段 4：发现与换源处理

目标：清掉仍然依赖脚本书源的功能。

如果发现页直接删除：

- [ ] 删除 discover 路由
- [ ] 删除 discover 页面入口
- [ ] 删除 discover 对 `SourceRuntimeFacade` 的依赖

如果发现页改服务器实现：

- [ ] 新建服务器发现 service
- [ ] discover 页面改为服务器数据源
- [x] 删除 discover 对脚本书源 discover 能力的依赖

换源功能：

- [x] 明确是否完全删除换源
- [x] 如果删除，移除详情页/阅读页换源入口
- [ ] 如果保留，必须基于服务器能力重做，不再使用脚本书源搜索与评分链路

建议检查文件：

- `lib/features/discover/application/explore_service.dart`
- `lib/features/discover/presentation/discover_page.dart`
- `lib/features/discover/providers.dart`
- `lib/features/discover/routes.dart`
- `lib/features/book/presentation/book_detail_switch_source_helper.dart`
- `lib/features/reader/presentation/reader_page_source_switch.dart`
- `lib/features/reader/presentation/reader_source_switch_controller.dart`

交付标准：

- [ ] discover/换源不再依赖脚本书源 runtime

阶段 4 当前状态说明：

- discover 的本地脚本实现文件和 provider 已移除，路由仅保留服务器预留页
- 换源的用户入口与提示文案已撤除
- 但换源的底层辅助代码仍存在于阅读/详情模块中，待后续继续物理删除

### 阶段 5：删除书源管理业务

目标：整块删除 `features/source` 业务。

- [x] 删除 `lib/features/source/presentation/*`
- [ ] 删除 `lib/features/source/application/*`
- [x] 删除 `lib/features/source/providers.dart`
- [x] 删除 `lib/features/source/routes.dart`
- [x] 删除 router 中的 `sourceRoutes`
- [x] 删除所有“书源能力不可用”相关占位页入口

交付标准：

- [x] 项目业务层不再存在书源管理、脚本编辑、脚本调试、登录流程

阶段 5 当前状态说明：

- `features/source` 的 UI 接入层已经删除完毕
- `features/source/application/*` 仍被 runtime / provider / 数据层复用，需放到阶段 6 统一清理

### 阶段 6：删除脚本 runtime 与 WebView 基础设施

目标：删除底层技术实现。

- [x] 删除 `lib/src/js_runtime.dart`
- [x] 删除 `lib/src/js_runtime_native.dart`
- [x] 删除 `lib/src/js_runtime_stub.dart`
- [x] 删除 `lib/runtime/sources/*` 的执行实现，保留最小兼容模型
- [x] 删除 `lib/runtime/session/source_session.dart`
- [x] 删除 `lib/runtime/host/appread_browser_runtime.dart`
- [x] 删除 `lib/core/webview/webview_executor.dart`
- [x] 删除 `lib/core/webview/interactive_verification_browser_executor.dart`
- [x] 删除或降级相关 provider 装配

建议检查文件：

- `lib/app/composition/app_providers.dart`
- `lib/app/bootstrap.dart`

交付标准：

- [ ] 业务代码中不再存在脚本 runtime 调用链

阶段 6 当前状态说明：

- 启动链已不再执行 WebView 调试设置、source diagnostics 恢复和 source health hydrate
- startup 已不再做 script source 预热
- discover/source 的 UI 接入层和路由层已删除
- `lib/src`、`lib/core/webview`、`lib/runtime` 大部分执行实现已物理删除
- 当前仍保留少量兼容壳与模型类型，以避免一次性打穿主业务引用

### 阶段 7：数据库与配置清理

目标：删除持久化残留与 capability 残留。

- [x] 删除 `ScriptSource` 实体
- [x] 删除 `ScriptSourceRepository` 接口与实现
- [x] 删除 `script_sources` 表
- [x] 删除 app database 中相关 DAO 方法
- [x] 删除 `sourceRuntime` / `interactiveWebView` capability 的有效能力语义
- [x] 删除启动预热中的脚本书源预热逻辑
- [x] 删除 `SourceLoginStateService` 及相关 SharedPreferences key

建议检查文件：

- `lib/domain/entities/script_source.dart`
- `lib/domain/repositories/script_source_repository.dart`
- `lib/data/repositories/script_source_repository_impl.dart`
- `lib/data/datasources/local/app_database.dart`
- `lib/app/platform/app_platform_capabilities.dart`
- `lib/app/startup/app_startup_coordinator.dart`

交付标准：

- [ ] 数据层和 capability 层不再保留 JS 书源业务结构

阶段 7 当前状态说明：

- 本地图书链已不再依赖 `SourceLoginStateService`
- 书架展示查询和书架页入口已不再依赖 source runtime 外围能力
- `script_sources` 表、`ScriptSource` 实体、repository 与相关 DAO 已从主代码中移除，并已重生成数据库代码
- `sourceRuntime / interactiveWebView` 已降级为永久不可用能力说明
- 当前仍保留少量兼容 provider / service 壳，以及 `SourceLoginStateService` 本体，待是否继续清理 SharedPreferences key 再决定

### 阶段 8：依赖、资源、测试、文档清理

目标：完成仓库收尾。

- [ ] 从 `pubspec.yaml` 删除 `flutter_js`
- [ ] 从 `pubspec.yaml` 删除 `flutter_inappwebview`
- [ ] 评估并移除 `read.json`
- [ ] 评估并移除 `test_read.json`
- [ ] 评估并移除 `晴天聚合.js`
- [ ] 清理脚本书源相关测试
- [ ] 清理脚本书源相关工具脚本
- [ ] 标记或删除脚本书源相关文档

重点检查目录：

- `test/features/source/**`
- `test/runtime/**`
- `test/features/search/**`
- `test/features/book/**`
- `test/features/reader/**`
- `test/features/discover/**`
- `docs/script_sources/**`

交付标准：

- [ ] 仓库内不再残留可执行的 JS 书源业务代码
- [ ] 文档与代码状态一致

## 11. 总体验收 checklist

这部分适合在全部拆除完成后统一勾选。

### 编译与检查

- [ ] `flutter analyze` 通过
- [ ] `flutter test` 通过，或已同步删除失效测试
- [ ] 全局搜索不再出现业务代码级别的 `SourceRuntimeFacade`
- [ ] 全局搜索不再出现业务代码级别的 `ScriptSource`
- [ ] 全局搜索不再出现业务代码级别的 `flutter_js`
- [ ] 全局搜索不再出现业务代码级别的 `js_runtime`

### 功能回归

- [ ] 本地图书导入正常
- [ ] 本地图书打开正常
- [ ] 本地图书阅读正常
- [ ] 服务器书源搜索正常
- [ ] 服务器书源详情正常
- [ ] 服务器书源目录正常
- [ ] 服务器书源正文正常
- [ ] 历史旧书打开时会得到友好提示
- [ ] 应用中不再出现书源管理/脚本调试/脚本导入/书源登录入口

### 收尾确认

- [ ] `pubspec.yaml` 已清理废弃依赖
- [ ] 资源清单已清理旧书源样例
- [ ] 测试与文档已同步更新
- [ ] 没有仅删除代码但遗漏文案、路由、provider、数据库的半成品状态
