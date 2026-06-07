# U5-LIB 成熟库与统一组件替换执行计划

更新时间：2026-06-07

## 1. 目标

本计划承接《全项目页面统一化审计与整改任务》里的 `U5-LIB-01` 到 `U5-LIB-07`。页面统一化已经完成了第一轮业务链、路由顶栏、状态展示和多端验证收口；本计划继续处理“手搓实现换成熟实现、不稳定实现换稳定实现”的长期维护债。

本计划不是一次性重写项目。后续 AI 或开发者每次只领取一个最小 checkbox，完成后必须记录影响平台、目标 `dart analyze`、目标测试、构建或未验证原因。

## 2. 执行红线

- [x] 只替换有明确维护收益的手搓实现，不为了“看起来更现代”盲目加依赖。
- [x] 优先复用项目已有成熟组件：`showAdaptiveActionSurface`、`showAdaptiveRawSurface`、`AdaptiveRouteTopBar`、`AdaptiveOverflowToolbar`、`AppStatusStateCard`、`AppEmptyStateCard`、`FeatureDisabledPage`、managed storage、reader / bookshelf / membership adapter。
- [x] 新增外部库前必须确认 Android、iOS、Web JS、macOS、Windows、Linux 支持情况，并写明 Web Wasm 影响。
- [x] 移动端和桌面端交互不能互相覆盖：移动端保留 bottom sheet / 触控路径，桌面端优先 dialog / popover / 键鼠路径。
- [x] 涉及旧数据、旧 key、旧 JSON、用户文件路径、数据库迁移时，必须先补兼容测试或写明手工验证步骤。
- [x] 复杂代码新增或改动时使用标准中文维护注释，注释解释边界、原因和风险，不复述代码字面行为。

## 3. 当前扫描结论

- 页面级弹层残留集中在 `bookmarks_page.dart`、`reader_page_settings_sheet.dart`、`reader_catalog_sheet.dart`、`shell_scaffold.dart`。自适应弹层组件本身的 `showDialog` / `showModalBottomSheet` 不算债务。
- 错误展示残留集中在 `book_detail_page.dart`、`reader_page.dart`、`reader_page_source_switch.dart`、`feedback_page.dart`、公告页和本地内容 parser / service。已有 `online_source_error_presentation.dart`、`ReaderFailurePresentationService`、`LocalBookWorkflowPolicy`，后续应继续收口。
- 响应式残留不是简单删除 `LayoutBuilder`。阅读器渲染、文本测量、漫画翻页等必须保留局部测量；需要治理的是页面级重复断点、重复列数、重复弹层高度和工具栏折叠策略。
- 文件和缓存路径残留主要在资源与本地内容服务层，尤其 `advanced_theme_service.dart`、图集服务、reader font / cache / local book 相关服务。页面层不应新增直接路径拼接。
- 模型治理已有 `freezed` / `json_serializable` 基础，但阅读设置、阅读进度、高级主题、图集等模型仍有手写 JSON / copyWith。模型迁移风险高，排在后续。
- 异步取消和节流残留较多，尤其书架、搜索、阅读器、高级主题导入导出。已有部分 controller 拆分，后续继续把 request id、mounted guard、取消和结果归属下沉到 controller。

## 4. U5-LIB-02 弹层替换

目标：页面级 `showDialog` / `showModalBottomSheet` 逐步迁移到 adaptive surface，让移动端和桌面端各走合理交互。

- [x] U5-LIB-02-01 迁移 `bookmarks_page.dart` 删除确认弹层：阅读记录、书签、灵感删除确认改为 `showAdaptiveActionSurface`，移动端保留底部确认，桌面端使用 dialog。
- [x] U5-LIB-02-02 为 `bookmarks_page.dart` 删除确认补 widget smoke，覆盖 390 移动宽度和 840 桌面宽度。
- [x] U5-LIB-02-03 迁移 `shell_scaffold.dart` 退出确认弹层：保持侧边栏退出按钮业务不变，弹层走 adaptive surface。
- [ ] U5-LIB-02-04 盘点 `reader_page_settings_sheet.dart` 内部二级 bottom sheet，区分移动端专属设置选择和可复用 adaptive surface。
- [ ] U5-LIB-02-05 迁移 `reader_catalog_sheet.dart` 目录弹层入口前，先输出移动端 bottom sheet / 桌面 side panel 的交互边界，避免破坏阅读器手势。
- [ ] U5-LIB-02-06 每迁移一个弹层后记录影响平台、返回值兼容、点击空白关闭、键盘 Esc、Android 返回键表现。

## 5. U5-LIB-03 状态卡替换

