# 本地脚本书源残留清理计划

检查日期：2026-05-24
执行更新：2026-05-24，Phase 0-4 已执行。

## 1. 当前结论

本地 JS / 脚本书源运行时已经从 Flutter 侧业务能力中移除。当前只保留历史旧数据 guard，用于给旧脚本 `sourceId` 返回可理解提示。

| 类型 | 结论 | 处理建议 |
| --- | --- | --- |
| 兼容 guard | 仍有必要，用来拦截历史书架、阅读记录、详情页、阅读器里的旧脚本 `sourceId` | 暂保留，等旧数据迁移/清理完成后再删 |
| 本地运行时空壳 | `SourceRuntimeFacade`、`runtime/sources/` 旧模型、诊断容器、旧搜索调度、旧 task gate 均已删除 | 已完成 |
| 原生导入和文案残留 | Android/iOS 脚本源导入与 README/禁用页旧文案已清理 | 保留本地图书、主题、字体外部导入 |

书源健康 `SourceHealthService` 保留，但语义已收口为“服务器书源 / 网关健康缓存”。`source_health_snapshots` 表继续保留，不再代表本地 JS 运行时健康。

## 2. 明确不属于本次移除范围

这些代码虽然有“解析/规则/本地源”等关键词，但不是本地 JS 书源运行时，当前仍是阅读闭环需要的能力：

| 能力 | 保留原因 | 代码位置 |
| --- | --- | --- |
| 本地图书导入与解析 | TXT/EPUB/Markdown/HTML/PDF/MOBI/AZW/AZW3 本地阅读仍依赖 | `lib/features/bookshelf/application/local_book_import_service.dart`、`lib/features/reader/application/local/` |
| TXT 章节识别规则 | 只是本地 TXT 分章正则，不是 Legado/JS 书源规则 | `lib/features/reader/application/local/txt_chapter_rule_service.dart` |
| HTML 清洗与本地 EPUB/HTML 解析 | 用于本地图书和内容渲染清洗 | `lib/features/reader/application/content_text_cleaner.dart`、`lib/features/reader/application/local/local_markup_book_parser_support.dart` |
| 服务器搜索和服务器网关 | 当前在线搜索、详情、目录、正文的新链路 | `lib/features/search/application/server_online_search_service.dart`、`lib/features/search/application/server_book_gateway_service.dart`、`lib/features/reader/application/server_gateway_content_provider.dart` |
| 字符集检测 | TXT/HTML 本地图书和网络响应仍在用 | `lib/features/reader/application/local/local_text_encoding_detector.dart`、`lib/core/network/http_client.dart` |

## 3. 已确认的本地脚本书源残留

| 残留点 | 当前状态 | 风险 | 建议 |
| --- | --- | --- | --- |
| `SourceRuntimeFacade` | 已删除 | 空壳误导已消除 | Phase 4 已完成 |
| `SourceRuntimeDiagnosticExecutionContainer` | 已删除 | 已无实际诊断价值 | 阶段 1 已完成 |
| `SourceRegistry` / `RuntimeSourceDefinition` / `runtime_models` | 已删除 | 运行时模型残留已清理 | Phase 4 已完成 |
| `SearchService` 本地运行时搜索 | 旧本地运行时搜索实现已删除；`SearchService` 保留为服务器搜索代理兼容层 | 换源/搜索不再走本地脚本 facade | 阶段 2 已完成 |
| `SourceRuntimeTaskGateService` | 已删除 | 本地 JS 移除后语义过时 | 阶段 2 已完成 |
| `RemoteContentTaskSchedulerService` / `RemoteContentTaskConflictService` | 已从 `SourceRuntime*` 改名，继续承担远程内容任务冲突保护 | 语义已收口 | Phase 3 已完成 |
| `jsHeavy` / `script-heavy` | 已随旧 task gate / search runtime profile 删除 | 概念误导已清理 | 阶段 2 已完成 |
| 启动本地数据库预热 | 已删除空预热调度和 `script_source_runtime_removed` 日志 | 启动日志噪音已清理 | 阶段 1 已完成 |

## 4. 原生和用户入口残留

