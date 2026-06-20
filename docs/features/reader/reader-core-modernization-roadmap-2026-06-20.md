# 阅读器核心功能改造路线图

**日期**: 2026-06-20
**来源**: `reader-core-code-review-legado-gap-2026-06-20.md`
**目标**: 在不推翻现有阅读器的前提下，逐步补齐主流阅读器需要的排版内核、交互锚点、翻页委托、混排语义和性能保护。

---

## 0. 当前落地状态

- [x] 已建立 V 节点总览：`reader-core-modernization-version-map-2026-06-20.md`。
- [x] 已建立 V1-V6 节点文档，后续主线按 V 节点推进。
- [x] V1 底座已落地：surface position、layout model、旧分页 adapter、hit-test/range service、adapterOnly fallback runner。
- [x] V1 默认不改变现有阅读器 UI 行为。
- [x] V1 出口报告：`reader-core-modernization-v1-exit-report-2026-06-20.md`。
- [x] V2 执行计划：`reader-core-modernization-v2-execution-plan-2026-06-20.md`。
- [x] V2-P0/P1/P2/P3/P4/P5/P6 已完成 alpha 代码侧落地。
- [ ] V1 真实样本手工行为记录仍需补齐。
- [ ] V2 默认切换新 renderer 前必须完成 diagnostics 和 smoke。

---

## 1. V 节点主线

| 节点 | 文档 | 状态 | 主效果 |
|---|---|---:|---|
| V1 | `reader-core-modernization-v1-foundation-node-2026-06-20.md` | 代码侧收尾 | 底座完成，默认 UI 不变 |
| V2 | `reader-core-modernization-v2-layout-engine-node-2026-06-20.md` | 已完成主体 | 新 layout engine 可运行 |
| V3 | `reader-core-modernization-v3-renderer-node-2026-06-20.md` | 未开始 | 新文本阅读器 debug/dev 灰度可用 |
| V4 | `reader-core-modernization-v4-interaction-node-2026-06-20.md` | 未开始 | 选择、标注、书签、搜索、朗读闭环 |
| V5 | `reader-core-modernization-v5-surface-node-2026-06-20.md` | 未开始 | 文本、漫画、PDF、音频 surface 完整 |
| V6 | `reader-core-modernization-v6-release-node-2026-06-20.md` | 未开始 | 新阅读器默认上线，旧阅读器 fallback |

---

## 2. 改造原则

- [ ] 保持用户可见行为渐进变化，避免一次性重写阅读器。
- [ ] 每个阶段只移动一个核心边界，阶段结束必须可独立回归。
- [ ] 新内核先通过 adapter 兼容旧 UI，再逐步替换旧模型。
- [ ] 分页、选择、标注、朗读、搜索必须最终共享同一套 layout position。
- [ ] 重计算任务默认不放在 UI isolate。
- [ ] 不以文件行数作为唯一目标，以职责边界、可测试性和性能预算作为验收。
- [ ] 每个阶段完成后更新本文档 checkbox 和阶段结论。

---

## 3. 目标架构

目标不是照搬 Legado，而是在 Flutter 项目内建立等价边界：

```text
ReaderPage
  -> ReaderSessionRuntime
  -> ReaderContentRuntime
  -> ReaderLayoutRuntime
      -> ReaderLayoutEngine
      -> ReaderLayoutCache
      -> ReaderLayoutStream
  -> ReaderPageTurnRuntime
      -> ReaderPageFactory
      -> ReaderPageTurnDelegate
  -> ReaderSelectionRuntime
      -> hitTest / rangeToRects / anchor restore
  -> ReaderMediaRuntime
      -> read aloud / audio / image actions
```

核心实体建议：

```text
ReaderDocument
  -> ReaderBlock
  -> ReaderInlineSpanNode

ReaderLayoutPage
  -> ReaderLayoutLine
  -> ReaderLayoutColumn
  -> ReaderLayoutPosition
  -> ReaderLayoutRange
```

