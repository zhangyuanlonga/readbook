# 阅读记录功能实施计划

更新时间：2026-03-21

## 背景

本文基于两部分现状整理：

- 参考项目：`/Users/zhangyuanlong/Downloads/legado-with-MD3-main`
- 当前 Flutter 项目：`/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook`

目标不是照搬 MD3，而是先明确：

1. MD3 的阅读记录到底有哪些能力
2. 我们当前已经实现到哪一步
3. 后续应该按什么顺序补齐

## 参考能力梳理

MD3 的阅读记录是三层结构：

- `ReadRecord`
  - 按书聚合
  - 保存累计阅读时长、最后阅读时间
- `ReadRecordDetail`
  - 按日期和书聚合
  - 保存当天阅读时长、当天首末阅读时间
- `ReadRecordSession`
  - 保存单次阅读会话
  - 记录开始时间、结束时间

MD3 的展示层有 3 个视图：

- 汇总视图
- 时间线视图
- 最后阅读

MD3 额外提供的交互能力：

- 搜索
- 日历热力图
- 按天过滤
- 删除单条明细
- 删除单条会话
- 删除整本书记录
- 合并同名不同作者记录
- 顶部摘要卡

参考源码：

- 数据模型：
  - `/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/data/entities/readRecord/ReadRecord.kt`
  - `/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/data/entities/readRecord/ReadRecordDetail.kt`
  - `/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/data/entities/readRecord/ReadRecordSession.kt`
- Repository：
  - `/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/data/repository/ReadRecordRepository.kt`
- 页面状态与模式：
  - `/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/ui/book/readRecord/ReadRecordViewModel.kt`
- 页面 UI：
  - `/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/ui/book/readRecord/ReadRecordScreen.kt`

## 当前项目现状

### 已有能力

- 已有三张表
  - `reading_records`
  - `reading_record_days`
  - `reading_record_sessions`
  - 文件：[`lib/data/datasources/local/app_database.dart`](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/data/datasources/local/app_database.dart)
- 已有服务层提交逻辑
  - 提交 session
  - 更新总记录
  - 更新按天聚合
  - 文件：[`lib/features/reader/application/reading_record_service.dart`](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/reading_record_service.dart)
- 已有阅读页接入
  - 退出页面提交
  - 切后台提交
  - 切章节前提交
  - 恢复阅读时重启 session
  - 2 分钟自动提交
  - 10 秒以下会话过滤
  - 文件：[`lib/features/reader/presentation/reader_page.dart`](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/presentation/reader_page.dart)
- 已有阅读记录页入口和路由
  - 我的页入口：[`lib/features/mine/presentation/mine_page.dart`](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/mine_page.dart)
  - 路由：[`lib/app/router.dart`](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/router.dart)
- 已有基础阅读记录页
  - 最近阅读
  - 按天汇总
  - 搜索
  - 累计阅读时长
  - 点击记录回到阅读页或书籍页
  - 文件：[`lib/features/reader/presentation/reading_records_page.dart`](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/presentation/reading_records_page.dart)

### 已有设计上的优势

- 我们使用 `bookId` 作为主识别键，比 MD3 的 `bookName + bookAuthor` 更稳
- 我们的 session 记录了：
  - `chapterId`
  - `chapterUrl`
  - `chapterTitle`
  - `chapterIndex`
  - `startPositionRatio`
  - `endPositionRatio`
- 这些字段更适合“回到上次阅读位置”和后续做更细粒度统计

### 当前缺口

- 没有时间线视图
- 没有日历热力图
- 没有按天选择过滤
- 没有删除明细、删除会话、删除整书记录 UI
- 没有合并记录能力
- 没有阅读记录总开关
- 没有更丰富的顶部摘要卡
- `watchSessions()` 已经存在，但页面未使用
- 数据库目前只有按 `bookId` 删除整本记录的接口，没有删单条 session / 删单条日明细的接口

## 完成度判断

### 数据层

- 已完成：75%
- 原因：
  - 三张表已经齐了
  - 基础查询和写入已经齐了
  - 但删除和高级查询能力不足

### 服务层

- 已完成：70%
- 原因：
  - 会话提交流程已经可用
  - 但缺少删除聚合重算、时间线查询包装、过滤态封装

### 页面层

- 已完成：35%
- 原因：
  - 当前只有“最近阅读 + 按天汇总”的基础页
  - 距离 MD3 的多视图统计页还有明显差距

## 设计原则

后续实现时坚持以下原则：

- 不照搬 MD3 的 `readWords/words` 语义
  - MD3 这里混入了章节索引语义，不适合直接复用
- 继续使用 `bookId` 作为聚合主键
- 不在滚动过程中频繁落库
- 保留最小会话时长过滤
- 保持阅读页写入逻辑简单，统计复杂度尽量沉到 service/database 层

## 分阶段计划

### 第一阶段：把阅读记录页补到“可交付”

