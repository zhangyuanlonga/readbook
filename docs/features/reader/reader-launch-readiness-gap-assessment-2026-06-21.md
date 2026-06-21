# 阅读器上线可用性差距评估：Legado MD3 / own 对照

**日期**: 2026-06-21  
**参考源码**:

- `/Users/zhangyuanlong/Downloads/legado-with-MD3-main`
- `/Users/zhangyuanlong/Downloads/legado-own`

**当前结论**: 文本阅读器已进入新 renderer 单路径，旧 renderer fallback 和旧 dart-define 回滚开关已移除。当前仍不应跳过上线验收：需要用真实样本、真机 profile、分页/滚动/设置/选择/搜索/朗读/自动阅读矩阵证明单路径稳定；回滚策略从“包内切旧阅读器”改为“回退上一稳定版本/提交”。

---

## 1. 两个参考实现的共同底层能力

MD3 和 own 虽然是不同分支，但阅读器底层关键设计基本一致：

- [x] `ReadView` 常驻 `prevPage / curPage / nextPage` 三个页面视图。
- [x] `ReadBook` 常驻 `prevTextChapter / curTextChapter / nextTextChapter` 三个章节对象。
- [x] `loadContent(resetPageOffset)` 加载当前章，并保持前后一章可用。
- [x] `moveToNextChapter / moveToPrevChapter` 切章时直接平移章节窗口，再后台补新相邻章。
- [x] `TextPageFactory` 能从当前章拿下一页，也能从下一章拿第一页/第二页作为 `nextPage / nextPlusPage`。
- [x] 滚动模式不是重建一个长列表，而是用 `ContentTextView.pageOffset` 在当前/相邻页面之间连续滚动。
- [x] 快速点击/触摸时 `ScrollPageDelegate.ACTION_DOWN -> abortAnim()`，动画可中断。
- [x] 滚动点击翻页距离按当前可见文本行计算，保留一行，而不是固定百分比。
- [x] 相邻页预渲染在 `ContentTextView.preRenderPage()` 里完成，滚动时能直接画 next/nextPlus。

own 分支相对 MD3 额外值得参考：

- [x] EPUB 加了 layout key，版式不变时复用已完成章节布局。
- [x] EPUB 相邻章加载策略更保守：当前章加载完成后再补前后一章，降低首开压力。
- [x] 朗读/阅读记录有更多分支状态，需要作为我们“可上线评估”的专项。

---

## 2. 我们当前已经追上的部分

- [x] 文本分页新 renderer 已接入正式入口，旧 renderer fallback 已移除。
- [x] release renderer 不能静默回旧阅读器；策略拒绝、request 缺失、renderer failure 都会显示诊断页。
- [x] 新旧 renderer authority 已拆开，page count/page index 不再完全隐式共享。
- [x] 翻页动画已由 release animation surface 承接，避免静默失效。
- [x] selection active gate、annotation range、settings signature、layout cache、anchor readiness 已有测试覆盖。
- [x] 连续滚动已补当前章节前后一章 warmup，不再只靠接近边缘时触发。
- [x] 滚动点击翻页已改为可中断/续接，快速点击不再因 `_isScrollStepAnimating` 被直接吞掉。
- [x] 分页/滚动快速输入对齐 MD3/own 的第一步：普通分页/curl/paperCurl 动画中再次点按会先提交当前目标页再续接最后一次输入；滚动点按不再用 `jumpTo` 硬取消上一段动画；滚动点按到章节边缘会保留原始用户输入来源；章节切换、章节加载期间的上一页/下一页/上一章/下一章不再弹“动画/章节处理中”，而是延迟执行最后一次用户输入。
- [x] 滚动跨章 loading toast 已去掉，只在真实第一章/最后一章提示边界。
- [x] 信息排版拖动进度条的正文闪动已通过 deferred commit 缓解。
- [x] 阅读器范围 `flutter analyze lib/features/reader test/features/reader` 已通过。
- [x] 阅读器 presentation 测试已通过，当前记录为 192 tests passed。

---

## 3. 与 Legado 仍然存在的核心差距

| 维度 | Legado MD3 / own | 我们当前 | 上线风险 |
|---|---|---|---|
| 滚动架构 | 单个 `ContentTextView` + pageOffset，绘制当前页/下一页/下下页 | Flutter `ListView` 多章节块 | 快速滚动、跨章定位、动态高度章节仍更容易闪动或跳动 |
| 滚动点击距离 | 按可见页最后/第一行计算，保留一行 | 仍主要按 viewport 比例 + 行高 reserve | 手感还不像主流阅读器，长段/不同字体下距离不稳 |
| 相邻页/章热备 | `prev/current/next` 模型长期常驻，nextPlus 参与预渲染 | 已补相邻章 warmup，但不是同一套 page model | 快速跨章比之前好，但还不是 Legado 级别 |
| EPUB layout 复用 | own 有 layout key，版式未变直接复用 | 我们有 pagination/layout cache，但真实 EPUB UI 验收不足 | EPUB 首开、重排、图片尺寸仍缺上线证据 |
| 动画 | 旧动画与 page factory 深度融合 | 新 renderer 已桥接主动画 | 仍需逐动画真机验收：跨章、快速取消、背景遮罩、内存释放 |
| 选择/标注 | 当前页模型能给行列坐标，长按/选择/朗读共用 | 新 layout 有 anchor，但工具链仍需端到端验收 | 灵感、复制、已有标注唤起可能存在边界遗漏 |
| 搜索/朗读/自动阅读 | 与章节/页/行模型绑定 | anchor mapper 有测试，UI 行为未完整验收 | 搜索跳转、高亮、自动阅读跨章仍是 P0/P1 风险 |
| 性能基线 | 原生 Canvas 绘制，可控预渲染 | Flutter widget/layout + snapshot/cache | 缺 profile 真机数据，不能只凭单测判断 |
| 回滚 | 单一原生阅读器，无新旧混跑 | 旧 dart-define fallback 已移除 | 发布前必须完成版本/提交回滚演练 |

### 3.1 分页链路差距细化

上一版评估对滚动写得更多，分页需要单独拆开。Legado 的分页不是单独的 PageView，而是 `TextPageFactory + prev/cur/next PageView + ReadBook 三章窗口` 共同组成的页面系统；分页、动画、搜索、朗读、选择都能回到同一套页/行/列语义。我们目前分页已经可用，但还缺完整的可上线验收闭环。

