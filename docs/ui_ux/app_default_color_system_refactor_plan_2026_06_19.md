# App 默认外观与配色体系改造方案

创建日期: 2026-06-19  
适用范围: Flutter 客户端默认主题、应用外观、主题色入口、官方主题预设、基础组件视觉、高级主题边界  
目标: 把当前基于 Material 3 seed color 的“主题色”能力，升级为更符合主流阅读 App 的默认外观体系；官方主题预设免费可用，高级主题的自定义编辑仍保留为会员深度定制能力。

---

## 1. 背景结论

当前 App 的默认外观不是能力不足，而是默认外观分层不够清楚。

现在的“主题色”本质是一个 MD3 seed color。用户选择蓝色、橙色、绿色后，`ColorScheme.primary`、按钮、checkbox、switch、slider、chip 选中态、图标底色等都会跟随 seed 变色。这样实现简单，但视觉结果容易变成“Material 默认示例感”，而不是成熟阅读 App 的产品气质。

结论:

- 默认 App 视觉必须免费、内置、好看，不能依赖会员高级主题来补救。
- “主题色”入口可以继续保留，但应从“单色 seed”升级为“基础配色”。
- “基础外观预设”本质是一整套 UI 主题，应放进高级主题体系承接。
- 官方主题预设免费可用；自定义、复制后编辑、导入导出等能力走会员高级主题。
- Lumina 不应只作为会员高级主题，它应该先作为官方默认主题预设之一。
- 高级主题继续负责深度编辑、导入导出、背景图、字体绑定、阅读器视觉、组件形态细调等。

---

## 2. 当前实现事实

### 2.1 主题色存储

`lib/app/theme/app_theme_seed_provider.dart`

- `appSeedColorProvider` 当前存储的是一个 `Color`。
- 默认值是 `Color(0xFFFFFFFF)`。
- 用户选择后通过 `appThemePreferencesServiceProvider.saveSeedColorValue(...)` 持久化。
- 这说明当前“主题色”数据模型仍是单色。

### 2.2 基础 ColorScheme 生成

`lib/app/theme/app_theme_palette.dart`

- `appThemeSeedOptions` 目前是若干 `AppThemeSeedOption(label, color)`。
- 普通颜色会走 `ColorScheme.fromSeed(...)`。
- `Selune` 和 `霁雪白` 已经是特殊分支，说明项目已经接受“某些选项不是纯 seed，而是官方定制配色”。
- 当前 `霁雪白` 仍保留蓝色 `primary: #1677FF`，这会造成默认按钮、checkbox、switch 等组件大量偏蓝。

### 2.3 ThemeData 构建

`lib/app/theme/app_theme.dart`

- `AppTheme.build(...)` 会把 `ColorScheme` 应用到 `ThemeData`。
- `FilledButton` 使用 `effectiveColorScheme.primary`。
- `InputDecoration` focused border 使用 `effectiveColorScheme.primary`。
- `TabBar`、`ChipTheme`、`SwitchTheme` 等也受 `ColorScheme` 和 component token 影响。
- 因此只要 `primary` 是高饱和蓝，常用组件就会自然变成强蓝色。

### 2.4 高级主题覆盖

高级主题已经有完整语义字段:

- `backgroundColorValue`
- `surfaceColorValue`
- `elevatedSurfaceColorValue`
- `cardColorValue`
- `cardBorderColorValue`
- `primaryColorValue`
- `primaryContainerColorValue`
- `secondaryColorValue`
- `noticeAccentColorValue`
- `searchFieldBackgroundColorValue`
- app/reader 字体和背景绑定

这套能力适合会员高级主题，不适合拿来承担所有用户的默认 App 视觉。

### 2.5 组件形态与圆角

`lib/app/theme/app_component_theme_tokens.dart`

- 项目已经有组件级形态 token: card、button、input、overlay、navigation、selection。
- `resolveAppComponentThemeTokensFromModeConfig(...)` 已经支持 `globalRadiusScale`。
- `lib/features/mine/presentation/advanced_theme_editor_page.dart` 里已经有“全局圆角比例”滑杆。

