# Web / Desktop / Mobile 平台规则

更新时间：2026-06-02

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

## 2. 移动端保护规则

Android / iOS 是稳定基线：

- 不因 Web / Desktop 适配重写移动端页面。
- 不改变移动端路由、交互、数据路径和用户习惯。
- 如果必须修改共享层，需要说明移动端影响面并补回归。
- 移动端已有平台桥保持稳定，只做等价抽取。

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

Native 平台：

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
dart run tool/check_architecture_guardrails.dart
dart run tool/check_storage_governance_guard.dart
dart run tool/check_route_inventory.dart
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
