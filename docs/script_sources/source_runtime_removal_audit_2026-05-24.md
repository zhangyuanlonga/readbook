# 本地脚本书源移除与书源健康审计

检查日期：2026-05-24
执行更新：2026-05-24，已完成 Phase 0-4 清理。

## 结论

- 本地 JS / 脚本书源运行时已经从用户可用能力中移除。
- 旧脚本源兼容 guard 仍保留，用来拦截历史书架、阅读记录、详情页、阅读器中残留的旧 `sourceId`，并提示用户重新搜索服务器书源版本。
- 书源健康 `SourceHealthService` 没有移除，仍用于服务器搜索/网关链路的健康快照、缓存保护和换源排序。
- “自动禁用书源”空壳已删除，避免继续暗示客户端会自动禁用本地脚本书源。

## 已确认移除的本地脚本能力

| 模块 | 当前状态 | 代码位置 |
| --- | --- | --- |
| 本地脚本运行时 | 已删除 `SourceRuntimeFacade` 和 `runtime/sources/` 旧模型 | `lib/features/source/application/source_runtime_facade.dart`、`lib/runtime/sources/` |
| 本地脚本诊断容器 | 已删除 | `lib/features/source/application/source_runtime_diagnostic_execution_container.dart` |
| 发现页脚本入口 | 页面已改成禁用页，提示服务器发现开发中 | `lib/features/discover/routes.dart` |
| 平台能力开关 | 已删除 `sourceRuntime`、`interactiveWebView` 两个废弃 capability | `lib/app/platform/app_platform_capabilities.dart` |
| 启动预热 | 旧本地脚本数据库预热和空日志已删除 | `lib/app/startup/app_startup_coordinator.dart` |
| URL WebView/JS 选项 | 已删除 `webView`、`webViewDelay`、`webJs` 解析字段 | `lib/core/network/url_option.dart` |

## 仍在使用的兼容 guard

这些代码不代表本地脚本功能还活着，而是为了处理旧数据中的脚本源：

| 用途 | 代码位置 |
| --- | --- |
| 判断旧脚本 `sourceId`，排除本地图书和服务器网关 | `lib/features/reader/application/removed_script_source_guard.dart` |
| 详情加载前拦截旧脚本源 | `lib/features/book/application/book_detail_service.dart` |
| 正文加载前拦截旧脚本源 | `lib/features/reader/application/chapter_content_service.dart` |
| 详情页 / 阅读器 UI 侧拦截旧脚本源 | 通过服务层 guard 和内容加载 presenter 展示用户提示 |
| 内容加载提示中转成用户可读错误 | `lib/features/reader/presentation/reader_content_loading_presenter.dart` |

建议：这组 guard 暂时保留，直到确认历史书架、阅读记录、缓存、书签里不再存在旧脚本 `sourceId`。

## 书源健康功能现状

书源健康不是本地脚本运行时本身，目前仍是活跃基础设施：

| 能力 | 当前使用情况 | 代码位置 |
| --- | --- | --- |
| 健康快照存储 | SQLite/Drift 表 `source_health_snapshots`，旧 SharedPreferences key `source.health.snapshots.v1` 已迁移 | `lib/data/datasources/local/app_database.dart`、`lib/features/source/application/source_health_persistence_service.dart` |
| 搜索成功/失败记录 | 服务器搜索会记录成功、失败、冷却和风险；旧 runtime profile 已删除 | `lib/features/search/application/search_service.dart`、`lib/features/search/application/server_online_search_service.dart` |
| 详情/目录健康记录 | 服务器网关详情和章节目录加载会写入健康快照 | `lib/features/book/application/book_detail_service.dart`、`lib/features/reader/application/server_gateway_content_provider.dart` |
| 正文健康记录 | 服务器网关正文加载成功/失败会写入健康快照 | `lib/features/reader/application/chapter_content_service.dart`、`lib/features/reader/application/server_gateway_content_provider.dart` |
| 换源排序与展示 | 健康状态参与换源候选评分，并在候选 UI 显示 badge | `lib/features/reader/application/switch_source_shared.dart`、`lib/app/widgets/source_health_badge.dart`、`lib/app/widgets/switch_source_candidate_sheet.dart` |
| 章节缓存保护 | 缓存前会读取健康快照，避免不健康源带来坏体验 | `lib/features/reader/application/chapter_cache_service.dart` |

结论：如果还需要服务器书源/网关搜索质量评估，就不建议整体移除书源健康表和服务。

## 空壳或弱使用代码

| 项目 | 现状 | 建议 |
| --- | --- | --- |
| `RemoteContentTaskSchedulerService` / `RemoteContentTaskConflictService` | 仍被详情、阅读器、书架后台刷新用于前后台任务冲突保护 | 已改名为远程内容任务语义，保留 |

## 未发现的残留

- 未发现本地 JS 规则编辑页、路由或设置入口。
- `docs/script_sources/` 当前只保留移除审计和清理计划。
- 未发现仍被测试引用的本地脚本 fixture；旧 `test/fixtures/script_sources/tencent_qq_reader_source_v1.js` 已删除。
- `TxtChapterRuleService` 是本地 TXT 章节识别规则，不是 JS 书源规则；它仍被本地 TXT 解析链路使用，不属于本次脚本书源移除范围。

## 建议清理顺序

1. 保留 `removed_script_source_guard.dart`，直到旧数据迁移/清理策略完成。
2. 继续保留 `source_health_snapshots`，但文档和 UI 不再称其为本地 JS 书源健康。
3. 后续如要彻底处理旧数据，可做一次书架/阅读记录扫描，辅助用户迁移到服务器书源版本。
