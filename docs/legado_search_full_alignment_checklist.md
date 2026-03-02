# legado 搜索/换源完整对齐执行清单

更新时间：2026-03-02  
目标：对齐开源阅读在“搜索聚合、排序、换源评分、阅读联动”上的核心体验与行为。

---

## 0. 基线与回滚

- [x] 创建工作分支：`codex/search-align-legado`
- [ ] 记录基线行为（截图 + 录屏）：搜索列表、详情页、阅读页换源
- [x] 导出当前回归用例列表（手测步骤 + 预期结果）
- [ ] 标记回滚点（每个里程碑完成后打 tag）

---

## 1. 统一聚合数据模型（Service 层）

目标：把“同书多源命中”从 UI 拼装改为业务层统一输出。

- [x] 新增聚合实体（建议）：
  - [x] `AggregatedSearchBook`（主展示书 + 命中源列表 + 命中数 + 排序分）
  - [x] `AggregatedSourceHit`（sourceId/sourceName/bookId/detailUrl/latestChapter）
- [x] 在搜索服务层聚合同书：
  - [x] 聚合 key：`normalize(title) + normalize(author)`
  - [x] 兼容作者为空、作者噪声（空格/标点）差异
  - [x] 防误聚合规则：同名同作者但明显不同书时拆分（章节名/简介差异阈值）
  - [x] 保留可切换的全部源命中信息
- [x] 定义主展示源选择规则（用于点击直达）：
  - [x] 命中分最高优先
  - [x] 次级按章节信息完整度
  - [x] 再次级按源顺序/响应表现

涉及文件：
- `lib/features/search/application/search_service.dart`
- `lib/domain/entities/book.dart`（必要时）
- `lib/features/search/application/` 下新增聚合模型文件

---

## 2. 对齐 legado 搜索排序规则

目标：实现“相关性优先 + 多源命中优先”。

- [x] 实现分组排序：`精确命中 > 包含命中 > 其他`
- [x] 组内排序：命中源数量降序
- [x] 同分稳定排序：章节号/更新时间/源顺序（固定策略）
- [x] 精准匹配开关与聚合结果联动，避免 UI 层二次冲突过滤
- [x] 对齐 legado 空结果兜底：分组无结果时提示“关闭精准搜索/切换全部分组”

涉及文件：
- `lib/features/search/application/search_service.dart`
- `lib/features/search/presentation/search_page.dart`

---

## 3. 搜索页 UI 对齐（同书一条 + 源数徽标）

目标：同一本书只显示一条，并明确展示“命中源数”。

- [x] 搜索页消费聚合结果列表（不再直接消费原始 `Book` 列表）
- [x] 卡片展示命中源数徽标（示例：`5`）
- [x] 卡片展示主源信息，补充“可切换到其他源”的入口
- [x] 精准匹配、分页加载、进度刷新在聚合模式下行为一致

涉及文件：
- `lib/features/search/presentation/search_page.dart`
- `lib/features/search/presentation/widgets/search_book_card.dart`
- `lib/features/search/presentation/widgets/search_report_summary.dart`（必要时）

---

## 4. 点击行为与详情页多源切换

目标：点击聚合项后既能快速进入，也能在详情页切换命中源。

- [x] 点击聚合项默认进入“主源详情”
- [x] 详情页新增“命中源列表/切换源”面板
- [x] 切换源后刷新详情与目录，不丢失当前书名与上下文
- [x] 切换源失败时保持原源不变并给出明确错误提示
- [x] 从阅读页发起换源时，搜索关键词强制使用“书名”而非“章节名”

涉及文件：
- `lib/features/book/presentation/book_detail_page.dart`
- `lib/app/router.dart`（必要时）
- `lib/features/book/application/book_detail_service.dart`（必要时）

---

## 5. 换源评分闭环（对齐 SourceConfig 思路）

目标：建立“书级评分 + 源级评分”的持久化反馈，让排序可学习。

- [x] 新增评分存储（本地 DB 或 SharedPreferences）
- [x] 记录维度：
  - [x] `bookScore(sourceId + title + author)`
  - [x] `sourceScore(sourceId)`（累计）
- [x] 提供评分写入时增量修正（避免重复累加错误）
- [x] 将评分注入换源候选排序链路
- [x] 提供评分交互入口（加分/减分/重置）并可即时重排
- [x] 预留设置页开关：启用/禁用评分排序

涉及文件：
- `lib/features/reader/presentation/reader_page.dart`
- `lib/features/reader/application/` 下新增评分服务/仓库
- `lib/data/datasources/local/`（如采用 DB）

---

## 6. 阅读页换源联动一致性

目标：保证“从搜索聚合进入 -> 阅读中换源”行为可预期。

- [x] 章节映射优先按标题匹配，索引兜底
- [x] 目录落后源给出风险提示（章节少于当前阅读进度）
- [x] 切换后书架同步（sourceId/detailUrl/title/author）一致
- [x] 回滚机制：换源中途失败恢复快照状态
- [x] 自动换源策略：当前源失效时可自动尝试候选源（可配置开关）

涉及文件：
- `lib/features/reader/presentation/reader_page.dart`
- `lib/features/reader/application/chapter_content_service.dart`（必要时）

---

## 7. 测试与回归

### 7.1 单元测试

- [x] 聚合逻辑测试：5 个源同书 -> 1 条聚合结果，`sourceCount=5`
- [x] 排序逻辑测试：精确命中结果始终前置
- [x] 评分逻辑测试：书级评分与源级评分叠加正确
- [x] 章节映射测试：标题匹配优先，索引兜底可用
- [x] 误聚合测试：同名同作者不同书可正确分开

### 7.2 Widget/集成测试

- [x] 搜索页显示源数徽标
- [x] 点击聚合项进入主源详情成功
- [x] 详情页可切换到其他命中源
- [x] 阅读中换源后章节位置合理
- [x] 分组搜索空结果时兜底弹窗行为正确

### 7.3 命令检查

- [x] `flutter analyze`
- [x] `flutter test`
- [ ] 关键流程手测（搜索 -> 详情 -> 阅读 -> 换源）

备注：2026-03-02 已通过全量 `flutter test`，并完成 `test/features/search`、`test/features/reader/application`、`test/features/book/presentation/book_detail_switch_source_test.dart` 目标回归。

---

## 8. 里程碑交付（建议）

### 里程碑 A：搜索聚合与排序
- [x] 完成第 1~3 节
- [ ] 输出变更说明与截图

### 里程碑 B：详情页多源切换
- [x] 完成第 4 节
- [ ] 输出切换链路录屏

### 里程碑 C：评分闭环与阅读联动
- [ ] 完成第 5~7 节
- [x] 输出回归报告与性能对比

### 里程碑 D：兼容与灰度
- [x] 增加功能开关（聚合/评分/自动换源）支持灰度回退
- [ ] 输出线上观测项（失败率、切源成功率、用户撤回率）

---

## 9. 验收标准（最终）

- [x] 同一本书被 5 个源命中时，列表只显示 1 条，徽标显示 `5`
- [x] 搜索结果相关性排序与 legado 体验一致
- [x] 详情页可在命中源之间切换，无需重新全局搜索
- [x] 阅读中换源稳定，章节定位与提示合理
- [x] 分组搜索与精准搜索兜底行为与 legado 一致
- [x] 全量回归通过，无新增 P1/P2 回归问题

---

## 10. 执行记录

- [ ] 第一次执行日期：
- [ ] 第二次执行日期：
- [ ] 最终上线日期：
- [ ] 回滚演练日期：
