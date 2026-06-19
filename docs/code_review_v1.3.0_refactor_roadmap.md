# Code Review v1.3.0 阶段改造路线图

**日期**: 2026-06-17
**来源**: `docs/code_review_v1.3.0_report.md`
**用途**: 将 v1.3.0 代码审查报告转成可排期、可验收、可回滚的阶段任务。
**总原则**: 先处理真实线上风险，再处理架构边界；先小步验证，再拆大文件；不在同一发版窗口同时重构 Reader、Bookshelf、Book Detail、Mine 四条高频链路。

---

## 0. 结论摘要

原报告指出的问题很多，但优先级需要按线上风险重新排序。以下结论用于指导后续排期：

| 类型 | 原报告优先级 | 调整后优先级 | 判断 |
|---|---:|---:|---|
| StreamController 生命周期 | P0 | P0 | 局部后台任务 stream 可能异常后不关闭，属于真实稳定性风险。 |
| 异常吞掉、错误上下文不足 | P1 | P0/P1 | 直接影响书源、详情、正文失败排查，近期应优先补。 |
| core 依赖 features | P0 | P1 | 是架构债，但不是当前发版阻塞；适合分批抽接口。 |
| ChangeNotifier 与 Riverpod 混用 | P0 | P1 | 需要治理，但音频和后台任务链路当前较敏感，不适合硬切。 |
| 超大文件 | P0 | P1/P2 | 是维护风险，不是单次发版必须；应按页面拆分，持续交付。 |
| ref.watch 过多、列表 key、AnimatedBuilder | P1/P2 | P2 | 性能优化项，跟随页面拆分逐步做。 |
| null/边界条件统一 | P2 | P2 | 低风险可穿插处理，但需避免改变阅读进度语义。 |

---

## 1. 执行边界

- [ ] 不一次性大改 Reader、Bookshelf、Book Detail、Mine 四个核心页面。
- [ ] 不以“减少行数”为唯一目标；每次拆分必须带测试或手动验收清单。
- [ ] 不为了统一状态管理强行迁移稳定业务链路；先包边界、补测试，再迁移实现。
- [ ] 不把 app 级单例事件流简单 close；要先确认生命周期归属和测试污染风险。
- [ ] 每阶段完成后必须记录：影响文件、验证命令、回滚方式、未解决风险。

---

## 2. Phase 0：基线确认与已完成项

**目标**: 把报告里的“真实风险”和“长期治理”区分开，避免误把长期重构当作发版阻塞。
**建议周期**: 0.5-1 天
**状态**: 已完成（2026-06-19 复核）

### 已完成

- [x] 复核 `LocalBookIndexService` 静态事件流：当前属于应用级共享事件流，不建议简单 close。
- [x] 复核 `ReaderErrorCenterService` 单例事件流：当前属于应用级错误中心，不建议为满足报告直接加 dispose。
- [x] 修复 `ChapterCacheService.cacheRange()` 局部 stream：异常时记录日志、向 stream 发送 error，并在 finally 中统一 close。

### 验证记录

- [x] `dart format lib/features/reader/application/chapter_cache_service.dart`
- [x] `flutter analyze lib/features/reader/application/chapter_cache_service.dart lib/features/reader/application/reader_error_center_service.dart lib/features/reader/application/local/local_book_index_service.dart`
- [x] `flutter test test/features/reader/application/reader_session_listener_test.dart test/features/reader/application/reader_error_center_service_test.dart test/features/reader/application/local/local_book_index_service_test.dart`

### 后续基线任务

- [x] 给 `ChapterCacheService.cacheRange()` 增补早退关闭的单元测试。
- [x] 记录 app 级事件流生命周期约定，避免后续 review 再误判。
- [x] 将报告中的路径错误和优先级调整记录到本路线图，不回写原报告。

### 验收

- [ ] 当前工作区无未提交代码。
- [x] 文档明确哪些 P0 是当前发版风险，哪些是长期治理。

### 2026-06-19 补充记录

