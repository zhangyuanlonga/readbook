# MD3 书源手工迁移策略（2026-05-08）

用途：作为当前项目围绕 `MD3 / 阅读` 书源能力迁移的独立判断文档。  
这份文档不沿用历史兼容文档的分期结构，也不以“继续兼容旧格式”为前提，只回答当前最重要的问题：

- 现在这个项目到底应该把自己定位成什么
- 未来怎么走会更简单
- MD3 / 阅读书源应该如何迁移到当前项目

---

## 1. 当前结论

先说结论：

1. 当前项目不是“直接兼容 MD3 / 阅读 JSON 书源”的执行器。
2. 当前项目也不应该回到“旧规则 JSON 直接执行”的主路线。
3. 当前项目最适合的定位是：
   - **脚本源运行时为唯一执行主线**
   - **MD3 / 阅读书源作为人工迁移参考来源**
4. 迁移方式不走“自动转换”，而走：
   - **对照表**
   - **模板**
   - **手工改写**

一句话概括：

**当前项目未来应当做“规范化 `.js` 书源平台”，而不是“阅读 JSON 书源兼容器”。**

---

## 2. 为什么不继续走“直接兼容阅读书源”

历史上项目确实走过“兼容阅读书源”的路线。旧版里存在：

- `LegadoSourceRaw`
- `LegadoSourceAdapter`
- 兼容矩阵分析工具
- 围绕 `bookSourceUrl / ruleSearch / ruleBookInfo / ruleToc / ruleContent` 的导入与测试

这说明旧版不是误打误撞，而是明确尝试过“直接兼容阅读书源”。

但这条路的问题也很明确：

1. 阅读书源不是单纯字段兼容问题
   - 它本质上是 **HTTP + 规则 + JS + WebView + 登录态** 的组合运行时
2. 旧 JSON 字段太散
   - `searchUrl`
   - `ruleSearch`
   - `ruleBookInfo`
   - `ruleToc`
   - `ruleContent`
   - `loginUi`
   - `loginCheckJs`
   - `webJs`
   - `sourceRegex`
   - `enabledCookieJar`
   - 以及更多长尾字段
3. 很多能力不是“字段等价”，而是“运行时语义等价”
4. 一旦把 JSON 旧格式直接放进执行主链，项目会长期背着两套心智：
   - 旧规则心智
   - 新脚本心智

这会让后续维护越来越重。

所以：

**旧版路线可以作为经验，但不应该作为未来主线。**

---

## 3. 当前项目真正已经具备的东西

当前项目虽然已经放弃直接执行旧 JSON，但并不是能力弱，反而已经有一套相对完整的书源运行时：

### 3.1 统一执行入口

当前项目已经把书源统一成脚本源执行：

- `search(ctx, keyword)`
- `detail(ctx, book)`
- `chapters(ctx, book)`
- `content(ctx, book, chapter)`

这说明项目已经有明确的主运行时模型。

### 3.2 统一运行时上下文

当前项目已经把宿主能力抽到了统一上下文里，包括：

- `ctx.http`
- `ctx.browser`
- `ctx.cookie`
- `ctx.sourceLogin`
- `ctx.bookState`
- `ctx.cache`
- `ctx.html`
- `ctx.crypto`
- `ctx.ui`
- `ctx.session`

这意味着项目已经具备承接复杂源的核心底座。

### 3.3 浏览器态能力

当前项目并不是没有 WebView / 浏览器能力，而是已经有：

- 浏览器打开
- 交互式挑战页
- 页面脚本执行
- `sourceRegex` 资源嗅探
- `overrideUrlRegex` 跳转匹配
- `webViewDelay`
- Cookie 同步

这已经覆盖了阅读生态里最难的一块之一。

### 3.4 登录能力

当前项目也不是没有登录能力，而是已经具备：

- `loginUi`
- `loginUrl`
- `login action`
- `login header`
- `login info`
- `source variable`
- `loginCheckJs` 最小兼容层
- 浏览器登录页回写 cookie

所以当前项目的问题不是“没有能力”，而是：

**还没有把这些能力整理成一套清晰、稳定、便于迁移的书源规范。**

---

## 4. 当前项目应该如何定位

从今天开始，建议统一口径：

### 4.1 执行层定位

**脚本源是唯一执行格式。**

不再把“旧规则 JSON 直接执行”作为主路线。

### 4.2 迁移层定位

**MD3 / 阅读书源是迁移参考输入，不是运行时输入。**

也就是说：

- 用户可以参考 MD3 / 阅读书源
- 用户可以按照对照表改写
- 项目可以提供迁移模板和帮助
- 但运行时最终只吃项目自己的 `.js` 书源

### 4.3 对外表达

更适合的对外表达方式是：

> 当前项目运行的是平台原生 `.js` 书源；  
> MD3 / 阅读书源可以作为参考，通过对照表手工迁移到当前项目。

而不是说：

> 当前项目兼容阅读 JSON 书源。

后者会持续引发误解。

---

## 5. 未来怎么走会更简单

未来最简单的路线不是回到旧版，也不是继续完全自由脚本，而是：

### 5.1 保持 `.js` 为官方载体

这点短期不需要改。

原因：

- 当前运行时已经围绕 `.js` 建好了
- 当前登录、浏览器、UI bridge 都是 `.js` 模型
- 强行换成 `.json` / `.yaml` 不会让问题立刻变简单

所以：

**文件后缀继续是 `.js`。**

### 5.2 把 `.js` 从“自由脚本”升级成“规范化脚本”

关键不是换后缀，而是规范脚本结构。

目标应该是：

- 仍然 `export default { ... }`
- 但结构明确
- 主体声明清楚
- 可扩展区有限

也就是：

```js
export default {
  meta: {...},
  capabilities: [...],

  async search(ctx, keyword) {...},
  async detail(ctx, book) {...},
  async chapters(ctx, book) {...},
  async content(ctx, book, chapter) {...},

  loginUi: ...,
  loginUrl: ...,
  loginCheckJs: ...,
}
```

再往后演进，也应该是：

- **主流程区固定**
- **登录区固定**
- **浏览器区固定**
- **少量 hook 保留灵活性**

### 5.3 迁移方式固定为“人工对照改写”

不做自动转换。

原因：

1. 复杂源自动转换质量不可控
2. 自动转换后生成的脚本通常更难维护
3. 既然最终还是 `.js`，人工重写更容易理解和长期维护

这条路最适合当前项目。

---

