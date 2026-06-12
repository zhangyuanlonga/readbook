# 书源生态简化改造方案

**版本：** v1.0  
**日期：** 2026-06-12  
**目标：** 修复旧书源兼容回退问题，理清 Flutter、Go、Rust 边界，减少重复调用，形成简单稳定的书源生态。

---

## 1. 背景问题

当前用户反馈的典型错误：

```text
检测网关调用失败：invalid source json: invalid type: map, expected a string
```

核心原因不是 Flutter 导入时 JSON 语法错误，而是新链路保存了用户原始 JSON，检测/阅读时再把原始 JSON 交给 Rust。旧逻辑导入后会重新规整一遍，所以很多 Legado 灵活字段可以被转成运行时可用结构；新逻辑缺少这个稳定的运行时 JSON 层。

改造前问题链路大致为：

```text
Flutter 我的书源
  -> Go /v1/me/book-sources/:id/test
  -> Go 读取 book_sources.source_json
  -> Rust /api/v1/sources/check/raw
  -> Rust 解析并检测
```

当时 Go 负责账号、权限、额度、分组、审核、CRUD；Rust 负责书源解析、检测、搜索、详情、目录、正文执行。边界被拉扯后出现了这些问题：

- Go 保存的是原始 JSON，Rust 运行时没有稳定读取统一规整后的 JSON。
- 旧方案里同时出现“Go 同步规整”和“同服共享数据库避免 HTTP 调用”，路线冲突。
- 线上失败数据里多数 `source_json` 是数组文本，说明新导入可能把一整个书源包存成了一条书源；旧逻辑通常会拆分数组并逐条规整。
- 增删改查应该只处理单个书源；多书源文件属于导入/导出能力，不能混进单条书源 CRUD。

### 1.1 线上只读审计快照

当前线上 `book_sources` 只读聚合结果：

```text
总数：18
检测失败：6
检测通过：1
未检测/unknown：11
空 source_json：0
```

失败原因分布：

```text
invalid type: map, expected a string：5
JS not a function：1
```

`source_json` 形态：

```text
json_array_text：12，其中 failed 5、unknown 7
json_object_text：6，其中 failed 1、passed 1、unknown 4
```

这个审计说明第一批修复不能只处理字段类型，还必须处理“数组/书源包导入拆分”。

### 1.2 现有导入/导出接口归属

当前 Rust 已有 `/api/v1/sources/import/*` 和 `/api/v1/sources/export`。长期口径下，这些接口属于平台/网关源导入导出，使用 `default_user_ns()`，写入唯一权威表 `book_sources`；`reader_book_sources` 只保留为只读投影视图，不再是第二张权威表。

移动端“我的书源”的归属模型是 `book_sources.user_id=当前用户`，但接口 owner 已从 Go 切到 Rust：Rust 直接校验用户身份、规整 JSON、写入 `runtime_source_json`，Go 不再提供 `/v1/me/book-sources*` 与 `/v1/me/book-source-groups*`。

后续仍需要新增私人导入/导出：

```text
私人导入：写入 book_sources.user_id = 当前用户
私人导出：只导出当前用户自己的 private 书源
平台导入：写入平台/网关源池，需要管理员权限
共享池：只能由用户提交审核或管理员审核通过后进入
```

### 1.3 阶段 0-3 执行记录

本轮已完成阶段 0-3 的基础落地，未直接执行任何线上写库操作。

- 阶段 0：已结合线上只读审计确认主要失败形态为 `json_array_text` 被误存为单条书源，同时本地 Rust 模型已具备 `loginUi/header/ruleSearch` 等结构化字段转字符串能力。
- 阶段 1：Rust 新增统一规整模块 `book_source_normalization`，提供 `normalize_book_source_json`、`parse_book_source_import`、单源解析拒绝多源 payload，以及结构化字段兼容 warning。
- 阶段 2：Go 新增 `0042_add_book_source_runtime_fields.sql`，增加 `runtime_source_json`、`compatibility_report`、`normalization_status`、`last_normalized_at`、`normalization_error`，并用 SQL 将历史运行态统一清为 `pending`，数组/包装历史行标记为待拆分。
- 阶段 3：移动端单源新增/编辑已切到 Rust 即时规整，数组/包装格式会返回“请使用导入功能导入多个书源”；Go 后台创建/编辑只保留控制面入口，不再作为移动端我的书源生命周期。
- 额外修正：Go source access 私人书源范围收紧为 `private + enabled`，不再把 `submitted` 投稿快照混入私人搜索范围。
- 验证：Rust `cargo test` 通过；Go `go test ./...` 通过。

