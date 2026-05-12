# 阅读器低资源占用改造执行方案

更新时间：2026-05-09  
用途：作为阅读器低能耗、低内存、低端机流畅专项的唯一执行文档，统一参考口径、阶段边界、验收标准和回填规则，避免改造范围失控。

## 0. 结论先行

本专项参考 `/Users/zhangyuanlong/Downloads/legado-with-MD3-main` 的阅读器设计，但不复制 Android 原生实现。

Legado 阅读器低资源占用的核心不是单点优化，而是下面几条原则：

- 只强持有前一章、当前章、后一章
- 当前页优先，分页逐页产出
- 后台预下载和预排版严格限流，离开阅读器立即取消
- 渲染缓存可回收，远离当前页的资源尽早释放
- 时间、电量、阅读记录等低频信息避免高频轮询
- 内存缓存有明确字节预算，不只按条数控制

本项目当前阅读器已经具备缓存、分页、预加载和阅读记录能力，但主问题是：

- `reader_page.dart` 汇聚过多状态和任务控制
- 分页结果更偏整章产出，长章节首次可见时间仍可优化
- 阅读器内存窗口没有被建模成明确的三章窗口
- 缓存清理主要按条数控制，缺少字节预算
- 后台任务对低电量、低端机和移动网络缺少统一降级策略

一句话目标：

- **先约束资源窗口**
- **再改分页产出方式**
- **最后按设备状态调度后台任务**

---

## 1. 适用范围

本文件覆盖：

- `lib/features/reader/`
- `lib/features/bookshelf/application/bookshelf_reader_open_service.dart`
- `lib/data/datasources/local/app_database.dart`
- `lib/core/cache/`
- `lib/runtime/http/`
- `lib/runtime/host/`
- 阅读器相关测试、架构守护脚本和性能观测文档

本文件不覆盖：

- 阅读器 UI 视觉重设计
- 新阅读模式产品功能
- 书源规则兼容专项
- WebDAV 同步专项
- 非阅读器页面的架构治理

相关文档：

- `docs/development_architecture_guardrails.md`
- `docs/reader_mode_rearchitecture_plan.md`
- `docs/bookshelf_reader_open_latency_execution_plan.md`
- `docs/local_multi_format_reading_plan.md`

---

## 2. 参考实现映射

### 2.1 Legado 可借鉴点

参考文件：

- `/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/model/ReadBook.kt`
- `/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/ui/book/read/page/provider/TextChapterLayout.kt`
- `/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/ui/book/read/page/entities/TextChapter.kt`
- `/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/ui/book/read/page/entities/TextPage.kt`
- `/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/help/CacheManager.kt`
- `/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/receiver/TimeBatteryReceiver.kt`

可迁移原则：

- `prev / current / next` 三章窗口
- 章节加载任务按当前章窗口取消
- 分页逐页产出并回调 UI
- 当前阅读位置可用即显示，不等待整章排完
- 自动保存阅读记录采用分钟级节流
- 预下载并发上限小，失败次数有限
- 渲染缓存可回收
- 内存缓存有字节上限

### 2.2 Flutter 不能直接照搬点

- Android `CanvasRecorder` 不能直接迁移为 Flutter 的长期 picture 缓存，Flutter 侧需谨慎评估 `RepaintBoundary`、`Picture` 和图片缓存压力。
- Android `StaticLayout` 可在后台线程使用；Flutter `TextPainter` 通常依赖 UI isolate，因此阶段 2 先做“逐页产出 + 分帧 yield”，不直接承诺 isolate 排版。
- Android 广播电量和分钟 tick 在 Flutter 多端不可完全等价，需通过平台桥或低频轮询封装。
- Glide 漫画解码策略不能直接复用，Flutter 侧应通过 `cacheWidth/cacheHeight`、`ImageCache` 限额和可视窗口控制实现。

### 2.3 MD3 分页和滚动语义结论

MD3/Legado 的命名容易误导：`scroll` 被放在 `PageAnim` 中，但实际不是单纯动画差异。