这说明项目已经具备类似 Google Stitch “角半径”面板的底层能力。差异在于:

- Stitch 展示为普通用户也容易理解的全局圆角 preset。
- 当前项目把全局圆角放在会员高级主题编辑里，且是连续滑杆。
- 业务页面仍存在部分 `AppAdaptiveMetrics.cardRadius` 或硬编码圆角，组件 token 没有完全闭环。

---

## 3. 问题定义

### 3.1 用户理解问题

如果把 Lumina、黑白灰、黑白蓝都放进“高级主题”，普通用户会误解:

- 默认 App 不好看，需要会员主题才能变好看。
- “主题色”和“高级主题”边界不清。
- 免费用户只能使用 MD3 seed 色，视觉质量不稳定。

新的边界应调整为:

- 高级主题入口所有用户都能进入。
- 免费用户可以使用官方默认主题预设。
- 自定义主题、复制官方主题后编辑、导入导出、完整语义色和组件细调走会员。

### 3.2 视觉问题

当前 seed 色会把强调色传播到太多组件:

- 主按钮高饱和。
- checkbox/switch/slider 强跟色。
- chip 选中态和图标背景变成同一套蓝。
- 页面整体缺少阅读 App 常见的黑白灰主轴。

成熟 App 常见做法不是“一种主题色染全局”，而是:

- 黑白灰作为默认结构。
- 少量低饱和蓝/绿/金作为状态或辅助强调。
- 主操作可以使用炭黑、品牌色或克制强调色。
- 背景、卡片、边框、文字层级优先稳定。

### 3.3 形态问题

当前默认外观缺少面向普通用户的“整体形态”概念。

Google Stitch 面板里的“角半径”不是单个卡片圆角，而是设计系统级 preset。它会影响按钮、输入框、卡片、弹层、选择控件等组件，让整套 UI 看起来属于同一个系统。

项目现有高级主题能调圆角比例，但这更像高级编辑能力。普通用户不应该先理解 72%-145% 的滑杆，官方主题预设应直接给出合理圆角风格。

---

## 4. 新分层

### 4.1 官方主题预设

免费，所有用户可用。

定位:

- 一整套 UI 主题包。
- 放进高级主题体系承接。
- 官方内置、免费使用、不可直接编辑。
- 每套主题都包含浅色和深色配置。
- 负责背景、卡片、按钮、输入框、选择态、列表、导航、圆角、阴影和字体倾向。

免费用户可以直接使用官方预设。会员用户可以复制官方预设后创建自己的高级主题。

示例:

```text
官方主题: Lumina
- 浅色: Lumina Neutral
- 深色: Dark Ink
```

这不是两个割裂主题，而是一套主题里的 `lightConfig` 和 `darkConfig`。

### 4.2 基础配色

免费，放在“应用外观”里。

定位:

- 对应当前“应用外观”里的主题色能力。
- 替代当前“单色 seed 决定大部分 UI”的模式。
- 负责默认外观的主色、强调色、中性色倾向。
- 在未启用高级主题或官方主题预设时，作为默认 App 外观的颜色来源。

建议在 UI 上仍可沿用“主题色”入口，但文案可以调整为:

- “配色”
- “基础配色”
- “主题色与配色”

### 4.3 主题色

保留为轻量概念，但降级为基础配色方案的一部分。

新的理解:

- 主题色不再等于 seed color。
- 主题色只是基础配色方案里的强调色字段。
- 蓝色方案可以有蓝色强调，但不能让所有控件都强蓝。

### 4.4 明暗模式

沿用当前“应用外观”里的明暗模式入口。

关系:

- 明暗模式决定使用当前外观体系的 lightConfig 或 darkConfig。
- 官方主题预设必须成对提供浅色和深色。
- 自定义高级主题也保持现有模型: 一套主题包含浅色配置和深色配置。

### 4.5 组件圆角

圆角不单独作为“主题色”能力。

建议作为主题预设的一部分:

- 官方主题预设内置合理圆角风格。
- 高级主题会员编辑中保留全局圆角比例和组件样式细调。
- 后续可以在官方预设预览里展示角半径风格，但免费用户只使用官方配置，不进入任意编辑。

建议的内部形态档位:

```text
sharp:  利落，8-10dp
balanced: 平衡，12-14dp，推荐默认
soft: 柔和，16-18dp
round: 圆润，20dp+，谨慎使用
```

阅读 App 默认建议使用 `balanced` 或偏轻的 `soft`，不建议大面积胶囊化。

### 4.6 高级主题

会员功能，继续保留。

定位:

- 官方主题预设的承载入口。
- 深度编辑语义色。
- 导入导出。
- 绑定应用背景和阅读器背景。
- 绑定界面字体和阅读字体。
- 复制官方预设后自定义。
- 调整全局圆角比例、组件样式、阴影强度等。

高级主题或官方主题预设启用时优先级仍高于基础配色:

```text
自定义高级主题 > 官方主题预设 > 基础配色 > 默认 fallback
```

---

## 5. 官方主题预设建议

### 5.0 下载稿 `DESIGN.md` 的采纳口径

下载稿 `Lumina Library System` 可作为 Lumina 的视觉参考，但不直接作为 App 默认主题规范照搬。

采纳:

- 现代、克制、以内容和书籍封面为中心的阅读/书库工具气质。
- 8px spacing rhythm、16px 卡片内边距、24px 页面容器边距等密度建议。
- 书籍封面 3:4、封面圆角小于外层卡片、卡片轻阴影和层级化白/灰表面。
- 主操作使用炭黑或深灰，而不是高饱和蓝。
- Manrope 可作为界面字体参考，但不影响阅读器正文字体体系。

修正:

- 下载稿 frontmatter 使用 `#FDF8F8` 粉白表面，但正文描述又使用 `#F3F4F6` 冷灰背景；默认 App 采用冷灰/净白方向，避免粉、黄、脏灰成为全局底色。
- 下载稿正文提到 muted violet accent，但 token 中没有明确 violet；本方案不采用 violet 作为默认强调色，进度和选中态优先使用冷灰蓝/低饱和绿灰。
- `primaryContainer` 不使用深炭黑底配灰字，避免小组件选中态对比不足；默认改为浅灰容器 + 炭黑文字。
- “Buttons & Chips 全 pill”只作为按钮/筛选控件倾向，不扩散到卡片、输入框、导航和弹层。

### 5.1 Lumina

建议作为默认。

定位: 黑白灰阅读 App 基线。

浅色配置: Lumina Neutral

```text
background: #F6F7F9
surface: #FFFFFF
surfaceDim: #EEF1F4
surfaceBright: #FFFFFF
surfaceContainerLowest: #FFFFFF
surfaceContainerLow: #F8FAFC
surfaceContainer: #F2F5F8
surfaceContainerHigh: #EBEFF4
surfaceContainerHighest: #E2E7EE
onSurface: #1C1B1B
onSurfaceVariant: #606773
primary: #1C1B1B
onPrimary: #FFFFFF
primaryContainer: #F1F3F5
onPrimaryContainer: #1C1B1B
secondary: #68717E
onSecondary: #FFFFFF
secondaryContainer: #E6EBF2
onSecondaryContainer: #2D3540
tertiary: #5F6F7A
onTertiary: #FFFFFF
tertiaryContainer: #E6EDF0
onTertiaryContainer: #243139
outline: #D5DAE2
outlineVariant: #E7EBF0
error: #BA1A1A
onError: #FFFFFF
errorContainer: #FFDAD6
onErrorContainer: #93000A
```

视觉来源:

- 参考下载稿的 Modern Minimalist、内容优先、轻阴影和书库信息密度。
- 舍弃下载稿里的粉白 `#FDF8F8` 作为全局底色，改用冷灰页面背景和净白卡片。
- 舍弃下载稿里的 muted violet 描述，默认强调只保留冷灰蓝/绿灰倾向。

行为:

- 主按钮使用炭黑。
- checkbox/switch/slider 使用冷灰或低饱和强调。
- 搜索框使用浅灰底。
- 白底优先，避免粉、黄、脏灰。

