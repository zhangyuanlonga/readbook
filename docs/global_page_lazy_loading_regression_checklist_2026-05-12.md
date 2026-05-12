# 全局页面懒加载回归清单

更新时间：2026-05-12  
关联计划：`docs/global_page_lazy_loading_execution_plan_2026-05-12.md` Phase 6

## 1. 自动检查

每次新增或调整全局页面路由后运行：

```bash
dart run tool/check_route_inventory.dart
```

完整架构回归会自动包含路由清单检查：

```bash
scripts/run_architecture_green_suite.sh
```

提交涉及页面懒加载、能力开关、跨端 UI 时，至少运行：

```bash
flutter analyze \
  lib/app/widgets/feature_disabled_page.dart \
  lib/features/bookshelf/presentation/bookshelf_page.dart \
  lib/features/mine/presentation/mine_page.dart \
  lib/features/mine/presentation/appearance_page.dart \
  lib/features/mine/presentation/appearance_page_view.dart \
  lib/features/reader/presentation/reader_page.dart \
  lib/features/reader/presentation/reader_page_bootstrap.dart

flutter test test/features/presentation/page_adaptive_smoke_test.dart
flutter test test/features/bookshelf/presentation/bookshelf_desktop_layout_test.dart
flutter test test/features/reader/application/reader_mode_capabilities_test.dart
```

## 2. 首屏请求检查

冷启动进入 `/home` 和 `/bookshelf` 时确认：

- 不触发书源列表、书源登录、脚本执行、在线搜索请求。
- 不触发 WebDAV 同步配置、同步历史或同步任务。
- 不扫描启动图集、封面图库、底栏图标库。
- 不统计缓存目录体积。
- 书架先出现基础列表或空状态，标签、分类、进度补齐可以随后完成。

## 3. 能力关闭检查

默认首版能力关闭时确认：

- `/discover`、`/search`、`/source`、`/source/login`、`/source/web-login`、`/source/script-editor`、`/source/paste-import` 只展示轻量禁用页。
- `/sync`、`/sync/history` 只展示轻量禁用页。
- 在线 `/book/:bookId` 和在线 `/reader/:bookId/:chapterId` 不创建书源运行时。
- 本地 `/local-library`、`/local/book/:bookId`、`/local/reader/:bookId/:chapterId` 仍可进入本地链路。

## 4. Web 检查

Web 端打开以下页面：

- `/bookshelf`：不白屏，空书架、搜索和导入入口可见；排序和选择态不因为桌面布局变灰或遮挡。
- `/mine`：仅展示可用入口，不展示已移除的系统入口。
- `/search`、`/source`、`/sync`：能力关闭时显示统一禁用页，不报错。
- `/appearance`：进入后不默认加载全部背景和字体资源；打开背景或字体面板时再加载对应数据。

## 5. 桌面检查

macOS、Windows、Linux 打开以下页面：

- `/bookshelf`：使用大屏布局，导入、搜索、空状态和列表区域不重叠；移动端专属底部交互不压住正文。
- `/book/:bookId`：本地图书详情优先显示本地 metadata；在线能力关闭时展示禁用页。
- `/reader/:bookId/:chapterId`：打开章节后先出现正文，再补齐字体、背景、颜色等附加 warmup。
- `/cache`、`/bookmarks`、`/feedback`、`/error-center`：进入页面后加载自身数据，返回我的页不触发全量刷新。

## 6. 低端移动端检查

Android 低内存设备或模拟器上确认：

- 1000 本书架数据下，基础列表先显示，滚动不明显掉帧。
- 长章节和含图章节打开后不一次性解码全部图片。
- 我的页打开不触发图集扫描、缓存统计、反馈列表或书签查询。
- Tab 切换不重复启动不可见页面的低优先级后台任务。

## 7. 文档回填

完成一个阶段或新增页面后必须同步：

- `docs/global_page_route_inventory_2026-05-12.md`：路由、页面、加载策略、能力边界。
- `docs/global_page_lazy_loading_execution_plan_2026-05-12.md`：阶段任务、验收和执行记录。
- `docs/page_function_multiplatform_methods_2026-05-12.md`：功能兼容状态。
- `docs/page_ui_multiplatform_display_plan_2026-05-12.md`：多端展示状态。
- `docs/page_ui_component_governance_plan_2026-05-12.md`：如果改动涉及通用 UI 组件、弹层、状态组件、列表/卡片或桌面交互。
- `docs/page_ui_scaffold_audit_2026-05-12.md`：如果新增或迁移页面 scaffold / 页面骨架。
- `docs/page_ui_state_component_audit_2026-05-12.md`：如果新增或迁移空、加载、错误、禁用状态。
- `docs/page_ui_modal_surface_audit_2026-05-12.md`：如果新增或迁移 bottom sheet、dialog、popover、snackbar。
- `docs/startup_init_cleanup_execution_plan_2026-05-12.md`：如果页面进入启动链或主 Tab 初始化链。
