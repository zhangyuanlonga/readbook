# 历史硬编码与未统一组件改造阶段计划

日期: 2026-06-20
分支: `codex/color-system-phase6-7`
范围: 历史硬编码样式、未统一组件、页面状态、弹层、Reader/Bookshelf/Mine 外围 UI

## 1. 当前审计基线

本计划基于以下命令的当前全量结果:

```bash
dart run tool/check_theme_coverage_audit.dart --top=20
dart run tool/check_ui_component_governance.dart
```

### 1.1 Theme Coverage 基线

| 指标 | 当前数量 |
|---|---:|
| 高风险文件 | 4 |
| `local-alpha` | 572 |
| `border-radius` | 558 |
| `box-decoration` | 377 |
| `material-color` | 98 |
| `hardcoded-color` | 98 |
| `shape-property` | 75 |
| `rounded-shape` | 32 |
| `box-shadow` | 30 |

当前 4 个高风险文件:

- `lib/app/widgets/text_cover_placeholder.dart`
- `lib/features/mine/presentation/mine_page_view.dart`
- `lib/features/bookshelf/presentation/bookshelf_page.dart`
- `lib/features/reader/presentation/reader_page.dart`

### 1.2 UI Governance 基线

| 指标 | 当前数量 |
|---|---:|
| 总 findings | 1018 |
| `hardcoded-style` | 814 |
| `platform-branch` | 51 |
| `loading-state` | 48 |
| `list-children` | 46 |
| `scaffold` | 40 |
| `list-performance` | 8 |
| `capability-wrapper` | 5 |
| `layout-builder` | 5 |
| `modal-surface` | 1 |

## 2. 阶段 8-10 执行结果

本轮已执行 Phase 8、Phase 9、Phase 10，并复跑以下命令:

```bash
flutter analyze
flutter test test/app/widgets/foundation_components_test.dart
flutter test test/features/mine/presentation/component_demo_visual_matrix_test.dart
flutter test test/features/mine/application/official_theme_activation_test.dart
dart run tool/check_ui_component_governance.dart --strict-new
dart run tool/check_theme_coverage_audit.dart --strict-new --top=20
dart run tool/check_ui_component_governance.dart
dart run tool/check_theme_coverage_audit.dart --top=20
```

实际结果:

| 指标 | 基线 | 阶段 8-10 后 |
|---|---:|---:|
| Theme high risk | 4 | 2 |
| Theme `local-alpha` | 572 | 555 |
| Theme `border-radius` | 558 | 534 |
| Theme `box-decoration` | 377 | 364 |
| Theme `material-color` | 98 | 85 |
| Theme `hardcoded-color` | 98 | 62 |
| UI Governance findings | 1018 | 818 |
| UI Governance exempted | 0 | 87 |
| `modal-surface` | 1 | 0 |
| `capability-wrapper` | 5 | 0 |
| `loading-state` | 48 | 8 |
| `platform-branch` | 51 | 6 |
| `scaffold` | 40 | 6 |
| `list-children` | 46 | 14 |
| `list-performance` | 8 | 0 |
| `layout-builder` | 5 | 0 |
| `hardcoded-style` | 814 | 784 |

剩余高风险文件:

- `lib/features/bookshelf/presentation/bookshelf_page.dart`: 放入 Phase 11 Bookshelf 外围收敛。
- `lib/features/reader/presentation/reader_page.dart`: 放入 Phase 12/13 Reader 外围与核心边界收敛。

本轮确认:

- 启动图、底栏图集继续按高级主题绑定使用，不恢复独立配置入口。
- Lumina 仍是组件演示唯一基线。
- Reader/Bookshelf 主渲染、主数据流未做业务重构；仅替换外围 loading/haptics 或补结构豁免。
- `TextCoverPlaceholder` 已作为内容资产色板归档，不再作为 App surface 强制主题化对象。

## 3. 阶段 11-12 执行结果

本轮已执行 Phase 11、Phase 12，并复跑以下命令:

```bash
flutter analyze
flutter test test/app/widgets/foundation_components_test.dart
flutter test test/features/bookshelf/presentation/bookshelf_card_width_smoke_test.dart
flutter test test/features/mine/application/official_theme_activation_test.dart
flutter test test/features/reader/application/reader_catalog_search_presentation_test.dart test/features/reader/application/reader_audio_controller_test.dart test/features/reader/presentation/reader_settings_sheet_helpers_test.dart
dart run tool/check_ui_component_governance.dart --strict-new
dart run tool/check_theme_coverage_audit.dart --strict-new --top=20
dart run tool/check_ui_component_governance.dart
dart run tool/check_theme_coverage_audit.dart --top=30
```

