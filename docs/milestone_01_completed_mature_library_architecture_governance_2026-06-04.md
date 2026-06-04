# 里程碑 01：已完成的成熟库与架构治理基线

创建日期：2026-06-04

状态：已完成。此文档由原“里程碑 04：成熟库替代与架构样板治理”整理而来，作为后续开发的第一里程碑和默认规则来源。

适用平台：Android、iOS、Web JS、macOS、Windows、Linux。

核心目标：把项目从“功能能跑但很多地方靠手搓维护”的状态，先拉到可继续治理的基线。后续所有里程碑都默认继承本阶段结论：能用成熟库、生成工具、provider、adapter、route helper 和 guard 的，不再继续堆复杂手写实现。

## 1. 为什么先做这个阶段

旧第四里程碑之所以要做，是因为项目已经进入多端和长期维护阶段，单纯继续加功能会把这些问题越堆越重：

- 页面业务状态过多，阅读器、书架、搜索、高级主题等页面难测难拆。
- 手写 JSON、copyWith、equality、路由字符串和缓存逻辑太多，后续 AI 或新人容易改错。
- 平台能力、依赖装配、日志、错误监控、表单校验等基础设施没有足够统一。
- Web / Desktop 适配会放大移动端原本能忍的手搓实现。
- 后续不怕改代码，怕的是每次改动都需要猜业务边界。

所以本阶段不是为了做新功能，而是先把“怎么写才可维护”固定下来。

## 2. 已完成任务

以下任务已经完成，后续不要重复执行，只在发现回归时修复。

- [x] M1-01 明确主架构继续使用 Riverpod、GoRouter、Dio、Drift，不引入 GetX / Bloc / get_it 替代主栈。
- [x] M1-02 建立成熟库优先规则：通用能力优先使用 Flutter 官方能力、成熟库、生成工具或项目统一封装。
- [x] M1-03 完成阅读器状态治理试点，把章节加载、预加载、分页 task generation 等迁入 Riverpod controller / provider family。
- [x] M1-04 完成书架页面状态治理试点，把筛选、排序、选择和卡片派生态迁入 Riverpod state model。
- [x] M1-05 完成高级主题列表和编辑器长生命周期状态治理试点，页面只保留必要 UI 临时态。
- [x] M1-06 完成搜索页长生命周期状态治理试点，搜索 session、模式、权限、历史和进度完成态进入 provider。
- [x] M1-07 完成低风险模型 codegen 试点，新增复杂状态模型默认使用 `freezed`。
- [x] M1-08 完成 JSON payload codegen 试点，新增复杂 DTO / payload 默认使用 `json_serializable`。
- [x] M1-09 建立 `tool/check_model_codegen_guard.dart`，防止新增复杂手写模型样板。
- [x] M1-10 完成网络图片与封面缓存治理试点，网络图片优先走成熟缓存方案和统一业务 fallback。
- [x] M1-11 完成 API 客户端与 REST DTO 治理试点，低风险响应模型接入生成工具并保留兼容读取。
- [x] M1-12 完成路由字符串治理试点，复杂 reader / book detail 路由进入 helper / guard。
- [x] M1-13 建立 `tool/check_route_string_guard.dart`，防止关键复杂路由继续裸字符串拼接。
- [x] M1-14 完成认证、资料、反馈等表单 validation service / state model 试点。
- [x] M1-15 完成部分全局单例 provider 化治理，降低页面和业务层直接抓单例的风险。
- [x] M1-16 完成日志与错误监控接入试点，保留本地诊断和远端监控 adapter 边界。
- [x] M1-17 完成架构 guard、UI guard、路由 guard、模型 guard 的本地执行入口。
- [x] M1-18 将中文维护注释规则写入开发规则，复杂代码必须解释业务边界、兼容原因和修改风险。
- [x] M1-19 完成旧第四里程碑收口：后续不再把这些治理结论当成可选项，而是默认开发规则。

## 3. 后续默认规则

- [x] 新增复杂状态模型默认使用 `freezed`。
- [x] 新增 JSON DTO / payload 默认使用 `json_serializable` 或 Drift 生成能力。
- [x] 页面不维护跨页面业务状态，业务态进入 provider / controller / service。
- [x] 页面不直接拼复杂路由，复杂参数路由走 route helper / route data。
- [x] 页面不直接访问数据库、平台通道、跨域 service 或 data implementation。
- [x] 平台差异进入 capability / adapter / conditional import，不散落在页面。
- [x] 本地 override、stub、fork 必须登记原因、平台影响和退出条件。
- [x] 复杂 public API、平台 fallback、存储兼容、用户资产保护和暂不替换逻辑必须有中文维护注释。

## 4. 本阶段不再做

- [x] 不再重复迁移已经完成的试点。
- [x] 不再把本阶段当作功能开发阶段。
- [x] 不全量机械迁移所有旧模型。
- [x] 不为了减少代码行数破坏旧字段、旧 key、旧 payload、数据库迁移或用户资产。
- [x] 不引入只支持单端、会拖累 Web JS / Desktop 的库。

## 5. 交给后续里程碑的事项

- [x] M2 继续处理旧代码里仍然手搓、不稳定、难测、难解释的实现。
- [x] M3 处理核心业务链的多端兼容与验收，不再只点通单端功能。
- [x] M4 处理本地内容、资源、解析、缓存和性能等重资产能力成熟化。
- [x] M5 把 M1-M4 的结果固化为长期 guard、CI、依赖健康、AI 接力和发布前验收流程。

## 6. 验证记录

- [x] 原阶段已通过相关单测、guard、build_runner 生成和架构检查完成收口。
- [x] 当前文档只做编号与执行口径重排，不改变业务代码。
- [x] 后续若发现 M1 规则被破坏，应在对应里程碑登记为回归任务，而不是重新执行整个 M1。
