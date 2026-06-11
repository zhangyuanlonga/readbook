# 项目文档清理清单

创建时间：2026-06-11  
用途：识别并清理无用/过期/误导性文档

---

## 一、需要删除的文档（7个）

### 1. 品牌相关（误导性）❌

**删除原因：** 品牌概念不符合实际，已误导 AI

- `brand_guidelines.md` - 品牌指南（"月光感"等虚构内容）
- `ui_ux_audit_and_design_system.md` - 包含品牌幻想的设计系统（已被 `ui_ux_design_system_actual.md` 替代）

### 2. 重复/过期文档 ❌

**删除原因：** 内容重复或已过期

- `ui_ux_comprehensive_audit_and_improvement_plan.md` - 内容太简单，已被其他详细文档覆盖

### 3. 临时/中间文档 ❌

**删除原因：** 只是中间产物，不再需要

- `api_cache_audit.md` - 临时审计文档，结论已整合到其他文档
- `api_cache_policy.md` - 内容太简单，已被 `storage_and_data_lifecycle_guide.md` 覆盖
- `user_data_isolation_policy.md` - 内容太简单，已被其他文档覆盖

### 4. 已完成的里程碑（可归档）❌

**建议：** 移到 `docs/archive/` 目录，而不是删除

- `ai_maintenance_execution_sequence_2026-06-04.md`
- `cache_governance_optimization_plan_2026-06-02.md`
- `codebase_engineering_governance_backlog_2026-06-02.md`
- `dependency_override_governance_matrix_2026-06-04.md`
- `desktop_engineering_productivity_milestone_2026-06-01.md`
- `desktop_ui_phase1_shell_mine_milestone_2026-05-31.md`
- 所有 `milestone_*` 文件（已完成的里程碑）
- 所有 `reader_*` 旧执行计划

---

## 二、保留的核心文档（按类别）

### A. 项目规范（必保留）✅

- `README.md` - 文档索引
- `project_core_principles.md` - 核心原则
- `development_architecture_guardrails.md` - 架构护栏
- `business_development_rules.md` - 业务开发规范
- `code_development_rules.md` - 代码开发规范
- `platform_development_rules.md` - 平台开发规范
- `ui_adaptive_design_rules.md` - UI 适配规范
- `business_and_code_standards_checklist.md` - 标准检查清单

### B. 存储治理（必保留）✅

- `storage_and_data_lifecycle_guide.md` - 存储与数据生命周期指南
- `storage_governance_improvement_plan.md` - 存储治理改进计划
- `storage_governance_baseline_matrix_2026-06-04.md` - 存储治理基线

### C. 用户状态与API（必保留）✅

- `user_session_api_governance_plan.md` - 用户状态与API治理计划

### D. UI/UX 设计体系（必保留）✅

- `ui_ux_design_system_actual.md` - 实际代码审计的设计规范 ⭐
- `ui_ux_review_standards_and_optimization.md` - 全面审查标准 ⭐
- `ui_ux_implementation_plan.md` - 实施计划
- `ui_ux_interaction_and_animation_guide.md` - 交互与动效指南
- `advanced_theme_experience_optimization.md` - 高级主题优化

### E. 书源功能（必保留）✅

- `book_source_import_improvement_plan.md` - 书源导入优化方案 ⭐
- `book_source_import_ui_design.md` - 书源导入 UI 设计 ⭐
- `book_source_ui_design_spec.md` - 书源 UI 设计规范
- `book_source_sharing_search_flow.md` - 书源分享搜索流程
- `book_source_mobile_optimization_summary.md` - 移动端优化总结

### F. 热更新（必保留）✅

- `hot_update_integration_plan.md` - 热更新接入方案
- `version_release_decision_guide.md` - 版本发布决策指南

### G. 任务分配（必保留）✅

- `task_allocation_guide.md` - 任务分配指南

---

## 三、执行操作

### 立即删除（7个文档）

```bash
# 删除品牌相关（误导性）
rm docs/brand_guidelines.md
rm docs/ui_ux_audit_and_design_system.md

# 删除重复/过期
rm docs/ui_ux_comprehensive_audit_and_improvement_plan.md

# 删除临时文档
rm docs/api_cache_audit.md
rm docs/api_cache_policy.md
rm docs/user_data_isolation_policy.md
```

### 归档已完成里程碑（可选）

```bash
# 创建归档目录
mkdir -p docs/archive/milestones_2026

# 移动已完成的里程碑文档
mv docs/milestone_*.md docs/archive/milestones_2026/
mv docs/*_2026-*.md docs/archive/milestones_2026/

# 但保留这些（仍在使用）
cp docs/archive/milestones_2026/storage_governance_baseline_matrix_2026-06-04.md docs/
cp docs/archive/milestones_2026/hot_update_integration_plan.md docs/
cp docs/archive/milestones_2026/version_release_decision_guide.md docs/
```

---

## 四、更新 README.md

删除/归档后，需要更新 `README.md`，移除已删除文档的引用。

---

## 五、文档统计

### 删除前
- 总文档数：65 个
- 核心文档：约 25 个
- 里程碑/临时：约 40 个

### 删除后
- 保留核心文档：约 25 个
- 归档文档：约 35 个
- 删除文档：7 个

---

## 六、建议

### 立即执行
1. ✅ 删除 7 个无用文档
2. ✅ 更新 README.md

### 可选操作
3. ⚠️ 归档已完成里程碑（移到 archive/ 目录）

---

**最后更新：** 2026-06-11