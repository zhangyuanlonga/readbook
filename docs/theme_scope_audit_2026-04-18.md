# 主题作用域与残留审计（2026-04-18）

## 1. 这次审计要解决什么

这次不是再列一遍“主题功能有哪些”，而是专门回答下面几个问题：

- 现在每一块主题能力，真实作用域到底在哪
- 编辑器 / 文案里写的作用域，和运行时代码里的真实作用域是否一致
- 两版改造之后，哪些旧路径还留着
- 哪些字段已经改了命名或分组，但运行态还在走旧逻辑

当前这套主题体系，实际上是两轮设计叠在一起：

### 第一轮

- 以“字段 / token”思路设计
- `AppAdvancedThemeColors` 里直接存 19 个颜色字段
- 偏底层、偏设计 token

### 第二轮

- 以“结果层 / 用户理解”思路重新分组
- 编辑器改成“页面 / 卡片 / 搜索框 / 选项卡 / 高级颜色”
- 偏业务表达、偏用户可理解命名

当前的问题不是“不能用”，而是：

- 存储层仍是第一轮
- UI 分组已经是第二轮
- 运行态消费只接了一部分

所以会出现：

- 文案说的是 A
- 字段存的是 B
- 页面真正生效的是 C

## 2. 三大主题块的真实作用域

## 2.1 主题模式

代码入口：

- `lib/app/app.dart`
- `lib/app/theme/app_theme_provider.dart`
- `lib/features/mine/presentation/appearance_page.dart`

真实作用域：

- `MaterialApp.router.themeMode`
- 整个应用基础 `ThemeData`

关键入口：

