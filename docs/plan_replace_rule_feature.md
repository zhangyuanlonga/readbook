# 源阅净化规则功能方案（最优解）

本文不是对外部项目的复述，而是结合当前 Flutter 项目的代码结构，给出“净化规则”在我们产品里的最优落地方案。

参考分析文档：

- [legado-md3-replace-rule-analysis.md](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/docs/reference/legado-md3-replace-rule-analysis.md)

---

## 结论

最优解不是把净化规则塞进现有书源 `replaceRegex` 执行器，也不是先做一个简单的“文本替换开关”。

最优解应该是：

1. 做一套**用户级净化规则库**
2. 挂在**阅读正文后处理层**
3. 与书源规则层明确分离
4. 支持**正文净化优先**，标题净化后补
5. 阅读页可查看“**本章实际生效规则**”
6. 管理端支持最少的：**新增、编辑、启停、测试、导入导出**

一句话概括：

> 这是“阅读体验层”的能力，不是“书源解析层”的能力。

---

## 一、为什么这是最优解

### 1. 不应该并入书源规则层

我们现在已经有书源级 `replaceRegex`：

- 适配来源：
  [`ChapterContentService._applyContentReplaceRegex(...)`](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/chapter_content_service.dart)
- 执行器：
  [`replace_regex_executor.dart`](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/core/rule_engine/processors/replace_regex_executor.dart)

它的职责是：

- 执行书源作者写在书源规则里的清洗逻辑
- 属于抓取 / 解析链路的一部分

如果把用户净化规则也塞进去，会导致：

- 用户规则和书源规则耦合
- 后续无法在阅读页显示“本章生效了哪些用户规则”
- 无法按书名 / 书源 / 作用域做用户级筛选
- 用户不容易理解“为什么导入一个书源，结果我自己的净化规则没了/变了”

### 2. 最适合挂在正文后处理层

我们当前章节正文处理链路核心在：

- [`ChapterContentService.load(...)`](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/chapter_content_service.dart)
- 文本清理：
  [`content_text_cleaner.dart`](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/content_text_cleaner.dart)

当前顺序大致是：

1. 请求正文
2. 应用书源 `replaceRegex`
3. `ContentTextCleaner.clean`
4. 返回阅读页

用户净化规则最适合插在：

1. 请求正文
2. 书源 `replaceRegex`
3. `ContentTextCleaner.clean`
4. **用户净化规则**
5. 返回阅读页

理由：

- 先做基础清洗，减少 HTML 噪声和空白干扰
- 再做用户净化，命中结果更稳定
- 规则测试时也能基于最终接近阅读态的文本

### 3. 先做正文净化，标题净化第二阶段补

从用户价值和实现成本看：

- 用户最痛的其实是广告、水印、作者注、章节尾推广
- 这些 90% 都是正文净化

所以第一阶段只做：

- 正文净化规则

第二阶段再加：

- 标题净化规则

这是最优解，不建议第一版一上来就把标题和正文全做完。

---

## 二、产品方案

### MVP 功能范围

第一版建议只做以下能力：

1. 全局净化规则库
2. 规则启停
3. 正文净化
4. 作用范围
   - 全局
   - 按书名
   - 按书源
   - 排除范围
5. 规则测试
6. 阅读页查看“本章生效规则”
7. 导入 / 导出

### 第一版不做

- 标题净化
- 批量规则操作
- 分组排序拖拽
- 规则自动禁用熔断
- Web API 管理
- 云同步

---

## 三、用户心智设计

### 入口设计

建议入口放在：

- `我的 -> 规则`
  新增一个子分组：`净化规则`

阅读页则增加一个轻入口：

- `设置` 里增加 `本章净化`
  进入后显示：
  - 当前是否启用用户净化
  - 本章命中的规则列表
  - 跳转到规则管理

### 为什么不放在“书源”里

因为用户净化规则不属于某一个书源配置页面，而是：

- 用户自己的阅读体验层
- 可跨书源使用

### 为什么阅读页要显示“本章生效规则”

这是最关键的可解释性能力。

用户最常见的问题不是“怎么写规则”，而是：

- 为什么正文被删多了
- 为什么广告没去掉
- 到底哪条规则生效了

如果阅读页能看见“本章生效规则”，整个功能会从“黑盒”变成“可理解、可调试”。

---

## 四、技术方案

### 1. 数据模型

建议新增用户净化规则实体，例如：

`ReaderReplaceRule`

建议字段：

- `id`
- `name`
- `group`
- `pattern`
- `replacement`
- `isRegex`
- `scopeMode`
  - `all`
  - `bookTitle`
  - `sourceId`
  - `mixed`
- `scope`
  兼容字符串输入，第一版可继续用文本
- `excludeScope`
- `scopeContent`
  第一版默认 `true`
- `scopeTitle`
  第一版先保留字段但 UI 不开放
- `isEnabled`
- `timeoutMs`
- `sortOrder`
- `createdAt`
- `updatedAt`

### 2. 数据库存储

当前项目本地数据是 Drift：

- [`app_database.dart`](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/data/datasources/local/app_database.dart)

建议新增一张表：

- `reader_replace_rules`

