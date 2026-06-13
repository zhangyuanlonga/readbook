# 阅读器层级堆叠代码对照审计与阶段计划

**日期**: 2026-06-13  
**对照文档**: `docs/features/reader/layer-stacking-problem-analysis-2026-06-13.md`  
**结论**: 原文抓到了“阅读器层级/手势/动画/浮层协调复杂”这个真实方向，但里面大量代码证据是旧结构或伪代码，不能照着伪代码推倒重写。结合当前已出现的 release 包纸页卷动异常、上一章/下一章点击无响应，长期方向应明确为“能统一就统一、能标准化就标准化”，只是统一点要落在稳定边界：输入、命令、翻页动画、第三方组件适配、overlay z-order，而不是简单追求少几个 widget。

---

## 1. 当前代码基线

- `lib/features/reader/presentation/reader_page.dart`: 5383 行。
- `lib/features/reader/presentation/reader_page.dart` 直属 part: 13 个。
- `lib/features/reader/presentation/reader_page_viewport.dart`: 491 行。
- `lib/features/reader/presentation/reader_page_selection.dart`: 1018 行。
- `lib/features/reader/presentation/reader_paper_curl_paged_view.dart`: 531 行。
- `lib/features/reader/presentation/paged_animation/reader_paged_animation_surface.dart`: 123 行。
- `lib/features/reader/presentation/reader_shell.dart`: 229 行。
- `lib/features/reader/presentation/reader_pointer_input_controller.dart`: 252 行。

---

## 2. 原审计结论逐项校准

| 原文判断 | 当前代码事实 | 结论 | 建议 |
|---|---|---|---|
| 当前至少 8-10 层，层级堆叠严重 | 当前确实有 `ReaderShell` Stack、viewport foreground Stack、paged animation surface、paper curl 内部 snapshot Stack、selection root overlay、modal sheet。 | 部分成立 | 需要梳理 z-order 和状态契约，但不能仅按层数判断性能或冲突。 |
| `reader_page_viewport.dart` 直接返回 background/content/animation/touch 的大 Stack | 当前入口是 `ReaderPageScaffoldShell -> ReaderShell`，viewport 主要构造 shell model，foreground overlay 是一个 Stack。 | 不成立/过期 | 原文代码证据不能作为当前改造依据。 |
| `reader_page.dart` build 又包一层 Stack | 当前 build 委托 `_buildReaderPageScaffold`，Scaffold 在 `ReaderPageScaffoldShell`，主 Stack 在 `ReaderShell`。 | 不成立/过期 | 不应按原文“清理 reader_page build 多层 Stack”执行。 |
| 3-4 个 GestureDetector 重叠导致冲突 | 当前 reader 级输入主要由 `_buildTapAwareBody` 的 `Listener` + `ReaderPointerInputController` 处理；`ReaderShell` 虽支持 callbacks，但当前 resolver 没传 callbacks；`SelectionArea`、书签面板 dismiss、漫画缩放等仍有自己的手势。 | 部分成立 | 重点不是强行变成一个 GestureDetector，而是定义手势优先级契约和测试。 |
| 创建唯一 `ReaderGestureCoordinator`，移除各层 GestureDetector | 文本选择、PageView/纸页卷动、InteractiveViewer、Overlay dismiss 都依赖 Flutter/第三方自己的手势机制。 | 不建议直接做 | 可做“手势协调门面/状态机”，但不能移除所有组件内部手势。 |
| 5+ 个 AnimationController 互相干扰 | 当前 `_ReaderPageState` 有 4 个 `AnimationController`: overlay controls、paged transition、curl auto turn、cross chapter snapshot；paper curl 使用第三方 `PageFlipController` 和 snapshot 状态。 | 部分成立 | 动画并发状态需要收口，但不建议合成唯一 controller。 |
| Paper Curl + Paged Animation 分离，应合并为单一动画协调器 | 当前 `ReaderPagedAnimationSurface` 已是统一入口，按 render mode 选择 static、paper curl、transition；`ReaderPaperCurlPagedView` 已声明只持有组件内部动画/快照状态。 | 部分成立但方向需修正 | 应保留 renderer 职责边界，增加动画状态门禁/日志，而不是拆掉现有统一入口。 |
| 背景图/设置变更会全局重建、阻塞主线程 | 设置变更仍会触发 reader state rebuild；但背景已有缓存、文件存在性异步检查、自定义背景压缩 `compute`。 | 部分成立 | 先 profile Android 真机主题/背景切换；确认 jank 后再隔离背景 layer。 |
| Selection Toolbar / Bookmark Toolbar 用 OverlayEntry 脱离层级，应移除 | Bookmark toolbar 使用 root `OverlayEntry` 和 `TextSelectionToolbarAnchors`，这是为了跟随系统选择锚点和跨层显示；确实有层级复杂性。 | 部分成立 | 先做可行性实验，不应直接移除 OverlayEntry。 |
| 性能提升 40%、维护性 +200%、P0 必须重构 | 原文没有 profiler、jank trace、widget rebuild 统计支撑。 | 不成立 | 先做基线测量，再决定是否进入高风险重构。 |

