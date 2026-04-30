# MD3 登录功能迁移执行计划

更新时间：2026-04-30  
用途：作为当前项目围绕 `legado-with-MD3-main` 登录相关成熟能力的专题迁移清单，统一“能力对照、阶段推进、验收口径、文档回填”。
总计划状态：`进行中`

关联文档：

- `docs/development_architecture_guardrails.md`
- `docs/project_architecture_unification_plan.md`
- `docs/cross_platform_boundary_refactor_plan.md`
- `docs/archive/script_sources/source_login_design_plan.md`
- `docs/archive/script_sources/source_login_full_compat_matrix.md`
- `docs/md3_login_ui_phase1_inventory.md`
- `docs/script_sources/official-source-author-guide.md`
- `/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/ui/login/`

---

## 1. 本专题边界

本专题不是泛化的“书源功能整改”，而是专门围绕 MD3 已成熟的登录相关能力迁移。

本专题重点范围：

- [x] `loginUi`
- [x] `loginUrl`
- [x] `loginCheckJs`
- [x] 登录态持久化
- [x] 登录相关宿主交互
- [x] 登录相关编写与调试体验

本专题暂不展开的范围：

- [x] 整套书源结构化编辑器重做
- [x] 非登录主题的书源字段编辑体验
- [x] 与登录无关的搜索、详情、目录、正文规则迁移
- [x] 非 MD3 登录功能的视觉重设计

---

## 2. 约束基线

本专题实施时必须遵守：

- [development_architecture_guardrails.md](./development_architecture_guardrails.md)
- [project_architecture_unification_plan.md](./project_architecture_unification_plan.md)
- [cross_platform_boundary_refactor_plan.md](./cross_platform_boundary_refactor_plan.md)

本专题硬约束：

- [x] 业务流程统一进 Flutter / Dart
- [x] 页面层只负责渲染、交互分发、订阅状态
- [x] 登录相关编排优先下沉到 `lib/features/source/application/`
- [x] 运行时脚本编译、bridge、cookie/session 继续收口到 `lib/runtime/`
- [x] 所有新增依赖统一通过 provider 注入
- [x] 开发顺序必须先补能力闭环，再补编写工具

本专题一票否决项：

- [x] 页面直接 new 底层 service / repository / runtime facade
- [x] 页面直接依赖 `AppDatabase`
- [x] 页面直接处理平台通道
- [x] 把 UI 决策继续塞回 runtime 层

---

## 3. MD3 成熟能力总表

当前需要迁移的 MD3 核心能力：

- [ ] 能力 A：`loginUi` 动态表单
- [ ] 能力 B：纯 `loginUrl` 网页登录
- [ ] 能力 C：`loginCheckJs` 请求后登录检测
- [ ] 能力 D：登录头 / 登录信息 / 源变量 / 书级变量持久化
- [ ] 能力 E：登录相关宿主交互
- [ ] 能力 F：登录相关编写与调试入口

说明：

- `loginUi` 对应 MD3 的动态控制台式登录面板
- `loginUrl` 在 MD3 里不只是 URL，也可能是登录入口脚本
- `loginCheckJs` 是高级源能否稳定工作的关键补链能力
- 宿主交互包括 `toast / longToast / browser await / verification code / confirm / prompt`

---

## 4. 阶段状态总览

- [x] 阶段 0：MD3 能力对照基线冻结
- [x] 阶段 1：`loginUi` 现状收口与缺口确认
- [ ] 阶段 2：纯 `loginUrl` 网页登录模式补齐
- [ ] 阶段 3：`loginCheckJs` 兼容层补齐
- [ ] 阶段 4：MD3 登录宿主交互补齐与校正
- [ ] 阶段 5：MD3 登录编写与调试体验补强
- [ ] 阶段 6：样本源验证、测试与文档验收

执行规则：

- [x] 未完成上一阶段，不进入下一阶段
- [x] 每完成一个勾选项，必须同步更新本文件
- [x] 若实施过程中调整迁移顺序，先改文档，再改代码
- [x] 每完成一个阶段，必须补“阶段完成记录”

---

## 5. 阶段 0：MD3 能力对照基线冻结

目标：

- 将“当前项目已有能力 / 缺失能力 / 本轮目标能力”一次性冻结，避免后续反复漂移

执行清单：

