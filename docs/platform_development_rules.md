# Web / Desktop / Mobile 平台规则

更新时间：2026-06-03

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

macOS 通过不代表 Windows / Linux 通过。文档和执行记录必须明确写清楚已验证平台。

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
