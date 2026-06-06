# Web / Desktop / Mobile 平台规则

更新时间：2026-06-06

本文定义 Android、iOS、Web、macOS、Windows、Linux 的平台差异处理规则。

## 1. 平台定位

| 平台 | 当前定位 |
| --- | --- |
| Android | 已稳定投入使用，受保护 |
| iOS | 已稳定投入使用，受保护 |
| Web JS | 可构建，可作为 Web 首版目标 |
| Web WASM | 暂不作为默认交付目标，需要独立专项 |
| macOS | debug 构建已验证，可进入桌面优先适配 |
| Windows | 需要 CI 或 Windows 机器验证 |
| Linux | 需要 CI 或 Linux 机器验证 |

## 2. 移动端规则

Android / iOS 是稳定基线，也是多端改动的验收对象：

- 不因 Web / Desktop 适配重写移动端页面。
- 不改变移动端路由、交互、数据路径和用户习惯。
- 如果必须修改共享层，需要说明移动端影响面并补回归。
- 移动端已有平台桥保持稳定，只做等价抽取。
- 桌面端任务不得顺手改动移动端 AppBar、bottom nav、bottom sheet、触控手势、更多菜单、选择模式、排序弹层和移动端搜索入口。
- 桌面端需要修改移动 / 桌面共用页面文件时，必须把新行为限制在桌面断点、desktop capability、adapter 或明确平台语义分支内；移动端原有分支必须保持等价。
- 涉及阅读器、导入、资源、缓存、登录、支付、分享、WebView、亮度、音量键、触感的改动，必须记录 Android / iOS 验证方式。
- 涉及 AndroidManifest、Info.plist、权限、原生插件或平台通道的改动，必须补移动端构建或真机 / 模拟器 smoke。

Android / iOS 能力入口必须按 capability 展示：

- 支持系统文件选择、相册选择、系统分享、移动端支付、亮度、音量键、触感等能力时，页面只读取语义能力，不直接判断插件实现。
- 不支持、未授权或系统限制时，入口要显示禁用、隐藏、只读或替代方案。
- 权限拒绝、永久拒绝、桥接失败要有可理解文案。

## 3. Web 规则

Web 首版按 JS 构建推进：

- `flutter build web --no-pub` 必须可通过。
- 页面刷新后不白屏。
- 深链路由可恢复。
- 不支持本地原生能力时给出禁用或替代入口。
- 文件上传可以作为 Web 本地图书能力的独立策略，但不得假装等同原生文件系统。

Web WASM 单独治理：

- 需要处理 FFI、sqlite、secure storage、Web 插件兼容。
- 不把 Web WASM 失败当成 Web JS 发布失败。
- 任何 WASM 目标都必须单独记录依赖风险和替换方案。

## 4. Desktop 规则

Desktop 默认包含 macOS、Windows、Linux。

桌面端必须具备：

- 最小窗口尺寸。
- 侧栏或桌面导航。
- 键盘、滚轮、hover、focus、右键或更多菜单。
- 文件选择、路径、缓存目录、诊断导出等能力通过 adapter。
- 不支持能力给出清晰禁用态。

桌面端默认按响应式布局验收：macOS、Windows、Linux 和 Web 大屏都要考虑窗口拖拽后的宽度变化。侧边栏、顶栏、工具按钮、搜索框、列表列数、详情分栏和弹窗宽度都不能只适配一个固定尺寸；窗口变窄时优先折叠工具和降低列数，窗口变宽时提升信息密度但不让正文无限拉伸。项目整体目标是自适应应用，即不同平台可以共享业务语义，但 UI 结构、入口位置和交互方式必须符合各自平台习惯。

桌面端开发保护移动端基线：

- 桌面端 UI / 交互任务优先改 `ShellScaffold`、desktop/adaptive wrapper、桌面专属 provider、capability 或 adapter，不反向改造已稳定的 Android / iOS 页面路径。
- 桌面端需要从共用页面调用业务动作时，优先用“桌面壳层注册动作 / facade / adapter”连接，不把移动端已有弹层、菜单或 AppBar 重写成新的共享实现。
- 桌面端任务完成前必须二次检查 diff，确认 Android / iOS 专属交互没有被重命名、抽取、替换或改变触发条件。

