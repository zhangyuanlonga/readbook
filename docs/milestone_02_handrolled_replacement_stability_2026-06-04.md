# 里程碑 02：手搓实现替换与稳定性治理

创建日期：2026-06-04

状态：已完成。由原 M5 调整为新的第二里程碑。

完成日期：2026-06-04。

适用平台：Android、iOS、Web JS、macOS、Windows、Linux。

核心目标：把旧代码里仍然手搓、不稳定、难测、难解释的实现，逐项替换为成熟库、生成工具、项目统一 adapter / provider / helper；不能替换的必须隔离、测试、中文注释和登记退出条件。

后续执行规则：每次只领取一个最小任务编号，例如 `M2-04-02`。不要领取一个大段后再发现里面有十几个小任务。

## 1. 已完成任务

- [x] M2-00-01 完成首轮手搓与不稳定实现扫描。
- [x] M2-00-02 新增 [M2 手搓与不稳定实现候选看板](m2_handrolled_stability_candidate_backlog_2026-06-04.md)。
- [x] M2-01-01 修复 green suite 本地 tool 执行方式，避免 `dart run tool/...` 触发无关 native assets hook。
- [x] M2-01-02 验证 `dart tool/run_architecture_green_suite.dart --dry-run`。
- [x] M2-01-03 验证 storage / architecture / model / route guard 可直接执行。
- [x] M2-02-01 新增 [Storage Guard Baseline 治理矩阵](storage_governance_baseline_matrix_2026-06-04.md)。
- [x] M2-02-02 新增 `tool/check_storage_baseline_governance.dart`。
- [x] M2-02-03 将 storage baseline guard 接入 green suite。
- [x] M2-03-01 新增 [依赖 Override 治理矩阵](dependency_override_governance_matrix_2026-06-04.md)。
- [x] M2-03-02 新增 `tool/check_dependency_override_governance.dart`。
- [x] M2-03-03 将 dependency override guard 接入 green suite。

## 2. 阶段任务

本里程碑已完成首轮治理闭环。后续如果继续深入，应从 M3-M5 或 M2 候选看板里的后续候选重新拆最小 checkbox 任务。

### M2-04 高级主题页面文件策略下沉

- [x] M2-04-01 定位 `advanced_theme_list_page.dart` 中页面层直接创建临时目录、读写 ZIP、写 manifest 的位置。
- [x] M2-04-02 设计 `AdvancedThemeService` 或相邻 application service 的批量主题包导入导出 API。
- [x] M2-04-03 将批量主题包识别逻辑从页面迁到 application 层。
- [x] M2-04-04 将批量主题包拆包临时目录逻辑从页面迁到 application 层。
- [x] M2-04-05 将批量主题包打包 manifest / ZIP 逻辑从页面迁到 application 层。
- [x] M2-04-06 页面只保留文件选择、进度显示、保存位置选择和分享分发。
- [x] M2-04-07 为 application 层导入导出 API 补中文维护注释，说明临时目录、用户资产和跨端边界。
- [x] M2-04-08 补或调整 `advanced_theme_service_test.dart`，覆盖批量包 manifest、缺文件、成功导入、失败计数。
- [x] M2-04-09 运行 storage guard，若页面层临时目录白名单减少，同步 storage baseline 矩阵。
- [x] M2-04-10 记录 Android、iOS、Web JS、macOS、Windows、Linux 影响和未验证原因。

执行记录：

