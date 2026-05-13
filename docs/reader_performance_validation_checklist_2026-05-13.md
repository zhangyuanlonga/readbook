# Reader Performance Validation Checklist - 2026-05-13

本清单用于承接阅读器滚动/分页丝滑改造中必须靠真机或固定样本验证的任务。代码侧已补齐 Timeline、慢分页日志、缓存统计、资源预算和设备分级入口；本文件记录可复测口径。

## 1. Device Matrix

| Device class | Required sample | Status | Notes |
| --- | --- | --- | --- |
| Low Android | 3GB RAM or below / Android 10-12 | Pending real device | 验证低端降级、图片 decode、翻页稳帧 |
| Mid Android | 4-6GB RAM / Android 13+ | Pending real device | 验证默认预算 |
| iPhone | iPhone 15/16/17 or current local iPhone | Pending real device | 验证 iOS 分页、图片、打包后表现 |
| Small simulator | 360-390dp width | Pending simulator run | 验证小屏分页和滚动 UI |

## 2. Fixed Sample Books

| Sample | Purpose | Required content |
| --- | --- | --- |
| Large TXT | 首开懒加载、长列表稳帧 | 10MB+，至少 1 万行 |
| Normal TXT | 回归普通阅读路径 | 50-200 章 |
| Mixed EPUB | 图文分页缓存和图片预算 | 章节内含多张图片 |
| Comic | 漫画分页重型状态释放 | 50+ 高清图 |
| PDF | 本地解析/预览基线 | 100+ 页 |

## 3. Metrics To Record

| Metric | Source |
| --- | --- |
| Open to first readable frame | `reader.first_page_ready` Timeline / startup log |
| First page turn latency | Flutter DevTools timeline |
| Pagination duration | `reader.pagination.*` Timeline and slow log |
| Scroll frame stability | Performance Overlay / DevTools frames |
| Page turn frame stability | Performance Overlay / DevTools frames |
| Peak memory | DevTools memory |
| Pagination cache hit rate | `reader.pagination.cache.hit/miss/write` Timeline |
| Cache size | startup maintenance log context |
| Active device tier | reader resource budget resolver input/output during debug |

## 4. Stress Chapters

- 10,000-line plain text chapter.
- 50 high-resolution images mixed with text.
- One single oversized paragraph with 30,000+ characters.

## 5. Manual Smoke Steps

1. Open each fixed sample from cold start and record first readable frame.
2. Switch between scroll and paged mode, then change font size, line height, and margins.
3. Flip 30 pages continuously in paged mode.
4. Fast-scroll from 0% to 90% in scroll mode.
5. Reopen the same chapter and confirm pagination cache hits.
6. Put device under low battery condition or simulate low battery budget and verify preload/decode budget tightens.
7. Re-run startup storage maintenance and verify the log includes reason, before/after counts, and bytes.

## 6. Acceptance Notes

- 真机数据未填前，不把“帧率达标”视为完成，只视为“验收入口已准备好”。
- 任何样本出现明显 jank，应带 Timeline 截图、设备型号、样本名和章节号回填到本文件或基线矩阵。
