# 本地图书导入阶段执行清单

**文档类型**: 阶段任务清单  
**创建日期**: 2026-06-14  
**适用范围**: 本地图书导入、外部应用打开、后台解析、书架/详情页/阅读器本地书入口  
**核心原则**: 能用 Flutter 原生、项目已有依赖或成熟库稳定解决的能力，不手搓底层实现。

关联文档:
- `docs/features/local_book_import_ux_optimization_2026_06_14.md`
- `docs/features/bookshelf/local_book_import_business_flow.md`
- `docs/features/bookshelf/local_book_import_optimization_plan.md`
- `docs/features/bookshelf/local_book_import_technical_implementation.md`

---

## 0. 执行原则

- [x] 新增实现前必须先检查 Flutter 原生能力、项目已有依赖、成熟第三方库。
- [x] 优先级顺序固定为: Flutter 原生能力 > 项目已有依赖 > 新增成熟库 > 小范围自研。
- [x] 自研前必须记录评估结论: 原生不覆盖、已有依赖不覆盖、成熟库不适合、风险可控。
- [x] 不手搓并发队列、哈希算法、编码检测、ZIP/EPUB/PDF/MOBI 底层解析、平台文件通道。
- [x] 不为了一个局部功能引入大而全 UI Kit 或与现有 Material 3/AppTheme 冲突的库。
- [x] 文件拷贝、解析、编码检测、哈希计算不得阻塞 UI 主线程。
- [x] Android、iOS、macOS、Windows、Web 的能力差异必须在任务验收里标注。

### 0.1 新增依赖评估模板

每个新增依赖必须在 PR 或任务记录中填写:

| 项 | 说明 |
|---|---|
| 解决的问题 | 明确要替代哪段自研或补哪块能力 |
| Flutter 原生是否覆盖 | 如 `file_selector`、`compute/Isolate`、`Future.timeout` 等 |
| 现有依赖是否覆盖 | 如 `archive`、`epub_pro`、`pdfrx`、`crypto`、`charset_converter` |
| 成熟度 | 维护频率、平台覆盖、Issue 状态、版本兼容 |
| 体积/性能 | 是否增加明显包体、启动成本、内存成本 |
| 许可证 | 是否符合项目可用范围 |
| 退出方案 | 后续不合适时如何回退 |

### 0.2 当前可优先复用的能力

| 能力 | 优先使用 | 说明 |
|---|---|---|
| 文件选择 | `file_selector` | 已接入，跨平台文件选择优先复用 |
| 文件路径/目录 | `path_provider`、`path` | 不手写平台路径规则 |
| ZIP/EPUB 基础解析 | `archive`、`epub_pro`、现有 EPUB parser | 不新增 `epub_view` 做导入预览 |
| PDF | `pdfrx`、`pdfium_dart`、`pdf_text_extract` | 不手写 PDF 解析 |
| MOBI/AZW | `dart_mobi`、现有 Kindle parser | 不手写二进制解析 |
| 编码检测/转换 | `flutter_charset_detector`、`charset_converter`、`charset` | 先优化现有检测链路 |
| 哈希/指纹 | `crypto` | 不自研加密或哈希算法 |
| 并发控制 | `pool`/`async` 评估后使用 | 不手写 Semaphore/队列 |
| 后台计算 | Flutter `compute`/`Isolate.run` | CPU 密集解析放后台 isolate |
| 超时保护 | Dart `Future.timeout` | 不自研定时器状态机 |

### 0.3 本地图书导入 PR checklist

- [x] 是否复用 Flutter 原生能力、项目已有依赖或成熟库，并在 PR 说明中写明选择。
- [x] 是否避免新增裸平台通道、裸文件解析、裸编码检测、裸哈希或手写并发队列。
- [x] 若新增依赖，是否填写依赖评估: 原生覆盖、现有依赖覆盖、成熟度、体积/性能、许可证、退出方案。
- [x] 导入后是否优先写入书架并展示可见状态，解析/索引是否后台进行且可失败反馈。
- [x] Android、iOS、macOS、Windows、Web 是否有能力差异说明或降级路径。