实际结果:

| 指标 | 阶段 8-10 后 | 阶段 11-12 后 |
|---|---:|---:|
| Theme high risk | 2 | 1 |
| Theme `local-alpha` | 555 | 547 |
| Theme `border-radius` | 534 | 497 |
| Theme `box-decoration` | 364 | 355 |
| Theme `material-color` | 85 | 77 |
| Theme `hardcoded-color` | 62 | 62 |
| Theme `box-shadow` | 30 | 27 |
| UI Governance findings | 818 | 754 |
| UI Governance exempted | 87 | 88 |
| `hardcoded-style` | 784 | 724 |
| `loading-state` | 8 | 4 |

本轮确认:

- `bookshelf_progress_indicator.dart` 已从 medium 降到 low。
- `bookshelf_page.dart` 已从 high 降到 medium；剩余项保留给 Phase 13 的大页/核心边界收尾。
- `reader_catalog_sheet.dart` 已从 medium 降到 low。
- `reader_audio_view.dart` 与 `reader_floating_settings_sheet.dart` 已降到 low。
- Reader 主页面仍为唯一 high risk，已明确留给 Phase 13，避免在本阶段误拆阅读渲染、翻页、分页缓存、阅读背景合成等核心链路。

## 4. 类型批处理执行结果

本轮从“按页面阶段推进”切换为“按问题类型批处理”，先处理数量小、边界明确、验证快的两类问题。

已复跑命令:

```bash
dart run tool/check_ui_component_governance.dart
dart run tool/check_theme_coverage_audit.dart --top=30
```

实际结果:

| 指标 | 阶段 11-12 后 | 类型批处理后 |
|---|---:|---:|
| Theme high risk | 1 | 1 |
| Theme `box-shadow` | 27 | 0 |
| Theme `box-shadow` exempted | 0 | 27 |
| UI Governance findings | 754 | 750 |
| `loading-state` | 4 | 0 |

本轮确认:

- `loading-state` 适合继续作为快速清零类型，裸 `CircularProgressIndicator` 已替换为 `AppProgressIndicator`。
- `box-shadow` 不适合单纯改数值；局部业务阴影应迁移到 `AppSurface`，组件内部、阅读 overlay、PDF 页面深度、封面/头像发光等固定视觉应做精确豁免。
- Reader 主阅读页仍是唯一 high risk，本轮没有触碰阅读渲染、翻页、分页缓存、阅读背景合成。
- 类型批处理比按页面阶段更快，下一轮建议继续按 `material-color`、`rounded-shape/shape-property`、`border-radius` 依次推进。

## 5. 改造原则

- 不追求一次清零，先处理高收益、低风险、可验证的问题。
- Reader 与 Bookshelf 继续只改外围 UI，暂不触碰核心阅读渲染、翻页、分页缓存、书架数据计算和批量选择主流程。
- `TextCoverPlaceholder`、Reader 渲染透明层、封面/内容图片、用户分类颜色这类内容资产优先做豁免归档，不强行主题化。
- 新增代码继续使用 `--strict-new` 门禁，历史问题按阶段下降。
- 每个阶段完成后都复跑两类审计，实际数字以脚本结果为准。

## 6. 阶段任务

### Phase 8: 快速清零阻断项与低成本豁免

目标: 先干掉数量少、边界清楚、容易验证的治理项，让门禁更干净。

- [x] T8.1 清理 `modal-surface`。
  范围: 当前唯一 `modal-surface` finding。
  要求: 若是页面级操作，迁移到 `showAdaptiveActionSurface`；若确实需要保留，补豁免说明。
  验收: `modal-surface` 从 1 降到 0。

- [x] T8.2 清理 `capability-wrapper`。
  范围: 当前 5 个直接使用成熟/平台能力的位置。
  要求: 能 wrapper 化的走 app/feature wrapper；平台桥接类保留但写明原因。
  验收: `capability-wrapper` 从 5 降到 0 或全部转明确豁免。

- [x] T8.3 清理第一批 blocking loading。
  范围: 非 Reader/Bookshelf 核心链路里的页面级裸 `CircularProgressIndicator`。
  要求: blocking loading 改 `AppBlockingProgressCard`，行内 loading 改 `AppProgressIndicator` 或 `AppInlineProgress`。
  验收: `loading-state` 至少下降 15-20 个。

