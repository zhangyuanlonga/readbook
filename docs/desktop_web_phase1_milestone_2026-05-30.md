# Web / Windows / macOS 第一里程碑任务

创建日期：2026-05-30  
里程碑名称：**Phase 1 - 多平台渐进式 Preview 基线**  
目标平台：Web、Windows、macOS  
保护平台：Android、iOS  
最高红线：**不得破坏移动端已上线稳定 UI、交互、业务逻辑和数据路径。**

## 0. 输入文档

本里程碑必须先阅读并遵守以下两份文档：

- [Web / Windows / macOS 渐进式适配规则](progressive_multiplatform_adaptation_rules_2026-05-30.md)
- [Web / Windows / macOS 适配功能模块扫描清单](multiplatform_adaptation_inventory_2026-05-30.md)

本里程碑的任务拆分基于扫描清单中的复杂度与阻断项，后续执行时不得绕过这两份文档。

阶段执行记录：

- [Phase 1.0 移动端保护基线记录](phase1_mobile_protection_record_2026-05-30.md)
- [Phase 1.1 平台能力与 import 链记录](phase1_platform_capability_record_2026-05-30.md)
- [Phase 1.2 构建与启动基线记录](phase1_build_startup_record_2026-05-30.md)
- [Phase 1.3 低风险页面记录](phase1_low_risk_pages_record_2026-05-30.md)
- [Phase 1.4 核心只读路径记录](phase1_core_readonly_path_record_2026-05-30.md)
- [Phase 1.5-1.7 Shell、风险与验证记录](phase1_shell_risk_validation_record_2026-05-30.md)

## 1. 里程碑目标

Phase 1 不追求一次性完整适配所有功能，只建立一条安全、可持续的多平台适配路径：

- [ ] Web 可以启动、构建、浏览低风险页面。
- [ ] macOS 可以构建并打开基础页面。
- [ ] Windows 有明确构建与验证任务，可在 Windows 环境补跑。
- [ ] Android / iOS 现有功能保持不变。
- [ ] 高风险移动端能力不强行迁移，先通过能力表、禁用态、替代方案处理。
- [ ] 后续每个功能都可以按“评估 -> 隔离 -> 适配 -> 四端验证”的流程推进。

## 2. 执行约束

所有阶段任务必须遵守：

- [ ] 不直接修改 Android / iOS 专属逻辑。
- [ ] 不为了 Web/Desktop 修改移动端默认布局。
- [ ] 遇到共享层必须改动时，先记录风险，不直接合并。
- [ ] 只勾选真实完成且验证过的任务。

## 3. 阶段任务

### Phase 1.0：移动端保护基线

目标：先定义“不能碰哪里”，避免后续适配失控。

- [x] 标记 Android / iOS 已上线核心路径为受保护范围。
- [x] 确认本阶段不直接重构移动端页面目录。
- [x] 建立移动端冒烟回归清单：启动、登录、书架、搜索、详情、阅读、设置。
- [x] 确认所有后续任务必须写明“是否影响 Android / iOS”。
- [x] 确认所有共享层改动必须附带移动端回归结果。
- [ ] 在 PR / 执行记录模板中加入“移动端影响评估”字段。

完成标准：

- [ ] 每个后续适配任务都有移动端影响说明。
- [x] 没有任何任务要求直接修改移动端稳定 UI。

### Phase 1.1：平台能力表与 import 链隔离

目标：先解决 Web/Desktop 能不能安全编译、启动，以及不支持能力如何表达。

- [x] 复查 `lib/app/platform/app_platform_capabilities.dart` 的 Web / Windows / macOS 能力状态。
- [x] 对照扫描清单，列出所有 Web import 链风险。
- [x] 优先处理或登记这些高风险入口：`dart:io`、`path_provider`、本地文件、PDF、本地图书解析、受管资源、日志导出。
- [x] 为 Web 不支持能力定义统一策略：隐藏、禁用、替代方案、只读模式。
- [x] 明确 Windows / macOS 文件选择、分享、外部打开、数据库、凭证存储的支持状态。
- [x] 统一图片选择能力口径：移动端走相机/相册，Web/Desktop 走文件选择或禁用。
- [x] 统一移动端专属能力口径：亮度、音量键、电量、触感反馈不作为 Web/Desktop 阻断。
- [x] 输出一份“平台能力差异表”并追加到本里程碑执行记录。

完成标准：

- [ ] Web 不会因为 native-only import 链直接编译失败。
- [ ] 不支持能力不会显示成可点击失败入口。
- [ ] 平台差异集中到 capability / adapter / conditional import，不散落页面。

### Phase 1.2：构建与启动基线

目标：确认新平台最小启动路径可用。

- [x] 执行 `flutter pub get`。
- [x] 执行 `flutter analyze`。
- [ ] 执行 `flutter test`。
- [x] 执行 `flutter build web --debug --no-web-resources-cdn --no-wasm-dry-run`。
- [x] 启动 Web 本地预览并检查首屏不白屏。
- [x] 执行 macOS debug build 或 run。
- [ ] 在 Windows 环境执行 Windows debug build 或 run。
- [ ] 检查 Web 标题、manifest、favicon、主题色与品牌一致。
- [ ] 检查 macOS / Windows 默认窗口标题、图标、尺寸与品牌一致。
- [x] 记录所有构建警告、失败、未验证平台。

