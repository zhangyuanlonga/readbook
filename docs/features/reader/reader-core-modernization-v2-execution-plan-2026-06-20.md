# 阅读器核心改造 V2 执行计划

**日期**: 2026-06-20
**前置**: `reader-core-modernization-v1-execution-plan-2026-06-20.md`
**目标**: 从 V1 的模型和 adapter 底座，推进到真正可灰度的 `ReaderLayoutEngine`、增量分页流、layout cache 和 renderer 接入准备。

---

## 1. V2 总目标

- [x] 建立 `ReaderLayoutRequest / Spec / Result`。
- [x] 建立 `ReaderLayoutEngine` alpha，产出真实 page/line/column。
- [x] 建立增量分页流，优先产出当前页附近页面。
- [ ] 建立 layout cache，支持签名命中、版本失效、内存/磁盘预算。
- [ ] 建立中文排版策略第一版。
- [ ] 建立 reader diagnostics 接入点。
- [ ] 准备 `ReaderLayoutPagedView`，但默认仍不替换旧 renderer。

---

## 2. 总体进度

| 阶段 | 名称 | 状态 | 进度 | 说明 |
|---|---|---:|---:|---|
| V2-P0 | V1 出口补强 | 进行中 | 60% | diagnostics service 与样本边界完成，debug UI/手工记录待补 |
| V2-P1 | Layout Request/Spec | 已完成主体 | 100% | 新 layout 输入 DTO 与 signature 测试完成 |
| V2-P2 | Layout Engine Alpha | 已完成主体 | 85% | 文本/title/image alpha engine 与测试完成，真实 TextPainter 测量待后续 |
| V2-P3 | 增量分页流 | 已完成主体 | 80% | loading/current/nearby/complete/cancel/failed 事件完成 |
| V2-P4 | Layout Cache | 未开始 | 0% | 内存/磁盘缓存与失效策略 |
| V2-P5 | 中文排版策略 | 未开始 | 0% | 避头尾、中英文边界、标点 fixture |
| V2-P6 | Renderer 准备 | 未开始 | 0% | 新 renderer 可灰度但不默认切 |
| V2-P7 | 验收与回退 | 未开始 | 0% | 性能、smoke、fallback、文档 |

**V2 总进度**: 42%

---

## 3. V2-P0：V1 出口补强

- [x] 将 `ReaderLayoutEngineMode` 接入 debug/dev 配置模型。
- [x] reader diagnostics 输出 layout mode、layout page count、adapter elapsed、fallback reason。
- [ ] 补 `docs/test_readr/` 样本手工行为记录。
- [ ] 补公开短 TXT fixture，供 CI 使用。
- [ ] 补漫画/PDF/音频样本路径或替代 fixture。
- [x] 明确真实样本不进入 CI 的边界。

---

## 4. V2-P1：Layout Request / Spec

- [x] 新建 `ReaderLayoutRequest`。
- [x] 新建 `ReaderLayoutSpec`。
- [x] 从 `ReaderPaginationSpec` 映射可复用字段。
- [x] 加入 typography signature：字号、行高、字距、缩进、字体来源、字重。
- [x] 加入 viewport signature：contentWidth/contentHeight/padding/header。
- [x] 加入 content signature：chapterId、document fingerprint、parser version。
- [x] 加入 feature signature：中文排版、图片策略、标题策略。
- [x] DTO 必须 isolate-safe，不包含 `BuildContext`、controller、`TextStyle`。
- [x] 补 spec signature 单测。

---

## 5. V2-P2：ReaderLayoutEngine Alpha

- [x] 新建 `ReaderLayoutEngine`。
- [x] 支持纯文本段落到 `ReaderLayoutPage`。
- [x] 支持 title line flag。
- [x] 支持 paragraph spacing。
- [x] 支持 first-line indent。
- [x] 支持 lineTop/lineBase/lineBottom alpha 计算。
- [x] 支持 column start/end offset 生成。
- [x] 支持 `ReaderLayoutCancellationToken`。
- [x] 支持 `onPageReady` 回调。
- [x] 保留旧 `ReaderPaginationEngine` fallback。
- [x] 补普通段落、长段落、空段落、跨页段落测试。

