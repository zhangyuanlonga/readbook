# 功能维度全项目旧字段扫描（2026-05-06）

## 说明

这次扫描的目标不是再做一轮泛关键词统计，而是回答：

- 整个项目里，**每个功能域** 是否还有显式旧字段/旧格式/旧迁移兼容
- 哪些兼容逻辑会继续影响新版功能
- 哪些模块已经基本没有旧字段兼容包袱

## 扫描口径

本次按功能域扫描了：

- `lib/features/*`
- `lib/core/*`
- `lib/app/*`
- `lib/data/*`
- `lib/domain/*`

只统计以下内容：

- 旧字段读取
- 旧 schema 升级
- 旧路径映射
- 旧导入格式兼容
- 旧 identity / 旧数据迁移桥接

不统计以下内容：

- 普通业务 fallback
- 普通 UI 占位 fallback
- 普通错误文案 fallback
- 非历史兼容性质的容错

## 总结

结论先说：

- **功能域层面，已经覆盖全项目核心模块扫描**
- **不是每个文件逐行人工审计**
- **但对于“显式旧字段兼容是否还在主链里”这个问题，项目主干已经基本摸清**

当前仍有显式旧字段兼容或旧格式兼容的主功能域，主要集中在：

1. 阅读器
2. Mine / 主题 / 外观
3. 本地图书
4. Source 运行时
5. Sync
6. 核心存储 / 数据库 / Domain 模型

当前未发现明显旧字段兼容主问题的功能域，主要有：

1. Announcement
2. Home
3. Error
4. Discover
5. Search
6. Bookshelf

说明：

- 上面这些“未发现”是指**模块自身未发现显式旧字段兼容主逻辑**
- 不代表它们完全不受底层旧 identity / 旧数据库 / 旧模型影响

## 功能域扫描表

| 功能域 | 是否已扫 | 是否发现显式旧字段兼容 | 风险 | 结论 |
| --- | --- | --- | --- | --- |
| Announcement | 是 | 否 | 低 | 未见旧字段兼容主逻辑 |
| Auth | 是 | 间接有 | 中 | Feature 层基本无，主要问题在 `core/user`、`core/membership` |
| Book | 是 | 是 | 中 | 换源后仍迁移旧书籍 identity 下的书架/进度/阅读记录 |
| Bookshelf | 是 | 基本无 | 低 | 模块自身未见旧字段兼容主逻辑 |
| Discover | 是 | 基本无 | 低 | 模块自身未见旧字段兼容主逻辑 |
| Error | 是 | 否 | 低 | 未见旧字段兼容主逻辑 |
| Home | 是 | 否 | 低 | 未见旧字段兼容主逻辑 |
| Mine | 是 | 是 | 高 | 主题旧格式兼容最重，另有旧版残留清理 |
| Reader | 是 | 是 | 高 | 旧设置键、旧进度、旧正文桥接、本地 TXT 旧偏移 fallback 都在这里 |
| Search | 是 | 基本无 | 低 | 模块自身未见旧字段兼容主逻辑 |
| Source | 是 | 是 | 中 | 仍有 `legacy()` 工厂和旧运行时入口 |
| Sync | 是 | 是 | 中 | 仍有同步 envelope / manifest 的旧 schema 容忍逻辑 |
| App | 是 | 是 | 中 | 启动期仍跑旧资源路径迁移和旧残留清理 |
| Core | 是 | 是 | 中 | 用户/会员/API 返回结构兼容、资源路径兼容仍存在 |
| Data | 是 | 是 | 高 | 数据库迁移链很长 |
| Domain | 是 | 是 | 高 | 新模型旁边仍保留多处旧字段桥接 |

## 各功能域明细

## 1. Announcement

扫描结果：

- 未发现显式旧字段兼容主逻辑

结论：

- 当前不属于旧字段治理重点模块

## 2. Auth

扫描结果：

- `features/auth/*` 本身未看到显式旧字段兼容主逻辑
- 但登录后用户信息和会员信息依赖：
  - `lib/core/user/user_profile.dart`
  - `lib/core/membership/membership_entitlement.dart`

发现点：

1. [user_profile.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/core/user/user_profile.dart:24)
   仍以旧字段 `vip_level / plan_type / vip_status / vip_expire_at` 解析资料。
2. [membership_entitlement.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/core/membership/membership_entitlement.dart:35)
   仍以旧字段 `vip_level / vip_status / plan_type / max_devices` 为主。

结论：

- Auth 功能域的旧字段问题主要在 Core 层，不在页面层

## 3. Book

扫描结果：

- 发现显式旧 identity 迁移逻辑

发现点：

