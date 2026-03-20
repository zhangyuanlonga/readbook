# Legado MD3 TXT 目录规则梳理

本文基于外部项目 `/Users/zhangyuanlong/Downloads/legado-with-MD3-main` 的源码分析，目标是把它的 TXT 目录规则功能梳理清楚，供我们在当前 Flutter 项目中实现时参考。

## 结论先看

- Legado MD3 的 TXT 目录规则不是“单本书独立规则库”，而是：
  - 一套全局可管理的 `TxtTocRule` 规则库
  - 每本 TXT 书在 `Book.tocUrl` 上保存“当前选中的目录正则字符串”
- 首次解析 TXT 时，如果书上还没有 `tocUrl`，系统会：
  - 先读文件头一段文本
  - 用全局启用规则自动挑一个“最像目录规则”的正则
  - 把这个正则字符串写回 `book.tocUrl`
- 真正分章时：
  - 如果 `book.tocUrl` 非空，则按正则分章
  - 如果为空，则退化成按固定字数 + 换行的“无规则分章”
- 规则管理是完整功能：
  - 内置默认规则
  - 用户可新增、编辑、启用/禁用、排序
  - 支持导入/导出
  - 阅读页/目录页可直接给当前书切换 TXT 目录规则

## 关键源码位置

- TXT 解析主实现：
  - `/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/model/localBook/TextFile.kt`
- TXT 目录规则实体：
  - `/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/data/entities/TxtTocRule.kt`
- TXT 目录规则 DAO：
  - `/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/data/dao/TxtTocRuleDao.kt`
- TXT 目录规则仓库：
  - `/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/data/repository/TxtTocRuleRepository.kt`
- 默认规则加载：
  - `/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/help/DefaultData.kt`
- 默认规则数据：
  - `/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/assets/defaultData/txtTocRule.json`
- 阅读页切换当前书 TXT 目录规则：
  - `/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/ui/book/read/ReadBookActivity.kt`
- 目录页保存当前书 TXT 目录规则：
  - `/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/ui/book/toc/TocViewModel.kt`
- 规则管理 UI：
  - `/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/ui/book/toc/rule/TxtRuleScreen.kt`
  - `/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/ui/book/toc/rule/TxtTocRuleActivity.kt`

## 数据模型

### 1. 全局规则库

`TxtTocRule` 实体很简单，核心字段只有 6 个：

- `id`
- `name`
- `rule`
- `example`
- `serialNumber`
- `enable`

源码：
- `/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/data/entities/TxtTocRule.kt`

含义：

- `name`：规则名称，给 UI 展示
- `rule`：真正生效的 Java/Kotlin 正则
- `example`：示例标题，帮助用户理解
- `serialNumber`：排序权重，规则库顺序按它排
- `enable`：是否参与自动匹配/可选列表

### 2. 单本书的当前规则

TXT 书当前使用的目录规则，不是存规则 ID，而是直接把正则字符串写到 `Book.tocUrl`。

源码：
- `/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/data/entities/Book.kt`

这一点很重要，因为它意味着：

- 规则库顺序、启用状态变化后，已经选中过规则的书不会自动受影响
- 单本书保存的是“快照字符串”，不是“规则引用”

## 首次解析流程

入口在 `TextFile.getChapterList()`。

源码：
- `/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/model/localBook/TextFile.kt`

它的整体流程是：

1. 如果书籍字符集未知、`book.tocUrl` 为空、或者本地文件已变更：
   - 读取文件头一块内容
   - 检测 charset
   - 如果 `tocUrl` 为空或文件变更，则自动选择目录规则
2. 自动选中的规则会写回 `book.tocUrl`
3. 再用 `book.tocUrl.toPattern(Pattern.MULTILINE)` 做正式分章
4. 分章完成后回填：
   - `book.wordCount`
   - 每章 `index`
   - 每章 `bookUrl`
   - 每章 `url`（基于标题和索引生成）

## 自动选规则逻辑

自动选规则核心在 `getTocRule(content: String)`。

源码：
- `/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/model/localBook/TextFile.kt`

算法特点：

1. 取出启用规则列表 `getTocRules()`
2. 反转规则列表后遍历 `rules.reversed()`
3. 每条规则先尝试编译：
   - 编译失败则记录日志并跳过
4. 用正则在文件头文本上做 `matcher.find()`
5. 统计“有效命中数”：
   - 第一次命中算一次
   - 后续只有当本次命中距上次命中起点超过 `1000` 字符，才算新命中
6. 选择有效命中数最多的规则
7. 若数量相同，后遍历到的规则会覆盖前面的规则

这说明它不是简单“命中即用”，而是基于“像目录行反复出现”的密度判断。

### 自动选规则的数据来源

`getTocRules()` 的逻辑是：

- 优先取数据库里启用的规则
- 如果数据库还是空的，就从默认资源 `txtTocRule.json` 导入一份
- 然后只保留 `enable = true` 的规则

相关源码：
- `/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/model/localBook/TextFile.kt`
- `/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/help/DefaultData.kt`

## 正则分章逻辑

正则分章走 `analyze(pattern: Pattern?)`。

源码：
- `/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/model/localBook/TextFile.kt`

### 解析特点

- 分块读取文件，每块约 `512000` 字节
- 处理 UTF-8 BOM
- 如果块读满，会向前回退到最近的换行符，避免把一行标题截断
- 用 `matcher.find()` 在块文本中扫描章节标题
- `matcher.group()` 整段匹配文本直接作为章节标题
  - 不依赖捕获组
  - 这点很适合我们实现时简化

