# 代码与架构编写规则

更新时间：2026-06-02

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

## 7. 成熟库优先规则

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

## 8. 验证命令

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