目标：页面私有加载、空态、错误、权限不足、平台能力缺失组件逐步替换为统一状态组件。

- [x] U5-LIB-03-01 盘点公告、反馈、关于、系统设置、错误中心之外仍在页面私有实现的空态 / 错误态。
- [x] U5-LIB-03-02 迁移 `bookmarks_page.dart` 空态和错误态到 `AppStatusStateCard` / `AppEmptyStateCard`。
- [ ] U5-LIB-03-03 迁移搜索失败详情、导出失败和部分失败摘要到统一状态卡外壳，保留现有错误明细业务。
- [ ] U5-LIB-03-04 迁移本地内容导入 / 索引失败入口到统一 `FeatureDisabledPage` 或 `AppStatusStateCard`，不改变重建索引业务。
- [ ] U5-LIB-03-05 为每个迁移页面补至少一个空态或错误态 widget smoke。

## 6. U5-LIB-04 响应式组件替换

目标：页面级重复宽度判断迁移到项目内部 adaptive 组件和断点策略。

- [x] U5-LIB-04-01 盘点 `search_page.dart` 内直接宽度 / 高度判断，标记哪些应迁到 `AdaptiveRouteTopBar`、`AdaptiveOverflowToolbar` 或结果网格 resolver。
- [x] U5-LIB-04-02 盘点 `book_detail_page.dart` 内详情正文、操作区、目录区宽度判断，输出桌面拖拽策略和可拆组件清单。
- [x] U5-LIB-04-03 盘点 `appearance_page_view.dart` 和图集页的列数 / 最大宽度判断，能复用 `AdaptiveGridSliver` 的先迁移低风险区域。
- [ ] U5-LIB-04-04 阅读器渲染类 `LayoutBuilder` 默认保留；只治理阅读器设置、目录、overlay chrome 的页面级重复断点。
- [ ] U5-LIB-04-05 每轮响应式替换至少跑 390、520、840、1200 宽度 smoke 或记录真实窗口手工验收。

## 7. U5-LIB-06 错误展示 adapter

目标：搜索、详情、阅读器、公告、反馈等网络或业务错误逐步收口到共享错误展示服务。

- [x] U5-LIB-06-01 把 `book_detail_page.dart` 的 `_toUserReadableError` 合并到 `OnlineSourceErrorPresentationAdapter` 或新的 detail error adapter，保留本地图书错误走 `LocalBookWorkflowPolicy`。
- [x] U5-LIB-06-02 把 `reader_page.dart` / `reader_page_source_switch.dart` 的在线章节错误映射迁到共享在线书源错误 adapter。
- [x] U5-LIB-06-03 为详情页和阅读器错误映射补单测：网络、规则解析、编码、权限、未知错误分别覆盖。
- [ ] U5-LIB-06-04 公告和反馈页继续保留业务文案，但将 AppException fallback 统一到一个低频网络错误 presentation helper。
- [ ] U5-LIB-06-05 本地内容 parser / service 的错误文案不强行并入在线 adapter；只抽本地内容错误 presentation，避免在线 / 本地语义混用。

## 8. U5-LIB-07 异步取消与节流

目标：把重复请求、取消、mounted guard、结果归属从页面层下沉到可测试 controller。

- [x] U5-LIB-07-01 盘点 `search_page.dart` 搜索取消、书源加载、分页、失败导出中的 request id / in-flight 状态。
- [x] U5-LIB-07-02 盘点 `reader_page_runtime.dart` 和 `reader_page_content_loading.dart` 的章节加载、预取、重试、错误恢复归属。
- [x] U5-LIB-07-03 盘点 `advanced_theme_list_page.dart` 和 `advanced_theme_service.dart` 导入导出任务是否还存在页面持有进度和结果归属。
- [x] U5-LIB-07-04 为搜索链先抽一个小型 cancel / ownership controller，不改 UI，只确保 disposed 后不再写页面状态。
- [x] U5-LIB-07-05 为阅读器章节加载补过期结果丢弃测试，避免快速切章后旧结果覆盖新章节。

## 9. U5-LIB-05 文件与缓存路径

目标：页面和大型 service 不直接拼用户文件路径、缓存路径或临时路径，统一走 managed storage / local book storage / resource service。

- [x] U5-LIB-05-01 审计 `advanced_theme_service.dart` 中路径拼接、资源复制、导入导出、迁移逻辑，按资源读写 / 导入导出 / 存储迁移拆分候选。
- [x] U5-LIB-05-02 审计 `launch_image_gallery_service.dart`、`cover_gallery_service.dart`、`bottom_nav_icon_gallery_service.dart` 是否能共享资源路径 helper。
- [x] U5-LIB-05-03 审计 reader font / background / cache 服务，明确哪些路径属于用户资产、托管资产、临时缓存。
- [ ] U5-LIB-05-04 新增或修改路径服务时，必须补 Web 能力降级和 macOS / Windows 路径 smoke 说明。
- [ ] U5-LIB-05-05 不直接迁移本地书库核心路径；本地图书涉及用户资产保护，必须单独小任务和回滚策略。