目标：

- 现有功能可用且完整
- 不做重型视觉扩展
- 先把基础能力补齐

范围：

- 最近阅读
- 按天汇总
- 时间线视图
- 删除操作
- 更完整的摘要卡

数据层任务：

- 在 [`lib/data/datasources/local/app_database.dart`](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/data/datasources/local/app_database.dart) 增加：
  - 删除单条 `reading_record_session`
  - 删除单条 `reading_record_day`
  - 查询某一天的 sessions
  - 查询全部 sessions 的按日分组排序支持
- 保留现有 `deleteReadingRecordsByBookId`

服务层任务：

- 在 [`lib/features/reader/application/reading_record_service.dart`](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/reading_record_service.dart) 增加：
  - `deleteSession(...)`
  - `deleteDayRecord(...)`
  - `deleteBookRecord(...)`
  - 删除后自动重算：
    - 某书总时长
    - 某天汇总
- 增加时间线数据整理方法
  - 先按时间倒序
  - 先不做复杂 session 合并

UI 层任务：

- 在 [`lib/features/reader/presentation/reading_records_page.dart`](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/presentation/reading_records_page.dart) 增加第三个 tab：
  - `时间线`
- 为 3 个视图统一顶部控制区：
  - 搜索
  - 视图切换
  - 总摘要
- 最近阅读支持删除整本记录
- 按天汇总支持删除某本书某天记录
- 时间线支持删除单条 session

交互要求：

- 删除前二次确认
- 删除后页面自动刷新
- 点击记录仍然支持回到书籍或阅读页

验收标准：

- 能看到 3 个视图：最近阅读 / 按天汇总 / 时间线
- 三个视图都支持搜索
- 三个视图至少有一种删除能力
- 阅读页正常继续写入，不回归

### 第二阶段：补齐 MD3 的统计体验

目标：

- 让阅读记录页从“列表页”升级为“统计页”

范围：

- 日历热力图
- 按天过滤
- 当日概览卡
- 累计成就卡

数据层任务：

- 增加按日统计接口
  - 每日阅读总时长
  - 每日阅读书籍数
  - 每日会话数

服务层任务：

- 组合出页面所需状态：
  - `dailyReadTimes`
  - `dailyReadBookCounts`
  - `selectedDate`
  - `filteredLatestRecords`
  - `filteredDayRecords`
  - `filteredSessions`

UI 层任务：

- 在阅读记录页顶部加入热力图入口或内嵌区块
- 支持点击某天后过滤下方列表
- 摘要区分两种状态：
  - 未选日期：累计概览
  - 已选日期：当日概览

交互要求：

- 切换日期后，三个视图的过滤逻辑一致
- 清除日期后恢复全量视图

验收标准：

- 热力图能正确显示有记录的日期
- 点击某天后，列表和摘要同步过滤
- 搜索和日期过滤可同时生效

### 第三阶段：做产品级增强

目标：

- 从“功能完整”走向“长期可维护”

范围：

- 阅读记录总开关
- 合并同名记录
- 更真实的阅读字数统计
- 后续多端同步预留

数据层任务：

- 评估是否需要记录：
  - `estimatedReadChars`
  - `chapterSpan`
  - `contentLengthSnapshot`
- 如果做合并：
  - 增加按标题候选查询
  - 增加批量迁移与事务保护

服务层任务：

- 增加总开关读取与写入
- 关闭开关时：
  - 停止会话提交
  - 保留已有数据
- 增加合并记录服务

UI 层任务：

- 在系统设置中增加：
  - `启用阅读记录`
- 在阅读记录页增加：
  - 合并入口
  - 可能的批量管理入口

验收标准：

- 总开关关闭后不再新增记录
- 合并后最近阅读、按天汇总、时间线三处数据一致
- 不出现重复总时长或脏数据

## 推荐优先级

建议实际执行顺序：

1. 第一阶段全部完成
2. 第二阶段中的热力图和按天过滤
3. 第三阶段中的总开关
4. 最后再评估合并记录和字数统计

原因：

- 第一阶段收益最大，风险最低
- 第二阶段最能提升产品观感
- 总开关是配置型能力，独立性强
- 合并记录和字数统计都属于复杂逻辑，适合最后做

## 拆分到任务单的建议

可以进一步拆成以下子任务：

- Task 1：补数据库删除接口与重算逻辑
- Task 2：补时间线视图
- Task 3：补阅读记录页统一摘要卡
- Task 4：补日历热力图与按天过滤
- Task 5：补阅读记录总开关
- Task 6：评估并实现合并记录

## 当前结论

当前项目的阅读记录并不是“没做”，而是：

- 数据基础已经有了
- 阅读页写入链路已经有了
- 页面展示只完成了基础版

所以最合理的方向不是推翻重做，而是：

- 复用现有表结构和提交逻辑
- 先把页面能力补到三视图
- 再逐步补统计体验和管理能力
