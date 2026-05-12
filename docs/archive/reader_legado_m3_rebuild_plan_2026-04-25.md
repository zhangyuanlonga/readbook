# 阅读器对标 Legado M3 的重构计划

更新时间：2026-04-25  
用途：基于本地参考工程 `legado-with-MD3-main` 的阅读器实现，梳理当前 Flutter 阅读器为什么“参数很多但效果不稳”，并给出一份面向项目现状的可执行改造计划。

最终目标补充说明：

- **完整承接并保留 `MD3` 阅读器这一块的配置能力**
- **不是删配置项来换稳定，而是用更稳定的页面模型把这些配置项重新组织起来**
- **最终效果应当是：`MD3` 的阅读排版能力完整可用，但实现复杂度明显下降**

## 1. 结论先行

这次对标的核心结论不是：

- 去抄某个页眉样式
- 去抄某个页脚动画
- 去继续补更多边距或 offset 参数

而是：

- `Legado` 的阅读器简单，是因为阅读页结构强约束
- 我们的阅读器复杂，是因为阅读页结构弱约束，且多个层级同时控制正文可用区域

一句话总结：

- `Legado` 是“一个阅读页面模型 + 少量配置”
- 我们当前更像“一个高自由度排版编辑器 + 多套布局逻辑”

## 2. 参考工程的关键做法

本地参考工程关键文件：

- [ReadBookActivity.kt](/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/ui/book/read/ReadBookActivity.kt)
- [BaseReadBookActivity.kt](/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/ui/book/read/BaseReadBookActivity.kt)
- [ReadView.kt](/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/ui/book/read/page/ReadView.kt)
- [PageView.kt](/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/ui/book/read/page/PageView.kt)
- [ContentTextView.kt](/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/ui/book/read/page/ContentTextView.kt)
- [activity_book_read.xml](/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/res/layout/activity_book_read.xml)
- [view_book_page.xml](/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/res/layout/view_book_page.xml)
- [ReadBookConfig.kt](/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/help/config/ReadBookConfig.kt)

### 2.1 页面分层很硬

`activity_book_read.xml` 外层只有一个真正的阅读主体 `ReadView`，菜单和搜索是覆盖层 sibling。

这意味着：

- 阅读背景、正文、页眉、页脚属于同一个阅读面
- 菜单、搜索、选中文案操作才是覆盖层
- 不存在“正文一套、背景一套、页眉页脚再一套”的三重系统

### 2.2 单页结构固定

`view_book_page.xml` 直接定义：

- `status bar placeholder`
- `header`
- `content`
- `footer`
- `navigation bar placeholder`

正文 `ContentTextView` 被严格约束在 header/footer 中间。

这意味着：

- 分页计算的正文高度就是天然稳定的
- 页眉页脚不是后贴浮层
- 不需要额外 reserve 来“猜”要给顶部/底部留多少空间

### 2.3 配置项虽多，但进入的是同一个页面模型

`ReadBookConfig` 的边距、字号、页眉页脚 padding 等，最终都收敛到同一个页面布局模型里。

这意味着：

- 配置变了，只是更新页面模型
- 分页、断句、正文宽高、页码信息一起基于同一组尺寸重算
- 不会出现一个参数只改视觉、另一个参数又偷偷改正文可用高度

## 3. 我们当前的问题

当前项目关键文件：

- [reader_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/presentation/reader_page.dart)
- [reader_settings.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/domain/entities/reader_settings.dart)
- [reader_layout_resolver.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/reader_layout_resolver.dart)
- [reader_preferences_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/reader_preferences_service.dart)

### 3.1 同一块正文区域被多套逻辑控制

当前正文可用区域会同时受到这些因素影响：

- 正文四边距
- 分页/滚动模式差异
- 顶部 pinned header
- 页眉信息栏
- 页脚信息栏
- 底部 overlay reserve
- safe area / system inset
- 高级主题背景外层壳

结果就是：

- 分页模式容易顶部多留、底部被压
- 滚动模式和分页模式很难始终口径一致
- 一处样式调整会牵动另一处正文高度计算

### 3.2 配置项过多，抽象边界太细