| 分页子能力 | Legado MD3 / own | 我们当前 | 缺口与验收要求 |
|---|---|---|---|
| 页模型 | `TextPage` 内含 chapter/page index、lines、read length、selection pos | legacy 有 paragraph slice，新 renderer 有 layout page/line | 需要确认 release renderer 的 page/line/offset 能覆盖搜索、朗读、标注、书签全部场景 |
| 前后页热备 | `prevPage / curPage / nextPage` 常驻，`nextPlusPage` 支撑滚动预渲染 | PageView/animation surface 按当前 pageCount 和目标页构建 | 快速连续翻页、跨章首尾页必须压测，不只测单次点击 |
| 页码与总页数 | 当前章节 layoutChannel 逐步产页，未完成时显示估算页数 | release pageCount、legacy pageCount 已做 authority 隔离 | 设置变化、fallback、跨章后页码不能短暂回 0、不能串旧 renderer |
| 进度保存 | `durChapterIndex + durChapterPos` 统一描述页/章位置 | 章节 ratio、logical position、page index 混合 | 需要验证分页/滚动切换、字体变化、退出重进后恢复到同一段文字附近 |
| 页内翻页 | `moveToNextPage / setPageIndex` 直接更新 `durChapterPos` | `_turnPagedTextPage` 经 page turn runtime/controller | 快速双击、键盘、音量键、触控滑动必须证明不会重复提交或丢页 |
| 跨章分页 | 目标章已有 `nextTextChapter` 时直接切换，否则加载后刷新 | 已改成目标未 ready 时降级无动画提交 | 还需证明后台预热足够；快速猛点跨章不能出现空白、旧页残影、错误 loading |
| 分页动画 | delegate 直接消费 `prev/cur/next PageView` 截图或 Canvas 状态 | `paperCurl/curl/cover/translate/fade/vertical/none` 已有入口 | 每种动画要独立验收：背景遮罩、下一页透出、跨章、快速取消、横竖屏 |
| 纸张卷页 | 原生页面截图/绘制与当前页状态绑定 | `ReaderPaperCurlPagedSurface` 仍是最复杂路径 | 必须做内存峰值和快速翻页截图释放验证，避免旧图像残留 |
| 仿真 curl | 与 page delegate 状态同源 | `CurlPagedAnimationRenderer` 走 transition stack | 需验收边缘拖拽、自动提交、取消回弹、背景不透下一页 |
| 普通过渡动画 | cover/slide/fade/noAnim 都由 page delegate 管 | registry/transition stack 已接入 | 需按设置逐项确认，不只是代码能 switch 到对应 renderer |
| 页面缓存 | own 对 EPUB 有 layout key，样式不变可复用 | 有 pagination/layout cache service | 需要真实 TXT/EPUB 样本验证 cache hit、设置变化 cache invalid、回滚后不串缓存 |
| 混排分页 | own 的 EPUB native layout 有 page color、link area、image box | EPUB mixed payload 已有 alpha | 图片比例、link 点击、footnote/caption、单图页、全页背景仍缺 UI 验收 |

分页 P0 需要补的验收：

- [ ] 每种动画 `none / cover / translate / vertical / fade / curl / paperCurl` 单独做普通章节翻页。
- [ ] 每种动画在章节末尾/开头跨章各测一次。
- [ ] 快速连续点击 20 次：不能吞页、不能页码错乱、不能显示旧页残影。
- [ ] 切换字体、字号、行高、段距、边距后：页数、当前页、进度恢复要稳定。
- [ ] 退出重进：恢复到同一章节同一段落附近，且页码/进度条一致。
- [ ] 搜索结果跳转到分页页码后，高亮位置和可见正文一致。
- [ ] 朗读从当前页开始时，高亮和语音位置一致；跨页/跨章不丢。
- [ ] paperCurl/curl 快速取消或反向操作后，图片资源释放、背景不透、控制器不残留。

### 3.2 界面设置功能等价细化

界面设置也不能只说“设置变化重排”。设置项分成三类：影响文本 layout 的、由 shell/chrome 承担的、影响输入/动画/专项 surface 的。每类的验收方式不同。

| 设置组 | 代表字段/入口 | 分页影响 | 滚动影响 | 当前缺口 |
|---|---|---|---|---|
| 字号/字体 | `fontSize / fontSource / systemFontPreset / customFontPath / fontWeightValue` | 必须触发重新分页和 layout signature 更新 | 必须正文立即重排且滚动锚点稳定 | 需要真实字体、自定义字体、粗细切换验收 |
| 行距/段距/缩进 | `lineHeight / paragraphSpacing / paragraphIndent / letterSpacing` | 影响 page count、行列坐标、搜索/朗读 anchor | 影响滚动高度和跨章 active chapter | 需要验证拖动时不闪、提交后锚点不跳 |
| 两端对齐/标点 | `textFullJustifyEnabled / textBottomJustifyEnabled / zhLayoutPolicy` | 影响中文断行和页末排版 | 影响段落视觉宽度 | 需要长中文、标点、超长句样本验收 |
| 正文边距 | `bodyMarginMode / bodyMarginPreset / bodyMarginTop/Bottom/Left/Right` | 改 content rect，必须重新分页 | 改可视宽高，滚动位置需保持语义 | 当前只修了拖动闪动；还需决定 px/百分比策略和横竖屏适配 |
| 章节标题 | `showChapterHeader / chapterHeaderMode / chapterHeader*Spacing / pinnedChapterHeaderOffset*` | 影响第一页内容起点、页数和 frame | 影响滚动顶部标题表现 | 需验收隐藏/居中/偏移后不遮挡正文 |
| 信息栏 | `infoHeaderEnabled / infoFooterEnabled / infoShowTime/Battery/Chapter/Progress / info*Margin / info*Padding` | shell owned，不应污染文本 layout，但会改变可读区域 | shell owned，拖动设置时不能正文闪 | 需要分页/滚动分别验收顶部/底部/分割线/安全区 |
| 背景主题 | `themeMode / backgroundStyle / backgroundTone / backgroundImageBase64 / bodyTextColorValue` | frame 与页面背景必须参与动画底色 | 同样影响滚动底色和图片透明背景 | 需验收 paperCurl/curl/cover 下背景不透下一页 |
| 亮度 | `brightness / followSystemBrightness` | 平台桥接，不应触发布局重排 | 同左 | 需 iOS/Android 真机验证系统亮度恢复 |
| 文字装饰 | `bodyTextItalicEnabled / shadow / underline/dashed` | release annotation/body style 都要可见 | 滚动正文也要一致 | 需确认普通正文装饰和标注装饰不互相覆盖 |
| 翻页模式 | `pageTurnMode tap/swipe/tapAndSwipe/scroll/tapAndScroll` | 决定分页/滚动 surface | 决定是否走滚动布局 | 需验收切换模式后进度不丢、旧动画状态清理 |
| 翻页动画 | `pageAnimationStyle` | 决定分页动画 surface | 滚动模式不应误用分页动画 | 需逐动画验收，不可用项应禁用或解释 |
| 滚动步长 | `pageTurnStepRatio` | 不适用或只影响 scroll layout | 影响点击滚动距离 | 需要改成可见行感知后重新定义设置含义 |
| 点击区域 | `tapZoneActions` | 分区动作必须走统一 navigation command | 同左 | 需要选择激活、工具栏显示、自动阅读时的冲突验收 |
| 音量键/键盘/鼠标 | `volumeKeyPageEnabled` + desktop resolver | 分页要翻页，边界跨章 | 滚动要步进或跨章 | 需要 Android 音量键、桌面滚轮、键盘回归 |
| 自动阅读 | `autoReadMode / speed / pauseMode / endBehavior` | page mode 按页推进 | scroll mode 连续滚动 | 自动阅读跨章、暂停恢复、手动打断仍缺 UI 验收 |
| 漫画设置 | `mangaReadMode / imageSpacing / imagePadding / loadStrategy` | 漫画 paged/horizontal 与 text 不同 surface | 漫画 continuous 与 text scroll 不同 | 要确认新 text renderer 不污染漫画进度/缓存 |
| 音频设置 | `audioDefaultSpeed / rememberSpeed / seekStep / autoPlay` | 不走文本分页 | 不走文本滚动 | 要确认阅读器设置面板不会把音频进度当文本进度 |

