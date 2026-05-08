# 书籍 / 书架 / 阅读器链路治理执行方案

更新时间：2026-05-08  
用途：作为“书籍详情、书架列表、阅读器”核心链路的统一治理文档，覆盖模块边界、热点问题、阶段任务、验收口径和文档维护方式。后续相关优化优先按本文件推进。

## 0. 结论先行

当前“首次打开书籍、翻页、书架列表滑动时整页都卡”的问题，不是单点问题，而是三条链路叠加造成：

- 书架列表仍承担部分展示态预处理、状态拼装和入口判定
- 书籍详情页仍承接目录、书架状态、元数据、本地索引等多类恢复逻辑
- 阅读器在正文加载后还要继续做文档构建、段落拆分、分页、批注绘制和背景处理

一句话结论：

- **先收口入口职责**
- **再拆分正文恢复与渲染计算**
- **最后建立统一的观测和回归基线**

---

## 1. 范围

本文件覆盖以下模块：

- `lib/features/bookshelf/`
- `lib/features/book/`
- `lib/features/reader/`
- `lib/domain/entities/book*.dart`
- `lib/domain/entities/local_book.dart`
- `lib/domain/entities/local_chapter.dart`
- `lib/domain/entities/reader_document.dart`
- `lib/domain/repositories/local_book_repository.dart`
- `lib/data/datasources/local/app_database.dart`
- `lib/data/repositories/local_book_repository_impl.dart`

本文件不覆盖：

- `discover / search / home` 书卡链路
- 登录页、WebView、平台授权页
- 视觉设计专项

关联文档：

- `docs/bookshelf_reader_open_latency_execution_plan.md`
- `docs/books_core_performance_plan.md`

关系说明：

- 前者继续负责“书架点击进入阅读页”专项
- 后者继续负责更宽范围的书籍核心性能
- 本文负责把“书架列表 + 书籍详情 + 阅读器”三条核心链路串成一份执行总表

---

## 2. 模块边界

### 2.1 书架链路

页面层：

- `lib/features/bookshelf/presentation/bookshelf_page.dart`
- `lib/features/bookshelf/presentation/bookshelf_page_flow.dart`
- `lib/features/bookshelf/presentation/widgets/bookshelf_grid_sliver.dart`

应用层：

- `lib/features/bookshelf/application/bookshelf_service.dart`
- `lib/features/bookshelf/application/bookshelf_presentation_query_service.dart`
- `lib/features/bookshelf/application/bookshelf_reader_open_service.dart`
- `lib/features/bookshelf/application/bookshelf_page_route_service.dart`
- `lib/features/bookshelf/application/local_book_import_service.dart`

依赖装配：

- `lib/features/bookshelf/providers.dart`

### 2.2 书籍详情链路

页面层：

- `lib/features/book/presentation/book_detail_page.dart`
- `lib/features/book/presentation/book_detail_page_view.dart`
- `lib/features/book/presentation/book_detail_page_catalog.dart`

应用层：

- `lib/features/book/application/book_detail_service.dart`
- `lib/features/book/application/book_detail_read_route_service.dart`
- `lib/features/book/application/book_detail_catalog_service.dart`
- `lib/features/book/application/book_detail_metadata_flow_service.dart`
- `lib/features/book/application/book_presentation_query_service.dart`
- `lib/features/book/application/local_book_detail_service.dart`

依赖装配：

- `lib/features/book/providers.dart`

### 2.3 阅读器链路

页面层：

- `lib/features/reader/presentation/reader_page.dart`
- `lib/features/reader/presentation/reader_page_bootstrap.dart`
- `lib/features/reader/presentation/reader_page_content_loading.dart`
- `lib/features/reader/presentation/reader_page_content_rendering.dart`
- `lib/features/reader/presentation/reader_page_background.dart`
- `lib/features/reader/presentation/reader_annotated_text.dart`

应用层：

