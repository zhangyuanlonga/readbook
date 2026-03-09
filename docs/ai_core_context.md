# AI 快速上下文（Core Context）

更新时间：2026-03-07  
目标：让 AI 在最短时间内读到“稳定且有用”的项目信息，减少被历史文档噪声干扰。

## 1. 分层读取策略

### L0（必读，先读这 3 份）

1. `docs/project_overview.md`：项目目标、范围边界、里程碑口径。
2. `docs/architecture.md`：核心模块与分层职责。
3. `docs/project_conventions.md`：代码/测试/提交流程规范。

### L1（进入任务前再读）

1. `docs/next_phase_plan.md`：当前阶段优先级与路线图。
2. `docs/plan_e_implementation.md`：Legado 兼容主线执行台账（任务级）。
3. `docs/legado_search_full_alignment_checklist.md`：搜索/换源主线执行清单。

### L2（按任务类型补充）

- UI/适配任务：`docs/phone_only_adaptive_strategy.md`
- 阅读体验任务：`docs/reader_content_quality_next_stage.md`、`docs/reader_font_system_implementation_plan.md`
- 规则/Bridge 语义：`docs/legado_native_bridge_mapping.md`

## 2. 默认不首读的文档

以下文档属于历史快照（`snapshot`），默认不作为 AI 首读上下文：

- `docs/archive/legado_compatibility_status_2026-02-28.md`
- `docs/archive/legado_search_regression_report_2026-03-02.md`
- `docs/archive/legado_search_compatibility_changes_2026-03-04.md`
- `docs/archive/legado_with_md3_source_rules_gap_analysis_2026-03-02.md`
- `docs/archive/legado_reader_tab_slider_impl_map_2026-03-06.md`

## 3. AI 读取建议（执行口径）

1. 先按 L0 获取稳定事实，不在历史报告里找主结论。
2. 再按任务类型进入 L1/L2，避免一次性扫全量 docs。
3. 若同主题多文档冲突，以 `docs/documentation_governance.md` 定义的主文档（SSOT）为准。
