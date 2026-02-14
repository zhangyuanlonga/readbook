# 章节缓存（小说详情页 + 阅读页双入口）计划

目标：在 Android/iOS 手机端提供"选范围缓存章节"能力，让用户离线/弱网也能继续阅读。

范围：仅缓存"章节正文"（纯文本）。不做后台下载、不做云同步、不做跨设备。

## 入口与交互

- 入口 1：小说详情页
  - 位置："最新章节"卡片 与 "目录"卡片之间
  - 展示：`缓存: cached/total  [缓存标志]`
  - 点击：打开缓存范围 BottomSheet（A）

- 入口 2：阅读页顶部浮层
  - 位置：顶部浮层右侧操作区，放在"书架"按钮左侧
  - 点击：打开同一个缓存范围 BottomSheet（A），默认范围从当前章节开始

## P0：数据层与缓存读写（必须先做）

- [x] CCH01：新增章节缓存表（Drift）
  - 表建议：`chapter_caches`
  - 字段：cacheKey(sourceId|chapterUrl)、bookId、sourceId、chapterIndex、chapterTitle、chapterUrl、content、createdAt/updatedAt
  - 验收：缓存一章后 App 重启仍存在

- [x] CCH02：ChapterContentService 接入 L1/L2 缓存
  - L1：内存 Map（现有 `_chapterCache`）
  - L2：DB（chapter_caches）
  - 读取顺序：L1 -> L2 -> 网络解析 -> 写入 L2 + 回填 L1
  - 验收：已缓存章节再次打开 `fromCache=true`

- [x] CCH03：统计接口
  - 能按 bookId 统计 cachedCount
  - 验收：详情页能显示 `0/2470` 并随缓存更新

## P0：缓存任务执行引擎（稳定保守）

- [x] CCH04：缓存任务 Service（可取消 + 进度）
  - 输入：bookId/sourceId/detailUrl/chapters + startIndex/endIndex + onlyIfNotCached
  - 输出：`Stream<CacheProgress>`（done/total/currentTitle/success/failed）
  - 限流并发：1（默认，最稳）
  - 超时：每章 connect 8s / receive 12s（或更短）
  - 失败策略：失败计数 + 跳过继续
  - 验收：不会卡 UI；可取消；完成后缓存数正确

- [x] CCH05：缓存范围选择 BottomSheet（A）
  - 选择方式：RangeSlider（粗选）+ 数字微调（精确）
  - 显示：当前范围"第 x 章 - 第 y 章"、预计缓存章节数
  - 操作：取消 / 确定开始缓存
  - 验收：2000+ 章节下仍顺滑

- [x] CCH06：缓存进度 BottomSheet
  - 显示：done/total、当前章节、失败数、停止按钮
  - 完成：提示"缓存完成/部分失败"并刷新卡片

## P1：体验补齐（建议，但可延后）

- [ ] CCH07：清理缓存
  - 入口：详情页缓存卡片长按 或 BottomSheet 内"清理本书缓存"
  - 验收：清理后 cachedCount 归零

- [ ] CCH08：阅读页命中提示（可选）
  - 例如：章节标题旁小点/云朵表示"已缓存"

## UI 状态定义（缓存标志）

- 未缓存：`cloud_download_outlined`
- 缓存中：小号进度环（CircularProgressIndicator）
- 已完成（cached==total）：`cloud_done_rounded`