macOS 通过不代表 Windows / Linux 通过。文档和执行记录必须明确写清楚已验证平台。

macOS / Windows / Linux 任一桌面构建通过，也不代表 Android / iOS 通过。只要任务把桌面构建作为验收项，且当前机器已经具备移动端构建环境，就必须在同一任务内同步补 Android 和 iOS 构建；确实无法构建时，必须写明阻塞原因、对应命令和发布前补验入口。

## 5. Capability 规则

页面只能消费语义能力，例如：

- 是否支持本地文件导入。
- 是否支持托管文件存储。
- 是否支持原生 SQLite。
- 是否支持 Web 数据库存储。
- 是否支持图片选择。
- 是否支持阅读器亮度桥。
- 是否支持音量键翻页。

页面不得反复判断：

- `kIsWeb`
- `Platform.isXxx`
- `defaultTargetPlatform`
- 插件实现类型

如果确实需要平台判断，优先放到：

- `lib/app/platform/`
- `lib/core/**`
- `lib/data/**` 条件导入
- `lib/features/<feature>/application/**`

## 6. 文件与存储平台规则

Android / iOS 平台：

- 可使用应用支持目录、缓存目录、托管文件目录和原生 SQLite。
- 用户资产、书籍、字体、背景、主题资源必须落到受管目录，不得混入可随时清理的缓存目录。
- 文件选择和相册选择必须通过 adapter / bridge，不让页面直接处理真实路径。
- Android 分区存储、iOS Files / 沙盒访问必须按平台能力降级。
- 清理任务不得删除书架、阅读进度、书签、主题资源、用户上传文件或会话凭证。

Desktop Native 平台：

- 可使用应用支持目录、缓存目录、托管文件目录和原生 SQLite。
- 文件路径必须通过 resolver / store / adapter。
- 不让页面直接处理真实路径。

Web 平台：

- 不假设有持久真实文件路径。
- 数据库使用 Web storage / IndexedDB 路线。
- 本地文件能力以浏览器上传、内存读取、可重建缓存为核心。
- 用户资产持久化策略必须单独评估。

## 7. 构建与 CI 规则

推荐 PR 基线：

```bash
flutter analyze
dart tool/check_architecture_guardrails.dart
dart tool/check_storage_governance_guard.dart
dart tool/check_route_inventory.dart
flutter build web --no-pub
```

推荐本机可用构建矩阵：

```bash
flutter build web --no-pub
flutter build apk --debug --no-pub
flutter build ios --no-codesign --no-pub
flutter build macos --debug --no-pub
```

执行规则：

- 只跑 Web build 时，仍需按任务影响面判断 Android / iOS 是否需要补构建或 smoke。
- 只要跑了 macOS、Windows、Linux 任一桌面 build，就必须同步跑 Android / iOS build，或在收尾记录中写清无法构建的真实原因。
- macOS build 不能替代 Android / iOS build；Windows / Linux build 也不能替代 Android / iOS build。
- Android 默认使用 `flutter build apk --debug --no-pub` 做开发验收；发布验收再跑 release 或 flavor 对应包。
- iOS 默认使用 `flutter build ios --no-codesign --no-pub` 做开发验收；如签名、Pods、Xcode 或模拟器环境阻塞，必须记录阻塞点和后续补验方式。

推荐发布前矩阵：

- Android release。
- iOS release。
- Web JS release。
- macOS build。
- Windows build。
- Linux build。

Windows / Linux 无法在本机验证时，必须交给 CI 或对应平台机器。

共享层或平台能力改动的收尾记录必须写清：

- Android 是否验证，未验证原因是什么。
- iOS 是否验证，未验证原因是什么。
- Web 是否验证，未验证原因是什么。
- macOS / Windows / Linux 是否分别验证，未验证原因是什么。
- 哪些平台只是代码级不回退，哪些平台完成了真实操作。
