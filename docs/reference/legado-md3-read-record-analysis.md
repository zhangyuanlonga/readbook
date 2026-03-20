# Legado MD3 阅读记录梳理

本文基于外部项目 `/Users/zhangyuanlong/Downloads/legado-with-MD3-main` 的源码分析，目标是梳理其“阅读记录”能力的完整设计，供我们在当前 Flutter 项目中实现阅读记录功能时参考。

## 结论先看

Legado MD3 的阅读记录不是单表，而是三层结构：

- `ReadRecord`
  - 按“书籍维度”聚合
  - 记录某本书累计读了多久、最后阅读时间
- `ReadRecordDetail`
  - 按“日期 + 书籍维度”聚合
  - 记录某一天读某本书多久
- `ReadRecordSession`
  - 按“单次阅读会话”记录
  - 记录开始/结束时间

展示层则提供 3 个视图：

- 汇总视图
- 时间线视图
- 最后阅读视图

并辅以：

- 日历热力图
- 按天过滤
- 搜索
- 删除
- 合并同名记录

## 关键源码位置

### 数据层

- `/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/data/entities/readRecord/ReadRecord.kt`
- `/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/data/entities/readRecord/ReadRecordDetail.kt`
- `/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/data/entities/readRecord/ReadRecordSession.kt`
- `/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/data/dao/ReadRecordDao.kt`
- `/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/data/repository/ReadRecordRepository.kt`

### 写入入口

- 文本阅读：
  - `/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/model/ReadBook.kt`
- 漫画阅读：
  - `/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/model/ReadManga.kt`

### UI

- 入口 Activity：
  - `/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/ui/book/readRecord/ReadRecordActivity.kt`
- 页面：
  - `/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/ui/book/readRecord/ReadRecordScreen.kt`
- ViewModel：
  - `/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/ui/book/readRecord/ReadRecordViewModel.kt`

### 配置

- 默认是否开启阅读记录：
  - `/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/help/config/AppConfig.kt`

## 数据模型设计

### 1. `ReadRecord`

作用：某本书的累计阅读统计。

字段：

- `deviceId`
- `bookName`
- `bookAuthor`
- `readTime`
- `lastRead`

主键：

- `deviceId + bookName + bookAuthor`

特点：

- 按书聚合
- 主要用于“最后阅读”列表和累计统计

### 2. `ReadRecordDetail`

作用：某一天某本书的阅读详情。

字段：

- `deviceId`
- `bookName`
- `bookAuthor`
- `date`
- `readTime`
- `readWords`
- `firstReadTime`
- `lastReadTime`

主键：

- `deviceId + bookName + bookAuthor + date`

特点：

- 按天聚合
- 用于“汇总视图”和日历按天回看

### 3. `ReadRecordSession`

作用：记录单次阅读会话。

字段：

- `id`
- `deviceId`
- `bookName`
- `bookAuthor`
- `startTime`
- `endTime`
- `words`

特点：

- 粒度最细
- 用于时间线视图
- 也是汇总统计的原始输入

## 记录写入时机

### 文本阅读 `ReadBook.kt`

核心方法：

- `initReadTime()`
- `upReadTime()`
- `startAutoSaveSession()`
- `commitReadSession()`
- `commitSessionInternal()`

行为：

1. 开始阅读时初始化一个 `currentActiveSession`
2. 阅读过程中不断更新会话结束时间
3. 每 `120s` 自动提交一次
4. 会话持续时间小于 `10s` 直接丢弃

关键常量：

- `AUTO_SAVE_INTERVAL = 120 * 1000L`
- `MIN_READ_DURATION = 10 * 1000L`

### 漫画阅读 `ReadManga.kt`

逻辑与文本阅读基本一致：

- 也是会话模型
- 也是 120 秒自动保存
- 也是 10 秒以下丢弃

## Repository 聚合逻辑

`ReadRecordRepository.saveReadSession(newSession)` 是核心入口。

它做三件事：

1. 插入 `ReadRecordSession`
2. 更新当日聚合 `ReadRecordDetail`
3. 更新总聚合 `ReadRecord`

### 当日聚合逻辑

如果当天已有记录：

- `readTime += duration`
- `readWords += words`
- `firstReadTime = min(...)`
- `lastReadTime = max(...)`

如果当天没有记录：

- 新建一条 `ReadRecordDetail`

### 总聚合逻辑

如果书已有总记录：

- `readTime += duration`
- `lastRead = session.endTime`

否则：

- 新建一条 `ReadRecord`

## UI 形态

### 三种展示模式

`DisplayMode` 有 3 个：

- `AGGREGATE`
- `TIMELINE`
- `LATEST`

#### 1. 汇总视图 `AGGREGATE`

按日期分组展示 `ReadRecordDetail`：

- 每个日期 sticky header
- header 展示当天总阅读时长
- 列表项展示某本书在当天的阅读时长

#### 2. 时间线视图 `TIMELINE`

按日期分组展示 `ReadRecordSession`：