界面设置 P0 需要补的验收：

- [ ] 分页模式下逐项拖动字号、行距、段距、正文边距：页面不闪白，页码和当前段落稳定。
- [ ] 滚动模式下逐项拖动同一组设置：滚动位置不抖，跨章 active chapter 不误切。
- [ ] 信息排版中 header/footer 开关、时间/电量/章节/进度开关、padding/margin 拖动：正文不被遮挡，安全区正确。
- [ ] 背景色、纸张背景、自定义背景图片在所有分页动画下不透底、不残影。
- [ ] 深色/浅色/护眼切换后，正文、标注、信息栏、工具栏对比度可读。
- [ ] 自定义字体导入/切换失败时有 fallback，不导致空白页。
- [ ] 点击区域编辑后，分页/滚动/自动阅读/工具栏状态下动作一致。
- [ ] 自动阅读设置变更后，分页自动阅读和滚动自动阅读分别可暂停、恢复、跨章。
- [ ] 漫画/PDF/音频 surface 打开设置后，只显示并保存对应有效项，不能误改文本 renderer 状态。

### 3.3 分页 Surface 专项审查矩阵

分页不能只看“左右能翻页”。对用户来说，分页模式至少包含 8 条链路：页面生成、页面缓存、动画、输入、跨章、进度、设置重排、专项能力。Legado 的优势在于这些链路都回到 `TextPageFactory + ReadView(prev/cur/next) + ReadBook(prev/cur/next chapter)`，我们现在还需要把 Flutter 新 renderer 的分页 surface 逐项对齐。

| 链路 | 当前应审查的代码/状态 | 与 Legado 的差距 | 必须补的判定项 |
|---|---|---|---|
| 分页入口 | `ReaderPageTurnMode.tap / swipe / tapAndSwipe` 进入分页；`scroll / tapAndScroll` 进入滚动 | Legado 的分页/滚动共用页面工厂，我们是不同 surface | [ ] 切换分页/滚动后，当前段落锚点不变；[ ] 自动阅读/工具栏/进度条 owner 正确切换 |
| 页面生成 | 新 renderer 依赖 layout page/line；legacy 依赖旧 paragraph slice | 还不是一个长期常驻的 `prev/cur/next/nextPlus` 页面池 | [ ] 首屏立即有当前页；[ ] 前后页 ready 状态可诊断；[ ] pageCount 不出现短暂 0 或旧值串入 |
| 页码语义 | page index、chapter ratio、logical position 并存 | Legado 主要用 `durChapterPos` 和 page factory 统一定位 | [ ] 页码、底部进度、目录进度、退出恢复指向同一段文字；[ ] 字号/边距变化后恢复到语义锚点附近 |
| 普通翻页 | 点按、滑动、键盘、音量键都进入 navigation command | Legado delegate 对触摸/按键/动画状态更集中；我们已补普通动画中断提交 + pending 续接 | [ ] 快速点击 20 次不吞页；[x] 动画中再次输入不弹 busy toast；[ ] 动画中反向操作真机验收；[ ] 音量键和键盘不绕过 page runtime |
| 跨章翻页 | 当前已避免未 ready 目标页参与截图动画，用户输入会 pending 续接 | Legado 通常目标章已在 `nextTextChapter` 热备；我们还不是同一套三章常驻模型 | [ ] 章节末页继续点按时无空白；[x] 跨章/加载 busy 不再弹“处理中”；[ ] 目标章未 ready 时无残影且有后台预热；[ ] 第一章/最后章只提示真实边界 |
| 动画 surface | `paperCurl / curl / cover / translate / fade / vertical / none` | 当前虽有入口，但每个动画是否 1:1 使用新 layout 内容还要实测 | [ ] 每种动画同章/跨章/取消/反向都验收；[ ] 背景、图片、信息栏遮罩不透；[ ] 资源释放无旧截图残留 |
| 页面缓存 | pagination/layout cache 已有，但真实样本证据不足 | own 对 EPUB layout key 更明确，版式不变复用，版式变化失效 | [ ] TXT cache hit；[ ] EPUB cache hit；[ ] 字体/字号/边距/背景变化时只失效该失效的内容 |
| 选择标注 | 新 layout 有 anchor，工具链需要端到端确认 | Legado 行列坐标与当前页模型同源 | [ ] 长按浮窗；[ ] 跨页拖选；[ ] 已有标注点击；[ ] 灵感/复制/删除回到正确 range |
| 搜索目录书签 | 搜索、目录、书签跳转要落到可见页 | Legado 可由章节位置转 page index | [ ] 搜索高亮可见；[ ] 目录跳转首段可见；[ ] 书签恢复不偏到上一页/下一页 |
| 朗读自动阅读 | 分页按页推进，滚动按 scroll offset 推进 | Legado 朗读和阅读记录分支更多 | [ ] 当前页开始朗读；[ ] 跨页高亮跟随；[ ] 跨章继续；[ ] 手动翻页后朗读位置同步 |
| 横竖屏/尺寸变化 | Flutter layout 受 viewport 尺寸直接影响 | Legado 原生 view 尺寸变化后 page factory 重算 | [ ] 旋转后不空白；[ ] 分屏/桌面 resize 后进度不丢；[ ] paperCurl 截图尺寸更新 |
| 混排/图片 | EPUB mixed payload 仍是 alpha 风险 | own 对图片、link、footnote 有成熟处理 | [ ] 单图页；[ ] 图文混排；[ ] caption/link/footnote；[ ] 图片加载失败重试不改变文字页码 |

分页按动画拆开的验收表：

| 动画 | 普通翻页 | 跨章翻页 | 快速操作 | 背景/信息栏 | 当前风险 |
|---|---|---|---|---|---|
| `none` | [ ] 直接切页无闪白 | [ ] 章节切换无旧页残影 | [ ] 快点不丢页 | [ ] 信息栏进度同步 | 基线必须最稳，其他动画都以它为回滚目标 |
| `cover` | [ ] 遮盖方向正确 | [ ] 目标章 ready 才播放 | [ ] 可打断 | [ ] 背景不透下一页 | 需要确认下一页内容不会提前露出 |
| `translate` | [ ] 位移距离正确 | [ ] 跨章不抖 | [ ] 快速反向可取消 | [ ] 页脚进度不抢跑 | 容易出现动画位置和 page index 先后不一致 |
| `fade` | [ ] 淡入淡出无闪白 | [ ] 跨章不显示 loading 截图 | [ ] 快点不叠多层 opacity | [ ] 深浅主题对比度稳定 | 对背景和文字颜色变化敏感 |
| `vertical` | [ ] 上下翻页方向正确 | [ ] 章首/章尾边界正确 | [ ] 连点不跳两页 | [ ] 顶/底信息位不遮挡 | 容易和滚动模式手势语义混淆 |
| `curl` | [ ] 拖拽/点击都能完成 | [ ] 目标页未 ready 降级合理 | [ ] 取消回弹正常 | [ ] 背景/下一页遮罩正确 | 最容易暴露截图、裁剪、方向问题 |
| `paperCurl` | [ ] 纸张卷页不透底 | [ ] 跨章资源可释放 | [x] 快速输入先提交当前目标页再续接；[ ] 不残留旧图 | [ ] 自定义背景图片参与底色 | 内存和截图生命周期是上线风险最高项 |