---

## 4. Phase 0：基线冻结和样本库

**目标**: 在动内核前固定当前行为、性能和样本，避免改造期间无法判断是否退化。

### 0.1 样本书库

- [ ] 准备短篇 TXT：纯中文、短段落、普通章节。
- [ ] 准备超长 TXT：单章 10 万字以上。
- [ ] 准备超长段落 TXT：单段 5000 字以上。
- [ ] 准备中文标点样本：避头尾标点、引号、破折号、省略号、括号。
- [ ] 准备 EPUB 简单样本：标题、段落、图片。
- [ ] 准备 EPUB 混排样本：图片、链接、脚注、列表、引用、caption。
- [ ] 准备 HTML 章节样本：inline style、span、a、img。
- [ ] 准备漫画/图片章节样本：连续图、横向、分页。

### 0.2 行为基线

- [ ] 记录当前分页模式首屏耗时。
- [ ] 记录当前字体大小变化后的重排耗时。
- [ ] 记录当前跳章、上一页、下一页、跨章节翻页行为。
- [ ] 记录当前长按选择、复制、标注、删除标注行为。
- [ ] 记录当前自动阅读滚动/翻页行为。
- [ ] 记录当前纸页动画、仿真/覆盖/滑动/淡入动画行为。
- [ ] 记录当前 EPUB 图片展示和点击行为。

### 0.3 保护测试

- [ ] 为样本 TXT 建立分页数量和关键 offset 快照测试。
- [ ] 为中文标点建立 data test，不要求首次完全正确，但要记录当前输出。
- [ ] 为跨页选择建立失败用例，先标记 expected current behavior。
- [ ] 为跨章节翻页建立 state machine 单测。
- [ ] 为字体/边距/行高改变建立 pagination signature 测试。
- [ ] 建立 Android/iOS 真机 smoke checklist。

### 0.4 阶段验收

- [ ] 样本库路径写入文档或测试 fixture 说明。
- [ ] 当前核心行为有可复跑记录。
- [ ] 当前性能有 profile mode 基线。
- [ ] 后续阶段能用这些样本判断退化。

---

## 5. Phase 1：建立 ReaderLayout 核心模型

**目标**: 先建模型和 adapter，不大改 UI。让项目拥有“页、行、列、位置、范围”的通用语言。

### 1.1 新增核心实体

- [x] 新建 `lib/features/reader/domain/entities/reader_layout_page.dart`。
- [x] 定义 `ReaderLayoutPage`：`chapterId`、`chapterIndex`、`pageIndex`、`startOffset`、`endOffset`、`contentRect`、`lines`、`blocks`、`isCompleted`。
- [x] 新建 `reader_layout_line.dart`。
- [x] 定义 `ReaderLayoutLine`：`text`、`paragraphIndex`、`chapterOffset`、`pageOffset`、`lineTop`、`lineBase`、`lineBottom`、`columns`、`flags`。
- [x] 新建 `reader_layout_column.dart`。
- [x] 定义 `ReaderLayoutColumn`：text/image/link/span 等 kind、`startOffset`、`endOffset`、`rect`、`styleKey`、`payload`。
- [x] 新建 `reader_layout_position.dart`。
- [x] 定义 `ReaderLayoutPosition`：`pageIndex`、`lineIndex`、`columnIndex`、`chapterOffset`、`affinity`。
- [x] 新建 `reader_layout_range.dart`。
- [x] 定义 `ReaderLayoutRange`：`start`、`end`、`selectedText`、`rects`。

### 1.2 兼容旧分页模型

- [x] 新建 `ReaderPagedSliceLayoutAdapter`。
- [x] 将 `List<List<ReaderPagedSlice>>` 转换成最低可用的 `List<ReaderLayoutPage>`。
- [x] adapter 生成 line 时先允许一段一行或 slice 一行，作为过渡模型。
- [x] 保留旧 `ReaderTextPagedView` 入参，不直接切 UI。
- [x] 给 adapter 补测试：段落 index、start/end、pageIndex、chapter offset 不丢失。

