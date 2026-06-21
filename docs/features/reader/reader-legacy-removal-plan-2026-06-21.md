# 阅读器旧实现移除计划

**日期**: 2026-06-21
**状态**: P0-P7 已执行
**完成进度**: 90%
**目标**: 在新阅读器已完成滚动、分页、动画、选择、设置、跨章与阅读记录验收后，移除旧阅读器 fallback 和旧分页实现路径，降低新旧共存导致的隐藏 bug。

---

## 1. 背景与结论

本轮调试已经确认：旧阅读器和新阅读器共存时，容易出现“实际运行路径不明确”的问题。例如连续滚动跨章闪动，最终涉及窗口裁剪、章节身份同步、正文容器 key 和旧状态联动。新阅读器稳定后，继续保留旧入口会让后续问题定位成本变高。

- [x] 删除旧阅读器前，必须先完成入口冻结和严格模式验收。
- [x] 删除目标是 legacy renderer/fallback/旧分页渲染路径，不是删除所有 reader 共享能力。
- [x] 漫画、PDF、音频不是“旧阅读器”，它们是独立 surface，不能误删。
- [x] 搜索、朗读、自动阅读、书签、灵感、设置、缓存、阅读记录是共享能力，不能因为文件名不新而删除。
- [x] 所有删除动作必须保持用户能力不退化：滚动、分页、翻页动画、长按、灵感、信息排版、跨章、预加载、阅读记录都要继续可用。

---

## 2. 删除范围定义

### 2.1 可以进入删除候选的内容

- [x] `ReaderLayoutReleaseSurface` 中只为旧 renderer 保留的 `legacyBuilder` 分支。
- [x] `ReaderLayoutRendererPreviewSurface` 中仅服务 preview/fallback 的 legacy mode。
- [x] `ReaderLayoutReleasePolicy` 中允许 release 回落 legacy 的策略分支。
- [x] `ReaderRendererAuthorityResolver` 中 legacy/release authority 双权威切换逻辑。
- [x] `READER_LAYOUT_FORCE_LEGACY`、`READER_LAYOUT_ENABLE_RELEASE` 等旧回滚开关。
- [x] `_ensurePagination` 仅服务旧文本分页的调用链。
- [ ] `ReaderTextPagedView` 中不再被新分页 surface 使用的旧 paragraph slice 渲染路径。
- [x] `ReaderPagedSlice`、`ReaderPagedSliceLayoutAdapter` 中只为旧分页兼容存在的桥接代码。
- [ ] 旧 cross-chapter snapshot fallback 中只为 legacy page 截图服务的路径。
- [x] 旧 renderer diagnostics、fallback reason、legacy test fixture。
- [x] V6/V7 文档中关于“TF 需保留 legacy fallback”的临时说明，删除后改为历史记录。

### 2.2 不应删除或必须重命名后保留的内容

- [ ] `ReaderPage` 主壳、viewport、settings、overlay、navigation command、runtime controller。
- [ ] `ReaderLayoutEngine`、`ReaderLayoutPage`、`ReaderLayoutLine`、layout cache 和 release renderer。
- [ ] `ReaderPagedAnimationSurface`、`ReaderPaperCurlPagedView`、curl/cover/translate/fade/vertical 动画 renderer，只要它们已被新分页承接。
- [ ] `ReaderTextPagedView` 如果仍作为新分页 page frame 容器使用，则应重命名或收敛，而不是直接删。
- [ ] 连续滚动 `ReaderPageContinuousTextChapter` 和跨章窗口逻辑。
- [ ] 漫画 `ReaderMangaView`、PDF `ReaderPdfView`、音频 `ReaderAudioView`。
- [ ] 本地图书解析、在线内容加载、章节缓存、阅读记录、书签、灵感、搜索、朗读、自动阅读。
- [ ] 通用容错意义的 `fallback`，例如编码探测、图片占位、错误展示、阅读记录 fallback。

---

## 3. 前置门禁

