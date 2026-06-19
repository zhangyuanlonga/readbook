# Lumina 阅读 UI 优化建议与阶段计划

创建日期: 2026-06-18  
适用范围: Flutter 客户端 UI/UX、高级主题、书架、阅读器、阅读记录、搜索与设置相关页面  
目标方向: 以 Lumina Library System 为主审美参考，把当前 MD3 + 高级主题能力收束成更稳定的阅读产品视觉语言。

---

## 1. 背景与结论

当前项目已经具备较完整的外观能力: Material 3 ColorScheme、seed 主题色、高级主题 palette/backdrop、组件形态 token、界面字体绑定、阅读字体绑定、应用背景和阅读器背景。问题不是能力不足，而是能力之间缺少一个统一的默认审美主轴。

现在的视觉观感容易出现以下情况:

- 基础 MD3 的主题色强调感偏强，容易显得像通用工具 App。
- 高级主题能覆盖很多字段，但页面局部仍存在硬编码圆角、间距、卡片形态和固定浅色阅读背景。
- 书架、搜索、阅读记录、设置面板、阅读器正文之间的背景层级和强调色不总是同一种语言。
- 阅读 App 的主角应该是书封、文本、阅读进度和阅读状态，而不是主题色本身。

Lumina 方向适合当前项目。它不要求推倒重做页面结构，而是把现有能力整理成一套更安静、更克制、更聚焦内容的阅读审美:

- 白底或冷白灰背景降低视觉噪音，避免暖粉、脏灰和明显发黄的底色。
- 白色或近白卡片承载书籍与状态信息。
- 深炭黑作为主要文字和主要操作。
- 冷灰作为作者、来源、章节、说明等辅助信息。
- 轻边框与低强度阴影建立层级，不依赖重色块。
- 进度条和选中态使用低饱和辅助强调，避免所有状态都变成纯黑。

结论: Lumina 应作为一个官方主题预设和 UI 收敛方向推进，而不是只作为一个新的主题色。

补充定位 2026-06-19:

- Lumina 放在高级主题体系中承接，但作为官方主题预设免费启用。
- Lumina 是一整套主题，包含浅色配置 `Lumina Neutral` 和深色配置 `Dark Ink`。
- 免费用户可以进入主题预设页并使用官方 Lumina。
- 复制 Lumina 后编辑、导入导出、完整语义色编辑、组件圆角和样式细调仍属于会员高级主题能力。
- “应用外观”里的基础配色继续存在，对应当前主题色能力；启用 Lumina 后会被 Lumina 覆盖。
- 默认外观、官方主题预设、基础配色和高级主题边界以 `docs/ui_ux/app_default_color_system_refactor_plan_2026_06_19.md` 为准；本文档专注 Lumina 的视觉目标和页面落地。

---

## 2. 当前实现梳理

### 2.1 已经具备的能力

项目当前能力足够支持 Lumina 的第一阶段落地:

- `lib/app/theme/app_theme_palette.dart`: 负责基础 light/dark ColorScheme 和 seed 主题色。
- `lib/app/theme/app_theme.dart`: 负责构建 ThemeData，并把高级主题 palette/backdrop 应用到全局主题。
- `lib/domain/entities/app_advanced_theme.dart`: 高级主题实体，支持颜色、组件风格、应用壁纸、阅读器壁纸、界面字体和阅读字体。
- `lib/app/theme/app_advanced_theme_tokens.dart`: 解析高级主题 palette/backdrop。
- `lib/app/theme/app_component_theme_tokens.dart`: 解析卡片、按钮、输入框、浮层、导航、选择控件形态。
- `lib/features/bookshelf/presentation/bookshelf_page.dart`: 书架卡片已经具备封面、标题、作者、章节、进度条结构。
- `lib/features/reader/application/reader_settings_resolution_service.dart`: 高级主题可以覆盖阅读字体与阅读器背景。
- `lib/features/reader/presentation/reader_page.dart`: 阅读器 modal 和阅读背景会从当前主题与阅读设置解析颜色。

### 2.2 主要断点

这些点会影响 Lumina 的完整观感:

