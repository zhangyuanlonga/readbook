# 书源登录子系统执行计划

更新时间：2026-04-30  
用途：作为当前项目“书源登录子系统”整改与扩展的唯一执行清单，指导后续分阶段落地、勾选、验收与文档回填。  
总计划状态：`进行中`

关联文档：

- `docs/development_architecture_guardrails.md`
- `docs/cross_platform_boundary_refactor_plan.md`
- `docs/project_architecture_unification_plan.md`
- `docs/archive/script_sources/source_login_design_plan.md`
- `docs/archive/script_sources/source_login_full_compat_matrix.md`
- `docs/script_sources/official-source-author-guide.md`

---

## 1. 约束基线

本清单执行时必须遵守：

- [development_architecture_guardrails.md](./development_architecture_guardrails.md)
- [cross_platform_boundary_refactor_plan.md](./cross_platform_boundary_refactor_plan.md)
- [project_architecture_unification_plan.md](./project_architecture_unification_plan.md)

本轮整改硬约束：

- [x] 书源登录相关业务流程统一放在 Flutter / Dart，不回退到原生页面拼装业务流程
- [x] 页面层只负责渲染、交互分发、订阅状态，不直接装配底层运行时依赖
- [x] 登录入口分流、登录态编排、网页登录状态回写统一下沉到 `features/source/application`
- [x] 运行时脚本编译、宿主 bridge、cookie/session 能力继续收口在 `runtime/`
- [x] 书源登录态持久化继续通过稳定 service 暴露，不让 presentation 直接接触底层存储
- [x] 后续新增依赖统一通过 provider 注入，不新增隐藏单例和页面内 `new service`
- [x] 本轮不重做整套书源编辑器，先补登录链路和最小编写辅助工具

本轮一票否决项：

- [x] 页面直接依赖 `AppDatabase`
- [x] 页面直接依赖 `MethodChannel / EventChannel`
- [x] 页面直接构建 `SourceRuntimeFacade / RepositoryImpl / BrowserExecutor`
- [x] 把 source feature 的 UI 决策继续塞回 `runtime/`

---

## 2. 总体目标

- [ ] 补齐 `loginUi` 与纯 `loginUrl` 的登录入口分流
- [ ] 建立纯 `loginUrl` 网页登录闭环
- [ ] 明确并补齐 `loginCheckJs` 的项目内落地路径
- [ ] 保持书源登录态、cookie、源变量、书级变量在统一模型内演进
- [ ] 为后续晋江、晴天聚合、云端聚合等高级样本源迁移提供稳定底座
- [ ] 补齐测试与文档回填机制，避免登录链路继续散落

---

## 3. 阶段状态总览

- [ ] 阶段 0：建立基线与范围冻结
- [ ] 阶段 1：登录入口分流
- [ ] 阶段 2：纯 `loginUrl` 网页登录闭环
- [ ] 阶段 3：`loginCheckJs` 兼容层
- [ ] 阶段 4：编写侧最小工具补强
- [ ] 阶段 5：测试、回归与文档验收

规则：

- [x] 未完成上一阶段，不进入下一阶段
- [x] 每完成一个勾选项，必须同步更新本文件
- [x] 每完成一个阶段，必须补“阶段完成记录”
- [ ] 若实施过程中调整范围或顺序，先改文档，再改代码

---

## 4. 阶段 0：建立基线与范围冻结

目标：

- 冻结本轮书源登录子系统整改边界，明确哪些能力本轮必须完成，哪些能力延后

执行清单：

- [x] 梳理当前项目书源登录运行时、状态存储、Flutter 页面、入口路由现状
- [x] 对照 MD3 项目梳理 `loginUi / loginUrl / loginCheckJs` 的成熟职责
- [x] 明确当前项目最大缺口是“纯 `loginUrl` 网页登录模式未补齐”
- [x] 明确本文件作为后续执行唯一勾选清单
- [ ] 将后续代码实现严格对齐 `Feature-first + Application + Riverpod DI`
- [ ] 将需要新增的类按 `application / presentation / providers / routes` 规划落点

