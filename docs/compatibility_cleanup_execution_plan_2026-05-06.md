# 历史旧字段断兼容执行计划（2026-05-06）

## 目标

当前核心判断已经明确：

- **不再兼容之前开发阶段遗留的旧字段**
- **新版功能正确性优先于历史字段兼容**
- **凡是旧字段继续影响新功能行为的地方，都要下线**

这份计划不再以“长期兼容旧数据”为目标，而是以“切断旧字段影响面”为目标。

## 执行总控

- [x] 阶段 0：冻结断兼容边界
- [ ] 阶段 1：切断阅读器旧字段
- [ ] 阶段 2：切断书签与正文桥接
- [ ] 阶段 3：切断主题旧格式
- [ ] 阶段 4：切断旧资源路径
- [ ] 阶段 5：压缩数据库历史迁移
- [ ] 阶段 6：回归与收尾

## 总原则

- [ ] 主模型、主渲染、主业务链只认新字段
- [ ] 旧字段不再参与新功能逻辑判定
- [ ] 旧字段不再作为静默兜底输入
- [ ] 遇到旧字段数据时，优先选择：清理、重建、重置、拒绝导入
- [ ] 所有断兼容点都要有明确提示或明确测试覆盖

## 本次清理范围

优先处理会直接影响新版功能的旧字段兼容：

- [ ] 阅读器设置旧字段
- [ ] 阅读进度旧字段
- [ ] 结构化正文对旧字符串内容的桥接
- [ ] 书签旧 payload 结构
- [ ] 主题旧字段与旧导入格式
- [ ] 资源路径旧目录映射
- [ ] 数据库超长历史迁移链

暂不作为第一优先级：

- [ ] 纯展示文案级兼容提示
- [ ] 与当前主功能无关的弱兼容 helper

## 阶段总览

| 阶段 | 目标 | 结果 |
| --- | --- | --- |
| 阶段 0 | 冻结断兼容边界 | 明确哪些旧字段必须直接停用 |
| 阶段 1 | 切断阅读器旧字段 | 设置、进度、正文主链只认新字段 |
| 阶段 2 | 切断书签与内容桥接 | 不再让旧字符串结构影响新模型 |
| 阶段 3 | 切断主题旧格式 | 旧主题字段和旧导入格式退出主链 |
| 阶段 4 | 切断旧资源路径 | 旧目录与旧路径映射退出运行时主链 |
| 阶段 5 | 压缩数据库历史迁移 | 过老 schema 不再继续兼容升级 |
| 阶段 6 | 回归与收尾 | 补测试、删遗留文档、删无效代码 |

## 功能域绑定

本计划与 [feature_compatibility_scan_2026-05-06.md](./feature_compatibility_scan_2026-05-06.md) 对齐，优先级如下：

- [ ] 第一优先级功能域：`Reader`
- [ ] 第一优先级功能域：`Domain`
- [ ] 第一优先级功能域：`Mine`
- [ ] 第二优先级功能域：`Book`
- [ ] 第二优先级功能域：`App`
- [ ] 第二优先级功能域：`Core`
- [ ] 第二优先级功能域：`Source`
- [ ] 第二优先级功能域：`Sync`
- [ ] 第三优先级功能域：`Data`

阶段与功能域关系：

- [ ] 阶段 1 主要覆盖 `Reader + Domain`
- [ ] 阶段 2 主要覆盖 `Reader + Domain`
- [ ] 阶段 3 主要覆盖 `Mine + Domain`
- [ ] 阶段 4 主要覆盖 `App + Core + Mine`
- [ ] 阶段 5 主要覆盖 `Data`
- [ ] 阶段 6 覆盖全项目

## 阶段 0：冻结断兼容边界

目标：先把“不再支持什么”定死，否则后面删不干净。

### Checklist

- [x] 明确旧字段断兼容原则写入项目文档
- [x] 给 49 处兼容点打标签
- [x] 兼容点标签：`立即删除`
- [x] 兼容点标签：`改成报错/重置`
- [x] 兼容点标签：`延后到数据库阶段`
- [x] 明确哪些旧字段会导致的后果
- [x] 旧字段后果：设置重置
- [x] 旧字段后果：进度重置
- [x] 旧字段后果：主题导入失败
- [x] 旧字段后果：本地缓存清理
- [x] 明确哪些旧数据不再迁移，只允许丢弃
- [x] 明确最低支持的数据库 schema 版本
: `schemaVersion >= 23` 允许直升，`schemaVersion < 23` 在阶段 5 改为重建数据库或拒绝升级。

### 输出物

