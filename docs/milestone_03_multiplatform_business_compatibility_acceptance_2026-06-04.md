# 里程碑 03：核心业务链多端兼容与验收

创建日期：2026-06-04

状态：待执行。

适用平台：Android、iOS、Web JS、macOS、Windows、Linux。

核心目标：把登录、搜索、详情、在线阅读、书架、设置等核心业务链按多端兼容和测试验收执行。一个任务不是“Web / Desktop 能点通”就算完成，而是移动端、Web、Desktop 的业务设计、状态、降级、测试和未验证原因都要清楚。

后续执行规则：每次只领取一个最小任务编号，例如 `M3-02-03`。

## 1. M3-01 业务链基线盘点

- [x] M3-01-01 列出登录、注册、会话恢复、退出登录的入口、状态、存储和失败路径。
- [x] M3-01-02 列出搜索、发现、书籍详情、目录、开始阅读的入口和状态路径。
- [x] M3-01-03 列出在线阅读章节加载、进度保存、设置、目录跳转、返回栈路径。
- [x] M3-01-04 列出书架、继续阅读、筛选排序、分类、批量选择路径。
- [x] M3-01-05 列出设置、资料、主题、反馈、远程访问等我的页业务路径。
- [x] M3-01-06 为每条链记录 Android、iOS、Web JS、macOS、Windows、Linux 的已知能力差异。

### M3-01 执行记录（2026-06-04）

#### M3-01-01 登录、注册、会话恢复、退出登录入口和状态路径

| 环节 | 入口 / 路由 | 状态 / Service | 失败 / 降级路径 | 后续手测关注 |
| --- | --- | --- | --- | --- |
| 登录 / 注册 | `/auth` 路由进入 `AuthPage`；根路径 `/` 在桌面端会按预热 session 分流到 `/auth` 或我的页目标；我的页未登录入口可进入登录页。 | `AuthPage` 使用 `authServiceProvider`、`authFormValidationServiceProvider`；表单状态包含登录 / 注册模式、提交中、密码显示、错误消息和自动校验。 | 空账号、空密码、确认密码不一致、接口失败都停留在登录页并展示错误；提交中禁用重复提交；注册成功和登录成功都写入会话。 | Android / iOS 测软键盘、输入框不遮挡、登录 / 注册切换；Web 测刷新和浏览器返回；Desktop 测回车提交、Tab 焦点、窄窗口滚动。 |
| 会话保存 / 恢复 | `AuthService.loginAndStore` / `registerAndStore` 写入 `AuthSessionStore`；`AuthSessionSnapshotBootstrap` 为桌面根路径提供同步 display cache / fallback secret 判断。 | 移动端优先 `FlutterSecureAuthSessionSecretStore`；Web 和桌面走 `SharedPreferencesAuthSessionSecretStore` fallback；`AuthSessionStore` 保留 legacy prefs token 迁移。 | secure storage 不可用时 fallback 到 prefs；legacy 迁移成功后清理旧 key；刷新 access token 失败时由 `AuthTokenRefresherImpl` 区分临时失败和服务端拒绝。 | 六端都要测重启后恢复；Web / Desktop 重点确认 fallback 存储不会出现“退出后又恢复”。 |
| 退出登录 | `/profile` 进入 `UserProfilePage`；退出按钮调用 `AuthService.logout()`，然后清理用户作用域缓存并 `context.go('/mine')`。 | 退出中状态 `_isLoggingOut` 防止重复点击；成功后清空 `_session`、`_profile`；Auth event bus 广播 loggedOut / sessionExpired。 | 服务端退出失败时展示“退出失败，请稍后再试。”；服务端失败不应造成 UI 卡死；会话过期会触发全局跳登录。 | Android / iOS / Web / macOS / Windows / Linux 都要测退出后重启不恢复、受保护入口回到未登录。 |

#### M3-01-02 搜索、发现、书籍详情、目录、开始阅读入口和状态路径

本阶段只做链路盘点和后续手测基线，不改业务代码，不运行桌面构建；因此本任务不触发“桌面构建后必须同步 Android / iOS 构建记录”的规则。