| 平台/模块 | 残留 | 代码位置 | 建议 |
| --- | --- | --- | --- |
| Android intent | 已移除 JS MIME、`.js/.mjs` 识别和 `scriptSource` payload | `android/app/src/main/AndroidManifest.xml`、`android/app/src/main/kotlin/com/jiangyan/selune/MainActivity.kt` | 阶段 1 已完成 |
| iOS document types | 已移除“书源文件”文档类型，保留主题/本地图书/字体类型 | `ios/Runner/Info.plist` | Phase 1 已完成 |
| iOS import bridge | 已删除 `payloadTypeScriptSource` 和 `scriptSourceImportSpec` | `ios/Runner/AppDelegate.swift` | 阶段 1 已完成 |
| Flutter method channel 命名 | 已改为 `com.jiangyan.selune/external_import_intent` | Flutter、Android、iOS 三端同名 | Phase 3 已完成 |
| README | 已改成服务器书源网关/本地阅读定位 | `README.md` | Phase 1/4 已完成 |
| 能力页文案 | 已删除未使用的在线详情/章节禁用页，发现/搜索文案已改为服务器网关 | `lib/app/widgets/feature_disabled_page.dart` | Phase 3 已完成 |

## 5. 书源健康功能判断

| 项目 | 当前使用 | 是否建议立刻删除 |
| --- | --- | --- |
| `SourceHealthService` | 服务器搜索/详情/正文、章节缓存、换源排序读取 | 保留，作为服务器书源/网关健康缓存 |
| `SourceHealthPersistenceService` / `source_health_snapshots` 表 | 已从 SharedPreferences 迁入 SQLite | 保留，不做删除迁移 |
| `SourceHealthAutoDisableService` | 已删除空实现和旧 `SearchService` 调用 | 阶段 1 已完成 |
| `SourceHealthBadge` / 换源健康排序 | 读取本地健康快照，但服务器搜索的健康状态没有写入这里 | 阶段 2 随换源服务重构决定保留或删除 |
| `SourceHealthReasonClassifier` | 仍将 `ruleParse`、`browserChallenge` 等归类为健康失败 | 若保留健康，要改成服务器错误分类；若删除健康，可一并删 |

最终决策：保留 `SourceHealthService` 的数据结构和迁移表，作为服务器书源/网关健康缓存；已移除“自动禁用”空壳。

## 6. 其他可疑或需要改名的代码

| 项目 | 现状 | 建议 |
| --- | --- | --- |
| `RemoteAccessSnapshot.showSourceEntry` / `sourceImportLimit` | 已改名为 `serverSourceGatewayEnabled` / `serverSourceGatewayLimit`，兼容旧 JSON key | Phase 3 已完成 |
| `SyncScope.sourceLoginState` / `bookCustomState` | 已从同步 scope 删除 | Phase 3 已完成 |
| `core/network/url_option.dart` 的 `webView` / `webJs` | 已确认无业务调用并删除解析字段；URL 选项仅保留 HTTP、charset、cookie、sourceRegex 等服务器/本地解析仍需要的参数 | Phase 4 已完成 |
| `pubspec.yaml` 的 `json_path` | 已移除，`pubspec.lock` 同步删除其传递依赖 | Phase 4 已完成 |
| `macos/Podfile.lock` 的 `flutter_js` / `flutter_inappwebview_macos` | 已通过 `pod install` 清理 | Phase 4 已完成 |
| `FeatureDisabledPages.onlineBookDetail` / `onlineChapter` | 已删除 | Phase 3 已完成 |

## 7. 分阶段任务

### Phase 0：确认边界

- [x] 确认产品方向：客户端不再支持本地 JS/Legado 规则导入和执行。
- [x] 确认服务器书源网关继续提供搜索、详情、目录、正文、换源。
- [x] 确认旧脚本源历史数据处理策略：继续通过 `removed_script_source_guard.dart` 提示用户重新搜索并加入服务器书源版本。

验收标准：

- 本地图书解析链路不纳入删除范围。
- 服务器网关链路不被误删。
- 历史脚本源数据有用户可理解的错误提示。

### Phase 1：清理用户可见残留

- [x] 删除 `SourceHealthAutoDisableService` 空实现及 `SearchService` 中两处调用。
- [x] 删除 `SourceRuntimeDiagnosticExecutionContainer` 和 `SourceRuntimeFacade.createDiagnosticExecutionContainerById()`。
- [x] Android 移除脚本源导入：`SCRIPT_SOURCE_IMPORT_SPEC`、`PAYLOAD_TYPE_SCRIPT_SOURCE`、JS MIME intent。
- [x] iOS 移除脚本源导入：`payloadTypeScriptSource`、`scriptSourceImportSpec`、`Info.plist` 里的“书源文件”文档类型。
- [x] 更新 README 和禁用页文案，避免继续承诺“本地脚本运行时后续恢复”。
- [x] 删除启动预热空日志：`AppStartupCoordinator._scheduleWarmupLocalDatabase()` / `_warmupLocalDatabase()` / `warmupLocalDatabase` 参数。