### 0.4 跨平台入口基线

| 平台/入口 | 当前统一入口 | Phase 0 结论 |
|---|---|---|
| 书架导入 | `LocalBookImportService.importFromFiles` -> `importFromFile` | 已统一 |
| 本地书库导入 | `LocalBookImportService.importFromFiles` -> `importFromFile` | 已统一 |
| Android 外部打开 | 外部 bridge 缓存后进入 `LocalBookImportService.importFromFile` | 已统一，真实 QQ/文件管理器仍需手工回归 |
| iOS Open In/Share | 外部 bridge 缓存后进入 `LocalBookImportService.importFromFile` | 已统一，security-scoped 行为仍需真机回归 |
| macOS/Windows 文件选择 | `file_selector` 入口进入统一导入服务 | 代码层统一，桌面打开方式/拖拽待 Phase 6 |
| Web | 本地持久路径不可用 | 维持降级，后续必须走 bytes/IndexedDB 策略 |

---

## 1. 当前吸收状态

- [x] 本地图书导入从“等待索引完成”调整为“写入书架后后台解析”。
- [x] 手动导入和外部打开导入统一进入 `LocalBookImportService.importFromFile`。
- [x] Android 外部文件缓存使用原生后台线程，避免 MethodChannel 主线程搬大文件。
- [x] iOS 外部文件缓存使用后台队列，避免同步 `copyItem/Data(contentsOf:)` 阻塞。
- [x] TXT pending 状态已有 bootstrap preview 基础，并已正式化为 `LocalBookPreviewService.canOpenBootstrapPreview` 能力判断。
- [x] 本地索引已有 `LocalBookIndexService.watchEvents`，已扩展为 stage/current/total/message/estimatedSeconds。
- [x] 重复检测已有 `sourcePath` 和 `format/title/sourceFileSize` 基础策略。
- [ ] EPUB/PDF/MOBI 的快速预览尚未形成稳定策略，不承诺 2 秒可读。
- [x] 批量导入已形成受控队列: `pool` 直接依赖、验证有限并发、导入写库串行。
- [x] 索引进度已覆盖 stage/current/total/message/estimatedSeconds。
- [x] 索引超时保护、失败分类、最小 telemetry 已系统化。
- [ ] 存储空间检查、失败重试入口尚未系统化。

---

## 2. Phase 0: 基线与护栏

目标: 先把边界定清楚，避免又写出新的手搓实现。

- [x] 汇总本地图书导入全链路入口: 书架导入、本地书库导入、Android/iOS 外部打开、未来桌面打开方式。
- [x] 标注每个入口最终是否进入统一导入服务。
- [x] 给现有解析/编码/文件/哈希/并发能力建立复用清单。
- [x] 把“不手搓底层能力”写入本地图书导入 PR checklist。
- [x] 明确导入任务的跨平台验收矩阵: Android、iOS、macOS、Windows、Web。

验收:
- [x] 每个新增导入相关 PR 都能说明复用或新增依赖选择。
- [x] 没有新增裸文件解析、裸平台通道、裸并发队列。

---

## 3. Phase 1: 反馈一致性与可见状态

目标: 先解决用户感知问题，让“正在处理”可见、可理解、可恢复。

- [x] 统一导入文案: “写入书架 -> 后台解析 -> 完成可读”。
- [x] 统一手动导入、外部打开、本地书库导入的状态展示。
- [x] 本地图书外部打开必须有接管提示和失败提示，不能白屏无反馈。
- [x] 书架/详情页展示本地图书 pending/indexing/failed 状态。
- [ ] 为 failed 状态补统一操作: 重试解析、重新导入、定位文件不可用提示。
- [x] 将本地索引事件扩展为 `stage/current/total/message/estimatedSeconds`。
- [ ] AppTask/书架/详情页只消费同一套索引事件，不各写一套状态机。

成熟能力优先:
- 使用现有 `LocalBookIndexService.watchEvents` 扩展事件，不另建平行 event bus。
- UI 使用已有 `ImportExportTaskSheet`、`AppTask`、Material 3 组件，不新增 UI Kit。