---

## 3. 真实问题归纳

- [x] 阅读器仍有多个展示层和浮层来源，z-order 规则需要写成显式契约。
- [x] 手势入口已经比旧结构收口，但文本选择、点击分区、滑动翻页、纸页卷动、漫画缩放之间仍需要稳定优先级。
- [x] 动画入口已经有 `ReaderPagedAnimationSurface`，但 reader page 仍要负责多个动画状态，Android 真机上需要防并发和 jank 观测。
- [x] 背景/设置更新存在全页 setState 风险，但现有实现不是完全同步阻塞，需要用数据决定是否拆 layer。
- [x] Selection/Bookmark toolbar 的 root overlay 是复杂点，但也是当前选择锚点准确性的依赖，迁移必须先验证。
- [x] release 包纸页卷动异常说明第三方 `turnable_page` 的接入边界还不够稳定，尤其是 snapshot 捕获、post-frame 时序、controller listener、overlay 清理这些流程需要统一适配层兜底。
- [x] 上一章/下一章点击无响应说明 chrome 按钮、overlay hit-test、reader 级 pointer fallback、章节跳转副作用之间缺少统一 command 流，后续不能再让按钮直接散落调用业务方法。

---

## 4. 长期统一架构目标

目标不是“把所有东西塞到一个类里”，而是形成稳定的 5 条标准边界：

- [ ] `ReaderRootScaffold`: 只负责 `PopScope`、`Focus`、`Scaffold`、SafeArea/Clip，不放业务副作用。
- [ ] `ReaderVisualStack`: 只负责 background、content、interaction、chrome、foreground overlay 的固定顺序和 hit-test 策略。
- [ ] `ReaderInteractionCoordinator`: 统一 reader 级 pointer/tap/swipe/long-press 输入，输出标准 command，不直接改章节/分页状态。
- [ ] `ReaderNavigationCommandBus`: 统一上一章、下一章、上一页、下一页、目录跳转、滚动边缘跳章、自动阅读跳章，不再让 chrome/tap-zone/keyboard 各自直调。
- [ ] `ReaderPageTurnCoordinator`: 统一普通翻页、跨章节翻页、仿真卷曲、纸页卷动的状态机，第三方库只能通过 adapter 接入。
- [ ] `ReaderThirdPartyAdapter`: 对 `turnable_page` 这类组件做 release-mode 保护，包括初始化时序、截图就绪、事件监听、失败降级和资源释放。

理想结果:

- [ ] chrome 点击、tap-zone 点击、键盘、自动阅读、滚动边缘都发同一种 `ReaderCommand`。
- [ ] 所有翻页都先经过同一个 gate，明确当前是否允许开始动画。
- [ ] 第三方纸页库不直接参与业务状态，只接收 snapshot 和 direction，完成后回调 commit/reject。
- [ ] overlay 的可点击/不可点击规则固定，避免按钮被透明层吞掉。
- [ ] release 包与 debug 包都有同一套 smoke 和日志开关。

