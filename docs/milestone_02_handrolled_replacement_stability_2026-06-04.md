# 里程碑 02：手搓实现替换与稳定性治理

创建日期：2026-06-04

状态：进行中。由原 M5 调整为新的第二里程碑。

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

## 2. 当前优先任务

优先从下面任务继续。每个任务做完后必须更新候选看板和本里程碑状态。

### M2-04 高级主题页面文件策略下沉

- [ ] M2-04-01 定位 `advanced_theme_list_page.dart` 中页面层直接创建临时目录、读写 ZIP、写 manifest 的位置。
- [ ] M2-04-02 设计 `AdvancedThemeService` 或相邻 application service 的批量主题包导入导出 API。
- [ ] M2-04-03 将批量主题包识别逻辑从页面迁到 application 层。
- [ ] M2-04-04 将批量主题包拆包临时目录逻辑从页面迁到 application 层。
- [ ] M2-04-05 将批量主题包打包 manifest / ZIP 逻辑从页面迁到 application 层。
- [ ] M2-04-06 页面只保留文件选择、进度显示、保存位置选择和分享分发。
- [ ] M2-04-07 为 application 层导入导出 API 补中文维护注释，说明临时目录、用户资产和跨端边界。
- [ ] M2-04-08 补或调整 `advanced_theme_service_test.dart`，覆盖批量包 manifest、缺文件、成功导入、失败计数。
- [ ] M2-04-09 运行 storage guard，若页面层临时目录白名单减少，同步 storage baseline 矩阵。
- [ ] M2-04-10 记录 Android、iOS、Web JS、macOS、Windows、Linux 影响和未验证原因。

### M2-05 超大页面继续拆分

- [ ] M2-05-01 选择一个低风险 reader settings 区块，确认只包含 UI 展示和意图分发。
- [ ] M2-05-02 抽出独立 widget 文件，保持参数明确，不读取全局状态。
- [ ] M2-05-03 为抽出 widget 补必要中文注释或调用边界说明。
- [ ] M2-05-04 运行相关 reader settings smoke / controller 测试。
- [ ] M2-05-05 更新大文件治理记录，说明减少的职责而不是只写减少行数。
- [ ] M2-05-06 选择一个 bookshelf 页面低风险区块重复执行同样拆分。
- [ ] M2-05-07 选择一个 advanced theme editor 低风险区块重复执行同样拆分。

### M2-06 平台散点收敛

- [ ] M2-06-01 扫描 presentation 层 `kIsWeb`、`defaultTargetPlatform`、`Platform`、`dart:io` 使用点。
- [ ] M2-06-02 选取一个登录或我的页平台分支，改为读取 capability / adapter。
- [ ] M2-06-03 为 capability 语义补中文 Dartdoc，说明支持平台和降级方式。
- [ ] M2-06-04 运行架构 guard 和对应页面 smoke。
- [ ] M2-06-05 记录本次减少的平台散点数量。

### M2-07 本地解析与平台 IO 隔离

- [ ] M2-07-01 盘点 TXT / EPUB / PDF / MOBI 解析入口的 `dart:io`、插件、override 和 Web 策略。
- [ ] M2-07-02 为本地文件读取定义 parser input adapter，先不改变具体解析算法。
- [ ] M2-07-03 把 Web 上传策略和 Native 文件路径策略拆开。
- [ ] M2-07-04 评估 EPUB / TXT 编码检测是否可换成熟库或保留业务定制。
- [ ] M2-07-05 为暂不替换的解析逻辑补中文注释和退出条件。
- [ ] M2-07-06 运行 local parser tests 和 Web build。

### M2-08 BookshelfService 拆分

- [ ] M2-08-01 只抽 `BookshelfService` legacy migration 逻辑，不改业务结果。
- [ ] M2-08-02 为 legacy migration service 补兼容旧 key / Drift 写入测试。
- [ ] M2-08-03 抽 taxonomy JSON / 分类标签逻辑到独立 service。
- [ ] M2-08-04 抽 collection event bus 或改为注入式 provider / event bus。
- [ ] M2-08-05 运行 `bookshelf_service_test.dart` 和 `bookshelf_page_state_test.dart`。
- [ ] M2-08-06 更新 storage baseline 和候选看板。

### M2-09 手写模型与偏好 key 收口

- [ ] M2-09-01 从 model codegen guard debt list 中选择一个低风险值对象。
- [ ] M2-09-02 先补旧 JSON / 默认值兼容测试。
- [ ] M2-09-03 迁移到 `freezed` 或 `json_serializable`。
- [ ] M2-09-04 从 guard debt list 删除已迁移项。
- [ ] M2-09-05 选择一个 SharedPreferences key，迁入 `PreferenceKey<T>` 或 typed service。
- [ ] M2-09-06 保留旧 key 兼容读取测试。

## 3. M2 验收任务

- [ ] M2-10-01 P0 候选全部关闭或登记延期原因。
- [ ] M2-10-02 P1 候选至少完成一轮替换、隔离或降级。
- [ ] M2-10-03 每个暂不替换点都有原因、平台影响、测试入口、退出条件。
- [ ] M2-10-04 `dart tool/run_architecture_green_suite.dart --dry-run` 通过。
- [ ] M2-10-05 `flutter analyze` 通过，或明确记录失败原因和下一步。
- [ ] M2-10-06 目标单测、guard、Web build、桌面 / 移动补验要求记录完整。
- [ ] M2-10-07 README、M2 候选看板、storage / dependency 矩阵完成同步。

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
