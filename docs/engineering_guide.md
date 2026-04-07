# 工程指南

更新时间：2026-04-01
用途：统一技术架构、模块边界、开发规范和测试要求。

## 1. 架构目标

- 以脚本源运行时作为唯一在线书源执行链
- 将脚本执行复杂度与阅读业务复杂度分离
- 支持后续扩展更多内容类型和规则能力

## 2. 技术栈

- 状态管理：Riverpod
- 路由：GoRouter
- 网络：Dio
- 解析：`html`、`json_path`、Dart `RegExp`
- 本地存储：Drift + SQLite
- 日志：`logger`

## 3. 分层架构

- UI 层：`features`
- Domain 层：`entities + use cases`
- Data 层：`repositories + local/remote data source`
- Core / Runtime 层：`runtime + network + logger`

## 4. 核心模块职责

### 4.1 Script Source Runtime

- 编译、注册并执行脚本源
- 对外暴露搜索、发现、详情、目录、正文统一能力
- 维护运行时书源注册表与宿主桥接能力

### 4.2 Fetch Pipeline

- 封装统一 HTTP 访问行为
- 输出可追踪日志
- 处理超时、重试、Header 和 Cookie

### 4.3 Reader Engine

- 文本分页或滚动渲染
- 章节预加载
- 阅读设置和进度持久化
- 阅读器页面壳层后续统一按三层维护：
  - `ReaderShell`
  - `ReaderContentSession`
  - `ReadingMode`

## 5. 代码规范

- 文件名：`snake_case.dart`
- 类名：`UpperCamelCase`
- 方法和变量：`lowerCamelCase`

## 6. 分层依赖规则

- `features` 可依赖 `domain` 与 `shared`
- `domain` 不依赖 `data`
- `data` 实现 `domain` 仓库接口
- `core` 不依赖具体业务 feature

## 7. 状态管理与错误处理

- 页面状态与业务状态分离
- 不在 Widget 中直接写网络或脚本源执行逻辑
- 禁止直接吞异常
- 所有 catch 至少记录一条结构化日志
- 用户文案与开发日志分离

## 8. 测试要求

每次重要改动至少执行：

- `flutter analyze`
- `flutter test`

规则相关改动要求：

- 补对应回归样本
- 补最小单测或服务层测试

## 9. 文档维护规则

- 项目定位和需求变化：更新 `docs/product_guide.md`
- 架构变化：更新 `docs/engineering_guide.md`
- 专题变化：更新对应专题文档
- 不再围绕旧兼容体系新增平行规划文档

## 10. 提交流程

提交前应说明：

- 变更目的
- 变更范围
- 测试结果
- 风险点
- 文档是否已同步