### 1.3 坐标工具

- [x] 新建 `ReaderLayoutHitTestService`。
- [x] 实现 `hitTestPage(page, offset)`。
- [x] 新建 `ReaderLayoutRangeService`。
- [x] 实现 `rangeToRects(layoutPages, startOffset, endOffset)`。
- [x] 实现 `positionToChapterOffset(position)`。
- [x] 实现 `chapterOffsetToPosition(layoutPages, offset)`。

### 1.4 阶段验收

- [x] 新模型有纯 Dart 单测。
- [x] 旧分页结果可以无损转换成 layout page。
- [x] 不改现有 UI 行为。
- [x] 新增文件定向 `flutter analyze` 通过。
- [x] 记录哪些字段目前由 adapter 填假值，作为 Phase 2 输入。

---

## 6. Phase 2：重建分页/排版引擎

**目标**: 从 paragraph slice engine 升级为 layout engine，支持增量、可取消、缓存和中文排版基础。

### 2.1 输入 DTO

- [ ] 新建 `ReaderLayoutRequest`。
- [ ] 包含 chapterId、chapterIndex、document、viewport spec、typography spec、image spec、layout flags。
- [ ] 确保 DTO isolate-safe，不能包含 `BuildContext`、`TextStyle`、`ui.Image`、controller。
- [ ] 将 `ReaderPaginationSpec` 中可复用字段迁移或映射到 `ReaderLayoutSpec`。
- [ ] 将 layout signature 包含字体、宽高、边距、行高、字距、缩进、中文布局开关、图片策略、标题策略。

### 2.2 LayoutEngine 第一版

- [ ] 新建 `ReaderLayoutEngine`。
- [ ] 支持纯文本 block 到 `ReaderLayoutPage/Line/Column`。
- [ ] 支持 title block 到 layout line，并保留 isTitle flag。
- [ ] 支持 image block 到 image column/block，并保存 estimated rect。
- [ ] 支持 paragraph spacing、first line indent、full justify、bottom justify。
- [ ] 支持取消 token。
- [ ] 支持每完成一页回调 `onPageReady`。

### 2.3 增量分页流

- [ ] 新建 `ReaderLayoutStreamController`。
- [ ] 优先计算当前目标页附近内容。
- [ ] 先返回 current/prev/next page，再继续排完整章。
- [ ] 支持设置变化后取消旧任务。
- [ ] 支持章节切换后丢弃旧 generation。
- [ ] 保留现有 `ReaderStreamingPaginationController`，通过 adapter 逐步替换。

### 2.4 后台执行

- [ ] 梳理哪些布局步骤能进 isolate。
- [ ] 对不能进 isolate 的 Flutter text measurement 建立 UI measurement gateway。
- [ ] 评估 `TextPainter` 依赖下的分层方案：UI 线程测量最小化、计算和缓存后台化。
- [ ] 对纯文本宽度测量建立缓存。
- [ ] 建立 `ReaderLayoutWorker`，先支持可序列化的预处理、分词、段落切分、中文断行准备。
- [ ] 不强行一次性把所有 TextPainter 迁走，先降低主线程连续占用。

### 2.5 中文排版

- [ ] 新增 `ReaderZhLayoutPolicy`。
- [ ] 支持避头标点。
- [ ] 支持避尾标点。
- [ ] 支持中英文混排 word boundary。
- [ ] 支持中文常用字符宽度缓存。
- [ ] 新增设置 `useZhLayout`，默认可先关闭或灰度开启。
- [ ] 将 `useZhLayout` 加入 layout signature。
- [ ] 用中文标点样本补 data test。

### 2.6 Layout cache