本轮尚未执行的接线项：私人导入/导出拆分写入当前用户。这属于阶段 7 的后续工作。

### 1.4 阶段 4-6 执行记录

本轮按长期方案收敛为“一个权威书源定义表 + 多个运行状态表”，不再维护 `book_sources` 和 `reader_book_sources` 两张权威书源表。

- 阶段 4：Rust 新增迁移 `0017_consolidate_reader_book_sources.sql`，将旧 `reader_book_sources` 数据迁入 `book_sources`，旧表改为 legacy；随后新增 `0018_split_bad_book_source_payloads.sql`，拆分历史聚合书源并删除 `reader_book_sources` 投影视图。Rust 写入改为直接 upsert `book_sources`，运行时读取只使用 `runtime_source_json`。
- 阶段 5：Rust 新增 `/api/v1/me/book-sources/:id/test`，按 source id 读取当前用户 `book_sources.runtime_source_json` 检测并写回 `last_test_status/last_test_message`，不再走 Flutter -> Go -> Rust raw JSON 中转。
- 阶段 6：Rust 新增 `/api/v1/me/book-sources*` 与 `/api/v1/me/book-source-groups*`，覆盖我的书源 CRUD、启停、提交共享、分组 CRUD；Flutter 我的书源服务已切到 Rust gateway；Go 已移除 `/v1/me/book-sources*` 和 `/v1/me/book-source-groups*` 移动端旧路由、权限配置、handler 死代码和 application 私人生命周期方法。
- 验证：Rust `cargo test` 通过；Go `go test ./...` 通过；Flutter `flutter analyze` 通过。

### 1.5 阶段 7-10 核心收口执行记录

本轮先执行核心收口项，私人导入/导出完整产品流程仍留到阶段 7 后续单独做。

- Rust 私人书源新增、分组新增、检测、提交共享已直接读取共享数据库中的 `users`、`user_vips`、`source_quota_policies`、`source_quota_daily_usages`，不再为了这些接口走 Go HTTP 中转。
- Rust 私人书源检测已写回 `source_quota_daily_usages.test_count`，并在响应中返回更新后的检测额度快照。
- Rust 新增 pending 规整后台任务，每 60 秒扫描 `book_sources.normalization_status='pending'`，成功写入 `runtime_source_json/compatibility_report`，失败写入 `normalization_status='failed'` 和错误原因。
- Rust 新增历史坏数据迁移脚本 `0018_split_bad_book_source_payloads.sql`，把数组/包装格式历史聚合行拆成单条书源；无效 JSON 或非单源对象直接标记 failed，不继续保留旧兼容垃圾数据。该脚本只提交到仓库，本轮不直接执行线上写库。
- Rust runtime 查询已改为内联 `book_sources` 投影，SQL 里的 `reader_book_sources` 只是子查询别名，不再依赖数据库视图。
- Flutter 我的书源已展示待规整、配置异常、检测通过、检测失败、未检测等状态；搜索范围列表会展示检测状态标签，检测失败源不会被默认隐藏。
- 验证：Rust `cargo test` 通过；Go `go test ./...` 通过；Flutter `flutter analyze` 通过。

---

## 2. 设计原则

1. **原始 JSON 必须保真保存。** 用户编辑、导出、问题排查都看原始导入内容。
2. **运行时只使用 canonical/runtime JSON。** 检测、搜索、阅读、WebView 相关能力都走同一份规整结果。
3. **规整逻辑只能有一个源头。** 优先放在 Rust，因为 Rust 才是书源执行引擎，不能在 Go 和 Flutter 各写一套兼容规则。
4. **Go 做商业控制面，Rust 做书源生命周期。** Go 管账号、会员、权限、额度策略、后台审核/发现控制；Rust 管我的书源 CRUD、分组 CRUD、导入导出、解析、检测、搜索、阅读执行。
5. **不保留旧兼容垃圾数据。** 迁移时直接清理旧的临时字段、错误缓存和不可判定状态，重新生成权威运行时数据。
6. **“可导入”和“可用”分开表达。** JSON 能保存不等于书源一定能搜索、登录或阅读。
7. **共库优先，避免服务互调。** Go 和 Rust 共用数据库时，Rust 直接读取用户、权限、书源、额度相关表；除非跨系统边界必须调用，否则不增加 Go -> Rust 或 Rust -> Go 的 HTTP 调用。
8. **搜索范围不因检测失败隐藏书源。** 用户有权限看到的书源都应出现在移动端搜索范围里，检测失败只作为标签和排序信号，不作为默认过滤条件。
9. **单源 CRUD 只支持单个网站书源。** 新增/编辑接口只接受单个书源对象，不接受数组或包装格式。
10. **书源包走导入流程。** 数组、`bookSourceList`、`bookSources`、`data`、`sources` 包装格式只能走导入接口，导入时拆分为多条私人书源。

