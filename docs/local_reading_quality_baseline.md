# 本地阅读质量门槛与平台回归基线

更新时间：2026-04-21  
用途：作为 `14.8 测试与质量门槛` 的落地结果，定义本地阅读后续改动必须遵守的最小回归范围、平台策略与质量基线。

## 1. 回归目标

本地阅读后续改动至少要守住三件事：

- 不再出现“导入时一种编码、阅读时另一种编码”的链路分裂
- `ready` 状态始终表示“目录和正文都可直接读取”
- 页面提示必须明确区分“重建目录”和“重新导入”

## 2. 平台回归策略

### 2.1 编码层平台矩阵

编码相关回归按以下平台矩阵执行：

- Android：优先验证 `flutter_charset_detector`
- iOS：优先验证 `flutter_charset_detector`
- Web：验证插件链路可用或安全回退
- Desktop：验证 Dart fallback 可稳定工作

### 2.2 同一批样本必须跨平台复用

后续编码探测回归必须复用同一批样本，不允许 Android / iOS 各自随意挑样本：

- UTF-8 正常文本
- UTF-16LE / UTF-16BE
- GBK
- GB18030
- Big5
- ASCII 头 + 中文正文的大文件
- 截断 UTF-8 sample

### 2.3 平台验证原则

- 同一文件在 Android 与 iOS 下的 `charsetName` 和正文核心内容必须一致
- 若平台插件不可用，必须有明确 fallback，而不是 silent failure
- 平台差异允许体现在实现层，不允许体现在业务语义层

## 3. 当前自动化测试基线

以下测试应视为本地阅读主链路的最小保护：

### 3.1 编码与解码

- `test/features/reader/application/local/local_text_encoding_detector_test.dart`
- `test/features/reader/application/local/local_book_preview_service_test.dart`

### 3.2 索引语义

- `test/features/reader/application/local/local_book_index_service_test.dart`

重点覆盖：

- `ready` 章节正文必须可直接读取
- offset-only 旧数据会被识别为 `stale`
- 文件变化后能正确转为 `stale`

### 3.3 正式阅读链路

- `test/features/reader/application/local/local_chapter_content_service_test.dart`
- `test/features/reader/application/local_content_provider_test.dart`

重点覆盖：

- 正式阅读只消费稳定索引结果
- bootstrap 只走 preview
- 不再现场补正文

### 3.4 多格式 parser

- `test/features/reader/application/local/epub_local_book_parser_test.dart`
- `test/features/reader/application/local/html_local_book_parser_test.dart`
- `test/features/reader/application/local/markdown_local_book_parser_test.dart`
- `test/features/reader/application/local/pdf_local_book_parser_test.dart`
- `test/features/reader/application/local/kindle_local_book_parser_test.dart`
- `test/features/bookshelf/application/local_book_import_service_test.dart`

## 4. 性能基线

本地阅读后续改动不要求当前就引入复杂 benchmark 框架，但必须保留以下“高频路径基线”：

### 4.1 导入高频路径

- 小 TXT 导入
- 大 TXT 导入
- HTML / Markdown 导入
- EPUB / Kindle 容器导入

观察项：

- 导入是否可立即返回书架
- 是否仍维持后台索引模式
- 是否出现明显同步阻塞

### 4.2 索引高频路径

- 大 TXT 流式分章
- EPUB 建目录与正文持久化
- Kindle HTML 与资源落库

观察项：

- 是否仍能完成正文持久化
- 是否还把 `ready` 书判成可现场补正文
- 是否出现大文件回归性退化

### 4.3 阅读高频路径

- 本地详情打开
- 正式正文打开
- bootstrap 预览打开

观察项：

- 正文是否直读库
- 错误是否明确提示“重建目录 / 重新导入”
- 页面是否不再触发隐式重索引

## 5. 文案一致性基线

后续与本地图书相关的页面提示，应优先通过统一策略层维护：

- `LocalBookWorkflowPolicy`

当前需要保持一致的场景：

- 书架页状态说明
- 详情页状态卡
- 目录 warning
- 阅读失败文案
- 非 ready 打开提示
- 导入成功提示

## 6. 推荐回归命令

### 6.1 本地阅读主链路

```bash
flutter test --no-test-assets \
  test/features/reader/application/local/local_text_encoding_detector_test.dart \
  test/features/reader/application/local/local_book_preview_service_test.dart \
  test/features/reader/application/local/local_book_index_service_test.dart \
  test/features/reader/application/local/local_chapter_content_service_test.dart \
  test/features/reader/application/local_content_provider_test.dart
```

### 6.2 多格式与导入

```bash
flutter test --no-test-assets \
  test/features/reader/application/local/epub_local_book_parser_test.dart \
  test/features/reader/application/local/html_local_book_parser_test.dart \
  test/features/reader/application/local/markdown_local_book_parser_test.dart \
  test/features/reader/application/local/pdf_local_book_parser_test.dart \
  test/features/reader/application/local/kindle_local_book_parser_test.dart \
  test/features/bookshelf/application/local_book_import_service_test.dart
```

### 6.3 静态检查

```bash
flutter analyze \
  lib/domain/entities/local_book.dart \
  lib/domain/entities/local_chapter.dart \
  lib/features/reader/application/local \
  lib/features/bookshelf/application/local_book_import_service.dart \
  lib/features/bookshelf/presentation/bookshelf_page.dart \
  lib/features/book/presentation/book_detail_page.dart \
  lib/features/reader/presentation/reader_page.dart
```

## 7. 收口标准

`14.8` 完成的判定标准：

- 已有跨平台编码回归策略文档
- 已有主链路自动化测试清单
- 已有高频路径性能观察项
- 已有页面文案一致性基线
- 后续任何本地阅读改造都可以按本文件直接执行回归
