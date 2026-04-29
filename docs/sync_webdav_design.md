# 同步系统与 WebDAV 首版设计

更新时间：2026-04-29  
用途：在当前项目架构统一化之后，为“多同步源可扩展的同步能力”定义唯一设计口径，首版先落地 `WebDAV`。

## 1. 背景

结合最近的标准化提交，可以明确一个前提：

- `9f20e95`：项目架构统一化阶段 0/1 完成
- `72140e2`：`reader` 已拆分
- `d2c1898`：`bookshelf` 已拆分
- `19023cf`：`book detail` 已拆分
- `a0f16e4`：阅读记录 / 书签 / 首页 已收口
- `696dcd5`：Mine / Appearance / Advanced Theme 已拆解
- `887b16a`：资源系统统一

这意味着同步功能不能再走“页面直接拼装多个 service / database / preferences”的旧路，而必须作为独立业务能力建设，避免重新把已拆开的 feature 耦回去。

同时，当前用户状态并不只存在一种存储里：

- `Drift`：阅读记录、书签、本地书库、章节、脚本源等
- `SharedPreferences`：书架、阅读进度、阅读器设置、若干界面偏好
- managed assets：自定义封面、背景图、字体、启动图、底栏图标等

所以同步设计必须先明确“同步什么”和“暂不同步什么”，不能一开始就做无边界全量云备份。

## 2. 设计目标

### 2.1 首要目标

- 支持未来接入多种同步后端
- 同步逻辑不破坏现有 `Feature-first + Application + Riverpod DI`
- 支持“按同步项勾选”的细粒度同步，而不是只有一个总开关
- 支持至少以下用户数据的跨设备同步：
  - 书架
  - 阅读进度
  - 阅读历史记录
  - 书签
- 支持会员资产中的高级主题同步
- 首版先支持一个真实可用的 `WebDAV` 远端
- 支持同步执行历史，便于用户和开发排查问题

### 2.2 非目标

以下内容不进入 `WebDAV v1`：

- 本地图书文件本体同步
- 章节正文缓存同步
- 登录 token / cookie / 会话同步
- 任意第三方网盘 SDK 直连

原因很直接：这些能力要么体积大、要么缺少稳定身份、要么涉及安全风险，不适合作为第一阶段。

## 3. 历史记录口径

这里的“历史记录”建议拆成两个概念，不要混用：

- 阅读历史记录：指当前已有的 `ReadingRecord / ReadingRecordSession / ReadingRecordDay`
- 同步执行历史：指每次同步任务的开始、结束、结果、错误、变更摘要

其中：

- 阅读历史记录属于“用户业务数据”，需要进入云端同步
- 同步执行历史属于“同步系统运维数据”，本地必须保存，远端可选保存摘要

## 4. WebDAV v1 同步范围

建议从一开始就把同步项做成“scope catalog + 用户勾选”，而不是代码里写死一个固定包。

阶段 0 冻结后的代码事实来源：

- `lib/features/sync/domain/sync_scope.dart`

后续若 scope 名、dataset 名或依赖关系发生变化，必须先同步更新设计文档和这个文件。

### 4.0 本轮全量盘点结论

按当前代码与持久化入口盘点，之前容易漏掉、但确实值得纳入同步设计的项主要有：

- `bookshelf_taxonomy`
  书架标签映射、标签顺序、分类顺序、基础筛选顺序，不能只同步书架列表而漏掉这一层。
- `reading_book_statuses`
  用户手动标记的“在读 / 读完”状态，属于明确用户资产。
- `book_metadata_overrides`
  用户手动改过的书名、作者、简介、自定义封面引用，价值很高。
- `book_metadata_assets`
  上一项引用的自定义封面资源文件，应与 override 配置拆 scope。
- `bookshelf_presentation_preferences`
  书架视图模式、排序、网格/列表展示项、搜索条偏好等。
- `app_theme_preferences / app_navigation_preferences / mine_page_preferences`
  属于应用级 UI 偏好，适合做可选同步。
- `home_engagement`
  打卡日期与每日目标，用户感知明显。
- `search_history`
  量小，跨设备复用价值明确。
- `discover_preferences`
  其中“当前选中的发现源”是偏好；`discover` 快照本身更像缓存，不建议同步。

同时也能明确一批“不该混进同步”的状态：

- `auth_session`
- `source_login_state`
- `book_custom_state`
- `source_health_snapshots`
- `source_runtime_diagnostics`
- `search_source_hits`
- `chapter_caches`
- `local_library_files`

这些要么涉及安全，要么是运行态/缓存，要么依赖本机文件，不适合进入首版同步协议。

### 4.1 建议纳入 scope catalog 的完整分层

下面不是“首版全部都做”，而是建议统一进入 scope catalog 的完整目录，避免后面继续漏项。