- 会话按开始时间升序
- UI 上再进行时间线样式渲染
- 还会将间隔很近的连续 session 合并显示

合并策略：

- 同书名
- 同作者
- 相邻两段会话间隔小于 20 分钟

#### 3. 最后阅读 `LATEST`

直接展示 `ReadRecord`：

- 按 `lastRead DESC`
- 体现“最近读过哪些书”

### 顶部摘要区

`SummarySection` 会根据当前是否选中日期显示：

- 未选日期：
  - 累计阅读成就
  - 书籍数
  - 总时长
- 选中某一天：
  - 当日阅读概览
  - 当天读过几本书
  - 当天总时长

### 日历热力图

页面支持日历热力图：

- 统计每日阅读次数
- 统计每日阅读总时长
- 点击某一天后过滤下方列表

这块是 MD3 体验里很完整的一部分。

### 搜索

支持搜索：

- 书名
- 作者

而且是直接作用于 Flow 查询，不是前端本地过滤。

### 删除与合并

支持：

- 删除某条明细
- 删除某段 session
- 删除某本书总记录
- 合并同名但作者不同的记录

其中“合并”逻辑比较特别：

- 目标记录和候选记录必须同设备、同书名
- 允许作者不同
- 会把明细和 session 一起迁移

这说明他们把“同书名不同作者可能是同一本书”作为现实修复入口。

## 默认开关

`AppConfig.enableReadRecord` 默认是 `true`。

也就是说：

- 阅读记录默认开启
- 用户可以在设置里关掉

## 一个很值得注意的异常点

### `words` 字段疑似并不是真正字数

源码显示：

- `ReadBook` / `ReadManga` 在创建和更新 session 时，写入的是 `durChapterIndex.toLong()`
- 不是正文字数

而在时间线页里：

- `session.words` 又被拿去当章节索引查询章节标题

这说明 MD3 当前实现里：

- `ReadRecordSession.words`
- `ReadRecordDetail.readWords`

至少在小说/漫画阅读场景下，不像是真正“读了多少字”，更像是“章节索引占位”或未完成字段。

这个点非常重要：

- UI 结构可以借鉴
- 但“readWords”统计不能直接照搬

## 我们值得借鉴的点

### 适合照搬

1. 三层数据结构
   - 总聚合
   - 日聚合
   - 会话记录

2. 会话写入策略
   - 不是每次翻页都插库
   - 采用活动 session + 定期提交

3. 最小会话时长过滤
   - 可有效去掉误触、秒开秒退

4. 三种视图拆分
   - 汇总
   - 时间线
   - 最后阅读

5. 日历热力图
   - 对阅读产品很加分

### 不建议直接照搬

1. `deviceId` 当前实现为 `""`
   - 对单机 App 没问题
   - 但如果将来要多设备同步，这个设计需要重做

2. `words/readWords` 的定义不清
   - 当前实现明显混入了章节索引语义
   - 我们最好改成真正的“已阅读字符数”或干脆先不做字数统计

3. 以 `bookName + bookAuthor` 作为主键
   - 对源切换、重命名、同名书都不够稳
   - 我们更适合用内部 `bookId`

## 对我们 Flutter 项目的实现建议

建议分 2 期。

### 第一期：先补可用阅读记录

目标：

- 低风险
- 快速落地
- 先满足“有阅读记录”

建议数据模型：

1. `reading_record`
   - `book_id`
   - `book_title_snapshot`
   - `book_author_snapshot`
   - `cover_url_snapshot`
   - `total_read_millis`
   - `last_read_at`

2. `reading_record_detail`
   - `book_id`
   - `date`
   - `read_millis`
   - `first_read_at`
   - `last_read_at`

3. `reading_record_session`
   - `book_id`
   - `chapter_id`
   - `chapter_title_snapshot`
   - `start_at`
   - `end_at`
   - `position_ratio_start`
   - `position_ratio_end`

写入策略：

- 进入阅读页时开启 session
- 退出阅读页/切后台/定时 2 分钟提交
- 少于 10 秒丢弃

UI 先做：

- “最后阅读”
- “按天汇总”

### 第二期：再做增强统计

再补：

- 时间线视图
- 日历热力图
- 真正的阅读字数估算
- 多端同步冲突处理

## 我们当前最适合的落地方向

因为你说“产品当前也缺少阅读记录”，我建议先不要一次照搬 MD3 的全量复杂度。

最合适的顺序是：

1. 在当前阅读页 session 流程里插入会话记录
2. 做数据库三表或两表简化版
3. 先做“最后阅读 + 当日汇总”
4. 热力图放下一步

## 对我们实现时的关键提醒

- 不要用书名+作者作为内部主键
- 不要把“章节索引”当“字数”
- 不要每次滚动都落库
- 一定要做最小会话时长过滤

## 文档结论

MD3 的阅读记录设计整体是值得借鉴的，特别是：

- 会话化写入
- 三层统计结构
- 三种视图模式
- 热力图

但其“字数统计/字段命名”这块存在明显不够严谨的问题，我们实现时应该重设计，而不是照搬。
