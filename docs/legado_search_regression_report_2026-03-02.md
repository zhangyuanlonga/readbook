# legado 搜索/换源回归报告（2026-03-02）

## 1. 回归范围

- 搜索聚合、排序、空结果兜底
- 详情页命中源切换
- 阅读换源章节定位与目录落后判定
- 系统设置开关：自动换源、搜索聚合

## 2. 自动化结果

- `flutter analyze`：通过
- `flutter test`：全量通过
- 重点回归子集：
  - `test/features/search`：通过
  - `test/features/reader/application`：通过
  - `test/features/book/presentation/book_detail_switch_source_test.dart`：通过
  - `test/features/discover/presentation/discover_page_test.dart`：通过

## 3. 性能观察

- 本轮未发现新增卡顿/阻塞型回归（基于自动化回归与逻辑路径检查）。
- 暂无统一基线数据的量化性能对比图，需后续结合真机录屏与 DevTools 采样补充。

## 4. 风险与待办

- 仍需手测关键流程：搜索 -> 详情 -> 阅读 -> 换源
- 仍需补充基线录屏、切换链路录屏、回滚点 tag 与上线观测项
