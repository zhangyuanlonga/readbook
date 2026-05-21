# 本地图文存储与阅读器改造执行计划

更新时间：2026-05-21

状态：执行中

适用范围：

- 本地图书导入与存储
- 本地图书索引与正文解析
- 阅读器分页、正文加载、缓存落位
- 存储治理草案在阅读器链路的补齐

关联文档：

- [storage_governance_spec_2026-05-21.md](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/docs/storage_governance_spec_2026-05-21.md)
- [sto.md](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/docs/sto.md)
- [storage_inventory_2026-05-20.md](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/docs/storage_inventory_2026-05-20.md)
- [storage_upgrade_validation_2026-05-21.md](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/docs/storage_upgrade_validation_2026-05-21.md)

## 1. 使用说明

- 所有任务默认以 `[ ]` 表示未完成。
- 单项任务完成后，改成 `[x]`。
- 只有当该阶段的任务、验证、回滚预案都满足后，才能勾选该阶段的“阶段完成”项。
- 如果代码现状与本文冲突，以代码真实现状为准，并同步更新本文。

## 2. 本次执行口径

- [x] 执行口径已确认

本次计划默认采用以下口径：

- EPUB `*_assets/` 定义为“托管派生资产”，继续保留在 `ApplicationSupport`，不参与常规缓存清理
- PDF 改为“索引阶段轻量化 + 正文按需提取 + 首次提取后缓存”
- 解析执行策略优先下沉到各 parser 内部，不强制要求 `LocalBookIndexService` 统一代理所有后台化
- 分页缓存属于“可重建缓存”，应从当前 `ApplicationSupport` 口径迁到缓存目录口径
- `local_chapters` 仅保留索引元数据，不再承担可重建正文缓存职责

## 3. 分阶段总览

| 阶段 | 名称 | 目标 | 优先级 |
|---|---|---|---|
| Phase 0 | 方案冻结 | 锁定边界、表结构方向和回滚策略 | P0 |
| Phase 1 | 解析后台化 | 降低 EPUB/PDF 导入与首开阻塞 | P0 |
| Phase 2 | 章节存储拆分 | 拆开索引表和正文缓存表 | P0 |
| Phase 3 | PDF 策略重构 | 去掉全书全文落库 | P0 |
| Phase 4 | 缓存落位收口 | 修正分页缓存与 TOC 快照落位 | P1 |
| Phase 5 | 阅读器性能收敛 | 优化分页、预加载、主线程负担 | P1 |
| Phase 6 | 文档与回归 | 补规范、补验证、形成基线 | P0 |

## 4. Phase 0：方案冻结

- [x] Phase 0 阶段完成

### 4.1 任务

- [x] 确认 EPUB `*_assets/` 的最终身份为“托管派生资产”
- [x] 确认 PDF 最终采用“按需提取 + 缓存”而不是“全书全文预落库”
- [x] 确认 `local_chapters` 只保留索引职责
- [x] 确认新增正文缓存表的命名、字段和生命周期
- [x] 确认分页缓存迁移后的目录口径
- [x] 确认 `ReaderPreferencesService` 中 TOC 快照的迁移目标
- [x] 确认各阶段上线顺序与可独立回滚边界

### 4.2 涉及文件

- `lib/data/datasources/local/app_database.dart`
- `lib/features/reader/application/local/local_book_index_service.dart`
- `lib/features/reader/application/local/local_chapter_content_service.dart`
- `lib/features/reader/application/local/epub_local_book_parser.dart`
- `lib/features/reader/application/local/pdf_local_book_parser.dart`
- `lib/features/reader/application/reader_pagination_cache_service.dart`
- `lib/features/reader/application/reader_preferences_service.dart`

### 4.3 验收标准

- [x] 关键表结构与缓存边界已定版
- [x] 每个阶段都具备独立上线和回滚边界
- [x] 无需要先拍板但未决的架构问题

## 5. Phase 1：解析后台化

- [ ] Phase 1 阶段完成

### 5.1 任务

- [x] 为 EPUB 解析新增后台执行入口
- [x] 将 EPUB zip 解压、目录提取、HTML 解析移出主线程
- [x] 校验 EPUB parser 需要传递到后台的数据结构是否可序列化
- [ ] 为 PDF 解析新增执行策略抽象
- [x] 验证当前 PDF 提取库是否支持后台 isolate 执行
- [ ] 如果 PDF 提取库不支持 isolate，改为“小步异步 + 按页按需提取”降阻塞方案
- [ ] 为 `LocalBookIndexService` 增加解析耗时埋点与阶段日志
- [ ] 为导入链路增加“后台索引中”可感知状态

### 5.2 涉及文件