- [ ] 新阅读器默认入口在 debug/profile/release 三种构建都生效。
- [x] 不再需要 `READER_LAYOUT_STRICT_RELEASE=true` 才能确认新阅读器接手。
- [x] `READER_LAYOUT_FORCE_LEGACY=true` 构建不再作为用户回滚方案。
- [ ] 滚动模式跨章连续点击无闪、无空白、无 loading toast、无 offset clamp。
- [ ] 分页模式普通翻页、跨章翻页、快速点击无 busy toast、无旧页残影。
- [ ] `none / cover / translate / vertical / fade / curl / paperCurl` 都有 pass/fail 记录。
- [ ] 信息排版拖动字号、行距、段距、边距、信息栏 margin/padding 不闪白。
- [ ] 长按浮窗、复制、灵感保存、已有标注点击、书签恢复可用。
- [ ] 搜索跳转、朗读高亮、自动阅读跨章至少完成一轮真机验收。
- [ ] 漫画/PDF/音频确认不受文本新阅读器删除旧路径影响。
- [x] 阅读器范围 `flutter analyze lib/features/reader test/features/reader` 通过。
- [ ] 阅读器 application 与 presentation 测试通过。
- [ ] `docs/test_readr` 中 TXT/EPUB 样本完成 smoke 记录。

---

## 4. 阶段任务

## P0 现状冻结与删除清单

- [x] 记录当前提交 hash，作为旧实现删除前基线。
- [x] 记录当前新阅读器默认 dart-define 组合。
- [x] 列出所有仍引用 `ReaderLayoutLegacyRendererBuilder` 的位置。
- [x] 列出所有仍引用 `legacyBuilder` 的位置。
- [x] 列出所有仍读取 `READER_LAYOUT_FORCE_LEGACY` 的位置。
- [x] 列出所有仍读取 `READER_LAYOUT_ENABLE_RELEASE` 的位置。
- [x] 列出所有仍读取 `READER_LAYOUT_STRICT_RELEASE` 的位置。
- [x] 列出所有 `_ensurePagination` 调用点并标记 owner：旧分页 / 新分页 / 共享预计算。
- [x] 列出所有 `ReaderPagedSlice` 调用点并标记是否仍被新 renderer 需要。
- [x] 列出所有 `ReaderLayoutReleasePolicy` 判断结果，确认是否还有真实 fallback 需求。
- [x] 列出所有 legacy/fallback 相关测试，标记删除、改名或改为新阅读器测试。
- [x] 更新本文件的删除清单，形成可执行勾选列表。

**验收**:

- [x] 删除清单可追溯到文件级别。
- [x] 每个候选文件都有保留/删除/重命名结论。
- [x] 不存在“看起来旧就删”的未归类项。

## P1 入口冻结：关闭旧入口但暂不删代码

- [x] 移除或忽略 `READER_LAYOUT_FORCE_LEGACY=true` 对正式阅读器入口的影响。
- [x] 移除 `READER_LAYOUT_ENABLE_RELEASE=false` 关闭新 renderer 的能力。
- [x] 保留 `READER_LAYOUT_SHOW_DIAGNOSTICS`，但诊断内容改为新阅读器状态，不再显示 legacy fallback。
- [x] `ReaderLayoutReleasePolicy` 默认只允许新 renderer。
- [x] `ReaderLayoutReleaseSurface` 不再在正常路径调用 `legacyBuilder`。
- [x] `ReaderRendererAuthorityResolver` 输出只有新 renderer authority。
- [x] 文本分页入口不再因为策略拒绝回旧 renderer。
- [x] 如果新 renderer 不 ready，显示明确诊断或 loading，不静默回旧页。
- [x] 本阶段不删除旧代码，只确认运行态不会进入旧路径。

**验收**:

- [x] 搜索日志确认没有 `legacy fallback`、`effectiveMode=legacy`。
- [ ] 打开滚动/分页/纸页/设置/长按后，运行态没有回旧 renderer。
- [ ] `flutter analyze lib/features/reader` 通过。
- [x] 旧代码未删，因此可快速回退本阶段提交。

