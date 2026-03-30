# 去 Legado 全量迁移蓝图（详细版）

更新时间：2026-03-30  
适用范围：`flutterreadbook` 当前仓库代码（阅读主链、发现页、书源导入导出、脚本源 runtime）

---

## 1. 你要的“完全移除”定义

本文把“完全移除旧规则和声明式”定义为以下 6 条全部成立：

1. 线上执行路径不再调用 `RuleEngine` 的声明式规则解析（`html:/json:/regex:/xpath:`）来跑书源。
2. `SearchService / BookDetailService / ChapterContentService / ExploreService` 不再消费 `SourceRuleSet`。
3. 书源唯一执行规范为脚本源规范 `source-spec-v1`（`search/detail/chapters/content` + discover 扩展）。
4. 导入导出默认仅面向新规则 schema；旧 JSON 仅作为“迁移输入”，不再作为运行态配置。
5. `legacy_*` processors、`LegadoSourceAdapter` 不再属于生产路径。
6. 数据层不再维护“旧规则源 + 脚本源”双执行仓。

---

## 2. 现状诊断（为什么现在不能直接删）

当前是双链并存：

1. 旧规则链仍是主链
- `search/detail/toc/content` 主实现仍在旧规则服务中。
- 关键依赖：`legacy_rule_compat / legacy_xpath_compat / legacy_script_rule_fallback`。

2. 脚本源链只覆盖“部分能力”
- 搜索已并行接入脚本源。
- 详情正文在旧源缺失时能回退脚本源。
- 发现页仍是旧规则专用 `ExploreService`。

3. discover 能力在 runtime 合约中不存在
- `SourceTaskStep` 只有 `search/detail/chapters/content`。
- 编译器也仅强制这 4 个方法。

结论：当前架构可“迁移”，但不具备“一步硬删旧链”的条件。

---

## 3. 目标架构（单链运行态）

目标是单一运行时链路：

1. 统一调度入口（建议新增）
- `UnifiedSourceDispatchService`
- 对外仅暴露：
  - `discoverCategories`
  - `discoverBooks`
  - `search`
  - `detail`
  - `chapters`
  - `content`

2. 统一执行内核
- 全部调用 `SourceRuntimeFacade -> ScriptSourceRuntimeService -> SourceExecutor`
- 不再走 `SourceRuleSet` 解析。

3. 统一数据主模型
- 运行态书源只存“脚本源实体”（含 `sourceCode + meta`）。
- 旧规则字段仅存在于迁移快照，不参与线上执行。

4. 统一能力声明
- 由 `meta.capabilities` 决定功能可用性（不是“存了但不读”）。

---

## 4. 关键缺口清单（按阻断级）

## P0（不做就无法全量切换）

1. discover 缺失 runtime 合约
- 现状：`SourceTaskStep` 无 discover。
- 结果：发现页无法纯脚本源化。

2. Discover 页面仍绑旧规则字段
- `exploreUrl + explore*` 映射成伪搜索。
- 脚本源 discover 不可用。

3. 导入导出仍是 Legado 口径
- 导入：`LegadoSourceAdapter` 直入旧模型。
- 导出 fallback：写 `ruleSearch/ruleBookInfo/ruleToc/ruleContent`。

4. 主链服务仍以声明式规则为核心
- 搜索/详情/正文链仍直接操作 `SourceRuleSet`。

## P1（不阻断上线，但会留下功能坑）

1. 漫画模式脚本源被排除。  
2. 换源候选仅来自旧书源表。  
3. runtime `Content.nextUrl` 未接阅读聚合。  
4. 错误文案、校验文案仍是旧字段术语。

## P2（技术债）

1. `sources` 与 `stored_script_sources` 双仓并存。  
2. 兼容能力分析仍围绕 Legado 特征（`Reload/js:`）。

---

## 5. “完全移除”实施方案（推荐）

## 阶段 0：冻结旧链扩展

目标：
- 不再新增任何基于 `SourceRuleSet` 的新能力。
- 新需求全部落到脚本源 runtime。

动作：
1. 文档声明旧规则进入维护态。  
2. 新模板与新功能仅走脚本源。  
3. 把旧链相关改动纳入“仅修复回归，不增功能”。

---

## 阶段 1：补齐 runtime discover 能力

目标：
- runtime 成为 discover 的一等执行路径。

建议接口（示例）：

```dart
enum SourceTaskStep {
  discoverCategories,
  discoverBooks,
  search,
  detail,
  chapters,
  content,
}
```

脚本规范扩展（建议）：

```js
export default {
  meta: {
    capabilities: [
      'discoverCategories',
      'discoverBooks',
      'search',
      'detail',
      'chapters',
      'content',
    ],
  },
  async discoverCategories(ctx) {},
  async discoverBooks(ctx, category, page, pageSize) {},
}
```

