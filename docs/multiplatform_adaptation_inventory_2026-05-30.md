# Web / Windows / macOS 适配功能模块扫描清单

创建日期：2026-05-30  
扫描范围：`lib/features`、`lib/app/widgets`、`lib/app/shell_scaffold.dart`、`lib/app/platform`、关键 `core/data` 平台依赖。  
扫描方法：基于文件结构、页面命名、弹层调用、平台依赖关键字静态扫描。  
移动端保护：本清单只用于新平台适配排期，不要求直接修改 Android / iOS 已稳定代码。

复杂度说明：

- 低：纯 UI + 网络请求，无明显平台依赖。
- 中：需要响应式布局 + 鼠标/键盘交互。
- 高：依赖移动端特有插件、文件、数据库、硬件、原生桥或复杂本地资源。

| 序号 | 功能名称 | 文件路径 | 类型 | 依赖项 | 复杂度 | 阻断项 | 备注 |
|-----|---------|---------|------|-------|-------|-------|------|
| 1 | App 根组件与启动弹窗 | `lib/app/app.dart` | 页面 | GoRouter、启动公告、更新弹窗、键盘 inset、平台 UI | 中 | 无 | Desktop/Web 可独立 Shell，移动端根逻辑保持冻结。 |
| 2 | 主导航 Shell | `lib/app/shell_scaffold.dart` | 页面 | NavigationRail、BottomNav、kIsWeb、TargetPlatform | 中 | 无 | 已有桌面判断，后续建议拆 MobileShell / DesktopShell。 |
| 3 | 首页 | `lib/features/home/presentation/home_page.dart` | 页面 | 网络数据、AdaptiveActionSurface、宽屏指标卡 | 中 | 无 | 需要桌面信息密度和 hover/focus 检查。 |
| 4 | 书架首页 | `lib/features/bookshelf/presentation/bookshelf_page.dart` | 页面 | `dart:io`、file_selector、搜索焦点、PopupMenu | 高 | 有替代：Web 文件导入受限 | 移动端保护优先；建议新增 Desktop/Web 书架 View。 |
| 5 | 书架流程弹层集合 | `lib/features/bookshelf/presentation/bookshelf_page_flow.dart` | 弹窗 | showAdaptiveActionSurface、本地导入、外部导入、分类编辑 | 高 | 有替代：导入/外部导入做平台门控 | 已有 adaptive surface，但文件导入仍需 Web/Desktop 能力隔离。 |
| 6 | 书架分区组件 | `lib/features/bookshelf/presentation/bookshelf_page_sections.dart` | 公共组件 | FocusNode、搜索栏、列表/网格 UI | 中 | 无 | 可作为桌面书架网格改造入口。 |
| 7 | 本地书库 | `lib/features/bookshelf/presentation/local_library_page.dart` | 页面 | file_selector、本地文件、列表管理 | 高 | 有替代：Web 只允许浏览已有记录或上传导入 | Web 端需受限模式。 |
| 8 | 图书详情页 | `lib/features/book/presentation/book_detail_page.dart` | 页面 | share_plus、封面、本地/远程详情、目录、阅读入口 | 中 | 有替代：分享 -> 复制链接 | 建议抽 ViewModel 后做桌面详情双栏。 |
| 9 | 图书详情主视图 | `lib/features/book/presentation/book_detail_page_view.dart` | 公共组件 | 详情布局、封面、目录片段 | 中 | 无 | 可复用状态，新建桌面布局。 |
| 10 | 图书详情操作弹层 | `lib/features/book/presentation/book_detail_page_actions.dart` | 弹窗 | showAdaptiveActionSurface、预览、书架操作 | 中 | 有替代：分享/预览平台门控 | 注意移动端按钮顺序不变。 |
| 11 | 图书详情元数据弹层 | `lib/features/book/presentation/book_detail_page_metadata.dart` | 弹窗 | showAdaptiveActionSurface、元数据编辑确认 | 中 | 无 | 桌面可改 dialog/side panel。 |
| 12 | 搜索页 | `lib/features/search/presentation/search_page.dart` | 页面 | PointerDeviceKind、FocusNode、网络搜索、筛选弹层 | 中 | 无 | 已支持鼠标 dragDevices，需桌面结果多栏。 |
| 13 | 搜索输入卡片 | `lib/features/search/presentation/widgets/search_input_card.dart` | 公共组件 | 输入焦点、模式切换 | 中 | 无 | 桌面需回车、快捷键和焦点策略。 |
| 14 | 搜索图书卡片 | `lib/features/search/presentation/widgets/search_book_card.dart` | 公共组件 | 结果卡片、封面、操作入口 | 中 | 无 | 桌面可网格/列表双模式。 |
| 15 | 搜索失败横幅/详情 | `lib/features/search/presentation/widgets/search_failure_banner.dart` | 弹窗 | showAdaptiveActionSurface、错误详情 | 低 | 无 | 适合先完成 Web/Desktop。 |
| 16 | 发现页 | `lib/features/discover/presentation/discover_page.dart` | 页面 | 网络分类、响应式布局 | 中 | 无 | 主要是宽屏布局。 |
| 17 | 发现分类图书页 | `lib/features/discover/presentation/discover_category_books_page.dart` | 页面 | 网络列表、LayoutBuilder、封面比例 | 中 | 无 | 需要桌面网格密度。 |
| 18 | 公告列表 | `lib/features/announcement/presentation/announcement_list_page.dart` | 页面 | 网络/本地已读状态、AdaptivePageScaffold | 低 | 无 | 低风险适配候选。 |
| 19 | 公告详情 | `lib/features/announcement/presentation/announcement_detail_page.dart` | 页面 | Markdown/正文滚动 | 低 | 无 | 低风险适配候选。 |
| 20 | 登录页 | `lib/features/auth/presentation/auth_page.dart` | 页面 | 网络登录、键盘 inset、表单 | 中 | 无 | 需桌面表单最大宽度；当前文件已有未提交改动，后续谨慎。 |
| 21 | 用户资料页 | `lib/features/auth/presentation/user_profile_page.dart` | 页面 | SharedPreferences、资料编辑弹层、头像操作 | 中 | 有替代：头像选择走 file_selector | 头像更新需统一图片选择能力。 |
| 22 | 我的页 | `lib/features/mine/presentation/mine_page.dart` | 页面 | 图片选择、会员入口、用户信息弹层 | 高 | 有替代：头像/背景上传走文件选择 | 需保护移动端个人页布局。 |
| 23 | 我的页视图 | `lib/features/mine/presentation/mine_page_view.dart` | 公共组件 | 菜单分组、入口配置 | 中 | 无 | 可作为 Desktop Mine View 分流基础。 |
| 24 | 我的管理页 | `lib/features/mine/presentation/mine_management_page.dart` | 页面 | showModalBottomSheet、分类编辑 | 中 | 无 | 仍有直接 bottom sheet，桌面需改 adaptive surface。 |
| 25 | 外观设置页 | `lib/features/mine/presentation/appearance_page.dart` | 页面 | 主题、预览、确认弹层 | 中 | 无 | 桌面需侧栏/预览区。 |
| 26 | 外观设置视图 | `lib/features/mine/presentation/appearance_page_view.dart` | 公共组件 | 主题选项、多个 adaptive 弹层 | 中 | 无 | 可复用状态，拆桌面布局。 |
| 27 | 系统设置页 | `lib/features/mine/presentation/system_settings_page.dart` | 页面 | SharedPreferences、多个设置面板 | 中 | 无 | 适合设置页桌面分组化。 |
| 28 | 会员中心 | `lib/features/mine/presentation/membership_center_page.dart` | 页面 | `dart:io`、path_provider、url_launcher、支付/权益弹层 | 高 | 有替代：支付跳 Web/外部浏览器 | 支付与导出能力要平台门控。 |
| 29 | 反馈页 | `lib/features/mine/presentation/feedback_page.dart` | 页面 | 网络提交、确认弹层、表单 | 中 | 无 | 桌面表单宽度和附件能力需确认。 |
| 30 | 关于页 | `lib/features/mine/presentation/about_page.dart` | 页面 | url_launcher、版本信息 | 低 | 无 | 低风险适配候选。 |
| 31 | 错误中心 | `lib/features/error/presentation/error_center_page.dart` | 页面 | share_plus、诊断信息 | 中 | 有替代：分享 -> 复制/下载日志 | Web 分享和诊断导出需降级。 |
| 32 | 书签页 | `lib/features/mine/presentation/bookmarks_page.dart` | 页面 | AlertDialog、阅读跳转、长列表 | 中 | 无 | 桌面可加搜索/筛选/右键操作。 |
| 33 | 字体管理页 | `lib/features/mine/presentation/font_management_page.dart` | 页面 | file_selector、字体注册、AlertDialog、PopupMenu | 高 | 有替代：Web 可禁用或上传字体到浏览器存储 | 字体文件和本地持久化是主要风险。 |
| 34 | 高级主题列表 | `lib/features/mine/presentation/advanced_theme_list_page.dart` | 页面 | `dart:io`、file_selector、path_provider、share_plus | 高 | 有替代：Web 导入/导出受限 | 需要 Web stub 和能力表统一。 |
| 35 | 高级主题编辑器 | `lib/features/mine/presentation/advanced_theme_editor_page.dart` | 页面 | `dart:io`、资源选择、颜色选择、MouseRegion | 高 | 有替代：资源选择走受限文件上传 | 编辑器复杂，建议后置。 |
| 36 | 封面图集页 | `lib/features/mine/presentation/cover_gallery_page.dart` | 页面 | PopupMenu、图集管理、本地资源 | 高 | 有替代：Web 只读/上传受限 | 受管文件存储需 Web 替代。 |
| 37 | 封面图集编辑器 | `lib/features/mine/presentation/cover_gallery_editor_page.dart` | 页面 | fullscreen preview、本地图片资源 | 高 | 有替代：文件上传/预览 | 需避免移动端编辑体验回归。 |
| 38 | 启动图集页 | `lib/features/mine/presentation/launch_image_gallery_page.dart` | 页面 | PopupMenu、本地图片资源 | 高 | 有替代：Web 只读/上传受限 | 与受管资源存储绑定。 |
| 39 | 启动图集编辑器 | `lib/features/mine/presentation/launch_image_gallery_editor_page.dart` | 页面 | fullscreen preview、本地图片资源 | 高 | 有替代：文件上传/预览 | 可复用图集编辑规则。 |
| 40 | 阅读背景页 | `lib/features/mine/presentation/reader_background_page.dart` | 页面 | fullscreen preview、本地背景资源 | 高 | 有替代：Web 预设背景/上传受限 | 需资源 adapter。 |
| 41 | 底部导航图标图集页 | `lib/features/mine/presentation/bottom_nav_icon_gallery_page.dart` | 页面 | PopupMenu、本地图标资源 | 高 | 有替代：Web 预设图标/上传受限 | 移动端导航图标不应被桌面适配影响。 |
| 42 | 底部导航图标编辑器 | `lib/features/mine/presentation/bottom_nav_icon_gallery_editor_page.dart` | 页面 | 图标资源编辑 | 高 | 有替代：Web 预设/上传受限 | 低优先级。 |
| 43 | 资源集合通用组件 | `lib/features/mine/presentation/widgets/image_resource_collection_widgets.dart` | 公共组件 | showAdaptiveActionSurface、LazyFileImage、本地文件图 | 高 | 有替代：Web 图片 provider/stub | 多个图集页共用，适合先抽 adapter。 |
| 44 | 外观其他设置卡 | `lib/features/mine/presentation/widgets/appearance_other_settings_card.dart` | 公共组件 | PopupMenu、showAdaptiveActionSurface | 中 | 无 | 桌面可复用。 |
| 45 | 书源 WebView 登录页 | `lib/features/source/presentation/source_webview_login_page.dart` | 页面 | webview_flutter、Cookie、登录会话 | 高 | 有替代：外部浏览器/服务器登录 | Web/Desktop 能力需重新定义，避免本地 WebView 依赖。 |
| 46 | 阅读器主页面 | `lib/features/reader/presentation/reader_page.dart` | 页面 | battery_plus、PointerDeviceKind、阅读状态、PDF/图片/文本、弹层 | 高 | 有替代：亮度/音量键改键盘/菜单 | 核心高风险，建议最后集中适配并做移动端回归。 |
| 47 | 阅读器 Shell | `lib/features/reader/presentation/reader_shell.dart` | 公共组件 | 阅读容器、沉浸式结构 | 高 | 无 | Desktop/Web 可新增外层 Shell，不直接改移动端。 |
| 48 | 阅读器页面 Shell / 快捷键 | `lib/features/reader/presentation/reader_page_shell.dart` | 公共组件 | LogicalKeyboardKey、键盘翻页 | 中 | 无 | 已有桌面快捷键基础，需验证不影响移动端手势。 |
| 49 | 阅读器目录弹层 | `lib/features/reader/presentation/reader_catalog_sheet.dart` | 弹窗 | showGeneralDialog、showModalBottomSheet、目录/书签搜索 | 高 | 无 | 已区分 dialog/sheet，但仍需桌面宽屏 UX。 |
| 50 | 阅读器设置弹层 | `lib/features/reader/presentation/reader_page_settings_sheet.dart` | 弹窗 | showGeneralDialog、showModalBottomSheet、颜色/字体/布局设置 | 高 | 有替代：字体/本地资源受限 | 复杂弹层，需分阶段迁移。 |
| 51 | 章节缓存弹层 | `lib/features/reader/presentation/chapter_cache_sheets.dart` | 弹窗 | showAdaptiveActionSurface、缓存任务 | 中 | 无 | 桌面 dialog 化即可。 |
| 52 | 阅读记录页 | `lib/features/reader/presentation/reading_records_page.dart` | 页面 | 图表/热力图、PopupMenu、统计数据 | 中 | 无 | 适合桌面宽屏增强。 |
| 53 | 阅读器 PDF 视图 | `lib/features/reader/presentation/reader_pdf_view.dart` | 公共组件 | `dart:io`、pdfrx、PDF 文件 | 高 | 有替代：Web PDF renderer 或禁用本地 PDF | Web import 链风险，需要条件导入。 |
| 54 | 阅读器文字分页视图 | `lib/features/reader/presentation/reader_text_paged_view.dart` | 公共组件 | `dart:io`、分页缓存、翻页动画 | 高 | 有替代：Web 降级滚动阅读 | 需确认 Web 编译链。 |
| 55 | 阅读器漫画视图 | `lib/features/reader/presentation/reader_manga_view.dart` | 公共组件 | 图片加载、滚动/分页 | 中 | 无 | 主要是鼠标滚轮与窗口尺寸。 |
| 56 | 阅读器音频视图 | `lib/features/reader/presentation/reader_audio_view.dart` | 公共组件 | url_launcher、音频入口 | 中 | 有替代：外部打开 | 需确认 just_audio/Web 支持路径。 |
| 57 | 阅读器顶部/底部覆盖层 | `lib/features/reader/presentation/reader_overlay_widgets.dart` | 公共组件 | 触摸操作、工具栏 | 中 | 无 | 桌面 hover/focus/快捷键需外层添加。 |
| 58 | 阅读器信息栏组件 | `lib/features/reader/presentation/reader_chrome_widgets.dart` | 公共组件 | 电量展示、阅读信息 | 中 | 有替代：桌面/Web 隐藏电量或显示未知 | battery_plus 在桌面/Web 需能力门控。 |
| 59 | 阅读器换源弹层 | `lib/features/reader/presentation/reader_page_source_switch.dart` | 弹窗 | showAdaptiveActionSurface、网络换源 | 中 | 无 | 主要是桌面弹层尺寸。 |
| 60 | 阅读器选区菜单 | `lib/features/reader/presentation/reader_page_selection.dart` | 弹窗 | contextMenuAnchors、showAdaptiveActionSurface | 中 | 无 | 桌面右键/文本选择要重点验证。 |
| 61 | Adaptive 页面骨架 | `lib/app/widgets/adaptive_page_scaffold.dart` | 公共组件 | 布局骨架、安全区 | 中 | 无 | 后续新平台适配优先复用。 |
| 62 | Adaptive 弹层系统 | `lib/app/widgets/adaptive_bottom_sheet.dart` | 公共组件 | showModalBottomSheet、showDialog、desktopDialog | 中 | 无 | 是渐进式适配核心，不要破坏移动端 sheet 行为。 |
| 63 | Adaptive 内容容器 | `lib/app/widgets/adaptive_content_container.dart` | 公共组件 | 最大宽度、响应式约束 | 低 | 无 | 适合统一桌面最大宽度。 |
| 64 | Adaptive 网格 | `lib/app/widgets/adaptive_grid_sliver.dart` | 公共组件 | Sliver 网格、断点 | 中 | 无 | 书架/搜索/发现的桌面网格基础。 |
| 65 | Adaptive 搜索栏 | `lib/app/widgets/adaptive_search_bar.dart` | 公共组件 | FocusNode、输入框 | 中 | 无 | 桌面快捷键聚焦可在外层加。 |
| 66 | Adaptive 筛选栏 | `lib/app/widgets/adaptive_filter_bar.dart` | 公共组件 | 筛选项、横向/换行布局 | 中 | 无 | 搜索/列表类页面复用。 |
| 67 | Adaptive 列表项 | `lib/app/widgets/adaptive_list_tile.dart` | 公共组件 | FocusNode、列表项布局 | 中 | 无 | 桌面 hover/focus 可增强。 |
| 68 | Adaptive 设置项 | `lib/app/widgets/adaptive_setting_tile.dart` | 公共组件 | 设置分组、trailing 控件 | 中 | 无 | 设置页桌面化基础组件。 |
| 69 | Adaptive 卡片 | `lib/app/widgets/adaptive_card.dart` | 公共组件 | 卡片样式 | 低 | 无 | 低风险。 |
| 70 | 空/状态组件 | `lib/app/widgets/app_empty_state_card.dart`、`lib/app/widgets/app_status_state_card.dart` | 公共组件 | 空态、错误态、加载态 | 低 | 无 | 适合作为 Web 受限能力占位统一入口。 |
| 71 | 任务队列/任务弹层 | `lib/app/widgets/app_task_queue_surface.dart`、`lib/app/widgets/app_task_bottom_sheet.dart` | 弹窗 | showAdaptiveRawSurface、任务状态 | 中 | 无 | 导入/导出/缓存任务桌面化依赖它。 |
| 72 | 导入导出任务面板 | `lib/app/widgets/import_export_task_overlay.dart`、`lib/app/widgets/import_export_task_sheet.dart` | 弹窗 | 任务进度、导入导出文案 | 中 | 有替代：Web 导入导出受限 | 需要与文件能力表联动。 |
| 73 | 封面解析组件 | `lib/app/widgets/resolved_book_cover.dart` | 公共组件 | 封面解析、缓存、占位 | 中 | 无 | 桌面网格会高频使用。 |
| 74 | 磁盘封面图片 | `lib/app/widgets/disk_cached_cover_image.dart` | 公共组件 | `dart:io`、本地磁盘缓存 | 高 | 有替代：Web 使用网络/IndexedDB/占位 | Web import 链风险，需要条件实现。 |
| 75 | 本地文件图片抽象 | `lib/app/images/local_file_image.dart` | 公共组件 | IO/Web 条件实现 | 高 | 有替代：Web stub/Blob URL | 已有 io/web 文件，需验证覆盖所有入口。 |
| 76 | 功能禁用页 | `lib/app/widgets/feature_disabled_page.dart` | 页面 | 禁用态文案 | 低 | 无 | Web/Desktop 受限能力推荐统一用它。 |
| 77 | 换源候选弹层 | `lib/app/widgets/switch_source_candidate_sheet.dart` | 弹窗 | showAdaptiveActionSurface、PopupMenu | 中 | 无 | 阅读器/详情复用，桌面需宽度验证。 |
| 78 | 全屏预览 | `lib/app/widgets/adaptive_fullscreen_preview.dart` | 弹窗 | showGeneralDialog、图片预览 | 中 | 有替代：Web 图片源受限 | 需支持桌面关闭/键盘 Esc。 |
| 79 | 底部导航图标组件 | `lib/app/widgets/bottom_nav_icon_view.dart` | 公共组件 | 自定义图标资源 | 高 | 有替代：桌面 Shell 不使用底部导航 | 不应让桌面适配影响移动端底栏。 |
| 80 | Cupertino Dock 导航 | `lib/app/widgets/cupertino_dock_navigation_bar.dart` | 公共组件 | Dock 视觉、搜索入口 | 中 | 无 | 可能用于大屏/桌面导航实验。 |
| 81 | 平台能力表 | `lib/app/platform/app_platform_capabilities.dart` | 公共组件 | kIsWeb、TargetPlatform、能力状态 | 高 | 无 | 所有新平台适配必须先更新/验证这里。 |
| 82 | 图片选择服务 | `lib/core/media/image_selection_service.dart` | 公共组件 | file_selector、image_picker、kIsWeb | 高 | 有替代：Web/桌面用文件选择 | capability 与实际支持需要统一口径。 |
| 83 | 数据库连接 | `lib/data/datasources/local/app_database_connection_native.dart`、`lib/data/datasources/local/app_database_connection_web.dart` | 公共组件 | Drift、SQLite、WebDatabase、path_provider | 高 | 无 | 已有 native/web 分流，需验证升级和刷新持久化。 |
| 84 | 安全凭证存储 | `lib/core/auth/auth_session_secret_store.dart` | 公共组件 | flutter_secure_storage | 高 | 有替代：Web 低安全等级提示 | Web secure storage 需明确安全边界。 |
| 85 | 受管文件路径 | `lib/core/storage/managed_file_path_resolver.dart` | 公共组件 | `dart:io`、path_provider | 高 | 有替代：Web stub/受限模式 | 当前是 Web import 链重点风险。 |
| 86 | 受管资源存储 | `lib/core/storage/managed_asset_store.dart` | 公共组件 | `dart:io`、path_provider | 高 | 有替代：Web IndexedDB/只读预设 | 影响图集、主题、背景。 |
| 87 | 源日志存储 | `lib/core/logging/source_log_store.dart` | 公共组件 | `dart:io`、path_provider | 高 | 有替代：Web 内存/下载日志 | 当前 Web import 链风险。 |
| 88 | 搜索失败导出服务 | `lib/features/search/application/search_failure_export_service.dart` | 公共组件 | `dart:io`、path_provider | 高 | 有替代：Web 下载文本/复制 | 错误导出需平台 adapter。 |
| 89 | 本地图书导入服务 | `lib/features/bookshelf/application/local_book_import_service.dart` | 公共组件 | `dart:io`、本地文件、格式解析 | 高 | 有替代：Web 上传文件/只读 | 核心阻力之一。 |
| 90 | 本地图书解析服务组 | `lib/features/reader/application/local/*_parser.dart` | 公共组件 | `dart:io`、PDF/MOBI/EPUB/TXT 解析 | 高 | 有替代：Web 降级格式支持 | 建议按格式逐个验证。 |
| 91 | 阅读器亮度桥 | `lib/features/reader/application/reader_screen_brightness_bridge.dart` | 公共组件 | MethodChannel、Platform.isAndroid/iOS | 高 | 有替代：Web/Desktop 隐藏入口 | 移动端专属能力。 |
| 92 | 阅读器音量键桥 | `lib/features/reader/application/reader_volume_key_page_bridge.dart` | 公共组件 | MethodChannel、EventChannel | 高 | 有替代：键盘快捷键 | 移动端专属能力。 |
| 93 | 阅读器桌面输入解析 | `lib/features/reader/application/reader_desktop_input_resolver.dart` | 公共组件 | LogicalKeyboardKey | 中 | 无 | 新平台阅读器交互基础。 |
| 94 | 阅读器依赖组装 | `lib/features/reader/application/reader_dependencies_provider.dart` | 公共组件 | battery_plus、多个服务注入 | 高 | 有替代：电量未知/隐藏 | 需要避免 native-only 依赖进入 Web。 |
| 95 | 自定义封面存储 | `lib/features/book/application/custom_cover_storage_service.dart` | 公共组件 | `dart:io` | 高 | 有替代：Web 上传/IndexedDB/禁用 | 影响详情页封面编辑。 |
| 96 | 主题/背景/图集服务组 | `lib/features/mine/application/*gallery*_service.dart`、`lib/features/mine/application/*background*_service.dart`、`lib/features/mine/application/advanced_theme_service.dart` | 公共组件 | `dart:io`、path_provider、SharedPreferences | 高 | 有替代：Web 只读预设/上传受限 | 建议统一资源存储 adapter 后再适配页面。 |

## 初步优先级建议

P0 先适配低风险可闭环：

- 公告列表/详情
- 关于页
- 搜索页基础浏览
- 发现页
- 图书详情只读路径
- 空态/禁用态/Adaptive 基础组件

P1 再适配核心高频：

- 首页
- 书架只读和远程图书路径
- 阅读器在线正文阅读
- 书签/阅读记录
- 设置页基础项

P2 最后适配高风险平台能力：

- 本地图书导入和解析
- PDF / MOBI / EPUB 本地阅读
- 自定义主题/背景/图集/字体
- WebView 登录
- 分享、诊断导出、会员支付
- 亮度、音量键、电量等移动端专属能力

