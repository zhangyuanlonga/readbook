# 阅读器核心改造 V1 执行计划

**日期**: 2026-06-20  
**范围**: V1 只启动阅读器核心内核改造的第一轮，不重写完整阅读器。  
**关联文档**:

- `reader-core-code-review-legado-gap-2026-06-20.md`
- `reader-core-modernization-roadmap-2026-06-20.md`
- `reader-surface-special-audit-2026-06-20.md`
- `reader-v1-test-samples-baseline-2026-06-20.md`
- `reader-core-modernization-v1-exit-report-2026-06-20.md`
- `reader-core-modernization-v2-execution-plan-2026-06-20.md`

---

## 1. V1 目标

V1 的目标是建立“后续所有阅读能力可以共用的底座”，不是一次性替换现有阅读器。

- [ ] 固定样本和当前行为基线。
- [x] 建立 `ReaderSurfacePosition`，统一文本、漫画、PDF、音频的进度表达。
- [x] 建立 `ReaderLayoutPage / Line / Column / Position / Range` 第一版。
- [x] 建立旧 `ReaderPagedSlice` 到新 layout model 的 adapter。
- [x] 建立 layout hit-test / range 工具的最小实现。
- [x] 接入 feature flag / fallback 策略，保证旧阅读器路径可回退。
- [x] 补齐首批 P1-P5 单元测试，避免后续阶段失控。

---

## 2. V1 不做

- [ ] 不重写 `reader_page.dart`。
- [ ] 不替换现有 `ReaderTextPagedView` 主渲染路径。
- [ ] 不重写漫画 view。
- [ ] 不重写 PDF viewer。
- [ ] 不把音频播放和 TTS/read-aloud 一次性合并。
- [ ] 不重写 EPUB/TXT/PDF parser。
- [ ] 不迁移全部历史 reading progress 数据。
- [ ] 不删除旧 `ReaderPaginationEngine`、`ReaderPagedSlice`、`ReaderPagedBlock`。

---

## 3. 总体进度

| 阶段 | 名称 | 状态 | 进度 | 说明 |
|---|---|---:|---:|---|
| P0 | 基线与样本库 | 进行中 | 35% | 样本目录与清单已固定，行为记录待补 |
| P1 | Surface Position | 已完成主体 | 85% | 模型、codec、旧 progress mapper 与单测已完成，ReaderPage runtime 收口待后续 |
| P2 | Layout 核心模型 | 已完成主体 | 90% | 页/行/列/位置/范围模型与单测已完成，复杂不变量后续服务层继续强化 |
| P3 | 旧分页 Adapter | 已完成主体 | 90% | 旧 slice 可转 layout page，offset policy 与防御测试已完成，图片 marker 细分待后续 |
| P4 | Layout 工具服务 | 已完成主体 | 100% | hitTest/range/offset 转换与单测完成 |
| P5 | 灰度与 fallback | 已完成主体 | 85% | mode/fallback/diagnostics 底座完成，UI debug 入口待 V2 |
| P6 | 测试与验收 | 代码侧收尾 | 85% | P1-P5 与 V2-P0-P3 单测通过，手工样本与 UI smoke 转 V2-P0 |

**V1 总进度**: 90%

进度口径：

- 0%：未开始。
- 25%：核心文件/文档建好，但测试未齐。
- 50%：核心逻辑可运行，单测部分通过。
- 75%：接入边界完成，有 fallback，主要测试通过。
- 100%：阶段验收全部完成，并更新本文档。

---

## 4. Phase P0：基线与样本库

**目标**: 在改内核前固定当前行为，避免后续无法判断是否退化。  
**状态**: 进行中  
**进度**: 35%

### P0.1 样本准备

- [ ] 准备短篇 TXT 样本：纯中文、普通章节、短段落。
- [ ] 准备超长 TXT 样本：单章 10 万字以上。
- [ ] 准备超长段落 TXT 样本：单段 5000 字以上。
- [ ] 准备中文标点样本：避头尾标点、引号、省略号、括号、破折号。
- [x] 准备 EPUB 普通样本：标题、段落、图片。
- [ ] 准备 EPUB 混排样本：图片、链接、脚注、列表、引用、caption。
- [ ] 准备 fixed EPUB / picture book 样本。
- [ ] 准备漫画样本：连续长图、分页漫画、横向漫画。
- [ ] 准备 PDF 样本：文本 PDF、扫描 PDF、加密 PDF、大页数 PDF。
- [ ] 准备音频样本：直链音频、manifest 音频、带 headers 音频、失败音频。

### P0.2 当前行为记录