第一版不建议用 SharedPreferences 存：

- 规则是结构化数据
- 未来会有测试、导入导出、排序、搜索
- 用表更稳，也方便后续批量操作

### 3. 作用域匹配

建议第一版先做一个简单但可解释的匹配器：

- 输入：
  - `bookTitle`
  - `sourceId`
- 规则：
  - `scope`
  - `excludeScope`
  - `scopeMode`

建议第一版匹配方式：

- `scopeMode = all`
  - 不做范围过滤
- `scopeMode = bookTitle`
  - `scope` 模糊包含书名
- `scopeMode = sourceId`
  - `scope` 精确或半精确匹配 sourceId
- `scopeMode = mixed`
  - `scope` 中任一 token 命中即可

排除规则优先级高于命中规则。

### 4. 执行器

建议新增用户净化执行器：

- `ReaderReplaceRuleExecutor`

职责：

- 接收原始正文字符串
- 按顺序执行规则
- 返回：
  - `content`
  - `effectiveRules`

返回结构建议：

`ReaderReplaceResult`

- `content`
- `effectiveRuleIds`
- `effectiveRules`

### 5. 阅读正文挂载点

建议在：

- [`ChapterContentService.load(...)`](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/features/reader/application/chapter_content_service.dart)

里新增用户净化步骤。

推荐顺序：

1. 书源 `replaceRegex`
2. `ContentTextCleaner.clean`
3. `ReaderReplaceRuleExecutor.execute`

不要放在 cleaner 之前，也不要放到 UI 层做。

### 6. 结果透传

现在章节结果对象是：

- `ChapterContentResult`

建议扩展新增：

- `effectiveReaderReplaceRules`

这样阅读页可以直接用，不需要二次查数据库。

---

## 五、规则测试方案

规则测试是必须有的，不建议第一版省略。

建议做一个极简测试面板：

- 输入：
  - 规则内容
  - 测试文本
- 输出：
  - 处理结果
  - 错误信息

第一版只支持：

- 普通字符串替换
- 正则替换

不需要一上来支持复杂脚本。

---

## 六、导入导出方案

最优解是：

- 第一版直接用 JSON
- 格式尽量贴近 MD3 / Legado 的 `ReplaceRule`
- 兼容旧字段映射

理由：

- 用户很多规则资产可能来自 Legado 生态
- 只要结构兼容，就能快速形成可迁移价值

建议导入兼容字段：

- `name`
- `group`
- `pattern`
- `replacement`
- `isRegex`
- `scope`
- `scopeTitle`
- `scopeContent`
- `excludeScope`
- `isEnabled`
- `timeoutMillisecond`
- `order` / `serialNumber`
- 老结构 `regex` / `replaceSummary` / `useTo`

---

## 七、阅读页展示方案

阅读页建议新增一个轻量弹层：

标题：

- `本章净化`

展示内容：

1. 总开关
   - 是否启用用户净化
2. 本章命中数量
3. 生效规则列表
   - 规则名
   - 可点进规则详情/编辑
4. 跳转到规则管理

这个入口价值非常高，建议 MVP 就带上。

---

## 八、与当前项目的衔接方式

### 新增文件建议

- `lib/domain/entities/reader_replace_rule.dart`
- `lib/features/reader/application/reader_replace_rule_executor.dart`
- `lib/features/reader/application/reader_replace_rule_service.dart`
- `lib/features/reader/presentation/reader_replace_rule_page.dart`
- `lib/features/reader/presentation/reader_effective_replace_sheet.dart`

### 数据层

- 在 [`app_database.dart`](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/data/datasources/local/app_database.dart) 增加表
- 增加 DAO / repository

### 接入链路

- `ChapterContentService`
  - 增加用户净化执行
- `ReaderPage`
  - 读取并展示 `effectiveReaderReplaceRules`

---

## 九、推荐实施顺序

### P1：先把链路打通

1. 建表 + 实体 + DAO
2. 做 `ReaderReplaceRuleExecutor`
3. 在 `ChapterContentService` 接入
4. 扩展 `ChapterContentResult`
5. 阅读页显示“本章生效规则”

### P2：再做管理 UI

1. 净化规则列表
2. 新增/编辑
3. 启停
4. 测试规则

### P3：最后做资产流转

1. JSON 导入
2. JSON 导出
3. 兼容 MD3 / Legado 旧格式

---

## 十、我建议我们下一步怎么做

如果按最优解推进，我建议下一步直接做：

1. `reader_replace_rules` 表设计
2. `ReaderReplaceRule` 实体
3. `ReaderReplaceRuleExecutor`
4. `ChapterContentService` 接入点

也就是先打通底层，不先做大而全的 UI。

原因：

- 没有底层执行链，UI 再漂亮都只是空壳
- 一旦执行链和结果透传打通，后面规则管理页、阅读页“本章净化”都只是 UI 迭代

---

## 十一、最后的推荐答案

最优解不是“先做一个规则页面”，而是：

> 先做用户级净化规则底层链路，再做阅读页的生效回显，最后补规则管理与导入导出。

这是当前项目里风险最低、收益最高、也最不容易返工的路线。