完成标准：

- [x] Web debug build 通过。
- [x] macOS debug build 或 run 通过。
- [ ] Windows build / run 有真实验证记录。
- [ ] Android / iOS 未因本阶段改动产生回归。

### Phase 1.3：低风险页面先行适配

目标：先完成无明显平台依赖的页面，验证渐进式流程可行。

优先页面来自扫描清单 P0：

- [x] 公告列表：`lib/features/announcement/presentation/announcement_list_page.dart`
- [ ] 公告详情：`lib/features/announcement/presentation/announcement_detail_page.dart`
- [x] 关于页：`lib/features/mine/presentation/about_page.dart`
- [ ] 发现页：`lib/features/discover/presentation/discover_page.dart`
- [ ] 发现分类页：`lib/features/discover/presentation/discover_category_books_page.dart`
- [ ] 搜索失败详情弹层：`lib/features/search/presentation/widgets/search_failure_banner.dart`
- [ ] 空态 / 状态组件：`lib/app/widgets/app_empty_state_card.dart`、`lib/app/widgets/app_status_state_card.dart`
- [x] 功能禁用页：`lib/app/widgets/feature_disabled_page.dart`

每个页面适配规则：

- [x] 不修改 mobile 原有交互路径。
- [x] Web/Desktop 只通过 wrapper、外层约束、Adaptive 组件增强。
- [ ] 宽屏下设置合理最大宽度或多栏布局。
- [ ] 鼠标滚轮、键盘焦点、链接打开可用。
- [ ] 390x844 仍保持移动端体验。
- [ ] 1280x800 不出现无限拉宽、遮挡或按钮溢出。

完成标准：

- [ ] 至少 5 个低风险页面在 Web/macOS 完成视觉与交互验证。
- [ ] 移动端同页面截图或冒烟结果无变化。

### Phase 1.4：核心只读路径适配

目标：打通“浏览 -> 搜索 -> 详情 -> 在线阅读”的新平台最小闭环，不碰高风险本地导入。

- [ ] 搜索页基础路径：输入关键词、发起搜索、展示结果。
- [ ] 搜索结果卡片：Web/Desktop 列表或网格展示。
- [ ] 图书详情只读路径：封面、简介、目录、主要操作区。
- [x] 服务器书源详情路径：不依赖本地文件能力。
- [ ] 在线正文阅读路径：优先验证非本地图书。
- [ ] 书架只读路径：展示已有书籍，暂不强制支持 Web 本地导入。
- [ ] 书签 / 阅读记录基础浏览。
- [ ] 分享能力降级：Web/Desktop 优先复制链接或外部打开。

完成标准：

- [ ] Web 完成搜索到详情的基础路径。
- [ ] macOS 完成搜索到详情的基础路径。
- [ ] 在线阅读基础路径可进入且不崩溃。
- [ ] 本地图书导入未完成时，入口有明确受限说明。

### Phase 1.5：Shell、导航与桌面交互基线

目标：让 Web/Desktop 不只是手机页面拉宽。

- [x] 确认 Mobile Shell 保持原底部导航和页面栈。
- [ ] 为 Web/Desktop 规划独立 Shell：左侧导航栏 + 内容区。
- [ ] 明确哪些路由共享，哪些页面骨架分离。
- [x] 宽度 `< 600` 保持移动端布局。
- [ ] 宽度 `600 - 839` 使用平板紧凑布局。
- [ ] 宽度 `840 - 1199` 启用侧栏或宽内容区。
- [ ] 宽度 `>= 1200` 支持桌面多栏 / 网格 / 预览面板。
- [ ] 将长按 / 滑动类操作映射到右键菜单、更多按钮或显式操作。
- [x] 阅读器键盘翻页、Esc、PageUp / PageDown、方向键有统一策略。
- [ ] 统一 hover、focus ring、滚轮行为。

完成标准：

- [ ] Desktop/Web Shell 方案明确。
- [ ] 不再把桌面端体验定义为移动端横向拉伸。
- [x] 移动端 Shell 不受影响。

### Phase 1.6：高风险能力降级与延期清单

目标：高风险能力不在 Phase 1 强行完整实现，先定义安全边界。

需要降级或延期的能力：

- [ ] 本地图书导入：Web 先受限或文件上传模式，Desktop 使用 file_selector。
- [ ] 本地图书解析：TXT / EPUB / PDF / MOBI 按格式逐个验证。
- [ ] PDF 阅读：Web 需要专门 renderer 或禁用本地 PDF。
- [ ] 字体管理：Web 先禁用或上传到浏览器存储。
- [ ] 自定义主题 / 背景 / 图集：Web 先只读预设或上传受限。
- [ ] WebView 登录：Web/Desktop 优先外部浏览器或服务器登录。
- [x] 亮度控制：仅移动端支持，新平台隐藏。
- [x] 音量键翻页：仅移动端支持，新平台替代为键盘快捷键。
- [ ] 电量显示：Web/Desktop 显示未知或隐藏。
- [ ] 分享：Web/Desktop 使用复制链接、下载文件或外部打开。
- [ ] 支付：新平台优先跳 Web 收银台或外部浏览器。