分页专项的第一版上线标准：

- [ ] 不要求所有动画手感达到 Legado 100%，但要求每个动画都有明确 pass/fail 记录。
- [ ] 任一动画未过关时，设置页要禁用该动画或降级到 `none/cover`，不能让用户选择后遇到坏状态。
- [ ] 跨章翻页必须依赖后台预热，不应让用户“等目标页”；预热未命中时可以无动画提交，但不能空白、不能 loading 截图入动画。
- [x] 新 renderer 已原生承接分页动画；搜索、目录、书签、朗读、自动阅读、选择标注继续按 release 单路径专项验收。

### 3.4 界面设置逐字段 Owner 与验收矩阵

当前 `ReaderSettings` 字段已经很多，但 `ReaderLayoutSettingsCompatibilityMatrix` 只覆盖了少量字段。上线判断不能只问“字段有没有保存”，而要问每个字段属于谁、触发什么、在哪里验收。建议把设置分成 5 类：

- [x] `layout-signature`: 会改变正文测量、断行、页数、anchor，需要重新布局/分页。
- [x] `chrome-owned`: 信息栏、背景、安全区、亮度等外层能力，不应该污染正文 layout，但要改变可读区域或显示层。
- [x] `interaction-owned`: 点击区域、音量键、翻页模式、动画、自动阅读输入策略。
- [x] `surface-owned`: 漫画、音频、EPUB 混排等不完全属于文本阅读器。
- [x] `visual-only-but-page-visible`: 字色、阴影、下划线、背景图等不一定改变断行，但会影响截图动画和可读性。

| 设置页分组 | 字段 | Owner 建议 | 分页验收 | 滚动验收 | 当前审查结论 |
|---|---|---|---|---|---|
| 字体 | `fontSize` | layout-signature | [ ] 页数重算，当前段落不丢 | [ ] 滚动 offset 语义保持 | 已入 compatibility，但仍需真实拖动验收 |
| 字体 | `fontSource / systemFontPreset / fontFamilyKey / customFontPath` | layout-signature | [ ] 字体加载失败 fallback；[ ] 搜索/标注坐标不偏 | [ ] 高度重算不闪白 | compatibility 用 `fontIdentity` 聚合，文档和测试需补明细 |
| 字体 | `fontWeightLevel / fontWeightValue` | layout-signature | [ ] 字重影响测量和页数 | [ ] 段落高度稳定 | 已聚合进 `fontIdentity`，但 UI 验收不足 |
| 字体 | `bodyTextItalicEnabled` | layout-signature 或 visual-measurement | [ ] 斜体后行宽不溢出 | [ ] 长英文/数字不截断 | 已补入 compatibility，仍需 UI 样本验收 |
| 字体颜色 | `bodyTextColorValue` | visual-only-but-page-visible | [ ] 所有动画截图颜色一致 | [ ] 滚动正文和选择高亮可读 | 不应触发重新分页，但要触发 repaint |
| 阴影 | `bodyTextShadow*` | visual-only-but-page-visible | [ ] 阴影不被页边裁掉 | [ ] 滚动时不产生重影 | 大阴影半径可能需要内容 rect 留量策略 |
| 下划线 | `bodyTextDecoration*` | visual-only-but-page-visible | [ ] solid/dashed 不遮挡标注 | [ ] 跨行下划线连续 | 标注装饰和正文装饰需冲突验收 |
| 排版 | `lineHeight` | layout-signature | [ ] 行高改变页数稳定 | [ ] 可见段落不跳 | 已入 compatibility |
| 排版 | `letterSpacing` | layout-signature | [ ] 中文/英文断行变化可控 | [ ] 长句不抖 | 已补入 compatibility，仍需 UI 样本验收 |
| 排版 | `paragraphSpacing` | layout-signature | [ ] 页末段距不制造空白页 | [ ] 跨章高度稳定 | 已入 compatibility |
| 排版 | `paragraphIndent` | layout-signature | [ ] 首行缩进影响首行宽度 | [ ] 段首点击/选择位置正确 | 已入 compatibility |
| 排版对齐 | `textFullJustifyEnabled` | layout-signature | [ ] 中文两端对齐断行正确 | [ ] 滚动中不拉伸异常 | 已入 compatibility |
| 排版对齐 | `textBottomJustifyEnabled` | layout-signature-paged-only | [ ] 分页页末分配剩余高度 | [ ] 滚动模式禁用/不生效 | 代码里滚动模式已禁用，需要验收分页效果 |
| 正文边距 | `bodyMarginMode / bodyMarginPreset` | layout-signature + preset-policy | [ ] preset 切换页数重算 | [ ] 滚动可读区域稳定 | 当前 UI 主要暴露自定义数值，preset 策略需补验收 |
| 正文边距 | `bodyMarginTop/Bottom/Left/Right` | layout-signature | [ ] 拖动期间不闪白；[ ] 松手后重排 | [ ] 拖动期间滚动不抖 | 已做 deferred commit，但需要分页/滚动双验收 |
| 章节头 | `showChapterHeader` | layout-signature 或 first-page-content | [ ] 第一页内容起点正确 | [ ] 滚动顶部章节头不遮正文 | 当前设置组只聚合部分字段，需确认 UI 入口 |
| 章节头 | `chapterHeaderMode / chapterHeaderTopSpacing / chapterHeaderBottomSpacing` | layout-signature | [ ] 隐藏/居中/间距改变页数 | [ ] 滚动章标题高度正确 | 已补入 compatibility，仍需确认 UI 聚合和真实效果 |
| 章节头 | `chapterHeaderHorizontalOffset / chapterHeaderVerticalOffset` | chrome/layout boundary | [ ] 偏移不遮正文和信息栏 | [ ] 滚动顶部不跳 | 当前设置页有横向/纵向，需要横竖屏验收 |
| 固定章节头 | `pinnedChapterHeaderOffsetX/Y` | chrome-owned | [ ] 不影响正文页数 | [ ] 滚动悬浮位置正确 | 需要确认是否仍有 UI 入口及保存迁移 |
| 信息栏 | `infoHeaderEnabled / infoFooterEnabled` | chrome-owned, may affect content rect | [ ] 开关后正文不被遮挡；[ ] 页码同步 | [ ] 滚动安全区正确 | 当前布局面板重点暴露 footer，header 字段需确认入口 |
| 信息栏 | `infoShowTime/Battery/Chapter/Progress` | chrome-owned | [ ] 页面变化时进度刷新 | [ ] 滚动跨章 active chapter 刷新 | 电量读取失败已有文案，但真机要验收 |
| 信息栏 | `infoHeaderPadding / infoFooterPadding` | chrome-owned | [ ] padding 不触发正文闪动 | [ ] 拖动不抖 | UI 当前主要看到 footer，header 需补入口确认 |
| 信息栏 | `infoHeaderMargin* / infoFooterMargin*` | chrome-owned | [ ] margin 不改变正文页数，除非设计决定纳入 safe area | [ ] 拖动时正文不闪 | 用户反馈的“信息排版拖动闪”主要落在这里 |
| 信息栏 | `infoHeaderDividerEnabled / infoFooterDividerEnabled` | chrome-owned | [ ] 分割线不参与截图脏状态 | [ ] 滚动时无残影 | 开关关闭时 divider 应自动清理 |
| 主题 | `themeMode / backgroundStyle / backgroundTone` | chrome-owned + animation-visible | [ ] 动画底色一致 | [ ] 滚动底色全屏覆盖 | paperCurl/curl 是重点风险 |
| 背景图 | `backgroundImageBase64` | chrome-owned + animation-visible | [ ] 背景图不透下一页 | [ ] 滚动长内容不重复异常 | 大图内存峰值要 profile |
| 亮度 | `brightness / followSystemBrightness` | platform-owned | [ ] 不触发重排 | [ ] 退出阅读器恢复策略正确 | 必须 iOS/Android 真机验收 |
| 翻页模式 | `pageTurnMode` | interaction-owned + surface switch | [ ] 分页/滚动切换不丢进度 | [ ] 切回分页页码正确 | 新旧共存隐藏 bug 高发点 |
| 翻页动画 | `pageAnimationStyle` | interaction-owned + animation surface | [ ] 每个动画独立验收 | [ ] 滚动模式不误用动画 | compatibility 负责 owner，逐动画能力矩阵由 3.3 跟踪 |
| 滚动步长 | `pageTurnStepRatio` | interaction-owned-scroll | [ ] 分页不误用 | [ ] 点击滚动距离自然且保留可见行 | 如果改成 Legado 可见行逻辑，设置含义要重新定义 |
| 音量键 | `volumeKeyPageEnabled` | platform/input-owned | [ ] 分页跨章可翻 | [ ] 滚动步进可中断 | Android 真机必须测，桌面不应显示不可用能力 |
| 点击区域 | `tapZoneActions` | interaction-owned | [ ] 9 宫格动作与分页一致 | [ ] 滚动/选择/工具栏冲突正确 | 长按浮窗、工具栏显示时要屏蔽翻页 |
| 自动阅读 | `autoReadEnabled` | interaction-owned | [ ] 开启/关闭不丢当前页 | [ ] 开启/关闭不丢滚动位置 | 设置页 session 会关闭 autoRead，需要验收用户预期 |
| 自动阅读 | `autoReadMode / autoReadSpeed / autoReadSpeedLevel` | interaction-owned | [ ] page mode 秒/页准确 | [ ] scroll mode px/s 平滑 | 跨章、手动打断、暂停恢复是 P1 |
| 自动阅读 | `autoReadPauseMode / autoReadEndBehavior` | interaction-owned | [ ] 段落/章节结束暂停 | [ ] 书末 loop/nextBook 行为可控 | 需要和书架下一本/章节加载状态联动 |
| 漫画 | `mangaReadMode / mangaImageSpacing / mangaImagePadding / mangaLoadStrategy` | surface-owned | [ ] 文本分页不受影响 | [ ] 漫画连续滚动独立保存 | 设置面板必须按内容类型过滤有效项 |
| 音频 | `audioDefaultSpeed / audioRememberSpeed / audioSeekStepSeconds / audioAutoPlay` | surface-owned | [ ] 文本页码不受影响 | [ ] 音频进度独立保存 | 听书模式设置说明已有，但要验收保存隔离 |
| 换源 | `switchSourceScoreRankingEnabled` | data/source-owned | [ ] 不影响当前分页状态 | [ ] 不影响滚动状态 | 不属于排版设置，应避免混入 reader layout signature |