当前 [reader_settings.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/domain/entities/reader_settings.dart) 已经持有大量独立参数：

- 字号
- 行距
- 段距
- 段首缩进
- 字距
- 字重
- 两端对齐
- 正文四边距
- 页眉四边距
- 页脚四边距
- 页眉 padding
- 页脚 padding
- pinned header 偏移
- 下划线一组参数
- 正文阴影一组参数
- 分页动画样式

问题不在“参数太多”本身，而在：

- 很多参数其实共同决定同一个页面矩形
- 但它们被拆成了互相独立的旋钮
- 结果视觉上不好收敛，代码上也很难稳定

### 3.3 当前计划里原本不够明确的遗漏项

这次复盘后，必须明确补进计划、不能遗漏的能力包括：

- 正文字号
- 行距
- 段距
- 段首缩进
- 字距
- 字重
- 两端对齐
- 正文四边距
- 章节头显示与位置
- 信息栏显示项
  包括：时间、电量、进度、章节信息
- 信息栏位置与版式
  包括：页眉/页脚、显示模式、间距、分隔线
- 正文装饰项
  包括：颜色、下划线、阴影、斜体

这些能力不能因为“要收口复杂度”就被删掉。  
后续要做的是：

- 保留能力
- 收口入口
- 收口布局解释逻辑

而不是为了简化实现，把能力本身砍掉。

### 3.4 `reader_page.dart` 职责过大

当前页面同时承担：

- 页面壳层
- 背景层
- 文本滚动布局
- 文本分页布局
- 漫画阅读
- 分页状态机
- 翻页动画
- 目录/设置/底部 overlay

这会导致两个直接后果：

- 改一个布局策略很容易牵连其他模式
- 很难建立一个稳定的“正文可用区域”唯一来源

## 4. 这次改造的目标

本轮重构不是追求“功能更少”，而是追求以下五件事：

1. 正文可用区域只有一个来源
2. 页眉页脚在每种模式下只有一种职责
3. 阅读配置从“很多独立旋钮”收敛为“少量语义化组合”
4. 分页、断句、滚动、页码信息都建立在统一阅读页面模型上
5. `MD3` 阅读器当前已有和目标中的配置项都能完整保留并继续扩展

同时补充一个硬约束：

5. `MD3` 这轮已经做到一半的阅读能力不能丢，只能换一种更稳定的组织方式继续保留

## 5. 排版与设置项覆盖清单

本轮改造必须覆盖并明确迁移归属的设置项如下。

### 5.1 正文排版

- [ ] 字号 `fontSize`
- [ ] 行距 `lineHeight`
- [ ] 段距 `paragraphSpacing`
- [ ] 段首缩进 `paragraphIndent`
- [ ] 字距 `letterSpacing`
- [ ] 字重 `fontWeightLevel / fontWeightValue`
- [ ] 两端对齐 `textFullJustifyEnabled`

### 5.2 正文版面

- [ ] 正文四边距 `bodyMarginTop/Bottom/Left/Right`
- [ ] 正文边距 preset `bodyMarginPreset`
- [ ] 滚动与分页共享同一套正文版面语义

### 5.3 章节头

- [ ] 章节头是否显示
- [ ] 章节头位置语义
- [ ] 章节头 offset 能力迁移
  当前 `pinnedChapterHeaderOffsetX/Y` 不能直接消失，但要降级为高级设置项，不再影响首层阅读体验

### 5.4 信息栏

- [ ] 信息栏显示项
  时间 / 电量 / 进度 / 章节信息
- [ ] 信息栏位置
  页眉 / 页脚
- [ ] 信息栏样式
  padding / margin / divider / 对齐方式
- [ ] 分页模式与滚动模式的信息栏职责分离

### 5.5 文字细节

- [ ] 正文颜色
- [ ] 正文阴影
- [ ] 正文下划线 / 虚线
- [ ] 正文斜体
- [ ] 字体来源 / 系统字体 / 自定义字体

### 5.6 迁移原则

上面这些设置项的迁移必须满足：