## 6. 迁移的本质：不是字段兼容，而是能力对照

这里是整个迁移策略里最重要的认识。

迁移不是：

- `ruleSearch` 换个名字
- `sourceRegex` 原样搬过来
- `loginUi` 直接塞进项目

迁移真正要做的是：

**把阅读字段背后的能力，对应到当前项目自己的运行时能力上。**

### 6.1 例子：`sourceRegex`

阅读里的 `sourceRegex` 本质是：

- 浏览器态资源嗅探

当前项目里对应的是：

- 浏览器执行
- 资源 URL 匹配
- 命中后取回 `matchedResourceUrl`

所以迁移时用户要理解的是：

- 不是“字段名字一样就行”
- 而是“这个能力在当前项目怎么表达”

### 6.2 例子：`loginCheckJs`

阅读里的 `loginCheckJs` 本质是：

- 请求后检测登录状态
- 必要时修正 header/cookie
- 重放请求

当前项目里对应的是：

- `ctx.http.request()` 包装层里的登录检测链

所以迁移时用户要理解的是：

- 这是“请求后恢复登录”的能力
- 而不是“某个脚本字段的原样搬运”

### 6.3 例子：`loginUi`

阅读里的 `loginUi` 本质是：

- 动态登录表单
- 按钮动作
- 表单数据回写
- 必要时打开浏览器

当前项目里对应的是：

- `loginUi`
- `login action`
- `ctx.ui.openBrowserAwait`
- `ctx.sourceLogin`

迁移关注点应当是：

- 动态字段如何写
- 动作如何写
- 登录态如何保存

而不是“这个 JSON 原样能不能读进来”。

---

## 7. 未来规范应该怎么组织

虽然官方载体继续用 `.js`，但内容组织要逐步固定。

建议从今天开始，把平台原生书源划成下面几个能力区：

### 7.1 `meta`

表达书源静态信息：

- 名称
- 分组
- 作者
- 描述
- 主页
- 域名
- 能力标签

### 7.2 主流程区

固定四个核心入口：

- `search`
- `detail`
- `chapters`
- `content`

它们是所有源最核心的执行入口。

### 7.3 `discover`

表达发现页能力：

- 分类列表
- 分类书籍列表

### 7.4 `login`

表达登录能力：

- `loginUi`
- `loginUrl`
- `login`
- `loginAction`
- `loginCheckJs`

即使目前仍然散落在对象顶层，文档和规范层也应该把它们视为一个能力域，而不是零碎字段。

### 7.5 `browser`

表达浏览器态能力：

- `webView`
- `webJs`
- `sourceRegex`
- `overrideUrlRegex`
- `webViewDelay`

### 7.6 `state`

表达状态能力：

- `sourceLogin`
- `bookState`
- `cookie`
- `cache`
- `session`

### 7.7 `ui`

表达宿主交互能力：

- `toast`
- `confirm`
- `prompt`
- `openBrowserAwait`
- `verification code`

这样做的意义是：

**虽然文件还是 `.js`，但书源已经不再是“任意 JS”，而是“按平台能力分区组织的脚本源”。**

---

## 8. 用户迁移时应该怎么做

既然不做自动转换，用户手工迁移应该遵循固定顺序。

建议统一为：

### 第一步：先迁 `meta`

把这些字段先对齐：

- `bookSourceName`
- `bookSourceGroup`
- `bookSourceUrl`
- `bookSourceComment`
- `bookSourceType`

对应到当前项目：

- `meta.name`
- `meta.group`
- `meta.homepage`
- `meta.description`
- `meta.capabilities`

### 第二步：再迁主流程

依次迁：

1. `search`
2. `detail`
3. `chapters`
4. `content`

不要一上来把所有逻辑糊在一个函数里。

### 第三步：再迁复杂能力

只在源真的需要时再迁：

- `loginUi`
- `loginUrl`
- `loginCheckJs`
- `webJs`
- `sourceRegex`

### 第四步：最后处理长尾能力

包括：

- `formatJs`
- `preUpdateJs`
- `replaceRegex`
- `nextContentUrl`
- 图片/音频/支付/段评等特殊逻辑

---

## 9. 文档体系应该怎么建设

如果未来要让这件事真正变简单，不靠口头理解，建议只保留三类文档：

### 9.1 官方书源规范文档

回答：

- 书源对象应该长什么样
- 每个入口该做什么
- `ctx.*` 能做什么

### 9.2 MD3 / 阅读手工迁移对照表

回答：

- 阅读字段的含义
- 当前项目对应能力
- 迁移时写到哪里
- 示例怎么写

### 9.3 复杂能力专题文档

只针对高复杂项单独写：

- 登录
- 浏览器态 / WebView
- `sourceRegex`
- 漫画 / 图片型正文
- 高级状态与变量

不再继续把“历史兼容治理文档”和“未来书源规范文档”混在一起。

---

## 10. 当前最适合优先补齐的东西

如果按“让手工迁移更容易”排序，建议优先做这些：

### 第一优先级

1. 一份正式的 MD3 -> 当前 `.js` 书源对照表
2. 三个官方模板：
   - 普通 HTML 小说源
   - JSON API 源
   - 登录 + 浏览器源
3. 一个固定的复杂源示例集

### 第二优先级

1. 把当前项目里“已支持但不明显”的能力写入正式文档
   - `ctx.browser`
   - `ctx.sourceLogin`
   - `ctx.bookState`
   - `ctx.ui.openBrowserAwait`
2. 用真实复杂样本源回归
   - `loginUi`
   - `loginCheckJs`
   - `sourceRegex`

### 第三优先级

1. 对脚本编辑器做少量辅助
   - 只做“对照式帮助”
   - 不做全自动转换

---

## 11. 不建议再做的事情

为了保持未来路线简单，建议明确不做：

1. 不再恢复“旧阅读 JSON 直接执行”的主链
2. 不再让项目同时维护：
   - JSON 规则运行时
   - 脚本运行时
3. 不再把“导入旧源”和“执行旧源”绑在一起
4. 不再用“兼容阅读书源”作为对外主表述

---

## 12. 最终建议

最终建议用一句话概括：

**保持 `.js` 为官方载体，保持脚本 runtime 为唯一执行主线，把 MD3 / 阅读书源定位为“手工迁移参考来源”，通过对照表、模板和样本源帮助用户重写。**

这条路有几个直接好处：

1. 不推翻当前运行时
2. 不回到旧版复杂兼容链
3. 用户仍然能参考 MD3 书源迁移
4. 平台自己的规范会越来越清楚
5. 后续维护成本最低

