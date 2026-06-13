# 项目文档未完成项总梳理

**日期**: 2026-06-13  
**目标**: 把当前 docs 里的未勾选项按发版风险和长期收益重新分层，避免把历史治理清单、审计建议、发版必测项混成一锅。

---

## 1. 总判断

当前未完成项很多，但不能按数量理解为“还有几百个任务没做”。它们主要分成四类：

1. **发版前必须验证**: 主要集中在 Reader 真机 release smoke、缓存清理/命中回归、书源核心链路回归。
2. **近期建议做**: Mine 私有书源/高级主题、Bookshelf 大页拆分、Search/Book 关键链路、Design System 基础件。
3. **长期治理**: UI/UX 全局治理、跨端标准、存储治理、自动阅读/多模态阅读完整能力。
4. **不建议本轮做**: 全量 Hive 替换、全量 easy_debounce 替换、全量 Riverpod 化、替换 turnable_page、一次性开启严格 lint。

结论：**本轮不要继续大重构，先把 Reader + 缓存 + 书源核心链路做发版前验证。** 验证通过后，下一阶段优先做 Mine/高级主题/私有书源和 Bookshelf，不建议把 UI 治理大清单直接当当前任务。

---

## 2. 现在应该做：发版前收口

### R0：Reader Android release 真机验证

来源：

- `docs/features/reader/reader-reasonable-architecture-refactor-plan-2026-06-13.md`
- `docs/features/reader/reader-architecture-hardening-plan-2026-06-13.md`
- `docs/features/reader/reader-refactoring-development-plan-3-2026-06-13.md`

必须执行：

- [ ] Android release 包验证纸页卷动：连续翻页、跨章节、快速点击、返回再进入。
- [ ] Android release 包验证上一章/下一章：底部 chrome、点击分区、键盘/音量键如可用。
- [ ] 收集 `reader.navigation_command`、`reader.paper_curl_adapter_result`、`reader.paper_curl` 日志样本。
- [ ] 记录是否还存在“闪字”“纸页变仿真”“点击无响应”。
- [ ] 验证设置页：打开、切换分组、拖动 slider、字体弹窗、背景选择/删除、应用/关闭。
- [ ] 验证 chrome/content 模式：顶部/底部 chrome、触摸输入、目录、自动阅读、长按选择、标注。
- [ ] 验证背景/主题切换：无明显闪烁；如果有，日志能定位 rebuild 层。

判断：**必须做。** 现在 Reader 架构边界已经做了不少，继续大拆收益不如 release 真机验证高。真机验证不通过时，再按日志定位 adapter/gate/runtime/hit-test，而不是继续凭感觉重构。

### C0：缓存治理发版验证

来源：

- `docs/features/reader/cache-architecture-refactor-plan-2026-06-13.md`
- `docs/features/reader/reader-architecture-hardening-plan-2026-06-13.md`

必须执行：

- [ ] 二次打开在线章节命中章节缓存。
- [ ] 翻页分页能命中分页缓存，并能恢复正确页码。
- [ ] 清理章节缓存后能重新加载。
- [ ] 清理分页缓存后能重新分页。
- [ ] 清理图片缓存后图片能重新下载。
- [ ] 登录切换用户后 API 缓存不串号。
- [ ] 会员权益接口不使用旧缓存。
- [ ] 搜索命中缓存不串号。
- [ ] 书源健康状态不被旧缓存覆盖。
- [ ] 冷启动不扫描大缓存目录。

建议顺手补的小项：

- [ ] 给图片缓存增加容量统计和清理入口的可观测性。
- [ ] 增加缓存管理页 widget smoke test。
- [ ] 给缓存 API 标记“是否登录态敏感”的文档字段。

判断：**验证必须做，小项可做但不应扩大成 Hive 迁移。** 当前缓存协议已经收口，本轮核心是证明不会串号、不会误清用户资产、不会导致阅读空白页。

### S0：书源核心链路回归

来源：

- `docs/features/reader/book-source-ecosystem-simplification-plan.md`
- `docs/features/book_source/book_source_sharing_search_flow.md`
- `docs/project-comprehensive-phased-development-tasks-2026-06-13.md`

必须执行：

- [ ] 我的书源增删改查、分组增删改查走 Rust，Go 不再承接移动端旧生命周期接口。
- [ ] 单源新增/编辑只接受单个书源对象，数组/包装格式提示走导入。
- [ ] 检测失败源不从搜索范围隐藏，只展示检测失败标签。
- [ ] 搜索范围懒加载展示用户全部可用源，并展示私人/共享、分组名、检测状态。
- [ ] 未登录进入我的书源显示“请登录后查看”。
- [ ] 删除书源、删除分组后列表不残留。

