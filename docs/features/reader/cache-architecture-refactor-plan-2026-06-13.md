# 缓存架构专项改造计划

**创建日期**: 2026-06-13  
**范围**: 阅读端 Flutter 项目内章节、分页、图片、API、搜索命中、主题预览、书源健康等缓存链路。  
**目标**: 一次性把分散缓存纳入统一协议、统一日志、统一治理和统一迁移路径，避免后续每个功能各自补缓存、各自清理、各自返工。

## 阶段执行状态

- [x] C0 缓存资产盘点完成。
- [x] C1 统一缓存协议完成。
- [x] C2 统一缓存日志能力层完成。
- [ ] C2 具体 backend trace 接入待 C4-C9 执行。
- [x] C3 统一缓存 Coordinator 能力层完成。
- [x] C3 章节内容与分页布局 store 已注册到 reader coordinator。
- [x] C3 API、搜索命中、书源健康 store 已注册到 app coordinator。
- [x] C3 主题预览、字体、本地书索引等 store 已注册到 app coordinator / 存储治理入口。
- [x] C4 章节内容缓存协议化接入完成。
- [x] C5 分页布局缓存协议化接入完成。
- [x] C6 阅读器网络图片统一组件替换完成。
- [x] C7 API 缓存默认实时与显式短缓存治理完成。
- [x] C8 搜索命中与书源健康缓存治理完成。
- [x] C9 用户资产与阅读偏好缓存边界治理完成（parserVersion / 视觉覆盖按主题维度待 schema 升级）。
- [x] C10 缓存治理 service 与存储管理页单项清理完成。
- [x] C11 后端替换评估完成：本轮不引入 Hive，不做长期双写，保留现有稳定 backend。
- [x] C12 旧入口扫描与业务层绕过点清理完成。

---

## 0. 改造原则

- [ ] 任何缓存读写必须能归属到一个明确 `scope`。
- [ ] 任何缓存读写必须能输出 `hit`、`miss`、`stale`、`decodeFailed`、`versionMismatch`、`backendError` 中的一种结果。
- [ ] 任何缓存必须声明是否可删除。
- [ ] 任何缓存必须声明是否可重建。
- [ ] 任何缓存必须声明是否用户隔离。
- [ ] 任何缓存必须声明是否参与容量治理。
- [ ] 任何缓存必须声明失效条件。
- [ ] 任何缓存必须声明默认 TTL。
- [ ] 任何缓存必须声明底层 backend。
- [x] 不做“全量强换 Hive”。
- [x] 不做“保留旧入口但新入口也加一套”的双倍复杂度。
- [x] 不把用户资产写入可清理缓存目录。
- [x] 不让页面层直接拼缓存 key。
- [x] 不让页面层直接判断缓存后端。
- [x] 不让页面层直接处理缓存损坏恢复。

---

## 1. 当前缓存范围清单

### 1.1 阅读核心缓存

- [x] 章节内容缓存：`chapter_caches` 表。
- [x] 章节内容缓存入口：`ReaderCachedChapterStore`。
- [x] 章节内容缓存写入：`AppDatabase.upsertChapterCache`。
- [x] 章节内容缓存读取：`AppDatabase.getChapterCache`。
- [x] 章节内容缓存清理：`AppDatabase.pruneChapterCachesByBudget`。
- [x] 分页布局内存缓存：`ReaderPaginationCacheService._memoryCache`。
- [x] 分页布局文件缓存：`ReaderPaginationCacheService` 持久化目录。
- [x] 分页布局缓存治理：`AppPaginationLayoutCacheStore`。
- [x] 章节网关内容缓存编解码：`ReaderGatewayContentCacheCodec`。
- [x] 章节缓存 payload 解码：`ReaderChapterCacheDecoder`。

### 1.2 图片缓存

- [x] 封面图片缓存：`CoverImageDiskCache`。
- [x] 封面图片组件：`DiskCachedCoverImage`。
- [x] 书籍封面解析缓存：`ResolvedBookCover`。
- [x] 阅读器正文图片：`ReaderImagePipeline`。
- [x] 阅读器分页图片：`ReaderTextPagedView`。
- [x] 阅读器滚动图片：`ReaderTextScrollView`。
- [x] 阅读器漫画图片：`ReaderMangaView`。
- [x] 阅读器内容渲染图片：`reader_page_content_rendering.dart`。
- [x] 高级主题背景图片 provider 缓存：`AdvancedThemeBackdropDecoration`。
- [x] 高级主题预览图片缓存：`advanced_theme_preview_image_cache.dart`。

### 1.3 API 与业务缓存