如果未来继续推进，判断一个决策是否正确，可以只问一句：

> 这个变化是在强化“平台原生脚本规范”，还是在把项目重新拖回“旧 JSON 兼容执行器”？

凡是后者，都应当谨慎。

---

## 13. MD3 / 阅读 到当前 `.js` 书源的完整手工迁移对照

这一节不是“字段名替换表”，而是“能力迁移表”。

使用方式：

1. 先看阅读字段或规则块
2. 再理解它在阅读里的职责
3. 再决定在当前项目里落到哪个能力区
4. 最后手工写进 `.js` 书源

### 13.1 基础元信息

| MD3 / 阅读字段 | 在阅读里的含义 | 当前项目对应位置 | 迁移建议 |
| --- | --- | --- | --- |
| `bookSourceName` | 书源名称 | `meta.name` | 直接迁移 |
| `bookSourceGroup` | 分组 | `meta.group` | 直接迁移 |
| `bookSourceUrl` | 书源主页/主域名 | `meta.homepage`、`meta.domains` | 建议同时补 `homepage + domains` |
| `bookSourceComment` | 注释 | `meta.description` 或源码注释 | 说明性内容可保留，运行态逻辑不要塞这里 |
| `bookSourceType` | 文本/漫画/音频等 | `meta.capabilities`、`Book.type` / `Content.images` | 不建议保留旧数字语义，统一映射为文本能力标签 |
| `header` | 默认请求头 | `ctx.http.request({ headers })` 或登录态 `ctx.sourceLogin.putHeader(...)` | 静态头写请求；登录后动态头写 `sourceLogin` |
| `jsLib` | 全局共享脚本库 | 当前项目无独立 `jsLib` 槽位 | 建议迁到文件顶部 helper 函数 / 常量 |
| `enabled` | 启用状态 | App 内管理 | 不放到书源逻辑层，交给项目配置管理 |
| `enabledExplore` | 是否启用发现 | 是否实现 `discoverCategories/discoverBooks` | 有发现能力才实现发现入口 |
| `concurrentRate` | 并发率 | 当前项目暂无等价一等公民 | 暂不作为书源作者手工迁移重点 |

### 13.2 搜索能力

| MD3 / 阅读字段 | 在阅读里的含义 | 当前项目对应位置 | 迁移建议 |
| --- | --- | --- | --- |
| `searchUrl` | 搜索请求入口 | `async search(ctx, keyword)` | 手工写成 `ctx.http.request(...)` |
| `ruleSearch.bookList` | 搜索结果列表规则 | `search()` 里列表提取 | 用 `ctx.html.parse` + selector / JSONPath 手写 |
| `ruleSearch.name` | 书名规则 | `search()` 返回 `Book.title` | 手工映射 |
| `ruleSearch.author` | 作者规则 | `search()` 返回 `Book.author` | 手工映射 |
| `ruleSearch.bookUrl` | 详情页地址 | `search()` 返回 `Book.detailUrl` | 必迁 |
| `ruleSearch.coverUrl` | 封面地址 | `search()` 返回 `Book.cover` | 建议补 |
| `ruleSearch.intro` | 简介 | `search()` 返回 `Book.intro` | 建议补 |
| `ruleSearch.kind` | 分类 | `search()` 返回 `Book.category` / `Book.tags` | 二选一或并用 |
| `ruleSearch.lastChapter` | 最新章节 | `search()` 返回 `Book.latestChapter` | 建议补 |
| `ruleSearch.wordCount` | 字数 | `search()` 返回 `Book.wordCount` | 可选 |
| `checkKeyWord` | 搜索结果校验 | `meta.checkKeyword` + `search()` 自检逻辑 | 不是直接字段等价，建议只保留为检测关键词 |

### 13.3 详情能力

| MD3 / 阅读字段 | 在阅读里的含义 | 当前项目对应位置 | 迁移建议 |
| --- | --- | --- | --- |
| `ruleBookInfo.init` | 详情页预处理/定位 | `detail()` 内前置步骤 | 手工写到 `detail()` 开头 |
| `ruleBookInfo.name` | 书名 | `detail()` 返回 `Book.title` | 必迁 |
| `ruleBookInfo.author` | 作者 | `detail()` 返回 `Book.author` | 必迁 |
| `ruleBookInfo.intro` | 简介 | `detail()` 返回 `Book.intro` | 建议补 |
| `ruleBookInfo.kind` | 分类 | `detail()` 返回 `Book.category` / `tags` | 可选 |
| `ruleBookInfo.coverUrl` | 封面 | `detail()` 返回 `Book.cover` | 建议补 |
| `ruleBookInfo.lastChapter` | 最新章节 | `detail()` 返回 `Book.latestChapter` | 可选 |
| `ruleBookInfo.wordCount` | 字数 | `detail()` 返回 `Book.wordCount` | 可选 |
| `ruleBookInfo.tocUrl` | 目录页 URL | `detail()` 返回 `Book.tocUrl` | 很重要 |
| `ruleBookInfo.canReName` | 可重命名/可校名 | 当前无一等字段 | 放 `Book.extra`，仅复杂源保留 |
| `ruleBookInfo.downloadUrls` | 下载地址 | 当前无正式一等字段 | 放 `Book.extra`，不作为主流迁移能力 |

### 13.4 目录能力

| MD3 / 阅读字段 | 在阅读里的含义 | 当前项目对应位置 | 迁移建议 |
| --- | --- | --- | --- |
| `ruleToc.init` | 目录预处理 | `chapters()` 前置逻辑 | 手工内联 |
| `ruleToc.preUpdateJs` | 目录解析前脚本 | `chapters()` 前置逻辑 | 手工内联 |
| `ruleToc.chapterList` | 目录列表 | `chapters()` 返回 `Chapter[]` | 必迁 |
| `ruleToc.chapterName` | 章节名 | `Chapter.title` | 必迁 |
| `ruleToc.chapterUrl` | 章节地址 | `Chapter.url` | 必迁 |
| `ruleToc.nextTocUrl` | 下一页目录 | `chapters()` 内分页抓取 | 当前需手工循环实现 |
| `ruleToc.formatJs` | 章节名格式化 | `chapters()` 末尾格式化 | 当前需手工实现 |
| `ruleToc.isVolume` | 卷标识 | `Chapter.isVolume` | 可迁 |
| `ruleToc.isVip` | VIP 标识 | `Chapter.vip` | 可迁 |
| `ruleToc.isPay` | 付费标识 | `Chapter.isPay` | 可迁 |
| `ruleToc.updateTime` | 更新时间 | `Chapter.updateTime` | 可选 |
| `reverse` / 倒序目录 | 目录顺序翻转 | `chapters()` 内数组翻转 | 当前手工实现 |

