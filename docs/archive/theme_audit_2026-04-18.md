# 主题体系审计（2026-04-18）

## 1. 范围

本次审计覆盖三块：

- `主题模式`
- `主题颜色`
- `高级主题`

以及对比历史提交 `194d467abe082621586d504a582b5146c0928f23`，调查“卡片边框从清晰变淡”的原因。

## 2. 当前实现总览

### 2.1 基础主题

基础主题由三部分组成：

- `ThemeMode`
- `seedColor`
- `ThemeData / ColorScheme`

代码入口：

- `lib/app/app.dart`
  - 读取 `appThemeModeProvider`
  - 读取 `appSeedColorProvider`
  - 生成 `lightScheme / darkScheme`
  - 传给 `AppTheme.build(...)`
- `lib/app/theme/app_theme_provider.dart`
  - 管理 `ThemeMode` 持久化
- `lib/app/theme/app_theme_seed_provider.dart`
  - 管理 `seedColor` 持久化
- `lib/app/theme/app_theme_palette.dart`
  - 负责 `ColorScheme` 生成
- `lib/app/theme/app_theme.dart`
  - 负责 `ThemeData` 组装

### 2.2 外观页入口

外观页当前已经把三块入口放在一起：

- `lib/features/mine/presentation/appearance_page.dart`
  - `模式`
  - `颜色`
  - `高级主题`

当前职责是清晰的：

- `模式`：直接切换 `ThemeMode`
- `颜色`：直接切换 `seedColor`
- `高级主题`：只显示摘要并跳转管理页

这部分与 `docs/advanced_theme_plan.md` 中的职责设计一致。

### 2.3 高级主题

高级主题不是替换基础主题，而是“运行时覆盖层”。

代码入口：

- `lib/domain/entities/app_advanced_theme.dart`
  - 高级主题实体
  - 浅色 / 深色双模式配置
  - 颜色、壁纸、底栏图集、封面图集字段
- `lib/features/mine/application/advanced_theme_service.dart`
  - 主题列表持久化
  - 当前启用主题 id 持久化
  - 导入导出
- `lib/features/mine/application/advanced_theme_provider.dart`
  - 当前启用主题 provider
- `lib/app/theme/app_advanced_theme_tokens.dart`
  - 把基础 `ColorScheme` + 高级主题，解析成运行态 palette/backdrop
- `lib/features/mine/presentation/advanced_theme_list_page.dart`
  - 应用 / 停用 / 管理入口
- `lib/features/mine/presentation/advanced_theme_editor_page.dart`
  - 创建 / 编辑 / 预览

## 3. 三块能力的打通情况

### 3.1 主题模式

已打通：

- 全局状态：`appThemeModeProvider`
- 持久化：`SharedPreferences`
- 应用入口：`MaterialApp.router.themeMode`
- UI 入口：`appearance_page.dart`

结论：

- 这一块是完整闭环，属于“已通”。

### 3.2 主题颜色

已打通：

- 全局状态：`appSeedColorProvider`
- 持久化：`SharedPreferences`
- 应用入口：`buildAppLightColorScheme / buildAppDarkColorScheme`
- UI 入口：`appearance_page.dart`

补充说明：

- 当前有预置色板，包含 `霁雪白 / Selune / 焰阳橙 / 松烟绿 / 澄海蓝` 等。
- 基础主题真正控制的是 `ColorScheme`，不是单独某个局部颜色。

结论：

- 这一块也是完整闭环，属于“已通”。

### 3.3 高级主题

已打通：

- 主题列表存储
- 当前启用主题 id
- 列表页应用 / 停用
- 编辑器保存
- 运行态解析层 `resolveAdvancedThemePalette / resolveAdvancedThemeBackdrop`
- 壁纸运行态背景
- 底栏图集覆盖
- 封面图集 fallback

当前已接入运行态的主页面 / 主模块：

- `lib/app/shell_scaffold.dart`
  - 底栏背景、描边、图标视觉联动
- `lib/features/mine/presentation/mine_page.dart`
- `lib/features/discover/presentation/discover_page.dart`
- `lib/features/bookshelf/presentation/bookshelf_page.dart`
- `lib/features/search/presentation/search_page.dart`
- `lib/features/book/presentation/book_detail_page.dart`
- `lib/features/search/presentation/widgets/search_book_card.dart`
- `lib/features/reader/presentation/reading_records_page.dart`
- `lib/features/reader/presentation/reader_catalog_sheet.dart`
- `lib/features/mine/presentation/bookmarks_page.dart`
- `lib/features/mine/presentation/cache_management_page.dart`
- `lib/app/widgets/resolved_book_cover.dart`
  - 封面图集 fallback

结论：

- 高级主题“能用”，但还不是“全局一致生效”。

## 4. 当前未打通 / 半打通项

### 4.1 高级主题没有回写到全局 `ThemeData`

当前高级主题只影响“手动接了 palette/backdrop 的页面”。

没有打到的层：

- `AppTheme.build(...)` 本身
- `CardTheme`
- `InputDecorationTheme`
- `DialogTheme`
- `ListTileTheme`
- 其他直接依赖 `Theme.of(context).colorScheme` 且没有接高级主题解析层的页面

结果：

- 同一个高级主题下，不同页面的一致性仍然不够
- 某些二级页仍只跟随基础主题，不跟随高级主题

这是当前最核心的“未通项”。

### 4.2 高级主题字段有存储，但运行态并未全部消费