第一层：核心用户资产，优先级最高

- `bookshelf_collection`
- `bookshelf_taxonomy`
- `reading_progress`
- `reading_history`
- `reading_stats`
- `bookmarks`
- `reading_book_statuses`
- `book_metadata_overrides`
- `book_metadata_assets`
- `script_sources`
- `advanced_theme_presets`
- `advanced_theme_assets`

第二层：应用与阅读偏好，可选同步

- `reader_settings`
- `reader_visual_overrides`
- `app_theme_preferences`
- `app_interface_typography`
- `app_navigation_preferences`
- `app_shell_navigation_preferences`
- `bookshelf_presentation_preferences`
- `mine_page_preferences`
- `search_history`
- `home_engagement`
- `discover_preferences`
- `txt_chapter_rules`

第三层：资源型配置，适合后续扩展

- `cover_galleries`
- `launch_image_galleries`
- `bottom_nav_icon_galleries`
- `reader_fonts`

第四层：默认不同步，但保留未来评估空间

- `announcement_read_state`
- `search_system_settings`
- `bookshelf_system_settings`
- `reader_system_settings`
- `source_switch_scores`

第五层：明确不进入首版同步

- `auth_session`
- `source_login_state`
- `book_custom_state`
- `discover_cache_snapshots`
- `source_health_snapshots`
- `source_runtime_diagnostics`
- `search_source_hits`
- `chapter_caches`
- `local_books`
- `local_chapters`
- `local_library_files`

### 4.2 首批建议同步的 scope

首批范围建议继续收敛，不要一口气全上：

- `bookshelf_collection`
- `bookshelf_taxonomy`
- `reading_progress`
- `reading_history`
- `reading_stats`
- `bookmarks`
- `reading_book_statuses`
- `book_metadata_overrides`
- `book_metadata_assets`
- `script_sources`
- `advanced_theme_presets`
- `advanced_theme_assets`

说明：

- `bookshelf_collection` 指书架成员本身
- `bookshelf_taxonomy` 指标签、分类、排序体系
- `book_metadata_overrides` 指用户手改元数据本身
- `book_metadata_assets` 指 override 引用的自定义封面资源
- `advanced_theme_presets` 指主题 JSON 配置本身，以及当前激活主题 id
- `advanced_theme_assets` 指主题引用的壁纸等 managed assets
- `script_sources` 指 `ScriptSource` 列表本身，包括源码与启用状态
- `reading_stats` 指用户在“统计”页看到的结果能力，但 `v1` 不建议独立保存为远端事实源

### 4.3 功能同步清单（面向产品）

这一节不是给开发看的 scope 名，而是给产品和实现一起对齐的“功能级同步清单”。

#### 4.3.1 首批支持同步

书架

- `书架 - 书籍列表`
  同步书架里有哪些书，对应 `bookshelf_collection`。
- `书架 - 标签`
  同步每本书打了哪些标签，对应 `bookshelf_taxonomy`。
- `书架 - 分类`
  同步每本书归属的分类，以及分类顺序，对应 `bookshelf_taxonomy`。
- `书架 - 标签顺序 / 分类顺序 / 基础筛选顺序`
  对应 `bookshelf_taxonomy`。

阅读

- `阅读 - 阅读进度`
  同步章节位置、进度百分比、最近阅读位置，对应 `reading_progress`。
- `阅读 - 阅读历史`
  同步最近阅读、会话记录、阅读时长来源数据，对应 `reading_history`。
- `阅读 - 阅读统计`
  用户可感知为“统计跟着同步”，首版技术上通过 `reading_history` 重建，对应 `reading_stats`。
- `阅读 - 书签`
  同步书签、高亮、摘录、备注，对应 `bookmarks`。
- `阅读 - 在读 / 读完状态`
  对应 `reading_book_statuses`。

书籍资料

- `书籍资料 - 自定义书名`
  对应 `book_metadata_overrides`。
- `书籍资料 - 自定义作者`
  对应 `book_metadata_overrides`。
- `书籍资料 - 自定义简介`
  对应 `book_metadata_overrides`。
- `书籍资料 - 自定义封面配置`
  对应 `book_metadata_overrides`。
- `书籍资料 - 自定义封面图片文件`
  对应 `book_metadata_assets`。

书源

- `书源 - 书源列表`
  对应 `script_sources`。
- `书源 - 书源源码`
  对应 `script_sources`。
- `书源 - 书源启用状态`
  对应 `script_sources`。

外观 / 会员

- `高级主题 - 主题列表`
  对应 `advanced_theme_presets`。
- `高级主题 - 当前启用主题`
  对应 `advanced_theme_presets`。
- `高级主题 - 主题颜色与配置`
  对应 `advanced_theme_presets`。
- `高级主题 - 主题壁纸 / 阅读壁纸资源`
  对应 `advanced_theme_assets`。