### 13.5 正文能力

| MD3 / 阅读字段 | 在阅读里的含义 | 当前项目对应位置 | 迁移建议 |
| --- | --- | --- | --- |
| `ruleContent.content` | 正文主体 | `content()` 返回 `Content.content` | 必迁 |
| `ruleContent.title` | 正文页标题 | `Content.title` | 建议补 |
| `ruleContent.nextContentUrl` | 正文下一页 | `Content.nextUrl` | 已有等价字段 |
| `ruleContent.replaceRegex` | 正文替换 | `content()` 内文本后处理 | 当前手工实现 |
| `ruleContent.webJs` | 页面内脚本处理 | `ctx.browser.eval(...)` 或 WebView 请求 | 当前不是纯字符串后处理，建议改成浏览器态逻辑 |
| `ruleContent.sourceRegex` | 资源嗅探 | `sourceRegex` | 当前已有正式支持 |
| `ruleContent.imageStyle` | 图片章节展示风格 | `Content.images` + 前端展示层 | 保留语义，不建议照搬字段名 |
| `ruleContent.subContent` | 副正文 | `Content.extra` 或手工拼接到正文 | 当前无一等字段，建议手工拼接 |
| `ruleContent.imageDecode` | 图片二次解密 | `ctx.crypto + ctx.http` 手工流程 | 当前可表达，但无专项简写 |
| `ruleContent.payAction` | 付费动作 | `ctx.ui / ctx.browser / ctx.sourceLogin` | 当前可写复杂脚本，但不是主流能力 |

### 13.6 发现能力

| MD3 / 阅读字段 | 在阅读里的含义 | 当前项目对应位置 | 迁移建议 |
| --- | --- | --- | --- |
| `exploreUrl` | 发现入口配置 | `discoverCategories()` | 需要手工转成分类数组 |
| `ruleExplore.bookList` | 发现书单列表 | `discoverBooks()` | 手工实现 |
| `ruleExplore.name` | 书名 | `Book.title` | 同搜索迁移方式 |
| `ruleExplore.author` | 作者 | `Book.author` | 同搜索迁移方式 |
| `ruleExplore.bookUrl` | 详情页地址 | `Book.detailUrl` | 同搜索迁移方式 |
| `ruleExplore.coverUrl` | 封面 | `Book.cover` | 同搜索迁移方式 |
| `ruleExplore.intro` | 简介 | `Book.intro` | 同搜索迁移方式 |
| `ruleExplore.kind` | 分类 | `Book.category` | 可选 |
| `ruleExplore.lastChapter` | 最新章节 | `Book.latestChapter` | 可选 |

### 13.7 登录能力

| MD3 / 阅读字段 | 在阅读里的含义 | 当前项目对应位置 | 迁移建议 |
| --- | --- | --- | --- |
| `loginUrl` | 登录入口，可能是 URL，也可能是脚本 | `webLoginUrl` / `login action` | 绝对 URL 走网页登录；脚本型登录走 `loginAction/login` |
| `loginUi` | 动态登录表单 | `loginUi(ctx, formData, ...)` | 当前已支持，建议重点保留 |
| `loginCheckJs` | 请求后登录检测与请求重放 | `ctx.http.request()` 包装层 | 当前已有最小兼容能力 |
| `loginHeader`（运行态概念） | 登录后动态头 | `ctx.sourceLogin.putHeader/getHeaderMap` | 当前已支持 |
| `loginInfo`（运行态概念） | 登录表单值/账号信息 | `ctx.sourceLogin.putInfo/getInfoMap` | 当前已支持 |
| `sourceVariable`（运行态概念） | 源级变量 | `ctx.sourceLogin.setVariable/getVariableMap` | 当前已支持 |

### 13.8 浏览器 / WebView 能力

| MD3 / 阅读字段 / 能力 | 在阅读里的含义 | 当前项目对应位置 | 迁移建议 |
| --- | --- | --- | --- |
| `webView: true` | 用浏览器态请求页面 | `ctx.http.request({ execution: 'browser' })` 或 `ctx.browser.*` | 当前更推荐显式写浏览器逻辑 |
| `webJs` | 页面执行 JS | `ctx.browser.eval(...)` | 已有正式能力 |
| `sourceRegex` | 浏览器资源嗅探 | `sourceRegex` | 当前已有正式能力 |
| `overrideUrlRegex` | 跳转 URL 嗅探 | `overrideUrlRegex` | 当前已有正式能力 |
| `webViewDelay` | 页面脚本稳定等待 | `webViewDelay` | 当前已有正式能力 |
| `showBrowser` | 打开页面交互 | `ctx.ui.openBrowserAwait(...)` | 已有宿主能力 |

### 13.9 长尾能力

| MD3 / 阅读字段 | 当前项目支持度 | 迁移建议 |
| --- | --- | --- |
| `preUpdateJs` | 可表达，但无一等字段 | 手工写在 `chapters()` / `detail()` 前置逻辑 |
| `formatJs` | 可表达，但无一等字段 | 手工写在结果格式化阶段 |
| `replaceRegex` | 可表达，但无一等字段 | 手工字符串后处理 |
| `coverDecodeJs` | 可表达，但较重 | 优先放弃，必要时手工用 `ctx.crypto` 补 |
| `imageDecode` | 可表达，但较重 | 同上 |
| `payAction` | 可表达，但不建议作为第一批迁移目标 | 只在强需求源保留 |
| `ruleReview` | 当前缺正式一等模型 | 暂不作为主流迁移能力 |
| `callBackJs` / `eventListener` | 当前缺正式宿主语义 | 暂不迁 |

---

## 14. 用户手工改写的推荐流程

为了让迁移最简单，建议统一按下面顺序改写：

### 14.1 低复杂度源

适用：

- 普通 HTML 小说源
- 普通 JSON API 源
- 不依赖登录
- 不依赖浏览器验证

推荐顺序：

1. 先写 `meta`
2. 写 `search()`
3. 写 `detail()`
4. 写 `chapters()`
5. 写 `content()`
6. 最后补 `discover`

### 14.2 中复杂度源

适用：