---

## 3. 推荐目标架构

### 3.1 数据模型

在 Go 的 `book_sources` 表中保留原始 JSON，并增加运行时字段：

```sql
source_json              -- 用户原始 JSON，保真
runtime_source_json      -- Rust 规整后的运行时 JSON
compatibility_report     -- 结构化兼容报告，建议 JSONB
normalization_status     -- pending / done / failed
last_normalized_at       -- 最近规整时间
```

命名建议使用 `runtime_source_json`，而不是 `source_json_normalized`。原因是它不只是“格式化后的 JSON”，而是 Rust 运行时真正应该使用的书源配置。

### 3.2 运行时读取规则

所有 Rust 书源执行入口统一按以下顺序取 JSON：

```text
只使用 runtime_source_json
  -> 如果为空，返回 SOURCE_NOT_NORMALIZED
  -> 如果规整失败，返回 SOURCE_NORMALIZE_FAILED + compatibility_report
```

涉及入口：

- 书源检测 `/api/v1/sources/check/raw`
- 搜索
- 详情
- 目录
- 正文
- WebView/login task
- Rust 从 Go `book_sources` 读取私人/共享书源的路径

### 3.3 服务边界

```text
Flutter
  -> Go：登录、会员、权限、额度展示、账号相关能力
  -> Rust：我的书源、分组、审核、检测、搜索、阅读执行、WebView 任务

Go
  -> 只维护用户、会员、权限、额度策略
  -> 不实现书源兼容规则
  -> 不提供书源 CRUD 和分组 CRUD 的长期接口
  -> 不承担运行时解析

Rust
  -> 我的书源增删改查
  -> 私人书源导入/导出
  -> 书源分组增删改查
  -> 书源审核/共享状态
  -> 唯一书源解析/规整入口
  -> 写入 runtime_source_json / compatibility_report
  -> 所有运行时执行都使用 runtime_source_json
```

### 3.4 权责划分

书源相关运行能力统一交给 Rust：

- 我的书源增删改查
- 私人书源导入/导出
- 书源分组增删改查
- 书源启用/停用
- 书源提交审核/共享状态
- 书源 JSON 解析
- 书源规整
- 兼容报告
- 书源检测
- 搜索
- 详情
- 目录
- 正文
- WebView/login task
- 运行时缓存
- 书源健康状态

账号与商业控制统一交给 Go：

- 用户登录
- token 签发与刷新
- 会员状态
- 功能权限
- 额度策略
- 额度扣减记录
- 管理后台

两边搭配方式：

```text
Flutter 带 token 请求 Rust 书源能力
  -> Rust 校验 token 或解析 Go 签发的用户身份
  -> Rust 直接读取共享数据库中的用户/会员/额度/书源授权状态
  -> Rust 处理我的书源/分组/检测/搜索/阅读
  -> Rust 执行书源能力
  -> Rust 写回检测结果、健康状态、运行时报告

Go 不执行书源规则
Go 不长期提供书源 CRUD / 分组 CRUD
Rust 不决定会员商品和账号体系
```

这条边界的重点是：Rust 负责书源完整生命周期，Go 负责账号商业规则。Rust 可以读取和更新必要的控制面数据，但会员商品、额度策略、账号体系仍由 Go 定义。

### 3.5 移动端搜索范围

移动端搜索范围列表不应该只展示检测成功的书源。原因是检测失败可能是临时网络、反爬、登录态、超时、规则局部失败导致，如果直接隐藏，用户会误以为书源丢失。

推荐展示规则：

```text
有权限 + enabled=true 的书源全部展示
  -> 检测通过：正常标签
  -> 检测失败：显示【检测失败】
  -> 待检测：显示【未检测】
  -> 规整失败：显示【配置异常】
```

默认排序建议：

