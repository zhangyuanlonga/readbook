# 阅读器核心改造 V5 执行计划：多 Surface 进度语义

**日期**: 2026-06-20
**状态**: 已完成 alpha
**进度**: 90%
**目标**: 把文本、漫画、PDF、音频和 EPUB 混排内容的进度/定位语义拆开，形成 V6 正式切换前可长期保留的兼容层。

---

## 阶段 0：边界确认

- [x] 确认 V5 不默认替换正式文本阅读器。
- [x] 确认旧阅读器回滚保留到 V6/V7。
- [x] 确认现有 `ReadingProgress.positionSnapshot` 可承载 V5，不新增持久化表。
- [x] 确认现有 `ReaderSurfacePosition` 是 V5 runtime 的基础模型。

## 阶段 1：Surface Runtime

- [x] 新增 `ReaderSurfacePositionRuntime`。
- [x] 从 `ReaderViewportState` + audio/pdf 状态生成 `ReaderSurfacePosition`。
- [x] 从旧 `ReaderPositionSnapshot` 恢复 typed surface position。
- [x] 输出多 surface diagnostics。
- [x] 提供 restore plan，避免页面层直接解析 snapshot。

## 阶段 2：进度保存接入

- [x] `ReaderProgressCommitController` 改为通过 surface runtime 写 snapshot。
- [x] 文本 paged/scroll 继续兼容旧字段。
- [x] 漫画 paged/continuous 保存为 image surface。
- [x] PDF 保存为 document surface。
- [x] 音频保存 position/duration/speed。

## 阶段 3：页面运行态拆分

- [x] 拆分漫画页码和 PDF 文档页码。
- [x] PDF 初始页从 document restore plan 恢复。
- [x] 漫画初始页从 image restore plan 恢复。
- [x] 阅读记录百分比继续使用 surface runtime 计算出的 ratio。

## 阶段 4：EPUB 混排 Payload

- [x] 新增 image/link/footnote/caption payload 模型。
- [x] layout image column 写入 image payload。
- [x] 文本类 block 写入 caption/footnote payload。
- [x] 不重写 EPUB/HTML parser，仅提供后续 parser 可写入的稳定 payload。

## 阶段 5：Smoke 和回归

- [x] 新增 surface runtime 单测。
- [x] 新增 progress commit 多 surface 单测。
- [x] 新增 EPUB mixed payload 单测。
- [x] 定向 `flutter analyze` 通过。
- [x] 定向 `flutter test` 通过。

## 阶段 6：文档收尾

- [x] 更新 V5 节点文档状态和进度。
- [x] 更新 V 节点总览。
- [x] 更新核心路线图。
- [x] 标记进入 V6 的剩余条件。

---

## Alpha 验证记录

- [x] `flutter analyze` 定向检查通过。
- [x] `flutter test` 运行 V5 新增/受影响测试通过。
- [x] 额外 smoke 覆盖 content mode、mode resolver、reader rendering memory。
- [x] 仅出现既有 `device_info_plus` Swift Package Manager warning。