## P2 分页旧渲染路径收敛

- [x] 确认新分页 surface 已承接 `none / cover / translate / vertical / fade / curl / paperCurl`。
- [x] 删除旧 paragraph slice 分页入口中不再使用的 page build 分支。
- [x] 删除旧 page count authority 与新 page count authority 的切换逻辑。
- [x] 删除旧 `_pagedPages` 仅用于渲染的分支，保留仍用于进度/缓存的字段前先改名确认。
- [x] 删除旧 `ReaderPagedSliceLayoutAdapter` 中只为 release fallback 准备的代码。
- [x] 新 renderer page model 成为分页唯一数据源。
- [x] 纸张卷页不再依赖旧 renderer page widget 截图。
- [x] cross-chapter animation 只消费新 page snapshot 或新 surface。
- [x] 删除旧分页 fallback 的 diagnostics reason。

**验收**:

- [x] `ReaderPagedViewportSupport` 测试仍覆盖所有动画。
- [ ] 快速点击分页 20 次不吞页。
- [ ] 每种动画跨章一次，无空白、无旧图残影。
- [ ] 字号/边距变化后页码、进度和可见段落稳定。

## P3 连续滚动旧兼容路径清理

- [x] 确认连续滚动以 `_continuousTextChapters` 作为唯一正文窗口源。
- [x] 删除滚动模式下旧单章正文 list 的 fallback 入口。
- [x] 删除滚动跨章时旧 `_jumpTo(nextChapter)` fallback。
- [x] 保留真实第一章/最后章边界提示。
- [x] 删除滚动预热中已不需要的 legacy loading toast。
- [x] 删除为旧窗口裁剪保留的稳定锚点兼容日志。
- [x] 收敛 `load_adjacent_*` 临时调试日志，只保留异常日志。
- [x] 保留连续滚动标题刷新，但不得重挂载正文容器。

**验收**:

- [ ] 滚动跨章快速点击 20 次无闪。
- [ ] 到下一章头部后继续下一页无闪。
- [ ] 上一页跨章可回到上一章尾部。
- [ ] 长按浮窗在滚动模式可触发。
- [ ] 信息排版拖动时正文不闪白。

## P4 设置与能力开关清理

- [x] 设置页不再显示旧 renderer / 新 renderer / fallback 相关内部选项。
- [x] 删除旧 renderer 专用不可用项的提示文案。
- [x] 翻页动画设置只展示新阅读器已支持项。
- [x] 若某动画仍未达标，设置页禁用该项并写明原因，不依赖旧 fallback。
- [x] 删除旧开关对应的 preferences 读取与迁移。
- [x] 清理旧诊断字段在错误页、反馈页、日志中的展示。
- [x] 更新 `ReaderFeatureParityMatrix`，移除 `requiresLegacyFallbackForTf` 或改为历史字段。
- [x] 更新设置兼容矩阵，所有字段 owner 指向新 renderer/shell/surface。

**验收**:

- [ ] 设置页没有“旧阅读器/legacy/fallback”用户可见字样。
- [ ] 每个设置项仍可保存和恢复。
- [x] 切换翻页模式不会产生旧运行态。
- [x] 反馈诊断可以判断新阅读器状态，但不出现旧 renderer 回退。

## P5 测试迁移与删除

- [x] 删除 strict release blocks legacy fallback 的测试，或改成“不存在 legacy fallback”测试。
- [x] 删除 `legacyBuilder should not render` 类测试。
- [x] 新增默认入口不回旧 renderer 的 widget/unit 测试。
- [x] 新增 dart-define 旧开关无效或已移除的测试。
- [x] 新增分页所有动画都由新 surface 承接的测试。
- [ ] 新增滚动跨章窗口稳定测试。
- [ ] 新增正文 content switcher key 在连续滚动跨章时稳定的测试。
- [ ] 新增设置变化不触发正文重挂载的测试。
- [x] 更新 golden/smoke 名称，避免 `legacy` 命名误导。
- [x] 删除已无入口的旧 fixture。

