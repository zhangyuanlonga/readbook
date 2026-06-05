# AI 后续执行序列与维护优先级

创建日期：2026-06-04

用途：给后续 AI 或开发者接手项目时使用。核心原则是：手搓换成熟，不稳定换成熟，复杂定制要隔离、测试、注释和记录。项目不怕改代码，怕的是后续无人能维护。

## 1. 必读顺序

后续 AI 开始任何任务前，按顺序读取：

1. [README](README.md)
2. [代码与架构编写规则](code_development_rules.md)
3. [业务开发规则](business_development_rules.md)
4. [多端架构开发约束](development_architecture_guardrails.md)
5. 当前任务所属里程碑文档
6. 本文档

M1 已完成，它来自旧第四里程碑的成熟库、生成工具和架构样板治理结论。M6 是阅读器全平台可用与架构收敛专项，执行时必须同时继承 M3 的业务链兼容、M4 的本地内容资源规则和 M5 的门禁接力要求。后续任务默认继承 M1，不再重复执行旧 M1-M3。

## 2. 总执行序列

后续任务默认按以下顺序推进：

| 序列 | 对应文档 | 目标 | 何时进入 |
| --- | --- | --- | --- |
| S1 | M1：已完成的成熟库与架构治理基线 | 只读取规则和结论，不重复执行旧任务 | 开始任何开发前 |
| S2 | M2：手搓实现替换与稳定性治理 | 当前优先执行；把手搓、不稳定、难维护代码替换或隔离 | 发现手写样板、平台散点、测试不稳、维护困难时 |
| S3 | M3：核心业务链多端兼容与验收 | 登录、搜索、详情、阅读、书架、设置等按六平台业务链验收 | 功能链路要确认业务合理和多端不回退时 |
| S4 | M4：本地内容、资源与性能成熟化 | 本地解析、用户资产、缓存、诊断、长任务和性能治理 | 涉及 TXT / EPUB / PDF / MOBI、资源、缓存、性能时 |
| S5 | M5：长期门禁、发布验收与 AI 接力 | 把治理结果固化为 guard、CI、依赖健康、smoke 和交接模板 | 需要防止问题复发，或准备长期维护时 |
| S6 | M6：阅读器全平台可用与架构收敛 | 阅读器在线、本地、PDF、音频、设置、目录、进度、输入和平台降级专项收束 | 目标是让阅读器 Android、iOS、Web JS、macOS、Windows、Linux 都可用且可验收时 |

当前默认从 M3 继续执行；如果发现手搓、不稳定或用户资产风险，再回到 M2 / M4 的对应最小任务；涉及阅读器全平台专项时进入 M6。不要因为用户提出某个功能点，就直接跳到页面写 UI。先判断它是否依赖手搓替换、业务链兼容、本地资源成熟化、长期门禁或阅读器专项收敛。

## 3. 最小任务领取规则

后续 AI 或开发者只能领取一个最小 checkbox 任务，例如 `M2-04-03`、`M3-02-06`、`M4-03-02`。

- [x] 不领取“完成整个 M2”这种大阶段任务。
- [x] 不领取“完成 M2-04”这种包含多步的小阶段任务，除非用户明确要求连续执行并允许分多轮。
- [x] 如果一个 checkbox 做到一半发现仍然太大，先拆文档，再继续执行。
- [x] 每次完成后更新对应 checkbox、候选看板和收尾记录。
- [x] 下一步必须指向明确任务编号，让后续 AI 能继续接。

## 4. 任务领取七步

每次接手任务按这七步执行：

1. 分类：任务属于 M2 手搓替换、M3 业务兼容、M4 资源性能、M5 长期门禁、M6 阅读器全平台专项中的哪一类。
2. 搜索：用 `rg` 找相关页面、provider、service、repository、adapter、route、storage 和测试。
3. 识别：标记手搓、不稳定、平台散点、旧兼容、用户资产风险和测试缺口。
4. 决策：能用成熟库、生成工具、项目 helper、adapter、provider 或 route data 替换的，优先替换。
5. 实施：小步等价迁移，保留旧字段、旧 key、旧 payload、旧行为和回滚方式。
6. 验证：跑目标测试、guard、build 或记录未验证原因和补验方式。
7. 收尾：同步中文注释、README / milestone / 技术债清单，并记录下一步候选。

## 5. 维护优先级

遇到多个候选时，按以下优先级处理：

| 优先级 | 类型 | 判断标准 |
| --- | --- | --- |
| P0 | 用户资产、安全、存储和会话风险 | 可能误删资产、破坏进度、泄露 token、破坏旧数据兼容 |
| P0 | 构建或平台编译风险 | Web JS、Android、iOS、Desktop 因平台 import、插件或条件导入失败 |
| P1 | 不稳定实现 | 测试偶发失败、刷新恢复异常、会话恢复异常、缓存清理不可预测 |
| P1 | 高风险手搓基础设施 | 缓存、文件选择、路径、cookie、日志、诊断、表单、路由、DTO、状态模型 |
| P2 | 超大页面和业务状态膨胀 | 页面维护长生命周期业务态，或跨页面共享状态藏在 widget 私有字段 |
| P2 | 重复逻辑 | 多处重复错误分类、空态、降级、表单校验、路由拼接、JSON 解析 |
| P3 | UI 细节和局部体验 | 不影响业务正确性和维护性的局部视觉或交互优化 |

