# 非阅读器页面自适应/响应式布局审计 2026-06-20

## 审计范围

- 范围：`lib/features/**/presentation/*page*.dart`、`lib/app/*scaffold*.dart`
- 排除：`lib/features/reader/**`
- 扫描页面/页面分片：51 个
- 命中固定布局风险文件：11 个
- 本次已修：6 处
- 明确建议后续整改：0 处
- 观察/低风险：3 处

## 本次已修

- [x] 书架选择书籍操作栏  
  文件：`lib/features/bookshelf/presentation/bookshelf_page.dart`、`lib/app/widgets/foundation/app_batch_action_bar.dart`  
  问题：选择栏操作按钮使用 Wrap，小屏下会变成三上一下。  
  处理：新增固定列按钮行，书架选择态固定一行四个按钮。

- [x] 高级主题编辑器视觉资源  
  文件：`lib/features/mine/presentation/advanced_theme_editor_page.dart`  
  问题：视觉资源网格强制使用中等屏宽和横向滚动，移动端出现大块空白、卡片错位/截断。  
  处理：改为按当前约束自适应 3 列，极窄宽度降为 2 列，清理 GridView 默认 padding，预览尺寸随卡片压缩。

## 本轮补充完成

- [x] P1 发现页分类书籍网格  
  文件：`lib/features/discover/presentation/discover_category_books_page.dart:358`、`:435`  
  问题：内容态和骨架态都固定 `crossAxisCount: 3`，没有按实际宽度调整。  
  风险：窄屏、大字号或折叠屏窄栏下卡片信息被压扁；宽屏又无法提高信息密度。  
  处理：内容态改为 `SliverLayoutBuilder + metrics.gridColumnsFor(...)`，骨架态同步动态列数。

- [x] P1 阅读背景资源页网格  
  文件：`lib/features/mine/presentation/reader_background_page.dart:309`  
  问题：固定 `const columns = 3`，虽然外层有 `LayoutBuilder`，但没有使用宽度计算列数。  
  风险：窄屏资源卡过瘦，角标/状态容易挤压；大屏不能扩列。  
  处理：改为 `metrics.gridColumnsFor(availableWidth: constraints.maxWidth - horizontal * 2, minItemWidth: 120...)`。

- [x] P2 应用外观页应用背景网格  
  文件：`lib/features/mine/presentation/appearance_page_view.dart:1146`  
  问题：应用背景资源固定 3 列。  
  风险：资源使用角标多时，小屏卡片内容拥挤。  
  处理：复用 `metrics.gridColumnsFor(...)`，按可用宽度在 2-5 列间调整。

- [x] P2 应用外观字体选择面板  
  文件：`lib/features/mine/presentation/appearance_page.dart:407`  
  问题：面板固定高度 `320`，字体选项固定 3 列。  
  风险：小屏、大字号、键盘/底部弹层环境下可能溢出或按钮压缩。  
  处理：面板高度跟随 `MediaQuery.sizeOf(context).height` 设上下限，列数按宽度在 2/3 之间切换。

## 观察/低风险

- [ ] P3 书源 WebView 登录/任务页  
  文件：`lib/features/source/presentation/source_webview_login_page.dart:191`、`lib/features/source/presentation/source_webview_task_page.dart:259`  
  观察：页面是全屏 WebView，未接入项目通用页面最大宽度/底部导航 inset。  
  判断：通常作为独立全屏任务页可以接受，但后续若进入底部导航 Shell，需要补 SafeArea/底部 inset。

- [ ] P3 书架标签单行展示  
  文件：`lib/features/bookshelf/presentation/bookshelf_page.dart:2802`  
  观察：使用横向 `SingleChildScrollView` 但禁用滚动。  
  判断：这是标签单行裁剪，不是页面响应式问题，暂不作为 Bug。

- [ ] P3 我的管理页小图标按钮  
  文件：`lib/features/mine/presentation/mine_management_page.dart:860`  
  观察：按钮最小宽度 32。  
  判断：属于紧凑操作区，不影响页面自适应，暂不整改。

## 已确认相对安全

- [x] 封面图集编辑器  
  文件：`lib/features/mine/presentation/cover_gallery_editor_page.dart:485`  
  结论：已使用 `metrics.gridColumnsFor(...)` 动态列数。

- [x] 启动图集编辑器  
  文件：`lib/features/mine/presentation/launch_image_gallery_editor_page.dart:502`  
  结论：已使用 `metrics.gridColumnsFor(...)` 动态列数。

- [x] 登录页  
  文件：`lib/features/auth/presentation/auth_page_layout_sections.dart`  
  结论：桌面/移动都有 `LayoutBuilder` 分支，并已有 UI-GOV 审查豁免。

## 后续观察顺序

1. [ ] WebView 页 SafeArea/底部 inset 观察：仅在确认它会进入底部导航 Shell 时整改。
2. [ ] 书架标签单行展示：若后续产品要求标签完整可见，再从裁剪改成可滚动/换行。
3. [ ] 我的管理页小图标按钮：如遇大字号点击热区问题，再统一收敛到组件按钮尺寸。
