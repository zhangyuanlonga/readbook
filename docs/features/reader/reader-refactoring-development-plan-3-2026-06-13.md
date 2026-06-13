# 阅读器重构开发计划三：阶段1收口与全局审计校准

**日期**: 2026-06-13  
**范围**: 阅读器阶段1收口、`docs/project-comprehensive-assessment-2026-06-13.md` 合理性校准  
**当前基线**: `reader_page.dart` 5692 行、`reader_page_settings_sheet.dart` 1335 行、`reader_page.dart` 直属 part 15 个  
**目标**: 不改阅读进度、章节定位、翻页算法和设置持久化 payload 的前提下，把阶段1从“可用拆分”推进到“可维护收口”。

---

## 1. 对综合评估文档的判断

### 1.1 合理部分

- [x] `Reader` 仍应作为当前 P0 收口对象，尤其是设置页、输入层、书签/标注、part 耦合。
- [x] `Mine` 是下一阶段高风险模块，私有书源、高级主题、会员/外观路径都和近期 bug 高相关。
- [x] `Bookshelf` 的 God Class 风险真实存在，且用户访问频率高，排在 Mine 之后或并行做局部治理是合理的。
- [x] 建立设计系统方向正确，当前 app-level widgets 和 feature widgets 的边界确实不够稳定。
- [x] Hero 动画、响应式、加载态、空态、错误态这些 UI/UX 方向值得做，但应排在核心稳定性之后。

### 1.2 需要修正的部分

- [x] 文档里的 Reader 数据是旧快照：`reader_page.dart` 已从 5876 行变为 5692 行，`settings_sheet` 当前为 1335 行，reader page part 当前为 15 个。
- [x] “阅读器重构完成度 30%”已不准确；按当前设置页、C 阶段 controller/presenter、part 解耦进度，更合理是阶段1完成约 60%-70%，剩余主要是收口和真机 smoke。
- [x] “共享组件占比 >60%”不适合作为硬指标。Feature 内部组件合理存在，硬追共享比例会制造低内聚的大组件。
- [x] “Hero 50+处”不适合作为目标。更合理是覆盖 3-5 条关键路径：书架到详情、详情到阅读器、搜索到详情、封面预览、主题/图集预览。
- [x] “设计系统 2 周减少重复 60%+”偏乐观。建议先做 tokens、button/input/sheet/empty/error/loading 这些基础件，再渐进迁移。
- [x] “统一纯 Dart，移除原生桥接”不合理。Flutter 跨端仍需要平台桥接，正确目标应是隔离原生桥接、收口平台能力 facade，而不是移除。

### 1.3 结论

- [x] 综合评估文档可以作为全局治理方向参考。
- [x] 发版前不建议扩大到 Mine/Bookshelf 大重构，先完成 Reader 阶段1收口与真机验证。
- [x] Reader 稳定后，下一阶段优先级建议是：Mine 私有书源/高级主题稳定性治理 > Bookshelf God Class 拆分 > 设计系统基础件。

---

## 2. Phase P3-A：设置页继续优化

**目标**: `reader_page_settings_sheet.dart` 从 1335 行降到 `< 1000` 行。  
**风险**: 低到中。主要是 UI 组合和 sheet 内部状态迁移，但仍涉及背景、字体导入、实时预览和持久化节流。

### A0：基线和保护线

- [ ] 记录当前 `reader_page_settings_sheet.dart` 行数、主要闭包、重复 panel 调用点。
- [ ] 不改 `ReaderSettings.toJson/fromJson`。
- [ ] 不改 `_persistResolvedReaderSettingsLayers` 的入参语义。
- [ ] 不改实时预览策略：slider 拖动时延迟持久化、非拖动时即时预览。
- [ ] 不改字体导入、背景选择、背景删除的用户可见行为。

### A1：抽出设置页会话控制器

- [ ] 新建 `reader_settings_sheet_session.dart` 或同级 helper。
- [ ] 抽出 fingerprint、`persistDraftNow`、`schedulePersistDraft`、slider interaction 状态控制。
- [ ] 保留真正的持久化调用由外层注入，helper 不直接读写 repository/service。
- [ ] 补测试覆盖：相同 fingerprint 不重复持久化、slider 拖动节流、dispose/cancel timer。