- [ ] 新建 `ReaderLayoutCacheService` 或扩展现有 cache service。
- [ ] 缓存 payload 改为 layout pages，而不是只存 `ReaderPagedSlice`。
- [ ] 支持按 chapterId + layout signature 命中。
- [ ] 缓存中保留 document fingerprint，避免内容变更误用。
- [ ] 限制内存 LRU 数量。
- [ ] 限制磁盘缓存体积。
- [ ] 增加 cache 版本号，允许旧缓存自动失效。

### 2.7 阶段验收

- [ ] 纯文本分页由新 layout engine 产出。
- [ ] 当前页首屏可以优先 ready。
- [ ] 设置变化后旧任务能取消。
- [ ] 超长段落不会长时间卡 UI。
- [ ] 中文标点测试有明确结果。
- [ ] 旧 `ReaderPaginationEngine` 仍可作为 fallback。

---

## 7. Phase 3：渲染层适配 ReaderLayoutPage

**目标**: UI 不再直接渲染 paragraph slice，而是渲染 layout page。旧 renderer 保留 fallback。

### 3.1 新 paged view

- [ ] 新建 `ReaderLayoutPagedView`。
- [ ] 输入 `List<ReaderLayoutPage>` 或 lazy page snapshot。
- [ ] 每页按 line/column 绘制文本和图片。
- [ ] 保留 `SelectableText` fallback，但业务命中使用 layout position。
- [ ] 支持 page keep-alive 策略。
- [ ] 支持图片 decode budget。

### 3.2 文本绘制

- [ ] 新建 `ReaderLayoutTextPainter` 或 painter adapter。
- [ ] 按 layout line 绘制文本。
- [ ] 支持段首缩进。
- [ ] 支持 full justify。
- [ ] 支持 bottom justify 后的 lineTop/lineBottom。
- [ ] 支持 title line 样式。
- [ ] 支持 annotation underline/highlight/wavy overlay。

### 3.3 图片和混排绘制

- [ ] 支持 block image。
- [ ] 支持 inline image placeholder。
- [ ] 图片保存真实显示 rect。
- [ ] 图片加载完成后触发局部 relayout 或更新 aspect ratio。
- [ ] 图片失败时保留稳定占位高度。
- [ ] 图片点击通过 layout hit test 返回 image payload。

### 3.4 旧 view 兼容

- [ ] `ReaderTextPagedView` 暂时保留。
- [ ] 新增 feature flag：旧 slice renderer / 新 layout renderer。
- [ ] 支持按章节或 debug setting 切换。
- [ ] 遇到新 layout 失败时 fallback 到旧 renderer。

### 3.5 阶段验收

- [ ] 纯文本章节在新 renderer 下可读。
- [ ] 旧 renderer 可 fallback。
- [ ] 标注视觉位置和 layout range 一致。
- [ ] 图片章节不出现明显跳页或重叠。
- [ ] `flutter analyze` 和核心 widget test 通过。

---

## 8. Phase 4：选择、标注、搜索、朗读锚点统一

**目标**: 把业务语义从 display offset 迁到 layout position，解决跨页和混排漂移。

### 4.1 Selection runtime

- [ ] 新建 `ReaderSelectionRuntimeController`。
- [ ] 保存当前 selection 的 `ReaderLayoutRange`。
- [ ] 系统 selection 只负责复制文本和 toolbar 展示。
- [ ] 长按命中使用 `ReaderLayoutHitTestService`。
- [ ] 拖拽选择使用 layout line/column 扩展 range。
- [ ] 提供 selection handles 所需 rect。

### 4.2 Bookmark/annotation

- [ ] bookmark 保存 chapterOffset start/end。
- [ ] annotation 渲染通过 `rangeToRects` 获取 rect。
- [ ] 删除旧的 paragraphIndex 强依赖路径。
- [ ] 保留从旧 bookmark range 到新 range 的 migration adapter。
- [ ] 支持跨段、跨页 annotation。
- [ ] 支持图片 annotation 的预留 payload，先不开放 UI 也可建模。

