# 文档整合映射（2026-03-07）

本文件用于回答三个问题：

1. 这批文档中哪些是“当前主入口”。
2. 哪些是“专题补充”，可按需读取。
3. 哪些已经是“历史记录”，默认不再持续更新。

## 1. 结论总览

- 当前主入口：4 份基线 + 4 份执行主线。
- 专题补充：17 份（按主题沉淀，继续保留）。
- 历史记录：6 份 dated 文档（默认停止增量维护）。

## 2. 主入口文档（继续维护）

| 文档 | 角色 | 备注 |
| --- | --- | --- |
| `docs/project_overview.md` | 项目基线 | 长期有效 |
| `docs/requirements.md` | 需求基线 | MVP 需求事实源 |
| `docs/architecture.md` | 架构基线 | 架构事实源 |
| `docs/project_conventions.md` | 工程规范 | 开发与提交流程事实源 |
| `docs/next_phase_plan.md` | 路线图主文档 | 当前阶段优先级 |
| `docs/plan_e_implementation.md` | Legado 兼容执行主文档 | 任务级进度台账 |
| `docs/legado_search_full_alignment_checklist.md` | 搜索专题执行主文档 | 搜索/换源对齐清单 |
| `docs/phone_only_adaptive_strategy.md` | 手机端适配主文档 | 当前适配口径 |

## 3. 专题补充文档（保留，但非主入口）

| 文档 | 归类 | 当前定位 |
| --- | --- | --- |
| `docs/chapter_cache_plan.md` | 阅读/缓存 | 专项计划 |
| `docs/legado_explore_compatibility_plan.md` | 兼容/发现页 | 专项计划 |
| `docs/legado_full_compatibility_plan.md` | 兼容/总策略 | 背景策略文档 |
| `docs/legado_native_bridge_mapping.md` | 兼容/桥接语义 | 规则语义对照 |
| `docs/legado_rule_full_compat_optimal_plan.md` | 兼容/策略 | 历史策略补充 |
| `docs/manga_source_compat_plan.md` | 兼容/漫画 | 专项计划 |
| `docs/reader_content_quality_next_stage.md` | 阅读体验 | 专项计划 |
| `docs/reader_font_system_implementation_plan.md` | 阅读体验 | 专项计划 |
| `docs/reader_uiux_optimization.md` | 阅读体验 | 设计思路 |
| `docs/responsive_adaptive_plan.md` | 适配/多端 | 未来扩展方案（平板/桌面） |
| `docs/adaptive_ui_refactor_plan.md` | 适配/执行记录 | 已执行项复盘 |
| `docs/source_list_scaling_plan.md` | 性能/书源列表 | 专项计划 |
| `docs/theme_plan.md` | 主题系统 | 专项计划 |
| `docs/ui_component_next_plan.md` | UI 组件 | 专项计划 |
| `docs/implementation_steps.md` | 历史实施步骤 | MVP 阶段参考 |
| `docs/PLAN.md` | 搜索优化旧方案 | 历史方案参考 |
| `docs/reference/README.md` | 外部规范索引 | 规范快照入口 |

## 4. 历史记录（默认不再继续维护）

| 文档 | 类型 | 处理原则 |
| --- | --- | --- |
| `docs/archive/legado_compatibility_status_2026-02-28.md` | 兼容度快照 | 保留追溯 |
| `docs/archive/legado_search_regression_manual_cases.md` | 手测用例快照 | 保留追溯 |
| `docs/archive/legado_search_regression_report_2026-03-02.md` | 回归报告 | 保留追溯 |
| `docs/archive/legado_search_compatibility_changes_2026-03-04.md` | 变更记录 | 保留追溯 |
| `docs/archive/legado_with_md3_source_rules_gap_analysis_2026-03-02.md` | 对比分析 | 保留追溯 |
| `docs/archive/legado_reader_tab_slider_impl_map_2026-03-06.md` | 实现对照 | 保留追溯 |

## 5. 同主题冲突处理（本次统一口径）

1. Legado 兼容主题：以 `docs/plan_e_implementation.md` 为执行主线。
2. 搜索主题：以 `docs/legado_search_full_alignment_checklist.md` 为执行主线。
3. 自适应主题：以 `docs/phone_only_adaptive_strategy.md` 为当前主线；`docs/responsive_adaptive_plan.md` 作为未来多端扩展预案。
4. 所有 dated 文档默认只记录历史，不承担“下一步计划”职责。

## 6. 后续建议（第二阶段，可选）

1. 新增历史快照统一存放到 `docs/archive/`，避免再次散落在根目录。
2. 给主文档增加统一头部元信息：`状态 / 负责人 / 最近更新时间 / 替代关系`。
3. 在发版流程里增加“文档入口更新检查”，避免再次发散。
