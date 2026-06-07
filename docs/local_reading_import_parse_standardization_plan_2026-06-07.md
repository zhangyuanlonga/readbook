# 本地阅读导入到解析规范化计划

创建日期：2026-06-07  
适用范围：Android、iOS、Web、macOS、Windows、Linux 的本地图书导入、受管存储、索引、解析和阅读入口。

## 1. 本轮结论

本地阅读链路不能继续按早期“先能读起来”的方式追加逻辑。后续所有 TXT / EPUB / PDF / MOBI / HTML / Markdown 的导入和解析，都必须先落到统一链路：

`用户选择 / Web 上传` -> `LocalBookImportService` -> `LocalBookStorageService` -> `LocalBookIndexService` -> `LocalBookParserInput` -> `LocalChapterContentService` -> `ReaderPage`

格式 parser 只负责把输入转换为 `LocalParsedBook` 和 `LocalParsedChapter`，不能直接决定 UI、书架状态、会员、路由、平台能力或长期存储目录。

## 2. 统一边界

| 层级 | 负责内容 | 不允许扩散的内容 |
| --- | --- | --- |
| 导入入口 | 文件选择、Web 上传、导入进度、用户取消。 | 章节识别、编码评分、阅读器 UI。 |
| 受管存储 | 复制到应用支持目录、路径归一化、文件大小、格式识别、用户资产边界。 | 页面弹窗、阅读排版、章节业务。 |
| 索引服务 | parser 分发、索引去重、stale 判断、数据库写入、错误归一化。 | 文件选择器和平台 UI。 |
| parser input | 明确 native file、managed file、web bytes 的输入语义。 | 各 parser 自己猜平台和来源。 |
| 格式 parser | 格式解析、metadata、章节、封面、资源引用。 | 书架排序、阅读状态、路由跳转。 |
| 章节内容服务 | 懒加载章节正文、TXT offset、EPUB sourceRef、ReaderDocument 归一化。 | 重新导入文件、改写索引结构。 |

## 3. TXT 策略

TXT 暂不整体替换成熟库。原因不是不想用库，而是当前常见 Dart / Flutter TXT 包没有稳定覆盖中文网文章节识别、多编码检测、超大文件 offset 懒加载和长章节拆分。`flutter_read` 更像完整阅读器组件而不是可直接接入的章节 parser，且 LGPLv3 许可需要单独评估；`flutter_charset_detector` 已在项目里承担编码检测能力，但不能替代章节识别。当前正确方向是保留项目内 parser，把可维护边界拆清楚，并继续寻找能替换单点能力的成熟库。

2026-06-07 已退役旧版用户自定义章节规则。`reader.local.txt.chapterRules` 不再读取、不再写入、不再作为 storage baseline；TXT 章节规则只使用随版本发布的内置规则。后续如果新增章节规则，必须改 `txt_auto_chapter_patterns.dart` 并同步测试，不能恢复用户设备本地自定义正则。

## 4. EPUB 策略

EPUB 是更适合成熟库 adapter 验证的格式，但不能直接全量替换。当前 parser 已经承担 OPF、spine、nav、metadata、cover、inline image、fixed-layout 信号、资源物化和 `ReaderDocument` 输出，替换必须先证明输出等价。

候选方向：

- `epub_pro`：已作为成熟库 adapter 接入。pub.dev 当前最新版本为 `5.6.0`，SDK 约束 `>=3.0.0 <4.0.0`，依赖 `archive ^4.0.7`、`xml ^6.5.0`、`image ^4.1.7`，与项目现有依赖方向更接近。当前生产 parser 只在 `epub_pro` 输出章节形态与现有 parser 等价、且不是 fixed-layout 时采用 adapter 索引；不等价、解析失败、同一 xhtml 多 fragment 拆章、fixed-layout 和复杂 mixed-media 仍回退项目 parser。
- `epubx`：pub.dev 当前最新版本为 `4.0.0`，发布时间更早，依赖 `archive ^3.1.6`、`image ^3.0.8`，与项目现有 `archive ^4.0.9`、`image ^4.3.0` 存在冲突风险。除非能在不加 dependency override 的前提下通过，否则不作为第一优先。
- `epub_view`：更偏阅读 UI / viewer 方案，不直接替代当前本地索引 parser。

成熟库接入原则：先建 adapter 和对照测试，再决定是否替换生产 parser；禁止直接把第三方模型泄漏到 repository、UI 或数据库层。

## 5. 平台口径