验收:
- [ ] Android QQ/文件管理器打开本地图书时，500ms 内能看到接管或处理反馈。
- [x] 后台解析期间用户能在书架或详情页看到明确状态。
- [ ] 解析失败能看到原因和下一步操作。

---

## 4. Phase 2: 快速预览正式化

目标: 把“导入后可先读”做成稳定能力，但按格式分级承诺。

### 4.1 TXT 预览

- [x] 将现有 TXT bootstrap preview 标准化为正式能力。
- [x] pending/indexing TXT 点击阅读时优先打开 bootstrap chapter。
- [ ] 阅读器顶部/底部提示“目录仍在后台解析”，不打断阅读。
- [ ] 完整索引 ready 后自动切换到正式章节入口。
- [x] 补齐 GBK/UTF-16/大文件 TXT 的预览测试。

### 4.2 EPUB 轻量预览

- [x] 先评估现有 `archive`、`epub_pro`、现有 EPUB parser 是否可复用。
- [x] 不引入 `epub_view` 作为导入预览能力。
- [ ] 只解析 OPF/metadata/前 N 个 spine item，避免完整解包。
- [ ] CPU 密集解析使用 `compute` 或 `Isolate.run`。
- [ ] 对大型 EPUB 设置超时和降级: 预览不可用时展示后台解析进度。

### 4.3 PDF/MOBI/AZW 策略

- [x] PDF 优先显示页数/解析状态，不承诺 2 秒文本可读。
- [x] 如需 PDF 快速预览，优先复用 `pdfrx`/`pdfium_dart` 能力。
- [x] MOBI/AZW 优先复用 `dart_mobi` 和现有 Kindle parser。
- [x] 对复杂格式默认“先入书架、后台解析、可重试”，不做不稳定预览承诺。

验收:
- [x] TXT pending 状态可稳定打开预览正文。
- [ ] EPUB 快速预览只在可控文件上启用，有超时和降级。
- [ ] PDF/MOBI/AZW 不出现“导入成功但白屏/无反馈”。

---

## 5. Phase 3: 批量导入队列

目标: 提升批量导入效率，同时避免并发导致数据库、文件、索引状态错乱。

- [x] 按格式和文件大小排序: TXT/小文件优先，大 EPUB/PDF/MOBI 后置。
- [x] 文件验证阶段允许有限并发。
- [x] 文件拷贝阶段使用受控并发，建议评估 `pool` 后作为直接依赖引入。
- [x] 数据库写入必须串行或走 repository 已有事务能力。
- [x] 后台索引进入统一队列，避免同时解析过多大文件。
- [x] 每本书独立状态，批量任务显示整体进度。
- [ ] 支持取消排队任务，但不破坏已写入书架的记录。

成熟能力优先:
- 并发限制使用 `pool`/`async`，不手写 Semaphore。
- 后台 CPU 解析使用 Flutter isolate 能力。
- 数据一致性依赖 Drift/repository 事务，不手写临时数据库状态机。

验收:
- [ ] 10 本混合格式导入时，UI 不阻塞。
- [x] 小文件优先出现在书架并进入可读/预览状态。
- [x] 批量中单本失败不影响其他书完成。

### 5.1 2026-06-14 Phase 0-3 执行记录

已落地:
- `pool` 升为直接依赖，用于批量导入验证、导入写入串行队列和后台索引限流，不手写 Semaphore/队列。
- `LocalBookImportService.importFromFiles` 承接批量导入: 按格式/大小排序、文件验证有限并发、单本失败不中断、服务层预留取消排队 hook。
- 书架导入 sheet 和本地书库导入页改为消费同一个批量导入接口，单本导入仍统一进入 `importFromFile`。
- `LocalBookIndexService.watchEvents` 扩展为 `stage/current/total/message/estimatedSeconds`，并在 queued/preparing/parsing/persisting/ready/failed 阶段发事件。
- `LocalBookIndexService` 后台索引使用 `pool` 限流，避免多本大文件同时解析。
- TXT bootstrap preview 正式化为 `LocalBookPreviewService.canOpenBootstrapPreview`，书架打开链路不再散落 `format == txt` 判断。
- 补测试: 批量导入排序、索引阶段事件、TXT GBK/UTF-16/大文件 bootstrap preview、书架打开 TXT pending fallback。