- [x] API 内存缓存：`ApiCacheStore`。
- [x] API 缓存 key：`ApiClient._cacheKey`。
- [x] API 缓存策略：`ApiCachePolicy`。
- [x] 公告 latest 内存缓存：`AnnouncementService`。
- [x] 搜索命中缓存：`SearchHitCacheService`。
- [x] 搜索命中表：`search_source_hits`。
- [x] 书源健康缓存：`SourceHealthPersistenceService`。
- [x] 书架详情首屏缓存：`BookDetailService.peekCached`。
- [x] 本地书索引缓存：`LocalBookIndexService`。
- [x] 阅读设置 JSON 缓存：`ReaderPreferencesService`。
- [x] 字体注册缓存：`ReaderFontRegistryService`。
- [x] 视觉覆盖缓存：`ReaderVisualOverridesService`。

### 1.4 资源与临时缓存

- [x] 外部导入临时文件缓存：`ExternalSourceImportBridge`。
- [x] 底部导航图集索引缓存：`BottomNavIconGalleryService`。
- [x] 托管资源 store 派生缓存：`ManagedAssetStore`。
- [x] 启动期缓存预算执行：`AppStartupCoordinator.cacheBudgetEnforcement`。
- [x] 全局缓存治理服务：`AppCacheGovernanceService`。

### 1.5 CacheInventory

| scope | 当前 owner | 当前 backend | 默认 TTL | 用户隔离 | 可删除 | 可重建 | 迁移策略 |
|---|---|---|---:|---|---|---|---|
| `chapterContent` | 阅读器 | Drift `chapter_caches` | 45 天 | 是 | 是 | 是 | C4 接入 `ReaderChapterContentCacheStore`，保留旧表做 backend。 |
| `paginationLayout` | 阅读器 | 内存 LRU + 文件目录 | 30 天 | 是 | 是 | 是 | C5 接入 `ReaderPaginationLayoutCacheStore`，保留文件 backend。 |
| `coverImage` | 全局封面 | `flutter_cache_manager` | 30 天 | 否 | 是 | 是 | C6/C10 统一 stats 与清理，继续复用成熟库。 |
| `readerImage` | 阅读器正文/漫画 | `Image.network` + Flutter 内存图片缓存 | 30 天 | 否 | 是 | 是 | C6 替换裸 `Image.network`，接入统一图片组件。 |
| `apiResponse` | `ApiClient` | 内存 Map | 5 分钟 | 是 | 是 | 是 | C7 默认实时，白名单接口才允许缓存。 |
| `searchHit` | 搜索/详情 | Drift `search_source_hits` | 7 天 | 是 | 是 | 是 | C8 接入 coordinator，按用户、书名、作者、源隔离。 |
| `sourceHealth` | 书源检测 | Drift/JSON 持久化 | 12 小时 | 否 | 是 | 是 | C8 接入 coordinator，失败/成功都带状态展示。 |
| `themePreview` | 高级主题 | 内存/文件 provider 缓存 | 30 天 | 否 | 是 | 是 | C9 只清理可重建预览，不误删主题资产。 |
| `localBookIndex` | 本地书 | Drift/本地索引服务 | 无固定 TTL | 否 | 是 | 是 | C9 以 fileSize、modifiedAt 失效；parserVersion 待 schema 升级。 |
| `readerPreference` | 阅读设置 | SharedPreferences/JSON | 无固定 TTL | 是 | 否 | 否 | C9 仅纳入协议和备份，不作为普通缓存清理。 |

---

## 2. Phase C0：缓存资产盘点

**目标**: 先把每个缓存落点登记清楚，避免改到一半发现还有隐藏入口。

- [x] 新建缓存盘点表格章节。
- [x] 登记 `chapter_caches` 表字段。
- [x] 登记 `search_source_hits` 表字段。
- [x] 登记分页布局缓存目录路径。
- [x] 登记封面图片缓存目录路径。
- [x] 登记高级主题预览缓存位置。
- [x] 登记 API 内存缓存 key 组成。
- [x] 登记公告缓存 key 组成。
- [x] 登记书源健康缓存 key 组成。
- [x] 登记本地书索引缓存 key 组成。
- [x] 登记阅读设置缓存 key 组成。
- [x] 登记字体注册缓存 key 组成。
- [x] 登记视觉覆盖缓存 key 组成。
- [x] 标记章节内容缓存是否用户隔离。
- [x] 标记分页布局缓存是否用户隔离。
- [x] 标记封面图片缓存是否用户隔离。
- [x] 标记 API 缓存是否用户隔离。
- [x] 标记搜索命中缓存是否用户隔离。
- [x] 标记书源健康缓存是否用户隔离。
- [x] 标记主题预览缓存是否用户隔离。
- [x] 标记每个缓存是否可删除。
- [x] 标记每个缓存是否可重建。
- [x] 标记每个缓存是否需要迁移。
- [x] 标记每个缓存是否可直接废弃。
- [x] 标记每个缓存是否需要保留旧读入口。
- [x] 输出 `CacheInventory` 表格。

验收:

- [x] 文档里能看到每个缓存的 owner。
- [x] 文档里能看到每个缓存的 backend。
- [x] 文档里能看到每个缓存的 TTL。
- [x] 文档里能看到每个缓存的清理策略。
- [x] 文档里能看到每个缓存的迁移策略。

