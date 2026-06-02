# 里程碑 02：桌面 UI 与交互体验成型

创建日期：2026-06-02

状态：待执行

适用平台：Web JS、macOS、Windows、Linux。Android / iOS 作为受保护基线。

核心目标：让 Web / Desktop 宽屏使用像一个真正的桌面阅读应用，而不是移动端页面横向拉宽。

## 1. 阶段定位

第二里程碑关注体验成型：

- 桌面 shell 稳定。
- 书架、详情、阅读器、我的页具备桌面布局。
- 键鼠交互完整。
- 弹层形态从移动端 bottom sheet 迁到桌面合适形态。
- UI token 和 adaptive 组件成为默认写法。

## 2. 不做项

- [x] 不做本地图书全格式完整闭环。
- [x] 不做 Web WASM。
- [x] 不重写移动端 shell。
- [x] 不把所有旧页面一次性拆完。
- [x] 不追求视觉大改版，优先做结构和交互正确。

## 3. 桌面 Shell

- [ ] 侧边栏导航稳定，当前 tab 明确。
- [ ] 顶部栏按当前 tab 展示合适操作。
- [ ] 搜索入口在书架和全局入口中都清晰。
- [ ] 公告入口、任务队列入口不遮挡内容。
- [ ] 宽度从 1024 到 1920 不出现无限拉伸。
- [ ] 窄于 600 时仍回到移动端布局。

## 4. 书架桌面版

- [ ] 书架内容区有最大宽度和合理网格列数。
- [ ] 筛选、排序、搜索、标签、分类有桌面工具栏形态。
- [ ] 空态保留可用操作或明确禁用原因。
- [ ] 书籍卡片 hover、selected、loading、error 状态完整。
- [ ] 批量选择操作在桌面端不依赖移动端长按。
- [ ] 更多操作支持按钮菜单或右键菜单。
- [ ] 本地图书入口按平台能力展示：Desktop 可导入，Web 按上传/禁用策略展示。

## 5. 详情页桌面版

- [ ] 主内容、元数据、目录、操作区有桌面分栏。
- [ ] 封面和信息区不在宽屏下失衡。
- [ ] 目录支持滚动、搜索或定位当前章节。
- [ ] 主操作按钮在桌面宽度下保持清晰层级。
- [ ] 换源、加入书架、继续阅读等操作不挤在移动端底部区域。
- [ ] 失败和空态使用统一状态组件。

## 6. 阅读器桌面交互

- [ ] 方向键、空格、PageUp / PageDown 有明确行为。
- [ ] 鼠标滚轮在分页 / 滚动模式下行为稳定。
- [ ] hover 不干扰正文阅读。
- [ ] focus ring 和键盘导航可用。
- [ ] 目录、设置、书签、换源等面板具备桌面形态。
- [ ] 自动阅读、音频、漫画、PDF 的入口按内容模式和能力展示。
- [ ] 阅读器 chrome 在 1024 / 1440 / 1920 下不遮挡正文。

## 7. 我的页与设置类页面

- [ ] 我的页桌面布局完成信息分组。
- [ ] 设置类页面有合理最大宽度。
- [ ] 表单类页面不无限拉宽。
- [ ] 主题、字体、图集、启动图等资源管理入口明确。
- [ ] 会员、反馈、关于、错误中心在桌面下不依赖移动端底部弹层。

## 8. 弹层与操作面

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

## 9. UI token 与组件治理

- [ ] 新 UI 默认使用 `AppAdaptiveMetrics`。
- [ ] 新 UI 默认使用 `AppComponentThemeTokens`。
- [ ] 新 UI 默认使用统一空态、加载态、失败态组件。
- [ ] 减少局部 `Color(0x...)`、`Colors.*`、硬编码圆角和阴影。
- [ ] `check_adaptive_layout_guard` 中关键问题下降。
- [ ] `check_ui_component_governance` high risk 页面逐步下降。

## 10. 测试与验收

建议测试：

```bash
flutter test test/app/layout/adaptive_breakpoints_test.dart test/app/layout/adaptive_ui_matrix_test.dart
flutter test test/app/widgets/adaptive_components_test.dart
flutter test test/features/bookshelf/presentation/bookshelf_desktop_layout_test.dart
flutter test test/features/reader/application/reader_desktop_input_resolver_test.dart
```

建议 guard：

```bash
dart run tool/check_adaptive_layout_guard.dart --fail
dart run tool/check_ui_component_governance.dart
flutter build web --no-pub
```

通过标准：

- [ ] 1024 / 1440 / 1600 / 1920 宽度关键页面不溢出、不遮挡。
- [ ] 桌面交互不依赖长按、下拉刷新、滑动删除。
- [ ] 书架桌面空态测试通过。
- [ ] Web / macOS 体验完整。
- [ ] Windows / Linux 至少进入 CI 构建验证。

## 11. 风险

- [ ] UI 改动容易误伤移动端，需要小屏回归。
- [ ] 弹层迁移可能影响阅读器复杂设置。
- [ ] 桌面交互如果只做快捷键、不做可见按钮，会降低可发现性。
- [ ] 高级主题会放大硬编码颜色和局部样式问题。

## 12. 执行记录

- [ ] 开始日期：
- [ ] 完成日期：
- [ ] 已验证平台：
- [ ] 未验证平台和原因：
- [ ] 关键改动：
- [ ] 遗留问题：
