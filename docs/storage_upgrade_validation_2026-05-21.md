# 存储升级验证清单

更新时间：2026-05-21

状态：Phase 5 首版回归清单

关联文档：

- [sto.md](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/docs/sto.md)
- [storage_governance_spec_2026-05-21.md](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/docs/storage_governance_spec_2026-05-21.md)
- [storage_inventory_2026-05-20.md](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/docs/storage_inventory_2026-05-20.md)

## 1. 本轮验证目标

本轮验证聚焦两类升级链：

- 数据库 schema 升级链
- `SharedPreferences` / 文件索引的高风险迁移链

当前已纳入可执行验证的迁移样本：

- `v27 -> v28`：新增 `reading_progresses`
- `reader.progress.<bookId>` -> `reading_progresses`
- `app.advancedThemes` -> `Documents/advanced_themes/index.json`

## 2. 升级测试矩阵

| 场景 | 样本 | 当前状态 | 验证方式 |
|---|---|---|---|
| 老用户单次升级 | 数据库 `v27 -> v28` | 已覆盖 | 自动测试 |
| 老用户单次升级 | 旧阅读进度 prefs -> 数据库 | 已覆盖 | 自动测试 |
| 老用户单次升级 | 旧高级主题 prefs -> 文件索引 | 已覆盖 | 自动测试 |
| 老用户多次覆盖安装 | 重复启动多次读取新结构 | 部分覆盖 | 手工 / 后续自动化 |
| 大量本地图书用户 | 本地图书 + 阅读进度并存 | 未覆盖 | 后续补 |
| 大量主题/图集用户 | 高级主题 + 图集迁移并存 | 部分覆盖 | 当前仅主题 |
| 清缓存后重启 | 缓存删空但资产保留 | 未覆盖 | 后续补 |
| 删除重装后恢复 | 重新安装后托管文件可恢复 | 未覆盖 | 后续补 |

## 3. 当前自动化验证项

### 3.1 数据库升级链

- [app_database_reading_progress_migration_test.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/test/data/datasources/local/app_database_reading_progress_migration_test.dart)
  - 验证 `v27` 升级到 `v28` 时会自动创建 `reading_progresses`
  - 验证索引 `idx_reading_progresses_updated_at` 存在

### 3.2 阅读进度迁移链

- [reader_preferences_service_test.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/test/features/reader/application/reader_preferences_service_test.dart)
  - 验证新写阅读进度落数据库
  - 验证旧 `reader.progress.<bookId>` 首次读取后迁移到数据库
  - 验证迁移成功后旧 key 被清理

### 3.3 高级主题迁移链

- [advanced_theme_service_test.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/test/features/mine/application/advanced_theme_service_test.dart)
  - 验证新写主题落 `advanced_themes/index.json`
  - 验证旧 `app.advancedThemes` 首次读取后迁移到 `index.json`
  - 验证迁移成功后旧 key 被清理

## 4. 迁移失败回滚策略

本轮执行口径：

1. 新结构读取优先
2. 如果新结构缺失，则回退读旧结构
3. 只有在新结构写入成功后，才清理旧结构
4. 迁移失败不能阻塞主流程
5. 迁移失败时保留旧结构，等待下次重试

## 5. 异常样本回归

当前已覆盖：

- 旧阅读进度 payload 缺少 `chapterPositionRatio` 时拒绝迁移

后续待补：

- 高级主题索引文件损坏
- 高级主题目录存在但索引文件为空
- 图集旧 JSON 中路径失效
- 阅读进度数据库记录存在但字段异常

## 6. 继续补齐建议

下一批建议纳入自动化：

1. `coverGallery.galleries` 迁移验证
2. `launchImageGallery.galleries` 迁移验证
3. 缓存删除后资产保留回归
4. 多次覆盖安装重复启动幂等回归
