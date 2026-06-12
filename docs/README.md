# 项目文档索引

**最后更新：** 2026-06-11  
**文档总数：** 59 个（已分类整理）

---

## 📁 文档目录结构

```
docs/
├── standards/           # 开发规范（7个）
├── governance/          # 治理计划（9个）
├── ui_ux/              # UI/UX设计（5个）
├── features/           # 功能文档（17个）
│   ├── book_source/    # 书源功能（5个）
│   ├── reader/         # 阅读器（7个）
│   ├── ui_component/   # UI组件（4个）
│   └── multiplatform/  # 多平台（1个）
├── operations/         # 运维发版（3个）
└── archive/            # 归档文档（15个）
    └── milestones/     # 已完成里程碑
```

---

## 📋 核心规范文档（standards/）

### 开发规范

- [项目核心原则](standards/project_core_principles.md) - 项目的核心价值观和设计原则
- [开发架构护栏](standards/development_architecture_guardrails.md) - 架构设计的边界和约束
- [业务开发规范](standards/business_development_rules.md) - 业务逻辑开发规范
- [代码开发规范](standards/code_development_rules.md) - 代码风格和质量标准
- [平台开发规范](standards/platform_development_rules.md) - 跨平台开发规范
- [UI 自适应设计规则](standards/ui_adaptive_design_rules.md) - 响应式 UI 适配规范
- [业务与代码标准检查清单](standards/business_and_code_standards_checklist.md) - 开发自查清单

---

## 🏗️ 治理计划（governance/）

### 存储治理

- [存储与数据生命周期指南](governance/storage_and_data_lifecycle_guide.md) ⭐ **核心**：数据存储规范、生命周期管理
- [存储治理改进计划](governance/storage_governance_improvement_plan.md) - 存储问题修复和优化
- [存储治理规范](governance/storage_governance_spec_2026-05-21.md) - 存储使用规范
- [存储治理基线矩阵](governance/storage_governance_baseline_matrix_2026-06-04.md) - 存储治理快照
- [存储清单](governance/storage_inventory_2026-05-20.md) - 存储使用盘点
- [存储升级验证](governance/storage_upgrade_validation_2026-05-21.md) - 存储迁移验证

### 其他治理

- [用户状态与 API 治理计划](governance/user_session_api_governance_plan.md) ⭐ **重要**：用户登录状态、API 请求治理
- [项目架构统一计划](governance/project_architecture_unification_plan.md) - 架构统一方向
- [搜索模式资源治理设计](governance/search_modes_resource_governance_design_2026-06-02.md) - 搜索功能治理

---

## 🎨 UI/UX 设计体系（ui_ux/）

**📚 入口文档：** [UI/UX 设计规范](ui_ux/README.md) - 设计体系索引和快速参考

### 核心文档

- [Flutter 多端适配设计规范](ui_ux/multiplatform_adaptive_design.md) ⭐ **Flutter必读**：响应式断点、平台适配、自适应组件
- [UI/UX 全面审查标准与优化方向](ui_ux/ui_ux_review_standards_and_optimization.md) ⭐ **可执行清单**：5大审查维度、全页面审查模板
- [UI/UX 设计体系总结（基于实际代码）](ui_ux/ui_ux_design_system_actual.md) - 实际代码审计：圆角、间距、Material 3
- [交互规范与动效指南](ui_ux/ui_ux_interaction_and_animation_guide.md) - 操作反馈、动画标准
- [UI/UX 改进实施计划](ui_ux/ui_ux_implementation_plan.md) - ⚠️ 暂缓执行：4阶段改进计划

---

## 🚀 功能文档（features/）

### 书源功能（features/book_source/）

- [书源导入功能优化方案](features/book_source/book_source_import_improvement_plan.md) ⭐ **进行中**：链接/文件/粘贴导入
- [书源导入 UI 设计详细说明](features/book_source/book_source_import_ui_design.md) ⭐ **给 Codex**：完整实现代码
- [书源 UI 设计规范](features/book_source/book_source_ui_design_spec.md) - 书源页面设计规范
- [书源分享搜索流程](features/book_source/book_source_sharing_search_flow.md) - 书源分享和搜索
- [书源移动端优化总结](features/book_source/book_source_mobile_optimization_summary.md) - 移动端优化

### 阅读器（features/reader/）

- [高级主题体验优化方案](features/reader/advanced_theme_experience_optimization.md) - **核心付费功能**：主题市场、付费转化
- [阅读器自动阅读执行计划](features/reader/reader_auto_read_execution_plan_2026-05-24.md)
- [阅读器本地内容重构执行计划](features/reader/reader_local_content_refactor_execution_plan_2026-05-21.md)
- [阅读器多模态架构重构执行计划](features/reader/reader_multimodal_architecture_refactor_execution_plan_2026-05-25.md)
- [阅读器多模态开发者笔记](features/reader/reader_multimodal_developer_notes_2026-05-25.md)
- [阅读器多模态手动回归检查清单](features/reader/reader_multimodal_manual_regression_checklist_2026-05-25.md)
- [阅读器多模态性能和回滚基线](features/reader/reader_multimodal_performance_and_rollback_baseline_2026-05-25.md)
- [本地阅读导入解析标准化计划](features/reader/local_reading_import_parse_standardization_plan_2026-06-07.md)

