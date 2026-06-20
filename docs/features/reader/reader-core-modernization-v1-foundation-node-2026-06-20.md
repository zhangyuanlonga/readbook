# 阅读器核心改造 V1：底座完成

**日期**: 2026-06-20
**状态**: 代码侧收尾
**进度**: 90%
**用户效果**: 默认阅读器体验不变，新内核底座进入代码仓库。

---

## 1. 目标效果

V1 的目标不是让用户看到新阅读器，而是让后续改造拥有统一语言和回退底座。

- [x] 文本、漫画、PDF、音频的进度语义可以区分。
- [x] 文本 layout 有 page/line/column/position/range 模型。
- [x] 旧分页结果可以转换成新 layout model。
- [x] hit-test 和 range-to-rects 有纯 Dart 服务。
- [x] 新 layout 构建有 legacy/adapterOnly/fallback 模式。
- [x] 默认路径仍然是旧阅读器。

---

## 2. 已完成

- [x] `ReaderSurfacePosition`。
- [x] `ReaderLayoutPage / Line / Column / Position / Range`。
- [x] `ReaderPagedSliceLayoutAdapter`。
- [x] `ReaderLayoutHitTestService`。
- [x] `ReaderLayoutRangeService`。
- [x] `ReaderLayoutEngineMode`。
- [x] `ReaderLayoutFallbackRunner`。
- [x] P1-P5 定向单测通过。
- [x] V1 出口报告：`reader-core-modernization-v1-exit-report-2026-06-20.md`。

---

## 3. 不做项

- [x] 不替换 `reader_page.dart`。
- [x] 不替换正式文本 renderer。
- [x] 不重写漫画/PDF/音频 UI。
- [x] 不迁移历史 progress。
- [x] 不删除旧 pagination engine。

---

## 4. 遗留项

- [ ] 真实样本手工行为记录仍需补齐。
- [ ] debug UI diagnostics 入口转入 V2-P0。
- [ ] `_mangaPageIndex` 等历史 runtime 字段转入 V5 语义拆分。
- [ ] 新 layout model 尚未驱动正式渲染。

---

## 5. 验收标准

- [x] 新底座代码存在且可测。
- [x] 默认旧阅读器路径不变。
- [x] adapterOnly 失败不会影响阅读器。
- [x] 文档和出口报告已更新。
- [ ] 手工样本记录完成后，可把 V1 从 90% 调整为 100%。