---

## 3. Phase C1：统一缓存协议

**目标**: 先统一模型，不急着换后端。

- [x] 新建 `lib/core/cache/cache_scope.dart`。
- [x] 定义 `AppCacheScope.chapterContent`。
- [x] 定义 `AppCacheScope.paginationLayout`。
- [x] 定义 `AppCacheScope.coverImage`。
- [x] 定义 `AppCacheScope.readerImage`。
- [x] 定义 `AppCacheScope.apiResponse`。
- [x] 定义 `AppCacheScope.searchHit`。
- [x] 定义 `AppCacheScope.sourceHealth`。
- [x] 定义 `AppCacheScope.themePreview`。
- [x] 定义 `AppCacheScope.localBookIndex`。
- [x] 定义 `AppCacheScope.readerPreference`。
- [x] 新建 `lib/core/cache/cache_key.dart`。
- [x] 定义 `AppCacheKey.scope`。
- [x] 定义 `AppCacheKey.owner`。
- [x] 定义 `AppCacheKey.parts`。
- [x] 定义 `AppCacheKey.normalized`。
- [x] 定义 `AppCacheKey.toStorageKey()`。
- [x] 新建 `lib/core/cache/cache_policy.dart`。
- [x] 定义 `AppCachePolicy.ttl`。
- [x] 定义 `AppCachePolicy.maxEntries`。
- [x] 定义 `AppCachePolicy.maxBytes`。
- [x] 定义 `AppCachePolicy.userScoped`。
- [x] 定义 `AppCachePolicy.rebuildable`。
- [x] 定义 `AppCachePolicy.deletable`。
- [x] 定义 `AppCachePolicy.version`。
- [x] 新建 `lib/core/cache/cache_entry.dart`。
- [x] 定义 `AppCacheEntry.key`。
- [x] 定义 `AppCacheEntry.payload`。
- [x] 定义 `AppCacheEntry.createdAt`。
- [x] 定义 `AppCacheEntry.updatedAt`。
- [x] 定义 `AppCacheEntry.lastAccessedAt`。
- [x] 定义 `AppCacheEntry.expiresAt`。
- [x] 定义 `AppCacheEntry.version`。
- [x] 定义 `AppCacheEntry.sizeBytes`。
- [x] 定义 `AppCacheEntry.metadata`。
- [x] 新建 `lib/core/cache/cache_result.dart`。
- [x] 定义 `AppCacheReadStatus.hit`。
- [x] 定义 `AppCacheReadStatus.miss`。
- [x] 定义 `AppCacheReadStatus.stale`。
- [x] 定义 `AppCacheReadStatus.decodeFailed`。
- [x] 定义 `AppCacheReadStatus.versionMismatch`。
- [x] 定义 `AppCacheReadStatus.backendError`。
- [x] 定义 `AppCacheInvalidReason.ttlExpired`。
- [x] 定义 `AppCacheInvalidReason.versionChanged`。
- [x] 定义 `AppCacheInvalidReason.layoutChanged`。
- [x] 定义 `AppCacheInvalidReason.fontChanged`。
- [x] 定义 `AppCacheInvalidReason.themeChanged`。
- [x] 定义 `AppCacheInvalidReason.viewportChanged`。
- [x] 定义 `AppCacheInvalidReason.userChanged`。
- [x] 定义 `AppCacheInvalidReason.payloadCorrupted`。
- [x] 新建 `lib/core/cache/cache_store.dart`。
- [x] 定义 `AppCacheStore.read()`。
- [x] 定义 `AppCacheStore.write()`。
- [x] 定义 `AppCacheStore.delete()`。
- [x] 定义 `AppCacheStore.clearScope()`。
- [x] 定义 `AppCacheStore.stats()`。
- [x] 定义 `AppCacheStore.prune()`。

验收:

- [x] `flutter analyze` 不报新增错误。
- [x] 协议层没有依赖 Flutter widget。
- [x] 协议层没有依赖阅读器页面。
- [x] 协议层没有依赖具体数据库。
- [x] 协议层有单元测试覆盖 key 归一化。
- [x] 协议层有单元测试覆盖 TTL 判断。
- [x] 协议层有单元测试覆盖 version mismatch。

---

## 4. Phase C2：统一缓存日志

**目标**: 所有缓存问题都能从日志判断是命中、失效、解码失败还是后端失败。

说明：本阶段先完成 trace 能力层；具体章节、分页、图片、API 等 backend 的 trace 接入在 C4-C9 随 store 改造逐项完成。