深色配置: Dark Ink

```text
background: #111418
surface: #161A20
surfaceDim: #0F1216
surfaceBright: #242A33
surfaceContainerLowest: #0B0D10
surfaceContainerLow: #151A20
surfaceContainer: #1B2129
surfaceContainerHigh: #232B35
surfaceContainerHighest: #2C3540
onSurface: #F4F0EF
onSurfaceVariant: #C4CAD3
primary: #F4F0EF
onPrimary: #111418
primaryContainer: #2B323C
onPrimaryContainer: #F4F0EF
secondary: #C0C7D6
onSecondary: #1E2630
secondaryContainer: #303846
onSecondaryContainer: #E6EBF2
tertiary: #ADC9C0
onTertiary: #19342D
tertiaryContainer: #28443C
onTertiaryContainer: #D5EFE6
outline: #4D5662
outlineVariant: #333B46
error: #FFB4AB
onError: #690005
errorContainer: #93000A
onErrorContainer: #FFDAD6
```

原则:

- 深灰黑背景，不使用纯黑大面积铺底。
- 略浅一点的卡片和浮层，靠层级而不是亮蓝制造区分。
- 柔和边框和白灰文字层级。
- 低饱和蓝灰/绿灰只用于少量状态、进度和辅助强调。

形态:

- 默认使用 `balanced`。
- 书籍封面圆角小于外层卡片。
- 按钮可以保持轻胶囊，但卡片和输入框不宜过圆。

### 5.2 Mono Blue

定位: 黑白蓝，保留现代工具感，但不泛滥。

原则:

- 页面和卡片仍以白/灰为主。
- 蓝色用于链接、状态点、少量选中态。
- 主按钮可以使用深蓝灰或品牌蓝，但 checkbox/switch 不宜全部高饱和。
- 深色配置使用深蓝灰，不使用高饱和亮蓝铺满组件。
- 形态建议 `balanced` 或 `sharp`。

### 5.3 Ink Green

定位: 黑白绿，适合阅读、完成状态、健康感。

原则:

- 绿色只做状态和轻强调。
- 主结构仍是白底/灰边框/黑文字。
- 深色配置使用墨绿灰，不做大面积翠绿。
- 形态建议 `balanced`。

### 5.4 Selune Warm

定位: 暖灰金，保留项目已有 Selune 气质。

原则:

- 可以有暖意，但不能明显发黄、发粉、发旧。
- 适合阅读器纸感和品牌预设，不建议把所有页面染成暖底。
- 深色配置使用暖夜阅读风格，但仍保持文本对比。
- 形态建议 `soft`，但控制在阅读 App 的克制范围内。

---

## 6. 数据模型建议

这块按长期规划处理，但不建议完全丢弃旧主题色数据。旧版本只存了一个 seed color，确实无法表达新的基础外观和完整语义色；不过可以做一次性近似映射，避免用户已选的蓝/绿/暖色在升级后静默丢失。

兼容策略:

- 读取不到新 id: 回落到默认官方主题 `official:lumina` 和默认基础配色 `lumina-neutral`。
- 旧 seed 是蓝色系: 映射到 `mono-blue`。
- 旧 seed 是绿色系: 映射到 `ink-green`。
- 旧 seed 是 `Selune` / 暖金系: 映射到 `selune-warm`。
- 旧 seed 是纯白或无法识别: 映射到 `lumina-neutral`。
- 映射只用于初始化新 key；后续主路径不再依赖 `appSeedColorPreferenceKey`。

### 6.1 官方主题预设模型

新增官方主题预设 id:

```dart
enum AppOfficialThemePresetId {
  lumina,
  monoBlue,
  inkGreen,
  seluneWarm,
}
```

或使用字符串 id:

```text
official:lumina
official:mono-blue
official:ink-green
official:selune-warm
```

建议复用高级主题承载模型:

```text
AppOfficialThemePreset
- id
- label
- description
- previewSwatches
- lightConfig
- darkConfig
- defaultBaseColorSchemeId
- defaultShapeSchemeId
- editable: false
- requiresMembershipToUse: false
- requiresMembershipToCopyOrEdit: true
```

默认规则:

- 没有官方主题 key: 使用 `official:lumina`。
- 新 key 为空或无法识别: 使用 `official:lumina`。
- 官方主题可以在高级主题入口中展示和启用。
- 官方主题不可直接编辑；复制为自定义高级主题后进入会员能力。
- 官方主题不应混入自定义高级主题列表的持久化数组；建议由内置 registry 提供，active id 支持 `official:*` 前缀。

### 6.2 新基础配色模型

新增基础配色方案 id:

```dart
enum AppBaseColorSchemeId {
  luminaNeutral,
  monoBlue,
  inkGreen,
  seluneWarm,
}
```

或使用字符串 id:

```text
lumina-neutral
mono-blue
ink-green
selune-warm
```

新增 provider:

```text
appBaseColorSchemeProvider
```

新增持久化 key:

```text
app.baseColorSchemeId
```

默认规则:

- 没有新 key: 使用 `lumina-neutral`。
- 新 key 为空或无法识别: 使用 `lumina-neutral`。
- 旧 `appSeedColorPreferenceKey` 只在首次初始化新 key 时读取并映射。
- 如需清理旧数据，可由偏好修复服务在新 key 写入成功后删除。

### 6.3 基础配色数据结构

```text
AppBaseColorScheme
- id
- label
- swatch
- light ColorScheme
- dark ColorScheme
- accent role
- neutral role
- selection role
```

这样“主题色”入口展示的是基础配色，而不是孤立颜色。基础配色不负责背景图、字体绑定、全局圆角和完整组件样式。

### 6.4 组件形态模型

组件形态先作为官方主题预设和高级主题的一部分，不单独放进“应用外观”的基础配色入口。

建议内部保留离散 preset:

```dart
enum AppBaseShapeSchemeId {
  sharp,
  balanced,
  soft,
  round,
}
```

对应当前已有字段:

```text
AppBaseShapeScheme -> AppAdvancedThemeComponentStyle
- globalRadiusScale
- cardStyle
- buttonStyle
- inputStyle
- overlayStyle
- navigationStyle
- switchStyle
```

普通用户使用官方主题预设中的形态；会员用户在高级主题编辑器中细调。

### 6.5 激活优先级

```text
自定义高级主题 > 官方主题预设 > 基础配色 > 默认 fallback
```

解释:

- 启用官方主题预设时，它会覆盖基础配色。
- 未启用官方主题或高级主题时，应用外观里的基础配色生效。
- 明暗模式只决定使用 lightConfig 或 darkConfig，不改变主题来源。
- UI 上必须明确提示: 如果当前启用了主题预设或高级主题，基础配色暂不参与当前外观渲染。

---

## 7. Flutter 落地路径

### Phase 1: 主题来源模型

目标: 一次性建立“官方主题预设 + 基础配色”的主题来源模型，避免先做基础配色后又被官方默认主题覆盖造成用户困惑。

涉及:

- `lib/app/theme/app_theme_palette.dart`
- `lib/app/theme/app_theme_seed_provider.dart`
- `lib/app/preferences/app_preferences_service.dart`
- `lib/app/theme/app_theme.dart`
- `lib/app/theme/app_component_theme_tokens.dart`
- `lib/features/mine/application/advanced_theme_provider.dart`
- `lib/features/mine/application/advanced_theme_service.dart`

建议:

- 新增 `AppThemeSource` 或等价模型，表达 `customAdvancedThemeId`、`officialPresetId`、`baseColorSchemeId`。
- active id 支持 `custom:*` / `official:*` 或通过明确字段区分，避免官方预设被误当作用户自定义主题。
- 新用户默认 `official:lumina`，同时写入默认 `baseColorSchemeId = lumina-neutral`。
- 新增 `AppBaseColorSchemeId` 和 `AppBaseColorSchemeOption`。
- 新增 `appBaseColorSchemeProvider`。
- 默认基础配色 id 为 `lumina-neutral`。
- 不再以旧 seed color 作为默认外观主模型。
- 读取不到新 id 时回落 `lumina-neutral`；首次迁移时按旧 seed 做近似映射。
- 先保留旧 `appSeedColorProvider` 文件也可以，但不再作为主路径。
- 自定义高级主题继续通过 active appearance snapshot 覆盖官方主题和基础配色。

