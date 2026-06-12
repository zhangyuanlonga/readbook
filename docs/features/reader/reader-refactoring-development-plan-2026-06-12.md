# 阅读器重构开发计划

**日期**: 2026-06-12  
**范围**: `lib/features/reader/`、`lib/domain/entities/reader_settings.dart`  
**来源文档**:

- [架构评审报告](./architecture-review-2026-06-12.md)
- [设计合理性分析](./design-analysis-2026-06-12.md)
- [UX/动画/组件化深度分析](./ux-animation-adaptiveness-analysis-2026-06-12.md)
- [重构统计报告](./refactoring-statistics-2026-06-12.md)

---

## 1. 总结结论

这几份审查文档指出的问题大体成立：阅读器功能已经比较完整，但维护入口过大，尤其是 `reader_page.dart`、`reader_page_settings_sheet.dart`、`ReaderSettings` 和翻页/视口相关逻辑。后续如果继续直接在这些大文件里修 bug，会让 Android 翻页、设置弹层、章节切换、书源切换这些敏感链路越来越难稳定。

但不建议照审查文档里的“全量 Clean Architecture 迁移、全量 Riverpod、一次性移除所有 part、一次性拆 ReaderSettings 存储结构”去做。这个方案风险过大，容易把刚稳定的阅读器重新打散。

**执行策略**: 先冻结行为，再拆低风险 UI 和边界，最后才碰状态、设置存储结构和 domain/data 迁移。

---

## 2. 采纳与暂缓

### 2.1 立即采纳

- 拆 `reader_page_settings_sheet.dart`。设置页 4430 行，改动频率高，拆分收益最大。
- 为阅读器建立最小手工验收清单。先保护纸页、仿真、滚动、上下章、目录、设置弹层。
- 收敛 `presentation/` 目录。新增代码进入 `widgets/`、`sheets/`、`paged_animation/` 等清晰目录。
- 翻页/视口边界单独治理。Android 纸页闪字问题说明这里必须有明确边界和回归路径。
- 盘点现有设置能力。代码里已经有 `ReaderSettingsPresetService`、`ReaderSettingsGroups`、`ReaderSettingsEntryController`，不能按“从零做配置方案”理解。

### 2.2 谨慎采纳

- `ReaderSettings` 分组。先做读取视图/分组 facade，不急着改持久化字段和数据库/本地存储格式。
- `ReaderView` 统一接口。可以先统一输入模型，不强行让所有 View 继承同一个抽象基类。
- Material 动画。只补设置弹层、主题切换、菜单显隐这类低风险过渡；不碰翻页动画核心算法。
- 换源逻辑整合。可以做服务边界收口，但必须保持当前章节定位和阅读进度迁移行为不变。

### 2.3 暂缓执行

- 暂缓全量迁移 `lib/domain/entities/reader_*` 到 `features/reader/domain/`。
- 暂缓一刀切把所有 `StatefulWidget` 改成 Riverpod。
- 暂缓一次性移除全部 `part/part of`。
- 暂缓大规模重命名 resolver/coordinator/facade/presenter。
- 暂缓把阅读器完全照搬 Android 原生阅读3 MD3 的 Activity/ViewModel/Dialog 结构。

---

## 3. 当前风险基线

| 风险点 | 当前状态 | 处理策略 |
|---|---:|---|
| 主阅读页过大 | `reader_page.dart` 6245 行 | 先拆纯展示层，保留核心状态 |
| 设置页过大 | `reader_page_settings_sheet.dart` 4430 行 | 第一阶段优先拆 |
| part 耦合 | 主页面相关 part 约 18 个 | 分阶段替换，不一次性清零 |
| 设置对象过大 | `ReaderSettings` 约 111 个属性 | 先分组读取，后续再改存储 |
| 翻页敏感 | Android 纸页/仿真近期多次修复 | 单独阶段治理和真机回归 |
| Presentation 测试弱 | 大型 UI 文件缺测试 | 先补 smoke，再补关键 widget test |
| 文档评分过激 | UX 文档评分和对标方式偏重 | 作为灵感，不作为排期依据 |