- 书架列表卡片和网格点击区域存在局部圆角硬编码，例如 14dp。
- 书架网格卡片默认不是完整白卡片，而是封面和文字直接浮在页面背景上。
- 阅读器 light + plain + surface 模式存在经典白底特例，会绕开当前全局主题背景。
- `buildAdvancedThemeBackdropDecoration` 使用 background 到 surface 的纵向渐变，如果颜色差距不小，会产生轻微不一致。
- 通用空状态、状态卡、搜索栏、菜单等部分组件使用 `surfaceContainerLow` 和局部常量，未必完全服从高级主题的 card/search/elevated 语义。
- Manrope 这类界面字体目前不能通过 pubspec 默认生效，需要导入注册或打包资源。

---

## 3. Lumina 设计目标

### 3.1 视觉目标

- 内容优先: 书封、书名、作者、章节、进度是视觉中心。
- 低干扰: 背景、导航、搜索框、chip 和菜单不要抢内容焦点。
- 轻层级: 通过白底优先的 canvas、白卡片、细边框、低强度阴影建立结构。
- 阅读舒适: 阅读器正文背景要比纯白更柔和，但不能发黄过重。
- 管理效率: 书架、搜索、阅读记录仍要具备高信息密度，不做营销型页面。

### 3.2 色彩建议

建议不要照搬纯黑 `#000000` 作为所有强调色。纯黑在 MD3 中会把按钮、选中态、进度条都压得过重。

推荐 Lumina Light:

```text
pageBackground: #FFFFFF
surface: #FFFFFF
elevatedSurface: #F6F7F9
card: #FFFFFF
cardBorder: #EDF0F4
textPrimary: #1C1B1B
textSecondary: #606773
outline: #D5DAE2
primary: #1C1B1B
primaryContainer: #F3F6F8
secondary: #585F6C
searchFieldBackground: #FFFFFF
shadow: rgba(15, 23, 42, 0.045)
progressAccent: #68717E 或 #746B87
```

补充: 当前 App 书架已经是白底、轻搜索框、少量黑色图标的简洁结构。Lumina Light 在移动端应优先延续这个白底气质，只把搜索框、底栏分隔、卡片边框、选中态和进度色做得更统一；不建议把整个书架改成明显灰底。

推荐 Lumina Dark:

```text
pageBackground: #141414
surface: #1B1A1A
elevatedSurface: #242323
card: #201F1F
cardBorder: #373535
textPrimary: #F4F0EF
textSecondary: #C8C6C5
outline: #555252
primary: #E5E2E1
primaryContainer: #313030
secondary: #C0C7D6
searchFieldBackground: #242323
shadow: rgba(0, 0, 0, 0.34)
progressAccent: #C0C7D6
```

### 3.3 字体建议

- 界面字体可以支持 Manrope 或相近现代无衬线字体。
- 中文界面不要强依赖 Manrope，因为中文 glyph 仍会走 fallback。
- 阅读正文不建议默认 Manrope。正文应优先使用系统中文字体、用户自定义字体或项目已有阅读字体设置。
- 高级主题可以绑定界面字体与阅读字体，但应允许用户覆盖。

### 3.4 形态建议

- 全局组件圆角比例: 0.85-0.95，避免当前部分区域过圆导致工具感和阅读感冲突。
- 卡片: soft 或 outlined，低阴影，细边框。
- 按钮: stadium 可保留，但主按钮颜色要克制。
- 输入框: search field 建议 pill，表单输入可以保留 12-14dp。
- 导航: soft 或 compact，降低存在感。
- 进度条: 3-4dp，高度轻，填充色不宜纯黑。

---

## 4. 优化建议

### 4.1 建立 Lumina 官方主题预设

把 Lumina 做成官方主题预设，而不是 seed color 选项。它应覆盖:

- light/dark 两套高级主题颜色。
- componentStyle: card、button、input、overlay、navigation、switch。
- 可选 appInterfaceFontFamilyKey。
- 可选 readerFontFamilyKey。
- 可选 reader wallpaper 或阅读器背景色策略。

收益:

- 不破坏现有“外观 - 主题色”能力。
- 能复用现有高级主题启用、预览和会员权益体系。
- 免费用户可直接启用官方 Lumina。
- 会员用户可复制 Lumina 后进入高级主题编辑、导入导出和微调。

### 4.2 收敛书架卡片视觉

书架是最能体现 Lumina 的页面，应作为第一试点。

建议:

- 网格模式提供或默认一个 Lumina 风格: 书封上方，标题/作者/进度在轻卡片内或至少在统一文字层级内。
- 列表卡片使用高级主题 card token，不再硬编码 14dp。
- 封面圆角保持 10-12dp，比外层卡片略小。
- 进度条填充色使用 Lumina progressAccent 或 primary 的柔和派生色。
- 作者、来源、最新章节统一用 textSecondary。
- 选中态用 primaryContainer + primary 边框，避免大块纯黑。

不建议:

- 不建议把书架做成大量厚重卡片。
- 不建议给每本书都加强阴影。
- 不建议把进度条、来源 badge、分类 tag 都做成高饱和色。

### 4.3 统一搜索、筛选和标签

搜索与筛选是当前视觉噪音容易聚集的地方。

建议:

- 搜索框使用 searchFieldBackground。
- 搜索框边框使用 outlineVariant 低透明度。
- quick filter chip 未选中态使用 elevatedSurface 或 surfaceContainer。
- 选中态使用 primaryContainer，不直接使用 primary 大色块。
- chip 字重保持 600 左右，避免所有标签都变成粗黑。

### 4.4 阅读器浅色背景跟随主题

当前阅读器经典白底特例会让外部 Lumina 和阅读器正文割裂。

建议:

- 在 Lumina 高级主题启用时，阅读器 light/plain/surface 不再强制返回固定 `#FDFDFD`。
- 阅读器正文背景可使用 Lumina 的 pageBackground 或专门的 readerSurface。
- 阅读器文字仍保持高对比，不为了柔和牺牲可读性。
- 阅读器菜单、设置面板、目录、书签、批注等 chrome 跟随 Lumina modal/elevated surface。

### 4.5 统一阅读记录页

阅读记录页天然适合 Lumina，因为它偏数据和状态。

建议:

- 日历热力图使用低饱和阶梯，不使用过强 primary。
- 统计卡片使用白卡片 + 细边框。
- 关键数字使用深炭黑或主文字色。
- 趋势、分布、排行使用 secondary 或 progressAccent。

### 4.6 收敛高级主题编辑体验

当前高级主题很强，但用户可能不容易理解“主题色”和“高级主题”的差别。

建议:

- 在高级主题列表增加“官方/内置预设”分组。
- Lumina 作为内置预设展示，不要求用户从零编辑。
- 编辑页里增加“主审美预设说明”，解释它会影响页面背景、卡片、搜索、阅读器 chrome 等。
- 保留现有导入导出，Lumina 可复制为用户主题再编辑。

### 4.7 增加主题覆盖审计

当前最大风险是局部硬编码导致主题不完整。

建议:

- 扩展或新增 theme coverage audit。
- 检查 `BorderRadius.circular(...)`、`Color(...)`、`surfaceContainerLow`、`primaryContainer` 等高频硬编码用法。
- 不是全部禁止硬编码，而是列出需要改为 token/palette 的核心路径。
- 对书架、阅读器、搜索、阅读记录优先做覆盖审计。

---

## 5. 开发计划总览

执行方式建议采用小步试点，不做一次性大改。

| 阶段 | 目标 | 建议周期 | 风险 |
|---|---|---:|---|
| Phase 0 | 设计决策与预设规格冻结 | 0.5-1 天 | 低 |
| Phase 1 | Lumina 高级主题预设落地 | 1-2 天 | 低 |
| Phase 2 | 书架试点收敛 | 2-4 天 | 中 |
| Phase 3 | 阅读器浅色背景与 chrome 统一 | 2-4 天 | 中高 |
| Phase 4 | 搜索、阅读记录、设置面板推广 | 3-5 天 | 中 |
| Phase 5 | 主题覆盖审计与自动化保护 | 2-4 天 | 中 |
| Phase 6 | 视觉验收、回归与发布准备 | 1-3 天 | 中 |