- [ ] 记录文本分页首屏耗时。
- [ ] 记录文本滚动首屏耗时。
- [ ] 记录字体大小变化后的重排耗时。
- [ ] 记录行距/边距变化后的重排耗时。
- [ ] 记录普通章节上一页/下一页行为。
- [ ] 记录跨章节上一页/下一页行为。
- [ ] 记录长按选择、复制、保存标注、删除标注行为。
- [ ] 记录漫画连续滚动进度恢复行为。
- [ ] 记录漫画分页 page index 恢复行为。
- [ ] 记录 PDF page index 恢复行为。
- [ ] 记录音频 position/speed 恢复行为。
- [ ] 记录换源后文本章节进度迁移行为。

### P0.3 基线测试

- [x] 新增样本说明文档或 fixture README。
- [ ] 为 TXT 普通章节建立分页数量基线。
- [ ] 为超长段落建立分页不崩溃基线。
- [ ] 为中文标点建立当前断行输出基线。
- [ ] 为漫画 page index 建立 smoke test。
- [ ] 为 PDF 缺文件/页码恢复建立 smoke test。
- [ ] 为音频无 URL/错误态建立 widget smoke test。
- [ ] 为换源进度迁移建立当前 behavior test。

### P0 验收

- [x] 样本路径明确。
- [ ] 当前行为记录完成。
- [ ] 核心 smoke 能复跑。
- [ ] 发现的当前缺陷已记录，不在 P0 中修复。

---

## 5. Phase P1：ReaderSurfacePosition 第一版

**目标**: 统一表达不同 surface 的阅读位置，先解决 `_mangaPageIndex` 同时表示漫画/PDF 的语义混乱。  
**状态**: 已完成主体
**进度**: 85%

### P1.1 模型定义

- [x] 新增 `lib/features/reader/application/reader_surface_position.dart`。
- [x] 定义 `ReaderSurfaceKind`: text、image、document、audio。
- [x] 定义 `ReaderSurfacePosition` 统一不可变模型，V1 暂不拆 sealed subclasses。
- [x] 定义 text surface 字段：chapterIndex、chapterOffset、pageIndex、scrollOffset、progressRatio。
- [x] 定义 image surface 字段：chapterIndex、imageIndex、imageCount、scrollOffset、progressRatio。
- [x] 定义 document surface 字段：chapterIndex、pageIndex、pageCount、zoomScale、pageScrollOffset。
- [x] 定义 audio surface 字段：chapterIndex、positionMs、durationMs、speed。
- [x] 增加手写 JSON codec。

### P1.2 与现有 progress 兼容

- [x] 增加 `ReaderSurfacePositionMapper`。
- [x] 从现有 `ReadingProgress.positionSnapshot` 映射到 `ReaderSurfacePosition`。
- [x] 从 `ReaderSurfacePosition` 映射回旧 progress 字段。
- [x] 旧字段保持写入，V1 不做历史数据迁移。
- [x] 缺少 surface kind 时按旧 `viewportMode` 推断。

### P1.3 ReaderPage 状态收口设计

- [ ] 标记 `_mangaPageIndex` 为待拆字段。
- [ ] 设计 `ReaderSurfacePositionRuntime`，先不强制接入全部 UI。
- [x] 将 PDF page index 设计为 document position，不再语义上归入 manga。
- [x] 明确文本 page index 仍由现有 page-turn runtime 承接，V1 只做 mapping。

### P1.4 测试

- [x] text position encode/decode 测试。
- [x] image position encode/decode 测试。
- [x] document position encode/decode 测试。
- [x] audio position encode/decode 测试。
- [x] old progress -> surface position 映射测试。
- [x] surface position -> old progress 映射测试。

### P1 验收

- [x] 新模型不影响现有阅读行为。
- [x] 现有 progress 读写兼容。
- [x] 漫画/PDF/音频的 position 语义在代码层可区分。
- [x] 新增文件定向 `flutter analyze` 通过。

---

## 6. Phase P2：ReaderLayout 核心模型

**目标**: 建立文本阅读内核的最小页/行/列/位置/范围模型。  
**状态**: 已完成主体
**进度**: 90%

### P2.1 文件与目录

- [x] 新建 `lib/features/reader/domain/entities/reader_layout_page.dart`。
- [x] 新建 `lib/features/reader/domain/entities/reader_layout_line.dart`。
- [x] 新建 `lib/features/reader/domain/entities/reader_layout_column.dart`。
- [x] 新建 `lib/features/reader/domain/entities/reader_layout_position.dart`。
- [x] 新建 `lib/features/reader/domain/entities/reader_layout_range.dart`。
- [x] 建立 feature domain 目录，并新增 `reader_layout_models.dart` barrel export。