| 项目 | 内容 |
| --- | --- |
| 任务编号 | M2-04 |
| 手搓点 | 高级主题列表页面直接处理 ZIP、manifest、临时目录和批量导入导出协议，页面职责过重。 |
| 替换方式 | 将批量包识别、拆包、打包、单包临时导出和批量临时导出下沉到 `AdvancedThemeService`，页面只保留文件选择、进度 UI、保存位置选择和分享分发。 |
| 行为等价 | 官方 ZIP、旧 JSON、Red、RGShare 和批量包导入仍复用原导入语义；主题资源最终仍落入托管主题目录，临时目录只作可删除中转。 |
| 多端影响 | Android、iOS、Web JS、macOS、Windows、Linux 均为代码层职责收敛；文件选择、保存和分享仍由页面 / 平台插件处理。当前未跑六端真机构建，需后续手测补验。 |
| 验证 | `dart analyze`、`flutter test test/features/mine/application/advanced_theme_service_test.dart`、storage guard、baseline guard、docs guard、green suite dry-run。 |
| 中文注释 | `AdvancedThemeService` 新增临时目录、用户资产、跨端文件名、批量包协议和页面 / service 边界说明。 |
| 下一步 | 建议执行 M2-06-01，先扫描 presentation 层平台散点，再决定是否处理登录 / 我的页平台 capability。 |

### M2-05 超大页面继续拆分

- [x] M2-05-01 选择一个低风险 reader settings 区块，确认只包含 UI 展示和意图分发。
- [x] M2-05-02 抽出独立 widget 文件，保持参数明确，不读取全局状态。
- [x] M2-05-03 为抽出 widget 补必要中文注释或调用边界说明。
- [x] M2-05-04 运行相关 reader settings smoke / controller 测试。
- [x] M2-05-05 更新大文件治理记录，说明减少的职责而不是只写减少行数。
- [x] M2-05-06 选择一个 bookshelf 页面低风险区块重复执行同样拆分。
- [x] M2-05-07 选择一个 advanced theme editor 低风险区块重复执行同样拆分。

执行记录：

| 项目 | 内容 |
| --- | --- |
| 任务编号 | M2-05 |
| 手搓点 | `reader_page_settings_sheet.dart`、`bookshelf_page_flow.dart`、`advanced_theme_editor_page.dart` 内存在局部 builder 和资源选择卡片，页面继续膨胀且样式难复用。 |
| 替换方式 | 抽出 `ReaderTypographySliderRow`、`BookshelfSettingsSwitchTile`、`AdvancedThemeLaunchGallerySelectionCard` 三个纯参数 widget。 |
| 行为等价 | 原页面仍负责 draft、保存、预览弹窗和回调分发；新 widget 不读取 provider、不持久化、不改变业务状态。 |
| 多端影响 | Android、iOS、Web JS、macOS、Windows、Linux 均为 UI 职责拆分；未改变文件、路由、存储或平台插件调用。 |
| 验证 | `dart analyze`、reader settings / bookshelf / advanced theme editor 相关 smoke 测试。 |
| 中文注释 | 三个新 widget 均补中文 Dartdoc，说明展示职责和调用边界。 |
| 下一步 | 继续 M2-06，收敛 presentation 层平台散点。 |

### M2-06 平台散点收敛

- [x] M2-06-01 扫描 presentation 层 `kIsWeb`、`defaultTargetPlatform`、`Platform`、`dart:io` 使用点。
- [x] M2-06-02 选取一个登录或我的页平台分支，改为读取 capability / adapter。
- [x] M2-06-03 为 capability 语义补中文 Dartdoc，说明支持平台和降级方式。
- [x] M2-06-04 运行架构 guard 和对应页面 smoke。
- [x] M2-06-05 记录本次减少的平台散点数量。

执行记录：