---

## 6. 阶段任务清单

### Phase 0: 设计决策与规格冻结

目标: 先把 Lumina 做成什么、不做什么定下来。

- [ ] 确认 Lumina 是高级主题预设，不作为普通 seed 主题色。
- [ ] 确认 Lumina 不推倒现有页面布局，只做视觉体系收敛。
- [ ] 确认 light/dark 两套基础色板。
- [ ] 确认 primary 不使用纯黑，而使用深炭黑。
- [ ] 确认 progressAccent 是否使用冷灰蓝或低饱和紫灰。
- [ ] 确认界面字体策略: 系统默认、可选 Manrope、自定义字体绑定三者关系。
- [ ] 确认阅读正文字体不默认强推 Manrope。
- [ ] 确认首批试点范围: 书架、阅读器 modal、阅读记录页。
- [ ] 确认暂不处理范围: 大规模布局重构、全量页面重写、启动图体系重做。

验收:

- [ ] 形成一份固定 Lumina token 表。
- [ ] 产品和开发确认 Lumina 预设边界。
- [ ] 明确哪些视觉差异属于本轮不处理。

### Phase 1: Lumina 官方主题预设落地

目标: 让用户可以启用 Lumina，并通过现有高级主题机制预览；复制、编辑和导入导出按会员权限处理。

- [ ] 设计 `Lumina` 内置主题数据结构。
- [ ] 为 lightConfig 配置 Lumina 色板。
- [ ] 为 darkConfig 配置 Lumina 色板。
- [ ] 配置 componentStyle: soft card、stadium/rounded button、soft input、comfortable overlay、soft/compact navigation。
- [ ] 配置 shadowStrength 为低强度。
- [ ] 配置 wallpaperOverlayOpacity 为低值或默认关闭壁纸。
- [ ] 如果支持内置主题列表，加入 Lumina 预设入口。
- [ ] 如果当前仅支持用户导入，先生成 Lumina 主题 JSON/ZIP 作为可导入资源。
- [ ] 确认 Lumina 可启用、禁用。
- [ ] 确认复制、编辑、导入导出会进入会员权限边界。
- [ ] 确认启用 Lumina 后 AppTheme.build 能正确应用 palette/backdrop。

验收:

- [ ] 外观页可看到或导入 Lumina。
- [ ] 启用后页面背景、卡片、按钮、文字、边框有明显统一变化。
- [ ] 禁用后能恢复默认主题。
- [ ] light/dark 切换没有明显低对比问题。

### Phase 2: 书架试点收敛

目标: 让书架成为 Lumina 方向的样板页面。

- [ ] 梳理书架页面中硬编码圆角、颜色、阴影、间距。
- [ ] 让 `BookshelfListBookCardShell` 使用主题 token 或 palette 派生圆角。
- [ ] 让 `BookshelfGridBookCardShell` 使用统一卡片/封面圆角策略。
- [ ] 评估网格模式是否需要增加 Lumina 卡片容器。
- [ ] 统一封面圆角为外层卡片圆角的 0.70-0.80 倍。
- [ ] 调整网格标题、作者、最新章节、进度条的颜色层级。
- [ ] 调整列表卡片边框透明度，降低视觉噪音。
- [ ] 调整 selection indicator，避免选中态过黑。
- [ ] 调整 progress bar 填充色与背景色。
- [ ] 检查书架空状态、加载、错误卡是否符合 Lumina。
- [ ] 检查继续阅读卡片是否符合 Lumina。
- [ ] 保留用户现有书架显示偏好，不强行重置布局。

验收:

- [ ] 书架网格和列表在 Lumina 下有一致气质。
- [ ] 书封成为主视觉焦点。
- [ ] 进度条清楚但不刺眼。
- [ ] 小屏、平板、桌面至少三个断点无明显溢出。
- [ ] 非 Lumina 主题下原有观感不明显回退。

### Phase 3: 阅读器浅色背景与 chrome 统一

目标: 解决外观主题和阅读器割裂问题。

