# 阅读器对标 Legado 的版面与翻页改造计划

更新时间：2026-04-08  
用途：基于对 `legado-with-MD3` 阅读器的结构梳理，明确我们当前阅读器在正文边距、分页排版、翻页动画上的差异，并给出适合当前 Flutter 架构的落地计划。

## 1. 结论先行

对标 `Legado`，我们应该借鉴的是“版面参数统一进入排版”和“翻页表现与正文排版解耦”的结构，不应该直接照搬其 Android 自绘实现。

当前判断：

- 我们已经具备独立的正文四边距设置，并且边距会真实参与分页计算，不只是视觉留白。
- 我们已经具备分页动画体系，但翻页状态机、分页布局、动画渲染仍然有不少逻辑堆叠在 `reader_page.dart`。
- `Legado` 的优势主要在于：阅读布局参数统一、分页视图稳定、不同翻页动画通过独立委托消费页面内容。
- 我们下一步最值得落地的不是“立刻追平仿真翻页效果”，而是先把布局模型和翻页控制层收口。

一句话总结：

- **先统一布局模型**
- **再抽翻页控制层**
- **最后逐步增强动画表现**

## 2. 参考项目梳理

### 2.1 Legado 的阅读器结构

`Legado` 的文本阅读主链路更接近传统电子书阅读器引擎：

- `ReadBookConfig` 统一持有阅读排版配置，包括正文边距、页眉页脚边距、翻页动画等。
- `PaddingConfigDialog` 负责修改正文、页眉、页脚的四边参数。
- `ChapterProvider` / `TextChapterLayout` 负责把配置转成可视区域尺寸，并参与真正的分页和元素布局。
- `ReadView` 负责切换不同翻页委托。
- `PageDelegate` 子类分别实现覆盖、滑动、仿真、滚动、淡入淡出、无动画。

这意味着：

- 正文边距天然属于阅读引擎的一部分。
- 翻页动画建立在“稳定的当前页 / 上一页 / 下一页”之上。
- 动画负责消费页面快照，不负责正文排版。

### 2.2 我们当前的阅读器结构

当前项目的文本阅读主链路更接近 Flutter 组件化方案：

- `ReaderSettings` 持有正文四边距、页眉页脚边距、分页动画样式等。
- `reader_page.dart` 同时承担了阅读页壳层、分页尺寸计算、分页状态维护、部分翻页控制、部分动画渲染。
- `_paginateParagraphSlices()` 使用 `TextPainter` 根据内容宽高进行分页。
- `PagedTextReaderRenderer` 负责分页阅读的进度换算、翻页决策和动画时长策略。
- 各种动画效果通过 widget 过渡完成，`curl` 再走一套单独路径。

这条路径的优点：

- 与 Flutter UI 体系兼容好，维护成本相对低。
- 普通动画效果容易扩展。
- 正文内容、设置、选择、书签等更容易复用普通 widget 能力。

当前主要问题：

- 阅读布局参数尚未收口为统一的布局对象。
- 翻页控制状态机仍偏集中地堆在页面文件中。
- 动画渲染入口已存在，但还没有演进成清晰的独立 renderer 层。

## 3. 正文边距现状与判断

### 3.1 Legado 的实现方式

`Legado` 的“正文边距”本质上是阅读可视区域的内边距，不是普通页面布局上的 margin。

其特点：

- 设置入口直接修改正文四边参数。
- 参数进入阅读配置对象后，会换算成 px。
- 正文宽高、可视区域、文本行坐标、图片布局都基于这套参数。
- 边距变化会直接影响分页结果。

可借鉴点：

- 正文边距、页眉、页脚应该统一归入阅读布局模型，而不是分散计算。
- 布局参数应尽可能只在一个地方被解析为“最终可视尺寸”。

### 3.2 我们当前的实现方式

当前项目已经支持：

- `bodyMarginTop / bodyMarginBottom / bodyMarginLeft / bodyMarginRight`
- `infoHeaderMargin* / infoFooterMargin*`
- 设置面板可独立调整正文四边距
- 滚动模式将正文四边距用于 `ListView.padding`
- 分页模式会基于正文四边距扣减分页可用宽高
- 分页签名包含正文四边距，边距变化会触发重新分页

当前判断：

- 这部分能力已经具备与 `Legado` 同级的核心语义，即“边距参与排版”，不是主要短板。
- 真正还需要补的，是把散落在多个方法里的边距计算收口为统一布局模型。

## 4. 翻页动画现状与判断

### 4.1 Legado 的实现方式

`Legado` 的翻页动画本质上是“阅读页位图 / 画布驱动”的动画系统。

特点：

