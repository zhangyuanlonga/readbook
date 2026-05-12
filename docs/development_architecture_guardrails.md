# 多端架构开发约束

更新时间：2026-05-11  
用途：作为当前项目后续开发的强约束文档，统一多端架构、目录、依赖、Riverpod、路由、原生桥接、平台能力、UI 适配、测试和代码评审口径，避免“改一个端误伤另一个端”的架构发散。

关联执行文档：

- 全平台兼容总计划：`docs/all_platform_compatibility_plan_2026-05-11.md`
- 逐页面功能多端兼容方法：`docs/page_function_multiplatform_methods_2026-05-12.md`
- 逐页面 UI 多端兼容展示计划：`docs/page_ui_multiplatform_display_plan_2026-05-12.md`
- 页面 UI 组件治理任务计划：`docs/page_ui_component_governance_plan_2026-05-12.md`

## 0. 结论先行

当前项目后续一律按这套口径收口：

- 总体架构：`Feature-first + Application + Riverpod DI`
- Flutter 角色：统一 UI、状态、业务流程、跨端复用
- 原生角色：只做系统入口和平台专属能力适配
- 多端边界：平台差异先进入 capability / bridge / conditional import，不进入页面散点判断
- 组合根位置：`app/` 与 feature provider
- 页面职责：只负责渲染、交互分发、订阅状态
- 禁止事项：页面直接 new 仓库 / service，页面直接依赖 `AppDatabase`，页面直接调用 `MethodChannel`，页面直接写散落的平台分支

一句话总结：

- **业务统一进 Flutter**
- **依赖统一进 Provider**
- **平台能力统一走 Bridge**
- **平台差异统一走 Capability**
- **页面不再充当组装层**
- **单端改动必须证明不影响其他端**

---

## 1. 适用范围

本约束适用于：

- 新增 feature
- 修改现有 feature
- Flutter 与原生桥接
- 平台能力差异处理
- 多端 UI / 自适应布局调整
- 路由扩展
- 本地存储与网络接入
- 测试与 code review

本约束不是“完全推翻当前代码后重建”，而是作为**从当前状态继续演进的唯一口径**。

目标平台统一按以下口径讨论：

- P0：Android、iOS、macOS、Windows、Linux
- P1：Web

任何改动都必须说明它影响哪些平台，以及不影响哪些平台。

---

## 2. 目标架构

### 2.1 总体分层

```text
app
  ├─ composition / shell / theme / top-level router
core
  ├─ cross-feature infrastructure
runtime
  ├─ script source runtime and host bridge
domain
  ├─ shared pure models + shared repository contracts
data
  ├─ shared repository implementations + shared datasources
features
  ├─ feature presentation + application + feature-local providers/routes
shared
  ├─ generic reusable widgets/utilities only
```

### 2.2 目录职责

`lib/app/`

- 只放应用级组合根
- 只放全局主题、外壳、顶层导航、启动装配
- 只放平台能力总入口和全局 capability provider
- 不承载具体 feature 业务流程

`lib/core/`

- 只放跨 feature 基础设施
- 如网络、日志、错误、设备、缓存、认证、系统能力封装
- 可放无业务语义的平台能力封装和文件/媒体/设备适配
- 不放具体业务页面逻辑

`lib/runtime/`

- 只放脚本源运行时、宿主桥、执行容器
- 不放阅读页 UI 逻辑
- 不放书架、书签、主题之类业务页面状态

`lib/domain/`

- 只放跨 feature 共享的纯 Dart 模型和仓库接口
- 不依赖 Flutter UI、Drift、平台通道
- 只在“确实跨 feature 共享”时新增内容

`lib/data/`

- 只放共享仓库实现、共享 datasource、数据库接入
- 平台差异实现必须使用条件导入或稳定 adapter
- 不允许反向依赖 `features/presentation`
- 不放页面编排逻辑

`lib/features/<feature>/`

- 默认是未来新增业务代码的第一落点
- 每个 feature 自己拥有 presentation / application / providers / routes
- feature 内平台差异必须先收口到 application/service，再给 presentation 暴露语义能力
- 若某个 feature 后续复杂度足够高，可以在 feature 内再细分 `domain/`、`data/`

`lib/shared/`

- 只放真正无业务语义的通用 UI 和工具
- 不能把“暂时没地方放的东西”都堆进来

---

## 3. 推荐目录模板

新增 feature 默认按下面结构：