---

## 4. 执行原则

- 每个阶段只改一个边界，不顺手重构无关链路。
- 第一轮目标是“行为不变，文件变小，边界清楚”，不是追求架构评分。
- Android 真机是阅读器重构的必测平台；iOS、macOS、Windows、Linux 按影响面补测。
- 动画、手势、滚动控制器这类局部 UI 状态可以继续留在 `StatefulWidget`。
- 跨组件共享状态、业务状态、加载状态才逐步迁到 controller/provider。
- 涉及设置持久化、阅读进度、书签、章节定位、书源切换时，必须先确认兼容策略。

---

## 5. 阶段任务清单

### 阶段 0：冻结行为与验收基线（0.5-1 天）

- [x] 梳理阅读器手工 smoke 清单：本地书进入、在线书进入、上一章、下一章、目录跳转、纸页、仿真、滚动、设置弹层、书源切换。
- [x] 记录 Android 真机重点验收项：纸页不闪字、仿真不误切、快速连续翻页不串页、上下章边界可点击。
- [x] 记录 iOS/桌面影响面：菜单、键鼠翻页、窗口尺寸变化、滚动/分页切换。
- [x] 为 `reader_page.dart` 的 part 文件做职责表，标记“可先拆纯 UI”“暂不碰状态”“暂不碰业务”。
- [x] 明确阶段提交规则：每阶段独立提交，提交说明写清验证平台。

**验收**:

- [x] 手工 smoke 清单写入文档或任务备注。
- [x] 当前阅读器行为有可对照记录。

### 阶段 1：设置页 UI 拆分（1-2 天）

- [x] 新建 `lib/features/reader/presentation/sheets/reader_settings/`。
- [ ] 将设置页拆成 section widget：字体、主题/背景、布局、翻页、自动阅读、音频、漫画/图片、高级。
- [x] 抽出通用设置项组件：标题、卡片、开关行、分隔线、标签行、分组入口。
- [x] 保持 `ReaderSettings`、`ReaderPreferencesService`、设置保存逻辑不变。
- [x] 复用现有 `ReaderSettingsGroups` 和 `ReaderSettingsPresenter`，避免重复写展示映射。
- [ ] 清理设置页底部安全区，确认不会被底部导航栏/手势区遮挡。

**验收**:

- [ ] Android 真机打开/关闭设置弹层正常。
- [ ] 字体、背景、翻页动画、纸页设置、底部安全区表现不变。
- [ ] `flutter analyze` 不新增错误。

### 阶段 2：主阅读页纯展示层拆分（2-3 天）

- [x] 从 `reader_page.dart` 和 part 文件中优先拆无副作用支持模型/小组件，已新增 `reader_page_support_models.dart`。
- [ ] 将 chrome/overlay 相关 widget 收到 `presentation/widgets/chrome/` 和 `presentation/widgets/overlay/`。
- [x] 保留 `_ReaderPageState` 的核心字段和导航方法，暂不迁 Riverpod。
- [x] 新拆组件/模型仍在同一 library 边界内，未新增主状态读取路径。
- [x] 禁止在此阶段改翻页算法、章节定位、书源切换逻辑。

**验收**:

- [ ] Android 真机纸页、仿真、点击翻页、上下章节点、菜单显隐行为不变。
- [ ] iOS 模拟器或真机确认阅读页进入、菜单、翻页无明显回归。

### 阶段 3：翻页与视口边界收口（2-4 天）

- [ ] 统一分页动画入口，明确 `paged_animation/` 下各 renderer 的职责。
- [x] 为视口创建稳定输入模型，例如 chapter id、page index、page count、animation style、viewport metrics。
- [ ] `reader_paper_curl_paged_view.dart` 只保留组件内部动画/快照状态，不直接耦合业务状态。
- [x] 给纸页、仿真、cover、translate、vertical、none 建立最小回归清单和 transition resolver 单测入口。
- [ ] 复查 Android 上的纸页闪字、仿真误切、动画结束后一帧串页问题。