- [x] 更新本计划文档
- [x] 输出一份“旧字段停用矩阵”
: [old_field_deprecation_matrix_2026-05-06.md](./old_field_deprecation_matrix_2026-05-06.md)

## 阶段 1：切断阅读器旧字段

目标：阅读器主链彻底不再吃旧字段。

### 重点文件

- `lib/features/reader/application/reader_preferences_service.dart`
- `lib/domain/entities/reader_settings.dart`
- `lib/domain/entities/reading_progress.dart`

### Checklist

- [x] 删除 `ReaderPreferencesService` 中旧布局 key 兜底读取
- [x] 删除 `bodyMarginMode/bodyMarginPreset` 对新布局的影响
- [x] 删除 `chapterHeaderMode/chapterHeaderTopSpacing/chapterHeaderBottomSpacing` 对新章节头逻辑的影响
- [x] 删除 `pinnedChapterHeaderOffsetX/Y` 对新章节头偏移逻辑的影响
- [x] 删除 `horizontalPadding` 作为新正文边距 fallback 的行为
- [x] 删除旧自定义背景图单值 key 对新列表读取的 fallback
- [x] 让 `ReaderSettings.fromJson` 只认新字段
- [x] 让 `ReadingProgress.fromJson` 对旧载荷缺字段时不再静默兜底
- [x] 评估 `migrateProgress` 是否保留
- [x] 若不保留 `migrateProgress`：删除迁移方法
- [x] 若不保留 `migrateProgress`：删除调用点
- [ ] `Book` / `Reader` 换源流程里的进度迁移是否保留，单独按功能策略决策
- [ ] `Book` / `Reader` 换源流程里的阅读记录迁移是否保留，单独按功能策略决策

### 完成标准

- [x] 阅读器设置主读取路径里不再出现旧字段名
- [x] 阅读器 UI 调整不会再被历史 prefs 反向污染
- [x] 旧阅读进度载荷进入系统后要么失败，要么被显式重置
- [ ] 换源后是否继承旧来源阅读状态，不在阶段 1 内处理

## 阶段 2：切断书签与正文桥接

目标：结构化数据就是唯一真相，不再让旧字符串兼容层影响主链。

### 重点文件

- `lib/domain/entities/bookmark.dart`
- `lib/domain/entities/reader_document.dart`
- `lib/features/reader/application/chapter_content_service.dart`
- `lib/features/reader/application/local/local_markup_book_parser_support.dart`
- `lib/features/reader/application/local/epub_local_book_parser.dart`
- `lib/features/reader/presentation/reader_content_loading_controller.dart`

### Checklist

- [ ] 梳理所有 `compatibilityContent` 调用点
- [ ] 区分哪些调用点必须改成结构化 block 消费
- [ ] 删除正文主链对 `compatibilityContent` 的依赖
- [ ] 只在必要导出/调试场景保留 `compatibilityContent`
- [ ] 评估 `Bookmark.snippet` 旧纯文本兼容是否直接停用
- [ ] 若停用旧纯文本兼容：删除旧纯文本 decode 逻辑
- [ ] 若停用旧纯文本兼容：删除从 `snippet` 中回读 note 的桥接
- [ ] 若短期不能停用旧纯文本兼容：将旧 decode 压缩到单一 decoder
- [ ] 若短期不能停用旧纯文本兼容：主模型不再依赖旧格式推导业务行为
- [ ] 删除本地 TXT 章节读取中的 `LegacyTxtOffsetFallback`

### 完成标准

- [ ] 阅读器正文渲染主链只依赖结构化内容
- [ ] 书签模型不再靠旧 payload 猜字段语义

## 阶段 3：切断主题旧格式

目标：保留外部 app 主题兼容能力，但不让旧格式兼容污染当前主题主链。

### 重点文件

- `lib/domain/entities/app_advanced_theme.dart`
- `lib/features/mine/application/advanced_theme_service.dart`
- `lib/features/mine/presentation/advanced_theme_list_page.dart`

### Checklist

- [ ] 保留 `Red` 主题包导入能力
- [ ] 保留 `RGShare` 主题包导入能力
- [ ] 保留外部主题兼容导入 UI 入口
- [ ] 将 `Red` 兼容导入从 `AdvancedThemeService` 主链拆到独立 adapter
- [ ] 将 `RGShare` 兼容导入从 `AdvancedThemeService` 主链拆到独立 adapter
- [ ] 将旧版主题颜色 JSON `version=1` 是否继续支持单独决策
- [ ] 将 `AppAdvancedTheme` 旧顶层字段 fallback 收口到导入/反序列化边界
- [ ] 将 `AppAdvancedThemeModeConfig` 旧 `wallpaperPath/readerWallpaperPath` 桥接收口到导入边界
- [ ] 将旧字体 key 重映射逻辑收口到兼容导入 adapter
- [ ] 将旧数字颜色 key 映射逻辑收口到兼容导入 adapter
- [ ] 将旧 reader schema layoutConfig 衍生逻辑收口到兼容导入 adapter
- [ ] 明确当前主题主模型与外部兼容导入模型分层