仍保留未完成:
- failed 状态的“重新导入/定位文件不可用”还没有完整统一操作，只已有重建索引和错误文案。
- AppTask 与详情页还没有完全消费同一套索引事件；本轮先完成事件模型和书架重索引提示。
- Reader 顶部/底部“目录仍在后台解析”提示、ready 后自动切换正式章节入口未做 UI 验收。
- EPUB 轻量预览仅完成成熟库复用策略确认，未启用 OPF/spine 快速预览实现。
- UI 层取消排队按钮未接入；服务层已有 `shouldCancel` hook。
- Android QQ/文件管理器 500ms 反馈、10 本混合格式真实导入、PDF/MOBI/AZW 真机无白屏仍需手工回归。

---

## 6. Phase 4: 导入前检查与重复策略

目标: 减少失败、重复、误覆盖。

- [x] 文件类型校验统一走 `ExternalImportCatalog`/本地格式解析规则。
- [x] 导入前检查文件存在、可读、大小、扩展名/MIME。
- [x] 存储空间检查优先评估平台原生能力和 `path_provider` 可行性。
- [x] 如果必须新增磁盘空间库，先比较维护状态、平台覆盖和包体。
- [x] 重复检测使用现有 `sourcePath`、`format/title/sourceFileSize`。
- [x] 如需更强重复检测，用 `crypto` 计算头尾/分段指纹，不自研哈希算法。
- [ ] 重复导入交互提供: 跳过、替换并保留进度、保留两本。
- [x] 替换书籍时必须保护阅读进度、书架分组、标签、收藏状态。

验收:
- [x] 重复导入不会静默覆盖用户阅读进度。
- [ ] 空间不足时给出可理解提示和处理建议。
- [x] 文件不可读/权限不足时提示来源和下一步。

### 6.1 2026-06-14 Phase 4 执行记录

已落地:
- `LocalBookImportService.inspectImportCandidate` 成为统一预检入口，覆盖空路径、不支持类型、文件不存在、不可读、文件夹、空文件、扩展名/MIME、重复命中。
- `ExternalImportCatalog.supportsFileMetadata` 支持“文件名 + MIME”判断；`application/octet-stream` 不再单独作为可导入依据。
- 外部打开缓存文件导入时透传 `mimeType`，文件名不标准但 MIME 明确的来源可进入统一预检。
- 单本/批量导入共用同一套预检错误文案，批量导入的 skipped 原因不再另写。
- Android 手动选择本地图书不再走 `file_selector_android` 的返回前复制链路，改为原生 picker 秒回 URI，回到 App 后再显示缓存/导入进度。
- EPUB/PDF/MOBI 等非 TXT 导入准备阶段文案改为“正在复制到应用存储”，避免大文件复制期间误以为卡在校验。
- 重复导入默认走 `replacePreservingUserState`: 复用原 `bookId`，并复用 `BookshelfService.replace` 保留分组、标签、阅读队列。
- 服务层预留 `skipExisting`、`keepBoth` 重复策略，后续 UI 弹窗可直接接入，不重写导入核心。
- 存储空间检查评估结论: `path_provider` 只能解决目录定位，不提供可靠剩余空间；本轮不新增磁盘空间库，后续若做空间不足提示，再比较平台 API/成熟库维护状态、平台覆盖和包体。

仍保留未完成:
- “跳过/替换/保留两本”的用户交互弹窗未接入；当前默认策略仍是替换并保留用户状态。
- 空间不足的真实检测和提示未落地。

---

## 7. Phase 5: 后台解析稳定性

目标: 大文件和异常格式不拖垮 App。