```text
检测通过
  -> 未检测/待检测
  -> 检测失败
  -> 配置异常
```

用户仍然可以手动选择失败书源搜索，但 UI 要给出明确提示，避免隐藏造成误解。

---

## 4. 阶段任务清单

### 阶段 0：确认真实失败样本

- [x] 从线上数据库做只读审计，优先覆盖 `json_array_text` 和 `json_object_text` 两类。
- [x] 统计线上 `source_json` 形态：object、array、wrapper、string-wrapped、invalid。
- [x] 确认主要失败形态是“多书源数组/书源包被误存为单条书源”。
- [x] 确认本地 Rust 模型已有 `deserialize_stringish_opt`，可兼容 `loginUi/header/ruleSearch` 等结构化字段。
- [x] 输出失败形态结论，区分数组拆分问题和字段兼容问题。
- [ ] 如线上继续报错，再补充 3-5 个原始失败 JSON 样本做定向回归。

验收标准：

- [x] 不再靠猜测修改字段兼容逻辑。
- [ ] 新增失败样本时必须有可复现测试或明确部署差异结论。

### 阶段 1：Rust 统一规整入口

- [x] 在 Rust 新增 `normalize_book_source_json(raw)` 纯函数，输入原始 JSON，输出 `runtime_source_json + compatibility_report`。
- [x] 在 Rust 新增 `parse_book_source_import(raw)` 纯函数，输入任意导入 payload，输出多条书源草稿。
- [x] 复用现有 `BookSource` 宽松反序列化，不在 Go/Flutter 重写规则。
- [x] 支持单个书源 JSON、数组书源、`bookSourceList/bookSources/data/sources` 包装格式。
- [x] 单源新增/编辑接口遇到数组/包装格式时返回明确错误：`请使用导入功能导入多个书源`。
- [x] 导入解析遇到数组/包装格式时拆分成多条书源草稿。
- [x] 对 object/array/number/bool 转 string 的字段记录 warning。
- [x] 为 `loginUi`、`header`、`ruleSearch` 等结构化字段增加回归测试。
- [ ] 私人导入保存接口接入当前用户名下的批量写入。
- [ ] 对无法支持的结构补齐更完整的字段路径、原始类型、期望类型、建议处理方式。

验收标准：

- [x] `cargo test` 中 normalization 相关测试通过。
- [x] 单源 CRUD 不再保存数组书源。
- [x] runtime JSON 可直接被 Rust 检测入口使用。
- [ ] 书源包导入会生成多条当前用户私人源记录，而不是一条数组记录。

### 阶段 2：SQL 迁移与数据清理

- [x] 用 SQL 迁移直接增加 `runtime_source_json`。
- [x] 增加 `compatibility_report`，使用 `JSONB`。
- [x] 增加 `normalization_status`、`last_normalized_at`、`normalization_error`。
- [x] 增加 pending/normalization 查询索引。
- [x] 用 SQL 将历史不可信运行态标记为 `pending`，数组/包装行标记为待拆分。
- [x] Rust 新增 `0017_consolidate_reader_book_sources.sql`，把旧 `reader_book_sources` 迁入 `book_sources`。
- [x] Rust 迁移将 `book_sources.id` 补齐为非空唯一约束，旧表迁入使用动态 SQL，避免无旧表环境解析失败。
- [x] `reader_book_sources` 降级为只读 runtime 投影视图，不再是权威表。
- [x] Go domain/repository/API 响应增加兼容状态字段，列表页不返回完整 runtime JSON。
- [x] 对历史数组/包装行执行拆分迁移，并删除或标记原聚合行。
- [ ] 迁移前备份、dry-run 和迁移报告脚本。

验收标准：

- [x] 新增字段为空时不会影响现有创建、编辑、列表、删除。
- [x] 新旧表不再双写，`book_sources` 是唯一权威书源定义表。
- [ ] 所有历史数据都有最终状态：done / failed / migrated。

### 阶段 3：创建/编辑后的规整流程

- [x] 移动端创建/编辑书源由 Rust 接管，并在写库前即时生成 `runtime_source_json` 和 `compatibility_report`。
- [x] Rust 新增/编辑接口只允许单条书源对象。
- [x] Rust 新增/编辑接口遇到数组/包装格式时返回明确提示，要求走导入功能。
- [x] 检测入口如果发现 runtime 为空或状态不是 `done`，返回“书源正在规整或规整失败，请编辑后重试”，不回退原始 JSON。
- [x] Go 移动端私人书源生命周期方法已移除，不再承担创建/编辑/检测/提交/删除。
- [x] 历史 pending/admin pending 数据的批量规整任务。
- [x] 规整失败时写入更完整的 `normalization_status=failed` 和错误报告。

