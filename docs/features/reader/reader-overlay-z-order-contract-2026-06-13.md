# 阅读器 Overlay / Chrome Z-Order 契约

**日期**: 2026-06-13  
**对应代码**:

- `lib/features/reader/presentation/reader_overlay_z_order.dart`
- `lib/features/reader/presentation/reader_shell.dart`
- `lib/features/reader/presentation/reader_page_viewport.dart`

---

## 1. 目标

阅读器只允许通过固定层级挂载背景、内容、chrome 和前景浮层，避免新增功能临时塞全屏透明层导致按钮点击、文本选择、纸页动画互相吞事件。

---

## 2. ReaderShell 主层级

主视觉 Stack 必须按 `readerShellLayerOrder` 渲染：

1. `background`: 背景色、背景图片、阅读纸张背景。
2. `backgroundOverlay`: 亮度/暗度遮罩，只允许 `IgnorePointer`。
3. `content`: 阅读正文、漫画、音频、PDF 等内容。
4. `center`: 居中装饰或状态层，只允许 `IgnorePointer`。
5. `top`: 顶部 chrome。
6. `bottom`: 底部 chrome。
7. `leading`: 左侧 chrome。
8. `trailing`: 右侧 chrome。
9. `foregroundOverlay`: 最高 reader 内浮层，可按自身规则接收手势。

新增主层级必须先改 `ReaderShellLayerSlot` 和测试，不允许直接在 `Stack.children` 里插入匿名层。

---

## 3. Foreground Overlay 层级

`ReaderShellChromeSlots.foregroundOverlay` 内部必须按 `readerForegroundOverlayOrder` 渲染：

1. `chapterLoading`: 章节轻量加载提示。
2. `autoReadStatus`: 自动阅读状态层。
3. `overlayScrim`: chrome 遮罩层。
4. `topChrome`: 顶部工具栏。
5. `bottomChrome`: 底部工具栏、进度条、上一章/下一章。

前景层默认不新增独立全屏手势捕获层；如果必须拦截点击，需要在代码和文档里说明 hit-test 原因。

---

## 4. 手势约束

- 背景、背景遮罩、中心装饰必须 `IgnorePointer`。
- chrome 按钮必须通过 command 入口触发业务动作。
- reader 内容区的文本选择、PageView、InteractiveViewer 可以保留内部手势，但必须通过 childHandled 或 command 与 reader 级输入协调。
- root `OverlayEntry` 仅保留给系统选择锚点类浮层，后续迁移前必须验证定位准确性。

---

## 5. 当前发版关注点

- 上一章/下一章只通过 `ReaderNavigationCommandDispatcher` 判断和执行。
- 纸页卷动的第三方组件只允许在 adapter 边界内管理 snapshot/controller，不直接改业务状态。
- release/debug/profile 均需要保留 `reader.navigation_command`、`reader.interaction_state`、`reader.paper_curl` Timeline 事件用于真机 trace。

