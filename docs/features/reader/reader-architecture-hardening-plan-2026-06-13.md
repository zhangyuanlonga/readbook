# 阅读器架构硬化计划

**创建日期**: 2026-06-13  
**目标**: 优先解决阅读器“半吊子边界”问题，让后续真机 bug 能像普通 bug 一样定位和修复，而不是每次牵一发动全身。

---

## 0. 核心判断

当前阅读器最大问题不是“还有多少行代码”或“用了多少 Riverpod”，而是关键链路边界仍不够硬：

- 翻页、跨章节、纸页卷动、自动阅读、点击分区还没有完全变成同一个可追踪 command/runtime 模型。
- 缓存架构落后且分散：章节缓存、分页缓存、封面缓存、API 缓存、搜索命中缓存各自为政，缺少统一策略、容量治理、命中/失效日志。
- 内容加载、分页缓存、章节跳转、换源仍与页面状态交织，导致真机问题容易表现成“闪一下”“点击无反应”“release 才坏”。
- Selection、背景、overlay 已经做了第一层边界，但还需要真机验证后的最小迁移策略。
- 继续大规模引库或全量 Riverpod 化，短期不会解决核心问题，反而会制造二次迁移风险。

---

## 1. 原则

- [ ] 先硬化核心链路，再做文件瘦身。
- [ ] 每次只收口一个业务边界，不为了减少 part 数量而制造新 manager 巨类。
- [ ] 真机 bug 必须能定位到 command、gate、runtime、adapter、content load、selection/overlay 中的某一层。
- [ ] 缓存是核心架构问题，优先做；但先抽统一缓存边界和迁移策略，再决定 Drift / Hive / CacheManager 的职责分工。
- [ ] 不做“全量替换库”：Timer、Riverpod、HTTP 都按证据逐个处理；缓存允许做后端替换试点。
- [ ] 每个阶段完成后必须跑 reader 定向测试、`flutter analyze`，并保留 Android/iOS smoke 项。

---

## 2. Phase H0：真机问题定位基线

**目标**: 先让后续 bug 有清晰证据链。

- [ ] Android release 包验证纸页卷动、上一章/下一章、普通分页、自动阅读翻页。
- [ ] iOS 模拟器/真机验证同路径，确认 Android-only 或跨端问题。
- [ ] 选择文本、保存灵感、清除选择、背景/主题切换做 smoke。
- [ ] 若出现问题，日志必须能区分：hit-test、command 未发出、gate reject、adapter reject、animation timeout、content loading。

验收:

- [ ] 每个真机问题都有稳定复现步骤和对应日志链路。
- [ ] 不再用“感觉是打架”作为唯一判断依据。

---

## 3. Phase H1：缓存架构硬化

**目标**: 把缓存从“散落工具类”升级成统一缓存生态，先解决落后和不稳定，再谈是否引入 Hive。

- [ ] 按专项文档执行：`docs/features/reader/cache-architecture-refactor-plan-2026-06-13.md`。
- [ ] 梳理当前缓存矩阵：章节内容、分页布局、封面图片、API 响应、搜索命中、书源健康、主题预览。
- [ ] 定义统一缓存协议：key、scope、ttl、size、lastAccessed、version、invalidReason、owner。
- [ ] 建立 `ReaderCacheCoordinator` 或同等 application 层边界，页面和业务服务不直接关心底层存储。
- [ ] 章节内容缓存和分页缓存优先接入统一协议，因为它们直接影响阅读器加载、恢复页码、离线和真机性能。
- [ ] 封面/图片继续优先使用 `cached_network_image` / `flutter_cache_manager`，不要重复造图片磁盘缓存。
- [ ] Drift 继续承载关系型、可查询、可统计数据；Hive 可作为章节 payload / 大块分页 layout 的试点后端。
- [ ] 先做读写双轨试点：新写入走新缓存协议，旧缓存可读；稳定后再做清理迁移。
- [ ] 增加缓存日志：hit、miss、stale、evicted、decodeFailed、versionMismatch、backendError。
- [ ] 增加缓存治理入口：按类型统计大小、清理策略、预算限制、异常修复。

验收:

- [ ] 阅读器打开章节时能明确知道命中章节缓存、分页缓存，还是走网络/本地解析。
- [ ] 设置变化、字体变化、宽高变化、主题变化导致分页缓存失效时，有明确 invalidReason。
- [ ] 缓存损坏不会导致空白页或错误页卡死，能 fallback 到重新加载/重新分页。
- [ ] 至少完成一条试点链路：章节内容缓存或分页布局缓存接入统一协议。
- [ ] 有单测覆盖 hit/miss/stale/version mismatch/evict。

---

## 4. Phase H2：翻页链路彻底硬化

**目标**: 所有翻页入口进入同一条 command -> gate -> coordinator -> runtime -> adapter/result 链路。

