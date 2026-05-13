# 阅读器滚动/分页丝滑体验改造计划

日期：2026-05-13

## 0. 结论

本轮检查确认：当前阅读器已经采用“底层内容共享，滚动与分页视图分立”的主流架构，不需要把两套交互合并。

当前主链路已经具备：

- 文本滚动视图：`lib/features/reader/presentation/reader_text_scroll_view.dart`
- 文本分页视图：`lib/features/reader/presentation/reader_text_paged_view.dart`
- 漫画连续/分页/横向视图：`lib/features/reader/presentation/reader_manga_view.dart`
- 统一文档模型：`lib/domain/entities/reader_document.dart`
- 分页引擎：`lib/features/reader/application/reader_pagination_engine.dart`
- 分页缓存：`lib/features/reader/application/reader_pagination_cache_service.dart`
- 邻章预加载：`lib/features/reader/application/reader_preload_controller.dart`
- 图片解码预算：`lib/features/reader/application/reader_image_decode_budget.dart`
- 进度防抖保存：`lib/features/reader/presentation/reader_page_runtime.dart`

本计划不重做阅读器壳层，不推翻现有滚动/分页分离方案。改造重点是：

1. 逐页流式分页，当前页抢先交付。
2. 本地 TXT/EPUB 首开更懒加载。
3. 图文分页缓存改为布局描述/内容引用区间。
4. 翻页/滚动期间减少后台任务抢占。
5. 长列表、设备分级和真机指标形成闭环。

## 1. 当前状态对账

| 方向 | 当前实现 | 判断 |
| --- | --- | --- |
| 滚动/分页分离 | `ReaderModeResolver` 根据内容和设置切到 `textScroll` 或 `textPaged` | 已符合 |
| 滚动渲染 | `ListView.builder` 按 block/paragraph 构建 | 已符合 |
| 分页渲染 | `PageView.builder` + 自定义 transition/curl stack | 已符合 |
| 统一内容模型 | `ReaderDocument` + `ReaderBlock` | 已符合 |
| 分页缓存 | 纯文本 `ReaderPrecomputedChapterLayout` 内存+磁盘缓存 | 部分符合 |
| 图文分页 | `ReaderPagedBlock` 已支持 text/image | 已符合主体 |
| 邻章预加载 | 内容预载 + 纯文本分页预热 | 部分符合 |
| 图片预算 | `cacheWidth/cacheHeight` + `ImageCache` 上限 | 已符合 |
| 进度保存 | Timer 防抖 + 异步保存 | 已符合 |
| 分页后台化 | 当前靠 cooperative yield，不是真 isolate | 需评估 |
| TXT 首开懒加载 | 大文件有 streaming index，但仍会 hydrate 章节内容 | 需优化 |
| EPUB 首开懒加载 | parse 阶段会遍历正文并抽取章节 | 需优化 |

## 2. 设计原则

- 保留“滚动和分页两套视图”。滚动是连续内容交付，分页是页边界交付，两者只共享内容、进度、设置、书签和缓存策略。
- 不盲目 isolate 化分页。当前分页使用 `TextPainter`，直接搬到普通 isolate 不一定可行；先补 Timeline 和真机数据，再决定拆法。
- 本地导入优先“目录可用、正文按需”。首屏只需要定位章节和展示当前章，不应该因为预解析全书正文拖慢。
- 缓存签名必须精确。章节、字号、行高、页宽高、段间距、字体、主题相关视觉字段变化都要导致分页缓存失效。
- 阅读主线程只做轻量构建和绘制。预加载、图片解码、缓存写入都要低优先级、可取消、可降级。

## 3. 评审意见吸收后的优先级

本轮吸收外部评审意见后，优先级调整为：

| 优先级 | 方向 | 原因 |
| --- | --- | --- |
| P0 | 逐页流式分页 | 直接消除大章分页白屏，是分页体验的最大杠杆 |
| P0 | TXT/EPUB 目录优先、正文按需 | 直接降低本地首开等待感 |
| P1 | 翻页动画期间后台任务降噪 + 页级 `RepaintBoundary` | 保证 60 fps 手感 |
| P1 | 图文分页缓存改为布局描述 | 设置恢复和二次打开收益明显 |
| P2 | 滚动长列表稳帧、设备分级、压测矩阵 | 覆盖低端机和极端样本 |
| P2 | 可观测性与反馈入口 | 把“流畅”变成可测量指标 |

执行时允许“轻量可观测性”先行，例如先给分页和首开链路打 `Timeline`，再进入 P0 实装；但不再把完整性能基线作为所有 P0 的阻塞前置条件。

## 4. 改造阶段

### 阶段 0：性能基线和卡顿定位

目标：先放入必要观测点，让后续 P0 优化可以量化收益。