### P2.2 ReaderLayoutPage

- [x] 字段：chapterId。
- [x] 字段：chapterIndex。
- [x] 字段：pageIndex。
- [x] 字段：startOffset。
- [x] 字段：endOffset。
- [x] 字段：contentWidth/contentHeight。
- [x] 字段：lines。
- [x] 字段：blocks 或 blockRefs。
- [x] 字段：isCompleted。
- [x] 字段：layoutSignature。

### P2.3 ReaderLayoutLine

- [x] 字段：lineIndex。
- [x] 字段：paragraphIndex。
- [x] 字段：text。
- [x] 字段：chapterOffset。
- [x] 字段：pageOffset。
- [x] 字段：lineTop。
- [x] 字段：lineBase。
- [x] 字段：lineBottom。
- [x] 字段：columns。
- [x] 字段：flags: title/image/html/paragraphEnd。

### P2.4 ReaderLayoutColumn

- [x] 定义 `ReaderLayoutColumnKind`: text、image、link、inlinePlaceholder。
- [x] 字段：columnIndex。
- [x] 字段：startOffset。
- [x] 字段：endOffset。
- [x] 字段：rect 或 left/top/right/bottom。
- [x] 字段：text。
- [x] 字段：styleKey。
- [x] 字段：payload。

### P2.5 ReaderLayoutPosition / Range

- [x] `ReaderLayoutPosition`: pageIndex、lineIndex、columnIndex、chapterOffset、affinity。
- [x] `ReaderLayoutRange`: start、end、selectedText、rects。
- [x] 支持 collapsed range。
- [x] 支持跨 line range。
- [x] 支持跨 page range 的结构预留。

### P2.6 不变量

- [x] page.startOffset <= page.endOffset。
- [ ] line.chapterOffset 单调递增。
- [x] column.startOffset <= column.endOffset。
- [ ] page.lines 按 lineIndex 排序。
- [x] range.start <= range.end。
- [x] 所有模型默认 immutable。

### P2.7 测试

- [x] page model 构造测试。
- [x] line/column offset 不变量测试。
- [x] range collapsed 测试。
- [x] range 跨 line 测试。
- [ ] JSON/codec 测试，如 V1 实现 codec。

### P2 验收

- [x] layout model 可被纯 Dart 测试覆盖。
- [x] 模型不依赖 Flutter `BuildContext`。
- [x] 模型不依赖 Widget。
- [x] 可作为后续 cache payload 的基础。

---

## 7. Phase P3：旧分页 Adapter

**目标**: 先让旧 `ReaderPagedSlice` 结果可以转换为新 layout model，做到新模型进入代码但旧 UI 行为不变。  
**状态**: 已完成主体  
**进度**: 90%

### P3.1 Adapter 定义

- [x] 新建 `ReaderPagedSliceLayoutAdapter`。
- [x] 输入：chapterId、chapterIndex、paragraphs、pagedPages、paginationSpec。
- [x] 输出：`List<ReaderLayoutPage>`。
- [x] 支持空 pagedPages。
- [x] 支持空 paragraphs。
- [x] 支持 paragraphIndex 越界防御。

### P3.2 Slice 到 Page

- [x] 每个 `List<ReaderPagedSlice>` 转一个 `ReaderLayoutPage`。
- [x] pageIndex 使用 slice page 顺序。
- [x] startOffset 使用页面第一个 slice 的章节 offset。
- [x] endOffset 使用页面最后一个 slice 的章节 offset。
- [x] contentWidth/contentHeight 来自 `ReaderPaginationSpec`。
- [x] layoutSignature 来自 pagination signature。

### P3.3 Slice 到 Line/Column 的临时策略

- [x] V1 允许一个 slice 先映射成一条 line。
- [x] column 先使用整段 text column。
- [x] lineTop/lineBottom 先用累积 height 估算。
- [x] 在 adapter 命名和 V1 文档中标注这些字段是 fallback，不是最终排版结果。
- [x] 不用 adapter 结果驱动最终视觉，只用于 anchor/range 原型和测试。

### P3.4 Offset 计算

- [x] 使用显式 paragraph starts 计算章节 offset。
- [x] 明确段落间隔策略，避免继续隐式假设 `+2`。
- [x] 增加 paragraph separator policy。
- [ ] 对 image marker paragraph 做特殊记录。

### P3.5 测试

- [x] 单页单段转换测试。
- [x] 单页多段转换测试。
- [x] 跨页段落切片转换测试。
- [x] paragraphIndex 越界测试。
- [x] 空页测试。
- [x] offset 与旧 mapper 对齐测试。