已确认代码路径：

- `PageAnim.scrollPageAnim = 3`
- `Book.getPageAnim()` 中，图片类书籍默认返回 `scrollPageAnim`，文本类书籍默认跟随全局 `ReadBookConfig.pageAnim`
- `ReadView.upPageAnim()` 根据 `ReadBook.pageAnim()` 切换不同 `PageDelegate`
- 当 `pageAnim == scrollPageAnim` 时，进入 `ScrollPageDelegate`
- `ReadView.upContent()` 在滚动模式下只更新 `curPage` 并让 `ContentTextView` 连续绘制当前页、下一页和下下页；非滚动模式会维护 `prevPage / curPage / nextPage`
- `ScrollPageDelegate` 使用连续纵向滚动距离计算，图片页按可视高度滚动，文本页会保留一行上下文

因此，本项目后续建模应坚持：

- `scroll` 是布局/交互模式，不是普通分页动画
- `cover / slide / simulation / fade / none` 才是 `paged text` 下的分页动画
- 文本内容可在 `paged` 和 `scroll` 之间切换
- 图片/漫画内容默认更适合滚动或专用漫画阅读器
- EPUB/PDF/MOBI 在 MD3 中仍先走文本阅读器入口，但内容里可能包含图片样式；是否滚动由书籍 `pageAnim` 和图片类型共同决定

对本项目的设计约束：

- 不再把滚动实现为 `pageAnimationStyle = scroll`
- 阅读模式模型应区分 `layoutMode: paged/scroll` 和 `pageAnimationStyle`
- 流式分页阶段必须同时定义分页模式和滚动模式的最小可见数据
- 漫画模式不要复用文本滚动的所有假设，图片缓存和可视窗口需要独立预算

### 2.4 MD3 图文和漫画能力差距结论

对比后需要把“已有基础”和“缺口”分开看：

- 本项目 EPUB 解析层已经能抽取图片：`EpubLocalBookParser` 会把 `<img>/<image>` 落成本地资源，并写入 `ReaderImageBlock`
- `ReaderDocument` 已经支持文本块、标题块、引用块、列表块、脚注块、图片块等结构化内容
- 纯图片章节会被识别为 comic，并进入 `ReaderMangaView`
- 漫画视图已有 `continuous / paged / horizontal` 三种模式，支持连续长图、纵向分页图、横向翻页和基础缩放
- 图文章节当前仍属于 text 模式，滚动正文可以渲染 `ReaderRenderImageItem`
- 但 `ReaderModeCapabilitiesResolver` 对带插图的 text 章节直接设置 `canUsePagedText = false`
- `ReaderAnimationPolicyResolver` 对带插图章节明确提示“退回滚动正文”
- `ReaderTextPagedView` 的分页单元仍是纯文本 `ReaderPagedSlice`，没有图片块、图文块和图片尺寸占位概念

因此，当前项目不是完全不支持 EPUB 图文，而是：

- EPUB 图文解析和滚动展示已有雏形
- EPUB 图文分页展示不完整
- 图文混排的分页动画不支持
- 纯漫画支持翻页/连续滚动，但更偏基础版，图片预载、回收、档位策略和 MD3 的 RecyclerView/Glide 方案还有差距
- MD3 的优势核心不是“多写了一套动画”，而是 `TextChapterLayout` 能把文字、图片、HTML 图片样式一起排成页面，再由 `ReadView` 切换分页或滚动 delegate

后续追齐 MD3 时，不应把所有图文内容都强行转漫画模式。推荐路线是：

- 纯图片章节继续走漫画模式
- 图文混排章节继续走文本阅读器
- 文本阅读器的分页模型升级为 block-based pagination，使图片成为分页布局的一等元素
- 滚动和分页共用同一份结构化 block 数据，只在 viewport/delegate 层分流

---

## 3. 开发约束

本专项必须遵守：