- [x] 在分页开始、分页完成处加 `Timeline` 标记。
- [x] 在 TXT/EPUB 索引开始、目录 ready、当前章 ready 处加 `Timeline` 标记。
- [ ] 补齐当前页可显示、缓存命中、缓存写入、首帧 ready 的细粒度 `Timeline` 标记。
- [ ] 建立真机样本矩阵：低端 Android、中端 Android、iPhone、小屏模拟器。
- [ ] 固定样本书：纯 TXT 大文件、普通 TXT、图文 EPUB、纯漫画、PDF。
- [ ] 记录指标：打开到首屏、首翻页耗时、分页耗时、滚动帧率、翻页帧率、峰值内存、分页缓存命中率。
- [ ] 构造压测章节：1 万行纯文本、50 张高清图混排、超长单段落。
- [ ] 预留测试反馈入口：开发期可查看分页耗时、帧率、缓存命中和当前降级等级。
- [x] 把结果回填到 `docs/reader_baseline_matrix_2026-05-09.md` 或新增 2026-05-13 小节。

验收：

- 有可复测的样本和数据。
- 至少能区分是解析慢、分页慢、图片慢，还是 UI rebuild 慢。

### 阶段 1：本地 TXT 首开懒加载

目标：TXT 导入/打开时优先建立目录和偏移，正文按章节读取。

当前风险点：

- `TxtLocalBookParser` 大文件虽然有 streaming index，但 `_hydrateChapterContentsFromOffsets` 会把章节正文补回 `LocalParsedChapter`。
- 对很大的 TXT，索引阶段可能仍写入大量正文，拖慢首开并放大数据库体积。

任务：

- [x] 为 TXT 建立“index-only chapter”模式：章节只保存 `startOffset/endOffset/charset/title`。
- [x] `LocalChapterContentService` 读取当前章节时再按 offset 解码正文。
- [x] 保留小文件或兼容路径的全文正文存储，但以策略控制，不作为大文件默认路径。
- [x] 对重新索引、旧数据迁移和 stale 状态补兼容。
- [x] 补测试：大 TXT 索引不写入正文、按章节读取正文、编码保持一致、文件变化后提示重建索引。

涉及文件：

- `lib/features/reader/application/local/txt_local_book_parser.dart`
- `lib/features/reader/application/local/local_chapter_content_service.dart`
- `lib/features/reader/application/local/local_book_index_service.dart`
- `lib/domain/entities/local_chapter.dart`

验收：

- 大 TXT 建目录速度明显下降。
- 当前章读取正确。
- 旧 TXT 数据仍能打开。

### 阶段 2：EPUB 首开懒加载

目标：EPUB 首次导入只解析 metadata、cover、toc/spine 和资源索引，章节正文按需解析。

当前风险点：

- `EpubLocalBookParser.parse()` 当前会遍历 body 章节并抽取正文。
- 对大 EPUB 或图文 EPUB，首次导入会被 HTML 解析和图片落盘拖慢。

任务：

- [x] 将 EPUB parse 拆成 `parseIndex` 和 `parseChapter` 两条路径。
- [x] `parseIndex` 只解析 `container.xml / opf / toc / nav / spine`，保存 chapter sourceRef。
- [x] `parseChapter` 按 sourceRef 解析当前章节 HTML，抽取 `ReaderDocument` 和图片资源。
- [x] 封面仍可在 index 阶段物化，章节图片资源按章节解析时再物化。
- [x] 对 zip archive cache 设置上限和失效策略，避免长期持有大 archive。
- [x] 补测试：EPUB 导入不提前解析所有正文、按章节读取图文、toc 粒度和 spine 顺序稳定。

涉及文件：

- `lib/features/reader/application/local/epub_local_book_parser.dart`
- `lib/features/reader/application/local/local_book_index_service.dart`
- `lib/features/reader/application/local/local_chapter_content_service.dart`
- `lib/features/reader/application/local_content_provider.dart`

验收：

- 大 EPUB 导入和首次打开明显变快。
- 当前章图文展示不退化。
- 章节跳转仍稳定。

### 阶段 3：分页计算可观测与渐进显示

目标：从“整章分页后交付”改为“当前页抢先、前后页跟进、其余空闲补齐”。

当前状态：

- `ReaderPaginationEngine` 已分段 yield，避免完全堵死 UI。
- `ReaderStreamingPaginationController` 已有 current/nearby/complete 事件，但内部仍是先跑完整分页再切 prefix。

任务：

