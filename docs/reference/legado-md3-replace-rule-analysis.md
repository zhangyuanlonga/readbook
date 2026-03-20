# Legado MD3 净化规则梳理

本文基于外部项目 `/Users/zhangyuanlong/Downloads/legado-with-MD3-main` 的源码分析，目标是把它的“净化规则 / 替换规则”功能梳理清楚，供我们在当前 Flutter 项目中设计和实现时参考。

## 一句话结论

Legado MD3 的“净化规则”本质上是一套用户可管理的全局替换规则库：

- 规则可以作用于标题、正文，或者两者同时作用
- 规则支持按书名 / 书源 origin 做命中范围控制
- 规则支持正则和普通字符串替换
- 正文加载时会实时应用匹配到的规则
- 命中的规则会被记录下来，阅读页可查看“本章实际生效了哪些规则”
- 规则有完整的管理能力：新增、编辑、测试、启停、排序、分组、导入导出、备份恢复

这不是“书源规则的一部分”，而是“用户自己的阅读净化层”。

## 核心源码位置

- 规则实体：
  [`ReplaceRule.kt`](/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/data/entities/ReplaceRule.kt)
- 规则查询 / 作用域匹配：
  [`ReplaceRuleDao.kt`](/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/data/dao/ReplaceRuleDao.kt)
- 正文处理主链路：
  [`ContentProcessor.kt`](/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/help/book/ContentProcessor.kt)
- 正文结果对象（带生效规则）：
  [`BookContent.kt`](/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/help/book/BookContent.kt)
- 规则管理列表：
  [`ReplaceRuleViewModel.kt`](/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/ui/replace/ReplaceRuleViewModel.kt)
- 规则编辑：
  [`ReplaceEditViewModel.kt`](/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/ui/replace/edit/ReplaceEditViewModel.kt)
- JSON 导入兼容：
  [`ReplaceAnalyzer.kt`](/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/help/ReplaceAnalyzer.kt)
- Web/API 测试与保存：
  [`ReplaceRuleController.kt`](/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/api/controller/ReplaceRuleController.kt)
- 阅读页查看本章生效规则：
  [`EffectiveReplacesDialog.kt`](/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/ui/book/read/EffectiveReplacesDialog.kt)

## 1. 规则模型

MD3 的净化规则实体是 `ReplaceRule`。

关键字段：

- `id`
- `name`
  规则名，用户识别用
- `group`
  分组名，可为空
- `pattern`
  匹配内容
- `replacement`
  替换结果，允许为空；为空时相当于删除命中内容
- `scope`
  生效范围，字符串匹配；通常写书名、书源标识等
- `scopeTitle`
  是否作用于标题
- `scopeContent`
  是否作用于正文
- `excludeScope`
  排除范围，命中则不生效
- `isEnabled`
  是否启用
- `isRegex`
  是否正则规则
- `timeoutMillisecond`
  单条正则超时
- `order`
  排序权重

要点：

- 一条规则不是“只绑定某本书”
- 而是通过 `scope / excludeScope` 在运行时动态匹配
- 标题和正文是两条并行作用域

## 2. 规则命中范围

规则命中是通过 DAO 层直接筛选出来的。

正文规则查询：
[`ReplaceRuleDao.findEnabledByContentScope(...)`](/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/data/dao/ReplaceRuleDao.kt)

标题规则查询：
[`ReplaceRuleDao.findEnabledByTitleScope(...)`](/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/data/dao/ReplaceRuleDao.kt)

匹配逻辑可以概括为：

- 规则必须启用
- `scopeContent` / `scopeTitle` 必须对当前阶段打开
- `scope` 为空则视为全局生效
- `scope` 非空时，只要包含当前 `bookName` 或 `bookOrigin` 之一就算命中
- `excludeScope` 命中 `bookName` 或 `bookOrigin` 时排除
- 最终按 `sortOrder` 顺序返回

这意味着 MD3 的净化规则是：