**验收**:

- [ ] `flutter test test/features/reader/application` 通过。
- [ ] `flutter test test/features/reader/presentation` 通过。
- [x] 没有测试仍依赖旧 renderer 才通过。

## P6 代码删除

- [x] 删除 `ReaderLayoutLegacyRendererBuilder` typedef。
- [x] 删除 `legacyBuilder` 参数和调用。
- [x] 删除 legacy mode enum 值或迁移为历史诊断值。
- [x] 删除旧 release fallback 分支。
- [x] 删除旧 renderer authority 分支。
- [x] 删除旧强制 legacy dart-define 常量与读取逻辑。
- [x] 删除旧关闭 release dart-define 常量与读取逻辑。
- [x] 删除旧 fallback diagnostics 文案。
- [x] 删除无引用的旧分页 widget、controller、support model。
- [x] 删除无引用的旧 paragraph slice 渲染 adapter。
- [x] 删除无引用 import、part、extension、helper。
- [x] 删除无引用测试 helper。
- [x] 运行 `dart format`。
- [x] 运行 `dart fix --dry-run` 或等价静态检查，确认无明显死代码。

**验收**:

- [ ] `rg "LegacyRenderer|legacyBuilder|FORCE_LEGACY|ENABLE_RELEASE|STRICT_RELEASE"` 只剩历史文档或完全为空。
- [ ] `rg "fallback"` 剩余项均为通用容错，不是旧阅读器回退。
- [x] `flutter analyze lib/features/reader test/features/reader` 通过。
- [ ] `git diff --check` 通过。

## P7 文档清理

- [x] 更新 `reader-core-modernization-v6-execution-plan-2026-06-20.md`，标注旧 fallback 已移除。
- [x] 更新 `reader-core-modernization-v7-feature-parity-node-2026-06-20.md`，标注功能等价已进入新阅读器单路径。
- [x] 更新 `reader-launch-readiness-gap-assessment-2026-06-21.md`，移除“不能删除旧阅读器”的当前态结论，保留历史风险说明。
- [x] 更新 `reader-feature-parity-matrix-v7-2026-06-20.md`，删除 TF legacy fallback 依赖。
- [x] 新增或更新验收报告：旧阅读器移除完成记录。
- [x] 在本文件每个阶段补执行记录、提交 hash 和测试结果。
- [x] 若删除过程中发现保留项，写入“延期项”而不是静默留下。

**验收**:

- [x] 文档结论与代码状态一致。
- [x] 没有文档继续要求打 `READER_LAYOUT_FORCE_LEGACY=true` 回滚包。
- [x] 新用户或开发者能从文档判断当前只有新阅读器路径。

## P8 发布与回滚策略更新

- [ ] 回滚策略从“打开旧阅读器”改为“回退上一稳定版本/提交”。
- [ ] 记录可回滚 tag 或提交 hash。
- [ ] 准备小范围灰度包，灰度包不包含旧阅读器开关。
- [ ] 收集滚动、分页、动画、设置、长按、搜索、朗读、自动阅读反馈。
- [ ] 如果出现 P0 问题，回滚到删除前提交，而不是在当前包内切旧路径。
- [ ] 更新反馈模板，删除 legacy 字段，增加 renderer/page/scroll/window/animation 状态字段。
- [ ] 发布前做一次真机 profile：首屏、快速分页、滚动跨章、paperCurl、设置拖动。

**验收**:

- [ ] 灰度期间没有旧路径诊断日志。
- [ ] 回滚演练明确：命令、分支、包版本、负责人。
- [ ] 用户反馈模板能定位新阅读器问题。

---

## 5. 验收矩阵