**验收**:

- [ ] Android 真机连续翻页 30 次无闪字/串页。
- [ ] 章节末尾下一章、章节开头上一章行为正常。
- [ ] 切换翻页动画后不需要重进阅读器。

### 阶段 4：设置方案与配置体验收口（2-4 天）

- [x] 盘点现有 `ReaderSettingsPresetService`，确认已有 preset 能力仍在 application 层，未在本轮强行改 UI。
- [x] 盘点 `ReaderSettingsGroups` 的覆盖范围，补齐翻页、音频、漫画、自动阅读等分组视图。
- [ ] 如果要做多套阅读配置，先做“当前配置另存/应用/删除”的产品闭环，不先改 `ReaderSettings` 存储结构。
- [x] 明确默认、高级主题、文字/漫画配置之间的关系先保持现状，不在重构中改变覆盖规则。
- [x] 暂不做复杂导入/导出，除非已有明确发版需求。

**验收**:

- [ ] 现有设置保存和恢复不变。
- [ ] 配置 preset 操作不会影响书籍阅读进度、书签、章节定位。
- [ ] 会员到期或高级主题失效时，默认主题/阅读设置降级路径清晰。

### 阶段 5：换源与内容 View 边界整理（3-5 天）

- [x] 梳理换源相关文件：coordinator、shared、position resolver、source switch controller。
- [ ] 抽出统一的换源服务边界，输入当前书、当前章节/位置、目标源，输出章节匹配结果和进度迁移结果。
- [x] 保留当前章节匹配策略，不在重构阶段顺手改匹配算法。
- [x] 为换源请求建立 `ReaderSwitchSourceRequestContext`，减少页面散参，后续再继续收口应用服务。
- [x] 只在新代码里使用清晰命名；旧 resolver/coordinator 不单独大规模改名。

**验收**:

- [ ] 在线书源换源后章节位置可恢复。
- [ ] 本地书不受换源服务影响。
- [ ] 文本、漫画、音频、PDF 入口可正常打开。

### 阶段 6：状态边界渐进迁移（后续迭代，3-5 天/批）

- [x] 先为跨组件共享状态建立边界模型：设置面板显隐、目录显隐、内容加载、书源切换状态、错误恢复状态。
- [x] 保留动画控制器、滚动控制器、手势临时状态在局部 widget 内。
- [x] 新增状态对象使用不可变模型，避免多个组件直接改同一份可变字段。
- [x] 每迁移一类状态，补一组单元测试或 widget smoke。

**验收**:

- [ ] 热重载、进入退出阅读器、后台恢复阅读位置正常。
- [ ] 状态迁移后 Android 真机关键路径无回归。

### 阶段 7：ReaderSettings 结构化与 domain/data 边界（长期治理）

- [x] 先为 `ReaderSettings` 增加分组访问层，不改变旧序列化字段。
- [x] 评估旧配置兼容：历史本地配置、云端配置、高级主题覆盖、默认值回退，本轮仅新增读取/合并 facade。
- [x] 如果要拆存储结构，必须提供旧格式读取、新格式写入、失败回滚策略；本轮不拆存储结构。
- [x] 新增 reader 数据能力优先放到 reader feature 内的接口，不再扩大 `lib/domain/entities/`。
- [x] 迁移 domain/data 前先盘点跨 feature 引用，分批改 import，不改 payload 和数据库结构。

**验收**:

- [x] 老用户设置可无损读取。
- [ ] 删除/切换主题后阅读设置不丢失。
- [x] 不产生数据库或本地存储不兼容。

---

## 6. 推荐执行顺序

当前建议先执行：

1. [ ] 阶段 0：冻结行为与验收基线。
2. [ ] 阶段 1：设置页 UI 拆分。
3. [ ] 阶段 2：主阅读页纯展示层拆分。
4. [ ] 阶段 3：翻页与视口边界收口。

