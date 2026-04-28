# 书架点击加载卡顿治理执行方案

更新时间：2026-04-28  
用途：作为“书架点击书籍后出现短暂卡顿”的唯一执行文档，统一问题判断、阶段任务、验收口径和文档维护方式。后续相关改造一律按本文件推进和回填。

## 0. 结论先行

当前卡顿问题与“缓存”和“本地图书逻辑”有关，但主因不是“章节缓存命中慢”，而是：

- 书架点击在线书时，进入阅读页前仍会同步等待详情和目录
- 书架点击本地图书时，为拿首章会全量查询章节列表，并把正文内容一并映射出来
- 阅读页内部已经具备 `toc snapshot` 和章节缓存的快速恢复能力，但书架入口没有优先走“先跳转、后恢复”的链路

一句话结论：

- **先把点击链路改轻**
- **再把目录和正文恢复能力前移到阅读页**
- **最后再补监控、测试和文档回填**

---

## 1. 适用范围

本文件覆盖以下范围：

- `lib/features/bookshelf/`
- `lib/features/reader/`
- `lib/features/book/`
- `lib/data/datasources/local/app_database.dart`
- 阅读进度、目录快照、章节缓存相关 provider / service

本文件不覆盖：

- 阅读器排版性能专项
- 页面动画和视觉表现优化
- 非书架入口的阅读跳转链路

---

## 2. 开发约束映射

本专项必须遵守 `docs/development_architecture_guardrails.md`，执行口径如下：

- 书架页面只负责交互分发和跳转触发，不继续承担详情加载编排
- 点击进入阅读页的业务编排放入 `reader` / `bookshelf` feature 的 application 能力，不把复杂判断堆回页面
- 页面不得直接拼装数据库访问细节
- 目录快照、进度恢复、缓存命中判断优先通过 provider 暴露的稳定 service 完成
- 涉及路由和阅读器行为的改动，必须补测试或 route smoke 验证

架构目标：

- `bookshelf/presentation` 只保留“判定走哪条入口路由”
- `reader/presentation` 负责启动恢复，但不直接 new repository / database
- `data` 层只负责章节、缓存、快照持久化实现

---

## 3. 问题基线

### 3.1 当前高风险卡顿点

- 在线书点击时，`bookshelf_page.dart` 先 `await _bookDetailService.load(...)` 再 `context.push(...)`
- 本地图书点击时，`bookshelf_page.dart` 为取首章先 `await _localBookRepository.getChapters(bookId)`
- `getLocalChapters()` 会返回完整 `LocalChapter`，包含 `content` 和 `document`，不只是目录元数据
- 阅读页虽然支持 `toc snapshot` 和可见章节缓存恢复，但这套能力主要发生在进入阅读页之后

### 3.2 现有可复用能力

- `ReaderEntryRouteResolver`
- `ReaderPreferencesService.loadTocSnapshot/saveTocSnapshot`
- `ReaderCachedChapterStore`
- `BookDetailService.peekCached(...)`
- 本地章节 `getLocalChapterByIndex(...)` / `getLocalChapterMetas(...)`

### 3.3 对标口径

对比 MD3，本项目当前差异是：

- MD3：书架点击先跳阅读页，再在阅读页里异步初始化
- 当前工程：书架点击时先做一部分目录和章节准备，再进入阅读页

本轮目标不是完全复制 MD3，而是收敛到同一原则：

- **进入阅读页前不做重 I/O**

---

## 4. 阶段任务清单

当前进度：

- 阶段 0：已阻塞，最后更新 `2026-04-28`，备注：代码埋点与观测口径已落地，Android 真机基线待实机验证
- 阶段 1：已完成，完成日期 `2026-04-28`
- 阶段 2：未开始
- 阶段 3：未开始
- 阶段 4：未开始

回填规则：

- 状态：`未开始 / 进行中 / 已完成 / 已阻塞`
- 完成日期：`YYYY-MM-DD`
- 备注：只写关键决策、阻塞原因或偏差说明

### 阶段 0：建立基线与观测口径

目标：