#### 4.3.2 后续建议支持同步

阅读器

- `阅读器 - 界面设置`
  包括字号、行距、翻页、亮度、页脚显示等，对应 `reader_settings`。
- `阅读器 - 视觉覆盖设置`
  包括阅读页临时覆盖的背景、字体等，对应 `reader_visual_overrides`。
- `阅读器 - TXT 分章规则`
  对应 `txt_chapter_rules`。

应用外观

- `外观 - 基础主题模式`
  如浅色 / 深色 / 种子色，对应 `app_theme_preferences`。
- `外观 - 应用字体设置`
  对应 `app_interface_typography`。
- `外观 - 导航栏样式`
  对应 `app_navigation_preferences`。
- `外观 - 底部导航显示项`
  对应 `app_shell_navigation_preferences`。
- `外观 - Mine 页布局与入口显隐`
  对应 `mine_page_preferences`。
- `外观 - 封面图集`
  对应 `cover_galleries`。
- `外观 - 启动图集`
  对应 `launch_image_galleries`。
- `外观 - 底栏图集`
  对应 `bottom_nav_icon_galleries`。
- `外观 - 字体文件库`
  对应 `reader_fonts`。

书架偏好

- `书架 - 网格 / 列表模式`
  对应 `bookshelf_presentation_preferences`。
- `书架 - 排序方式`
  对应 `bookshelf_presentation_preferences`。
- `书架 - 网格列数 / 间距 / 展示项`
  对应 `bookshelf_presentation_preferences`。
- `书架 - 搜索栏显隐与固定`
  对应 `bookshelf_presentation_preferences`。

其他常用偏好

- `搜索 - 搜索历史`
  对应 `search_history`。
- `首页 - 打卡记录 / 每日目标`
  对应 `home_engagement`。
- `发现 - 当前选择的发现源`
  对应 `discover_preferences`。

#### 4.3.3 明确不建议同步

安全与登录

- `账号登录态`
- `书源登录态`
- `cookie / token / refresh token`

运行时与缓存

- `章节缓存`
- `搜索命中缓存`
- `书源健康快照`
- `书源运行时诊断状态`
- `Discover 页面快照缓存`

本地文件

- `本地图书文件本体`
- `本地图书章节内容`
- `依赖本机路径的本地阅读资产`

#### 4.3.4 特别说明

- `本地不同步`
  这里不是说“整套同步功能不支持本地数据存储”，而是说 `v1` 不同步“本地图书作用域”的阅读数据和文件。原因是当前本地图书缺少稳定跨设备身份。
- `没有全局`
  这里不是说“没有总开关”，而是说不建议做一个不分项目语义的“全量云备份”默认模式。产品上可以有“全选/推荐组合”，但底层仍要按 scope 精细管理。

### 4.4 建议暂不开放的 scope

- `reader_settings`
- `reader_visual_overrides`
- `app_theme_preferences`
- `app_interface_typography`
- `app_navigation_preferences`
- `app_shell_navigation_preferences`
- `bookshelf_presentation_preferences`
- `mine_page_preferences`
- `search_history`
- `home_engagement`
- `discover_preferences`
- `txt_chapter_rules`
- `cover_galleries`
- `launch_image_galleries`
- `bottom_nav_icon_galleries`
- `reader_fonts`
- `announcement_read_state`
- `search_system_settings`
- `bookshelf_system_settings`
- `reader_system_settings`
- `source_switch_scores`

### 4.5 用户勾选模型

设置页建议按组展示 scope：

核心阅读资产：

- `bookshelf_collection`
- `bookshelf_taxonomy`
- `reading_progress`
- `reading_history`
- `reading_stats`
- `bookmarks`
- `reading_book_statuses`
- `book_metadata_overrides`
- `book_metadata_assets`
- `script_sources`

会员外观：

- `advanced_theme_presets`
- `advanced_theme_assets`

应用与阅读偏好：

- `reader_settings`
- `reader_visual_overrides`
- `app_theme_preferences`
- `app_interface_typography`
- `app_navigation_preferences`
- `app_shell_navigation_preferences`
- `bookshelf_presentation_preferences`
- `mine_page_preferences`
- `search_history`
- `home_engagement`
- `discover_preferences`
- `txt_chapter_rules`

资源扩展：

- `cover_galleries`
- `launch_image_galleries`
- `bottom_nav_icon_galleries`
- `reader_fonts`

交互建议：

- 每个 scope 单独勾选
- 提供“推荐组合”
- 对存在依赖关系的 scope 给出联动提示

例如：