| 环节 | 入口 / 路由 | 状态 / Service | 失败 / 降级路径 | 后续手测关注 |
| --- | --- | --- | --- | --- |
| 搜索入口 | `/search`；底部 dock 可带 `/search?entry=dock`；书架顶部入口可带 `/search?entry=bookshelf_top`。路由在 `lib/features/search/routes.dart`，不同 `entry` 决定无转场、反向淡出缩放或普通 fade。 | 页面为 `SearchPage`；页面状态集中在 `SearchPageState` / `SearchPageStateNotifier`，包含搜索中、源数量加载、搜索会话、内容模式、精确匹配、按书名作者聚合、选中源、追加加载、进度 UI、会员在线搜索权限、搜索历史等字段。搜索执行使用 `ServerOnlineSearchService`，历史使用 `SearchHistoryService`。 | 空关键词只提示不请求；在线搜索权限未通过时走会员 / 权限提示；搜索失败展示错误消息；搜索中可取消；源筛选失败或无源时要保留可理解状态；历史记录读取失败不能阻塞搜索页打开。 | Android / iOS 重点测软键盘提交、焦点和返回；Web 重点测刷新后页面仍可打开、浏览器返回；Desktop 重点测物理键盘回车、宽窄窗口布局、搜索中取消和列表滚动。 |
| 搜索到详情 | 搜索结果点击调用 `buildBookDetailRoute(...)` 生成 `/book/:bookId`，通过 `context.push(route, extra: book)` 进入详情。 | 初始 `Book` 通过 `extra` 传递给详情页，用于首屏元数据和封面展示；路由 query 同步携带 `sourceId`、`detailUrl`、`title`、`author`、`coverUrl`、hero tag 和 reveal transition。 | Web 刷新或直接打开详情页时可能没有 `extra`，必须依赖 route query 和详情 service 重新加载；缺少 `sourceId` / `detailUrl` 时只能显示降级信息或无法开始阅读。 | 六端都要测“从搜索进详情”和“详情页刷新 / 重启直接进详情”的差异；Web 特别测 URL 编码后的中文书名、作者和 detailUrl。 |
| 发现入口 | `/discover` 为 shell 分支入口；分类书籍为 `/discover/source/:sourceId/category/:categoryId`，路由在 `lib/features/discover/routes.dart`。 | `DiscoverPage` 监听 `discoverSourcePagerProvider`；页面本地维护搜索框、滚动加载、展开源、远程搜索关键字和远程搜索 async 状态。分类页依次依赖 `discoverSourcePagerProvider`、`discoverSourceCategoriesProvider`、`discoverCategoryBooksProvider`。 | 发现源加载中 / 失败 / 空态使用统一 loading、error、empty UI；本地筛选为空时不能误判远程源不可用；远程搜索失败需要保留当前列表或展示可重试状态；分类源或分类缺失时进入 missing-category 降级。 | 移动端测下拉/滚动和分类返回；Web 测浏览器刷新分类 URL；Desktop 测宽屏列表、滚轮触发分页、分类页返回 shell 后状态是否合理。 |
| 发现到详情 | 分类书籍页点击书籍时构建初始 `Book`，调用 `buildBookDetailRoute(...)` 后 `context.push(route, extra: initialBook)`。 | 分类列表数据来自 `discoverCategoryBooksProvider`，详情页首屏依赖 extra + route query，随后由详情 service 补完整元数据和目录能力。 | 分类结果为空显示空态；分类接口失败显示错误并允许重新加载；进入详情后如果源被删除、detailUrl 无效或服务端返回不完整，详情页必须展示错误 / 降级，而不是卡死。 | 六端都要测“发现首页 -> 分类 -> 详情 -> 返回分类 -> 返回发现”的返回栈；Web 额外测分类页和详情页直接 URL 打开。 |
| 书籍详情 | `/book/:bookId`，路由名 `book`，定义在 `BookDetailRouteData`；query 包含 `sourceId`、`detailUrl`、`title`、`author`、`coverUrl`、hero tag、`transition=reveal`。 | `BookDetailPage` 维护 `_BookDetailPresentationState` 和 `_BookDetailAuxiliaryState`，覆盖详情加载、目录加载、错误、目录警告、加载结果、书架状态、本地书籍元数据和高级选项。`BookDetailService.load` 返回 `BookDetailLoadResult`，包含 detail、chapters、sourceName、tocFromCache、tocError、catalogAvailable、catalogLoaded、catalogComplete。 | sourceId / detailUrl / bookId 缺失、源不存在、网关失败、目录失败、缓存目录警告、无目录、无可读章节都需要单独可见；详情缓存有 20 分钟 TTL，后续改动要避免旧缓存遮住新状态。 | 移动端测首屏、加入书架、更多操作和浮动开始阅读；Web 测刷新恢复、URL query 恢复；Desktop 测宽屏布局、鼠标滚动、键盘返回和弹层位置。 |
| 目录 | 详情页“查看目录”动作进入 `_handleOpenCatalogAction()`；目录加载通过 `_ensureCatalogLoaded()` 和 `_ensureFirstReadableCatalogBatch()`；展示使用目录 sheet / catalog UI。 | 目录能力由 `BookDetailLoadResult.catalogAvailable`、`catalogLoaded`、`catalogComplete`、`tocError` 决定；目录搜索、展示章节和缓存逻辑下沉在 `BookDetailCatalogService`。 | 目录加载失败提示“目录加载失败，请稍后重试。”；无目录提示“当前书籍暂无目录。”；目录只有卷标题或空 chapterUrl 时不能作为可读章节；部分目录可用时允许先读首批并后台补全。 | Android / iOS 测 sheet 高度、触控选择、返回关闭；Web / Desktop 测滚轮、键盘焦点、宽屏弹层、目录加载中再次点击。 |
| 开始阅读 | 详情页浮动按钮触发 `_handleStartReading()`；有可读章节时打开首个章节；目录未加载但可用时先拉取首个可读批次；否则使用 bootstrap fallback route。 | 可读章节和阅读 route 由 `BookDetailReadRouteService` 与 `ReaderEntryRouteResolver` 生成；最终进入 `/reader/:bookId/:chapterId`，query 可携带 `chapterUrl`、`chapterTitle`、`sourceId`、`detailUrl`、`chapterIndex`、`bookmarkId`、`openRequestedAtMs`、`openRouteKind`、`heroTag`。旧本地书路径 `/local/reader/:bookId/:chapterId` 会重定向到标准 reader route。 | 300ms 内重复点击会被节流；sourceId / detailUrl 缺失时不生成 route；目录不可用且 fallback 为空时不跳转；无可读正文章节时提示“当前目录没有可阅读的正文章节。”；本地旧路由必须能补全 local source/detail/chapter URL。 | 六端都要测详情页开始阅读、目录选择章节阅读、返回详情、旧本地阅读 URL；Web 重点测刷新 reader URL；Desktop 重点测键盘和鼠标进入阅读后的焦点不丢。 |

