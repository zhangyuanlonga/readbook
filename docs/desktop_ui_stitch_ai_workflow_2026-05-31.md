# Stitch 到 AI 的桌面端 UI 实现流程

创建日期：2026-05-31  
适用范围：Web、Windows、macOS、Linux 的桌面端 UI 设计落地。  
关联基线：

- `docs/desktop_ui_phase1_shell_mine_milestone_2026-05-31.md`
- `docs/web_desktop_business_logic_compatibility_rules_2026-05-31.md`

核心目标：**用 Stitch 先做桌面端页面原型，再让 AI 按里程碑规则实现 Flutter 桌面分支，同时不牵扯已经成熟的 iOS / Android 移动端产品。**

## 0. 文档定位

本文是执行流程文档，不替代里程碑文档。

- 里程碑文档负责定义桌面端 UI 的阶段范围、验收规则和不做什么。
- 业务兼容规则文档负责定义 Web / Desktop 业务链如何复用业务内核、隔离平台能力。
- 本文负责定义：Stitch 产物如何交给 AI，AI 如何拆解、实现、验证和记录。

因此本文建议单独维护，不合并进里程碑正文。里程碑是基线，本文是工作方法。

## 1. 基本原则

### 1.1 平台边界

本流程只服务桌面端：

- Web
- Windows
- macOS
- Linux

iOS / Android 不进入本流程的 UI 任务、截图验收和交互重做范围。

如果桌面端实现必须改共享组件或共享业务层，必须记录风险，但不能顺手重做移动端 UI。

### 1.2 实现边界

AI 实现时优先选择表现层分流：

- 桌面端：使用桌面布局、侧边栏、双列 / 多列、dialog、popover、side panel、键鼠交互。
- 移动端：保留现有成熟路径、bottom navigation、手机页面结构和交互。

禁止为了桌面端视觉，把移动端页面整体改成新结构。

### 1.3 产物边界

Stitch 产物用于提供桌面端视觉目标，但不直接决定业务能力是否完成。

一次 Stitch 页面只能驱动以下内容：

- 桌面端页面结构。
- 视觉层级。
- 间距、颜色、字体、图标方向。
- 交互入口和状态展示。
- 空态、禁用态、错误态的大致形态。

不能因为 Stitch 画了某个能力入口，就默认该业务链已经兼容 Web / Desktop。业务链仍需按兼容规则单独验收。

## 2. 推荐流程

### 2.1 在 Stitch 设计页面

每个页面或页面组建议在 Stitch 中明确命名：

- 业务模块：例如 `登录与注册`、`系统导航框架`、`我的页仪表盘`。
- 平台口径：例如 `桌面端`、`Web / Desktop`。
- 主题：例如 `霁雪白主题`。
- 状态：例如 `未登录`、`已登录`、`空态`、`禁用态`。

推荐一次只设计一条窄范围链路：

- Shell + 一级导航。
- 登录与注册。
- 我的页首页。
- 一个设置类页面。
- 一个资源管理类页面。

不要一次把移动端、桌面端、完整业务链和所有异常态混在一张图里。

### 2.2 从 Stitch 交给 AI 的材料

交给 AI 时优先提供：

- Stitch 项目名和页面名。
- 页面截图。
- HTML 下载内容或结构摘要。
- 设计主题 / design theme。
- 页面要实现的目标文件或路由。
- 明确说明是否只做桌面端。
- 明确说明移动端不得改动。

如果截图下载失败，可以继续用 Stitch 的页面结构、设计主题和页面描述推进；但最终必须用 Flutter 运行或测试验证真实布局。

### 2.3 AI 拆解规则

AI 开工前必须先读：

- 本文档。
- 对应里程碑文档。
- 业务兼容规则文档。
- 目标 Flutter 文件的现有实现。
- 相关 widget / layout / route 测试。

拆解时必须输出或在实现中遵守：

- 本次只改哪些桌面端分支。
- 哪些移动端路径保持不动。
- 是否修改共享层。
- 是否涉及业务能力兼容。
- 需要补哪些桌面端测试。

### 2.4 Flutter 实现规则

优先做桌面端分支，而不是重写整个页面。

常用判断：

- `AppLayout.isDesktopLike(...)`
- `AppAdaptiveMetrics.isDesktopLikeForPlatform(...)`
- 已有断点：`600`、`840`、`1280`、`1600`

桌面端实现优先使用：

- 自定义 desktop shell / sidebar。
- 桌面页面标题区。
- 内容最大宽度。
- 双列或多列布局。
- `Dialog` / `Popover` / `SidePanel` 类形态。
- hover、focus、selected 状态。

移动端继续使用：