- `lib/features/reader/application/source_content_provider.dart`
- `lib/features/reader/application/local_content_provider.dart`
- `lib/features/reader/application/chapter_content_service.dart`
- `lib/features/reader/application/local/local_chapter_content_service.dart`
- `lib/features/reader/application/reader_pagination_engine.dart`
- `lib/features/reader/application/reader_content_loading_controller.dart`
- `lib/features/reader/application/reader_preferences_service.dart`
- `lib/features/reader/application/reader_entry_route_resolver.dart`

依赖装配：

- `lib/features/reader/application/reader_dependencies_provider.dart`

### 2.4 数据与模型

- `lib/data/datasources/local/app_database.dart`
- `lib/domain/repositories/local_book_repository.dart`
- `lib/data/repositories/local_book_repository_impl.dart`
- `lib/domain/entities/reader_document.dart`
- `lib/domain/entities/local_book.dart`
- `lib/domain/entities/local_chapter.dart`
- `lib/domain/entities/bookshelf_book.dart`
- `lib/domain/entities/book_detail.dart`
- `lib/domain/entities/reading_progress.dart`

---

## 3. 当前主链路

### 3.1 书架列表

主链路：

- `BookshelfService.getAll()` 读取书架集合
- `BookshelfPresentationQueryService` 批量补齐展示态、缓存章信息、本地图书信息
- `BookshelfPage` 做筛选、排序、展示、点击跳转

关键入口：

- 点击阅读：`BookshelfReaderOpenService.resolve(...)`
- 点击详情：`BookshelfPageRouteService.resolveBookDetailRoute(...)`

### 3.2 书籍详情

主链路：

- `BookDetailPage._load(...)`
- `BookDetailService.load(...)` 远程详情 / 目录恢复
- `LocalBookDetailService.load(...)` 本地目录恢复
- `BookDetailReadRouteService.buildChapterRoute(...)` 详情进入阅读页

### 3.3 阅读器

主链路：

- `ReaderEntryRouteResolver` 构造阅读路由
- `ReaderPage._bootstrap()` 恢复设置、进度、目录快照、正文缓存
- `SourceContentProvider / LocalContentProvider.loadChapterContent(...)` 取正文
- `ReaderContentLoadingController.buildResolvedContent(...)` 构建段落与渲染模型
- `ReaderPaginationEngine.paginateParagraphs(...)` 分页
- `ReaderAnnotatedText` / `reader_page_content_rendering.dart` 完成正文绘制

---

## 4. 已确认热点

### A. 书架列表热点

- `BookshelfPage` 文件体量过大，仍承担过多筛选、展示态、入口交互编排
- 书架展示态虽已部分批量化，但页面层仍残留较多状态拼装和切换逻辑
- `BookshelfService` 仍以 `SharedPreferences + JSON` 维护整库，集合读写和排序切换仍偏重
- 书架点击虽然已完成“先跳阅读页再恢复”的一轮治理，但入口与后续恢复口径还没有统一到全链路文档

### B. 书籍详情热点

- `BookDetailPage` 同时管理详情加载、书架状态、元数据编辑、目录搜索、换源、索引状态
- 详情页根部直接订阅主题态并持有大量局部状态，整页重建成本较高
- 详情页进入阅读时，目录、缓存、书架状态和本地索引的责任边界仍需继续收口

### C. 阅读器热点

- `ReaderPage` 文件过大，bootstrap、正文恢复、分页、交互、背景、批注都在同一状态对象里
- 正文进入阅读器后，仍要在 UI isolate 上做 `ReaderDocument` 构建、段落拆分、render item 生成
- 分页虽然已做让出主线程，但仍运行在 UI isolate，长章仍存在压力
- `ReaderAnnotatedText` 中 `TextPainter`、`computeLineMetrics()`、`CustomPainter` 仍可能在滚动时持续吃帧
- 自定义背景路径判断、图片缩放、编码仍会占用主线程

### D. 本地数据热点