---

## 5. 不建议执行的原方案

- [ ] 不把所有手势强行收成唯一 `GestureDetector`，但要统一 reader 级输入 command。
- [ ] 不把所有动画强行合成唯一 `AnimationController`，但要统一翻页状态机和并发门禁。
- [ ] 不直接删除 `OverlayEntry`，但要把 overlay z-order、hit-test、生命周期标准化。
- [ ] 不推翻 `ReaderPagedAnimationSurface` 和 `ReaderPaperCurlPagedView` 当前职责边界，但要把第三方纸页组件包进更稳定的 adapter。
- [ ] 不按原文伪代码开工，但按长期可维护目标逐步统一。

---

## 6. 修正版阶段计划

### Phase L0：测量与保护线

**目标**: 先证明问题在哪，避免“看起来复杂所以重构”。

- [ ] Android 真机录制 3 条 trace：纸页卷动、普通翻页、背景/主题切换。
- [x] 加临时 debug log：手势 pointer down/up、childHandled、longPress、swipe commit/reject。
- [x] 加动画生命周期 log：paged transition、curl preview、paper curl、cross chapter snapshot 开始/结束/取消。
- [ ] 记录 widget rebuild 热点：背景切换、设置 slider 拖动、翻页完成。
- [x] 建立 smoke 清单：点击分区、长按选择、书签 toolbar、上下章、纸页卷动、切主题、目录/设置 sheet。

验收:

- [ ] 有 Android 真机 trace 或日志样本。
- [ ] 能明确区分是手势冲突、动画并发、重建 jank，还是第三方纸页组件行为。

### Phase L1：Overlay/Chrome 层级契约

**目标**: 不改大结构，先把层级顺序和职责固定下来。

- [x] 文档化 `ReaderShell` slots 顺序：background、backgroundOverlay、content、center、top、bottom、side、foregroundOverlay。
- [x] 把 foreground overlay 内部顺序写成显式模型：loading、auto-read、scrim、top、bottom。
- [x] 增加测试或 presenter 校验，防止后续新增 overlay 插错层。
- [x] 明确哪些 overlay 允许拦截手势，哪些必须 `IgnorePointer`。
- [x] 保留 modal sheet 使用 Navigator/Flutter 原生 overlay，不纳入 ReaderShell Stack。

验收:

- [x] 新增或更新一份 overlay z-order 文档。
- [x] 关键 overlay 不改变现有用户行为。

### Phase L2：手势优先级契约

**目标**: 保留 Flutter/第三方组件内部手势，但统一 reader 级输入出口，最终都转成标准 command。

- [x] 定义优先级：系统边缘返回 > modal/sheet > selection toolbar > text selection > child handled tap > swipe turn > tap zone > chrome toggle。
- [x] 给 `ReaderPointerInputController` 补测试：移动取消长按、childHandled 阻止 fallback tap、selection active 忽略 reader tap。
- [x] 给 `ReaderTouchNavigationController` 补测试：overlay 隐藏、自动阅读暂停/打开控制、tap zone action。
- [ ] 检查 `SelectionArea` 与 reader fallback long press 的边界，避免文本阅读模式下重复长按。
- [x] 新增轻量 `ReaderInteractionCoordinator`，输入 touch intent / tap-zone action，输出统一 interaction command / navigation command。
- [x] 不替换 `SelectionArea/PageView/InteractiveViewer` 内部手势，只让它们通过 childHandled/command 回到统一入口。

验收:

- [ ] 点击分区、长按选择、漫画双击缩放、滑动翻页在 Android 真机通过。
- [ ] 没有为了“唯一入口”破坏系统选择和第三方组件手势。
- [ ] 点击分区、chrome 按钮、键盘、自动阅读都能在日志里看到统一 command。

### Phase L3：动画状态门禁

**目标**: 不合并 renderer，但统一翻页状态机，所有翻页先经过 gate。