- 勾选 `advanced_theme_assets` 时，默认联动勾选 `advanced_theme_presets`
- 勾选 `book_metadata_assets` 时，默认联动勾选 `book_metadata_overrides`
- 勾选 `bookshelf_taxonomy` 时，默认提示最好同时勾选 `bookshelf_collection`
- 只勾选 `advanced_theme_presets` 也允许，但 UI 要提示“另一台设备可能缺少壁纸资源，将降级显示”
- `reading_stats` 勾选时，默认联动勾选 `reading_history`，因为统计页当前主要由阅读历史重建
- `script_sources` 建议默认关闭，由用户主动开启，因为用户未必希望把自定义书源同步到所有设备

### 4.6 特别说明：本地图书与本地作用域数据

`WebDAV v1` 不建议同步本地图书相关状态，至少不建议默认启用，原因是当前 `LocalBook` 缺少稳定的跨设备内容指纹。

现状里本地图书身份更多依赖本地 `bookId` / `storagePath`，这在另一台设备上通常不成立。  
如果未来要支持本地图书进度和书签同步，应先补充类似字段：

- `contentFingerprintSha256`
- `archiveFingerprint`
- `sourceFileFingerprint`

在没有稳定内容指纹前，本地图书同步会产生大量误关联。

因此以下带本地作用域的数据也要一起保守处理：

- 本地图书的 `book_metadata_overrides`
- 本地图书的 `reading_progress`
- 本地图书的 `bookmarks`
- 本地图书的 `reading_book_statuses`

在 `v1` 里建议仅同步远程书籍作用域的数据。

## 5. 架构落点

按当前架构约束，建议新增独立 feature：

```text
lib/features/sync/
  presentation/
    sync_settings_page.dart
    sync_history_page.dart
    widgets/
  application/
    sync_profile_service.dart
    sync_orchestrator.dart
    sync_plan_builder.dart
    sync_history_service.dart
    sync_conflict_service.dart
    exporters/
    importers/
  domain/
    sync_profile.dart
    sync_scope.dart
    sync_job.dart
    sync_conflict.dart
    sync_snapshot.dart
    sync_remote_driver.dart
  data/
    repositories/
    local/
    remote/
      webdav_sync_remote_driver.dart
  providers.dart
  routes.dart
```

落点原则：

- 同步页面只负责展示 profile、任务状态、历史记录
- 同步编排放 `application/`
- 同步 profile、job、conflict、自定义 snapshot 元信息放 `feature domain/data`
- `WebDAV` 实现作为 `remote driver`
- 不要让 `reader` / `bookshelf` / `book` 页面直接调用 WebDAV

## 6. 核心设计：先做“同步域”，再做“远端适配器”

同步系统建议拆成两层：

### 6.1 同步域层

负责：

- 定义哪些数据可同步
- 导出本地快照
- 对比 base / local / remote
- 计算 merge 结果
- 回写本地
- 记录冲突和历史

这一层不关心远端是 `WebDAV`、自建服务器还是别的网盘。

### 6.2 远端驱动层

负责：

- 列目录
- 读文件
- 写文件
- 获取远端 revision / etag / modified time
- 创建目录

这层只提供“像文件仓库一样的远端能力”。

这样以后接入：

- `WebDAV`
- 自建 HTTP API
- S3 兼容存储
- 其他网盘桥接

都不需要重写本地 merge 逻辑。

## 7. 本地数据模型建议

建议在本地新增以下表或等价持久化结构：

### 7.1 `sync_profiles`

字段建议：

- `id`
- `name`
- `driverType`，如 `webdav`
- `endpointUrl`
- `basePath`
- `username`
- `secretRef`
- `enabledScopesJson`
- `scopeConfigJson`
- `isAutoSyncEnabled`
- `lastSyncAt`
- `createdAt`
- `updatedAt`

说明：

- 密码不要明文放这里
- `secretRef` 只存“去系统安全存储取密钥的 key”
- `enabledScopesJson` 保存勾选项
- `scopeConfigJson` 为未来保留 per-scope 配置，例如“仅 Wi‑Fi 同步资源类 scope”

### 7.2 `sync_scope_states`

每个 `profile + scope` 一条，用于三方合并。

字段建议：

- `profileId`
- `scope`
- `lastBaseSnapshotJson`
- `lastRemoteRevision`
- `lastRemoteHash`
- `lastLocalHash`
- `lastSyncedAt`

这个表是关键。  
它保存“上次成功同步的共同基线”，用于后续三方合并。

### 7.3 `sync_jobs`

字段建议：

- `id`
- `profileId`
- `triggerKind`，如 `manual` / `appStart` / `foreground`
- `direction`，建议固定为 `bidirectional`
- `status`，如 `running` / `success` / `partial` / `failed`
- `startedAt`
- `endedAt`
- `summaryJson`
- `errorMessage`

### 7.4 `sync_conflicts`

字段建议：

- `id`
- `profileId`
- `scope`
- `recordKey`
- `basePayloadJson`
- `localPayloadJson`
- `remotePayloadJson`
- `resolution`
- `createdAt`
- `resolvedAt`