验收标准：

- [x] 移动端新增/编辑后检测使用同一份 runtime JSON。
- [x] 单源新增/编辑不会再把书源包保存成一条数组记录。
- [ ] 私人批量导入保存后立刻检测不抛底层 JSON 类型错误。

### 阶段 4：Rust 执行入口统一读取 runtime JSON

- [x] Rust 写入和平台导入直接 upsert `book_sources`。
- [x] Rust runtime 读取通过内联 `book_sources` 投影拿 `runtime_source_json`，不再依赖 `reader_book_sources` 投影视图。
- [x] 私人书源检测直接读取 `book_sources.runtime_source_json`。
- [x] 健康状态写回 `book_sources.health_status/last_checked_at`。
- [x] 搜索范围候选不因检测失败默认隐藏可见书源。
- [x] 把 Rust repo 中剩余 `reader_book_sources` 查询逐步改成直接查询 `book_sources`，最终删除投影视图。
- [ ] 对 runtime 缺失、规整失败、字段不兼容补齐统一错误码和用户提示。

验收标准：

- [x] Go `book_sources` 和 Rust 运行时读取路径已收敛到单权威表。
- [x] 移动端搜索范围能看到检测成功、检测失败、未检测的可见书源。
- [x] 完全移除 repo 层对投影视图的依赖。

### 阶段 5：检测接口边界收敛

- [x] 目标链路改为 Flutter -> Rust 检测接口。
- [x] Rust 检测接口接收 source id，不接收客户端传来的 raw JSON。
- [x] Rust 自己从数据库读取 `runtime_source_json`。
- [x] Rust 校验 owner、visibility、enabled。
- [x] Rust 写回 `last_test_status`、`last_test_message`、检测报告摘要。
- [x] Go 侧 `/v1/me/book-sources/:id/test` 已删除，不保留 raw JSON 转发代理。
- [x] Rust 检测接口接入 Go 维护的检测额度扣减。

验收标准：

- [x] 不再出现 Flutter -> Go -> Rust 传 raw JSON 的链路。
- [x] 不再保留 Go -> Rust raw JSON 检测中转代码。
- [x] 不绕过检测额度。
- [ ] 检测报错不再暴露底层 serde 原始错误，改为结构化兼容提示。

### 阶段 6：我的书源与分组接口迁移到 Rust

- [x] Rust 提供我的书源列表接口。
- [x] Rust 提供我的书源详情接口。
- [x] Rust 提供我的书源新增接口。
- [x] Rust 提供我的书源编辑接口。
- [x] Rust 提供我的书源删除接口。
- [x] Rust 提供书源启用/停用接口。
- [x] Rust 新增/编辑接口只接受单个书源对象。
- [x] Rust 新增/编辑接口拒绝数组/包装格式，并返回“多个书源请使用导入功能”。
- [x] Rust 提供书源分组列表接口。
- [x] Rust 提供书源分组新增接口。
- [x] Rust 提供书源分组编辑接口。
- [x] Rust 提供书源分组删除接口。
- [x] Rust 删除分组后同步处理书源分组归属，避免移动端继续显示已删除分组。
- [x] Flutter 我的书源和分组服务调用地址已切换到 Rust gateway。
- [x] Go 删除 `/v1/me/book-sources*` 和 `/v1/me/book-source-groups*` 旧路由、权限配置、handler 死代码和 application 私人生命周期方法。
- [x] Rust 创建/编辑书源时校验 Go 维护的会员权限和数量额度。

验收标准：

- [x] 我的书源增删改查全部走 Rust。
- [x] 分组增删改查全部走 Rust。
- [x] Go 不再承担移动端我的书源管理接口，只保留账号、会员、权限、额度、后台审核/发现控制相关接口。

### 阶段 7：私人书源导入/导出

