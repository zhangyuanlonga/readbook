# 存储盘点清单

更新时间：2026-05-20

状态：Phase 1 首版盘点，基于当前代码真实现状整理

关联文档：

- [存储治理定版规范](storage_governance_spec_2026-05-21.md)
- [存储升级验证清单](storage_upgrade_validation_2026-05-21.md)
- [多端架构开发约束](development_architecture_guardrails.md)

## 1. 结论摘要

- 当前本地存储已形成 5 层：`SharedPreferences`、`drift`、托管文件目录、缓存目录、`flutter_secure_storage`
- `SharedPreferences` 仍存在 19 处 JSON 聚合写入，是后续 `Phase 3` 的主要高风险迁移对象
- 用户资产主目录已基本收口到 `ManagedAssetStore`，主要落在 `Documents` / `Support`
- 缓存目录已存在明确对象，但“缓存预算 / 统一注册表 / 启动期清理边界”仍未完全制度化
- 敏感信息当前已收口到 `auth.*` 凭证安全存储；历史 WebDAV 同步 secret 代码已移除

## 2. SharedPreferences 盘点

### 2.1 轻量偏好和状态

| 模块 | 数据名 | 当前存储位置 | key / 模式 | 是否持续增长 | 是否可重建 | 是否用户资产 | 是否敏感 | 是否影响升级 | 建议目标位置 | 风险等级 |
|---|---|---|---|---|---|---|---|---|---|---|
| 应用主题 | 主题模式 | SharedPreferences | `app.themeMode` | 否 | 是 | 否 | 否 | 低 | 保持 SharedPreferences | 低 |
| 应用主题 | 种子色 | SharedPreferences | `app.seedColor` | 否 | 是 | 否 | 否 | 低 | 保持 SharedPreferences | 低 |
| 应用字体 | 字体来源/系统字体/字体 key/自定义字体路径 | SharedPreferences | `app.interfaceFont.*` | 否 | 部分可重建 | 否 | 否 | 中 | 保持 SharedPreferences，路径继续走托管文件 | 中 |
| 应用界面 | 文字缩放/字重 | SharedPreferences | `app.interfaceTextScale`、`app.interfaceFontWeight` | 否 | 是 | 否 | 否 | 低 | 保持 SharedPreferences | 低 |
| 导航 | 导航样式/标签显示/浮动栏/毛玻璃 | SharedPreferences | `app.navigation.*` | 否 | 是 | 否 | 否 | 低 | 保持 SharedPreferences | 低 |
| 顶层导航 | 首页/书架/发现/统计显隐 | SharedPreferences | `app.shell.navigation.*` | 否 | 是 | 否 | 否 | 低 | 保持 SharedPreferences | 低 |
| 启动 Gate | 每日任务 gate | SharedPreferences | `startup.taskGate.<task>` | 有界增长 | 是 | 否 | 否 | 中 | 保持 SharedPreferences，后续增加过期治理 | 中 |
| 设备标识 | 安装 ID | SharedPreferences | `app.install_id` | 否 | 否 | 否 | 否 | 中 | 可保持 SharedPreferences | 中 |
| 公告 | 已读 ID 集合 | SharedPreferences | `announcement.read.ids` | 有界增长 | 是 | 否 | 否 | 低 | 可保持 SharedPreferences / `StringList` | 低 |
| 首页 | 打卡日期和日目标 | SharedPreferences | `home.engagement.*` | 有界增长 | 可部分重建 | 否 | 否 | 低 | 保持 SharedPreferences | 低 |
| 搜索 | 系统开关 | SharedPreferences | `search.system.*` | 否 | 是 | 否 | 否 | 低 | 保持 SharedPreferences | 低 |
| 书架 | 系统开关 | SharedPreferences | `bookshelf.system.autoRefreshOnTabActiveEnabled` | 否 | 是 | 否 | 否 | 低 | 保持 SharedPreferences | 低 |
| 我的页面 | 隐藏项/启动落点/布局模式 | SharedPreferences | `mine.page.hiddenItems`、`app.startup.destination`、`mine.page.layoutMode` | 否 | 是 | 否 | 否 | 低 | 保持 SharedPreferences | 低 |
| 阅读器 | 大量轻量设置项 | SharedPreferences | `reader.settings.*` 中非 JSON 单值项 | 否 | 是 | 否 | 否 | 中 | 保持 SharedPreferences，仅保留轻量项 | 中 |
| 阅读器 | 系统设置 | SharedPreferences | `reader.system.readRecordEnabled` | 否 | 是 | 否 | 否 | 低 | 保持 SharedPreferences | 低 |
| 书源切换 | 源评分 / 书评分 | SharedPreferences | `reader.switch_source.source_score.*`、`reader.switch_source.book_score.*` | 持续增长 | 可重建 | 否 | 否 | 中 | 后续评估表化 | 中 |
| 认证 | access/refresh token、过期时间 | flutter_secure_storage | `auth.access_token`、`auth.refresh_token`、`auth.access_expires_at`、`auth.refresh_expires_at` | 否 | 否 | 否 | 是 | 低 | 保持安全存储 | 低 |
| 认证展示缓存 | user_id、username、account、display_name | SharedPreferences | `auth.user_id`、`auth.username`、`auth.account`、`auth.display_name` | 否 | 可从服务端补齐 | 否 | 否 | 低 | 保持轻量缓存 | 低 |

