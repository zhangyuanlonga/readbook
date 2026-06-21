# 阅读器核心改造 V6 执行计划：正式入口、TF 灰度与回滚

**日期**: 2026-06-20
**状态**: 历史计划，已被旧阅读器移除计划 P4-P7 更新
**完成进度**: 100%

---

## P0 发布策略与开关

- [x] 新增 release policy，集中控制正式入口是否启用新 renderer。
- [x] text+paged 已具备进入新 renderer 的正式入口。
- [x] V7 功能等价后，文本阅读正式入口进入新 renderer 单路径。
- [x] 非文本、滚动文本、漫画、PDF/混合文档、音频不切换。
- [x] 旧强制回滚 dart-define 已删除；回滚策略改为版本/提交回退。
- [x] 旧关闭 release path dart-define 已删除；默认包不再切回旧 renderer。
- [x] 支持 `READER_LAYOUT_SHOW_DIAGNOSTICS=true` 显示诊断 overlay。
- [x] 支持 `READER_LAYOUT_MAX_CONTENT_LENGTH` 内容长度保护阈值。

## P1 正式入口接入

- [x] 新增 `ReaderLayoutReleaseSurface`，正式入口不直接依赖 preview 命名。
- [x] `ReaderPage` 的 textPaged viewport 接入 release decision。
- [x] release ready 状态复用现有分页 header/footer/padding。
- [x] release loading 状态复用现有分页 loading 占位。
- [x] release failure 状态显示明确诊断，不再回旧 renderer。
- [x] 旧 `_ensurePagination` 和 streaming pagination 运行态已删除。

## P2 进度与翻页同步

- [x] 新 layout page count 纳入 `_currentPagedPageCount`。
- [x] layout request 首次进入时固定 targetRatio 和 initialPageIndex，避免翻页重复订阅。
- [x] 新 PageView 的 pageChanged 回写 `_pageTurnRuntimeController.currentPageIndex`。
- [x] 外部 tap/键盘翻页通过 pageIndex override 同步新 PageView。
- [x] pageChanged 复用现有 reading record sync 和 progress save。

## P3 选择、标注和诊断

- [x] 新 layout selection snapshot 桥接到现有灵感工具条。
- [x] 长按选择后可复用复制/保存灵感链路。
- [x] 现有书签 highlight 转为 layout annotation range。
- [x] release diagnostics 写入 ReaderPage 诊断上下文。
- [x] 本地图书诊断增加 layout release diagnostic。
- [ ] 跨页拖拽选择追平。
- [ ] underline/wavy 在新 layout annotation painter 中追平。

## P4 自动化验证

- [x] 新增 `reader_layout_release_policy_test.dart`。
- [x] 覆盖默认开启、旧开关已移除、非目标 surface、内容长度阈值、fingerprint 稳定性。
- [x] renderer preview surface 测试覆盖 readyBuilder。
- [x] targeted `flutter analyze` 通过。
- [x] targeted release/surface tests 通过。
- [x] V2-V6 reader core bundle 通过。

## P5 TF 灰度建议

- [x] 当前默认包使用新 renderer 单路径，旧阅读器不再作为包内开关回滚方案。
- [x] 紧急回滚改为回退上一稳定版本/提交。
- [x] 小范围外部邀请可先覆盖本地 TXT、在线章节、EPUB 混排。
- [ ] 若 V7 未完成，只允许把新 renderer 作为小范围灰度/诊断路径。
- [ ] 外部用户反馈模板补充 layout release diagnostic 字段。
- [ ] 崩溃/卡死反馈按样本、机型、章节长度、dart-define 参数归档。

## P6 样本与性能门禁

- [ ] `docs/test_readr` 样本补齐 README 和来源说明。
- [ ] 短篇 TXT smoke。
- [ ] 超长 TXT smoke。
- [ ] 超长段落 TXT smoke。
- [ ] 中文标点样本 smoke。
- [ ] EPUB 简单样本 smoke。
- [ ] EPUB 混排样本 smoke。
- [ ] 漫画/PDF/音频确认未误切新 text renderer。
- [ ] profile mode 首屏耗时记录。
- [ ] profile mode 内存峰值记录。
- [ ] 设置变化重排压力测试记录。

---

## 回滚策略

旧 dart-define 回滚方式已废弃。当前回滚方式是回退上一稳定版本或旧阅读器删除前基线提交。

诊断构建：

```bash
--dart-define=READER_LAYOUT_SHOW_DIAGNOSTICS=true
```

超长内容保护构建示例：

```bash
--dart-define=READER_LAYOUT_MAX_CONTENT_LENGTH=300000
```