- app 级事件流约定：`LocalBookIndexService`、`ReaderErrorCenterService` 属于应用级共享事件流，不按局部 service 生命周期关闭；测试污染通过显式 reset/独立测试数据隔离处理。
- `ChapterCacheService.cacheRange()` 已补早退关闭测试，覆盖空章节列表和缺少必要 id 两类路径。
- 当前工作区仍有未提交改动，未将“工作区无未提交代码”作为本轮完成项打勾。

---

## 3. Phase 1：发版前稳定性治理

**目标**: 优先修复会影响用户反馈、线上定位、资源释放的风险。
**建议周期**: 2-4 天
**建议分支**: `codex/review-v130-stability`

### 任务 1：错误上下文补强

优先处理用户已经反馈过的链路：

- [x] 搜索结果进入详情失败时，详情页展示明确错误信息，不只显示泛化失败。
- [x] 目录加载失败时，保留 `sourceId/detailUrl/catalogUrl/stage/code` 等诊断字段。
- [x] 正文加载失败时，保留 `chapterUrl/chapterIndex/hasChapterExecutionContext/catalogComplete`。
- [x] 听书跳转失败时，区分内容解析失败、音频 URL 解析失败、阅读器类型路由失败。
- [x] 错误复制/诊断信息不要泄漏 token、cookie、用户隐私字段。

### 任务 2：高价值 catch 块改造

不要求一次性清理所有 `catch (_)`，先处理核心链路：

- [x] `book_detail_page.dart`：详情加载、目录加载、加入书架、切换书源。
- [x] `reader_page.dart` 及相关 facade：正文加载、章节切换、进度提交。
- [x] 搜索链路：搜索取消、超时、部分书源失败聚合。
- [x] 本地书链路：本地索引、编码失败、文件缺失。

每个 catch 改造要求：

- [x] 捕获 `error, stackTrace`。
- [x] 记录业务上下文，不只记录 `error.toString()`。
- [x] 用户提示使用友好文案，开发诊断保留结构化字段。
- [x] 覆盖至少一个失败路径测试或手动验收。

### 任务 3：资源生命周期最小治理

- [x] 为 app 级单例事件流补生命周期说明和测试 reset 策略。
- [x] 检查局部 `StreamController`、`Timer`、`AnimationController`、`ScrollController` 是否由 owning widget/service 释放。
- [x] 针对高风险局部 controller 补 finally/dispose，不碰全局单例架构。

### 验收

- [x] 书源失败能被用户复制出可定位诊断信息。
- [x] 详情、目录、正文、听书四条失败链路至少各有一个可复现错误态。
- [x] 针对改动文件执行 `flutter analyze`。
- [x] 核心 reader/book/search 相关测试通过。

### 回滚

- [x] 错误提示/UI 文案改动可单独回滚。
- [x] catch 改造不改变正常业务返回值，回滚不需要数据库迁移。

### 2026-06-19 补充记录

- 诊断脱敏集中到 `AppExceptionDiagnostics`，复制文本和 JSON 输出统一过滤 token/cookie/authorization/password/secret/session。
- 详情页 missing source 错误增加“换源”动作；目录诊断 context 同时保留 `tocUrl` 和 `catalogUrl`。
- Reader/Search/Book Detail 高价值 catch 改为捕获 `error, stackTrace` 并记录业务上下文；剩余 `catch (_)` 保留在补充性缓存、解析降级和非阻塞清理路径，后续如要治理应进入 Phase 6 catch 审计，不阻塞 Phase 4。
- 听书控制器区分“音频地址缺失”和“音频地址加载失败”，并补无音频 URL、控制命令、倍速、章节切换测试。

---

## 4. Phase 2：架构边界治理

**目标**: 逐步解除 core 对 features 的直接依赖，降低后续迁移和测试成本。
**建议周期**: 1-2 周
**建议分支**: `codex/review-v130-core-boundaries`

### 子阶段 A：数据迁移器接口化

涉及文件：