阶段 4-7 放到后续迭代。它们有价值，但涉及设置体验、状态迁移、数据兼容，不能和当前发版修复混在一起。

---

## 6.1 阶段 0 基线记录

### 手工 smoke 清单（待每阶段实测）

- [x] 本地书进入阅读器：不触发在线详情/章节请求，阅读进度可恢复。
- [x] 在线书进入阅读器：章节内容、缓存命中、错误提示链路保持现状。
- [x] 上一章/下一章：章节边界节点可点击，跨章后页码和阅读进度正确。
- [x] 目录跳转：目录打开、搜索、点击章节、回到正文不丢状态。
- [x] 纸页动画：Android 真机不闪上一页/下一页文字，不退化成仿真动画。
- [x] 仿真动画：拖拽、点击、快速连续翻页不误切。
- [x] 滚动模式：滚动位置、章节边界加载、菜单呼出不回跳。
- [x] 设置弹层：打开/关闭、修改字体/背景/翻页方式、底部安全区不遮挡。
- [x] 书源切换：入口、候选列表、切换后章节定位和错误提示保持现状。

### Android 真机重点（待每阶段实测）

- [x] 纸页翻页结束后一帧不串页、不闪字。
- [x] 纸页和仿真样式切换后不互相串动画。
- [x] 快速连续翻页 30 次不出现上一页/下一页残影。
- [x] 章节开头上一章、章节末尾下一章节点可点击。
- [x] 底部设置弹层、会员弹层、书籍更多弹层不被导航栏/手势区遮挡。

### iOS/桌面影响面（待每阶段实测）

- [x] iOS：分页、菜单、设置弹层、章节跳转按影响面回归。
- [x] macOS/Windows/Linux：键鼠翻页、窗口尺寸变化、滚动/分页切换按影响面回归。
- [x] 桌面侧不把移动端底部安全区修复反向带成过大留白。

### `reader_page.dart` part 职责表

| 文件 | 当前职责 | 阶段策略 |
|---|---|---|
| `reader_page_widget.dart` | `ReaderPage` widget 入口 | 可先拆纯 UI，暂不改构造参数 |
| `reader_page_content_loading.dart` | 内容加载、错误恢复 | 暂不碰业务，后续按加载状态边界拆 |
| `reader_page_selection.dart` | 文本选择、标注交互 | 暂不碰状态，避免影响选择手势 |
| `reader_page_background.dart` | 阅读背景、背景资源解析 | 可先拆纯展示，暂不改资源解析 |
| `reader_page_bootstrap.dart` | 初始化、依赖绑定、入口恢复 | 暂不碰业务 |
| `reader_page_content_rendering.dart` | 内容渲染分发 | 阶段 2 可拆展示，阶段 3 再碰视口边界 |
| `reader_page_lifecycle.dart` | 生命周期、依赖释放 | 暂不碰 |
| `reader_page_navigation.dart` | 上下章、返回、跳转 | 暂不碰业务 |
| `reader_page_runtime.dart` | 运行时状态、控制器协调 | 暂不碰状态迁移 |
| `reader_desktop_input_layer.dart` | 桌面键鼠输入 | 可单独回归后小步整理 |
| `reader_touch_navigation_layer.dart` | 移动端触摸导航 | 暂不碰翻页手势 |
| `reader_chrome_surface.dart` | 顶/底工具栏展示 | 可先拆纯 UI |
| `reader_page_shell.dart` | 页面外壳、overlay 组合 | 可先拆纯 UI |
| `reader_page_settings_panel.dart` | 旧设置面板入口/组合 | 可跟阶段 1 合并整理 |
| `reader_page_settings_sheet.dart` | 设置底部弹层和分组 UI | 阶段 1 优先拆 |
| `reader_page_source_switch.dart` | 换源 UI 和流程 | 阶段 5 再处理 |
| `reader_page_viewport.dart` | 视口构建、阅读模式分发 | 阶段 3 前不改核心输入 |
| `reader_content_mode_surface.dart` | 文本/漫画/音频/PDF surface | 阶段 5 再统一输入模型 |

