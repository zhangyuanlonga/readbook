# 阅读器核心改造 V3：新文本阅读器灰度可用

**日期**: 2026-06-20
**状态**: 未开始
**进度**: 0%
**用户效果**: debug/dev 可切到新文本阅读器，能读普通 TXT/EPUB 文本章节。

---

## 1. 目标效果

V3 是第一个用户可感知节点。目标是在不影响正式用户的前提下，让新 layout renderer 可以真实阅读普通文本章节。

- [ ] 新 `ReaderLayoutPagedView` 可显示文本章节。
- [ ] 新 renderer 使用 `ReaderLayoutPage`，不再直接依赖旧 slice。
- [ ] 翻页、返回、重新进入能恢复大致位置。
- [ ] 字号、行距、边距变化后可重新 layout。
- [ ] debug/dev 开关可关闭并回到旧 renderer。
- [ ] 普通 TXT/EPUB 文本 smoke 通过。

---

## 2. 必须完成项

- [ ] 新建 `ReaderLayoutPagedView`。
- [ ] 新建 `ReaderLayoutTextPainter` 或 painter adapter。
- [ ] 接入 `ReaderLayoutStreamController`。
- [ ] 接入 `ReaderLayoutEngineMode` debug/dev 开关。
- [ ] 接入 layout diagnostics 展示或日志。
- [ ] 支持 annotation highlight 的只读绘制。
- [ ] 支持基础图片占位。
- [ ] 支持 renderer fallback 到旧 `ReaderTextPagedView`。

---

## 3. 不做项

- [ ] 不默认开放给正式用户。
- [ ] 不一次性迁移所有 selection/annotation 业务。
- [ ] 不强行完成 EPUB 全混排。
- [ ] 不重写漫画/PDF/音频。

---

## 4. 验收标准

- [ ] debug/dev 可打开新文本 renderer。
- [ ] 普通 TXT 可读、可翻页、可返回恢复。
- [ ] 普通 EPUB 文本章节可读。
- [ ] 切换字号/行距/边距后不崩溃。
- [ ] layout engine 失败能自动 fallback。
- [ ] 旧 renderer 仍可关闭新功能后使用。

---

## 5. V3 完成后进入 V4 的条件

- [ ] 新 renderer 已能稳定展示普通文本。
- [ ] layout position 和视觉坐标基本一致。
- [ ] diagnostics 能定位 layout/render/fallback 问题。