- [x] T8.4 为 `text_cover_placeholder.dart` 建立内容资产豁免。
  范围: 封面生成色板、固定渐变、可读性遮罩。
  要求: 标注为内容资产色板，不作为 App 主题 surface 强制迁移；补 `UI-GOV-EXEMPT` 或集中豁免表。
  验收: 该文件不再作为优先整改对象；高风险文件可快速减少 1 个或转豁免。

- [x] T8.5 扩展审计脚本豁免识别。
  范围: `check_theme_coverage_audit.dart`、`check_ui_component_governance.dart`。
  要求: 识别 `UI-GOV-EXEMPT` 注释或集中豁免表；全量报告分出 unresolved 与 exempted。
  验收: “剩余未治理”数量更接近真实待改数量。

预计覆盖:

- UI governance 阻断型项: 覆盖 `modal-surface` 1 个、`capability-wrapper` 5 个、`loading-state` 15-20 个。
- 高风险文件: `text_cover_placeholder.dart` 预计转豁免，剩余高风险从 4 降到 3。
- `hardcoded-color`: 预计豁免约 36 个。
- UI governance 总 findings: 预计减少或转豁免 55-75 个。

### Phase 9: Mine 首页与非核心中风险页面

目标: 处理收益高、风险低、不涉及核心阅读/书架数据流的页面。

- [x] T9.1 迁移 `mine_page_view.dart` 首页卡片。
  范围: profile card、action section、入口 tile、会员/主题摘要外层。
  要求: 优先使用 `AppSurface`、`AppPanel`、`AppSection`；保留业务跳转和会员状态逻辑。
  验收: `mine_page_view.dart` 从 high risk 降到 medium 或 low。

- [x] T9.2 收敛 Mine 首页本地阴影、圆角、边框。
  范围: `BoxDecoration`、`BoxShadow`、`BorderRadius.circular`、本地 alpha。
  要求: 能用组件 token 的全部迁移；业务强调色需要记录原因。
  验收: Mine 首页 theme coverage score 明显下降。

- [x] T9.3 迁移 `advanced_theme_resource_picker_widgets.dart` 剩余资源 tile。
  范围: 资源选择 tile、角标、预览槽、空槽。
  要求: 与高级主题资源页保持一致，不改资源绑定规则。
  验收: 文件从 medium 降到 low。

- [x] T9.4 迁移 `user_profile_page.dart`、`auth_page_layout_sections.dart` 的低风险 surface。
  范围: 登录/个人资料页面外层卡片、按钮、状态。
  要求: 不改认证流程。
  验收: 两个 medium 文件降级。

- [x] T9.5 补充 Mine/资源页回归测试。
  范围: Mine 首页 smoke/widget test、已有高级主题资源测试。
  验收: `flutter analyze` 和目标测试通过。

预计覆盖:

- 高风险文件: 覆盖 1 个，剩余 2 个真实高风险大页。
- Theme coverage medium 文件: 覆盖 3 个。
- Theme coverage: 预计减少 `local-alpha` 35+、`box-decoration` 25+、`border-radius` 25+、`box-shadow` 6+。
- UI governance `hardcoded-style`: 预计减少 50-80 个。

### Phase 10: 列表、Scaffold 与平台分支分拣

目标: 清理容易判断的结构类问题；难判断的先归类，不急着硬改。

- [x] T10.1 复核 `scaffold`。
  范围: 新式普通页面优先迁移 `AdaptivePageScaffold`；沉浸式、Reader、WebView 记录豁免。
  要求: 只改普通页面骨架，不碰 Reader 主 shell。
  验收: `scaffold` 下降 10-15 个，剩余项均有分类。

- [x] T10.2 复核 `list-children`。
  范围: 长列表必须 builder/sliver；短设置列表标注豁免。
  要求: 不为短静态列表做无意义重构。
  验收: `list-children` 下降 10-15 个。

- [x] T10.3 复核 `list-performance`。
  范围: `shrinkWrap:true`、可增长列表和嵌套滚动。
  要求: 长列表保持 lazy；短静态设置区写明原因。
  验收: `list-performance` 下降 2-3 个。

- [x] T10.4 复核 `layout-builder`。
  范围: LayoutBuilder 中疑似副作用或重活的位置。
  要求: 纯布局保留并标注；有副作用的迁出。
  验收: `layout-builder` 下降 1-2 个。

- [x] T10.5 复核 `platform-branch`。
  范围: app shell、platform bridge、Reader 平台能力。
  要求: 真正页面级分支迁移到 adaptive/capability；平台桥接保留并标注。
  验收: `platform-branch` 真实减少 5-10 个，其余归档为平台能力边界。