- [ ] 审查 `_resolveThemeColors` 的 classic light 特例。
- [ ] 设计 Lumina 启用时的 reader background 策略。
- [ ] 避免普通默认主题被意外改变。
- [ ] 让阅读器 modal theme 在 Lumina 下使用更稳定的 surface/elevatedSurface。
- [ ] 检查阅读设置 sheet、目录 sheet、书签/批注相关 surface。
- [ ] 检查阅读器顶部/底部 chrome 的透明度和文字对比。
- [ ] 确认高级主题 reader wallpaper 和用户 visual overrides 的优先级。
- [ ] 确认阅读器 light/dark/system 同步逻辑不受破坏。
- [ ] 检查正文背景、文字、meta、divider 的对比度。
- [ ] 保持 sepia 和 pureBlack 阅读模式不被 Lumina 强行覆盖。

验收:

- [ ] Lumina 下阅读器正文背景与 App 外层气质一致。
- [ ] 正文阅读对比足够，长时间阅读不刺眼。
- [ ] 用户自定义阅读背景和字体仍可覆盖。
- [ ] 夜间阅读模式不变亮、不反色异常。

### Phase 4: 搜索、阅读记录、设置面板推广

目标: 把 Lumina 从书架和阅读器推广到高频周边页面。

- [ ] 搜索页输入框使用 searchFieldBackground 和统一边框。
- [ ] 搜索结果卡片使用 card/elevatedSurface 层级。
- [ ] 搜索进度卡使用 Lumina progressAccent。
- [ ] 搜索失败、空状态、筛选 sheet 使用统一 surface。
- [ ] 阅读记录页统计卡片使用 Lumina card。
- [ ] 阅读记录页热力图使用低饱和阶梯色。
- [ ] 阅读记录页排行/分布图颜色避免过强 primary。
- [ ] 外观页和高级主题编辑页使用更清晰的预设说明。
- [ ] 设置页、关于页、存储管理页的卡片与状态组件跟随 Lumina。
- [ ] 弹窗、菜单、底部 sheet 在 Lumina 下统一 modal surface。

验收:

- [ ] 搜索、阅读记录、设置页在 Lumina 下不再像另一套主题。
- [ ] 高频操作仍清晰可识别。
- [ ] 错误、警告、会员、权限等语义色不被 Lumina 弱化到不可见。

### Phase 5: 主题覆盖审计与自动化保护

目标: 防止主题体系继续被局部硬编码打散。

- [ ] 扩展 `tool/check_theme_coverage_audit.dart` 或新增 Lumina 覆盖审计。
- [ ] 检查核心路径中的硬编码 `Color(...)`。
- [ ] 检查核心路径中的硬编码 `BorderRadius.circular(...)`。
- [ ] 检查核心路径中的 `surfaceContainerLow` 是否应替换为 palette.card/elevated/search。
- [ ] 检查核心路径中的 `primary` 是否应使用 progressAccent 或 secondary。
- [ ] 为允许硬编码的场景建立白名单。
- [ ] 输出审计报告，不立即 CI 拦截。
- [ ] 修复 P0/P1 主题覆盖问题。
- [ ] 将新增问题逐步纳入 CI 或本地检查。

验收:

- [ ] 有一份 Lumina 主题覆盖审计报告。
- [ ] 书架、阅读器、搜索、阅读记录 P0/P1 问题已处理。
- [ ] 后续新增 UI 有明确检查入口。

### Phase 6: 视觉验收、回归与发布准备

目标: 确认 Lumina 不是只在单个页面好看，而是在主路径上稳定。

- [ ] 准备截图验收场景: 书架空状态、有书网格、有书列表、搜索中、搜索结果、阅读器正文、阅读设置、阅读记录、外观页、常用组件样板。
- [ ] 覆盖 compact、largePhone、medium、expanded 至少四个宽度。
- [ ] 覆盖 light/dark/system。
- [ ] 覆盖有无高级主题、启用 Lumina、恢复默认主题。
- [ ] 覆盖自定义阅读背景、自定义阅读字体、用户手动覆盖背景。
- [ ] 运行 Flutter analyze。
- [ ] 运行相关 widget tests 或 smoke tests。
- [ ] 补充变更说明和用户可感知说明。
- [ ] 确认是否需要做灰度开关或实验入口。