首版即使默认自动解决大部分冲突，也建议把高风险冲突落表，便于未来做冲突详情页。

## 8. 本地凭据存储

`WebDAV` 凭据不建议放 `SharedPreferences` 或普通 Drift 字段。

建议新增安全存储依赖，例如：

- `flutter_secure_storage`

口径：

- `sync_profiles` 只存 `secretRef`
- 真正的密码走系统安全存储
- UI 编辑凭据时只改安全存储，不把密码回显到普通日志或历史表

## 9. 远端目录协议建议

`WebDAV` 远端建议按“应用私有目录 + manifest + datasets”组织：

```text
<basePath>/selune-sync/v1/
  manifest.json
  datasets/
    bookshelf_collection.json
    bookshelf_taxonomy.json
    reading_progress.json
    reading_history.json
    reading_stats_snapshot.json
    bookmarks.json
    reading_book_statuses.json
    book_metadata_overrides.json
    book_metadata_assets.json
    script_sources.json
    advanced_theme_presets.json
    advanced_theme_assets.json
  logs/
    2026-04/
      sync-job-<jobId>.json
```

说明：

- `manifest.json` 是远端入口
- `datasets/*.json` 是各个 scope 的当前快照
- `logs/` 可选，只保存摘要，方便人工排查

## 10. 远端文件格式建议

### 10.1 `manifest.json`

建议结构：

```json
{
  "schemaVersion": 1,
  "app": "selune",
  "updatedAt": "2026-04-29T12:00:00Z",
  "updatedBy": {
    "installId": "xxx",
    "platform": "android",
    "appVersion": "1.1.0"
  },
  "datasets": {
    "bookshelf_collection": {
      "path": "datasets/bookshelf_collection.json",
      "hash": "sha256:...",
      "revision": "\"etag-value\"",
      "updatedAt": "2026-04-29T12:00:00Z"
    }
  }
}
```

### 10.2 dataset 文件

建议每个 scope 都统一包一层 envelope：

```json
{
  "schemaVersion": 1,
  "scope": "reading_progress",
  "generatedAt": "2026-04-29T12:00:00Z",
  "device": {
    "installId": "xxx"
  },
  "items": []
}
```

这样未来做 schema 升级和调试更稳。

## 11. 关键技术路线：三方合并，不做“谁覆盖谁”的粗暴同步

首版不要做：

- 上传覆盖远端
- 下载覆盖本地

建议固定采用：

- `base`：上次成功同步基线
- `local`：当前本地导出结果
- `remote`：当前远端下载结果

然后按 scope 执行三方合并。

优势：

- 可以识别删除
- 可以识别双方是否都改过
- 不需要所有业务都先引入实时操作日志

这很适合当前项目，因为现有状态分散在多个 service，短期内不适合先做全局 mutation journal。

## 12. 各 scope 的合并策略

### 12.1 `reading_progress`

主键建议：

- 远程书籍：`SourceBookKey.storageKey`
- 本地图书：`v1` 不同步

策略：

- 按 `updatedAt` 取新
- 如果双方都改了且时间接近，可记录低优先级冲突
- 导入本地时只覆盖进度，不动阅读统计

### 12.2 `bookmarks`

主键建议：

- `bookmark.id`

策略：

- 新增：并集
- 更新：按 `updatedAt`
- 删除：基于三方合并识别 tombstone

说明：

书签具备 `updatedAt`，是非常适合三方合并的一类数据。

### 12.3 `reading_history`

建议包含：

- `ReadingRecord`
- `ReadingRecordSession`

`ReadingRecordDay` 不建议直接远端持久化，可在导入后本地重建，避免重复冗余。

策略：

- `session` 以稳定 key 去重，建议新增显式 `sessionUid`
- `record` 以 `SourceBookKey.storageKey` 为主键
- 汇总值优先由 `session` 重建，避免双方累计口径偏差

这里有一个必要前置改造：

- 当前 `StoredReadingRecordSessions.id` 是本地自增整数，不适合跨设备同步

建议新增：

- `syncSessionId`

生成方式可基于：

- `installId + bookKey + startAt + endAt + chapterIndex`

没有这个稳定 ID，跨设备 session 很难可靠去重。

### 12.4 `reading_stats`

这个 scope 需要明确分两层：

- 用户理解层：这是“统计页是否能跟着同步”
- 数据实现层：当前统计页主要由 `ReadingRecord / ReadingRecordDay / ReadingRecordSession` 派生生成

基于当前代码现状，`v1` 建议口径是：

- 用户勾选了 `reading_history`，就应该获得“统计可同步”的结果
- `reading_stats` 不作为首版独立事实源
- 统计结果优先在本地根据同步下来的阅读历史重建