- [x] 列出动画状态：paged transition、curl preview/auto turn、paper curl component、cross chapter snapshot、reader interaction animating。
- [x] 新增 `ReaderPageTurnGate`，负责判断当前是否允许开始新翻页/跨章节/跳章。
- [x] 在 reader navigation command 入口拒绝冲突状态：cross chapter snapshot、paged transition、curl preview、paper curl animating。
- [x] 在纸页 adapter 完成/拒绝/超时路径统一清理 busy state 和 snapshot state。
- [x] 保留 `ReaderPagedAnimationSurface` 作为渲染入口，保留 `ReaderPaperCurlPagedView` 只管理组件内部快照。
- [ ] 把普通翻页、跨章节翻页、纸页翻页、自动阅读翻页都归一到 `ReaderPageTurnRequest -> ReaderPageTurnResult`。

验收:

- [ ] Android 真机快速连续翻页不出现旧页/下一页闪字。
- [ ] 纸页卷动不会退化成仿真卷曲。
- [ ] 普通动画、跨章节动画、纸页动画各自职责仍清晰。

### Phase L4：背景/设置重建隔离

**目标**: 只在测量证明有 jank 时做隔离，避免提前拆复杂。

- [x] 基于当前代码与已加 trace 点评估：暂未拿到 Android 真机背景/主题切换掉帧证据，不先拆背景 layer。
- [ ] 若掉帧，先把背景视觉输入抽成不可变 model，减少 reader page build 中的同步解析。
- [ ] 给背景 layer 加 `RepaintBoundary` 或 `AnimatedSwitcher`，只处理视觉切换，不改变设置存储。
- [ ] 保留现有 `compute` 压缩和 managed file cache。
- [ ] 验证设置 slider 拖动时分页/内容层不会频繁做无关重建。

验收:

- [ ] 背景/主题切换无明显闪烁。
- [ ] 设置实时预览行为不变。

### Phase L5：Selection/Bookmark Toolbar 迁移可行性

**目标**: 先验证 root overlay 是否真的造成问题，再决定是否迁移。

- [x] 对比两种方案：继续 root `OverlayEntry`、迁入 ReaderShell foreground overlay。
- [ ] 验证 `TextSelectionToolbarAnchors` 在分页、滚动、SafeArea、键盘弹出下的位置准确性。
- [ ] 验证 dismiss 手势不吞掉文本选择和点击分区。
- [x] 若 foreground overlay 方案稳定，再做迁移；否则保留 root overlay，只补生命周期和 z-order 文档。当前结论：保留 root overlay，等 Android/iOS/Desktop 手动验证后再迁移。

验收:

- [ ] 长按选择、复制、保存书签、编辑笔记、清除选择在 Android/iOS/桌面均通过。
- [ ] 不出现双 toolbar、位置漂移、点击穿透。

### Phase L6：上一章/下一章命令流统一

**目标**: 修正“点击无响应”这类问题的根因，让所有章节切换入口走同一条链路。

- [x] 新增 `ReaderNavigationCommand`：previousPage、nextPage、previousChapter、nextChapter、jumpChapter、reloadChapter。
- [x] 新增 `ReaderNavigationCommandDispatcher`，统一处理 chrome、tap-zone、keyboard、scroll-edge、auto-read 的命令。
- [x] chrome 上一章/下一章按钮不再直接调用 `_jumpToAdjacentReadableChapter`，改发 command。
- [x] command dispatcher 内统一处理：overlay 是否拦截、当前是否 loading、动画是否 busy、是否到边界、是否本地书、是否连续阅读模式。
- [x] 所有 reject 都有日志和用户可见反馈，避免“点了没反应”。
- [x] 给上一章/下一章补 widget/controller tests，覆盖 overlay 显示、loading、边界、成功跳转、失败提示。

验收:

- [ ] 底部 chrome 上一章/下一章在 Android release 包可点击。
- [x] 点击无响应时日志能定位是 hit-test、busy gate、边界还是加载失败。
- [x] keyboard/tap-zone/scroll-edge 与 chrome 行为一致。