以下字段目前能在编辑器里编辑、能存储，但运行态解析层没有真正统一消费：

- `secondaryColorValue`
- `primaryContainerColorValue`
- `buttonTextColorValue`
- `outlineColorValue`
- `shadowColorValue`

现状：

- 它们主要存在于编辑器和预览里
- 但 `resolveAdvancedThemePalette(...)` 当前没有把这些字段暴露成统一运行态 token
- 真正业务页面也没有稳定依赖这些字段

结论：

- 这是“数据层已做，但页面层未通”的第二类问题。

### 4.3 高级主题接入面仍不均匀

当前明显偏“首页级页面”优先，很多设置 / 管理页仍主要使用基础主题：

- 关于页
- 系统设置页
- 反馈页
- 管理类页
- 其他未主动 watch `activeAdvancedThemeProvider` 的页面

结论：

- 高级主题目前更像“主页面风格增强”，还不是“全应用皮肤层”。

### 4.4 阅读器正文主题仍然独立

这属于设计上的刻意隔离，不是 bug。

现状：

- 阅读器正文页没有纳入这套高级主题运行态
- 仍走阅读器自己的设置体系

结论：

- 这是“暂不接入”，不是“漏接”。

## 5. 卡片边框变淡的调查结论

### 5.1 对比结果

历史提交 `194d467abe082621586d504a582b5146c0928f23` 中，纯白主题的浅色 `outlineVariant` 来源是：

- `#E6E6E6`

当前版本纯白主题浅色 `outlineVariant` 变成了：

- `#E9EDF2`

虽然看起来差异不大，但当前项目大量边框写法又是：

- `outlineVariant.withValues(alpha: 0.35)`
- `outlineVariant.withValues(alpha: 0.4)`
- `outlineVariant.withValues(alpha: 0.45)`
- `outlineVariant.withValues(alpha: 0.18)`

于是边框实际落地时被做了两次“变轻”：

1. 基础色本身比旧版更浅、更偏冷
2. 页面层继续乘透明度

### 5.2 不是单点问题，而是两层叠加

#### 原因 A：基础边框色变浅

位置：

- `lib/app/theme/app_theme_palette.dart`

纯白主题浅色边框基准从旧版 `#E6E6E6` 变成了现在的 `#E9EDF2`。

#### 原因 B：大量页面使用半透明边框

项目里大量局部容器没有直接使用 `CardTheme` 默认边框，而是自己写：

- `Border.all(color: colorScheme.outlineVariant.withValues(alpha: ...))`

并且很多 alpha 在：

- `0.18`
- `0.35`
- `0.4`
- `0.45`

这在白底 / 浅灰底上会非常容易“发虚”。

#### 原因 C：高级主题运行态默认边框也偏保守

位置：

- `lib/app/theme/app_advanced_theme_tokens.dart`

当高级主题没有显式配置 `cardBorderColorValue` 时，默认 fallback 是：

- `colorScheme.outlineVariant`

而具体页面在使用 `palette.cardBorderColor` 时，很多地方又会继续加透明度。

这会让“高级主题未单独配置边框色”的场景也偏淡。

### 5.3 为什么你会感觉“有时看不到”

因为现在不是所有页面都用同一套边框策略：

- 有的用 `CardTheme` 的 `0.45`
- 有的局部写 `0.55`
- 有的局部写 `0.35`
- 有的高级主题页面再套一层 palette fallback

所以不同页面、不同主题色、不同背景层级下，边框体感差异会被放大，表现成：

- 有些卡片正常
- 有些卡片偏淡
- 有些几乎看不见

## 6. 本次已做的低风险修复

已调整：

- 纯白主题浅色 `outlineVariant`
  - 从 `#E9EDF2`
  - 调回 `#E6E6E6`

修改文件：

- `lib/app/theme/app_theme_palette.dart`
- `test/app/theme/app_theme_test.dart`

这次修复的目标是：

- 先恢复默认白色主题下最基础的边框可见度
- 不直接改动大量页面局部样式，避免一次性牵动太大

## 7. 后续建议清单

建议按下面顺序收敛：

1. 先统一“边框 token 策略”
2. 再补高级主题未消费字段
3. 最后决定是否让高级主题部分回写全局 `ThemeData`

### 7.1 边框收敛

建议新增统一边框语义，而不是继续每个页面手写 alpha：

- `subtleBorder`
- `defaultBorder`
- `strongBorder`

否则边框问题会反复出现。

### 7.2 高级主题 token 补齐

建议把以下字段补进运行态统一 token：

- `primaryContainer`
- `outline`
- `shadow`
- `buttonText`
- 必要时补 `secondary`

这样编辑器里改动的内容，运行态才真正可见。

### 7.3 明确“高级主题是否要部分写回全局 ThemeData”

如果希望高级主题更像全局皮肤，建议至少考虑以下几项回写：

- `cardTheme`
- `inputDecorationTheme`
- `dialogTheme`
- `dividerTheme`

否则高级主题会长期停留在“部分页面有效”的状态。

## 8. 结论

当前状态可以总结成三句话：

- `主题模式`：已完整打通
- `主题颜色`：已完整打通
- `高级主题`：已可用，但仍是“页面级覆盖”，不是“全局主题层”

卡片边框变淡的主因也已经确认：

- 基础 `outlineVariant` 变浅
- 局部页面大量继续叠加低 alpha
- 高级主题默认边框 fallback 也偏保守

本次先做了第一步低风险修复，后面如果继续推进，建议优先把“边框 token”统一掉。