原因：

- 当前 `ReadingRecordsQueryService / ReadingRecordsStatsPresenter` 主要是聚合层，不是权威存储
- 如果把统计结果再作为一个独立远端事实源，会和阅读历史形成双写、双口径
- 统计本身后续还会优化，现在太早固化远端协议反而会拖慢后续重构

因此建议把 `reading_stats` 视为：

- 产品可见 scope
- 但技术实现上依赖 `reading_history`

首版实现建议：

- UI 上允许用户看到“阅读统计”勾选项
- 勾选 `reading_stats` 时自动勾选 `reading_history`
- 后端真正同步的是 `reading_history`
- 导入后本地重建统计页所需数据与投影

后续优化建议：

- 如果统计页后续出现明显首屏计算压力，再追加一个可选的 `reading_stats_snapshot`
- 该 snapshot 只做缓存加速，不做权威事实源
- 一旦 snapshot 丢失或冲突，必须允许完全由 `reading_history` 重建

### 12.5 `reading_book_statuses`

建议同步内容：

- `ReadingBookStatusEntry`

策略：

- 主键使用远程书籍的 `SourceBookKey.storageKey`
- 冲突按 `updatedAt` 取新
- 本地图书作用域仍默认不进入 `v1`

这项本质上是用户显式判断结果，应该和阅读记录分开看待，不应丢失。

### 12.6 `book_metadata_overrides`

建议同步内容：

- `BookMetadataOverride.targetKey`
- `title / author / intro / coverPath`
- `createdAt / updatedAt`

策略：

- 只同步远程书籍作用域 override
- 主键使用 `targetKey`
- 冲突按 `updatedAt` 取新
- `coverPath` 仅作为资源引用，真实文件归 `book_metadata_assets`

说明：

- 这是用户手工编辑资产，优先级很高
- 它不应该和书源原始抓取结果混在一起

### 12.7 `book_metadata_assets`

建议同步内容：

- `BookMetadataOverride.coverPath` 引用的自定义封面文件

策略：

- 资源文件按内容哈希去重上传
- 远端保存为 `assets/book_metadata/<content-hash>.<ext>`
- 配置缺资源时允许降级，不阻塞 metadata override 本体导入

依赖关系：

- `book_metadata_assets` 依赖 `book_metadata_overrides`

### 12.8 `bookshelf_collection`

主键建议：

- `SourceBookKey.storageKey`

策略：

- 集合成员采用并集
- 删除用三方合并识别
- `title / author / coverUrl / latestChapter` 采用“更完整字段优先，时间相同时保留非空值更多的一侧”
- `category` 建议 `v1` 先保守处理，默认本地优先

原因：

- 当前 `BookshelfBook` 没有显式 `updatedAt`
- 书架本身更像“集合 + 展示快照”，而不是强事务对象

建议不要在 `v1` 就追求复杂字段级实时协同。

### 12.9 `bookshelf_taxonomy`

建议同步内容：

- 书架标签映射
- 标签顺序
- 分类顺序
- 基础筛选顺序

策略：

- 标签与分类分开建模
- 对单书标签映射按书籍 key 合并
- 顺序列表冲突时优先保留“并集 + 相对顺序尽量稳定”

说明：

- 这一项如果不单独同步，书架的组织体系会丢失
- 它应与 `bookshelf_collection` 拆 scope，但 UI 上可以作为同组能力展示

### 12.10 `script_sources`

建议同步内容：

- `ScriptSource.id`
- `ScriptSource.name`
- `ScriptSource.sourceCode`
- `ScriptSource.enabled`
- `ScriptSource.createdAt`
- `ScriptSource.updatedAt`
- 以及现有元字段：`group / author / description / checkKeyword / primaryHost / registrableDomain / clusterKey`

明确不属于本 scope 的内容：

- 登录态
- cookie / token
- 运行时缓存
- 健康状态、自动禁用状态、诊断面板数据

策略：

- 主键使用 `ScriptSource.id`
- 同一 `id` 冲突时按 `updatedAt` 取新
- 删除通过三方合并识别 tombstone
- 导入本地后触发一次书源注册/重载

补充建议：

- UI 上命名为“书源列表与源码同步”，避免用户误以为登录态也会跟着走
- 对用户自定义修改过的书源，冲突详情里要能看到“本地更新 / 远端更新”

这一项总体量通常不大，适合进入首批可选同步范围。

### 12.11 `advanced_theme_presets`

建议同步内容：

- `AppAdvancedTheme` 列表
- `activeThemeId`

当前代码基础可直接支撑这件事：

- `AppAdvancedTheme` 已有 `id / createdAt / updatedAt`
- `AdvancedThemeService` 已有 `loadThemes / saveThemes / loadActiveThemeId / saveActiveThemeId`

策略：