P0 和 P1 优先于新功能。新功能如果依赖 P0 / P1 债务，先治理再实现。

## 6. 替换决策表

| 当前实现 | 默认方向 | 可保留条件 |
| --- | --- | --- |
| 手写状态对象、copyWith、equality | `freezed` | 纯临时值对象且无共享、无 JSON、无复杂比较 |
| 手写 JSON DTO / payload | `json_serializable` 或 Drift 生成能力 | 旧 payload 兼容高度复杂，且已有 golden / compatibility test |
| 页面拼路由字符串 | route helper / route data | 简单静态路由且已有 guard 放行 |
| 页面持有业务状态 | Riverpod controller / notifier / state model | 纯 UI 临时态、动画、输入 controller |
| 手写缓存下载和过期 | `cached_network_image`、`flutter_cache_manager` 或统一 cache service | 业务特定缓存，且边界、测试、注释完整 |
| 手写 cookie / session 辅助 | `cookie_jar`、secure storage、auth service | 服务端协议特殊，且封装在 core / service |
| 手写文件路径和选择 | `file_selector`、`path_provider`、统一 adapter | 平台库不支持目标端，且有 fallback |
| 手写表单校验 | validation service / state model | 只有单个字段的局部 UI 约束 |
| 手写平台判断 | capability / adapter / conditional import | 仅编译期隔离文件内部实现，业务层不可见 |
| 本地 override / fork / stub | 回主线、替代库或登记退出计划 | 上游无可用方案，且影响平台、测试和退出条件清楚 |

## 7. 成熟方案优先级

优先使用项目已有稳定栈：

- 状态：Riverpod provider、Notifier、AsyncNotifier、provider family。
- 路由：GoRouter、route helper、route data、route string guard。
- 网络：Dio、typed DTO、cookie jar、统一错误分类。
- 数据库：Drift。
- 模型：freezed、json_serializable。
- 文件与路径：file_selector、path_provider、平台 adapter。
- 图片缓存：cached_network_image、flutter_cache_manager、项目业务 fallback。
- 凭证：flutter_secure_storage、安全 fallback 和 auth session service。
- 日志与监控：logger、Sentry adapter、本地诊断导出。

引入新库前必须确认 Android、iOS、Web JS、macOS、Windows、Linux 支持情况，并记录是否影响 Web WASM。

## 8. 必须写中文维护注释的地方

以下位置新增或修改时，必须补标准中文维护注释：

- public class、public method、public enum、public provider。
- 跨 feature service、facade、resolver、repository contract。
- capability、adapter、conditional import、平台 fallback。
- 存储 key、旧数据迁移、旧 payload 兼容、用户资产路径。
- 缓存清理、诊断导出、日志脱敏、安全凭证。
- 阅读器分页、章节定位、进度恢复、编码检测、PDF / EPUB / MOBI 解析。
- 暂不替换的手搓逻辑、override、stub、TODO、FIXME。

注释要解释“为什么这样写、不能破坏什么、修改风险是什么”，不要只复述代码正在做什么。

## 9. 收尾模板

每次任务完成后，在回复或执行记录中至少说明：

| 项目 | 内容 |
| --- | --- |
| 所属序列 | S2 / S3 / S4 / S5 |
| 任务编号 | 例如 M2-04-03 |
| 业务链 | 搜索、详情、阅读、书架、登录、设置、本地内容、缓存等 |
| 手搓判断 | 本次发现了什么手搓 / 不稳定点，替换还是暂留 |
| 成熟方案 | 使用了什么库、生成工具、helper、adapter 或 provider |
| 多端影响 | Android、iOS、Web JS、macOS、Windows、Linux |
| 测试与构建 | 已运行命令、未运行原因、后续补验 |
| 注释与文档 | 哪些复杂代码补了中文注释，哪些 docs 已同步 |
| 下一步 | 下一个最应该处理的最小任务编号 |

## 10. 常用命令

基础搜索：

```bash
rg -n "setState|ValueNotifier|StreamController|toJson|fromJson|copyWith|MethodChannel|EventChannel|dart:io|AppDatabase.instance|go\\(|push\\(|replace\\(" lib test
rg -n "override|stub|TODO|FIXME|SharedPreferences|File\\(|Directory\\(|path_provider|file_selector" lib docs
```

基础验证：

```bash
flutter analyze
dart tool/check_architecture_guardrails.dart
dart tool/check_model_codegen_guard.dart
dart tool/check_storage_governance_guard.dart
dart tool/check_storage_baseline_governance.dart
dart tool/check_dependency_override_governance.dart
dart tool/check_route_inventory.dart
dart tool/check_route_string_guard.dart
flutter build web --no-pub
```

生成与构建：

```bash
dart run build_runner build --delete-conflicting-outputs
flutter build macos --debug --no-pub
flutter build apk --no-pub
flutter build ios --no-pub --no-codesign
```

## 11. 接力原则

- 如果发现 P0 / P1 维护性风险，不要为了赶功能绕过去。
- 如果成熟库不能覆盖项目业务，保留定制可以，但必须隔离、测试、注释和登记退出条件。
- 如果没有环境验证某个平台，必须写明原因，不能写“未涉及”。
- 如果修改共享层，必须扩大多端影响判断。
- 如果改动复杂代码而没有补中文维护注释，任务不算收尾。
- 如果本次只完成部分治理，必须留下下一步候选，让后续 AI 能接着做。
