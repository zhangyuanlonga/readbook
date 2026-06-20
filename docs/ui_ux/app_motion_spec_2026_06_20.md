# App Motion Spec v0.1

日期: 2026-06-20
范围: App 组件库、状态切换、资源页、高级主题相关页面

## 标准 token

| 场景 | 时长/曲线 |
|---|---|
| 小控件反馈 | `AppMotion.fast` |
| 内容状态切换 | `AppMotion.medium` + `AppMotion.standard` |
| 页面进入 | `AppMotion.page` |
| 大块内容进入 | `AppFadeSlideTransition` |
| 短列表首屏进入 | `AppStaggeredEntrance`，仅用于少量静态项 |
| 按压反馈 | `AppPressable` 或组件内读取 `AppMotion.fast` |

## 使用规则

- 新增 App 组件必须读取 `AppMotion.enabledOf(context)` 或通过已有 motion 组件间接接入。
- 长列表、资源网格和可无限增长内容不做逐项重入场动画。
- loading、empty、error、locked、offline、progress、content 的切换优先使用 `AppStateView`。
- blocking 任务进度优先使用 `AppBlockingProgressCard`，行内任务优先使用 `AppInlineProgress` 或 `AppTaskProgressRow`。
- 用户系统设置减少动画时，组件应即时切到无动画或静态表现。

## 验收

- Widget test 覆盖禁用动画、长文案、紧凑模式和进度语义。
- 主题切换后状态组件、表面容器、进度组件读取当前 `ColorScheme` 和 component tokens。
- 后续截图回归以组件样板页和高频资源页为第一批基线。