| 能力 | 删除旧实现前 | 删除旧实现后 | 验收状态 |
|---|---|---|---|
| 滚动普通点击 | 新阅读器可用 | 必须可用 | [ ] |
| 滚动跨章 | 新阅读器已修复闪动 | 必须无闪、无空白 | [ ] |
| 滚动上一章 | 需回归 | 必须可用 | [ ] |
| 分页普通翻页 | 新阅读器可用 | 必须可用 | [ ] |
| 分页跨章 | 已优化 | 必须无 busy toast、无残影 | [ ] |
| paperCurl | 已接入并需回归 | 必须可用或禁用 | [ ] |
| curl/cover/translate/fade/vertical/none | 已接入 | 必须逐项通过 | [ ] |
| 长按选择 | 可用 | 必须可用 | [ ] |
| 灵感/标注 | 可用 | 必须可用 | [ ] |
| 书签恢复 | 可用 | 必须可用 | [ ] |
| 搜索跳转 | 需回归 | 必须可用 | [ ] |
| 朗读高亮 | 需回归 | 必须可用 | [ ] |
| 自动阅读 | 需回归 | 必须可用或显式降级 | [ ] |
| 信息排版 | 已修拖动闪 | 必须不闪、不遮挡 | [ ] |
| 阅读记录 | 可用 | 必须可用 | [ ] |
| 漫画/PDF/音频 | 独立 surface | 必须不受影响 | [ ] |

---

## 6. P0-P3 执行记录

**执行时间**: 2026-06-21
**删除前基线**: `36dfdace`
**当前阶段结论**: P0/P1/P3 已完成；P2 完成运行态收敛，结构性删除和命名迁移留到 P6。

### P0 盘点结果

- [x] `ReaderLayoutLegacyRendererBuilder` 仅剩 `lib/features/reader/presentation/reader_layout_renderer_preview_surface.dart` 和对应 preview 测试，正式 `ReaderLayoutReleaseSurface` 已不暴露该 builder。
- [x] `legacyBuilder` 仅剩 preview surface/test，作为 P6 删除候选；正式阅读器入口不再传入。
- [x] `READER_LAYOUT_FORCE_LEGACY`、`READER_LAYOUT_ENABLE_RELEASE` 仍在 `ReaderLayoutReleasePolicy` 读取，但已变成诊断字段，不再影响正式入口。
- [x] `READER_LAYOUT_STRICT_RELEASE` 不再是新阅读器接手的必要开关，策略默认严格模式。
- [x] `_ensurePagination`、`_restoreOrPaginateCurrentChapter`、`_paginateCurrentChapter`、旧 `_buildPagedPageContainer`、旧 `_buildPagedResolvedSliceContent`、旧 `_handleBookmarkTapInSlice` 和旧 static page controller resolver 已删除。
- [x] `ReaderPagedSlice` 仍被 content loading、offset mapper、selection、presentation resolver、`ReaderTextPagedView` 和测试使用；需要先确认是否为新路径共享模型，再决定重命名或删除。
- [x] `fallback` 搜索结果多数是通用容错、书签/阅读记录恢复、图片占位、错误展示，不属于旧阅读器 fallback，不能按关键词批量删除。

### P1 已落地

- [x] `ReaderLayoutReleasePolicy` 默认 `strictReleaseValidation=true`。
- [x] `READER_LAYOUT_FORCE_LEGACY=true` 不再返回 `force_legacy`，只进入 diagnostics。
- [x] `READER_LAYOUT_ENABLE_RELEASE=false` 不再关闭新 renderer，只进入 diagnostics。
- [x] `ReaderLayoutReleaseSurface` 删除 `legacyBuilder` 参数，不再把旧 renderer builder 传入 release surface。
- [x] `ReaderPageViewport` 在 release decision 不可用或 request 不存在时显示 `ReaderLayoutStrictReleaseFailure`，不静默回旧分页。

### P2 已落地与延期项

