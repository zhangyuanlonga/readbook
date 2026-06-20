# 阅读器核心改造 V5：多内容 Surface 完整

**日期**: 2026-06-20
**状态**: 已完成 alpha
**进度**: 90%
**用户效果**: 文本、漫画、PDF、音频的进度和阅读体验语义一致，不再用临时字段互相顶替。

---

## 1. 目标效果

V5 解决阅读器多内容形态的长期债务，让不同 surface 有独立 runtime，又能共享统一进度表达。

- [x] 文本 surface 使用 layout position 或 text viewport position。
- [x] 漫画 surface 使用 image position。
- [x] PDF surface 使用 document position。
- [x] 音频 surface 使用 audio position。
- [x] EPUB 混排图片、链接、脚注、caption 有明确 payload。
- [x] 多 surface 之间的进度保存和恢复互不污染。
- [x] V5 执行计划：`reader-core-modernization-v5-execution-plan-2026-06-20.md`。

---

## 2. 必须完成项

- [x] `ReaderSurfacePositionRuntime`。
- [x] 拆分 `_mangaPageIndex` 等历史混用字段，至少 PDF 不再复用漫画页码。
- [x] 漫画连续滚动/分页进度恢复。
- [x] PDF page/zoom/pan 恢复。
- [x] 音频 position/duration/speed 恢复。
- [x] EPUB image/link/footnote/caption 基础 payload。
- [x] 多 surface diagnostics。
- [x] 多 surface smoke。

---

## 3. 不做项

- [x] 不一次性重写所有 parser。
- [x] 不把 PDF viewer 内核替换为自研。
- [x] 不把音频播放和 TTS 强行合并。

---

## 4. 验收标准

- [x] 漫画分页和连续滚动恢复准确。
- [x] PDF 页码、缩放、平移恢复准确。
- [x] 音频进度和倍速恢复准确。
- [x] EPUB 图片不会破坏文本 layout。
- [x] 文本、漫画、PDF、音频 progress 字段互不混用。
- [x] source switch 后文本进度迁移仍可用。

---

## 5. V5 完成后进入 V6 的条件

- [x] 多 surface 进度语义清晰。
- [x] 文本以外主要阅读模式有 smoke。
- [x] 新旧 progress 兼容策略可长期保留或迁移。

---

## 6. 当前执行备注

- [x] V5 不负责把新版文本 renderer 默认切到正式入口；该动作放到 V6。
- [x] V5 不删除旧阅读器回滚；只让新旧路径共享稳定的 surface progress 兼容层。
- [x] V5 优先保证进度保存、恢复和 diagnostics 语义，不重写 PDF/manga/audio viewer 内核。

---

## 7. Alpha 落地记录

- [x] 新增 `ReaderSurfacePositionRuntime`，统一 capture/restore/snapshot/diagnostics。
- [x] `ReaderProgressCommitController` 改为通过 runtime 生成 position snapshot。
- [x] `ReaderViewportState` 支持 document zoom/pan 和 audio position/duration/speed。
- [x] `ReaderPdfView` 回传 page/zoom/pan，并支持通过 `goToPosition` 恢复初始 zoom/pan。
- [x] `ReaderPage` 拆分 `_imagePageIndex`、`_documentPageIndex` 和 document zoom/pan 状态。
- [x] 新增 `ReaderMixedContentPayload`，并让 layout block/column 支持 image/link/footnote/caption payload。
- [x] 新增/更新 runtime、progress commit、layout request、layout engine smoke 测试。