后续执行 M3-03 搜索、发现与详情链时，建议按下面的小任务拆分验证，不要把“搜索链”一次性做成一个大任务：

- [ ] 从 `/search`、`/search?entry=dock`、`/search?entry=bookshelf_top` 分别进入，验证输入、历史、筛选、搜索中取消、空态、失败态。
- [ ] 从搜索结果进入 `/book/:bookId`，验证有 `extra` 和无 `extra` 两种详情恢复路径。
- [ ] 从 `/discover` 进入分类 `/discover/source/:sourceId/category/:categoryId`，验证分页、刷新、缺源 / 缺分类降级。
- [ ] 从分类书籍进入详情，验证返回栈、query 编码、源删除 / detailUrl 失效提示。
- [ ] 在详情页验证元数据、目录加载、目录失败、无目录、无可读章节、加入书架和换源边界。
- [ ] 从详情页“开始阅读”进入 `/reader/:bookId/:chapterId`，验证首章、fallback bootstrap、本地旧路由重定向和 Web 刷新恢复。
- [ ] 每个小任务都分别记录 Android、iOS、Web JS、macOS、Windows、Linux 的通过、未测或阻塞原因。

#### M3-01-03 在线阅读章节加载、进度保存、设置、目录跳转、返回栈路径

| 环节 | 入口 / 路由 | 状态 / Service | 失败 / 降级路径 | 后续手测关注 |
| --- | --- | --- | --- | --- |
| 阅读入口 | 标准入口 `/reader/:bookId/:chapterId`；本地旧入口 `/local/reader/:bookId/:chapterId` 重定向到标准 reader route。 | `ReaderRouteData` 解析 `chapterUrl`、`sourceId`、`detailUrl`、`chapterIndex`、`bookmarkId`、`openRouteKind` 等 query；`ReaderContentSession` 承载内容模式、章节、目录、进度和阅读记录 session。 | bookId / chapterId 缺失时落到 unknown 占位；本地旧入口会补齐 local source/detail/chapter URL；远程章节缺 sourceId/detailUrl 时只能显示加载失败或降级提示。 | 六端测从详情开始阅读、从目录进章节、从书架继续阅读、直接打开 reader URL。 |
| 章节加载 | `ReaderPage` 按 route 和 progress bootstrap 加载章节正文、目录和相邻章节；正文模式由 `ReaderContentMode` 区分 text、hybrid、comic、audio。 | `ReaderSessionState` 记录当前章节、逻辑位置、可见位置、viewport session、渲染模式、自动阅读和章节切换状态。 | 网络失败、章节正文为空、PDF / EPUB / 图片 / 音频资源不可用时必须展示可理解状态；本地文件缺失要走本地 guard。 | 移动端测触控翻页 / 滚动；Web 测刷新恢复；Desktop 测键盘、鼠标滚轮、窗口缩放。 |
| 进度保存 | `_saveProgress()` 通过 `ReaderPreferencesService.saveProgress` 保存当前 book/chapter/offset/page/viewport；运行时用 debounce 合并频繁保存。 | `ReaderViewportSession` 保存分页、滚动、缩放、音频位置等多内容模式进度；书架继续阅读依赖同一进度实体。 | 快速翻页、章节切换、退出页面时不能丢最后进度；保存失败不能阻塞阅读，但后续验收要能看出继续阅读是否回退。 | 六端测读几页后返回书架继续阅读，重启后继续阅读位置不回退。 |
| 设置 / 目录 | 阅读页设置弹层由 `_showSettingsSheet()` 打开；目录由 `_openCatalogSheetFromOverlay()` / `showReaderCatalogSheet` 打开并跳转章节。 | 设置草稿即时持久化，包含字体、行距、边距、主题、翻页动画、自动阅读等；目录搜索由 `ReaderCatalogSearchService` 和 `ReaderNavigationEntryResolver` 处理。 | 自定义字体 / 背景资产缺失时要回退；仿真翻页等动画在不同平台要符合 capability；目录跳转要避免重复章节切换。 | 移动端测 sheet、手势和安全区；Web / Desktop 测滚轮、键盘焦点和弹层高度。 |
| 返回栈 | Reader 从详情 / 书架 / 目录进入后使用 GoRouter 返回；旧本地路由重定向后仍要能返回业务入口。 | `openRouteKind`、`bookmarkId`、`heroTag` 辅助恢复入口语义和动画。 | Web 直接刷新 reader 后没有上一个页面时，返回应回到合理 shell 入口，不应白屏。 | Web 重点测浏览器后退；Desktop 测 Esc / 系统返回习惯；移动端测系统返回键。 |