- [x] 新建 `lib/core/cache/cache_trace.dart`。
- [x] 定义 `AppCacheTraceEvent.scope`。
- [x] 定义 `AppCacheTraceEvent.key`。
- [x] 定义 `AppCacheTraceEvent.status`。
- [x] 定义 `AppCacheTraceEvent.backend`。
- [x] 定义 `AppCacheTraceEvent.owner`。
- [x] 定义 `AppCacheTraceEvent.sizeBytes`。
- [x] 定义 `AppCacheTraceEvent.costMs`。
- [x] 定义 `AppCacheTraceEvent.invalidReason`。
- [x] 定义 `AppCacheTraceEvent.errorType`。
- [x] 定义 `AppCacheTraceEvent.errorMessage`。
- [x] 新建 `AppCacheTracer`。
- [x] 实现 `traceRead()`。
- [x] 实现 `traceWrite()`。
- [x] 实现 `traceDelete()`。
- [x] 实现 `tracePrune()`。
- [x] 实现 `traceDecodeFailed()`。
- [x] 实现 `traceVersionMismatch()`。
- [x] 接入 `AppLogger`。
- [x] 增加日志开关。
- [x] 增加 release 可用的关键 trace。
- [x] 给章节内容缓存接入 read trace。
- [x] 给章节内容缓存接入 write trace。
- [x] 给分页布局缓存接入 read trace。
- [x] 给分页布局缓存接入 write trace。
- [ ] 给封面图片缓存接入 stats trace。
- [x] 给 API 缓存接入 read trace。
- [x] 给 API 缓存接入 write trace。

验收:

- [ ] 打开章节能看到章节缓存 read 结果。
- [ ] 翻页分页能看到分页缓存 read 结果。
- [ ] 缓存损坏能看到 decodeFailed。
- [ ] 版本不一致能看到 versionMismatch。
- [ ] 清理缓存能看到 prune 结果。

---

## 5. Phase C3：统一缓存 Coordinator

**目标**: 业务层只面向 coordinator，不直接关心 Drift、文件、CacheManager 或内存 Map。

说明：本阶段先完成 coordinator 与 provider；具体 store 注册在 C4-C9 随真实 backend 接入逐项完成。

- [x] 新建 `lib/core/cache/app_cache_coordinator.dart`。
- [x] 注册章节内容 store。
- [x] 注册分页布局 store。
- [ ] 注册图片缓存 store。
- [x] 注册 API 响应 store。
- [x] 注册搜索命中 store。
- [x] 注册书源健康 store。
- [x] 注册主题预览 store。
- [x] 注册本地书索引 store。
- [x] 新建 `AppCacheCoordinator.read()`。
- [x] 新建 `AppCacheCoordinator.write()`。
- [x] 新建 `AppCacheCoordinator.delete()`。
- [x] 新建 `AppCacheCoordinator.clearScope()`。
- [x] 新建 `AppCacheCoordinator.stats()`。
- [x] 新建 `AppCacheCoordinator.prune()`。
- [x] 新建 `AppCacheCoordinator.clearUserScoped()`。
- [x] 新建 `AppCacheCoordinator.clearRebuildable()`。
- [x] 在 Riverpod provider 中暴露 coordinator。
- [x] 禁止新增业务代码直接实例化缓存 store。
- [x] 为 coordinator 增加 fake store 测试。

验收:

- [x] 新增缓存入口只需要注册 store。
- [x] 页面层不需要 import 具体缓存 backend。
- [x] 单测能替换 fake store。
- [x] 登出时能通过 coordinator 清理用户缓存。

---

## 6. Phase C4：章节内容缓存改造

**目标**: 章节内容缓存先接入统一协议，保留现有 Drift 表作为 backend。

- [x] 新建 `ReaderChapterContentCacheKeyBuilder`。
- [x] key builder 接收 `bookId`。
- [x] key builder 接收 `sourceId`。
- [x] key builder 接收 `chapterUrl`。
- [x] key builder 接收 `chapterIndex`。
- [x] key builder 输出 `AppCacheKey`。
- [x] 新建 `ReaderChapterContentCacheStore`。
- [x] store 读取现有 `chapter_caches` 表。
- [x] store 写入现有 `chapter_caches` 表。
- [x] store 更新 `lastAccessedAt` 等价字段。
- [x] store 映射 `createdAt`。
- [x] store 映射 `updatedAt`。
- [x] store 计算 `sizeBytes`。
- [x] store 处理空 content。
- [x] store 处理空 sourceId。
- [x] store 处理空 chapterUrl。
- [x] store 处理旧 key 格式。
- [x] store 输出 hit。
- [x] store 输出 miss。
- [x] store 输出 backendError。
- [x] `ReaderCachedChapterStore` 改为调用 coordinator。
- [x] `ReaderCachedChapterStore` 保留原公开方法。
- [x] `ReaderCachedChapterStore` 移除直接拼接 `sourceId|chapterUrl` 的逻辑。
- [x] `AppDatabase.getChapterCache` 标注为 backend 方法。
- [x] `AppDatabase.upsertChapterCache` 标注为 backend 方法。
- [x] 章节加载流程消费 `AppCacheReadResult`。
- [x] 章节加载流程处理 stale。
- [x] 章节加载流程处理 decodeFailed。
- [x] 章节加载流程处理 versionMismatch。
- [x] 添加章节缓存 hit 单测。
- [x] 添加章节缓存 miss 单测。
- [x] 添加章节缓存空 payload 单测。
- [x] 添加章节缓存旧 key 读取单测。
- [x] 添加章节缓存清理单测。