- “全局规则库”
- “运行时按书名 / 书源筛选”
- “有正向范围 + 反向排除”

## 3. 阅读时的正文处理链路

核心入口在：
[`ContentProcessor.getContent(...)`](/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/help/book/ContentProcessor.kt)

处理顺序大致是：

1. 去重标题
2. 可选重分段 `reSegment`
3. 简繁转换
4. 特殊 HTML 内容占位保护
5. 应用正文净化规则
6. 恢复 HTML 占位内容
7. 重新补回标题
8. 最终按段切分并加段首缩进

其中真正的“净化规则应用”是第 5 步。

### 正文规则怎么执行

执行时先拿当前书的正文规则列表：

- `getContentReplaceRules()`

然后逐条应用：

- 如果 `isRegex = true`
  - 使用正则替换
  - 带超时保护
- 如果 `isRegex = false`
  - 直接字符串替换

只要某条规则让正文发生了变化：

- 就把这条规则加入 `effectiveReplaceRules`
- 并把替换后的正文继续传给下一条规则

这说明 MD3 是严格的“链式净化”：

- 前一条规则的结果会影响后一条规则
- 规则顺序非常重要

## 4. 标题规则怎么用

标题规则不会在 `getContent` 里直接循环替换正文，而是通过：

- `chapter.getDisplayTitle(...)`
- `getTitleReplaceRules()`

去生成显示标题。

所以 MD3 把“标题净化”和“正文净化”明确分开：

- 正文：正文替换链
- 标题：显示标题生成链

这个分离很重要，后面我们产品里最好也保持这个模型，不要混成一个字段。

## 5. 生效规则可回显

正文处理结果 `BookContent` 里会把本章实际命中的规则列表一起带出来：

- `effectiveReplaceRules: List<ReplaceRule>?`

见：
[`BookContent.kt`](/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/help/book/BookContent.kt)

阅读页里可以通过：
[`EffectiveReplacesDialog.kt`](/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/ui/book/read/EffectiveReplacesDialog.kt)

查看：

- 本章生效了哪些净化规则
- 点击后还能直接跳到规则编辑

这是个很有价值的设计点，因为用户不会只关心“有没有规则”，而是关心：

- 这章到底用了哪条规则
- 是不是某条规则误伤了正文

## 6. 错误与保护机制

MD3 对净化规则不是“全信任执行”，而是做了几层保护：

- 规则格式校验：`ReplaceRule.isValid()`
- 正则编译校验：非法正则直接视为无效
- 正则替换超时：`timeoutMillisecond`
- 超时后会禁用该规则并更新数据库
- 替换异常会记录日志并弹提示

尤其这一点值得借鉴：

- 发生正则超时时，会把规则直接 `isEnabled = false`
- 避免用户下次继续被同一条坏规则卡住

## 7. 管理功能

MD3 的净化规则管理不是一个简单列表，而是一套完整规则库功能。

### 列表能力

在：
[`ReplaceRuleViewModel.kt`](/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/ui/replace/ReplaceRuleViewModel.kt)

支持：

- 搜索
- 分组筛选
- 启停
- 批量启停
- 删除
- 批量删除
- 排序模式切换
- 调整顺序（置顶 / 置底 / 上下移动）
- 分组增删改

### 编辑能力

在：
[`ReplaceEditViewModel.kt`](/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/ui/replace/edit/ReplaceEditViewModel.kt)

支持编辑字段：

- 名称
- 分组
- 匹配内容
- 替换内容
- 是否正则
- 作用范围
- 是否作用标题
- 是否作用正文
- 排除范围
- 超时时间

另外还有：

- 复制规则为 JSON
- 从剪贴板粘贴规则

## 8. 导入导出 / 备份恢复

### JSON 导入兼容

在：
[`ReplaceAnalyzer.kt`](/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/help/ReplaceAnalyzer.kt)

它兼容两种 JSON 形态：

