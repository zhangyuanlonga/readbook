# 阅读器核心改造 V7：旧能力承接与功能等价

**日期**: 2026-06-20
**状态**: 执行中，0-3 首轮已落地
**进度**: 35%
**用户效果**: 用户切到新阅读器后，旧阅读器已有功能不会消失、失效或行为明显退化。

---

## 1. 核心判断

V6 证明新 layout renderer 可以进入正式阅读器入口，但它还不是完整的新阅读器替换。真正上线前必须完成 V7：把旧阅读器已有能力接入、重构或等价替换到新阅读器。

- [ ] 新阅读器不是只渲染正文，还必须承接旧阅读器的翻页、选择、标注、搜索、朗读、设置、输入、跨章、诊断和 fallback。
- [ ] 旧阅读器可以继续保留 fallback，但不能长期和新 renderer 混用一套隐式运行态。
- [x] 所有旧能力必须有“新 renderer 下是否可用”的矩阵记录。
- [ ] 未完成矩阵前，不删除旧阅读器。
- [ ] 未完成矩阵前，不宣称新阅读器达到用户功能等价。

---

## 2. 来源：最初 Code Review 关键结果

来自 `reader-core-code-review-legado-gap-2026-06-20.md` 的初始审查结论：

- [ ] `ReaderPage` 仍是 God State，很多 part 共享同一个私有状态池。
- [ ] 旧分页、动画、选择、进度、内容加载互相牵连，容易产生隐藏 bug。
- [ ] 旧分页模型只能表达 paragraph slice，不能完整表达行、列、图片、链接和坐标。
- [ ] 选择、标注、朗读、搜索曾依赖 display offset 反推，混排/跨页风险高。
- [ ] 翻页动画仍和 UI 快照、主页面状态强耦合。
- [ ] EPUB/HTML/混排语义不足，复杂章节和主流阅读器仍有差距。
- [ ] 设置项很多，但必须确认每个旧设置在新 renderer 下是否仍然生效。

来自 `reader-surface-special-audit-2026-06-20.md` 的补充结论：

- [ ] 项目不是多个独立阅读器，而是一个 `ReaderPage` 主壳 + 多个 surface。
- [ ] 文本、漫画、PDF、音频可以不共享文本排版，但必须共享 session/progress/intent/cache/diagnostics 边界。
- [ ] 漫画/PDF/音频不能被新 text renderer 误切。
- [ ] 多 surface 进度字段不能互相污染。

---

## 3. 旧能力功能等价矩阵

| 能力 | 旧阅读器状态 | 新阅读器当前状态 | V7 要求 |
|---|---|---|---|
| 普通翻页 | 可用 | 可用但刚修过旧动画耦合 | 接入统一 page-turn delegate |
| 纸张卷页 paperCurl | 可用 | 未接入 | 必须接入或显式降级并给用户可理解设置 |
| 仿真 curl/覆盖/滑动/淡入 | 可用 | 未完整接入 | 承接旧动画或建立新动画 adapter |
| 跨章节翻页动画 | 可用 | 未完整接入 | 新 renderer 支持 from/to page snapshot |
| 点击分区翻页 | 可用 | 可用但需回归 | 统一 tap zone -> intent -> surface |
| 键盘/音量键翻页 | 可用 | 需回归 | 统一 input intent，覆盖新 renderer |
| 长按选择 | 可用 | 最小闭环可用 | 跨页拖拽、工具条、复制、取消全部追平 |
| 标注/灵感保存 | 可用 | 最小闭环可用 | 高亮、加粗、下划线、波浪线视觉追平 |
| 书签定位 | 可用 | 需回归 | layout position 恢复稳定 |
| 搜索高亮/跳转 | 可用 | layout anchor alpha | 新 renderer 下跳转和高亮稳定 |
| 朗读/高亮 | 可用或 alpha | layout anchor alpha | 朗读进度和可见文字一致 |
| 自动阅读 | 可用 | 未完整验证 | 新 renderer 支持 paged/scroll auto-read 策略 |
| 字体/字号/行距/边距 | 可用 | 部分接入 layout spec | 每个设置进入 layout signature 并生效 |
| 背景/亮度/信息栏 | 可用 | 大多复用外壳 | 新 renderer frame 不遮挡、不错位 |
| EPUB 图片/标题/caption | 部分可用 | alpha | 图片尺寸、点击、caption、标题样式继续补齐 |
| diagnostics/fallback | 可用 | 已接入 alpha | 诊断能区分新旧路径和 fallback reason |

---

## 4. P0：功能等价审计

- [x] 列出旧阅读器全部用户可见功能。
- [x] 对每个功能标记新 renderer：已可用 / 部分可用 / 未接入 / 不适用。
- [x] 对“部分可用”写明缺失点，例如 paperCurl、跨页拖拽、underline/wavy。
- [ ] 对“不适用”写明原因，例如漫画/PDF/音频不走 text layout。
- [x] 建立 `ReaderFeatureParityMatrix` 文档或测试 fixture。
- [x] 把 TestFlight 首包必须保留旧 fallback 写入发布清单。

执行记录：

- [x] 新增 `reader-feature-parity-matrix-v7-2026-06-20.md`。
- [x] 新增 `ReaderFeatureParityMatrix` 代码 fixture 与测试。

## 5. P1：Page Turn Delegate 接入