### Phase L7：纸页卷动第三方适配层标准化

**目标**: 解决 debug 可用、release 不稳定的问题，让 `turnable_page` 变成可替换、可降级的内部实现。

- [x] 新增 adapter 语义：保留 `ReaderPaperCurlPagedView` 文件名，内部按 adapter contract 输出标准结果。
- [x] adapter 只接收 `ReaderPaperCurlPagedSurface`：surface token、page count、current page、pageBuilder。
- [x] adapter 只输出 `ReaderPaperCurlResult`：started、committed、rejected、timedOut、snapshotFailed。
- [x] 把 `PageFlipController` 初始化、`animationComplete` 监听、post-frame 等待、snapshot dispose 都封装在 adapter 内。
- [x] 增加 release-mode 超时兜底：动画开始后 2400ms 没有 complete，则记录 timedOut 并 fallback commit，不能卡死。
- [x] 增加 snapshot readiness 检查：尺寸为 0、`debugNeedsPaint`、context 丢失、toImage 失败都必须有明确 reject。
- [x] release 包专门加日志链路，记录 capture/start/complete/timeout/reset/result 每一步。
- [ ] 如果 `turnable_page` 在 release 仍不稳定，保留 adapter API，内部替换为自绘 paper curl 或退回仿真卷曲。

验收:

- [ ] Android debug/profile/release 三种模式纸页卷动一致。
- [ ] 失败时不闪字、不变成错误动画、不吞掉下一次点击。
- [ ] 第三方库替换时 reader page 和业务状态不需要跟着大改。

### Phase L8：Reader 结构扁平化落地

**目标**: 在 command、page-turn、adapter 都统一后，再做真正的层级瘦身。

**执行拆分**: 详细任务见 `docs/features/reader/reader-reasonable-architecture-refactor-plan-2026-06-13.md`。L8 不再作为一个大任务直接领取，必须按 R0-R6 分阶段执行。

- [ ] 将 `ReaderShell` 固化为唯一视觉 Stack。
- [ ] 将 viewport 里的 foreground overlay 收口为 `ReaderOverlayLayerModel`。
- [ ] 将 chrome top/bottom/auto-read/status/loading 都由 overlay layer 渲染。
- [ ] 将 reader page 中直接 setState 的 UI 状态逐步迁移到 session/controller model。
- [ ] 只有在 L2-L7 稳定后，再评估 selection toolbar 是否迁到 foreground overlay。

验收:

- [ ] reader 主路径层级可画成一张图，且每一层职责唯一。
- [ ] 新增功能必须选择现有 layer/command/adapter，不允许临时再塞一层全屏透明捕获层。

---

## 7. 推荐执行顺序

1. [ ] L0：先加日志和真机 trace。
2. [x] L1：固化 overlay/chrome z-order。
3. [x] L6：先统一上一章/下一章 command 流，解决点击无响应。
4. [x] L2：统一 reader 级输入 command，补手势优先级测试。
5. [x] L3：统一翻页状态门禁。
6. [x] L7：纸页卷动第三方 adapter 标准化，重点验证 release 包。
7. [x] L4：按 trace 决定是否拆背景重建。当前结论：无真机背景 jank 证据，暂不拆。
8. [x] L5：评估 selection toolbar 是否迁移。当前结论：暂保留 root overlay。
9. [ ] L8：等前面稳定后做真正结构扁平化。

---

## 8. 发版前最低完成线

- [ ] L0 必须完成，有真实 Android 真机证据。
- [x] L6 必须完成，上一章/下一章点击链路要有统一 command 和可定位日志。
- [x] L3 至少完成动画并发门禁。
- [x] L7 至少完成纸页卷动 release-mode 兜底和日志，纸页闪字/失效要能复现定位。
- [x] L2 至少补齐手势 controller/command 测试。
- [ ] 不要求 L4/L5 全部完成，除非 L0 证明它们是当前 bug 根因。
