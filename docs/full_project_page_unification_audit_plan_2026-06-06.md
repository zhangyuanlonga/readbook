# 全项目页面统一化审计与整改任务

创建日期：2026-06-06  
适用范围：`lib/app`、`lib/features` 下所有页面、路由、桌面壳层、移动端交互、Web / Desktop / Mobile 业务链。  
核心目标：用响应式布局作为实现手段，把项目治理成自适应应用；不同平台共享业务语义，但 UI 结构、入口位置、交互方式和能力降级符合各自平台习惯。

## 0. 执行红线

- [x] 不以“统一化”为名大面积重写稳定移动端页面。
- [x] 不把桌面端窗口布局、侧边栏、顶栏、popover 反向塞进移动端交互路径。
- [x] 不把移动端 bottom sheet、AppBar、底部导航简单拉宽成桌面端体验。
- [x] 不在页面层新增散落的平台判断，优先使用 capability、adapter、facade 或 adaptive 组件。
- [x] 不机械替换成熟稳定实现；只有复杂、重复、不稳定、难维护或不符合平台习惯的实现才进入整改。
- [x] 每次只领取一个最小 checkbox，完成后记录影响平台、测试结果和未验证原因。

## 1. 审计标准

- [x] UI 标准：页面是否使用响应式布局处理可用空间变化，是否达到自适应应用目标。
- [x] 桌面标准：窗口拖拽后侧边栏、顶栏、工具按钮、搜索框、列表列数、详情分栏、弹窗宽度是否合理。
- [x] 移动标准：Android / iOS 触控路径、底部弹层、返回手势、安全区、软键盘和小屏布局是否保持成熟。
- [x] Web 标准：刷新恢复、浏览器尺寸变化、路由深链、不支持能力降级和 Web 存储是否合理。
- [x] 业务标准：同一业务在移动端、Web、Desktop 的状态、权限、缓存、错误、空态和入口语义是否一致。
- [x] 架构标准：页面是否过度手搓，是否应该下沉 service/provider/adapter，是否已有成熟库或项目内通用组件可复用。
- [x] 注释标准：复杂业务、平台分支、兼容读取、能力降级、异步竞态处理必须有标准中文维护注释。
- [x] 验收标准：每个整改任务必须至少跑 `dart analyze` 目标文件；涉及 UI 或平台能力时补对应平台 smoke、构建或未验证说明。

## 2. U0：全量页面与路由清单基线

目标：先知道项目到底有哪些页面、哪些在 shell 内、哪些是独立路由，避免漏审。

- [x] U0-01 复核 `lib/app/router.dart` 中 Shell 路由、独立路由和启动重定向逻辑。
- [x] U0-02 复核书架路由：`/bookshelf`、`/local-library`、`/local/book/:bookId`。
- [x] U0-03 复核在线链路路由：`/search`、`/book/:bookId`、阅读器路由。
- [x] U0-04 复核发现页路由：`/discover`、发现分类详情。
- [x] U0-05 复核我的页与设置路由：`/mine`、外观、主题、图集、字体、会员、反馈、关于、系统设置等页面。
- [x] U0-06 复核账号与公告路由：`/auth`、`/profile`、`/announcements`。
- [x] U0-07 输出页面分组清单：核心高频页、设置管理页、低频能力页、沉浸式页面、平台专属页。
- [x] U0-08 标记每个页面当前使用的骨架：Shell 页面、独立 Scaffold、AdaptivePageScaffold、沉浸式专用 Scaffold。

### U0 执行结论

- 当前主路由由 `lib/app/router.dart` 汇总：根路径 `/` 只做启动重定向，主界面使用 `StatefulShellRoute.indexedStack`，Shell 内实际接入 `书架 / 发现 / 统计 / 我的` 四个一级页。
- 首页运行时入口已删除：`/home` 路由、`HomePage` 页面文件、`AppShellTab.home` 枚举和 `showHome` 导航状态均已清理；历史启动目标、历史导航偏好、历史底部导航图标包里的 `home` 只允许迁移到书架或被清除，不能再恢复首页入口。
- 路由静态基线：`GoRoute(` 命中 39 处；`class *Page` 粗略命中 44 处，包含部分非 Widget 分页模型；`Scaffold(` 命中 49 处，`AdaptivePageScaffold(` 命中 1 处。
- 书架链路：`/bookshelf` 是 Shell 一级页；`/local-library` 是独立本地书库页；`/local/book/:bookId` 会补齐本地 source/detail 参数并重定向到统一 `/book/:bookId` 详情页。
- 在线阅读链路：`/search` 是独立在线搜索页；`/book/:bookId` 是统一详情页；`/reader/:bookId/:chapterId` 是统一阅读器路由；`/local/reader/:bookId/:chapterId` 会重定向到统一阅读器路由；`/read-records` 兼容重定向到 Shell 内 `/stats`。
- 发现链路：`/discover` 是 Shell 一级页；`/discover/source/:sourceId/category/:categoryId` 是发现分类详情，当前挂在发现分支下。
- 我的与设置链路：`/mine` 是 Shell 一级页；外观、阅读背景、启动图集、高级主题、底部导航图标、封面图集、标签分类管理、会员、关于、系统设置、字体、书签、错误中心、反馈等均为独立路由。
- 账号与公告链路：`/auth`、`/profile` 为独立账号页；`/announcements`、`/announcements/:id` 为独立公告页。
- 页面分组基线：核心高频页为书架、搜索、详情、阅读器、我的、统计；设置管理页集中在 mine routes；低频能力页包括公告、反馈、关于、错误中心；沉浸式页面主要是阅读器；平台专属或能力敏感页包括 source webview login、字体管理、本地书库、资源图集和高级主题相关页面。
- 页面骨架基线：Shell 页面由 `ShellScaffold` 包裹；多数独立页面仍直接使用 `Scaffold`；阅读器保留沉浸式专用 scaffold；当前 `AdaptivePageScaffold` 接入较少，后续 U6 应按收益逐页治理，不能机械批量替换。

## 3. U1：桌面壳层与全局导航统一化

目标：桌面端外部 UI 已确认方向，下一步只审计响应式细节和职责边界。

- [x] U1-01 审计 `ShellScaffold` 的侧边栏宽度分档，确认窄窗口、常规桌面、宽屏桌面是否合理。
- [x] U1-02 审计侧边栏职责：全局导航、书架状态筛选、退出入口是否清晰，不与顶栏账号信息重复。
- [x] U1-03 审计顶栏职责：页面工具位、通知、日夜切换、设置、账号入口是否清晰。
- [x] U1-04 审计顶栏在窄桌面窗口下的折叠策略，避免搜索框、工具按钮、账号名称互相挤压。
- [x] U1-05 审计 Shell 内页面是否能注册页面级工具动作，避免每个页面各自手搓桌面顶栏。
- [x] U1-06 审计 Web 大屏是否复用桌面响应式规则，同时保留浏览器刷新和路由恢复能力。
- [x] U1-07 输出桌面壳层整改候选清单，只列问题和任务，不立即批量改代码。

### U1 执行结论

- Shell 切换规则：当前 `useNavigationRail` 在宽度 `>= 600` 或 desktop-like 时启用桌面壳层。这能覆盖 Web / Desktop 大屏，但也意味着移动端横屏、平板或 600-839 窄窗口会进入完整侧边栏壳层，后续需要确认 medium 宽度是否应使用更轻的 rail / 窄侧栏策略。
- 侧边栏宽度：当前只有两档，`>= 840` 使用 244，`600-839` 使用 216。常规桌面可用，但窄窗口偏占空间，宽屏也不一定需要 244；建议后续改成 `medium / desktop / wide` 多档，并把 600-839 作为特殊窄桌面处理。
- 侧边栏职责：当前结构是品牌、主导航、书架页专属“我的书架”状态筛选、底部退出登录。账号资料和设置已经放到顶栏右侧，侧边栏没有重复账号信息，职责方向合理。
- 顶栏职责：当前顶栏右侧固定通知、日夜切换、设置、账号；书架页左侧有书架状态下拉、本地搜索、视图选项。这个方向符合“顶栏承载当前页工具 + 全局轻操作”，但目前页面工具能力主要服务书架。
- 顶栏窄窗口风险：顶栏固定高度 74，右侧全局按钮和账号入口固定占宽，书架搜索框最大 460 但没有通用 overflow 策略。600-839 或浏览器窄窗口下可能出现搜索框被挤压、账号名称占位过多、工具按钮没有收纳入口的问题。
- 页面级工具注册：当前已有书架专属 `desktopBookshelfToolbarActionsProvider` 和 `desktopBookshelfLibraryActionsProvider`，但没有通用的 Shell 页面工具位注册机制。搜索、详情、统计、我的等页面如果要使用桌面顶栏，容易继续在页面内部手搓或扩大 `ShellScaffold` 的页面判断。
- Web 大屏：Web 宽度 `>= 600` 会复用桌面壳层；宽度 `< 600` 会回到移动底部导航。方向合理，但 Web 的刷新恢复、URL 深链和浏览器窄窗口需要在后续 U2/U7 中结合具体页面验证。

### U1 后续整改候选

- [x] U1-FIX-01 将桌面侧边栏宽度从 `216 / 244` 两档调整为窄窗口、常规桌面、宽屏三档，并确认 600-839 是否使用完整侧边栏或轻量 rail。
- [x] U1-FIX-02 为桌面顶栏增加统一 overflow 策略：窄窗口优先收起账号名称、页面工具按钮和低优先级全局按钮。
- [x] U1-FIX-03 抽象 Shell 页面工具位注册机制，让书架、搜索、详情、统计、我的可以按页面注册顶栏工具，避免 `ShellScaffold` 继续堆页面专属判断。
- [x] U1-FIX-04 为在线搜索页设计桌面顶栏接入方案：搜索输入、书源筛选、聚合状态进入页面工具位，结果区专注展示结果。
- [x] U1-FIX-05 为详情页设计桌面顶栏接入方案：返回、当前书名摘要、加入书架、开始阅读等操作按宽度折叠。
- [x] U1-FIX-06 为 Shell 响应式补最小 widget test 或 golden/smoke：覆盖 600、840、1200、1600 宽度下侧边栏和顶栏不溢出。

### U1-FIX 执行结论

