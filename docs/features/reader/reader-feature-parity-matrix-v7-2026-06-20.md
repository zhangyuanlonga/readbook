# 阅读器 V7 功能等价矩阵

**日期**: 2026-06-20  
**状态**: V7 P8 已验收，旧阅读器 fallback 已移除
**进度**: 100%
**代码 fixture**: `lib/features/reader/application/reader_feature_parity_matrix.dart`

---

## 1. 发布原则

- [x] 新 renderer 未完整承接的旧功能，不能静默降级成不可用。
- [x] 旧 renderer fallback 已移除，不再作为外部用户包内回滚方案。
- [x] paperCurl/curl/cover/translate/fade/vertical 已由 layout release 明确支持。
- [x] diagnostics 必须记录 release active/reason/requested animation。
- [x] 旧动画能力已迁入 `ReaderPageTurnDelegate` 的 release supported 列表。

---

## 2. V7 0-3 矩阵

| 功能 | 旧阅读器 | 新 renderer | 当前策略 | 当前结论 |
|---|---|---|---|---|
| 普通分页翻页 | 可用 | 可用 | release 可用 | 共用 `ReaderNavigationCommand` 和 page index runtime |
| paperCurl | 可用 | 可用 | release 单路径 | 由 release paper curl surface 承接 |
| curl | 可用 | 可用 | release 单路径 | release transition stack 承接 |
| cover/translate/fade/vertical | 可用 | 可用 | release 单路径 | release 已接 `ReaderPagedAnimationSurface` |
| 跨章节翻页动画 | 可用 | 可用 | release 单路径 | 使用 layout page snapshot，未准备好时新路径降级 |
| 点击分区翻页 | 可用 | 可用 | release 可用 | tap zone -> navigation command |
| 键盘/音量键/滚轮 | 可用 | 可用 | release 可用 | 统一 dispatcher，selection active 拦截 page intent |
| 长按选择 | 可用 | 可用 | release 可用 | layout hit-test -> old selection toolbar |
| 跨页拖拽选择 | 可用 | 部分 | release 可用，继续补强 | 已支持拖出当前页映射相邻 layout page |
| 高亮/加粗/下划线/波浪线 | 可用 | 可用 | release 可用 | annotation range 已承接旧 bookmark 样式字段 |
| 点击已有标注工具条 | 可用 | 部分 | release 单路径 | 直接点击现有标注仍待独立 hit-test |
| 书签恢复 | 可用 | 部分 | release + 通用容错 | layout anchor 优先，chapter offset/snippet 容错保留 |
| 搜索/朗读 anchor | 可用 | 部分 | release readiness | 已有 readiness diagnostics，搜索高亮仍需 UI smoke |
| 自动阅读 | 可用 | 部分 | release readiness | 分页 readiness 已回归，跨章体验继续验收 |
| 设置兼容 | 可用 | 部分 | signature matrix | 字体/行距/边距/字体来源进入签名，shell owned 设置隔离 |
| EPUB/HTML 混排 | 部分 | 部分 | payload policy | title/image/caption/footnote/link payload 已有策略测试 |
| 单路径隔离 | 可用 | 可用 | renderer authority | release active 只信 release page count，failure 清理 release runtime |

---

## 3. 已落地任务

- [x] P0: 建立 `ReaderFeatureParityMatrix` 代码 fixture。
- [x] P0: 文档化旧 fallback 移除后的版本回滚策略。
- [x] P1: 新增 `ReaderPageTurnDelegate`，明确 layout release 支持策略。
- [x] P1: `ReaderLayoutReleasePolicy` 接入 page animation capability gate。
- [x] P1: paperCurl/curl/cover/translate/fade/vertical 由 release transition stack 承接。
- [x] P2: `ReaderNavigationCommandDispatcher` 增加 selection active page-intent gate。
- [x] P2: tap zone、键盘、音量键、滚轮最终共享 navigation command 拦截口。
- [x] P3: `ReaderLayoutTextAnnotationRange` 承接 bold/underline/wavy。
- [x] P3: release annotation ranges 读取旧 bookmark 样式字段。
- [x] P3: `ReaderLayoutPagedView` 增加长按拖动选择更新和相邻页映射。
- [x] P4: 新增 `ReaderLayoutAnchorReadinessPolicy`。
- [x] P4: release diagnostics 输出 search/read-aloud/auto-read anchor readiness。
- [x] P5: 新增 `ReaderLayoutSettingsCompatibilityMatrix` 与 signature 回归测试。
- [x] P6: 新增 `ReaderMixedContentParityPolicy`。
- [x] P7: 新增 `ReaderRendererAuthorityResolver` 并接入 `_currentPagedPageCount`。
- [x] P7: release failure 清空 request/pageCount 并取消 active layout task。

---

## 4. 继续遗留

- [x] P1: 为 layout release 实现 paperCurl/curl page snapshot 动画。
- [x] P1: 为 cover/translate/fade/vertical 接入 release transition stack。
- [x] P1: 跨章节不再只依赖主页面截图，改为 from/to layout page snapshot。
- [ ] P3: 点击已有标注直接唤起旧工具条。
- [ ] P3: 复杂多页拖拽、跨图片/混排行的选择继续补测试。
- [ ] P3: 书签恢复完全切到 layout position 权威源。
- [ ] P4: 搜索命中高亮和目录搜索跳转做 widget/smoke 验收。
- [ ] P4: 自动阅读跨章行为在 release renderer 下做端到端验收。
- [ ] P6: 图片点击、重试、真实尺寸更新策略继续接入 release renderer。
- [ ] P7: profile mode 记录 release 单路径首屏和翻页性能。

---

## 5. P8 验收摘录

完整记录见 `reader-core-modernization-v7-acceptance-report-2026-06-20.md`。

- [x] 阅读器范围 analyze 通过。
- [x] reader application tests 通过，576 tests passed。
- [x] reader presentation tests 通过，186 tests passed。
- [x] TXT/EPUB parser tests 通过，35 tests passed。
- [x] `docs/test_readr` 两个 TXT 和一个 EPUB 完成文件级 smoke。
- [ ] 全项目 `flutter analyze` 被非阅读器 `mine` 测试阻塞。
- [ ] profile mode 和版本回滚演练未执行。