| 项目 | 内容 |
| --- | --- |
| 任务编号 | M2-06 |
| 手搓点 | 我的页头像选择来源直接拼 `kIsWeb`、`defaultTargetPlatform` 和桌面平台枚举，平台语义散落在 presentation 层。 |
| 替换方式 | 在 `AppPlatformCapabilities` 增加 `shouldUseFilePickerForProfileAvatar`，我的页改为读取 capability。 |
| 行为等价 | Web / macOS / Windows / Linux 仍直接走文件选择；Android / iOS 仍展示相册、文件、拍照等动作面板。 |
| 多端影响 | Android、iOS、Web JS、macOS、Windows、Linux 行为保持等价；平台语义集中到 app platform capability。 |
| 验证 | 扫描后本次减少我的页 `defaultTargetPlatform` 直接判断 3 处，`kIsWeb` 头像来源判断 1 处；目标 analyze、capability 单测、页面 smoke、architecture guard。 |
| 中文注释 | `shouldUseFilePickerForProfileAvatar` 补中文 Dartdoc，解释 Web / 桌面降级和移动端保留动作面板原因。 |
| 下一步 | 建议执行 M2-07-01，盘点本地解析与平台 IO 隔离。 |

### M2-07 本地解析与平台 IO 隔离

- [x] M2-07-01 盘点 TXT / EPUB / PDF / MOBI 解析入口的 `dart:io`、插件、override 和 Web 策略。
- [x] M2-07-02 为本地文件读取定义 parser input adapter，先不改变具体解析算法。
- [x] M2-07-03 把 Web 上传策略和 Native 文件路径策略拆开。
- [x] M2-07-04 评估 EPUB / TXT 编码检测是否可换成熟库或保留业务定制。
- [x] M2-07-05 为暂不替换的解析逻辑补中文注释和退出条件。
- [x] M2-07-06 运行 local parser tests 和 Web build。

执行记录：

| 项目 | 内容 |
| --- | --- |
| 任务编号 | M2-07 |
| 手搓点 | 本地书籍解析直接把 `LocalBook.storagePath` 当作唯一输入语义，Web 上传字节、Native 原始路径和受管文件恢复容易在 parser 内继续混杂。 |
| 替换方式 | 新增 `LocalBookParserInput`、`LocalBookParserInputSource`、`LocalBookParserInputAware` 和 `parseLocalBookInput` adapter；当前解析算法不重写，先把输入来源边界集中到 application 层。 |
| 行为等价 | TXT / EPUB / PDF / MOBI 仍走原 parser；旧 `parse(LocalBook)` 继续可用，支持 input-aware 的 parser 可逐步改用 `parseInput`。 |
| 多端影响 | Android、iOS、macOS、Windows、Linux 继续使用路径 / 受管文件；Web JS 后续可走 uploaded bytes 分支，不需要污染 Native 路径语义。 |
| 成熟库评估 | TXT 编码检测当前已使用 `charset` 等成熟能力并保留业务兜底；EPUB / PDF / MOBI 暂不在本阶段替换算法，退出条件是 parser input adapter 稳定后再逐一评估解析库升级。 |
| 验证 | `dart analyze lib/features/reader/application/local/local_book_parser.dart lib/features/reader/application/local/local_book_index_service.dart test/features/reader/application/local/local_book_index_service_test.dart`；`flutter test test/features/reader/application/local/local_book_index_service_test.dart`；`flutter build web --no-pub`。Web build 出现 Flutter wasm dry run warning，但命令最终成功生成 `build/web`。 |
| 中文注释 | `LocalBookParserInput.fromBook` 补充 Native / Web / managed file 边界说明。 |
| 下一步 | M2 后续可把具体 EPUB / PDF / MOBI parser 逐个迁入 input-aware 实现。 |

### M2-08 BookshelfService 拆分

- [x] M2-08-01 只抽 `BookshelfService` legacy migration 逻辑，不改业务结果。
- [x] M2-08-02 为 legacy migration service 补兼容旧 key / Drift 写入测试。
- [x] M2-08-03 抽 taxonomy JSON / 分类标签逻辑到独立 service。
- [x] M2-08-04 抽 collection event bus 或改为注入式 provider / event bus。
- [x] M2-08-05 运行 `bookshelf_service_test.dart` 和 `bookshelf_page_state_test.dart`。
- [x] M2-08-06 更新 storage baseline 和候选看板。

执行记录：

