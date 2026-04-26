# 本地阅读功能二次重构总方案

更新时间：2026-04-21  
当前状态：规划中  
适用范围：本地导入、本地索引、本地多格式解析、本地正文读取、本地阅读入口、本地图文模型、跨平台编码探测与本地缓存链路。

## 1. 文档目的

这份方案不是只解决 `txt` 乱码或单个 parser 的问题，而是对“整个本地阅读功能”做一次系统性重梳理。

目标是把当前本地阅读从“能用但链路分散、兼容性不稳定、状态语义不统一”的实现，收口成一套可持续演进的跨平台本地阅读架构。

这份文档将作为后续本地阅读改造的总蓝图，后续具体开发任务、拆分里程碑、测试回归都应以本方案为准。

## 2. 当前问题判断

当前本地阅读已经具备导入、索引、阅读和多格式支持的基础，但整体仍存在以下结构性问题：

- 编码探测链路不统一。
- 导入、索引、预览、正文读取各自有不同的解码策略。
- `ready` 状态语义不够稳定。
- 本地章节有时持久化正文，有时只持久化偏移。
- 阅读阶段仍承担部分本应属于索引阶段的重活。
- 多格式虽然已接入，但主路径没有完全收口到统一模型。
- 插件能力和 Dart fallback 并存，但平台使用策略还不够清晰。

用户最终感知为：

- 某些 TXT 导入后仍乱码。
- 某些大文件第一次能读，后续切章或重进仍出现异常。
- 某些格式能进详情页，但真正打开章节才暴露问题。
- 索引完成、目录可见，不一定等于正文一定可靠。

## 3. 当前架构盘点

### 3.1 主模块

本地阅读当前主要由以下模块组成：

- 导入入口：
  - `lib/features/bookshelf/application/local_book_import_service.dart`
- 存储层：
  - `lib/features/reader/application/local/local_book_storage_service.dart`
- 编码探测层：
  - `lib/features/reader/application/local/local_text_encoding_detector.dart`
- 索引层：
  - `lib/features/reader/application/local/local_book_index_service.dart`
- 各格式 parser：
  - `txt_local_book_parser.dart`
  - `epub_local_book_parser.dart`
  - `markdown_local_book_parser.dart`
  - `html_local_book_parser.dart`
  - `pdf_local_book_parser.dart`
  - `kindle_local_book_parser.dart`
- 详情读取：
  - `lib/features/book/application/local_book_detail_service.dart`
  - `lib/features/reader/application/local_content_provider.dart`
- 正文读取：
  - `lib/features/reader/application/local/local_chapter_content_service.dart`
  - `lib/features/reader/application/local/local_book_preview_service.dart`
- 数据模型：
  - `lib/domain/entities/local_book.dart`
  - `lib/domain/entities/local_chapter.dart`
  - `lib/domain/entities/reader_document.dart`
- 本地持久化：
  - `lib/data/datasources/local/app_database.dart`

### 3.2 当前持久化事实

当前数据库已经持久化以下核心对象：

- `local_books`
- `local_chapters`

其中 `local_chapters` 已支持持久化：

- `content`
- `imageUrls`
- `documentJson`
- `sourceRef`
- `startOffset`
- `endOffset`

这说明当前架构并不是“完全没有正文缓存”，而是不同格式、不同路径的正文持久化策略不一致。

### 3.3 当前最关键的实现割裂

当前最大的割裂点不是 parser 本身，而是“编码探测”和“正文读取”没有统一。

例如：

- 导入阶段可能使用 `LocalTextEncodingDetector`
- 大文件 sample 探测可能使用 `flutter_charset_detector`
- TXT 正文按偏移读取时，却仍走另一套手写 decode 逻辑

结果就是：

- 导入时判一种编码
- 阅读时又按另一套规则解
- 最终造成移动端正文乱码

## 4. 关键结论

### 4.1 本地阅读必须统一成单一主路径

后续本地阅读必须统一成：

1. 文件导入
2. 文件归档
3. 编码探测 / 容器解析
4. 章节与正文统一生成
5. 持久化入库
6. 阅读时只消费持久化结果

除极少数“预览”或“兼容迁移”场景外，阅读时不应再做主解析。

### 4.2 核心业务必须留在 Flutter 层

本地阅读是跨平台业务，不应把业务逻辑散落在各个平台原生层。

正确原则：

- Flutter/Dart 层定义统一业务服务
- 原生插件只提供能力
- 只有 Flutter 层无法实现的能力，才交给原生插件

这意味着：