边距策略建议：

- [ ] 对外 UI 可以继续显示“数值边距”，用户更容易理解。
- [ ] 内部保存建议保留当前 px 语义，短期不要直接改百分比，避免老用户设置迁移造成阅读区域突变。
- [ ] 可以新增 preset 层使用百分比/设备分档计算默认值：小屏、平板、横屏、桌面窗口分别给不同默认边距。
- [ ] 自定义模式继续保存绝对值，但渲染时做 viewport clamp：左右边距总和不能超过可读宽度的安全比例，上下边距不能挤掉正文。
- [ ] 验收要覆盖横屏、分屏、iPad/桌面 resize；这比“全部改百分比”更稳。

### 3.5 当前最需要补的文档结论

- [ ] 不能再用“滚动已优化”代表阅读器可上线；分页、设置、专项能力必须分别给结论。
- [ ] 不能再用“动画已接入”代表动画 1:1；每个动画都要有同章、跨章、快速取消、背景遮罩记录。
- [ ] 不能再用“设置已保存”代表设置正确；每个设置必须有 owner，明确是否触发布局、是否只 repaint、是否只影响 shell。
- [x] 不能再用“有 legacy fallback”代表安全；旧 fallback 已移除，安全性必须来自单路径验收和版本回滚。
- [ ] 上线前至少要形成一张 pass/fail 表：分页 8 链路、界面设置 5 类 owner、样本 TXT/EPUB、真机 profile、回滚包。

---

## 4. 当前优化不到位的地方

### 4.1 P0：上线前必须补齐

- [ ] 真机 UI smoke：用 `docs/test_readr` 三个样本逐一记录首次打开、章节识别、翻页、滚动、设置变化、退出重进恢复。
- [ ] release 单路径 smoke：打开同一批样本，确认分页、动画、设置切换、搜索/朗读/标注不会触发 release failure 诊断页。
- [ ] profile mode 性能基线：首开耗时、连续翻页帧率、快速滚动 jank、内存峰值、图片章节峰值。
- [ ] 回滚演练：回退上一稳定版本/提交并实际打开阅读器验证。
- [x] 新旧共存压力测试改为历史项；当前重点是 release 单路径快速切换动画、滚动/分页、字号/边距、背景、横竖屏后状态不串。
- [ ] 搜索/目录跳转/书签跳转/朗读/自动阅读跨章做 UI 或集成验收。
- [ ] EPUB 真实 UI 验收：图片比例、点击预览/重试、caption/footnote/link、重排后位置恢复。
- [ ] 全项目门禁恢复：至少发布分支需要 `flutter analyze` 结论明确，非阅读器阻塞要修复或隔离。

### 4.2 P1：影响体验和放量信心

- [ ] 滚动点击距离改成可见行感知，追平 Legado 的“保留一行”逻辑。
- [ ] 连续滚动跨章从“多章节 ListView warmup”进一步抽象成稳定 page/window model，减少动态高度导致的跳动。
- [x] 新 renderer 原生承接 paperCurl/curl/cover/translate/fade/vertical。
- [ ] 选择/标注工具条补完整端到端矩阵：复制、保存灵感、编辑、删除、点击已有标注、跨页拖拽。
- [ ] 阅读记录/阅读时长/自动保存与新旧 renderer 统一，避免切 surface 后进度或统计异常。
- [ ] 图片 layout cache 与真实尺寸更新策略补齐，避免 EPUB 图片章节二次跳动。

### 4.3 P2：质量治理

- [ ] ReaderPage 仍是巨型 State + part 文件共享私有状态池，继续拆 facade/controller。
- [ ] 给 reader 增加端到端脚本或半自动验收记录模板，不再只靠人工口述。
- [ ] 补低端 Android、iOS 真机、桌面窗口变化的差异化验收记录。
- [ ] 将“可上线评估”从 V 文档进度中独立出来，作为 release checklist 固定复用。

---

## 5. 当前可上线等级评估