预期收益：`settings_sheet` -120 到 -180 行。

### A2：抽出背景资源面板输入构建

- [ ] 新建 `reader_settings_background_tiles_presenter.dart`。
- [ ] 抽出 preset/custom background tile data 构建。
- [ ] 抽出 `hasBackgroundImage`、`isPresetBackground`、active/custom 判断。
- [ ] 保留选图、存储、删除文件副作用在外层，只让 presenter 产出 tile data。
- [ ] 补测试覆盖：preset 选中、自定义选中、preview 缺失 fallback。

预期收益：`settings_sheet` -120 到 -180 行。

### A3：消除布局/信息栏 panel 重复调用

- [ ] 把 `quick_margins`、`info_layout`、`info` 三处重复 `ReaderLayoutInfoSettingsPanel` 参数收口成一个 builder/helper。
- [ ] 抽出 `ReaderLayoutInfoPanelCallbacks` 或局部私有 helper，避免复制 slider/value formatter 参数。
- [ ] 保持 `ReaderLayoutInfoSettingsPanel` 本身不改行为。

预期收益：`settings_sheet` -80 到 -130 行。

### A4：抽出 sheet 壳层

- [ ] 新建 `reader_settings_sheet_frame.dart` 或复用现有 floating helper。
- [ ] 抽出 drag handle、标题栏、返回按钮、ListView padding、heightFactor 组合。
- [ ] 外层只传 `title`、`canBack`、`onBack`、`children`、`heightFactor`。
- [ ] 补 widget smoke test，确认返回按钮和标题渲染。

预期收益：`settings_sheet` -120 到 -180 行。

### A5：验收

- [ ] `reader_page_settings_sheet.dart < 1000` 行。
- [ ] `flutter analyze`。
- [ ] 设置页相关 widget/session/presenter tests。
- [ ] Android 真机 smoke：打开设置、切换分组、拖动 slider、字体弹窗、背景选择/删除、应用/关闭。

---

## 3. Phase P3-B：reader_page 继续瘦身

**目标**: `reader_page.dart` 从 5692 行降到约 `5200` 行。  
**风险**: 中。已经完成 pointer tracking、bookmark range、error presenter；下一步不再碰翻页算法，只继续抽“决策和展示映射”。

### B0：确认已完成边界

- [x] `ReaderPointerInputController` 已接管 pointer/长按/swipe 临时状态。
- [x] `ReaderBookmarkRangePresenter` 已接管书签范围和高亮映射。
- [x] `ReaderErrorPresenter` 已接管错误展示和网关恢复 stage。
- [ ] 真机验证长按、点击分区、书签/标注、错误恢复入口。

### B1：提取触摸导航决策边界

- [ ] 新建 `reader_touch_navigation_controller.dart`。
- [ ] 把 `_onReaderTap` 前半段判断改成 controller 返回 `ReaderTouchNavigationIntent`。
- [ ] 保留实际副作用在 `_ReaderPageState`：翻页、打开目录、打开自动阅读、切主题。
- [ ] 覆盖测试：选区中忽略、冷却中忽略、自动阅读中打开控制、overlay 可见时隐藏、tap zone 命中。

预期收益：`reader_page.dart`/part -80 到 -130 行，逻辑边界更清楚。

### B2：提取桌面输入派发边界

- [ ] 复用现有 `ReaderDesktopInputResolver`，新增 dispatcher/presenter 只负责 action 到 intent 的转换。
- [ ] 将 `reader_desktop_input_layer.dart` 从 part 移出或删除，保留 reader_page 中极薄副作用执行入口。
- [ ] 覆盖测试：键盘翻页、overlay 切换、自动阅读暂停、滚轮节流。

预期收益：part -1，`reader_page` 净减少较小，但耦合下降。

### B3：提取标注工具栏 presenter

- [ ] 新建 `reader_selection_toolbar_presenter.dart`。
- [ ] 抽出灵感/笔记/高亮/加粗/下划线/波浪线 actions 的构建规则。
- [ ] 保留 repository 写入、overlay entry、note editor 在原流程。
- [ ] 覆盖测试：已有 bookmark 时显示删除、无 bookmark 时显示保存、样式 active 状态正确。

