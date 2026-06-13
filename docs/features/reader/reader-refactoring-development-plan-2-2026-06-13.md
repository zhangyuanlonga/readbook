# 阅读器重构开发计划二：设置页优先拆分

**日期**: 2026-06-13  
**范围**: `lib/features/reader/presentation/reader_page_settings_sheet.dart`、`lib/features/reader/presentation/sheets/reader_settings/`、低风险 `reader_page` presentation part  
**目标**: 先完成设置页真实拆分，再考虑低风险 part 解耦；不为了行数牺牲阅读器稳定性。

---

## 1. 当前判断

上一阶段已经建立了设置页目录、通用组件和 section wrapper，但目前真实完成度仍偏低：

- [x] `reader_page_settings_sheet.dart` 当前约 4181 行。
- [x] `reader_settings_sections.dart` 当前只是 section 壳，约 62 行，具体设置项仍主要留在原 sheet。
- [x] `reader_settings_components.dart` 已有约 430 行通用组件，可复用。
- [x] `reader_page.dart` 当前约 5876 行，part 入口仍约 19 个。

结论：下一阶段优先级应聚焦 **Phase A：设置页拆分**。Phase B 和 Phase C 有价值，但不要抢在设置页完成前推进。

---

## 2. 优先级结论

### Phase A：完成设置页拆分，最高优先级

理由：

- [x] 收益最大：当前最大痛点是 4000+ 行设置 sheet。
- [x] 风险最低：主要是 UI 组合和回调搬迁，不改阅读进度、翻页、章节、书源核心逻辑。
- [x] 框架已具备：`sheets/reader_settings/`、section wrapper、components 已存在。
- [x] 体验收益直接：设置项更容易维护，后续修外观、主题、底部弹层更快。

### Phase B：低风险 part 解耦，次优先级

理由：

- [x] 有助于减少 `part of reader_page.dart` 的耦合。
- [x] 适合只挑纯展示或低状态文件做，不追求一次性清空 part。
- [x] 风险中等，必须排在设置页拆分之后。

### Phase C：reader_page 继续瘦身，中低优先级

理由：

- [x] `reader_page.dart` 仍大，但继续拆会更容易碰核心状态。
- [x] 手势、错误、书签等都和阅读状态/生命周期相连，不能按行数机械拆。
- [x] 适合作为 Phase A 完成后的长期治理，不作为当前主线。

---

## 3. Phase A 详细任务：设置页真实拆分

### A0：拆分前基线和保护线（0.5 天）

- [x] 记录设置页当前行数、主要 builder 区域、已有 section wrapper。
- [x] 标记不能改的敏感逻辑：`ReaderSettings` 序列化、`ReaderPreferencesService` 保存、自动阅读启停、会员判断、背景资源存储。
- [x] 为设置页 smoke 流程列清单：打开/关闭、应用、取消、字体、边距、翻页、背景、自动阅读、音频、漫画。
- [x] 确认本阶段只做 UI 组合搬迁，不改设置字段含义。

验收：

- [x] `flutter analyze` 无新增问题。
- [ ] 设置页打开不报错，现有 section wrapper 仍可定位。

### A1：字体/排版 section（1 天）

- [x] 新建 `reader_typography_settings_section.dart`。
- [x] 抽出字号、字重、字体来源、系统字体、正文颜色、阴影、下划线等字体样式；行距/字间距/段距/缩进随 A2 阅读排版面板迁出。
- [x] 抽出正文倾斜、阴影、下划线等纯 UI 项；文字两端对齐随 A3 交互面板迁出。
- [x] 保留原 `draft.copyWith(...)` 行为，不改字段名和默认值。
- [x] 补 widget smoke test，确认 section label、核心控件和回调可触发。

验收：

- [ ] 字体相关设置修改后可应用。
- [ ] 取消设置不污染当前配置。
- [x] `reader_page_settings_sheet.dart` 明显减少排版相关代码。

### A2：布局/信息栏 section（0.5-1 天）

- [x] 新建 `reader_layout_settings_section.dart`。
- [x] 抽出阅读边距、快捷边距卡片、阅读排版、章节头偏移。
- [x] 抽出信息栏位置、信息栏边距、电量/时间/进度/章节显示。
- [x] 复用已有 `ReaderSettingsComponents`，避免复制 slider/card 样式。
- [x] 保留平台电量读取提示和不支持状态。

验收：

- [ ] 页眉页脚显示、边距调整、电量提示行为不变。
- [ ] Android 底部安全区不被设置弹层遮挡。

### A3：翻页/交互 section（0.5-1 天）

