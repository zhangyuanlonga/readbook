# 阅读器 V7 功能等价矩阵

**日期**: 2026-06-20  
**状态**: V7 0-3 首轮已落地  
**进度**: 0-3 阶段约 65%  
**代码 fixture**: `lib/features/reader/application/reader_feature_parity_matrix.dart`

---

## 1. TestFlight 首包原则

- [x] 新 renderer 未完整承接的旧功能，不能静默降级成不可用。
- [x] TestFlight 外部邀请前，旧 renderer fallback 必须保留。
- [x] paperCurl/curl/cover/translate/fade/vertical 尚未由 layout release 明确支持时，直接回落 legacy renderer。
- [x] diagnostics 必须记录 release active/reason/requested animation。
- [ ] 后续再把旧动画逐项迁入 `ReaderPageTurnDelegate` 的 release supported 列表。

---

## 2. V7 0-3 矩阵

| 功能 | 旧阅读器 | 新 renderer | TF 策略 | 当前结论 |
|---|---|---|---|---|
| 普通分页翻页 | 可用 | 可用 | release 可用 | 共用 `ReaderNavigationCommand` 和 page index runtime |
| paperCurl | 可用 | 部分 | legacy fallback | 不再在 release 下触发 `paperCurlUnavailable` |
| curl | 可用 | 部分 | legacy fallback | 旧 curl transition 仍由 legacy page stack 承接 |
| cover/translate/fade/vertical | 可用 | 部分 | legacy fallback | release 尚未接 `ReaderPagedAnimationSurface` |
| 跨章节翻页动画 | 可用 | 部分 | legacy fallback | 后续需要 layout page snapshot source |
| 点击分区翻页 | 可用 | 可用 | release 可用 | tap zone -> navigation command |
| 键盘/音量键/滚轮 | 可用 | 可用 | release 可用 | 统一 dispatcher，selection active 拦截 page intent |
| 长按选择 | 可用 | 可用 | release 可用 | layout hit-test -> old selection toolbar |
| 跨页拖拽选择 | 可用 | 部分 | release 可用，继续补强 | 已支持拖出当前页映射相邻 layout page |
| 高亮/加粗/下划线/波浪线 | 可用 | 可用 | release 可用 | annotation range 已承接旧 bookmark 样式字段 |
| 点击已有标注工具条 | 可用 | 部分 | legacy fallback/长按恢复 | 直接点击现有标注仍待独立 hit-test |
| 书签恢复 | 可用 | 部分 | release + fallback | layout anchor 优先，chapter offset/snippet fallback 保留 |

---

## 3. 已落地任务

- [x] P0: 建立 `ReaderFeatureParityMatrix` 代码 fixture。
- [x] P0: 文档化 TestFlight 首包必须保留 legacy fallback。
- [x] P1: 新增 `ReaderPageTurnDelegate`，明确 layout release 支持/回落策略。
- [x] P1: `ReaderLayoutReleasePolicy` 接入 page animation capability gate。
- [x] P1: paperCurl/curl/cover/translate/fade/vertical 在 release 未支持前回落 legacy。
- [x] P2: `ReaderNavigationCommandDispatcher` 增加 selection active page-intent gate。
- [x] P2: tap zone、键盘、音量键、滚轮最终共享 navigation command 拦截口。
- [x] P3: `ReaderLayoutTextAnnotationRange` 承接 bold/underline/wavy。
- [x] P3: release annotation ranges 读取旧 bookmark 样式字段。
- [x] P3: `ReaderLayoutPagedView` 增加长按拖动选择更新和相邻页映射。

---

## 4. 继续遗留

- [ ] P1: 为 layout release 真正实现 paperCurl/curl page snapshot 动画。
- [ ] P1: 为 cover/translate/fade/vertical 接入 release transition stack。
- [ ] P1: 跨章节不再只依赖主页面截图，改为 from/to layout page snapshot。
- [ ] P3: 点击已有标注直接唤起旧工具条。
- [ ] P3: 复杂多页拖拽、跨图片/混排行的选择继续补测试。
- [ ] P3: 书签恢复完全切到 layout position 权威源。
