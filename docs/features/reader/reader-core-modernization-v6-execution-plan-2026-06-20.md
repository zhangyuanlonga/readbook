# 阅读器核心改造 V6 执行计划：默认切换、TF 灰度与回滚

**日期**: 2026-06-20
**状态**: 代码 alpha 已完成，发布验收继续推进
**完成进度**: 78%

---

## P0 发布策略与开关

- [x] 新增 release policy，集中控制正式入口是否启用新 renderer。
- [x] 默认 text+paged 开启新 renderer。
- [x] 非文本、滚动文本、漫画、PDF/混合文档、音频不切换。
- [x] 支持 `READER_LAYOUT_FORCE_LEGACY=true` 强制旧阅读器。
- [x] 支持 `READER_LAYOUT_ENABLE_RELEASE=false` 关闭 V6 默认切换。
- [x] 支持 `READER_LAYOUT_SHOW_DIAGNOSTICS=true` 显示诊断 overlay。
- [x] 支持 `READER_LAYOUT_MAX_CONTENT_LENGTH` 内容长度保护阈值。

## P1 正式入口接入

- [x] 新增 `ReaderLayoutReleaseSurface`，正式入口不直接依赖 preview 命名。
- [x] `ReaderPage` 的 textPaged viewport 接入 release decision。
- [x] release ready 状态复用现有分页 header/footer/padding。
- [x] release loading 状态复用现有分页 loading 占位。
- [x] release fallback 状态回到旧 renderer。
- [x] 旧 `_ensurePagination` 只在 legacy/fallback 路径触发，避免默认路径重复分页。

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
- [x] 覆盖默认开启、强制 legacy、非目标 surface、内容长度阈值、fingerprint 稳定性。
- [x] renderer preview surface 测试覆盖 readyBuilder。
- [x] targeted `flutter analyze` 通过。
- [x] targeted release/surface tests 通过。
- [x] V2-V6 reader core bundle 通过。

## P5 TF 灰度建议

- [x] TF 首包默认启用新 renderer。
- [x] 同时准备 `READER_LAYOUT_FORCE_LEGACY=true` 紧急回滚包。
- [x] 小范围外部邀请先覆盖本地 TXT、在线章节、EPUB 混排。
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

## 回滚指令

紧急回滚无需删除代码，打包时加入：

```bash
--dart-define=READER_LAYOUT_FORCE_LEGACY=true
```

保守关闭 V6 默认切换：

```bash
--dart-define=READER_LAYOUT_ENABLE_RELEASE=false
```

诊断构建：

```bash
--dart-define=READER_LAYOUT_SHOW_DIAGNOSTICS=true
```

超长内容保护构建示例：

```bash
--dart-define=READER_LAYOUT_MAX_CONTENT_LENGTH=300000
```