- [x] `ReaderRendererAuthorityResolver` 只输出 `ReaderRendererAuthority.release`。
- [x] 删除 resolver 的 legacy page count、block page count 和 `shouldScheduleLegacyPagination` 字段。
- [x] `ReaderPage`、`ReaderPageViewport` 不再把旧 page count 作为 authority 输入。
- [x] 文本分页正式入口不再调用 `buildLegacyViewport` 和 `scheduleLegacyPagination`。
- [x] 删除旧 streaming pagination 运行态入口和旧文本分页 fallback-to-scroll 方法。
- [x] 删除旧 `ReaderTextPagedView` page frame 在 `ReaderPage` 中的直接 import 和旧交互回调。
- [ ] `ReaderTextPagedView`、`ReaderPagedSlice` 相关结构性删除或重命名延期到 P6，原因是它们仍与预计算、选择、offset mapper 和测试共享。

### P3 已落地

- [x] 连续滚动跨章目标未准备好时，不再 `_jumpTo(targetChapterIndex)` 重挂正文。
- [x] 真实第一章/最后一章仍保留边界提示。
- [x] `load_adjacent_*` 临时日志收敛为异常类日志：`load_adjacent_result_empty`、`load_adjacent_target_rejected`。
- [x] 保留锚点跳点异常日志：`anchor_restore_jump`、`activate_restore_offset_jump`。
- [x] 正常 `load_adjacent_inserted`、`activate_commit`、`sync_active_activate_resolved` 不再刷日志。

### P0-P3 验证结果

- [x] `flutter analyze lib/features/reader test/features/reader` 通过。
- [x] `flutter test test/features/reader/application/reader_layout_release_policy_test.dart test/features/reader/application/reader_renderer_authority_resolver_test.dart test/features/reader/presentation/reader_layout_renderer_preview_surface_test.dart test/features/reader/application/reader_page_turn_gate_test.dart test/features/reader/application/reader_navigation_command_dispatcher_test.dart test/features/reader/presentation/reader_paged_viewport_support_test.dart test/features/reader/presentation/reader_text_offset_mapper_test.dart test/features/reader/presentation/reader_bookmark_range_presenter_test.dart -r compact` 通过，49 tests passed。
- [x] `git diff --check` 通过。
- [x] `rg "_ensurePagination|buildLegacyViewport|scheduleLegacyPagination|shouldScheduleLegacyPagination|ReaderRendererAuthority\\.(legacy|fallback)|edge_fallback_chapter_jump" lib/features/reader test/features/reader` 无代码命中。

### P4-P7 已落地

- [x] `ReaderLayoutReleasePolicy` 删除旧强制 legacy / 关闭 release 的 dart-define 常量、构造字段和 diagnostics 字段。
- [x] `ReaderPageTurnDelegate` 删除 legacy surface、legacy fallback decision 和 `canUseLegacyFallback`。
- [x] `ReaderLayoutRendererController` 状态收敛为 `loading / ready / failed`，失败只输出 release failure，不回旧 renderer。
- [x] `ReaderLayoutRendererPreviewSurface` 删除 `ReaderLayoutLegacyRendererBuilder`、`legacyBuilder` 和 preview fallback builder。
- [x] `ReaderLayoutEngineMode` 只保留 `experimental`；删除 adapter-only fallback runner。
- [x] 删除 `ReaderPagedSliceLayoutAdapter` 和旧 adapter/fallback runner 测试。
- [x] `ReaderLayoutAnchorReadinessPolicy` 将 `legacyFallback` 改为 `nonLayoutAnchor`。
- [x] `ReaderFeatureParityMatrix` 删除 `requiresLegacyFallbackForTf` 和 `legacyFallbackItemsForTf()`。
- [x] `ReaderLayoutDiagnostics` 将 layout fallback diagnostics 改为 failure diagnostics。
- [x] 更新 V6/V7/上线评估/功能矩阵/验收报告文档，旧 fallback 策略改为历史记录。

### P4-P7 延期项