| 等级 | 是否建议 | 条件 |
|---|---|---|
| 开发内测 | 可以 | 保留新旧 fallback，继续按 reader 专项测试推进 |
| 小范围灰度 | 谨慎可以 | P0 smoke、profile、回滚包验证完成后；灰度期间保留 legacy |
| 全量用户默认新阅读器 | 暂不建议 | 必须补齐 P0，并至少完成滚动手感、搜索/朗读/自动阅读、EPUB UI 验收 |
| 删除旧阅读器 | 不建议 | 新 renderer 原生承接动画/选择/标注/搜索/朗读/自动阅读之前不能删 |
| 宣称 1:1 替代 | 不成立 | 当前仍有 fallback 和未验收能力 |

---

## 6. 发布前验收清单

### G0：代码门禁

- [ ] `flutter analyze` 发布范围通过，非阅读器阻塞有明确处理结论。
- [ ] `flutter test test/features/reader/application -r compact` 通过。
- [ ] `flutter test test/features/reader/presentation -r compact` 通过。
- [ ] 本地 TXT/EPUB parser tests 通过。

### G1：样本验收

- [ ] `《漫画万人嫌自救指南》作者：奶茶只喝微糖.txt`：首开、目录、滚动、分页、搜索、退出恢复。
- [ ] `【番20】《我在废土世界扫垃圾》作者：有花在野 (1).txt`：超长文本快速滚动、跨章、设置变化。
- [ ] `斗破苍穹(天蚕土豆).epub`：章节、图片、caption/link/footnote、分页、设置重排。

### G2：交互验收

- [ ] 点击分区、键盘、音量键、鼠标滚轮。
- [ ] 滚动模式快速连续点击，不能闪、不能吞输入、不能错误弹 loading。
- [ ] 滚动跨章向前/向后，边界只提示第一章/最后一章。
- [ ] 分页动画切换：无动画、覆盖、滑动、淡入、仿真、纸张卷页。
- [ ] 长按选择、拖拽、复制、灵感、已有标注点击。
- [ ] 搜索跳转、目录跳转、书签跳转、朗读高亮、自动阅读跨章。

### G3：性能验收

- [ ] Profile 首屏打开耗时记录。
- [ ] 连续翻页 30 秒帧率记录。
- [ ] 滚动模式快速滚动 30 秒 jank 记录。
- [ ] 字号/边距/背景连续调整内存峰值记录。
- [ ] EPUB 图片章节内存峰值记录。

### G4：回滚和灰度

- [ ] 默认包验证新 renderer。
- [ ] 版本/提交回滚演练。
- [ ] release 单路径验收包验证新阅读器完整接手。
- [ ] diagnostics 能记录 release renderer 状态、page count、failure reason。
- [ ] 灰度反馈入口和问题收集字段明确。

---

## 7. 建议下一步

- [ ] 新增一个 V8 或 Release Readiness 节点，但不要继续只按“功能开发阶段”推进。
- [ ] V8-P0 只做上线门禁：样本 UI smoke、profile、回滚包、全项目门禁。
- [ ] V8-P1 做 Legado 对齐的滚动手感：可见行感知滚动距离、跨章窗口稳定化、快速输入压测。
- [ ] V8-P2 做新 renderer 1:1：动画原生承接、搜索/朗读/自动阅读 UI 验收、EPUB 图片策略。
- [ ] 完成 V8-P0 后再决定是否扩大灰度；完成 V8-P1/P2 后再讨论删除旧阅读器。

---

## 8. V8 阶段性任务拆分

**V8 目标**: 不是继续堆功能，而是把新阅读器从“代码已接入”推进到“现有用户可稳定使用、能灰度、能回滚、知道哪些功能还不能删除旧实现”。
**当前进度**: 50%。阶段 0-8 已完成自动化门禁、样本基线、设置 owner 矩阵代码补齐、专项能力/多 surface/性能预算定向测试和当前上线决策；分页/滚动/设置/朗读/亮度/回滚包仍缺真机 UI 验收，不能据此认定可全量上线。

进度口径：

- [x] 0%：完成阶段计划和验收矩阵。
- [x] 30%：完成 P0 自动化门禁，能证明当前代码基线可进入真机 smoke。
- [ ] 60%：完成分页、滚动、设置三条主链路的高风险体验修复。
- [ ] 85%：完成搜索、书签、朗读、自动阅读、选择标注、EPUB 混排专项验收。
- [ ] 100%：完成旧阅读器删除条件复核，并形成是否删除旧阅读器的结论。

### 阶段 0-4 执行记录（2026-06-21）

| 阶段 | 状态 | 已完成 | 未完成/风险 |
|---|---|---|---|
| 阶段 0：冻结基线 | 部分完成 | 已确认 `docs/test_readr` 三个样本、文件大小、EPUB HTML 条目数、默认/legacy 开关位置、设置入口与动画枚举 | 还未逐样本记录首屏文字、目标搜索词、章节末尾跨章位置 |
| 阶段 1：代码门禁 | 自动化完成 | reader analyze、全项目 analyze、application、presentation、本地 parser 测试均通过 | 默认包/回滚版本“实际打开阅读器”仍需模拟器或真机手工 smoke |
| 阶段 2：分页 | 自动化覆盖完成 | 已由 presentation/application 测试覆盖动画 registry、paged transition、paperCurl runtime、cross chapter snapshot、EPUB paged smoke | 每种动画的同章/跨章/快速取消还未真机逐项 pass/fail |
| 阶段 3：滚动 | 自动化覆盖完成 | 已由 scroll renderer、viewport builder、selection area、EPUB scroll smoke 覆盖基础链路 | Legado 手感级对齐、快速猛点、跨章自然滚动仍需真机验收和可能继续修复 |
| 阶段 4：界面设置 | 代码补齐完成 | 已补 `ReaderLayoutSettingsCompatibilityMatrix`，覆盖 layout/chrome/platform/visual/interaction/surface/data owner，并新增测试 | 字体、边距、信息栏、亮度、背景图、点击区域仍需真机 UI 验收 |
| 阶段 5：专项能力 | 自动化覆盖完成 | 定向测试覆盖搜索/目录、跳转、书签恢复、标注、分页长按选择、自动阅读、阅读记录 | 朗读真实播放、高亮跟随、灵感工具窗完整交互仍需真机 UI 验收 |
| 阶段 6：多 surface | 自动化覆盖完成 | 定向测试覆盖 EPUB parser、PDF parser、local chapter content、manga/audio/runtime ratio、EPUB/manga widget smoke | 真实 EPUB 大目录打开、图片失败重试、PDF/漫画/音频完整用户流仍需真机验收 |
| 阶段 7：性能压力 | 策略/Widget smoke 完成 | 定向测试覆盖 performance budget、resource budget、image decode budget、rendering memory smoke | Android/iOS profile 帧率、jank、内存峰值仍未采集 |
| 阶段 8：上线决策 | 已形成当前结论 | 当前可进入真机 smoke/内部灰度准备；不建议跳过 profile 和回滚演练直接全量 | 需要默认包和回滚版本都实际打开通过后，才讨论外部灰度 |

样本基线：

| 样本 | 类型 | 大小 | 当前记录 |
|---|---|---:|---|
| `《漫画万人嫌自救指南》作者：奶茶只喝微糖.txt` | TXT 普通/论坛混排章节 | 3,724,610 bytes | 命中约 289 个章节标题候选，适合章节识别、论坛标题、滚动/分页恢复 |
| `【番20】《我在废土世界扫垃圾》作者：有花在野 (1).txt` | TXT 超长文本 | 7,406,776 bytes | `rg` 章节标题规则未直接命中，适合测试弱章节识别、超长滚动和导入策略 |
| `斗破苍穹(天蚕土豆).epub` | EPUB | 8,825,090 bytes | zip 内 1679 个条目、1674 个 HTML 章节、1 个图片资源，适合 EPUB 大目录和分页缓存 |

