# 里程碑 02：多端 UI 与桌面交互体验成型

创建日期：2026-06-02
复拆日期：2026-06-04

状态：待按多端分段执行。

适用平台：Android、iOS、Web JS、macOS、Windows、Linux。

核心目标：在 M1 已复验的在线阅读链和最小登录会话链基础上，让 Web / Desktop 宽屏使用像真正的桌面阅读应用，同时证明 Android / iOS 成熟移动端 UI、手势、导航和系统能力不回退。

## 1. 阶段定位

第二里程碑关注体验成型：

- M1 的工程绿线、在线阅读链、最小登录会话链应已完成复验；如果 M1 未完成，M2 只能做 UI 基线盘点和低风险组件治理。
- 桌面 shell 稳定。
- 书架、详情、阅读器、我的页具备桌面布局。
- 登录、会话过期、退出登录、受限入口在移动端、Web、Desktop 都有合适页面和弹层形态。
- 键鼠交互完整。
- 弹层形态从移动端 bottom sheet 迁到桌面合适形态。
- Android / iOS 保持触控、返回、Safe Area、软键盘、移动端 sheet 和阅读器手势体验。
- UI token 和 adaptive 组件成为默认写法。

## 2. 执行方式

每个 UI 段必须分成两条线：

- 移动端保持线：Android / iOS 小屏、触控、返回、Safe Area、软键盘、手势和移动端弹层不回退。
- 宽屏成型线：Web / Desktop 有独立布局、键鼠交互、hover / focus / selected 状态和桌面弹层形态。

M2 是 UI / 交互里程碑，不负责补齐 M3 的本地图书、资源持久化、诊断导出和缓存治理能力。UI 里遇到未完成能力时，只能通过 capability 展示禁用、隐藏、只读、外部打开或延期说明；如果必须新增 adapter、storage 或 parser，应拆回 M3。

任何 adaptive 组件、theme token 或共享 widget 的改动，都必须同时记录移动端和宽屏结果。

## 3. 不做项

- [x] 不做本地图书全格式完整闭环。
- [x] 不做 Web WASM。
- [x] 不重写移动端 shell。
- [x] 不把所有旧页面一次性拆完。
- [x] 不追求视觉大改版，优先做结构和交互正确。
- [x] 不在 UI 任务中顺手新增未设计的本地导入、资源存储、诊断导出或缓存清理实现。

## 4. M2 复拆执行段

| 段 | 名称 | 目标 | Android / iOS 检查 | Web / Desktop 检查 | 状态 |
| --- | --- | --- | --- | --- | --- |
| M2-0 | UI 基线盘点 | 列出本阶段页面、共享组件、弹层和平台能力入口 | 记录移动端现状截图 / smoke 范围 | 记录宽屏待改页面和断点风险 | [ ] |
| M2-1 | Shell 与导航 | 移动端 shell 保持，桌面 shell 成型 | bottom nav、返回、Safe Area 不回退 | 侧栏、顶部栏、全局入口稳定 | [ ] |
| M2-2 | 书架 UI | 书架多端可用 | 小屏卡片、筛选、长按或更多入口不回退 | 网格、工具栏、hover、右键或菜单可用 | [ ] |
| M2-3 | 详情页 UI | 详情页多端可读可操作 | 移动端主操作层级和底部区域不回退 | 元数据、目录、操作区分栏 | [ ] |
| M2-4 | 阅读器 UI / 交互 | 阅读器跨输入方式稳定 | 触控翻页、滚动、目录、设置、书签不回退 | 键盘、滚轮、hover、focus、面板形态可用 | [ ] |
| M2-5 | 我的页、账号与设置 | 设置类页面和账号状态多端信息结构清楚 | 移动端表单、sheet、登录态、退出登录和系统能力入口不回退 | 分组、最大宽度、资源入口、反馈入口、登录 / 退出入口清楚 | [ ] |
| M2-6 | 弹层与操作面 | 建立 adaptive action surface 使用规则 | 移动端继续使用合适 bottom sheet | 桌面使用 dialog / side panel / popover / menu | [ ] |
| M2-7 | Token 与组件治理 | 新 UI 走统一 token 和 adaptive 组件 | 小屏文字、按钮、卡片不遮挡 | 宽屏内容不无限拉宽，状态完整 | [ ] |
| M2-8 | UI 验收记录 | 输出多端 UI 验收矩阵 | 390 以下、390-479、480-599 检查 | 840、1280、1600、1920 检查 | [ ] |

## 5. Shell 与导航

- [ ] 移动端 bottom nav 路径保持稳定。
- [ ] Android 返回键和 iOS 返回手势不被桌面 shell 改动影响。
- [ ] 侧边栏导航稳定，当前 tab 明确。
- [ ] 顶部栏按当前 tab 展示合适操作。
- [ ] 搜索入口在书架和全局入口中都清晰。
- [ ] 公告入口、任务队列入口不遮挡内容。
- [ ] 宽度从 1024 到 1920 不出现无限拉伸。
- [ ] 窄于 600 时仍回到移动端布局。

## 6. 书架 UI

- [ ] 移动端书架卡片、筛选、排序、搜索、分类入口不回退。
- [ ] 移动端长按或更多入口仍可发现，误触保护不回退。
- [ ] 书架内容区有最大宽度和合理网格列数。
- [ ] 筛选、排序、搜索、标签、分类有桌面工具栏形态。
- [ ] 空态保留可用操作或明确禁用原因。
- [ ] 书籍卡片 hover、selected、loading、error 状态完整。
- [ ] 批量选择操作在桌面端不依赖移动端长按。
- [ ] 更多操作支持按钮菜单或右键菜单。
- [ ] 本地图书入口按平台能力展示：Android / iOS 保持既有路径，Desktop 可导入，Web 按上传 / 禁用策略展示。