判断：**核心回归必须做。** 私人导入/导出、批量导入数量额度属于下一阶段产品能力，不建议卡本次发版，除非本轮发版明确要带私人导入/导出。

---

## 3. 近期建议做：发版后第一批

### P1：Mine 私有书源 / 高级主题 / 会员外观

来源：

- `docs/project-comprehensive-phased-development-tasks-2026-06-13.md`
- `docs/features/reader/advanced_theme_experience_optimization.md`

建议拆票：

- [ ] 拆 `private_book_sources_page.dart`：列表 item、筛选/分组 header、空态/错误态、底部操作 sheet。
- [ ] 私有书源 presenter/view model 化，UI 不直接拼检测状态、登录态、分组状态。
- [ ] 拆 `advanced_theme_service.dart`：导入解析、资源索引、校验、应用、预览分开。
- [ ] 拆 `advanced_theme_editor_page.dart`：整体预览、应用背景、阅读背景、封面图集、启动图集、底栏图集独立组件。
- [ ] 高级主题资源标签明确：默认、当前主题、高级主题引用资源。
- [ ] 统一会员入口 bottom sheet 安全区，避免被底部导航遮挡。

判断：**建议发版后优先做。** 这里是近期 bug 高发区，但不建议和 Reader release 验证继续混在同一个阶段。

### P2：Bookshelf 书架治理

来源：

- `docs/project-comprehensive-phased-development-tasks-2026-06-13.md`

建议拆票：

- [ ] 抽书籍卡片组件，移动端更多按钮可改竖向 more icon。
- [ ] 抽书籍更多 bottom sheet，统一安全区。
- [ ] 抽排序/筛选/分组 header presenter。
- [ ] 本地书详情优先本地数据，避免不必要网络请求。
- [ ] 检查列表懒加载和封面加载策略。

判断：**建议做，但排在 Reader 发版验证之后。** 书架是高频入口，大文件风险真实存在。

### P3：Search / Book 关键链路

来源：

- `docs/project-comprehensive-phased-development-tasks-2026-06-13.md`

建议拆票：

- [ ] 拆 `book_detail_page.dart`：头图/信息、目录、书源状态、操作区、错误态。
- [ ] 搜索结果 item、失败标签、书源范围选择迁移成组件。
- [ ] 搜索范围页面继续保持懒加载，不一次性加载所有源。
- [ ] 补测试：搜索取消、失败源展示、范围筛选、登录态。

判断：**建议作为第二批治理。** 搜索范围和书源标签如果本轮已经稳定，更多组件拆分可以后置。

### P4：Design System 最小基础件

来源：

- `docs/project-comprehensive-phased-development-tasks-2026-06-13.md`
- `docs/ui_ux/ui_governance_phased_task_checklist.md`

建议拆票：

- [ ] 建立 tokens：spacing、radius、duration、elevation、breakpoints。
- [ ] 统一 Button、Input、BottomSheet/Dialog frame、Loading/Empty/Error、Card/ListTile。
- [ ] 选 Mine 或 Bookshelf 的低风险页面试点，不迁移 Reader。

判断：**建议做最小版本，不做全局迁移。** 这个能减少后续页面拆分返工，但如果做成全项目 UI 大重构，会拖慢发版。

---

## 4. 后置：保留未勾但暂不执行

### H1：Hive 缓存试点

来源：

- `docs/features/reader/cache-architecture-refactor-plan-2026-06-13.md`
- `docs/project-hand-rolled-vs-library-full-scan-2026-06-13.md`

后置原因：

- 缓存协议已接入，章节缓存继续用 Drift，分页缓存继续用内存 LRU + 文件 backend。
- 现在引入 Hive 会带来新依赖、迁移读 fallback、双写、回滚策略和数据兼容测试。
- 当前发版目标是稳定，不是换存储引擎。

判断：**本轮不做。** 后续如要做，必须先建 benchmark 分支，不要在主线直接迁移。

### H2：全量 Timer/Debounce 替换

来源：

- `docs/project-hand-rolled-vs-library-full-scan-2026-06-13.md`

后置原因：

- Timer 不都是 debounce，有些是动画、阅读进度、runtime settle、auto-read 生命周期。
- 全量替换可能破坏 dispose、controller 生命周期和测试时序。

判断：**不做全量替换。** 只在新代码或明确重复的 UI debounce 场景试点。