- [ ] 新增 lazy page snapshot 模型，表达 `ready / loading / failed` 三态，页面消费快照而不是直接等整章列表。
- [x] 把 streaming pagination 改成逐页回调产出，当前/附近页可在完整分页结束前更新 UI。
- [x] 当前页优先：按恢复 ratio 映射目标段落，分页推进到目标段落时先发 current 事件。
- [ ] 仅当前页、前页、后页进入高优先级计算队列；远页空闲时补齐，不阻塞首屏。
- [ ] 翻到未计算页时展示骨架屏或上一页快照，计算完成后替换为真实页。
- [x] 快速切章、改字号、改边距时继续沿用 `shouldAbort`，避免旧分页结果污染 UI。
- [ ] 加分页耗时阈值日志，记录章节长度、段落数、页数、耗时。
- [x] 评估 isolate 可行性：当前 `TextPainter` 仍留在主 isolate，消息粒度先落到“单页回调/单页结果”。
- [x] 如果 isolate 不能安全使用 `TextPainter`，优先做主 isolate 分块分页和 cooperative yield，不强行拆。

涉及文件：

- `lib/features/reader/application/reader_pagination_engine.dart`
- `lib/features/reader/application/reader_streaming_pagination_controller.dart`
- `lib/features/reader/presentation/reader_page.dart`
- `lib/features/reader/presentation/reader_page_viewport.dart`

验收：

- 长章节分页模式能先显示当前页或加载占位，不卡死。
- 快速调整设置不会出现旧页闪回。
- 真机 timeline 能看到分页阶段耗时。

### 阶段 4：分页缓存扩展到图文 block

目标：缓存布局描述和内容引用区间，不缓存 widget 或最终像素。

当前状态：

- 纯文本分页缓存已持久化。
- 图文分页走 `ReaderPagedBlock`，但缓存主体仍偏纯文本布局。

任务：

- [ ] 新增 block layout 缓存模型，保存 text block 字符区间和 image block 归一化 bounds。
- [ ] 缓存 value 只保存布局描述，例如 `blockId/type/start/end/imageId/bounds`，不保存 widget、不保存渲染像素。
- [ ] 缓存 key 扩展：章节 ID、章节内容版本、字体、字号、行高、段距、页宽高、图片占位策略。
- [ ] 图文分页完成后写入 block layout。
- [ ] 命中缓存时直接恢复 `pagedBlockPages`。
- [ ] 图片真实尺寸获取后，只在尺寸变化超阈值时触发重分页，避免小抖动导致全量失效。
- [ ] 设置变化时只重新分割文字区间和布局图片位置，不重新解析 EPUB HTML。

涉及文件：

- `lib/features/reader/application/reader_pagination_models.dart`
- `lib/features/reader/application/reader_pagination_cache_service.dart`
- `lib/features/reader/presentation/reader_page.dart`

验收：

- 图文 EPUB 第二次打开分页模式能命中缓存。
- 图片章节不会因为轻微尺寸差异频繁重分页。

### 阶段 5：翻页/滚动期间后台任务降噪

目标：翻页动画和滚动手势期间，降低后台任务争抢。

任务：

- [ ] 建立阅读器交互状态：idle、dragging、animating、settling。
- [ ] dragging/animating 时暂停低优先级图片预载和远章分页预热。
- [ ] 动画结束 200ms 后恢复暂停的低优先级队列，避免手指刚松开就抢占。
- [ ] 当前章内容加载和当前页必要图片不暂停。
- [ ] 页级内容外包 `RepaintBoundary`，单页重绘不污染相邻页。
- [ ] 避免在 `PageView.builder` 的 `itemBuilder` 内做异步加载后全局 `setState`；分页页内容通过 page snapshot/listenable 精准更新。
- [ ] 分页模式只保留水平分页手势，滚动模式只走纵向滚动和点击滚动。
- [ ] 检查 `PageView` 物理参数和自定义 curl/cover/translate renderer 的重建范围。
- [ ] 仿真翻页按设备等级降级：低端机默认平推或淡入淡出，中高端机再启用卷曲。

涉及文件：

- `lib/features/reader/application/reader_preload_controller.dart`
- `lib/features/reader/presentation/reader_text_paged_view.dart`
- `lib/features/reader/presentation/reader_page_navigation.dart`
- `lib/features/reader/presentation/paged_animation/`

验收：

- 连续快速翻页不触发明显掉帧。
- 低端机翻页时后台预热不会抢占主体验。

### 阶段 6：资源回收和缓存预算闭环

目标：把章节缓存、分页缓存、图片缓存和封面缓存统一到可观测预算。

任务：

- [ ] 对章节缓存、分页缓存、图片缓存记录条数和字节数。
- [ ] 启动维护继续按预算清理，但日志要能看出清理原因。
- [ ] 漫画分页只保留当前页、前后页的重型状态。
- [ ] 滚动图文列表用 decode budget 控制图片尺寸，不使用全局 `imageCache.clear()` 粗暴清理。
- [ ] 补缓存增长回归脚本或手工验收清单。

涉及文件：