## 10. U5-LIB-01 模型生成式治理

目标：将高风险手写模型逐步迁移到 `freezed` / `json_serializable` 或至少补齐类型安全边界。

- [x] U5-LIB-01-01 盘点 `reader_settings.dart`、`reading_progress.dart`、`app_advanced_theme.dart`、图集模型的字段数量、JSON 兼容要求和旧数据来源。
- [x] U5-LIB-01-02 先选择一个低风险展示型模型试点 `freezed`，不能从阅读进度或高级主题主模型开始。
- [x] U5-LIB-01-03 为试点模型补 copyWith、默认值、JSON round-trip、旧 payload 兼容测试。
- [x] U5-LIB-01-04 评估生成文件对现有 architecture guard、analyze、build_runner 的影响。
- [x] U5-LIB-01-05 阅读进度、高级主题、图集主模型只在试点稳定后迁移，必须带旧数据兼容和回滚说明。

## 11. 推荐领取顺序

- [x] 第一批：`U5-LIB-02-01` 到 `U5-LIB-02-03`，先做 bookmarks 和 shell 的确认弹层替换。
- [x] 第二批：`U5-LIB-06-01` 到 `U5-LIB-06-03`，合并详情页 / 阅读器在线错误展示。
- [x] 第三批：`U5-LIB-03-01` 到 `U5-LIB-03-02`，迁移 bookmarks 状态卡。
- [x] 第四批：`U5-LIB-04-01` 到 `U5-LIB-04-03`，只做页面级响应式盘点和低风险图集页迁移。
- [x] 第五批：`U5-LIB-07-01` 到 `U5-LIB-07-05`，抽搜索和阅读器异步 ownership controller。
- [x] 第六批：`U5-LIB-05-01` 到 `U5-LIB-05-03`，拆资源路径 service。
- [x] 第七批：`U5-LIB-01-01` 到 `U5-LIB-01-05`，模型生成式治理试点。

## 12. 收尾记录