- `getChapterById()` / `getChapterByIndex()` 仍会把正文、图片 JSON、`ReaderDocument` 一起映射出来
- `LocalChapterContentService._resolveChapter(...)` 在兜底时仍可能回退到 `getChapters(book.id)` 全量重读
- `ReaderDocument.fromContent(...)` / `ReaderDocument.fromJson(...)` 都是大字符串和大 JSON 的 CPU 工作

---

## 5. 治理原则

- 页面层只负责渲染、交互分发、轻量状态切换
- 入口页不承担跨链路恢复编排
- 非正文场景不得读取正文 payload
- 能批量算的，不做 item 级重复计算
- 能缓存的，不重复解码
- 能延后到首屏后的，不阻塞首屏
- 能下放到后台 isolate 的，不留在 UI isolate

专项核心原则：

- **先可见，再补齐**
- **先轻路由，再重恢复**
- **先正文，再附属状态**
- **默认不预取用户当前看不到、也暂时用不到的内容**

按需加载口径：

- 折叠态目录，不应阻塞详情页首屏
- 未展开的附加面板，不应提前请求对应数据
- 未进入的阅读模式，不应提前做对应重计算
- 仅在用户即将使用，或命中高价值缓存预热窗口时，才启动延后任务

### 5.1 立即加载 / 按需加载 / 后台预热审计口径

#### A. 书架列表

应立即加载：

- 书架书目基础集合
- 每个书卡最小展示信息：标题、作者、封面占位、书源类型、本地/在线标识
- 当前筛选、排序、布局偏好
- 当前页首屏需要展示的继续阅读入口文案

应按需加载：

- 进入视口外书卡的补充展示态
- 大结果集下全部书卡的完整进度展示换算
- 缓存章节详情文案
- 批量模式相关状态
- 分类/标签管理的完整编辑能力

可后台预热：

- 首屏书卡的 metadata override
- 本地图书补充元信息
- 缓存章节数量 / 最近缓存章节标题
- 最近阅读记录
- 书源能力类型映射

当前实现备注：

- `BookshelfPage` 初始化后会直接 `_loadBookshelf()`，并在加载过程中并发拉取 source type、本地图书、metadata override 等展示态
- 这类信息大部分适合“首屏最小集合 + 首屏书卡补齐 + 非首屏后台补齐”的分层，而不是一次性准备整页完整展示态

#### B. 书籍详情

应立即加载：

- 详情主体：书名、作者、简介、封面、来源名
- 进入阅读按钮是否可见
- 加入书架 / 已在书架状态
- 基础错误态、loading 态

应按需加载：

- 目录列表
- 目录搜索
- 章节缓存面板
- 换源候选列表
- 本地高级选项
- 元数据编辑面板里的附属数据

可后台预热：

- 本地图书元信息
- metadata override
- 书架归属状态
- 命中缓存时的背景 refresh
- 用户已经展开过目录后的目录缓存刷新

当前实现备注：

- `BookDetailPage._load()` 当前直接调用 `detailProvider.loadDetail(...)`
- `BookDetailService.load(...)` 当前会串行完成 `detail + chapters`
- 这意味着即使目录 UI 折叠，目录也已被提前请求；后续应拆成“详情主体加载”和“目录加载”两段

#### C. 阅读器

应立即加载：

- 当前章可见正文或可见缓存正文
- 与当前章位置恢复直接相关的最小进度信息
- 当前阅读模式首屏必要设置
- 最基础的错误态和占位态

应按需加载：

- 完整目录
- 相邻章节正文
- 相邻章节预分页
- 批注工具条
- 目录搜索
- 背景图库管理
- 非当前阅读模式相关的渲染准备

可后台预热：

- 当前章分页缓存落盘
- 相邻章节正文缓存
- 相邻章节分页缓存
- 目录快照持久化
- 书架状态刷新
- 字体、背景预览、非首屏面板资源

当前实现备注：