### 2.2 JSON 聚合写入基线

以下 19 处已被 `tool/check_storage_governance_guard.dart` 记录为历史基线。现阶段不允许继续新增同类写法。

| 模块 | 数据名 | key / 模式 | 当前形态 | 建议目标位置 | 风险等级 |
|---|---|---|---|---|---|
| 高级主题 | 主题全集 | `app.advancedThemes` | 大 JSON 列表 | 数据库索引或文件索引 | 高 |
| 高级主题 | 生效外观快照 | `app.advancedThemes.activeAppearanceSnapshot` | JSON 对象 | 轻量对象可保留或拆轻 | 中 |
| 封面图集 | 图集全集 | `coverGallery.galleries` | 大 JSON 列表 | 数据库索引或文件索引 | 高 |
| 启动图集 | 图集全集 | `launchImageGallery.galleries` | 大 JSON 列表 | 数据库索引或文件索引 | 高 |
| 底栏图集 | 图集全集 | `bottomNavIconGallery.galleries` | 大 JSON 列表 | 数据库索引或文件索引 | 高 |
| 书架 | 书籍集合 | `bookshelf.books` | JSON 列表 | 数据库 | 高 |
| 书架 | 标签集合 | `bookshelf.book_tags` | JSON 列表 | 数据库 | 高 |
| 书架 | 标签顺序 | `bookshelf.tag_order` | JSON 列表 | 数据库或轻量索引 | 中 |
| 书架 | 标签元数据 | `bookshelf.tag_metadata.v1` | JSON 列表 | 数据库 | 中 |
| 书架 | 分类顺序 | `bookshelf.category_order` | JSON 列表 | 数据库或轻量索引 | 中 |
| 书架 | 分类元数据 | `bookshelf.category_metadata.v1` | JSON 列表 | 数据库 | 中 |
| 书架 | 基础筛选顺序 | `bookshelf.base_filter_order` | JSON 列表 | 轻量索引 / 数据库 | 中 |
| 远程访问 | 远端能力快照 | `remote.access.snapshot.v1.<userId>` | JSON 对象 | 可保留或后续表化 | 中 |
| 阅读器 | TXT 章节规则 | `reader.local.txt.chapterRules` | JSON 对象 | 数据库或独立文件 | 中 |
| 阅读器 | 阅读进度 | `reader.progress.<bookId>` | JSON 对象，按书增长 | 数据库 | 高 |
| 阅读器 | TOC 快照 | `reader.tocSnapshot.<bookId>` | JSON 对象，按书增长 | 数据库 / 缓存边界重判 | 高 |
| 阅读器 | 自定义背景图列表 | `reader.settings.customBackgroundImages` | JSON 列表 | 托管文件索引 | 中 |
| 阅读器 | 最近文字颜色 | `reader.settings.recentBodyTextColors` | JSON 列表 | 可保留或拆 `StringList` | 低 |
| 阅读器 | 视觉覆盖 | `reader.visualOverrides` | JSON 对象 | 可保留或拆轻量结构 | 中 |
| 搜索 | 搜索历史 | `search.history` | JSON 列表 | 改 `StringList` 或数据库 | 低 |
| 书源健康 | 健康快照集合 | `source.health.snapshots.v1` | JSON Map | 数据库 | 中 |

说明：

- `reader.settings.backgroundImageBase64` 虽然不是 JSON，但名字和历史语义表明它存在“大字符串 / 资产误存偏好”的风险，应在后续盘点中视作高风险存量
- `mine.profile.avatar.path.<userId>` 当前只保存路径字符串，不属于 JSON 聚合，但路径本体仍应视作用户资产绑定

## 3. 数据库盘点

代码位置：

- [app_database.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/data/datasources/local/app_database.dart)
- schemaVersion：`27`

### 3.1 表清单