### 完成标准

- [ ] `AdvancedThemeService` 主链只处理当前内部主题模型
- [ ] 外部 app 兼容导入能力继续可用
- [ ] 外部主题兼容逻辑不再散落在主题主链

## 阶段 4：切断旧资源路径

目标：旧目录和旧路径映射不再作为长期运行时能力存在。

### 重点文件

- `lib/app/startup/managed_asset_path_migration_service.dart`
- `lib/core/storage/managed_asset_directory_policy.dart`
- `lib/core/storage/managed_asset_store.dart`
- `lib/features/mine/application/cache_management_service.dart`

### Checklist

- [ ] 评估启动期 `ManagedAssetPathMigrationService` 是否直接移除
- [ ] 若不移除 `ManagedAssetPathMigrationService`：改成只运行一次
- [ ] 若不移除 `ManagedAssetPathMigrationService`：增加迁移完成版本标记
- [ ] 删除 `legacyRelativePrefixes`
- [ ] 删除旧目录到新目录的自动重映射
- [ ] 明确旧版残留扫描是否保留
- [ ] 若保留旧版残留扫描：只保留清理能力
- [ ] 若保留旧版残留扫描：不再作为主链兼容依赖
- [ ] 若不保留旧版残留扫描：删除“旧版残留”相关 UI 与 service 逻辑

### 完成标准

- [ ] 运行时路径解析只认当前目录规则
- [ ] 旧目录数据不再影响当前资源加载

## 阶段 5：压缩数据库历史迁移

目标：明确放弃过老 schema 的直接升级。

### 重点文件

- `lib/data/datasources/local/app_database.dart`
- `test/data/datasources/local/*migration_test.dart`

### Checklist

- [ ] 列出当前 21 个迁移分支的来源版本与保留理由
- [ ] 定义最低支持直升版本
- [ ] 低于最低版本时：重建数据库
- [ ] 低于最低版本时：或中止启动并提示清理
- [ ] 合并无必要保留的补列分支
- [ ] 删除仅为极老 schema 保留的迁移段
- [ ] 保留当前版本必需的数据迁移测试
- [ ] 删除已放弃版本的迁移测试

### 完成标准

- [ ] `AppDatabase.onUpgrade` 分支显著减少
- [ ] 每个保留迁移分支都有明确业务理由
- [ ] 不再承诺支持非常老版本直接升级

## 阶段 6：回归与收尾

目标：删完之后不留下伪兼容代码和误导文档。

### Checklist

- [ ] 更新测试，去掉旧字段兼容预期
- [ ] 新增断兼容测试：
- [ ] 断兼容测试：旧设置输入应失败或重置
- [ ] 断兼容测试：旧主题导入应失败
- [ ] 断兼容测试：旧正文桥接主链不再可达
- [ ] 断兼容测试：低于最低 schema 版本的库不再直接升级
- [ ] 删除旧兼容说明文档
- [ ] 删除无调用的 legacy helper
- [ ] 删除无调用的旧字段常量
- [ ] 回查代码库中 `legacy` / `compatibility` / `fallback` 关键路径是否已收干净

### 完成标准

- [ ] 项目主链逻辑不再依赖旧字段兼容
- [ ] 文档口径与代码真实行为一致

## 推荐执行顺序

按风险和收益，建议这样推进：

1. **阶段 0**
2. **阶段 1**
3. **阶段 2**
4. **阶段 3**
5. **阶段 4**
6. **阶段 5**
7. **阶段 6**

原因：

- 阅读器旧字段最直接影响新版功能
- 主题旧格式其次复杂，但影响范围可控
- 数据库迁移链最危险，必须最后在边界清楚后再动

## 第一轮建议直接开工

如果现在就进入代码改造，建议先做下面这一轮：

- [x] 阶段 0：冻结边界
- [ ] 阶段 1：切断阅读器旧字段
- [ ] 阶段 2：切断书签与正文桥接

这三块完成后，最核心的“旧字段影响新版功能”问题会先被切掉。

## 结论

后续执行口径已经明确：

- **不是继续整理怎么兼容旧字段**
- **而是按阶段主动取消旧字段兼容**

后面每做一轮改动，都应该围绕一句话检查：

- [ ] 这次改动有没有继续让旧字段影响新功能

只要答案还是“有”，那这一轮就还没做完。
