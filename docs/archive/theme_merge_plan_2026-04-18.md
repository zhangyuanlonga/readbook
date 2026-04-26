# 颜色入口并入高级主题方案（2026-04-18）

## 1. 本次讨论结论

这次只确定两件事：

1. `我的 -> 外观 -> 颜色` 卡片移除  
   也就是外观页不再单独提供“颜色”入口。
2. 颜色相关能力并入 `高级主题`  
   后续在“新增高级主题 / 编辑高级主题”里包含原来颜色卡片承载的内容。

同时明确：

- `高级主题` 名称不改
- 不改成“我的主题”
- `高级主题` 目前默认空状态保留，这是合理的
- `主题模式` 不属于这次合并范围

## 2. 不改什么

为了控制范围，本次明确不做：

- 不改 `主题模式`
- 不把 `高级主题` 改名
- 不新增“默认主题”概念
- 不新增“我的主题”概念
- 不扩展成新的官方主题体系
- 不顺手改阅读器正文主题
- 不为了这次入口合并去重写底层模型

开发时不额外延伸的判断标准：

- 只做“颜色入口移除 + 颜色能力并入高级主题新增/编辑”所必需的改动
- 不是这两件事直接依赖的内容，一律不展开

## 3. 当前实现梳理

## 3.1 主题模式

当前实现：

- `浅色 / 深色 / 跟随系统`
- 独立 provider：`appThemeModeProvider`
- 页面入口：`外观 -> 模式`
- 全局生效：`MaterialApp.router.themeMode`

代码位置：

- [app_theme_provider.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/theme/app_theme_provider.dart)
- [appearance_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/appearance_page.dart)
- [app.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/app.dart)

这部分本轮不改。

## 3.2 颜色

当前实现：

- 独立 provider：`appSeedColorProvider`
- 持久化 key：`app.seedColor`
- 页面入口：`外观 -> 颜色`
- 作用：生成全局基础 `ColorScheme`

代码位置：

- [app_theme_seed_provider.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/theme/app_theme_seed_provider.dart)
- [app_theme_palette.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/theme/app_theme_palette.dart)
- [appearance_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/appearance_page.dart)

当前问题：

- 它是单独入口
- 但用户实际理解上，它已经和高级主题存在能力重叠
- 继续独立摆放，会让用户理解成：
  - 颜色是一个系统
  - 高级主题又是另一个系统

## 3.3 高级主题

当前实现：

- 独立列表存储：`app.advancedThemes`
- 独立启用 id：`app.advancedThemes.activeId`
- 页面入口：`外观 -> 高级主题`
- 当前默认状态可以为空
- 支持：
  - 浅色/深色双配置
  - 颜色语义
  - 壁纸
  - 壁纸遮罩
  - 底栏图集
  - 封面图集
  - 导入 / 导出 / 复制

代码位置：

- [advanced_theme_provider.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/application/advanced_theme_provider.dart)
- [advanced_theme_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/application/advanced_theme_service.dart)
- [app_advanced_theme_tokens.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/theme/app_advanced_theme_tokens.dart)
- [advanced_theme_list_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/advanced_theme_list_page.dart)
- [advanced_theme_editor_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/advanced_theme_editor_page.dart)

这次的方向不是改名，而是让它承接原“颜色”入口的能力。

## 3.4 当前作用域与设置项调查结论

结合当前代码，现有两层能力可以先这样理解：

### 颜色层当前的真实特点

- 它虽然在 UI 上只是一个“颜色卡片”
- 但底层实际上是：
  - `appSeedColorProvider`
  - `buildAppLightColorScheme / buildAppDarkColorScheme`
  - 全局 `ColorScheme`
- 所以它影响的不是一两个点，而是大量直接依赖基础 `colorScheme` 的页面

这也是它“覆盖域大”的原因。

### 高级主题当前的真实特点

它已经不是单点换色了，而是有完整设置项体系。

当前主要设置项包括：

- 强调色
- 页面背景
- 次级背景
- 搜索框背景
- 高层级背景
- 卡片背景
- 卡片文字
- 卡片边框
- 通用边框
- 图标底色
- 主要文字
- 辅助文字
- 标签/状态相关颜色
- 按钮文字
- 阴影
- 壁纸与遮罩
- 底栏图集
- 封面图集

也就是说，高级主题已经有“精细调主题”的基础了。

### 当前真正的问题

问题不在于高级主题没有颜色能力，而在于：

- 颜色层还在外部单独存在
- 而且它先生成了一层大范围基础主题
- 高级主题再在其上做部分覆盖

所以用户看起来会像是：

- 先改一套主题
- 再叠另一套主题

这就是这次要合并的根本原因。

## 4. 本次要实现的产品变化

## 4.1 外观页

外观页最终保留：

- `模式`
- `高级主题`
- 其他外观能力（字体、底栏、背景库等）

外观页移除：

- `颜色`

也就是：

- `我的 -> 外观 -> 颜色` 卡片下线

## 4.2 高级主题页

高级主题页保持现有定位：

- 仍叫 `高级主题`
- 仍允许为空
- 仍由会员体系控制

这里不引入新的“默认主题”项。