#### M3-01-04 书架、继续阅读、筛选排序、分类、批量选择路径

| 环节 | 入口 / 路由 | 状态 / Service | 失败 / 降级路径 | 后续手测关注 |
| --- | --- | --- | --- | --- |
| 书架入口 | `/bookshelf` shell 分支；本地书库 `/local-library`；旧本地详情 `/local/book/:bookId` 重定向到 `/book/:bookId` 并补 local query。 | `BookshelfPage` 使用 `BookshelfService`、`BookshelfPageState`、`BookshelfPresentationQueryService`；页面本地维护搜索、排序、视图、滚动、导入和选择状态。 | 书架加载失败、空书架、筛选后为空分别展示不同状态；本地导入失败通过任务 overlay / error 文案反馈。 | 六端测书架打开、空态、已有书加载、返回后滚动位置。 |
| 继续阅读 | 书架卡片使用阅读进度打开 reader；详情页加入书架后回到书架也应保留进度。 | `BookshelfReaderOpenService` 和 `BookshelfPageRouteService` 负责继续阅读 / 详情 route；进度来自 `ReaderPreferencesService`。 | 旧进度章节不存在、本地文件移动、sourceId/detailUrl 缺失时要降级到详情或首章，不应直接崩溃。 | 六端测读几页后返回书架，再点击继续阅读位置是否一致。 |
| 筛选排序 / 分类 | 书架搜索框、本地 quick filter、标签 `/mine/tags`、分类 `/mine/categories`。 | 排序和展示设置持久化到 `BookshelfService`；标签 / 分类 map、order、items 用于 badge 和筛选。 | 筛选无结果展示 filter empty；标签 / 分类缺失时不影响基础书架打开。 | 移动端测长按 / sheet；Desktop 测菜单、键盘焦点、宽屏密度；Web 测刷新后设置恢复。 |
| 批量选择 | 更多菜单进入选择模式，批量操作由 `BookshelfSelectionState` / `BookshelfBatchAction` 管理。 | 支持选择、取消选择、批量分类 / 标签 / 删除等操作；导入导出任务由 `AppTaskManager` 和任务弹层展示。 | 批量操作失败要保留选择上下文或给出清晰反馈；取消任务要通过 `SessionCancellationHandle` 结束。 | 六端测进入/退出选择模式、批量操作确认框、误触取消。 |