- 现有 bottom navigation。
- 现有手机页面结构。
- 现有 bottom sheet 或手机交互。

### 2.5 业务兼容规则

如果页面只是 UI 展示，可以只按里程碑 UI 规则验收。

如果页面涉及真实业务链，必须同时按两条线推进：

- 平台兼容线：能否 Web / Desktop 编译运行，平台能力是否隔离，禁用能力是否有降级。
- UI 展示线：是否符合桌面端布局，不是手机页面横向拉宽。

业务兼容时仍然遵守：

- 不把 iOS / Android 拉进本轮任务。
- 不为桌面端需求改造移动端流程。
- 共享层变更只记录风险和必要验证，不扩大范围。

## 3. AI 实现提示模板

可以把下面模板贴给 AI：

```text
请按桌面端 UI 第一里程碑实现这个 Stitch 页面。

Stitch 页面：
- 项目：
- 页面：
- 主题：
- 截图 / HTML：

实现范围：
- 只做 Web / Desktop。
- iOS / Android 移动端路径保持不动。
- 优先在现有页面中增加桌面端分支，不重写移动端实现。

必须先阅读：
- docs/desktop_ui_phase1_shell_mine_milestone_2026-05-31.md
- docs/web_desktop_business_logic_compatibility_rules_2026-05-31.md
- docs/desktop_ui_stitch_ai_workflow_2026-05-31.md

验收要求：
- flutter analyze 通过。
- 相关 widget / layout smoke 通过。
- 覆盖至少一个桌面端真实或测试视口。
- 说明是否修改共享层。
- 说明是否涉及移动端；默认应为未涉及。
```

## 4. 验收清单

每次 Stitch 页面落地后，收尾必须记录：

- 修改文件。
- 对应 Stitch 页面。
- 是否只改桌面端分支。
- 移动端是否未涉及。
- 是否修改共享层。
- 不支持能力的处理方式：隐藏、禁用、只读、外部打开、延期。
- 已跑测试。
- 未验证平台和原因。

推荐测试：

- `flutter analyze`
- 目标页面 widget smoke。
- Shell / layout 断点测试。
- 关键桌面视口测试：`840x900`、`1280x800`、`1490x948`、`1600x1000`

如果是 Web / Desktop 真实验证，必须记录：

- Web 是否可打开。
- macOS 是否可打开。
- Windows / Linux 是否待补验。
- 是否存在浏览器刷新、路由、滚动、弹层、键盘焦点问题。

## 5. 常见失败模式

### 5.1 手机页面被横向拉宽

表现：

- 内容无限拉宽。
- 表单过宽。
- 卡片间距松散。
- 手机 AppBar 和 bottom sheet 直接出现在桌面端。

处理：

- 增加桌面端页面容器。
- 限制最大宽度。
- 使用双列 / 多列 / 详情面板。
- 弹层改为 dialog / popover / side panel。

### 5.2 桌面分支影响移动端

表现：

- 手机底部导航消失。
- 手机页面间距变大。
- 手机弹层形态变化。
- 手机测试因为桌面改造失败。

处理：

- 把桌面分支收敛到 `AppLayout.isDesktopLike` 或现有 adaptive metrics 内。
- 保持移动端原 widget 路径。
- 为桌面端新增测试锚点，不用移动端旧断言硬套桌面结构。

### 5.3 Flutter 无界约束错误

表现：

- `RenderFlex children have non-zero flex but incoming height constraints are unbounded`
- `RenderBox was not laid out`
- 宽屏或 Web 运行时报错，但普通手机 smoke 不报错。

常见原因：

- `SingleChildScrollView` 内的 `Column` 使用 `Expanded` 或 `Spacer`。
- 横向布局里的某个面板没有有限高度。
- 桌面端分支只在 Web 或桌面平台触发，普通 widget 测试没有覆盖。

处理：

- 给桌面面板明确有限高度。
- 在滚动容器内避免 `Expanded` / `Spacer`。
- 增加 Web-like 或 desktop-like 视口测试。

### 5.4 Stitch 视觉和 Flutter 组件不匹配

表现：

- 用 `NavigationRail` 强行拼完整侧栏，导致图标居中、文字不对齐或 overflow。
- Material 默认组件形态和原型相差很远。

处理：

- 原型是完整侧栏时，优先自定义 desktop sidebar。
- 继续复用导航状态和路由语义。
- 测试锚点验证新的桌面结构，而不是旧组件类型。

## 6. 文档维护方式

本文作为 Stitch + AI 执行流程单独维护。

当里程碑范围变化时，优先改里程碑文档。

当业务兼容范围变化时，优先改业务兼容规则文档。

当 Stitch 交付方式、AI 实现步骤、测试模板或常见失败模式变化时，更新本文。