```text
lib/features/<feature>/
  presentation/
    pages/
    widgets/
    controllers/
  application/
    services/
    coordinators/
    resolvers/
  providers.dart
  routes.dart
```

当 feature 出现跨页面共享模型或接口时，再升级为：

```text
lib/features/<feature>/
  presentation/
  application/
  domain/
  data/
  providers.dart
  routes.dart
```

补充规则：

- 能放 feature 内，就不要先放到全局 `domain/` 或 `data/`
- 只有多个 feature 共享时，才提升为全局模块
- 不再新增“超大综合页面文件”

---

## 4. 依赖方向

### 4.1 允许的依赖

```text
app -> features / core / runtime / shared
features/presentation -> feature/application + app-level UI tokens + shared + domain
features/application -> core + runtime + domain
data -> core + domain
runtime -> core + domain
core -> pure infra only
domain -> pure dart only
```

### 4.2 禁止的依赖

明确禁止：

- `presentation -> data/repositories/*_impl.dart`
- `presentation -> data/datasources/local/app_database.dart`
- `presentation -> MethodChannel/EventChannel`
- `domain -> data`
- `core -> features`
- `runtime -> features/presentation`
- `app -> feature 具体 service 细节编排`

### 4.3 一条判断规则

如果一个类里同时出现下面两类内容，就说明它大概率越界了：

- UI 控件 / 生命周期
- 仓库实现 / 数据库 / 平台桥 / 网络细节

---

## 5. 多端平台能力约束

### 5.1 目标口径

平台差异只能出现在少数稳定边界：

- `lib/app/platform/`：应用级能力矩阵与 capability provider
- `lib/core/**`：跨 feature 平台基础设施
- `lib/data/**`：数据库、文件、缓存等 datasource 的条件导入
- `lib/features/<feature>/application/**`：feature 私有平台能力 service / bridge
- 原生目录：只做系统入口和平台 SDK 适配

页面层不得把平台差异散落到交互和布局细节里。

### 5.2 Capability 强制规则

涉及平台差异时，优先新增或复用 capability：

- `supportsLocalFileImport`
- `supportsManagedFileStorage`
- `supportsNativeSqlite`
- `supportsDriftWebStorage`
- `supportsImagePicking`
- `supportsReaderBrightnessBridge`
- `supportsReaderVolumeKeyBridge`
- `supportsSourceRuntime`
- `supportsInteractiveWebView`
- `supportsWebDavSync`

规则：

- 页面只能消费“能不能做某件事”的语义能力，不直接判断插件或原生实现。
- `kIsWeb`、`defaultTargetPlatform`、`Platform.isXxx` 不得在页面中反复出现；已有历史代码逐步收口，新代码默认不允许新增。
- 如果只是 UI 样式差异，优先走自适应断点和主题 token；如果是能力差异，必须走 capability。
- feature 想隐藏、降级或替换入口时，必须通过 capability 或 feature-level access service，不允许在多个 widget 中各自写一份判断。
- 书源运行时属于延期能力，首版默认 `APP_ENABLE_SOURCE_RUNTIME=false`；所有换源、在线搜索、WebView 登录和脚本调试入口必须先经过 `supportsSourceRuntime` / `supportsInteractiveWebView`。局域网网页调试服务已从项目移除，不再新增入口或服务端口。
- WebDAV 同步属于 P1+ 能力，首版默认 `APP_ENABLE_WEBDAV_SYNC=false`；同步设置、同步历史和后台同步任务必须先经过 `supportsWebDavSync`，不允许默认进入可点击但必失败的页面。
- 文件导入、缓存清理、诊断导出等常用业务必须按 `supportsLocalFileImport` 与 `supportsManagedFileStorage` 做禁用、占位或文案降级；不支持平台仍需保留本地阅读、书签、阅读记录和外观设置的可用路径。

### 5.3 条件导入强制规则

以下场景必须使用条件导入或平台 adapter，不允许直接在共享文件中导入不可跨端库：

- `dart:io`
- `dart:ffi`
- `drift/native.dart`
- 文件系统读写
- 原生 SQLite
- Web-only storage
- WebView / JS runtime
- 平台插件专属 API

推荐结构：

```text
foo.dart
foo_native.dart
foo_web.dart
```

`foo.dart` 只负责条件导出：

```dart
export 'foo_native.dart'
    if (dart.library.html) 'foo_web.dart';
```

约束：