1. [book_detail_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/book/presentation/book_detail_page.dart:1423)
   换源后仍迁移旧书源下的书架项。
2. [book_detail_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/book/presentation/book_detail_page.dart:1478)
   换源后仍迁移旧 `bookId` 下的阅读进度与阅读记录。

影响：

- 这会继续让旧 identity 链路参与新版换源后的阅读状态同步

结论：

- Book 模块需要纳入断兼容治理

## 4. Bookshelf

扫描结果：

- 模块自身未发现显式旧字段兼容主逻辑

说明：

- 书架会受 `Book` / `Reader` 的 identity 迁移影响
- 但 `bookshelf` 模块内部目前没看到单独的旧字段读取兼容

结论：

- 不作为第一批治理模块

## 5. Discover

扫描结果：

- 模块自身未发现显式旧字段兼容主逻辑

说明：

- 发现页仍会通过 `BookIdentity` / `SourceBookKey` 间接受旧 identity 形状影响
- 但该影响属于 Domain 层，不是 Discover 自己的旧字段兼容代码

结论：

- Discover 本身不是重点

## 6. Error

扫描结果：

- 未发现显式旧字段兼容主逻辑

结论：

- 可排除

## 7. Home

扫描结果：

- 未发现显式旧字段兼容主逻辑

结论：

- 可排除

## 8. Mine

扫描结果：

- 发现大量显式旧格式兼容

发现点：

1. [advanced_theme_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/application/advanced_theme_service.dart:449)
   兼容旧版主题颜色 JSON `version=1`。
2. [advanced_theme_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/application/advanced_theme_service.dart:864)
   兼容导入 Red 主题包。
3. [advanced_theme_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/application/advanced_theme_service.dart:1062)
   兼容导入 RGShare 主题包。
4. [advanced_theme_list_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/advanced_theme_list_page.dart:1269)
   UI 仍暴露旧主题格式兼容导入入口。
5. [cache_management_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/application/cache_management_service.dart:647)
   仍有“旧版残留”扫描逻辑。
6. [cache_management_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/cache_management_page.dart:302)
   UI 仍把“旧版残留”作为正式清理分类。

影响：

- Mine 是当前最重的旧格式兼容入口之一
- 主题兼容直接影响新版主题功能边界

结论：

- Mine 必须列入高优先级治理

## 9. Reader

扫描结果：

- 发现最多的旧字段兼容主逻辑

发现点：

1. [reader_preferences_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/reader_preferences_service.dart:228)
   仍读取旧布局字段：
   `bodyMarginMode / bodyMarginPreset / chapterHeaderMode / pinnedChapterHeaderOffsetX/Y / horizontalPadding`
2. [reader_preferences_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/reader_preferences_service.dart:717)
   仍读取旧自定义背景图单值 key。
3. [reader_preferences_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/reader_preferences_service.dart:878)
   仍保留 `migrateProgress`。
4. [reader_page_source_switch.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/presentation/reader_page_source_switch.dart:808)
   换源后迁移旧 `bookId` 下的进度与阅读记录。
5. [reader_content_loading_controller.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/presentation/reader_content_loading_controller.dart:203)
   正文链路仍回落到 `compatibilityContent`。
6. [chapter_content_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/chapter_content_service.dart:32)
   正文解析结果仍可能回落到 `compatibilityContent`。
7. [epub_local_book_parser.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/local/epub_local_book_parser.dart:133)
   EPUB 解析链仍依赖 `compatibilityContent`。
8. [local_markup_book_parser_support.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/local/local_markup_book_parser_support.dart:463)
   本地图文解析仍输出 `compatibilityContent`。
9. [local_chapter_content_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/local/local_chapter_content_service.dart:218)
   仍有 `LegacyTxtOffsetFallback`，允许旧 TXT 偏移数据继续参与读取。

影响：

- 这是当前“旧字段影响新版功能”最直接的模块

结论：

- Reader 是第一优先级

## 10. Search

扫描结果：

- 模块自身未发现显式旧字段兼容主逻辑

说明：

- Search 会间接受 `BookIdentity` 旧逻辑影响
- 但没发现 Search 模块自己在读旧字段

结论：

- Search 本身不是首批重点

## 11. Source

扫描结果：

- 发现旧运行时入口仍在保留

发现点：

1. [source_runtime_facade.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/source/application/source_runtime_facade.dart:55)
   仍保留 `SourceRuntimeFacade.legacy()`
2. [source_login_runtime_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/source/application/source_login_runtime_service.dart:143)
   仍保留 `SourceLoginRuntimeService.legacy()`

说明：