1. 当前新结构：直接反序列化 `ReplaceRule`
2. 老结构映射：
   - `regex`
   - `replaceSummary`
   - `replacement`
   - `isRegex`
   - `useTo`
   - `enable`
   - `serialNumber`

这说明 MD3 很重视历史替换规则资产兼容。

### 备份恢复

搜索结果里能看到：

- `Backup.kt` 会导出 `replaceRule.json`
- `Restore.kt` 会恢复 `replaceRule`
- `ImportOldData.kt` 会导入旧版 `myBookReplaceRule.json`

也就是说，净化规则在 MD3 是一等公民，不是附属功能。

## 9. Web / API 侧测试能力

在：
[`ReplaceRuleController.kt`](/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/api/controller/ReplaceRuleController.kt)

还提供了：

- 取全部规则
- 保存规则
- 删除规则
- 测试规则

测试规则的输入是：

- `rule`
- `text`

输出是替换后的结果或错误堆栈。

这说明 MD3 除了 App 内 UI，还考虑了规则外部调试/网页调试场景。

## 10. 产品能力拆解

如果从产品角度抽象，MD3 的“净化规则”最少包含这 6 个能力：

1. 规则库
   - 可全局管理
2. 作用域
   - 全局 / 定向书名 / 定向书源 / 排除范围
3. 应用阶段
   - 标题
   - 正文
4. 执行模式
   - 普通字符串替换
   - 正则替换
5. 调试反馈
   - 测试文本
   - 查看本章生效规则
6. 资产流转
   - 导入 / 导出 / 备份 / 恢复

## 11. 对我们产品的意义

我们当前 Flutter 项目里已经有：

- 书源规则层的 `replaceRegex` 执行能力
  见：
  [`replace_regex_executor.dart`](/Users/zhangyuanlong/storage/FlutterProject/flutterreadbook/lib/core/rule_engine/processors/replace_regex_executor.dart)

但这和 MD3 的净化规则不是一回事。

区别在于：

- 书源 `replaceRegex`
  - 是“源作者写的解析规则的一部分”
  - 作用在爬取结果 / 书源链路
- MD3 净化规则
  - 是“用户自己维护的阅读净化层”
  - 作用在最终展示内容之前

所以如果我们要加这个能力，不应该塞进源规则执行器里，而应该单独做成：

- 阅读内容后处理层
- 用户规则库

## 12. 我建议我们怎么做

建议分 3 层落地：

### 第一层：MVP

- 只做正文净化规则
- 规则字段：
  - 名称
  - pattern
  - replacement
  - isRegex
  - isEnabled
  - scope
  - excludeScope
- 阅读页支持：
  - 开/关使用净化规则
  - 查看本章生效规则

### 第二层：完整版本

- 增加标题净化规则
- 增加分组、排序、批量启停
- 增加测试规则
- 增加导入导出

### 第三层：高级版本

- 作用域支持更明确的结构化匹配
  - 按书名
  - 按作者
  - 按书源 ID
- 规则命中调试
- 规则超时熔断 / 自动禁用

## 13. 我们实现时建议保留的设计

我建议优先保留 MD3 这几个设计点：

- 标题净化和正文净化分开
- 规则按书名 / 书源做作用域筛选
- 记录本章实际生效规则
- 正则替换要有超时保护
- 导入兼容旧格式

## 14. 我们不建议照搬的点

有几处建议不要原样复制：

- `scope` / `excludeScope` 直接做字符串 `LIKE`
  - 对用户不够直观
  - 后面我们更适合改成结构化作用域
- 超时后直接禁用规则
  - 可保留为可选策略
  - 但最好先提示用户，而不是静默失活

## 15. 下一步建议

如果要真正落到我们产品，我建议下一步先做一份“净化规则 MVP 设计”：

- 数据模型
- 存储方式
- 阅读页挂载点
- 管理入口放在哪
- 阅读页如何显示“本章生效规则”

这样会比直接开始写代码更稳。