#### M3-01-05 设置、资料、主题、反馈、远程访问等我的页业务路径

| 环节 | 入口 / 路由 | 状态 / Service | 失败 / 降级路径 | 后续手测关注 |
| --- | --- | --- | --- | --- |
| 我的页 / 资料 | `/mine` shell 分支；资料页 `/profile`。 | `MinePage` 展示我的页入口；`UserProfilePage` 使用 `UserProfileService` 和 `AuthSessionStore` 拉取 / 更新资料。 | 未登录进入资料页要引导登录；资料接口失败展示可刷新状态；退出登录清理用户作用域缓存。 | 六端测未登录、登录后资料刷新、退出登录。 |
| 设置 / 外观 | `/system-settings`、`/appearance`、`/appearance/reader-background`、`/font-management`。 | 系统设置、阅读背景、字体和外观配置由对应 service / provider 持久化。 | Web 不支持的文件能力要隐藏、禁用或给出说明；桌面文件选择要走系统文件选择器。 | Android / iOS 测安全区和系统权限；Web 测能力降级；Desktop 测文件选择和窗口宽度。 |
| 高级主题 / 图库 | `/appearance/advanced-themes`、`/appearance/advanced-themes/editor`、启动图、底部导航图标、封面图库相关 route。 | 高级主题由 `advancedThemeServiceProvider`、`activeAdvancedThemeIdProvider`、`activeThemeAppearanceSnapshotProvider` 管理；编辑页有独立 page state。 | 会员能力不足时禁用或提示；主题资产缺失时回退默认快照；编辑未保存退出要避免丢失提示不清。 | 六端测主题启用、禁用、编辑、刷新恢复；Web / Desktop 测颜色选择和文件资产。 |
| 反馈 / 会员 / 远程能力 | `/feedback`、`/feedback/:id`、`/feedback/compose`、`/membership`、远程源登录 `/source/webview-login`。 | `FeedbackService` 依赖 session 发起列表、详情、提交；会员页读取会员功能；源 WebView 登录走 source route。 | 未登录提交反馈要拦截；WebView / 外部登录在 Web 和桌面可能需要 fallback；网络失败要保留草稿或错误提示。 | 六端测反馈列表、提交、详情；Web / Desktop 特别测远程登录能力是否合理降级。 |

#### M3-01-06 六平台已知能力差异

| 业务链 | Android / iOS | Web JS | macOS / Windows / Linux | 留给真实手测确认 |
| --- | --- | --- | --- | --- |
| 登录与会话 | 移动端优先 secure storage，重点是软键盘和系统返回。 | 使用 prefs fallback，重点是刷新恢复、URL 返回、退出后不恢复。 | 使用 prefs fallback；桌面根路径同步分流到 `/auth` 或我的页目标；重点是键盘提交、窗口尺寸、重启恢复。 | M3-02-01、M3-02-02、M3-02-03、M3-02-08。 |
| 搜索 / 发现 / 详情 | 重点是触控、键盘遮挡、底部 sheet、安全区。 | 重点是直接 URL、刷新后无 `extra`、浏览器返回。 | 重点是键盘、鼠标滚轮、宽屏布局、弹层位置。 | M3-03 各端检查。 |
| 阅读 | 重点是触控翻页、系统返回、沉浸式安全区。 | 重点是刷新 reader URL、滚轮和键盘、资源加载降级。 | 重点是窗口缩放、键盘、鼠标、目录 / 设置弹层。 | M3-04 各端检查。 |
| 书架 | 重点是长按、sheet、导入权限。 | 重点是刷新恢复、能力隐藏、导入限制。 | 重点是批量选择、菜单、文件选择、窗口密度。 | M3-05 各端检查。 |
| 我的页 / 设置 | 重点是权限、软键盘和安全区。 | 重点是文件 / WebView 等不支持能力降级。 | 重点是文件选择、打开目录、外部浏览器 / WebView fallback。 | M3-06 各端检查。 |