| 表 | 业务含义 | 是否持续增长 | 是否可重建 | 是否用户资产 | 是否敏感 | 是否影响升级 | 建议目标位置 | 风险等级 |
|---|---|---|---|---|---|---|---|---|
| `chapter_caches` | 章节缓存内容 | 是 | 是 | 否 | 否 | 中 | 数据库缓存表，后续纳入统一缓存协议 | 中 |
| `local_books` | 本地图书索引 | 是 | 否 | 是 | 否 | 高 | 保持数据库 | 低 |
| `local_chapters` | 本地图书章节和文档快照 | 是 | 部分可重建 | 间接属于用户资产 | 否 | 高 | 保持数据库 | 中 |
| `bookmarks` | 书签 / 划线 / 笔记 | 是 | 否 | 是 | 否 | 高 | 保持数据库 | 低 |
| `book_metadata_overrides` | 元数据覆盖 | 是 | 否 | 是 | 否 | 高 | 保持数据库 | 低 |
| `reading_records` | 阅读记录汇总 | 是 | 否 | 是 | 否 | 高 | 保持数据库 | 低 |
| `reading_record_days` | 日阅读统计 | 是 | 否 | 否 | 否 | 中 | 保持数据库 | 低 |
| `reading_record_sessions` | 会话统计 | 是 | 否 | 否 | 否 | 中 | 保持数据库 | 低 |
| `reading_book_statuses` | 书籍阅读状态 | 是 | 否 | 是 | 否 | 高 | 保持数据库 | 低 |
| `search_source_hits` | 搜索源命中统计 | 是 | 是 | 否 | 否 | 中 | 保持数据库或缓存表 | 低 |
| `sync_profiles` | 同步配置元数据 | 是 | 否 | 否 | 否 | 高 | 保持数据库 | 低 |
| `sync_scope_states` | 同步 scope 状态 | 是 | 否 | 否 | 否 | 高 | 保持数据库 | 低 |
| `sync_jobs` | 同步任务 | 是 | 是 | 否 | 否 | 中 | 保持数据库 | 低 |
| `sync_conflicts` | 同步冲突 | 是 | 否 | 否 | 可能含业务数据 | 高 | 保持数据库 | 中 |

### 3.2 升级链现状

- 当前 `schemaVersion = 27`
- `onUpgrade` 从历史版本逐步创建表、补列、删废列、补性能索引
- 已有性能索引：
  - `idx_chapter_caches_book_id`
  - `idx_chapter_caches_book_source_chapter`
  - `idx_chapter_caches_updated_at`
  - `idx_local_chapters_book_chapter`
  - `idx_bookmarks_book_chapter_start`

升级风险判断：

- 数据库主结构总体比 `SharedPreferences` 更稳定
- `local_chapters.document_json`、`image_urls_json` 属于表内 JSON，但仍在数据库边界内，不属于本轮“禁止新增大 JSON 到 SharedPreferences”问题
- 后续 `Phase 5` 需要围绕 `from < N` 的历史分支做回放验证

## 4. 托管文件目录盘点

代码位置：

- [managed_asset_directory_policy.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/core/storage/managed_asset_directory_policy.dart)
- [managed_asset_store.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/core/storage/managed_asset_store.dart)

### 4.1 目录映射

| 资产类型 | 根目录 | 相对目录 | 用户资产属性 | 建议 |
|---|---|---|---|---|
| 应用背景 | Documents | `backgrounds/` | 是 | 保持托管文件 |
| 阅读背景 | Documents | `reader_backgrounds/` | 是 | 保持托管文件 |
| 封面图集图片 | Documents | `cover_galleries/` | 是 | 保持托管文件 |
| 启动图集图片 | Documents | `launch_image_galleries/` | 是 | 保持托管文件 |
| 底栏图标 | Support | `bottom_nav_icon_galleries/` | 是 | 保持托管文件 |
| 阅读字体 | Support | `reader_fonts/` | 是 | 保持托管文件 |
| 自定义书籍封面 | Support | `shuxiang_reading_next/custom_covers/` | 是 | 保持托管文件 |
| 本地图书派生资源 | Support | `local_books/` | 是 | 保持托管文件 |

### 4.2 已发现额外路径

| 模块 | 路径 | 现状判断 | 风险等级 |
|---|---|---|---|
| Mine 头像 | `Documents/profile_avatars` | 用户资产路径，尚未纳入 `ManagedAssetStore` | 中 |
| 高级主题目录 | `Documents/advanced_themes/<themeId>` | 用户主题资源目录，未统一走 `ManagedAssetStore` policy | 中 |
| 本地图书主文件 | `Support/local_books` | 已受控 | 低 |

说明：

- 托管文件层整体方向正确，但仍有少量目录未完全纳入统一 policy 枚举
- 后续 `Phase 2` 需要决定是否把 `profile_avatars`、`advanced_themes` 也纳入统一 policy