- `flutter_charset_detector` 应被视为“统一解码服务的能力提供方”
- 不应在业务层写一套 Android 逻辑、一套 iOS 逻辑
- 不应继续在多个业务模块里各自维护手写 decode 分支

### 4.3 本地阅读不能再按格式各自长出半套体系

未来支持更多格式不是简单往 `enum LocalBookFormat` 增值，而是必须先把这些格式全部收口到：

- 统一导入语义
- 统一索引语义
- 统一 `ReaderDocument`
- 统一章节可读语义
- 统一缓存和阅读入口

## 5. 目标架构

## 5.1 分层目标

后续本地阅读建议明确划分为 6 层：

### A. 导入编排层

职责：

- 识别格式
- 接收用户文件
- 创建本地图书记录
- 调度后台索引
- 给 UI 提供导入进度与状态

对应模块：

- `LocalBookImportService`

原则：

- 不负责正文解析细节
- 不直接决定编码策略
- 不直接决定阅读行为

### B. 文件存储层

职责：

- 将原文件复制到应用托管目录
- 管理资源目录
- 检测源文件变化
- 处理原文件与托管副本关系

对应模块：

- `LocalBookStorageService`

原则：

- 只关心文件和资源
- 不承载解析策略

### C. 文本解码与容器能力层

职责：

- 统一完成文本字节解码
- 统一封装跨平台编码探测能力
- 提供容器格式内容解码基础能力

对应目标模块：

- `LocalTextDecodingService` 或保留 `LocalTextEncodingDetector` 并升级

原则：

- 所有文本解码只能走这一层
- Flutter 层统一入口
- Android/iOS/Web 优先复用 `flutter_charset_detector`
- Desktop 走统一 fallback

### D. 格式解析层

职责：

- 将不同格式文件转换成统一章节模型
- 提取目录、正文、图片、封面、元数据

对应模块：

- 各 `LocalBookParser`

原则：

- parser 只负责把“输入文件”转成“标准产物”
- parser 不负责页面交互逻辑
- parser 不负责运行期状态决策

### E. 索引持久化层

职责：

- 持久化 `LocalBook`
- 持久化 `LocalChapter`
- 持久化 `ReaderDocument`
- 维护索引状态

对应模块：

- `LocalBookIndexService`
- `AppDatabase`

原则：

- `ready` 必须等价于“章节正文可直接读”
- 不能再让 `ready` 混入“目录可见但正文要现场补”

### F. 阅读消费层

职责：

- 详情页展示本地书信息
- 阅读页读取本地章节
- 预览未完成索引的书

对应模块：

- `LocalBookDetailService`
- `LocalContentProvider`
- `LocalChapterContentService`
- `LocalBookPreviewService`

原则：

- 正常阅读只读库
- 预览链路只作为特殊兜底
- 阅读层不应再隐式触发主解析

## 5.2 目标数据语义

### `LocalBookIndexStatus`

后续强制收口为：

- `pending`：已导入，尚未开始或尚未完成索引
- `indexing`：后台正在解析
- `ready`：目录、正文、结构化文档均已可读
- `stale`：源文件或索引规则变化，需要重建
- `failed`：索引失败

这里的核心约束是：

- `ready` 不再允许表示“目录 ready、正文现场补”

### `LocalChapter`

后续统一要求：

- `title` 必须存在
- `content` 对文本章节必须可读
- `document` 对图文格式必须尽量完整
- `imageUrls` 作为兼容层保留
- `sourceRef` 可用于回溯来源，但不能成为阅读时再解析正文的必要前提
- `startOffset/endOffset` 可保留，用于诊断、迁移、验证或极端 fallback

### `ReaderDocument`

后续本地图文阅读统一以 `ReaderDocument` 为主表达：

- 文本块
- 标题块
- 列表块
- 引用块
- 图片块
- 其他后续扩展块

兼容原则：

- `content` 仍保留，用于全文搜索、兼容展示和调试
- 但图文顺序与富文本主表达以 `ReaderDocument` 为准

## 6. 格式分组策略

后续不要按扩展名平铺推进，而按内容形态分组。

### 6.1 文本型

- `txt`
- `md`

重点：

- 编码探测
- 分章规则
- 正文持久化
- 全文搜索

### 6.2 文档型

- `html`

重点：

- DOM 清洗
- 相对资源归档
- 元信息提取
- 转 `ReaderDocument`

### 6.3 容器型电子书

- `epub`
- `mobi`
- `azw`
- `azw3`

重点：

- 容器解析
- 资源解包
- OPF / NCX / NAV 元信息与目录解析
- 封面提取
- 章节正文结构化

### 6.4 固定版式

- `pdf`

重点：