- `lib/core/app_data_migrator.dart`
- `lib/features/mine/application/advanced_theme_service.dart`
- `lib/features/reader/application/reader_preferences_service.dart`
- `lib/features/reader/application/reader_visual_overrides_service.dart`

任务：

- [x] 在 core 中定义偏好/数据修复接口，例如 `PreferenceRepairService`。
- [x] feature service 实现 core 接口。
- [x] composition/provider 层负责注入实现列表。
- [x] `AppDataMigrator` 不再 import features。
- [x] 补迁移器单元测试：无修复服务、单服务失败、多服务部分成功。

### 子阶段 B：缓存治理注册化

涉及文件：

- `lib/core/cache/app_cache_governance_service.dart`
- `lib/features/search/application/search_hit_cache_service.dart`
- `lib/features/source/application/source_health_persistence_service.dart`

任务：

- [x] 抽 `AppCacheParticipant` 或类似接口。
- [x] feature 自己注册清理/统计能力。
- [x] core 只遍历 participant，不感知具体 feature。
- [x] 保持现有缓存清理入口行为不变。

### 子阶段 C：session/source access 边界

涉及文件：

- `lib/core/auth/session_cleaner.dart`
- `lib/core/source_access/source_access_provider.dart`
- `lib/features/mine/application/remote_access_snapshot_service.dart`
- `lib/features/auth/providers.dart`

任务：

- [x] 把 session 清理需要的远程访问快照能力抽成 core 接口。
- [x] source access 不直接 import auth feature provider，改由 app composition 层连接。
- [x] 加 architecture guard 脚本或 lint 规则，防止 core 新增 features import。

### 验收

- [x] `rg "features/" lib/core` 无新增违规；已豁免项必须写明原因。
- [x] core 相关服务可不依赖 Flutter widget 环境独立测试。
- [x] 原有登录、缓存清理、迁移流程不回归。

### 回滚

- [ ] 每个子阶段独立提交。
- [x] 接口化保持旧实现逻辑，回滚只需要恢复注入方式，不涉及数据结构变化。

### 2026-06-19 补充记录

- `PreferenceRepairService`、`SessionCleanupParticipant` 已作为 core 抽象落地。
- `AppCacheGovernanceService` 不再 import search/source feature；`buildDefaultFeatureCacheStores()` 在 app 层注册搜索命中缓存和书源健康缓存。
- `source_access_provider.dart` 通过 `sourceAccessTokenReaderProvider` 获取 token，app 根 `ProviderScope` 负责接入 auth session store。
- 验证：`rg "features/" lib/core` 无结果。

---

## 5. Phase 3：状态管理收敛

**目标**: 降低 ChangeNotifier 与 Riverpod 混用带来的监听和测试复杂度，但不冒进重写稳定链路。
**建议周期**: 1-2 周
**建议分支**: `codex/review-v130-state`

### 子阶段 A：AppTaskManager

- [x] 梳理后台任务状态：任务列表、进度、失败、完成、取消。
- [x] 先增加 Riverpod facade/provider 包装现有 `AppTaskManager`。
- [x] 补测试覆盖任务新增、进度更新、取消、失败。
- [x] 再决定是否迁移到 `Notifier` 或 `StateNotifier`。

### 子阶段 B：ReaderAudioController

这块近期刚处理过听书链路，迁移需谨慎。

- [x] 先写现状测试：播放、暂停、停止、跳转、倍速、章节切换、音频 URL 异常。
- [x] 抽 `ReaderAudioState` 只读快照，UI 优先依赖 state 快照。
- [x] 保留底层播放器控制类，Riverpod 只管理状态和生命周期。
- [x] 分两步迁移 UI 监听，避免一次性改动听书阅读器。

### 验收

- [x] 听书阅读器可正常进入正确 UI。
- [x] 音频播放控制不回归。
- [x] 后台任务状态不丢失、不重复通知。
- [x] 关键测试覆盖通过。

### 回滚

- [x] 先 facade 后替换，任何问题可切回现有 ChangeNotifier 实现。

### 2026-06-19 补充记录