- [ ] Rust 提供私人书源导入预览接口，支持文件、剪贴板文本、URL 文本。
- [ ] 导入预览识别单个书源、数组书源、`bookSourceList/bookSources/data/sources` 包装格式。
- [ ] 导入预览返回总数、可导入数、失败数、重复数、分组建议和错误明细。
- [ ] 导入预览读取 Go 维护的会员/额度策略，返回当前私人书源数、最大可拥有数、剩余可新增数。
- [ ] 导入预览按“新增数量”计算额度占用，已存在且选择覆盖的书源不重复占用新增额度。
- [ ] 导入预览标记超额候选，明确提示“剩余额度不足，可升级会员、删除旧书源或只导入前 N 条”。
- [ ] Rust 提供私人书源导入保存接口，批量写入 `book_sources.user_id=当前用户`。
- [ ] 私人导入保存时再次校验会员权限和数量额度，不能只信任预览结果。
- [ ] 私人导入保存使用事务或等价并发保护，避免两个导入请求同时通过额度检查后超额写入。
- [ ] 私人导入保存默认 all-or-none：只要新增数量超过剩余额度，整批拒绝并返回可导入上限。
- [ ] 如产品允许“部分导入”，必须由前端明确传 `allowPartial=true`，Rust 只保存额度内候选并返回 skipped_over_quota 明细。
- [ ] 私人导入保存时每条书源生成独立 `runtime_source_json` 或标记 `pending`。
- [ ] Rust 提供私人书源导出接口，只导出当前用户自己的 `visibility=private` 书源。
- [ ] 私人导出默认导出原始 `source_json`，不导出 runtime 字段和内部兼容报告。
- [ ] Rust 平台源导入/导出与私人源导入/导出使用不同接口和权限。
- [ ] 明确现有 `/api/v1/sources/import/*`、`/api/v1/sources/export` 若继续保留，只作为平台/网关源导入导出，不作为我的书源接口。
- [ ] 用户导入的私人源不能直接进入共享池，也不能默认挂到管理员账号。
- [ ] 用户点击“提交共享”后才生成待审核共享记录。

验收标准：

- [ ] 多书源文件不能通过单源新增保存。
- [ ] 多书源文件可以通过私人导入拆分成多条当前用户私人源。
- [ ] 导入保存不会突破当前用户私人书源数量限制。
- [ ] 额度不足时不会产生半批静默写入；要么整批拒绝，要么在用户确认后部分导入并返回明细。
- [ ] 私人导入不会写入管理员名下，不会直接进入共享池。
- [ ] 私人导出只能导出当前用户自己的私人源。

### 阶段 8：Flutter 展示与交互

- [x] `PrivateBookSourceItem` 增加 `normalizationStatus`、`compatibilityReport` 摘要字段。
- [x] 我的书源列表展示兼容状态：待规整、可用、有警告、规整失败。
- [x] 我的书源服务调用地址从 Go 切换到 Rust。
- [x] 我的书源分组服务调用地址从 Go 切换到 Rust。
- [ ] 新增单个书源时，如果用户选择多书源文件，提示“该文件包含多个书源，请使用导入功能”。
- [ ] 新增私人书源导入入口，支持文件、剪贴板、URL。
- [ ] 新增私人书源导入预览页，展示可导入条数、失败条数、重复条数和分组。
- [ ] 新增私人书源导出入口。
- [x] 搜索范围列表展示健康状态标签：检测通过、检测失败、未检测、配置异常。
- [x] 检测失败书源仍可被用户选择搜索。
- [ ] 详情/编辑页显示兼容报告，但编辑器仍展示原始 JSON。
- [ ] 检测失败时展示字段路径和建议，不只显示 `invalid type`。
- [x] 不在 Flutter 实现完整规整逻辑，只做 JSON 合法性、名称/分组提取和 UI 提示。

验收标准：

- [x] 用户知道“已导入但待规整/有兼容警告/规整失败”的区别。
- [x] 用户不会因为书源检测失败而在搜索范围里“看不见”该书源。
- [x] 前端不会和 Rust 产生两套兼容规则。

### 阶段 9：历史数据批量规整

- [ ] SQL 先完成 schema 迁移和脏数据清理。
- [x] 对历史 `source_json` 为数组/包装格式的记录执行拆分迁移。
- [x] 拆分成功后，原数组记录标记为 migrated 或删除，避免重复展示。
- [x] 拆分出的新记录继承 owner、visibility、enabled、group、created_at 等控制面字段。
- [x] Rust 批量扫描已有 `book_sources.source_json`。
- [x] 对历史书源生成 `runtime_source_json`。
- [ ] 输出迁移报告：总数、成功数、警告数、失败数、Top 失败字段。
- [ ] 迁移前备份数据库。
- [ ] 迁移支持 dry-run。
- [x] 迁移失败的数据保持 `normalization_status=failed`，不生成半成品 runtime JSON。

