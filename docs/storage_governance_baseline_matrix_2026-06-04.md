# Storage Guard Baseline 治理矩阵

创建日期：2026-06-04

用途：解释 `tool/check_storage_governance_guard.dart` 中已批准的 storage baseline。任何新增 JSON-backed preferences、临时目录、启动清理或托管目录直连白名单，都必须同步本文档，并通过 `dart tool/check_storage_baseline_governance.dart`。

## 1. 治理原则

- 白名单不是豁免，而是“已知技术债 / 已知合理边界”的登记。
- JSON-backed preferences 必须说明为什么暂不进入 Drift、typed preference 或文件索引。
- temporary/cache directory 必须说明是否可删、是否含用户资产、是否影响业务正确性。
- managed directory direct usage 必须说明为什么暂不完全走 `ManagedAssetStore` / policy。
- 每个 baseline 都要有退出条件；如果没有退出条件，必须说明长期保留原因。

## 2. 当前 Baseline 矩阵

| 类型 | Baseline ID | 当前用途 / 原因 | 风险 | 推荐方向 | 退出条件 | 状态 |
| --- | --- | --- | --- | --- | --- | --- |
| prefs-json | `lib/app/navigation/bottom_nav_icon_gallery_service.dart|_galleriesKey` | 底部导航图标图集集合索引，当前存储为小型 JSON 列表，图片本体走托管文件。 | 图集数量增长后 SharedPreferences 会膨胀；Web storage 容量和清缓存行为需解释。 | 迁移到文件索引或 Drift，继续保留图片本体托管文件目录。 | 图集索引迁出 SharedPreferences，并保留旧 key 兼容读取测试。 | 暂留 |
| prefs-json | `lib/features/mine/application/advanced_theme_service.dart|_activeThemeAppearanceSnapshotKey` | 当前生效主题的轻量外观快照，用于启动预热和快速展示。 | 快照字段继续膨胀会变成隐形主题状态。 | 保持轻量；如果字段继续增长，迁入 typed preference 或主题索引文件。 | 快照只保留启动所需轻量字段，或迁出 SharedPreferences 并补旧 key 兼容。 | 暂留 |
| prefs-json | `lib/features/reader/application/local/txt_chapter_rule_service.dart|_ruleStorageKey` | TXT 章节规则配置，属于小型用户规则集合。 | 规则集合增长或结构复杂后不适合继续 JSON prefs。 | 保持小型规则；如要支持多套规则、同步、排序，迁入 Drift / 文件索引。 | 规则集合表化或文件索引化，并补旧 key 迁移测试。 | 暂留 |
| prefs-json | `lib/features/reader/application/reader_preferences_service.dart|_customBackgroundImagesKey` | 阅读器自定义背景图路径列表，图片本体不在 prefs。 | 路径列表与用户资产绑定，若继续扩展可能变成资源索引。 | 迁到 managed asset collection / 文件索引，prefs 只留当前选择。 | 背景图列表迁出 prefs，旧 key 兼容读取并清理。 | 暂留 |
| prefs-json | `lib/features/reader/application/reader_preferences_service.dart|_recentBodyTextColorsKey` | 最近使用正文颜色列表，属于小型 UI 偏好。 | 风险低，但仍是 JSON prefs。 | 可改为 StringList / typed preference，或继续限制数量。 | 使用非 JSON typed key 或明确长期小型保留。 | 暂留 |
| prefs-json | `lib/features/reader/application/reader_visual_overrides_service.dart|_visualOverridesKey` | 阅读器视觉 override，包含资源相对路径引用，当前通过 `ManagedAssetStore` 解析。 | 视觉配置字段可能膨胀；资源路径和旧 payload 兼容需要持续保护。 | 拆成 typed preference + managed asset ref，或迁入 reader settings 统一模型。 | override 迁入统一 reader settings / Drift / typed key，并补旧 payload 兼容测试。 | 暂留 |
| temp-dir | `lib/core/logging/diagnostic_log_export_service_io.dart|getTemporaryDirectory` | 诊断导出临时文件，用户可通过分享 / 保存拿到结果。 | 临时文件可被系统清理，不应承载长期诊断资产。 | 保持临时导出；如需长期保存，让用户选择目标或走 Documents。 | 诊断导出明确只作为临时中转，或改为用户选择保存路径。 | 暂留 |
| temp-dir | `lib/data/datasources/local/app_database_connection_native.dart|Directory.systemTemp` | Flutter test 环境数据库落入系统临时目录，避免污染真实 support 目录。 | 只应在测试环境使用。 | 保持 `FLUTTER_TEST` 分支，并确保生产使用 application support。 | 测试数据库路径有更明确 test harness；生产分支不使用系统临时目录。 | 暂留 |
| temp-dir | `lib/features/mine/application/advanced_theme_service.dart|Directory.systemTemp.createTemp` | 高级主题导入 / 导出工作目录，属于可删除临时中转。 | 不能把主题资源最终落在临时目录。 | 保持临时工作目录，最终资源写入托管目录 / index。 | 导入导出任务队列化后，由统一 temp workspace service 管理。 | 暂留 |
| temp-dir | `lib/features/mine/application/advanced_theme_service.dart|getTemporaryDirectory` | 高级主题单包 / 批量包导出分享文件和批量导入导出工作目录，属于可删除临时中转。 | 临时文件不能作为最终用户资产；Web / 移动 / 桌面分享或保存流程必须由调用方决定最终去向。 | 保持在 application service 内集中管理，页面只拿 `File` 或导入摘要；后续如任务队列化，再迁到统一 temp workspace service。 | 高级主题导入导出任务统一进入 temp workspace service，或所有临时文件都由成熟队列 / cache adapter 管理。 | 已迁入服务层 |
| managed-dir | `lib/features/mine/application/advanced_theme_service.dart|advanced_themes` | 高级主题资源目录，归类为用户资产，目前使用 Documents/advanced_themes。 | 直接拼目录容易绕过 `ManagedAssetDirectoryPolicy`。 | 逐步收敛到 `ManagedAssetStore` / policy，保留旧目录兼容。 | 主题目录解析全走 managed asset policy，旧目录只作为兼容读取。 | 暂留 |
| managed-dir | `lib/features/mine/application/mine_page_session_service.dart|profile_avatars` | 用户头像本地文件目录，归类为用户资产。 | 直接拼目录可能误删或路径不统一。 | 纳入 `ManagedAssetDirectoryPolicy` 和 `ManagedAssetStore`。 | 头像保存、删除、路径持久化全走 managed asset service。 | 待迁移 |

## 3. 当前结论

- 当前 baseline 没有新增 violation，但不是最终理想状态。
- P0 风险集中在用户资产和资源目录：`advanced_themes`、`profile_avatars`、阅读器背景图路径。
- 低风险项是小型 UI 偏好：最近正文颜色仍应优先改为 typed preference / StringList；搜索历史已迁入 `PreferenceKey<List<String>>` 和 `StringList`，并保留旧 JSON 兼容读取。
- 高级主题 presentation 层直接 `getTemporaryDirectory` 已迁入 application service；后续重点是把 service 内多个临时工作区收敛到统一 temp workspace service。

## 4. 维护命令

```bash
dart tool/check_storage_governance_guard.dart
dart tool/check_storage_baseline_governance.dart
```

修改相关服务后，按影响范围补充：

```bash
flutter test test/features/mine/application/advanced_theme_service_test.dart
flutter test test/features/reader/application/reader_preferences_service_test.dart
flutter test test/features/search/application/search_history_service_test.dart
flutter test test/core/logging/diagnostic_log_export_service_test.dart
flutter build web --no-pub
```
