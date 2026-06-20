# 阅读器核心改造 V4：交互闭环

**日期**: 2026-06-20
**状态**: 已完成 alpha，旧交互链路保留
**进度**: 90%
**用户效果**: 新阅读器不只是能看，还能完成选择、标注、书签、搜索、朗读等核心操作。

---

## 1. 目标效果

V4 把业务锚点统一迁移到 layout position，让阅读器核心交互不再各自维护 offset 规则。

- [x] 选择使用 layout hit-test。
- [x] 标注保存 layout range，同时双写旧 offset。
- [x] 书签保存 layout position，同时双写旧 progress/offset。
- [x] 搜索结果能定位到 layout range。
- [x] 自动阅读/朗读能按 layout line 或 block 推进。
- [x] 跨页 range 可恢复和绘制。

---

## 2. 必须完成项

- [x] `ReaderSelectionRuntime`。
- [x] `ReaderAnnotationAnchorMapper`。
- [x] `ReaderBookmarkAnchorMapper`。
- [x] `ReaderSearchAnchorMapper`。
- [x] `ReaderReadAloudAnchorMapper`。
- [x] 跨页 range merge/split。
- [x] layout position 与旧 progress 双写兼容。
- [x] 旧标注/书签兼容读取。

---

## 3. 不做项

- [x] 不在 V4 默认删除旧 selection 链路。
- [x] 不迁移全部历史数据，只做兼容读取和新写入策略。
- [x] 不把漫画/PDF/音频全部纳入文本 selection 规则。

---

## 4. 验收标准

- [x] 长按选择可用：`ReaderLayoutPagedView` 可通过 `ReaderSelectionRuntime` 回调 selection snapshot。
- [x] 复制文本可用：selection snapshot 暴露 `selectedText`。
- [x] 新建、删除、恢复标注可用：annotation mapper 支持 build/remove/restore。
- [x] 书签回跳位置稳定：bookmark mapper 支持旧 offset 到 layout position。
- [x] 搜索结果点击定位稳定：search mapper 输出 layout range、pageIndex、logical position。
- [x] 自动阅读或朗读推进不丢位置：read-aloud mapper 支持 line/block step。
- [x] 跨页选择不崩溃：range segmenter 支持 split/merge。

---

## 5. V4 完成后进入 V5 的条件

- [x] 文本阅读交互闭环在 V4 runtime/mapper 层稳定。
- [x] layout position 已成为新文本业务 runtime 主锚点。
- [x] 旧锚点兼容策略明确。

---

## 6. 落地文件

- [x] `reader_layout_anchor_models.dart`: layout range / position anchor、legacy progress snapshot。
- [x] `reader_layout_range_segmenter.dart`: 跨页 range split/merge 和复制文本提取。
- [x] `reader_selection_runtime.dart`: hit-test 选词、跨点/跨 offset selection、copy text。
- [x] `reader_annotation_anchor_mapper.dart`: 标注 layout range 新写入与旧 offset 读取兼容。
- [x] `reader_bookmark_anchor_mapper.dart`: 书签 layout position 和旧 progress/offset 双写兼容。
- [x] `reader_search_anchor_mapper.dart`: 搜索命中到 layout range/logical position。
- [x] `reader_read_aloud_anchor_mapper.dart`: 朗读/自动阅读按 line/block 推进。
- [x] `ReaderLayoutPagedView`: 可选长按选择回调，不改变默认渲染行为。

---

## 7. 剩余边界

- [ ] 正式 `ReaderPage` 默认仍保留旧 selection/annotation UI 链路，V6 灰度时再切默认入口。
- [ ] selection handles、拖拽手柄 UI 和系统 toolbar 深度替换未在 V4 强切。
- [ ] 漫画/PDF/音频 surface 的进度语义进入 V5 处理。
