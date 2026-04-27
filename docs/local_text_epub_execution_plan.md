# 本地 TXT / EPUB 整改执行清单

更新时间：2026-04-27  
用途：作为当前本地 `txt / epub` 阅读链路整改的唯一执行清单，指导后续分阶段落地、验收与文档维护。

---

## 1. 约束基线

本清单执行时必须遵守：

- [development_architecture_guardrails.md](./development_architecture_guardrails.md)
- [cross_platform_boundary_refactor_plan.md](./cross_platform_boundary_refactor_plan.md)
- [product_features_guide.md](./product_features_guide.md)
- [reader_multimodal_plan.md](./reader_multimodal_plan.md)

本次整改的硬约束：

- [x] 不新增第二套阅读器页面，本地/在线继续共用 `ReaderShell`
- [x] 来源差异继续收口在 `ContentProvider` 和本地解析链路
- [x] 页面层不直接依赖 `AppDatabase`、`RepositoryImpl`、`MethodChannel`
- [x] 业务规则继续收口在 Flutter / Dart，不把 TXT 分章或正文解码下沉回原生
- [x] TXT 目录规则继续保持“无用户配置入口、统一内置自动分章”的产品口径

---

## 2. 总体目标

- [ ] 修复 TXT 导入后不可逆乱码问题
- [ ] 固定 TXT 导入、索引、正文读取的单一编码事实来源
- [ ] 提升 EPUB 目录粒度，补齐 `fragment` 级章节切分
- [ ] 保持本地/在线共用同一套正文展示、分页、进度恢复链路
- [ ] 补齐自动化测试与执行文档回填机制

---

## 3. 阶段状态总览

- [x] 阶段 0：建立改造基线
- [x] 阶段 1：重做 TXT 导入与编码冻结
- [x] 阶段 2：统一 TXT 索引与正文读取
- [x] 阶段 3：收紧本地导入与索引时序
- [ ] 阶段 4：补齐 EPUB `fragment` 级目录解析
- [ ] 阶段 5：依赖注入收口与残留清理
- [ ] 阶段 6：测试、回归与文档验收

规则：

- [x] 未完成上一阶段，不进入下一阶段
- [x] 每完成一个勾选项，必须同步更新本文件
- [x] 每完成一个阶段，必须补“阶段完成记录”
- [ ] 若实施过程中调整范围或顺序，先改文档，再改代码

---

## 4. 阶段 0：建立改造基线

目标：

- 冻结本轮改造边界，只改本地内容准备层，不重做阅读器壳层

执行清单：

- [x] 明确本轮目标范围仅包含 `txt / epub` 本地阅读
- [x] 明确不改 `ReaderShell`、分页展示模型、在线书正文链路
- [x] 盘点当前 TXT 导入、索引、正文读取的关键入口文件
- [x] 盘点当前 EPUB 目录解析、正文提取、图片资源处理入口文件
- [x] 记录本轮改造影响的 provider / service / parser 清单
- [x] 将本文件作为后续执行唯一勾选清单

阶段完成定义：

- [x] 已确认边界，不再争论“是否重做阅读器正文展示层”
- [x] 已确认后续改动主落点为 `lib/features/reader/application/local/`

---

## 5. 阶段 1：重做 TXT 导入与编码冻结

目标：

- 杜绝“导入时错误转码后不可逆乱码”
- 建立同一本 TXT 的单一编码事实来源

执行清单：

- [x] 梳理 `LocalBookStorageService.copyIntoStorage()` 当前 TXT 转码路径
- [x] 调整 TXT 主路径为“默认保留原始字节，不在导入阶段重写 UTF-8”
- [x] 保留可恢复的源文件路径 / 存储路径规则，不把恢复逻辑散落到页面
- [x] 给 `LocalBook` 明确记录冻结后的 `charset` 语义
- [x] 约束 `LocalTextEncodingDetector`：Dart 常见编码优先，插件仅 fallback
- [x] 去掉平台插件结果在主路径里的过强优先权，避免不同平台选到不同编码
- [x] 明确“修改编码”后的重新索引来源必须回到原始字节文件

阶段完成定义：