- [x] 2026-06-07：建立 U5-LIB 专项文档；初步扫描弹层、错误展示、响应式、模型、异步和路径残留，确认第一批优先从 `bookmarks_page.dart` 和 `shell_scaffold.dart` 的确认弹层开始。
- [x] 2026-06-07：执行 `U5-LIB-02-01` 到 `U5-LIB-02-03`；`bookmarks_page.dart` 的批量删除、单条灵感删除和书籍详情删除所有确认弹层统一迁移到 `showBookmarkDeleteConfirmSurface`，该 surface 复用 `showAdaptiveActionSurface`，移动端为底部弹层、桌面端为 dialog；`shell_scaffold.dart` 的退出登录确认也迁移到 `showAdaptiveActionSurface`，退出业务和 session 清理路径保持不变。验证：`dart analyze lib/features/mine/presentation/bookmarks_page.dart lib/app/shell_scaffold.dart test/features/mine/presentation/bookmarks_delete_surface_test.dart` 通过；`flutter test test/features/mine/presentation/bookmarks_delete_surface_test.dart` 通过，覆盖 390 移动宽度和 840 桌面宽度。未验证：Android / iOS / macOS / Windows / Linux 真机或真实窗口手工点击；执行整页 `BookmarksPage` smoke 时暴露出既有分栏布局约束问题，已记录为后续 `U5-LIB-04` 响应式治理候选，不在本批弹层替换中扩大处理。
- [x] 2026-06-07：执行 `U5-LIB-06-01` 到 `U5-LIB-06-03` 与 `U5-LIB-03-01` 到 `U5-LIB-03-02`；`OnlineSourceErrorPresentationAdapter` 新增阅读器章节错误出口，保留 403、404、超时、正文配置缺失、正文解析为空等阅读器原有细文案，`reader_page.dart` / `reader_page_source_switch.dart` 通过同一 `_toUserReadableError` 出口读取共享 adapter；`book_detail_page.dart` 已保持在线详情错误走同一 adapter、本地图书错误走 `LocalBookWorkflowPolicy`，本轮补测试确认。`bookmarks_page.dart` 空态迁移到 `BookmarksEmptyStateCard` / `AppEmptyStateCard`，错误态收口为 `BookmarksStatusStateCard` / `AppStatusStateCard`，避免页面私有空态继续扩散。验证：目标 `dart analyze` 覆盖在线错误 adapter、reader、detail、bookmarks 和新增测试通过；`flutter test test/features/search/presentation/online_source_error_presentation_test.dart test/features/mine/presentation/bookmarks_state_cards_test.dart test/features/mine/presentation/bookmarks_delete_surface_test.dart` 通过。未验证：Android / iOS / Web / macOS / Windows / Linux 真机手工；本轮只改文案出口和状态卡外壳，不改业务请求、删除或导航路径。
- [x] 2026-06-07：执行第四批 `U5-LIB-04-01` 到 `U5-LIB-04-03`；确认 `search_page.dart` 已使用 `AdaptiveRouteTopBar`、`AdaptiveOverflowToolbar` 和 `AdaptiveGridSliver`，剩余 `MediaQuery` / `LayoutBuilder` 主要用于安全区、键盘避让、弹层高度和页面最大宽度，不做无收益替换；确认 `book_detail_page_view.dart` 顶栏和正文最大宽度已统一，目录区和操作区的弹层高度 / 桌面判断属于交互边界，后续如继续拆应拆到 detail action / catalog 组件，不直接改页面外壳；确认 `appearance_page_view.dart` 的预览测量和编辑器图集预览属于局部视觉测量，默认保留。低风险迁移：`cover_gallery_page.dart`、`launch_image_gallery_page.dart`、`bottom_nav_icon_gallery_page.dart` 桌面图集网格从私有 `SliverGridDelegateWithMaxCrossAxisExtent` 迁到 `AdaptiveGridSliver`，列数、间距和比例交给统一 adaptive 组件收口。
- [x] 2026-06-07：执行第五批 `U5-LIB-07-01` 到 `U5-LIB-07-05`；盘点搜索页后确认搜索执行已有 `SearchCancellationToken`、`searchSessionId` 和 render controller，在线搜索会员权限刷新仍是页面 request id 判断，已新增 `AsyncOwnershipController` 并接入该链路，页面 dispose 或登录状态变化后会推进 generation，旧权限检查结果不能再写回页面状态。阅读器已存在 `ReaderSessionController` 管理章节、预取和分页 generation，本轮不重复造轮子，补充“快速切章旧章节 token 失效”测试确认旧结果不会覆盖新章节。高级主题列表已存在 `_summaryLoadToken`，高级主题服务的导入导出和资源路径归属继续留给第六批 `U5-LIB-05` 与后续任务拆分。
- [x] 2026-06-07：执行第六批 `U5-LIB-05-01` 到 `U5-LIB-05-03`；审计确认 `advanced_theme_service.dart` 仍是最大资源路径维护债，内部同时承担主题索引、导入导出 zip、红果 / 阅读 package 兼容、字体 / 壁纸 / 图集资源复制和清理，后续应按“资源读写、导入导出、存储迁移”继续拆；`cover_gallery_service.dart` 与 `launch_image_gallery_service.dart` 已使用 `ManagedAssetStore` 管理图片资产，但 index 文件路径仍重复手写，本轮新增 `GalleryIndexFileStore` 并接入封面图集 / 启动图集，旧 SharedPreferences payload 仍会迁移到 documents index 文件；`bottom_nav_icon_gallery_service.dart` 图片资产已经走 `ManagedAssetStore`，索引仍存 SharedPreferences，因数据体小且带内置图集合并逻辑，本轮只审计不强迁。阅读器本地图书路径已有 `LocalBookStorageService` 管用户资产，epub / html parser 的资产目录依赖本地图书 storagePath，不在本批移动，避免误删用户文件。
- [x] 2026-06-07：执行第七批 `U5-LIB-01-01` 到 `U5-LIB-01-05`；盘点确认 `reader_settings.dart`、`reading_progress.dart`、`app_advanced_theme.dart`、主图集实体都是持久化主模型，迁移风险高，不作为试点；选择低风险展示型图集 index item 作为 `freezed` / `json_serializable` 试点，新建 `gallery_index_models.dart`，迁移 `CoverGalleryIndexItem`、`LaunchImageGalleryIndexItem`、`BottomNavIconGalleryIndexItem`，服务层返回类型保持不变。补充 JSON round-trip、copyWith、能力 flag、底栏图集 previewItems 枚举 key / value 转换测试。生成器可用，但当前项目 SDK / `json_annotation` 约束会输出 warning，且 build_runner 会按当前 pub host 改写 `pubspec.lock` URL，本轮已恢复无关 lockfile 变更；后续正式扩大模型迁移前应先统一开发机 pub host 和 SDK 约束策略。
