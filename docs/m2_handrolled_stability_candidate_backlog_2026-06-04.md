# M2 手搓与不稳定实现候选看板

创建日期：2026-06-04

用途：承接 M2 首轮扫描结果。核心判断是：手搓换成熟，不稳定换成熟；不能替换的必须隔离、测试、中文注释和退出条件。

## 1. 已关闭候选

| 编号 | 类型 | 处理方式 | 状态 |
| --- | --- | --- | --- |
| M2-D001 | 工具稳定性 | green suite local tool 从 `dart run tool/...` 改为 `dart tool/...`，避免 native assets hook 干扰本地 guard | [x] |
| M2-D002 | Storage baseline | 新增 storage baseline 矩阵和同步 guard，所有白名单必须有业务理由、影响平台和退出条件 | [x] |
| M2-D003 | Dependency override | 新增 dependency override 矩阵和同步 guard，所有 override 必须有原因、平台影响和回主线 / 替换条件 | [x] |
| M2-D004 | 高级主题文件策略 | 高级主题页面的 ZIP、manifest、临时目录和批量导入导出协议已下沉到 `AdvancedThemeService`，页面只保留交互职责 | [x] |
| M2-D005 | 超大页面首轮拆分 | reader settings、bookshelf settings、advanced theme editor 各抽一个纯参数 widget，页面保留状态和业务意图分发 | [x] |
| M2-D006 | 平台散点首轮收敛 | 我的页头像选择来源改读 `AppPlatformCapabilities.shouldUseFilePickerForProfileAvatar`，页面不再直接拼桌面平台枚举 | [x] |
| M2-D007 | 本地解析平台 IO 隔离 | 新增 parser input adapter，先把 Native 路径、Web bytes 和 managed file 语义集中起来，解析算法保持不变 | [x] |
| M2-D008 | BookshelfService 首轮拆分 | legacy migration、taxonomy JSON 解析、事件广播已下沉到独立 application 文件，主服务继续负责编排 | [x] |
| M2-D009 | 模型 codegen 债务确认 | model codegen guard 当前 tracked legacy debt 为 0，本轮不硬造模型迁移 | [x] |
| M2-D010 | 搜索历史 typed key | `search.history` 从 JSON prefs 改为 `PreferenceKey<List<String>>` + StringList，保留旧 JSON 兼容读取 | [x] |

## 2. P1 候选

以下候选已在 M2-10 登记延期原因，不属于 M2 未完成项。后续如果继续处理，必须重新拆成 M3-M5 或专项里的最小 checkbox 任务。

| 编号 | 对应任务 | 候选问题 | 当前实现 | 推荐方向 | 验证入口 | 状态 |
| --- | --- | --- | --- | --- | --- | --- |
| M2-D012 | M2 后续登记 | 具体 EPUB / PDF / MOBI parser 仍未逐个改为 input-aware，Web bytes 解析分支还需后续落地 | TXT / EPUB / PDF / MOBI parser 和 storage service | parser input adapter 后续深化、成熟库替换评估 | local parser tests、Web build | 已登记延期 |
| M2-D013 | M2 后续登记 | `BookshelfService` 仍保留 taxonomy 数据库写入、重命名、删除等编排逻辑 | `bookshelf_service.dart` | 继续拆 taxonomy persistence / command service | bookshelf service tests | 已登记延期 |

## 3. P2 候选

P2 候选由对应治理矩阵长期跟踪，不阻塞 M2 验收关闭。

| 编号 | 对应任务 | 候选问题 | 推荐方向 | 状态 |
| --- | --- | --- | --- | --- |
| M2-D011 | M2-06 | 本地 override / stub 后续仍需回主线或替换 | 依赖矩阵定期复查，优先处理平台构建风险 | 已登记延期 |

## 4. 下一步建议

- [x] M2-04-01 到 M2-04-10 已完成，高级主题页面里的文件策略已下沉。
- [x] M2-05-01 到 M2-05-07 已完成，完成三处低风险 UI 职责拆分。
- [x] M2-06-01 到 M2-06-05 已完成，头像选择平台语义已收敛到 capability。
- [x] M2-07-01 到 M2-07-06 已完成，解析输入 adapter 已建立。
- [x] M2-08-01 到 M2-08-06 已完成，书架 legacy migration、taxonomy JSON 解析和 event bus 已拆出。
- [x] M2-09-01 到 M2-09-06 已完成，模型 guard 无存量 debt，搜索历史已迁 typed StringList。
- [x] M2-10 已完成验收；P0 无未登记开放项，P1 / P2 后续候选均已写清原因、影响面、验证入口和退出方向。
- [x] 下一步执行入口切到 M3；如果要继续 M2-D012 或 M2-D013，应在后续里程碑重新拆最小任务。