验收:

- [ ] 主路径截图通过。
- [ ] 无明显文字溢出、按钮挤压、颜色不可读。
- [ ] 主题切换、阅读器打开、书架滚动没有明显性能退化。
- [ ] 发布说明解释 Lumina 是高级主题预设。

---

## 7. 优先级建议

### P0: 先做

- [ ] Lumina 高级主题预设。
- [ ] 书架视觉收敛。
- [ ] 阅读器浅色背景与 modal chrome 跟随 Lumina。
- [ ] light/dark 对比度检查。

### P1: 第二批

- [ ] 搜索页与阅读记录页推广。
- [ ] 高级主题编辑页预设说明。
- [ ] 主题覆盖审计报告。
- [ ] 进度条和选中态辅助强调色治理。

### P2: 后续增强

- [ ] Manrope 或其他现代界面字体内置化。
- [ ] Lumina 卡片模式作为书架显示偏好。
- [ ] 主题预设市场/模板分组。
- [ ] 截图自动化回归。

---

## 8. 风险与控制

### 8.1 风险: 纯黑 primary 过重

控制:

- [ ] 使用深炭黑替代纯黑。
- [ ] 进度条使用 progressAccent，不直接使用 primary。
- [ ] 选中背景使用 primaryContainer。

### 8.2 风险: 阅读器可读性下降

控制:

- [ ] 阅读正文保持高对比。
- [ ] 不强制覆盖用户阅读字体。
- [ ] sepia 和 pureBlack 继续作为独立阅读模式。

### 8.3 风险: 官方主题、高级主题和普通主题色概念混乱

控制:

- [ ] Lumina 放在高级主题体系的官方主题分组里。
- [ ] 外观页保留基础配色入口，对应原普通主题色能力。
- [ ] 主题预设页说明官方主题会覆盖基础配色。
- [ ] 复制编辑、导入导出和组件样式细调明确走会员能力。

### 8.4 风险: 局部硬编码导致效果不完整

控制:

- [ ] 先审计核心页面。
- [ ] 只修 P0/P1 路径。
- [ ] 建立允许例外清单。

### 8.5 风险: 一次性改动过大

控制:

- [ ] 书架先试点。
- [ ] 阅读器单独阶段处理。
- [ ] 每阶段都能独立验收和回滚。

---

## 9. 推荐最小可行版本

如果只做一个最小可行版本，建议范围如下:

- [ ] 新增 Lumina 官方主题预设。
- [ ] 书架列表卡片和网格文字层级适配 Lumina。
- [ ] 进度条颜色从纯 primary 改为 Lumina 友好的辅助强调色。
- [ ] 阅读器 light/plain/surface 在 Lumina 启用时不再使用固定经典白底。
- [ ] 搜索框和空状态卡跟随 Lumina surface/card。
- [ ] 做一轮 compact、medium、desktop 的截图验收。

最小版本不处理:

- [ ] 不内置 Manrope 字体。
- [ ] 不重做所有页面。
- [ ] 不重构书架布局偏好。
- [ ] 不强制替换所有硬编码圆角。
- [ ] 不改变用户已有阅读模式偏好。

---

## 10. 验收清单

- [ ] Lumina 作为官方主题能启用、禁用。
- [ ] Lumina 的复制、编辑和导入导出按会员权限正确拦截或放行。
- [ ] 书架页面在 Lumina 下有稳定的白底或冷白灰背景、白卡片/轻层级、低干扰进度条。
- [ ] 阅读器正文背景与外层主题不割裂。
- [ ] 阅读器设置、目录、书签、批注等 chrome 与 Lumina 一致。
- [ ] 搜索页和阅读记录页没有明显跳回默认蓝白风格。
- [ ] 搜索框、按钮、下拉框、单选、多选、列表等常用组件在 Lumina 下有一致的轻层级。
- [ ] light/dark 都通过基础对比度检查。
- [ ] 小屏、平板、桌面没有明显布局溢出。
- [ ] 默认主题、Selune 主题和用户自定义高级主题没有明显回退。
- [ ] 主题覆盖审计能列出核心问题和白名单。