- [app.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/app.dart#L37)
- [appearance_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/appearance_page.dart#L429)

当前残留 / 作用域串线：

- 阅读器仍有自己独立的 `ReaderThemeMode`
- 但阅读器里切换夜间时，会反向修改全局 `appThemeModeProvider`

定位：

- [reader_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/presentation/reader_page.dart#L7440)

结论：

- `主题模式` 的主作用域是“全应用基础主题”
- 但阅读器存在“独立主题模式 + 回写全局模式”的双向耦合
- 这是当前主题模式块最大的历史残留

## 2.2 主题颜色

代码入口：

- `lib/app/theme/app_theme_seed_provider.dart`
- `lib/app/theme/app_theme_palette.dart`
- `lib/features/mine/presentation/appearance_page.dart`

真实作用域：

- 全局 `ColorScheme`
- 所有直接依赖 `Theme.of(context).colorScheme` 的页面
- 高级主题编辑页的默认模板 / fallback 来源

关键入口：

- [app.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/app.dart#L43)
- [appearance_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/appearance_page.dart#L519)

当前残留：

- 很多页面仍直接使用基础 `colorScheme.primaryContainer / outlineVariant / surfaceContainer*`
- 这意味着这些区域并不会自动跟随高级主题结果层字段
- 例如很多“选中态 / badge / 提示块”仍直接走基础主题颜色

结论：

- `主题颜色` 的真实作用域很大，仍是全局主导层
- 高级主题并没有完全接管它上面的所有语义层
- 所以当前系统仍是“基础主题主导 + 高级主题局部覆盖”

## 2.3 高级主题

代码入口：

- `lib/domain/entities/app_advanced_theme.dart`
- `lib/features/mine/application/advanced_theme_provider.dart`
- `lib/app/theme/app_advanced_theme_tokens.dart`
- `lib/features/mine/presentation/advanced_theme_editor_page.dart`
- `lib/features/mine/presentation/advanced_theme_list_page.dart`

外观页中的真实职责：

- 只显示摘要
- 不负责直接切换

定位：

- [appearance_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/appearance_page.dart#L601)

真实运行态作用域：

- 已接入 `resolveAdvancedThemePalette(...)` / `resolveAdvancedThemeBackdrop(...)` 的页面
- 已接入 `resolveBookCover(...)` 的封面 fallback 页面
- 通过 `bottomNavGalleryId` 接管的底栏图集

关键入口：

- [app_advanced_theme_tokens.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/theme/app_advanced_theme_tokens.dart#L55)
- [bottom_nav_icon_gallery_provider.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/navigation/bottom_nav_icon_gallery_provider.dart#L17)

结论：

- 高级主题的真实作用域不是“全局主题层”
- 而是“已接线页面的运行态覆盖层”

## 3. 高级主题分组作用域：UI 说法 vs 真实代码

下面这一段是这次最关键的内容。

## 3.1 页面

编辑器文案：

- 强调色
- 页面背景
- 次级背景
- 主要文字
- 辅助文字
- 边框

定位：

- [advanced_theme_editor_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/advanced_theme_editor_page.dart#L1376)

宣称作用域：

- 页面底色
- 输入框和分割区域
- 正文和标题
- 提示和说明
- 分割线和边框

真实运行态：

- `background`:
  - 页面级 backdrop 背景
  - 书架根背景也会直接消费
- `surface`:
  - backdrop 渐变第二层
  - 书架搜索 / filter 区域 / 部分页块背景
  - 作用域已经明显大于“输入框和分割区域”
- `textPrimary / textSecondary`:
  - 已接入 palette 的页面大量消费
- `outline`:
  - 目前只在首批新接的搜索输入焦点边框里真正有运行态消费
  - 远远没有达到“分割线和边框”的广义作用域

结论：

- `页面` 分组里的 `outline` 作用域被高估了
- `surface` 的真实作用域又被低估了
- 这是一组明显的“文案与真实作用域不一致”

## 3.2 卡片

编辑器文案：

- 卡片背景
- 卡片文字
- 阴影

定位：

- [advanced_theme_editor_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/advanced_theme_editor_page.dart#L1420)

真实运行态：

- `card`:
  - 书架、发现、我的等页面中的主卡片与容器
- `cardText`:
  - 已在书架 / 发现 / 我的多处消费
- `shadow`:
  - 基本仍停留在编辑器预览
  - 运行态主页面没有形成统一 token 消费

结论：

- `卡片背景 / 卡片文字` 已经有真实作用域
- `阴影` 仍基本是旧字段残留，真实作用域接近“仅编辑器预览”

## 3.3 搜索框

编辑器文案：

- 搜索框和搜索触发条的填充颜色

定位：

- [advanced_theme_editor_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/advanced_theme_editor_page.dart#L1453)

真实运行态：

- 书架搜索输入框
- 书架搜索触发条
- 搜索页顶部搜索输入框

当前状态：

- 这一组的文案和真实作用域基本一致
- 但焦点边框不是由它自己控制，而是同时依赖 `outline`

结论：

- 这是当前分组里最接近“说什么就是什么”的一块

## 3.4 选项卡

编辑器文案：

- `primaryContainer` = 选项卡背景色
- `cardBorder` = 为选项卡添加边框线

定位：

- [advanced_theme_editor_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/advanced_theme_editor_page.dart#L1468)

真实运行态：

- `primaryContainer`:
  - 当前高级主题运行态基本没有统一消费
  - 项目中大量选中态仍直接走基础 `colorScheme.primaryContainer`
- `cardBorder`:
  - 真实作用域已经远大于“选项卡边框线”
  - 它是当前高级主题里最核心的卡片 / 容器 / 底栏边框颜色之一

典型定位：

- [shell_scaffold.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/shell_scaffold.dart#L254)
- [discover_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/discover/presentation/discover_page.dart#L242)
- [mine_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/mine_page.dart#L446)

结论：

- `选项卡` 这个分组是当前作用域最失真的一块
- `primaryContainer` 基本没真正打通
- `cardBorder` 又被放在了不准确的分组里

这是典型的第二轮 UI 分组改了，但第一轮字段消费还没重构完。

## 3.5 高级颜色

编辑器文案：

- 辅助强调
- 提示强调
- 提示底色
- 高层级背景
- 图标底色
- 按钮文字

定位：

- [advanced_theme_editor_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/advanced_theme_editor_page.dart#L1503)

真实运行态拆分如下：

### 已有真实作用域

- `noticeAccent / noticeSurface`
  - 发现页筛选与提示块
  - 书架筛选与错误卡
  - 我的页状态 badge 等
- `elevatedSurface`
  - 发现页局部高层级 panel
  - 书架部分信息浮层 / 高层容器
- `iconBackground`
  - 主要仍集中在“我的页”图标圆底

### 仍偏弱或未打通

- `secondary`
  - 仍基本停留在存储层 / 编辑器层
  - 运行态缺乏稳定消费点
- `buttonText`
  - 编辑器预览会用
  - 真实主页面按钮体系没有统一消费

结论：

- `高级颜色` 分组内部已经出现“有些字段已通，有些字段几乎没通”的状态
- 继续把它们平铺放在同一组里，会让用户误以为所有项的作用域是同等级的

## 4. 资源类作用域

## 4.1 壁纸

真实作用域：

- 发现页
- 搜索页
- 我的页
- 书架页
- 阅读记录页
- 底栏背景透明叠加场景

定位：

- [advanced_theme_backdrop_decoration.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/widgets/advanced_theme_backdrop_decoration.dart#L7)
- [bookshelf_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/bookshelf/presentation/bookshelf_page.dart#L518)
- [discover_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/discover/presentation/discover_page.dart#L187)
- [search_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/search/presentation/search_page.dart#L167)
- [mine_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/mine_page.dart#L169)
- [reading_records_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/presentation/reading_records_page.dart#L265)

结论：

- 壁纸是资源类里作用域最完整的一块

## 4.2 底栏图集

真实作用域：

- 应用主底栏图标资源
- 只影响底栏图标图集，不影响底栏颜色语义本身

定位：

- [bottom_nav_icon_gallery_provider.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/app/navigation/bottom_nav_icon_gallery_provider.dart#L17)

结论：

- 这一块链路清晰，残留较少

## 4.3 封面图集

真实作用域：

- 所有接入 `resolveBookCover(...)` 的封面 fallback 页面

当前已接入定位：

- [bookshelf_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/bookshelf/presentation/bookshelf_page.dart#L5008)
- [discover_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/discover/presentation/discover_page.dart#L1070)
- [book_detail_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/book/presentation/book_detail_page.dart#L473)
- [reader_catalog_sheet.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/presentation/reader_catalog_sheet.dart#L909)
- [search_book_card.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/search/presentation/widgets/search_book_card.dart#L163)
- [reading_records_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/presentation/reading_records_page.dart#L2439)
- [bookmarks_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/bookmarks_page.dart#L396)
- [cache_management_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/cache_management_page.dart#L358)

结论：

- 封面图集这块比旧文档写得更完整
- 但旧文档还保留着“未接入 book_detail / reader_catalog_sheet / search_book_card”的描述，已经过期

## 5. 已确认的旧残留清单

## 5.1 文档残留

### 残留 A：封面图集接入文档过期

文档：

- `docs/cover_gallery_theme_integration_plan.md`

问题：

- 文档仍写 `book_detail_page / reader_catalog_sheet / search_book_card` 未纳入接入
- 但当前代码已经接入 `resolveBookCover(...)`

定位：

- [cover_gallery_theme_integration_plan.md](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/docs/cover_gallery_theme_integration_plan.md#L92)
- [book_detail_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/book/presentation/book_detail_page.dart#L473)
- [reader_catalog_sheet.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/presentation/reader_catalog_sheet.dart#L909)
- [search_book_card.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/search/presentation/widgets/search_book_card.dart#L163)

### 残留 B：上一版主题审计文档部分结论已经过期

文档：

- `docs/theme_audit_2026-04-18.md`

问题：

- 文档里把 `outlineColorValue` 归为“未消费”
- 但现在它已经开始接入书架 / 搜索等边框焦点语义

## 5.2 分组语义残留

### 残留 C：`选项卡` 分组仍带着旧字段思维

表现：

- `primaryContainer` 被塞进“选项卡背景色”
- `cardBorder` 被塞进“选项卡边框线”

但真实情况是：

- `primaryContainer` 还没打通成统一选项卡背景
- `cardBorder` 反而已经承担了大量卡片 / 容器 / 底栏边框职责

这是当前最需要重新命名或重分组的一块。

### 残留 D：`页面-边框` 的作用域文案过大

表现：

- 编辑器说它管“分割线和边框”

真实情况：

- 目前只部分接入
- 远没有全局替代 `cardBorder` 或所有 divider/border

## 5.3 运行态残留

### 残留 E：仍有大量基础 `colorScheme.primaryContainer` 直连使用点

影响：

- 高级主题里的 `primaryContainerColorValue` 仍难以形成稳定作用域
- 分组文案和真实结果差距会继续存在

### 残留 F：`secondary / buttonText / shadow` 仍偏编辑器预览字段

影响：

- 用户能改
- 但主页面未形成稳定可感知作用域

### 残留 G：高级主题列表预览仍是独立简化实现

定位：

- [advanced_theme_list_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/advanced_theme_list_page.dart#L826)

问题：

- 列表页预览并没有走统一运行态 palette/backdrop
- 仍是自己按几项字段手拼一个 preview

结果：

- 列表页预览作用域和真实页面作用域不完全一致

### 残留 H：编辑器预览仍是手工拼装，不是运行态真实渲染

定位：

- [advanced_theme_editor_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/mine/presentation/advanced_theme_editor_page.dart#L1888)

问题：

- 编辑器预览有自己的拼装逻辑
- 不是直接复用运行态页面组件

结果：

- 预览可能比真实页面“更完整”或“更理想化”
- 这也会放大作用域理解偏差

## 6. 现在可以怎么理解这套系统

如果只说一句最准确的话：

- 当前系统不是“按分组生效”
- 而是“按字段存储，再由少数页面各自消费”

所以真正的作用域应该分成两层看：

### 第一层：用户可见分组

- 页面
- 卡片
- 搜索框
- 选项卡
- 高级颜色
- 壁纸
- 底栏图集
- 封面图集

### 第二层：真实运行态

- 哪些字段真的进了 `ResolvedAdvancedThemePalette`
- 哪些页面真的用了这些字段
- 哪些地方仍在直接读基础 `colorScheme`

只有第二层才是“真实作用域”。

## 7. 建议的拆理顺序

建议不要同时动所有块，按下面顺序最稳：

1. 先重命名 / 重分组 `选项卡` 块
2. 再补齐 `primaryContainer / secondary / buttonText / shadow`
3. 然后统一编辑器预览和列表预览的运行态来源
4. 最后再决定是否把高级主题进一步回写到全局 `ThemeData`

更具体一点：

### 第一步：把分组语义纠正

- `cardBorder` 从“选项卡”挪走
- `outline` 明确改成“通用边框 / 输入边框”之类更窄的语义
- `primaryContainer` 不打通前，不要继续叫“选项卡背景色”

### 第二步：把“看得见但没打通”的字段补齐

- `primaryContainer`
- `secondary`
- `buttonText`
- `shadow`

### 第三步：去掉双份预览逻辑

- 列表页 preview
- 编辑器 preview

尽量都改成基于统一运行态 token 或真实组件生成

## 8. 结论

当前这套主题最核心的问题，不是字段不够，也不是页面不够，而是：

- 分组语义已经是第二版
- 运行态消费还停留在第一版半途

所以才会出现：

- 有的块名已经变了
- 旧字段还在
- 旧作用域没拆
- 新作用域也没真正立起来

这份审计里最重要的三个结论是：

1. `选项卡` 分组当前最失真，必须优先处理
2. `primaryContainer / secondary / buttonText / shadow` 是最典型的“能配但作用域没立住”
3. 列表预览、编辑器预览、真实运行态三套作用域并没有完全统一