---

## 6. V2-P3：增量分页流

- [x] 新建 `ReaderLayoutStreamController`。
- [x] 优先计算当前页。
- [x] 然后计算 nearby 页。
- [x] 后台继续补完整章节。
- [x] 设置变化时取消旧 generation。
- [x] 章节切换时可通过 generation 丢弃旧结果。
- [x] 暴露 loading/ready/failed snapshot。
- [x] 与现有 `ReaderStreamingPaginationController` 事件语义对齐。
- [x] 补取消、ready、failed 测试。

---

## 7. V2-P4：Layout Cache

- [ ] 新建或扩展 `ReaderLayoutCacheService`。
- [ ] 缓存 payload 使用 layout pages。
- [ ] key 包含 chapterId + layout signature。
- [ ] value 包含 document fingerprint。
- [ ] 增加 cache version。
- [ ] 内存 LRU 限量。
- [ ] 磁盘缓存限量。
- [ ] layout spec 改变时自动失效。
- [ ] 内容变更时自动失效。
- [ ] 补 hit/miss/失效/版本迁移测试。

---

## 8. V2-P5：中文排版策略

- [ ] 新建 `ReaderZhLayoutPolicy`。
- [ ] 建立中文标点 fixture。
- [ ] 支持避头标点。
- [ ] 支持避尾标点。
- [ ] 支持引号、省略号、破折号、括号基础规则。
- [ ] 支持中英文混排 word boundary。
- [ ] 将 `useZhLayout` 加入 layout signature。
- [ ] 默认先灰度关闭或仅 debug 开启。
- [ ] 补 data test，记录与旧断行差异。

---

## 9. V2-P6：Renderer 准备

- [ ] 新建 `ReaderLayoutPagedView`。
- [ ] 输入 `ReaderLayoutPage` 或 lazy snapshot。
- [ ] 按 line/column 绘制文本。
- [ ] 先支持纯文本，不强行一次性支持全部混排。
- [ ] annotation highlight 使用 layout range rects。
- [ ] hit-test 使用 `ReaderLayoutHitTestService`。
- [ ] 保留旧 `ReaderTextPagedView` fallback。
- [ ] feature flag 默认仍为 legacy renderer。
- [ ] 新 renderer 仅 debug/dev 可打开。

---

## 10. V2-P7：验收与回退

- [ ] `flutter analyze` 通过。
- [x] V2-P0-P3 新增单测通过。
- [ ] 关键 reader 测试通过。
- [ ] 普通 TXT 打开、翻页、跨章节 smoke 通过。
- [ ] 字号/行距/边距变化后重排 smoke 通过。
- [ ] 长段落不卡死 smoke 通过。
- [ ] adapter/layout engine 失败可 fallback。
- [ ] 默认正式路径仍可保持 legacy。
- [ ] 更新 roadmap 和 V2 进度。

---

## 11. V2 不做

- [ ] 不默认替换正式阅读器 renderer。
- [ ] 不重写漫画阅读器。
- [ ] 不重写 PDF viewer。
- [ ] 不一次性完成 EPUB 全混排。
- [ ] 不删除旧分页 engine。
- [ ] 不迁移全部历史 progress。

---

## 12. V2 完成定义

- [ ] 有真实 `ReaderLayoutEngine` alpha。
- [ ] 有增量分页流。
- [ ] 有 layout cache。
- [ ] 有中文排版 data test。
- [ ] 有 debug/dev renderer 灰度入口。
- [ ] 默认正式路径仍可 fallback legacy。
- [ ] V2 文档和 roadmap 更新完成。