- 文本层识别与抽取
- 扫描版降级提示
- 页级或章节级切分策略

## 7. 跨平台策略

### 7.1 编码探测平台策略

统一原则：

- Android / iOS / Web：
  优先 `flutter_charset_detector`
- Desktop：
  统一走 Dart fallback

但业务层只看到一个 Flutter 服务，不感知平台差异。

### 7.2 原生边界

允许原生插件做的事：

- 字节级 charset 探测
- 系统级编码转换

不允许原生插件承载的事：

- 本地图书导入业务
- 索引状态流转
- 阅读页章节决策
- 多格式章节模型转换

## 8. 当前改造重点

这次二次重构建议分四个专题推进。

### 专题 A：统一文本解码服务

目标：

- 导入
- 索引
- 预览
- TXT 正文按偏移读取

全部只走统一 `LocalTextEncodingDetector`

要做的事：

- 移除 `LocalChapterContentService` 中分散的手写 decode 主路径
- 移除 `LocalBookPreviewService` 中分散的手写 decode 主路径
- 让解码优先级改为：
  - 显式 charset
  - `flutter_charset_detector`
  - 平台 converter
  - Dart fallback

### 专题 B：统一正文持久化语义

目标：

- 正常可读章节都在索引阶段完成正文持久化

要做的事：

- 继续收口 TXT 大文件流式分章后的正文持久化
- 审核 EPUB / HTML / MD / Kindle 的正文与 `document` 持久化完整性
- 明确“哪些场景允许 content 为空”

### 专题 C：重写阅读消费语义

目标：

- 阅读层只读库
- 预览层只做特殊场景

要做的事：

- `LocalBookDetailService` 只读索引结果
- `LocalChapterContentService` 只读已持久化章节
- `LocalBookPreviewService` 仅服务 pending/indexing 阶段临时预览

### 专题 D：多格式统一治理

目标：

- 新格式接入时不再扩散临时分支

要做的事：

- 明确 parser 产物规范
- 审核各格式是否都满足统一 `LocalParsedBook`
- 明确各格式失败分级与用户提示

## 9. 推荐执行顺序

建议严格按顺序做，不要并行乱切。

### 第 1 阶段：统一文本解码

- 收口 `LocalTextEncodingDetector`
- 改掉正文读取链路的手写 decode
- 改掉预览链路的手写 decode

这是最先要做的，因为它直接影响乱码。

### 第 2 阶段：统一 `ready` 语义

- 审核并补齐正文持久化
- 清理旧“正文延迟补全”依赖

### 第 3 阶段：重写阅读消费层

- 详情页
- 阅读页
- preview

只消费标准索引产物

### 第 4 阶段：格式专项收口

- EPUB
- Kindle 系列
- HTML / Markdown
- PDF

## 10. 测试与回归要求

后续改造必须至少补齐这些测试：

### 10.1 编码层

- Android / iOS 下同一份 GBK / Big5 / UTF-16 文件结果一致
- 导入和阅读正文结果一致
- 大文件 sample 判码和正文判码一致

### 10.2 索引层

- `ready` 章节正文必须可直接读取
- 文件变化后能稳定变 `stale`

### 10.3 阅读层

- 详情页不触发隐式重索引
- 阅读页不依赖正文现场解析
- pending/indexing 只走 preview，不走正式章节读取

### 10.4 多格式层

- `txt`
- `epub`
- `md`
- `html`
- `pdf`
- `mobi`
- `azw`
- `azw3`

每种格式至少要有：

- 成功样本
- 异常样本
- 元信息样本
- 图文样本（适用时）

## 11. 旧数据处理策略

这次改造不把“旧数据平滑迁移”作为前置目标。

统一原则：

- 不专门投入迁移链路开发成本
- 必要时直接提示用户重新导入
- 只保证新导入和重新索引后的数据完全符合新语义

这意味着：

- 老 TXT 若仍是“仅偏移、正文不完整”的旧结构，不作为本轮兼容重点
- 老 EPUB 若仍是“目录可见但正文未完全持久化”的旧结构，不作为本轮兼容重点
- 当旧数据不符合新主路径时，可以直接通过“重新导入 / 手动重建目录”完成切换

对应产品策略建议：

- 在本地图书详情页或阅读失败提示中明确给出“请重新导入该书”或“请重建目录”的文案
- 不继续扩展 legacy 兼容分支，避免新架构再次被旧路径拖住

## 12. 交付定义

本地阅读二次重构完成的标准应是：

- 本地图书导入、索引、阅读链路语义统一
- 编码探测链路统一
- 阅读正文不再依赖零散手写 decode
- `ready` 状态收口
- 新格式接入不再继续堆临时分支
- 本地阅读功能具备长期维护基础