### 前言/序章处理

如果第一次命中前面还有正文：

- 且当前还没有章节，则会生成一章 `"前言"`
- 并把前 500 字作为 `book.intro`

### 卷判断

它会用：

- `chapterContent.substringAfter(lastChapter.title).isBlank()`

来判断上一项是不是卷名/空壳标题，并写到 `lastChapter.isVolume`。

### 长章节拆分

有两套长度阈值：

- 有目录规则时：`maxLengthWithToc = 102400`
- 无目录规则时：`maxLengthWithNoToc = 10 * 1024`

如果开启 `book.getSplitLongChapter()`，且章节正文超阈值：

- 会把原章节拆成多个子章节
- 子章节标题格式：`原标题(1)`、`原标题(2)`...

## 无规则兜底分章

如果没有目录规则，走 `analyze(fileStart, fileEnd)` 这个无规则版本。

特点：

- 纯按字数切分
- 单章长度默认约 `10KB`
- 优先向后找到最近换行作为切点
- 自动生成标题：
  - `第{blockPos}章({chapterPos})`

这不是高质量目录，只是阅读兜底。

## 默认规则库内容特征

默认规则在：
- `/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/assets/defaultData/txtTocRule.json`

观察下来它的默认策略很实用：

- 有“严格规则”
  - `目录`
  - `目录(去空白)`
- 有“格式备用”
  - 古典/轻小说
  - `Chapter/Section/Part/Episode`
  - 特殊符号标题
- 有“纯数字/分隔符标题”类规则
- 有“通用激进规则”
- 还有一个空规则：
  - `默认分章规则`
  - `rule = ""`
  - 实际就是无规则兜底的占位项

启用策略不是全开，很多高误伤规则默认是关闭的。

## 用户怎么改规则

### 1. 全局规则管理

`TxtRuleScreen` 提供完整管理能力：

- 搜索
- 新增
- 编辑
- 删除
- 启用/禁用
- 拖拽排序
- 本地导入
- 在线导入
- 导出

源码：
- `/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/ui/book/toc/rule/TxtRuleScreen.kt`

### 2. 给当前正在读的 TXT 书切规则

阅读页菜单会打开 `TxtTocRuleActivity`：

- 传入当前书的 `tocRegex`
- 用户从规则页挑一个规则
- 返回选中的正则字符串
- 直接写回 `ReadBook.book?.tocUrl`
- 然后重新加载章节列表

源码：
- `/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/ui/book/read/ReadBookActivity.kt`
- `/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/ui/book/toc/rule/TxtTocRuleActivity.kt`

### 3. 在目录页保存当前书规则

目录页 ViewModel 里也有：

- `saveTocRegex(newRegex)`

会把新正则写回 `book.tocUrl` 并持久化。

源码：
- `/Users/zhangyuanlong/Downloads/legado-with-MD3-main/app/src/main/java/io/legado/app/ui/book/toc/TocViewModel.kt`

## 对我们实现最有价值的设计点

### 建议保留

1. 全局规则库 + 单本书当前规则快照
2. 首次自动选规则，只读文件头一段，不全量扫描
3. 规则命中数量评估，而不是首条命中即用
4. 无规则时提供字数兜底分章
5. 长章节拆分开关独立存在
6. 规则库支持启用/禁用和排序

### 建议改进

1. 自动选规则不要只看“命中次数”
   - 可增加标题唯一性
   - 可增加标题分布均匀性
   - 可扣掉过短纯数字误判
2. 单本书最好存“规则 ID + 正则快照”
   - 这样既能追溯来源
   - 又能避免规则库变动把历史书搞乱
3. 卷判断逻辑可更显式
   - 当前只是“标题后面正文是否为空”
4. 无规则分章标题建议换成更用户可理解的格式
   - 例如 `第 1 段`
   - 避免误导用户把兜底分段当成真实章节

## 对我们 Flutter 项目的落地建议

建议拆成 4 层：

1. `TxtTocRule` 数据层
   - id
   - name
   - rule
   - example
   - serialNumber
   - enabled

2. `TxtTocRuleService`
   - 读默认规则
   - 自动补库
   - 启用规则列表
   - 规则自动选择

3. `TxtChapterParser`
   - `parseWithRegex`
   - `parseWithoutRegex`
   - `splitLongChapterIfNeeded`

4. `PerBookTxtConfig`
   - 当前书选中的规则
   - 是否开启长章节拆分
   - 文件 charset

## 我们实现时最值得直接对标的行为

- 如果书还没有目录规则：
  - 读取文件头
  - 自动挑规则
  - 写回当前书配置
- 如果目录规则为空：
  - 走无规则兜底分段
- 用户改了当前书目录规则：
  - 只影响当前书
  - 立刻重建目录
- 全局规则库变动：
  - 只影响新书或未绑定规则的书

## 一个很实际的产品决策建议

我们的 Flutter 项目里，建议把 TXT 目录规则分成两层 UI：

- 全局“TXT 目录规则管理”
- 当前书“切换目录规则”

不要只做全局规则管理，不然用户很难解决“这一本书分错章”的问题。

## 后续实现建议

建议实现顺序：

1. 先做 `TxtTocRule` 数据模型和默认规则导入
2. 再做 `Text parser` 的无规则兜底
3. 再做“自动选规则”
4. 再做“当前书切换目录规则”
5. 最后做“长章节拆分”和规则管理 UI

如果后续要开始编码，这份文档可以直接作为实现 checklist 使用。