- 功能不丢
- 默认值更稳
- 首层入口更少
- 高级入口更清晰
- 不允许继续通过多个布局层重复解释同一参数

## 6. 明确设计决策

### 5.1 文本分页模式

按 `Legado` 的思路，分页模式采用“页面内建 header/footer”。

也就是说：

- 分页页眉页脚属于页面本体
- 不再用额外浮层去覆盖分页正文
- 分页正文高度直接由页面结构扣出来

### 5.2 文本滚动模式

滚动模式可以保留顶部/底部信息浮层，但必须遵守：

- 正文 top/bottom padding 只计算一次
- header/footer 浮层不再反向改变正文布局口径

### 5.3 菜单、设置、目录

统一视为覆盖层，不参与正文高度和分页计算。

### 5.4 高级主题背景

高级主题背景只能作为阅读面的底层背景，不得再参与正文高度决策。

## 7. 改造范围

本轮主要涉及：

- [lib/features/reader/presentation/reader_page.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/presentation/reader_page.dart)
- [lib/features/reader/application/reader_layout_resolver.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/reader_layout_resolver.dart)
- [lib/domain/entities/reader_settings.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/domain/entities/reader_settings.dart)
- [lib/features/reader/application/reader_preferences_service.dart](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/reader_preferences_service.dart)

必要时新增：

- `lib/features/reader/presentation/widgets/reader_surface.dart`
- `lib/features/reader/presentation/widgets/reader_page_chrome.dart`
- `lib/features/reader/presentation/widgets/reader_scroll_chrome.dart`
- `lib/features/reader/application/reader_surface_metrics.dart`

## 8. 分阶段计划

### 阶段 A：先把阅读页面模型立住

- [x] 抽出统一的 `ReaderSurfaceMetrics`
  统一描述：正文可用宽高、safe inset、header/footer 占位、内容区矩形
- [x] 文本分页和文本滚动都改为依赖同一个 `ReaderSurfaceMetrics` 入口
- [x] 停止在 `reader_page.dart` 各处分散计算顶部/底部 reserve
- [x] 明确背景层只服务阅读 surface，不再服务正文布局

当前阶段说明：

- 本次只完成 metrics 收口，不改变阅读器视觉与交互行为
- 目的是先把“正文可用区域”的计算入口统一，避免后续继续分散改动

验收标准：

- 分页和滚动都有唯一正文矩形来源
- 顶部/底部留白不再由多个方法叠加决定

### 阶段 B：拆开分页 chrome 和滚动 chrome

- [ ] 为分页模式建立 page-local chrome
  负责页眉、页脚、页码、时间、电量
- [ ] 为滚动模式建立 overlay chrome
  负责顶部/底部浮层信息
- [ ] 删除混合判断逻辑
  例如“某个信息栏有时参与正文、有时当浮层”

验收标准：

- 分页模式下 header/footer 永远是页面本体
- 滚动模式下 header/footer 永远是浮层

### 阶段 C：收口配置项（模型层）

- [x] 将阅读配置收口为语义化配置组
  已新增：正文排版、正文版面、章节头、信息栏、视觉装饰
- [x] 为正文排版建立一级配置组
  字号、行距、段距、缩进、字距、字重、两端对齐
- [x] 为正文版面建立一级配置组
  正文边距、正文边距 preset、自定义边距
- [x] 为章节头建立一级配置组
  章节头 offset 能力单独收口，不再散落在页面逻辑里
- [x] 为信息栏建立一级配置组
  显示项、页眉/页脚位置、分隔线、padding、margin
- [x] 将首层高频配置收敛为少量 preset 能力
  已新增：`typographyPreset / spacingPreset / chapterHeaderPreset / infoStylePreset / fontPreset`

阶段 C 说明：

- 本阶段只完成“配置模型”和“preset 服务”收口
- 不改阅读器设置 UI，不改变当前交互入口
- UI 接线与高级项下沉统一放到后续阶段 F 处理

建议第一阶段收口目标：

- `typographyPreset`
- `spacingPreset`
- `bodyMarginPreset`
- `bodyMarginCustom`
- `chapterHeaderPreset`
- `infoStylePreset`
- `pageAnimationStyle`
- `fontPreset`