预计覆盖:

- UI governance `scaffold`: 预计减少 10-15 个。
- UI governance `list-children`: 预计减少 10-15 个。
- UI governance `list-performance`: 预计减少 2-3 个。
- UI governance `layout-builder`: 预计减少 1-2 个。
- UI governance `platform-branch`: 预计减少 5-10 个，其余分类归档。

### Phase 11: Bookshelf 外围继续收敛

目标: Bookshelf 放在 Reader 前面，但仍只做外围，不拆核心数据流。

- [x] T11.1 迁移 `bookshelf_progress_indicator.dart`。
  范围: 书架进度条、未读提示、动画高亮。
  要求: token 化颜色/圆角/阴影；保留动画语义和 reduce motion 口径。
  验收: 文件从 medium 降到 low。

- [x] T11.2 迁移 Bookshelf toolbar 与 setting sheet 外围。
  范围: toolbar、筛选、设置面板非核心卡片。
  要求: 不改书籍筛选、排序、批量选择数据流。
  验收: `bookshelf_page.dart` 和 `bookshelf_page_flow.dart` score 下降。

- [x] T11.3 建立 `bookshelf_page.dart` 拆分边界。
  范围: 书架主页面遗留本地样式、继续阅读卡、局部浮层。
  要求: 每次只抽一个外围 widget，保持 book card 手势和数据流稳定。
  验收: high risk score 下降或形成明确拆分 backlog。

- [x] T11.4 清理第二批 Bookshelf loading/state。
  范围: 书架设置、局部任务状态、非核心导入展示。
  要求: 使用 `AppStateView`、`AppProgressIndicator`、`AppTaskProgressRow`。
  验收: `loading-state` 再下降 10-15 个。

预计覆盖:

- 高风险文件: 覆盖 `bookshelf_page.dart`，目标从 high 降到 medium 或形成可执行拆分 backlog。
- Theme coverage: 预计减少 `border-radius` 25+、`local-alpha` 25+、`box-decoration` 15+、`box-shadow` 3+。
- UI governance `hardcoded-style`: 预计减少 40-60 个。
- UI governance `loading-state`: 预计减少 10-15 个。

### Phase 12: Reader 外围收敛

目标: Reader 往后放，只做 sheet/chrome/状态外围，不碰核心阅读渲染。

- [x] T12.1 迁移 `reader_catalog_sheet.dart` 外围。
  范围: catalog sheet 的 surface、搜索、空态、分组、进度。
  要求: 使用 `AppSurface`、`AppTextField`、`AppStateView/AppStatusStateCard`；不改目录数据和跳章逻辑。
  验收: `reader_catalog_sheet.dart` 从 medium 降到 low。

- [x] T12.2 迁移 `reader_page_settings_sheet.dart` 外围。
  范围: 设置 sheet 中仍散落的本地容器、按钮、状态、progress。
  要求: 与 `reader_settings_components.dart` 保持同一组件族。
  验收: Reader settings 视觉一致，不影响设置持久化。

- [x] T12.3 迁移 `reader_audio_view.dart`、`reader_floating_settings_sheet.dart` 的外围控件。
  范围: 音频视图和浮动设置 sheet 的卡片、按钮、状态。
  要求: 不改播放/设置业务逻辑。
  验收: 两个文件 score 下降。

- [x] T12.4 为 Reader 固定视觉建立豁免记录。
  范围: Reader 渲染透明层、翻页动画、阅读背景合成、overlay 对比度。
  要求: 不改核心渲染；只标注合理项，能迁移的外围项拆出 backlog。
  验收: Reader 高风险项可解释，避免误拆核心阅读链路。

预计覆盖:

- Theme coverage medium 文件: 覆盖 3-4 个。
- Theme coverage: 预计减少 `border-radius` 30+、`local-alpha` 30+、`box-decoration` 20+、`material-color` 8+。
- UI governance `hardcoded-style`: 预计减少或转豁免 60-90 个。

### Phase 13: 难拆大页与核心边界收尾

目标: 最后处理真正难拆的大文件和核心边界，只在前面阶段收益拿完后进入。

- [ ] T13.1 复核 `reader_page.dart`。
  范围: Reader 主页面里剩余可拆外围项。
  要求: 核心阅读渲染、翻页、分页缓存、内容加载不在本任务内重写。
  验收: 可迁移外围项迁出；核心固定视觉全部有豁免说明。

- [ ] T13.2 复核 `bookshelf_page.dart` 主流程剩余项。
  范围: 继续阅读卡、局部浮层、历史遗留容器。
  要求: 不改批量选择、书籍打开、数据刷新主流程。
  验收: high risk 归零或剩余项全部进入拆分 backlog。

