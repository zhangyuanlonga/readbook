# 颜色层与高级主题层作用域映射（2026-04-18）

## 1. 目的

这份文档只做一件事：

- 把当前 `颜色` 和 `高级主题` 各自控制什么梳理清楚

重点不是讨论入口，而是回答：

- `颜色` 现在到底覆盖了哪些地方
- `高级主题` 现在有哪些设置项
- 哪些已经重叠
- 哪些应该归入新版高级主题里的“基础主题层”

## 2. 当前两层分别是什么

## 2.1 颜色层

当前“颜色”本质不是一个小卡片，而是一层全局基础主题配置。

核心实现：

- `appSeedColorProvider`
- `buildAppLightColorScheme(...)`
- `buildAppDarkColorScheme(...)`
- `MaterialApp.theme / darkTheme`

代码位置：

- [app_theme_seed_provider.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/theme/app_theme_seed_provider.dart)
- [app_theme_palette.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/theme/app_theme_palette.dart)
- [app.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/app.dart)
- [appearance_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/appearance_page.dart)

### 它的真实特点

- 不只是“选个主色”
- 实际上是在生成全局基础 `ColorScheme`
- 所有直接依赖基础 `Theme.of(context).colorScheme` 的页面都会被它影响

所以它的覆盖域天然很大。

## 2.2 高级主题层

当前“高级主题”本质是一层运行态覆盖系统。

核心实现：

- `AppAdvancedTheme`
- `AppAdvancedThemeColors`
- `resolveAdvancedThemePalette(...)`
- `resolveAdvancedThemeBackdrop(...)`

代码位置：

- [app_advanced_theme_tokens.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/theme/app_advanced_theme_tokens.dart)
- [app_advanced_theme.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/domain/entities/app_advanced_theme.dart)
- [advanced_theme_editor_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/advanced_theme_editor_page.dart)

### 它的真实特点

- 已经不是“局部改一个色”
- 已经具备较完整的主题设置项体系
- 但它当前仍建立在“颜色层生成的基础主题”之上

## 3. 颜色层当前覆盖域

颜色层当前通过基础 `ColorScheme` 影响：

### 3.1 全局基础主题

- App 根主题的浅色/深色主题
- AppBar、CardTheme、InputDecorationTheme、OutlinedButtonTheme 等基础组件

关键入口：