- [ ] 自动阅读、点击分区、键盘、音量键、滚动边缘、chrome 上一章/下一章都只提交 `ReaderNavigationCommand` 或 `ReaderPageTurnRequest`。
- [ ] `_turnCrossChapterWithSnapshot` 内部剩余 UI/animation 清理继续迁入 `ReaderPageTurnRuntimeController` 的 executor 方法。
- [ ] `_turnPaperCurlPage` 只负责调用 paper-curl adapter，业务状态提交全部由 runtime controller 完成。
- [ ] `ReaderPaperCurlPagedView` adapter 的 result 覆盖 started、committed、rejected、timedOut、snapshotFailed。
- [ ] release 模式下增加关键 trace，不依赖 debug-only 行为。

验收:

- [ ] 上一章/下一章点击无响应时，日志能显示 command 是否发出、gate 是否拒绝、边界是否触发。
- [ ] 纸页 release 包异常时，日志能定位 adapter reject/timeout/snapshot fail。
- [ ] 不直接从 UI widget 分支里改 page-turn runtime 状态。

---

## 5. Phase H3：内容加载与分页状态机

**目标**: 把“加载章节、恢复进度、使用缓存、重新分页”变成可测试状态机。

- [ ] 从 `reader_page_content_loading.dart` 抽出 `ReaderContentLoadStateMachine` 或同等 planner。
- [ ] 输入：当前书/章节、统一缓存状态、预计算分页、目标进度、内容模式。
- [ ] 输出：使用缓存、加载网络、本地章节、等待分页、恢复页码、展示错误等明确 action。
- [ ] 页面只执行 action，不在多个 setState 分支里散落判断。
- [ ] 分页恢复逻辑统一进入 `ReaderPageTurnRuntimeController` 或 pagination runtime 边界。
- [ ] 内容加载状态机必须消费 H1 的统一缓存结果，而不是直接访问多个缓存服务。

验收:

- [ ] 设置变化后重新分页、切章恢复进度、缓存命中、缓存失效都有单测。
- [ ] 内容加载失败不会误触发翻页/overlay/auto-read 状态。

---

## 6. Phase H4：换源边界硬化

**目标**: 换源从页面流程变成 application/service 协调结果，页面只负责展示和确认。

- [ ] 抽 `ReaderSourceSwitchRuntimeService` 或增强现有 `ReaderSourceSwitchService`。
- [ ] 输入：当前书、当前章节/位置、目标源、搜索结果、章节匹配策略。
- [ ] 输出：匹配章节、迁移进度、失败原因、是否保留原源。
- [ ] 页面只处理弹窗、loading、toast、跳转，不直接拼业务状态。
- [ ] 补换源失败、匹配失败、成功迁移、用户取消测试。

验收:

- [ ] 换源流程失败后能恢复原阅读状态。
- [ ] 成功后阅读进度、章节标题、缓存状态一致。

---

## 7. Phase H5：Selection / Overlay / Background 稳定化

**目标**: 保持系统选择准确性，同时把 overlay 和背景问题限制在小边界内。

- [ ] Selection toolbar 默认 root overlay，只有真机确认 root overlay 有问题才走 foreground overlay。
- [ ] 补 selection toolbar anchor smoke：分页、滚动、安全区、键盘弹出。
- [ ] 背景层只做 visual model / repaint boundary / trace，不动资源存储。
- [ ] overlay 全屏层必须继续声明 hit-test 策略，不允许临时 `Positioned.fill + GestureDetector`。

验收:

- [ ] 长按选择、复制、保存灵感、清除选择在 Android/iOS/Desktop 可用。
- [ ] 背景/主题切换没有明显闪烁，若有 trace 能定位 rebuild 层。

---

## 8. Phase H6：低风险文件解耦

**目标**: 在核心链路硬化后，再按职责拆 part，而不是为了 part 数量拆。

- [ ] 优先拆纯 presenter/helper：toolbar、status view、loading view、reader info clock。
- [ ] 再拆 runtime 子域：auto-read runtime、reading-record runtime、delayed-loading runtime。
- [ ] 暂缓直接独立 `reader_page_content_loading.dart`、`reader_page_source_switch.dart`，等 H2/H3 状态机完成。
- [ ] 不创建万能 `ReaderRuntimeManager` 巨类。

验收:

- [ ] 每拆一个文件都有对应单测或 widget test。
- [ ] `reader_page.dart` 行数下降是结果，不是目标。

---

## 9. 暂不执行

- [ ] 不无脑全量 Hive 替换现有 Drift/SQLite/CacheManager 缓存；允许在 H1 里通过统一协议做后端试点。
- [ ] 不全量 easy_debounce 替换阅读器 Timer。
- [ ] 不为了 Riverpod 使用率迁移动画、滚动、焦点、选择生命周期。
- [ ] 不替换 `turnable_page`，除非 release 包 trace 证明第三方 adapter 本身不可控。
- [ ] 不一次性开启严格 lint，避免产生大量与业务无关的噪音改动。
