# 阅读器阶段 0 基线矩阵

日期：2026-05-09

用途：固定阅读器性能、能耗、缓存和内存的回归口径。后续阶段不再用“感觉更流畅”作为结论，必须回填这里的样本和指标。

## 1. 样本矩阵

| 编号 | 类型 | 用途 | 固定来源 | 当前状态 |
| --- | --- | --- | --- | --- |
| S1 | 长 TXT | 验证长章节分页、首屏、首翻页 | 待放入本地测试样本目录或固定 mock | 待采样 |
| S2 | 普通 EPUB | 验证普通本地书打开链路 | 待放入本地测试样本目录或固定 mock | 待采样 |
| S3 | 图文 EPUB | 验证文字+图片滚动/分页 | 已有 smoke test 覆盖渲染；真机样本待固定 | 待采样 |
| S4 | 纯图 EPUB/漫画 | 验证连续、分页、横向漫画 | 已有 smoke test 覆盖三模式；真机样本待固定 | 待采样 |
| S5 | 网络章节 | 验证当前章优先和邻章预载 | 使用固定书源或 fake provider | 待采样 |
| S6 | 低质量图片章节 | 验证坏图、超大图、重试和降级 | 待放入本地测试样本目录或固定 mock | 待采样 |

## 2. 指标口径

| 指标 | 起点 | 终点 | 记录方式 |
| --- | --- | --- | --- |
| 打开耗时 | 点击书架/目录章节 | 阅读页 route 初始化完成 | profile 日志或 DevTools timeline |
| 首屏耗时 | 点击书架/目录章节 | 当前章第一屏文字或图片可见 | profile 日志、录屏帧时间 |
| 首翻页耗时 | 第一次触发翻页 | 翻页完成且新页稳定 | 现有 `Reader first page turn completed` 日志或 timeline |
| 内存峰值 | 进入阅读页前 | 首屏后 30 秒 | DevTools Memory、Android Studio Profiler |
| 连续滚动 FPS | 开始连续滚动 | 连续滚动 60 秒 | Flutter Performance overlay / DevTools frame chart |
| 后台任务数 | 阅读页可见后 | 后台预载稳定期 | session token、preload controller、日志计数 |
| 缓存增长 | 进入阅读页前 | 阅读 5 分钟后 | cache 目录大小、数据库缓存条目/字节 |
| 电量体感 | 阅读开始 | 连续阅读 30 分钟 | 真机电量变化和温度体感记录 |

## 3. 回归用例映射

| 能力 | 自动化覆盖 | 备注 |
| --- | --- | --- |
| 图文 EPUB 滚动显示文字和图片 | `test/features/reader/presentation/reader_rendering_memory_smoke_test.dart` | 覆盖 `ReaderTextScrollView` |
| 图文 EPUB 分页显示文字和图片 | `test/features/reader/presentation/reader_rendering_memory_smoke_test.dart` | 覆盖 `ReaderTextPagedView` block 渲染 |
| 纯漫画连续模式 | `test/features/reader/presentation/reader_rendering_memory_smoke_test.dart` | 覆盖 `ListView` |
| 纯漫画分页模式 | `test/features/reader/presentation/reader_rendering_memory_smoke_test.dart` | 覆盖 `PageView` |
| 纯漫画横向模式 | `test/features/reader/presentation/reader_rendering_memory_smoke_test.dart` | 覆盖 `Axis.horizontal` |
| 资源预算降级 | `test/features/reader/application/reader_resource_budget_test.dart` | 覆盖低电量和离线 |
| 预载任务计划和失败记忆 | `test/features/reader/application/reader_preload_controller_test.dart` | 覆盖当前优先、低电量、任务拆分、失败冷却 |

## 4. 真机记录表

| 样本 | 设备 | 模式 | 打开耗时 | 首屏耗时 | 首翻页耗时 | 峰值内存 | 滚动 FPS | 后台任务数 | 缓存增长 | 结论 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| S1 长 TXT | 待填 | 分页 | 待填 | 待填 | 待填 | 待填 | 不适用 | 待填 | 待填 | 待填 |
| S1 长 TXT | 待填 | 滚动 | 待填 | 待填 | 不适用 | 待填 | 待填 | 待填 | 待填 | 待填 |
| S2 普通 EPUB | 待填 | 分页 | 待填 | 待填 | 待填 | 待填 | 不适用 | 待填 | 待填 | 待填 |
| S3 图文 EPUB | 待填 | 分页 | 待填 | 待填 | 待填 | 待填 | 不适用 | 待填 | 待填 | 待填 |
| S3 图文 EPUB | 待填 | 滚动 | 待填 | 待填 | 不适用 | 待填 | 待填 | 待填 | 待填 | 待填 |
| S4 纯图 EPUB/漫画 | 待填 | 连续 | 待填 | 待填 | 不适用 | 待填 | 待填 | 待填 | 待填 | 待填 |
| S4 纯图 EPUB/漫画 | 待填 | 分页/横向 | 待填 | 待填 | 待填 | 待填 | 不适用 | 待填 | 待填 | 待填 |
| S5 网络章节 | 待填 | 分页 | 待填 | 待填 | 待填 | 待填 | 不适用 | 待填 | 待填 | 待填 |
| S6 低质量图片章节 | 待填 | 图片/图文 | 待填 | 待填 | 待填 | 待填 | 待填 | 待填 | 待填 | 待填 |

## 5. 阶段 0 验收

- 自动化 smoke test 必须覆盖图文滚动、图文分页、漫画连续、漫画分页、漫画横向。
- 每次架构阶段完成后，至少运行对应 application/presentation 测试。
- 性能结论必须区分“自动化渲染可用”和“真机低端流畅”。
- 真机表没有回填前，不能宣称能耗、峰值内存或低端机流畅性已最终达标。

## 6. 2026-05-13 阶段 0 执行记录

本次先落地代码级观测点，为阶段 1 和后续逐页分页优化提供 DevTools Timeline 依据。

| 链路 | Timeline 名称 | 当前覆盖 | 待补 |
| --- | --- | --- | --- |
| 本地索引总链路 | `reader.local.index` | format、force、chapterCount、costMs、失败原因 | 按缓存/存储写入拆更细事件 |
| TXT 索引 | `reader.local.txt.index` | charset、chapterCount、是否 index-only | 目录 ready 到首章 ready 的分段耗时 |
| EPUB 索引 | `reader.local.epub.index` | chapterCount、cover 状态 | Stage 2 拆分 parseIndex/parseChapter 后补章节按需解析耗时 |
| 本地章节读取 | `reader.local.chapter.load` | chapterIndex、contentLength、是否 offset range | 在线章节读取统一事件 |
| 纯文本分页 | `reader.pagination.paragraphs` | paragraphCount、viewport、pageCount、aborted/ready/failed | 当前页 ready、缓存命中、缓存写入 |
| 图文分页 | `reader.pagination.blocks` | blockCount、paragraphCount、viewport、pageCount | 图片尺寸稳定后的重分页原因 |

本次没有回填真机数值。低端 Android、中端 Android、iPhone、小屏模拟器仍需按第 4 节表格实测。