### 4.3 Search

- [ ] 搜索结果保存 chapterOffset range。
- [ ] 当前页高亮由 layout range 转 rect。
- [ ] 搜索跳转通过 `chapterOffsetToPosition` 定位页。
- [ ] 支持搜索结果跨页时分段高亮。

### 4.4 Read aloud

- [ ] 朗读位置保存 chapterOffset。
- [ ] 当前朗读句/段通过 layout range 高亮。
- [ ] 自动翻页时从 layout position 判断下一页/下一章。
- [ ] 保留现有音频章节能力，不和 TTS 一次性混改。

### 4.5 阶段验收

- [ ] 跨页选择不丢范围。
- [ ] 标注恢复位置稳定。
- [ ] 搜索结果高亮和跳转页一致。
- [ ] 朗读高亮跟随可见文字。
- [ ] 旧 bookmark 数据可读。

---

## 9. Phase 5：PageFactory 和 PageTurnDelegate

**目标**: 翻页从 UI 状态操作变成“页面源 + 动画委托”的组合，降低跨章节和多动画模式风险。

### 5.1 PageFactory

- [ ] 新建 `ReaderPageFactory`。
- [ ] 提供 `currentPage`、`nextPage`、`prevPage`。
- [ ] 支持跨章节 next/prev page。
- [ ] 支持 page loading snapshot。
- [ ] 支持 no next/no prev boundary result。
- [ ] 支持自动阅读请求页面。

### 5.2 Page turn request/result

- [ ] 统一 `ReaderPageTurnRequest` 字段：source、direction、animationStyle、allowCrossChapter、reason。
- [ ] 统一 `ReaderPageTurnResult` 字段：started、committed、cancelled、rejected、boundary、fallbackCommitted、error。
- [ ] 每次翻页记录 generation。
- [ ] busy gate 从 UI 状态迁到 page-turn runtime。

### 5.3 Delegate 抽象

- [ ] 新建 `ReaderPageTurnDelegate`。
- [ ] 定义 `prepare`、`start`、`cancel`、`dispose`。
- [ ] 实现 `NoAnimationPageTurnDelegate`。
- [ ] 实现 `FadePageTurnDelegate`。
- [ ] 实现 `CoverPageTurnDelegate`。
- [ ] 实现 `SlidePageTurnDelegate`。
- [ ] 将 paper curl 包装成 `PaperCurlPageTurnDelegate`。
- [ ] 将当前截图跨章逻辑包装成 `SnapshotCrossChapterDelegate`。

### 5.4 降低截图耦合

- [ ] 优先使用 `ReaderLayoutPage` 构造 from/to page。
- [ ] 只有特殊动画需要 bitmap 时才截图。
- [ ] 截图失败时明确 fallback 策略。
- [ ] 快照生命周期由 delegate 管理，不散落在 `_ReaderPageState`。

### 5.5 阶段验收

- [ ] 点击、滑动、音量键、自动阅读都走同一 page-turn request。
- [ ] 普通页内翻页不依赖跨章截图。
- [ ] 跨章翻页失败可降级。
- [ ] 动画 delegate 可单测状态机。
- [ ] 现有纸页动画行为不退化。

---

## 10. Phase 6：ReaderDocument 语义升级

**目标**: 支持 EPUB/HTML/混排内容，不再把复杂内容过早拍平成纯段落。

### 6.1 Block 模型

- [ ] 扩展 `ReaderBlockKind`：paragraph、title、quote、listItem、image、caption、footnote、divider、code、htmlBlock。
- [ ] Block 保存 source range。
- [ ] Block 保存 semantic id，便于脚注、链接、目录 anchor。
- [ ] Block 支持 style key。

### 6.2 Inline 模型

