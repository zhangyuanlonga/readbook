# 桌面端工程提效与底座优化里程碑

创建日期：2026-06-01  
最近更新：2026-06-02  
适用范围：在 Android / iOS 移动端已成熟稳定的前提下，补齐 Web、Windows、macOS、Linux 的桌面端工程底座、开发效率和 UI 回归能力。  
最高原则：**移动端为受保护基线；桌面端通过新增底座、分流组件和平台适配层演进，不反向改造已稳定移动端。**

关联专项：更完整的代码复杂度、存储偏好、模型样板、平台判断与响应式规范治理，见 [代码库工程治理专项 Backlog](codebase_engineering_governance_backlog_2026-06-02.md)。

## 0. 移动端保护红线

- [x] Android / iOS 现有 UI、交互、业务流程、状态流和数据路径默认不修改。
- [x] 桌面端新增能力优先放在 shell、adapter、facade、desktop view、adaptive wrapper 中。
- [x] 共享底层如必须调整，必须先说明移动端影响面，并补 Android / iOS 回归验证。
- [x] 无法证明移动端不受影响的改动，不进入桌面端优化任务。
- [x] 不为引入新库而替换已稳定移动端实现。
- [x] 不引入第二套响应式体系覆盖现有 `AppLayout + AppAdaptiveMetrics`。

## 1. 当前工程基线

- [x] `lib` 约 489 个 Dart 文件，约 16.9 万行代码。
- [x] `test` 约 234 个 Dart 测试文件。
- [x] 1000 行以上 Dart 文件约 39 个，主要集中在阅读器、书架、主题编辑、详情页。
- [x] 手写 `toJson/fromJson/copyWith` 较多，新增模型需要逐步减少样板代码。
- [x] `SharedPreferences` 调用较分散，需要类型安全偏好设置层集中治理。
- [x] `AppLayout + AppAdaptiveMetrics` 已全局接入，属于现有响应式底座，应继续增强而非替换。
- [x] 桌面壳层已具备侧边栏和顶部栏，后续重点是页面级桌面布局和平台能力补齐。

## 2. 引库原则

- [x] 只引入能明确减少复杂度、提升稳定性、补齐平台能力或提升回归效率的库。
- [x] 能用现有底座小步增强解决的问题，不新增大框架。
- [x] 新库先用于新增代码或低风险试点，不全量迁移旧代码。
- [x] UI 组件库默认不引入，避免与现有 Material、自研组件和 Stitch 设计体系混杂。
- [x] 依赖进入项目前必须确认维护活跃度、平台支持、许可证和迁移成本。

## 3. Phase 1：桌面平台能力补齐

- [x] 引入 `window_manager`。
- [x] 配置桌面最小窗口尺寸，例如 `960x640` 或 `1024x680`。
- [x] 配置窗口标题、启动居中、显示时机。
- [ ] 评估是否需要窗口尺寸和位置记忆。
- [ ] 验证 macOS / Windows / Linux 启动和窗口缩放行为。
- [x] 保持移动端入口不受 `window_manager` 影响。

## 4. Phase 2：响应式内部底座增强

- [x] 保留现有 `AppLayout + AppAdaptiveMetrics`。
- [x] 增加更清晰的桌面宽屏规则，例如 `desktop / wideDesktop / ultraWideDesktop`。
- [x] 新增内部组件 `AdaptiveSplitBody`，支持移动单列、桌面左右分栏。
- [x] 新增内部组件 `AdaptiveOverflowToolbar`，支持工具按钮按优先级收进“更多”。
- [ ] 优先接入首页、书架、详情页、阅读记录页。
- [x] 为新增自适应组件补 widget test。
- [x] 确认 `< 600` 宽度继续走现有移动端布局。

## 5. Phase 3：模型与状态样板代码治理

- [x] 引入 `freezed` / `freezed_annotation`，先用于状态和配置快照对象。
- [x] 新增 DTO、配置对象、状态对象优先评估 `freezed`；涉及 JSON 序列化时，等项目 SDK 升级窗口再评估 `json_serializable`。
- [ ] 新增 Riverpod provider 优先评估 `riverpod_generator`。
- [x] 不全量迁移旧模型，避免大面积生成文件和回归风险。
- [x] 先选择一个低风险新模块做试点：`AppShellNavigationState` 与 `AppShellNavigationSnapshot`。
- [x] 形成模型规范：纯 UI 临时对象可手写；跨 Provider/Service 传递、需要 `copyWith`/值相等/default 的状态或配置快照优先用 `freezed`。
- [x] 对已有复杂模型只在功能改动时顺手治理，不做纯机械迁移。
- [x] 暂缓直接引入 `json_serializable`：当前项目 SDK 为 Dart 3.7，较新生成器会提示 Dart 3.8 language version 要求；不为试点抬高移动端构建基线。

## 6. Phase 4：Preferences 与本地配置治理

- [x] 盘点 `SharedPreferences` key 分散情况：已有 `AppPreferencesService` 与 `tool/check_storage_governance_guard.dart`，但业务模块内仍存在分散读写。
- [x] 建立类型安全 Preferences 访问层试点：新增 `PreferenceKey<T>`。
- [x] 集中管理 key、默认值、迁移逻辑和读写方法：先覆盖 shell navigation 配置。
- [x] 新增配置禁止直接散落 `prefs.getString/setString`：先在文档约束，后续再扩展 guardrail 自动检查。
- [x] 逐步迁移高频配置：首批完成导航 shell 配置；主题、界面字体、启动目的地后续迁移。
- [x] 所有迁移必须保留旧 key 兼容读取和测试。
- [x] 处理 storage guard 既有待审计项：`remote_access_snapshot_service.dart` 的 JSON prefs sidecar 与 `reader_pagination_cache_service.dart` 的临时目录使用。