- 页面不直接创建 repository、database、runtime service
- 新增能力优先进入 `features/reader/application/`
- `reader/presentation` 只负责渲染、交互分发和订阅状态
- 任务调度、缓存预算、章节窗口和分页策略必须可单测
- 每个阶段都要保持 `flutter analyze` 通过
- 不在同一阶段混入视觉重设计和产品功能扩展

新增文件建议：

```text
lib/features/reader/application/
  reader_resource_budget.dart
  reader_chapter_window_controller.dart
  reader_streaming_pagination_controller.dart
  reader_background_task_policy.dart
  reader_memory_pressure_policy.dart

lib/features/reader/presentation/
  reader_page_* 只做薄适配，不继续扩大 reader_page.dart
```

---

## 4. 当前基线

### 4.1 已确认事实

- `flutter analyze` 当前通过。
- `tool/check_architecture_guardrails.dart` 当前失败：
  - `lib/features/mine/application/advanced_theme_service.dart` 超过 application 文件硬限制
- 架构守护脚本给出阅读器相关警告：
  - `lib/features/reader/presentation/reader_page.dart` 约 5275 行
  - `lib/features/reader/application/local/epub_local_book_parser.dart` 约 2147 行
- 阅读器已有：
  - 章节缓存
  - 分页磁盘缓存
  - 封面磁盘缓存
  - 启动后缓存清理
  - WebView 池化
  - 章节预缓存并发限制

### 4.2 待采样指标

阶段 0 必须补齐真机基线：

- 低端 Android 设备冷启动到书架可交互
- 书架点击到阅读页首屏可见
- 阅读页首屏可见到当前章分页完成
- 长章节首次打开内存峰值
- 连续翻页 5 分钟 jank
- 连续阅读 30 分钟内存增长
- 章节预缓存时 CPU、网络和电量体感
- 漫画章节连续滚动内存峰值

---

## 5. 阶段任务清单

当前进度：

- 阶段 0：未开始
- 阶段 1：已完成（2026-05-09：`ReaderSessionController` 统一发放和取消章节加载、预加载、分页任务 token；`reader_dependencies_provider.dart` 已复用 app-level database/repository provider）
- 阶段 2：已完成（2026-05-09：`ReaderChapterWindowController` 定义 previous/current/next slot、窗口状态和 move plan；continuous text 章节流接入窗口裁剪，切章时取消窗口外预加载/分页任务）
- 阶段 3：已完成（2026-05-09：新增 block-based 分页模型和 `ReaderStreamingPaginationController`；纯文本分页改为 current/nearby/complete 事件，图文 EPUB 可进入分页 block 渲染）
- 阶段 4：已完成（2026-05-09：新增 `ReaderResourceBudget`，资源预算覆盖章节预取、下载/WebView 并发、漫画 cache extent、分页内存条数和图片 decode 倍率）
- 阶段 5：已完成（2026-05-09：新增 `CacheBudgetPolicy`，章节/分页/封面缓存改为条数兜底 + 过期时间 + LRU + 字节预算；数据库 v26 补阅读缓存索引并覆盖迁移测试）
- 阶段 6：已完成（2026-05-09：新增 `ReaderImageDecodeBudget`，正文图、EPUB 插图和漫画图接入 `cacheWidth/cacheHeight`、data URI 大小限制、ImageCache 上限和漫画缩放状态窗口释放）
- 阶段 7：已完成（2026-05-09：新增 `ReaderRuntimeWakePolicy`，信息栏按分钟 one-shot 刷新、电量 5 分钟低频读取、进度保存分钟级节流并在后台/退出 flush，自动阅读在后台/弹层/低电量暂停）

回填规则：

- 状态：`未开始 / 进行中 / 已完成 / 已阻塞`
- 完成日期：`YYYY-MM-DD`
- 备注：只写关键决策、阻塞原因或偏差说明

---

## 阶段 0：建立基线和防失控边界

目标：

- 先建立可比较数据和边界，避免凭体感修改。

任务：