验收:

- [ ] 打开已缓存在线章节不发起重复内容请求。
- [x] 缓存损坏时能回退网络加载。
- [x] 缓存 miss 时日志能明确显示 key。
- [ ] 清理章节缓存后阅读器能正常重新加载。

---

## 7. Phase C5：分页布局缓存改造

**目标**: 分页缓存接入统一协议，先保留现有文件 backend，后续可无痛切换 Hive 或对象存储。

- [x] 新建 `ReaderPaginationLayoutCacheKeyBuilder`。
- [x] key builder 接收 `sourceId`。
- [x] key builder 接收 `chapterUrl`。
- [x] key builder 接收 `paginationSignature`。
- [x] key builder 接收 `viewportWidth`。
- [x] key builder 接收 `viewportHeight`。
- [x] key builder 接收 `fontFamily`。
- [x] key builder 接收 `fontSize`。
- [x] key builder 接收 `lineHeight`。
- [x] key builder 接收 `letterSpacing`。
- [x] key builder 接收 `paragraphSpacing`。
- [x] key builder 接收 `themeId`。
- [x] key builder 输出 `AppCacheKey`。
- [x] `ReaderPaginationCacheService` 实现 `AppCacheStore`。
- [x] store 包装 `ReaderPaginationCacheService` 文件读取。
- [x] store 包装 `ReaderPaginationCacheService` 文件写入。
- [x] store 包装 `ReaderPaginationCacheService` 内存读取。
- [x] store 包装 `ReaderPaginationCacheService` 内存写入。
- [x] store 输出 hit。
- [x] store 输出 miss。
- [x] store 输出 stale。
- [x] store 输出 decodeFailed。
- [x] store 输出 versionMismatch。
- [x] store 输出 backendError。
- [x] 给分页 payload 添加 `schemaVersion`。
- [x] 给分页 payload 添加 `layoutSignature`。
- [x] 给分页 payload 添加 `createdAt`。
- [x] 给分页 payload 添加 `pageCount`。
- [x] 给分页 payload 添加 `blockPageCount`。
- [ ] 修改字体变化失效 reason 为 `fontChanged`。
- [x] 修改布局变化失效 reason 为 `layoutChanged`。
- [ ] 修改宽高变化失效 reason 为 `viewportChanged`。
- [ ] 修改主题变化失效 reason 为 `themeChanged`。
- [x] `ReaderPaginationCacheService` 旧方法改为 backend 方法。
- [ ] 阅读器分页流程改为消费 coordinator。
- [x] 分页恢复流程处理 versionMismatch。
- [x] 分页恢复流程处理 decodeFailed。
- [x] 添加分页缓存 memory hit 单测。
- [x] 添加分页缓存 file hit 单测。
- [x] 添加分页缓存 version mismatch 单测。
- [x] 添加分页缓存 layoutChanged 单测。
- [x] 添加分页缓存 prune 单测。

验收:

- [x] 字号变化后旧分页缓存不会误用。
- [x] 横竖屏变化后旧分页缓存不会误用。
- [ ] 主题变化后旧分页缓存不会误用。
- [x] 分页缓存损坏不会导致空白页。
- [x] 分页缓存命中能恢复到正确页码。

说明：字体、宽高、边距、字距、行高、字体来源/权重等布局输入已经包含在 `paginationSignature` 中，旧分页缓存会因签名变化自然 miss。本轮先保留 `fontChanged`、`viewportChanged`、`themeChanged` 的细粒度 reason 待后续可观测性阶段补，不把现有稳定签名拆成多套失效逻辑。

---

## 8. Phase C6：图片缓存标准化

**目标**: 阅读器内所有网络图片都走统一图片组件，不再裸用 `Image.network`。