| 平台 | 当前口径 | 后续要求 |
| --- | --- | --- |
| Android | Native 文件选择后复制到受管目录，再走 parser。 | 真机验证权限、沙盒、大 TXT / EPUB 导入耗时。 |
| iOS | 同 Android，但更关注沙盒和文件安全访问。 | 真机验证文件选择、导入副本、退出后重开。 |
| Web | 不应依赖 `dart:io File`。 | 以 `LocalBookParserInput.webUploadedBytes` 为入口，明确 IndexedDB / bytes / blob 存储策略。 |
| macOS | Native 文件选择和受管目录可用。 | 验证窗口拖拽、文件路径、权限和大文件导入。 |
| Windows | 同桌面 Native。 | 与 macOS 分开验收，不用 macOS 结果代替。 |
| Linux | 同桌面 Native。 | 单独验构建、文件选择器、路径编码。 |

## 6. 已执行任务

- [x] `LOCAL-STD-01` 梳理本地阅读导入到解析链路，并固化统一边界。
- [x] `TXT-STD-01` 退役旧版 `reader.local.txt.chapterRules` 自定义章节规则读取。
- [x] `TXT-STD-02` 补 TXT parser 回归测试，确认旧 prefs 残留不会影响章节识别。
- [x] `STORAGE-STD-01` 移除 TXT 自定义章节规则 storage guard 白名单。
- [x] `DOC-STD-01` 在 README、storage 盘点、baseline、M4 文档中登记本轮结论。
- [x] `EPUB-STD-01` 新建 `EpubProLocalBookAdapter`，第三方模型只停留在 adapter 内部。
- [x] `EPUB-STD-02` 用 `epub_pro` 对照 metadata、OPF、spine、nav / toc 输出，并补 adapter 测试。
- [x] `EPUB-STD-03` 确认 `epub_pro` 不适合直接全量替换：同一 xhtml 多 fragment 会去重，fixed-layout / ReaderDocument / inline image 仍需项目 parser。
- [x] `EPUB-STD-04` 生产 `EpubLocalBookParser` 增加保守门禁：adapter 等价时采用 `epub_pro` 索引，不等价时自动回退。

## 7. 后续阶段任务

- [ ] `LOCAL-STD-02` 将 `LocalBookParserInput` 补充为所有本地 parser 的强制入口，并记录不支持 bytes 的 parser 降级错误。
- [ ] `LOCAL-STD-03` 给 `LocalBookIndexService` 增加 parser input smoke，覆盖 native file、managed file、web bytes 三类来源。
- [ ] `LOCAL-STD-04` 修复本地阅读测试中的 Drift 多数据库警告，统一测试数据库注入方式。
- [ ] `LOCAL-WEB-01` 设计 Web 本地图书上传和长期存储语义，明确 bytes、IndexedDB、浏览器刷新恢复和容量错误提示。
- [ ] `TXT-STD-03` 拆分 `TxtLocalBookParser`：编码检测、章节规则选择、章节切分、offset 计算、流式索引分别落到小型内部组件。
- [ ] `TXT-STD-04` 为内置章节规则建立样例矩阵，覆盖中文、英文、纯数字、前言、番外、误判标题和长章节。
- [ ] `TXT-STD-05` 建立 TXT 大文件性能基线：10MB、50MB、100MB 的索引耗时、峰值内存、打开首章耗时。
- [ ] `TXT-STD-06` 调研是否存在可稳定替代“章节识别”单点的成熟库；如果没有，明确长期保留项目规则库。
- [ ] `TXT-STD-07` 调研 `flutter_read` 是否只有 UI 阅读器价值，确认 LGPLv3 许可和现有阅读器冲突后再决定是否放弃。
- [ ] `EPUB-STD-05` 为 EPUB parser 实现 `LocalBookParserInputAware`，Web bytes 可直接解析，不依赖 `dart:io File`。
- [ ] `EPUB-STD-06` 建立 EPUB 样例集：普通小说、带封面、nav.xhtml、ncx、inline image、fixed-layout、缺失 OPF、损坏压缩包。
- [ ] `EPUB-STD-07` 用真实 EPUB 样例验证 adapter 门禁命中率，决定是否扩大 `epub_pro` 接管范围。
- [ ] `LOCAL-TEST-01` 建立 Android / iOS / Web / macOS / Windows / Linux 本地导入 smoke 清单。
- [ ] `LOCAL-DOC-01` 每次替换 parser 或成熟库 adapter 后，更新本文件和 M4 / M6 对应验收记录。

## 8. 维护规则

- 新 parser 或 parser adapter 必须有中文维护注释，说明保留原因、替换边界、平台限制和测试入口。
- 成熟库优先，但只能通过 adapter 进入项目，不能让第三方模型穿透到 UI、数据库和路由。
- 历史残留 key 如果没有 UI 和业务承接，默认退役；只在迁移期读取一次并清理，不允许长期保留隐形状态。
- 同一文件在不同设备上必须解析出一致章节；用户本地旧偏好不能改变章节结构。
- 大文件解析必须有懒加载、offset 或后台 isolate / cooperative yield 方案，不能把完整正文长期塞进 UI 状态。