落地点：
1. `source_contract.dart` 增 discover task 与模型。  
2. `source_script_compiler.dart` 支持 discover 可选方法识别。  
3. `source_executor.dart` 增 discover 执行与缓存。  
4. `source_runtime_facade.dart` 暴露 discover API。  
5. 模板文件增加 discover 专属模板。

---

## 阶段 2：Discover 页面改为统一调度

目标：
- Discover 不再依赖 `explore* -> search*` 映射技巧。

动作：
1. 新建 `DiscoverDispatchService`（或并入统一调度服务）。  
2. 执行顺序：
   - 先 runtime discover
   - 旧 `explore*` 仅作为过渡 fallback（有开关）
3. `supportsExplore` 判定改为 capability 驱动。  
4. 页面状态里显式标注当前来源类型（runtime/legacy-fallback）。

退出条件：
- 至少 90% 已启用源可走 runtime discover。

---

## 阶段 3：旧字段迁移到新规则脚本（核心）

这是你问的重点：如何把旧字段迁移并对接原有数据。

### 3.1 迁移总原则

1. 不做“运行时兼容旧字段”，做“一次性迁移生成脚本”。  
2. 迁移结果一定是可编辑脚本文件，不是隐式映射黑盒。  
3. 对无法自动迁移的规则必须输出明确告警与 TODO。

### 3.2 迁移输入与输出

输入：
- 旧 JSON（`ruleSearch/ruleBookInfo/ruleToc/ruleContent/ruleExplore...`）
- 或 DB 中旧 `SourceDefinition`

输出：
- 新脚本源代码（符合 `source-spec-v1`）
- 迁移报告（成功项、降级项、失败项）

### 3.3 字段对接映射（旧 -> 新）

| 旧字段 | 中间语义 | 新脚本位置 | 迁移说明 |
|---|---|---|---|
| `searchUrl` / `ruleSearchUrl` / `ruleSearch` | 搜索请求 | `search(ctx, keyword)` | 生成请求 URL 与参数 |
| `searchInitRule` | 搜索前置变量 | `init` 或 `search` 前置调用 | 迁移为预请求/会话变量 |
| `ruleSearchList` | 搜索列表抽取 | `search` | 解析列表节点 |
| `ruleSearchName` | 书名抽取 | `search` | 填充 `Book.title` |
| `ruleSearchBookUrl` | 详情链接抽取 | `search` | 填充 `Book.detailUrl` |
| `ruleSearchAuthor/Intro/Cover/LastChapter` | 搜索附加字段 | `search` | 对应 `Book` 字段 |
| `ruleBookInfo` | 详情页解析入口 | `detail(ctx, book)` | 补齐 `Book` |
| `detailInitRule` / `ruleBookInfoInit` | 详情前置请求 | `detail` 前置调用 | 迁移到 `detail` 内 |
| `ruleBookName/Author/Intro/CoverUrl` | 详情字段抽取 | `detail` | 补齐 `Book` |
| `ruleTocUrl` | 目录 URL | `detail.extra.catalogUrl` | 供 `chapters` 使用 |
| `ruleToc` | 目录解析入口 | `chapters(ctx, book)` | 返回 `Chapter[]` |
| `tocInitRule` / `ruleTocInit` | 目录前置请求 | `chapters` 前置调用 | 迁移到 `chapters` |
| `ruleChapterList/Name/Url` | 目录字段 | `chapters` | 构造 `Chapter` |
| `ruleTocNextUrl` / `tocNextUrlRule` | 目录分页 | `chapters` 循环翻页 | 追加章节 |
| `ruleContent` | 正文抽取 | `content(ctx, book, chapter)` | 输出 `Content.content/images` |
| `contentInitRule` / `ruleContentInit` | 正文前置请求 | `content` 前置调用 | 迁移到 `content` |
| `contentDecryptRule` | 响应解密/解码 | `content` 辅助函数 | 迁移为脚本内 helper |
| `replaceRegex` / `contentReplaceRegex` | 正文替换 | `content` 后处理 | 用正则清洗 |
| `nextContentUrl` / `contentNextUrlRule` | 正文分页 | `content.nextUrl` 或循环抓取 | 推荐先填 `nextUrl` |
| `exploreUrl` / `discoverUrl` | 发现入口 | `discoverCategories/discoverBooks` | 改 discover 主链 |
| `ruleExplore*` | 发现解析字段 | `discoverBooks` | 输出 `Book[]` |
| `jsLib` | 共享函数库 | 脚本顶部 helper | 合并为本地函数 |

### 3.4 自动迁移器分级

1. `AUTO`（可自动）
- 固定 URL + 常规 CSS/JSONPath 抽取 + 简单分页

2. `SEMI`（半自动）
- `@put`、复杂模板、部分 JS 表达式
- 生成脚本 + `TODO` 注释 + 报告警告

3. `MANUAL`（需人工）
- `Reload(...)`、外部动态脚本、强依赖老桥接函数
- 仅生成骨架并阻止自动启用

### 3.5 迁移后如何对接原有字段

迁移后保留以下元数据，保证可追溯与回滚：