- [x] 新建 `reader_page_turn_settings_section.dart`。
- [x] 抽出翻页模式、动画样式、纸页/仿真/覆盖/平移/无动画选择。
- [x] 抽出点击区域、音量键翻页、快捷开关中和翻页强相关的项目。
- [x] 保留 `_currentPagedAnimationStyle()`、`PagedTransitionController`、纸页动画逻辑不变。
- [x] 补测试覆盖动画选项渲染和选择回调。

验收：

- [ ] 切换翻页动画不需要重进阅读器。
- [ ] Android 真机纸页、仿真、无动画入口可正常选择。

### A4：自动阅读、音频、漫画 section（1 天）

- [x] 新建 `reader_auto_read_settings_section.dart`。
- [x] 新建 `reader_audio_settings_section.dart`。
- [x] 新建 `reader_manga_settings_section.dart`。
- [x] 抽出自动阅读模式、速度、暂停策略、结束策略、应用后启动开关。
- [x] 抽出音频自动播放、倍速、快进快退步长。
- [x] 抽出漫画阅读模式、加载策略、图片间距等。
- [x] 保留“当前内容模式下显示不同说明”的逻辑，并将应用外观主面板的内容模式说明迁入主题/背景 section。

验收：

- [ ] 文本章节、漫画章节、音频章节进入设置页展示正确。
- [ ] 自动阅读保存后启停行为不变。
- [ ] 音频倍速和步长设置不影响文本阅读。

### A5：主题/背景 section，分两步拆（1.5-2 天）

- [x] 新建 `reader_theme_background_settings_section.dart`。
- [x] 第一步抽出亮度、跟随系统、主题模式、背景色卡片。
- [x] 第二步抽出背景图预设、自定义背景图、移除背景、背景管理入口。
- [x] 抽出 `ReaderThemeBackgroundColorDot`、`ReaderBackgroundImageTile` 等子组件。
- [x] 会员/高级主题判断不在 section 内重新查权限；本轮仅接收外层传入状态和回调。
- [x] 自定义背景存储、删除、预加载逻辑仍保留在外层，section 只负责展示和回调。

验收：

- [ ] 默认背景、预设背景、自定义背景可正常切换。
- [ ] 会员限制提示不变。
- [ ] 移除背景和进入背景管理入口不回归。

### A6：设置页收口（0.5-1 天）

- [x] 删除原 sheet 中已经迁出的重复 builder。
- [x] 将 `wrapSettingsSection` 保持为纯 section 包装逻辑，不承载具体控件实现。
- [ ] 统一 section 输入模型命名，例如 `ReaderTypographySettingsSectionModel`。
- [x] 保持底部操作栏、应用/取消逻辑在外层统一收口。
- [x] 检查 `reader_page_settings_sheet.dart` 行数：当前约 1281 行，较 A0 的 4181 行减少约 69%，已达到 `< 1500` 第一阶段目标。

验收：

- [x] `flutter analyze` 通过。
- [x] 设置相关 widget test 通过。
- [ ] Android 真机设置页完整 smoke 通过。
- [x] 不改 `ReaderSettings.toJson/fromJson` 和本地保存 payload。

---

## 4. Phase B 详细任务：低风险 part 解耦

前置条件：

- [ ] Phase A 完成并通过 Android 真机 smoke。
- [x] 设置页主文件已降到 `< 1500` 行。

任务：

- [x] 重新扫描所有 `part of 'reader_page.dart'` 文件，标记纯展示、轻状态、重状态。
- [x] 已评估 `reader_chrome_surface.dart`：当前是 overlay/runtime 状态协调，不是纯展示，暂缓强行移出 part。
- [x] 已处理 `reader_content_mode_surface.dart`：11 行 getter 已内联到 `_ReaderPageState`，删除 part。
- [x] 已评估 `reader_page_background.dart`：仍依赖背景资源缓存、图片压缩、偏好存储和 `_ReaderPageState` 访问器，本轮不强拆。
- [x] 暂缓 `reader_page_runtime.dart`、`reader_page_content_loading.dart`、`reader_page_selection.dart`。
- [x] 额外低风险处理：`reader_page_widget.dart` 路由入口已内联到 `reader_page.dart`，删除 part。
- [x] 额外低风险处理：`reader_page_settings_panel.dart` 已拆成独立 `reader_floating_settings_sheet.dart` helper，并删除 part。
- [x] 额外低风险处理：`reader_page_support_models.dart` 已从 `part of` 改为普通 import 文件，页面内部状态 DTO 统一改为 `ReaderPage...` 前缀，避免和已有 controller/presenter DTO 撞名。