- `ReadView` 根据配置切换 delegate。
- `PageDelegate` 提供统一的滚动启动、惯性、状态切换能力。
- `Cover / Slide / Fade / Simulation / Scroll` 都是独立实现。
- 仿真翻页不是普通淡入淡出，而是折角、阴影、背页、路径裁切共同参与。
- 滚动翻页也不是简单切页，而是带有阅读器语义的滚页。

可借鉴点：

- 翻页动画应该建立在“稳定页内容”之上。
- 动画表现层不要反向侵入正文分页逻辑。
- 不同动画样式应该有独立实现边界。

### 4.2 我们当前的实现方式

当前项目已经支持：

- `curl / fade / cover / translate / vertical / none`
- 分页模式使用独立的页切换决策
- 动画时长和曲线由 `PagedTextReaderRenderer` 统一给出
- `scroll` 模式、含插图章节、听书模式等会显式关闭正文分页动画

当前判断：

- 我们已经具备“动画策略层”和“动画渲染入口层”。
- 真正薄弱的部分不是动画种类，而是页面文件职责过重。
- `cover / translate / vertical / fade` 继续走 widget 动画是合理路线。
- `curl` 应该单独升级，不能长期混在普通 page transition 逻辑里。

## 5. 目标

本轮对标改造只围绕以下目标展开：

- 将正文、页眉、页脚、系统安全区相关参数收口为统一阅读布局模型
- 将分页尺寸计算统一依赖布局模型，不再在多个方法内重复计算边距
- 将分页翻页状态机从页面大文件中抽离
- 将分页动画效果继续收口为清晰的 renderer 层
- 为后续升级 `curl` 动画预留干净边界

本轮不做：

- 不直接重写成 Android 自绘式阅读引擎
- 不把滚动阅读改造成自绘滚页系统
- 不在当前阶段追求完全复刻 `Legado` 的仿真翻页
- 不大规模改动现有阅读主路径视觉

## 6. 设计原则

### 6.1 布局参数统一进入排版

正文边距、页眉页脚边距、底部进度区预留、安全区都应在一个地方被解析为最终版面参数。

### 6.2 正文分页和翻页表现解耦

分页阶段只关心：

- 当前内容可用宽高
- 字体与段落排版
- 一页可以容纳多少内容

动画阶段只关心：

- 从哪一页切到哪一页
- 当前动画方向
- 当前动画进度
- 当前动画样式如何渲染

### 6.3 先优化结构，再增强效果

如果结构没收口，继续增强动画只会增加 `reader_page.dart` 的复杂度。

## 7. 落地方案

### 7.1 方案 A：引入统一的阅读布局模型

建议新增：

- `lib/features/reader/application/reader_layout_metrics.dart`
- `lib/features/reader/application/reader_layout_resolver.dart`

建议收口的字段：

- `bodyPadding`
- `headerPadding`
- `footerPadding`
- `contentWidth`
- `contentHeight`
- `safeInsets`
- `bottomProgressReserve`
- `pinnedHeaderHeight`
- `effectivePagePadding`

目标：

- 滚动模式和分页模式共用同一套正文边距解析结果
- 页眉页脚边距和正文边距不再在 UI 构建处各自重复 `clamp`
- 分页签名从“散落的 margin 字段拼接”逐步过渡到“基于 layout metrics”

### 7.2 方案 B：抽出分页翻页控制层

建议新增：

- `lib/features/reader/application/paged_transition_controller.dart`

职责：

- 根据翻页方向决定：跨章、立即切页、普通动画、curl
- 管理 from/to page index
- 管理分页动画 controller 生命周期
- 管理动画完成后的页码提交

目标：

- 把 `reader_page.dart` 中与分页翻页状态机直接相关的逻辑抽出去
- 页面层只负责提供当前页面数据与接收结果

### 7.3 方案 C：收口分页动画 renderer

建议新增目录：

- `lib/features/reader/presentation/paged_animation/`

建议拆分：

- `paged_animation_renderer.dart`
- `cover_paged_animation_renderer.dart`
- `translate_paged_animation_renderer.dart`
- `vertical_paged_animation_renderer.dart`
- `fade_paged_animation_renderer.dart`
- `curl_paged_animation_renderer.dart`

目标：

- 普通动画继续使用 widget 方案
- 每种动画有独立渲染边界
- 页面层只负责把 `fromPage`、`toPage`、`progress`、`direction` 交给 renderer

### 7.4 方案 D：为 curl 单独升级留接口

建议 `curl` 后续采用：

- widget 页面内容
- `RepaintBoundary` 稳定页面层
- `CustomPainter` 只负责折角、阴影、背页遮罩和路径裁切

不建议：

- 把所有分页动画都强行切到 `CustomPainter`
- 直接重写成完全仿 `Legado` 的位图录制系统

### 7.5 方案 E：滚动阅读保持 Flutter 原生路线

建议保持：

- `ListView` / `ScrollController` 为核心
- 渐进增强点击翻页步长、自动滚动体验