| 项目 | 内容 |
| --- | --- |
| 任务编号 | M2-08 |
| 手搓点 | `BookshelfService` 同时承担旧 JSON 快照迁移、taxonomy payload 解析、事件广播和 Drift 快照编排，后续维护入口过多。 |
| 替换方式 | 新增 `BookshelfLegacyMigrationService` 承接旧 `bookshelf.*` JSON 到 Drift 的迁移；新增 `BookshelfTaxonomyService` 承接标签 / 分类 JSON 解析、去重和默认颜色；新增 `BookshelfEventBus` 与 `bookshelf_events.dart` 承接集合 / taxonomy 广播协议。 |
| 行为等价 | 旧 key 迁移到 Drift 后仍清理 legacy prefs；`BookshelfService.watchTaxonomyChanges` 和 `watchCollectionChanges` 对外 API 保持不变；标签、分类、基础筛选顺序的旧 JSON 读取规则保持等价。 |
| 多端影响 | Android、iOS、Web JS、macOS、Windows、Linux 均为 application 层职责拆分；不改变 SharedPreferences key、Drift 表结构、页面监听或同步调用。 |
| 验证 | `dart analyze` 覆盖 bookshelf service / migration / taxonomy / event bus；`flutter test test/features/bookshelf/application/bookshelf_service_test.dart test/features/bookshelf/application/bookshelf_page_state_test.dart`。 |
| 中文注释 | migration、taxonomy、event bus 新文件均补中文 Dartdoc，说明旧 key、Drift、广播和后续深拆边界。 |
| 下一步 | 若继续瘦身 `BookshelfService`，下一轮再把 taxonomy 的数据库写入、重命名、删除编排从主服务拆出。 |

### M2-09 手写模型与偏好 key 收口

- [x] M2-09-01 从 model codegen guard debt list 中选择一个低风险值对象。
- [x] M2-09-02 先补旧 JSON / 默认值兼容测试。
- [x] M2-09-03 迁移到 `freezed` 或 `json_serializable`。
- [x] M2-09-04 从 guard debt list 删除已迁移项。
- [x] M2-09-05 选择一个 SharedPreferences key，迁入 `PreferenceKey<T>` 或 typed service。
- [x] M2-09-06 保留旧 key 兼容读取测试。

执行记录：

| 项目 | 内容 |
| --- | --- |
| 任务编号 | M2-09 |
| 手搓点 | 搜索历史使用 `jsonEncode` / `jsonDecode` 写入 SharedPreferences，属于低价值手写 JSON；模型 codegen guard 当前没有存量 debt 候选。 |
| 替换方式 | `SearchHistoryService` 新增 `PreferenceKey<List<String>> historyPreference`，新写入改为 `setStringList`；读取时兼容旧 `search.history` JSON 字符串，并归一化 trim、去空、去重和限制 15 条。 |
| 行为等价 | 搜索历史 key 保持 `search.history`；旧 JSON payload 可读，新写入为 StringList；添加、删除、清空语义保持。 |
| 多端影响 | Android、iOS、Web JS、macOS、Windows、Linux 均走 SharedPreferences typed StringList；旧 JSON 兼容分支避免升级丢历史。 |
| 模型结论 | `dart tool/check_model_codegen_guard.dart --verbose` 显示 tracked legacy debt 为 0，因此本阶段不硬造模型迁移；M2-09-01 到 M2-09-04 以 guard 确认为完成。 |
| 验证 | `dart analyze lib/features/search/application/search_history_service.dart test/features/search/application/search_history_service_test.dart`；`flutter test test/features/search/application/search_history_service_test.dart`；model guard。 |
| 中文注释 | `SearchHistoryService` 补中文 Dartdoc，说明 typed StringList 与旧 JSON 兼容原因。 |
| 下一步 | 继续从 storage baseline 中选择最近正文颜色或阅读器背景图索引，做下一批 typed preference / managed asset 迁移。 |

