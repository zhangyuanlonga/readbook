# 阅读器核心改造 V3：新文本阅读器灰度可用

**日期**: 2026-06-20
**状态**: 已完成 alpha，默认仍关闭
**进度**: 90%
**用户效果**: debug/dev 可切到新文本阅读器，能读普通 TXT/EPUB 文本章节。

---

## 1. 目标效果

V3 是第一个用户可感知节点。目标是在不影响正式用户的前提下，让新 layout renderer 可以真实阅读普通文本章节。

- [x] 新 `ReaderLayoutPagedView` 可显示文本章节。
- [x] 新 renderer 使用 `ReaderLayoutPage`，不再直接依赖旧 slice。
- [x] 翻页、返回、重新进入能按 `targetRatio` / `initialPageIndex` 恢复大致位置。
- [x] 字号、行距、边距变化后可通过 layout signature 重新 layout。
- [x] debug/dev 开关可关闭并回到旧 renderer。
- [x] 普通 TXT 与 EPUB-like 图文 block smoke 通过。

---

## 2. 必须完成项

- [x] 新建并升级 `ReaderLayoutPagedView`，支持 `PageView` 翻页。
- [x] 新建 `ReaderLayoutTextPainter` painter adapter。
- [x] 接入 `ReaderLayoutStreamController`。
- [x] 接入 `ReaderLayoutEngineMode` debug/dev 开关。
- [x] 接入 layout diagnostics 展示或日志回调。
- [x] 支持 annotation highlight 的只读绘制。
- [x] 支持基础图片占位。
- [x] 支持 renderer fallback 到旧 `ReaderTextPagedView` builder。

---

## 3. 不做项

- [x] 不默认开放给正式用户。
- [x] 不一次性迁移所有 selection/annotation 业务。
- [x] 不强行完成 EPUB 全混排。
- [x] 不重写漫画/PDF/音频。

---

## 4. 验收标准

- [x] debug/dev 可通过 `ReaderLayoutRendererPreviewSurface` 打开新文本 renderer。
- [x] 普通 TXT 可读、可翻页、可返回恢复。
- [x] 普通 EPUB-like 文本/图片 block 可读。
- [x] 切换字号/行距/边距后可触发新 signature，不复用旧 cache。
- [x] layout engine 失败能自动 fallback。
- [x] 旧 renderer 仍可关闭新功能后使用。

---

## 5. V3 完成后进入 V4 的条件

- [x] 新 renderer 已能稳定展示普通文本。
- [x] layout position 和视觉坐标在 line/column 级别基本一致。
- [x] diagnostics 能定位 layout/render/fallback 问题。

---

## 6. 落地文件

- [x] `ReaderLayoutRendererController`: 负责 legacy/experimental/cache/stream/fallback 状态流。
- [x] `ReaderLayoutRendererPreviewSurface`: 负责 debug/dev preview 与旧 renderer fallback builder。
- [x] `ReaderLayoutPagedView`: 负责 `ReaderLayoutPage` 翻页渲染、图片占位和只读高亮。
- [x] `ReaderLayoutTextPainter`: 负责按 fragment 绘制文本与高亮背景。
- [x] `reader_layout_renderer_controller_test.dart`: 覆盖 legacy、experimental、cache、EPUB-like、fallback。
- [x] `reader_layout_renderer_preview_surface_test.dart`: 覆盖 preview 打开与失败回退。

---

## 7. 剩余边界

- [ ] 尚未把新 renderer 默认接入正式 `ReaderPage`，需要 V4/V6 完成交互和灰度策略后再切。
- [ ] selection/annotation 编辑仍走旧阅读器路径，V3 只做只读高亮绘制。
- [ ] 真实 EPUB 样本手工 smoke 需在接主阅读页前补一次设备侧记录。