- 桌面侧边栏已改为多档宽度：`600-839 => 184`、`840-1199 => 216`、`1200-1599 => 244`、`>=1600 => 260`。600-839 仍保留完整侧边栏语义，但使用轻量宽度，避免窄桌面 / Web 小窗口被导航挤压。
- 桌面顶栏已增加统一窄窗口策略：可用宽度不足时隐藏书架本地搜索框、隐藏账号名称、把通知和设置收进更多菜单；日夜切换和账号头像仍保持外露。
- 已新增 `desktopShellPageToolbarActionsProvider`，作为 Shell 内页面的通用桌面顶栏动作注册模型。书架页先继续使用已有复杂菜单 provider，统计 / 我的 / 发现后续可逐步接入通用工具位。
- 在线搜索页和详情页当前是独立路由，不在 `ShellScaffold` 内。U1-FIX-04 / U1-FIX-05 本轮完成接入方案，不强行半接入 Shell：下一轮应先抽 `AdaptiveRouteTopBar` / 独立路由桌面骨架，再迁移搜索和详情页 AppBar。
- 已补 `test/app/layout/adaptive_breakpoints_test.dart` 覆盖 600、840、1200、1600 侧栏宽度、窄桌面顶栏 overflow、非书架页面注册工具位。

## 4. U2：核心业务页面 UI 统一化

目标：优先审计用户每天会用的页面，先解决影响最大的体验不一致。

- [x] U2-01 审计书架页：移动端触控路径、桌面端侧栏筛选、顶栏本地搜索、在线搜索入口、列表/双列/网格模式是否一致合理。
- [x] U2-02 审计书架书籍卡片：封面自适应、进度/未读切换、更多菜单、标签分类、阅读状态、删除和编辑入口是否全平台一致。
- [x] U2-03 审计在线搜索页：会员权限、搜索输入、聚合结果、书源筛选、空态、错误态、桌面列数是否统一。
- [x] U2-04 审计在线详情页：目录首批加载、封面/简介/操作区、加入书架、开始阅读、会员提示和桌面分栏是否统一。
- [x] U2-05 审计阅读器页面：本地/在线内容加载、返回、目录、设置、分页、错误恢复、桌面键鼠和移动手势是否统一。
- [x] U2-06 审计我的页：账号、会员状态、设置入口、管理入口在移动端和桌面端是否职责清晰。
- [x] U2-07 审计认证链路：登录、注册、退出、会话恢复、账号卡片、会员显示在全平台是否使用同一业务源。

### U2 执行结论

- 书架页：移动端仍保留原 AppBar / bottom sheet / 本地搜索触控路径；桌面端已具备侧栏阅读状态筛选、顶栏本地搜索、右下角在线搜索入口、列表 / 双列 / 网格显示模式。当前方向合理，主要债务是 `bookshelf_page.dart` 体量过大，书架卡片和更多菜单仍集中在单文件里。
- 书架卡片：进度条 / 未读章节数切换、更多菜单、编辑、标签、分类、待读清单、未读 / 阅读中 / 已读完、删除已全平台共享同一业务入口。阅读状态和详情页的 `BookReadingStatusService` 已联动；后续重点是把卡片 UI、更多菜单和标签分类弹层继续拆组件，降低移动端和桌面端互相误改风险。
- 在线搜索页：会员权限统一走 `MembershipAccessService`，搜索状态集中在 `SearchPageState`，结果支持聚合、书源筛选、失败提示、历史、分页和中大屏网格。风险是页面仍直接持有大量控制器和 AppBar；桌面大窗口搜索输入、书源筛选和聚合状态还没有下沉到独立路由桌面顶栏。
- 在线详情页：详情链路统一在 `BookDetailService`，已有 20 分钟缓存、目录首批加载、完整目录按需加载、详情错误和目录错误分层；阅读状态、标签分类和本地元数据已与书架服务联动。风险是详情页仍是大页面，桌面编辑器 / 操作区 / 目录区虽有响应式分支，但缺少独立路由桌面顶栏骨架。
- 阅读器：本地 / 在线章节加载、content session、mode capability、viewport state、键鼠输入解析已逐步下沉到 application / shell / resolver；桌面键盘和滚轮行为已有统一 `ReaderDesktopInputResolver`。风险是 `ReaderPage` 仍然过大，目录、设置、选择、分页和错误恢复还分散在多个 part，需要继续按 M6 的拆分方向推进。
- 我的页：账号卡片、会员状态、会员中心、高级主题权限、设置入口基本同源；桌面壳层账号入口已经放到顶栏，侧边栏只保留退出，职责不重复。后续应把 Mine 页会员显示和在线搜索权限的显示文案继续对齐到统一 access snapshot。
- 认证链路：登录、注册、退出、session display cache、secret fallback、会员字段存取均集中在 `AuthService`、`AuthSessionStore`、`MembershipAccessService` 一组服务里。桌面顶栏监听 `AuthEventBus` 刷新账号入口；Web / Desktop / Mobile 应继续通过同一事件链验证会话恢复和退出。

### U2 后续整改候选

- [ ] U2-FIX-01 拆分书架卡片 UI：把网格卡片、列表卡片、更多菜单、进度展示、封面自适应策略从 `bookshelf_page.dart` 下沉为独立 widgets，并保留移动 / 桌面快照测试。
- [x] U2-FIX-02 抽 `AdaptiveRouteTopBar`：服务搜索页、详情页这类独立路由，桌面端承载搜索输入 / 筛选 / 主操作，移动端继续使用当前 AppBar。
- [ ] U2-FIX-03 在线搜索页接入独立路由桌面顶栏：搜索输入、书源筛选、聚合状态和搜索中取消进入顶栏；结果区只保留结果、进度、失败和空态。
- [ ] U2-FIX-04 在线详情页接入独立路由桌面顶栏：返回、书名摘要、加入书架、开始阅读、分享 / 更多按宽度折叠；详情正文继续负责封面、简介、目录和元数据。
- [ ] U2-FIX-05 阅读器继续执行 M6 拆分：目录、设置、选择、分页缓存和错误恢复从 `ReaderPage` part 文件继续向 facade / controller / adaptive sheet 下沉。
- [ ] U2-FIX-06 统一会员权限展示：我的页、高级主题、在线搜索、书源能力、阅读器会员功能都读取同一 access snapshot，并补一组会员账号 smoke。
- [x] U2-FIX-07-01 修正原生桌面最小窗口尺寸，确保 macOS / Windows / Linux 能拖到 `<600` 和 `600 - 839` 断点；当前最小值为 `520x620`，初始值仍为 `1280x820`。
- [ ] U2-FIX-07 为书架、搜索、详情、阅读器补桌面窗口拖拽 smoke：至少覆盖 520、600、840、1200、1600，记录移动端小屏未回归项。

### U2-FIX 执行结论

- 已新增 `AdaptiveRouteTopBar`，专门服务 `/search`、`/book/:bookId` 这类不在 `ShellScaffold` 内的独立路由。移动端仍输出常规轻量 AppBar；`>=600` 的中大屏可承载标题、副标题、中间搜索 / 筛选区域和 overflow 动作。
- 已补 `test/app/widgets/adaptive_components_test.dart`，覆盖 `<600` 移动端不显示桌面中间工具区、`840` 窄桌面显示中间区域并把动作收进 overflow 的行为。
- 本轮不直接迁移在线搜索页和详情页。原因是两个页面都持有复杂业务状态、滚动、会员权限和编辑逻辑；应先有稳定路由顶栏骨架，再分别领取 `U2-FIX-03`、`U2-FIX-04` 做页面接入。
- `U2-FIX-01`、`U2-FIX-05`、`U2-FIX-06` 仍是后续真实整改项，不能因为本轮完成了组件前置工作而误打勾。

## 5. U3：设置与资源管理页面统一化

目标：设置类页面数量多、功能散，统一骨架、状态和弹层后能明显降低维护成本。

- [x] U3-01 审计外观设置页：应用外观、导航栏显示、阅读背景、封面、主题入口是否与当前首页删除后的业务口径一致。
- [x] U3-02 审计高级主题列表：会员权限、导入导出、预览、下载、错误态、桌面网格和移动列表是否合理。
- [x] U3-03 审计高级主题编辑器：表单结构、资源选择、预览、保存校验、桌面宽屏布局是否合理。
- [x] U3-04 审计启动图集、封面图集、底部导航图标图集：列表、编辑、导入、重命名、删除、空态是否使用统一模式。
- [x] U3-05 审计字体管理、阅读背景管理、缓存管理、错误中心：文件能力、Web 降级、桌面路径和移动端权限是否清晰。
- [x] U3-06 审计标签与分类管理：书架更多菜单、详情编辑页、我的管理页是否共享业务服务，不重复造状态。
- [x] U3-07 审计公告、反馈、关于、系统设置：页面骨架、最大宽度、加载/错误/空态是否统一。

### U3 执行结论

- 外观设置页：`/appearance` 已通过 query section 区分应用外观、导航栏、封面和阅读背景；首页删除后的旧 `home` 图标入口已经在 U0 清掉，当前外观页应继续围绕书架 / 发现 / 统计 / 我的四个一级入口。风险是 `appearance_page_view.dart` 体量较大，仍在页面层持有部分平台判断和大量弹层入口。
- 高级主题列表：`advanced_theme_list_page.dart` 体量接近 3700 行，已使用 `showAdaptiveActionSurface` / `showAdaptiveRawSurface`、空态和导入任务 surface，业务能力完整；风险是会员权限、导入导出、预览、批量导入、下载、删除确认和排序筛选都集中在单页，后续维护成本高。
- 高级主题编辑器：`advanced_theme_editor_page.dart` 体量接近 3900 行，资源选择、壁纸、封面图集、启动图集、底部导航图集、字体和预览能力都在一个页面里。它已经大量使用 adaptive surface，但表单分区、保存校验和桌面宽屏布局仍需要拆成状态 service + 分区 widgets。
- 图集页面族：启动图集、封面图集、底部导航图标图集都存在列表页和编辑页，且服务层分别为 `LaunchImageGalleryService`、`CoverGalleryService`、`BottomNavIconGalleryService`。业务语义相近，但列表卡片、更多菜单、编辑器、空态、删除确认和图片预览仍没有完全统一。
- 文件与资源能力页：字体管理、阅读背景管理、错误中心已能读取 capability 或 managed storage 能力，并对 Web / 不支持文件能力给出提示；风险是 `font_management_page.dart` 仍有直接 `showDialog` 和页面内复杂导入流程，后续应统一到 adaptive action surface。
- 标签与分类管理：书架更多菜单、详情编辑页和 `/mine/tags`、`/mine/categories` 当前都围绕书架元数据服务联动；`mine_management_page.dart` 已在 `U3-FIX-08` 改为 adaptive action surface，移动端保留底部弹层，桌面端使用 dialog。
- 公告、反馈、关于、系统设置：公告和错误中心已使用统一状态卡；反馈、关于、系统设置仍多为独立 Scaffold + AppBar。低频页面方向可接受，但需要统一最大宽度、错误 / 空态、桌面 route topbar 和系统能力降级入口。

### U3 后续整改候选