## 2. M3-02 登录与会话链

- [ ] M3-02-01 检查移动端登录、注册、退出登录、会话恢复是否仍按旧体验工作。
- [ ] M3-02-02 检查 Web 登录后刷新恢复、根路径跳转、未登录拦截和退出登录。
- [ ] M3-02-03 检查 macOS 登录、键盘提交、窗口尺寸、外部浏览器 / fallback 凭证策略。
- [x] M3-02-04 为 Windows 登录路径写代码级影响判断和 CI / 手工补验要求。
- [x] M3-02-05 为 Linux 登录路径写代码级影响判断和 CI / 手工补验要求。
- [x] M3-02-06 补 auth form validation / session store 相关测试。
- [x] M3-02-07 为会话存储、凭证 fallback、过期跳转补中文维护注释。
- [ ] M3-02-08 输出登录链六平台验收记录。

### M3-02 执行记录（2026-06-04）

#### M3-02-04 Windows 登录路径代码级影响判断

- 登录入口：`/auth` 路由进入 `AuthPage`；个人资料页未登录状态通过 `context.push('/auth')` 进入登录页。
- 表单路径：Windows 被 `AppLayout.isDesktopLike` 归入桌面布局；宽屏使用桌面双栏 / 单栏 surface，窄窗回落为滚动表单，不依赖移动端键盘 inset 行为。登录密码框和注册确认密码框保留 `TextInputAction.done` 与 `onFieldSubmitted => _submit()`，Windows 物理键盘回车提交路径可用。
- 服务路径：`AuthPage` 通过 `authServiceProvider` 调用 `AuthService.loginAndStore` / `registerAndStore`；成功后写入 `AuthSessionStore` 并触发登录事件，失败时保留 inline error。
- Windows 会话存储：`createDefaultAuthSessionSecretStore` 在 Windows 走 `SharedPreferencesAuthSessionSecretStore` fallback，不依赖移动端 secure storage 插件；`AuthSessionStore` 仍保留旧 prefs token 迁移逻辑，便于历史版本升级。
- 代码级风险：Windows fallback token 存在 SharedPreferences，不等价于 OS 凭据库；发布前需要确认后端 token 时效和退出登录清理策略足够保守。当前登录链没有外部浏览器 OAuth 分支，Windows 不需要额外 browser callback 验证。
- CI 要求：至少运行 `flutter test test/features/auth/application/auth_form_validation_service_test.dart test/core/auth/auth_session_store_test.dart test/core/auth/auth_service_test.dart`；Windows 构建机需开启 Developer Mode 或具备 symlink 权限。
- 手工补验要求：Windows Release 或 Debug 启动后，依次补验登录页打开、账号/密码空值校验、回车提交、登录失败 inline error、登录成功会话恢复、退出登录后会话清理、重启应用后未过期 session 仍可恢复。

#### M3-02-06 测试补充

- `auth_form_validation_service_test.dart` 增加 required trim、可选新密码长度、空格密码当前行为、确认密码边界覆盖。
- `auth_session_store_test.dart` 增加安全存储 access token 优先、legacy refresh / 过期时间补缺迁移、禁用 legacy fallback 时不读取也不清理旧凭证的覆盖。
- 执行结果：`flutter test test/features/auth/application/auth_form_validation_service_test.dart test/core/auth/auth_session_store_test.dart test/core/auth/auth_service_test.dart` 通过。

#### M3-02-05 Linux 登录路径代码级影响判断