阶段完成定义：

- [x] 团队对本轮边界形成一致口径
- [ ] 后续开发不再反复讨论“先做编辑器还是先补登录链路”

阶段完成记录：

- `2026-04-30`：已完成现状与 MD3 对照梳理，确认先落地文档和登录入口分流。

---

## 5. 阶段 1：登录入口分流

目标：

- 让 source feature 能区分“动态表单登录”“网页登录”“不支持登录”三种入口

执行清单：

- [ ] 明确登录入口模式解析模型：
  - `form`
  - `web`
  - `unsupported`
- [ ] 新增 source feature application 层的登录入口 resolver
- [ ] 将 source 页面登录入口判断从字符串扫描式判断收口到稳定 service / resolver
- [ ] `loginUi` 存在时继续走 Flutter 动态表单登录页
- [ ] 仅有 `loginUrl` 时不再提示“未声明登录面板”，改走网页登录路径
- [ ] source 路由层补齐登录入口跳转方式，避免页面内临时拼分流逻辑
- [ ] 保持现有 `SourceLoginPage` 作为表单登录页，不把网页登录逻辑硬塞进同一个页面类

阶段完成定义：

- [ ] source 列表点击“登录”时，能稳定进入正确入口
- [ ] `loginUi` 书源现有行为不回退
- [ ] 纯 `loginUrl` 书源不再落入错误提示分支

---

## 6. 阶段 2：纯 `loginUrl` 网页登录闭环

目标：

- 建立一条专门服务于纯 `loginUrl` 书源的网页登录闭环

执行清单：

- [ ] 新增 source feature 专用网页登录页
- [ ] 解析并支持相对 `loginUrl` 到绝对地址
- [ ] 在打开网页登录前同步当前 session cookies 到浏览器容器
- [ ] 在网页登录完成或退出后同步浏览器 cookies 回写到 session
- [ ] 将关键登录结果持久化回 source login state
- [ ] 支持 header 注入、标题展示、加载状态和退出反馈
- [ ] 明确网页登录完成后的成功定义
- [ ] source 页面从网页登录返回后可触发必要刷新

阶段完成定义：

- [ ] 纯 `loginUrl` 源可从 source feature 内完成网页登录
- [ ] 登录后再次执行书源请求能消费到新的 cookie / header
- [ ] 网页登录链路不要求页面直接碰底层浏览器 executor

---

## 7. 阶段 3：`loginCheckJs` 兼容层

目标：

- 为需要“请求后登录检测 / 自动补登录 / 重放请求”的高级书源补齐兼容层

执行清单：

- [ ] 盘点当前项目中 `loginCheckJs` 的缺位点和请求执行切入点
- [ ] 设计 `loginCheckJs` 在运行时中的唯一落点，不把逻辑散到页面
- [ ] 为请求执行链引入“结果检测 -> 登录态更新 -> 重试请求”的稳定流程
- [ ] 保持普通源不走额外复杂路径
- [ ] 明确 `loginCheckJs` 可以读取和写回的上下文边界
- [ ] 至少选取一个依赖 `loginCheckJs` 的样本源做链路验证

阶段完成定义：

- [ ] 运行时支持基于请求结果的登录检测与重试
- [ ] 不影响现有普通 search/detail/chapters/content 源

---

## 8. 阶段 4：编写侧最小工具补强

目标：

- 在不重做整套结构化编辑器的前提下，补齐最小可用的登录编写与调试辅助能力

执行清单：

- [ ] 在现有脚本源编辑器内补一个“登录相关工具”入口
- [ ] 提供“登录预览”能力
- [ ] 提供“网页登录测试”入口
- [ ] 提供“清空登录态”能力
- [ ] 提供“查看当前 loginHeader / loginInfo / sourceVariable”能力
- [ ] 明确这些工具都经由 application service 暴露，不让编辑器直接读写底层存储

阶段完成定义：

- [ ] 书源作者在编辑器里可以完成最小登录链路调试
- [ ] 常见登录态问题可通过工具快速定位

