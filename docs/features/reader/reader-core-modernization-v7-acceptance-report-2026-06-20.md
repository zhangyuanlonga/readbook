# 阅读器核心改造 V7 P8 验收报告

**日期**: 2026-06-20  
**范围**: V7 P0-P7 已落地内容、阅读器专项 analyze/test、`docs/test_readr` 本地样本 smoke  
**结论**: 阅读器专项门禁通过；旧阅读器 fallback 已移除；发布前仍需补 profile 和版本回滚演练。

---

## 1. 验收总览

| 门禁 | 结果 | 记录 |
|---|---|---|
| 全项目 `flutter analyze` | 未通过 | 阻塞在 `test/features/mine/presentation/advanced_theme_editor_sections_test.dart` 两处缺少必填 `onChanged`，非阅读器范围 |
| 阅读器范围 analyze | 通过 | `flutter analyze lib/features/reader test/features/reader` 无 issues |
| reader application tests | 通过 | `flutter test test/features/reader/application`，576 tests passed |
| reader presentation tests | 通过 | `flutter test test/features/reader/presentation`，186 tests passed |
| 本地 TXT/EPUB parser tests | 通过 | `txt_local_book_parser_test.dart` + `epub_local_book_parser_test.dart`，35 tests passed |
| `docs/test_readr` 样本 smoke | 通过 | 文件类型、尺寸、行数、EPUB zip 完整性和结构统计通过 |
| profile mode 性能记录 | 未执行 | 需要真机或目标设备 profile/run 验收 |
| 版本回滚演练 | 未执行 | 旧 dart-define 回滚开关已删除，外部发布前需确认上一稳定版本/提交可回退 |

---

## 2. 本次发现并修正的测试问题

- [x] `ReaderLayoutRendererPreviewSurface` 测试改用 `find.text(..., findRichText: true)`，匹配 release layout 当前通过 `RichText` 绘制正文的实现。
- [x] `resolveReaderTextBlockPresentation` 测试更新段后距断言，跟随 `ReaderTypographyMetricsResolver` 的真实排版指标。
- [x] 修正后 presentation 整包复跑通过。

---

## 3. 样本 Smoke 记录

| 样本 | 类型 | 规模 | Smoke 结论 |
|---|---|---:|---|
| `《漫画万人嫌自救指南》作者：奶茶只喝微糖.txt` | UTF-8 with BOM, CRLF | 3,724,610 bytes / 32,009 lines | 文件识别正常，适合作为 BOM + 长中文 TXT 样本 |
| `【番20】《我在废土世界扫垃圾》作者：有花在野 (1).txt` | UTF-8, CRLF | 7,406,776 bytes / 61,627 lines | 文件识别正常，适合作为特殊文件名 + 长中文 TXT 样本 |
| `斗破苍穹(天蚕土豆).epub` | EPUB | 8,825,090 bytes / 1,679 zip entries | `unzip -t` 无压缩错误；含 1,674 个 html/xhtml 条目和 1 个图片条目 |

说明：

- [x] 本报告只登记样本元信息，不摘录真实书籍正文。
- [x] 当前 smoke 证明样本文件可被系统工具识别且 EPUB 压缩结构完整。
- [ ] 尚未完成真机 UI 打开、翻页、设置变化、退出重进恢复的手工记录。

---

## 4. V7 功能等价结论

- [x] P0 功能矩阵、单路径原则和版本回滚策略已文档化。
- [x] P1-P7 的核心代码路径已有 reader application/presentation 单测覆盖。
- [x] renderer authority 已明确，release active 只信 release page count。
- [x] 旧翻页动画已迁入 release animation surface，不再回落旧 renderer。
- [x] selection active gate、annotation 样式、settings signature、混排 payload、anchor readiness 已进入可复跑测试。
- [x] paperCurl/curl/cover/translate/fade/vertical 的 release 原生动画已迁移完成。
- [ ] 搜索高亮/目录搜索跳转、自动阅读跨章仍需 UI 或端到端验收。
- [ ] 图片点击、重试、真实尺寸更新策略仍未完整接入 release renderer。

---

## 5. 发布前剩余门禁

- [ ] 修复或隔离 `mine` 高级主题编辑器测试后，让全项目 `flutter analyze` 通过。
- [ ] 在目标设备执行 profile mode：首屏进入、连续翻页、设置变化重排、release failure 诊断。
- [ ] 用 `docs/test_readr` 三个样本做手工 UI 验收，并补首次打开耗时、章节识别、分页数量、设置重排、退出恢复记录。
- [ ] 做一次版本/提交回滚演练，确认外部发布前可退回上一稳定包。
- [x] release 原生动画迁移优先级已执行：paperCurl/curl、cover/translate/fade/vertical 已接入。