## 5. 已关闭记录

| 字段 | 内容 |
| --- | --- |
| 编号 | M2-D004 |
| 日期 | 2026-06-04 |
| 处理方式 | 隔离 / 补测试 / 补注释：批量包协议、临时目录和 ZIP 处理迁入 `AdvancedThemeService`，页面层删除直接文件策略。 |
| 行为等价 | 单包导入导出、批量包 manifest、缺文件失败计数和旧格式导入保持原语义。 |
| 多端影响 | Android、iOS、Web JS、macOS、Windows、Linux 均为职责边界调整；跨端文件名和临时目录策略集中到 application 层。 |
| 验证 | `advanced_theme_service_test.dart`、storage guard、baseline guard、docs guard、green suite dry-run。 |
| 后续 | 关闭；若继续治理高级主题，可进入 M2-05 超大页面拆分或后续 temp workspace service。 |

| 字段 | 内容 |
| --- | --- |
| 编号 | M2-D005 |
| 日期 | 2026-06-04 |
| 处理方式 | 隔离 / 补注释：抽出 `ReaderTypographySliderRow`、`BookshelfSettingsSwitchTile`、`AdvancedThemeLaunchGallerySelectionCard`。 |
| 行为等价 | 页面仍负责状态、保存、预览和回调；新 widget 只吃参数并渲染 UI。 |
| 多端影响 | Android、iOS、Web JS、macOS、Windows、Linux 为 UI 层职责拆分，无平台插件行为变化。 |
| 验证 | 目标 analyze、reader settings / bookshelf / advanced theme editor 相关 smoke。 |
| 后续 | 首轮关闭；复杂页面仍需后续按 Phase E 继续拆。 |

| 字段 | 内容 |
| --- | --- |
| 编号 | M2-D006 |
| 日期 | 2026-06-04 |
| 处理方式 | 收敛 / 补注释：我的页头像选择来源改读 `AppPlatformCapabilities.shouldUseFilePickerForProfileAvatar`。 |
| 行为等价 | Web / 桌面仍直接文件选择，Android / iOS 仍展示动作面板。 |
| 多端影响 | Android、iOS、Web JS、macOS、Windows、Linux 行为保持，平台语义集中到 app capability。 |
| 验证 | presentation 平台散点扫描、目标 analyze、capability 单测、mine/auth 页面相关 smoke、architecture guard。 |
| 后续 | 首轮关闭；剩余 presentation 平台散点进入后续 M3/M4 或专项治理。 |

| 字段 | 内容 |
| --- | --- |
| 编号 | M2-D007 |
| 日期 | 2026-06-04 |
| 处理方式 | 隔离 / 补测试 / 补注释：新增 `LocalBookParserInput` 和 `parseLocalBookInput`，解析入口先通过 adapter 传递输入来源。 |
| 行为等价 | 原 TXT / EPUB / PDF / MOBI parser 算法不变，旧 `parse(LocalBook)` 仍可作为 fallback。 |
| 多端影响 | Android、iOS、macOS、Windows、Linux 继续使用路径 / managed file；Web JS 后续可接 uploaded bytes。 |
| 验证 | local book index service analyze、parser 相关单测、`flutter build web --no-pub`。Web build 出现 Flutter wasm dry run warning，但最终成功。 |
| 后续 | 首轮关闭；具体 parser 迁入 input-aware 和成熟解析库评估进入 M2-D012。 |

| 字段 | 内容 |
| --- | --- |
| 编号 | M2-D008 |
| 日期 | 2026-06-04 |
| 处理方式 | 拆分 / 补注释：新增 `BookshelfLegacyMigrationService`、`BookshelfTaxonomyService`、`BookshelfEventBus` 和 `bookshelf_events.dart`。 |
| 行为等价 | 旧 JSON 快照迁移、标签 / 分类 JSON 读取、集合 / taxonomy 事件广播保持原行为和原公开 API。 |
| 多端影响 | Android、iOS、Web JS、macOS、Windows、Linux 均为 application 层职责拆分，不改平台插件和存储 key。 |
| 验证 | bookshelf service analyze、`bookshelf_service_test.dart`、`bookshelf_page_state_test.dart`。 |
| 后续 | 首轮关闭；taxonomy 数据库写入和命令编排继续进入 M2-D013。 |

