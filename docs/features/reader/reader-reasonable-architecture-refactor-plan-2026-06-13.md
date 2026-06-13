# Reader 合理架构改造计划二

**日期**: 2026-06-13  
**来源**: `layer-stacking-current-code-audit-and-plan-2026-06-13.md` 的 L8 拆分  
**目标**: 把前面已完成的 command/gate/adapter 边界继续落成稳定、低嵌套、可维护的 Reader 主架构。

---

## 0. 为什么看起来“还没开始”

前一轮已经开始了，但做的是发版风险最高的止血边界，不是大拆结构：

- [x] `ReaderNavigationCommandDispatcher`: 上一章/下一章/上一页/下一页统一 command。
- [x] `ReaderInteractionCoordinator`: reader 级 tap-zone/touch intent 统一出口。
- [x] `ReaderPageTurnGate`: 翻页/跳章统一动画门禁。
- [x] `ReaderPaperCurlPagedView` adapter 化：第三方纸页库只管理快照、动画、结果回调。
- [x] `ReaderShell` / foreground overlay z-order 显式化。
- [x] `ReaderRootScaffold`: route/back/focus/scaffold 壳层独立。
- [x] `ReaderVisualStack`: background/content/chrome/foreground overlay 视觉 Stack 独立。

这些属于“先把乱线拧成几束”，还没有进入“把主页面拆成合理架构”的阶段。真正结构改造从本计划开始。

---

## 1. 改造原则

- [ ] 不追求一次性推翻 `reader_page.dart`，避免把 release 风险放大。
- [ ] 不为了减少 widget 层数而破坏 Flutter 原生机制，例如 `SelectionArea`、`OverlayEntry`、`PageView`、`InteractiveViewer`。
- [ ] 每个阶段只允许改一个架构边界，完成后必须跑 analyze/test。
- [ ] 每拆出一个边界，都要明确输入 model、输出 callback/result、禁止直接读写的状态。
- [ ] 真机 release 验证优先于“代码看起来更干净”。

---

## 2. Phase R0：真机基线与发版保护

**目标**: 先确认当前止血改造是否解决线上症状，再进入大拆。

- [ ] Android 真机 release 包验证纸页卷动：连续翻页、跨章节、快速点击、返回再进入。
- [ ] Android 真机 release 包验证上一章/下一章：底部 chrome、点击分区、键盘/音量键如可用。
- [ ] 收集 `reader.navigation_command`、`reader.paper_curl_adapter_result`、`reader.paper_curl` 日志样本。
- [ ] 记录是否还存在“闪字”“纸页变仿真”“点击无响应”。
- [ ] 如果 release 仍有纸页问题，先在 adapter 内部修，不扩散到 `reader_page.dart`。

验收:

- [ ] 明确当前问题是否已修复。
- [ ] 如果未修复，日志能定位是 hit-test、gate reject、snapshot failed、animation timeout、第三方 controller rejected。

---

## 3. Phase R1：拆出 ReaderRootScaffold

**目标**: 让路由页面只负责页面壳，不再把 PopScope、Focus、Scaffold、body 构造和业务状态混在一起。

- [x] 新增 `presentation/widgets/root/reader_root_scaffold.dart`。
- [x] 输入 `ReaderRootScaffoldModel`: focusNode、canPop 策略、backgroundColor、body、onBack。
- [x] 把 `PopScope`、`Focus`、`Scaffold`、SafeArea/Clip 相关壳层迁入。
- [x] `reader_page.dart` 继续只组装 model 和业务 callbacks；兼容入口 `ReaderPageScaffoldShell` 委托 `ReaderRootScaffold`。
- [x] 不迁移内容加载、分页、设置、换源、选择逻辑。

验收:

- [x] `reader_page.dart` 行为不变，壳层职责已移出兼容组件。
- [x] 返回键、键盘输入、页面焦点、底部安全区保持原路径。
- [x] 补 widget test：root scaffold 能渲染 body 并保持 ReaderShell 内容。

---

## 4. Phase R2：拆出 ReaderVisualStack

**目标**: 固化唯一视觉 Stack，让 background/content/interaction/chrome/foreground overlay 的层级不再散在多个 part 里。

- [x] 新增 `presentation/widgets/stack/reader_visual_stack.dart`。
- [x] 新增 `ReaderVisualStackModel`: background、backgroundOverlay、content、center、chromeTop、chromeBottom、sidePanel、foregroundOverlay。
- [x] `ReaderShell` 已退化为兼容 wrapper，内部委托 `ReaderVisualStack`。
- [x] viewport 仍负责提供 foreground overlay 内容，但全局层级由 `ReaderVisualStack` + z-order contract 承接。
- [x] 所有全屏透明层必须声明 hit-test 策略：拦截、透传、仅可见时拦截。已新增 `ReaderFullScreenHitTestLayer` 并覆盖设置/选择 dismiss 层、scrim、snapshot、paper-curl 预渲染层、visual stack 透传层。

验收:

- [x] Reader 主路径视觉层级可以用 `ReaderVisualStackModel` 解释。
- [x] 新增顶层 visual slot 必须进入 `ReaderVisualStackModel`，不能临时再套全屏 Stack。
- [x] overlay z-order 测试继续通过。

---

## 5. Phase R3：OverlayLayerModel 收口

**目标**: 把 loading、auto-read、scrim、top chrome、bottom chrome、status/hint 等统一成 overlay layer model。