完成标准：

- [x] 所有高风险能力都有“支持 / 替代 / 禁用 / 延期”结论。
- [ ] 用户不会在 Web/Desktop 点到必失败入口。
- [ ] 高风险能力不阻塞低风险页面发布。

### Phase 1.7：四端验证与发布闸门

目标：确定能否开放 Preview。

- [ ] Android 冒烟：启动、登录、书架、搜索、详情、阅读、设置。
- [ ] iOS 冒烟：启动、登录、书架、搜索、详情、阅读、设置。
- [ ] Web 验证：首屏、刷新、前进后退、低风险页面、搜索到详情。
- [ ] macOS 验证：启动、窗口缩放、导航、低风险页面、搜索到详情。
- [ ] Windows 验证：启动、窗口缩放、导航、低风险页面、搜索到详情。
- [ ] 视口验证：390x844、600x960、840x1180、1280x800。
- [ ] 字体缩放验证：1.0x、1.3x。
- [ ] 弹层验证：移动端仍是 bottom sheet，桌面/Web 是 dialog / panel / popover。
- [x] 记录未验证项、阻断项和延期项。
- [x] 更新本里程碑勾选状态。

发布闸门：

- [ ] Android / iOS UI 与核心逻辑回归为 0。
- [x] Web debug build 通过。
- [x] macOS build / run 通过。
- [ ] Windows build / run 通过。
- [ ] P0 低风险页面可浏览。
- [ ] 搜索到详情基础路径可用。
- [x] 高风险能力有明确降级说明。

## 4. 执行记录模板

每次执行后追加一段：

```markdown
### 执行记录：YYYY-MM-DD

- 执行人：
- 执行阶段：
- 修改范围：
- 是否影响 Android / iOS：
- Android 验证：
- iOS 验证：
- Web 验证：
- macOS 验证：
- Windows 验证：
- 已完成勾选：
- 未完成原因：
- 新增阻断项：
- 下一步：
```

## 5. 当前执行摘要

### 执行记录：2026-05-30

- 执行人：Codex。
- 执行阶段：Phase 1.0、Phase 1.1、Phase 1.2。
- 修改范围：仅 `docs/` 记录与里程碑勾选；未修改 `lib/`、`android/`、`ios/`。
- 是否影响 Android / iOS：否，本轮没有修改移动端业务代码或 UI。
- Android 验证：未运行真机/模拟器冒烟；已建立冒烟清单。
- iOS 验证：未运行真机/模拟器冒烟；已建立冒烟清单。
- Web 验证：debug build 通过，本地预览首屏不白屏。
- macOS 验证：debug build / run 通过；run 日志出现 `Failed to foreground app; open returned 1`，未阻塞启动。
- Windows 验证：未验证，当前 macOS host 不支持 `flutter build windows`。
- 已完成勾选：Phase 1.0 部分任务、Phase 1.1 扫描与记录任务、Phase 1.2 构建启动通过项。
- 未完成原因：`flutter test` 失败；Windows 未验证；品牌一致性未通过；Web native-only import 链仍需后续 adapter/stub 解决。
- 新增阻断项：Web import 链仍涉及 `dart:io` / `path_provider` 高风险服务；品牌名 `Selune`、`书享阅读 Next`、`flutter_appread`、`shuxiang_reading_next` 并存。
- 下一步：优先修复 Web import 链和品牌一致性，再进入 Phase 1.3 低风险页面适配。

### 执行记录：2026-05-30（剩余阶段）

- 执行人：Codex。
- 执行阶段：Phase 1.3、Phase 1.4、Phase 1.5、Phase 1.6、Phase 1.7。
- 修改范围：仅 `docs/` 记录与里程碑勾选；未修改 `lib/`、`android/`、`ios/`。
- 是否影响 Android / iOS：否，本轮没有修改移动端业务代码或 UI。
- Web 验证：低风险页面中公告列表、关于页、功能禁用页已可打开；发现页被 Shell 默认可见性重定向，核心只读路径未完成真实搜索到详情交互。
- macOS 验证：`--route /about` debug run 启动成功；核心搜索到详情未完成真实交互。
- Windows 验证：未验证。
- 已完成勾选：Phase 1.3 部分低风险页面、Phase 1.4 服务器书源详情静态路径、Phase 1.5 部分 Shell/阅读器键盘策略、Phase 1.6 高风险能力结论、Phase 1.7 部分发布闸门。
- 未完成原因：Browser 插件没有可用 in-app browser pane；发现页入口默认不可见；在线搜索依赖登录/会员/服务器网关测试数据；Windows 未验证；移动端真机冒烟未执行。
- Phase 1 Preview 结论：当前不建议开放 Preview；应先进入 Phase 2 处理阻断项。