- 先确认卡顿发生在哪一段，再做链路改造，避免凭体感反复试错

任务：

- [x] 梳理书架点击在线书、本地图书、有进度、无进度四条链路
- [x] 在书架点击入口补统一耗时埋点，区分点击到跳转、点击到首屏内容、点击到正文可交互
- [x] 在阅读页 bootstrap 补统一耗时埋点，区分 `toc snapshot`、详情加载、正文加载、分页恢复
- [ ] 记录当前 Android 真机基线数据，至少覆盖在线书 2 本、本地图书 2 本
- [x] 将观测字段和口径补回本文件

当前链路口径：

- 在线书有进度：书架命中 `ReadingProgress` 后直接构建 progress 路由进入阅读页
- 在线书无进度：优先命中 `toc snapshot`，再尝试 `detail cache`，都未命中时走 reader fallback 路由
- 本地图书有进度：书架命中 `ReadingProgress` 后直接构建 progress 路由进入阅读页
- 本地图书无进度：优先命中 `toc snapshot`，否则只读取首章 meta；`txt` 未完成索引时直接走 reader fallback 并后台继续索引

当前观测字段：

- 书架入口日志：`Bookshelf reader open plan resolved`
  字段：`progressHit`、`tocSnapshotHit`、`detailCacheHit`、`localFirstChapterMetaHit`、`progressLoadMs`、`tocSnapshotLoadMs`、`localFirstChapterMetaLoadMs`、`resolveDurationMs`
- 书架跳转日志：`Bookshelf reader route push`
  字段：`tapToPushMs`、`kind`
- 阅读页启动日志：`Reader bootstrap started` / `Reader bootstrap finished`
  字段：`tapToBootstrapStartMs`、`progressLoadMs`、`tocSnapshotLoadMs`、`visibleCacheLoadMs`、`detailLoadMs`、`chapterLoadMs`、`tapToVisibleMs`、`tapToBootstrapDoneMs`

阻塞说明：

- 当前环境未连接 Android 真机，阶段 0 剩余项只差真实设备基线采样

完成标准：

- 能明确区分“点击前阻塞”与“阅读页内恢复耗时”
- 后续每个阶段都能复用同一套耗时指标

---

### 阶段 1：压缩书架点击前阻塞链路

目标：

- 让书架点击尽快完成路由跳转，不在 `bookshelf_page.dart` 里等待详情/全量目录

任务：在线书

- [x] 将“无进度在线书点击”从“先 `loadDetail()` 再跳转”改为“先走 reader fallback 路由，再由阅读页恢复”
- [x] 优先复用 `ReaderEntryRouteResolver.buildRouteFromBookshelfFallback(...)`
- [x] 如存在可用 `toc snapshot` 或 `detail cache`，只做轻量命中判断，不在书架页发起重网络/脚本任务
- [x] 将“书源不可用时提示”从书架页前置失败提示改为阅读页内统一处理

任务：本地图书

- [x] 将“无进度本地图书点击”从 `getChapters(bookId)` 改为只取首章 meta
- [x] 优先新增或复用 `getLocalChapterByIndex(bookId, 0)` / `getLocalChapterMetas(bookId)`
- [x] 禁止为取首章在书架页全量读取本地章节正文
- [x] 保留未索引、索引中、索引失败的分支提示，但不要回退成重查询

任务：结构收口

- [x] 将书架点击进入阅读页的决策逻辑整理为独立 application 能力或局部 flow helper
- [x] 保持 `bookshelf/presentation` 只负责交互分发，不继续增长数据装配代码

完成标准：

- 书架点击在线书时，不再同步等待 `BookDetailService.load(...)`
- 书架点击本地图书时，不再为取首章读取整本 `LocalChapter.content`
- 点击到路由跳转耗时明显下降

---

### 阶段 2：强化阅读页启动恢复链路

目标：

- 把原本在书架点击前做的工作，安全迁回阅读页 bootstrap，并优先走本地快照恢复

任务：