手工验收记录模板：

| 日期 | 设备/系统 | 样本 | renderer | 模式/动画 | 操作 | 预期 | 结果 | 截图/录屏 | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 待填 | iOS 模拟器 / 真机 / Android / macOS | 待填 | release / legacy / fallback | paged-none / paged-paperCurl / scroll / settings | 待填 | 待填 | pass / fail / blocked | 待填 | 待填 |

自动化门禁结果：

- [x] `flutter analyze lib/features/reader test/features/reader`：通过。
- [x] `flutter test test/features/reader/application -r compact`：通过，580 tests passed。
- [x] `flutter test test/features/reader/presentation -r compact`：通过，192 tests passed。
- [x] `flutter test test/features/reader/application/local -r compact`：通过，107 tests passed。
- [x] `flutter analyze`：通过。
- [x] 阶段 4/5 定向测试：设置、搜索/目录、跳转、书签、标注、分页长按选择、自动阅读、阅读记录通过，76 tests passed。
- [x] 阶段 6/7 定向测试：EPUB/PDF/local content、多 surface、runtime、性能/资源/图片预算、rendering smoke 通过，78 tests passed。
- [ ] 默认包实际打开阅读器：待真机/模拟器 smoke。
- [ ] 版本回滚后实际打开阅读器：待真机/模拟器 smoke。

执行中观察到的非阻塞项：

- [ ] Flutter analyze/test 均提示 `dynamic_app_icon_flutter_plus`、`device_info_plus` 暂不支持 iOS/macOS Swift Package Manager。这是未来 Flutter 版本风险，不是当前 reader 编译错误。
- [ ] application/local 测试有 Drift `AppDatabase` 多实例 debug warning，测试通过，但后续测试治理可清理，避免日志干扰。
- [ ] `flutter devices` 能看到 iOS 模拟器、macOS、Chrome；无线真机 `小张的 iPhone 16 Plus` 未连接成功，需要解锁/同网/Developer Mode。

### 阶段 0：冻结基线与样本准备

**目标**: 先冻结当前行为，避免一边修一边不知道退化了哪里。

- [x] 记录当前默认 renderer、failure diagnostics、版本回滚策略。
- [x] 整理 `docs/test_readr` 样本清单：TXT 长文本、TXT 普通章节、EPUB 图文混排。
- [ ] 为每个样本记录：首开章节、章节数、首屏文字、目标搜索词、章节末尾跨章位置。
- [x] 记录当前分页动画可选项和默认值。
- [x] 记录当前界面设置入口：字体、主题背景、界面设置、翻页行为、自动阅读、漫画、音频。
- [x] 建立一张手工验收记录表，字段包含设备、系统、样本、renderer、模式、结果、截图/录屏位置。
- [ ] 阶段完成：基线文档可复现，后续每次改动都能回到同一批样本验证。

**当前进度**: 75%。缺首屏文字、搜索词、章节末尾跨章点位的人工记录。

### 阶段 1：P0 代码门禁与回滚门禁

**目标**: 先确认当前工程能发、能测、能回。

- [x] 跑阅读器范围 analyze：`flutter analyze lib/features/reader test/features/reader`。
- [x] 跑阅读器 application 测试。
- [x] 跑阅读器 presentation 测试。
- [x] 跑本地导入/TXT/EPUB parser 相关测试。
- [x] 跑一次全项目 `flutter analyze`，记录非阅读器阻塞项。
- [ ] 使用默认配置启动阅读器，确认新 renderer 路径生效。
- [ ] 回退上一稳定版本/提交并启动阅读器，确认版本回滚可用。
- [ ] 阶段完成：默认包和回滚版本都能打开阅读器，代码门禁结果有明确记录。

**当前进度**: 70%。自动化门禁完成；实际打开默认阅读器和回滚版本待真机或模拟器 smoke。

### 阶段 2：分页主链路验收与修复

**目标**: 把分页从“能翻”验收到“可作为默认阅读方式”。

- [ ] 验收 `none` 动画：同章翻页、跨章翻页、快速点击、退出恢复。
- [ ] 验收 `cover` 动画：下一页不提前透出、跨章不残影、快速反向操作。
- [ ] 验收 `translate` 动画：位移方向、进度同步、连续点击不跳页。
- [ ] 验收 `fade` 动画：无闪白、不叠多层 opacity、深浅主题可读。
- [ ] 验收 `vertical` 动画：不和滚动模式冲突，边界提示正确。
- [ ] 验收 `curl` 动画：拖拽、取消回弹、跨章降级、背景遮罩。
- [ ] 验收 `paperCurl` 动画：截图生命周期、内存峰值、背景不透、旧图不残留。
- [ ] 快速点击 20 次：不能吞页、不能页码错乱、不能显示旧页残影。代码层已补普通动画/curl/paperCurl 中断提交、滚动取消不再 jump、滚动边缘保留输入来源、章节/loading pending 续接，仍需真机 pass/fail。
- [ ] 修复验收中发现的 P0 分页问题。
- [ ] 对未过关动画制定策略：禁用、降级、还是继续修复。
- [ ] 阶段完成：每个动画都有 pass/fail 结论，默认动画没有 P0 级坏状态。

**当前进度**: 35%。自动化覆盖通过，但还没有真机逐动画 pass/fail；暂不能声明分页体验已验收完成。

### 阶段 3：滚动主链路验收与修复

**目标**: 对齐 Legado 的自然滚动、快速响应、跨章稳定。

- [ ] 验收点击滚动：单次点击、连续点击、动画中继续点击。
- [ ] 验收滚动跨章：向下一章、向上一章、第一章边界、最后章边界；点按滚动到边缘后继续点应续接，不应弹处理中提示。
- [ ] 验收滚动中长按：能唤起选择/灵感工具窗。
- [ ] 验收滚动中目录跳转、搜索跳转、书签跳转。
- [ ] 将滚动点击距离改成可见行感知或给出不改的明确原因。
- [ ] 验证跨章 warmup 是否足够覆盖快速猛点和快速滚动。
- [ ] 修复滚动跨章 active chapter、offset 抖动、闪烁问题。
- [ ] 阶段完成：滚动模式不再出现用户已反馈的闪、断、不能长按、跨章异常。

**当前进度**: 35%。自动化覆盖通过，但 Legado 手感、快速猛点、跨章自然滚动仍需真机验收。

### 阶段 4：界面设置逐字段验收与修复

**目标**: 设置页不是“能保存”，而是每个设置都有 owner，不误触发、不闪、不串状态。

