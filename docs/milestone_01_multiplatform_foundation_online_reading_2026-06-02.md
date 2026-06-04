# 里程碑 01：多端底座绿线与在线阅读闭环

创建日期：2026-06-02
复拆日期：2026-06-04

状态：旧 Phase 1.1-1.6 已完成；按 2026-06-04 多端规则进入 M1-R 复验与补验。

适用平台：Android、iOS、Web JS、macOS、Windows、Linux。Web WASM 仍为独立专项。

核心目标：把在线阅读链和最小登录会话链从“Web / Desktop 可走通”升级为“Android / iOS / Web / Desktop 影响面清楚、能力边界清楚、每段可重新执行”。

## 1. 阶段定位

第一里程碑不追求所有平台全功能完成，而是先把底座和第一条业务链扶正：

- 有规则：开发、UI、业务、平台、存储、路由都能找到统一文档。
- 有绿线：分析、Web JS 构建、macOS 构建、docs guard、route inventory 能稳定通过。
- 有闭环：搜索 / 发现 -> 书籍详情 -> 在线阅读 -> 进度保存可以被真实操作验证。
- 有会话：登录入口 -> 登录 / 会话恢复 -> 受限入口展示 -> 退出登录 -> 会话过期跳转具备最小多端闭环。
- 有平台记录：Android、iOS、Web、macOS、Windows、Linux 都必须写明已验证、未验证原因或非交付目标。
- 有边界：不支持能力要有禁用、隐藏、只读或替代入口，不让用户点了才失败。

旧完成项不撤销；本次复拆是为了按新的多端口径重新执行、补验证据和拆出后续可维护段落。

## 2. 执行方式

每个复拆段都必须记录：

- 本段目标。
- 修改范围。
- 是否修改共享层。
- Android / iOS 影响面和回归方式。
- Web / Desktop 验证方式。
- 不支持能力的降级结论。
- 已验证平台与未验证原因。

任一复拆段如果涉及共享 model、provider、repository、service、route、storage、theme token、adaptive 组件或平台 capability，不能只写“移动端未涉及”。

## 3. 不做项

- [x] 不做 Web WASM 交付。
- [x] 不做本地图书完整多端导入。
- [x] 不做全部阅读模式多端完美适配。
- [x] 不做 Windows / Linux 正式发布。
- [x] 不一次性升级所有 major 依赖。
- [x] 不大规模重写移动端成熟页面。

## 4. 移动端复验红线

- [ ] Android / iOS 主导航、系统返回、iOS 返回手势、Android 返回键不回退。
- [ ] Android / iOS 阅读器默认手势、目录、设置、进度保存不回退。
- [ ] Android / iOS 存储 key、数据库迁移、用户资产路径不被本阶段改动。
- [ ] 移动端小屏断点不因桌面 UI 需求改变。
- [ ] 如有共享层等价抽取，记录旧行为与新 capability 结果的一致性。

## 5. M1-R 复拆执行段