- [x] 新建 `ReaderCachedNetworkImage`。
- [x] `ReaderCachedNetworkImage` 支持 headers。
- [x] `ReaderCachedNetworkImage` 支持 cacheKey。
- [x] `ReaderCachedNetworkImage` 支持 memCacheWidth。
- [x] `ReaderCachedNetworkImage` 支持 memCacheHeight。
- [x] `ReaderCachedNetworkImage` 支持 placeholder。
- [x] `ReaderCachedNetworkImage` 支持 errorWidget。
- [x] `ReaderCachedNetworkImage` 支持 retry nonce。
- [x] `ReaderCachedNetworkImage` 接入 `CoverImageDiskCache` 或独立 reader image CacheManager。
- [x] 明确封面图片 cache scope。
- [x] 明确阅读正文图片 cache scope。
- [x] 明确漫画图片 cache scope。
- [ ] 明确主题背景图片 cache scope。
- [x] 替换 `ReaderImagePipeline` 中的 `Image.network`。
- [x] 替换 `ReaderTextPagedView` 中的 `Image.network`。
- [x] 替换 `ReaderTextScrollView` 中的 `Image.network`。
- [x] 替换 `ReaderMangaView` 中的 `Image.network`。
- [x] 替换 `reader_page_content_rendering.dart` 中的 `Image.network`。
- [x] 保留 `Image.file` 用于本地文件。
- [x] 保留 `Image.memory` 用于 data-uri。
- [ ] 给 data-uri 增加 max bytes 日志。
- [x] 给网络图片失败增加 cache trace。
- [x] 给网络图片成功增加可选 trace。
- [x] 给网络图片 placeholder 增加统一样式。
- [ ] 给漫画图片增加懒加载策略。
- [x] 给长图增加 decode 尺寸预算。
- [ ] 给图片缓存增加容量统计。
- [ ] 给图片缓存增加清理入口。
- [ ] 添加 reader image widget test。
- [ ] 添加 headers 透传测试。
- [ ] 添加 error fallback 测试。

验收:

- [x] 阅读器代码里不再出现裸 `Image.network`。
- [x] 封面列表继续使用磁盘缓存。
- [x] 正文插图重复打开能命中缓存。
- [ ] 漫画图片滚动不会一次性解码过多图片。
- [ ] 清理图片缓存后图片可重新加载。

---

## 9. Phase C7：API 缓存治理

**目标**: API 缓存必须默认实时，只有明确标记的接口允许缓存。

- [x] 盘点所有 `cachePolicy` 调用点。
- [x] 给每个缓存 API 标记业务 owner。
- [x] 给每个缓存 API 标记 TTL。
- [x] 给每个缓存 API 标记是否用户隔离。
- [ ] 给每个缓存 API 标记是否登录态敏感。
- [x] 给会员权益接口标记 realtime。
- [x] 给用户信息接口标记 realtime。
- [x] 给设备席位接口标记 realtime。
- [x] 给支付状态接口标记 realtime。
- [x] 给公告接口保留短 TTL。
- [ ] 给静态配置接口保留短 TTL。
- [ ] 给书籍详情接口评估短 TTL。
- [x] 给搜索接口默认 realtime。
- [x] `ApiCacheStore` 接入 `AppCacheStore` 协议。
- [x] `ApiCacheStore` 接入统一 trace。
- [x] `ApiCacheStore` key 改用 `AppCacheKey`。
- [x] `ApiClient.clearCache()` 改为调用 coordinator。
- [x] 登出流程调用 `clearUserScoped()`。
- [x] token 变化流程清理用户 API 缓存。
- [x] 添加实时接口不缓存测试。
- [x] 添加短 TTL 命中测试。
- [x] 添加 TTL 过期测试。
- [x] 添加用户隔离测试。

验收:

- [x] 会员到期不会因为 API 缓存继续显示高级能力。
- [x] 登录切换用户不会读到上个用户缓存。
- [x] 支付状态不会被本地缓存误判。
- [x] 允许缓存的接口能看到明确 TTL。

说明：默认 `ApiClient` 已改为共享 `ApiClient.defaultCacheStore`，并注册进全局 `AppCacheCoordinator`。账号退出、过期和切换会触发 userScoped cache 清理；显式注入自定义 `ApiCacheStore` 的测试/特殊服务仍保持隔离。

---

## 10. Phase C8：搜索与书源健康缓存治理

**目标**: 搜索命中、书源健康属于业务缓存，必须能按用户、源、关键字正确隔离。

- [x] `SearchHitCacheService` 接入 coordinator。
- [x] 搜索命中 key 增加用户维度。
- [x] 搜索命中 key 增加 titleNorm。
- [x] 搜索命中 key 增加 authorNorm。
- [x] 搜索命中 key 增加 sourceId。
- [x] 搜索命中缓存声明 TTL。
- [x] 搜索命中缓存声明 maxEntries。
- [x] 搜索命中缓存声明 maxBytes。
- [x] 搜索命中缓存接入 trace。
- [x] 搜索命中缓存接入 stats。
- [x] 搜索命中缓存接入 prune。
- [x] `SourceHealthPersistenceService` 接入 coordinator。
- [x] 书源健康 key 增加 sourceId。
- [x] 书源健康 key 增加 checkMode。
- [x] 书源健康缓存声明 TTL。
- [x] 书源健康缓存声明 owner。
- [x] 书源健康缓存接入 trace。
- [x] 书源健康缓存接入 stats。
- [x] 书源健康缓存接入 prune。
- [x] 添加搜索命中用户隔离测试。
- [x] 添加搜索命中 TTL 测试。
- [x] 添加书源健康 TTL 测试。

验收:

