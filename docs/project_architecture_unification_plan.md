# 项目架构统一计划

更新时间：2026-06-02

本文是架构 guardrail 的统一计划文档，用于把项目从“移动端稳定 + 多端迁移中”推进到“多端稳定 + 长期可治理”。

## 1. 当前结论

项目主架构方向正确，但还处于治理收口期。

已经成熟的部分：

- Feature-first 目录已经形成。
- Riverpod、GoRouter、Dio、Drift 等基础选型合理。
- 多端平台目录齐全。
- Web JS 和 macOS 已经具备构建基础。
- 自适应布局、主题 token、组件治理脚本已经存在。

需要统一的部分：

- 超大页面拆分。
- `core -> features` 反向依赖清理。
- 页面层平台判断收敛。
- 手写模型和 JSON 样板减少。
- Android / iOS / Web / Desktop 业务链验收矩阵补齐。
- 依赖升级和本地 override 治理。

## 2. 目标架构

```text
app
  composition / shell / router / theme / platform capability
core
  network / auth / storage / cache / device / logging / feedback
domain
  pure entities + repository contracts
data
  drift / datasource / repository implementations
features
  presentation / application / providers / routes
shared
  generic reusable widgets and utils
```

依赖方向必须保持：

```text
presentation -> application -> domain/core
data -> domain/core
app -> composition/root
core -> no features
domain -> pure dart
```

## 3. 统一阶段

### Phase A：Guardrail 修绿

- [x] 清理 `core -> features` 反向依赖。
- [x] 补齐路由清单。
- [x] 将架构统一计划纳入 docs。
- [x] 处理超过硬阈值的超大文件。
- [x] `dart tool/check_architecture_guardrails.dart` 通过。

### Phase B：多端能力收敛

- [x] 扩展 `AppPlatformCapabilities`，覆盖 Web 文件上传、桌面文件导入、诊断导出、WebView、音频、窗口能力。
- [x] 页面层新增平台分支必须改为 capability 或 adaptive metrics。
- [x] Native/Web 数据、文件、缓存继续使用条件导入。
- [x] Web JS 构建进入常规验证。
- [ ] Web WASM 单独建依赖兼容专项。

### Phase C：复杂页面拆分

- [ ] 拆 `reader_page.dart`：shell、overlay、toolbar、tap zone、runtime controller。
- [ ] 拆 `bookshelf_page.dart`：桌面布局、筛选、空态、书籍卡片、批量操作。
- [ ] 拆 `reader_page_settings_sheet.dart`：字体、排版、主题、音频、漫画设置组。
- [ ] 拆 `advanced_theme_service.dart`：资源读写、导入导出、存储迁移、主题编排。
- [ ] 拆 `advanced_theme_list_page.dart` 和 `advanced_theme_editor_page.dart`。
- [ ] 每次拆分保持行为等价，并补最小测试。

### Phase D：模型与偏好治理

- [ ] 新增状态模型默认使用不可变模型。
- [ ] 新增 JSON DTO 优先生成。
- [ ] 全局偏好继续收敛到 typed preference service。
- [ ] 旧模型只在改动窗口逐步迁移。

### Phase E：UI 和主题治理

- [ ] 新页面默认使用 adaptive 组件。
- [ ] 桌面弹层从 bottom sheet 迁到 dialog / side panel / popover。
- [ ] 高风险页面接入 `AppComponentThemeTokens`。
- [ ] 主题 coverage audit 的 high risk 文件逐步下降。

### Phase F：依赖与成熟库治理

- [ ] 按批次升级 Riverpod、GoRouter、plus 插件、secure storage、share_plus、flutter_lints。
- [ ] 本地 override 包建立说明和回主线计划。
- [ ] discontinued transitive dependency 进入升级风险清单。

## 4. 验收标准

阶段性验收：

- `flutter analyze` 通过。
- 架构、存储、路由 guard 通过。
- Web JS build 通过。
- 至少一个桌面 build 通过。
- 关键业务链 widget/service test 通过。
- 文档入口同步更新。

发布前验收：

- Android / iOS 关键流程不回退。
- Web / macOS / Windows / Linux 构建矩阵明确。
- 不支持能力有禁用、隐藏或替代策略。
- 缓存和存储不新增高风险落点。