- 登录入口：Linux 与其他桌面端一样通过 `/auth` 路由进入 `AuthPage`；根路径 `/` 在 `resolveAppRootStartupLocation` 中被 `AppLayout.isDesktopLike` 归入桌面同步分流。
- 表单路径：Linux 使用桌面布局，宽屏双栏，窄窗滚动表单；账号和密码输入保留 `TextInputAction.done` 与 `onFieldSubmitted => _submit()`，物理键盘回车提交路径与 macOS / Windows 一致。
- 服务路径：登录 / 注册仍走 `AuthService.loginAndStore` / `registerAndStore`，成功后写入 `AuthSessionStore`，失败时保留 inline error。
- Linux 会话存储：`createDefaultAuthSessionSecretStore` 在非 Android / iOS 环境走 `SharedPreferencesAuthSessionSecretStore` fallback，不依赖 Linux secret service、gnome-keyring 或 KDE wallet；这保证能运行，但安全等级不等同移动端 secure storage。
- 代码级风险：Linux 发行版、桌面环境和权限差异较大，当前判断只覆盖 Flutter 应用层路径；发布前需要在目标 Linux 机器补验窗口缩放、回车提交、登录成功、退出清理、重启恢复。
- CI / 构建要求：Linux 构建机需要 Flutter Linux desktop 依赖齐全；如执行 `flutter build linux`，按项目规则必须同步记录 Android / iOS 构建结果或真实阻塞原因。

#### M3-02-07 中文维护注释

- `auth_session_secret_store.dart` 补充桌面 / Web fallback secret store 的维护说明，明确 Windows / Linux / macOS 不假设 secure storage 与移动端等价。
- `auth_session_store.dart` 补充 legacy prefs token 迁移说明，明确新 secret store 的 access token 优先，迁移成功后清理旧 key。
- `auth_token_refresher_impl.dart` 补充刷新失败清理条件说明，明确只有服务端拒绝凭证才广播 session expired。
- `router.dart` 和 `app.dart` 补充桌面冷启动同步分流、过期后全局跳登录的维护说明。

#### M3-02 手动验收留存项

下面这些是必须在真实端操作 UI 才能打勾的任务，代码级盘点、测试和维护注释已经由前置任务完成。

| 任务 | 平台 | 手动验证步骤 | 通过标准 |
| --- | --- | --- | --- |
| M3-02-01 | Android / iOS | 1. 未登录打开 App 进入登录页；2. 空账号 / 空密码提交；3. 错误密码提交；4. 正确账号登录；5. 关闭重开；6. 退出登录；7. 再次关闭重开。 | 表单错误清晰；错误密码不登录；正确登录后重启可恢复；退出后重启不恢复；软键盘不遮挡输入框和按钮。 |
| M3-02-02 | Web JS | 1. 打开 Web 登录页；2. 空表单、错误密码、正确登录各测一次；3. 登录后刷新；4. 新标签打开当前 URL；5. 退出后刷新；6. 浏览器后退 / 前进。 | 刷新和新标签能恢复已登录；退出后不恢复；浏览器返回不会出现登录态错乱；未登录受保护入口会回登录或未登录状态。 |
| M3-02-03 | macOS | 1. 运行 macOS App；2. 放大 / 缩小登录窗口；3. Tab 切换输入框；4. 回车提交；5. 错误密码和正确登录；6. 关闭重开；7. 退出后重启。 | 桌面布局不溢出；键盘焦点和回车提交正常；会话恢复和退出清理正常。 |
| M3-02-08 | Android / iOS / Web JS / macOS / Windows / Linux | 汇总各端登录、注册、会话恢复、退出登录结果；不能真实验证的平台写明机器、命令、阻塞原因和发布前补验方式。 | 六平台都有“通过 / 未测 / 阻塞”明确记录，才能最终打勾。 |

#### M3-02-08 登录链六平台验收记录（待手测汇总）

