# 本地阅读重构发版检查清单

## 目标范围
- 仅覆盖本地图文链路：导入、索引、目录展示、正文加载、重索引、迁移升级。
- 不包含书源网络解析的旧测试基线。

## 代码检查
- [ ] 已移除 TXT 规则配置入口与页面
- [ ] 本地 TXT 仅保留内置自动分章策略
- [ ] `LocalBook` 不再包含 `txtToc*` 业务字段
- [ ] `local_books` 表已清理废弃列（迁移到 v15）
- [ ] 本地错误文案统一为“自动分章/索引”语义

## 必跑命令
```bash
flutter analyze
flutter test test/data/datasources/local/app_database_reading_record_migration_test.dart
flutter test test/data/datasources/local/app_database_local_book_test.dart
flutter test test/data/repositories/local_book_repository_impl_test.dart
flutter test test/features/reader/application/local/txt_local_book_parser_test.dart test/features/reader/application/local/epub_local_book_parser_test.dart test/features/reader/application/local/local_book_index_service_test.dart test/features/reader/application/local/local_chapter_content_service_test.dart test/features/bookshelf/application/local_book_import_service_test.dart
```

## 手工冒烟
- [ ] 导入 TXT（UTF-8）
- [ ] 导入 TXT（GBK/UTF-16）
- [ ] 进入详情页查看目录
- [ ] 打开正文并前后翻章
- [ ] 执行“重新索引”
- [ ] 验证“长章节拆分”开关生效
- [ ] 升级场景下旧本地书仍可正常打开

## 发布后观察（48h）
- [ ] 本地导入成功率
- [ ] 本地索引失败率
- [ ] 本地阅读打开失败率
- [ ] 用户反馈关键词：目录为空、缺章、正文空白、文件丢失