- 业务层只 import `foo.dart`，不得 import `foo_native.dart` 或 `foo_web.dart`。
- native / web 文件必须暴露同名接口或函数。
- 新增条件导入时必须至少跑 `flutter analyze` 和一个目标端 build / test。
- Web 临时方案必须在文档里标注“受限模式”和后续替换路径。

### 5.4 Bridge 强制规则

- `MethodChannel/EventChannel` 只能在 bridge/service 文件中出现。
- bridge 必须提供 no-op 或 unsupported 实现，不能让不支持的平台直接崩溃。
- 原生返回的数据必须转换为稳定 Dart 模型后再进入 application 层。
- 页面只能看到业务语义，例如“支持音量键翻页”“支持亮度控制”，不能看到 channel 名称、method 名称或原生 payload。

### 5.5 单端改动隔离规则

任何声称“只改某个平台”的改动，必须满足：

- 改动文件位于该平台目录、条件导入实现、capability 分支或明确的 platform adapter。
- 不修改共享 UI 默认样式，除非同步验证所有目标平台。
- 不改变共享路由、Provider 默认值、数据库 schema、主题 token，除非 PR 明确列出跨端影响。
- 不在共享 widget 中硬编码某平台尺寸、间距、手势或文案。
- 不让不支持的平台出现可点击但必失败的入口，必须隐藏、禁用或展示统一占位页。

如果做不到这些条件，就不能把改动描述为“只影响某端”。

---

## 6. 多端 UI 与自适应约束

### 6.1 总体原则

UI 改动必须以“同一套业务语义，多端不同呈现”为原则：

- 手机端：优先底部导航、底部弹层、触控手势。
- 平板/桌面端：优先 NavigationRail、侧栏、宽屏分区、鼠标键盘可操作。
- Web：优先可启动、可浏览、能力受限时有明确占位。

不允许为了修某一端，直接破坏另一端的布局密度、导航结构或核心操作。

### 6.2 断点与布局规则

- 断点必须优先使用 `AppLayout`、`AppAdaptiveMetrics`、`adaptive_*` 组件。
- 页面内部禁止新增孤立 magic width，例如随手写 `390`、`480`、`600` 来判断布局。
- 固定格式 UI 必须有稳定尺寸约束，例如网格、工具栏、图标按钮、阅读器设置项。
- 大屏不是放大的手机页面，必须考虑内容最大宽度、双栏/多栏、鼠标滚轮、键盘焦点。
- 横屏和大字体是必测场景，不允许只按竖屏默认字体验证。

### 6.3 平台 UI 隔离规则

平台差异 UI 必须按以下优先级处理：

1. 先用自适应布局解决。
2. 再用 capability 决定功能入口是否出现。
3. 最后才使用 `TargetPlatform` 做视觉微调。

禁止：

- 在页面中大段 `if (Platform.isAndroid) ... else if (Platform.isIOS) ...`。
- 为了桌面端改共享 widget 默认 padding，导致手机端信息密度变化。
- 为了 Web 编译把 native 端能力直接删掉。
- 为了移动端手势修改阅读器桌面键盘/鼠标路径。

### 6.4 UI 变更验收矩阵

涉及页面布局、导航、设置面板、阅读器、书架卡片、详情页、主题外观时，至少覆盖：

- `360x800`
- `390x844`
- `600x960`
- `840x1180`
- `780x360`
- `1280x800`
- 文字缩放 `1.0x`
- 文字缩放 `1.3x`

如果只改一个平台，也必须说明其他平台为什么不会受影响；无法说明时，按全矩阵验收。

### 6.5 UI 回归底线

以下任一情况视为 UI 回归：

- 文本、按钮、图标互相遮挡。
- 手机端底部导航遮挡主操作。
- 桌面端内容无限拉宽、信息密度明显失衡。
- Web 端出现 native-only 操作入口但点击必失败。
- 横屏高度不足时无法完成关键操作。
- 大字体下标题、筛选、按钮、trailing 控件溢出。

---

## 7. Riverpod 与依赖注入约束

### 7.1 强制规则

- 所有仓库、service、coordinator、facade 的创建都必须进入 Provider 或组合根
- 页面只能 `read/watch/listen` provider，不能自己 `new` 具体基础设施
- Provider 尽量返回抽象接口或稳定服务对象，不向页面暴露底层实现细节
- 新代码禁止继续新增 `xxx.instance` 风格单例，已有单例视为待收敛技术债

### 7.2 页面允许做什么

页面允许：

- 订阅状态
- 分发用户交互
- 管理局部 UI 状态
- 管理短生命周期 controller