- `ReaderPage._bootstrap()` 当前已经优先走 progress、可见正文缓存、TOC snapshot、detail cache
- 但 settings、visual overrides、背景预览、TOC、detail、chapter load 仍在同一 bootstrap 链路内
- 后续应继续把“正文可见之后才需要”的能力从 bootstrap 关键路径中剥离

#### D. 本地数据与正文模型

应立即加载：

- 当前章节正文恢复必须的最小 payload
- 进入阅读所需的首章或当前章身份

应按需加载：

- 完整 `ReaderDocument`
- 全量章节正文
- 批注定位辅助数据
- 连续滚动模式相邻章节正文

可后台预热：

- 当前章 `ReaderDocument` 扩展结构
- 相邻章节轻量元信息
- 目录快照与分页缓存

当前实现备注：

- `getChapterById()` / `getChapterByIndex()` 仍会把正文、图片 JSON、`ReaderDocument` 一起映射出来
- 后续应把“正文文本”“文档结构”“目录元信息”拆成更细粒度的数据读取级别

---

## 6. 分阶段执行计划

### Phase 0：建立统一基线

目标：

- 统一“书架列表 / 详情页 / 阅读器”三条链路的性能口径

任务：

- [ ] 统一埋点字段：书架首帧、详情首帧、阅读正文可见、首次翻页完成
- [ ] 区分在线书、本地图书、有缓存、无缓存四类场景
- [ ] 明确 UI thread 与 raster thread 的真机采样口径
- [ ] 记录 Android 真机基线：书架滑动、详情打开、阅读首开、首次翻页

完成标准：

- 三条链路使用同一套耗时命名
- 能明确区分“入口阻塞”“数据恢复阻塞”“渲染阻塞”

### Phase 1：书架列表继续收口

目标：

- 书架页只保留列表展示和交互分发
- 列表滑动与切换视图更稳定

任务：

- [ ] 拆分 `BookshelfPage`，把筛选、排序、批量模式、书卡展示态继续下沉
- [ ] 评估 `BookshelfService` 的整库 `SharedPreferences` 读写是否迁移到更稳定的数据层
- [ ] 统一书架书卡展示态缓存键，减少页面层重复字符串处理和状态拼装
- [ ] 审计书架切换筛选、搜索、批量模式时的无效重建
- [ ] 让 `BookshelfReaderOpenService` 成为唯一阅读入口判定能力

完成标准：

- `bookshelf/presentation` 不再继续增长业务编排
- 书架滑动和筛选切换时无明显整页抖动

### Phase 2：书籍详情职责收口

目标：

- 详情页成为“详情展示 + 阅读跳转 + 编辑入口”的稳定层，不再承担重恢复

任务：

- [ ] 继续拆分 `BookDetailPage` 的展示、目录、元数据编辑、换源状态
- [ ] 收口“详情进入阅读”逻辑，统一走 `BookDetailReadRouteService`
- [ ] 把书架状态、本地索引状态、元数据编辑状态继续下沉到 application service
- [ ] 审计详情页根部 provider 订阅，避免无关状态驱动整页重建
- [ ] 建立详情页首屏必要态与补充态清单
- [ ] 拆分详情主体加载与目录加载，默认只请求详情主体，目录在点击“目录”或进入需要目录的操作时再请求
- [ ] 为目录建立独立的 loading / cache / refresh 状态，避免把目录请求重新绑回详情主体首屏
- [ ] 评估“最后阅读章节”“缓存章统计”“目录搜索”哪些必须依赖目录，哪些可以继续延后

完成标准：

- 详情页首屏只依赖必要展示态
- 详情页进入阅读时不再混入额外恢复逻辑
- 折叠态目录不会阻塞详情首屏

### Phase 3：阅读器启动链路拆层

目标：

- 阅读器启动只做首屏必须工作，其余恢复延后

任务：