- 需要 `sourceRegex`
- 需要 `webJs`
- 需要 `webViewDelay`
- 页面渲染后才能拿到结果

推荐顺序：

1. 先按低复杂度源完成主流程
2. 再把 `content()` 或 `search()` 中相关请求切到浏览器态
3. 最后再补 `sourceRegex / overrideUrlRegex / webViewDelay`

### 14.3 高复杂度源

适用：

- 有 `loginUi`
- 有 `loginCheckJs`
- 需要网页登录
- 需要验证码或交互挑战

推荐顺序：

1. 先做 `loginUi` 或 `webLoginUrl`
2. 确认 `ctx.sourceLogin` 能保存登录态
3. 再做 `loginCheckJs`
4. 最后回到 `search/detail/chapters/content` 接入登录态

---

## 15. 当前项目所需技术库与依赖判断

这里不谈“理想世界需要什么”，只谈按当前路线继续推进，现有项目够不够用。

### 15.1 当前主路线已经具备的关键依赖

当前 `pubspec.yaml` 里，和书源迁移主线直接相关的库已经不少：

#### 网络与请求

- `dio`
- `http`
- `charset`
- `flutter_charset_detector`
- `charset_converter`

用途：

- 普通 HTTP 请求
- 响应字节读取
- 字符集解码
- 旧站兼容

结论：

- **够用**

#### HTML / 结构解析

- `html`
- `xml`
- `json_path`

用途：

- HTML DOM 解析
- XML / RSS 类解析
- JSONPath 风格提取

结论：

- **够用**

#### JS 运行时

- `flutter_js`

用途：

- 执行脚本源
- 跑登录脚本
- 跑 `loginCheckJs`
- 跑调试脚本

结论：

- **这是当前路线的核心依赖**

#### 浏览器 / WebView

- `flutter_inappwebview`

用途：

- Headless WebView
- 交互式网页登录 / 验证页
- 页面脚本执行
- `sourceRegex`
- `overrideUrlRegex`

结论：

- **这是浏览器态能力的核心依赖**

#### 存储与状态

- `drift`
- `shared_preferences`
- `flutter_secure_storage`
- `sqlite3_flutter_libs`
- `path_provider`

用途：

- 书源存储
- 登录态持久化
- 安全存储
- 本地数据库

结论：

- **够用**

#### 加密与工具

- `crypto`
- `pointycastle`
- `basic_utils`
- `archive`
- `uuid`

用途：

- 哈希
- 对称 / 非对称加解密
- 压缩与导入辅助
- 标识生成

结论：

- **对复杂源已经足够**

### 15.2 现有依赖已经能支撑到哪一步

如果按“手工迁移 MD3 到当前 `.js` 书源”的路线继续走：

**当前依赖已经足够支撑：**

1. 普通 HTML 小说源
2. 普通 JSON API 源
3. 漫画图片源
4. `sourceRegex` 资源嗅探源
5. `loginUi` 源
6. 纯网页登录源
7. `loginCheckJs` 最小兼容链

也就是说：

**当前路线不需要为了“手工迁移策略”再引入一个大的核心依赖。**

### 15.3 当前项目真正缺的不是依赖，而是文档与规范

从今天的判断看，当前短板主要不是技术库，而是：

1. 书源规范表达还不够清晰
2. 手工迁移对照表还没有正式成文
3. 复杂能力的迁移指引还不成体系
4. 样本源回归集还不够稳定

所以：

**现阶段优先补文档和样本，不优先加依赖。**

---

## 16. 是否还需要新增依赖

按当前路线，我的建议是：

### 16.1 现在不必须新增的

以下方向目前都 **不是必须**：

- 新的 JS 引擎
- 新的浏览器引擎
- 新的规则 DSL 库
- 新的代码生成框架
- 新的 JSON Schema 框架

原因：

- 当前 runtime 已经成型
- 现有能力不是空白
- 当前真正缺的是“如何用”

### 16.2 未来可选新增的

如果后面想提升“手工迁移体验”，可以考虑增加这些辅助型依赖，但都不是当下必须：

#### 可选 1：脚本 AST / 语法分析类库

用途：

- 更好地分析用户书源脚本
- 做静态检查
- 做 lint / 提示

结论：

- **可选，不急**

#### 可选 2：规则对照表生成工具

用途：

- 生成用户文档
- 校验模板覆盖情况

结论：

- **更适合用 tool 脚本，不一定要新依赖**

#### 可选 3：样本源回归工具

用途：

- 批量跑样本源
- 生成迁移报告

结论：

- **建议用现有 test/tool 架构先做**

### 16.3 总结

当前路线下：

**没有“必须新增的核心依赖”。**

最应该补的是：

- 规范
- 对照表
- 样本
- 测试

---

## 17. 实现难度判断

这里按你现在要做的事情来分级，不按“最终理想平台”来分。

### 17.1 目标 A：建立手工迁移文档体系

内容包括：

- 书源规范文档
- MD3 对照表
- 三类模板
- 复杂能力专题说明

难度：

- **低**

原因：

- 代码底座已存在
- 主要是梳理和固化

是否容易实现：

- **容易**

### 17.2 目标 B：让大部分普通小说源能按对照表迁移

内容包括：

- 普通 HTML 源
- 普通 JSON API 源
- 基础发现页

难度：

- **中低**

原因：

- 当前 `ctx.http + ctx.html + result models` 已经够用
- 用户主要是“重写”，不是“开新能力”

是否容易实现：

- **比较容易**

### 17.3 目标 C：让登录源和浏览器态源稳定迁移

内容包括：

- `loginUi`
- `loginUrl`
- `loginCheckJs`
- `sourceRegex`
- `webViewDelay`

难度：

- **中等**

原因：

- 底座已经有
- 但需要样本源验证和细节收口

是否容易实现：

- **可以实现，但要靠样本源回归，不是光靠设计就能完成**

### 17.4 目标 D：补齐长尾高级能力

内容包括：

- `payAction`
- `ruleReview`
- `callBackJs`
- 图片二次解密
- 更复杂的跨页面状态

难度：

- **中高**

原因：

- 当前多数只能“可表达”，不是“平台一等公民”
- 需要单独设计宿主边界

是否容易实现：

- **不算容易，不建议作为近期主目标**

### 17.5 目标 E：重新回到“直接兼容阅读 JSON 执行”

难度：

- **高**

原因：

- 要重新维护旧规则模型
- 要重新维护 JSON -> runtime 直连语义
- 要长期背两套心智

