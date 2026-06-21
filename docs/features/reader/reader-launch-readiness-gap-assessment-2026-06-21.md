# 阅读器上线可用性差距评估：Legado MD3 / own 对照

**日期**: 2026-06-21  
**参考源码**:

- `/Users/zhangyuanlong/Downloads/legado-with-MD3-main`
- `/Users/zhangyuanlong/Downloads/legado-own`

**当前结论**: 现在不能把“新阅读器已经 1:1 替代旧阅读器”作为上线结论。更准确的判断是：阅读器专项代码门禁已通过，文本阅读核心链路已有明显改善，但仍缺少产品级可用性验收、真机性能基线、功能等价矩阵复核和回滚包验证。可做小范围灰度，但不建议删除旧阅读器或面向全部用户宣称新阅读器完全稳定。

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

- [x] 文本分页新 renderer 已接入正式入口，并有 legacy fallback。
- [x] 新旧 renderer authority 已拆开，page count/page index 不再完全隐式共享。
- [x] 未桥接的翻页动画可以显式回落 legacy，避免静默失效。
- [x] selection active gate、annotation range、settings signature、layout cache、anchor readiness 已有测试覆盖。
- [x] 连续滚动已补当前章节前后一章 warmup，不再只靠接近边缘时触发。
- [x] 滚动点击翻页已改为可中断/续接，快速点击不再因 `_isScrollStepAnimating` 被直接吞掉。
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
| 动画 | 旧动画与 page factory 深度融合 | 新 renderer 未完整桥接，部分 fallback legacy | 可用但不是 1:1；共存期间仍有隐藏状态风险 |
| 选择/标注 | 当前页模型能给行列坐标，长按/选择/朗读共用 | 新 layout 有 anchor，但工具链仍需端到端验收 | 灵感、复制、已有标注唤起可能存在边界遗漏 |
| 搜索/朗读/自动阅读 | 与章节/页/行模型绑定 | anchor mapper 有测试，UI 行为未完整验收 | 搜索跳转、高亮、自动阅读跨章仍是 P0/P1 风险 |
| 性能基线 | 原生 Canvas 绘制，可控预渲染 | Flutter widget/layout + snapshot/cache | 缺 profile 真机数据，不能只凭单测判断 |
| 回滚 | 单一原生阅读器，无新旧混跑 | 有 dart-define fallback，但未完整出包验证 | 发布前必须有可执行回滚包 |

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

---

## 4. 当前优化不到位的地方

### 4.1 P0：上线前必须补齐

- [ ] 真机 UI smoke：用 `docs/test_readr` 三个样本逐一记录首次打开、章节识别、翻页、滚动、设置变化、退出重进恢复。
- [ ] profile mode 性能基线：首开耗时、连续翻页帧率、快速滚动 jank、内存峰值、图片章节峰值。
- [ ] 回滚包验证：使用 `--dart-define=READER_LAYOUT_FORCE_LEGACY=true` 打包并实际打开阅读器验证。
- [ ] 新旧共存压力测试：快速切换动画、滚动/分页、字号/边距、背景、横竖屏后状态不串。
- [ ] 搜索/目录跳转/书签跳转/朗读/自动阅读跨章做 UI 或集成验收。
- [ ] EPUB 真实 UI 验收：图片比例、点击预览/重试、caption/footnote/link、重排后位置恢复。
- [ ] 全项目门禁恢复：至少发布分支需要 `flutter analyze` 结论明确，非阅读器阻塞要修复或隔离。

### 4.2 P1：影响体验和放量信心

- [ ] 滚动点击距离改成可见行感知，追平 Legado 的“保留一行”逻辑。
- [ ] 连续滚动跨章从“多章节 ListView warmup”进一步抽象成稳定 page/window model，减少动态高度导致的跳动。
- [ ] 新 renderer 原生承接 paperCurl/curl/cover/translate/fade/vertical，减少长期 legacy fallback。
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
- [ ] `READER_LAYOUT_FORCE_LEGACY=true` 回滚包验证旧阅读器可用。
- [ ] diagnostics 能记录 renderer：legacy / release / fallback。
- [ ] 灰度反馈入口和问题收集字段明确。

---

## 7. 建议下一步

- [ ] 新增一个 V8 或 Release Readiness 节点，但不要继续只按“功能开发阶段”推进。
- [ ] V8-P0 只做上线门禁：样本 UI smoke、profile、回滚包、全项目门禁。
- [ ] V8-P1 做 Legado 对齐的滚动手感：可见行感知滚动距离、跨章窗口稳定化、快速输入压测。
- [ ] V8-P2 做新 renderer 1:1：动画原生承接、搜索/朗读/自动阅读 UI 验收、EPUB 图片策略。
- [ ] 完成 V8-P0 后再决定是否扩大灰度；完成 V8-P1/P2 后再讨论删除旧阅读器。
