# 里程碑 01：多端底座绿线与在线阅读闭环

创建日期：2026-06-02

状态：待执行

适用平台：Android、iOS、Web JS、macOS，Windows / Linux 进入构建验证准备。

核心目标：在保护 Android / iOS 稳定体验的前提下，让 Web / Desktop 开发有统一底座，并跑通第一条真实业务链：搜索 / 发现 -> 书籍详情 -> 在线阅读 -> 进度保存。

## 1. 阶段定位

第一里程碑不追求所有平台全功能完成，而是先把方向扶正：

- 有规则：开发、UI、业务、平台、存储、路由都能找到统一文档。
- 有绿线：分析、Web JS 构建、macOS 构建、docs guard、route inventory 能稳定通过。
- 有闭环：至少一条 Web / Desktop 真实阅读链路能从入口走到进度保存。
- 有边界：不支持能力要有禁用、隐藏或替代，不让用户点了才失败。

## 2. 不做项

- [x] 不做 Web WASM 交付。
- [x] 不做本地图书完整多端导入。
- [x] 不做全部阅读模式多端完美适配。
- [x] 不做 Windows / Linux 正式发布。
- [x] 不一次性升级所有 major 依赖。
- [x] 不大规模重写移动端成熟页面。

## 3. 移动端保护红线

- [ ] 共享层改动必须说明 Android / iOS 影响面。
- [ ] 不修改移动端主导航交互。
- [ ] 不修改移动端阅读器默认手势和阅读体验。
- [ ] 不修改移动端存储 key、数据库迁移和用户资产路径，除非有兼容迁移。
- [ ] 不因桌面 UI 需求改小屏断点行为。

## 4. 构建与工程绿线

### Phase 1.1：基础验证

- [ ] `flutter analyze` 通过。
- [ ] `flutter build web --no-pub` 通过。
- [ ] `flutter build macos --debug --no-pub` 或 release build 通过。
- [ ] `dart tool/check_architecture_guardrails.dart --check=docs` 通过。
- [ ] `dart run tool/check_route_inventory.dart` 通过。
- [ ] Markdown 相对链接无缺失。

### Phase 1.2：架构 guard 收口

- [ ] 修复 `core -> features` 反向依赖。
- [ ] 对超过硬阈值的文件建立拆分任务，不继续加重。
- [ ] `reader_page.dart` 不再新增无关功能代码。
- [ ] `advanced_theme_service.dart` 不再新增无关存储 / UI 编排代码。
- [ ] 架构 guard 中 docs 和 routes 必须保持绿色。

### Phase 1.3：平台能力矩阵

- [ ] 扩展并复核 `AppPlatformCapabilities`。
- [ ] 明确 Web JS、Web WASM、macOS、Windows、Linux 的不同状态。
- [ ] 文件导入能力区分 Web 上传与 Native 文件系统。
- [ ] 数据库存储能力区分 Native SQLite 与 Web storage。
- [ ] WebView、图片选择、诊断导出、亮度桥、音量键桥接进入能力表。
- [ ] 页面层新增平台判断必须改为 capability 或 adaptive metrics。

## 5. 第一条业务链：在线阅读闭环

目标链路：

```text
搜索 / 发现 -> 书籍详情 -> 在线章节阅读 -> 目录 / 翻页 / 设置 -> 进度保存 -> 再次进入恢复进度
```

### Phase 1.4：入口与搜索 / 发现

- [ ] Web / Desktop 可以进入搜索页。
- [ ] Web / Desktop 可以进入发现页。
- [ ] 搜索加载、失败、空态、取消、重试状态完整。
- [ ] 发现页加载、失败、空态、刷新入口完整。
- [ ] 不支持 WebView 登录的能力有明确说明。

### Phase 1.5：书籍详情

- [ ] 搜索结果或发现入口可以进入详情页。
- [ ] 详情页在 Web / Desktop 宽度下不无限拉宽。
- [ ] 目录加载、失败、空态有统一状态。
- [ ] 加入书架、开始阅读、换源等入口按 capability 显示。
- [ ] 本地图书相关入口不干扰在线阅读链。

### Phase 1.6：阅读器最小闭环

- [ ] 在线章节可以打开阅读器。
- [ ] 文本阅读模式可正常渲染。
- [ ] 键盘方向键 / 空格至少有基础翻页或滚动策略。
- [ ] 滚轮行为不破坏阅读器主体验。
- [ ] 目录可以打开并跳转。
- [ ] 阅读设置可以打开并关闭。
- [ ] 进度可以保存。
- [ ] 再次从详情、书架或记录进入时能恢复合理位置。

## 6. 桌面 UI 最低要求

本阶段只做最低可接受标准：

- [ ] 桌面 shell 不白屏、不遮挡。
- [ ] 首页、书架、我的页在 1024 / 1440 宽度下没有明显手机页面拉宽感。
- [ ] 页面空态、加载态、禁用态清楚。
- [ ] 书架桌面空态保留本地图书入口或明确禁用原因。
- [ ] 任务队列、搜索入口、公告入口位置清晰。

## 7. 测试与验收

最低验收命令：

```bash
flutter analyze
dart tool/check_architecture_guardrails.dart --check=docs
dart run tool/check_route_inventory.dart
flutter build web --no-pub
flutter build macos --debug --no-pub
```

建议测试：

```bash
flutter test test/app/layout/adaptive_breakpoints_test.dart test/app/widgets/adaptive_components_test.dart
flutter test test/features/reader/application/reader_desktop_input_resolver_test.dart
flutter test test/features/reader/application/reader_entry_route_resolver_test.dart
flutter test test/features/search/application/search_provider_smoke_test.dart
```

通过标准：

- [ ] Web JS 可构建。
- [ ] macOS 可构建。
- [ ] 在线阅读链路可走通。
- [ ] 不支持能力有可理解降级。
- [ ] 移动端风险记录完整。
- [ ] 关键文档和路由清单同步。

## 8. 风险

- [ ] Web JS 可用但 Web WASM 不可用，需避免混淆交付目标。
- [ ] 阅读器复杂度高，第一阶段只保证在线文本阅读闭环。
- [ ] 详情页、书架页、阅读器页文件过大，继续加功能会加重治理成本。
- [ ] Web / Desktop 平台能力不一致，必须用 capability 收口。

## 9. 执行记录

- [ ] 开始日期：
- [ ] 完成日期：
- [ ] 已验证平台：
- [ ] 未验证平台和原因：
- [ ] 关键改动：
- [ ] 遗留问题：
