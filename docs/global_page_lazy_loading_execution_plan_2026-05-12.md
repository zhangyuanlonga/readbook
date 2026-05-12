# 全局页面懒加载阶段任务

更新时间：2026-05-12  
来源：`docs/global_page_route_inventory_2026-05-12.md`  
目标：把全局页面从“路由已梳理”推进到“核心功能优先，其他功能按需加载”的可执行阶段任务。

## 0. 执行原则

本计划不优先追求 Dart 代码分包。先做更稳定、全平台收益更明确的业务懒初始化：

- 主 Tab 只加载当前页面需要的数据。
- 页面入口可以存在，但页面服务、网络请求、图片扫描、数据库重查询必须等用户进入后再做。
- 书架、首页、统计、我的是核心入口，首屏只加载基础快照。
- 书源、同步、发现、在线搜索是 capability-gated，能力关闭时只显示轻量占位。
- 每完成一个阶段后，必须同步更新本文状态和 `global_page_route_inventory_2026-05-12.md`。

## 1. 阶段总览

| 阶段 | 名称 | 目标 | 主要页面 | 状态 |
| --- | --- | --- | --- | --- |
| Phase 0 | 页面加载约束落地 | 建立页面分级和新增路由规则 | 全局 | 已完成 |
| Phase 1 | Core Shell 首屏瘦身 | 主导航页面只加载基础快照 | `/home`、`/bookshelf`、`/stats`、`/mine` | 已完成 |
| Phase 2 | 书架链路分阶段加载 | 书架基础可见优先，附加信息后台补齐 | `/bookshelf`、`/local-library`、`/book/:bookId` | 已完成 |
| Phase 3 | 阅读链路按需启动 | 只在打开章节时初始化阅读重资源 | `/reader/:bookId/:chapterId`、`/stats` | 已完成 |
| Phase 4 | 我的与管理页懒初始化 | 低频管理功能进入页面后加载 | 外观、主题、图集、缓存、书签、反馈 | 已完成 |
| Phase 5 | Feature-gated 页面轻量化 | 能力关闭时不创建真实业务页面 | 书源、发现、搜索、同步 | 已完成 |
| Phase 6 | 验证与回归基线 | 建立启动、首屏、滚动、能力关闭验证 | 全局 | 待执行 |

## 2. Phase 0：页面加载约束落地

目标：

- 先统一规则，避免后续继续新增“进入路由前就初始化”的页面。
- 新增页面必须先定义加载等级，再决定路由和服务初始化位置。

任务：

- [x] 在 `docs/development_architecture_guardrails.md` 增加“页面加载分级”约束。
- [x] 新增路由必须补 `docs/global_page_route_inventory_2026-05-12.md`。
- [x] 新增页面必须标记为 `Core Shell`、`Core On-demand`、`Management On-demand` 或 `Feature-gated`。
- [x] 页面禁止在 `build` 和主 Tab 初始化路径里做重 IO、网络请求、图片扫描、全量数据库查询。
- [x] 明确 capability-gated 页面关闭能力时只能返回 `FeatureDisabledPage` 或轻量占位。

验收：

- [x] 文档约束已补齐。
- [x] 路由清单和阶段任务互相引用。
- [x] 后续新增页面有明确 checklist 可跟。

## 3. Phase 1：Core Shell 首屏瘦身

目标：

- 主导航页面快速可见。
- 不把低频页面、书源、同步、图库、缓存统计带入首屏。

范围：

- `/home` `HomePage`
- `/bookshelf` `BookshelfPage`
- `/stats` `ReadingRecordsPage`
- `/mine` `MinePage`

任务：

- [x] 检查 Shell 是否因 `StatefulShellRoute.indexedStack` 提前初始化非当前 branch 的重数据。
- [x] `HomePage` 只加载继续阅读、最近记录、基础统计；推荐、排行榜、在线入口按 capability 或用户行为延后。
- [x] `BookshelfPage` 首屏只加载基础书架列表和必要阅读进度。
- [x] `ReadingRecordsPage` 只在进入统计页后查询统计数据，不由首页或 shell 预查询重数据。
- [x] `MinePage` 只读会员/模块/入口快照，不初始化外观、图集、缓存、反馈等管理页服务。
- [x] 检查主导航切换时后台任务是否继续跑；不可见页面的低优先级任务需要暂停或取消。

验收：

- [x] 冷启动首屏不触发书源、同步、图库扫描、缓存统计。
- [x] 进入 `/home` 或 `/bookshelf` 时能先显示核心内容。
- [x] 切换 Tab 不产生明显卡顿或重复全量加载。

执行记录：

