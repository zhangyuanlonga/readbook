# 本地阅读重构发布说明（草案）

## 版本目标
- 下线 `TXT 目录规则配置` 整体功能，统一为内置自动分章。
- 去除本地阅读链路中与规则配置相关的业务污染字段。
- 保持历史数据库升级可用，并在升级时清理废弃字段。

## 用户可见变更
- “我的”页不再提供 `TXT 目录规则` 入口。
- 本地 TXT 阅读改为固定的自动分章策略。
- 仍保留：重新索引、长章节拆分、诊断信息等能力。

## 技术变更
- 删除模块：
  - `lib/features/mine/presentation/rule_config_page.dart`
  - `lib/features/reader/application/local/txt_toc_rule_settings_service.dart`
  - `test/features/reader/application/local/txt_toc_rule_settings_service_test.dart`
- 自动分章命名收口：
  - `txt_toc_rules.dart` -> `txt_auto_chapter_patterns.dart`
- 业务模型去污染：
  - `LocalBook` 移除 `txtTocRuleName / txtTocRulePattern`。
- 数据库升级：
  - `schemaVersion` 升级到 `15`。
  - `v14 -> v15` 时重建 `local_books`，移除废弃列：
    - `txt_toc_rule_name`
    - `txt_toc_rule_pattern`

## 兼容性与风险
- 本地书籍内容、章节、索引状态均保留；仅移除无用规则配置列。
- 风险点：升级过程中 `local_books` 表重建。
- 缓解措施：已增加迁移回归测试，覆盖 `v14 -> v15` 列清理与数据保留。

## 回归验证（已执行）
- `flutter analyze`
- `test/data/datasources/local/app_database_reading_record_migration_test.dart`
- `test/data/datasources/local/app_database_local_book_test.dart`
- `test/data/repositories/local_book_repository_impl_test.dart`
- `test/features/reader/application/local/*`
- `test/features/bookshelf/application/local_book_import_service_test.dart`

## 发布后观察建议
- 监控升级后本地阅读打开率、索引失败率、崩溃率。
- 重点关注“升级后本地书缺失/目录为空/正文无法加载”反馈。