- `lib/features/reader/application/local/local_book_index_service.dart`
- `lib/features/reader/application/local/epub_local_book_parser.dart`
- `lib/features/reader/application/local/pdf_local_book_parser.dart`
- `lib/features/bookshelf/application/local_book_import_service.dart`

### 5.3 验收标准

- [ ] 大 EPUB 导入时主线程阻塞明显下降
- [ ] PDF 导入或首开不再出现长时间卡死 UI
- [ ] 解析失败时错误信息和回退链路保持可用

### 5.4 回滚点

- [ ] EPUB 后台化可以独立关闭并恢复旧解析路径
- [ ] PDF 新执行策略可以独立关闭并恢复旧路径

### 5.5 当前执行备注

- 已确认当前 `pdf_text_extract` 为 `MethodChannel('pdf_text')` 插件实现，不适合直接搬入 Dart isolate
- 因此 `Phase 1` 对 PDF 的执行口径调整为：先完成“策略抽象 + 按页按需提取设计”，不直接强推 isolate 化

## 6. Phase 2：章节存储拆分

- [ ] Phase 2 阶段完成

### 6.1 任务

- [x] 设计 `local_chapter_bodies` 或等价表结构
- [x] 为正文缓存表定义主键、命中键、更新时间和可重建标记
- [x] 数据库 schema 升级新增正文缓存表
- [ ] 修改 `LocalChapterContentService`：优先读取正文缓存表
- [ ] 修改 `LocalChapterContentService`：缓存未命中时按格式解析正文并写入正文缓存表
- [x] 修改 `LocalBookIndexService`：索引阶段不再把可重建正文塞入 `local_chapters`
- [x] 为 `local_chapters.content` 建立废弃策略
- [x] 设计老数据迁移策略：保留、搬迁或懒清理
- [ ] 为正文缓存表增加清理接口和预算统计接口

### 6.2 涉及文件

- `lib/data/datasources/local/app_database.dart`
- `lib/data/repositories/local_book_repository_impl.dart`
- `lib/domain/repositories/local_book_repository.dart`
- `lib/features/reader/application/local/local_book_index_service.dart`
- `lib/features/reader/application/local/local_chapter_content_service.dart`

### 6.3 验收标准

- [ ] `local_chapters` 只保留索引元数据、偏移、`sourceRef`、结构化轻量字段
- [ ] 可重建正文缓存已从索引表拆出
- [ ] 升级后旧数据不丢失，阅读功能不回退

### 6.4 回滚点

- [ ] 可通过双读方式回退到旧表读取
- [ ] schema 升级后仍保留兼容窗口

## 7. Phase 3：PDF 策略重构

- [ ] Phase 3 阶段完成

### 7.1 任务

- [ ] 将 PDF 索引阶段改为“页数、元数据、轻量目录信息”优先
- [ ] 取消索引阶段逐页全文抽取并落库
- [ ] 为 PDF 阅读正文建立按页提取入口
- [ ] 为 PDF 阅读正文建立首次提取后的缓存写入
- [ ] 为 PDF 章节模型定义“页 -> 章节”映射策略
- [ ] 校验书签、进度、跳转在新 PDF 模型下仍然可用
- [ ] 校验搜索能力在新策略下的处理方式
- [ ] 明确扫描版/无文本层 PDF 的降级提示

### 7.2 涉及文件

- `lib/features/reader/application/local/pdf_local_book_parser.dart`
- `lib/features/reader/application/local/local_chapter_content_service.dart`
- `lib/domain/entities/local_chapter.dart`
- `lib/features/reader/presentation/reader_page.dart`

### 7.3 验收标准

- [ ] 1000+ 页 PDF 不再在导入阶段全量落正文
- [ ] 数据库体积增长明显下降
- [ ] 首次打开单页允许稍慢，但重复打开命中缓存后明显加快

### 7.4 回滚点

- [ ] PDF 新正文加载链可按开关切回旧实现

## 8. Phase 4：缓存落位收口

- [ ] Phase 4 阶段完成

### 8.1 任务

- [ ] 将分页缓存目录从 `ApplicationSupport` 迁到缓存目录口径
- [ ] 为分页缓存增加旧目录兼容读取与迁移清理策略
- [ ] 为分页缓存补预算、过期、清理入口联动
- [ ] 新增 `toc_snapshots` 数据库表或等价结构
- [ ] 将 TOC 快照从 `SharedPreferences` 迁到数据库
- [ ] 迁移成功后清理旧 `reader.tocSnapshot.*` key
- [ ] 清理阅读器设置中的历史大值路径，禁止 base64 大字符串继续留存
- [ ] 为视觉覆盖和背景图确认“只存路径引用，不存大值”

