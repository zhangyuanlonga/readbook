# Responsive Framework Full Migration Plan

创建时间：2026-03-23

## 执行清单

- [x] 新建并落库本计划文档（含可勾选任务与验收标准）
- [x] 统一 `AppLayout/AppSpacing` 规则层：新增公共 helper，收敛页面密度策略
- [x] 迁移「我的」页面：移除页面内断点魔法数，改用 `AppLayout` helper
- [x] 迁移「阅读记录」页面：移除页面内断点魔法数，改用 `AppLayout` helper
- [x] 优化「发现」页面手机密度：确保 `390dp` 与 `430dp` 呈现差异
- [x] 更新/新增自适应测试（包含新 helper 与关键页面行为）
- [x] 运行 `flutter analyze` 与关键测试并记录结果

## 验收标准

- 页面层不再新增 `width >= xxx` / `constraints.maxWidth < xxx` 这类断点魔法数。
- 断点与密度决策统一在 `lib/app/layout/app_layout.dart` 与 `lib/app/layout/app_spacing.dart`。
- 手机端小屏统一阈值：`<=360dp`（优先兼容移动端）。
- `390dp` 与 `430dp` 手机视口下，关键页面同屏信息量不再完全一致（`430dp` 更高）。
- `flutter analyze` 通过；关键自适应测试通过。

## 执行记录

- `flutter test test/app/layout/adaptive_breakpoints_test.dart`：通过
- `flutter test test/features/discover/presentation/discover_page_test.dart`：通过
- `flutter test test/app/layout/adaptive_ui_matrix_test.dart`：通过
- `flutter analyze`：通过（No issues found）
