# Web / Windows / macOS 渐进式适配规则

创建日期：2026-05-30  
适用范围：在 iOS / Android 已稳定上线的前提下，逐步扩展 Web、Windows、macOS。  
最高原则：**业务内核复用，平台外壳分离；移动端不被迁就，新平台通过适配层加入。**

## 0. 核心红线

- Android / iOS 现有 UI、交互、状态流、业务逻辑和数据路径视为受保护区域。
- 新平台适配默认不得直接修改移动端已验证代码。
- 新平台只能通过 wrapper、adapter、facade、shell 分流、capability 能力表等方式附加。
- 如必须调整共享底层，必须单独做移动端影响评审，并完成 Android / iOS 回归。
- 无法证明移动端不受影响的改动，不进入合并范围。

## 1. 代码隔离规则

### 1.1 移动端受保护

移动端现有代码应视为 **Protected Mobile Surface**。后续 Web / Desktop 能力通过外层附加：

- Wrapper：外层判断平台，移动端继续走原组件，新平台走新组件。
- Adapter：把文件、存储、分享、通知等平台差异隐藏在接口后。
- Facade：页面只调用业务语义，例如“选择文件”“保存设置”。
- Shell：移动端使用现有壳，Web / Desktop 使用独立壳。
- Capability：统一声明平台支持能力，页面不散落平台判断。

### 1.2 目录建议

```text
lib/
  app/
    shell/
      mobile/
      desktop/
      web/
    platform/
      capabilities/
      adapters/
  features/
    <feature>/
      domain/
      application/
      presentation/
        mobile/
        desktop/
        web/
        adaptive/
  core/
    storage/
    file/
    share/
    device/
```

分层规则：

- `domain` / `application` 尽量平台无关。
- `presentation/mobile` 保护现有移动端。
- `presentation/desktop`、`presentation/web` 新增，不回写移动端。
- `adaptive` 只负责分流，不写复杂业务。
- 平台 SDK、插件、文件系统、浏览器 API 全部放 adapter。

### 1.3 复用移动端组件

- 优先组合，不改内部。
- 在外层添加约束、滚动、快捷键、hover、右键菜单。
- 如果移动端组件不适合桌面，复制业务语义并新建桌面组件。
- 抽出只读 ViewModel / props，让 mobile 和 desktop 吃同一份数据。

推荐模式：**Presenter / ViewModel + 多套 View**。

## 2. UI 适配规则

### 2.1 一个功能，多套外观

同一功能拆成：

- `FeatureState / Controller`：平台无关。
- `MobileView`：现有移动端 UI。
- `DesktopView`：桌面网格、多栏、预览面板。
- `WebView`：Web 可用版本，必要时能力受限。
- `AdaptiveView`：根据断点和平台选择。

不要强行把一个移动端组件改成全平台万能组件。

### 2.2 断点建议

- `< 600`：Mobile，保持现有移动端布局。
- `600 - 839`：Tablet Compact，可双列但触控优先。
- `840 - 1199`：Tablet / Small Desktop，可启用侧栏、宽内容区。
- `>= 1200`：Desktop，多栏、网格、预览面板。
- `>= 1600`：Wide Desktop，提高信息密度，但内容仍需最大宽度。

红线：**小于 600 的布局必须保持移动端现状。**

### 2.3 导航结构

- Mobile Shell：底部导航 + 页面栈，保持现状。
- Desktop / Web Shell：左侧导航栏 + 内容区 + 可选详情面板。
- 路由名称可以共享，Shell 不共享。
- 深层页面可以共享状态和用例，不共享页面骨架。

规则：**根导航可以分家，业务状态不要分家。**

### 2.4 鼠标键盘交互

转换规则：

- 长按 -> 右键菜单 / 更多按钮。
- 左滑删除 -> 显式操作按钮 / 右键菜单。
- 下拉刷新 -> 刷新按钮 / 快捷键。
- 手势翻页 -> 键盘方向键、空格、滚轮。
- 触摸反馈 -> hover、focus ring、选中态。
- 底部弹层 -> dialog、popover、side panel。

统一入口建议：

- `DesktopInteractionWrapper`
- `AdaptiveActionSurface`
- `ContextMenuAdapter`
- `KeyboardShortcutLayer`

## 3. 业务逻辑适配规则

### 3.1 平台无关与平台特定

平台无关：

- 实体模型
- 用例规则
- 状态机
- 数据转换
- 网络协议
- 权限前业务判断
- 阅读进度、收藏、设置等业务语义

平台特定：