### 阶段提交规则

- [x] 每个阶段独立提交；如果阶段过大，按“纯 UI / 状态边界 / 数据边界”拆提交。
- [x] 提交说明必须写清验证平台：Android 真机、iOS、桌面、未验证项。
- [x] 翻页、章节定位、设置持久化、书源切换相关提交必须附带手工 smoke 结果。

### 阶段 0-1 执行记录

- [x] 阶段 0 已补齐 smoke 清单、Android 真机重点、iOS/桌面影响面和 part 职责表。
- [x] 阶段 1 已建立 `presentation/sheets/reader_settings/` 目录。
- [x] 阶段 1 已抽出设置页通用组件：`ReaderSettingsSectionCard`、`ReaderSettingsGroupEntryCard`、`ReaderSettingsToggleRow`、`ReaderSettingsDivider`、`ReaderSettingsCompactTitle`、`ReaderSettingsCard`、`ReaderSettingsLabeledRow`。
- [x] 本次没有修改 `ReaderSettings`、`ReaderPreferencesService`、设置保存逻辑、翻页动画核心、章节导航、书源切换。

### 阶段 2-7 执行记录

- [x] 阶段 2 已新增 `reader_page_support_models.dart`，把主阅读页尾部支持模型和小组件移出 `reader_page.dart`。
- [x] 阶段 3 已新增 `ReaderPagedViewportInput`，用于描述分页视口稳定输入，并补充单测。
- [x] 阶段 4 已扩展 `ReaderSettingsGroups`，覆盖翻页、自动阅读、听书、漫画/图片分组，并补充拆分/合并单测。
- [x] 阶段 5 已新增 `ReaderSwitchSourceRequestContext`，为手动换源和自动换源门禁提供统一请求上下文，并补充 coordinator 单测。
- [x] 阶段 6 已新增 `ReaderSharedUiStateBoundary`，先用不可变快照承接设置面板、目录、加载、换源、错误恢复状态决策，并补充单测。
- [x] 阶段 7 已在 application 层新增 `ReaderSettingsGroupedAccess` 扩展，提供 `settings.grouped` 和 `settings.mergeGroups(...)`，不让 domain 反向依赖 feature。
- [x] 本轮没有修改 `ReaderSettings.toJson/fromJson` 字段、没有改本地/云端设置 payload、没有改翻页 renderer 算法、没有改章节匹配/定位算法。

---

## 7. 不做清单

- [ ] 不在当前阶段全量改 `ReaderSettings` 构造、序列化、持久化格式。
- [ ] 不为了目录整洁改阅读行为。
- [ ] 不在未补 smoke 的情况下迁移核心状态。
- [ ] 不把所有 `StatefulWidget` 机械改成 `ConsumerWidget`。
- [ ] 不把 Flutter 阅读器强行改成 Android 阅读3 MD3 的原生架构。
- [ ] 不把 Web 发版纳入 GitHub 原生客户端自动打包链路。

---

## 8. 验证命令与平台

基础命令：

```bash
flutter analyze
flutter test
dart run tool/check_model_codegen_guard.dart
dart run tool/check_route_string_guard.dart
```

平台验收：

- [ ] Android 真机：阅读器核心 smoke 必测。
- [ ] iOS：分页/菜单/设置弹层按影响面补测。
- [ ] macOS/Windows/Linux：桌面输入、窗口尺寸、滚动/分页切换按影响面补测。

---

## 9. 交付标准

每个阶段完成时必须记录：

- [ ] 本阶段改了哪些边界。
- [ ] 明确没有改哪些敏感链路。
- [ ] Android 真机验证结果。
- [ ] iOS/桌面是否验证，未验证需说明原因。
- [ ] 是否需要更新本计划的勾选状态。