## 4.3 新增 / 编辑高级主题

新增和编辑高级主题时，补齐原“颜色”入口里的能力。

也就是说，后续如果用户想改颜色，不再先去外观页点“颜色”，而是：

1. 进入 `高级主题`
2. 新增一个高级主题
3. 在高级主题编辑器里配置具体颜色项

## 5. 功能映射关系

## 5.1 从外观页移除的能力

当前外观页颜色卡片承载的是：

- 主色选择
- 基础色板切换

这部分后续不再单独存在于外观页。

但这不代表要把这套色板方案原封不动搬进高级主题。

真正要做的是：

- 调查这层颜色当前实际覆盖了哪些作用域
- 把这些大覆盖域能力吸收到高级主题的具体设置项里
- 让高级主题不只是“局部润色”，而是更接近真正的主题自定义

## 5.2 并入高级主题的能力

后续放进高级主题新增/编辑里的内容：

- 强调色
- 页面背景
- 次级背景
- 主要文字
- 辅助文字
- 通用边框
- 搜索框背景
- 卡片背景
- 卡片文字
- 卡片边框
- 阴影
- 标签/状态相关颜色
- 壁纸
- 底栏图集
- 封面图集

也就是：

- 原来“颜色”入口背后那层大覆盖域能力
- 加上原来的“高级主题”细分覆盖能力

统一都在高级主题编辑器里完成，而且是以“具体颜色项手动自定义”为主，不是几个固定颜色方案让用户选。

## 5.3 颜色层与高级主题层的新版拆法

新版应把高级主题理解成两层：

### 基础主题层

承接原来“颜色”入口那层大覆盖域能力，例如：

- 主强调色
- 容器色
- 大面积表面色
- 大范围文字层级
- 大范围描边层级

这一层的目标不是色板搬家，而是把“颜色”原本能影响很多地方的能力，变成高级主题里的正式组成部分。

### 精细覆盖层

保留当前高级主题已有的细分能力，例如：

- 卡片背景
- 卡片文字
- 卡片边框
- 标签/状态相关颜色
- 壁纸
- 底栏图集
- 封面图集

这样合并后的高级主题才不是“颜色入口迁移”，而是“真正的主题自定义”。

## 5.4 结构定义定稿

基于当前代码和作用域审计，先把高级主题里的两层结构固定如下。

### 基础主题层：负责整体风格

这些项应视为“原颜色层的大覆盖域能力”：

- `primary`
  - 作用：主强调色、主按钮、主交互高亮
- `primaryContainer`
  - 作用：选中态、标签/pill、状态块背景
- `secondary`
  - 作用：次级强调与辅助徽标色
- `background`
  - 作用：页面根背景、大面积基底
- `surface`
  - 作用：次级表面、面板/区域容器底色
- `searchFieldBackground`
  - 作用：输入框、搜索条、搜索触发区
- `elevatedSurface`
  - 作用：高层级面板、弹层感容器
- `textPrimary`
  - 作用：全局主要文字层级
- `textSecondary`
  - 作用：全局辅助文字层级
- `outline`
  - 作用：通用描边、输入边框、分隔线基准

这些项的共同特点：

- 不是只影响一两个局部组件
- 一旦改动，会影响一大批外层页面的整体风格

### 精细覆盖层：负责局部精修

这些项应视为高级主题原本已有的细分覆盖能力：

- `card`
  - 作用：卡片/面板专属底色
- `cardText`
  - 作用：卡片内文字层级
- `cardBorder`
  - 作用：卡片/面板专属描边
- `noticeAccent`
  - 作用：提示/提醒强调色
- `noticeSurface`
  - 作用：提示/提醒底色
- `iconBackground`
  - 作用：图标圆底、局部图标承托色
- `buttonText`
  - 作用：按钮文字精修
- `shadow`
  - 作用：阴影/光晕精修
- `wallpaperOverlay`
  - 作用：壁纸遮罩色

这些项的共同特点：

- 它们是在基础主题层之上做局部强化
- 更适合“细调某一类块的观感”

### 资源层：保持独立

这些项不属于颜色层，但继续归高级主题统一管理：

- `wallpaperPath`
- `wallpaperOverlayOpacity`
- `bottomNavGalleryId`
- `coverGalleryId`

## 5.5 现有字段归类结果

为了后续开发不再摇摆，现有字段先按下面归类：

### 归入基础主题层

- `primary`
- `secondary`
- `primaryContainer`
- `background`
- `surface`
- `searchFieldBackground`
- `elevatedSurface`
- `textPrimary`
- `textSecondary`
- `outline`

### 归入精细覆盖层

- `card`
- `cardText`
- `cardBorder`
- `noticeAccent`
- `noticeSurface`
- `iconBackground`
- `buttonText`
- `shadow`
- `wallpaperOverlay`

### 归入资源层

- `wallpaperPath`
- `wallpaperOverlayOpacity`
- `bottomNavGalleryId`
- `coverGalleryId`

## 5.6 页面切换优先级

后续把基础主题层真正接管外层页面时，优先顺序固定如下：

### 第一优先级：当前已接高级主题运行态的主链路