- [ ] U3-FIX-01 将 `/appearance` 外观页接入 `AdaptiveRouteTopBar`：桌面端显示当前 section、搜索 / 快捷入口或保存状态；移动端保留当前 AppBar 和触控路径。
- [ ] U3-FIX-02 拆分 `appearance_page_view.dart` 的应用外观、导航栏、封面、阅读背景四个 section widgets，并移除页面层散落平台判断。
- [ ] U3-FIX-03 为高级主题列表抽 `AdvancedThemeListToolbar`：排序、分类筛选、导入、批量导入、下载入口进入桌面 route topbar / overflow。
- [ ] U3-FIX-04 为高级主题列表抽状态与操作 facade：会员权限、导入导出、删除、下载、预览不再散落在页面方法里。
- [ ] U3-FIX-05 拆分高级主题编辑器分区：基础信息、颜色与组件、壁纸、封面图集、启动图集、底部导航图集、字体、预览分别成 widgets。
- [ ] U3-FIX-06 抽统一 `ImageGalleryManagementPage` 模式：启动图集、封面图集、底部导航图标图集共享列表空态、更多菜单、重命名、删除确认和导入进度 surface。
- [ ] U3-FIX-07 把字体管理页的直接 `showDialog` 改为 `showAdaptiveActionSurface`，并把导入、重命名、删除、能力提示抽成可测小组件。
- [x] U3-FIX-08 把标签 / 分类管理页的 `showModalBottomSheet` 改为 adaptive action surface：移动端仍是底部弹层，桌面端为 dialog / popover。
- [ ] U3-FIX-09 统一低频页面骨架：公告、反馈、关于、系统设置、错误中心逐步接入 `AdaptiveRouteTopBar` 和统一最大宽度，保持移动端 AppBar 不变。
- [ ] U3-FIX-10 为资源管理页面补 Web / Desktop / Mobile 能力矩阵 smoke：文件导入、图片预览、删除、导出、Web 降级分别记录。

### U3-FIX 执行结论

- 已执行 `U3-FIX-08`：`mine_management_page.dart` 的标签 / 分类删除确认和新增 / 编辑入口已从直接 `showModalBottomSheet` 改为 `showAdaptiveActionSurface`。
- 移动端行为保持底部弹层；桌面端改为 dialog 样式，去掉移动端拖拽条，避免设置 / 资源管理类页面在桌面端继续套用移动交互。
- 已补 `mine_management_page_test.dart` 的 macOS 宽屏用例，验证桌面端标签管理页能通过 dialog 新增标签。
- `U3-FIX-01` 到 `U3-FIX-07`、`U3-FIX-09`、`U3-FIX-10` 仍是后续真实整改项，本轮没有误打勾。

## 6. U4：业务链一致性审计

目标：页面可以长得不同，但业务状态必须同源、同语义、同错误处理。

- [x] U4-01 审计会员权限链：我的页、高级主题、在线搜索、书源能力、阅读器会员功能是否统一读取同一 access service。
- [x] U4-02 审计书架元数据链：标签、分类、阅读状态、待读清单、进度、未读章节是否在书架、详情、阅读器同步。
- [x] U4-03 审计在线书源链：搜索、详情、目录首批加载、章节阅读、书源切换、错误降级是否全平台同源。
- [x] U4-04 审计本地内容链：导入、智能分段、详情、阅读、封面、删除、缓存和路径是否全平台一致。
- [x] U4-05 审计账号会话链：display session、secret store、退出事件、过期事件、桌面冷启动、Web 刷新是否一致。
- [x] U4-06 审计主题链：日夜切换、高级主题、阅读器主题、系统设置、桌面顶栏快捷入口是否状态一致。
- [x] U4-07 审计错误与降级链：网络失败、权限不足、插件不支持、平台能力缺失是否有统一文案和恢复入口。

### U4 执行结论

- 会员权限链：底座已经集中到 `MembershipAccessService` 和 `MembershipAccessResolver`，能从 entitlement、profile、session 三层回退推导会员状态。风险是我的页、高级主题、在线搜索、阅读器书源切换仍有页面级展示和 gate glue，后续要把“显示会员”和“判断会员能力”收口成同一个 snapshot / adapter。
- 书架元数据链：标签 / 分类通过 `BookshelfService` 和 taxonomy event bus 联动；未读 / 阅读中 / 已读完通过 `BookReadingStatusService` 从阅读进度推导或写入；待读清单目前对应 `BookshelfBook.inReadingQueue`。风险是书架页仍有局部状态文案、图标和筛选包装，容易跟详情编辑页语义漂移。
- 在线书源链：搜索、详情和阅读器已经通过 server gateway、详情服务和 `ServerGatewayContentProvider` 串起来；详情页保留首批目录加载，避免一次性拉全量目录导致卡顿。风险是搜索 / 详情 / 阅读器仍各自有错误文案和权限提示，桌面大窗口列表 / 详情响应式结构还需要专项设计。
- 本地内容链：导入、索引、预览和阅读内容已经集中到 `LocalBookIndexService`、`LocalBookDetailService`、`LocalChapterContentService`、`LocalContentProvider` 等服务。风险是智能分段和文件能力必须做全平台手工 smoke，尤其是 macOS / Windows / Web 的路径、权限和插件降级。
- 账号会话链：`AuthSessionStore` 和 `AuthEventBus` 是统一底座，Shell 和搜索页会监听登录 / 退出 / 过期事件；桌面启动有 display cache 和 secret fallback。风险是 Web 刷新恢复、注册后用户卡片刷新、退出后全局状态清理仍需要持续回归。
- 主题链：日夜切换、高级主题和阅读器主题覆盖已经围绕全局 theme provider、`activeAdvancedThemeProvider` 和阅读器设置解析服务工作；桌面顶栏快捷切换复用同一状态方向正确。风险是外观页、高级主题编辑器、阅读器显示预览仍可能各自拼展示状态。
- 错误与降级链：项目已有 `AppException` / `ErrorCode`、`AppStatusStateCard`、`FeatureDisabledPage`、`ReaderFailurePresentationService` 等统一能力。风险是详情、搜索和阅读器仍有局部 `_toUserReadableError` / 页面内错误映射，后续应统一到共享错误展示 adapter。

### U4 后续整改候选

- [ ] U4-FIX-01 抽统一会员 access snapshot provider / display adapter：我的页、在线搜索、高级主题、阅读器书源切换只读取同一快照。
- [ ] U4-FIX-02 为“profile 或 session 显示永久会员”的账号补会员 smoke test，覆盖在线搜索和高级主题 gate。
- [ ] U4-FIX-03 抽 `book_reading_status_presentation.dart`：未读 / 阅读中 / 已读完的 label、icon、排序和筛选语义全平台共用。
- [ ] U4-FIX-04 抽待读清单语义 mapper：明确它是书架收藏状态，不混入阅读状态；书架、详情、更多菜单共用文案。
- [ ] U4-FIX-05 抽在线书源错误展示 adapter：搜索、详情、阅读器章节加载和书源切换使用同一权限 / 网络 / 空结果文案。
- [ ] U4-FIX-06 补本地内容导入到阅读 smoke 清单：导入、本地详情、智能分段、阅读、删除、缓存清理按 Desktop / Web / Mobile 记录。
- [ ] U4-FIX-07 补账号会话事件 smoke：登录、注册、退出、session restore、过期事件覆盖 Desktop / Web / Mobile。
- [ ] U4-FIX-08 抽主题状态展示 snapshot：顶栏日夜切换、外观设置、高级主题、阅读器主题预览共用展示值。
- [ ] U4-FIX-09 合并详情 / 搜索 / 阅读器残留 `_toUserReadableError` 到共享错误展示服务。

## 7. U5：代码可维护性与成熟库替换审计

目标：继续执行“手搓换成熟，不稳定换成熟”，但只对真实复杂点下手。

- [x] U5-01 复核 1500 行以上页面，按业务区块拆分候选排序。
- [x] U5-02 复核页面层直接平台判断，能用 capability / adapter 的列入整改。
- [x] U5-03 复核页面层直接读写 `SharedPreferences`、文件路径、缓存目录的使用点。
- [x] U5-04 复核手写弹层、菜单、空态、加载态、错误态，能接入 adaptive surface 和统一状态组件的列入整改。
- [x] U5-05 复核手写模型、手写 `copyWith`、手写 JSON、手写 equality，适合 `freezed` 或类型安全 key 的列入整改。
- [x] U5-06 复核复杂异步竞态：widget dispose 后使用 `ref/context`、重复请求、进度节流、搜索取消、目录加载取消。
- [x] U5-07 复核性能热点：大列表、封面图片、目录加载、智能分段、主题资源、阅读器分页和缓存。

### U5 执行结论

- 超大文件排序：当前最大维护债集中在 `bookshelf_page.dart`（约 7253 行）、`reader_page.dart`（约 5993 行）、`reader_page_settings_sheet.dart`（约 4424 行）、`advanced_theme_service.dart`（约 4084 行）、`advanced_theme_editor_page.dart`（约 3890 行）、`advanced_theme_list_page.dart`（约 3681 行）、`book_detail_page.dart`（约 3671 行）。后续不能继续在这些文件里直接补大功能，必须先拆边界。
- 成熟库现状：项目已经接入 `freezed` / `json_serializable`、`drift`、`go_router`、`flutter_riverpod`、`dio`、`responsive_framework`、`cached_network_image`、`window_manager` 等成熟库。U5 的方向不是盲目加新库，而是把现有成熟库和项目内 adaptive 组件用完整。
- 页面层平台判断：桌面 / Web / 移动差异已经有部分 capability、adapter、adaptive surface，但大页面里仍有页面级平台分支。后续应迁移到 `capability`、`resolver`、`adapter` 或 `Adaptive*` 组件，减少同一业务多端重复判断。
- 存储和路径：`SharedPreferences`、文件路径、缓存目录的读写已经有部分 service 封装，例如 reader preferences、managed storage、local book storage；风险是页面或大型 service 仍可能直接拼 key / 路径。后续优先抽类型安全 key、storage adapter 和 repository facade，不要在页面内继续读写。
- 弹层和状态：项目已有 `showAdaptiveActionSurface`、`showAdaptiveRawSurface`、`AppStatusStateCard`、`AppEmptyStateCard`、`FeatureDisabledPage`，但仍能扫到 `showDialog` / `showModalBottomSheet` 残留。除通用 adaptive 组件自身外，页面级弹层应逐步迁移到 adaptive surface。
- 模型和 JSON：项目已部分使用 `freezed` / `json_serializable`，但仍有手写 `copyWith`、`toJson`、`fromJson` 和复杂配置模型，尤其是阅读进度、阅读设置、高级主题、图集等。下一步不要一次性全替换，优先选择改动频繁、字段多、容易漏字段的模型迁移。
- 异步竞态：之前出现过 widget dispose 后使用 `ref/context` 的问题；阅读器、搜索、目录加载、导入进度、封面批量加载、分页缓存都属于高风险异步链。后续拆 controller 时必须把取消、超时、mounted 检查和结果归属一起下沉。
- 性能热点：大列表、封面图片、目录加载、智能分段、主题资源、阅读器分页和本地内容索引是主要热点。已有缓存和分页能力，但仍需要通过拆分和 smoke 确认不会因为 UI 重构重新引入卡顿。