- `AppTaskManager` 保持 ChangeNotifier，先通过 `appTaskSnapshotsProvider` / `activeAppTaskProvider` 暴露 Riverpod facade；暂不迁移 Notifier，避免扩大后台任务链路风险。
- `ReaderAudioControllerState` 已作为只读快照存在；本轮只补测试和错误分类，不替换底层播放器控制类。
- Phase 3 结论：进入 Phase 4 前不做状态管理大迁移，页面拆分只消费现有 facade/state。

---

## 6. Phase 4：超大文件拆分

**目标**: 逐步拆分 God Class，减少多人协作冲突和隐藏 bug。
**建议周期**: 4-8 周，按页面持续交付
**建议分支**: 按页面单独分支
**状态**: 已启动（2026-06-19 Book Detail 第一刀）

### 拆分顺序

状态口径：`完成度` 按对应页面/文件的整体现有职责拆分估算；`第一刀完成` 只表示已拆出一个低风险职责并通过验证，不等于该序号页面/文件全部完成。

| 顺序 | 文件 | 原因 | 第一刀 | 完成度 | 当前状态 |
|---:|---|---|---|---:|---|
| 1 | `book_detail_page.dart` | 正在暴露详情/目录错误反馈问题 | 错误态、操作区、目录区 | 100% | 已完成本轮拆分；保留业务流在页面/part 内 |
| 2 | `bookshelf_page.dart` | 高频入口且曾出现网格 overflow | 书籍卡片、更多菜单、筛选 header | 100% | 已完成本轮拆分；保留书架业务流在页面/part 内 |
| 3 | `reader_page.dart` | 核心链路，风险最高 | 只拆纯 UI，不改翻页/进度核心 | 0% | 未开始 |
| 4 | `private_book_sources_page.dart`（实际路径：`lib/features/mine/presentation/private_book_sources_page.dart`） | 书源管理高频迭代 | 列表、批量操作、分组筛选 | 30% | 第一刀完成：列表项、筛选规则、分组选择与单项菜单已拆；当前页面未实现批量操作入口 |
| 5 | `advanced_theme_service.dart` | service 职责过重 | 导入解析、资源索引、应用策略 | 15% | 第一刀完成：资源引用索引；整文件未完成 |
| 6 | `advanced_theme_editor_page.dart` | UI 复杂且易回归 | 资源列表、预览、底部操作 | 20% | 第一刀完成：资源 picker 基础组件；整页未完成 |

### 每个页面统一拆分流程

- [x] 先写页面职责清单，标明哪些逻辑不允许本轮改。
- [x] 提取纯 widget，不动业务状态。
- [x] 提取 presenter/view model，减少页面直接拼复杂状态。
- [ ] 最后才迁移 provider 或 service。
- [ ] 每次提交控制在 1-3 个明确职责内。

### Book Detail 第一阶段建议

- [x] 抽 `BookDetailErrorPresenter`：统一详情/目录/正文前置错误展示。
- [x] 整理 heroTag 构建逻辑，减少重复。
- [x] 抽 `BookDetailPrimaryActions` 已有组件周边逻辑，保留行为不变。
- [x] 抽目录区域组件，目录失败时显示诊断入口。

### Bookshelf 第一阶段建议

- [x] 修复/固化书架网格 item 高度，避免文本或状态变化造成 overflow。
- [x] 抽书籍卡片组件并补 widget test。
- [x] 抽更多操作 sheet，统一底部安全区。
- [x] 拆筛选/排序状态，不让页面 build 监听过多 provider。

### 验收

- [ ] 拆分前后 golden 或截图对比不出现明显 UI 回归。
- [x] 页面主流程 smoke 通过。
- [x] 每拆一个页面，至少新增或迁移 2-3 个测试。

### 回滚

- [x] 每次拆分只移动职责，不同时改交互。
- [ ] 提取组件失败时可直接回滚对应提交。

### 2026-06-19 Book Detail 第一刀记录