- [app.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/app.dart#L37)
- [app_theme.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/theme/app_theme.dart)

### 3.2 大量仍直接读 `colorScheme` 的页面

当前仍直接吃基础 `colorScheme` 的典型项包括：

- `primary`
- `onPrimary`
- `primaryContainer`
- `onPrimaryContainer`
- `surfaceContainer*`
- `outlineVariant`

这类页面非常多，典型分布：

- 认证相关页
- 设置相关页
- 反馈 / 关于
- 部分书籍详情页
- 阅读记录页
- 目录弹层
- 阅读器外围弹层
- 各类管理页 / 工具页

从引用看，当前这层尤其重度控制：

- 选中态 / badge / pill
- 输入框和表单
- 大量卡片边框
- 大量容器底色

## 4. 高级主题层当前设置项

当前高级主题颜色项实际已经包括：

- `primary`
- `secondary`
- `noticeAccent`
- `noticeSurface`
- `primaryContainer`
- `background`
- `surface`
- `searchFieldBackground`
- `elevatedSurface`
- `card`
- `cardText`
- `cardBorder`
- `iconBackground`
- `textPrimary`
- `textSecondary`
- `buttonText`
- `outline`
- `shadow`
- `wallpaperOverlay`

资源项包括：

- `wallpaperPath`
- `wallpaperOverlayOpacity`
- `bottomNavGalleryId`
- `coverGalleryId`

这些字段定义在：

- [app_advanced_theme.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/domain/entities/app_advanced_theme.dart)

## 5. 高级主题层当前已生效的运行态字段

当前 `ResolvedAdvancedThemePalette` 已经正式暴露并参与运行态的字段有：

- `backgroundColor`
- `surfaceColor`
- `searchFieldBackgroundColor`
- `elevatedSurfaceColor`
- `cardColor`
- `cardTextColor`
- `cardBorderColor`
- `outlineColor`
- `iconBackgroundColor`
- `textPrimaryColor`
- `textSecondaryColor`
- `primaryColor`
- `primaryContainerColor`
- `secondaryColor`
- `buttonTextColor`
- `shadowColor`
- `noticeAccentColor`
- `noticeSurfaceColor`

代码位置：

- [app_advanced_theme_tokens.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/theme/app_advanced_theme_tokens.dart#L5)

这说明高级主题已经具备承载“基础主题层 + 精细覆盖层”的结构基础。

## 6. 高级主题层当前真实生效页面

当前已经明确接入高级主题运行态的页面主要有：

- 书架页
- 发现页
- 搜索页
- 我的页
- 底部导航栏
- 阅读记录页背景层
- 高级主题列表预览
- 高级主题编辑器预览

以及封面 fallback 链路：

- 书架
- 发现
- 搜索结果卡
- 书籍详情页封面
- 阅读记录页
- 目录弹层
- 书签页
- 缓存页

## 7. 两层当前重叠在哪

当前重叠最明显的是：

### 7.1 主强调体系

颜色层控制：

- `primary`
- `onPrimary`
- `primaryContainer`
- `onPrimaryContainer`

高级主题层也已经有：

- `primaryColor`
- `primaryContainerColor`
- `buttonTextColor`
- `secondaryColor`

这意味着：

- 当前“颜色”已经在做一套主题基础强调体系
- 高级主题又已经开始提供自己的强调体系

这就是最典型的重叠区。

### 7.2 大面积表面/容器体系

颜色层控制：

- `surface`
- `surfaceContainerLow`
- `surfaceContainerHigh`
- `surfaceContainerHighest`

高级主题层已有：

- `backgroundColor`
- `surfaceColor`
- `searchFieldBackgroundColor`
- `elevatedSurfaceColor`
- `cardColor`

这说明高级主题已经具备接管“全局大面积容器语义”的基础，只是当前仍有大量页面没有切过来。

### 7.3 边框体系

颜色层现在大量控制：

- `outlineVariant`
- `outline`

高级主题层已有：

- `cardBorderColor`
- `outlineColor`

再加上新增的边框 token：

- [app_border_tokens.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/theme/app_border_tokens.dart)

这说明边框体系也已经具备收口条件。

## 8. 颜色层与高级主题层的当前断层

断层主要有两种：

### 8.1 页面还没切到高级主题运行态

很多页面仍直接读基础 `colorScheme`，所以：

- 颜色层覆盖很大
- 高级主题层虽然有字段，但没完全打过去

### 8.2 用户心智断层

用户看到的是：

- 外观里有一个“颜色”
- 还有一个“高级主题”

但代码真实关系是：

- 颜色层先生成了基础主题
- 高级主题再做覆盖

所以用户会感觉像两套主题系统。

## 9. 新版该怎么拆

如果按你现在真正想要的方向，新版应该把高级主题理解成两层：

## 9.1 基础主题层

这层承接原来颜色层的大覆盖域能力。

建议归入这一层的能力：

- 主强调色
- 辅助强调色
- 强调背景/容器色
- 大面积背景
- 次级背景
- 搜索框背景
- 高层级背景
- 基础文字层级
- 基础边框层级

也就是：

- 不是一堆“具体哪一块小卡片”的颜色
- 而是能大范围决定外观风格的颜色能力

## 9.2 精细覆盖层

这层保留当前高级主题原本擅长的能力：

- 卡片背景
- 卡片文字
- 卡片边框
- 图标底色
- 提示强调
- 提示底色
- 按钮文字
- 阴影
- 壁纸
- 底栏图集
- 封面图集

## 10. 受控范围下的开发计划

为了不无限延伸，建议只做下面 3 步：

### 第一步：完成作用域映射确认

- 确认哪些现有 `colorScheme` 能力要归入高级主题的基础主题层
- 确认哪些保留为精细覆盖层

### 第二步：调整高级主题编辑器结构

- 不加“几个颜色方案”
- 继续以“具体设置项手动自定义”为主
- 但分组上明确区分：
  - 基础主题层
  - 精细覆盖层

### 第三步：逐步把外层页面的基础主题能力切到高级主题运行态

- 只做外层页面
- 不碰阅读器正文主题

## 11. 明确不做什么

本轮不做：

- 不改主题模式
- 不改阅读器正文主题体系
- 不改高级主题名称
- 不新增官方预设主题体系
- 不把色板方案搬进高级主题
- 不重写底层存储模型

## 12. 一句话结论

当前“颜色”真正有价值的地方，不是入口，而是它背后那层大覆盖域主题能力。

新版方向应该是：

- 让高级主题吸收这层大覆盖域能力
- 变成真正的“基础主题层 + 精细覆盖层”
- 而不是把原来的颜色入口搬个位置继续存在