### U5 成熟库 / 组件替换候选

- [ ] U5-LIB-01 手写复杂模型迁移候选：优先评估 `reader_settings.dart`、`reading_progress.dart`、`app_advanced_theme.dart`、图集模型是否继续手写，或逐步迁移到 `freezed` / `json_serializable`。
- [ ] U5-LIB-02 手写弹层替换候选：页面级 `showDialog` / `showModalBottomSheet` 迁移到 `showAdaptiveActionSurface` / `showAdaptiveRawSurface`；移动端底部弹层、桌面端 dialog / popover 保持平台语义。
- [ ] U5-LIB-03 手写状态卡替换候选：页面私有加载 / 空态 / 错误 / 权限不足组件逐步替换为 `AppStatusStateCard`、`AppEmptyStateCard`、`FeatureDisabledPage`。
- [ ] U5-LIB-04 手写响应式替换候选：页面内直接宽度判断优先迁移到 `AdaptivePageScaffold`、`AdaptiveRouteTopBar`、`AdaptiveGridSliver`、`AdaptiveOverflowToolbar`、`responsive_framework` 断点配置。
- [ ] U5-LIB-05 手写文件 / 缓存路径替换候选：页面和大型 service 不直接拼路径，统一走 managed storage、local book storage、reader resource / cache service。
- [ ] U5-LIB-06 手写网络错误展示替换候选：搜索、详情、阅读器、公告、反馈等网络错误收口到共享 error presentation adapter。
- [ ] U5-LIB-07 手写异步节流 / 取消替换候选：搜索取消、目录加载、导入进度、封面批量加载、分页重排统一抽 controller，必要时引入可测试的 cancel token / request id 策略。

### U5 分发清单（Windows 优先）

这些任务适合另一台 Windows 执行，原则是“先拆代码边界，不改业务行为”。Windows 完成后回填本节、对应 `U5-*` 项和 Backlog 项，并提交目标 analyze / tests 结果。

- [x] WIN-U5-01 执行 `U5-BS-01` 到 `U5-BS-04`：书架模型、mapper、状态组件、工具条拆分；对应 `BL-01-01`。
- [x] WIN-U5-02 执行 `U5-ATL-01` 到 `U5-ATL-06`：高级主题列表 action 盘点、查询 controller、权限 controller、卡片、状态组件、toolbar；对应 `BL-05-02`。
- [ ] WIN-U5-03 执行 `U5-ATE-01` 到 `U5-ATE-05`：高级主题编辑器字段盘点、状态 facade、基础信息、颜色组件、壁纸分区；对应 `BL-05-03`。
- [x] MAC-U5-01 执行 `U5-RD-01` 到 `U5-RD-15`：阅读器拆分索引、bootstrap、lifecycle、content load、进度保存、分页触发、触控、桌面输入、chrome、目录、设置、选区、反馈和内容模式 surface；对应 `BL-03-01` / `BL-03-02`。
- [ ] WIN-U5-05 如果 Windows 已占用 `bookshelf_page.dart`，Mac 暂停 `BL-01`；如果 Windows 已占用高级主题列表或编辑器，Mac 暂停对应 `BL-05-02` / `BL-05-03`。

### U5 最大维护债细拆

目标：把当前最大的四个页面文件拆成能单独领取、单独验证的小任务。每个 checkbox 只允许处理一个明确边界；如果执行时发现任务仍然过大，必须继续拆小，不能把多个业务区块一起改。

#### U5-BS：`bookshelf_page.dart`

当前约 `5784` 行。拆分顺序先纯 UI / mapper，再 controller，最后动异步加载链。

- [x] U5-BS-01 迁移书架私有 enum、展示模型、常量到 `bookshelf_page_models.dart`，不改行为。
- [x] U5-BS-02 迁移排序、视图模式、进度显示、网格样式等字符串映射到 `bookshelf_preference_mappers.dart`，补 mapper 单测。
- [x] U5-BS-03 抽书架空态、加载态、错误态、继续阅读提示到 `widgets/bookshelf_status_widgets.dart`。
- [x] U5-BS-04 抽书架本地搜索、筛选条、阅读状态 selector 到 `widgets/bookshelf_toolbar_widgets.dart`。
- [x] U5-BS-05 抽桌面“我的书架 / 阅读状态 / 标签分类入口”侧栏视图到 `widgets/bookshelf_library_sidebar.dart`。
- [x] U5-BS-06 抽网格书籍卡片壳层到 `widgets/bookshelf_grid_book_card.dart`，只搬 UI 参数和回调。
- [x] U5-BS-07 抽列表 / 双列书籍卡片壳层到 `widgets/bookshelf_list_book_card.dart`，展示开关语义不变。
- [x] U5-BS-08 抽封面尺寸、占位和自适应策略到 `bookshelf_cover_layout_resolver.dart`，补尺寸测试。
- [x] U5-BS-09 抽进度条 / 未读章节数展示到 `widgets/bookshelf_progress_indicator.dart`，网格和列表共用。
- [x] U5-BS-10 抽书籍更多菜单 action 和 UI 到 `widgets/bookshelf_book_more_menu.dart`，移动端 bottom sheet、桌面 popover 入口保持原样。
- [x] U5-BS-11 抽标签 / 分类选择弹层 UI 到 `widgets/bookshelf_taxonomy_picker_surface.dart`，复用现有服务。
- [x] U5-BS-12 抽删除、待读清单、阅读状态标记、编辑入口 dispatcher 到 `bookshelf_book_action_controller.dart`，补最小单测。
- [x] U5-BS-13 抽列表 / 网格 / 排序偏好恢复到 `bookshelf_preference_restore_controller.dart`，不改持久化 key。
- [x] U5-BS-14 抽首屏加载和即时元数据加载到 `bookshelf_initial_load_controller.dart`，保留超时和错误文案。
- [x] U5-BS-15 抽封面、元数据、本地书信息批量加载到 `bookshelf_presentation_metadata_loader.dart`，补 dispose 后不更新 UI 的防护测试。
- [x] U5-BS-16 抽在线书籍最新章节后台刷新到 `bookshelf_latest_info_refresh_controller.dart`，保留冲突取消和 TOC snapshot 保存。
- [x] U5-BS-17 抽阅读入口解析、fallback、退出后进度刷新到 `bookshelf_reader_entry_controller.dart`。
- [x] U5-BS-18 清理已迁移 helper，跑书架目标 analyze 和相关 widget / provider tests。

#### U5-RD：`reader_page.dart`

当前约 `5993` 行。拆分必须跟 M6 阅读器专项一致，先拆生命周期和加载 glue，后拆手势、分页和选择。

- [x] U5-RD-01 盘点 `reader_page.dart` 与现有 part 文件职责，补拆分索引注释，不改行为。
- [x] U5-RD-02 抽 route 参数解析与入口初始化 glue 到 `reader_page_bootstrap_controller.dart`。
- [x] U5-RD-03 抽 App lifecycle、wakelock、系统 UI 恢复到 `reader_runtime_lifecycle_controller.dart`。
- [x] U5-RD-04 抽章节加载状态、错误恢复、重试入口到 `reader_content_load_controller.dart`。
- [x] U5-RD-05 抽本地 / 在线进度保存与阅读记录写入到 `reader_progress_commit_controller.dart`，补保存测试。
- [x] U5-RD-06 抽分页触发、分页缓存 key、字体变化重分页到 `reader_pagination_controller.dart`，复用现有 resolver。
- [x] U5-RD-07 抽触控手势区域和 tap zone 判断到 `reader_touch_navigation_layer.dart`，移动端手势必须回归。
- [x] U5-RD-08 抽桌面键盘、滚轮、hover / focus glue 到 `reader_desktop_input_layer.dart`，继续复用 `ReaderDesktopInputResolver`。
- [x] U5-RD-09 抽阅读器顶部 / 底部 chrome 到 `reader_chrome_surface.dart`，不改沉浸式显示时机。
- [x] U5-RD-10 抽目录入口和目录弹层调用到 `reader_catalog_entry_controller.dart`。
- [x] U5-RD-11 抽设置入口和设置弹层调用到 `reader_settings_entry_controller.dart`。
- [x] U5-RD-12 抽选择文本、复制、划线 / 书签入口 glue 到 `reader_selection_controller.dart`。
- [x] U5-RD-13 抽错误卡片、离线提示、能力缺失提示到 `reader_feedback_widgets.dart`。
- [x] U5-RD-14 抽本地图文 / 漫画 / 文本模式切换 UI glue 到 `reader_content_mode_surface.dart`。
- [x] U5-RD-15 清理已迁移 helper，跑 M6 现有 reader application / route tests。

#### U5-ATE：`advanced_theme_editor_page.dart`

当前约 `3711` 行。拆分重点是让编辑状态同源，不把表单字段拆成多个互不同步的局部状态。

已拆分边界索引：

- [x] 编辑器状态 facade：`advanced_theme_editor_controller.dart`，负责 draft、模式、保存 / 加载、展开状态和外观资源链接的一致更新。
- [x] 基础信息：`widgets/advanced_theme_basic_section.dart`，先承接标题编辑入口。
- [x] 颜色区块：`widgets/advanced_theme_color_section.dart`，以 part extension 承接颜色 / 强度区块 glue，后续再继续抽纯 widget。
- [x] 视觉资源卡片：`widgets/advanced_theme_wallpaper_section.dart`，作为应用背景 / 阅读背景 / 后续图集卡片的共用壳层。
- [x] 封面图集：`widgets/advanced_theme_cover_gallery_section.dart`，先承接封面图集绑定入口壳层。
- [x] 启动图集：`widgets/advanced_theme_launch_gallery_section.dart`，先承接启动图集绑定入口壳层。
- [x] 外观资源条目：`widgets/advanced_theme_appearance_link_tile.dart`，承接底栏、字体等资源绑定行。
- [x] 底部导航图集：`widgets/advanced_theme_bottom_nav_gallery_section.dart`，承接底栏图集绑定入口；旧 `home` slot 已由 `BottomNavIconGallery.fromJson` 映射到书架槽位并补测试。
- [x] 字体选择：`widgets/advanced_theme_font_section.dart`，承接界面字体 / 阅读字体绑定入口，保留原字体管理跳转和能力降级路径。
- [x] 预览面板：`widgets/advanced_theme_preview_panel.dart`，先承接编辑页实时背景预览承载层；后续桌面右侧固定预览在该组件内继续扩展，移动端仍保持滚动体验。
- [x] 保存校验：`advanced_theme_editor_validation_service.dart`，承接保存前业务校验和错误文案。
- [x] 资源解析：`advanced_theme_editor_resource_service.dart`，承接本地 / asset 图片解析、file URI 读取和图片 provider 构造。
- [x] 路由顶栏：编辑器接入 `AdaptiveRouteTopBar`，桌面顶栏承载主题名、保存、预览、更多，移动端保留 AppBar 语义；`AdaptiveRouteTopBar` 增加兼容的 bottom 插槽承载浅 / 深色 TabBar。