- [ ] 新增 `ReaderInlineNode`。
- [ ] 支持 text span。
- [ ] 支持 link span。
- [ ] 支持 emphasis/strong/code。
- [ ] 支持 color/size/style run。
- [ ] 支持 inline image。
- [ ] 支持 footnote reference。

### 6.3 EPUB/HTML parser 输出

- [ ] `epub_local_book_parser.dart` 输出 ReaderDocument v2。
- [ ] `html_local_book_parser.dart` 输出 ReaderDocument v2。
- [ ] Markdown parser 输出 ReaderDocument v2。
- [ ] TXT parser 继续输出简单 paragraph block。
- [ ] 保留 ReaderDocument v1 到 v2 adapter。

### 6.4 图片和链接语义

- [ ] 图片保存 src、resolvedUri、width、height、alt、caption、headers。
- [ ] 链接保存 href、title、action type。
- [ ] footnote 保存 reference id 和 target block。
- [ ] 图片/链接点击通过 layout column payload 派发。

### 6.5 阶段验收

- [ ] 简单 TXT 行为不变。
- [ ] EPUB 标题、图片、链接可进入 document v2。
- [ ] HTML span 不被全部丢成纯文本。
- [ ] layout engine 能处理 document v2 的基础节点。

---

## 11. Phase 7：成熟阅读器设置和交互补齐

**目标**: 在内核稳定后补齐主流阅读器体验项，避免设置先行但无法真正生效。

### 7.1 排版设置

- [ ] 增加中文排版开关 `useZhLayout`。
- [ ] 增加标题大小。
- [ ] 增加标题行距。
- [ ] 增加标题上下间距。
- [ ] 增加标题分段策略。
- [ ] 增加标题居中/隐藏/左对齐更完整策略。
- [ ] 增加双页阅读模式。
- [ ] 增加横屏双页策略。

### 7.2 点击和硬件输入

- [ ] 文本阅读九宫格点击动作支持更多 action。
- [ ] 漫画阅读九宫格点击动作独立配置。
- [ ] 增加长按音量键翻页选项。
- [ ] 增加播放中音量键是否翻页策略。
- [ ] 增加鼠标滚轮翻页策略。
- [ ] 增加键盘翻页映射配置。
- [ ] 所有输入先转 `ReaderInteractionIntent`，再派发副作用。

### 7.3 朗读/TTS

- [ ] 区分章节音频播放和 TTS 朗读。
- [ ] 新增 TTS engine abstraction。
- [ ] 新增朗读语速/音调/音量配置。
- [ ] 新增朗读定时关闭。
- [ ] 新增媒体按键控制。
- [ ] 新增朗读时自动翻页/滚动策略。
- [ ] 新增朗读位置恢复。

### 7.4 渲染优化设置

- [ ] 增加渲染缓存开关。
- [ ] 增加 e-ink/低动画模式预留。
- [ ] 增加图片内存策略配置。
- [ ] 增加预加载页数配置。
- [ ] 增加布局缓存清理入口。

### 7.5 阶段验收

- [ ] 新设置都写入 `ReaderSettings`。
- [ ] 新设置都进入 layout/page-turn signature 或 interaction resolver。
- [ ] 设置页不因新增项重新膨胀成单文件大面板。
- [ ] 每类设置至少有 application 层测试。

---

## 12. Phase 8：测试、性能和发布治理

**目标**: 把阅读器从“功能可用”推进到“可长期维护、可发版验证”。

### 8.1 自动化测试矩阵

- [ ] Layout model 单测。
- [ ] Layout engine data test。
- [ ] 中文排版 data test。
- [ ] Document parser v2 test。
- [ ] Selection range test。
- [ ] Annotation restore test。
- [ ] Search highlight test。
- [ ] Read aloud anchor test。
- [ ] Page turn delegate state machine test。
- [ ] Cache version/migration test。
- [ ] Settings signature test。

### 8.2 Widget/golden-free 测试