- [x] 新导入 TXT 不再因为首次误判而永久写坏内部存储
- [x] 同一本 TXT 的编码不再在导入、预览、索引、阅读阶段反复漂移

---

## 6. 阶段 2：统一 TXT 索引与正文读取

目标：

- 分章、偏移、正文读取全部依赖同一编码口径

执行清单：

- [x] 梳理 `TxtLocalBookParser` 当前全量解析与流式解析两条链路
- [x] 统一 `TxtLocalBookParser` 的编码输入来源，禁止索引过程中二次漂移
- [x] 统一章节偏移计算规则，确保 offset 与冻结编码一致
- [x] 校正 `LocalChapterContentService` 的 offset 回读逻辑，确保按冻结编码读取
- [x] 保留 TXT 自动分章能力，但不恢复用户可编辑目录规则入口
- [x] 对长章节拆分继续使用统一业务规则，不引入平台分叉
- [x] 清理旧 fallback 路径里与当前主路径冲突的解码逻辑

阶段完成定义：

- [x] TXT 目录和正文不再出现“目录可用但正文乱码”或“重索引后反而变坏”
- [x] TXT 改编码后重新索引可以稳定修复可恢复文件

---

## 7. 阶段 3：收紧本地导入与索引时序

目标：

- 本地导入完成后的最小成功定义为“目录已可用”

执行清单：

- [x] 梳理 `LocalBookImportService` 当前导入完成、后台索引、UI 提示的时序
- [x] 明确哪些导入入口必须 `waitForIndexing: true`
- [x] 明确本地图书“可进入阅读”的状态定义
- [x] 让 `LocalBookIndexService` 成为唯一权威索引入口
- [x] 收口 TXT 预览、详情页、阅读页对索引状态的口径
- [x] 统一索引失败、正文缺失、目录过期的错误提示语义
- [x] 校正外部打开本地图书时的可读性体验

阶段完成定义：

- [x] 导入完成后，详情页至少能稳定拿到目录
- [x] 阅读页不会再命中多套相互冲突的“补索引/补解析”策略

---

## 8. 阶段 4：补齐 EPUB `fragment` 级目录解析

目标：

- 提升 EPUB 章节粒度，不只停留在 `resource/spine` 级

执行清单：

- [ ] 梳理 `EpubLocalBookParser` 当前目录候选选择逻辑
- [ ] 引入 `toc/nav + fragment` 级章节定位能力
- [ ] 为同一 `xhtml/html` 内多个逻辑章节保留切分信息
- [ ] 对封面、卷首、前言、导航页保持稳定过滤
- [ ] 保持当前 `ReaderDocument` 结构化正文输出，不另起 EPUB 阅读链路
- [ ] 校验图片资源、相对路径、章节标题回填在新粒度下不回退

阶段完成定义：

- [ ] 复杂 EPUB 的目录粒度优于当前实现
- [ ] EPUB 仍继续复用当前统一阅读器正文链路

---

## 9. 阶段 5：依赖注入收口与残留清理

目标：

- 新增能力全部按开发约束收口到 feature application + provider

执行清单：

- [ ] 将新增 service / coordinator / resolver 优先放到 `lib/features/reader/application/`
- [ ] 将新增依赖统一放到 `lib/features/reader/providers.dart` 或 reader feature 组合根
- [ ] 不在页面层直接 new 本地解析 service
- [ ] 不在页面层直接访问数据库或平台通道
- [ ] 清理本轮范围内新增的默认兜底构造与隐藏单例
- [ ] 若出现跨 feature 共享的稳定能力，再评估是否提升到全局层

阶段完成定义：

- [ ] 本轮新增逻辑没有违反开发约束文档中的一票否决项
- [ ] reader 本地阅读新增能力的依赖图可由 provider 清晰表达

---

## 10. 阶段 6：测试、回归与文档验收

目标：

- 建立可持续回归集，而不是只靠手点验证

执行清单：

- [ ] 为 `LocalTextEncodingDetector` 补常见编码样本测试
- [ ] 为 TXT 导入、索引、正文读取补 application / service 测试
- [ ] 为 EPUB 目录粒度与章节读取补 application / parser 测试
- [ ] 补本地阅读入口的 route / provider smoke test
- [ ] 执行手工回归：TXT 导入、查看目录、打开正文、重索引、旧数据升级
- [ ] 将已验证通过的项回填到本文件
- [ ] 将关键结论同步更新到相关长期文档