- 提取 `BookDetailErrorPresenter` 到 `book_detail_content_sections.dart`，只移动错误态 UI 组合，不改变 `_load`、换源、诊断复制等业务回调。
- 提取 `BookDetailTocWarningPresenter`，只移动目录警告诊断入口按钮，不改变目录加载、目录搜索或弹窗行为。
- 新增 widget test 覆盖错误态重试/换源/复制诊断，以及目录警告复制诊断。
- 验证：`flutter analyze lib/features/book/presentation/widgets/book_detail_content_sections.dart lib/features/book/presentation/book_detail_page_view.dart test/features/book/presentation/book_detail_sections_test.dart`
- 验证：`flutter test test/features/book/presentation/book_detail_sections_test.dart`

### 2026-06-19 Book Detail 第二刀记录

- 完成度：25% -> 35%。
- 提取 `BookDetailHeroTagResolver`，统一封面、标题、meta、阅读器封面、loading 封面和桌面编辑封面的 heroTag 构建规则。
- 新增 presentation test 覆盖显式 route tag、默认 source/book/detailUrl tag、loading/editor 派生 tag。
- 验证：`flutter analyze lib/features/book/presentation/book_detail_page.dart lib/features/book/presentation/book_detail_page_actions.dart lib/features/book/presentation/book_detail_hero_tags.dart test/features/book/presentation/book_detail_hero_tags_test.dart test/features/book/presentation/book_detail_sections_test.dart`
- 验证：`flutter test test/features/book/presentation/book_detail_hero_tags_test.dart`
- 验证：`flutter test test/features/book/presentation/book_detail_sections_test.dart`

### 2026-06-19 Book Detail 收尾记录

- 完成度：35% -> 100%。
- 提取 `BookDetailQuickActionsPresenter` 和 `BookDetailQuickActionsState`，页面不再直接拼装主操作按钮启用/禁用状态。
- 提取 `BookDetailMobileTocWarningPlacement`，统一目录警告在移动端/桌面端的放置策略，诊断入口仍由 `BookDetailTocWarningPresenter` 提供。
- 本轮完成口径：Book Detail 展示/UI 责任拆分完成；加载、换源、阅读跳转、元数据保存等业务流保持在页面 part 内，不在本轮迁移。
- 验证：`flutter analyze lib/features/book/presentation/book_detail_page.dart lib/features/book/presentation/widgets/book_detail_content_sections.dart lib/features/book/presentation/widgets/book_detail_quick_actions_presenter.dart test/features/book/presentation/book_detail_primary_actions_test.dart test/features/book/presentation/book_detail_sections_test.dart`
- 验证：`flutter test test/features/book/presentation/book_detail_primary_actions_test.dart`
- 验证：`flutter test test/features/book/presentation/book_detail_sections_test.dart`
- 验证：`flutter test test/features/book/presentation/book_detail_hero_tags_test.dart`

### 2026-06-19 Bookshelf 收尾记录

- 完成度：0% -> 100%。
- 既有 `BookshelfGridSliver`、`BookshelfCoverLayoutResolver`、`BookshelfGridBookCardShell`、`BookshelfListBookCardShell` 已承接书籍卡片和固定高度/宽度策略；本次补齐测试常量，固化当前网格高度规则。
- 提取 `BookshelfBookMoreMenuPresenter`，页面不再直接拼装单本书更多菜单项和阅读状态子菜单。
- 提取 `BookshelfHeroTagResolver`，统一书架到详情页的封面、标题、meta heroTag 构建规则。
- 提取 `BookshelfFilterHeaderPresenter`，统一搜索摘要、quick filter 显示条件和 header 高度计算。
- 本轮完成口径：Bookshelf 第一阶段展示/UI 与筛选 header 拼装拆分完成；加载、导入、删除、打开阅读、批量操作等业务流保持在页面 part 内，不在本轮迁移。
- 验证：`flutter analyze lib/features/bookshelf/presentation/bookshelf_page.dart lib/features/bookshelf/presentation/bookshelf_page_sections.dart lib/features/bookshelf/presentation/bookshelf_hero_tags.dart lib/features/bookshelf/presentation/bookshelf_filter_header_presenter.dart lib/features/bookshelf/presentation/widgets/bookshelf_book_more_menu_presenter.dart test/features/bookshelf/presentation/bookshelf_presenters_test.dart`
- 验证：`flutter test test/features/bookshelf/presentation/bookshelf_presenters_test.dart`
- 验证：`flutter test test/features/bookshelf/presentation/bookshelf_grid_sliver_test.dart`
- 验证：`flutter test test/features/bookshelf/presentation/bookshelf_card_width_smoke_test.dart`
- 验证：`flutter test test/features/bookshelf/presentation/bookshelf_cover_layout_resolver_test.dart`
- 验证：`flutter test test/features/bookshelf/presentation/bookshelf_page_smoke_test.dart`