## 13. 这份方案与旧文档的关系

这份文档是对以下旧方案的升级与总收口：

- [local_reading_refactor_plan.md](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/docs/local_reading_refactor_plan.md)
- [local_multi_format_reading_plan.md](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/docs/local_multi_format_reading_plan.md)

旧文档仍可作为历史背景与阶段成果记录保留；  
后续所有本地阅读新改造，应以本方案作为总基线。

## 14. 执行任务清单

### 14.1 编码与解码统一

- [x] 将 `LocalTextEncodingDetector` 收口为唯一文本解码入口
- [x] 统一 Android / iOS / Web 优先使用 `flutter_charset_detector`
- [x] 统一 Desktop 使用 Dart fallback，不在业务层写平台分支
- [x] 移除 `LocalChapterContentService` 中分散的手写 decode 主路径
- [x] 移除 `LocalBookPreviewService` 中分散的手写 decode 主路径
- [x] 保证导入、索引、预览、正文读取四条链路使用同一套解码策略

### 14.2 索引语义收口

- [x] 明确 `LocalBookIndexStatus.ready` 只表示“目录和正文均可直接读取”
- [x] 审核所有格式的 parser 输出，确保 `ready` 章节不依赖阅读时再补正文
- [x] 清理旧的“目录 ready 但正文现场补”的实现残留
- [x] 明确 `pending / indexing / ready / stale / failed` 的页面提示和交互语义

### 14.3 TXT 主路径重构

- [x] 统一 TXT 导入后的编码记录策略
- [x] 统一 TXT 索引后正文持久化策略
- [x] 统一 TXT 大文件流式分章与正文持久化策略
- [x] 保留 offset 仅作为诊断、校验或极端 fallback，不再作为正式阅读主路径
- [x] 补齐 TXT 乱码、GBK、Big5、UTF-16、大文件等样本回归

### 14.4 EPUB / Kindle / HTML / Markdown / PDF 收口

- [x] 审核 EPUB parser，确保正文、图片、封面、元信息都能稳定落库
- [x] 审核 Kindle 系列 parser，明确是否先转换成统一文档模型再入库
- [x] 审核 HTML parser，统一相对资源归档与 DOM 清洗策略
- [x] 审核 Markdown parser，统一 front matter、图片资源和章节生成策略
- [x] 审核 PDF parser，明确文本型与扫描型 PDF 的处理边界和提示策略
- [x] 明确每种格式的失败分级与用户提示

### 14.5 数据模型与存储层

- [x] 明确 `LocalBook` 字段语义，补齐本地阅读主链路实际需要的信息
- [x] 明确 `LocalChapter` 中 `content / imageUrls / document / sourceRef / offset` 的使用边界
- [x] 统一 `ReaderDocument` 作为本地图文主表达模型
- [x] 审核 `app_database.dart` 中本地图书和本地章节表结构是否满足新主路径
- [x] 明确图片、封面、资源目录的托管规则

### 14.6 阅读消费层重构

- [x] `LocalBookDetailService` 只消费稳定索引结果，不承担隐式补解析
- [x] `LocalContentProvider` 明确详情、目录、正文、预览四类本地能力边界
- [x] `LocalChapterContentService` 改成“正常阅读只读库”的正式职责
- [x] `LocalBookPreviewService` 收口为 pending/indexing 阶段的临时预览工具
- [x] 阅读页本地章节打开失败时的提示统一成可理解的用户语言

### 14.7 导入与重建流程

- [x] 重梳 `LocalBookImportService` 的导入阶段、后台索引阶段和 UI 提示阶段
- [x] 明确哪些格式允许“导入即返回，后台索引”
- [x] 明确哪些失败应提示“重新导入”，哪些失败应提示“重建目录”
- [x] 统一“重新索引 / 重建目录 / 重新导入”的产品文案

### 14.8 测试与质量门槛

- [x] 为编码层补齐 Android / iOS 一致性测试策略
- [x] 为索引层补齐 `ready` 语义测试
- [x] 为阅读层补齐“不再现场补正文”的测试
- [x] 为主要格式补齐成功样本、异常样本、图文样本、元信息样本
- [x] 为大文件和高频路径补齐性能回归基线

### 14.9 页面与产品联动

- [x] 详情页明确展示本地图书当前状态与建议操作
- [x] 阅读失败页明确提示“重新导入 / 重建目录”的建议动作
- [x] 书架页、本地详情页、阅读页对本地书状态展示保持一致
- [x] 不再为旧数据兼容额外扩展复杂产品分支