是否容易实现：

- **不容易，也不建议**

---

## 18. 推荐的最简实施路线

如果目标是“未来更简单”，推荐按下面顺序推进：

### 第 1 步：固定官方口径

明确：

- 当前官方书源是 `.js`
- 阅读源是手工迁移参考
- 不再承诺直接兼容旧 JSON 运行

### 第 2 步：补齐完整手工迁移文档

至少包含：

1. 平台原生 `.js` 书源规范
2. MD3 / 阅读对照表
3. 三个模板：
   - 普通小说源
   - JSON API 源
   - 登录/浏览器源

### 第 3 步：建立样本源回归集

建议先固定 10 到 20 个：

- 纯文本源
- 漫画源
- `loginUi` 源
- `loginCheckJs` 源
- `sourceRegex` 源

### 第 4 步：只针对高频痛点补能力

优先补：

- 登录态验证
- 浏览器态稳定性
- 变量和状态说明

不优先补：

- 段评
- 支付动作
- 长尾回调系统

---

## 19. 最终落点

这份文档最终希望固定的不是“又一版兼容计划”，而是下面这句话：

**当前项目的未来主线是：以平台原生 `.js` 书源为唯一执行格式，以 MD3 / 阅读书源为人工迁移参考来源，通过对照表和模板支持用户手工改写。**

如果未来某个决策会让项目偏离这句话，就要重新评估。

---

## 20. 可直接起步的 3 个完整模板

这一节的目标不是“展示所有技巧”，而是给出三种最常见迁移场景的稳定起手式。

使用建议：

1. 先选最接近自己站点的模板
2. 再把 MD3 / 阅读里的旧规则拆到对应函数里
3. 先跑通主链，再补复杂能力

### 20.1 模板 A：普通 HTML 小说源

适用：

- 普通 HTML 页面
- 不需要登录
- 不需要浏览器挑战
- 列表、详情、目录、正文都能直接通过 HTML 抓取

```js
const BASE_URL = 'https://www.example.com';

function absolute(base, relative) {
  return new URL(relative, base).toString();
}

function textOf(element, selector, fallback = '') {
  if (!element) return fallback;
  if (!selector) return (element.textContent || '').trim() || fallback;
  const target = element.querySelector(selector);
  return (target?.textContent || '').trim() || fallback;
}

function attrOf(element, selector, attrName, fallback = '') {
  if (!element) return fallback;
  const target = selector ? element.querySelector(selector) : element;
  return (target?.getAttribute(attrName) || '').trim() || fallback;
}

export default {
  meta: {
    name: '示例 HTML 小说源',
    group: '小说',
    author: 'your-name',
    description: '适用于普通 HTML 站点的基础模板',
    homepage: BASE_URL,
    domains: ['www.example.com'],
    checkKeyword: '斗罗大陆',
    capabilities: ['novel'],
  },

  async search(ctx, keyword) {
    const response = await ctx.http.request({
      url: absolute(BASE_URL, '/search'),
      method: 'GET',
      query: { q: keyword },
      responseType: 'text',
    });

    const doc = ctx.html.parse(response.text || '');
    const items = doc.querySelectorAll('.book-item');

    return items.map((item) => {
      const detailUrl = absolute(
        BASE_URL,
        attrOf(item, '.title a', 'href'),
      );
      return {
        title: textOf(item, '.title a'),
        author: textOf(item, '.author'),
        intro: textOf(item, '.intro'),
        cover: absolute(BASE_URL, attrOf(item, 'img.cover', 'src')),
        latestChapter: textOf(item, '.latest'),
        detailUrl,
        sourceId: ctx.source.id,
      };
    });
  },

  async detail(ctx, book) {
    const response = await ctx.http.request({
      url: book.detailUrl,
      responseType: 'text',
    });

    const doc = ctx.html.parse(response.text || '');
    const tocUrl = attrOf(doc, '.toc-link', 'href');

    return {
      ...book,
      title: textOf(doc, 'h1.book-title', book.title),
      author: textOf(doc, '.book-author', book.author),
      intro: textOf(doc, '.book-intro', book.intro),
      category: textOf(doc, '.book-category'),
      latestChapter: textOf(doc, '.latest-chapter', book.latestChapter),
      cover: absolute(BASE_URL, attrOf(doc, '.cover img', 'src', book.cover)),
      tocUrl: tocUrl ? absolute(book.detailUrl, tocUrl) : book.detailUrl,
      sourceId: ctx.source.id,
    };
  },

  async chapters(ctx, book) {
    const tocUrl = book.tocUrl || book.detailUrl;
    const response = await ctx.http.request({
      url: tocUrl,
      responseType: 'text',
    });

    const doc = ctx.html.parse(response.text || '');
    const items = doc.querySelectorAll('.chapter-list li');

    return items.map((item, index) => ({
      title: textOf(item, 'a'),
      url: absolute(tocUrl, attrOf(item, 'a', 'href')),
      index,
      sourceId: ctx.source.id,
    }));
  },

  async content(ctx, book, chapter) {
    const response = await ctx.http.request({
      url: chapter.url,
      responseType: 'text',
    });

    const doc = ctx.html.parse(response.text || '');
    const body = doc.querySelector('#content');
    const nextHref = attrOf(doc, '.next-page', 'href');

    return {
      title: textOf(doc, 'h1.chapter-title', chapter.title),
      content: ctx.utils.htmlFormat(body?.innerHtml || ''),
      nextUrl: nextHref ? absolute(chapter.url, nextHref) : null,
      sourceId: ctx.source.id,
    };
  },
};
```

### 模板 A 迁移说明

- 阅读里的 `searchUrl` 迁到 `search()` 请求入口
- 阅读里的 `ruleSearch.*` 拆到 `search()` 里
- 阅读里的 `ruleBookInfo.*` 拆到 `detail()` 里
- 阅读里的 `ruleToc.*` 拆到 `chapters()` 里
- 阅读里的 `ruleContent.*` 拆到 `content()` 里

这种模板最适合第一批迁移的普通小说源。

---

### 20.2 模板 B：JSON API 源

适用：

- 搜索、详情、目录或正文主要来自 JSON API
- 规则核心不是 HTML 选择器，而是 JSON 字段提取
- 可能有分页参数、签名参数，但不一定需要浏览器态