- [ ] 验收字体/字号/字重/自定义字体：分页和滚动都能稳定重排。
- [ ] 验收行距、字距、段距、缩进：拖动和松手后的重排策略正确。
- [ ] 验收正文边距：分页/滚动都不闪，横竖屏和小屏不挤掉正文。
- [ ] 确认边距策略：短期保留 px 语义，preset 可按设备分档，渲染层做 clamp。
- [ ] 验收章节头：显示/隐藏/偏移/间距不遮正文和信息栏。
- [ ] 验收信息栏：时间、电量、章节、进度、padding、margin、divider。
- [ ] 验收背景和主题：纯色、纸张、暖色、自定义背景图、深色模式。
- [ ] 验收亮度：iOS/Android 真机进入、调整、退出恢复。
- [ ] 验收点击区域：9 宫格动作在分页、滚动、工具栏、选择状态下不冲突。
- [x] 补齐 `ReaderLayoutSettingsCompatibilityMatrix` 或同等 owner 文档，让字段归属和真实设置页一致。
- [ ] 阶段完成：设置改动不会制造正文闪动、页码串旧、进度丢失或跨 surface 污染。

**当前进度**: 55%。字段 owner 代码和测试已补齐；设置面板定向测试通过；真实拖动、亮度、背景图、信息栏、点击区域仍需真机 UI 验收。

### 阶段 5：专项能力等价验收

**目标**: 补齐旧阅读器已有能力，避免用户切到新阅读器后发现常用功能不能用。

- [x] 搜索：搜索结果跳转、高亮、跨章搜索、退出搜索恢复的 application 层自动化覆盖已通过。
- [x] 目录：章节跳转、章节末尾跳转、切换分页/滚动后目录进度的跳转/entry resolver 自动化覆盖已通过。
- [x] 书签：添加、删除、跳转、退出重进恢复的 range/restore/route 自动化覆盖已通过。
- [x] 选择标注：长按、拖选、复制、已有标注点击、跨页边界的 controller/paged view 自动化覆盖已通过。
- [ ] 朗读：从当前页开始、高亮跟随、跨页、跨章、手动翻页同步。
- [x] 自动阅读：分页自动翻页、滚动自动滚、暂停恢复、手动打断、书末行为的 coordinator 自动化覆盖已通过。
- [x] 阅读记录：阅读时长、最后阅读位置、切 renderer 后统计不重复不丢的 coordinator/metrics 自动化覆盖已通过。
- [ ] 阶段完成：旧阅读器常用功能在新 renderer 下都有 pass/fail 结论；fail 项不得进入删除旧阅读器范围。

**当前进度**: 60%。专项能力自动化覆盖已通过；朗读真实播放、高亮跟随、灵感工具窗完整 UI 流仍需真机验收。

### 阶段 6：EPUB / 图片 / 多 Surface 验收

**目标**: 不让文本阅读器改造污染漫画、PDF、音频，也不让 EPUB 混排成为上线盲区。

- [x] EPUB 文本章节：parser、local content、paged/scroll widget smoke 自动化覆盖已通过。
- [x] EPUB 图片章节：图片章节、SVG、inline marker、decode budget 自动化覆盖已通过。
- [x] EPUB 图文混排：caption、link/footnote、structured blocks、mixed media parser 自动化覆盖已通过。
- [x] 漫画连续模式：manga continuous widget smoke 和 runtime ratio 自动化覆盖已通过。
- [x] 漫画分页/横向模式：manga paged/horizontal widget smoke 和 runtime ratio 自动化覆盖已通过。
- [x] PDF surface：PDF parser 轻量索引、懒加载正文自动化覆盖已通过。
- [x] 音频 surface：audio mode、runtime ratio、controller 自动化覆盖已通过。
- [ ] 阶段完成：文本、漫画、PDF、音频、EPUB 混排的进度语义互不污染。

**当前进度**: 65%。多 surface 自动化覆盖已通过；真实样本打开、图片失败重试、PDF/漫画/音频完整用户流仍需真机验收。

### 阶段 7：真机性能与压力验收

**目标**: 补上“能用”和“好用”之间最容易被忽略的性能证据。

- [ ] Android 真机 profile：首屏打开耗时。
- [ ] Android 真机 profile：连续分页 30 秒帧率和 jank。
- [ ] Android 真机 profile：滚动 30 秒帧率和 jank。
- [ ] Android 真机 profile：paperCurl/curl 内存峰值。
- [ ] iOS 真机 smoke：亮度、音量键替代行为、系统手势冲突。
- [ ] 平板/横屏/桌面窗口 resize：重排、进度、截图尺寸。
- [ ] 低端设备或模拟低性能：长 TXT、EPUB 图片章节压力。
- [x] 自动化性能预算：foreground page turn、parser/pagination chunking、resource budget、image decode budget、rendering memory smoke 已通过。
- [ ] 阶段完成：有可引用的 profile 数据，默认策略不会把高风险动画推给所有用户。

**当前进度**: 25%。性能预算和 widget smoke 已通过；真机 profile 数据仍为空，所以不能据此判断放量性能。

### 阶段 8：上线决策与旧阅读器处理

**目标**: 给出明确决策：能否灰度、能否默认、旧阅读器保留还是删除。

- [x] 汇总阶段 0-7 的 pass/fail。
- [x] 列出必须上线前修复的 P0。
- [x] 列出可灰度观察的 P1。
- [x] 列出可以后续优化的 P2。
- [x] 决定默认动画和默认翻页模式。
- [x] 决定是否开放全部动画，还是按能力禁用部分动画。
- [x] 决定是否小范围灰度新 renderer。
- [x] 决定旧阅读器是否继续保留 fallback。
- [ ] 若考虑删除旧阅读器，必须确认新 renderer 已原生承接分页动画、滚动、搜索、目录、书签、选择标注、朗读、自动阅读、EPUB、漫画/PDF/音频隔离。
- [ ] 阶段完成：形成“可上线 / 可灰度 / 不可上线 / 是否删除旧阅读器”的最终结论。

**当前进度**: 80%。当前结论已形成：自动化门禁允许进入真机 smoke；未完成真机 smoke、profile、legacy 回滚包前，不建议外部灰度、全量默认或删除旧阅读器。

当前上线决策：

- [x] 当前可以进入：模拟器/真机 smoke、内部人员试用、继续补用户体验修复。
- [ ] 当前不建议：直接全量默认新阅读器。
- [x] 旧阅读器 fallback 已删除，后续不再以旧路径作为上线兜底。
- [ ] 当前不建议：向外部用户扩大灰度，除非默认包 smoke/profile 和版本回滚演练都通过。
- [x] 默认策略建议：继续保留当前默认配置，但灰度前要在设置页对未真机通过的高风险动画保持可降级策略。
- [x] 旧阅读器策略建议已更新：不保留包内 fallback，改用版本回滚，并补分页动画、滚动跨章、朗读、选择标注、EPUB 多 surface、真机性能 pass 记录。

P0 未完成：

- [ ] 默认包实际打开阅读器 smoke。
- [ ] release 单路径实际打开阅读器 smoke。
- [ ] 版本回滚演练实际打开阅读器 smoke。
- [ ] 每种分页动画同章/跨章/快速取消真机验收。
- [ ] 滚动快速点击、跨章、长按工具窗真机验收。
- [ ] 亮度、音量键、系统手势真机验收。
- [ ] Android/iOS profile 数据采集。

P1 可灰度观察：

- [ ] Legado 级滚动手感继续优化。
- [ ] EPUB 图片失败重试、caption/link/footnote 真实样本验收。
- [ ] 朗读高亮跨页/跨章真实播放验收。

P2 后续治理：

- [ ] Drift 测试多实例 debug warning 治理。
- [ ] 自动化 UI smoke 脚本化，减少人工表格依赖。
- [ ] ReaderPage 继续拆 controller/facade，降低新旧共存状态风险。