TXT 编码样本最小集合：

- [ ] UTF-8
- [ ] UTF-16LE
- [ ] UTF-16BE
- [ ] GBK
- [ ] GB18030
- [ ] Big5

手工回归最小集合：

- [ ] 导入 TXT（简体中文）
- [ ] 导入 TXT（繁体 / Big5）
- [ ] 修改编码后重新索引
- [ ] 打开 TXT 正文并翻章
- [ ] 导入标准 EPUB
- [ ] 导入带复杂目录 / fragment 的 EPUB
- [ ] 详情页进入阅读
- [ ] 书架进入阅读
- [ ] 升级场景下旧本地图书继续可打开

阶段完成定义：

- [ ] 自动化测试覆盖本轮关键业务链路
- [ ] 文档状态、代码状态、实际回归状态一致

---

## 11. 影响文件清单

核心改造落点：

- [x] [local_book_storage_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/local/local_book_storage_service.dart)
- [x] [local_text_encoding_detector.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/local/local_text_encoding_detector.dart)
- [x] [txt_local_book_parser.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/local/txt_local_book_parser.dart)
- [x] [local_chapter_content_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/local/local_chapter_content_service.dart)
- [ ] [local_book_index_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/local/local_book_index_service.dart)
- [ ] [local_book_import_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/bookshelf/application/local_book_import_service.dart)
- [ ] [local_content_provider.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/local_content_provider.dart)
- [ ] [epub_local_book_parser.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/local/epub_local_book_parser.dart)
- [x] [local_book_preview_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/local/local_book_preview_service.dart)
- [x] [local_book_workflow_policy.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/local/local_book_workflow_policy.dart)
- [x] [local_library_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/bookshelf/presentation/local_library_page.dart)
- [x] [bookshelf_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/bookshelf/presentation/bookshelf_page.dart)

说明：

- 若实施中新增其他关键文件，必须先补到本节，再继续开发。

---

## 12. 文档维护规则

- [x] 每次提交若完成了本文件中的任一勾选项，必须同步勾选
- [x] 每个阶段完成时，必须在下方“阶段完成记录”补日期和摘要
- [ ] 若某项取消、延期或拆分，必须先改本文件再继续实现
- [ ] 本文件与代码冲突时，不允许只改代码不改文档

---

## 13. 阶段完成记录

### 阶段 0

- 状态：`已完成`
- 完成日期：`2026-04-27`
- 备注：已冻结本轮边界为本地 `txt / epub` 内容准备层整改；确认不重做 `ReaderShell`、分页展示链路和在线书正文链路；已建立本文件作为唯一勾选清单。

### 阶段 1

- 状态：`已完成`
- 完成日期：`2026-04-27`
- 备注：`LocalBookStorageService` 已改为 TXT 默认保留原始字节，不再在导入阶段重写 UTF-8；`LocalTextEncodingDetector` 已调整为 Dart 常见编码优先、插件仅 fallback；已补充并通过 `local_book_storage_service_test`、`local_book_import_service_test`、`local_text_encoding_detector_test`。

### 阶段 2

- 状态：`已完成`
- 完成日期：`2026-04-27`
- 备注：`TxtLocalBookParser` 已统一优先使用冻结后的 `book.charset` 进行全量解析与流式样本解码；`LocalChapterContentService` 与 `LocalBookPreviewService` 已按冻结编码回读 TXT 字节，避免索引后正文阶段再次漂移到其它编码。

### 阶段 3

- 状态：`已完成`
- 完成日期：`2026-04-27`
- 备注：手动导入与外部导入入口已统一使用 `waitForIndexing: true`，导入成功口径收紧为“目录已建立，可直接阅读”；`LocalChapterContentService` 已先按索引状态返回 `pending / stale / failed` 语义，再处理章节缺失，避免阅读页误报“未找到章节”。

### 阶段 4

- 状态：`未完成`
- 完成日期：
- 备注：

### 阶段 5

- 状态：`未完成`
- 完成日期：
- 备注：

### 阶段 6

- 状态：`未完成`
- 完成日期：
- 备注：