- [ ] 新 paged view smoke test。
- [ ] 图片 block 渲染 smoke test。
- [ ] annotation overlay smoke test。
- [ ] selection toolbar smoke test。
- [ ] page-turn surface smoke test。
- [ ] settings panel smoke test。

### 8.3 性能预算

- [ ] 首屏 current page ready 时间。
- [ ] 章节完整 layout 时间。
- [ ] 字体大小变化重排时间。
- [ ] 横竖屏切换重排时间。
- [ ] 超长段落布局时间。
- [ ] 缓存命中恢复时间。
- [ ] 跨章节翻页准备时间。
- [ ] 图片章节内存峰值。
- [ ] 连续 100 次翻页平均 frame time。

### 8.4 真机 smoke

- [ ] Android release：TXT 分页、滚动、跨章、长按、标注。
- [ ] Android release：EPUB 图片、链接、脚注、混排。
- [ ] Android release：纸页、覆盖、滑动、无动画。
- [ ] Android release：音量键、鼠标滚轮、键盘。
- [ ] iOS release/TestFlight：同样覆盖核心阅读路径。
- [ ] Desktop debug/profile：键盘、鼠标、窗口 resize。

### 8.5 观测和回滚

- [ ] 为 layout generation 增加 debug log。
- [ ] 为 cache hit/miss 增加统计。
- [ ] 为 page-turn result 增加统一日志。
- [ ] 为 selection anchor 失败增加 diagnostics。
- [ ] 新 layout renderer 支持远程或本地 feature flag 回退。
- [ ] 发布前保留旧 pagination fallback 至少一个版本。

### 8.6 阶段验收

- [ ] 新旧内核有明确切换策略。
- [ ] 性能数据达到或优于 Phase 0 基线。
- [ ] 真机 smoke 通过。
- [ ] 文档和 checklist 更新。

---

## 13. 推荐执行顺序

### 第一批：低风险打底

- [ ] Phase 0：基线冻结和样本库。
- [ ] Phase 1：ReaderLayout 核心模型。
- [ ] Phase 1 adapter：旧 `ReaderPagedSlice` 转新 layout page。

### 第二批：核心能力替换

- [ ] Phase 2：重建分页/排版引擎。
- [ ] Phase 3：渲染层适配 ReaderLayoutPage。
- [ ] Phase 4：选择、标注、搜索、朗读锚点统一。

### 第三批：体验和主流能力

- [ ] Phase 5：PageFactory 和 PageTurnDelegate。
- [ ] Phase 6：ReaderDocument 语义升级。
- [ ] Phase 7：成熟阅读器设置和交互补齐。

### 第四批：发版保护

- [ ] Phase 8：测试、性能和发布治理。
- [ ] 新内核灰度打开。
- [ ] 旧内核保留 fallback。
- [ ] 数据确认稳定后清理旧 slice 主路径。

---

## 14. 不建议现在做的事

- [ ] 不建议直接删除 `ReaderPaginationEngine`，先作为 fallback。
- [ ] 不建议直接把 `SelectionArea` 全部替换，自定义选择需要逐步接管。
- [ ] 不建议一次性重写 `reader_page.dart`。
- [ ] 不建议先堆新增设置，内核无法支持时设置只会增加维护成本。
- [ ] 不建议先做大规模目录搬迁，先让核心实体和 runtime 边界稳定。
- [ ] 不建议为了追求 Legado 一致而照搬 Android 绘制模型，Flutter 侧应保留 widget/painter 的平台优势。

---

## 15. 每阶段统一完成标准

- [ ] 有设计说明或更新本文档。
- [ ] 有纯 Dart 单测覆盖核心规则。
- [ ] 有必要的 widget smoke test。
- [ ] `flutter analyze` 通过。
- [ ] 关键 reader 测试通过。
- [ ] 有手工 smoke 记录。
- [ ] 有 fallback 或回滚路径。
- [ ] 没有把新业务状态继续塞回 `_ReaderPageState`。