## 7. 详情页 UI

- [ ] 移动端详情页主操作、封面、目录入口和底部区域不回退。
- [ ] 主内容、元数据、目录、操作区有桌面分栏。
- [ ] 封面和信息区不在宽屏下失衡。
- [ ] 目录支持滚动、搜索或定位当前章节。
- [ ] 主操作按钮在桌面宽度下保持清晰层级。
- [ ] 换源、加入书架、继续阅读等操作不挤在移动端底部区域。
- [ ] 失败和空态使用统一状态组件。

## 8. 阅读器 UI 与交互

- [ ] Android / iOS 触控翻页、滚动、目录、设置、书签、进度保存不回退。
- [ ] Safe Area、状态栏、底部手势区、刘海屏和横屏表现可接受。
- [ ] 方向键、空格、PageUp / PageDown 有明确行为。
- [ ] 鼠标滚轮在分页 / 滚动模式下行为稳定。
- [ ] hover 不干扰正文阅读。
- [ ] focus ring 和键盘导航可用。
- [ ] 目录、设置、书签、换源等面板具备桌面形态。
- [ ] 自动阅读、音频、漫画、PDF 的入口按内容模式和能力展示。
- [ ] 阅读器 chrome 在 1024 / 1440 / 1920 下不遮挡正文。

## 9. 我的页与设置类页面

- [ ] 我的页移动端信息流、入口顺序和系统能力入口不回退。
- [ ] 我的页桌面布局完成信息分组。
- [ ] 登录、会话过期、退出登录和受限能力入口在桌面端不依赖移动端 bottom sheet。
- [ ] 设置类页面有合理最大宽度。
- [ ] 表单类页面不无限拉宽。
- [ ] 主题、字体、图集、启动图等资源管理入口明确。
- [ ] 未进入 M3 的资源持久化能力只展示入口状态和降级说明，不在本阶段补存储实现。
- [ ] 会员、反馈、关于、错误中心在桌面下不依赖移动端底部弹层。

## 10. 弹层与操作面

迁移原则：

- 移动端继续使用 bottom sheet。
- 桌面端优先 dialog / side panel / popover / menu。
- 复杂设置面板优先 side panel 或 constrained dialog。
- 简单确认使用 dialog。
- 轻量选择使用 popover 或 menu。

任务：

- [ ] 建立统一 adaptive action surface 使用规则。
- [ ] 书架筛选 / 排序弹层改为桌面合适形态。
- [ ] 阅读器设置面板改为桌面合适形态。
- [ ] 详情页操作菜单改为桌面合适形态。
- [ ] 资源选择器改为桌面合适形态。
- [ ] 每个弹层迁移都记录移动端是否仍使用原有形态。

## 11. UI token 与组件治理

- [ ] 新 UI 默认使用 `AppAdaptiveMetrics`。
- [ ] 新 UI 默认使用 `AppComponentThemeTokens`。
- [ ] 新 UI 默认使用统一空态、加载态、失败态组件。
- [ ] 减少局部 `Color(0x...)`、`Colors.*`、硬编码圆角和阴影。
- [ ] `check_adaptive_layout_guard` 中关键问题下降。
- [ ] `check_ui_component_governance` high risk 页面逐步下降。

## 12. 测试与验收

建议测试：

```bash
flutter test test/app/layout/adaptive_breakpoints_test.dart test/app/layout/adaptive_ui_matrix_test.dart
flutter test test/app/widgets/adaptive_components_test.dart
flutter test test/features/bookshelf/presentation/bookshelf_desktop_layout_test.dart
flutter test test/features/reader/application/reader_desktop_input_resolver_test.dart
flutter test test/features/presentation/account_page_smoke_test.dart test/features/auth/application/auth_provider_smoke_test.dart
```

建议 guard：

```bash
dart run tool/check_adaptive_layout_guard.dart --fail
dart run tool/check_ui_component_governance.dart
flutter build web --no-pub
```

移动端补验按可用环境选择：

```bash
flutter build apk --no-pub
flutter build ios --no-pub --no-codesign
```

通过标准：

- [ ] M2-0 到 M2-8 均有执行记录。
- [ ] M1 在线阅读链和最小登录会话链的 UI 入口在 M2 改动后仍可走通。
- [ ] 390 以下、390-479、480-599 移动端关键页面不溢出、不遮挡。
- [ ] Android / iOS 返回、Safe Area、软键盘、触控命中区域和阅读器关键手势不回退。
- [ ] 1024 / 1440 / 1600 / 1920 宽度关键页面不溢出、不遮挡。
- [ ] 桌面交互不依赖长按、下拉刷新、滑动删除。
- [ ] 书架桌面空态测试通过。
- [ ] Web / macOS 体验完整。
- [ ] Windows / Linux 至少进入 CI 构建验证或明确补验原因。

## 13. 风险

- [ ] UI 改动容易误伤移动端，需要小屏回归。
- [ ] 弹层迁移可能影响阅读器复杂设置。
- [ ] 桌面交互如果只做快捷键、不做可见按钮，会降低可发现性。
- [ ] 高级主题会放大硬编码颜色和局部样式问题。
- [ ] 共享 adaptive 组件如果缺少注释和验收记录，后续维护成本会继续上升。

## 14. 执行记录

- [ ] 开始日期：
- [ ] 完成日期：
- [ ] Android 验证：
- [ ] iOS 验证：
- [ ] Web 验证：
- [ ] macOS 验证：
- [ ] Windows 验证：
- [ ] Linux 验证：
- [ ] 未验证平台和原因：
- [ ] 关键改动：
- [ ] 遗留问题：
