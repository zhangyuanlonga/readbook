# 脚本源非搜索链路运行时梳理

更新时间：2026-04-06

当前说明：

- 本文只讨论 `flutterreadbook` 在脚本源运行时下的非搜索主链路。
- 范围包括：详情页、目录、正文、发现页。
- 本文不讨论旧规则 JSON、Legado 执行链，也不讨论本地书籍链路。
- 本文建立在“搜索运行时重构方案”和“源健康系统规划”已经落地的前提上。

## 0. 结论先行

当前宿主在“功能兼容”层面已经基本完成脚本源统一：

- 详情页已走脚本源 `detail()`
- 目录已走脚本源 `chapters()`
- 正文已走脚本源 `content()`
- 发现页已走脚本源 `discoverCategories() / discoverBooks()`

当前非搜索链路在“运行时治理”层面已经补齐了第一批核心能力：

- 取消失效
- 健康回写
- 重任务门控
- 统一日志字段

但仍未完全追平搜索链的全部调度模型。

一句话总结：

- 搜索链已经进入“脚本源运行时调度系统”阶段
- 详情 / 目录 / 正文 / 发现 目前还主要停留在“脚本源功能链已接通”阶段

## 1. 范围

本文覆盖四条宿主主链：

1. 详情页
2. 目录
3. 正文
4. 发现页

目标不是重写业务，而是明确：

- 当前哪些链路已经真正接到脚本源运行时
- 哪些能力已经统一
- 哪些治理能力仍只存在于搜索链
- 后续应该如何补齐

## 2. 当前实现映射

### 2.1 详情页

当前详情页主链文件：

- `lib/features/book/application/book_detail_service.dart`
- `lib/features/book/presentation/book_detail_page.dart`
- `lib/features/reader/application/source_content_provider.dart`

当前实现方式：

1. 详情页进入 `BookDetailService.load()`
2. 宿主通过 `SourceRuntimeFacade.ensureRegisteredScriptSourceById()` 获取脚本源
3. 调用脚本源 `detail()`
4. 紧接着调用脚本源 `chapters()`
5. 将结果映射成宿主 `BookDetail` 和 `Chapter`

结论：

- 详情和目录已经完全走脚本源运行时
- 不再依赖旧规则解析链

### 2.2 正文

当前正文主链文件：

- `lib/features/reader/application/chapter_content_service.dart`
- `lib/features/reader/application/source_content_provider.dart`

当前实现方式：

1. 阅读页进入 `ChapterContentService.load()`
2. 宿主通过 `SourceRuntimeFacade.ensureRegisteredScriptSourceById()` 获取脚本源
3. 构造运行时 `Book / Chapter`
4. 调用脚本源 `content()`
5. 将文本正文或图片正文转换成宿主 `ReaderDocument`
6. 结果写入内存缓存和章节缓存表

结论：

- 正文已经完全走脚本源运行时
- 文本和图片两类正文都已兼容

### 2.3 发现页

当前发现页主链文件：

- `lib/features/discover/application/explore_service.dart`
- `lib/features/discover/presentation/discover_page.dart`

当前实现方式：

1. 发现页先通过 `ExploreService.loadDiscoverSources()` 读取已启用脚本源
2. 只选择声明了 `discover` 且实现了 `discoverCategories / discoverBooks` 的脚本源
3. 调用 `SourceRuntimeFacade.discoverCategories()`
4. 调用 `SourceRuntimeFacade.discoverBooks()`
5. 将结果映射为宿主 `ExploreCategoryItem` 和 `Book`

结论：

- 发现页已经完全建立在脚本源 discover 能力上
- discover 不是“兼容边角”，而是当前正式运行链

## 3. 当前已完成的统一点

### 3.1 统一运行时入口

当前搜索、详情、目录、正文、发现都已经汇总到：

- `SourceRuntimeFacade`
- `ScriptSourceRuntimeService`
- `SourceExecutor`

这意味着：

- 宿主层已经不再需要为这些链路分别维护旧规则执行入口
- 书源作者的核心方法已经统一为脚本源方法集

### 3.2 统一注册与装载

非搜索链路和搜索链一样，都会先走：

- `ensureRegisteredScriptSourceById()`

这保证了：

- 页面进入时可以按需注册脚本源
- 已禁用或缺失的源会统一返回 `unknownSource`

### 3.3 统一模型映射

当前宿主已经统一完成：

- `runtime_models.Book -> Book / BookDetail`
- `runtime_models.Chapter -> Chapter`
- `runtime_models.Content -> ReaderDocument / ChapterContentResult`
- `runtime_models.DiscoverCategory -> ExploreCategoryItem`

这部分说明：

- 书源层与宿主 UI 层之间的模型桥接已经基本成型

### 3.4 统一 discover 能力约束

当前 discover 链已经明确要求：

- 书源必须声明 `discover`
- 必须同时实现 `discoverCategories + discoverBooks`

这说明 discover 链不是随意兼容，而是已经按脚本源规范落地。

## 4. 当前测试覆盖

当前已存在的关键测试包括：