- [ ] `ReaderTextPagedView` 与 `ReaderPagedSlice` 仍被 offset mapper、content state、selection/presentation 测试使用，当前不再作为正式渲染入口，后续如果重命名/删除需单独开 P8+ 结构任务。
- [ ] `fallback` 词仍存在于通用容错：书签/snippet 恢复、错误展示、字体/图片/缓存兼容、reading record 迁移等，不属于旧阅读器回退。
- [ ] 真机 UI smoke、profile 数据、版本回滚演练仍属于 P8 发布门禁。

### P4-P7 验证结果

- [x] `flutter analyze lib/features/reader test/features/reader` 通过。
- [x] `flutter test test/features/reader/application/reader_layout_diagnostics_service_test.dart test/features/reader/application/reader_layout_renderer_controller_test.dart test/features/reader/presentation/reader_layout_renderer_preview_surface_test.dart test/features/reader/application/reader_layout_release_policy_test.dart test/features/reader/application/reader_renderer_authority_resolver_test.dart test/features/reader/application/reader_page_turn_delegate_test.dart test/features/reader/application/reader_feature_parity_matrix_test.dart test/features/reader/application/reader_layout_anchor_readiness_policy_test.dart -r compact` 通过。
- [x] `flutter test test/features/reader/application -r compact` 通过，573 tests passed。
- [x] `flutter test test/features/reader/presentation -r compact` 通过，192 tests passed。

---

## 7. 风险清单

- [ ] 删除旧分页过早，paperCurl 或 cross-chapter snapshot 仍依赖旧 page widget。
- [ ] `ReaderTextPagedView` 名字像旧实现，但可能仍是新 surface frame，误删会破坏分页。
- [ ] `fallback` 词在代码中大量表示通用容错，不能用全局搜索直接删除。
- [ ] 旧 dart-define 删除后，线上问题只能靠版本回滚，灰度范围必须更保守。
- [ ] 设置页某些选项如果只在旧 renderer 生效，删除后会变成静默失效。
- [ ] 搜索、朗读、自动阅读可能在单测通过但 UI 链路未完全覆盖。
- [ ] 本地 EPUB/HTML/图片混排样本可能暴露新 renderer page model 边界。
- [ ] 删除旧测试后，必须用新路径测试补上同等保护。

---

## 8. 建议执行顺序

- [ ] 第 1 个提交：P0 盘点文档和入口清单，不改运行态。
- [ ] 第 2 个提交：P1 入口冻结，不删代码。
- [ ] 第 3 个提交：P2/P3 收敛分页和滚动旧入口。
- [ ] 第 4 个提交：P4/P5 设置与测试迁移。
- [ ] 第 5 个提交：P6 删除代码。
- [ ] 第 6 个提交：P7/P8 文档、验收和回滚策略更新。

每个提交后至少运行：

```bash
flutter analyze lib/features/reader test/features/reader
flutter test test/features/reader/application -r compact
flutter test test/features/reader/presentation -r compact
git diff --check
```

删除代码提交后额外运行：

```bash
rg "LegacyRenderer|legacyBuilder|FORCE_LEGACY|ENABLE_RELEASE|STRICT_RELEASE" lib/features/reader test/features/reader
rg "reader_content_.*legacy|effectiveMode=legacy|legacy fallback" lib/features/reader test/features/reader
```

---

## 9. 完成定义

- [ ] 用户打开阅读器只存在新阅读器一条文本路径。
- [ ] 代码中不存在可运行的旧文本 renderer fallback。
- [ ] 旧 dart-define 开关已删除或不再影响运行态。
- [ ] 滚动、分页、动画、设置、选择、标注、搜索、朗读、自动阅读全部完成验收。
- [ ] 漫画/PDF/音频 surface 不受影响。
- [ ] 阅读器范围 analyze/test 通过。
- [ ] 文档不再把旧阅读器作为上线兜底。
- [ ] 回滚策略改为版本回滚，并有明确提交 hash/tag。
