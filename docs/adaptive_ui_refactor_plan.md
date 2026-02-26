# 跨页面自适应修复计划（Adaptive UI Refactor Plan）

更新时间：2026-02-26

## 执行状态（截至 2026-02-26）

- [x] P0-01 已执行：详情页操作区已改为基于局部宽度分支，宽屏可显示完整文案（开始阅读/移出书架）。
- [x] P0-01a 已执行：根据实机反馈下调短文案阈值，避免大屏手机仍停留在“阅读/移出”。
- [x] P0-02 已执行：书架网格列数已改为基于 `SliverLayoutBuilder` 局部宽度计算。
- [ ] P1-01 未执行：断点语义层尚未统一。
- [ ] P1-02 未执行：多页面 `maxWidth` token 尚未收敛。
- [ ] P1-03 未执行：BottomSheet 高度策略尚未统一。
- [ ] P2-01 未执行：关键展示页断点回归测试尚未补齐。

## 背景与目标

当前多页面在不同手机上呈现“几乎同形态”，未体现大屏手机应有的信息密度与布局差异。  
本计划目标是统一断点口径、修正宽度测量方式，并建立可回归的适配测试矩阵。

## 当前问题（已定位）

### P0（必须优先修复）

- P0-01：小说详情页操作按钮文案/图标分支几乎不可达
  - 文件：`lib/features/book/presentation/book_detail_page.dart`
  - 位置：`LayoutBuilder` + `perButtonWidth` + `useShortLabels/hideActionIcons`
  - 现象：高分辨率手机与小屏手机显示几乎一致（都走短文案/隐藏图标）
  - 根因：阈值绑定在“封面右侧剩余宽度”，不是页面级可用宽度

- P0-02：部分网格列数使用全局宽度计算，忽略局部约束
  - 文件：`lib/features/bookshelf/presentation/bookshelf_page.dart`
  - 位置：`_buildBookGridSliver` 使用 `MediaQuery.sizeOf(context).width`
  - 风险：在 `NavigationRail`/分栏/受约束容器中列数计算失真，导致拥挤

### P1（高优先级）

- P1-01：断点体系过粗，360/390 宽度落在同策略桶
  - 文件：`lib/app/layout/app_layout.dart`
  - 风险：小屏与大屏手机视觉差异被抹平

- P1-02：多个页面存在分散的 `maxWidth` 常量与局部分支规则
  - 文件：`lib/features/mine/presentation/*.dart`
  - 风险：同样宽度下页面行为不一致，维护成本高

- P1-03：BottomSheet 高度分支多基于全局宽度，非局部约束
  - 文件：`book_detail_page.dart` / `reader_page.dart` / `source_filter_sheet.dart`
  - 风险：在嵌套布局或未来多窗体场景不稳定

### P2（质量保障）

- P2-01：缺少关键展示页面的断点回归测试
  - 现状：已有 `test/app/layout/adaptive_breakpoints_test.dart`，但覆盖不足
  - 风险：后续改动易回归

## 技术方案

### 1）统一断点与尺寸策略（先基础设施）

- 在 `AppLayout` 新增语义断点层：
  - `compact`：`< 360`
  - `regularPhone`：`360-389`
  - `largePhone`：`390-479`
  - `phoneXL`：`480-599`
  - `medium`：`600-839`
  - `expanded`：`>= 840`
- 保留现有常量兼容，但逐步迁移业务分支到语义断点 API。

### 2）统一“测量口径”（全局 vs 局部）

- 页面级布局决策：允许使用 `MediaQuery.sizeOf(context).width`。
- 子树级布局决策：统一使用 `LayoutBuilder.constraints.maxWidth`。
- 明确禁用模式：
  - 在受约束子树里用全局宽度算列数/按钮文案分支。

### 3）小说详情页重构（首个样板页）

- 当前实现：详情头部保持“封面 + 信息 + 操作区”同块布局，
  操作区位于信息列内并基于局部宽度分支。
- 按钮策略：
  - `compact`：短文案，可隐藏图标；
  - `largePhone` 及以上：完整文案 + 图标；
  - `medium/expanded`：更大内边距与最小高度。

### 4）网格策略统一

- 网格优先使用“目标单元宽度”推导列数：
  - 可选：`SliverGridDelegateWithMaxCrossAxisExtent`；
  - 或统一封装 `resolveGridColumns(maxWidth, minTileWidth, maxColumns)`。
- 避免为单页面硬编码特例（例如仅针对某个 `itemCount` 强制列数）。

### 5）页面宽度 token 化

- 新增统一内容宽度 token（示例）：
  - `contentNarrow`、`contentRegular`、`contentWide`
- `mine`/`settings`/`about` 等页统一使用 token，而不是各自写 `700/760/860/920/1080`。

### 6）BottomSheet 高度策略统一

- 统一入口：`resolveSheetHeightFactor(widthBucket)`。
- 优先读取当前上下文可用宽度（必要时通过 `LayoutBuilder` 传入）。

## 分阶段执行计划

### Phase 0：基线与观测（0.5 天）

- [ ] 建立断点调试信息（仅 debug 构建启用）：
  - 页面宽度、局部宽度、命中断点、关键分支。
- [ ] 输出对照截图：`320 / 360 / 390 / 430 / 480 / 600 / 840`。

### Phase 1：基础设施（1 天）

- [ ] 扩展 `AppLayout` 语义断点 API。
- [ ] 提供统一辅助方法：
  - `isCompact` / `isLargePhoneUp` / `isMediumUp` / `resolveWidthBucket`。
- [ ] 不改业务外观，只接入基础能力。

### Phase 2：小说详情页（1 天）

- [x] 重构详情头部布局与操作区。
- [x] 让“图标+完整文案”在 `largePhone` 起稳定生效。
- [ ] 补充页面级 widget 测试（断点矩阵）。

### Phase 3：网格与弹层（1-1.5 天）

- [x] 修正书架网格列数计算口径（改局部约束）。
- [ ] 统一 `book/source/reader` 的 sheet 高度分支入口。

### Phase 4：全站收敛（1-2 天）

- [ ] 收敛 `mine/settings/about/rule_config` 的 `maxWidth` 与间距 token。
- [ ] 清理重复断点判断与魔法数字。

### Phase 5：回归与冻结（0.5-1 天）

- [ ] 跑完整测试矩阵与人工验收。
- [ ] 输出变更说明与后续维护规范。

## 验收标准

- 不同手机宽度（特别是 `360` vs `390` vs `430`）有可感知布局差异。
- 小说详情页操作按钮在 `390+` 宽度默认显示“图标 + 完整文案”。
- 网格列数在分栏/受约束场景与视觉宽度一致。
- BottomSheet 在所有主流程中无遮挡、无拥挤、无错位。
- 新增测试通过，且能覆盖关键断点分支。

## 测试矩阵（最小）

- 宽度：`320 / 360 / 390 / 430 / 480 / 600 / 840 / 1024`
- 页面：
  - 书籍详情页（操作区文案/图标）
  - 书架页（网格列数）
  - 我的页（宫格密度）
  - 目录/筛选弹层（高度与头部布局）

## 风险与规避

- 风险：一次性改动过多导致 UI 波动
  - 规避：按 Phase 分批提交，先详情页样板后全站推广。
- 风险：断点变动引发测试脆弱
  - 规避：测试断言“语义行为”而非像素级硬编码。
- 风险：历史魔法数字残留
  - 规避：引入 lint/审查规则，新增布局代码必须走语义断点 API。
