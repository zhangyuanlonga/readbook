# 高级主题视觉回归矩阵

日期: 2026-06-20
范围: 组件样板页、Mine 首页、高级主题列表、启动图集、底栏图集、封面图集、阅读背景页

## 1. 目标

本矩阵用于把高级主题和组件库验收从“人工看一眼”收敛成固定入口、固定状态、固定视口的回归流程。当前阶段先建立 Flutter widget smoke 入口，后续可在同一路由上升级为 golden 或浏览器截图。

## 2. 固定路由

| 页面 | 路由 | 说明 |
|---|---|---|
| Lumina 组件样板 | `/appearance/component-demo` | 唯一组件样板入口，仅 debug/internal 可访问 |
| Mine 首页 | `/mine` | 验证 profile card、action section、资源入口 |
| 高级主题列表 | `/appearance/advanced-themes` | 验证官方主题、自定义主题、会员提示、导入导出状态 |
| 启动图集 | `/appearance/launch-image` | 仅图库管理，启动图跟随高级主题绑定 |
| 底栏图集 | `/bottom-nav-icon-galleries` | 仅图库管理，底栏图标跟随高级主题绑定 |
| 封面图集 | `/cover-galleries` | 主题封面只在书籍无封面时补位 |
| 阅读背景 | `/appearance/reader-background` | 阅读器内 override 优先于主题绑定 |

## 3. 截图矩阵

| 主题 | 模式 | 视口 |
|---|---|---|
| Lumina | light / dark | 390x844, 1280x800 |
| Mono Blue | light / dark | 390x844, 1280x800 |
| Ink Green | light / dark | 390x844, 1280x800 |
| Selune Warm | light / dark | 390x844, 1280x800 |

## 4. 当前自动化入口

当前已新增:

```bash
flutter test test/features/mine/presentation/component_demo_visual_matrix_test.dart
```

覆盖:

- Lumina 组件样板 mobile / desktop
- `AppStateView` 的 loading、locked、offline、progress、filtered empty、retry error、disabled dependency
- 业务模式样板: 书籍卡、主题卡、书源卡、阅读设置行、资源 tile、任务卡

## 5. 差异记录规则

每次视觉差异必须标记为以下三类之一:

| 结论 | 处理 |
|---|---|
| 接受 | 记录原因，例如主题 token 调整、产品确认的文案变化 |
| 修复 | 关联具体页面、组件和测试命令 |
| 豁免 | 写明固定视觉语义，例如封面生成色板、全屏预览遮罩、Reader 渲染透明层 |

## 6. 下一步升级点

- 把 `component_demo_visual_matrix_test.dart` 升级为 golden 或截图输出。
- 给 Mine、外观页、高级主题列表和四类资源页补固定 fake 数据。
- 将视觉差异记录接入 UI governance 文档和审计脚本 baseline。
