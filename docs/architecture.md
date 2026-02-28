# Flutter AppRead 技术架构设计

## 1. 架构目标

- 对外兼容书源规则，对内保持稳定且可演进的数据模型。
- 将“规则执行复杂度”与“阅读业务复杂度”分离。
- 支持后续扩展更多内容类型和规则能力。

## 1.1 MVP 技术栈（阶段 0 - 任务 1）

- 状态管理：Riverpod（`flutter_riverpod`）
- 路由：GoRouter（`go_router`）
- 网络：Dio（`dio`）
- 解析：`html` + `json_path` + Dart `RegExp`
- 本地存储：Drift + SQLite（`drift`、`sqlite3_flutter_libs`）
- 日志：`logger`

选型原则：

- 优先选择生态稳定、跨平台成熟的 Flutter 主流方案。
- 能力按 MVP 先后拆分：先跑通链路，再补高级兼容能力。
- 保留替换空间（例如 Rule Engine 解析能力后续可渐进增强）。

## 2. 分层架构

建议采用简化 Clean Architecture：

- UI 层（features）
- Domain 层（entities + use cases）
- Data 层（repositories + local/remote data source）
- Core 引擎层（rule engine + network + parser + logger）

## 3. 建议目录结构

```text
lib/
  app/
    app.dart
    router.dart
    shell_scaffold.dart
    bootstrap.dart
  core/
    network/
      http_client.dart
      request_context.dart
      interceptors.dart
    rule_engine/
      rule_engine.dart
      rule_parser.dart
      executors/
        html_executor.dart
        regex_executor.dart
        jsonpath_executor.dart
      processors/
        text_cleaner.dart
        url_template_resolver.dart
    logging/
      app_logger.dart
      source_log_store.dart
    errors/
      app_exception.dart
      error_codes.dart
      error_stage.dart
    result/
      result.dart
  domain/
    entities/
      source_definition.dart
      search_request_context.dart
      book.dart
      chapter.dart
      reading_progress.dart
    repositories/
      source_repository.dart
      book_repository.dart
    usecases/
      import_sources.dart
      search_books.dart
      get_book_detail.dart
      get_toc.dart
      get_chapter_content.dart
  data/
    models/
      legado_source_raw.dart
      source_record.dart
    adapters/
      legado_source_adapter.dart
    repositories/
      source_repository_impl.dart
      book_repository_impl.dart
    datasources/
      local/
        app_database.dart
      remote/
  features/
    bookshelf/
    source/
      application/
        source_import_service.dart
        source_validator.dart
      presentation/
    search/
      application/
        search_result_parser.dart
      presentation/
    book/
    reader/
  shared/
    widgets/
    utils/
```

## 4. 核心模块职责

## 4.1 Source Adapter（关键）

职责：

- 接收外部书源 JSON（Legado 风格）并校验。
- 转换为内部统一模型 `SourceDefinition`。
- 保留原始字段，便于后续增强兼容。

原则：

- 内部代码不直接依赖外部字段名。
- 所有字段映射集中在 Adapter 层。

## 4.2 Rule Engine（关键）

职责：

- 解析规则表达式。
- 对响应内容执行提取逻辑。
- 返回结构化结果（搜索结果、目录项、正文文本）。
- 维护 Legado `java.*` bridge 能力画像（`full/partial/unsupported`），避免兼容统计与真实语义脱节。

执行链：

1. 请求构建（URL 模板变量替换）
2. 网络请求（header/cookie/timeout）
3. 响应解码（UTF-8/GBK）
4. 规则提取（HTML/Regex/JSONPath）
5. 文本清洗与结构化输出

## 4.3 Fetch Pipeline

职责：

- 封装统一 HTTP 访问行为，屏蔽不同站点差异。
- 输出可追踪日志（请求、响应摘要、错误码）。

建议能力：

- 超时与重试。
- 自定义 UA 和 Header。
- Cookie 管理（MVP 可先只读写内存，后续持久化）。

## 4.4 Reader Engine

职责：

- 文本分页或滚动渲染。
- 章节预加载（当前章前后）。
- 阅读设置和进度持久化。

## 5. 数据模型建议

## 5.1 SourceDefinition

最小字段建议：

- id
- name
- baseUrl
- group
- enabled
- searchRule
- detailRule
- tocRule
- contentRule
- headers
- lastCheckStatus

## 5.2 Book

- id（来源 + 详情链接 hash）
- sourceId
- title
- author
- intro
- coverUrl
- detailUrl

## 5.3 Chapter

- id
- bookId
- title
- chapterUrl
- index
- content
- fetchedAt

## 6. 状态流转（核心流程）

## 6.1 搜索流程

UI 输入关键词 -> UseCase.searchBooks -> BookRepository -> RuleEngine(search) -> 返回 Book 列表 -> UI 展示。

## 6.2 阅读流程

点击书籍 -> 拉取详情 -> 拉取目录 -> 点击章节 -> 拉取正文 -> 内容清洗 -> 渲染页面 -> 保存进度。

## 7. 错误模型设计

建议统一异常类型：

- `NetworkException`
- `RuleParseException`
- `RuleMatchEmptyException`
- `DecodeException`
- `UnknownSourceException`

每个异常要包含：

- sourceId
- stage（search/detail/toc/content）
- requestUrl
- briefMessage

## 8. 测试策略

- 单元测试：Adapter 映射、RuleParser、TextCleaner。
- 仓库测试：Mock 网络响应验证四段流程。
- 回归样本：维护一组书源+关键词样本，验证兼容率。

## 9. 演进策略

- MVP：HTML + Regex 优先。
- v0.2：补 JSONPath 和更丰富后处理。
- v0.3：引入 JS 沙箱执行。
- v0.4：插件化扩展内容类型（漫画/听书）。