验收标准：

- 首层阅读设置能在少量选项下得到稳定版面
- 高级参数不再直接影响多种阅读模式的结构稳定性

### 阶段 D：让分页和断句只服务一个页面模型

- [x] 分页前先拿到稳定的正文内容区尺寸
- [x] 断句和分页只基于正文内容区尺寸运算
- [x] 页眉页脚变化时，只更新页面模型，不在外层再补额外 reserve
- [x] 分页签名基于 surface metrics 收口

阶段 D 说明：

- 已新增 `ReaderPaginationSpec`，统一承接正文内容区尺寸与分页相关排版参数
- 分页、断句、签名、预计算缓存现在统一依赖 `ReaderPaginationSpec`
- 本阶段仍不改阅读器 UI，只收口分页输入模型

验收标准：

- 调整正文边距后，分页结果稳定且可预期
- 调整页眉页脚样式后，不再出现顶部/底部空白错位

### 阶段 E：回归验证与体验基线

- [x] 文本分页最后一页不出现异常大块留白
- [x] 文本分页最后一页不被页脚覆盖
- [x] 滚动模式底部不再二次叠加空白
- [x] 切换高级主题背景不改变正文可用高度口径
- [x] 切换分页/滚动后，阅读进度恢复一致

阶段 E 说明：

- 本阶段已补齐自动化体验基线测试
- 验证口径基于 `ReaderSurfacePolicy / ReaderPaginationSpec / ReaderLogicalPosition`
- 重点保证：
  分页底部预留不小于信息栏占位、滚动底部不重复叠加、背景变化不影响正文内容区、模式切换不丢逻辑位置
- 这一步是“自动化回归基线完成”，不是最终视觉验收截图

## 9. 具体落地顺序

为了降低回归风险，建议严格按顺序做：

1. 先抽 `ReaderSurfaceMetrics`
2. 再拆分页/滚动 chrome
3. 再收口设置项
4. 最后再微调视觉样式

不要反过来做：

- 不要先改页眉视觉
- 不要先调 offset/reserve 数值
- 不要先堆更多设置参数

否则只会继续增加结构债务。

## 10. 本轮不做

- 不直接模仿 Android 自绘阅读页实现
- 不强行把滚动和分页做成完全一样的视觉
- 不在这一轮处理漫画阅读版式
- 不继续为现有混合结构补新的 reserve / overlay 分支
- 不为了“简化”而删掉现有已经做到一半的 `MD3` 阅读排版能力

## 11. 风险提醒

当前最大的风险不是代码量，而是“边改边试参数”。

如果不先把页面模型收口，会继续出现：

- 一个模式修好了，另一个模式坏掉
- 高级主题背景和阅读布局互相干扰
- 页眉页脚视觉变化引发分页高度变化
- 配置项越来越多，但体验越来越不稳定
- 以“减少参数”为名把现有可用能力删除，导致体验倒退

## 12. 完成标准

本计划落地后的阅读器应满足：

- 分页模式像一个完整页面，而不是正文外面再贴若干层
- 滚动模式信息栏是真正浮层，不再参与正文高度计算
- 正文边距调整简单、稳定、结果可预期
- 字距、行距、段距、缩进、正文边距、章节头位置、信息栏显示项都仍然可用
- 这些能力被收敛到更少、更稳定的入口里，而不是继续散落在页面逻辑中
- 阅读设置首层明显更少，但默认效果更好
- `reader_page.dart` 不再同时承担页面模型、配置解释、分页布局、浮层布局四类职责

## 13. 当前仓内落点

本计划文档用于指导后续阅读器结构收口，和已有文档分工如下：

- [docs/reader_refactor_task_plan.md](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/docs/reader_refactor_task_plan.md)
  侧重阅读器整体结构收口和任务清单
- [docs/reader_legado_layout_animation_plan.md](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/docs/reader_legado_layout_animation_plan.md)
  侧重分页布局与翻页动画差异
- 本文档
  侧重“为什么参考工程简单、我们为什么复杂，以及如何把阅读页面模型重新收拢”
