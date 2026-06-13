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

- [ ] 新增 `presentation/widgets/root/reader_root_scaffold.dart`。
- [ ] 输入 `ReaderRootScaffoldModel`: focusNode、canPop 策略、backgroundColor、body、onBack。
- [ ] 把 `PopScope`、`Focus`、`Shortcuts/Actions`、`Scaffold`、SafeArea/Clip 相关壳层迁入。
- [ ] `reader_page.dart` 只组装 model 和业务 callbacks。
- [ ] 不迁移内容加载、分页、设置、换源、选择逻辑。

验收:

- [ ] `reader_page.dart` 行数减少，但行为不变。
- [ ] 返回键、键盘输入、页面焦点、底部安全区行为不变。
- [ ] 补 widget test：root scaffold 能渲染 body、触发 back、保持 focus。

---

## 4. Phase R2：拆出 ReaderVisualStack

**目标**: 固化唯一视觉 Stack，让 background/content/interaction/chrome/foreground overlay 的层级不再散在多个 part 里。

- [ ] 新增 `presentation/widgets/stack/reader_visual_stack.dart`。
- [ ] 新增 `ReaderVisualStackModel`: background、backgroundOverlay、content、interactionLayer、chromeTop、chromeBottom、sidePanel、foregroundOverlay。
- [ ] `ReaderShell` 逐步退化为兼容 wrapper 或合并到 `ReaderVisualStack`。
- [ ] viewport 不再直接决定 foreground overlay 的全局层级，只提供 content 和局部 renderer。
- [ ] 所有全屏透明层必须声明 hit-test 策略：拦截、透传、仅可见时拦截。

验收:

- [ ] Reader 主路径视觉层级可以用一张图解释。
- [ ] 新增 overlay 必须进入 `ReaderVisualStackModel`，不能临时再套全屏 Stack。
- [ ] overlay z-order 测试继续通过。

---

## 5. Phase R3：OverlayLayerModel 收口

**目标**: 把 loading、auto-read、scrim、top chrome、bottom chrome、status/hint 等统一成 overlay layer model。

- [ ] 新增 `ReaderOverlayLayerModel` 和 `ReaderOverlayLayerRenderer`。
- [ ] 把 foreground overlay 内部顺序从 widget 列表升级为 model 列表。
- [ ] 每个 overlay 声明 `zOrder`、`visible`、`hitTestPolicy`、`semanticRole`。
- [ ] chrome top/bottom 只接收 action callbacks，不直接知道章节跳转实现。
- [ ] loading/error/auto-read overlay 不允许直接发业务跳转，必须走 command。

验收:

- [ ] top/bottom chrome、loading、auto-read、scrim 行为不变。
- [ ] 点击 chrome 按钮不被 scrim 或 foreground 透明层吞掉。
- [ ] 补 model 单测：z-order、hit-test policy、visible 过滤。

---

## 6. Phase R4：PageTurnCoordinator 真正落地

**目标**: 从“gate 只判断能不能开始”升级到“统一翻页请求、执行、结果、清理”。

- [ ] 新增 `ReaderPageTurnRequest`: source、direction、kind、targetChapterIndex、animationStyle。
- [ ] 新增 `ReaderPageTurnResult`: committed、rejected、boundary、snapshotFailed、timedOut、fallbackCommitted。
- [ ] 普通分页动画、仿真卷曲、纸页卷动、跨章节快照统一返回 result。
- [ ] `_turnPagedTextPage`、`_turnCrossChapterWithSnapshot`、`_turnPaperCurlPage` 不再各自散落清理逻辑。
- [ ] 自动阅读、点击分区、键盘、滚动边缘都只提交 request，不直接操作 renderer。

验收:

- [ ] 连续快速翻页不会并发启动两个动画。
- [ ] 所有 reject 都有统一日志和用户反馈策略。
- [ ] 纸页 adapter 可替换，业务层不用改。

---

## 7. Phase R5：ReaderPage 状态瘦身

**目标**: 等 R1-R4 边界稳定后，再从 `reader_page.dart` / part 中搬状态，避免先搬状态导致逻辑失联。

- [ ] 把 overlay UI 状态迁到 `ReaderOverlayController`。
- [ ] 把 page-turn runtime 状态迁到 `ReaderPageTurnRuntimeController`。
- [ ] 把 reader interaction cooldown / busy / settle 迁到 `ReaderInteractionRuntimeController`。
- [ ] 保留章节加载、分页缓存、换源、selection 为独立后续阶段，不在本阶段一起搬。
- [ ] 每迁一个 controller，都补纯 Dart 单测，不依赖 widget pump。

验收:

- [ ] `reader_page.dart` 主文件继续下降，part 文件职责更窄。
- [ ] `_ReaderPageState` 不再直接持有所有 overlay/page-turn 细节字段。
- [ ] 行为回归测试和 Android 真机 smoke 通过。

---

## 8. Phase R6：谨慎处理 Selection 与背景

**目标**: 只在证据充分时动高风险层，不为了“结构漂亮”牺牲系统选择准确性。

- [ ] Selection toolbar 继续默认保留 root `OverlayEntry`。
- [ ] 只有当真机证明 root overlay 造成点击穿透/位置漂移，才尝试迁入 foreground overlay。
- [ ] 背景 layer 只有在 trace 证明切主题/换背景 jank，才拆不可变 visual model。
- [ ] 背景拆分优先做 `RepaintBoundary` 与 visual model，不动设置存储和资源压缩逻辑。

验收:

- [ ] 长按选择、复制、保存灵感、清除选择在 Android/iOS/Desktop 都通过。
- [ ] 背景/主题切换没有明显闪烁或卡顿。

---

## 9. 推荐执行顺序

1. [ ] R0：真机 release 基线验证。
2. [ ] R1：拆 `ReaderRootScaffold`。
3. [ ] R2：拆 `ReaderVisualStack`。
4. [ ] R3：收口 `OverlayLayerModel`。
5. [ ] R4：落地 `PageTurnCoordinator`。
6. [ ] R5：ReaderPage 状态瘦身。
7. [ ] R6：按 trace 决定 selection/background 是否继续拆。

---

## 10. 本阶段不做

- [ ] 不直接删除 `SelectionArea` 或 root `OverlayEntry`。
- [ ] 不把所有动画合成一个 `AnimationController`。
- [ ] 不把所有手势合成一个 `GestureDetector`。
- [ ] 不在没有真机日志时替换 `turnable_page`。
- [ ] 不把章节加载、换源、selection、背景、page-turn 一次性混拆。

