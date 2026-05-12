# 项目历史兼容审计（2026-05-06）

## 统计口径

本次只统计“显式兼容点”：

- 明确为旧版本安装数据、旧字段、旧 schema、旧目录、旧导入格式保留的分支或桥接
- 明确的迁移逻辑、旧键兜底、旧格式导入、旧路径归一化

本次不统计：

- 普通空值默认值
- 单纯的解析容错
- 与“覆盖安装后的本地历史数据”无关的通用业务分支

按这个保守口径，当前项目内共整理出 **49 处显式兼容点**。

## 汇总

| 类别 | 数量 | 主要位置 |
| --- | ---: | --- |
| 数据库 schema 升级分支 | 21 | `lib/data/datasources/local/app_database.dart` |
| 阅读器设置 / SharedPreferences / 进度兼容 | 6 | `lib/features/reader/application/reader_preferences_service.dart` 等 |
| 高级主题 / 主题包 / 外部主题格式兼容 | 11 | `lib/domain/entities/app_advanced_theme.dart`、`lib/features/mine/application/advanced_theme_service.dart` |
| 资源路径迁移 / 旧目录兼容 / 旧残留清理 | 4 | `lib/app/startup/managed_asset_path_migration_service.dart` 等 |
| 其他历史字段 / 逻辑桥接 | 7 | `lib/domain/entities/bookmark.dart` 等 |
| 合计 | **49** |  |

## 详细清单

### 1. 数据库 schema 升级分支：21 处

集中在 `lib/data/datasources/local/app_database.dart:410-667` 的 `onUpgrade`。

显式升级分支如下：

1. `from < 2`
2. `from < 3`
3. `from < 5`
4. `from < 6`
5. `from == 6`
6. `from < 8`
7. `from < 9`
8. `from < 12`
9. `from < 19`
10. `from < 20`
11. `from < 21`
12. `from < 22`
13. `from < 23`
14. `from < 24`
15. `from < 25`
16. `from < 13`
17. `from < 14`
18. `from < 15`
19. `from < 16`
20. `from < 17`
21. `from < 18`

补充说明：

- `lib/data/datasources/local/app_database.dart:671-728` 还有一次 `local_books` 的“重建表 + 回填 + 删除旧表”迁移
- `lib/data/datasources/local/app_database.dart:730-748` 用 `_addColumnIfMissing` / `PRAGMA table_info` 兜住不一致安装状态

这部分是当前最重的历史包袱。

### 2. 阅读器设置 / SharedPreferences / 进度兼容：6 处

1. `lib/features/reader/application/reader_preferences_service.dart:228-478`
   读取新设置时，仍回落到旧的 `bodyMarginMode/bodyMarginPreset/chapterHeaderMode/pinnedChapterHeaderOffsetX/Y/horizontalPadding`。
2. `lib/features/reader/application/reader_preferences_service.dart:481-695`
   保存新设置后，主动删除旧 key，属于“写新格式 + 清旧格式”的迁移尾巴。
3. `lib/features/reader/application/reader_preferences_service.dart:697-729`
   自定义背景图列表读取时，仍兼容旧单值 key `_customBackgroundImageBase64Key`。
4. `lib/features/reader/application/reader_preferences_service.dart:878-897`
   `migrateProgress` 会把阅读进度迁到新的书籍 identity key。
5. `lib/domain/entities/reader_settings.dart:750-979`
   `ReaderSettings.fromJson` 仍把旧布局字段当迁移输入。
6. `lib/domain/entities/reading_progress.dart:43-56`
   旧阅读进度没有 `chapterPositionRatio` 时，默认回落为 `0`。

### 3. 高级主题 / 主题包 / 外部主题格式兼容：11 处

1. `lib/domain/entities/app_advanced_theme.dart:273-371`
   `AppAdvancedThemeModeConfig` 兼容旧 `wallpaperPath/readerWallpaperPath`，转换成新的 `ManagedAssetRef`。
2. `lib/domain/entities/app_advanced_theme.dart:570-613, 744-773`
   `AppAdvancedTheme.fromJson` 兼容旧顶层 `colors` 和 `wallpaperPath`，回填到 `lightConfig/darkConfig`。
3. `lib/features/mine/application/advanced_theme_service.dart:449-496`
   主题颜色 JSON 导入同时支持旧版 `version=1` 与新版格式。
4. `lib/features/mine/application/advanced_theme_service.dart:864-1059`
   兼容导入 Red 主题包。
5. `lib/features/mine/application/advanced_theme_service.dart:1511-1574`
   Red 主题字段里 `primaryColor` 可回退到旧 `accentColor`。
6. `lib/features/mine/application/advanced_theme_service.dart:2418-2468`
   Red 阅读器 schema 仍兼容从旧 `layoutConfig` 里反推出背景模糊配置。
7. `lib/features/mine/application/advanced_theme_service.dart:1062-1180`
   兼容导入 RGShare 主题包。
8. `lib/features/mine/application/advanced_theme_service.dart:1576-1644`
   RGShare 颜色仍靠旧数字 key 映射。
