# 文档治理规则（Documentation Governance）

更新时间：2026-03-07
适用范围：`/docs` 全部文档

## 1. 目标

- 降低同主题多版本并存带来的维护成本。
- 保证每个主题只有一个“主文档（Single Source of Truth）”。
- 把阶段报告与长期规范分层，避免计划文档失控增长。

## 2. 文档类型与状态

| 类型 | 状态标记 | 用途 | 命名建议 |
| --- | --- | --- | --- |
| 基线文档 | `baseline` | 长期有效的项目事实（目标、架构、规范） | 无日期后缀，如 `architecture.md` |
| 计划文档 | `active` | 当前正在推进的执行方案 | `<topic>_plan.md` |
| 变更记录 | `snapshot` | 某次改造的变更说明 | `<topic>_changes_YYYY-MM-DD.md` |
| 回归报告 | `snapshot` | 某次验证结果与风险 | `<topic>_report_YYYY-MM-DD.md` |
| 调研对照 | `snapshot` | 对外部项目或方案的阶段分析 | `<topic>_analysis_YYYY-MM-DD.md` |
| 历史归档 | `archived` | 已结束阶段资料，仅供追溯 | 保留原名并在索引标注历史 |

## 3. 单一事实来源规则（SSOT）

同一主题只允许一个主文档，其他文件仅作补充记录。

- Legado 全兼容主文档：`docs/plan_e_implementation.md`
- 搜索/换源主文档：`docs/legado_search_full_alignment_checklist.md`
- 手机端自适应主文档：`docs/phone_only_adaptive_strategy.md`
- 项目基线主文档：`project_overview/requirements/architecture/project_conventions`

当出现新版本计划时，优先更新主文档，不新建平行计划文件。

## 4. 新增文档准入规则

新增文档前必须先判断：

1. 是否已有同主题主文档可直接追加更新。
2. 是否属于一次性快照（应使用日期后缀并标注 `snapshot`）。
3. 是否会替代已有主文档（若是，必须在旧文档头部写明“已被哪个文档替代”）。

仅在以下情况允许新建“计划文档”：

- 主题全新且现有主文档无法承载。
- 原计划已结束并明确进入下一阶段，且范围变化超过 50%。

## 5. 更新与归档流程

1. 先更新 `docs/README.md`（统一入口）。
2. 在对应主文档更新“当前状态/最近更新时间”。
3. 若产生阶段快照，新增日期文件并在主文档追加链接。
4. 阶段结束后，把快照文件移动到 `docs/archive/` 并标注为历史记录（不继续修改）。

## 6. 最小维护要求

每次迭代（功能完成或版本发布）至少完成：

1. 更新 `docs/README.md` 的状态标记。
2. 更新对应主题主文档的进度与结论。
3. 新增的 dated 文档必须在 `docs/README.md` 可检索。

## 7. 反例（禁止）

- 同一主题连续创建 `*_plan_v2.md`、`*_new_plan.md`、`*_final_plan.md`。
- 报告文档承担长期计划职责。
- 文档已失效但仍在 `README` 作为首选入口。
