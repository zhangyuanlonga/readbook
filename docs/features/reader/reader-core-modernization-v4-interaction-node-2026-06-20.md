# 阅读器核心改造 V4：交互闭环

**日期**: 2026-06-20
**状态**: 未开始
**进度**: 0%
**用户效果**: 新阅读器不只是能看，还能完成选择、标注、书签、搜索、朗读等核心操作。

---

## 1. 目标效果

V4 把业务锚点统一迁移到 layout position，让阅读器核心交互不再各自维护 offset 规则。

- [ ] 选择使用 layout hit-test。
- [ ] 标注保存 layout range。
- [ ] 书签保存 layout position。
- [ ] 搜索结果能定位到 layout range。
- [ ] 自动阅读/朗读能按 layout line 或 block 推进。
- [ ] 跨页 range 可恢复和绘制。

---

## 2. 必须完成项

- [ ] `ReaderSelectionRuntime`。
- [ ] `ReaderAnnotationAnchorMapper`。
- [ ] `ReaderBookmarkAnchorMapper`。
- [ ] `ReaderSearchAnchorMapper`。
- [ ] `ReaderReadAloudAnchorMapper`。
- [ ] 跨页 range merge/split。
- [ ] layout position 与旧 progress 双写兼容。
- [ ] 旧标注/书签兼容读取。

---

## 3. 不做项

- [ ] 不在 V4 默认删除旧 selection 链路。
- [ ] 不迁移全部历史数据，只做兼容读取和新写入策略。
- [ ] 不把漫画/PDF/音频全部纳入文本 selection 规则。

---

## 4. 验收标准

- [ ] 长按选择可用。
- [ ] 复制文本可用。
- [ ] 新建、删除、恢复标注可用。
- [ ] 书签回跳位置稳定。
- [ ] 搜索结果点击定位稳定。
- [ ] 自动阅读或朗读推进不丢位置。
- [ ] 跨页选择不崩溃。

---

## 5. V4 完成后进入 V5 的条件

- [ ] 文本阅读交互闭环稳定。
- [ ] layout position 已成为文本业务主锚点。
- [ ] 旧锚点兼容策略明确。
