# Flutter AppRead 项目规范

## 1. 适用范围

本规范用于统一项目开发方式，覆盖代码规范、分支管理、提交流程、测试要求、文档维护要求。

## 2. 基本原则

- 先保证可维护，再追求功能速度。
- 任何跨模块改动必须同步更新文档。
- 规则兼容逻辑集中在 `core/rule_engine` 与 `data/adapters`，禁止散落在 UI 层。

## 3. 代码规范

## 3.1 命名

- 文件名：`snake_case.dart`
- 类名：`UpperCamelCase`
- 方法/变量：`lowerCamelCase`
- 常量：`lowerCamelCase`（Dart 社区习惯）

## 3.2 分层依赖

- `features` 可依赖 `domain` 与 `shared`。
- `domain` 不依赖 `data`。
- `data` 实现 `domain` 定义的仓库接口。
- `core` 不依赖具体业务 feature。

## 3.3 状态管理

MVP 推荐：Riverpod（或 Bloc，二选一并全项目统一）。

统一要求：

- 页面状态与业务状态分离。
- 不在 Widget 中直接写网络请求逻辑。

## 3.4 错误处理

- 禁止直接吞异常。
- 所有 catch 至少记录一条结构化日志。
- 用户可见错误文案与开发日志文案分离。

## 4. Git 规范

## 4.1 分支策略

- `main`：稳定可发布。
- `develop`：日常集成。
- `feature/*`：功能开发。
- `fix/*`：问题修复。

## 4.2 提交规范

建议使用 Conventional Commits：

- `feat:` 新功能
- `fix:` 缺陷修复
- `refactor:` 重构
- `test:` 测试
- `docs:` 文档
- `chore:` 构建或工具链

示例：

- `feat(source): add legado json import validation`
- `fix(reader): handle empty chapter content`

## 4.3 Pull Request 规范

每个 PR 必须包含：

- 变更目的
- 变更范围
- 测试结果
- 风险评估
- 文档更新说明

## 5. 测试规范

## 5.1 必跑检查

- `flutter pub get`
- `flutter analyze`
- `flutter test`

## 5.2 测试分层

- 单测：规则解析、映射转换、文本清洗。
- 组件测试：关键页面渲染和状态流。
- 集成测试：搜索到阅读闭环（可逐步补齐）。

## 5.3 回归样本管理

- 在 `test/fixtures/sources/` 保存书源样本（脱敏）。
- 在 `test/fixtures/responses/` 保存响应快照。
- 任何兼容修复必须新增对应回归样本。

## 6. 文档规范

- 新增模块必须更新 `docs/architecture.md`。
- 新增需求必须更新 `docs/requirements.md`。
- 迭代计划和完成情况写入 `docs/implementation_steps.md`。

## 7. 日志与排障规范

- 日志至少包含：时间、sourceId、阶段、URL、错误摘要。
- 用户反馈问题时可一键复制最近一次失败日志。
- 禁止日志中写入敏感信息（token/cookie 明文）。

## 8. 发布规范（MVP）

发版前检查清单：

- 关键链路可用（导源、搜索、阅读）。
- 回归样本通过率达到目标。
- 崩溃与严重错误已清零。
- 文档与版本号一致。