- `test/features/book/application/book_detail_service_test.dart`
- `test/features/reader/application/chapter_content_service_test.dart`
- `test/features/reader/application/source_content_provider_test.dart`
- `test/features/discover/application/explore_service_test.dart`
- `test/features/discover/presentation/discover_page_test.dart`
- `test/features/source/application/script_source_runtime_service_discover_test.dart`

这代表：

- 详情 / 目录 / 正文 / 发现 不只是“代码看起来兼容”
- 已经有宿主层测试证明这些链路能跑在脚本源运行时上

## 5. 目前尚未统一到搜索链水平的能力

这是本文最重要的部分。

### 5.1 预算调度仍主要集中在搜索链

当前搜索链已经具备：

- 画像
- 预算调度
- 场景策略
- browser / JS 重任务限流

但详情 / 目录 / 正文 / 发现 当前还没有等价治理。

这意味着：

- 详情链默认仍是“进入详情就跑 `detail + chapters`”
- 正文链默认仍是“进入章节就直接跑 `content`”
- discover 链默认仍是“切分类 / 翻页就直接跑 discover 请求”

### 5.2 取消链路没有统一下沉

搜索链已具备：

- 统一取消 token
- 调度停止派发
- 请求 / browser 响应取消

但详情 / 正文 / 发现 当前还没有同等的取消语义。

这会带来：

- 快速返回页面时旧详情任务仍可能继续跑
- 阅读过程中快速切章时旧正文任务仍可能滞后回灌
- discover 切换源和分类时旧列表请求仍可能占用资源

### 5.3 健康状态回写仍主要集中在搜索与检测

当前健康系统已经消费：

- 搜索
- 换源
- 检测

但详情 / 正文 / 发现 还没有稳定地回写健康事实。

这意味着：

- 某个源搜索稳定，但正文经常空文或超时，健康系统未必能感知
- discover 源分类稳定但翻页经常失败，当前健康系统也未完全吸收

### 5.4 browser / JS 重任务治理没有跨链统一

搜索链已经明确把：

- browser
- JS runtime

当成受控资源。

但正文和 discover 也可能触发：

- browser challenge
- 重 JS 脚本执行
- cookie / session / webview 状态同步

如果这些链路不纳入统一治理，风险会表现为：

- 搜索页已经稳定，但阅读态仍容易被重源拖慢
- discover 翻页会和阅读态正文争抢重运行时资源

## 6. 逐链路判断

### 6.1 详情页

当前状态：

- 功能兼容：已完成
- 运行时治理：已完成阶段 A、B、C

仍需补的重点：

- 对重 browser 源的保守策略

### 6.2 目录

当前状态：

- 功能兼容：已完成
- 运行时治理：已完成阶段 B、C

仍需补的重点：

- 目录失败对健康系统的事实吸收

### 6.3 正文

当前状态：

- 功能兼容：已完成
- 运行时治理：已完成阶段 A、B、C

仍需补的重点：


### 6.4 发现页

当前状态：

- 功能兼容：已完成
- 运行时治理：已完成阶段 A、B、C

仍需补的重点：


## 7. 统一改造建议

如果后续要继续推进，建议把“非搜索链路治理”单独拆成一批，而不是零碎地各修一处。

建议顺序：

1. 先补详情和正文的取消能力，再确认 discover 复用现有 token 机制
2. 再补详情 / 目录 / 正文 / 发现 的健康回写
3. 再补 browser / JS 重任务跨链限流
4. 最后决定是否需要把这些链路接入统一预算层

原因：

- 正文和发现最容易产生“旧结果回灌”
- 健康回写补齐后，健康系统才真正覆盖全运行时
- 重任务限流一旦跨链统一，搜索与阅读 / 发现之间的资源争抢会明显减少

## 8. 推荐任务清单

### 阶段 A：非搜索链路取消统一

- [x] 为详情链增加取消语义
- [x] 为正文链增加切章失效语义
- [x] 为 discover 链增加切源 / 切分类 / 翻页失效语义

### 阶段 B：非搜索链路健康回写

- [x] `detail()` 成功 / 失败回写健康状态
- [x] `chapters()` 成功 / 失败回写健康状态
- [x] `content()` 成功 / 失败回写健康状态
- [x] `discoverCategories / discoverBooks` 成功 / 失败回写健康状态

### 阶段 C：非搜索链路重任务治理

- [x] 为正文链补 browser / JS 重任务识别
- [x] 为 discover 链补 browser / JS 重任务识别
- [x] 统一与搜索链共享重资源限流策略

### 阶段 D：统一观测

- [x] 详情 / 目录 / 正文 / 发现 增加统一运行日志字段
- [x] 补可观测指标，区分搜索失败与正文失败、discover 失败

## 9. 最终判断

当前项目可以明确认为：

- 新书享源已经不仅兼容搜索
- 也已经兼容详情页、目录、正文和发现页

但还不能简单认为：

- 搜索链完成了治理
- 所有其它链路也已经完成治理

真正准确的表述应该是：

- 搜索链：兼容 + 治理都已成型
- 详情 / 目录 / 正文 / 发现：兼容已完成，第一批治理能力也已统一
- 如果后续继续做，重点会从“补主链能力”转为“观察、微调和补更细粒度策略”