- 主题主键使用 `theme.id`
- 主题对象按 `updatedAt` 取新
- 删除通过三方合并识别 tombstone
- `activeThemeId` 不做复杂合并，默认“最后更新时间更新的一侧优先”

说明：

- 这一项本质上是会员配置数据，应该进入首批可同步范围
- 它的体积小、结构稳定，远比“所有外观资源都一起同步”更适合先落地

### 12.12 `advanced_theme_assets`

建议同步内容：

- `AppAdvancedThemeModeConfig.wallpaperAsset`
- `AppAdvancedThemeModeConfig.readerWallpaperAsset`

策略：

- 资源文件按内容哈希去重上传
- 远端保存为 `assets/advanced_themes/<content-hash>.<ext>`
- `advanced_theme_presets` 中只保存资源引用，不直接内联大体积二进制

依赖关系：

- `advanced_theme_assets` 依赖 `advanced_theme_presets`
- 导入时若缺失资源文件，主题配置仍可导入，但运行态降级为无壁纸

这比把所有 managed assets 打成一个大 scope 更合适，因为：

- 主题壁纸是高级主题最核心的会员资产之一
- 它和封面图库、启动图、底栏图标、字体并不是同一个价值层级
- 用户可以只同步主题配置，也可以同时同步壁纸资源

## 13. WebDAV 驱动设计

建议定义统一接口：

```dart
abstract class SyncRemoteDriver {
  Future<void> ensureReady();
  Future<SyncRemoteFileStat?> stat(String path);
  Future<String?> readText(String path);
  Future<void> writeText(
    String path,
    String content, {
    String? ifMatchRevision,
  });
  Future<void> ensureDirectory(String path);
}
```

`WebDAV` 实现建议：

- 基于 `dio`
- 认证先支持 Basic Auth
- 目录探测和 `etag` 获取通过 `PROPFIND Depth: 0`
- 文件读取用 `GET`
- 文件写入用 `PUT`
- 缺失目录时用 `MKCOL`
- 优先使用 `ETag + If-Match` 做乐观并发控制

不建议把标准 `LOCK/UNLOCK` 作为必需能力，因为不同 WebDAV 服务商兼容性差异很大。

## 14. 导出器 / 导入器设计

建议每个 scope 一对组件：

- `BookshelfSyncExporter` / `BookshelfSyncImporter`
- `BookshelfTaxonomySyncExporter` / `BookshelfTaxonomySyncImporter`
- `ReadingProgressSyncExporter` / `ReadingProgressSyncImporter`
- `ReadingHistorySyncExporter` / `ReadingHistorySyncImporter`
- `ReadingStatsSnapshotExporter` / `ReadingStatsSnapshotImporter`
- `BookmarkSyncExporter` / `BookmarkSyncImporter`
- `ReadingBookStatusSyncExporter` / `ReadingBookStatusSyncImporter`
- `BookMetadataOverrideSyncExporter` / `BookMetadataOverrideSyncImporter`
- `BookMetadataAssetSyncExporter` / `BookMetadataAssetSyncImporter`
- `ScriptSourceSyncExporter` / `ScriptSourceSyncImporter`
- `AdvancedThemePresetSyncExporter` / `AdvancedThemePresetSyncImporter`
- `AdvancedThemeAssetSyncExporter` / `AdvancedThemeAssetSyncImporter`

职责：

- exporter：从现有 service / repository 读取业务数据并归一化
- importer：把 merge 结果回写到现有 service / repository

这能把同步 feature 和已有 feature 解耦在 application 层，而不是直接在 UI 或 WebDAV driver 里写业务逻辑。

## 15. 现有代码的适配建议

### 15.1 可直接复用

- `DeviceIdentityService`
  用于生成 `installId`、写入 manifest 的设备信息
- `ReadingRecordService`
  可作为阅读历史导出/导入入口之一
- `ReadingRecordsQueryService`
  可作为统计页重建与后续 snapshot 导出的聚合入口
- `ReaderPreferencesService`
  可复用阅读进度读写
- `BookmarkRepository`
  可作为书签导入导出入口
- `BookshelfService`
  可作为书架导入导出入口
- `BookMetadataOverrideRepository`
  可作为元数据覆盖导入导出入口
- `ReadingBookStatusService`
  可作为阅读状态导入导出入口
- `ScriptSourceRepository`
  可作为书源列表导入导出入口
- `AdvancedThemeService`
  可作为高级主题配置与资源导入导出入口

### 15.2 建议增加的薄适配层

不要让同步编排直接深入各 service 的内部细节，建议增加：

- `SyncBookshelfGateway`
- `SyncBookshelfTaxonomyGateway`
- `SyncReadingProgressGateway`
- `SyncReadingHistoryGateway`
- `SyncReadingStatsGateway`
- `SyncBookmarkGateway`
- `SyncReadingBookStatusGateway`
- `SyncBookMetadataOverrideGateway`
- `SyncBookMetadataAssetGateway`
- `SyncScriptSourceGateway`
- `SyncAdvancedThemeGateway`

