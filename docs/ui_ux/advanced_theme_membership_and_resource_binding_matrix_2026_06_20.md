# 高级主题会员边界与资源绑定矩阵

日期: 2026-06-20
范围: 高级主题、自定义主题资源、启动图集、底栏图集、阅读背景、应用背景、封面图集

## 1. 会员边界

| 动作 | 普通用户 | 会员用户 | 标准提示 |
|---|---|---|---|
| 使用官方主题 | 允许 | 允许 | 官方主题可直接使用 |
| 创建自定义主题 | 阻止 | 允许 | 创建自定义主题需要会员。 |
| 编辑自定义主题 | 阻止 | 允许 | 编辑自定义主题需要会员。 |
| 复制自定义主题 | 阻止 | 允许 | 复制自定义主题需要会员。 |
| 导入自定义主题 | 阻止 | 允许 | 导入自定义主题需要会员。 |
| 外部文件导入 | 阻止 | 允许 | 导入自定义主题需要会员。 |
| 导出自定义主题 | 阻止 | 允许 | 导出自定义主题需要会员。 |
| 批量导出 | 阻止 | 允许 | 批量导出自定义主题需要会员。 |
| 批量删除 | 阻止 | 允许 | 批量删除自定义主题需要会员。 |
| 批量分类 | 阻止 | 允许 | 批量分类自定义主题需要会员。 |
| 删除自定义主题 | 阻止 | 允许 | 删除自定义主题需要会员。 |
| 启用自定义主题 | 阻止 | 允许 | 启用自定义主题需要会员。 |

页面说明统一使用:

> 官方主题可直接使用；创建、编辑、复制、导入导出自定义主题需要会员。

## 2. 资源绑定生效规则

| 资源 | 生效入口 | 未绑定时 | 独立设置入口 |
|---|---|---|---|
| 启动图 | 当前自定义高级主题的 `launchImageGalleryId` | 不展示自定义启动图，保留系统/默认启动体验 | 不支持 |
| 底栏图集 | 当前自定义高级主题的 `bottomNavGalleryId` | 使用系统/默认底栏图标 | 不支持 |
| 阅读背景 | 阅读器手动 visual override > 当前高级主题 reader wallpaper > 阅读器默认背景 | 阅读器默认背景 | 阅读器内手动覆盖优先 |
| 应用背景 | 当前高级主题 app wallpaper / 背景色 > 默认主题背景 | 默认主题背景 | 暂不支持独立全局覆盖 |
| 封面图集 | 单书自定义封面 > 书源真实封面 > 当前高级主题封面图集 > 文字封面 | 文字封面 | 单书自定义封面优先 |

## 3. 删除与失效回收

| 场景 | 规则 |
|---|---|
| 删除当前主题绑定的启动图集 | 启动快照清空，启动页不拿空路径 |
| 删除当前主题绑定的底栏图集 | effective provider 返回 `null`，底栏回到系统图标 |
| 删除当前主题绑定的封面图集 | 封面解析回落到真实封面或文字封面 |
| 删除高级主题时勾选私有 app wallpaper | 若没有其他主题引用则删除 |
| 删除高级主题时勾选 reader wallpaper | 若没有其他主题引用则删除 |
| 删除高级主题时勾选共享图集 | 仅在没有其他主题引用时删除 |
| 删除高级主题但资源仍被其他主题引用 | 保留资源文件和图集 |

## 4. 验收测试映射

| 规则 | 测试 |
|---|---|
| 会员访问状态 | `test/features/mine/application/advanced_theme_access_controller_test.dart` |
| 会员 gate 文案矩阵 | `AdvancedThemeMembershipGateCopy.guardedActionMessages` |
| 启动图仅主题绑定生效 | `test/features/mine/application/launch_image_gallery_service_test.dart` |
| 底栏仅主题绑定生效 | `test/app/navigation/bottom_nav_icon_gallery_provider_test.dart` |
| 阅读背景 override 优先 | `test/features/reader/application/reader_settings_resolution_service_test.dart` |
| 应用背景取当前高级主题 | `test/app/theme/app_advanced_theme_tokens_test.dart` |
| 封面图集优先级 | `test/app/widgets/resolved_book_cover_test.dart` |
| 删除预览和引用保护 | `test/features/mine/application/advanced_theme_resource_reference_service_test.dart`、`test/features/mine/application/advanced_theme_service_test.dart` |