页面不允许：

- 创建 `RepositoryImpl`
- 创建 `AppDatabase.instance`
- 直接拼装复杂业务依赖图
- 直接处理平台通道

### 7.3 Provider 落点

- feature 内依赖：优先放 `lib/features/<feature>/providers.dart`
- 应用级依赖：放 `lib/app/` 下的组合根 provider
- 真正跨 feature 的基础设施 provider：放 `core/` 或专门的 app composition 文件

---

## 8. 页面、Controller、Service 三层职责

页面级功能兼容必须同步维护 `docs/page_function_multiplatform_methods_2026-05-12.md`：新增或修改页面功能时，需要写清该功能在移动端、桌面端和 Web 的状态、能力边界、降级方式和验证结果。UI 展示差异只维护到 `docs/page_ui_multiplatform_display_plan_2026-05-12.md`，不要把功能 capability 和视觉断点混在同一判断里。

### 8.1 Presentation

负责：

- 页面布局
- UI 状态展示
- 用户交互入口
- 调用 application 层能力

不负责：

- 业务编排细节
- 仓库装配
- 数据持久化细节
- 平台桥接细节

### 8.2 Application

负责：

- 用例编排
- feature 内状态协调
- 页面之间共用的业务流程
- 外部依赖整合

不负责：

- 原始 SQL / Drift 表定义
- Widget 渲染细节

### 8.3 Data / Runtime / Core

负责：

- 数据访问
- 平台或运行时能力实现
- 持久化
- 网络与宿主桥

不负责：

- 页面行为决策
- feature UI 流程

### 8.4 页面加载分级与懒初始化

页面必须先定加载等级，再定初始化策略。加载等级以 `docs/global_page_route_inventory_2026-05-12.md` 为准：

| 等级 | 含义 | 初始化规则 |
| --- | --- | --- |
| Core Shell | 主导航高频页面 | 只加载基础快照和首屏必要数据 |
| Core On-demand | 核心但非首屏页面 | 用户进入后加载业务数据 |
| Management On-demand | 低频管理页面 | 进入页面后再加载列表、统计、扫描、编辑器依赖 |
| Feature-gated | 能力开关页面 | capability 关闭时只创建轻量占位 |

强制规则：

- 新增 `GoRoute` 必须同步更新 `docs/global_page_route_inventory_2026-05-12.md`，并标记加载等级。
- 新增或调整页面阶段任务必须同步更新 `docs/global_page_lazy_loading_execution_plan_2026-05-12.md`。
- 主导航页面不得在 `initState` / 首帧路径里初始化低频管理页服务、书源运行时、同步服务、图库扫描、缓存统计、反馈列表。
- 页面首屏只允许读取“当前页面可见内容”需要的最小数据；标签、分类、封面补齐、远端状态、缓存统计、编辑器资源都必须延后。
- Feature-gated 页面在 capability 关闭时不得创建真实业务页面或重依赖，只能返回统一 disabled/placeholder。
- 首屏后的补充任务必须可取消或可过期，至少要有 `mounted`、route active、ticket/epoch 之类的保护。
- 手动刷新、进入具体管理页、登录态变化、用户明确打开设置/详情/编辑器，可以触发完整加载。

验收口径：

- 冷启动进入 `/home` 或 `/bookshelf`，不应触发书源、同步、图库扫描、缓存统计。
- 打开 `/mine`，不应预加载外观编辑器、图集、缓存管理、反馈列表。
- 直接访问书源、搜索、同步等受限路由，能力关闭时必须可显示轻量占位，不允许白屏或崩溃。

---

## 9. 路由约束

### 9.1 目标口径

每个 feature 自己维护自己的路由定义。

推荐形式：

- `lib/features/<feature>/routes.dart`
- `lib/app/router.dart` 只负责组装

### 9.2 app/router.dart 允许保留的内容

- 顶层 `GoRouter`
- shell route
- 全局 navigator key
- feature route 聚合

### 9.3 app/router.dart 禁止继续增长的内容

- 具体 feature 的业务判断
- 大量 query/path 参数解析细节
- 直接导入所有页面并长期集中维护

### 9.4 约束规则

- 新增页面时，优先往 feature 自己的 `routes.dart` 加
- 路由参数解析优先放 feature 本地
- 跨 feature 跳转只依赖 route contract，不依赖页面构造细节

---

## 10. 启动与生命周期约束

### 10.1 app 层职责

`App` 只能承担：

- MaterialApp / theme / router
- 全局外壳
- 顶层 composition