```js
const API_BASE = 'https://api.example.com';

function asArray(value) {
  return Array.isArray(value) ? value : [];
}

function safe(obj, path, fallback = '') {
  const segments = Array.isArray(path) ? path : String(path).split('.');
  let current = obj;
  for (const key of segments) {
    if (current == null || typeof current !== 'object' || !(key in current)) {
      return fallback;
    }
    current = current[key];
  }
  if (current == null) return fallback;
  return current;
}

export default {
  meta: {
    name: '示例 JSON API 源',
    group: '小说',
    author: 'your-name',
    description: '适用于 JSON API 站点的模板',
    homepage: API_BASE,
    domains: ['api.example.com'],
    checkKeyword: '凡人修仙传',
    capabilities: ['novel', 'api'],
  },

  async search(ctx, keyword) {
    const response = await ctx.http.request({
      url: `${API_BASE}/book/search`,
      method: 'GET',
      query: {
        keyword,
        page: '1',
      },
      responseType: 'json',
    });

    const payload = response.json || {};
    const items = asArray(safe(payload, 'data.list', []));

    return items.map((item) => ({
      title: String(safe(item, 'title', '')),
      author: String(safe(item, 'author', '')),
      intro: String(safe(item, 'intro', '')),
      cover: String(safe(item, 'cover', '')),
      latestChapter: String(safe(item, 'latestChapter', '')),
      detailUrl: `${API_BASE}/book/detail?id=${safe(item, 'id', '')}`,
      sourceId: ctx.source.id,
      extra: {
        bookId: String(safe(item, 'id', '')),
      },
    }));
  },

  async detail(ctx, book) {
    const bookId = book.extra?.bookId || '';
    const response = await ctx.http.request({
      url: `${API_BASE}/book/detail`,
      method: 'GET',
      query: { id: String(bookId) },
      responseType: 'json',
    });

    const item = safe(response.json || {}, 'data', {});

    return {
      ...book,
      title: String(safe(item, 'title', book.title)),
      author: String(safe(item, 'author', book.author)),
      intro: String(safe(item, 'intro', book.intro)),
      category: String(safe(item, 'category', '')),
      latestChapter: String(safe(item, 'latestChapter', book.latestChapter)),
      cover: String(safe(item, 'cover', book.cover)),
      tocUrl: `${API_BASE}/book/chapters?id=${safe(item, 'id', bookId)}`,
      sourceId: ctx.source.id,
      extra: {
        ...book.extra,
        bookId: String(safe(item, 'id', bookId)),
      },
    };
  },

  async chapters(ctx, book) {
    const bookId = book.extra?.bookId || '';
    const response = await ctx.http.request({
      url: `${API_BASE}/book/chapters`,
      method: 'GET',
      query: { id: String(bookId) },
      responseType: 'json',
    });

    const items = asArray(safe(response.json || {}, 'data.list', []));

    return items.map((item, index) => ({
      title: String(safe(item, 'title', '')),
      url: `${API_BASE}/book/content?id=${safe(item, 'id', '')}`,
      index,
      sourceId: ctx.source.id,
      extra: {
        chapterId: String(safe(item, 'id', '')),
      },
    }));
  },

  async content(ctx, book, chapter) {
    const chapterId = chapter.extra?.chapterId || '';
    const response = await ctx.http.request({
      url: `${API_BASE}/book/content`,
      method: 'GET',
      query: { id: String(chapterId) },
      responseType: 'json',
    });

    const item = safe(response.json || {}, 'data', {});
    const paragraphs = asArray(safe(item, 'paragraphs', []));

    return {
      title: String(safe(item, 'title', chapter.title)),
      content: paragraphs
        .map((line) => String(line).trim())
        .where((line) => line.isNotEmpty)
        .map((line) => `　　${line}`)
        .join('\n'),
      sourceId: ctx.source.id,
    };
  },
};
```

### 模板 B 迁移说明

- 阅读里的 JSONPath、接口字段提取，统一改写成 `safe(...)`
- 如果旧源用了 `@js:` 拼请求参数，建议直接在 `search/detail/chapters/content` 里手算
- 如果源依赖 token/header，优先结合 `ctx.sourceLogin` 使用

---

### 20.3 模板 C：登录 + WebView / `sourceRegex` 源

适用：

- 有 `loginUi`
- 或有纯 `loginUrl`
- 或有 `loginCheckJs`
- 或正文/搜索必须依赖浏览器态
- 或要用 `sourceRegex` 嗅探资源 URL