- `lib/app/startup/startup_storage_maintenance_service.dart`
- `lib/features/reader/application/reader_pagination_cache_service.dart`
- `lib/features/reader/application/chapter_cache_service.dart`
- `lib/features/reader/presentation/reader_image_pipeline.dart`
- `lib/features/reader/presentation/reader_manga_view.dart`

验收：

- 长时间阅读后缓存增长可解释。
- 退出阅读器后不保留窗口外重型图片状态。

### 阶段 7：滚动模式长列表稳帧

目标：让超长 TXT、超多段落、图文混排在快速滚动时保持稳定。

任务：

- [ ] 梳理滚动模式段落 item 的高度策略：可固定高度的资源项使用固定约束，文本项避免额外测量。
- [ ] 对超长单章建立段落窗口策略，只保留可见段落和缓冲区的重型状态。
- [ ] 滚动回调不做全量 `setState`，进度展示改为独立 listenable/select 精准刷新。
- [ ] 对图文滚动列表继续使用 decode budget，不做全局 `imageCache.clear()`。
- [ ] 增加大 TXT 快速滚动 smoke 或手工压测清单。

涉及文件：

- `lib/features/reader/presentation/reader_text_scroll_view.dart`
- `lib/features/reader/presentation/reader_page_content_rendering.dart`
- `lib/features/reader/presentation/reader_page_runtime.dart`

验收：

- 1 万行文本快速滚动不卡顿到不可用。
- 滚动进度更新不引发整页重建。

### 阶段 8：设备分级与降级策略

目标：旗舰机保留效果，低端机优先稳定。

建议分级：

| 能力/预算 | Low | Medium | High |
| --- | --- | --- | --- |
| 最大图片解码尺寸 | 1080p | 1440p | 封顶 4K |
| 仿真翻页动画 | 降级平推/淡入淡出 | 轻量卷曲 | 完整卷曲 |
| 邻章预加载数 | 0 章 | 1 章 | 2 章 |
| 离线分页缓存数量 | 3 章 | 5 章 | 10 章 |
| 分页计算并发 | 1 条队列 | 1-2 条队列 | 2-3 条队列 |

任务：

- [ ] 新增 reader device tier resolver，输入设备型号、系统版本、内存线索、电量和当前工作场景。
- [ ] 把 tier 接入 `ReaderResourceBudget`。
- [ ] 把 tier 接入翻页动画策略、图片 decode budget、邻章预加载和分页缓存数量。
- [ ] 低电量和后台恢复场景自动收紧预算。

涉及文件：

- `lib/features/reader/application/reader_resource_budget.dart`
- `lib/features/reader/application/reader_image_decode_budget.dart`
- `lib/features/reader/application/reader_animation_policy.dart`
- `lib/features/reader/application/reader_preload_controller.dart`

验收：

- 低端机不会默认启用高成本卷曲和远章预载。
- 高端机仍保留完整视觉体验。

## 5. 不做事项

- 不把滚动模式和分页模式合并成一套 widget。
- 不重写整个 `ReaderPage`。
- 不为了“后台化”强行把 `TextPainter` 分页搬到普通 isolate。
- 不在滚动过程中全局 `imageCache.clear()`。
- 不让仿真翻页成为低端机默认路径；必要时按设备和资源预算降级。

## 6. 验证集合

每个阶段至少跑：

```bash
flutter analyze lib/features/reader
flutter test test/features/reader
```

涉及本地格式解析时追加：

```bash
flutter test test/features/reader/application/local
```

涉及分页模型时追加：

```bash
flutter test test/features/reader/application/reader_pagination_engine_test.dart
flutter test test/features/reader/presentation
```

真机验收必须覆盖：

- TXT 大文件打开、目录跳转、分页、滚动。
- EPUB 图文打开、分页、滚动、章节跳转。
- 漫画连续、分页、横向。
- 快速改字号、行距、边距后分页恢复正确。
- 后台/前台切换后进度保存正确。

## 7. 执行顺序建议

优先级从高到低：

1. 阶段 0 的轻量观测点：先打 Timeline 和压测口径。
2. 阶段 3：真正逐页流式分页。
3. 阶段 1：TXT 首开懒加载。
4. 阶段 2：EPUB 首开懒加载。
5. 阶段 5：后台任务降噪和页级重绘隔离。
6. 阶段 4：图文 block 布局缓存。
7. 阶段 7：滚动模式长列表稳帧。
8. 阶段 8：设备分级与降级策略。
9. 阶段 6：缓存预算闭环。

原因：

- 逐页流式分页和首开懒加载是最大体感收益。
- 轻量 Timeline 是执行护栏，但完整性能矩阵不阻塞 P0。
- 后台任务降噪应跟分页一起做，否则分页快了也可能被动画抢占拖慢。
- 图文缓存、滚动稳帧和设备分级属于扩大收益覆盖面。
