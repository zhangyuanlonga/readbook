# 代码库工程治理专项 Backlog

创建日期：2026-06-02  
适用范围：在移动端已经成熟稳定的前提下，对代码复杂度、手写样板、存储偏好、平台判断、响应式底座使用进行持续治理。  
最高原则：**这是工程治理专项，不是移动端重构专项；任何改动都必须保持 Android / iOS 既有 UI、交互、业务流程和数据兼容。**

## 0. 治理红线

- [x] 不以“治理”为名大面积重写成熟移动端页面。
- [x] 不为了引入库而迁移已有稳定实现。
- [x] 不机械迁移旧模型、旧偏好设置、旧 JSON 结构。
- [x] 共享底层改动必须说明移动端影响面，并补对应回归测试。
- [x] 复杂页面拆分优先做等价搬迁：拆文件、拆组件、拆服务，不改视觉和业务语义。
- [x] 存储迁移必须保留旧 key、旧 JSON、旧路径兼容读取。

## 1. 当前工程基线

- [x] `lib` 下约 496 个 Dart 文件，约 17.1 万行代码。
- [x] `test` 下约 237 个 Dart 测试文件。
- [x] 1000 行以上文件约 39 个，总计约 8 万行。
- [x] 复杂度主要集中在阅读器、书架、主题、详情页。
- [x] 最大文件包括：`reader_page.dart` 约 6012 行。
- [x] 最大文件包括：`bookshelf_page.dart` 约 5331 行。
- [x] 最大文件包括：`reader_page_settings_sheet.dart` 约 4575 行。
- [x] 最大文件包括：`advanced_theme_list_page.dart` 约 4023 行。
- [x] 最大文件包括：`advanced_theme_editor_page.dart` 约 3880 行。
- [x] 手写模型样板较多：`toJson` 命中 87 次，`fromJson` 命中 131 次，`copyWith` 命中 1234 次，手写相等/hash 命中 33 次。
- [x] 偏好设置和 JSON 手工处理较多：`SharedPreferences` 相关命中 694 次，`jsonDecode/jsonEncode` 命中 86 次。
- [x] 响应式底座已广泛使用：`AppLayout/AppAdaptiveMetrics` 与自适应组件相关命中 431 次。
- [x] 平台判断较分散：`kIsWeb/defaultTargetPlatform/TargetPlatform/Platform` 命中 193 次。

## 2. 治理目标

- [ ] 将复杂页面拆成可维护、可测试、可桌面化扩展的组件和服务。
- [ ] 将新增状态/配置对象逐步切到生成式不可变模型，减少手写 `copyWith`、相等和 hash。
- [ ] 将全局偏好配置逐步收拢到类型安全访问层，减少散落 key 和默认值。
- [ ] 将 JSON-backed preferences、临时目录、托管目录使用纳入 storage guard 可解释基线。
- [ ] 将平台判断收敛到 facade / adapter / capability service，减少页面内直接判断。
- [ ] 将响应式规则沉淀为内部组件和页面接入规范，而不是每个页面手写一套分支。

## 3. Phase A：基线与自动扫描

- [x] 固化统计脚本：文件数、行数、1000 行以上文件、`copyWith/toJson/fromJson`、`SharedPreferences`、平台判断。
- [x] 将统计结果输出到文档，作为每轮治理前后的对比基线。
- [x] 建立“页面文件超过 1500 行需要拆分评估”的规则。
- [x] 建立“应用层直接新增 `SharedPreferences` import 需要说明理由”的规则。
- [x] 建立“页面层直接新增平台判断需要说明理由”的规则。
- [x] 将既有 guard 与新增统计脚本挂到本地验证清单。
- [x] 新增 `tool/check_codebase_engineering_baseline.dart`，并接入 `tool/run_architecture_green_suite.dart`。
- [x] 当前规则先以非阻断 report 方式输出，避免影响移动端稳定分支；后续稳定后再评估是否升级为 guard。

## 4. Phase B：Storage Guard 审计

- [x] 处理当前 storage guard 失败项：`remote_access_snapshot_service.dart` 的 JSON prefs sidecar。
- [x] 处理当前 storage guard 失败项：`reader_pagination_cache_service.dart` 的 `getTemporaryDirectory` 使用。
- [x] 清理 stale baseline：`reader_preferences_service.dart|key`。
- [x] 复核当前 JSON-backed `SharedPreferences` 写入点：硬失败项已迁移，剩余历史基线从 8 降为 7。
- [x] 复核当前 temporary/cache directory 使用点：硬失败项已改为 application cache directory，剩余历史基线从 13 降为 12。
- [x] 复核当前 3 个 managed directory direct usages，当前 guard 无新增 violation。
- [x] 对本轮处理项补充 rationale：远程会员 sidecar 迁入 Drift 表字段；阅读分页缓存属于可丢失缓存，默认目录改为 application cache directory。
- [x] guard 白名单只允许在完成 rationale 后更新。
- [x] `tool/check_storage_governance_guard.dart` 已复跑通过：7 个 JSON-backed prefs、12 个 temporary/cache usages、0 个 startup cleanup、3 个 managed directory usages，无 warning、无 violation。