- [x] 对照 MD3 登录相关源码入口
- [x] 对照当前项目 source feature 与 runtime 现状
- [x] 明确 `loginUi` 当前已有一版 Flutter 动态表单实现
- [x] 明确纯 `loginUrl` 网页登录模式当前仍未补齐
- [x] 明确 `loginCheckJs` 当前仍无项目内正式落点
- [x] 明确本文件作为“MD3 登录功能迁移”的唯一勾选清单

阶段完成定义：

- [x] 团队对本专题范围形成一致口径
- [x] 后续讨论不再混用“书源专题”和“MD3 登录专题”

阶段完成记录：

- `2026-04-30`：已完成 MD3 登录相关能力对照，确认单独拆出专题文档。

---

## 6. 阶段 1：`loginUi` 现状收口与缺口确认

目标：

- 把当前项目已实现的 `loginUi` 能力和 MD3 对齐后，明确剩余差距，不在本阶段盲目返工

执行清单：

- [x] 梳理当前 `loginUi` 字段类型支持矩阵
- [x] 梳理当前 `action` 触发语义支持矩阵
- [x] 梳理当前布局语义支持矩阵
- [x] 梳理当前 `viewName`、动态标签、回填机制
- [x] 梳理当前登录页与 MD3 对话框式交互的差异
- [x] 明确当前 `loginUi` 哪些能力已经可直接复用
- [x] 明确本轮不需要重做的 `loginUi` 区域
- [x] 将需要补的 `loginUi` 缺口单列到后续阶段

阶段完成定义：

- [x] 当前项目 `loginUi` 能力边界清晰
- [x] 不再把纯 `loginUrl` 问题误判为 `loginUi` 问题

阶段完成记录：

- `2026-04-30`：已完成 `loginUi` 支持矩阵、差异与复用边界梳理，产出 `docs/md3_login_ui_phase1_inventory.md`。

---

## 7. 阶段 2：纯 `loginUrl` 网页登录模式补齐

目标：

- 对齐 MD3 中“没有 `loginUi` 时直接走 WebView 登录”的成熟模式

执行清单：

- [x] 补齐登录入口模式分流：
  - `loginUi`
  - `loginUrl(web)`
  - `unsupported`
- [x] 为纯 `loginUrl` 模式新增 source feature 专用网页登录页
- [x] 支持相对 `loginUrl` 转绝对地址
- [x] 支持 header 注入
- [x] 打开网页登录前同步 session cookies
- [x] 关闭网页登录后回写浏览器 cookies 到 session 和持久化状态
- [x] 明确网页登录完成后的成功判定
- [ ] source 页 / 调试页可从网页登录返回后刷新状态

阶段完成定义：

- [x] 纯 `loginUrl` 源可完成网页登录闭环
- [x] 登录后后续请求能消费到新的 cookie / header
- [ ] 该闭环不违反现有开发约束

阶段完成记录：

- `2026-04-30`：已完成 source 页登录模式分流、专用网页登录页、cookie 前后同步与最小测试闭环；剩余调试页返回刷新待后续收尾。

---

## 8. 阶段 3：`loginCheckJs` 兼容层补齐

目标：

- 对齐 MD3 中“请求返回后判定是否需要重登或补登”的能力

执行清单：

- [ ] 梳理 MD3 `loginCheckJs` 的实际职责和使用模式
- [ ] 设计当前项目内 `loginCheckJs` 的唯一运行时落点
- [ ] 为请求执行链增加“结果检测 -> 登录态更新 -> 重放请求”流程
- [ ] 明确 `loginCheckJs` 可读写的上下文范围
- [ ] 避免普通源请求链路被强行复杂化
- [ ] 选择至少一个样本源验证 `loginCheckJs`

阶段完成定义：

- [ ] 当前项目具备最小 `loginCheckJs` 兼容能力
- [ ] 高级源可利用该能力补登录并继续请求

---

## 9. 阶段 4：MD3 登录宿主交互补齐与校正

目标：

- 校正当前项目与 MD3 在登录宿主交互上的差距

执行清单：

- [ ] 梳理当前项目已支持宿主交互：
  - `toast`
  - `longToast`
  - `openBrowserAwait`
  - `verificationCode`
  - `confirm`
  - `prompt`
- [ ] 对照 MD3 校正宿主交互的参数与行为
- [ ] 明确哪些能力已等价，哪些只是基础版
- [ ] 补齐登录专题高频缺失交互
- [ ] 保持这些交互继续通过 `SourceUiContext` 暴露

阶段完成定义：