建议验证：

- `flutter analyze`
- `flutter test test/features/source/application/source_health_persistence_service_test.dart`
- Android/iOS 外部打开本地图书、主题、字体仍可识别。

### Phase 2：替换旧运行时搜索和换源

- [x] 将 `SearchExecutionReport`、`SourceSearchFailure`、`SearchContentMode`、`SearchCancellationToken` 等共享模型从 `search_service.dart` 抽到 `search_models.dart`。
- [x] 将 `ServerOnlineSearchService`、搜索页、失败导出、搜索渲染状态改为依赖 `search_models.dart`。
- [x] 删除旧本地运行时搜索实现：`search_planner.dart`、`script_source_search_runner.dart`、`search_scheduler.dart`、`search_runtime_profile_service.dart`；`SearchService.search()` 保留为服务器搜索兼容代理。
- [x] 书籍详情页、阅读器和书架后台刷新改用服务器搜索/服务器网关能力，历史脚本源继续走移除 guard。
- [x] 删除 `SourceRuntimeTaskGateService` 以及详情/正文中围绕 `RegisteredSource` 的旧 gate 调用。
- [x] 删除 `runtime/sources/source_registry.dart` 和 `runtime/sources/source_result_models.dart`。

建议验证：

- 搜索页普通搜索、指定服务器书源搜索、加载更多服务器书源。
- 书籍详情页换源、阅读器手动换源、阅读器自动换源。
- 本地图书打开、详情、阅读不受影响。

### Phase 3：收口命名和权限残留

- [x] 将 `SourceRuntimeSchedulerService` / `SourceRuntimeTaskConflictService` 改名为 `RemoteContentTaskSchedulerService` / `RemoteContentTaskConflictService`。
- [x] 将外部导入通道从 `source_import_intent` 改名为 `external_import_intent`，Flutter/Android/iOS 同步修改。
- [x] 处理 `RemoteAccessSnapshot.showSourceEntry` / `sourceImportLimit`：改名为服务器书源网关权限字段，并保留旧 JSON key 兼容。
- [x] 删除 `SyncScope.sourceLoginState` / `bookCustomState`。
- [x] 删除未使用的 `FeatureDisabledPages.onlineBookDetail` / `onlineChapter`。

建议验证：

- 登录态和会员模块加载不回退。
- WebDAV 同步入口已移除，无需再验证同步范围展示。
- 外部导入本地图书、主题、字体仍正常。

### Phase 4：依赖和历史文档清理

- [x] 确认 `json_path` 无业务 import，并从 `pubspec.yaml` / `pubspec.lock` 移除。
- [x] 删除 `UrlOption` 中只服务旧 WebView/JS 规则的 `webView`、`webViewDelay`、`webJs` 字段与测试断言。
- [x] 重新生成 macOS Pods 锁文件，确认 `flutter_js` / `flutter_inappwebview_macos` 不再进入原生产物。
- [x] 更新 `docs/development_architecture_guardrails.md`，把“书源运行时延期能力”改成“本地脚本运行时已移除；在线能力走服务器网关”。
- [x] 更新 `docs/storage_governance_draft_2026-05-20.md` 中 `script_sources` 和书源登录态描述。
- [x] 根据最终决策保留 `source_health_snapshots` 表，作为服务器书源/网关健康缓存，不做删除迁移。

建议验证：

- `flutter pub deps --style=compact` 不再出现本地 JS/WebView 运行时依赖。
- `flutter analyze`
- 核心回归：搜索、服务器详情、阅读器、本地图书导入、主题导入、字体导入、同步设置。

## 8. 推荐优先级

优先做 Phase 1。它风险低、用户可见收益高，能先消除“导入 JS 规则但 Flutter 不支持”的错觉。

Phase 2 是真正的业务重构：换源和搜索共享模型要先拆出来，再把详情页/阅读器从旧 `SearchService` 切到服务器能力。这个阶段不要和 UI 优化混做。

Phase 3/4 属于命名、权限、依赖和文档治理。等服务器搜索/换源稳定后再做，避免在业务链路未收口时过早删除健康、同步或权限字段。