- `BookshelfPage` 基础列表显示后再延迟加载标签、分类、展示态和进度补齐；书源能力关闭时跳过 source type map。
- `MinePage` 首次进入只读本地 session / 权益快照，不再因为快照过期自动发起远端刷新；远端刷新保留给下拉刷新、登录态变化和会员中心等明确场景。
- `HomePage` 与 `ReadingRecordsPage` 审计确认没有书源、同步、图库、缓存统计初始化；统计数据只在对应页面 stream 中加载。

## 4. Phase 2：书架链路分阶段加载

目标：

- 书架作为核心入口优先可见。
- 标签、分类、封面、最新章节、在线刷新等附加信息延后或按能力关闭。

范围：

- `/bookshelf`
- `/local-library`
- `/book/:bookId`
- `/local/book/:bookId`

任务：

- [x] 将书架加载拆成 `基础列表加载`、`本地展示补齐`、`低优先级后台刷新` 三层。
- [x] 基础列表只包含书名、作者、封面引用、阅读入口需要的最小字段。
- [x] 标签、分类、排序统计和展示态缓存放到基础列表之后加载。
- [x] 封面加载增加可见范围策略和并发预算，避免首屏请求/解码过多封面。
- [x] 在线最新章节刷新在 `supportsSourceRuntime=false` 时不启动。
- [x] 本地书库页进入后再扫描导入状态、重索引状态和文件能力。
- [x] 书籍详情页本地图书先显示本地 metadata，目录、封面编辑、重索引按用户动作加载。

验收：

- [x] 书架 1000 本基础列表可先显示，不等待标签分类和在线刷新。
- [x] 书源能力关闭时，书架不启动在线详情/最新章节刷新。
- [x] 桌面和 Web 首屏没有因为封面或分类补齐出现白屏。

执行记录：

- `BookshelfPage` 现在基础书架列表先完成首屏可见，标签、分类、source type、展示态、进度和章节缓存进入首屏后补齐。
- `CoverImageDiskCache` 增加下载并发闸门，同一时刻最多 4 个封面下载；书架封面传入 `cacheWidth/cacheHeight`，按显示尺寸和设备像素比解码。
- `supportsSourceRuntime=false` 时，书架跳过 source type map 和在线最新章节刷新。
- `LocalLibraryPage`、本地书详情和封面/重索引能力经由用户进入页面或明确操作触发，未进入主 Tab 首屏链路。

## 5. Phase 3：阅读链路按需启动

目标：

- 阅读器只在用户打开章节时启动。
- 阅读页先显示可读内容，再补齐设置、背景、分页、图片等附加能力。

范围：

- `/reader/:bookId/:chapterId`
- `/local/reader/:bookId/:chapterId`
- `/stats`
- `/read-records`

任务：

- [x] 本地阅读入口优先走本地章节和缓存，不触发在线 source 读取链。
- [x] 阅读设置恢复分层：必要设置先读，外观背景、字体资源、视觉覆盖延后校正。
- [x] 目录、书签、章节缓存 sheet 只在打开对应面板时加载。
- [x] 阅读正文中的图片按可见范围加载，避免章节打开时一次性请求/解码全部图片。
- [x] 阅读统计页不预初始化阅读器依赖，只保留打开阅读的 route resolver。

验收：

- [x] 打开本地章节不依赖书源运行时。
- [x] 阅读首屏先可读，背景和附加视觉可后补但不能闪烁严重。
- [x] 长章节和含图章节不会在打开时一次性解码全部资源。

执行记录：

- 阅读器 bootstrap 保留必要设置、进度和正文加载在首屏路径；字体注册、背景图库、最近颜色、系统开关等 warmup 改为正文可见后触发。
- 本地阅读 route 已在路由层补本地 `sourceId/detailUrl/chapterUrl`，在线章节在 `supportsSourceRuntime=false` 时显示 disabled，不创建在线读取链。
- 文本、分页和漫画视图继续使用 `ListView.builder` / `PageView.builder`，图片只在可见 item 构建时加载，并沿用解码预算。

## 6. Phase 4：我的与管理页懒初始化

目标：

- 我的页是入口聚合，不是管理功能初始化器。
- 低频页面全部进入后再加载。

范围：

- `/mine`
- `/appearance`
- `/appearance/reader-background`
- `/appearance/launch-image`
- `/appearance/launch-image/editor`
- `/appearance/advanced-themes`
- `/appearance/advanced-themes/editor`
- `/bottom-nav-icon-galleries`
- `/bottom-nav-icon-galleries/editor`
- `/cover-galleries`
- `/cover-galleries/editor`
- `/cache`
- `/mine/tags`
- `/mine/categories`
- `/membership`
- `/about`
- `/system-settings`
- `/font-management`
- `/bookmarks`
- `/error-center`
- `/feedback`
- `/feedback/:id`
- `/feedback/compose`