| 段 | 名称 | 目标 | Android / iOS 检查 | Web / Desktop 检查 | 状态 |
| --- | --- | --- | --- | --- | --- |
| M1-R0 | 文档入口与规则同步 | README、平台规则、业务规则、UI 规则、代码规则指向多端口径 | 确认移动端不再只是“不可触碰边界” | 确认 Web / Desktop 仍保留宽屏与降级规则 | [ ] |
| M1-R1 | 工程绿线复验 | 分析、docs guard、route inventory、Web build、macOS build | 记录 Android / iOS 构建是否执行，未执行写原因 | Web JS 与 macOS 至少保持绿色 | [ ] |
| M1-R2 | Capability 矩阵复验 | 复核 `AppPlatformCapabilities` 覆盖在线阅读链能力 | 亮度、音量键、WebView、图片选择、文件能力结果不回退 | WebView、文件、数据库、窗口、诊断能力不散落页面 | [ ] |
| M1-R3 | 搜索 / 发现入口链 | 搜索 / 发现入口、加载、失败、空态、重试可用 | 移动端入口与触控路径不变 | Web / Desktop 入口、刷新、宽屏状态可用 | [ ] |
| M1-R4 | 书籍详情链 | 详情、目录、加入书架、换源、开始阅读可用 | 移动端详情页主操作层级不回退 | 宽屏不无限拉宽，受限能力按 capability 显示 | [ ] |
| M1-R5 | 在线阅读核心链 | 在线章节渲染、目录跳转、设置、进度保存、恢复进度 | 触控翻页 / 滚动、目录、设置、进度保存不回退 | 方向键、空格、滚轮、宽屏正文不遮挡 | [ ] |
| M1-R6 | 最小登录与会话链 | 登录入口、会话恢复、退出登录、会话过期跳转可解释 | 移动端登录、会话恢复、退出登录和受限入口不回退 | Web / Desktop 登录入口、凭证持久化、外部浏览器或降级策略清楚 | [ ] |
| M1-R7 | 降级与异常链 | WebView 登录、本地书入口、网络失败、空态禁用清晰 | 移动端可用能力不被桌面降级覆盖 | Web / Desktop 不支持能力不出现点击后失败 | [ ] |
| M1-R8 | 复验记录落表 | 收尾记录按 6 平台填写 | Android / iOS 真实验证、模拟器验证或发布前补验明确 | Web、macOS、Windows、Linux 分别写明状态 | [ ] |

## 6. 旧完成基线

旧 Phase 1.1-1.6 的结果作为复验起点：

- [x] `flutter analyze` 通过。
- [x] `flutter build web --no-pub` 通过。
- [x] `flutter build macos --debug --no-pub` 或 release build 通过。
- [x] `dart tool/check_architecture_guardrails.dart --check=docs` 通过。
- [x] `dart run tool/check_route_inventory.dart` 通过。
- [x] `AppPlatformCapabilities` 已扩展为平台能力矩阵。
- [x] WebView 登录页改用 capability。
- [x] 搜索、发现、详情、在线阅读 smoke 链路已建立。
- [x] 书架桌面空态和阅读器桌面输入解析已有测试基础。

## 7. 复验命令

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
flutter test test/features/reader/application/online_reading_chain_smoke_test.dart
flutter test test/features/bookshelf/presentation/bookshelf_desktop_layout_test.dart
flutter test test/core/auth/auth_session_store_test.dart test/features/auth/application/auth_form_validation_service_test.dart test/features/auth/application/auth_provider_smoke_test.dart
```

移动端补验按可用环境选择：

```bash
flutter build apk --no-pub
flutter build ios --no-pub --no-codesign
```

## 8. 复验通过标准

- [ ] M1-R0 到 M1-R8 均有执行记录。
- [ ] Web JS 可构建。
- [ ] macOS 可构建。
- [ ] 在线阅读链路可走通。
- [ ] 最小登录与会话链路可走通。
- [ ] Android / iOS 影响面和未验证原因清楚。
- [ ] 不支持能力有可理解降级。
- [ ] 关键文档和路由清单同步。
- [ ] Windows / Linux 未验证原因或 CI 补验计划明确。

## 9. 风险

- [ ] Web JS 可用但 Web WASM 不可用，需避免混淆交付目标。
- [ ] 阅读器复杂度高，本阶段只保证在线文本阅读闭环。
- [ ] 详情页、书架页、阅读器页文件过大，继续加功能会加重治理成本。
- [ ] Web / Desktop 平台能力不一致，必须用 capability 收口。
- [ ] 新的多端复验会暴露 Android / iOS 真机验证缺口，需要在发布前补齐。

## 10. 执行记录

- [x] 原开始日期：2026-06-02
- [x] 原完成日期：Phase 1.1-1.3 于 2026-06-02 完成；Phase 1.4-1.6 与桌面 UI 最低要求于 2026-06-02 完成。
- [ ] M1-R 复验开始日期：
- [ ] M1-R 复验完成日期：
- [ ] Android 验证：
- [ ] iOS 验证：
- [ ] Web 验证：
- [ ] macOS 验证：
- [ ] Windows 验证：
- [ ] Linux 验证：
- [ ] 未验证平台和原因：
- [ ] 关键改动：
- [ ] 遗留问题：