### H3：Reader 内容加载状态机 / 换源状态机

来源：

- `docs/features/reader/reader-architecture-hardening-plan-2026-06-13.md`

后置原因：

- 这是正确方向，但风险高，容易牵动章节定位、阅读进度、缓存恢复、书源切换。
- 当前 Reader 已完成 command/gate/overlay/page-turn/runtime 第一层收口，下一步应先真机验证。

判断：**先不做。** 如果真机验证仍暴露内容加载/分页恢复问题，再针对问题抽状态机。

### H4：多模态阅读完整清单

来源：

- `docs/features/reader/reader_multimodal_*`
- `docs/features/reader/reader_auto_read_execution_plan_2026-05-24.md`

后置原因：

- 这些是长期能力清单，覆盖 PDF、漫画、绘本、听书、fixed-layout EPUB。
- 不应作为当前 Reader 纸页/上一章下一章 bug 的发版阻塞。

判断：**保留为长期回归清单。** 只有改到对应模式时再执行对应子集。

### H5：全局 UI/UX 治理大清单

来源：

- `docs/ui_ux/ui_governance_phased_task_checklist.md`
- `docs/ui_ux/ui_ux_review_standards_and_optimization.md`

后置原因：

- 这些是治理框架，不是当前版本的代码任务。
- 未勾选数量大，但大多数不是当前发版缺口。

判断：**不作为本轮任务。** 只抽出 Design System 最小基础件和高频 bug 页面治理。

---

## 5. 建议标记为历史或改口径的文档

这些文档有价值，但容易误导后续 AI 或开发同学，需要加“已被新文档覆盖/仅作背景”的说明：

- [ ] `docs/features/reader/book-source-compatibility-complete-plan.md`: 旧双 JSON + 登录 + WebView 长期战略，当前应以 `book-source-ecosystem-simplification-plan.md` 为准。
- [ ] `docs/features/reader/dual-json-implementation-guide-for-gpt.md`: 旧实施指南，当前 Rust 统一规整和 `runtime_source_json` 口径已经变化。
- [ ] `docs/features/reader/dual-json-implementation-checklist.md`: 与新书源生态方案有重复，建议转为历史参考。
- [ ] `docs/project-hand-rolled-vs-library-full-scan-2026-06-13.md`: “可替换比例/性能提升”偏乐观，建议标记为审计素材，不作为直接执行计划。
- [ ] `docs/project-comprehensive-assessment-2026-06-13.md`: Reader 行数、完成度、纯 Dart、共享组件占比、Hero 数量等口径需刷新。
- [ ] `docs/document_cleanup_checklist.md`: 里面“所有 reader 旧执行计划可归档”的说法需要谨慎，当前 Reader 多份 2026-06-13 文档仍在使用。

判断：**建议做文档治理，但不要影响发版。** 最简单做法是在这些文件顶部加“状态说明”，避免以后继续按旧方案执行。

---

## 6. 当前推荐执行顺序

### 发版前

1. [ ] Reader Android release 真机 smoke 和日志采样。
2. [ ] 缓存命中/清理/串号发版验证。
3. [ ] 书源核心链路回归：CRUD、分组、检测标签、搜索范围、登录态。
4. [ ] `flutter analyze` + 已有 reader/cache/source 相关测试。
5. [ ] 只修验证中暴露的真实 bug，不继续扩大重构。

### 发版后第一批

1. [ ] Mine 私有书源页面拆分。
2. [ ] 高级主题 service/editor 拆分。
3. [ ] 会员/外观/bottom sheet 安全区统一。
4. [ ] Bookshelf 卡片、更多弹窗、删除弹窗拆分。
5. [ ] Design System 最小基础件。

### 后续长期

1. [ ] Search / Book 详情关键链路组件化。
2. [ ] Reader 内容加载状态机、换源状态机。
3. [ ] Hive benchmark 分支评估，不直接主线迁移。
4. [ ] UI/UX 全局治理按页面分批执行。
5. [ ] 多模态阅读完整回归清单按功能触发执行。

---

## 7. 不建议本轮继续做的事

- [ ] 不继续为了行数拆 Reader 核心 part。
- [ ] 不替换 `turnable_page`，除非 release trace 证明 adapter 本身不可控。
- [ ] 不全量把缓存迁到 Hive。
- [ ] 不全量替换 Timer/Debounce。
- [ ] 不一次性迁移 Design System 到全项目。
- [ ] 不把 Mine、Bookshelf、Reader 三个高风险模块同时大改。
- [ ] 不把历史 UI/UX 治理清单当发版阻塞。