不建议本轮做：

- 独立 scroll delegate
- 自绘滚页分页模型

原因：

- 这会与 Flutter 的滚动体系冲突较多
- 收益不如先把分页结构收口来得直接

## 8. 实施阶段

### 阶段 1：统一阅读布局模型

目标：

- 统一正文、页眉、页脚、安全区、底部预留的解析逻辑

任务：

- [x] 新增 `ReaderLayoutMetrics`
- [x] 新增 `ReaderLayoutResolver`
- [x] 将滚动模式正文 padding 切换为依赖布局模型
- [x] 将分页模式 `contentPadding / maxWidth / maxHeight` 切换为依赖布局模型
- [x] 将分页签名改为依赖布局模型的关键字段

验收：

- 切换正文四边距后，滚动和分页的可视留白一致
- 切换页眉页脚配置后，不出现分页高度与视觉留白不一致的问题

### 阶段 2：抽出分页翻页控制层

目标：

- 将分页翻页状态机从页面文件中拆走

任务：

- [x] 新增 `PagedTransitionController`
- [x] 抽出翻页决策与动画启动逻辑
- [x] 抽出动画完成后的索引提交逻辑
- [x] 为跨章、立即切页、普通动画、curl 保留统一返回结构

验收：

- 当前翻页行为不退化
- 页面层中与分页动画直接相关的状态和方法显著减少

### 阶段 3：拆分页动画 renderer

目标：

- 建立清晰的分页动画表现层

任务：

- [x] 抽 `PagedAnimationRenderer` 接口
- [x] 拆出 `cover / translate / vertical / fade` renderer
- [x] 保持当前动画时长与曲线策略不变
- [x] 页面层仅负责组装 `fromPage` / `toPage`

验收：

- 普通动画效果与当前一致
- 新增动画类型时不需要再往 `reader_page.dart` 塞一大段渲染分支

### 阶段 4：升级 curl

目标：

- 单独提升 `curl` 表现质量

当前阶段结论：

- `curl` 继续复用分页后的页内容层，不额外引入页面快照缓存。
- 当前只消费两层稳定页面内容：`currentPage` 与 `targetPage`。
- `curl` 的阴影、折页背面、边缘高光与预览反馈统一收口到独立 renderer。

任务：

- [x] 明确 `curl` 需要的页内容层级和缓存策略
- [x] 将当前 curl 专有逻辑继续收口
- [x] 按需要引入 `CustomPainter`
- [x] 加阴影、折页背面、拖拽预览等增强

验收：

- `curl` 的表现明显优于普通平移/覆盖动画
- 不影响普通动画结构

## 9. 文件影响范围

预计重点涉及：

- `lib/features/reader/presentation/reader_page.dart`
- `lib/domain/entities/reader_settings.dart`
- `lib/features/reader/application/text_reader_renderer.dart`
- `lib/features/reader/application/reader_animation_policy.dart`

预计新增：

- `lib/features/reader/application/reader_layout_metrics.dart`
- `lib/features/reader/application/reader_layout_resolver.dart`
- `lib/features/reader/application/paged_transition_controller.dart`
- `lib/features/reader/presentation/paged_animation/`

## 10. 风险与注意事项

### 10.1 结构拆分风险

如果在拆 `reader_page.dart` 时直接同时改动画表现，很容易引入回归。

建议：

- 先抽布局模型
- 再抽控制层
- 最后替换动画 renderer

### 10.2 分页回归风险

边距、页眉、页脚一旦进入统一布局模型，可能影响：

- 当前页数
- 恢复进度时的页码
- 分页模式下的目录跳转位置

建议：

- 每次布局模型变更都保证分页签名同步变化
- 保证旧进度仍按逻辑位置恢复，而不是依赖过时页码

### 10.3 动画与选择态冲突

当前文本选择、书签点击、分页动画之间存在天然耦合。

建议：

- 继续保持动画期间禁用不必要的选择交互
- `curl` 单独定义交互边界，不复用普通动画的所有手势逻辑

## 11. 验收口径

本计划完成后，至少应满足：

- 正文四边距在滚动和分页模式下行为一致
- 分页内容尺寸计算不再散落在多个方法里重复实现
- 分页翻页状态机不再主要堆在 `reader_page.dart`
- 普通分页动画具有清晰的 renderer 目录边界
- `curl` 拥有单独升级空间，不继续污染普通动画链路

## 12. 当前建议优先级

如果只能先做两件事，优先做：

- [ ] 阶段 1：统一阅读布局模型
- [ ] 阶段 2：抽出分页翻页控制层

原因：

- 这是当前最接近 `Legado` 结构收益、且最适合我们 Flutter 架构的改造路径。
- 这两步做完之后，后续不管是增强 `curl`，还是继续整理正文信息栏和分页行为，复杂度都会明显下降。
