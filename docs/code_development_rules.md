# 代码与架构编写规则

更新时间：2026-06-04

本文定义后续代码如何写。目标是减少手写、减少散点判断、减少超大文件，让项目保持可维护。

## 1. 分层规则

允许的依赖方向：

```text
app -> features / core / domain / data / shared
features/presentation -> feature/application + domain + app widgets/tokens
features/application -> core + domain + repository contracts
data -> core + domain
core -> 基础设施，不依赖 features
domain -> 纯 Dart，不依赖 Flutter UI、data、features
```

禁止：

- `core -> features`
- `domain -> data`
- `presentation -> data implementation`
- `presentation -> AppDatabase`
- `presentation -> MethodChannel/EventChannel`
- 页面直接 `new` 仓库或跨域 service。

## 2. Provider 与状态

- 全局依赖放在 `app/composition` 或稳定 feature provider。
- feature 私有依赖放在 `features/<feature>/providers.dart` 或 feature application provider。
- 页面不负责装配复杂依赖。
- 页面临时 UI 状态可以使用 `StatefulWidget`，但业务状态优先进入 Riverpod provider、controller 或 service。
- 跨页面共享状态不得藏在页面私有字段里。
- 异步状态优先使用 `AsyncValue` 或明确的状态模型。

## 3. 模型与样板代码

新增模型默认遵守：

- 纯业务实体优先保持不可变。
- 需要 value equality、copyWith、默认值的状态对象优先使用 `freezed`。
- 需要 JSON 序列化的 DTO 优先使用成熟生成工具；迁移旧模型时必须保留旧字段兼容。
- 不再为新增复杂模型手写大段 `copyWith/toJson/fromJson/operator ==/hashCode`。
- 新增或改名为模型职责的文件如果仍手写上述样板，必须先登记为明确技术债，否则 `dart run tool/check_model_codegen_guard.dart` 应保持通过。

旧模型迁移规则：

- 不全量机械迁移。
- 只在功能改动、拆分或测试覆盖充分时顺手迁移。
- 迁移前后必须补兼容测试。

## 4. 存储规则

存储落点按语义选择：

- `SharedPreferences`：轻量偏好、小型开关、最近选择。
- Drift：结构化、会增长、需要查询或迁移的数据。
- 托管文件目录：用户资产、导入文件、主题资源、字体、封面资源。
- 缓存目录：可重建、可删除、可预算治理的数据。
- `flutter_secure_storage`：token、敏感凭证、会话秘密。

禁止：

- 把大型 JSON 长期塞进 `SharedPreferences`。
- 把用户资产写进 cache/tmp。
- 启动期同步清理大目录。
- 清理逻辑删除书架、阅读进度、书签、主题资源或用户上传文件。

## 5. 平台代码规则

共享文件不得直接导入不可跨端库，除非它只会在对应平台编译。

涉及以下能力必须使用 adapter 或条件导入：

- `dart:io`
- `dart:ffi`
- 文件系统路径
- 原生 SQLite
- Web storage
- WebView
- 窗口控制
- 平台通道
- PDF/native engine

业务层只 import 抽象入口，不 import `*_native.dart` 或 `*_web.dart`。

## 6. 超大文件治理

新代码不得继续堆入超大页面。建议阈值：

- presentation 文件超过 1500 行：必须评估拆分。
- presentation 文件超过 4500 行：进入治理警戒。
- presentation 文件超过 6000 行：视为架构问题。
- application 文件超过 2000 行：必须评估 service/resolver/coordinator 拆分。
- application 文件超过 2500 行：视为架构问题。

拆分优先级：

1. 纯 widget section。
2. presenter / resolver。
3. controller / coordinator。
4. service。
5. model / state。

拆分必须等价迁移，不趁机改业务语义。

## 7. 注释与维护说明规则