- [ ] 记录当前阅读器架构热点文件和职责边界
- [ ] 记录低端 Android 真机基线数据
- [ ] 记录中端 Android 真机基线数据
- [ ] 记录 Android 模拟器或桌面调试基线数据，仅作辅助参考
- [ ] 明确本专项不处理的 UI 和产品功能需求
- [ ] 建立阅读器性能采样脚本或手工记录模板
- [ ] 将 `reader_page.dart` 后续新增行数设为临时警戒项

建议观测字段：

- `reader.open.tapToRouteMs`
- `reader.open.tapToVisibleMs`
- `reader.open.visibleToCurrentPageReadyMs`
- `reader.pagination.firstPageReadyMs`
- `reader.pagination.currentPositionPageReadyMs`
- `reader.pagination.chapterCompleteMs`
- `reader.chapterWindow.activeChapterCount`
- `reader.chapterWindow.activeTaskCount`
- `reader.cache.memoryBytes`
- `reader.cache.diskBytes`
- `reader.prefetch.activeCount`
- `reader.prefetch.cancelledCount`

完成标准：

- 有一份可复测的基线记录
- 每个后续阶段都有明确指标可比较
- 没有开始大规模重构代码

---

## 阶段 1：收敛 Reader 依赖和任务所有权

目标：

- 先把阅读器依赖图收口，为后续拆状态和取消任务做准备。

任务：

- [x] 将 `reader_dependencies_provider.dart` 中直接使用 `AppDatabase.instance` 的路径收敛到 app-level provider
- [x] 复用 `app_providers.dart` 中已有 repository provider，避免重复创建 repository impl
- [x] 为阅读器任务引入统一 owner 或 session id
- [x] 明确章节加载、分页、预缓存、阅读记录提交分别属于哪个 controller/service
- [x] 页面销毁、换书、换源、跳章时，所有旧 session 任务必须可取消
- [x] 补 `ReaderFeatureDependencies` 单测或 provider smoke test

阶段边界：

- 不改变分页算法
- 不改变 UI
- 不改变缓存结构

完成标准：

- 阅读器不再绕过 Provider 直接拿数据库单例
- 任务生命周期可以按 reader session 统一取消
- `flutter analyze` 通过

---

## 阶段 2：三章窗口模型

目标：

- 建立明确的 `previous / current / next` 章节资源窗口，减少正文、分页和图片资源常驻。

任务：

- [x] 新增 `ReaderChapterWindowController`
- [x] 定义 `ReaderChapterSlot.previous/current/next`
- [x] 定义章节窗口状态：`empty / loading / ready / failed / cancelled`
- [x] 当前章切换时复用已有 next/previous，避免重复加载
- [x] 超出窗口的章节正文、分页结果、图片引用、加载任务必须释放或取消
- [x] 本地图书和在线书共用窗口模型
- [x] 漫画章节也接入窗口模型，但图片解码策略放到阶段 5
- [x] 补窗口移动、取消过期任务、失败重试的单测

阶段边界：

- 不做远距离预下载
- 不做分页流式化
- 不改阅读记录语义

完成标准：

- 任意时刻 application 层强持有的章节主体不超过三章
- 快速连跳章节不会让旧加载任务继续写入当前 UI
- 阶段测试覆盖前进、后退、跳章、换书

---

## 阶段 3：当前页优先的流式分页

目标：

- 长章节不再等待整章分页完成后才稳定显示，优先产出当前阅读位置附近页面。
- 为后续 EPUB 图文分页打底，让分页结果从纯文本切片演进为结构化页面片段。

任务：

- [x] 新增 `ReaderStreamingPaginationController`
- [x] 新增 block-based 分页结果模型，例如文本片段、图片占位、标题、引用等 `ReaderPagedBlock`
- [x] 将 `ReaderPagedSlice` 保留为文本片段类型，不再代表整个分页世界
- [x] 分页前先为图片块解析尺寸、最大显示宽高和占位高度，解析失败时使用保守占位
- [x] 将分页输出拆成：
  - 当前阅读位置页 ready
  - 邻近页 ready
  - 整章分页 complete
