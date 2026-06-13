# UI 治理 Phase 4-7 执行记录

**日期**: 2026-06-13  
**试点范围**: Mine / StorageManagementPage  
**目标**: 用一个低风险页面验证 Phase 2-3 的基础能力封装，并补齐性能、自动化和推广闭环。

---

## 1. Phase 4 试点迁移

### 1.1 试点选择

- [x] 选择 `StorageManagementPage` 作为 Mine 低风险试点。
- [x] 不触碰 Reader 核心翻页、阅读进度、章节定位和阅读设置持久化链路。
- [x] 试点页面覆盖操作反馈、确认弹层、加载态、错误态和缓存条目列表。

### 1.2 已落地改造

- [x] 裸 `showDialog` 改为 `showAdaptiveActionSurface`。
- [x] 裸 `SnackBar` 改为 `AppFeedback.showSnackBar`。
- [x] 手写 loading skeleton 改为 `AppSkeletonList`。
- [x] `loading / error / content` 状态区接入 `AppAnimatedSwitcher`。
- [x] 局部错误提示改为 `AppInlineFeedback`。
- [x] 为页面增加 `StorageManagementGateway` 注入点，便于 widget smoke test。
- [x] 保留已有 `ListView` 页面结构；该页面为有限静态区块，不作为长列表治理对象。

### 1.3 验收

- [x] `loading -> content` widget smoke test。
- [x] 清理缓存确认弹层 smoke test。
- [x] 成功反馈 `SnackBar` smoke test。
- [x] 单项缓存清理失败反馈 smoke test。
- [x] 桌面宽屏 `1280x800` smoke test。
- [ ] 真机 Android / iOS smoke 待后续人工验收。

---

## 2. Phase 5 性能治理

### 2.1 已落地规则

- [x] 新增 foundation 组件保持 `const` 构造优先。
- [x] `AppReorderableList` 使用 builder 模式，避免长列表一次性 children 构建。
- [x] `AppReorderableList` smoke 覆盖 120 个稳定 key item。
- [x] `AppSkeletonList` 使用固定高度，避免 loading -> content 明显 layout shift。
- [x] `StorageManagementPage` 试点页面保留有限静态区块，不把 `shrinkWrap` 用在长列表上。

### 2.2 仍需后续补齐

- [ ] 图片封面统一组件需要补 loading / error / cache hit / decode size 测试。
- [ ] Bookshelf / Search 高频列表需要独立做滚动和图片尺寸审查。
- [ ] `flutter_slidable` 项目封装后需要补移动端左滑、桌面替代入口和撤销反馈性能验证。

---

## 3. Phase 6 自动化检查

### 3.1 已落地脚本能力

- [x] 扩展 `tool/check_ui_component_governance.dart`。
- [x] 支持全量报告模式：`dart run tool/check_ui_component_governance.dart`。
- [x] 支持新增/修改行报告模式：`dart run tool/check_ui_component_governance.dart --diff-only`。
- [x] 支持按需阻断：`--fail-on-warning`。
- [x] 检查新增裸弹层、裸反馈、业务页面直连成熟能力、硬编码样式、长列表风险和裸 Scaffold。
- [x] diff-only 模式会扫描未跟踪 Dart 文件，适合当前阶段报告新增问题。

### 3.2 当前验证结果

- [x] `dart analyze tool/check_ui_component_governance.dart` 通过。
- [x] `dart run tool/check_ui_component_governance.dart --diff-only` 通过，当前报告模式不阻断。
- [ ] 当前工作树另有未跟踪 `book_detail_content_sections.dart` 产生 7 个 warning，进入后续 backlog，不在本轮 StorageManagement 试点内处理。

### 3.3 CI 策略

- [x] 当前阶段只建议报告模式，不阻断 CI。
- [ ] 下一轮可先阻断新增裸 `showDialog` / `showModalBottomSheet`。
- [ ] 再下一轮阻断业务页面直接新增 `RefreshIndicator`、`HapticFeedback`、`MenuAnchor`、`Slidable`、`Shimmer` 等能力调用。

---

## 4. Phase 7 分模块推广

### 4.1 本轮推广结论

- [x] Mine 模块已完成 1 个低风险页面试点。
- [x] 试点证明 foundation 能力可以覆盖反馈、弹层、骨架和测试注入。
- [x] 自动化规则可用于后续 PR 的新增行报告。

### 4.2 下一轮推广顺序

- [ ] Mine: FontManagementPage 或 LaunchImageGalleryPage，优先迁移 `RefreshIndicator` 和 `AppFeedback`。
- [ ] Bookshelf: 筛选/排序局部，优先迁移反馈、右键/更多操作和长列表性能规则。
- [ ] Search: 搜索结果卡片和失败报告，优先迁移 `AppHighlightedText`、错误反馈和 loading 状态。
- [ ] Book detail: 主操作和目录局部，优先迁移反馈、图片占位和操作面。
- [ ] Reader 非核心周边: 设置 sheet、目录 sheet 和缓存反馈，避开核心阅读链路。

### 4.3 不推广的范围

- [x] 本轮不迁移 Reader 核心页面。
- [x] 本轮不全量替换所有 Material Button/TextField。
- [x] 本轮不新增大而全 UI Kit，也不新增 `photo_view` / `context_menus`；原生能力不足时再评估。

---

## 5. 本轮验证命令

```bash
flutter test test/features/mine/presentation/storage_management_page_test.dart
flutter test test/app/widgets/foundation_components_test.dart
flutter analyze lib/app/widgets/foundation lib/features/mine/application/storage_management_service.dart lib/features/mine/presentation/storage_management_page.dart test/app/widgets/foundation_components_test.dart test/features/mine/presentation/storage_management_page_test.dart
dart analyze tool/check_ui_component_governance.dart
dart run tool/check_ui_component_governance.dart --diff-only
```
