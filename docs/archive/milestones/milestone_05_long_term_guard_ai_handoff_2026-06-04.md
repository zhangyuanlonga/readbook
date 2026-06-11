# 里程碑 05：长期门禁、发布验收与 AI 接力

创建日期：2026-06-04

状态：待执行；M5-01 的 AI 执行序列基础规则和 M5-08-01 的 README 当前入口已随本次里程碑重排完成。

适用平台：Android、iOS、Web JS、macOS、Windows、Linux。

核心目标：把 M1-M4 的治理结果固化为长期可执行规则。后续 AI 或开发者接手时，不靠猜，不靠一次性大重构，而是按 guard、CI、看板、验收矩阵和交接模板继续推进。

后续执行规则：每次只领取一个最小任务编号，例如 `M5-04-01`。

## 1. M5-01 AI 执行序列固化

- [x] M5-01-01 更新 [AI 后续执行序列与维护优先级](ai_maintenance_execution_sequence_2026-06-04.md)。
- [x] M5-01-02 明确后续任务分类：M1 规则来源、M2 手搓替换、M3 业务链、M4 本地内容资源、M5 门禁接力。
- [x] M5-01-03 明确后续 AI 每次只领取一个最小 checkbox 任务。
- [x] M5-01-04 明确任务收尾必须记录多端影响、测试、未验证原因、中文注释和下一步编号。

## 2. M5-02 Green suite 与 CI

- [ ] M5-02-01 确认 `tool/run_architecture_green_suite.dart` 包含 architecture、codegen、storage、override、route、UI guards。
- [ ] M5-02-02 增加 green suite 文档，说明本地、CI、发布前分别跑哪些命令。
- [ ] M5-02-03 增加 Web build 默认入口或说明何时跳过。
- [ ] M5-02-04 增加 macOS build 默认入口或说明何时跳过。
- [ ] M5-02-05 为 Android、iOS、Windows、Linux 写 CI 或人工补验要求。

## 3. M5-03 手搓候选 guard

- [ ] M5-03-01 复查 `check_model_codegen_guard.dart`，保证新增复杂手写模型会被发现。
- [ ] M5-03-02 复查 `check_route_string_guard.dart`，保证关键复杂路由裸字符串会被发现。
- [ ] M5-03-03 评估是否新增 presentation 平台散点 guard。
- [ ] M5-03-04 评估是否新增页面直接文件系统 / 临时目录访问 guard。
- [ ] M5-03-05 guard 只拦截高确定性问题，低确定性问题进入看板。

## 4. M5-04 依赖健康与 override 复查

- [ ] M5-04-01 建立 `flutter pub outdated` 复查节奏。
- [ ] M5-04-02 为本地 override 记录上游状态、SDK 约束、平台影响、回主线条件。
- [ ] M5-04-03 为新增依赖建立 Android、iOS、Web JS、macOS、Windows、Linux 支持检查模板。
- [ ] M5-04-04 记录 Web WASM 影响，不把 Web JS 通过等同于 WASM 通过。
- [ ] M5-04-05 依赖升级必须小步、可回滚、可测试。

## 5. M5-05 测试金字塔与 smoke 矩阵

- [ ] M5-05-01 整理单测、widget test、guard、build、手工 smoke 的分层职责。
- [ ] M5-05-02 建立 Android 发布前 smoke 模板。
- [ ] M5-05-03 建立 iOS 发布前 smoke 模板。
- [ ] M5-05-04 建立 Web JS 发布前 smoke 模板。
- [ ] M5-05-05 建立 macOS 发布前 smoke 模板。
- [ ] M5-05-06 建立 Windows 发布前 smoke 模板。
- [ ] M5-05-07 建立 Linux 发布前 smoke 模板。

## 6. M5-06 中文注释与文档审计

- [ ] M5-06-01 建立 public API、provider、adapter、storage、route helper 中文注释检查清单。
- [ ] M5-06-02 建立旧 key、旧 payload、数据库迁移、用户资产路径注释检查清单。
- [ ] M5-06-03 建立复杂解析、分页、进度恢复、缓存清理注释检查清单。
- [ ] M5-06-04 说明注释要解释为什么、边界和风险，不复述代码字面行为。
- [ ] M5-06-05 说明生成文件不手工补注释。

## 7. M5-07 技术债与退出条件看板

- [ ] M5-07-01 将暂不替换、暂不支持、暂不验证的问题登记到长期看板。
- [ ] M5-07-02 每个债务必须有编号、类型、影响链路、影响平台、当前实现、推荐方向、验证入口、退出条件。
- [ ] M5-07-03 P0 / P1 债务优先于新功能。
- [ ] M5-07-04 未验证平台必须写原因，不能写“未涉及”。

## 8. M5 验收

- [x] M5-08-01 README 只保留当前有效里程碑入口。
- [ ] M5-08-02 AI 执行序列、green suite、候选看板、发布前 smoke 模板已登记。
- [ ] M5-08-03 依赖健康、override、技术债和注释审计有复查节奏。
- [ ] M5-08-04 后续 AI 可以从任意最小 checkbox 继续执行，不需要重新猜阶段目标。