- [x] 分页循环中加入可配置 yield 策略
- [x] 当前阅读位置页可用后立即通知 UI
- [x] 滚动模式和分页模式分别定义最小可见数据
- [x] 分页签名变化时取消旧分页任务
- [x] 分页缓存写入延后到整章完成或稳定片段完成
- [x] 将带插图章节从“强制滚动”调整为“分页能力由 block 分页器决定”
- [x] `ReaderTextPagedView` 支持文本块和图片块混排渲染
- [x] 补长章节、跳章中断、设置变化中断的单测

阶段边界：

- 不承诺 isolate 排版
- 不改视觉动效
- 不做 Canvas/Picture 缓存
- 不在本阶段实现复杂图片缩放和漫画预载策略

完成标准：

- 长章节首屏可见时间下降
- 中断旧分页不会污染新章节状态
- 当前页附近可用后 UI 可先显示，整章完成作为后续事件
- EPUB 图文混排章节可在分页模式下展示文字和图片，不再只能退回滚动正文

---

## 阶段 4：资源预算和后台任务降级

目标：

- 把低端机、低电量、移动网络等环境差异转为统一策略，而不是散落在各处判断。

任务：

- [x] 新增 `ReaderResourceBudget`
- [x] 定义设备档位：`low / normal / high`
- [x] 定义电量档位：`lowBattery / normal`
- [x] 定义网络档位：`offline / metered / unmetered`
- [x] 定义阅读场景：`foregroundReading / backgroundPrefetch / cacheManagement`
- [x] 按预算输出：
  - 章节预取数量
  - 章节预下载并发
  - WebView 并发
  - 漫画 cache extent
  - 分页内存条数
  - 图片 decode 目标尺寸倍率
- [x] 低电量或移动网络下暂停远距离预下载
- [x] WebView 只在规则要求时使用，普通 HTTP 优先
- [x] 补策略矩阵单测

阶段边界：

- 不重写网络层
- 不改变书源规则语义
- 不做系统级后台服务

完成标准：

- 阅读器所有后台任务都能从 `ReaderResourceBudget` 拿到明确预算
- 低端机和低电量下后台任务明显收敛
- 策略矩阵有测试覆盖

---

## 阶段 5：缓存从条数限制升级为字节预算

目标：

- 避免超长章节、大图和分页文件让缓存膨胀失控。

任务：

- [x] 为章节缓存增加估算字节预算
- [x] 为分页缓存增加文件总字节预算
- [x] 为封面和阅读器图片缓存增加总字节预算
- [x] 保留当前条数限制作为兜底
- [x] 清理策略改为 `过期时间 + LRU + 字节预算`
- [x] 缓存管理页展示条数和估算大小
- [x] 数据库增加必要索引：
  - `chapter_caches(book_id)`
  - `chapter_caches(book_id, source_id, chapter_index)`
  - `chapter_caches(updated_at)`
  - `local_chapters(book_id, chapter_index)`
  - `bookmarks(book_id, chapter_index, start_offset)`
- [x] 补 migration 测试和缓存清理测试

阶段边界：

- 不迁移章节正文到外部文件，除非阶段评审确认数据库膨胀仍不可接受
- 不改变用户可见的缓存功能入口

完成标准：

- 缓存清理可按字节预算收敛
- 大章节和大图不会只因条数少而逃过清理
- 数据库常用查询有索引支撑

---

## 阶段 6：渲染和图片内存治理

目标：

- 降低连续翻页、漫画滚动和插图章节的内存峰值。
- 在不牺牲低端机流畅度的前提下，补齐漫画和 EPUB 插图的基础体验。

任务：