### 10.2 需要拆出的内容

以下内容不得继续直接堆在 `App` 根 widget：

- 启动任务编排
- 更新检查
- 公告拉取
- 心跳与埋点访问
- 外部导入订阅
- 数据库预热
- 登录刷新流程

### 10.3 推荐收口方式

- `bootstrap()`：一次性初始化
- `startup coordinator provider`：启动任务
- `lifecycle coordinator provider`：前后台生命周期
- `bridge listener provider`：外部导入、音量键等桥接事件

---

## 11. 原生边界约束

### 11.1 原生层允许承载的内容

- 系统入口
- 文件导入 / Intent / URL open
- 平台专属 SDK
- 音量键、通知、后台服务等系统级能力
- Flutter 插件暂时无法稳定覆盖的能力

### 11.2 原生层禁止承载的内容

- 阅读业务规则
- 书架业务规则
- 搜索编排
- 文本解析业务决策
- 主题业务逻辑

### 11.3 Flutter 侧桥接规则

- `MethodChannel/EventChannel` 只能出现在 bridge 文件
- bridge 文件只能位于 `core/` 或 feature `application/`
- 页面不得直接调用平台通道
- 原生层返回的数据必须是稳定协议对象，而不是零散字段

---

## 12. 数据层约束

### 12.1 数据库

- Drift 表定义只允许位于 data 层
- 页面不得直接访问 `AppDatabase`
- application 层如果需要数据，只依赖仓库或查询 service

### 12.2 Repository

- `domain` 中定义接口
- `data` 中实现接口
- 页面只能拿到接口或 provider 暴露出的稳定能力

### 12.3 共享实体

以下条件同时满足，才允许把模型放入全局 `domain/entities`：

- 至少两个 feature 使用
- 不依赖 UI
- 不依赖存储实现
- 语义稳定

否则优先放 feature 内部。

---

## 13. 安全与仓库卫生约束

强制规则：

<!-- - 禁止提交 keystore、签名配置、密钥、token、私有证书 -->
- 禁止提交 `ios/build`、`android/.gradle`、临时构建物
- `.gitignore` 已覆盖的不应再被 Git 跟踪
- 若已经泄漏，必须先旋转密钥，再清理仓库

---

## 14. 测试约束

### 14.1 必测项

新增或修改业务流程时，至少覆盖以下之一：

- application service test
- provider test
- widget test
- route smoke test

### 14.2 特殊要求

以下改动必须补测试：

- 路由编排
- 阅读器行为
- 平台桥接协议
- Drift 仓库实现
- 启动流程与生命周期协调器
- capability 默认值或平台能力分支
- 条件导入文件
- 影响多个端的共享 widget / layout / theme token

### 14.3 多端验证要求

按改动类型选择验证集合：

- 纯 Dart 业务：`flutter analyze` + 对应 service/provider test。
- 共享 UI：`flutter analyze` + 相关 widget/smoke test + 目标视口矩阵。
- 平台能力：`flutter analyze` + 至少一个支持端和一个不支持端的能力验证。
- Web 编译边界：`flutter analyze` + `flutter build web --debug --no-web-resources-cdn --no-wasm-dry-run`。
- 数据库/条件导入：`flutter analyze` + 当前端测试 + Web 或 native build 基线。
- Web 首屏验证必须使用本地 Flutter Web 资源；`flutter run -d chrome` 和 Web 产物构建默认带 `--no-web-resources-cdn`，避免 CanvasKit / Roboto 依赖外网导致白屏。
- Web 首屏还必须检查插件注册日志；native/mobile 优先插件如编码检测、PDF、WebView、JS runtime 不得在 Web 注册阶段抛错，必要时用 Web stub 或条件依赖把能力降级到 application 层。
- 桌面 UI 改动至少验证一个真实桌面端 run 日志，RenderFlex overflow 视为失败，不能只依赖 widget smoke。

必须在 PR 或执行记录中写清：

- 本次改动影响哪些平台。
- 哪些平台应该不受影响。
- 已验证哪些平台 / 视口 / 字体缩放。
- 未验证项和原因。

### 14.4 禁止口径

- 只改大逻辑不补测试
- 只靠手点验证复杂回归
- 只验证当前开发机器平台，就宣称全平台可用
- 只验证手机竖屏，就合并共享 UI 改动

---

## 15. Code Review 检查清单

每个 PR 必须检查下面问题：