后续新增或维护的业务代码、平台适配代码和复杂公共代码，默认必须配备标准中文维护注释。注释的目标是解释“为什么这样写”“业务边界是什么”“维护时不能破坏什么”，不是复述代码正在做什么。

中文注释标准：

- 默认使用简体中文；Flutter、Riverpod、provider、adapter、capability、token 等通用技术名词可以保留英文。
- public class、public method、public enum、public provider、跨 feature service / facade / resolver 必须优先使用中文 Dartdoc。
- 复杂私有方法、平台分支、降级策略、兼容旧数据、状态转换和异常兜底必须补中文行注释或块注释。
- 注释要写清业务语义、平台范围、降级方式、兼容原因、关键不变量和修改风险。
- 详细不等于堆长文；如果说明超过一个代码块能承受的范围，应沉淀到 docs，并在注释里链接文档。

必须写注释的场景：

- 平台能力 adapter、bridge、conditional import：说明支持平台、降级方式和失败边界。
- capability 字段或判断：说明业务语义，不说明具体插件实现。
- 数据迁移、存储 key、用户资产路径、缓存清理：说明兼容要求和不能删除的内容。
- 阅读器分页、进度、章节定位、编码检测、PDF / EPUB / MOBI 解析等复杂算法：说明关键不变量和边界条件。
- 等价抽取旧逻辑时：说明保留了哪些旧行为，避免后续误以为可以顺手改语义。
- 临时技术债、TODO、FIXME：必须写清原因、触发条件、退出条件或关联文档，不能只写“待优化”。

优先使用 Dartdoc 的场景：

- public class、public method、public enum、public provider。
- 跨 feature 使用的 model、service、facade、resolver。
- 平台 capability、storage resolver、route helper、task coordinator。

禁止的注释：

- 复述代码字面行为，例如“设置变量”“返回结果”。
- 与代码不一致的历史解释。
- 大段业务流程复制粘贴到代码里，应该放到 docs。
- 在注释里写 token、cookie、密码、本机绝对路径、完整用户正文、设备指纹或带 query / fragment 的敏感 URL。
- 为了绕过 lint 增加 `ignore`，但不说明原因和移除条件。

注释维护规则：

- 改代码时必须同步检查相邻注释是否仍然准确。
- 移动端保护、Web / Desktop 降级、用户资产和缓存边界相关注释如果过期，视为回归风险。
- 生成文件不手工补注释。
- 新增复杂文件时，文件顶部不写流水账背景；若确实需要上下文，写一段短 Dartdoc 或链接到已登记文档。

## 8. 成熟库优先规则

优先使用：

- Flutter 官方组件和插件。
- Riverpod、GoRouter、Drift、Dio 等当前项目已采用的成熟栈。
- `file_selector`、`path_provider`、plus 插件等跨端能力库。
- `freezed`、`json_serializable` 等生成工具。

引入新库前必须确认：

- 是否支持 Android、iOS、Web、macOS、Windows、Linux。
- 是否影响 Web JS 或 Web WASM。
- 是否维护活跃。
- 是否需要本地 override。
- 是否比项目现有方案更简单、更可靠。

本地 override 包必须有说明：为什么 override、改了什么、何时回主线或替换。

## 9. 验证命令

常规改动至少执行：

```bash
flutter analyze
```

架构或平台相关改动优先执行：

```bash
dart run tool/check_architecture_guardrails.dart
dart run tool/check_model_codegen_guard.dart
dart run tool/check_storage_governance_guard.dart
dart run tool/check_ui_component_governance.dart
dart run tool/check_route_inventory.dart
dart run tool/check_route_string_guard.dart
flutter build web --no-pub
```

复杂参数路由补充规则：

- 阅读器、书籍详情等带 path 参数和多 query 参数的路由，必须通过 route helper 或 route data 构造，不得在页面里手写拼接。
- 新增复杂路由时，必须补对应单测，并保持 `dart run tool/check_route_string_guard.dart` 通过。

桌面相关改动至少在可用宿主机执行一个桌面构建。