- [ ] T13.3 处理剩余 `hardcoded-style` 高密度文件。
  范围: 前面阶段未覆盖的高密度历史文件。
  要求: 只处理明确标准件可替换的位置，不强行重构业务。
  验收: 总 findings 再下降一轮。

- [ ] T13.4 形成下一轮技术债清单。
  范围: 大文件拆分、Reader core、Bookshelf core、平台能力桥接。
  要求: 明确哪些不能靠 UI Kit 迁移解决，需要单独架构阶段。
  验收: 剩余项按“可迁移/需架构/已豁免”分类。

预计覆盖:

- 高风险文件: 目标高风险从 2 降到 0-1。
- UI governance `hardcoded-style`: 预计减少或转豁免 40-70 个。
- 完成后剩余项主要应是大页拆分、平台桥接和内容资产豁免。

## 7. 完成后预计覆盖与剩余

以下是保守目标。实际完成后必须以脚本复跑结果为准。

### 4.1 Theme Coverage 预计结果

| 指标 | 当前数量 | 预计覆盖/减少或豁免 | 预计剩余 |
|---|---:|---:|---:|
| 高风险文件 | 4 | 3-4 | 0-1 |
| `local-alpha` | 572 | 90-130 | 442-482 |
| `border-radius` | 558 | 90-130 | 428-468 |
| `box-decoration` | 377 | 60-90 | 287-317 |
| `material-color` | 98 | 25-40 | 58-73 |
| `hardcoded-color` | 98 | 45-60 | 38-53 |
| `shape-property` | 75 | 20-30 | 45-55 |
| `rounded-shape` | 32 | 7-12 | 20-25 |
| `box-shadow` | 30 | 10-15 | 15-20 |

说明:

- `hardcoded-color` 的覆盖里包含内容资产豁免，不全是代码删除。
- `local-alpha`、`border-radius` 的剩余数量会较多，因为 Reader、封面、短列表和既有业务组件里仍有合理固定视觉或低风险历史债务。

### 4.2 UI Governance 预计结果

| 指标 | 当前数量 | 预计覆盖/减少或豁免 | 预计剩余 |
|---|---:|---:|---:|
| 总 findings | 1018 | 250-330 | 688-768 |
| `hardcoded-style` | 814 | 180-240 | 574-634 |
| `loading-state` | 48 | 30-40 | 8-18 |
| `modal-surface` | 1 | 1 | 0 |
| `capability-wrapper` | 5 | 5 | 0 |
| `scaffold` | 40 | 10-15 | 25-30 |
| `list-children` | 46 | 10-15 | 31-36 |
| `list-performance` | 8 | 2-3 | 5-6 |
| `layout-builder` | 5 | 1-2 | 3-4 |
| `platform-branch` | 51 | 5-10 | 41-46 |

说明:

- `platform-branch` 很多属于平台桥接、Reader 平台能力或 app shell，不能简单清零。
- `hardcoded-style` 数量最大，后续应继续按高风险文件和业务域滚动治理。
- 完成本计划后，最关键的变化不是“全部变 0”，而是高风险文件归零或接近归零，blocking 型治理项基本归零，新增代码继续由 `--strict-new` 防回归。

## 8. 每阶段验收命令

每个阶段完成后至少执行:

```bash
flutter analyze
flutter test test/app/widgets/foundation_components_test.dart
dart run tool/check_ui_component_governance.dart --strict-new
dart run tool/check_theme_coverage_audit.dart --strict-new --top=20
dart run tool/check_theme_coverage_audit.dart --top=20
dart run tool/check_ui_component_governance.dart
```

涉及 Reader/Bookshelf 时追加对应目标测试；涉及高级主题资源时追加高级主题资源测试和 Lumina 组件样板测试。

## 9. 推荐执行顺序

1. Phase 8: 快速清零阻断项与低成本豁免，先把最容易降的数字拿掉。
2. Phase 9: Mine 首页与非核心中风险页面，优先处理体验收益明显且业务风险低的区域。
3. Phase 10: 列表、Scaffold 与平台分支分拣，能改就改，不能改先归类。
4. Phase 11: Bookshelf 外围继续收敛，仍不碰书架核心数据流。
5. Phase 12: Reader 外围收敛，阅读器整体后移，只做 sheet/chrome/状态外围。
6. Phase 13: 难拆大页与核心边界收尾，最后处理 Reader/Bookshelf 主大页和架构类技术债。