- 这更像“旧调用路径兼容”，不是字段兼容
- 但它确实会延续旧依赖注入方式

结论：

- Source 模块需要顺手清理 legacy 工厂

## 12. Sync

扫描结果：

- 发现旧同步 envelope / manifest 兼容痕迹

发现点：

1. [sync_stage4_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/sync/application/sync_stage4_service.dart:930)
   当前同步 envelope 固定写 `schemaVersion: 1`。
2. [sync_stage4_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/sync/application/sync_stage4_service.dart:961)
   manifest 更新时，对缺失 `schemaVersion` 的旧数据默认回退到 `1`。
3. [sync_stage4_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/sync/application/sync_stage4_service.dart:896)
   envelope 解码失败时静默返回空集合。

说明：

- Sync 不是旧字段最重的模块
- 但当前同步格式边界并不严格

结论：

- Sync 属于第二梯队治理

## 13. App

扫描结果：

- 启动链仍有旧资源迁移和旧残留清理

发现点：

1. [bootstrap.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/bootstrap.dart:37)
   启动时仍执行 `ManagedAssetPathMigrationService.migrate()`
2. [managed_asset_path_migration_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/startup/managed_asset_path_migration_service.dart:29)
   启动时统一做旧路径迁移
3. [startup_storage_maintenance_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/startup/startup_storage_maintenance_service.dart:70)
   版本启动维护里仍清理 `legacyResidual`

结论：

- App 层还在默认接受旧路径时代的遗留状态

## 14. Core

扫描结果：

- 有明确接口字段兼容和路径兼容

发现点：

1. [app_update_check_result.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/core/app_update/app_update_check_result.dart:46)
   同时兼容 `snake_case` / `camelCase` / 多种 release 容器结构。
2. [user_profile.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/core/user/user_profile.dart:62)
   仍读取旧会员字段口径。
3. [membership_entitlement.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/core/membership/membership_entitlement.dart:60)
   仍以旧会员字段为主。
4. [managed_asset_store.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/core/storage/managed_asset_store.dart:149)
   仍做旧目录前缀映射。

结论：

- Core 层仍承担多处旧协议/旧路径兼容

## 15. Data

扫描结果：

- 数据库迁移链是项目最重的历史兼容区

发现点：

1. [app_database.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/data/datasources/local/app_database.dart:410)
   `schemaVersion=25`，`onUpgrade` 里保留了 21 个历史迁移分支。
2. [app_database.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/data/datasources/local/app_database.dart:671)
   还保留了一次旧列清理用的表重建迁移。
3. [app_database.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/data/datasources/local/app_database.dart:730)
   还用 `addColumnIfMissing + PRAGMA table_info` 兜异常安装状态。

结论：

- Data 层必须单独治理，不能夹在功能改造里顺手做

## 16. Domain

扫描结果：

- Domain 模型里仍保留多处旧字段桥接

发现点：

1. [reader_settings.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/domain/entities/reader_settings.dart:760)
   `fromJson` 仍把旧布局字段当迁移输入。
2. [reading_progress.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/domain/entities/reading_progress.dart:43)
   旧进度缺 `chapterPositionRatio` 时仍静默补 `0`。
3. [reader_document.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/domain/entities/reader_document.dart:283)
   仍提供 `compatibilityContent`。
4. [bookmark.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/domain/entities/bookmark.dart:13)
   书签仍兼容旧纯文本 snippet 和旧 note 载荷。
5. [book_identity.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/domain/entities/book_identity.dart:122)
   仍保留 `legacyLogicalBookId`。
6. [app_advanced_theme.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/domain/entities/app_advanced_theme.dart:581)
   仍兼容旧顶层 `colors` / `wallpaperPath`。
7. [local_book.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/domain/entities/local_book.dart:191)
   旧载荷缺 `splitLongChapter` 时默认 `true`。

结论：

- Domain 是断兼容改造的核心战场之一

## 当前优先级排序

按“旧字段是否继续影响新版功能”排序：

### 第一优先级

1. Reader
2. Domain
3. Mine

### 第二优先级

1. App
2. Core
3. Book
4. Source
5. Sync

### 第三优先级

1. Data

说明：

- Data 风险最高，但不是第一批动手对象
- 应该在边界冻结后单独做

## 结论

这次按功能域扫描后，可以明确说：

- **项目主功能域已经扫过一轮**
- **不是每个文件逐行人工审计**
- **但哪些功能还在被旧字段兼容影响，已经比较清楚**

最关键的结论是：

- 旧字段问题并不是“整个项目平均分布”
- 而是**高度集中在 Reader / Domain / Mine / Data**

所以后续改造不应该平均用力，而应该先打这几块。