- [ ] 把 `ReaderPage` 启动链路明确拆成“首屏必须 / 首屏后补 / 后台预热”
- [ ] 审计 bootstrap 中所有 `await`，标记是否必须阻塞正文可见
- [ ] 收口可见正文缓存、目录快照、detail cache 的优先级和互斥关系
- [ ] 减少阅读页首次进入时连续 `setState`
- [ ] 继续控制相邻章节预加载和预分页触发时机

完成标准：

- 阅读页出现正文前只保留必要恢复项
- 首屏后补的逻辑不会拖慢首次翻页

### Phase 4：正文解析与本地数据瘦身

目标：

- 把最重的字符串解析、JSON 解码和正文映射从 UI isolate 挪走

任务：

- [ ] 为本地章节正文读取建立“元数据 / 正文 / 正文+文档”分级查询接口
- [ ] 避免 `getChapterById()` 默认就解码完整 `ReaderDocument`
- [ ] 避免 `LocalChapterContentService` 兜底回退到 `getChapters(book.id)` 全量重读
- [ ] 评估 `ReaderDocument.fromContent(...)` 与 `ReaderDocument.fromJson(...)` 的 isolate 化
- [ ] 评估章节缓存 payload 解码与分页缓存落盘读取的 isolate 化

完成标准：

- 本地大章节恢复不再在主线程堆叠多轮 JSON / 字符串解析
- 数据层语义明确区分“拿目录”和“拿正文”

### Phase 5：阅读器渲染与交互减负

目标：

- 降低滚动、翻页、批注、背景渲染对 UI / raster 的持续压力

任务：

- [ ] 继续优化 `ReaderPaginationEngine`，评估是否需要后台分页或增量分页
- [ ] 为 `ReaderAnnotatedText` 增加精确 `shouldRepaint` 与测量缓存
- [ ] 审计 `TextPainter`、`computeLineMetrics()`、`CustomPainter` 的重复调用
- [ ] 把背景图片缩放、编码移到 isolate
- [ ] 评估顶部/底部 `BackdropFilter` 在低端机的降级策略

完成标准：

- 首次翻页不再带动整页交互明显失灵
- 长章滚动和批注显示更稳定

### Phase 6：回归、观测与文档收口

目标：

- 建立长期可维护的性能回归机制

任务：

- [ ] 为书架、详情、阅读器建立最小 smoke / service 回归集
- [ ] 记录真机回归结果和基线对比
- [ ] 回填每阶段状态、时间和偏差说明
- [ ] 若实施与既有计划有偏差，同步更新关联文档

完成标准：

- 有统一的最小性能回归清单
- 后续性能问题可以直接定位到链路阶段

---

## 7. 优先级排序

P0：

- 阅读器启动链路拆层
- 本地章节正文读取瘦身
- 正文解析与 `ReaderDocument` 构建降主线程占用

P1：

- 书架列表职责继续收口
- 详情页状态和订阅收口
- 阅读器渲染层缓存与降频

P2：

- 背景图处理 isolate 化
- BackdropFilter 降级策略
- 长期数据层迁移与持久化结构优化

---

## 8. 验收口径

必须覆盖以下场景：

- 在线书：书架进入详情
- 在线书：书架直接进入阅读
- 在线书：阅读器首次翻页
- 本地图书：已完成索引直接进入阅读
- 本地图书：未完成索引走 bootstrap 预览
- 长章节：首次打开、首次翻页、连续翻页
- 书架大列表：滚动、切换筛选、切换布局

通过标准：

- 无新增同步重 I/O 放进 build 或首屏关键路径
- UI thread 卡顿热点可以从日志或 profile 中解释
- 核心链路至少有一条自动化回归或 smoke 覆盖

---

## 9. 当前建议的执行顺序

推荐顺序：

1. Phase 0
2. Phase 3
3. Phase 4
4. Phase 5
5. Phase 1
6. Phase 2
7. Phase 6

原因：