- [x] 新增 `ReaderOverlayLayerModel` 和 `ReaderOverlayLayerRenderer`。
- [x] 把 foreground overlay 内部顺序从 widget 列表升级为 model 列表。
- [x] 每个 foreground overlay 声明 `zOrder`、`visible`、`hitTestPolicy`、`semanticRole`。
- [x] chrome top/bottom 继续只接收 action callbacks，不直接知道章节跳转实现。
- [x] loading/auto-read/scrim/top/bottom overlay 已进入统一 renderer；error 仍在 content body 内，暂不纳入 foreground overlay。

验收:

- [x] top/bottom chrome、loading、auto-read、scrim 行为不变。
- [x] 点击 chrome 按钮继续由 child 自身 hit-test/IgnorePointer 控制。
- [x] 补 model 单测：z-order、hit-test policy、visible 过滤。
- [x] 补全屏透明层单测：透传、仅可见时拦截。

---

## 6. Phase R4：PageTurnCoordinator 真正落地

**目标**: 从“gate 只判断能不能开始”升级到“统一翻页请求、执行、结果、清理”。

- [x] 新增 `ReaderPageTurnRequest`: source、direction。
- [x] 新增 `ReaderPageTurnResult`: started、committed、rejected、ignored、boundary、snapshotFailed、timedOut、fallbackCommitted。
- [x] 普通分页动画、仿真卷曲、纸页卷动、跨章节快照统一记录 result 日志。
- [x] `_turnPagedTextPage` 的计划入口改为 `ReaderPageTurnCoordinator`。
- [x] `_turnCrossChapterWithSnapshot`、`_turnPaperCurlPage` 已改为 coordinator executor handler，统一返回 `ReaderPageTurnResult`。
- [x] 自动阅读、点击分区、键盘、滑动、音量键、滚动边缘等 source 已从 navigation command 精确透传到 page-turn request。
- [x] 跨章节 snapshot / paper-curl 内部 page-turn runtime 状态已迁到 `ReaderPageTurnRuntimeController`：snapshot generation/transition、首翻计时、curl preview/commit、paper-curl commit 统一收口。

验收:

- [x] 连续快速翻页先经过 gate + coordinator 计划，不会绕过 busy 判断。
- [x] page-turn reject/ignored/started/committed 有统一日志链路。
- [x] 纸页 adapter 可替换，业务层不用改。

---

## 7. Phase R5：ReaderPage 状态瘦身

**目标**: 等 R1-R4 边界稳定后，再从 `reader_page.dart` / part 中搬状态，避免先搬状态导致逻辑失联。

- [x] 把 overlay UI 状态迁到 `ReaderOverlayController`，并收口 loading indicator reset、底部进度草稿 reset。
- [x] 把 page-turn runtime 状态迁到 `ReaderPageTurnRuntimeController`，并收口 paged transition、curl transition、snapshot transition、paper-curl commit、首翻计时。
- [x] 把 reader interaction busy / settle / deferred preload 迁到 `ReaderInteractionRuntimeController`。
- [x] reader interaction cooldown/back double-tap guard 已迁到 `ReaderInteractionRuntimeController`。
- [x] 保留章节加载、分页缓存、换源为独立后续阶段；selection/background 进入 R6 低风险边界。
- [x] 已迁 `ReaderInteractionRuntimeController` 并补纯 Dart 单测。

验收:

- [x] `_ReaderPageState` 不再直接持有 reader interaction settle timer / deferred preload 字段。
- [x] `_ReaderPageState` 不再直接持有 overlay/page-turn 细节字段，也不再保留 `_showOverlayControls` / `_currentPageIndex` 等桥接 getter/setter；part 文件直接通过 runtime controller 边界读写。
- [x] 行为回归测试通过。
- [ ] Android 真机 smoke 仍待执行。

---

## 8. Phase R6：谨慎处理 Selection 与背景

**目标**: 只在证据充分时动高风险层，不为了“结构漂亮”牺牲系统选择准确性。

- [x] Selection toolbar 继续默认保留 root `OverlayEntry`，并由 `ReaderSelectionOverlayPolicy` 显式决策。
- [x] 只有当真机证明 root overlay 造成点击穿透/位置漂移，并且 foreground anchors 已验证，policy 才允许迁入 foreground overlay。
- [x] 背景 layer 已拆出不可变 `ReaderBackgroundVisualModel` + `ReaderBackgroundLayer`。
- [x] 背景拆分只做 `RepaintBoundary` 与 visual model，不动设置存储和资源压缩逻辑。

验收:

- [x] Selection overlay policy 有单测覆盖默认 root overlay 与迁移条件。
- [x] 背景 layer 有 widget test 覆盖 `RepaintBoundary`。
- [ ] 长按选择、复制、保存灵感、清除选择在 Android/iOS/Desktop 真机/桌面 smoke 仍待执行。
- [ ] 背景/主题切换真机 trace/smoke 仍待执行。

---

## 9. 推荐执行顺序

1. [ ] R0：真机 release 基线验证。
2. [x] R1：拆 `ReaderRootScaffold`。
3. [x] R2：拆 `ReaderVisualStack`。
4. [x] R3：收口 `OverlayLayerModel`。
5. [x] R4：落地 `PageTurnCoordinator` 第一版。
6. [x] R5：ReaderPage 状态瘦身。
7. [x] R6：selection/background 低风险边界已完成，真机 smoke 待执行。

---

## 10. 本阶段不做

- [ ] 不直接删除 `SelectionArea` 或 root `OverlayEntry`。
- [ ] 不把所有动画合成一个 `AnimationController`。
- [ ] 不把所有手势合成一个 `GestureDetector`。
- [ ] 不在没有真机日志时替换 `turnable_page`。
- [ ] 不把章节加载、换源、selection、背景、page-turn 一次性混拆。