- [x] 为索引任务增加超时保护，优先用 `Future.timeout`。
- [x] 超时后标记 failed。
- [ ] failed 状态统一重试入口。
- [x] 解析失败按类型归类: 文件不存在、权限不足、空文件、格式不支持、编码失败、解析超时、未知错误。
- [ ] 大文件解析必须在 isolate 或平台后台能力里执行。
- [ ] 解析中的 App 重启恢复策略: pending/indexing 重新入队或提示重试。
- [x] Warm-up 失败写入可观察日志，不吞掉用户可见状态。
- [x] 建立本地图书索引任务的最小 telemetry: format、size、duration、stage、result。

成熟能力优先:
- 超时用 Dart 标准能力。
- 日志用现有 `AppLogger`/Sentry，不新增日志库。
- 状态存储用现有 repository/Drift，不手写文件状态缓存。

验收:
- [x] 超大/损坏文件不会造成长时间无响应。
- [ ] failed 状态可重试，重试不会产生重复书籍。
- [x] 解析异常能在日志中定位到格式、阶段、文件大小。

### 7.1 2026-06-14 Phase 5 执行记录

已落地:
- `LocalBookIndexService` 增加可注入 `indexTimeout`，解析阶段使用 Dart `Future.timeout`。
- 超时、`FileSystemException`、`FormatException`、`UnsupportedError`、`AppException`、未知异常统一归类为用户可理解的 `AppException`。
- 失败统一写入 `LocalBookIndexStatus.failed` 和 `lastError`，并通过 `LocalBookIndexService.watchEvents` 发 failed 事件。
- 成功/失败日志补齐 `format`、`size`、`durationMs`、`stage`、`result`、`errorCode`，继续使用现有 `AppLogger`/监控链路。

仍保留未完成:
- 解析中的 App 重启恢复策略还未接入启动流程。
- 大文件 isolate 覆盖需要逐个 parser 审计，不能用一个开关假装完成。
- failed 状态的统一 UI 重试入口仍依赖后续 Phase 1 残留项收尾。

---

## 8. Phase 6: 跨平台导入一致性

目标: Android 测到的问题要同步检查其他平台。

- [x] Android: ACTION_VIEW/SEND/SEND_MULTIPLE、本地 file/content URI 代码入口已覆盖。
- [ ] Android: QQ/微信/文件管理器真实回归。
- [x] Android: 大文件缓存必须在后台线程，MethodChannel 回调只回传结果。
- [x] iOS: Open In/Share 文件必须后台缓存，处理 security-scoped resource。
- [x] macOS: 文件选择进入统一服务。
- [ ] macOS: 拖拽/打开方式如支持则进入统一服务。
- [ ] Windows: 文件选择、路径编码、长路径兼容性。
- [ ] Web: 不依赖本地持久路径，按上传字节流或明确降级。
- [x] 所有平台都要统一到同一套错误提示和状态展示。

验收:
- [ ] 每个平台都有至少一条手动验证记录。
- [x] 外部打开失败不会白屏或静默失败。
- [x] 平台差异写入测试说明或限制说明。

### 8.1 2026-06-14 Phase 6 执行记录

代码审计结论:
- Android `MainActivity` 已覆盖 `ACTION_VIEW`、`ACTION_SEND`、`ACTION_SEND_MULTIPLE`，支持 `file/content` URI；缓存文件在线程中执行，MethodChannel 主线程只回传结果。
- Android 书架导入、本地书库导入新增 `pickLocalBookFiles` 原生选择入口，只返回 URI/label/MIME，不在选择器返回前复制大文件；选择后应立即回 App，由导入进度承接慢操作。
- iOS `AppDelegate` 已使用 `externalImportCacheQueue` 后台缓存，且对 file URL 执行 `startAccessingSecurityScopedResource`。
- Flutter 层外部导入失败会进入 `ImportExportTaskStatus.failure` 并展示统一错误文案，不再静默白屏。
- 外部缓存目录 `/external_imports/` 中的 EPUB/PDF/MOBI 等非 TXT 文件优先移动到受管存储，避免原生缓存后 Dart 再完整复制一遍；移动失败时自动回退复制。
- macOS/Windows 现有文件选择走 `file_selector`，手动导入进入 `LocalBookImportService.importFromFiles`。