- [x] 为正文图片统一计算 `cacheWidth/cacheHeight`
- [x] 为 EPUB 插图、漫画图、封面图拆分图片预算，避免互相挤占缓存
- [x] 漫画模式按资源预算调整 `cacheExtent`
- [x] 漫画页离开可视窗口后释放缩放 controller 和临时状态
- [x] 漫画分页模式只保留当前页、前一页、后一页的重型状态
- [x] 连续漫画滚动按设备档位限制预渲染距离，低端档位优先降低 `cacheExtent`
- [x] 限制 data URI 图片大小，超限时拒绝内存解码
- [x] 审核 `Image.memory`、`Image.network`、`Image.file` 的使用点
- [x] 调整 Flutter `PaintingBinding.instance.imageCache` 上限，按设备档位配置
- [x] 对文本分页页面引入可选轻量渲染缓存评估，不默认启用
- [x] 补 EPUB 图文分页、EPUB 图文滚动、纯漫画分页、纯漫画连续滚动四类回归用例
- [x] 补漫画滚动和插图章节 smoke test

阶段边界：

- 不做新的漫画阅读产品模式，只补齐现有 `continuous / paged / horizontal` 的资源治理和稳定性
- 不做复杂 Picture 缓存，除非有 profile 证明收益大于内存成本

完成标准：

- 漫画连续滚动内存峰值下降
- 插图章节不因原图过大造成明显内存尖峰
- 低端机档位下图片缓存明显更保守
- EPUB 图文分页不会因大图导致明显卡顿或 OOM

---

## 阶段 7：定时器、阅读记录和信息栏低频化

目标：

- 减少阅读器长时间停留时的无意义唤醒和 setState。

任务：

- [x] 梳理 `reader_page.dart` 内所有 `Timer`
- [x] 阅读记录提交统一为 session coordinator 管理
- [x] 自动保存采用分钟级节流，并在退出/切章时补提交
- [x] 时间显示只按分钟更新
- [x] 电量显示优先事件驱动，无法事件驱动时低频读取
- [x] 自动阅读在不可见、弹层显示、低电量策略触发时自动暂停
- [x] 补生命周期测试：进入后台、返回前台、退出阅读器、快速换书

阶段边界：

- 不改变阅读统计口径
- 不改变用户设置项

完成标准：

- 长时间阅读时无高频无效 setState
- 退出阅读器后无遗留 timer
- 阅读记录不丢失且写入频率可控

---

## 6. 验证矩阵

每个阶段至少执行：

```bash
flutter analyze
```

涉及 application 逻辑：

```bash
flutter test test/features/reader
```

涉及数据库 migration：

```bash
flutter test test/data
```

涉及架构边界：

```bash
dart run tool/check_architecture_guardrails.dart
```

真机手工验证：

- 低端 Android 打开在线书
- 低端 Android 打开本地 TXT 长章节
- 低端 Android 打开 EPUB
- 低端 Android 漫画连续滚动
- 连续阅读 30 分钟
- 快速连续切章 20 次
- 低电量模式下阅读和预缓存
- 移动网络下阅读和预缓存

---

## 7. 风险和回退

### 7.1 高风险点

- 分页流式化可能引入进度恢复偏差
- 三章窗口可能误释放仍被 UI 引用的资源
- 图片 decode size 可能导致图片清晰度下降
- 字节预算清理可能误删用户期望保留的缓存
- 任务取消不彻底可能造成旧章节写入新章节

### 7.2 回退策略

- 每阶段独立 feature flag 或内部策略开关
- 先在测试入口和 debug 日志中验证，再默认开启
- 若流式分页风险过高，先保留整章分页，单独启用三章窗口和任务取消
- 若图片降采样影响体验，按设备档位启用，不全量开启

---

## 8. 文档维护规则

- 本专项相关任务只维护在本文件。
- 每完成一个阶段，必须回填阶段状态、完成日期和偏差说明。
- 若新增阶段，必须写明为什么不能归入既有阶段。
- 若阶段任务扩大超过 30%，必须拆新阶段，不允许在原阶段无限追加。
- 与已有文档冲突时：
  - 架构边界以 `docs/development_architecture_guardrails.md` 为准
  - 阅读模式语义以 `docs/reader_mode_rearchitecture_plan.md` 为准
  - 书架点击链路以 `docs/bookshelf_reader_open_latency_execution_plan.md` 为准
  - 本文件只负责低资源占用和性能执行顺序