## 5. Phase C：Preferences 分层治理

- [x] 首轮试点：新增 `PreferenceKey<T>`。
- [x] 首轮试点：shell navigation 配置使用类型安全 key，保留旧 key 兼容。
- [x] 盘点 `lib` 下约 35 个直接 import `shared_preferences` 的生产文件。
- [x] 将使用点分为全局配置、领域配置、缓存/sidecar、认证/session、迁移任务、测试辅助。
- [x] 优先治理全局配置：主题、种子色、字体、导航、启动目的地、我的页外观。
- [x] 对 reader/bookshelf 大模块只做服务层内聚，不跨模块强行迁移。
- [x] 每迁移一组 key，必须补旧 key 兼容读取测试。
- [x] 新增偏好配置默认使用 service/facade，不在页面内直接读写 prefs。

### Phase C 使用点分类

- [x] 全局配置 / 启动 / 壳层：`lib/app/bootstrap.dart`、`lib/app/navigation/app_navigation_style_provider.dart`、`lib/app/navigation/bottom_nav_icon_gallery_service.dart`、`lib/app/preferences/app_preferences_service.dart`、`lib/app/router.dart`、`lib/app/startup/managed_asset_path_migration_service.dart`、`lib/app/startup/startup_task_gate_service.dart`、`lib/app/startup_artwork_store.dart`、`lib/app/theme/app_interface_typography_provider.dart`、`lib/app/theme/app_theme_provider.dart`、`lib/app/theme/app_theme_seed_provider.dart`。
- [x] 认证 / session / device：`lib/core/auth/auth_session_secret_store.dart`、`lib/core/auth/auth_session_store.dart`、`lib/core/device/device_identity_service.dart`。
- [x] 领域轻量配置：`lib/features/announcement/application/announcement_read_state_service.dart`、`lib/features/bookshelf/application/bookshelf_system_settings_service.dart`、`lib/features/home/application/home_engagement_service.dart`、`lib/features/mine/application/mine_page_preferences_service.dart`、`lib/features/reader/application/reader_system_settings_service.dart`、`lib/features/search/application/search_system_settings_service.dart`。
- [x] 领域服务 / 迁移 / index/cache：`lib/features/bookshelf/application/bookshelf_service.dart`、`lib/features/mine/application/advanced_theme_provider.dart`、`lib/features/mine/application/advanced_theme_resource_reference_service.dart`、`lib/features/mine/application/advanced_theme_service.dart`、`lib/features/mine/application/cover_gallery_service.dart`、`lib/features/mine/application/launch_image_gallery_service.dart`、`lib/features/mine/application/remote_access_snapshot_service.dart`、`lib/features/reader/application/local/txt_chapter_rule_service.dart`、`lib/features/reader/application/reader_preferences_service.dart`、`lib/features/reader/application/reader_visual_overrides_service.dart`、`lib/features/reader/application/source_switch_score_service.dart`、`lib/features/search/application/search_history_service.dart`、`lib/features/source/application/source_health_persistence_service.dart`。
- [x] Provider composition / feature boundary：`lib/features/mine/providers.dart`。
- [x] 用户作用域资源与 session 展示缓存：`lib/features/mine/application/mine_page_session_service.dart`。
- [x] 页面层直接 prefs 清理：`lib/features/auth/presentation/user_profile_page.dart` 已移除直接 `SharedPreferences` 读取，改走 `MinePageSessionService`。
- [x] 首轮 key 迁移：`mine.page.hiddenItems`、`app.startup.destination`、`mine.page.layoutMode` 已接入 `PreferenceKey<T>`；我的页布局模式由 `MinePagePreferencesService` 管理，不再由 session service 承担。

## 6. Phase D：模型与状态样板治理

- [x] 首轮试点：引入 `freezed/freezed_annotation`。
- [x] 首轮试点：`AppShellNavigationState` 与 `AppShellNavigationSnapshot` 改成生成式不可变对象。
- [ ] 对 34 处手写 equality/hash 做风险分类。
- [ ] 对高频 `copyWith` 状态对象做候选清单。
- [ ] 新增跨 Provider/Service 传递的状态对象优先使用 `freezed`。
- [ ] 新增需要 JSON 序列化的 DTO，等待 Dart SDK 升级窗口后再评估 `json_serializable`。
- [ ] 不全量迁移旧模型；只在功能改动或拆分时顺手治理。
- [ ] 每个生成模型试点必须补 value equality、default、copyWith 或 JSON 兼容测试。

## 7. Phase E：复杂页面拆分治理