- [x] U5-ATE-01 盘点编辑器字段、表单分区和保存依赖，补编辑器拆分索引，不改代码。
- [x] U5-ATE-02 抽编辑器状态读写 facade 到 `advanced_theme_editor_controller.dart`，页面不直接拼保存 payload。
- [x] U5-ATE-03 抽基础信息分区到 `widgets/advanced_theme_basic_section.dart`。
- [x] U5-ATE-04 抽颜色和组件样式分区到 `widgets/advanced_theme_color_section.dart`。
- [x] U5-ATE-05 抽壁纸 / 背景图选择分区到 `widgets/advanced_theme_wallpaper_section.dart`。
- [x] U5-ATE-06 抽封面图集绑定分区到 `widgets/advanced_theme_cover_gallery_section.dart`。
- [x] U5-ATE-07 抽启动图集绑定分区到 `widgets/advanced_theme_launch_gallery_section.dart`。
- [x] U5-ATE-08 抽底部导航图标图集绑定分区到 `widgets/advanced_theme_bottom_nav_gallery_section.dart`，确认旧 home slot 仍映射书架。
- [x] U5-ATE-09 抽字体选择分区到 `widgets/advanced_theme_font_section.dart`，保留 Web / Desktop / Mobile 能力降级。
- [x] U5-ATE-10 抽预览面板到 `widgets/advanced_theme_preview_panel.dart`，桌面可右侧固定，移动端保持滚动体验。
- [x] U5-ATE-11 抽保存校验和错误文案到 `advanced_theme_editor_validation_service.dart`，补基础校验单测。
- [x] U5-ATE-12 抽资源路径解析和 managed file 写入调用到 application service，页面不直接处理真实路径。
- [x] U5-ATE-13 接入 `AdaptiveRouteTopBar`：桌面显示主题名、保存、预览、更多；移动端保留 AppBar。
- [x] U5-ATE-14 清理已迁移 surface builder，跑高级主题 editor 目标 analyze / tests。

#### U5-ATL：`advanced_theme_list_page.dart`

当前约 `2902` 行。拆分重点是把查询、会员、导入导出和批量操作从页面方法里拿出去。

- [x] U5-ATL-01 盘点列表页 action、状态字段、弹层和导入导出流程，补列表页拆分索引，不改行为。
- [x] U5-ATL-02 抽列表查询、搜索、分类筛选、排序到 `advanced_theme_list_query_controller.dart`，补排序 / 筛选单测。
- [x] U5-ATL-03 抽会员权限加载和 AuthEvent 刷新到 `advanced_theme_access_controller.dart`。
- [x] U5-ATL-04 抽主题卡片 UI 到 `widgets/advanced_theme_summary_card.dart`。
- [x] U5-ATL-05 抽列表空态、加载态、会员 gate、错误提示到 `widgets/advanced_theme_list_status_widgets.dart`。
- [x] U5-ATL-06 抽搜索框、排序、分类筛选、导入入口到 `widgets/advanced_theme_list_toolbar.dart`。
- [x] U5-ATL-07 接入 `AdaptiveRouteTopBar`：桌面承载搜索、排序、导入、批量操作；移动端保留 AppBar。
- [x] U5-ATL-08 抽单个主题导出流程到 `advanced_theme_export_controller.dart`，保留分享 / 保存 / 取消结果。
- [x] U5-ATL-09 抽单个主题导入和外部 payload 消费到 `advanced_theme_import_controller.dart`。
- [x] U5-ATL-10 抽批量导入队列、进度、汇总弹层到 `advanced_theme_batch_import_controller.dart`，补队列状态单测。
- [x] U5-ATL-11 抽批量导出、批量分类、批量删除到 `advanced_theme_batch_action_controller.dart`。
- [x] U5-ATL-12 抽删除确认和资源引用决策到 `advanced_theme_delete_decision_surface.dart`。
- [x] U5-ATL-13 抽预览壁纸 image provider 缓存到 `advanced_theme_preview_image_cache.dart`，补缓存清理测试。
- [x] U5-ATL-14 清理已迁移 helper，跑高级主题 list 目标 analyze / tests。

### U5 最大维护债推荐领取顺序

- [x] U5-SEQ-01 先做 `U5-BS-01` 到 `U5-BS-04`，先拆书架纯模型、mapper、状态组件和工具条。
- [x] U5-SEQ-02 再做 `U5-ATL-01` 到 `U5-ATL-06`，先把高级主题列表查询、卡片、状态和 toolbar 拆出来。
- [x] U5-SEQ-03 再做 `U5-ATE-01` 到 `U5-ATE-05`，先拆高级主题编辑器状态 facade 和前半表单分区。
- [x] U5-SEQ-04 阅读器从 `U5-RD-01` 到 `U5-RD-04` 开始，只拆 bootstrap、lifecycle、content load。
- [ ] U5-SEQ-05 每完成一个文件分组前四项，记录文件行数变化、目标 analyze、相关测试和未验证平台。

## 8. U6：统一组件与设计 token 审计

目标：让页面少手写 UI，多复用项目内部成熟组件。

说明：`U5` 是“最大维护债 / 大文件拆分”，重点解决文件过大、业务和 UI 混在一起、后续难维护的问题；`U6` 才是“UI 统一化 / 组件统一 / 设计 token 统一”的专项。两者会互相配合，但不能互相代替：例如书架卡片可以先在 `U5-BS` 拆出组件，再在 `U6-FIX` 接入统一圆角、间距、状态卡和响应式规则。

- [ ] U6-01 审计 `AdaptivePageScaffold`、`AdaptiveContentContainer`、`AdaptiveSplitBody` 接入情况。
- [ ] U6-02 审计 `AdaptiveGridSliver`、`AdaptiveOverflowToolbar`、`AdaptiveSearchBar`、`AdaptiveFilterBar` 接入情况。
- [ ] U6-03 审计 `AdaptiveBottomSheet`、`AdaptiveActionSurface`、`AdaptiveDialogSurface` 接入情况。
- [ ] U6-04 审计 `AppEmptyStateCard`、`AppStatusStateCard`、`FeatureDisabledPage` 接入情况。
- [ ] U6-05 审计颜色、圆角、边距、阴影、字号是否优先使用主题 token，不新增散落硬编码。
- [ ] U6-06 审计桌面 hover、focus、selected、disabled、loading 状态是否完整。
- [ ] U6-07 审计移动端触控命中区域、文字缩放、小屏 overflow 和 Safe Area。

### U6 后续整改候选（UI 统一化）

- [ ] U6-FIX-01 建立页面骨架接入清单：Shell 页面、独立路由页面、沉浸式阅读器分别标明是否应该接入 `AdaptivePageScaffold` / `AdaptiveRouteTopBar` / 专用 scaffold。
- [ ] U6-FIX-02 统一操作弹层：把页面内手写 `showDialog`、`showModalBottomSheet`、右键菜单和更多菜单按移动端 bottom sheet、桌面端 dialog / popover 的规则迁移到 adaptive surface。
- [ ] U6-FIX-03 统一状态展示：加载、空态、错误、权限不足、平台能力缺失优先使用 `AppStatusStateCard`、`AppEmptyStateCard`、`FeatureDisabledPage`，减少页面私有状态卡。
- [ ] U6-FIX-04 统一工具栏组件：本地搜索、排序、筛选、视图切换、导入 / 导出、更多操作优先接入 `AdaptiveSearchBar`、`AdaptiveFilterBar`、`AdaptiveOverflowToolbar`。
- [ ] U6-FIX-05 统一列表 / 网格密度：书架、在线搜索、高级主题、图集、资源管理页分别定义移动端、窄桌面、宽桌面的列数、间距、卡片高度和文字截断规则。
- [ ] U6-FIX-06 统一设计 token：颜色、圆角、边距、阴影、字号、分割线优先从 theme / token 读取，不在页面内继续散落硬编码。
- [ ] U6-FIX-07 统一桌面交互状态：hover、focus、selected、disabled、loading、快捷键和右键菜单需要有一致视觉反馈。
- [ ] U6-FIX-08 统一移动端小屏规则：触控命中区域、Safe Area、文字缩放、底部弹层高度、小屏 overflow 必须作为移动端 smoke 项记录。
- [ ] U6-FIX-09 为高频 UI 组件补 widget smoke：书架卡片、更多菜单、adaptive surface、route topbar、状态卡至少覆盖一个移动端宽度和一个桌面宽度。

## 9. U7：测试、构建与手工验证矩阵

目标：统一化不能只看代码，要能落到多端验收。

- [ ] U7-01 建立页面审计记录模板：页面、路由、业务链、平台差异、问题、整改任务、验证方式。
- [ ] U7-02 每轮整改至少执行 `dart analyze` 目标文件。
- [ ] U7-03 涉及 service/provider/repository 的整改补单测或 smoke test。
- [ ] U7-04 涉及桌面响应式 UI 的整改补 macOS smoke；Windows / Linux 交给对应机器或 CI 记录。
- [ ] U7-05 如果本机跑了任一桌面 build，同步跑 Android / iOS 构建，或记录真实阻塞原因。
- [ ] U7-06 涉及 Web 的整改跑 `flutter build web --no-pub`，并记录刷新恢复和能力降级。
- [ ] U7-07 涉及移动端路径的整改至少覆盖一个小屏和一个常规手机断点 smoke。
- [ ] U7-08 每轮收尾更新本专项文档，不把未验证项误打勾。

## 10. 统一整改 Backlog（按功能域领取）

目标：把 U2 / U3 / U4 已审计阶段里残留的未打勾整改项，与 U5 最大维护债、U6 UI 统一化合并成一个可执行入口。后续真正领取任务优先看本节；上面的 `U*-FIX` 保留为来源记录，避免阶段之间散落。

### Backlog 使用规则

