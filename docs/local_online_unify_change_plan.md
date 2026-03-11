# 本地图文导入与在线书源统一改动清单（可勾选）

## 目标
- [ ] 书架入口与阅读入口统一，用户感知一致。
- [ ] 本地导入与在线书源复用同一套阅读页、阅读进度与设置。
- [ ] 保持现有书源规则引擎不变，降低改造风险。

## 非目标
- [ ] 不改造书源规则引擎语法或兼容性。
- [ ] 不在本阶段引入复杂的漫画/图像解析能力。

## 统一方案（落地结构）

### 1) Provider 抽象层
- [x] 新增 `ContentProvider` 接口。
- [x] 新增 `ContentProviderRegistry`（按 `BookshelfBook` 或 `sourceId` 选 Provider）。
- [x] 新增 `ContentCapabilities` 能力开关：
- [x] `canSwitchSource`
- [x] `canCacheChapter`
- [x] `canRefreshToc`
- [x] `canSearchInSource`
- [x] `canReindexLocal`

### 2) Provider 实现
- [x] 新增 `SourceContentProvider`：内部使用 `BookDetailService` 与 `ChapterContentService`。
- [x] 新增 `LocalContentProvider`：
- [x] `loadDetail` 使用 `LocalBookDetailService` 并映射为 `BookDetailLoadResult`。
- [x] `loadChapterContent` 读取本地章节内容并返回 `ChapterContentResult`。
- [x] 如需要，新增 `LocalChapterContentService` 处理 `local://chapter/{id}` 解析。

## 详细改动清单

### 3) Reader 入口统一
- [x] `ReaderPage` 改用 `ContentProvider` 获取详情与正文。
- [x] 兼容缺省参数：优先从 `ReadingProgress` 补齐 `sourceId/detailUrl/chapterId/chapterUrl`。
- [x] 本地书继续使用 `local://book/{bookId}` 与 `local://chapter/{chapterId}`。
- [x] 按能力开关控制以下功能：
- [x] 换源（本地关闭）
- [x] 章节缓存（本地关闭或短路）
- [x] 目录刷新（本地用“重新索引”替代）

### 4) Detail 入口统一
- [x] `BookDetailPage` 支持 Provider 渲染本地详情数据。
- [x] “重新索引”入口移动到统一详情页，并由能力开关控制显示。
- [x] 换源能力仅对在线 Provider 可见。

### 5) 书架入口统一
- [x] 书架打开逻辑统一走 `/reader` 路由（本地不再进 `LocalReaderPage`）。
- [x] `continueReading` 分支统一走 `ReaderPage`。
- [x] 详情打开统一走 `BookDetailPage`（本地不再进 `LocalBookDetailPage`）。

### 6) 路由兼容
- [x] 保留 `/local/book/:bookId` 与 `/local/reader/:bookId/:chapterId` 路由。
- [x] 在路由 builder 内重定向到统一 `/book` / `/reader`。
- [x] Phase 3 再删除旧页面与路由。

### 7) 数据与进度一致性
- [ ] 本地阅读进度保持 scheme：
- [ ] `detailUrl = local://book/{bookId}`
- [ ] `chapterUrl = local://chapter/{chapterId}`
- [ ] 本地 Provider 保证上述 scheme 与现有进度一致。

### 8) 错误与提示统一
- [x] 本地 Provider 将索引失败、文件缺失、章节为空等错误映射成可读提示。
- [x] `ReaderPage` 的错误文案区分“网络错误”与“本地解析错误”。

### 9) 性能与内存
- [x] 评估 `LocalBookRepository.getChapters` 全量正文加载的内存风险。
- [x] 可选新增“目录-only”查询或延迟加载正文。

### 10) 无用代码清理
- [x] 标记并移除不再使用的页面与路由：`LocalReaderPage`、`LocalBookDetailPage`。
- [x] 删除不再使用的服务与依赖分支（例如书架内对本地/在线的旧分流逻辑）。
- [x] 删除无用的 import、路由常量、旧功能入口。

## 关键文件触点
- [x] `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/features/bookshelf/presentation/bookshelf_page.dart`
- [x] `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/features/book/presentation/book_detail_page.dart`
- [x] `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/features/reader/presentation/reader_page.dart`
- [x] `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/features/book/application/book_detail_service.dart`
- [x] `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/features/reader/application/chapter_content_service.dart`
- [x] `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/features/book/application/local_book_detail_service.dart`
- [x] `/Users/zhangyuanlong/storage/FlutterProject/flutter_appread/lib/app/router.dart`

## 分阶段实施建议

### Phase 1: Provider 抽象 + 适配
- [x] 新增 `ContentProvider`/`ContentProviderRegistry`。
- [x] 实现 `SourceContentProvider`（封装 `BookDetailService` 与 `ChapterContentService`）。
- [x] 实现 `LocalContentProvider`（封装本地详情与章节内容读取）。

### Phase 2: 入口统一
- [x] `ReaderPage` 改用 Provider 获取详情与正文。
- [x] `BookDetailPage` 改用 Provider 获取详情与目录。
- [x] 书架入口改为统一路由。

### Phase 3: 清理与兼容
- [x] 路由保留但改为重定向。
- [x] 删除旧逻辑分支与 UI 开关。
- [x] 评估并移除 `LocalReaderPage` 与 `LocalBookDetailPage`。

## 测试清单
- [ ] 本地 TXT/EPUB 导入后可进入统一阅读页。
- [ ] 本地阅读进度保存与恢复正常。
- [ ] 在线书源加载目录与正文正常。
- [ ] 换源、缓存按钮对本地书隐藏或禁用。
- [ ] 本地书“重新索引”入口可用并可刷新目录。
- [ ] 旧路由 `/local/*` 仍能打开并正确跳转到统一页面。
- [ ] 异常路径：本地文件缺失、解析失败、空章节提示正确。

## 兼容性与迁移注意事项
- [ ] 不破坏 `ReadingProgress` 字段要求。
- [ ] 不改动规则引擎与书源格式。
- [ ] 保持本地 `sourceId` 常量不变：`__local_book__`。
- [ ] 本地 `detailUrl` 与 `chapterUrl` scheme 不变。