## 5. 缓存目录盘点

### 5.1 已识别缓存对象

| 模块 | 当前存储位置 | key / 目录规则 | 是否持续增长 | 是否可重建 | 是否用户资产 | 建议目标位置 | 风险等级 |
|---|---|---|---|---|---|---|---|
| 封面磁盘缓存 | `CoverImageDiskCache`，优先 `ApplicationSupport`，部分平台 fallback `Directory.systemTemp` | URL MD5 文件名 | 是 | 是 | 否 | 保持缓存目录，后续纳入预算协议 | 中 |
| 阅读分页缓存 | `ApplicationSupport` 下分页缓存目录 | 章节签名文件 | 是 | 是 | 否 | 保持缓存目录，后续纳入预算协议 | 中 |
| 章节缓存 | `chapter_caches` 数据库表 | `sourceId|chapterUrl` | 是 | 是 | 否 | 保持数据库缓存表 | 中 |
| 搜索故障导出临时文件 | `ApplicationSupport` / 临时导出目录 | 按导出任务生成 | 否 | 是 | 否 | 保持临时导出 | 低 |
| 诊断日志导出临时文件 | `TemporaryDirectory` | 按导出任务生成 | 否 | 是 | 否 | 保持临时导出 | 低 |
| 高级主题导入/导出工作目录 | `Directory.systemTemp.createTemp` / `getTemporaryDirectory()` | 临时工作目录 | 否 | 是 | 否 | 保持临时目录 | 低 |

### 5.2 清理入口现状

| 清理入口 | 实际作用对象 | 是否模糊清理 | 风险判断 |
|---|---|---|---|
| `ChapterCacheService.clearAllCaches()` | 数据库 `chapter_caches` | 否 | 可控 |
| `ReaderPaginationCacheService.clearPersistedChapterLayouts()` | 分页缓存文件 | 否 | 可控 |
| `CoverImageDiskCache.clearAll()` | 封面缓存文件 | 否 | 可控 |
| `CoverImageDiskCache.compact()` | 封面缓存文件 | 否 | 可控 |
| `BottomNavIconGalleryService` / `CoverGalleryService` / `LaunchImageGalleryService` / `AdvancedThemeService` 删除目录 | 仅删除对应用户资产目录 | 否 | 删除的是用户主动删除对象，不属于缓存清理 |
| `RemoteContentTaskSchedulerService.clearAll()` | 内存调度状态 | 否 | 非持久化 |

结论：

- 当前未发现“清理全部本地数据”的统一入口
- 当前未发现启动阶段主动清空缓存目录 / 托管目录的逻辑
- 但缓存目录仍缺统一预算配置和总注册表

## 6. 安全存储盘点

| 模块 | 当前存储位置 | key / 模式 | 是否敏感 | 建议目标位置 | 风险等级 |
|---|---|---|---|---|---|
| 历史同步 secret | 已移除代码入口 | 旧 `secretRef` 动态 key 仅可能存在于历史安装数据 | 是 | 不再新增；后续如做数据库清理再统一迁移/删除 | 低 |

说明：

- WebDAV 同步模块已移除，客户端不再新增同步 secret；历史安装中残留的旧安全存储 key 暂不主动清理
- `auth.*` 已完成“安全凭证进 `flutter_secure_storage`，展示字段保留轻量缓存”的拆分

## 7. 风险归类

### 7.1 高风险

- `SharedPreferences` 中的主题/图集/书架/阅读进度等 JSON 聚合对象
- `reader.settings.backgroundImageBase64` 这类大字符串/资产型内容仍混在偏好层

### 7.2 中风险

- `remote.access.snapshot.v1.<userId>`、`source.health.snapshots.v1`、`reader.visualOverrides`
- `profile_avatars`、`advanced_themes/<themeId>` 尚未完全纳入统一托管 policy
- 分页缓存、封面缓存尚未纳入统一预算总表

### 7.3 低风险

- 纯开关、枚举、数值型偏好
- 已明确边界的临时导出目录
- 已明确按对象删除的用户资产目录

## 8. 下一步建议

按阶段顺序建议：

1. Phase 0 继续完成：
   - 为“临时/缓存目录新增使用”与“启动期高风险清理”持续保守卫
   - 在 PR / 文档层补存储接入 checklist
2. Phase 2 先定版：
   - 明确主题/图集/书架 JSON 的最终落位
   - 明确 `auth.*` 和 `backgroundImageBase64` 的整改口径
3. Phase 3 优先迁移：
   - `app.advancedThemes`
   - `coverGallery.galleries`
   - `launchImageGallery.galleries`
   - `bookshelf.books`
   - `reader.progress.<bookId>`