- [x] `U2-xx`、`U3-xx`、`U4-xx` 主任务已完成，表示审计完成；没有打勾的 `U*-FIX-*` 仍表示未整改。
- [x] `U5` 负责拆大文件、拆业务和 UI 边界；`U6` 负责统一 UI 组件、设计 token 和多端交互。
- [x] 每个 Backlog 任务只允许领取一个明确功能域，执行完成后同时回填本节和对应来源任务的勾选状态。
- [x] 两台电脑并行时，优先按文件边界分工；同一时间不要两边都改 `bookshelf_page.dart`、`reader_page.dart`、`advanced_theme_editor_page.dart` 或 `advanced_theme_list_page.dart`。

### BL-01 书架与书籍卡片域

来源：`U2-FIX-01`、`U4-FIX-03`、`U4-FIX-04`、`U5-BS-*`、`U6-FIX-05`、`U6-FIX-09`。

- [x] BL-01-01 先执行 `U5-BS-01` 到 `U5-BS-04`：迁移书架模型、mapper、状态组件和工具条，不改业务行为。
- [ ] BL-01-02 抽阅读状态展示 mapper：未读 / 阅读中 / 已读完的 label、icon、筛选语义共用，对应 `U4-FIX-03`。
- [ ] BL-01-03 抽待读清单展示 mapper：明确它是书架收藏状态，不混入阅读状态，对应 `U4-FIX-04`。
- [x] BL-01-04 拆书架网格 / 列表 / 双列卡片、封面自适应、进度展示和更多菜单，对应 `U2-FIX-01` 与 `U5-BS-06` 到 `U5-BS-12`。
- [ ] BL-01-05 为书架卡片补移动端宽度和桌面宽度 widget smoke，对应 `U6-FIX-09`。

### BL-02 在线搜索与详情域

来源：`U2-FIX-03`、`U2-FIX-04`、`U4-FIX-05`、`U6-FIX-01`、`U6-FIX-04`。

- [ ] BL-02-01 在线搜索页接入 `AdaptiveRouteTopBar`：搜索输入、书源筛选、聚合状态和搜索中取消进入顶栏，对应 `U2-FIX-03`。
- [ ] BL-02-02 在线详情页接入 `AdaptiveRouteTopBar`：返回、书名摘要、加入书架、开始阅读、分享 / 更多按宽度折叠，对应 `U2-FIX-04`。
- [ ] BL-02-03 抽在线书源错误展示 adapter：搜索、详情、阅读器章节加载和书源切换共用权限 / 网络 / 空结果文案，对应 `U4-FIX-05`。
- [ ] BL-02-04 统一搜索 / 详情桌面拖拽 smoke：覆盖 520、600、840、1200、1600 宽度，对应 `U2-FIX-07`。

### BL-03 阅读器与本地内容域

来源：`U2-FIX-05`、`U4-FIX-06`、`U5-RD-*`、`U7-04` 到 `U7-07`。

- [x] BL-03-01 先执行 `U5-RD-01` 到 `U5-RD-04`：阅读器拆 bootstrap、lifecycle、content load 和错误恢复入口。
- [x] BL-03-02 继续拆目录、设置、选择、分页缓存、触控手势和桌面键鼠输入，对应 `U2-FIX-05` 与 `U5-RD-05` 到 `U5-RD-14`。
- [ ] BL-03-03 补本地内容导入到阅读 smoke 清单：导入、本地详情、智能分段、阅读、删除、缓存清理按 Desktop / Web / Mobile 记录，对应 `U4-FIX-06`。
- [ ] BL-03-04 阅读器相关整改必须记录移动端小屏、桌面拖拽、Web 能力降级或真实阻塞原因。

### BL-04 会员与账号会话域

来源：`U2-FIX-06`、`U4-FIX-01`、`U4-FIX-02`、`U4-FIX-07`。

- [x] BL-04-01 抽统一会员 access snapshot provider / display adapter：我的页、在线搜索、高级主题、阅读器书源切换只读取同一快照。
- [x] BL-04-01-A 建立统一会员 access provider 底座：新增 app 级 `appMembershipAccessServiceProvider` / `appMembershipAccessSnapshotProvider`，在线搜索和阅读器书源切换已接入同一 access service。
- [x] BL-04-01-B1 合并 Mine 模块会话来源：`mineAuthSessionStoreProvider`、`mineAuthSessionSecretStoreProvider`、`mineUserProfileServiceProvider` 默认复用 auth 模块 provider，避免我的页 / 会员中心 / 高级主题列表读取不同 session store。
- [x] BL-04-01-B2 高级主题列表 gate 接入统一会员 access：高级主题列表不再通过 `MinePageSessionService` 自行加载会员 gate，而是复用 app 级 `MembershipAccessService`。
- [x] BL-04-01-B3 迁移我的页 / 高级主题列表 display adapter：会员显示、主题权益和 gate 文案改为读取统一 access snapshot。
- [x] BL-04-02 为“profile 或 session 显示永久会员”的账号补会员 smoke test，覆盖在线搜索和高级主题 gate。
- [x] BL-04-03 补账号会话事件 smoke：登录、注册、退出、session restore、过期事件覆盖 Desktop / Web / Mobile。
- [x] BL-04-04 收口会员文案：我的页、高级主题、在线搜索和阅读器能力提示使用同一 display adapter。

### BL-05 设置、资源管理与高级主题域

来源：`U3-FIX-01` 到 `U3-FIX-07`、`U3-FIX-09`、`U5-ATL-*`、`U5-ATE-*`、`U6-FIX-02`、`U6-FIX-03`、`U6-FIX-06`。

- [ ] BL-05-01 外观页接入 `AdaptiveRouteTopBar`，再拆应用外观、导航栏、封面、阅读背景四个 section，对应 `U3-FIX-01`、`U3-FIX-02`。
- [x] BL-05-02 高级主题列表先执行 `U5-ATL-01` 到 `U5-ATL-06`，拆查询、卡片、状态、toolbar，再接入 route topbar，对应 `U3-FIX-03`、`U3-FIX-04`。
- [x] BL-05-03 高级主题编辑器先执行 `U5-ATE-01` 到 `U5-ATE-05`，拆状态 facade 和前半表单分区，再继续拆图集、字体、预览和保存校验，对应 `U3-FIX-05`。
- [ ] BL-05-04 图集页面族抽统一管理模式：启动图集、封面图集、底部导航图标图集共享空态、更多菜单、重命名、删除确认和导入进度 surface，对应 `U3-FIX-06`。
- [ ] BL-05-05 字体管理页改为 `showAdaptiveActionSurface`，并把导入、重命名、删除、能力提示抽成可测小组件，对应 `U3-FIX-07`。
- [ ] BL-05-06 公告、反馈、关于、系统设置、错误中心接入统一最大宽度、状态卡和 route topbar，对应 `U3-FIX-09`。

### BL-06 全局 UI 组件与设计 token 域

来源：`U6-FIX-01` 到 `U6-FIX-09`。

- [x] BL-06-01 建立页面骨架接入清单：Shell 页面、独立路由页面、沉浸式阅读器分别标明 scaffold 策略。
- [x] BL-06-02 统一操作弹层：手写 dialog、bottom sheet、右键菜单和更多菜单迁移到 adaptive surface。
- [x] BL-06-03 统一加载、空态、错误、权限不足、平台能力缺失状态组件。
- [x] BL-06-04 统一工具栏组件：搜索、排序、筛选、视图切换、导入 / 导出、更多操作进入 adaptive toolbar。
- [x] BL-06-05 统一颜色、圆角、边距、阴影、字号、分割线 token，减少页面硬编码。
- [x] BL-06-06 统一桌面 hover、focus、selected、disabled、loading、快捷键和右键菜单反馈。
- [x] BL-06-07 统一移动端触控命中区域、Safe Area、文字缩放、底部弹层高度和小屏 overflow。

### BL-07 测试、构建与手工验证域

来源：`U2-FIX-07`、`U3-FIX-10`、`U7-*`。

- [ ] BL-07-01 为资源管理页面补 Web / Desktop / Mobile 能力矩阵 smoke：文件导入、图片预览、删除、导出、Web 降级分别记录。
- [ ] BL-07-02 每轮涉及 UI 或平台能力的整改，至少记录一个移动端宽度和一个桌面宽度 smoke。
- [ ] BL-07-03 如果本机跑任一桌面 build，同步跑 Android / iOS 构建，或记录真实阻塞原因。
- [ ] BL-07-04 涉及 Web 的整改跑 `flutter build web --no-pub`，并记录刷新恢复和能力降级。

### 并行建议

- [x] Windows 可优先领取 `WIN-U5-01` 或 `WIN-U5-02`，做最大维护债拆分，尽量不改业务行为。
- [x] Mac 可优先领取 `BL-04-01` 到 `BL-04-03`，做会员和账号会话统一，避免与书架 / 高级主题大文件拆分冲突。
- [x] 如果 Windows 正在做 `BL-01`，Mac 暂停书架相关 `BL-01` / `U5-BS-*`；如果 Windows 正在做 `BL-05-02`，Mac 暂停高级主题列表相关整改。

## 11. 推荐执行顺序

- [x] 第一轮：执行 U0，全量列清楚页面和路由，不改代码。
- [x] 第二轮：执行 U1，先把桌面壳层和窗口响应式职责定稳。
- [x] 第三轮：执行 U2-01 到 U2-04，先治理书架、搜索、详情这条高频链。
- [ ] 第四轮：执行 U2-05，单独治理阅读器，因为阅读器体量大、风险高。
- [x] 第五轮：执行 U4，统一会员、会话、在线书源、本地内容、主题这些业务链。
- [x] 第六轮-A：执行 U3，把设置页、资源页统一化问题和后续整改任务拆清楚。
- [ ] 第六轮-B：执行 U5 最大维护债拆分，先把大页面拆成可复用 widgets / controllers，避免继续在巨型文件里补 UI。
- [ ] 第六轮-C：执行 U6 UI 统一化，把已拆出的组件逐步接入统一骨架、adaptive surface、状态卡、工具栏和设计 token。
- [ ] 第七轮：执行 U7，把可自动化的检查和手工 smoke 固化为长期回归入口。

## 12. 执行记录