- 当前最影响用户体感的是阅读器首开和首次翻页
- 阅读器问题不先收口，书架和详情的轻量化收益会被放大后的正文卡顿抵消
- 数据层和渲染层热点处理完，再回头收口书架与详情，收益更稳定

---

## 10. 开发阶段任务清单

说明：

- 本节用于日常开发执行
- 每完成一项直接勾选
- 若确认不做，在该项后补一句原因
- 每阶段结束后同步更新验收结果

### Stage 0：基线与分层规则落地

目标：

- 统一“立即加载 / 按需加载 / 后台预热”的执行口径
- 建立可对比的性能基线

任务：

- [x] 为书架列表补 `首屏可见耗时` 埋点
- [x] 为书籍详情补 `详情主体可见耗时` 埋点
- [x] 为书籍详情补 `目录首次展开耗时` 埋点
- [x] 为阅读器补 `正文首次可见耗时` 埋点
- [x] 为阅读器补 `首次翻页完成耗时` 埋点
- [x] 为阅读器补 `正文缓存命中 / TOC 快照命中 / detail cache 命中` 区分字段
- [ ] 记录 Android 真机基线：书架滑动、详情首开、目录展开、阅读首开、首次翻页
- [x] 将本文件第 5.1 节作为后续需求评审默认口径

验收：

- [ ] 三条链路使用统一耗时字段
- [ ] 能明确区分“首屏阻塞”和“附属信息阻塞”

### Stage 1：书籍详情按需加载拆分

目标：

- 详情页首屏只加载主体
- 目录、目录搜索、缓存章节面板改为按需加载

任务：

- [x] 拆分 `BookDetailService.load(...)` 为“详情主体加载”和“目录加载”两段能力
- [x] 调整 `BookDetailPage._load()`，默认只请求详情主体
- [x] 点击“目录”按钮时再触发目录请求
- [x] 为目录建立独立的 `loading / success / error / refresh` 状态
- [x] 目录首次加载成功后写入目录缓存，二次展开优先命中缓存
- [x] 目录搜索仅在目录已加载后可用
- [x] 缓存章节面板仅在用户点击时读取章节列表
- [x] 审计“开始阅读 / 继续阅读 / 阅读最新章”是否依赖完整目录
- [x] 若某个首屏操作需要目录，只补最轻的首章/末章信息，不回退为全量目录请求

验收：

- [x] 折叠态目录不阻塞详情首屏
- [x] 目录首次展开时才出现章节请求日志
- [x] 详情页基础信息可在目录未加载时完整可用

### Stage 2：书架列表分层加载

目标：

- 书架列表先稳定出首屏，再逐步补齐书卡附属信息

任务：

- [x] 明确书架首屏必要字段：标题、作者、封面占位、来源、本地/在线标识
- [x] 将 metadata override 补齐改为“首屏书卡优先，非首屏后台补齐”
- [ ] 将本地图书补充信息改为“按当前视口和首屏优先级加载”
- [x] 将缓存章节数量、最近缓存章节标题改为后台补齐
- [ ] 将最近阅读记录卡片改为不阻塞书架主列表首屏
- [x] 审计 `_loadBookshelf()` 是否一次性准备了过多非首屏展示态
- [x] 为书架首屏外书卡建立延迟补齐策略
- [ ] 复查筛选、排序、搜索切换时是否触发整批展示态重算

验收：

- [x] 书架首屏可在附属展示态未补齐时稳定显示
- [ ] 书架滑动时附属信息补齐不会造成明显掉帧

### Stage 3：阅读器启动链路再瘦身

目标：

- 阅读器启动只保留“让当前章正文可见”的必要工作

当前进展：

- 已完成：正文缓存优先、书架状态刷新延后、目录后补、当前章无目录直开
- 已完成：非首屏设置恢复继续下沉、背景资源准备继续后移、目录/缓存面板缺目录时按需自恢复

任务：