- [ ] 高级源常用登录交互能力达到可迁移水平
- [ ] 登录脚本不再频繁因宿主交互缺失而中断

---

## 10. 阶段 5：MD3 登录编写与调试体验补强

目标：

- 围绕 MD3 登录功能，为当前脚本源编写体验补最小必需工具

执行清单：

- [ ] 在现有脚本源编辑器里增加“登录相关工具”入口
- [ ] 提供 `loginUi` 预览能力
- [ ] 提供纯 `loginUrl` 网页登录测试入口
- [ ] 提供登录态查看能力：
  - `loginHeader`
  - `loginInfo`
  - `sourceVariable`
- [ ] 提供清理登录态能力
- [ ] 明确这些工具统一经由 application service 暴露

阶段完成定义：

- [ ] 书源作者可围绕 MD3 登录能力完成最小调试闭环
- [ ] 常见登录态问题不再只能靠日志排查

---

## 11. 阶段 6：样本源验证、测试与文档验收

目标：

- 用真实 MD3 风格样本源验收迁移质量，而不是停留在抽象能力表

执行清单：

- [ ] 建立最小样本验证序列：
  - 纯 `loginUrl` 网页登录样本
  - `loginUi` 动态表单样本
  - `loginCheckJs` 高级样本
- [ ] 优先验证：
  - `docs/js/晋江文学 API.js`
  - `docs/js/晴天聚合.js`
  - `docs/js/☁️云端聚合v4.551(1).json`
- [ ] 为登录入口分流补 application 测试
- [ ] 为 `loginUi` 页和网页登录页补 widget 测试
- [ ] 为登录态存储、cookie 回写、请求重试补 service / runtime 测试
- [ ] 将验证结果回填本文件
- [ ] 将长期有效结论同步到作者文档或专题文档

阶段完成定义：

- [ ] 能用真实 MD3 风格样本源验证迁移质量
- [ ] 文档、代码、测试状态一致

---

## 12. 样本验证清单

优先样本：

- [ ] 纯 `loginUrl` 网页登录简单样本
- [ ] `docs/js/晋江文学 API.js`
- [ ] `docs/js/晴天聚合.js`
- [ ] `docs/js/☁️云端聚合v4.551(1).json`

验证维度：

- [ ] `loginUi` 动态表单是否可正常渲染
- [ ] 纯 `loginUrl` 是否可完成网页登录
- [ ] `loginCheckJs` 是否可接入请求执行链
- [ ] 登录信息是否可稳定持久化
- [ ] cookie / header 是否可回流到后续请求
- [ ] 登录后 search/detail/chapters/content 是否继续正常

---

## 13. 预计改造落点

核心改造落点预计包括：

- [ ] `lib/features/source/application/source_login_runtime_service.dart`
- [ ] `lib/features/source/application/source_login_entry_resolver.dart`
- [ ] `lib/features/source/application/source_login_browser_service.dart`
- [ ] `lib/features/source/application/source_login_state_service.dart`
- [ ] `lib/features/source/presentation/source_login_page.dart`
- [ ] `lib/features/source/presentation/source_web_login_page.dart`
- [ ] `lib/features/source/presentation/`
- [ ] `lib/features/source/routes.dart`
- [ ] `lib/features/source/providers.dart`
- [ ] `lib/runtime/sources/source_contract.dart`
- [ ] `lib/runtime/sources/source_script_compiler.dart`
- [ ] `lib/runtime/sources/source_executor.dart`
- [ ] `test/features/source/application/`
- [ ] `test/features/source/presentation/`
- [ ] `test/runtime/sources/`

说明：

- 若实施中新增关键文件，必须先补到本节
- 若确认某些文件最终不需要修改，也要同步更新本节状态

---

## 14. 文档维护规则

- [x] 本文件是“MD3 登录功能迁移”唯一阶段清单
- [x] 每完成一个实现项，先更新勾选状态，再继续开发
- [x] 若迁移策略变化，先更新本文件，再改代码
- [x] 若新增约束，优先补到“约束基线”
- [x] 若某个能力确认延后，也要在本文件显式记录

---

## 15. 当前下一步

当前推荐立即进入：

- [ ] 阶段 2：纯 `loginUrl` 网页登录模式补齐

执行前检查：

- [ ] 新增类的落点已按 `application / presentation / providers / routes` 规划
- [ ] 依赖注入路径已明确
- [ ] 开发方案已对齐 `docs/development_architecture_guardrails.md`