- [ ] 搜索范围页面不会只看到错误缓存结果。
- [ ] 检测失败源能被展示为失败状态。
- [ ] 检测成功源不会被旧失败缓存覆盖。
- [x] 切换用户不会复用旧搜索命中。

---

## 11. Phase C9：主题、字体、本地书缓存治理

**目标**: 资源类缓存和用户资产划清边界。

- [x] 高级主题预览缓存接入 coordinator。
- [x] 高级主题背景 provider 缓存接入统一 stats。
- [x] 高级主题资源缓存声明 owner。
- [x] 高级主题资源缓存声明是否可删除。
- [x] 高级主题资源缓存声明是否可重建。
- [x] 字体注册缓存接入 coordinator。
- [x] 字体注册缓存声明 owner。
- [x] 字体注册缓存声明 version。
- [x] 字体注册缓存声明失效条件。
- [x] 阅读视觉覆盖缓存接入 coordinator。
- [x] 阅读视觉覆盖缓存声明用户维度。
- [ ] 阅读视觉覆盖缓存声明主题维度。
- [x] 本地书索引缓存接入 coordinator。
- [x] 本地书索引缓存声明 fileSize 维度。
- [x] 本地书索引缓存声明 modifiedAt 维度。
- [ ] 本地书索引缓存声明 parserVersion。
- [x] 本地书索引缓存声明是否可重建。
- [x] 本地书索引缓存损坏时触发重建。
- [x] 添加主题预览缓存清理测试。
- [ ] 添加字体缓存版本变化测试。
- [ ] 添加本地书索引版本变化测试。
- [x] 阅读偏好缓存声明不可重建。
- [x] 阅读偏好缓存声明不可作为普通缓存删除。
- [x] 可重建缓存清理不会删除 `ManagedAssetStore` 高级主题资源。

验收:

- [x] 高级主题资源不会被误当作临时缓存删除。
- [x] 字体变化后分页缓存会正确失效。
- [x] 本地书源文件变化后索引会重建。
- [x] 本地书索引损坏不会卡死详情页。

说明：字体与视觉覆盖已归入 `readerPreference` scope，策略保持不可普通删除；字体文件仍属于 `ManagedAssetStore` 用户资产。`parserVersion` 和视觉覆盖按主题维度需要本地书/偏好存储 schema 升级，本轮未强行补字段，避免上线前制造隐性迁移风险。

---

## 12. Phase C10：缓存治理页面与启动任务

**目标**: 用户能看见缓存占用，系统能稳定清理缓存，但启动不能被缓存扫描拖慢。

- [x] `AppCacheGovernanceService` 改为读取 coordinator stats。
- [x] 保留章节缓存统计。
- [x] 保留分页缓存统计。
- [x] 保留封面缓存统计。
- [ ] 增加阅读正文图片缓存统计。
- [x] 增加 API 缓存统计。
- [x] 增加搜索命中缓存统计。
- [x] 增加书源健康缓存统计。
- [x] 增加主题预览缓存统计。
- [x] 增加本地书索引缓存统计。
- [x] 增加按 scope 清理入口。
- [x] 增加清理前二次确认文案。
- [x] 增加清理后 toast。
- [x] 增加清理失败局部提示。
- [ ] 增加缓存损坏修复入口。
- [x] 启动期只执行轻量预算检查。
- [x] 启动期不扫描大图片目录。
- [x] 启动期不扫描分页布局全部文件。
- [x] 缓存管理页打开后再加载完整 stats。
- [x] stats 加载过程显示骨架屏。
- [x] stats 加载失败显示可重试。
- [x] 添加缓存治理 service 单测。
- [ ] 添加缓存管理页 widget test。

验收:

- [ ] 冷启动不因缓存统计明显变慢。
- [x] 缓存页能看到已接入治理的各类缓存大小。
- [x] 用户能单独清理章节缓存。
- [x] 用户能单独清理图片缓存。
- [x] 用户能单独清理分页缓存。

---

## 13. Phase C11：后端替换试点

**目标**: 在协议稳定后评估 Hive，不让存储选型绑死业务代码。

- [ ] 为章节内容缓存实现 Hive 试点 backend。
- [ ] 为分页布局缓存实现 Hive 试点 backend。
- [ ] 为 Hive backend 添加开关。
- [ ] 为 Hive backend 添加迁移读 fallback。
- [ ] 为 Hive backend 添加写入失败 fallback。
- [ ] 对比 Drift 章节缓存读取耗时。
- [ ] 对比 Hive 章节缓存读取耗时。
- [ ] 对比文件分页缓存读取耗时。
- [ ] 对比 Hive 分页缓存读取耗时。
- [ ] 对比章节缓存写入耗时。
- [ ] 对比分页缓存写入耗时。
- [ ] 对比缓存目录占用。
- [ ] 对比内存峰值。
- [x] 输出 backend 选择结论。
- [x] 决定章节缓存是否切 Hive。
- [x] 决定分页缓存是否切 Hive。
- [x] 决定是否保留 Drift 章节表。
- [x] 决定是否迁移旧章节缓存。
- [x] 决定是否删除旧分页文件。