验收：

- [x] part 数量减少 2-4 个即可，不追求一次性到 15。
- [ ] 阅读页进入、背景、顶部/底部 chrome、内容模式切换无回归。
- [x] 不改翻页、章节定位、进度保存。

---

## 5. Phase C 详细任务：reader_page 长期瘦身

前置条件：

- [ ] Phase A 完成。
- [ ] Phase B 至少完成 1 个低风险 part 解耦，验证方案可行。

候选任务：

- [x] 提取手势输入边界，但先做 resolver/controller，不直接拆所有手势 widget。
- [x] 提取书签/标注入口协调器，避免和选择状态互相牵连。
- [x] 提取错误展示 presenter，保留错误恢复行为在原流程。
- [x] 建立每次迁移的自动化验证清单；真机 smoke 仍单独保留未勾选。

暂缓项：

- [ ] 暂缓迁移 `_ReaderPageState` 核心字段。
- [ ] 暂缓大规模 Riverpod 化。
- [ ] 暂缓改阅读进度、章节定位、分页计算 payload。

---

## 6. 推荐排期

### Week 1：只做 Phase A

- [ ] Day 1：A0 + A1 字体/排版。
- [ ] Day 2：A2 布局/信息栏。
- [ ] Day 3：A3 翻页/交互 + A4 自动阅读/音频/漫画第一部分。
- [ ] Day 4：A4 收尾 + A5 主题/背景第一步。
- [ ] Day 5：A5 第二步 + A6 收口 + 测试和真机 smoke。

### Week 2：看 Phase A 结果再决定

- [ ] 如果 Phase A 稳定，执行 Phase B 低风险 part 解耦。
- [ ] 如果 Phase A 遗留 bug 较多，先修设置页，不进入 Phase B。
- [ ] Phase C 仅作为后续长期治理，不纳入当前发版必做。

---

## 7. 量化目标

| 阶段 | 当前 | 阶段目标 | 理想目标 | 风险 |
|---|---:|---:|---:|---|
| 设置页主文件 | 4181 行 | `< 1500` 行 | `< 1200` 行 | 低 |
| section/components | 约 492 行 | `> 2500` 行 | `> 3000` 行 | 低 |
| part 数量 | 约 19 个 | 减少 2-4 个 | 约 15 个 | 中 |
| reader_page.dart | 5876 行 | 暂不强求 | `< 5200` 行 | 中高 |

说明：

- [ ] 不建议把 `settings_sheet < 800` 作为当前阶段硬目标，容易为了行数把复杂资源逻辑拆散。
- [ ] 更合理的第一目标是 `< 1500`，稳定后再二次收口到 `< 1000`。
- [ ] 行数只是辅助指标，核心验收仍是设置保存、阅读行为和 Android 真机 smoke。

---

## 8. 每阶段必须验证

- [ ] `dart format` 相关 Dart 文件。
- [ ] `flutter analyze`。
- [ ] 设置 section widget test。
- [ ] 阅读器核心 smoke：进入阅读器、打开设置、修改并应用、取消、翻页、上下章。
- [ ] Android 真机重点：底部安全区、纸页/仿真动画、设置弹层滚动和应用按钮。
- [ ] iOS/桌面按影响面补测：设置弹层、分页/滚动切换、窗口尺寸变化。

---

## 9. 不做清单

- [ ] 不在 Phase A 修改 `ReaderSettings` 存储结构。
- [ ] 不在 Phase A 修改翻页动画算法。
- [ ] 不在 Phase A 修改章节定位、阅读进度、书签、书源切换。
- [ ] 不为减少行数把会员/资源/背景存储逻辑塞进 widget。
- [ ] 不一次性移除所有 part。
- [ ] 不把 Phase C 作为当前发版阻塞项。

---

## 10. A0-A3 执行记录

- [x] A0-A3 已完成代码拆分：新增字体/排版、布局/信息栏、翻页/交互三个独立 section 文件。
- [x] `reader_page_settings_sheet.dart` 从 4181 行降到约 2944 行，A4-A6 继续拆分后再冲 `< 1500`。
- [x] 已运行 `dart format`，无额外格式化变更。
- [x] 已运行 `flutter analyze`，无新增问题；仅保留 `device_info_plus` Swift Package Manager 未来兼容提醒。
- [x] 已运行 `flutter test test/features/reader/presentation/reader_settings_sections_test.dart`。
- [x] 已补跑邻近阅读器测试：`reader_chrome_widgets_test.dart`、`reader_paged_viewport_support_test.dart`、`paged_animation_renderer_test.dart`。
- [x] 已运行 `git diff --check`，无空白问题。
- [ ] Android 真机设置页 smoke 未在本轮执行，后续真机统一补测。