### P3 验收

- [x] 旧分页结果可生成 layout pages。
- [x] 生成结果不参与正式 UI 渲染。
- [x] 不改变当前阅读器行为。
- [x] adapter fallback 字段有注释或文档说明。

---

## 8. Phase P4：Layout 工具服务

**目标**: 建立后续选择、标注、搜索、朗读会用到的最小工具层。
**状态**: 已完成主体
**进度**: 100%

### P4.1 Hit Test

- [x] 新建 `ReaderLayoutHitTestService`。
- [x] 实现 `hitTestPage(page, offset)`。
- [x] 支持按 lineTop/lineBottom 命中 line。
- [x] 支持按 column rect 命中 column。
- [x] 未命中 column 时返回最近 column。
- [x] 支持空 page 返回 null。

### P4.2 Offset / Position 转换

- [x] 实现 `chapterOffsetToPosition(layoutPages, offset)`。
- [x] 实现 `positionToChapterOffset(position)`。
- [x] 支持 pageIndex 越界防御。
- [x] 支持 lineIndex 越界防御。
- [x] 支持 offset 超出章节范围 clamp。

### P4.3 Range 转 Rect

- [x] 新建 `ReaderLayoutRangeService`。
- [x] 实现同一 line range rect。
- [x] 实现跨 line range rect。
- [x] 预留跨 page range 返回多 page rects。
- [x] 支持 collapsed range 返回 caret rect。
- [x] 支持空 range 返回空 rects。

### P4.4 与现有选择链路的关系

- [x] V1 不替换 `SelectionArea`。
- [x] V1 只新增工具服务和测试。
- [x] 现有 `reader_text_offset_mapper.dart` 保留。
- [x] 为后续 selection migration 标注接入点。

### P4.5 测试

- [x] hitTest 命中 line 测试。
- [x] hitTest 命中 column 测试。
- [x] hitTest 空 page 测试。
- [x] chapterOffsetToPosition 测试。
- [x] positionToChapterOffset 测试。
- [x] rangeToRects 单行测试。
- [x] rangeToRects 多行测试。
- [x] collapsed caret 测试。

### P4 验收

- [x] 工具服务纯 Dart 可测。
- [x] 不引入 UI 依赖。
- [x] 不改变现有 selection 行为。
- [x] 为后续标注/朗读迁移提供 API。

---

## 9. Phase P5：灰度入口与 Fallback

**目标**: 让新模型可以被安全打开和关闭，V1 不影响默认阅读体验。
**状态**: 已完成主体
**进度**: 85%

### P5.1 Feature Flag

- [x] 定义 `ReaderLayoutEngineMode`: legacy、adapterOnly、experimental。
- [x] 默认 `legacy`。
- [x] debug/dev 可通过 runner 参数切到 `adapterOnly`。
- [x] experimental 仅预留，不在 V1 默认启用。
- [x] flag 来源先不接远程配置。

### P5.2 接入点

- [x] 提供分页完成后可选生成 layout pages 的 runner。
- [x] 在 diagnostics model 中输出 layout mode。
- [x] 在 diagnostics model 中输出 layout page count。
- [x] adapter 失败时捕获并回退 legacy。
- [x] 不因 adapter 失败影响阅读器显示。

### P5.3 Diagnostics

- [x] 记录 layout adapter 耗时。
- [x] 记录 layout page count。
- [x] 记录 adapter fallback/error。
- [x] 记录 surface position kind。
- [x] 旧 progress 与 surface position 映射结果由 `ReaderSurfacePositionMapper` 覆盖。

### P5.4 Fallback

- [x] legacy 模式完全不构建新 layout。
- [x] adapterOnly 模式构建 layout 但不驱动 UI。
- [x] adapter 失败后返回 diagnostics，不向 UI 抛错。
- [x] 保留关闭开关。

### P5 验收

- [x] 默认行为与当前一致。
- [ ] debug UI 下可观察新 layout 输出。
- [x] 新逻辑失败不会影响正文显示。
- [x] 有 diagnostics 可以定位 adapter 问题。

---

## 10. Phase P6：测试与 V1 出口验收

**目标**: V1 结束时不是“写了一堆模型”，而是有保护线、有 fallback、有下一阶段接入点。  
**状态**: 代码侧收尾
**进度**: 85%

### P6.1 单元测试

- [x] `ReaderSurfacePosition` codec/mapping 测试。
- [x] `ReaderLayoutPage` 模型测试。
- [x] `ReaderLayoutLine` 模型测试。
- [x] `ReaderLayoutColumn` 模型测试。
- [x] `ReaderLayoutRange` 模型测试。
- [x] `ReaderPagedSliceLayoutAdapter` 测试。
- [x] `ReaderLayoutHitTestService` 测试。
- [x] `ReaderLayoutRangeService` 测试。
- [x] `ReaderLayoutFallbackRunner` 测试。