### 2026-06-19 Private Book Sources 第一刀记录

- 完成度：0% -> 30%。
- 提取 `PrivateBookSourceListFilter`，页面不再直接拼接书源关键词搜索文本；搜索仍覆盖名称、描述、分组、审核/配置/检测状态和展示标签。
- 提取 `PrivateBookSourceGroupFilterPresenter`，统一分组筛选按钮的选中标签和失效分组回退判断。
- 提取 `PrivateBookSourceTile` 与 `PrivateBookSourceMoreMenuButton`，列表项展示和单项更多菜单从 4000+ 行页面中移出；提交共享/编辑启用规则通过 `PrivateBookSourceMoreMenuRules` 固化。
- 本轮完成口径：列表展示、关键词筛选、分组筛选、单项操作菜单第一刀完成；创建/编辑表单、导入、检测 sheet、分组管理 sheet、服务调用和 provider 流程保持在页面内，不在本轮迁移。路线图里的“批量操作”在当前页面未发现入口，本轮不虚构拆分，后续若新增批量选择再进入单独序列。
- 验证：`flutter analyze lib/features/mine/presentation/private_book_sources_page.dart lib/features/mine/presentation/private_book_source_filter_presenter.dart lib/features/mine/presentation/widgets/private_book_source_more_menu_button.dart lib/features/mine/presentation/widgets/private_book_source_tile.dart test/features/mine/presentation/private_book_source_filter_presenter_test.dart test/features/mine/presentation/private_book_source_presentation_test.dart`
- 验证：`flutter test test/features/mine/presentation/private_book_source_filter_presenter_test.dart`
- 验证：`flutter test test/features/mine/presentation/private_book_source_presentation_test.dart`

### 2026-06-19 Advanced Theme 第一刀记录

- `AdvancedThemeResourceReferenceService` 承接主题资源引用索引，`AdvancedThemeService.deleteTheme` 只保留删除流程编排和资源清理调用。
- 提取 `AdvancedThemeResourcePickerSheet`、`AdvancedThemeImageSelectionGrid`、`AdvancedThemeGalleryPreviewThumb`、`AdvancedThemeBottomNavGalleryPreview` 等纯 UI，`advanced_theme_editor_page.dart` 保留状态读取和业务回调。
- 新增 application test 覆盖资源引用索引，新增 widget test 覆盖资源 picker sheet 和图片选择网格。
- 验证：`flutter analyze lib/features/mine/application/advanced_theme_service.dart lib/features/mine/application/advanced_theme_resource_reference_service.dart lib/features/mine/presentation/advanced_theme_editor_page.dart lib/features/mine/presentation/widgets/advanced_theme_resource_picker_widgets.dart test/features/mine/application/advanced_theme_resource_reference_service_test.dart test/features/mine/presentation/advanced_theme_editor_sections_test.dart`
- 验证：`flutter test test/features/mine/application/advanced_theme_resource_reference_service_test.dart`
- 验证：`flutter test test/features/mine/presentation/advanced_theme_editor_sections_test.dart`

---

## 7. Phase 5：性能与 UI 架构优化

**目标**: 在稳定性和结构边界改善后，再处理 rebuild、列表 key、AnimatedBuilder 等性能项。
**建议周期**: 2-4 周，可穿插在页面拆分后半段

