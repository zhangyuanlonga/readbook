# A4 Capability 三态化

更新时间：2026-05-13

## 0. 目标

平台能力不再只表达“支持/不支持”，而是区分：

- `supported`：当前环境可直接使用。
- `needsSetup`：平台具备条件，但需要构建开关、权限、配置、登录或依赖。
- `unsupported`：当前平台或运行环境不支持。

## 1. 当前代码入口

- `lib/app/platform/app_capability_state.dart`
- `lib/app/platform/app_platform_capabilities.dart`

## 2. 已完成

- [x] 新增 `AppCapabilityState` 和 `AppCapabilityAvailability`。
- [x] `AppPlatformCapabilities` 保留旧 `supportsXxx` getter，避免一次性改动所有页面。
- [x] 高风险能力已有三态字段：本地文件导入、受管文件存储、SQLite、图片选择、亮度/音量桥接、书源运行时、交互式 WebView、WebDAV。
- [x] 桌面端默认关闭的书源/WebDAV 能力现在可表达为 `needsSetup`，而不是直接混成 unsupported。
- [x] Web 端原生文件能力保持 `unsupported`。

## 3. 页面使用规则

- 新页面需要展示能力入口时，优先读取三态字段，而不是只读 `supportsXxx`。
- `supported`：正常显示并允许点击。
- `needsSetup`：入口可以显示，但应置灰、显示引导或进入解释页。
- `unsupported`：隐藏入口或进入 `FeatureDisabledPage`。
- 旧页面可以继续使用 `supportsXxx`，迁移时逐步替换。

## 4. 后续迁移

- [x] 文件导入入口从 bool 判断迁移到 `localFileImport` 三态。
- [x] WebDAV 设置页迁移到 `webDavSync` 三态。
- [x] 书源、搜索、发现、WebView 登录迁移到 `sourceRuntime` / `interactiveWebView` 三态。
- [x] 为 `needsSetup` 补统一禁用按钮和引导文案组件。

## 5. 本次补充

- `FeatureDisabledPages` 支持透传 `AppCapabilityState`，禁用页可显示 capability 的 `reason`。
- 书源、发现、搜索、在线详情、在线章节、WebDAV 同步路由从旧 bool 判断迁移到三态字段。
- 桌面/Web 这类 `needsSetup` 场景可以保留入口，点击后进入解释页，不再静默隐藏成“什么都没有”。
- 本地书库、字体管理的文件导入入口改读 `localFileImport` / `managedFileStorage` 三态，并展示对应降级原因。