- [x] 首轮试点：`home_page.dart` 拆出移动/桌面 dashboard 布局壳。
- [x] 首轮试点：`home_page.dart` 拆出首页指标展示与阅读目标弧线 painter。
- [ ] 拆分 `reader_page.dart`：优先拆 toolbar、overlay、tap zone、reader shell、状态协调器。
- [ ] 拆分 `bookshelf_page.dart`：优先拆桌面布局、筛选排序、空状态、书籍卡片交互。
- [ ] 拆分 `reader_page_settings_sheet.dart`：优先拆 typography、spacing、theme、audio、manga 设置组。
- [ ] 拆分 `advanced_theme_service.dart`：优先拆资源读写、导入导出、存储迁移、主题编排。
- [ ] 拆分 `advanced_theme_list_page.dart`：优先拆列表、导入导出、预览、空状态。
- [ ] 拆分 `advanced_theme_editor_page.dart`：优先拆表单区块、资源选择、预览、校验。
- [ ] 每次只拆一个小区域，保持行为不变。
- [ ] 拆分后补最小 widget test / service test / smoke test。

## 8. Phase F：平台判断收敛

- [ ] 盘点约 155 处平台判断，按 Web、Desktop、Mobile、文件系统、窗口、设备能力分类。
- [ ] 将窗口能力收敛到 desktop/window adapter。
- [ ] 将文件选择、路径、缓存目录能力收敛到 platform storage facade。
- [ ] 将 Web 特有能力收敛到 web capability service。
- [ ] 页面层新增平台判断优先改为读取 capability，而不是直接使用 `Platform` 或 `defaultTargetPlatform`。
- [ ] 移动端现有平台行为只做等价抽取，不改变分支结果。

## 9. Phase G：响应式底座规范

- [x] 保留 `AppLayout + AppAdaptiveMetrics`，不引入第二套响应式体系覆盖。
- [x] 新增 `AdaptiveSplitBody` 与 `AdaptiveOverflowToolbar` 作为内部补充组件。
- [ ] 盘点 311 次 `AppLayout/AppAdaptiveMetrics` 使用，区分规范使用和重复手写分支。
- [ ] 首页、书架、详情页、阅读记录页优先接入内部自适应组件。
- [ ] 桌面页面优先使用最大宽度、流式列、可折叠工具栏、主从分栏。
- [ ] `< 600` 宽度继续走移动端布局，不为桌面治理改动移动端断点行为。
- [ ] 为关键桌面尺寸补 smoke 或截图回归：`1024 / 1440 / 1920`。

## 10. 优先级建议

- [x] P0：Storage guard 当前失败项，避免 guard 长期带病运行。
- [x] P0：建立统计脚本，让治理有可量化基线。
- [x] P0：建立 1500 行评估规则，让大文件治理逐步自动化。
- [x] P1：Preferences 全局配置治理，优先主题、字体、导航、外观。
- [ ] P1：复杂页面首批拆分，优先 reader/bookshelf 中和桌面端 UI 强相关区域。
- [ ] P1：平台判断 facade 化，优先窗口、文件、缓存目录。
- [ ] P2：模型生成式治理，随功能改动逐步推进。
- [ ] P2：响应式组件接入更多页面，配合桌面 UI 回归。

## 11. 验收方式

- [x] `dart analyze` 覆盖本轮改动文件。
- [x] 相关 widget/service/provider test 通过。
- [x] 移动端 smoke test 覆盖受影响页面。
- [x] storage guard 无新增 violation；既有 violation 必须有审计记录。
- [x] 统计脚本能说明治理前后变化，例如大文件行数下降、直接 prefs import 下降、平台判断下降。
- [x] 文档 checklist 同步更新，不把未审计项误打勾。

## 12. 执行记录

- [x] 2026-06-02：建立代码库工程治理专项 Backlog。
- [x] 2026-06-02：确认 Phase 3/4 首轮只完成 `freezed` 状态试点与 shell navigation typed preferences 试点。
- [x] 2026-06-02：确认 storage guard 当前失败项不是全部工作量，需要单独审计和持续治理。
- [x] 2026-06-02：完成 Phase A 首轮，新增工程基线扫描脚本并接入 architecture green suite。
- [x] 2026-06-02：完成 Phase B 首轮，迁移远程访问会员 sidecar、修正阅读分页缓存默认目录、清理 stale storage baseline，并复跑 storage guard 通过。
- [x] 2026-06-02：完成 Phase A 剩余规则报告，baseline 脚本输出 1500 行页面评估、`SharedPreferences` import 分类、presentation 平台判断报告；当前未分类 prefs import 为 0。
- [x] 2026-06-02：完成 Phase C 剩余首轮治理，分类 35 个生产 prefs import，`MinePagePreferencesService` 接管我的页隐藏项、启动目的地、布局模式 typed key，`UserProfilePage` 移除页面层直接 prefs 读取。