验收:

- [ ] 业务代码不因 backend 切换而改动。
- [ ] backend 切换失败可回滚。
- [ ] 性能数据能支持最终选择。
- [x] 没有产生双写长期维护负担。

结论：本轮不引入 Hive，不做章节/分页双写。理由是章节内容缓存已经稳定落在 Drift `chapter_caches`，分页布局缓存已经稳定落在内存 LRU + 文件 backend，二者都已接入 `AppCacheStore` 协议、trace 与治理入口；当前上线目标是统一入口和清理旧绕过点，不值得为了试点引入新的持久化依赖、迁移脚本和回滚路径。后续如需重新评估 Hive，应先建立独立 benchmark 分支，完成读写耗时、目录占用、内存峰值和迁移回滚数据后再决定。

---

## 14. Phase C12：旧入口清理

**目标**: 避免“新架构上线，旧架构还在被调用”。

- [x] 搜索直接调用 `AppDatabase.getChapterCache` 的业务入口。
- [x] 搜索直接调用 `AppDatabase.upsertChapterCache` 的业务入口。
- [x] 搜索直接调用 `ReaderPaginationCacheService` 的业务入口。
- [x] 搜索直接调用 `CoverImageDiskCache` 的业务入口。
- [x] 搜索直接调用 `ApiCacheStore` 的业务入口。
- [x] 搜索直接调用 `SearchHitCacheService` 的业务入口。
- [x] 搜索阅读器内裸 `Image.network`。
- [ ] 删除不再使用的缓存 helper。
- [ ] 删除不再使用的缓存 key 拼接方法。
- [ ] 删除不再使用的缓存 prune 方法。
- [ ] 删除不再使用的缓存 stats 方法。
- [ ] 删除不再使用的缓存 mock。
- [x] 更新导入路径。
- [x] 更新测试 fake。
- [x] 更新缓存治理文档。
- [ ] 更新架构硬化计划 H1 状态。

验收:

- [x] `rg "Image.network" lib/features/reader` 没有结果。
- [x] `rg "sourceId\\|chapterUrl" lib/features/reader` 没有缓存 key 拼接结果。
- [x] `flutter analyze` 通过。
- [x] reader 定向测试通过。
- [x] 缓存相关单测通过。

说明：`AppDatabase.getChapterCache`、`AppDatabase.upsertChapterCache`、`ReaderPaginationCacheService`、`ApiCacheStore` 等 backend 方法仍被统一 store、provider 或测试使用，属于保留后端，不属于旧业务入口。`SearchReportAssembler` 已改为由 `ServerOnlineSearchService/SearchService` 注入 app 级 `SearchHitCacheService`，不再自行 new 默认实例。

---

## 15. 最小上线验收清单

- [ ] 首次打开在线章节正常加载。
- [ ] 二次打开在线章节命中章节缓存。
- [ ] 改字号后重新分页。
- [ ] 改行距后重新分页。
- [ ] 横竖屏切换后重新分页。
- [ ] 切换主题后重新分页。
- [ ] 正文插图能显示。
- [ ] 正文插图失败能重试。
- [ ] 漫画章节能显示。
- [ ] 漫画章节滑动不卡死。
- [ ] 清理章节缓存后能重新加载。
- [ ] 清理分页缓存后能重新分页。
- [ ] 清理图片缓存后图片能重新下载。
- [ ] 登录切换用户后 API 缓存不串号。
- [ ] 会员权益接口不使用旧缓存。
- [ ] 搜索命中缓存不串号。
- [ ] 书源健康状态不被旧缓存覆盖。
- [ ] 本地书索引损坏能重建。
- [ ] 高级主题资源不被误删。
- [ ] 冷启动不扫描大缓存目录。

---

## 16. 推荐执行顺序

- [x] C0 先执行。
- [x] C1 紧跟执行。
- [x] C2 紧跟执行。
- [x] C3 紧跟执行。
- [x] C4 与 C5 作为第一批核心落地。
- [x] C6 作为第一批核心落地。
- [x] C7 在 C3 后执行。
- [x] C8 在 C7 后执行。
- [x] C9 在 C6 后执行。
- [x] C10 在 C4、C5、C6 完成后执行。
- [x] C11 在 C4、C5 稳定后执行。
- [x] C12 最后执行。

---

## 17. 不建议本轮做的事

- [x] 不把所有缓存立即迁到 Hive。
- [x] 不把用户资产迁入 cache directory。
- [x] 不在启动期做完整缓存体检。
- [x] 不长期保留双写。
- [x] 不把缓存治理做成页面层逻辑。
- [x] 不用缓存绕过权限、会员、额度实时校验。
- [x] 不为追求行数下降删除必要 trace。
- [x] 不把缓存异常吞掉后只显示空白页。