### UI 组件（features/ui_component/）

- [页面 UI 组件治理计划](features/ui_component/page_ui_component_governance_plan_2026-05-12.md)
- [主题语义重构计划](features/ui_component/theme_semantic_refactor_plan_2026-05-21.md)
- [全项目页面统一审计计划](features/ui_component/full_project_page_unification_audit_plan_2026-06-06.md)
- [全局页面路由清单](features/ui_component/global_page_route_inventory_2026-05-12.md)

### 多平台（features/multiplatform/）

- [多平台业务逻辑兼容规则](features/multiplatform/multiplatform_business_logic_compatibility_rules_2026-06-03.md)

---

## 🔧 运维与发版（operations/）

- [热更新接入方案](operations/hot_update_integration_plan.md) ⭐ **核心**：Shorebird 热更新接入
- [版本发布决策指南](operations/version_release_decision_guide.md) ⭐ **重要**：正常发版 vs 热更新决策
- [任务分配指南](operations/task_allocation_guide.md) - AI 协作任务分配

---

## 📦 归档文档（archive/milestones/）

### 已完成里程碑（15个）

- milestone_01 ~ milestone_06：项目里程碑文档
- 各类已完成的治理和优化计划
- 历史执行计划和基线文档

**说明：** 归档文档保留作为历史记录，不再主动更新

---

## 📝 文档管理

### 主目录文档（3个）

- **README.md** - 本文档，文档索引
- **document_cleanup_checklist.md** - 文档清理清单
- **project_documentation_full_audit.md** - 项目文档全面审查报告

---

## 🎯 快速导航

### 新成员入门
1. [项目核心原则](standards/project_core_principles.md) - 理解项目价值观
2. [开发架构护栏](standards/development_architecture_guardrails.md) - 了解架构约束
3. [业务与代码标准检查清单](standards/business_and_code_standards_checklist.md) - 开发自查

### 开发规范
- [代码开发规范](standards/code_development_rules.md) - 代码风格
- [业务开发规范](standards/business_development_rules.md) - 业务逻辑
- [平台开发规范](standards/platform_development_rules.md) - 跨平台
- [UI 自适应设计规则](standards/ui_adaptive_design_rules.md) - UI 适配

### 核心治理
- [存储与数据生命周期指南](governance/storage_and_data_lifecycle_guide.md) - 数据管理
- [用户状态与 API 治理计划](governance/user_session_api_governance_plan.md) - API 治理

### UI/UX 设计
- [UI/UX 设计规范](ui_ux/README.md) - 设计体系入口
- [多端适配规范](ui_ux/multiplatform_adaptive_design.md) ⭐ **Flutter必读** - 响应式断点、平台适配
- [全面审查标准](ui_ux/ui_ux_review_standards_and_optimization.md) - 审查清单
- [设计体系总结](ui_ux/ui_ux_design_system_actual.md) - 设计规范

### 进行中功能
- [书源导入优化](features/book_source/book_source_import_improvement_plan.md) - 正在开发
- [书源导入 UI 设计](features/book_source/book_source_import_ui_design.md) - 开发指南

### 运维发版
- [热更新接入方案](operations/hot_update_integration_plan.md) - Shorebird
- [版本发布决策指南](operations/version_release_decision_guide.md) - 发版决策

---

## 📊 文档统计

- **总文档数：** 61 个（+1个多端适配文档）
- **核心规范：** 7 个
- **治理计划：** 9 个
- **UI/UX 设计：** 6 个（+1个多端适配）
- **功能文档：** 18 个
- **运维文档：** 3 个
- **归档文档：** 16 个
- **其他：** 3 个

---

## 🔄 文档更新记录

### 2026-06-11
- ✅ 项目文档整理与清理
  - 删除 10 个遗留配置文件（.workflow/、多余icon配置、lib/src/）
  - 新增 CLAUDE.md 项目指南
  - 新增 scripts/README.md 构建脚本文档
- ✅ UI/UX 文档整理与补充
  - 移动高级主题文档到 features/reader/
  - 归档审查报告到 archive/
  - 新增 ui_ux/README.md 入口文档
  - 🆕 新增 multiplatform_adaptive_design.md Flutter多端适配规范
  - 更新实施计划状态（标注"暂缓执行"）
- ✅ 历史整理记录
  - 删除 6 个无用/误导文档
  - 整理文档目录结构（分类到子目录）
  - 归档 15 个已完成里程碑文档
  - 新增书源导入功能文档
  - 更新 UI/UX 实施计划（恢复推荐依赖）

### 2026-06-10
- 新增 UI/UX 设计体系文档
- 新增存储与数据治理文档
- 新增用户状态与 API 治理文档

---

**维护说明：**
- 每次新增/删除文档时更新此索引
- 归档文档不需要更新索引
- 保持分类清晰，便于查找

**最后更新：** 2026-06-11