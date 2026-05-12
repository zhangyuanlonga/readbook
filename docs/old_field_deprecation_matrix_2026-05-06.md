# 旧字段停用矩阵（2026-05-06）

用途：

- 对应阶段 0 输出物
- 明确哪些旧字段/旧兼容点直接删除
- 明确哪些旧数据进入系统后应报错、重置或拒绝导入

## Reader / Domain

- [x] `reader.settings.bodyMarginMode`：立即删除
- [x] `reader.settings.bodyMarginPreset`：立即删除
- [x] `reader.settings.chapterHeaderMode`：立即删除
- [x] `reader.settings.chapterHeaderTopSpacing`：立即删除
- [x] `reader.settings.chapterHeaderBottomSpacing`：立即删除
- [x] `reader.settings.pinnedChapterHeaderOffsetX`：立即删除
- [x] `reader.settings.pinnedChapterHeaderOffsetY`：立即删除
- [x] `reader.settings.horizontalPadding`：立即删除
- [x] `reader.settings.customBackgroundImageBase64`：立即删除
- [x] `ReadingProgress.chapterPositionRatio` 缺失旧载荷：改成报错/重置
- [x] `ReaderDocument.compatibilityContent` 主链依赖：阶段 2 删除
- [x] `Bookmark` 旧纯文本 `snippet`：阶段 2 删除
- [x] `Bookmark` 从 `snippet` 回读 `note`：阶段 2 删除
- [x] 本地 TXT `LegacyTxtOffsetFallback`：阶段 2 删除
- [x] `Book` / `Reader` 换源流程里的进度迁移：不归类为旧字段兼容，单独作为功能策略处理
- [x] `Book` / `Reader` 换源流程里的阅读记录迁移：不归类为旧字段兼容，单独作为功能策略处理

## Mine / Theme

- [x] `AppAdvancedTheme.colors` 顶层旧字段 fallback：阶段 3 收口到导入/反序列化边界
- [x] `AppAdvancedTheme.wallpaperPath` 顶层旧字段 fallback：阶段 3 收口到导入/反序列化边界
- [x] `AppAdvancedThemeModeConfig.wallpaperPath` 自动桥接：阶段 3 收口到导入边界
- [x] `AppAdvancedThemeModeConfig.readerWallpaperPath` 自动桥接：阶段 3 收口到导入边界
- [x] 主题颜色 JSON `version=1`：阶段 3 单独决策是否继续支持
- [x] Red 主题包兼容导入：阶段 3 保留，不删除
- [x] RGShare 主题包兼容导入：阶段 3 保留，不删除
- [x] 旧字体 key 重映射：阶段 3 收口到兼容导入 adapter
- [x] 旧数字颜色 key 映射：阶段 3 收口到兼容导入 adapter
- [x] 旧 reader schema `layoutConfig` 衍生逻辑：阶段 3 收口到兼容导入 adapter

## App / Core / Storage

- [x] `ManagedAssetPathMigrationService` 常驻启动迁移：阶段 4 收口或删除
- [x] `legacyRelativePrefixes`：阶段 4 删除
- [x] 旧目录到新目录自动重映射：阶段 4 删除
- [x] “旧版残留”扫描作为主链依赖：阶段 4 删除

## Book / Source / Sync

- [x] `SourceRuntimeFacade.legacy()`：阶段 4 或阶段 6 删除
- [x] `SourceLoginRuntimeService.legacy()`：阶段 4 或阶段 6 删除
- [x] Sync manifest 缺失 `schemaVersion` 自动回退：阶段 4 或阶段 6 收紧
- [x] Sync envelope 解码失败静默空集合：阶段 4 或阶段 6 收紧

## Data

- [x] 最低支持直升数据库版本：`schemaVersion >= 23`
- [x] `schemaVersion < 23`：不再继续兼容直接升级，阶段 5 改为重建数据库或拒绝升级
- [x] 数据库 `from < 2 ... < 25` 超长迁移链：延后到数据库阶段
- [x] 旧列检测 `addColumnIfMissing + PRAGMA`：延后到数据库阶段
- [x] `local_books` 重建式旧列清理迁移：延后到数据库阶段

## 旧数据进入系统后的处理口径

- [x] 旧阅读器设置键：忽略，不再迁移
- [x] 旧阅读进度缺 `chapterPositionRatio`：读取失败，按无进度处理
- [x] 外部 app 主题兼容格式：保留导入能力，但从主题主链剥离
- [x] 旧资源路径：不再依赖运行时自动映射
- [x] 过老数据库 schema：在阶段 5 定义为重建或拒绝升级