- UI 布局
- 本地文件读写
- 数据库存储实现
- 相机、定位、通知、支付
- 分享、剪贴板、窗口控制
- 浏览器路由、缓存、CORS
- 桌面菜单、快捷键、右键

### 3.2 存储切换

调用处不得判断平台。应定义抽象接口，各平台实现：

- Mobile：SharedPreferences / SQLite。
- Web：localStorage / IndexedDB。
- Desktop：SQLite / JSON / app data directory。

调用方只知道保存、读取、清除，不知道底层实现。

### 3.3 不支持能力

处理优先级：

1. 有替代方案：展示替代方案。
2. 没有替代方案但用户需要知道：显示禁用态和原因。
3. 用户不需要感知：隐藏入口。
4. 高风险能力：默认隐藏，不让用户点击失败。

## 4. 逐个功能适配流程

### 4.1 适配前评估

- 依赖哪些移动端插件。
- 是否使用文件、相机、定位、通知、支付、震动。
- 是否有散落平台判断。
- UI 是否依赖触摸手势。
- 数据是否可跨平台存储。
- Web 是否存在 CORS、刷新路由、浏览器权限问题。
- 是否需要桌面快捷键、右键、窗口尺寸适配。
- 移动端现有路径是否能完全不动。

### 4.2 适配步骤

1. 冻结移动端现状，记录关键截图和核心流程。
2. 抽象平台能力接口，不改移动端实现。
3. 新增 Web / Desktop adapter。
4. 新增 Desktop / Web UI，不改 Mobile UI。
5. 新增 Adaptive Wrapper 负责分流。
6. 接入 feature 入口。
7. 做四端验证。
8. 只给已完成项打勾，未验证项保持未完成。

### 4.3 四平台验证

- iOS：原流程不变。
- Android：原流程不变。
- Web：可打开、刷新不丢状态、不白屏。
- Windows：窗口缩放、鼠标、键盘、文件路径正常。

最低检查：

- `flutter analyze`
- `flutter test`
- Web build
- 至少一个桌面端 build / run
- 移动端核心流程冒烟
- 移动端关键页面截图对比

### 4.4 必须修改移动端原代码时

默认先不改，处理顺序：

1. 尝试 wrapper。
2. 尝试 adapter。
3. 尝试复制一份新平台组件。
4. 仍必须改共享底层时，写清影响范围。
5. 单独开移动端影响评审。
6. 补 Android / iOS 回归。
7. 没有回归结果，不合入。

## 5. 平台差异化清单

| 功能 | Web 处理 | 桌面处理 | 优雅降级 |
| --- | --- | --- | --- |
| 相机拍照/相册选择 | 文件上传，浏览器相机需 HTTPS 和授权 | 文件选择 | 上传图片或隐藏拍照 |
| GPS 定位 | 浏览器 Geolocation，需 HTTPS 和授权 | 通常不可靠，可手动选择 | 手动选择城市/位置 |
| 推送通知 | Web Push，配置复杂 | 系统通知，平台差异大 | 站内消息/轮询提醒 |
| 本地数据库 | IndexedDB / Drift Web | SQLite | Web 受限本地存储 |
| 文件读写 | File API，沙盒受限 | 应用数据目录/文件选择器 | 只允许导入/导出 |
| 分享功能 | Web Share API，兼容性不一 | 复制链接/系统分享有限 | 复制到剪贴板 |
| 支付 | Web 收银台/第三方支付页 | 浏览器打开支付页 | 跳外部支付或提示不支持 |
| 版本更新 | 静态资源版本/刷新提示 | 检查更新、下载页 | 提示前往官网下载 |
| 震动/触感 | 基本不可靠 | 通常无意义 | 视觉反馈替代 |
| 指纹/面容 | WebAuthn 可选但复杂 | Windows Hello / Touch ID 可选 | 密码、验证码、PIN |

## 6. 避坑指南

- 为了复用强改移动端组件：新平台另建 View。
- 平台判断散落页面：统一 capability + adapter。
- Web 路由刷新 404：部署 fallback 到 `index.html` 或使用 hash 路由。
- CORS 导致 Web 网络失败：后端允许 Web origin，必要时走网关。
- native-only 依赖进入 Web import 链：条件导入、Web stub、adapter 隔离。
- 桌面端只是手机页面拉宽：独立 Shell、多栏、最大宽度、键鼠交互。
- 文件路径和权限假设错误：文件能力全部走平台 adapter。
- 包体积和首屏加载变差：资源本地化、按需加载、清理大资源。
- 字体和图标闪烁：字体资源本地打包，首屏避免外部 CDN。
- 移动端回归没测就合并：共享层变更必须跑 Android / iOS 冒烟。