### P6.2 Widget / Smoke

- [ ] 文本分页默认 legacy smoke。
- [ ] 文本滚动默认 legacy smoke。
- [ ] 漫画 surface smoke。
- [ ] PDF 缺文件 smoke。
- [ ] 音频错误态 smoke。
- [ ] reader diagnostics 包含 layout mode smoke。

### P6.3 性能检查

- [ ] adapterOnly 模式下分页后额外耗时记录。
- [ ] 超长章节 adapter 耗时记录。
- [ ] 超长段落 adapter 耗时记录。
- [ ] adapter 不产生明显内存尖峰。
- [ ] legacy 模式无额外开销。

### P6.4 手工验收

- [ ] 打开普通文本书籍。
- [ ] 翻页、跨章节、返回、重新进入。
- [ ] 打开漫画章节。
- [ ] 打开 PDF 章节。
- [ ] 打开音频章节。
- [ ] 切换字体大小。
- [ ] 长按选择仍可用。
- [ ] 关闭 debug flag 后行为恢复 legacy。

### P6.5 文档更新

- [x] 更新本文档每阶段进度。
- [x] 更新 roadmap 中 V1 完成状态。
- [x] 记录 V1 遗留问题。
- [x] 明确 V2 入口任务。

### P6 验收

- [ ] 全量 `flutter analyze` 通过。
- [x] 新增文件定向 `flutter analyze` 通过。
- [x] P1-P5 新增单测通过。
- [x] V2-P0-P3 新增单测通过。
- [ ] 关键 reader 测试通过。
- [ ] 默认 legacy 行为不变。
- [x] adapterOnly 可观测、可关闭、可 fallback。

---

## 11. V1 任务顺序建议

建议按下面顺序开工：

- [ ] 1. 完成 P0 样本与行为基线。
- [x] 2. 实现 P1 `ReaderSurfacePosition`。
- [x] 3. 实现 P2 layout model。
- [x] 4. 实现 P3 旧分页 adapter。
- [x] 5. 实现 P4 工具服务。
- [x] 6. 实现 P5 feature flag 和 diagnostics。
- [ ] 7. 完成 P6 手工 smoke 与样本验收。

并行策略：

- [ ] P0 样本准备可与 P1 模型定义并行。
- [ ] P2 layout model 完成前不要启动 P3。
- [ ] P3 adapter 完成前不要接 P5。
- [ ] P4 可以在 P3 后半段并行。
- [ ] P6 从 P1 开始随阶段补，不要最后集中补。

---

## 12. V1 风险清单

- [ ] 风险：模型抽象过大，导致 V1 迟迟不能落地。控制：V1 只做最小字段。
- [ ] 风险：adapter 伪 line/column 被误认为最终排版。控制：命名和注释明确 fallback。
- [ ] 风险：新 position 与旧 progress 双写不一致。控制：只做 mapper，默认仍写旧字段。
- [ ] 风险：feature flag 泄漏到正式用户。控制：默认 legacy，不接远程开关。
- [ ] 风险：测试样本缺真实复杂书。控制：P0 明确样本清单。
- [ ] 风险：又把新状态塞进 `_ReaderPageState`。控制：新增 runtime/model 文件，不新增主页面字段，必要时先放 adapter local。

---

## 13. V1 完成定义

V1 完成必须同时满足：

- [x] 有 `ReaderSurfacePosition`，并能从旧 progress 映射。
- [x] 有 `ReaderLayoutPage / Line / Column / Position / Range`。
- [x] 有旧 `ReaderPagedSlice` 到 layout page 的 adapter。
- [x] 有 hitTest/rangeToRects 的最小工具服务。
- [x] 有 feature flag，默认 legacy。
- [x] adapterOnly 模式失败不影响阅读。
- [ ] 有对应单测和 smoke。
- [ ] 文档进度更新到 100%。

---

## 14. V2 预告

V1 完成后，V2 才建议做：

- [x] 已创建 V2 执行计划：`reader-core-modernization-v2-execution-plan-2026-06-20.md`。
- [ ] 真正的 `ReaderLayoutEngine`。
- [ ] 增量分页流。
- [ ] Layout cache。
- [ ] Selection/bookmark/search/read-aloud anchor 迁移。
- [ ] `ReaderDocument v2` 设计和 parser 输出升级。
- [ ] PageFactory / PageTurnDelegate 第一版。