- [ ] 新增或扩展 `ReaderPageTurnDelegate`，输入统一为 fromPage/toPage/direction/style/source。
- [ ] 新 renderer 输出可被动画消费的 page snapshot。
- [ ] paperCurl 接入新 renderer，不能再依赖旧 `ReaderPaperCurlPagedSurface` 独占状态。
- [ ] curl/cover/translate/fade/none 在新 renderer 下行为与旧设置一致。
- [ ] 跨章节 from/to snapshot 不再依赖主页面临时截图作为唯一方案。
- [x] page turn 失败时有明确 fallback，不出现点击无响应。

执行记录：

- [x] `ReaderPageTurnDelegate` 首轮声明 release 支持能力与 legacy fallback。
- [x] `ReaderLayoutReleasePolicy` 对未桥接动画回落 legacy renderer。
- [x] paperCurl/curl/cover/translate/fade/vertical 在 release 未支持前不再静默失效。

## 6. P2：输入 Intent 统一

- [x] tap zone、键盘、音量键、鼠标滚轮统一转为 `ReaderNavigationCommand`。
- [x] 新 renderer 和旧 renderer 都通过同一个 intent adapter 消费命令。
- [ ] 新 renderer 下上一页/下一页、上一章/下一章边界行为与旧阅读器一致。
- [x] selection 激活时禁用翻页 intent，避免长按和点击冲突。
- [ ] 自动阅读状态下的手动翻页、暂停、恢复行为保持一致。

执行记录：

- [x] `ReaderNavigationCommandDispatcher` 增加 selection active page-intent gate。
- [x] volume key 等输入通道无法绕过 selection gate。

## 7. P3：选择、标注和书签功能等价

- [x] 新 renderer 长按命中使用 layout hit-test。
- [x] 跨页拖拽选择可用。
- [ ] 复制、保存灵感、删除灵感、编辑笔记可用。
- [x] 高亮、加粗、下划线、波浪线视觉在新 renderer 下绘制正确。
- [ ] 点击已有标注能唤起旧工具条。
- [ ] 书签恢复优先使用 layout position，失败时 fallback 到 chapter offset/snippet。

执行记录：

- [x] layout annotation range 承接旧 bookmark 的 bold/underline/wavy 字段。
- [x] `ReaderLayoutPagedView` 长按移动时更新 layout range，拖出页边映射相邻 page。

## 8. P4：搜索、朗读和自动阅读

- [ ] 搜索结果使用 layout range 定位到页、行、列。
- [ ] 搜索命中高亮在新 renderer 下位置正确。
- [ ] 从目录搜索/正文搜索跳转后页码与可见内容一致。
- [ ] 朗读高亮使用同一套 layout position。
- [ ] 自动阅读在新 renderer 下支持分页节奏、暂停、恢复、跨章。
- [ ] 音频 surface 不误用 text renderer 的进度字段。

## 9. P5：设置兼容矩阵

- [ ] 字号、行高、段距、首行缩进、边距进入 layout signature。
- [ ] 字体来源、字体粗细、字体 family 在新 renderer 下生效。
- [ ] 两端对齐、中文标点策略在新 renderer 下生效。
- [ ] 背景、亮度、信息栏、章节标题 frame 在新 renderer 下不遮挡正文。
- [ ] 翻页动画设置在新 renderer 下要么等价，要么禁用不可用选项。
- [ ] 设置变化后旧 layout task 取消，新 layout 稳定重建。

## 10. P6：EPUB/HTML/混排承接

- [ ] 标题、段落、列表、引用、caption、footnote 在新 renderer 下可读。
- [ ] 图片 block/inline image 不重叠、不跳页、不遮挡文字。
- [ ] 图片点击、重试、占位、真实尺寸更新有明确策略。
- [ ] link/footnote/caption 的 semantic payload 不丢。
- [ ] EPUB 混排样本加入 smoke checklist。

## 11. P7：新旧共存隔离

- [ ] 新 renderer 激活时，不再触发旧 `_ensurePagination` 除 fallback 外的工作。
- [ ] 新 renderer 激活时，不读旧 paperCurl/curl surface 的私有状态。
- [ ] 旧 renderer fallback 时，清理新 renderer request/pageCount/diagnostics 的活跃态。
- [ ] page count、page index、selection、progress 只能有一个当前权威来源。
- [ ] diagnostics 明确记录当前 renderer：legacy / release / fallback。

## 12. P8：验收和发布门禁

- [ ] V7 功能等价矩阵全部 P0/P1 能力完成。
- [ ] `flutter analyze` 通过。
- [ ] reader core test bundle 通过。
- [ ] 新增 page-turn delegate widget/unit tests。
- [ ] 新增 selection/annotation parity tests。
- [ ] 新增 settings signature/effect tests。
- [ ] `docs/test_readr` 样本 smoke 通过。
- [ ] profile mode 首屏、翻页、设置变化有记录。
- [ ] TF 外部邀请前确认旧 fallback 可一键恢复。

---

## 13. 不做项

- [ ] 不在 V7 前删除旧阅读器。
- [ ] 不用“降级普通翻页”假装 paperCurl 已经支持。
- [ ] 不让用户已开启的旧设置在新阅读器里静默失效。
- [ ] 不继续让新旧 renderer 共享未声明的私有状态。
- [ ] 不把漫画/PDF/音频强行塞进文本 layout renderer。

---

## 14. 完成定义

- [ ] 用户切到新阅读器后，旧阅读器已有核心功能仍可使用。
- [ ] 无明显“点了没反应”“设置失效”“标注错位”“页码错乱”等体验缺口。
- [ ] 新 renderer 与旧 fallback 边界明确。
- [ ] 旧阅读器可以继续保留 fallback，但不再是用户功能缺口的唯一兜底。