| 字段 | 内容 |
| --- | --- |
| 编号 | M2-D009 |
| 日期 | 2026-06-04 |
| 处理方式 | 暂缓 / guard 确认：`dart tool/check_model_codegen_guard.dart --verbose` 显示 tracked legacy debt 为 0。 |
| 行为等价 | 无模型文件迁移，无业务行为变化。 |
| 多端影响 | Android、iOS、Web JS、macOS、Windows、Linux 无运行时影响。 |
| 验证 | model codegen guard 通过。 |
| 后续 | 关闭当前候选；未来如果 guard 增加 debt list，再逐项迁移 `freezed` / `json_serializable`。 |

| 字段 | 内容 |
| --- | --- |
| 编号 | M2-D010 |
| 日期 | 2026-06-04 |
| 处理方式 | 替换 / 补测试 / 补注释：`SearchHistoryService` 改用 `PreferenceKey<List<String>>` 和 `setStringList`，保留旧 JSON 字符串读取。 |
| 行为等价 | `search.history` key 不变；添加、删除、清空、去重和 15 条限制保持。 |
| 多端影响 | Android、iOS、Web JS、macOS、Windows、Linux 均兼容旧 JSON 并新写 typed StringList。 |
| 验证 | 搜索历史 analyze、`search_history_service_test.dart`、storage guard、storage baseline guard。 |
| 后续 | 关闭；下一批可迁移最近正文颜色或阅读器背景图索引。 |

| 字段 | 内容 |
| --- | --- |
| 编号 | M2-D012 |
| 日期 | 2026-06-04 |
| 处理方式 | 登记延期：M2-D007 已先建立 parser input adapter，本阶段不一次性重写 EPUB / PDF / MOBI 解析算法，避免扩大解析行为风险。 |
| 行为等价 | 当前 TXT / EPUB / PDF / MOBI 继续走原 parser；Web bytes 入口由 adapter 预留，不改变 Native 路径和 managed file 语义。 |
| 多端影响 | Android、iOS、macOS、Windows、Linux 继续使用路径 / 受管文件；Web JS 后续需要补 uploaded bytes parser smoke。 |
| 验证 | local parser tests、`flutter build web --no-pub` 已在 M2-10 通过；后续改具体 parser 时必须补对应格式测试。 |
| 后续 | 后续阶段按格式逐个迁入 input-aware，并评估 EPUB / PDF / MOBI 是否可替换为更成熟、跨端更完整的解析库。 |

| 字段 | 内容 |
| --- | --- |
| 编号 | M2-D013 |
| 日期 | 2026-06-04 |
| 处理方式 | 登记延期：M2-D008 已拆出 legacy migration、taxonomy JSON 解析和 event bus；taxonomy 数据库写入、重命名、删除仍留在主服务编排。 |
| 行为等价 | `BookshelfService` 对外 API、Drift 表结构、SharedPreferences legacy key 和页面监听均保持。 |
| 多端影响 | Android、iOS、Web JS、macOS、Windows、Linux 都是 application 层职责边界问题，不涉及平台插件变更。 |
| 验证 | `bookshelf_service_test.dart`、`bookshelf_page_state_test.dart` 已通过；后续拆 persistence / command service 时继续复用这些测试。 |
| 后续 | 后续阶段拆 taxonomy persistence / command service，让 `BookshelfService` 进一步回到编排入口。 |

| 字段 | 内容 |
| --- | --- |
| 编号 | M2-D011 |
| 日期 | 2026-06-04 |
| 处理方式 | 登记延期：本地 override / Web stub 仍由 dependency override 矩阵跟踪，本阶段不在没有替代验证的情况下强删。 |
| 行为等价 | PDF、编码检测和翻页链路继续保持当前实现。 |
| 多端影响 | Android、iOS、Web JS、macOS、Windows、Linux 的差异和退出条件已写入 dependency override 矩阵。 |
| 验证 | dependency override guard、Web build、macOS build 已在 M2-10 通过；平台专项变更时再补 PDF / TXT / 阅读器 smoke。 |
| 后续 | 优先在 M4-M5 或依赖升级窗口处理本地包回主线、成熟替代和 Web 编码检测降级说明。 |

## 6. 收尾记录模板

| 字段 | 内容 |
| --- | --- |
| 编号 | M2-Dxxx |
| 日期 | YYYY-MM-DD |
| 处理方式 | 替换 / 隔离 / 补测试 / 补注释 / 暂缓 |
| 行为等价 | 旧行为和新行为是否一致 |
| 多端影响 | Android、iOS、Web JS、macOS、Windows、Linux |
| 验证 | 命令、结果、未验证原因 |
| 后续 | 是否关闭、降级优先级或进入下一阶段 |