验收标准：

- [ ] 老用户已导入书源不需要手动重新导入。
- [ ] 历史数组书源不会继续以“单条失败书源”的形式存在。
- [ ] 失败数据可定位原因，不静默丢弃，也不混入可用数据。

### 阶段 10：Go/Rust 协作边界固化

- [x] 明确书源运行能力全部归 Rust，包括检测、搜索、详情、目录、正文、WebView/login task。
- [x] 明确我的书源 CRUD、书源分组 CRUD 归 Rust。
- [x] 明确私人书源导入/导出归 Rust。
- [x] 明确账号、权限、会员、额度策略全部归 Go。
- [x] Rust 书源接口支持 Go 签发 token 的用户身份解析。
- [x] Rust 我的书源生命周期接口直接读取共享数据库中的会员/权限/额度配置，避免 HTTP 互调。
- [x] Rust 我的书源生命周期接口执行前完成 owner、visibility、enabled、quota 校验。
- [x] Rust 私人检测执行后写回额度使用记录、检测结果、书源健康状态。
- [x] Go 不再提供书源检测中转接口。
- [x] Go 不再提供我的书源和分组 CRUD 接口。
- [x] Go 不提供私人书源导入/导出接口。
- [x] 删除 Go -> Rust raw JSON 转发代码。
- [x] 清理所有“Go 执行书源规则”或“Go 调 Rust normalize”的旧文档描述。

验收标准：

- [x] 每个接口只有一个明确 owner：书源运行归 Rust，账号商业归 Go。
- [x] 不为了少一次 HTTP 牺牲权限、额度和状态一致性。

---

## 5. 不建议做的事

- [ ] 不建议 Flutter 实现完整书源规整规则。
- [ ] 不建议 Go 长期调用 Rust `/api/normalize` 同步阻塞创建书源。
- [ ] 不建议 Go 和 Rust 各自维护一套字段兼容表。
- [ ] 不建议只加 `source_json_normalized` 字段但不改 Rust 读取路径。
- [ ] 不建议 runtime 为空时自动回退原始 `source_json` 执行。
- [ ] 不建议为了兼容历史数据保留旧错误缓存或旧半成品规整数据。
- [ ] 不建议单源新增/编辑接口兼容多书源数组。
- [ ] 不建议私人导入直接写入共享池或管理员名下。
- [ ] 不建议承诺“100% 书源可用”，应表述为“100% 合法 JSON 可导入，运行能力按兼容报告展示”。
- [ ] 不建议检测接口直接暴露 serde 原始错误给用户。

---

## 6. 推荐实施顺序

第一优先级：

- [x] 阶段 0：确认失败样本。
- [x] 阶段 1：Rust 统一规整入口。
- [x] 阶段 2：SQL 迁移与数据清理。

第二优先级：

- [x] 阶段 3：创建/编辑后的规整流程。
- [x] 阶段 4：Rust 执行入口统一读取 runtime JSON。
- [x] 阶段 5：检测接口边界收敛。
- [x] 阶段 6：我的书源与分组接口迁移到 Rust。
- [ ] 阶段 7：私人书源导入/导出。

第三优先级：

- [ ] 阶段 8：Flutter 展示。
- [ ] 阶段 9：历史数据迁移。
- [x] 阶段 10：协作边界固化。

---

## 7. 最小可交付版本

如果要最快修复客户当前问题，建议先做最小版本：

- [ ] 用真实失败 JSON 补 Rust 回归测试。
- [x] 修 Rust 解析兼容，确保旧逻辑能处理的 JSON 可生成 runtime JSON。
- [x] SQL 增加 runtime 字段并清理旧兼容垃圾数据。
- [x] 单源新增/编辑拒绝数组书源，并提示走导入。
- [ ] 先处理线上 `json_array_text` 失败源，把书源包按私人导入规则拆成多条当前用户私人源。
- [x] Rust 接管我的书源和分组 CRUD。
- [ ] Rust 增加私人书源导入/导出。
- [x] Rust 从 Go `book_sources` 读取时只使用 runtime JSON。
- [x] 检测接口改为 source id，不再传 raw JSON。
- [x] Flutter 只增加兼容状态/错误提示，不做复杂规整。

这个版本能先解决“导入成功但检测失败”的主问题，同时不会把架构一次性推倒重来。