- [ ] 明确阅读页启动顺序：`progress -> toc snapshot -> visible content cache -> detail/toc fallback -> chapter content`
- [ ] 如存在 `toc snapshot`，确保阅读页直接恢复目录和当前章节身份，不重复走详情链路
- [ ] 如存在当前章节缓存，确保优先展示缓存内容，再异步补齐必要状态
- [ ] 对 `BookDetailService.peekCached(...)` 建立阅读页可复用的轻量读取入口
- [ ] 梳理本地图书 `bootstrap` 场景，保证无进度时也能通过轻量目录信息进入首章
- [ ] 补齐阅读页错误态文案，避免把“书架点击失败”变成“静默空白页”

完成标准：

- 阅读页成为唯一的恢复编排入口
- 已缓存书籍能更稳定地实现“先出内容，后补状态”
- 书架页与阅读页之间的职责边界符合 guardrails

---

### 阶段 3：本地章节查询与缓存结构瘦身

目标：

- 收口“目录查询误带正文”的问题，避免后续其他页面重复踩坑

任务：

- [ ] 审计 `LocalBookRepository` 现有接口语义，区分“章节 meta 查询”和“章节正文查询”
- [ ] 为本地章节列表建立明确的 meta-only 查询入口
- [ ] 禁止书架、目录、详情等非正文场景调用返回 `content/document` 的全量章节列表
- [ ] 评估 `LocalChapter` 是否需要拆出更轻的目录模型，或至少通过 repository 语义隔离
- [ ] 审计 `app_database.dart` 中本地章节查询热点，确认是否需要补索引或减少 JSON 解码

完成标准：

- “取目录”和“取正文”在 repository 语义上明确分离
- 本地大书点击不再因全量章节内容映射产生明显顿挫

---

### 阶段 4：验收、回归与文档维护

目标：

- 用统一口径关闭本专项，并让文档能继续作为维护基线

任务：

- [ ] 补充或更新测试，至少覆盖书架到阅读页的 route smoke 和关键 application service
- [ ] 手工回归在线书、有缓存在线书、本地图书、未完成索引本地图书四类场景
- [ ] 回填阶段完成状态、完成日期、关键决策
- [ ] 将最终落地策略同步到 `docs/README.md`
- [ ] 如实施过程和本文偏差较大，直接更新本文，不另起平行计划文档

完成标准：

- 本文件状态完整可追溯
- 新成员只看本文件即可理解问题、方案和当前进度

---

## 5. 实施顺序建议

推荐顺序：

1. 先做阶段 0，补耗时观测
2. 再做阶段 1，先砍掉点击前最重的同步等待
3. 然后做阶段 2，把恢复能力稳住
4. 最后做阶段 3，清理本地章节查询语义

不建议的顺序：

- 先大改阅读页缓存结构，再回头处理书架点击
- 先做大量 UI 提示优化，回避点击前阻塞主因

---

## 6. 验收口径

至少验证以下结果：

- 在线书无进度点击时，点击后应优先进入阅读页，不再卡在书架页
- 在线书有进度点击时，恢复行为不退化
- 本地图书无进度点击时，不再触发整本章节正文级查询
- `toc snapshot` 命中时，阅读页能直接恢复目录和当前章节
- 当前章节缓存命中时，阅读页能尽快显示正文
- 失败态仍可进入阅读页并给出可理解提示

建议记录指标：

- 点击到 `context.push(...)` 耗时
- 点击到阅读页首屏可见耗时
- 阅读页 bootstrap 总耗时
- `toc snapshot` 命中率
- 当前章节缓存命中率

---

## 7. 文档维护规则

本文件是活文档，执行期间必须维护，规则如下：

- 每完成一个阶段，更新“当前进度”
- 每关闭一组任务，直接勾选，不另写外部零散记录
- 若实现偏离原方案，先改本文，再继续开发
- 若阶段被拆分或合并，直接在本文调整，不新增同主题平行文档
- 本专项结束后，若文档只剩历史价值，再移入 `docs/archive/`

---

## 8. 当前建议优先级

`P1`

- 阶段 0
- 阶段 1

`P2`

- 阶段 2
- 阶段 3

`P3`

- 阶段 4 的文档整理和长期维护优化