预期收益：selection part -150 到 -220 行，reader_page 间接瘦身。

### B4：提取 reader 顶部/底部 action 数据 presenter

- [ ] 只抽按钮展示数据和 enabled/label/icon 决策，不抽 overlay 动画和系统 UI。
- [ ] 暂不移动 `reader_chrome_surface.dart`，除非 presenter 抽完后它变成纯展示。
- [ ] 覆盖测试：书签按钮、缓存按钮、自动阅读按钮、章节进度文案。

预期收益：`reader_page.dart` -150 到 -250 行。

### B5：验收

- [ ] `reader_page.dart <= 5200` 行，或说明未达成原因。
- [ ] `flutter analyze`。
- [ ] 新增 presenter/controller tests。
- [ ] 阅读器 smoke：点击分区、左右翻页、上下章、目录、自动阅读、长按、标注、错误重试。

---

## 4. Phase P3-C：part 文件继续解耦

**当前**: reader_page 直属 part 15 个。  
**目标**: 优先到 13 个，理想到 12 个。  
**原则**: 不为了数量强拆 runtime/content_loading/source_switch 这种高状态 part。

### C1：安全候选

- [ ] `reader_desktop_input_layer.dart`：72 行，优先移出 part 或合并为独立 dispatcher。
- [ ] `reader_touch_navigation_layer.dart`：152 行，在 B1 controller 完成后再移出 part。
- [ ] `reader_page_viewport.dart`：490 行，只有在 viewport 输入模型收口后才考虑独立 widget/helper。

### C2：暂缓候选

- [ ] `reader_page_runtime.dart`：1910 行，状态核心，暂缓。
- [ ] `reader_page_content_loading.dart`：1327 行，章节加载核心，暂缓。
- [ ] `reader_page_source_switch.dart`：1024 行，换源流程复杂，暂缓。
- [ ] `reader_page_selection.dart`：1064 行，先抽 toolbar presenter，不直接移出 part。
- [ ] `reader_page_background.dart`：516 行，涉及缓存、压缩、偏好存储，暂缓。
- [ ] `reader_chrome_surface.dart`：185 行，仍是 overlay/runtime 协调，暂缓。

### C3：验收

- [ ] part 数量到 13 个。
- [ ] 若要到 12 个，必须先证明第三个候选不碰核心状态。
- [ ] `flutter analyze`。
- [ ] 相关 controller/widget tests。
- [ ] 真机验证顶部/底部 chrome、触摸/桌面输入、内容模式切换。

---

## 5. Phase P3-D：综合评估文档后续处理

- [ ] 刷新 `docs/project-comprehensive-assessment-2026-06-13.md` 中 Reader 行数、part 数、阶段完成度。
- [ ] 把“统一纯 Dart”改为“平台桥接 facade 化/隔离化”。
- [ ] 把“共享组件占比 >60%”改为“重复 UI 模式清单 + 基础组件覆盖率”。
- [ ] 把“Hero 50+处”改为“关键路径 Hero 覆盖”。
- [ ] 把设计系统拆成 `DS-0 tokens`、`DS-1 基础组件`、`DS-2 业务迁移` 三阶段。
- [ ] Reader 阶段1真机 smoke 通过后，再启动 Mine/Bookshelf 的独立计划。

---

## 6. 推荐执行顺序

1. [ ] P3-A1 到 P3-A4：先把 settings sheet 压到 `<1000`。
2. [ ] P3-B1 到 P3-B3：继续抽触摸导航、桌面输入、标注 toolbar。
3. [ ] P3-C1：完成 2 个安全 part 解耦，视风险冲 12 个。
4. [ ] P3-D：刷新综合评估文档，避免旧数字误导后续排期。
5. [ ] Android 真机完整 smoke，再决定是否进入 Mine/Bookshelf。

---

## 7. 不做清单

- [ ] 不改阅读进度、章节定位、分页计算 payload。
- [ ] 不改纸页/仿真/覆盖/滑动动画算法。
- [ ] 不改 `ReaderSettings` 存储结构。
- [ ] 不把 service/repository 副作用塞进 widget/presenter。
- [ ] 不为了 part 数量强拆 runtime/content_loading。
- [ ] 不把综合评估里的长期 UI/UX 指标作为当前发版阻塞项。