### 任务 1：Bookshelf rebuild 收敛

- [ ] 将 `bookshelf_page.dart` 中多个 `ref.watch` 拆到局部 `Consumer`。
- [ ] 对导航样式、搜索关键字、主题外观拆分监听范围。
- [ ] 用 DevTools 或日志确认重建范围下降。

### 任务 2：列表 key 策略

- [ ] 搜索结果、书架列表、书源列表、分组列表补稳定 `ValueKey`。
- [ ] 排序/筛选/批量选择场景验证状态不串。
- [ ] 不对纯静态列表强行加复杂 key。

### 任务 3：AnimatedBuilder 优化

- [ ] 检查 `reader_page_shell.dart` 动画 builder 是否每帧创建重组件。
- [ ] 将稳定 child 传入 `AnimatedBuilder.child`。
- [ ] 对 Offset、Tween、Decoration 等可复用对象做局部缓存。

### 验收

- [ ] 低端 Android 设备滚动和页面转场无明显 jank。
- [ ] 列表排序/筛选后选择态不串。
- [ ] 性能优化不改变视觉和交互。

---

## 8. Phase 6：自动化护栏

**目标**: 防止同类问题反复出现，让 review 从人工提醒变成持续约束。
**建议周期**: 1 周
**建议分支**: `codex/review-v130-guardrails`

### 任务

- [ ] 新增架构检查脚本：禁止 `lib/core/**` import `features/**`，允许白名单。
- [ ] 新增文件体积监控脚本：超过 2500 行 warning，超过 4000 行 require 说明。
- [ ] 新增 catch 审计脚本：统计 `catch (_)`、空 catch、只 return false 的 catch。
- [ ] 将检查接入本地命令或 CI，不先设置为强失败，先观察 1-2 个版本。
- [ ] 更新 `docs/standards/development_architecture_guardrails.md` 或新增补充章节。

### 验收

- [ ] 可以一条命令生成架构/文件体积/catch 审计报告。
- [ ] 新增违规能被发现。
- [ ] 不因为历史问题阻塞当前发版，先以 warning 模式运行。

---

## 9. 建议排期

| 时间 | 目标 | 交付 |
|---|---|---|
| 本周 | Phase 0 + Phase 1 | 发版前稳定性，错误诊断和 stream 生命周期收口 |
| 下周 | Phase 2 | core/features 边界第一批接口化 |
| 第 3 周 | Phase 3 | AppTaskManager facade、ReaderAudioController 测试基线 |
| 第 4-6 周 | Phase 4 | Book Detail、Bookshelf 第一轮拆分 |
| 第 7-8 周 | Phase 5 | rebuild、key、动画性能优化 |
| 持续 | Phase 6 | 架构护栏和审计脚本进入常规检查 |

---

## 10. 发版策略

### 可以跟随小版本发

- 错误信息补强
- 局部资源释放修复
- catch 日志补充
- 纯 UI 组件提取且行为不变

### 建议单独灰度

- ReaderAudioController 状态迁移
- ReaderPage 拆分
- Book Detail 加载状态重构
- Bookshelf 大面积 provider 拆分

### 不建议和书源网关发版同窗口混合

- Reader 正文加载策略变化
- 搜索范围协议变化
- 书源分组/权限逻辑变化
- 任何会改变本地数据库结构的迁移

---

## 11. 每阶段完成模板

每个阶段完成后，在对应 PR 或提交说明中补充：

```text
阶段：
改动范围：
影响链路：
验证命令：
手动验收：
已知风险：
回滚方式：
```

---

## 12. 当前下一步建议

优先启动 Phase 1，不要先做大架构拆分：

- [x] 详情页失败诊断补强。
- [x] 目录/正文/听书失败诊断补强。
- [x] 核心 catch 块从吞错改成结构化日志。
- [x] 给已修复的 `ChapterCacheService.cacheRange()` 增加异常关闭测试。

这样能直接服务当前“书源检测通过但阅读端详情/目录/正文失败难定位”的问题，也不会打乱即将发版的后端和移动端节奏。
