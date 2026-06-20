# 阅读器核心改造 V1 出口报告

**日期**: 2026-06-20
**范围**: V1 底座代码侧收口，不代表主阅读器 UI 已切换到新 layout engine。

---

## 1. 已完成

- [x] 建立 `ReaderSurfacePosition`，区分 text/image/document/audio 进度语义。
- [x] 建立 `ReaderLayoutPage / Line / Column / Position / Range` 第一版。
- [x] 建立旧 `ReaderPagedSlice` 到新 layout page 的 adapter。
- [x] 建立 `ReaderLayoutHitTestService`。
- [x] 建立 `ReaderLayoutRangeService`。
- [x] 建立 `ReaderLayoutEngineMode` 和 `ReaderLayoutFallbackRunner`。
- [x] 默认 legacy 路径不构建新 layout。
- [x] adapterOnly 构建失败时返回 legacy fallback 结果，不向 UI 抛出错误。
- [x] P1-P5 新增单测覆盖通过。

---

## 2. 未完成但已明确留项

- [ ] `docs/test_readr/` 真实样本的手工行为记录仍未完成。
- [ ] 漫画、PDF、音频、公开短 fixture 样本仍需补齐。
- [ ] `ReaderLayoutEngineMode` 尚未接入 reader debug 设置面板。
- [ ] reader diagnostics 尚未在 UI/日志链路集中展示。
- [ ] `ReaderPage` 仍未拆出 `ReaderSurfacePositionRuntime`。
- [ ] 旧 `_mangaPageIndex` 仍需在 V2/V3 中继续语义拆分。
- [ ] 新 layout model 仍未驱动正式渲染。

---

## 3. V1 结论

- [x] V1 已具备启动 V2 的代码底座。
- [x] V1 没有改变现有阅读器默认用户路径。
- [x] V2 可以从真正的 `ReaderLayoutEngine`、layout cache、增量分页流开始。
- [x] V2 已启动 P0-P3：diagnostics service、layout request/spec、layout engine alpha、layout stream controller。
- [ ] V2 正式切 renderer 前，仍要补手工样本基线和 debug UI diagnostics。

---

## 4. V2 入口条件

- [x] layout 基础实体可用。
- [x] hit-test/range 工具可用。
- [x] adapterOnly/fallback 模式可用。
- [x] 新旧 layout 之间已有过渡 adapter。
- [x] 真实样本行为基线待补，不阻塞 V2 设计，但阻塞默认切换。