### 8.2 涉及文件

- `lib/features/reader/application/reader_pagination_cache_service.dart`
- `lib/features/reader/application/reader_preferences_service.dart`
- `lib/features/reader/application/reader_visual_overrides_service.dart`
- `lib/data/datasources/local/app_database.dart`
- `lib/core/cache/app_cache_governance_service.dart`

### 8.3 验收标准

- [ ] 分页缓存已归入缓存目录治理口径
- [ ] TOC 快照不再驻留 `SharedPreferences`
- [ ] Reader 相关 SP 不再承载历史大值

### 8.4 回滚点

- [ ] 新旧分页缓存目录具备兼容窗口
- [ ] TOC 快照保留一次性迁移双读窗口

## 9. Phase 5：阅读器性能收敛

- [ ] Phase 5 阶段完成

### 9.1 任务

- [ ] 评估 `ReaderPaginationEngine` 的热点章节耗时
- [ ] 为超长章节增加更早的切片或分页前分块策略
- [ ] 优化分页阶段“首屏页优先、邻近页延后”的执行顺序
- [ ] 校验分页取消 token 在快速翻页场景下是否及时生效
- [ ] 校验预加载任务在快速翻页时是否存在无效工作
- [ ] 校验 EPUB 图文混排章节的图片 decode budget 是否合理
- [ ] 校验漫画模式 `cacheExtent` 与内存占用平衡
- [ ] 为长时间阅读场景补内存观测点

### 9.2 涉及文件

- `lib/features/reader/application/reader_pagination_engine.dart`
- `lib/features/reader/application/reader_streaming_pagination_controller.dart`
- `lib/features/reader/application/reader_preload_controller.dart`
- `lib/features/reader/presentation/reader_page.dart`
- `lib/features/reader/presentation/reader_text_paged_view.dart`
- `lib/features/reader/presentation/reader_manga_view.dart`

### 9.3 验收标准

- [ ] 首屏可读时间缩短
- [ ] 快速翻页时无明显“还在算旧页”的体感卡顿
- [ ] 长时间阅读无明显内存持续爬升

## 10. Phase 6：文档与回归

- [ ] Phase 6 阶段完成

### 10.1 任务

- [ ] 更新 `storage_governance_spec_2026-05-21.md`
- [ ] 在规范中补充“索引表与正文缓存表分离”原则
- [ ] 在规范中补充“解析线程隔离”原则
- [ ] 在规范中补充“PDF 按需提取”原则
- [ ] 更新 `sto.md`，登记本次阶段性落地记录
- [ ] 补覆盖安装升级回归用例
- [ ] 补本地图书导入与阅读性能基线记录
- [ ] 记录数据库体积、分页缓存体积、首开耗时、连续翻页耗时
- [ ] 形成最终验收结论

### 10.2 验收标准

- [ ] 规范、执行稿、验证记录三者一致
- [ ] 覆盖安装与老用户升级场景有可复跑记录
- [ ] 后续同类问题有明确守卫与基线

## 11. 验证清单

- [ ] TXT 小文件导入、索引、阅读正常
- [ ] TXT 大文件导入、流式索引、按偏移读取正常
- [ ] EPUB 普通图文书导入、封面、正文、图片渲染正常
- [ ] EPUB 重新打开命中正文缓存正常
- [ ] PDF 1000+ 页导入不再长时间阻塞
- [ ] PDF 首次打开单页可读、重复打开更快
- [ ] 阅读进度保存与恢复正常
- [ ] 书签、笔记、高亮在 TXT/EPUB/PDF 下行为正确
- [ ] 快速翻页、连续翻页、自动阅读无明显回退
- [ ] 删除本地图书后原始文件、派生资源、索引、正文缓存能正确清理
- [ ] 清理缓存后不会误删本地图书原件与 EPUB 派生资产

## 12. 风险清单

- [ ] 已评估 PDF 提取库的后台执行限制
- [ ] 已评估数据库 schema 升级对旧用户的影响
- [ ] 已评估 EPUB 资源目录迁移或保留的清理边界
- [ ] 已评估正文缓存拆表后对书签/进度的影响
- [ ] 已评估分页缓存目录迁移对旧缓存命中的影响

## 13. 完成定义

- [ ] 全部阶段完成

当以下条件全部满足，才可视为本计划完成：

- [ ] P0 阶段已全部完成
- [ ] 本地图书三类主格式 `TXT/EPUB/PDF` 已完成新链路验证
- [ ] 存储边界与阅读器缓存边界已收口
- [ ] 覆盖安装升级回归已通过
- [ ] 规范文档已补齐并与代码现状一致