- 书架
- 发现
- 搜索
- 我的
- 底栏

原因：

- 这些页面已经接入 `ResolvedAdvancedThemePalette`
- 成本最低、收益最高

### 第二优先级：外层设置与信息页

- 外观
- 系统设置
- 反馈
- 关于

原因：

- 这些页面现在还大量直接依赖基础 `colorScheme`
- 用户对主题一致性感知明显

### 第三优先级：阅读器外围页

- 阅读记录
- 目录弹层
- 书籍详情页外围块

原因：

- 它们仍属于外层页面或外围 UI
- 但容易和正文体系混在一起，所以必须单独控制范围

### 明确不进入本轮

- 阅读器正文页
- 阅读器正文内部主题色体系

## 5.3 当前空状态为什么合理

`高级主题` 目前默认空着是合理的，含义就是：

- 用户没有启用任何高级主题
- App 继续使用基础主题结果

也就是说：

- 没有高级主题，不是异常状态
- 而是正常默认状态

这个逻辑本轮保留，不额外抽象成新的“默认主题对象”。

## 6. 技术处理策略

## 6.1 本轮不重写底层模型

为了控制风险，本轮建议保留：

- `appSeedColorProvider`
- `AppAdvancedTheme`
- `AppAdvancedThemeColors`
- `activeAdvancedThemeId`

本轮只做：

- 入口调整
- 编辑体验调整
- 语义调整

## 6.2 `seedColor` 的处理

本轮对 `seedColor` 的策略是：

- 不再作为外观页的独立入口暴露
- 但底层先保留，避免高风险迁移
- 后续新增高级主题时，可以把当前基础主题结果作为回填底子

这样做的目的：

- 不破坏现有数据
- 不把问题扩大成数据迁移项目

## 7. 分阶段计划（可勾选）

## 第一阶段：入口收口

目标：

- 先把外观页结构改对
- 不扩大到底层重构

任务清单：

- [ ] 外观页移除 `颜色` 卡片
- [ ] 外观页保留 `高级主题` 入口
- [ ] 外观页文案调整，避免继续暗示“颜色”和“高级主题”是两个并列系统

本阶段不做：

- 不删除 `appSeedColorProvider`
- 不改高级主题名称
- 不新增默认主题对象

## 第二阶段：高级主题编辑器承接颜色能力

目标：

- 让颜色层的大覆盖域能力真正进入高级主题新增/编辑流程
- 不是把颜色方案入口搬进来，而是把它吸收成高级主题设置项的一部分

任务清单：

- [ ] 梳理原颜色入口承载的能力
- [ ] 调查这层颜色当前实际覆盖了哪些作用域
- [ ] 归纳出哪些属于“基础主题层能力”
- [ ] 归纳出哪些属于“精细覆盖层能力”
- [ ] 在新增高级主题时，能通过具体设置项承接这些能力
- [ ] 在编辑高级主题时，完整保留这些具体设置项
- [ ] 新建高级主题时，允许从当前基础主题结果回填初始值
- [ ] 不再要求用户先去外观页改颜色，再回来做高级主题
- [ ] 不引入“几个固定颜色方案”的替代实现

本阶段不做：

- 不新增新的颜色字段
- 不扩充为官方预设主题库

## 第三阶段：文案与行为收尾

目标：

- 让产品表达和实际行为一致

任务清单：

- [ ] 高级主题页空状态文案明确为正常默认状态
- [ ] 高级主题列表 / 编辑器文案统一
- [ ] 审计文档更新到最新口径
- [ ] 校验旧“颜色”路径移除后，用户流程仍闭环

## 7.4 收尾验证清单

- [ ] 外观页不再出现 `颜色` 卡片
- [x] 外观页仍保留 `模式`
- [x] 外观页仍保留 `高级主题`
- [ ] 用户可以在“新增高级主题”里完成原颜色入口的配置需求
- [ ] 高级主题默认空状态仍然成立
- [ ] 不影响阅读器正文主题体系
- [x] `flutter analyze` 通过
- [ ] 主题相关测试通过

## 8. 明确不做什么

为了防止无限延伸，这次明确不做：

- 不改 `主题模式`
- 不改阅读器正文主题体系
- 不改 `高级主题` 名称
- 不引入“默认主题 / 我的主题”新概念
- 不新建官方预设主题体系
- 不一次性删除 `seedColor` 底层存储
- 不重写 `AppAdvancedTheme` 数据模型
- 不处理与本次入口合并无关的业务改动

补充执行规则：

- 如果开发中发现新的“顺手一起做更好”的想法，默认不纳入本轮，先记为后续事项

## 9. 最终交付标准

本轮收口完成后，应达到：

1. 外观页不再有 `颜色` 入口
2. 高级主题继续保留原名称
3. 颜色能力并入高级主题新增/编辑
4. 高级主题默认空状态仍然成立
5. 当前底层数据模型仍可复用，不做高风险重写

## 10. 一句话结论

这次合并不是大重构，而是：

- 移除外观页的颜色卡片
- 把颜色能力并入高级主题新增/编辑
- 保留高级主题名称
- 保留高级主题默认空状态
- 全程控制范围，不额外延伸
