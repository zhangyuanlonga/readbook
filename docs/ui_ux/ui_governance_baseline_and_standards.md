# UI 治理基线与标准收敛

**创建日期**: 2026-06-13  
**覆盖阶段**: Phase 0 基线盘点、Phase 1 标准收敛  
**结论**: 项目已有 UI Token、Theme、Adaptive 组件和状态组件基础。本轮治理采用收敛和补缺策略，不新建并行设计体系。

---

## 1. 基线结论

- [x] 不新增独立的 `AppDesignTokens` 总文件，避免与现有 `ThemeExtension` 和 Adaptive metrics 分裂。
- [x] 继续使用 `docs/standards/ui_adaptive_design_rules.md` 作为 UI 与自适应硬规范入口。
- [x] 继续使用 `docs/standards/development_architecture_guardrails.md` 作为架构与 UI 基线组件硬规范入口。
- [x] `docs/ui_ux/ui_governance_phased_task_checklist.md` 只作为阶段任务追踪文档。
- [x] 本轮试点限定在高级主题列表状态区域、书架状态卡和高级主题标题输入，不触碰 Reader 核心链路。

---

## 2. Token 与主题来源

| 领域 | 标准来源 | 使用规则 |
|---|---|---|
| 颜色 | `Theme.of(context).colorScheme`、高级主题 palette/backdrop | 页面和组件默认走主题色；真实资源色、封面占位、阅读器用户主题可例外 |
| 组件形态 | `AppComponentThemeTokens` | 卡片、按钮、输入、弹层、导航、选择控件的圆角、高度、边框、阴影参数从这里取 |
| 响应式布局 | `AppLayout`、`AppAdaptiveMetrics` | 页面 padding、gap、card radius、control height、dialog/sheet width 随断点和密度变化 |
| 通用尺寸 | `AppSpacing`、`AppSizeTokens` | 通用间距、触摸目标、内容最大宽度、控制高度 |
| 动效 | `AppMotion`、`AppMotionScope` | 动画时长、曲线、无障碍禁用动画 |
| 边框 | `resolveAppBorderSide`、`resolveAppBorderColor` | 需要统一边框语义时使用，避免局部随手调透明度 |
| 字体 | `AppTypography`、`ThemeData.textTheme` | 页面文字优先走主题字阶，局部字号需要说明业务原因 |

---

## 3. 组件来源

| 场景 | 优先组件 | 说明 |
|---|---|---|
| 页面骨架 | `AdaptivePageScaffold` | 新增页面默认使用；沉浸式、Reader、WebView 等说明例外 |
| 内容宽度 | `AdaptiveContentContainer` | 桌面/平板避免内容无限拉宽 |
| 分栏 | `AdaptiveSplitBody` | 详情、列表/详情等结构优先使用 |
| 网格 | `AdaptiveGridSliver` | 按可用宽度计算列数 |
| 搜索 | `AdaptiveSearchBar` | 搜索入口优先使用，不用新 `AppTextField` 重做搜索 |
| 过滤 | `AdaptiveFilterBar` | 筛选 chip、筛选入口优先使用 |
| 列表项 | `AdaptiveListTile`、`AdaptiveSettingTile` | 设置、简单列表和管理页优先使用 |
| 卡片 | `AdaptiveCard` | 通用卡片容器，优先读取 Adaptive metrics |
| 弹层 | `showAdaptiveActionSurface` | 移动端 bottom sheet，桌面/Web dialog |
| 空状态 | `AppEmptyStateCard` | 列表空态、筛选空态 |
| 错误/警告状态 | `AppStatusStateCard` | 错误、警告、局部失败和操作反馈 |
| 语义按钮 | `AppButton` | P0 补缺。用于业务语义明确、重复出现的操作按钮，不机械替换所有 Material Button |
| 表单输入 | `AppTextField` | P0 补缺。用于普通表单输入；搜索仍用 `AdaptiveSearchBar` |

---

## 4. 合法例外

- [x] Adaptive 组件内部可以调用 `showDialog`、`showModalBottomSheet` 等 Flutter 原生 API。
- [x] Theme、Token、palette 解析代码可以出现固定颜色值。
- [x] 阅读器正文主题、用户自定义主题、封面占位和真实资源颜色可以保留业务色。
- [x] 警示、错误、危险操作可以使用 `colorScheme.error` 或明确的危险色样式。
- [x] 单点强业务 UI 暂不抽到 app 基础组件，除非两个以上 feature 真实复用。
- [x] 已经由全局 Theme 统一且没有重复业务语义的 `FilledButton`、`TextButton`、`TextField` 可以暂时保留。

---

## 5. 成熟库优先标注

- [x] 成熟库能稳定解决的问题，不手搓底层能力。
- [x] 项目封装只负责统一主题、Token、动效、跨端降级、无障碍和性能边界。
- [x] 第三方库 API 不直接散落到业务页面；先进入 app 基础组件、core service 或 feature-local 组件。
- [x] 新增依赖前必须评估 Flutter 原生能力、现有依赖、维护活跃度、license、平台覆盖和包体影响。
- [x] 自研实现必须说明成熟库无法满足的原因，并保留未来替换成成熟库的退出条件。

优先采用成熟库或 Flutter 原生能力的场景：

| 场景 | 优先策略 |
|---|---|
| 骨架屏 | 使用现有 `shimmer`，封装 `AppSkeleton*` |
| 基础动效 | 使用现有 `flutter_animate` + `AppMotion`，不手写分散动画 |
| 滑动操作 | 使用现有 `flutter_slidable`，封装统一 action tile |
| 图片缓存 | 使用现有 `cached_network_image` / 项目图片缓存能力 |
| 图片预览缩放 | 按需评估 `photo_view`，不自行实现缩放手势和边界 |
| 拖拽排序 | 优先 Flutter 原生 `ReorderableListView`，不足再评估库 |
| 下拉刷新 | 优先 Flutter 原生 `RefreshIndicator`，封装统一样式 |
| 快捷键 | 优先 Flutter 原生 `Shortcuts` / `Actions` |
| 触觉反馈 | 优先 Flutter 原生 `HapticFeedback` |

---

## 6. 试点范围

### 已选试点

- [x] 高级主题列表会员锁定状态: 使用 `AdaptiveCard` 和 `AppButton` 收敛手写卡片和操作按钮。
- [x] 高级主题标题编辑输入: 使用 `AppTextField` 验证普通表单输入薄封装。
- [x] 书架状态卡操作按钮: 使用 `AppButton` 验证跨 feature 复用。

### 暂缓范围

- [x] Reader 翻页、章节定位、阅读进度、设置持久化核心链路暂缓。
- [x] Reader 目录和点击分区弹层暂不在本轮迁移，避免和阅读器重构并行冲突。
- [x] Mine、Bookshelf 大页面不做全量按钮和输入框替换。

---

## 7. 新增 UI Review Checklist

- [ ] 是否使用现有 Token 或说明例外。
- [ ] 是否优先采用 Flutter 原生能力、现有成熟依赖或成熟库，而不是手搓底层能力。
- [ ] 如选择自研，是否说明成熟库不可用的原因和未来替换条件。
- [ ] 是否使用 Adaptive surface 或说明弹层例外。
- [ ] 是否复用统一空态、错误态、加载态。
- [ ] 是否保留移动端成熟路径，没有被桌面适配改写。
- [ ] 是否覆盖至少 `390x844`、`600x960`、`1280x800`。
- [ ] 是否处理文字缩放 `1.3x`。
- [ ] 是否补 widget test 或记录手测矩阵。