9. `lib/features/mine/application/advanced_theme_service.dart:1711-1785`
   RGShare 阅读器主题导入时，仍要把旧字体 id / 文件路径映射成当前字体注册表。
10. `lib/features/mine/application/advanced_theme_service.dart:1788-1828`
    RGShare 底栏图标导入仍兼容旧 `tabBarProfile/iconSource` 结构。
11. `lib/features/mine/application/advanced_theme_service.dart:2248-2273`
    主题 bundle 导入时，仍要把旧字体 family key 重映射到新导入后的 key。

这块是当前最难看清边界的一组兼容逻辑。

### 4. 资源路径迁移 / 旧目录兼容 / 旧残留清理：4 处

1. `lib/app/startup/managed_asset_path_migration_service.dart:29-89`
   启动时统一跑资源路径迁移，并重写本地图书/元数据覆盖中的旧封面路径。
2. `lib/core/storage/managed_asset_directory_policy.dart:63-69`
   `customBookCover` 仍保留旧前缀 `custom_covers/`。
3. `lib/core/storage/managed_asset_store.dart:129-159`
   资源路径相对化时，会把旧目录前缀重新映射到新目录。
4. `lib/features/mine/application/cache_management_service.dart:647-683`
   仍有“旧版残留”扫描与清理逻辑，用于发现未被当前索引引用的旧本地图书产物。

### 5. 其他历史字段 / 逻辑桥接：7 处

1. `lib/domain/entities/bookmark.dart:13-52`
   书签 `snippet` 同时兼容旧纯文本和新编码 payload。
2. `lib/domain/entities/bookmark.dart:88-99`
   新增 `note` 字段后，仍保留从旧 `snippet` 里解出 note 的桥接逻辑。
3. `lib/domain/entities/book_identity.dart:119-149`
   仍保留旧的 `legacyLogicalBookId` 形状，避免内部 identity 改造直接打断旧链路。
4. `lib/domain/entities/reader_document.dart:186-283`
   结构化 `ReaderDocument` 仍能回落为旧的纯文本 `compatibilityContent`。
5. `lib/domain/entities/local_book.dart:169-192`
   旧载荷缺失 `splitLongChapter` 时默认按 `true` 处理。
6. `lib/core/membership/membership_entitlement.dart:35-73`
   会员权益仍以旧 `vip_level/vip_status/plan_type` 字段为主。
7. `lib/core/user/user_profile.dart:24-72`
   用户资料仍继续读取旧会员字段口径。

## 未计入总数，但值得注意

以下也带有兼容意味，但不纳入本次“覆盖安装历史数据兼容点”总数：

- `lib/runtime/sources/source_script_template.dart:46-47, 248-249`
  书源运行时兼容 `vip` / `isVip`
- `lib/features/source/application/source_runtime_facade.dart:56-58`
  `legacy()` 工厂
- `lib/features/source/application/source_login_runtime_service.dart:143`
  `legacy()` 工厂
- `lib/features/reader/presentation/reader_page_background.dart:458`
  兼容只暴露 JSON manifest 的旧 runtime

## 风险判断

### 风险最高

1. 数据库升级链
   21 个升级分支已经足够说明版本跨度大，而且还夹杂“缺列检测”和“重建表迁移”，最容易在异常安装态下出边缘问题。
2. 阅读器设置双轨兼容
   新旧字段语义同时存在，后续再调阅读器布局时容易误碰旧键回退。
3. 主题导入兼容
   Red / RGShare / 旧版颜色 JSON / 旧路径字段 / 旧字体 key 同时存在，测试覆盖稍弱时容易悄悄回归。

### 风险中等

1. 资源路径迁移
   现在已经有启动迁移和残留清理，说明目录规则发生过变更，后续再动目录结构要格外谨慎。
2. 书签 / 阅读进度 / 本地图书的旧载荷兜底
   数量不算最多，但这些都属于用户核心数据，一旦删错影响感知会很强。

### 风险较低

1. 用户资料 / 会员字段兼容
   目前量少，且更偏接口字段兼容。
2. 纯桥接型逻辑
   如 `ReaderDocument.compatibilityContent`、`legacyLogicalBookId`，可控但需要明确淘汰计划。

## 建议的清理顺序

1. 先给数据库迁移链补一份“最低支持升级版本”策略
   明确是否还需要支持从非常老的 schema 直接升级到当前版本。
2. 再收 ReaderSettings / ReaderPreferences 的旧字段
   最适合做成单独 migration adapter，把主模型和主读取路径彻底切成“只认新字段”。
3. 主题兼容单独列生命周期
   Red / RGShare / v1 颜色 JSON 是否还要继续支持，需要产品层明确。
4. 最后清理桥接型兼容
   如 `legacyLogicalBookId`、`compatibilityContent`、旧 `snippet` note 载荷。

## 结论

按保守口径，当前项目里有 **49 处显式兼容点**。

其中最重的是：

- **21 处数据库升级分支**
- **11 处主题与外部主题格式兼容**
- **6 处阅读器设置与进度兼容**

如果后面要继续做“去历史包袱”，优先级应该是：

1. 数据库迁移链
2. 阅读器旧设置键
3. 主题导入兼容层
