# 阅读器核心改造 V2：新 Layout Engine 可运行

**日期**: 2026-06-20
**状态**: 已完成主体
**进度**: 78%
**用户效果**: 默认用户仍无感；debug/dev 能观察新 layout engine 的输出。

---

## 1. 目标效果

V2 要把 V1 的模型底座推进成可运行的新排版内核，但仍不默认替换正式阅读器。

- [x] 新 layout request/spec/result 成型。
- [x] alpha engine 能把文本、标题、图片占位排成 layout pages。
- [x] stream controller 能先发 current/nearby，再发 complete。
- [x] layout cache 可用。
- [x] 中文排版策略第一版可测。
- [x] debug/dev renderer 准备组件可打开。
- [x] diagnostics 能以 context map 形式接入 UI 或日志。

---

## 2. 必须完成项

- [x] `ReaderLayoutRequest`。
- [x] `ReaderLayoutSpec` 和 signature。
- [x] `ReaderLayoutEngine` alpha。
- [x] `ReaderLayoutStreamController`。
- [x] `ReaderLayoutDiagnosticsPresenter`。
- [x] `ReaderLayoutCacheService`。
- [x] `ReaderZhLayoutPolicy`。
- [x] 公开短 TXT fixture。
- [x] debug/dev 入口准备组件。
- [ ] 真实样本 smoke。

---

## 3. 不做项

- [x] 不默认切换新 renderer。
- [x] 不删除旧 `ReaderPaginationEngine`。
- [x] 不完成全部 EPUB 混排。
- [x] 不重写漫画/PDF/音频 UI。

---

## 4. 验收标准

- [x] V2-P0/P1/P2/P3 单测通过。
- [x] layout cache hit/miss/失效测试通过。
- [x] 中文标点 fixture 测试通过。
- [x] debug/dev 可观察 layout diagnostics。
- [ ] 普通 TXT 在 debug 新 renderer 下可读。
- [x] engine 失败可 fallback 到 legacy。
- [x] 新增/修改文件定向 `flutter analyze` 通过。

---

## 5. 关联文档

- `reader-core-modernization-v2-execution-plan-2026-06-20.md`
- `reader-core-modernization-v1-exit-report-2026-06-20.md`