## 3. M2 验收任务

- [x] M2-10-01 P0 候选全部关闭或登记延期原因。
- [x] M2-10-02 P1 候选至少完成一轮替换、隔离或降级。
- [x] M2-10-03 每个暂不替换点都有原因、平台影响、测试入口、退出条件。
- [x] M2-10-04 `dart tool/run_architecture_green_suite.dart --dry-run` 通过。
- [x] M2-10-05 `flutter analyze` 通过，或明确记录失败原因和下一步。
- [x] M2-10-06 目标单测、guard、Web build、桌面 / 移动补验要求记录完整。
- [x] M2-10-07 README、M2 候选看板、storage / dependency 矩阵完成同步。

执行记录：

| 项目 | 内容 |
| --- | --- |
| 任务编号 | M2-10 |
| P0 结论 | 本轮没有未登记的 P0 候选；storage P0 风险已进入 storage baseline 矩阵，不再作为隐藏风险留在代码里。 |
| P1 结论 | M2-D007 / M2-D008 / M2-D010 已完成首轮隔离、拆分或 typed key 替换；M2-D012 / M2-D013 登记为后续候选，原因、影响平台、验证入口和退出方向已写入候选看板。 |
| Dependency 结论 | M2-D011 不在 M2 内强删本地 override / stub，继续由 dependency override 矩阵治理；本轮 macOS build 暴露 `charset_converter` 必须保持带 macOS plugin 声明的版本，已补依赖治理备注。 |
| 大文件结论 | `reader_page.dart` 当前登记债务 6013 行，`advanced_theme_service.dart` 当前登记债务 4090 行；`bookshelf_page.dart`、`epub_local_book_parser.dart` 保留 warning，退出条件是后续按职责拆分而不是只追求行数下降。 |
| 多端影响 | Android、iOS、Web JS、macOS、Windows、Linux 均为架构、存储、解析、书架和偏好治理收口；登录 / session 文件未在本阶段改动，避免和 M3 Windows 并行工作冲突。 |
| 已验证 | `flutter analyze` 通过；目标单测通过；storage / dependency / model / architecture guards 通过；`dart tool/run_architecture_green_suite.dart --dry-run` 通过；`flutter build web --no-pub` 通过；`flutter build macos --debug --no-pub` 通过。 |
| 验证备注 | reader 相关测试仍有既有 Drift 多数据库 warning；Web build 有 Flutter wasm dry-run warning；macOS build 有 Sentry `@_implementationOnly` 和 duplicate `-lsqlite3` warning，但命令均成功。 |
| 未验证平台 | Android、iOS、Windows、Linux 未在本机做真构建；发布前仍需对应机器或 CI 补验。Windows 可由当前 M3 并行环境顺手验证构建和核心 smoke。 |
| 中文注释 | 本轮新增 parser input、bookshelf migration / taxonomy / event bus、search history typed key 的中文维护注释；后续新增或维护代码继续遵守标准中文详细注释规则。 |
| 下一步 | M2 已关闭。当前执行入口切到 M3：核心业务链多端兼容与验收；M2-D012 / M2-D013 / M2-D011 作为后续治理候选接入 M4-M5 或专项任务。 |

## 4. 收尾模板

每完成一个最小任务，在回复或文档中记录：

| 项目 | 内容 |
| --- | --- |
| 任务编号 | M2-xx-xx |
| 手搓点 | 当前不稳定或难维护点是什么 |
| 替换方式 | 成熟库、生成工具、provider、adapter、helper 或隔离方式 |
| 行为等价 | 旧行为、旧 key、旧 payload、用户资产是否保持 |
| 多端影响 | Android、iOS、Web JS、macOS、Windows、Linux |
| 验证 | 命令、结果、未验证原因 |
| 中文注释 | 哪些复杂边界已补注释 |
| 下一步 | 下一个最小任务编号 |