验收:

- 新用户默认启用 `official:lumina`，而不是只使用 `lumina-neutral` base color。
- Flutter 组件样板页不再出现大面积蓝。
- 当前书架页面仍接近白底、轻搜索框。
- 搜索、阅读记录、设置列表没有明显颜色跳出。
- 旧 seed 蓝/绿/暖色至少能映射到对应基础配色或官方主题倾向。

### Phase 2: 应用外观入口调整

目标: 降低用户误解。

涉及:

- `lib/features/mine/presentation/appearance_page.dart`
- `lib/features/mine/presentation/appearance_page_view.dart`

建议:

- “主题色”改为“基础配色”或“主题色与配色”。
- 说明文案强调“影响默认外观的强调色和组件配色”。
- 明暗模式继续保留在应用外观。
- 高级主题入口说明“官方主题和高级主题启用后会覆盖基础配色”。
- 当当前外观来源是 `official:*` 或自定义高级主题时，基础配色入口展示“当前被主题预设覆盖”，允许用户修改备用基础配色，但不暗示立即生效。

验收:

- 用户能理解基础配色和高级主题的区别。
- 入口不暗示免费用户只能换一个 seed 颜色。

### Phase 3: 官方主题预设

涉及:

- 高级主题列表页。
- 高级主题服务。
- 官方主题预设数据。
- 权限判断。

建议:

- 新增四套官方主题预设: `lumina`、`mono-blue`、`ink-green`、`selune-warm`。
- 每套官方主题都包含 `lightConfig` 和 `darkConfig`。
- 所有用户可进入高级主题入口并启用官方主题。
- 非会员不能创建、复制编辑、导入导出自定义高级主题。
- 官方主题预设启用后覆盖基础配色。
- Lumina 的 light/dark token 以本文 5.1 为准，不直接照搬下载稿 `DESIGN.md` 的粉白 surface 和未落地 violet accent。

验收:

- 新用户默认使用官方主题 `lumina`。
- Lumina 的浅色为 Lumina Neutral，深色为 Dark Ink。
- Blue/Green/Warm 都是完整 UI 主题，不是 seed 染色。
- 免费用户能使用官方主题，但不能编辑其内部字段。

### Phase 4: 组件 token 与圆角收敛

目标: 让按钮、输入框、选择控件、列表、浮层和业务卡片符合当前主题预设。

涉及:

- `AppTheme.build`
- `app_component_theme_tokens.dart`
- `foundation` 组件
- `AppAdaptiveMetrics.cardRadius`
- 书架、搜索、设置等业务页面的硬编码圆角

建议:

- FilledButton 不一定总用 `primary`，默认 Lumina 可用炭黑。
- tonal button 用 `primaryContainer`，但低饱和。
- input filled/search 背景要稳定。
- FilterChip/Checkbox/Switch/Slider 的选中态不要全跟高饱和 primary。
- 业务卡片优先读取 `AppComponentThemeTokens.card.radius`。
- 封面圆角使用外层卡片圆角的 0.70-0.80 倍。
- 官方主题预设使用离散 shape preset，不给普通用户暴露连续圆角滑杆。

验收:

- 组件样板页通过。
- light/dark 都不突兀。
- 小屏没有按钮文字挤压。
- 切换官方主题后，常用组件圆角和卡片形态一致变化。
- 页面中不再出现明显脱离主题的硬编码圆角。

### Phase 5: 高级主题边界复核

目标: 保证会员功能不被削弱，同时默认免费外观变好。

建议:

- 自定义高级主题继续覆盖官方主题预设和基础配色。
- 官方主题预设免费使用。
- 复制官方主题、创建自定义主题、导入导出、完整语义色编辑、组件样式细调走会员。
- 高级主题入口所有用户可进入，但会员能力要明确展示权限状态。

