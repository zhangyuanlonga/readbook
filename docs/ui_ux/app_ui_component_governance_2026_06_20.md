# App UI 组件治理规则

日期: 2026-06-20
适用范围: `lib/app`、`lib/features/*/presentation`

## 1. 新增页面默认规则

- 页面骨架优先使用 `AdaptivePageScaffold`；Reader、WebView、沉浸式预览等专用页面需要在代码附近说明原因。
- 页面级弹层优先使用 `showAdaptiveActionSurface`；设置、筛选、资源选择、批量操作不直接新增 `showModalBottomSheet`。
- loading、empty、filtered empty、error、locked、offline、progress 默认使用 `AppStateView` 或状态组件族。
- blocking progress 使用 `AppBlockingProgressCard`；行内任务使用 `AppInlineProgress` 或 `AppTaskProgressRow`；不要新增裸 `CircularProgressIndicator` 作为页面状态。
- 表面容器优先使用 `AppSurface`、`AppPanel`、`AppSection`；新增 `Container + BoxDecoration` 必须属于内容资产、Reader 渲染层或已记录豁免。

## 2. Foundation 组件选择

| 场景 | 标准组件 | 不推荐新增写法 |
|---|---|---|
| 按钮 | `AppButton` | 页面内重复拼 `FilledButton.styleFrom` |
| 输入 | `AppTextField` | 本地 `TextField + OutlineInputBorder` |
| 选择状态 | `AppSelectionIndicator`、业务 picker 组件 | 每页自定义 selected check |
| 表面容器 | `AppSurface`、`AppPanel`、`AppSection` | 本地 `BoxDecoration` 重复写 radius/border/shadow |
| 进度 | `AppProgressIndicator`、`AppInlineProgress`、`AppBlockingProgressCard` | 页面级裸 spinner |
| 状态 | `AppStateView`、`AppEmptyStateCard`、`AppStatusStateCard` | 每个页面自绘 empty/error |
| 弹层 | `showAdaptiveActionSurface`、`AdaptiveBottomSheet` | 新增不可自适应 bottom sheet |

## 3. 分级门禁

日常新增代码使用 strict-new 模式，只扫描未提交和已暂存变更。阻断型问题会失败，样式类低风险问题会继续报告并进入复查:

```bash
dart run tool/check_ui_component_governance.dart --strict-new
dart run tool/check_theme_coverage_audit.dart --strict-new
```

当前 UI governance 阻断型问题包括: 新增不自适应弹层、直接能力使用、页面级 blocking spinner、未解释的页面 scaffold。硬编码样式在 strict-new 中先报告，避免 Reader/Bookshelf 合理豁免阻断阶段迁移。

全量模式只用于阶段复盘和趋势观察:

```bash
dart run tool/check_ui_component_governance.dart
dart run tool/check_theme_coverage_audit.dart
```

## 4. 豁免注释格式

允许保留固定视觉时，在相邻代码或对应文档中记录:

```dart
// UI-GOV-EXEMPT: reader-overlay-fixed-alpha
// reason: Reader chrome must preserve text contrast over arbitrary book backgrounds.
// owner: reader-ui
// review-after: 2026-09-20
```

字段要求:

- `reason`: 为什么不能直接接入主题 token。
- `owner`: 归属模块或负责人角色。
- `review-after`: 下一次复查日期。

## 5. 当前执行结论

- 组件样板固定为 Lumina，仅作为内部 QA/视觉回归入口。
- 启动图和底栏图集只通过高级主题绑定生效，不恢复独立配置入口。
- Reader/Bookshelf 本阶段只迁移外围 UI，不触碰 Reader 核心渲染和 Bookshelf 核心数据流。
