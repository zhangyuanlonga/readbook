# Selune 项目文档入口

更新时间：2026-06-06

本目录只保留对后续开发有决策价值的文档：核心方针、开发规则、平台规则、当前里程碑、长期回归清单。历史草稿、重复计划、一次性工作流文档不再保留，避免后续开发者在旧口径里迷路。

## 当前执行口径

当前里程碑已经重排并扩展为 6 个阶段：M1 是已完成的成熟库与架构治理基线，M2 是已完成验收的手搓实现替换与稳定性治理，M3 是当前优先的核心业务链多端兼容与验收，M4 聚焦本地内容、资源与性能，M5 聚焦长期门禁、发布验收与 AI 接力，M6 是阅读器全平台可用与架构收敛专项。旧 M1-M3 已删除，不再作为执行入口；旧 M4 已升为新 M1，旧 M5 已升为新 M2。

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

多端 UI 的长期口径固定为：项目用 **响应式布局** 作为实现手段，通过断点、弹性布局和平台能力判断，让界面随可用空间变化；最终目标是形成 **自适应应用**，也就是 Android / iOS、Web 大屏、macOS、Windows、Linux 都有符合自身使用习惯的交互体验。桌面端和 Web 大屏必须重点处理窗口拖拽、宽窄变化、侧边栏宽度、顶栏工具折叠和内容列数变化；移动端必须优先保持 Android / iOS 已成熟的触控路径、导航、弹层和安全区体验。后续桌面端任务不能把移动端页面简单拉宽，移动端任务也不能反向依赖桌面端侧边栏、顶栏或键鼠入口。

## 任务拆分规则

后续开发或 AI 接力时，只领取带编号的最小 checkbox 任务，例如 `M2-04-03`。不要领取“完成 M2-04”或“完成整个 M3”这种大任务。

- [x] 每个里程碑必须把阶段任务拆成可单独完成的小任务。
- [x] 每个小任务前必须有 `- [ ]` 或 `- [x]`，方便后续继续执行。
- [x] 一个小任务应该能在一次开发回合内完成、验证并记录收尾。
- [x] 如果执行时发现小任务仍然过大，先拆分文档，再继续做代码。
- [x] 文档可以写得粗糙，但任务边界必须清楚，不能把很多隐藏小任务塞进一个 checkbox。

## 单端任务保护规则

2026-06-04 书架桌面端工具栏调整暴露出一个教训：即使代码文件是移动端和桌面端共用的，执行“桌面端”任务时也不能为了复用、抽取或顺手整理而改动移动端交互路径。后续所有单端任务必须先锁定适用端和排除端。

- [x] 任务写明“桌面端 / Web / macOS / Windows / Linux”时，默认排除 Android / iOS 的 AppBar、底部导航、底部弹层、触控手势、移动端菜单和移动端业务入口。
- [x] 任务写明“移动端”时，默认排除桌面端侧边栏、顶栏、键鼠菜单、popover、窗口布局和桌面专属快捷路径。
- [x] 如果必须修改共用页面文件，只允许新增被断点、capability、adapter 或明确平台语义门禁保护的分支；不得把移动端已有逻辑改成新的共享逻辑来服务桌面端。
- [x] 不为了桌面端复用去重写移动端已稳定的排序弹层、搜索入口、更多菜单、选择模式、导航返回或数据路径。
- [x] 发现实现需要触碰排除端时，先停下说明影响面；除非用户明确同意，否则不继续扩大范围。
- [x] 收尾必须做 diff 审计：列出实际改动文件，并确认移动端专属文件或移动端交互路径是否保持原样。

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
| 测试与构建 | flutter analyze、目标单测、Web build、桌面构建、移动端构建或 smoke；如果本次跑了任一桌面 build，必须同步记录 Android / iOS build 结果或真实阻塞原因 |
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

里程碑按“已完成治理基线 -> 手搓替换 -> 业务兼容 -> 本地内容资源 -> 长期门禁 -> 阅读器全平台专项”推进。M2 已完成验收，当前优先执行 M3；M6 用于承接阅读器全平台可用和架构收敛任务，执行时仍必须继承 M3 / M4 / M5 的业务链、多端和门禁规则。Windows 并行环境正在处理 M3 登录 / session 可拆部分，本机后续领取任务时应避开同一文件和同一业务状态链。每次只领取一个最小 checkbox 任务。

- [里程碑 01：已完成的成熟库与架构治理基线](milestone_01_completed_mature_library_architecture_governance_2026-06-04.md)
- [里程碑 02：手搓实现替换与稳定性治理](milestone_02_handrolled_replacement_stability_2026-06-04.md)
- [M2 手搓与不稳定实现候选看板](m2_handrolled_stability_candidate_backlog_2026-06-04.md)
- [依赖 Override 治理矩阵](dependency_override_governance_matrix_2026-06-04.md)
- [Storage Guard Baseline 治理矩阵](storage_governance_baseline_matrix_2026-06-04.md)
- [里程碑 03：核心业务链多端兼容与验收](milestone_03_multiplatform_business_compatibility_acceptance_2026-06-04.md)
- [里程碑 04：本地内容、资源与性能成熟化](milestone_04_local_content_resource_performance_maturity_2026-06-04.md)
- [里程碑 05：长期门禁、发布验收与 AI 接力](milestone_05_long_term_guard_ai_handoff_2026-06-04.md)
- [里程碑 06：阅读器全平台可用与架构收敛](milestone_06_reader_cross_platform_availability_2026-06-05.md)
- [AI 后续执行序列与维护优先级](ai_maintenance_execution_sequence_2026-06-04.md)
- [缓存治理优化计划](cache_governance_optimization_plan_2026-06-02.md)
- [代码库工程治理专项 Backlog](codebase_engineering_governance_backlog_2026-06-02.md)
- [桌面端工程提效与底座优化里程碑](desktop_engineering_productivity_milestone_2026-06-01.md)
- [桌面端 UI 第一里程碑：外壳导航与我的页展示基线](desktop_ui_phase1_shell_mine_milestone_2026-05-31.md)

## 业务与专项规则

- [全项目页面统一化审计与整改任务](full_project_page_unification_audit_plan_2026-06-06.md)
- [U5-LIB 成熟库与统一组件替换执行计划](u5_lib_mature_component_replacement_plan_2026-06-07.md)
- [页面 UI 组件治理任务计划](page_ui_component_governance_plan_2026-05-12.md)
- [存储治理定版规范](storage_governance_spec_2026-05-21.md)
- [存储升级验证清单](storage_upgrade_validation_2026-05-21.md)
- [主题语义化改造计划](theme_semantic_refactor_plan_2026-05-21.md)
- [品牌视觉规范](brand_guidelines.md)

## 阅读器专项

- [本地阅读导入到解析规范化计划](local_reading_import_parse_standardization_plan_2026-06-07.md)
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