---

## 8. UI 入口建议

建议结构:

```text
应用外观
- 明暗模式
- 基础配色
  - 净白 / Lumina Neutral
  - 黑白蓝 / Mono Blue
  - 黑白绿 / Ink Green
  - 暖灰 / Selune Warm
- 主题预设与高级主题
  - 当前启用状态
  - 进入主题预设页
- 应用界面字体
- 底部菜单
- 其他设置
```

主题预设页建议结构:

```text
主题预设与高级主题
- 官方主题
  - Lumina
  - Mono Blue
  - Ink Green
  - Selune Warm
- 我的高级主题
  - 创建主题: 会员
  - 复制官方主题后编辑: 会员
  - 导入/导出: 会员
```

文案建议:

```text
基础配色
调整未启用主题预设时的主色、强调色和中性色倾向。

主题预设与高级主题
官方主题可直接使用。启用后会覆盖基础配色；自定义编辑、导入导出和完整组件样式需要会员。
```

---

## 9. 与 Lumina 文档关系

现有文档:

```text
docs/ui_ux/lumina_reading_ui_optimization_plan_2026_06_18.md
外部下载稿 DESIGN.md
```

定位调整:

- 保留为 Lumina 视觉参考和阅读 UI 优化方案。
- 下载稿 `DESIGN.md` 保留为外部视觉参考，不直接作为 Flutter token 源。
- 不再单独承担“默认外观体系”和“主题色入口重构”的完整设计。
- 本文档负责默认外观、官方主题预设、基础配色和高级主题边界。

Lumina 的新定位:

```text
Lumina = 官方默认主题预设，建议作为新用户默认。
Lumina Neutral = Lumina 的浅色配置。
Dark Ink = Lumina 的深色配置。
复制 Lumina 后编辑 = 会员高级主题能力。
下载稿 DESIGN.md = Lumina 的视觉方向参考，不是最终 ColorScheme。
```

---

## 10. 验收清单

- [ ] 默认 App 不再出现大面积高饱和蓝。
- [ ] 新用户默认启用官方主题 `lumina`。
- [ ] Lumina 同时具备浅色 `Lumina Neutral` 和深色 `Dark Ink`。
- [ ] 组件样板页在 Lumina 下比当前主题更接近成熟阅读 App。
- [ ] 书架、搜索、阅读记录、设置页保持白底优先和轻层级。
- [ ] 主题色/基础配色入口文案不误导用户。
- [ ] 官方主题和自定义高级主题启用后仍优先覆盖基础配色。
- [ ] 免费用户能进入主题预设页并使用官方主题。
- [ ] 非会员不能复制编辑、创建自定义主题、导入导出或细调组件样式。
- [ ] 切换官方主题后，颜色、圆角、按钮、输入框、卡片和弹层风格一致变化。
- [ ] 旧 seed color 数据不存在或无法识别时，会回落到 `official:lumina` 和 `lumina-neutral`。
- [ ] 旧 seed 蓝/绿/暖色能初始化映射到 `mono-blue` / `ink-green` / `selune-warm`。
- [ ] light/dark 都通过基础可读性检查。
- [ ] 小屏、平板、桌面没有控件挤压或文字溢出。

---

## 11. 建议下一步

建议按两条线并行推进:

1. 基于当前 Flutter 组件样板页，对比当前主题和 Lumina 组件样板。
2. 以本文 5.1 的 Lumina Neutral + Dark Ink 作为官方主题 `lumina` 的第一版 token。
3. 新增主题来源模型、基础配色 id/provider/persistence，并做旧 seed 一次性映射。
4. 在高级主题体系中新增官方主题预设 registry，先让所有用户可进入并使用官方主题。
5. 再收敛组件 token、圆角 preset 和业务页面硬编码圆角。

默认外观和官方主题预设要一起考虑: 默认外观负责第一印象，官方主题预设负责承接整套 UI 风格；会员高级主题负责深度编辑能力。