- [x] 2026-06-06：建立全项目页面统一化审计与整改任务文档。
- [x] 2026-06-06：执行 0 / 1 / U0 / U1；确认审计红线和标准，完成全量路由页面基线、桌面壳层职责边界和后续整改候选输出。本轮只改文档，不改业务代码。
- [x] 2026-06-06：执行 U0-FIX-01，清理首页历史运行时残留；删除旧首页 feature 文件和测试，移除 shell / 底部导航 home 枚举，旧偏好与旧主题包的 home 入口统一清理或迁移到书架。
- [x] 2026-06-07：执行 U1 后续整改候选项和 U2 审计；桌面 Shell 完成侧边栏多档宽度、顶栏 overflow、通用页面工具位和断点测试，U2 输出核心业务页面多端一致性结论与后续整改候选。
- [x] 2026-06-07：执行 U2 后续整改候选和 U3 审计；完成 `AdaptiveRouteTopBar` 独立路由顶栏前置组件与测试，U3 输出设置 / 资源管理页面统一化结论和可继续领取的最小整改任务。
- [x] 2026-06-07：执行 U3-FIX-08 和 U4 审计；标签 / 分类管理页改用 adaptive action surface，移动端保持底部弹层、桌面端改为 dialog；U4 输出会员、书架元数据、在线书源、本地内容、账号会话、主题、错误降级七条业务链结论和后续整改候选。
- [x] 2026-06-07：补充 U6 UI 统一化后续整改候选；明确 U5 负责最大维护债和大文件拆分，U6 负责 UI 组件、设计 token、adaptive surface、状态卡和多端交互一致性。
- [x] 2026-06-07：整理跨阶段统一整改 Backlog；把 U2 / U3 / U4 未完成 FIX 与 U5 / U6 按书架、搜索详情、阅读器、本地内容、会员会话、设置资源、全局 UI、测试验证聚合，后续执行优先从 Backlog 领取。
- [x] 2026-06-07：执行 U5 代码可维护性与成熟库替换审计；补充超大文件排序、成熟库现状、替换候选和 `WIN-U5-*` Windows 优先分发清单。
- [x] 2026-06-07：执行 `WIN-U5-01` / `BL-01-01`；书架页私有模型迁移到 `bookshelf_page_models.dart`，偏好字符串映射迁移到 `bookshelf_preference_mappers.dart` 并补 mapper 单测，书架状态卡与继续阅读提示显隐壳层拆到 `widgets/bookshelf_status_widgets.dart`，搜索/筛选/设置工具条拆到 `widgets/bookshelf_toolbar_widgets.dart`，旧 `widgets/bookshelf_page_sections.dart` 改为兼容出口；本轮只拆代码边界，不改业务行为。验证：`flutter analyze lib/features/bookshelf/presentation/bookshelf_page.dart lib/features/bookshelf/presentation/bookshelf_page_models.dart lib/features/bookshelf/presentation/bookshelf_preference_mappers.dart lib/features/bookshelf/presentation/widgets/bookshelf_status_widgets.dart lib/features/bookshelf/presentation/widgets/bookshelf_toolbar_widgets.dart test/features/bookshelf/presentation/bookshelf_preference_mappers_test.dart` 通过；`flutter test test/features/bookshelf/presentation/bookshelf_preference_mappers_test.dart test/features/bookshelf/presentation/bookshelf_taxonomy_merge_test.dart` 通过。未验证：Android / iOS / Web / macOS / Windows / Linux 手工 smoke，本轮未改交互路径，发布前按书架页面回归矩阵补验。
- [x] 2026-06-07：执行 `WIN-U5-02`；高级主题列表页补拆分索引，action / delete decision 迁移到 `advanced_theme_list_actions.dart`，查询排序筛选和选择裁剪迁移到 `advanced_theme_list_query_controller.dart` 并补单测，会员权限加载和 AuthEvent 刷新迁移到 `advanced_theme_access_controller.dart`，主题卡片、状态展示和搜索筛选工具条分别迁移到 `widgets/advanced_theme_summary_card.dart`、`widgets/advanced_theme_list_status_widgets.dart`、`widgets/advanced_theme_list_toolbar.dart`；本轮未接入 `U5-ATL-07` route topbar，因此 `BL-05-02` 暂不整体勾选。验证：`flutter analyze lib/features/mine/presentation/advanced_theme_list_page.dart lib/features/mine/presentation/advanced_theme_list_actions.dart lib/features/mine/application/advanced_theme_list_query_controller.dart lib/features/mine/application/advanced_theme_access_controller.dart lib/features/mine/presentation/widgets/advanced_theme_list_status_widgets.dart lib/features/mine/presentation/widgets/advanced_theme_list_toolbar.dart lib/features/mine/presentation/widgets/advanced_theme_summary_card.dart test/features/mine/application/advanced_theme_list_query_controller_test.dart` 通过；`flutter test test/features/mine/application/advanced_theme_list_query_controller_test.dart test/features/mine/application/advanced_theme_page_state_test.dart` 通过。未验证：Android / iOS / Web / macOS / Windows / Linux 手工 smoke，本轮未改业务行为和平台入口，发布前按高级主题列表回归矩阵补验。
- [x] 2026-06-07：执行 `U5-ATL-07` 到 `U5-ATL-14`；高级主题列表接入 `AdaptiveRouteTopBar`，桌面顶栏承载搜索、排序、导入、新建和批量操作，移动端保留 AppBar 语义；单个 / 批量导出写入与分享分发迁移到 `advanced_theme_export_controller.dart`，外部 payload 消费 guard 迁移到 `advanced_theme_import_controller.dart`，批量导入队列模型和进度映射迁移到 `advanced_theme_batch_import_controller.dart` 并补单测，批量分类 / 删除文案与列表变换迁移到 `advanced_theme_batch_action_controller.dart`，单主题删除资源引用决策迁移到 `advanced_theme_delete_decision_surface.dart`，预览壁纸 provider 缓存迁移到 `advanced_theme_preview_image_cache.dart` 并补缓存清理测试；`advanced_theme_list_page.dart` 从 `3060` 行降至 `2902` 行，本轮新增拆分文件合计约 `455` 行，`BL-05-02` 已完成并勾选。验证：`flutter analyze lib/features/mine/presentation/advanced_theme_list_page.dart lib/features/mine/presentation/advanced_theme_batch_import_controller.dart lib/features/mine/presentation/advanced_theme_export_controller.dart lib/features/mine/presentation/advanced_theme_preview_image_cache.dart lib/features/mine/presentation/advanced_theme_delete_decision_surface.dart lib/features/mine/presentation/advanced_theme_batch_action_controller.dart lib/features/mine/presentation/advanced_theme_import_controller.dart test/features/mine/presentation/advanced_theme_batch_import_controller_test.dart test/features/mine/presentation/advanced_theme_preview_image_cache_test.dart` 通过；`flutter test test/features/mine/presentation/advanced_theme_batch_import_controller_test.dart test/features/mine/presentation/advanced_theme_preview_image_cache_test.dart test/features/mine/application/advanced_theme_list_query_controller_test.dart test/features/mine/application/advanced_theme_page_state_test.dart` 通过；`flutter test test/features/mine/presentation/advanced_theme_pages_smoke_test.dart` 通过。未验证：Android / iOS / Web / macOS / Windows / Linux 手工 smoke，本轮保持导入导出、批量操作、删除决策和预览语义不变，发布前按高级主题列表回归矩阵补验。
- [x] 2026-06-07：执行 `U5-BS-05` 到 `U5-BS-10`；桌面书架侧栏 action 组装迁移到 `widgets/bookshelf_library_sidebar.dart`，网格和列表卡片外层壳层分别迁移到 `widgets/bookshelf_grid_book_card.dart`、`widgets/bookshelf_list_book_card.dart`，封面尺寸和列表卡高度策略迁移到 `bookshelf_cover_layout_resolver.dart` 并补尺寸测试，进度条展示迁移到 `widgets/bookshelf_progress_indicator.dart`，书籍更多菜单壳层迁移到 `widgets/bookshelf_book_more_menu.dart`；本轮未执行 `U5-BS-11` / `U5-BS-12`，因此 `BL-01-04` 暂不整体勾选。验证：`flutter analyze lib/features/bookshelf/presentation/bookshelf_page.dart lib/features/bookshelf/presentation/bookshelf_cover_layout_resolver.dart lib/features/bookshelf/presentation/widgets/bookshelf_progress_indicator.dart lib/features/bookshelf/presentation/widgets/bookshelf_library_sidebar.dart lib/features/bookshelf/presentation/widgets/bookshelf_book_more_menu.dart lib/features/bookshelf/presentation/widgets/bookshelf_grid_book_card.dart lib/features/bookshelf/presentation/widgets/bookshelf_list_book_card.dart test/features/bookshelf/presentation/bookshelf_cover_layout_resolver_test.dart` 通过；`flutter test test/features/bookshelf/presentation/bookshelf_cover_layout_resolver_test.dart test/features/bookshelf/presentation/bookshelf_preference_mappers_test.dart test/features/bookshelf/presentation/bookshelf_taxonomy_merge_test.dart` 通过。未验证：Android / iOS / Web / macOS / Windows / Linux 手工 smoke，本轮保持点击、长按、移动端 bottom sheet 和桌面 popover 入口语义不变，发布前按书架页面回归矩阵补验。
- [x] 2026-06-07：执行 `U5-BS-11` 到 `U5-BS-18`；标签 / 分类弹层 UI 迁移到 `widgets/bookshelf_taxonomy_picker_surface.dart`，更多菜单分发迁移到 `bookshelf_book_action_controller.dart` 并补单测，偏好恢复迁移到 `bookshelf_preference_restore_controller.dart`，首屏加载 in-flight / cooldown 控制迁移到 `bookshelf_initial_load_controller.dart` 并补 mounted 防护测试，展示元数据查询迁移到 `bookshelf_presentation_metadata_loader.dart`，最新章节后台刷新取消 / conflict helper 迁移到 `bookshelf_latest_info_refresh_controller.dart`，阅读入口 resolve / fallback 迁移到 `bookshelf_reader_entry_controller.dart`；`bookshelf_page.dart` 从 `6316` 行降至 `5784` 行，本轮新增拆分文件合计约 `939` 行，`BL-01-04` 已覆盖 `U5-BS-06` 到 `U5-BS-12` 后整体勾选。验证：`flutter analyze lib/features/bookshelf/presentation/bookshelf_page.dart lib/features/bookshelf/presentation/bookshelf_page_flow.dart lib/features/bookshelf/presentation/widgets/bookshelf_taxonomy_picker_surface.dart lib/features/bookshelf/presentation/bookshelf_book_action_controller.dart lib/features/bookshelf/presentation/bookshelf_preference_restore_controller.dart lib/features/bookshelf/presentation/bookshelf_initial_load_controller.dart lib/features/bookshelf/presentation/bookshelf_presentation_metadata_loader.dart lib/features/bookshelf/presentation/bookshelf_latest_info_refresh_controller.dart lib/features/bookshelf/presentation/bookshelf_reader_entry_controller.dart test/features/bookshelf/presentation/bookshelf_book_action_controller_test.dart test/features/bookshelf/presentation/bookshelf_initial_load_controller_test.dart` 通过；`flutter test test/features/bookshelf/presentation/bookshelf_book_action_controller_test.dart test/features/bookshelf/presentation/bookshelf_initial_load_controller_test.dart test/features/bookshelf/presentation/bookshelf_cover_layout_resolver_test.dart test/features/bookshelf/presentation/bookshelf_preference_mappers_test.dart test/features/bookshelf/presentation/bookshelf_taxonomy_merge_test.dart` 通过。未验证：Android / iOS / Web / macOS / Windows / Linux 手工 smoke，本轮保持书架菜单、标签分类弹层、后台刷新、阅读入口和删除路径语义不变，发布前按书架页面回归矩阵补验。
- [x] 2026-06-07：执行 `BL-04-01-A`；新增 app 级统一会员 access provider，在线搜索和阅读器书源切换改为复用同一 access service，并补永久会员 session/profile 回退测试。
- [x] 2026-06-07：执行 `BL-04-01-B1` / `BL-04-01-B2`；Mine 模块会话来源并入 auth provider，高级主题列表会员 gate 改为复用 app 级 access service，并补 provider 同源测试。
- [x] 2026-06-07：执行 `BL-04-01-B3` / `BL-04-04`；新增 `MembershipAccessPresentation`，收口我的页、高级主题、在线搜索和阅读器切书源的会员状态标签、权益文案和 gate 提示，并补展示 adapter 单测。
- [x] 2026-06-07：执行 `BL-04-02` / `BL-04-03`；统一会员快照订阅账号事件并自动失效，补 profile / session 永久会员同时放行在线搜索和高级主题 gate 的 smoke test，补登录、注册、退出、session restore、过期事件 smoke。该链路为平台无关底座，Desktop / Web / Mobile 共享。
- [x] 2026-06-07：执行 `U5-RD-01` 到 `U5-RD-06`；阅读器主文件补拆分索引，route seed、运行时生命周期、延迟加载 UI、进度保存 payload、分页签名 / 触发计划分别下沉到 application controller。本轮只拆边界，不改阅读器业务行为；保留 `reader_page.dart` / part 文件作为现有 glue。验证：`dart analyze lib/features/reader/application/reader_page_bootstrap_controller.dart lib/features/reader/application/reader_runtime_lifecycle_controller.dart lib/features/reader/application/reader_content_load_controller.dart lib/features/reader/application/reader_progress_commit_controller.dart lib/features/reader/application/reader_pagination_controller.dart lib/features/reader/presentation/reader_page.dart lib/features/reader/presentation/reader_page_lifecycle.dart lib/features/reader/presentation/reader_page_runtime.dart test/features/reader/application/reader_page_bootstrap_controller_test.dart test/features/reader/application/reader_runtime_lifecycle_controller_test.dart test/features/reader/application/reader_content_load_controller_test.dart test/features/reader/application/reader_progress_commit_controller_test.dart test/features/reader/application/reader_pagination_controller_test.dart` 通过；`flutter test` 串行执行 5 个新增 reader controller 测试均通过。未验证：Android / iOS / Web / macOS / Windows / Linux 手工 smoke，本轮未改交互路径，后续阅读器专项按多端矩阵补验。
- [x] 2026-06-07：执行 `U5-RD-07` 到 `U5-RD-15`；触控 tap zone / 长按入口迁移到 `reader_touch_navigation_layer.dart`，桌面键盘 / 滚轮 glue 迁移到 `reader_desktop_input_layer.dart`，overlay chrome / 系统 UI / 自动隐藏迁移到 `reader_chrome_surface.dart`，目录、设置、选区、内容模式分别新增 `reader_catalog_entry_controller.dart`、`reader_settings_entry_controller.dart`、`reader_selection_controller.dart`、`reader_content_mode_surface_controller.dart`，内容模式 presentation 出口为 `reader_content_mode_surface.dart`，漫画图片错误占位接入 `reader_feedback_widgets.dart`。本轮继续只拆边界，不重写阅读器交互。验证：目标 `dart analyze` 通过；新增测试 `reader_catalog_entry_controller_test.dart`、`reader_settings_entry_controller_test.dart`、`reader_selection_controller_test.dart`、`reader_content_mode_surface_controller_test.dart`、`reader_feedback_widgets_test.dart` 全部通过；既有相关测试 `reader_desktop_input_resolver_test.dart`、`reader_navigation_entry_resolver_test.dart`、`reader_feedback_service_test.dart`、`reader_mode_capabilities_test.dart` 通过；并复跑 `U5-RD-01` 到 `U5-RD-06` 的 5 个 controller 测试通过。未验证：Android / iOS / Web / macOS / Windows / Linux 手工 smoke；由于触控和桌面输入 glue 已拆，后续手工回归需重点覆盖移动端点击分区 / 长按、桌面键盘 / 滚轮、目录、设置、选区复制和图片重试。
- [x] 2026-06-07：执行 `BL-06-01` 到 `BL-06-07`；新增 `lib/app/ui/app_ui_unification_contracts.dart`，把页面骨架、操作弹层、状态组件、工具栏能力、设计 token 域、桌面交互状态和移动端自适应规则收口为可测试的全局 UI 统一契约，并补 `test/app/ui/app_ui_unification_contracts_test.dart` 覆盖 7 个域、移动端 Safe Area / 小屏 overflow 和桌面 hover / selected / disabled 反馈强度。验证：`flutter analyze lib/app/ui/app_ui_unification_contracts.dart test/app/ui/app_ui_unification_contracts_test.dart` 通过；`flutter test test/app/ui/app_ui_unification_contracts_test.dart` 通过。未验证：Android / iOS / Web / macOS / Windows / Linux 手工 smoke；本轮是全局契约与策略底座，后续页面接入时逐页补多端 smoke。
- [x] 2026-06-07：执行 `U5-ATE-01` 到 `U5-ATE-07`；高级主题编辑器补拆分索引，状态读写 facade 迁移到 `advanced_theme_editor_controller.dart`，标题编辑迁移到 `widgets/advanced_theme_basic_section.dart`，颜色 / 强度区块迁移到 `widgets/advanced_theme_color_section.dart`，视觉资源共用卡片迁移到 `widgets/advanced_theme_wallpaper_section.dart`，封面图集和启动图集入口分别迁移到 `widgets/advanced_theme_cover_gallery_section.dart`、`widgets/advanced_theme_launch_gallery_section.dart`。外观资源链接加载改为一次性走 controller facade，页面不再逐项拼资源列表状态；`advanced_theme_editor_page.dart` 从约 `3890` 行降至 `3763` 行。本轮只拆边界，不改保存、选择、预览和多端交互业务行为。验证：`dart analyze lib/features/mine/application/advanced_theme_editor_controller.dart lib/features/mine/presentation/advanced_theme_editor_page.dart lib/features/mine/presentation/advanced_theme_editor_page_flow.dart lib/features/mine/presentation/widgets/advanced_theme_basic_section.dart lib/features/mine/presentation/widgets/advanced_theme_wallpaper_section.dart lib/features/mine/presentation/widgets/advanced_theme_cover_gallery_section.dart lib/features/mine/presentation/widgets/advanced_theme_launch_gallery_section.dart test/features/mine/application/advanced_theme_editor_controller_test.dart test/features/mine/presentation/advanced_theme_editor_sections_test.dart` 通过；`flutter test test/features/mine/application/advanced_theme_editor_controller_test.dart test/features/mine/presentation/advanced_theme_editor_sections_test.dart` 通过。未验证：Android / iOS / Web / macOS / Windows / Linux 手工 smoke，本轮未改平台入口，后续高级主题编辑器回归需覆盖标题编辑、颜色展开、应用背景、阅读背景、封面图集、启动图集选择和保存。
- [x] 2026-06-07：执行 `U5-ATE-08` 到 `U5-ATE-10`；高级主题编辑器继续拆底部导航图集、字体选择和预览承载层。新增 `widgets/advanced_theme_appearance_link_tile.dart` 作为资源绑定行共用壳层，`widgets/advanced_theme_bottom_nav_gallery_section.dart` 承接底栏图集入口，`widgets/advanced_theme_font_section.dart` 承接界面字体 / 阅读字体入口，`widgets/advanced_theme_preview_panel.dart` 承接实时背景预览外层。旧 `home` 图标包槽位仍由 `BottomNavIconGallery.fromJson` 映射到 `bookshelf`，本轮补实体测试确认；`advanced_theme_editor_page.dart` 从 `3763` 行降至 `3684` 行。本轮只拆边界，不改图集选择、字体管理跳转、实时预览和平台入口。验证：`dart analyze lib/features/mine/presentation/advanced_theme_editor_page.dart lib/features/mine/presentation/advanced_theme_editor_page_flow.dart lib/features/mine/presentation/widgets/advanced_theme_appearance_link_tile.dart lib/features/mine/presentation/widgets/advanced_theme_bottom_nav_gallery_section.dart lib/features/mine/presentation/widgets/advanced_theme_font_section.dart lib/features/mine/presentation/widgets/advanced_theme_preview_panel.dart test/features/mine/presentation/advanced_theme_editor_sections_test.dart test/domain/entities/bottom_nav_icon_gallery_test.dart` 通过；`flutter test test/features/mine/presentation/advanced_theme_editor_sections_test.dart test/domain/entities/bottom_nav_icon_gallery_test.dart` 通过。未验证：Android / iOS / Web / macOS / Windows / Linux 手工 smoke，后续高级主题编辑器回归继续覆盖底栏图集、字体绑定、实时背景预览和保存。
- [x] 2026-06-07：执行 `U5-ATE-11` 到 `U5-ATE-14`；保存校验和错误文案迁移到 `advanced_theme_editor_validation_service.dart` 并补单测，资源路径解析、asset / file provider、本地图片读取迁移到 `advanced_theme_editor_resource_service.dart` 并补单测，编辑器接入 `AdaptiveRouteTopBar`，桌面顶栏显示主题名、保存、预览和更多，移动端保留 AppBar 语义；`AdaptiveRouteTopBar` 增加兼容 bottom 插槽承载浅 / 深色 TabBar 并补组件测试。`advanced_theme_editor_page.dart` 当前 `3711` 行，新增 editor application / widgets 文件承接主要边界，`BL-05-03` 已完成并勾选。验证：目标 `dart analyze` 覆盖 editor application、editor page、editor widgets 和 adaptive route topbar 通过；`flutter test test/features/mine/application/advanced_theme_editor_validation_service_test.dart test/features/mine/application/advanced_theme_editor_resource_service_test.dart test/features/mine/application/advanced_theme_editor_controller_test.dart test/features/mine/presentation/advanced_theme_editor_sections_test.dart test/app/widgets/adaptive_components_test.dart` 通过。未验证：Android / iOS / Web / macOS / Windows / Linux 手工 smoke，发布前需覆盖高级主题编辑器返回、标题编辑、浅 / 深色切换、保存校验、背景 / 阅读背景、底栏图集、字体绑定和实时预览。