| 平台 | 当前状态 | 已完成的代码级记录 | 等待用户手动确认 |
| --- | --- | --- | --- |
| Android | 待手测 | 登录 / 注册 service、移动端表单、secure storage 路径已纳入 M3-01-01 和 M3-02-06。 | 登录成功 / 失败、注册、重启恢复、退出后不恢复、软键盘。 |
| iOS | 待手测 | 登录 / 注册 service、移动端表单、secure storage 路径已纳入 M3-01-01 和 M3-02-06。 | 登录成功 / 失败、注册、重启恢复、退出后不恢复、软键盘。 |
| Web JS | 待手测 | Web fallback secret store、根路径和会话恢复路径已纳入 M3-01-01 / M3-02-07。 | 刷新恢复、新标签、浏览器返回、退出后刷新不恢复。 |
| macOS | 待手测 | 桌面布局、根路径同步分流、fallback secret store 已纳入 M3-01-01 / M3-02-07。 | 回车提交、窗口缩放、登录成功 / 失败、重启恢复、退出清理。 |
| Windows | 待手测 | 代码路径完成影响判断；`AuthPage` 桌面布局、键盘提交、`AuthService`、`AuthSessionStore`、Windows fallback secret store 均有可追踪路径；本次补充 auth form validation 和 session store 单测；历史记录中 Windows 构建曾通过。 | 需要连接真实后端或可控 mock 后端，在 Windows UI 上手工补验登录成功、失败、退出、重启恢复。 |
| Linux | 待手测 | M3-02-05 已完成 Linux 代码级影响判断，确认走桌面布局和 prefs fallback secret store。 | 在目标 Linux 机器补验登录页、回车提交、窗口缩放、登录成功 / 失败、重启恢复、退出清理。 |

## 3. M3-03 搜索、发现与详情链

- [ ] M3-03-01 检查移动端搜索输入、历史、筛选、空态、失败重试。
- [ ] M3-03-02 检查 Web 搜索刷新恢复、路由参数、浏览器返回和网络失败展示。
- [ ] M3-03-03 检查 Desktop 搜索键盘提交、宽屏列表、详情打开和返回栈。
- [ ] M3-03-04 检查书籍详情元数据、目录、加入书架、换源、开始阅读的 service 边界。
- [ ] M3-03-05 补搜索 / 详情 provider 或 service 测试。
- [ ] M3-03-06 运行 route inventory 和 route string guard。
- [ ] M3-03-07 输出搜索详情链六平台验收记录。

## 4. M3-04 在线阅读链

- [ ] M3-04-01 检查移动端触控翻页、滚动、目录、设置、进度保存不回退。
- [ ] M3-04-02 检查 Web 键盘、滚轮、刷新恢复、章节加载和不支持能力降级。
- [ ] M3-04-03 检查 macOS 键盘、鼠标、窗口宽度、目录和设置弹层。
- [ ] M3-04-04 为 Windows / Linux 阅读链写补验要求，不能用 macOS 代替。
- [ ] M3-04-05 补阅读器 session / progress / route helper 相关测试。
- [ ] M3-04-06 为阅读进度、章节定位、刷新恢复关键逻辑补中文维护注释。
- [ ] M3-04-07 输出在线阅读链六平台验收记录。

## 5. M3-05 书架与继续阅读链

- [ ] M3-05-01 检查移动端书架列表、排序、长按、更多入口、继续阅读不回退。
- [ ] M3-05-02 检查 Web 书架刷新恢复、空态、继续阅读和详情跳转。
- [ ] M3-05-03 检查 Desktop 批量选择、菜单、键盘焦点和继续阅读。
- [ ] M3-05-04 补 bookshelf service / page state / migration 相关测试。
- [ ] M3-05-05 检查旧书架数据、阅读进度、书签、分类不会因兼容治理丢失。
- [ ] M3-05-06 输出书架链六平台验收记录。

## 6. M3-06 设置、主题与我的页链

- [ ] M3-06-01 检查移动端设置、主题、资料、反馈、远程访问入口不回退。
- [ ] M3-06-02 检查 Web 不支持能力是否隐藏、禁用或提供替代说明。
- [ ] M3-06-03 检查 Desktop 文件选择、保存、分享、打开目录等行为是否符合桌面习惯。
- [ ] M3-06-04 补高级主题、资料、反馈、设置相关 service / provider 测试。
- [ ] M3-06-05 输出我的页链六平台验收记录。

## 7. M3 验收

- [ ] M3-07-01 每条核心业务链都有六平台影响记录。
- [ ] M3-07-02 没有条件真实验证的平台写明原因和发布前补验方式。
- [ ] M3-07-03 业务链相关代码遵守 provider、route helper、storage、capability、中文注释规则。
- [ ] M3-07-04 `flutter analyze` 通过或记录阻塞原因。
- [ ] M3-07-05 Web build、目标单测、guard、可用桌面构建或未验证原因记录完整。
- [ ] M3-07-06 如果任一任务跑了 macOS / Windows / Linux 桌面构建，同一任务必须同步记录 Android / iOS 构建结果；无法构建时写明阻塞命令、原因和补验机器。