## 7. Phase 5：桌面快捷键与专业交互

- [ ] 梳理桌面快捷键规范。
- [ ] 阅读器优先覆盖翻页、目录、设置、搜索。
- [ ] 全局优先覆盖搜索、设置、返回。
- [ ] 评估并引入 `hotkey_manager`，或先实现应用内快捷键层。
- [ ] 输入框、编辑器和 WebView 聚焦时不得误触全局快捷键。
- [ ] 增加快捷键测试或手动回归清单。

## 8. Phase 6：复杂页面拆分治理

- [x] Phase 6 是跨端复杂度治理，不是移动端重构。
- [x] 移动端稳定视图只做等价搬迁，不做视觉、交互和业务行为改造。
- [x] 优先拆分跨端混杂文件，而不是纯移动端稳定文件。
- [x] 桌面端新增 UI 拆入独立 desktop/adaptive/widget 组件。
- [ ] 优先拆分 `reader_page.dart`。
- [ ] 优先拆分 `bookshelf_page.dart`。
- [ ] 优先拆分 `reader_page_settings_sheet.dart`。
- [ ] 优先拆分 `advanced_theme_list_page.dart` 和 `advanced_theme_editor_page.dart`。
- [x] 先拆分 `home_page.dart` 中移动/桌面 dashboard 布局壳。
- [x] 继续拆分 `home_page.dart` 中首页指标 pill 与阅读目标弧线 painter 展示组件。
- [x] 按职责拆分：状态控制、布局、工具栏、弹层、卡片组件。
- [x] 每次只拆一个小区域，保持行为不变。
- [x] 拆分后补最小 widget test 或 service test。
- [ ] 建立“页面文件超过 1500 行需要拆分评估”的规则。

## 9. Phase 7：桌面 UI 回归保障

- [ ] 评估 `golden_toolkit` 或项目内截图回归方案。
- [ ] 先覆盖登录页、首页、书架页、我的页。
- [ ] 桌面尺寸优先覆盖 `1024 / 1440 / 1920`。
- [ ] smoke test 继续负责“不崩”，截图测试负责“比例不跑”。
- [ ] 将 Stitch 设计稿关键比例和状态写入 UI regression checklist。
- [ ] 截图回归只覆盖桌面关键页，不扩大到所有移动端页面。

## 10. Phase 8：性能专项治理

- [ ] 建立性能基线：书架滚动、搜索结果、阅读器翻页、EPUB/TXT 解析。
- [ ] 优先使用 Flutter DevTools 找真实瓶颈。
- [ ] 如果列表构建掉帧，再评估 `keframe` 等分帧方案。
- [ ] 如果解析阻塞主线程，优先使用 isolate / compute 或现有解析服务拆分。
- [ ] 不为“可能性能更好”提前引入性能库。
- [ ] 性能优化必须保留正确性测试和可回滚路径。

## 11. Phase 9：视觉体验增强

- [ ] 评估空状态、加载状态、启动页是否需要动画。
- [ ] 有明确 AE / Lottie 资产时引入 `lottie`。
- [ ] 需要交互式矢量动画时再评估 `rive`。
- [ ] 阅读主流程保持克制，动画只用于启动、加载、空状态和反馈。
- [ ] 动画不得影响阅读器帧率、输入响应和注意力。

## 12. 建议执行顺序

- [ ] 第一批：`window_manager`、`AdaptiveSplitBody`、`AdaptiveOverflowToolbar`。
- [ ] 第二批：Preferences 类型安全层、桌面页面截图回归。
- [ ] 第三批：`freezed/json_serializable/riverpod_generator` 新模块试点。
- [ ] 第四批：快捷键、复杂页面拆分、性能专项。

## 13. 不建议当前引入

- [ ] 不引入 `dynamic_layouts` 替换现有响应式底座。
- [ ] 不引入大型 UI 组件库替换现有视觉体系。
- [ ] 不引入 `common_utils` 这类宽泛工具库作为通用依赖。
- [ ] 不提前引入性能专项库，先用真实性能数据驱动。

## 14. 执行记录

- [x] 2026-06-01：完成 Phase 0 基线与引库原则落文档。
- [x] 2026-06-01：完成 Phase 1 首轮落地，引入 `window_manager` 并通过 `DesktopWindowBootstrap` 隔离桌面平台初始化。
- [x] 2026-06-01：完成 Phase 2 首轮落地，新增桌面宽屏等级、`AdaptiveSplitBody`、`AdaptiveOverflowToolbar` 和基础 widget test。
- [x] 2026-06-01：启动 Phase 6，明确“跨端复杂度治理，不是移动端重构”，并将首页移动/桌面 dashboard 布局壳抽入独立 widget。
- [x] 2026-06-02：继续 Phase 6，抽离首页指标展示与阅读目标弧线 painter，并补充独立 widget test。
- [x] 2026-06-02：完成 Phase 3 首轮试点，引入 `freezed`，将 `AppShellNavigationState` 与 `AppShellNavigationSnapshot` 改为生成不可变对象，并补充状态测试。
- [x] 2026-06-02：完成 Phase 4 首轮试点，新增 `PreferenceKey<T>` 并将 shell navigation 偏好设置改为类型安全 key 读写，保留旧 key 兼容测试。
- [x] 2026-06-02：评估并暂缓直接引入 `json_serializable`，避免为了试点抬高 Dart 3.7 项目的 SDK 构建基线。