1. 页面里有没有直接 `new RepositoryImpl` 或 `AppDatabase.instance`
2. 页面里有没有直接调用 `MethodChannel`
3. 新增代码是不是默认先放进 feature 内，而不是先污染全局
4. `app/` 有没有新增具体业务编排
5. `router.dart` 有没有继续堆 feature 细节
6. 原生层有没有新增业务逻辑，而不是能力适配
7. 新 service 是否已 provider 化
8. 新模型放到全局 `domain` 是否真的跨 feature 共享
9. 是否补了对应层级的测试
10. 是否引入了新的静态单例或隐藏依赖
11. 是否新增了散落的 `kIsWeb` / `Platform.isXxx` / `defaultTargetPlatform` 判断
12. 是否通过 capability 隐藏、禁用或降级了不支持平台的入口
13. 是否使用条件导入隔离了 native-only / web-only 依赖
14. 是否说明了影响平台、非影响平台和验证矩阵
15. 是否有共享 UI 改动却只验证单一平台或单一视口

只要第 1、2、4、6、10、11、13、15 任一项回答为“有”，默认不通过。

---

## 16. 当前项目的明确整改方向

### 16.1 第一优先级

- 清理仓库中的签名文件与敏感配置
- 停止页面直接构造数据层实现
- 把新增平台差异统一收口到 `AppPlatformCapabilities`、bridge 或条件导入

### 16.2 第二优先级

- 拆薄 `lib/features/reader/presentation/reader_page.dart`
- 把阅读器依赖图收口到 provider
- 让 `reader_page.dart` 只保留页面壳与交互绑定
- 把阅读器平台能力、文件图片、键盘鼠标/触控差异继续向 application 层收口

### 16.3 第三优先级

- 拆分 `lib/app/app.dart` 中的启动与生命周期编排
- 将 `lib/app/router.dart` 重构为 feature route 聚合器
- 让启动任务、延期功能、平台受限能力都由 capability 控制

### 16.4 第四优先级

- 新增业务优先走 feature 内聚结构
- 全局 `domain/data` 只继续承载共享稳定能力
- 共享 UI 改动补齐多端视口测试基线

---

## 17. 落地执行规则

后续开发按以下顺序判断：

1. 这段代码是不是某个 feature 私有能力  
如果是，先放 feature 内。

2. 这段代码是不是页面渲染逻辑  
如果是，放 presentation。

3. 这段代码是不是业务编排  
如果是，放 application。

4. 这段代码是不是数据访问或平台实现  
如果是，放 data / core / runtime / bridge。

5. 这段代码是否跨多个 feature 共享且语义稳定  
如果是，再考虑提升到全局 `domain` 或 `core`。

6. 这段代码是否只适用于某个平台  
如果是，先放平台 adapter / bridge / 条件导入，不要直接放共享页面。

7. 这段代码是否影响共享 UI  
如果是，先列视口矩阵和非影响平台，再改代码。

---

## 18. 一票否决项

出现以下情况时，必须拦截：

- 新页面直接依赖 `AppDatabase`
- 新页面直接依赖 `RepositoryImpl`
- 新页面直接使用平台通道
- 新业务逻辑继续堆入 `App` 根 widget
- 新 feature 路由仍全部堆进一个总文件且带具体业务逻辑
- 新增原生代码承载 Flutter 本可统一处理的业务规则
- 再次提交签名密钥或构建产物
- 新增共享页面中的散落平台判断
- native-only / web-only 依赖直接进入共享 import 链
- 不支持平台仍展示可点击但必失败的入口
- 共享 UI 改动未说明多端影响和验证矩阵

---

## 19. 文档联动

本文件是“开发约束”的唯一基线。

关联文档：

- `docs/engineering_guide.md`：工程总览
- `docs/all_platform_compatibility_plan_2026-05-11.md`：全平台兼容总计划
- `docs/page_function_multiplatform_methods_2026-05-12.md`：逐页面功能多端兼容方法
- `docs/page_ui_multiplatform_display_plan_2026-05-12.md`：逐页面 UI 多端兼容展示计划
- `docs/cross_platform_boundary_refactor_plan.md`：跨端与原生边界
- `docs/flutter_adaptive_baseline_matrix.md`：自适应基线矩阵
- `docs/adaptive_visual_regression_checklist.md`：自适应视觉回归清单
- `docs/archive/reader_page_decomposition_plan_2026-04-26.md`：阅读器历史拆解执行文档

如果这些文档与本文件冲突，以本文件为准，并同步修正文档。