这些 gateway 放在 `features/sync/application/`，负责把现有服务收口成同步需要的最小读写接口。

## 16. UI 形态建议

`v1` 先做两个页面即可：

- 同步设置页
- 同步历史页

同步设置页包含：

- 开关
- 同步方式选择，首版只有 `WebDAV`
- 地址、用户名、密码、根目录
- 分组的可同步 scope 勾选
- 对依赖 scope 的联动提示
- 推荐组合快捷入口，例如“仅阅读数据”“阅读数据 + 会员主题”
- 测试连接
- 立即同步

同步历史页包含：

- 最近任务列表
- 每次任务成功/失败状态
- 变更摘要
- 错误信息

不要在 `v1` 就做过重的可视化 diff 页面。

## 17. 实施顺序建议

### 阶段 1：基础设施

- 新增 `features/sync/`
- 新增 `sync_profiles / sync_scope_states / sync_jobs / sync_conflicts`
- 接入安全存储
- 实现 `SyncRemoteDriver`
- 实现 `WebDavSyncRemoteDriver`

### 阶段 2：只做读取和上传验证

- 测试连接
- 创建远端目录
- 写入最小 `manifest.json`
- 读取远端 `manifest.json`

### 阶段 3：先打通单 scope

优先级建议：

1. `reading_progress`
2. `bookmarks`
3. `script_sources`
4. `reading_book_statuses`
5. `book_metadata_overrides`
6. `advanced_theme_presets`
7. `reading_history`
8. `reading_stats`
9. `bookshelf_collection`
10. `bookshelf_taxonomy`
11. `book_metadata_assets`
12. `advanced_theme_assets`

理由：

- `reading_progress` 结构最简单，最容易验证首轮协议
- `bookmarks` 有 `updatedAt`，冲突处理清晰
- `script_sources` 总体量通常不大，结构规整，而且跨设备复用价值高，适合较早接入
- `reading_book_statuses` 是明确用户判定，模型小、收益高
- `book_metadata_overrides` 是强用户资产，应该早于很多 UI 偏好进入同步
- `advanced_theme_presets` 已有稳定 `id / updatedAt`，而且是会员价值点，适合尽早纳入
- `reading_history` 价值高，但需要先补 `session` 稳定 ID
- `reading_stats` 用户感知强，但首版应依赖 `reading_history` 重建，后续再看是否补 snapshot 加速
- `bookshelf_collection / bookshelf_taxonomy` 受当前 SharedPreferences 结构影响更大，放后面更稳
- `book_metadata_assets / advanced_theme_assets` 都需要补资源文件同步和哈希去重，适合在配置链路稳定后再上

### 阶段 4：补历史与自动化

- 同步任务历史页
- 失败重试
- 进入前台后轻量自动同步
- 应用启动后延迟同步

## 18. 风险与前置改造

### 18.1 必须优先解决

- `WebDAV` 凭据安全存储
- `ReadingRecordSession` 稳定跨设备 ID
- 本地图书不同步边界要在 UI 里明确提示
- 高级主题配置与主题资源要拆 scope，不能混成一个“大外观同步”
- `reading_stats` 首版必须坚持“历史为事实源、统计为派生结果”，避免双写失真
- `bookshelf_collection` 与 `bookshelf_taxonomy` 必须同时设计，否则书架组织信息会丢
- `book_metadata_overrides` 与 `book_metadata_assets` 必须拆 scope，但默认联动

### 18.2 可以后补

- `reader_settings` 同步
- 主题关联的 `cover_gallery / launch_image_gallery / bottom_nav_icon_gallery / reader_fonts`
- 冲突详情页
- 多 profile

## 19. 结论

建议方案不是“给现有页面加一个 WebDAV 按钮”，而是：

1. 建一个独立的 `sync feature`
2. 把同步定义成“本地状态导出 + 远端快照协议 + 三方合并 + 本地回写”
3. 首批支持 `reading_progress / bookmarks / script_sources / reading_book_statuses / book_metadata_overrides / advanced_theme_presets / reading_history / reading_stats / bookshelf_collection / bookshelf_taxonomy`
4. `reading_stats` 首版技术上跟随 `reading_history` 重建，后续可补 snapshot 优化
5. `book_metadata_assets` 与 `advanced_theme_assets` 都单独作为资源 scope，允许用户自行勾选
6. 首版远端只实现 `WebDAV driver`
7. 明确排除本地图书文件、登录态同步，以及其余未分 scope 的资源类数据

这是和当前项目架构约束最一致、后续也最容易继续扩展到“多种网盘和服务器”的路线。