```js
const HOST = 'https://www.example.com';

function absolute(base, relative) {
  return new URL(relative, base).toString();
}

function parseJsonSafely(text, fallback = {}) {
  try {
    return JSON.parse(text);
  } catch (_) {
    return fallback;
  }
}

export default {
  meta: {
    name: '示例登录浏览器源',
    group: '小说',
    author: 'your-name',
    description: '适用于登录、验证、浏览器态资源嗅探场景',
    homepage: HOST,
    domains: ['www.example.com'],
    checkKeyword: '庆余年',
    capabilities: ['novel', 'browser', 'webview', 'challenge'],
  },

  // 纯网页登录入口。若只是普通网页登录，可保留绝对 URL。
  loginUrl: `${HOST}/login`,

  // 动态登录表单。若不需要表单登录，可删除整个 loginUi。
  async loginUi(ctx, formData) {
    const current = formData || {};
    return [
      {
        name: '账号',
        type: 'text',
        default: current['账号'] || '',
      },
      {
        name: '密码',
        type: 'password',
        default: current['密码'] || '',
      },
      {
        name: '网页登录',
        type: 'button',
        action: 'open_web_login()',
      },
      {
        name: '脚本登录',
        type: 'button',
        action: 'script_login()',
      },
      {
        name: '清空登录态',
        type: 'button',
        action: 'clear_login_state()',
      },
    ];
  },

  async login(ctx, formData) {
    const account = await ctx.sourceLogin.getField('账号');
    const password = await ctx.sourceLogin.getField('密码');

    if (!account || !password) {
      await ctx.ui.toast('请先填写账号和密码');
      return false;
    }

    const response = await ctx.http.request({
      url: `${HOST}/api/login`,
      method: 'POST',
      bodyType: 'json',
      body: {
        account,
        password,
      },
      responseType: 'json',
    });

    const payload = response.json || {};
    const token = payload.token || payload.data?.token || '';
    if (!token) {
      await ctx.ui.longToast('登录失败，未获取到 token');
      return false;
    }

    await ctx.sourceLogin.putHeader(
      JSON.stringify({
        Authorization: `Bearer ${token}`,
      }),
    );
    await ctx.sourceLogin.patchInfo({
      token: String(token),
    });
    await ctx.ui.toast('脚本登录成功');
    return true;
  },

  async loginCheckJs(ctx, result, requestState, java) {
    const payload = result.json() || parseJsonSafely(result.body() || '', {});
    const statusCode = Number(payload.statusCode || payload.code || 0);

    if (statusCode === 301 || statusCode === 401 || statusCode === 403) {
      const browserResult = await ctx.ui.openBrowserAwait({
        url: `${HOST}/login`,
        title: '登录',
        refetchAfterSuccess: true,
      });

      const finalUrl = String(browserResult.finalUrl || '');
      if (finalUrl.includes('/home') || finalUrl.includes('/profile')) {
        const currentHeaders = await ctx.sourceLogin.getHeaderMap();
        if (currentHeaders.Authorization) {
          java.getHeaderMap().put(
            'Authorization',
            currentHeaders.Authorization,
          );
        }
        result = await java.getResponse();
      }
    }

    return result;
  },

  async search(ctx, keyword) {
    const response = await ctx.http.request({
      url: `${HOST}/search,{"webView":true,"webViewDelay":1200}`,
      query: { q: keyword },
      responseType: 'text',
    });

    const doc = ctx.html.parse(response.text || '');
    const items = doc.querySelectorAll('.book-item');

    return items.map((item) => ({
      title: (item.querySelector('.title')?.textContent || '').trim(),
      author: (item.querySelector('.author')?.textContent || '').trim(),
      detailUrl: absolute(
        HOST,
        item.querySelector('a')?.getAttribute('href') || '',
      ),
      sourceId: ctx.source.id,
    }));
  },

  async detail(ctx, book) {
    const response = await ctx.http.request({
      url: book.detailUrl,
      responseType: 'text',
    });

    const doc = ctx.html.parse(response.text || '');
    return {
      ...book,
      title: (doc.querySelector('h1')?.textContent || '').trim() || book.title,
      author:
        (doc.querySelector('.author')?.textContent || '').trim() || book.author,
      tocUrl: absolute(
        book.detailUrl,
        doc.querySelector('.toc-link')?.getAttribute('href') || '',
      ),
      sourceId: ctx.source.id,
    };
  },

  async chapters(ctx, book) {
    const response = await ctx.http.request({
      url: book.tocUrl || book.detailUrl,
      responseType: 'text',
    });

    const doc = ctx.html.parse(response.text || '');
    const items = doc.querySelectorAll('.chapter-list li a');

    return items.map((item, index) => ({
      title: (item.textContent || '').trim(),
      url: absolute(book.tocUrl || book.detailUrl, item.getAttribute('href') || ''),
      index,
      sourceId: ctx.source.id,
    }));
  },

  async content(ctx, book, chapter) {
    // 场景 1：正文页是浏览器渲染后才能拿到内容
    const browserResult = await ctx.browser.eval({
      url: chapter.url,
      script: `
        const node = document.querySelector('#content');
        node ? node.innerHTML : '';
      `,
      webViewDelay: 1200,
    });

    const html = String(browserResult || '');
    if (html.trim()) {
      return {
        title: chapter.title,
        content: ctx.utils.htmlFormat(html),
        sourceId: ctx.source.id,
      };
    }

    // 场景 2：正文页本身只是中转，真正资源通过 sourceRegex 嗅探
    const resourceResponse = await ctx.http.request({
      url: chapter.url,
      responseType: 'text',
      execution: 'browser',
    });

    const matchedUrl =
      resourceResponse.matchedResourceUrl ||
      resourceResponse.matchedOverrideUrl ||
      '';

    if (matchedUrl) {
      return {
        title: chapter.title,
        content: '',
        images: [matchedUrl],
        sourceId: ctx.source.id,
      };
    }

    return {
      title: chapter.title,
      content: ctx.utils.htmlFormat(resourceResponse.text || ''),
      sourceId: ctx.source.id,
    };
  },
};
```

### 模板 C 迁移说明

这个模板要点是：

1. `loginUrl` 是网页登录入口，不一定等于脚本登录
2. `loginUi` 是登录表单，不是普通设置页
3. `login()` 负责脚本登录
4. `loginCheckJs()` 负责请求后检测登录失效并重放请求
5. 浏览器态内容尽量优先走：
   - `ctx.browser.eval(...)`
   - `ctx.ui.openBrowserAwait(...)`
6. `sourceRegex` 场景要重点验证是否真的能嗅探到资源 URL

---

## 21. 三类模板对应的实现门槛

为了避免“模板看起来都能写，实际上难度完全不同”，这里补一份现实判断。

### 模板 A：普通 HTML 小说源

- 所需能力：`ctx.http + ctx.html`
- 新增依赖：无
- 实现难度：**低**
- 适合优先推广：**是**

### 模板 B：JSON API 源

- 所需能力：`ctx.http`
- 新增依赖：无
- 实现难度：**低到中**
- 适合优先推广：**是**

### 模板 C：登录 + 浏览器态源

- 所需能力：
  - `ctx.sourceLogin`
  - `ctx.ui.openBrowserAwait`
  - `ctx.browser.eval`
  - `loginCheckJs`
  - `sourceRegex`
- 新增依赖：无
- 实现难度：**中**
- 适合优先推广：**只适合给中高级用户**

---

## 22. 当前阶段的最终判断

如果只从“需要什么技术库、依赖、是否容易实现”三个维度看：

### 22.1 技术库和依赖

当前项目 **不缺核心依赖**。

现有这几类依赖已经足够支撑手工迁移路线：

- 网络请求：`dio`、`http`
- 页面解析：`html`、`xml`、`json_path`
- JS 执行：`flutter_js`
- WebView / 浏览器态：`flutter_inappwebview`
- 存储与状态：`drift`、`shared_preferences`、`flutter_secure_storage`
- 加密：`crypto`、`pointycastle`、`basic_utils`

### 22.2 是否容易实现

分情况：

- 让用户手工迁移普通小说源：**容易**
- 让用户手工迁移普通 JSON API 源：**比较容易**
- 让用户手工迁移登录 + 验证 + 浏览器态源：**中等**
- 让项目回头重新做旧 JSON 直接兼容执行：**困难且不值得**

### 22.3 当前最值得做的事

不是加依赖，不是重写 runtime，而是：

1. 固定规范
2. 完善对照表
3. 提供模板
4. 建立样本源回归集

这四件事做完，项目会比现在清晰很多，也更容易让别人按你的方式写源。