---

## 9. 阶段 5：测试、回归与文档验收

目标：

- 让书源登录子系统具备持续回归能力，而不是只靠手点

执行清单：

- [ ] 为登录入口 resolver 补 application 层测试
- [ ] 为 `SourceLoginPage` 和新增网页登录页补 widget 测试
- [ ] 为登录态持久化、cookie 同步、回写流程补 service 测试
- [ ] 为 `loginUi / loginUrl / loginCheckJs` 的运行时编译与执行链补测试
- [ ] 建立最小样本源回归集：
  - 一个纯 `loginUrl` 源
  - 一个动态 `loginUi` 源
  - 一个依赖 `loginCheckJs` 的高级源
- [ ] 将每轮验证结果同步回填本文件
- [ ] 将长期有效结论同步到相关作者文档或架构文档

阶段完成定义：

- [ ] 自动化测试覆盖本轮关键登录业务链路
- [ ] 文档状态、代码状态、实际回归结果一致

---

## 10. 建议验证顺序

- [ ] 第 1 步：验证一个仅声明 `loginUrl` 的简单网页登录源
- [ ] 第 2 步：验证一个带 `loginUi` 的动态表单源
- [ ] 第 3 步：验证一个带 `loginCheckJs` 的高级源
- [ ] 第 4 步：回归 source 页、调试页、编辑页相关入口

说明：

- 样本源验证必须按“简单 -> 动态表单 -> 高级登录检测”递进
- 每通过一个样本，先勾文档，再进入下一类样本

---

## 11. 影响文件清单

本轮预计核心改造落点：

- [ ] `lib/features/source/application/source_login_runtime_service.dart`
- [ ] `lib/features/source/application/source_login_browser_service.dart`
- [ ] `lib/features/source/application/source_login_state_service.dart`
- [ ] `lib/features/source/application/source_page_flow_coordinator.dart`
- [ ] `lib/features/source/presentation/source_page.dart`
- [ ] `lib/features/source/presentation/source_login_page.dart`
- [ ] `lib/features/source/presentation/source_page_flow.dart`
- [ ] `lib/features/source/routes.dart`
- [ ] `lib/features/source/providers.dart`
- [ ] `lib/runtime/sources/source_contract.dart`
- [ ] `lib/runtime/sources/source_script_compiler.dart`
- [ ] `lib/runtime/sources/source_executor.dart`
- [ ] `test/features/source/application/`
- [ ] `test/features/source/presentation/`
- [ ] `test/runtime/sources/`

说明：

- 若实施中新增关键文件，必须先补到本节，再继续开发
- 若某文件最终确认不需要修改，也应在阶段完成后更新本节状态

---

## 12. 样本源验证清单

优先验证样本：

- [ ] 纯 `loginUrl` 网页登录样本
- [ ] `docs/js/晋江文学 API.js`
- [ ] `docs/js/晴天聚合.js`
- [ ] `docs/js/☁️云端聚合v4.551(1).json`

验证维度：

- [ ] 登录入口是否正确分流
- [ ] 登录信息是否正确持久化
- [ ] cookie / header 是否可回流到后续请求
- [ ] 动态按钮、select、toggle、验证码是否可用
- [ ] 登录后 search/detail/chapters/content 是否继续正常

---

## 13. 文档维护规则

- [x] 本文件是当前“书源登录子系统”唯一阶段清单
- [x] 每完成一项实现，先更新勾选状态，再继续后续开发
- [x] 若实现策略变化，先更新本文件中的阶段目标、清单和影响文件
- [x] 若新增约束，优先补到“约束基线”
- [x] 若完成一整个阶段，必须补“阶段完成记录”

---

## 14. 当前下一步

当前推荐立即进入：

- [ ] 阶段 1：登录入口分流

进入编码前执行要求：

- [ ] 先按本文件确认新增类的落点
- [ ] 先确认 provider 注入路径
- [ ] 先确认不会违反 `docs/development_architecture_guardrails.md`
