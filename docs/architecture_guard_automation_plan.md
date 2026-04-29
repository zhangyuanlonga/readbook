# 架构守卫与阶段 6 自动化计划

更新时间：2026-04-29  
用途：作为总计划阶段 6“测试、验收与守卫自动化”的唯一执行文档，统一绿色集合、结构守卫、超大文件预警与文档回填检查口径。  
总计划状态：`进行中专题`

关联文档：

- `docs/project_architecture_unification_plan.md`
- `docs/development_architecture_guardrails.md`
- `docs/engineering_guide.md`

---

## 0. 结论先行

阶段 6 当前不再是“补几条零散测试”，而是把前面阶段已经收口出来的结构边界，转成可重复执行的守卫入口。

本轮拆分后的 4 条执行线：

1. 关键阶段绿色集合
2. dependency violation 检查
3. 超大文件预警
4. 文档回填检查

一句话目标：

- **让阶段 `2 ~ 5` 的结构结果有自动化守卫**
- **让总计划与专题文档的状态一致性可被脚本检查**

---

## 1. 本轮范围

纳入本轮：

- `flutter analyze`
- 阶段 `2 ~ 5` 的代表性回归测试
- `lib/features/**/presentation`
- `lib/features/**/application`
- `lib/core`
- `lib/domain`
- `lib/runtime`
- `docs/project_architecture_unification_plan.md`

暂不纳入本轮：

- 真机 / 模拟器平台回归
- 发布构建
- 所有专题文档的一致性扫描
- 全量 widget / integration test 收口

说明：

- 本轮先建立“最小可执行守卫”，避免阶段 6 一开始就因为范围过大而继续停留在文档层。

---

## 2. 阶段拆分

### 2.1 绿色集合

目标：

- 固化一套可复现的阶段 `2 ~ 5` 最小绿色回归集

当前已落地：

- [x] 新增执行入口：`tool/run_architecture_green_suite.dart`
- [x] 新增 shell 包装：`scripts/run_architecture_green_suite.sh`
- [x] 将 `flutter analyze` 纳入绿色集合
- [x] 将共享语义实体回归纳入绿色集合
- [x] 将 provider smoke / shared semantics / reader-source 代表性测试纳入绿色集合
- [x] 当前最小绿色集合已在本地执行通过

当前绿色集合：

1. `flutter analyze`
2. `dart run tool/check_architecture_guardrails.dart`
3. `flutter test`
   - `test/domain/entities/book_identity_test.dart`
   - `test/domain/entities/managed_asset_test.dart`
   - `test/domain/entities/app_advanced_theme_reader_wallpaper_test.dart`
4. `flutter test`
   - `test/features/announcement/application/announcement_provider_smoke_test.dart`
   - `test/features/auth/application/auth_provider_smoke_test.dart`
   - `test/features/book/application/book_provider_smoke_test.dart`
   - `test/features/bookshelf/application/bookshelf_provider_smoke_test.dart`
   - `test/features/search/application/search_provider_smoke_test.dart`
   - `test/features/source/application/source_provider_smoke_test.dart`
5. `flutter test`
   - `test/features/book/application/book_presentation_query_service_test.dart`
   - `test/features/book/application/book_presentation_sync_service_test.dart`
   - `test/features/mine/application/appearance_page_resource_service_test.dart`
6. `flutter test`
   - `test/features/reader/application/reader_source_switch_coordinator_test.dart`
   - `test/features/reader/presentation/reader_runtime_controller_test.dart`
   - `test/features/source/presentation/source_page_script_tab_test.dart`

当前剩余项：

- [ ] 视后续变更补充更多 Mine / Bookshelf / Reader 代表性测试
- [ ] 评估是否增加 opt-in 的 integration / 平台回归入口

---

### 2.2 Dependency Violation 检查

目标：

- 用脚本拦截最容易回退的分层越界

当前已落地：

- [x] 新增检查脚本：`tool/check_architecture_guardrails.dart`
- [x] 新增 shell 包装：`scripts/check_architecture_guardrails.sh`
- [x] 增加 `presentation -> data` 导入检查
- [x] 增加 `presentation -> app_database.dart / *_impl.dart` 导入检查
- [x] 增加 `presentation` 中 `MethodChannel / EventChannel / AppDatabase.instance` 直接使用检查
- [x] 增加 `domain -> data/features` 检查
- [x] 增加 `core -> features` 检查
- [x] 增加 `runtime -> features/presentation` 检查
- [x] 当前守卫脚本已在本地执行通过

当前剩余项：

- [ ] 评估是否补 `instance / legacy / SharedPreferences.getInstance()` 进一步守卫
- [ ] 评估是否补页面直接 `new Service()` 的静态检查

---

### 2.3 超大文件预警

目标：

- 对阶段 2 已压薄的热点文件建立体量预警，避免再次无感膨胀

当前已落地：

- [x] 在 `tool/check_architecture_guardrails.dart` 中增加行数扫描
- [x] 为 `presentation` 文件增加预警阈值：`4500`
- [x] 为 `presentation` 文件增加硬上限：`6000`
- [x] 为 `application` 文件增加预警阈值：`2000`
- [x] 为 `application` 文件增加硬上限：`2500`

当前口径：

- 到达预警阈值：输出 warning，不阻塞
- 超过硬上限：直接失败

当前剩余项：

- [ ] 结合后续继续拆分结果再收紧阈值
- [ ] 评估是否为个别历史热点增加更细粒度阈值

---

### 2.4 文档回填检查

目标：

- 让总计划状态与正文状态的一致性不再靠人工肉眼检查

当前已落地：

- [x] 增加 `docs/project_architecture_unification_plan.md` 阶段总看板与正文状态一致性检查
- [x] 增加“`已完成` 必须带完成日期”检查
- [x] 增加“`进行中` 必须带当前剩余项”检查
- [x] 增加“`已完成` 阶段不允许残留未勾选项”检查

当前剩余项：

- [ ] 评估是否扩展到专题文档状态一致性检查
- [ ] 评估是否补“专题已完成但总计划未回填”的交叉检查

---

## 3. 执行入口

推荐命令：

```bash
dart run tool/run_architecture_green_suite.dart
dart run tool/check_architecture_guardrails.dart
```

便捷包装：

```bash
scripts/run_architecture_green_suite.sh
scripts/check_architecture_guardrails.sh
```

说明：

- `run_architecture_green_suite` 负责“能不能绿”
- `check_architecture_guardrails` 负责“有没有结构回退”

---

## 4. 阶段完成标准

阶段 6 最终关闭时，应满足：

- [ ] 关键阶段绿色集合稳定可复现
- [ ] dependency violation 能在本地脚本中直接发现
- [ ] 超大文件达到阈值时有明确 warning / failure
- [ ] 文档回填错误能被脚本发现
- [ ] 总计划与本专题文档状态一致

---

## 5. 本轮新增文件

- [x] `tool/run_architecture_green_suite.dart`
- [x] `tool/check_architecture_guardrails.dart`
- [x] `scripts/run_architecture_green_suite.sh`
- [x] `scripts/check_architecture_guardrails.sh`
- [x] `docs/architecture_guard_automation_plan.md`

说明：

- 后续若继续扩展阶段 6 范围，先更新本文件，再新增脚本或规则。
