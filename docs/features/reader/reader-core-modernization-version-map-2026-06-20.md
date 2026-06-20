# 阅读器核心改造 V 节点总览

**日期**: 2026-06-20
**目的**: 用 V1-V6 大节点追踪最终效果，细任务只放在对应 V 节点执行文档中。

---

## 1. 节点总览

| 节点 | 目标效果 | 状态 | 进度 | 主文档 |
|---|---|---:|---:|---|
| V1 | 底座完成 | 代码侧收尾 | 90% | `reader-core-modernization-v1-foundation-node-2026-06-20.md` |
| V2 | 新 Layout Engine 可运行 | 已完成主体 | 78% | `reader-core-modernization-v2-layout-engine-node-2026-06-20.md` |
| V3 | 新文本阅读器灰度可用 | 已完成 alpha | 90% | `reader-core-modernization-v3-renderer-node-2026-06-20.md` |
| V4 | 交互闭环 | 已完成 alpha | 90% | `reader-core-modernization-v4-interaction-node-2026-06-20.md` |
| V5 | 多内容 Surface 完整 | 已完成 alpha | 90% | `reader-core-modernization-v5-surface-node-2026-06-20.md` |
| V6 | 正式替换与质量打磨 | 代码 alpha 完成 | 78% | `reader-core-modernization-v6-release-node-2026-06-20.md` |

---

## 2. 主线判断

- [x] V1 已建立新内核语言，不改变现有 UI。
- [x] V2 已完成 alpha engine、layout request/spec、stream controller、cache、中文策略和 renderer 准备组件。
- [x] V3 才是第一个用户可感知节点：debug/dev 可打开新文本阅读器。
- [x] V4 让新阅读器真正可用：选择、标注、书签、搜索、朗读共享 layout position。
- [x] V5 补齐文本以外的内容形态：漫画、PDF、音频、EPUB 混排。
- [x] V6 已完成 text+paged 默认切换代码 alpha，并把旧阅读器保留为 fallback。
- [ ] V6 仍需补齐 TF 样本 smoke、profile 性能和外部邀请反馈记录。

---

## 3. 文档规则

- [x] 主文档只追踪 V 节点，不再用大量 P 阶段作为主进度。
- [x] 每个 V 节点文档只保留目标效果、必须完成项、不做项、验收标准、当前进度。
- [x] 细任务可继续在执行计划文档里拆分，但不再影响主线阅读。
- [x] 每个 V 完成时同步更新本总览、路线图和对应 V 节点文档。

---

## 4. 当前下一步

- [x] V2-P4：补 layout cache。
- [x] V2-P5：补中文排版策略和公开标点 fixture。
- [x] V2-P6：准备 debug/dev 版 `ReaderLayoutPagedView`。
- [x] V2-P7：补 diagnostics UI、样本 smoke 和性能基线。
- [x] V3：完成新 layout renderer alpha preview surface。
- [x] V4：完成选择、标注、搜索、朗读锚点统一 alpha。
- [x] V5：完成多 surface 语义拆分和进度统一 alpha。
- [x] V6：新阅读器正式入口灰度、质量门禁和旧阅读器隐藏回滚代码 alpha。
- [ ] V6：补齐样本 smoke、profile 性能和 TF 外部反馈闭环。
