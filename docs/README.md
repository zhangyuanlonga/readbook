# Selune 项目文档入口

更新时间：2026-06-04

本目录只保留对后续开发有决策价值的文档：核心方针、开发规则、平台规则、当前里程碑、长期回归清单。历史草稿、重复计划、一次性工作流文档不再保留，避免后续开发者在旧口径里迷路。

## 当前执行口径

后续里程碑任务不再只按“做完某个功能”拆分，默认按 **业务链兼容 + 测试验收** 拆分。也就是说，一个任务写成“兼容 Web / Desktop 登录”时，完成标准不是 Web / Desktop 页面能点通，而是要同时回答：

- 移动端、Web、Desktop 的业务设计是否合理。
- Android / iOS 既有登录、会话恢复、退出登录是否不回退。
- Web 是否可构建、可刷新恢复，并且不支持能力有清晰降级。
- macOS / Windows / Linux 是否按桌面习惯处理窗口、键鼠、外部浏览器、凭证和退出登录。
- 代码是否遵守分层、capability、adapter、route helper、storage 和注释规则。
- 自动测试、构建、手工 smoke 或未验证原因是否记录完整。

因此，“当前里程碑”中的每一项都应理解为兼容任务和测试任务的组合。任务执行时必须同时检查三条线：

- **业务合理线**：入口、状态、错误、降级、会话、数据落点和用户路径合理。
- **多端兼容线**：Android、iOS、Web JS、macOS、Windows、Linux 的能力边界和影响面清楚。
- **代码正确线**：架构分层、平台隔离、测试、构建、中文维护注释和文档同步到位。

## 任务收尾矩阵

每个功能、兼容或治理任务收尾时，至少记录以下内容。没有条件真实验证的平台，必须写明原因和后续补验方式，不能用“未涉及”跳过。

| 项目 | 必填结论 |
| --- | --- |
| 业务链 | 本次影响搜索、详情、阅读、书架、登录、设置、本地内容、缓存等哪条链 |
| 修改范围 | 页面、provider、service、repository、storage、route、theme、platform capability 是否修改 |
| Android | 已验证 / 代码级不回退 / 未验证原因 / 发布前补验要求 |
| iOS | 已验证 / 代码级不回退 / 未验证原因 / 发布前补验要求 |
| Web JS | 构建、刷新恢复、路由、浏览器存储、不支持能力降级 |
| macOS | 构建、启动、窗口、键鼠、文件路径、外部打开、凭证能力 |
| Windows | 已验证 / CI 补验 / 未验证原因，不能用 macOS 结果代替 |
| Linux | 已验证 / CI 补验 / 未验证原因，不能用 macOS 结果代替 |
| 测试与构建 | flutter analyze、目标单测、Web build、桌面构建、移动端构建或 smoke |
| 注释与文档 | 新增或修改的复杂代码是否有标准中文维护注释，相关 docs 是否同步 |

## 必读规则

- [项目核心方针](project_core_principles.md)
- [业务开发规则](business_development_rules.md)
- [代码与架构编写规则](code_development_rules.md)
- [UI 与自适应设计规则](ui_adaptive_design_rules.md)
- [Web / Desktop / Mobile 平台规则](platform_development_rules.md)
- [Web / Desktop / Mobile 业务逻辑兼容规则](multiplatform_business_logic_compatibility_rules_2026-06-03.md)
- [项目架构统一计划](project_architecture_unification_plan.md)
- [多端架构开发约束](development_architecture_guardrails.md)

## 当前里程碑

- [里程碑 01：多端底座绿线与在线阅读闭环](milestone_01_multiplatform_foundation_online_reading_2026-06-02.md)
- [里程碑 02：多端 UI 与桌面交互体验成型](milestone_02_desktop_ui_interaction_2026-06-02.md)
- [里程碑 03：本地内容与资源能力多端化](milestone_03_local_content_resource_multiplatform_2026-06-02.md)
- [里程碑 04：成熟库替代与架构样板治理](milestone_04_mature_library_architecture_governance_2026-06-03.md)
- [缓存治理优化计划](cache_governance_optimization_plan_2026-06-02.md)
- [代码库工程治理专项 Backlog](codebase_engineering_governance_backlog_2026-06-02.md)
- [桌面端工程提效与底座优化里程碑](desktop_engineering_productivity_milestone_2026-06-01.md)
- [桌面端 UI 第一里程碑：外壳导航与我的页展示基线](desktop_ui_phase1_shell_mine_milestone_2026-05-31.md)

## 业务与专项规则

- [页面 UI 组件治理任务计划](page_ui_component_governance_plan_2026-05-12.md)
- [存储治理定版规范](storage_governance_spec_2026-05-21.md)
- [存储升级验证清单](storage_upgrade_validation_2026-05-21.md)
- [主题语义化改造计划](theme_semantic_refactor_plan_2026-05-21.md)
- [品牌视觉规范](brand_guidelines.md)

## 阅读器专项

- [阅读器本地内容重构执行计划](reader_local_content_refactor_execution_plan_2026-05-21.md)
- [阅读器自动阅读执行计划](reader_auto_read_execution_plan_2026-05-24.md)
- [阅读器多模态架构重构执行计划](reader_multimodal_architecture_refactor_execution_plan_2026-05-25.md)
- [阅读器多模态手工回归清单](reader_multimodal_manual_regression_checklist_2026-05-25.md)
- [阅读器多模态开发备注](reader_multimodal_developer_notes_2026-05-25.md)
- [阅读器多模态性能与回滚基线](reader_multimodal_performance_and_rollback_baseline_2026-05-25.md)

## 工程清单

- [全局页面路由清单](global_page_route_inventory_2026-05-12.md)
- [存储盘点](storage_inventory_2026-05-20.md)

## 文档维护规则

- 新增长期规则时，优先补充到“必读规则”中的文档。
- 新增阶段任务时，使用“当前里程碑”文档；完成后只保留对后续仍有价值的结论。
- 新文档必须在本入口登记，否则视为临时草稿。
- 过期草案、重复清单、一次性流程文档应删除，不另建“归档垃圾桶”。
- 删除文档前先确认没有工具脚本依赖它；若脚本依赖，应先补齐替代文档。
