# 阅读器核心改造 V5：多内容 Surface 完整

**日期**: 2026-06-20
**状态**: 未开始
**进度**: 0%
**用户效果**: 文本、漫画、PDF、音频的进度和阅读体验语义一致，不再用临时字段互相顶替。

---

## 1. 目标效果

V5 解决阅读器多内容形态的长期债务，让不同 surface 有独立 runtime，又能共享统一进度表达。

- [ ] 文本 surface 使用 layout position。
- [ ] 漫画 surface 使用 image position。
- [ ] PDF surface 使用 document position。
- [ ] 音频 surface 使用 audio position。
- [ ] EPUB 混排图片和链接有明确 payload。
- [ ] 多 surface 之间的进度保存和恢复互不污染。

---

## 2. 必须完成项

- [ ] `ReaderSurfacePositionRuntime`。
- [ ] 拆分 `_mangaPageIndex` 等历史混用字段。
- [ ] 漫画连续滚动/分页进度恢复。
- [ ] PDF page/zoom/pan 恢复。
- [ ] 音频 position/duration/speed 恢复。
- [ ] EPUB image/link/footnote/caption 基础 payload。
- [ ] 多 surface diagnostics。
- [ ] 多 surface smoke。

---

## 3. 不做项

- [ ] 不一次性重写所有 parser。
- [ ] 不把 PDF viewer 内核替换为自研。
- [ ] 不把音频播放和 TTS 强行合并。

---

## 4. 验收标准

- [ ] 漫画分页和连续滚动恢复准确。
- [ ] PDF 页码、缩放、平移恢复准确。
- [ ] 音频进度和倍速恢复准确。
- [ ] EPUB 图片不会破坏文本 layout。
- [ ] 文本、漫画、PDF、音频 progress 字段互不混用。
- [ ] source switch 后文本进度迁移仍可用。

---

## 5. V5 完成后进入 V6 的条件

- [ ] 多 surface 进度语义清晰。
- [ ] 文本以外主要阅读模式有 smoke。
- [ ] 新旧 progress 兼容策略可长期保留或迁移。