任务：

- [x] `MinePage` 只读取入口配置和快照，不预加载管理页列表数据。
- [x] 高级主题列表进入后加载；编辑器不由列表页提前创建。
- [x] 启动图集、封面图库、底栏图标库进入后再扫描资源。
- [x] 缓存管理进入后再统计缓存体积。
- [x] 错误中心、反馈列表进入后再查询数据。
- [x] 书签页进入后再查询书签；我的页不预查询。
- [x] 标签管理、分类管理保持在数据标题下，但只在进入管理页后加载。

验收：

- [x] 打开我的页不会触发图库扫描、缓存统计、反馈列表请求。
- [x] 管理页返回我的页不会强制刷新所有入口数据。
- [x] 低频页面独立失败时不影响核心书架、阅读、统计。

执行记录：

- `MinePage` 审计确认只读取 session / 权益 / 模块快照和入口配置，不预加载图集、缓存、反馈、书签或管理页列表。
- `/appearance` 从“进入即加载背景和字体资源”改为按 section 和用户动作加载：背景页才加载背景资源，字体选择面板打开前才加载字体列表。
- 高级主题、启动图集、封面图库、底栏图标库、缓存管理、错误中心、反馈、书签、标签/分类管理均保持进入具体页面后加载。

## 7. Phase 5：Feature-gated 页面轻量化

目标：

- 书源、发现、搜索、同步默认不参与首版核心加载。
- 能力关闭时，页面只创建轻量占位，不创建真实业务页面和运行时依赖。

范围：

- `/discover`
- `/search`
- `/source`
- `/source/login`
- `/source/web-login`
- `/source/script-editor`
- `/source/paste-import`
- `/sync`
- `/sync/history`

任务：

- [x] 统一 `FeatureDisabledPage` 文案模型，按能力生成标题、说明和返回路径。
- [x] `supportsSourceRuntime=false` 时，发现、搜索、书源页面不初始化真实 service。
- [x] `supportsWebDavSync=false` 时，同步设置和同步历史不初始化同步 service。
- [x] 主导航隐藏不可用发现 Tab，直接深链访问时显示轻量 disabled。
- [x] 书源 debug、登录、编辑、导入这些非 GoRouter 页面在能力关闭时不可触发。

验收：

- [x] 默认首版配置下，进入书源/搜索/发现/同步只显示占位，不报错、不白屏。
- [x] 关闭能力时没有相关网络请求、WebView 初始化、脚本运行时初始化。
- [x] 开启能力后，原页面仍可进入。

执行记录：

- 新增 `FeatureDisabledPages` 统一维护发现、在线搜索、书源、同步、在线详情和在线章节的禁用文案。
- `/discover`、`/search`、`/source*`、`/sync*` 能力关闭时统一返回轻量 disabled 页面，不创建真实业务页。
- `/book/:bookId` 在线详情和 `/reader/:bookId/:chapterId` 在线章节也接入统一禁用预设。

## 8. Phase 6：验证与回归基线

目标：

- 每个阶段完成后都有明确验证，不靠肉眼猜。

任务：

- [ ] 建立路由覆盖检查：所有 `routes.dart` 的 path 都出现在全局页面清单。
- [ ] 建立首屏请求检查：冷启动进入 `/home`、`/bookshelf` 不出现书源/同步/图库/缓存统计请求。
- [ ] 建立低端设备验证：Android 低内存设备书架滚动、阅读打开、我的页打开不明显卡顿。
- [ ] 建立 Web 验证：默认能力关闭时 `/bookshelf`、`/mine`、`/search`、`/source`、`/sync` 不白屏。
- [ ] 建立桌面验证：macOS/Windows/Linux 打开书架、详情、管理页不触发移动端专属能力异常。
- [ ] 建立文档回填规则：完成阶段后勾选本文，并在页面清单补状态说明。

验收：

- [ ] 有一套可重复执行的手工或自动化验证清单。
- [ ] 每个阶段完成后有记录，不出现“代码改了但文档不知道”的情况。

## 9. 推荐执行顺序

先执行：

1. Phase 0：先把规则写进架构约束。
2. Phase 1：主导航首屏瘦身。
3. Phase 2：书架链路分阶段加载。

随后执行：

4. Phase 5：能力开关页面轻量化。
5. Phase 4：我的与管理页懒初始化。
6. Phase 3：阅读链路按需启动。
7. Phase 6：统一验证基线。

说明：

- Phase 2 放在前面，是因为书架是主入口，收益最大。
- Phase 5 可提前，是因为书源和同步已经不属于首版核心，轻量化风险低。
- Phase 3 涉及阅读器核心体验，建议在书架基础加载稳定后再做，避免同时动两个核心链路。