```json
{
  "migration": {
    "legacySourceId": "...",
    "legacyHash": "...",
    "migratedAt": "2026-03-30T10:00:00Z",
    "mode": "AUTO|SEMI|MANUAL",
    "warnings": []
  }
}
```

建议存放位置：
- `ScriptSource.description` 附加 JSON 片段或单独 `meta.extra`。

---

## 阶段 4：切换执行默认值

目标：
- 所有用户入口默认仅显示/使用新规则源。

动作：
1. 搜索、详情、目录、正文、发现统一走 runtime 调度。  
2. 旧链改为隐藏开关（仅应急回滚可见）。  
3. 导入入口默认“新 schema”；“导入旧 JSON”移到“迁移工具”。  
4. 导出默认“新 schema”；旧导出仅在高级选项里保留过渡期。

---

## 阶段 5：物理删除旧规则与声明式

删除范围：
1. `legacy_*` processors。  
2. `LegadoSourceAdapter`（或迁入 `archive/` 工具目录，不进生产构建）。  
3. `SearchService/BookDetailService/ChapterContentService` 中旧规则执行分支。  
4. 旧文案与校验口径（`ruleSearch/ruleContent` 等）。

硬门禁（建议 CI）：
1. `rg "legacy_|Legacy|ruleSearch|ruleBookInfo|ruleToc|ruleContent"` 仅允许命中 `docs/archive/testdata`。  
2. 主路径代码不得再 import `legacy_*`。

---

## 6. 数据层迁移方案（双仓 -> 单仓）

当前：
- `sources`（旧规则）
- `stored_script_sources`（脚本源）

目标：
- 单一运行态仓（建议新表 `runtime_sources` 或复用 `stored_script_sources` 扩展字段）

建议步骤：

1. 新增统一查询视图层（先不改表）
- 统一 API：`listRuntimeSources()/getRuntimeSourceById()`
- 先把脚本源 + 已迁移旧源聚合出来

2. 批量迁移旧源
- 逐条转换为脚本源
- 转换成功后旧源置 `enabled=false` 并打迁移标记

3. 稳定运行一段窗口期
- 收集故障率与回滚率

4. 执行表收敛
- 移除 `sources` 的执行路径引用
- 最终迁移脚本清理旧表或仅归档

---

## 7. 风险与回滚

## 高风险点

1. 复杂旧源自动迁移失败导致可读性下降。  
2. discover 切换后分类规则不一致。  
3. 漫画/分页正文在 runtime 侧行为回归。  
4. 用户导入习惯仍是旧 JSON，造成入口理解成本。

## 回滚策略

1. 运行时开关
- `useRuntimeForSearch`
- `useRuntimeForDetail`
- `useRuntimeForContent`
- `useRuntimeForDiscover`

2. 数据回滚
- 保留旧源快照（至少一个版本周期）
- 支持“一键回退到迁移前状态”

3. 发布策略
- 灰度开启 -> 全量
- 灰度阶段保留旧链兜底

---

## 8. 测试与验收（详细）

## 单元测试

1. discover 合约与编译器识别。  
2. 旧字段迁移器映射正确性（分 `AUTO/SEMI/MANUAL`）。  
3. `nextUrl` 在 runtime content 聚合中的行为。  
4. capability 驱动的可用性判断。

## 集成测试

1. 搜索 -> 详情 -> 目录 -> 正文（小说源）。  
2. 搜索 -> 详情 -> 目录 -> 正文（漫画源）。  
3. discover 分类 -> 发现列表 -> 详情打开。  
4. 换源（含脚本源候选）。  
5. 导入旧 JSON -> 自动迁移 -> 可阅读。

## 回归测试

1. 阅读记录、缓存、书签不回归。  
2. 本地阅读链路不受影响。  
3. 错误中心日志可定位到 runtime 步骤与源 ID。

## 物理删除前 DoD

1. 所有线上执行入口都能在“关闭旧链”情况下通过回归。  
2. P0/P1 清单全部关闭。  
3. 灰度周期稳定，无 P0 线上事故。  
4. 文档、模板、导入导出口径全部更新为新规则术语。

---

## 9. 你可直接执行的最小落地顺序

如果你要最短路径推进，建议按这个顺序做：

1. 先实现 runtime discover 合约与模板。  
2. 再改 Discover 页面接 runtime（旧逻辑降级为 fallback）。  
3. 然后做“旧 JSON -> 脚本源”迁移器（先支持 `AUTO` 子集）。  
4. 接着把搜索/详情/正文统一走 runtime 调度。  
5. 最后执行物理删除旧规则与声明式。

---

## 10. 关联参考

1. `docs/script_sources/source-spec-v1.md`  
2. `docs/script_sources/official-source-author-guide.md`  
3. `docs/script_sources/js-rules-quick-reference.md`  
4. `docs/templates/source_template_minimal_v1.js`  
5. `docs/templates/source_template_api_v1.js`