仍保留未完成:
- QQ/微信/系统文件管理器真实 Android 回归未执行。
- Android 手动选择大 EPUB/PDF/MOBI 的“秒回 App + App 内进度”仍需真机回归。
- iOS 真机 Open In/Share security-scoped 行为未执行。
- macOS 拖拽/打开方式、Windows 长路径、Web bytes/IndexedDB 策略未实现。

---

## 9. Phase 7: 测试与性能基线

目标: 防止导入链路再次松散。

- [ ] 建立本地图书导入 fixture: 小 TXT、GBK TXT、UTF-16 TXT、大 TXT、EPUB、PDF、MOBI、损坏文件。
- [x] 覆盖 `LocalBookImportService` 单元测试。
- [x] 覆盖 `LocalBookPreviewService` TXT bootstrap 测试。
- [x] 覆盖重复导入策略测试。
- [x] 覆盖索引事件 stage/current/total 测试。
- [ ] 覆盖外部导入桥接解析测试。
- [ ] Android/iOS 原生外部缓存至少保留编译检查。
- [ ] 建立性能基线: 首次反馈时间、写入书架耗时、后台索引耗时、主线程阻塞。

验收:
- [x] `flutter analyze` 通过。
- [x] 本地图书导入相关测试通过。
- [ ] Android Kotlin 编译通过。
- [ ] iOS simulator build 或 Swift 编译检查通过。
- [x] 不用“满意度提升 80%”这类不可验证指标作为工程完成标准。

### 9.1 2026-06-14 Phase 7 执行记录

已落地测试:
- `LocalBookImportService`: 批量排序、预检不支持/缺失/空文件、MIME 格式识别、重复替换保留书架元数据、保留两本策略。
- `LocalBookPreviewService`: TXT bootstrap、GBK/UTF-16/大文件预览测试已在 Phase 0-3 补齐。
- `LocalBookIndexService`: stage 事件、解析超时 failed、文件系统异常归类、既有重建索引测试。
- `ExternalImportCatalog`: 本地图书扩展名/MIME 支持判断。

仍保留未完成:
- 完整 fixture 包尚未覆盖 EPUB、PDF、MOBI、损坏文件。
- 外部导入 bridge 私有解析和 Android/iOS 原生编译检查未执行。
- 性能基线已有日志字段，但未形成真实设备采样表。
- EPUB/PDF/MOBI 导入耗时仍需用真实大文件在 Android/iOS/macOS/Windows 上采样。

---

## 10. 推荐执行顺序

### Week 1: 低风险收敛

- [x] Phase 1: 统一进度事件模型。
- [ ] Phase 1: 书架/详情页/任务中心消费同一套进度。
- [x] Phase 2.1: TXT bootstrap preview 正式化。
- [x] Phase 5: 加索引超时和失败归类。

### Week 2: 批量与检查

- [x] Phase 3: 引入成熟并发控制方案，建立批量导入队列。
- [x] Phase 4: 重复导入策略和空间/权限检查。
- [x] Phase 7: 核心测试。
- [ ] Phase 7: 完整导入 fixture 和真机性能基线。

### Week 3+: 格式扩展

- [ ] Phase 2.2: EPUB 轻量预览试点。
- [ ] Phase 2.3: PDF/MOBI/AZW 降级策略和状态优化。
- [ ] Phase 6: macOS/Windows/Web 导入能力补齐或限制说明。

---

## 11. 不建议事项

- [ ] 不为了 EPUB 预览新增 `epub_view`，除非证明现有 `archive/epub_pro/parser` 无法满足。
- [ ] 不再新增一套外部导入流程，统一走现有 bridge 和 `LocalBookImportService`。
- [ ] 不手写 ZIP、PDF、MOBI、编码检测、哈希算法。
- [ ] 不用全局静态 Map 堆复杂任务状态，优先走 repository、Stream、Riverpod/provider。
- [ ] 不把所有格式都承诺成“2 秒可读”，不同格式按能力分级。
- [ ] 不用不可验证的收益数字作为任务完成标准。
