# Selune 项目文档入口

更新时间：2026-06-02

本目录只保留对后续开发有决策价值的文档：核心方针、开发规则、平台规则、当前里程碑、长期回归清单。历史草稿、重复计划、一次性工作流文档不再保留，避免后续开发者在旧口径里迷路。

## 必读规则

- [项目核心方针](project_core_principles.md)
- [业务开发规则](business_development_rules.md)
- [代码与架构编写规则](code_development_rules.md)
- [UI 与自适应设计规则](ui_adaptive_design_rules.md)
- [Web / Desktop / Mobile 平台规则](platform_development_rules.md)
- [项目架构统一计划](project_architecture_unification_plan.md)
- [多端架构开发约束](development_architecture_guardrails.md)

## 当前里程碑

- [里程碑 01：多端底座绿线与在线阅读闭环](milestone_01_multiplatform_foundation_online_reading_2026-06-02.md)
- [里程碑 02：桌面 UI 与交互体验成型](milestone_02_desktop_ui_interaction_2026-06-02.md)
- [里程碑 03：本地内容与资源能力多端化](milestone_03_local_content_resource_multiplatform_2026-06-02.md)
- [缓存治理优化计划](cache_governance_optimization_plan_2026-06-02.md)
- [代码库工程治理专项 Backlog](codebase_engineering_governance_backlog_2026-06-02.md)
- [桌面端工程提效与底座优化里程碑](desktop_engineering_productivity_milestone_2026-06-01.md)
- [桌面端 UI 第一里程碑：外壳导航与我的页展示基线](desktop_ui_phase1_shell_mine_milestone_2026-05-31.md)

## 业务与专项规则

- [Web / Desktop 业务逻辑兼容规则](web_desktop_business_logic_compatibility_rules_2026-05-31.md)
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