---

## 11. A4-A6 执行记录

- [x] A4 已完成代码拆分：新增自动阅读、听书、漫画三个独立 settings panel。
- [x] A5 已完成代码拆分：新增主题/背景 settings panel，并抽出背景色点、背景图 tile 和对应轻量输入模型。
- [x] A6 已删除旧的自动阅读/听书/漫画/主题背景重复 builder，以及旧背景 tile/color 私有绘制 helper。
- [x] 自定义背景选择、删除、预加载、字体服务导入等副作用仍保留在外层，未塞入 section widget。
- [x] 已继续抽出字体选择弹窗、字重弹窗、点击分区编辑器：新增 `reader_font_picker_sheet.dart`、`reader_font_weight_sheet.dart`、`reader_tap_zone_editor_sheet.dart`。
- [x] `reader_page_settings_sheet.dart` 当前约 1281 行，已达到 `< 1500` 第一阶段目标。
- [x] 已运行 `dart format`。
- [x] 已运行 `flutter analyze`。
- [x] 已运行 `flutter test test/features/reader/presentation/reader_settings_sections_test.dart`。
- [ ] Android 真机设置页 smoke 未在本轮执行。

---

## 12. Phase B 执行记录

- [x] part 数从 19 个降到 15 个。
- [x] 删除 `reader_content_mode_surface.dart`：将 `_currentContentModeSurfaceModel` getter 内联到 `_ReaderPageState`。
- [x] 删除 `reader_page_settings_panel.dart`：将浮层 frame 抽成 `reader_floating_settings_sheet.dart`，将背景色选项列表收回 settings sheet。
- [x] 删除 `reader_page_widget.dart`：将 `ReaderPage` 路由入口内联到 `reader_page.dart`。
- [x] 独立 `reader_page_support_models.dart`：移除 `part of 'reader_page.dart'`，补齐自身 import，并将页面私有模型重命名为 `ReaderPage...`/`Reader...` 内部公开类型。
- [x] 明确连续阅读页面 DTO 与 `ReaderContentLoadingController`/`ReaderContentLoadingPresenter` DTO 的转换边界，避免独立 import 后发生 ambiguous import。
- [x] 已评估 `reader_chrome_surface.dart`：它是 overlay 自动隐藏、系统 UI、音量键拦截等运行态协调，暂不作为低风险 part 解耦对象。
- [x] 已评估 `reader_page_background.dart`：它同时承载背景缓存、压缩、持久化和服务调用，本轮不强拆。
- [x] 已运行 `dart format`。
- [x] 已运行 `flutter analyze`。
- [x] 已运行 reader 相关测试：`reader_settings_sections_test.dart`、`reader_chrome_widgets_test.dart`、`reader_paged_viewport_support_test.dart`、`paged_animation_renderer_test.dart`。
- [x] 已运行 `git diff --check`。
- [ ] 阅读页进入、背景、顶部/底部 chrome、内容模式切换真机 smoke 未在本轮执行。

---

## 13. Phase C 执行记录

- [x] 抽出 `reader_pointer_input_controller.dart`：接管阅读页 pointer id、down/up 时间、长按 timer、child handled 标记和 swipe snapshot。
- [x] `reader_page.dart` 不再直接保存 `_tapPointer...`、`_swipeDrag...`、`_readerLongPressTimer` 等临时手势字段；翻页、纸页预览、pull refresh 和长按副作用仍保留在原流程。
- [x] 抽出 `reader_bookmark_range_presenter.dart`：接管书签当前章节判断、段落范围切分、高亮 token 判断和 selection bookmark 查找。
- [x] 抽出 `reader_error_presenter.dart`：接管网关错误 presentation、WebView 任务 stage 解析、本地图书/在线书源错误文案。
- [x] 新增测试：`reader_pointer_input_controller_test.dart`、`reader_bookmark_range_presenter_test.dart`、`reader_error_presenter_test.dart`。
- [x] 已运行 `dart format`。
- [x] 已运行 `flutter analyze`。
- [x] 已运行 C 阶段新增测试，并补跑 reader 邻近测试：`reader_settings_sections_test.dart`、`reader_chrome_widgets_test.dart`、`reader_paged_viewport_support_test.dart`、`paged_animation_renderer_test.dart`。
- [ ] 阅读器核心真机 smoke 未在本轮执行：上下章、目录、翻页、设置、书源切换、长按菜单、书签/标注。