- [x] 列出 `ReaderPage._bootstrap()` 中所有步骤的分层归属：立即加载 / 按需加载 / 后台预热
- [x] 继续下沉非首屏必须设置恢复项
- [x] 将背景图库预览、非当前模式预处理从 bootstrap 关键路径移出
- [x] 将书架状态刷新改为正文可见后再做
- [x] 将完整目录恢复改为“只有需要目录 UI 或章节导航时才补齐”
- [x] 保证正文缓存命中时，不再被后续目录/详情恢复阻塞交互
- [x] 明确相邻章节预加载和预分页的延后触发时机

验收：

- [x] 正文缓存命中时可先显示正文，再补目录和附属状态
- [x] 有章节路由时可先直接加载当前章正文，目录随后补齐
- [x] 首次翻页不再被 bootstrap 尾部任务拖慢

### Stage 4：本地数据读取分级

目标：

- 把“目录元信息”“正文文本”“文档结构”拆成不同读取层级

任务：

- [ ] 为 `LocalBookRepository` 明确三类接口：meta-only、content-only、content-with-document
- [ ] 审计 `getChapterById()` / `getChapterByIndex()` 的调用方，标记哪些其实只需要 meta
- [ ] 避免 `getChapterById()` 默认解码完整 `ReaderDocument`
- [ ] 避免 `LocalChapterContentService._resolveChapter(...)` 兜底回退到 `getChapters(book.id)` 全量重读
- [ ] 为本地章节正文恢复建立更轻的首屏读取路径
- [ ] 为本地章节文档结构建立延迟解码策略

验收：

- [ ] 非正文场景不再读取正文 payload
- [ ] 正文场景不再默认附带完整文档结构解码

### Stage 5：正文模型与分页计算降主线程占用

目标：

- 收口正文字符串处理、文档构建、分页、批注绘制对 UI isolate 的压力

任务：

- [ ] 评估 `ReaderDocument.fromContent(...)` isolate 化
- [ ] 评估 `ReaderDocument.fromJson(...)` isolate 化
- [ ] 评估 `ReaderContentLoadingController.buildResolvedContent(...)` 中段落/渲染模型构建的缓存或 isolate 化
- [ ] 继续优化分页触发频率，避免重复整章分页
- [ ] 为批注渲染补 `TextPainter` / line metrics 缓存
- [ ] 为 `ReaderAnnotatedText` 增加精确 `shouldRepaint`
- [ ] 审计连续滚动模式下相邻章节加载是否抢占当前章交互

验收：

- [ ] 长章节进入阅读后不会出现长时间主线程占满
- [ ] 批注较多时滚动和翻页仍保持稳定

### Stage 6：图片、背景与视觉附属能力延后

目标：

- 不让图片处理和背景资源成为正文首屏阻塞项

任务：

- [ ] 将背景图片缩放、压缩、编码移到后台 isolate
- [ ] 清理阅读器背景相关同步文件判断
- [ ] 将背景图库预览改为点击面板后再准备完整资源
- [ ] 评估顶部/底部 `BackdropFilter` 的低端机降级策略
- [ ] 审计详情封面、本地封面、阅读背景在 build 期的同步路径探测

验收：

- [ ] 背景资源不会阻塞阅读正文首屏
- [ ] 切换背景或进入有背景主题的阅读页时无明显卡峰

### Stage 7：回归与文档维护

目标：

- 把本次治理沉淀成长期可维护的执行基线

任务：

- [ ] 为书架、详情、阅读器分别补最小 smoke 回归
- [ ] 为“详情主体加载 / 目录按需加载”补服务层测试
- [ ] 为“阅读器正文缓存优先”补回归测试
- [ ] 为“本地章节读取分级”补仓储/数据层测试
- [ ] 回填每阶段完成日期、结果和偏差说明
- [ ] 若执行过程改变了加载分层口径，同步更新本文件第 5.1 节

验收：

- [ ] 有最小自动化回归集
- [ ] 文档状态与实际代码一致
